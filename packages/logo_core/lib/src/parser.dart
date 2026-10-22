import 'errors.dart';
import 'values.dart';

// ---------------------------------------------------------------------------
// Jetons
// ---------------------------------------------------------------------------

enum TokKind { number, quoted, variable, name, op, unaryMinus, lparen, rparen, list }

class Token {
  final TokKind kind;
  final String text;
  final LogoValue? value;
  final SourcePos? pos;

  Token(this.kind, this.text, {this.value, this.pos});

  @override
  String toString() => text;
}

const _opChars = '+-*/=<>';

/// Découpe le contenu d'une liste d'instructions en jetons. Les mots lus par
/// le lecteur sont redécoupés autour des opérateurs infixes (`:x+1`),
/// comme le fait le « runparse » de Logo.
List<Token> tokenize(LogoList list) {
  final out = <Token>[];
  for (final item in list.items) {
    switch (item) {
      case LogoList l:
        out.add(Token(TokKind.list, '[…]', value: l, pos: l.pos));
      case LogoNumber n:
        out.add(Token(TokKind.number, n.text, value: n));
      case LogoWord w:
        _tokenizeWord(w, out);
    }
  }
  return out;
}

void _tokenizeWord(LogoWord w, List<Token> out) {
  final s = w.text;
  final pos = w.pos;
  SourcePos? at(int offset, int len) => pos?.shift(offset, len);

  if (s == '(') {
    out.add(Token(TokKind.lparen, s, pos: pos));
    return;
  }
  if (s == ')') {
    out.add(Token(TokKind.rparen, s, pos: pos));
    return;
  }
  if (s.startsWith('"')) {
    final t = s.substring(1);
    out.add(Token(TokKind.quoted, s, value: LogoWord(t, pos), pos: pos));
    return;
  }
  final whole = parseLogoNumber(s);
  if (whole != null) {
    out.add(Token(TokKind.number, s, value: LogoNumber(whole), pos: pos));
    return;
  }

  var j = 0;
  while (j < s.length) {
    final c = s[j];
    if (_opChars.contains(c)) {
      if (c == '-') {
        final prevIsOp = j > 0 && _opChars.contains(s[j - 1]);
        final unary = (j == 0 || prevIsOp) && j + 1 < s.length;
        if (unary) {
          // Nombre négatif collé : -10, 3*-2
          final m = _numAt(s, j + 1);
          if (m != null && (j + 1 + m.length == s.length || _opChars.contains(s[j + 1 + m.length]))) {
            out.add(Token(TokKind.number, '-$m', value: LogoNumber(-parseLogoNumber(m)!), pos: at(j, m.length + 1)));
            j += 1 + m.length;
            continue;
          }
          out.add(Token(TokKind.unaryMinus, '-', pos: at(j, 1)));
          j++;
          continue;
        }
        out.add(Token(TokKind.op, '-', pos: at(j, 1)));
        j++;
        continue;
      }
      if ((c == '<' || c == '>') && j + 1 < s.length) {
        final two = s.substring(j, j + 2);
        if (two == '<=' || two == '>=' || two == '<>') {
          out.add(Token(TokKind.op, two, pos: at(j, 2)));
          j += 2;
          continue;
        }
      }
      out.add(Token(TokKind.op, c, pos: at(j, 1)));
      j++;
      continue;
    }
    // Segment jusqu'au prochain opérateur.
    final start = j;
    if (c == ':') {
      j++;
      while (j < s.length && !_opChars.contains(s[j])) {
        j++;
      }
      final name = s.substring(start + 1, j);
      if (name.isEmpty) throw LogoError('Nom de variable manquant après « : »', at(start, 1));
      out.add(Token(TokKind.variable, s.substring(start, j), value: LogoWord(name), pos: at(start, j - start)));
      continue;
    }
    final m = _numAt(s, j);
    if (m != null && (j + m.length == s.length || _opChars.contains(s[j + m.length]))) {
      out.add(Token(TokKind.number, m, value: LogoNumber(parseLogoNumber(m)!), pos: at(j, m.length)));
      j += m.length;
      continue;
    }
    while (j < s.length && !_opChars.contains(s[j])) {
      j++;
    }
    out.add(Token(TokKind.name, s.substring(start, j), pos: at(start, j - start)));
  }
}

final _numPrefix = RegExp(r'(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?');

String? _numAt(String s, int j) {
  final m = _numPrefix.matchAsPrefix(s, j);
  return m?.group(0);
}

// ---------------------------------------------------------------------------
// Arbre syntaxique
// ---------------------------------------------------------------------------

sealed class Node {
  final SourcePos? pos;
  const Node(this.pos);
}

class LiteralNode extends Node {
  final LogoValue value;
  const LiteralNode(this.value, SourcePos? pos) : super(pos);
}

class VarNode extends Node {
  final String name;
  const VarNode(this.name, SourcePos? pos) : super(pos);
}

class CallNode extends Node {
  /// Nom en minuscules.
  final String name;

  /// Nom tel qu'écrit par l'utilisateur (pour les messages).
  final String written;
  final List<Node> args;
  const CallNode(this.name, this.written, this.args, SourcePos? pos) : super(pos);
}

class BinaryNode extends Node {
  final String op;
  final Node left, right;
  const BinaryNode(this.op, this.left, this.right, SourcePos? pos) : super(pos);
}

class NegateNode extends Node {
  final Node operand;
  const NegateNode(this.operand, SourcePos? pos) : super(pos);
}

/// Nombre d'arguments d'une procédure : [normal] sans parenthèses, entre
/// [min] et [max] avec parenthèses (`max` négatif = illimité).
class Arity {
  final int min, normal, max;
  const Arity(this.min, this.normal, this.max);
  const Arity.fixed(int n) : this(n, n, n);
}

typedef ArityLookup = Arity? Function(String lowerName);

// ---------------------------------------------------------------------------
// Analyseur
// ---------------------------------------------------------------------------

/// Analyse une liste d'instructions. Comme en Logo, le découpage dépend du
/// nombre d'arguments attendu par chaque procédure, d'où [arityOf].
class Parser {
  final List<Token> _toks;
  final ArityLookup arityOf;
  final SourcePos? _fallbackPos;
  int _p = 0;

  Parser(this._toks, this.arityOf, [this._fallbackPos]);

  static List<Node> parseList(LogoList list, ArityLookup arityOf) {
    final parser = Parser(tokenize(list), arityOf, list.pos);
    final out = <Node>[];
    while (!parser._atEnd) {
      out.add(parser.parseExpression());
    }
    return out;
  }

  bool get _atEnd => _p >= _toks.length;
  Token? get _peek => _atEnd ? null : _toks[_p];

  SourcePos? get _endPos => _toks.isNotEmpty ? _toks.last.pos : _fallbackPos;

  static int _prec(String op) => switch (op) {
    '=' || '<' || '>' || '<=' || '>=' || '<>' => 1,
    '+' || '-' => 2,
    '*' || '/' => 3,
    _ => 0,
  };

  Node parseExpression([int minPrec = 1]) {
    var left = _parseUnary();
    return _parseInfix(left, minPrec);
  }

  Node _parseInfix(Node left, int minPrec) {
    while (true) {
      final t = _peek;
      if (t == null || t.kind != TokKind.op) break;
      final prec = _prec(t.text);
      if (prec < minPrec) break;
      _p++;
      if (_atEnd) {
        throw LogoError('Il manque quelque chose après « ${t.text} »', t.pos);
      }
      final right = parseExpression(prec + 1);
      left = BinaryNode(t.text, left, right, t.pos);
    }
    return left;
  }

  Node _parseUnary() {
    final t = _peek;
    if (t != null && (t.kind == TokKind.unaryMinus || (t.kind == TokKind.op && t.text == '-'))) {
      _p++;
      if (_atEnd) throw LogoError('Il manque quelque chose après « - »', t.pos);
      return NegateNode(_parseUnary(), t.pos);
    }
    return _parsePrimary();
  }

  Node _parsePrimary() {
    final t = _peek;
    if (t == null) throw LogoError('Expression incomplète', _endPos);
    _p++;
    switch (t.kind) {
      case TokKind.number:
      case TokKind.quoted:
      case TokKind.list:
        return LiteralNode(t.value!, t.pos);
      case TokKind.variable:
        return VarNode((t.value as LogoWord).text.toLowerCase(), t.pos);
      case TokKind.name:
        return _parseCall(t, parenthesized: false);
      case TokKind.lparen:
        final next = _peek;
        Node inner;
        if (next != null && next.kind == TokKind.name && arityOf(next.text.toLowerCase()) != null) {
          _p++;
          inner = _parseCall(next, parenthesized: true);
          inner = _parseInfix(inner, 1);
        } else {
          inner = parseExpression();
        }
        final close = _peek;
        if (close == null || close.kind != TokKind.rparen) {
          throw LogoError('Parenthèse fermante « ) » manquante', t.pos);
        }
        _p++;
        return inner;
      case TokKind.rparen:
        throw LogoError('« ) » inattendue', t.pos);
      case TokKind.op:
      case TokKind.unaryMinus:
        throw LogoError('« ${t.text} » inattendu', t.pos);
    }
  }

  Node _parseCall(Token t, {required bool parenthesized}) {
    final lower = t.text.toLowerCase();
    final arity = arityOf(lower);
    if (arity == null) {
      throw LogoError('Je ne sais pas faire « ${t.text} »', t.pos);
    }
    final args = <Node>[];
    if (parenthesized) {
      while (true) {
        final n = _peek;
        if (n == null || n.kind == TokKind.rparen) break;
        if (n.kind == TokKind.op) break; // ex. (pi * 2)
        if (arity.max >= 0 && args.length >= arity.max) break;
        args.add(parseExpression());
      }
      if (args.length < arity.min) {
        throw LogoError('Pas assez d\'arguments pour « ${t.text} »', t.pos);
      }
    } else {
      for (var i = 0; i < arity.normal; i++) {
        if (_atEnd || _peek!.kind == TokKind.rparen) {
          throw LogoError('Pas assez d\'arguments pour « ${t.text} »', t.pos);
        }
        args.add(parseExpression());
      }
    }
    return CallNode(lower, t.text, args, t.pos);
  }
}

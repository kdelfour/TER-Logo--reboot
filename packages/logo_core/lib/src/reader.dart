import 'errors.dart';
import 'values.dart';

/// Une ligne logique du programme : les crochets et parenthèses ouverts
/// prolongent la ligne sur les lignes physiques suivantes.
class LogicalLine {
  final LogoList items;
  final int line;

  /// Texte source exact de la ligne (utilisé pour `detaille`).
  final String source;

  LogicalLine(this.items, this.line, this.source);
}

/// Lit du texte Logo et le découpe en lignes logiques composées de mots et
/// de listes, à la manière du lecteur de Logo : seuls les blancs, crochets
/// et parenthèses délimitent les mots à ce stade.
class Reader {
  final String text;
  int _i = 0;
  int _line = 1;
  int _lineStart = 0;

  Reader(this.text);

  static List<LogicalLine> readProgram(String text) => Reader(text)._readAll();

  /// Lit le contenu d'une chaîne comme une seule liste (pour `exec "texte`,
  /// la console, etc.).
  static LogoList readList(String text) {
    final lines = readProgram(text);
    if (lines.length == 1) return lines.first.items;
    return LogoList([for (final l in lines) ...l.items.items]);
  }

  SourcePos _pos([int len = 1]) => SourcePos(_line, _i - _lineStart + 1, len);

  List<LogicalLine> _readAll() {
    final out = <LogicalLine>[];
    while (_i < text.length) {
      final startLine = _line;
      final startOffset = _i;
      final items = <LogoValue>[];
      final lineStartPos = _pos();
      var parenDepth = 0;
      var ended = false;
      while (_i < text.length && !ended) {
        final c = text[_i];
        if (c == '\n') {
          _newline();
          if (parenDepth == 0) ended = true;
        } else if (_isSpace(c)) {
          _i++;
        } else if (c == ';') {
          _skipComment();
        } else if (c == '~' && _restOfLineBlank(_i + 1)) {
          // Continuation de ligne explicite.
          _skipComment();
          if (_i < text.length) _newline();
        } else if (c == '[') {
          items.add(_readBracketList());
        } else if (c == ']') {
          throw LogoError('« ] » inattendu', _pos());
        } else if (c == '(' || c == ')') {
          if (c == '(') parenDepth++;
          if (c == ')' && parenDepth > 0) parenDepth--;
          items.add(LogoWord(c, _pos()));
          _i++;
        } else {
          items.add(_readWord());
        }
      }
      if (items.isNotEmpty) {
        final src = text.substring(startOffset, _i).trimRight();
        out.add(LogicalLine(LogoList(items, lineStartPos), startLine, src));
      }
    }
    return out;
  }

  void _newline() {
    _i++;
    _line++;
    _lineStart = _i;
  }

  bool _restOfLineBlank(int from) {
    for (var j = from; j < text.length; j++) {
      final c = text[j];
      if (c == '\n') return true;
      if (!_isSpace(c)) return false;
    }
    return true;
  }

  void _skipComment() {
    while (_i < text.length && text[_i] != '\n') {
      _i++;
    }
  }

  LogoList _readBracketList() {
    final start = _pos();
    _i++; // [
    final items = <LogoValue>[];
    while (true) {
      if (_i >= text.length) {
        throw LogoError('Crochet fermant « ] » manquant', start);
      }
      final c = text[_i];
      if (c == '\n') {
        _newline();
      } else if (_isSpace(c)) {
        _i++;
      } else if (c == ';') {
        _skipComment();
      } else if (c == '[') {
        items.add(_readBracketList());
      } else if (c == ']') {
        _i++;
        return LogoList(items, start);
      } else if (c == '(' || c == ')') {
        items.add(LogoWord(c, _pos()));
        _i++;
      } else {
        items.add(_readWord());
      }
    }
  }

  LogoWord _readWord() {
    final start = _pos();
    final startIndex = _i;
    final buf = StringBuffer();
    while (_i < text.length) {
      final c = text[_i];
      if (_isSpace(c) || c == '\n' || c == '[' || c == ']' || c == '(' || c == ')' || c == ';') {
        break;
      }
      if (c == '\\' && _i + 1 < text.length) {
        buf.write(text[_i + 1]);
        _i += 2;
        continue;
      }
      if (c == '|') {
        _i++;
        while (_i < text.length && text[_i] != '|') {
          if (text[_i] == '\n') {
            _line++;
            _lineStart = _i + 1;
          }
          buf.write(text[_i]);
          _i++;
        }
        if (_i < text.length) _i++;
        continue;
      }
      buf.write(c);
      _i++;
    }
    return LogoWord(buf.toString(), start.shift(0, _i - startIndex));
  }

  static bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\r' || c == ' ';
}

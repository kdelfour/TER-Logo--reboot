import 'errors.dart';

/// Une valeur Logo : un mot (les nombres sont des mots) ou une liste.
sealed class LogoValue {
  const LogoValue();

  /// Représentation telle qu'affichée par `montre` (listes entre crochets).
  String show() => _format(this, true);

  /// Représentation telle qu'affichée par `ecris` (crochets externes omis).
  String print() => _format(this, false);

  @override
  String toString() => show();
}

/// Un mot Logo. Un nombre est un mot dont le texte est numérique ;
/// [LogoNumber] en est une forme déjà convertie.
class LogoWord extends LogoValue {
  final String text;

  /// Position dans le source, si le mot provient du lecteur.
  final SourcePos? pos;

  const LogoWord(this.text, [this.pos]);

  num? get asNumber => parseLogoNumber(text);

  @override
  bool operator ==(Object other) => other is LogoValue && logoEquals(this, other);

  @override
  int get hashCode => text.toLowerCase().hashCode;
}

class LogoNumber extends LogoWord {
  final num value;

  LogoNumber(num v)
      : value = _normalize(v),
        super(formatNumber(_normalize(v)));

  static num _normalize(num v) {
    if (v is double && v.isFinite && v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt();
    }
    return v;
  }

  @override
  num get asNumber => value;
}

class LogoList extends LogoValue {
  final List<LogoValue> items;
  final SourcePos? pos;

  /// Cache du parseur : instructions déjà analysées pour cette liste.
  Object? parseCache;
  int parseCacheGeneration = -1;

  LogoList(this.items, [this.pos]);

  static final empty = LogoList(const []);

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  @override
  bool operator ==(Object other) => other is LogoValue && logoEquals(this, other);

  @override
  int get hashCode => Object.hashAll(items);
}

final LogoWord logoTrue = LogoWord('vrai');
final LogoWord logoFalse = LogoWord('faux');
final LogoWord emptyWord = LogoWord('');

LogoWord logoBool(bool b) => b ? logoTrue : logoFalse;

final _numberRe = RegExp(r'^-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$');

num? parseLogoNumber(String s) {
  if (s.isEmpty || !_numberRe.hasMatch(s)) return null;
  final hasFrac = s.contains('.') || s.contains('e') || s.contains('E');
  if (!hasFrac) {
    final i = int.tryParse(s);
    if (i != null) return i;
  }
  final d = double.tryParse(s);
  if (d == null) return null;
  if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt();
  return d;
}

String formatNumber(num n) {
  if (n is int) return n.toString();
  final d = n as double;
  if (d.isNaN) return 'nan';
  if (d.isInfinite) return d > 0 ? 'infini' : '-infini';
  if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
  var s = d.toStringAsPrecision(12);
  if (s.contains('e')) {
    final parts = s.split('e');
    var m = parts[0];
    if (m.contains('.')) m = m.replaceFirst(RegExp(r'\.?0+$'), '');
    return '${m}e${parts[1]}';
  }
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s;
}

String _format(LogoValue v, bool brackets) {
  switch (v) {
    case LogoWord w:
      return w.text;
    case LogoList l:
      final inner = l.items.map((e) => _format(e, true)).join(' ');
      return brackets ? '[$inner]' : inner;
  }
}

/// Égalité Logo : numérique si les deux sont des nombres, sinon
/// comparaison de mots insensible à la casse, structurelle pour les listes.
bool logoEquals(LogoValue a, LogoValue b) {
  if (a is LogoWord && b is LogoWord) {
    final na = a.asNumber, nb = b.asNumber;
    if (na != null && nb != null) return na == nb;
    return a.text.toLowerCase() == b.text.toLowerCase();
  }
  if (a is LogoList && b is LogoList) {
    if (a.items.length != b.items.length) return false;
    for (var i = 0; i < a.items.length; i++) {
      if (!logoEquals(a.items[i], b.items[i])) return false;
    }
    return true;
  }
  return false;
}

bool? asLogoBool(LogoValue v) {
  if (v is LogoWord) {
    switch (v.text.toLowerCase()) {
      case 'vrai':
      case 'true':
        return true;
      case 'faux':
      case 'false':
        return false;
    }
  }
  return null;
}

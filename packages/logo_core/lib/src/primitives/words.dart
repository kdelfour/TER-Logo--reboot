import '../errors.dart';
import '../interpreter.dart';
import '../parser.dart';
import '../values.dart';
import 'util.dart';

const _cat = 'Mots et listes';
const _catPred = 'Prédicats';

/// Éléments d'un mot (ses caractères) ou d'une liste.
List<LogoValue> _elements(LogoValue v) => switch (v) {
  LogoList l => l.items,
  LogoWord w => [for (final ch in w.text.split('')) LogoWord(ch)],
};

LogoValue _rebuild(LogoValue like, List<LogoValue> items) => switch (like) {
  LogoList _ => LogoList(items),
  LogoWord _ => LogoWord(items.map((e) => e.print()).join()),
};

void _nonEmpty(PrimCall c, int i) {
  final v = c[i];
  final empty = v is LogoList ? v.isEmpty : (v as LogoWord).text.isEmpty;
  if (empty) throw LogoError('« ${c.name} » n\'aime pas une entrée vide', c.node.pos);
}

List<Primitive> wordPrimitives() => [
  prim(
    'premier prem',
    const Arity.fixed(1),
    (c) {
      _nonEmpty(c, 0);
      return _elements(c[0]).first;
    },
    cat: _cat,
    doc: 'premier élément d\'un mot ou d\'une liste',
  ),
  prim(
    'dernier der',
    const Arity.fixed(1),
    (c) {
      _nonEmpty(c, 0);
      return _elements(c[0]).last;
    },
    cat: _cat,
    doc: 'dernier élément',
  ),
  prim(
    'saufpremier sp',
    const Arity.fixed(1),
    (c) {
      _nonEmpty(c, 0);
      return _rebuild(c[0], _elements(c[0]).sublist(1));
    },
    cat: _cat,
    doc: 'tout sauf le premier élément',
  ),
  prim(
    'saufdernier sd',
    const Arity.fixed(1),
    (c) {
      _nonEmpty(c, 0);
      final e = _elements(c[0]);
      return _rebuild(c[0], e.sublist(0, e.length - 1));
    },
    cat: _cat,
    doc: 'tout sauf le dernier élément',
  ),
  prim(
    'item element',
    const Arity.fixed(2),
    (c) {
      final n = c.integer(0);
      final e = _elements(c[1]);
      if (n < 1 || n > e.length) {
        throw LogoError('« ${c.name} » : pas d\'élément numéro $n dans « ${c[1].show()} »', c.node.pos);
      }
      return e[n - 1];
    },
    cat: _cat,
    doc: 'item n liste — n-ième élément (à partir de 1)',
  ),
  prim('compte', const Arity.fixed(1), (c) => LogoNumber(_elements(c[0]).length), cat: _cat, doc: 'nombre d\'éléments'),
  prim(
    'mot',
    const Arity(0, 2, -1),
    (c) {
      final buf = StringBuffer();
      for (var i = 0; i < c.count; i++) {
        buf.write(c.word(i).text);
      }
      return LogoWord(buf.toString());
    },
    cat: _cat,
    doc: 'mot "a "b — colle des mots',
  ),
  prim(
    'liste',
    const Arity(0, 2, -1),
    (c) => LogoList(List.of(c.args)),
    cat: _cat,
    doc: 'liste a b — liste formée des entrées',
  ),
  prim(
    'phrase ph',
    const Arity(0, 2, -1),
    (c) {
      final out = <LogoValue>[];
      for (final a in c.args) {
        if (a is LogoList) {
          out.addAll(a.items);
        } else {
          out.add(a);
        }
      }
      return LogoList(out);
    },
    cat: _cat,
    doc: 'phrase a b — met bout à bout (listes aplaties d\'un niveau)',
  ),
  prim(
    'metspremier mp',
    const Arity.fixed(2),
    (c) {
      final l = c[1];
      if (l is LogoWord) return LogoWord(c.word(0).text + l.text);
      return LogoList([c[0], ...(l as LogoList).items]);
    },
    cat: _cat,
    doc: 'metspremier élément liste',
  ),
  prim(
    'metsdernier md',
    const Arity.fixed(2),
    (c) {
      final l = c[1];
      if (l is LogoWord) return LogoWord(l.text + c.word(0).text);
      return LogoList([...(l as LogoList).items, c[0]]);
    },
    cat: _cat,
    doc: 'metsdernier élément liste',
  ),
  prim(
    'inverse',
    const Arity.fixed(1),
    (c) => _rebuild(c[0], _elements(c[0]).reversed.toList()),
    cat: _cat,
    doc: 'inverse l\'ordre des éléments',
  ),
  prim(
    'majuscule',
    const Arity.fixed(1),
    (c) => LogoWord(c.word(0).text.toUpperCase()),
    cat: _cat,
    doc: 'mot en majuscules',
  ),
  prim(
    'minuscule',
    const Arity.fixed(1),
    (c) => LogoWord(c.word(0).text.toLowerCase()),
    cat: _cat,
    doc: 'mot en minuscules',
  ),
  prim(
    'choix',
    const Arity.fixed(1),
    (c) {
      _nonEmpty(c, 0);
      final e = _elements(c[0]);
      return e[c.ip.random.nextInt(e.length)];
    },
    cat: _cat,
    doc: 'élément pris au hasard',
  ),

  // Prédicats
  prim('mot?', const Arity.fixed(1), (c) => logoBool(c[0] is LogoWord), cat: _catPred, doc: 'vrai si mot'),
  prim('liste?', const Arity.fixed(1), (c) => logoBool(c[0] is LogoList), cat: _catPred, doc: 'vrai si liste'),
  prim(
    'nombre?',
    const Arity.fixed(1),
    (c) {
      final v = c[0];
      return logoBool(v is LogoWord && v.asNumber != null);
    },
    cat: _catPred,
    doc: 'vrai si nombre',
  ),
  prim(
    'vide?',
    const Arity.fixed(1),
    (c) {
      final v = c[0];
      return logoBool(v is LogoList ? v.isEmpty : (v as LogoWord).text.isEmpty);
    },
    cat: _catPred,
    doc: 'vrai si mot vide ou liste vide',
  ),
  prim(
    'membre?',
    const Arity.fixed(2),
    (c) {
      final x = c[0];
      return logoBool(_elements(c[1]).any((e) => logoEquals(e, x)));
    },
    cat: _catPred,
    doc: 'membre? élément liste',
  ),
  prim(
    'avant? precede?',
    const Arity.fixed(2),
    (c) => logoBool(c.word(0).text.compareTo(c.word(1).text) < 0),
    cat: _catPred,
    doc: 'avant? "a "b — ordre alphabétique',
  ),
];

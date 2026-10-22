import '../errors.dart';
import '../interpreter.dart';
import '../parser.dart';
import '../reader.dart';
import '../values.dart';
import 'util.dart';

const _cat = 'Contrôle';
const _catVar = 'Variables';
const _catProc = 'Procédures';

/// Une condition peut être une valeur ou une liste à évaluer.
Future<bool> _condition(PrimCall c, int i) async {
  final v = c[i];
  final LogoValue r = v is LogoList ? await c.ip.evalListValue(v, c.name) : v;
  final b = asLogoBool(r);
  if (b == null) {
    throw LogoError('« ${c.name} » attend vrai ou faux, pas « ${r.show()} »', c.node.pos);
  }
  return b;
}

/// Une liste d'instructions, ou un mot à lire comme du code.
LogoList _instructions(PrimCall c, int i) {
  final v = c[i];
  if (v is LogoList) return v;
  return Reader.readList((v as LogoWord).text);
}

List<Primitive> controlPrimitives() => [
  prim(
    'repete',
    const Arity.fixed(2),
    (c) async {
      final n = c.integer(0);
      final body = c.list(1);
      c.ip.pushRepcount(0);
      try {
        for (var i = 1; i <= n; i++) {
          c.ip.setRepcount(i);
          final t = c.ip.tick();
          if (t != null) await t;
          await c.ip.runList(body);
        }
      } finally {
        c.ip.popRepcount();
      }
      return null;
    },
    cat: _cat,
    doc: 'repete n [instructions] — répète n fois les instructions',
  ),
  prim(
    'compteur',
    const Arity.fixed(0),
    (c) => LogoNumber(c.ip.repcount),
    cat: _cat,
    doc: 'numéro du tour en cours dans le « repete » le plus proche',
  ),
  prim(
    'repetepour',
    const Arity.fixed(2),
    (c) async {
      final spec = c.list(0);
      final body = c.list(1);
      if (spec.length < 3 || spec.items.first is! LogoWord) throw c.badArg(0);
      final varName = (spec.items.first as LogoWord).text.toLowerCase();
      final exprs = Parser.parseList(LogoList(spec.items.sublist(1), spec.pos), c.ip.arityOf);
      if (exprs.length < 2 || exprs.length > 3) throw c.badArg(0);
      final nums = <num>[];
      for (final e in exprs) {
        final v = await c.ip.eval(e);
        final n = v is LogoWord ? v.asNumber : null;
        if (n == null) throw c.badArg(0);
        nums.add(n);
      }
      final from = nums[0], to = nums[1];
      final step = nums.length == 3 ? nums[2] : (to >= from ? 1 : -1);
      if (step == 0) throw LogoError('Le pas de « repetepour » ne peut pas être nul', c.node.pos);
      await c.ip.withFrame((f) async {
        for (var x = from; step > 0 ? x <= to + 1e-9 : x >= to - 1e-9; x += step) {
          f.vars[varName] = LogoNumber(x);
          final t = c.ip.tick();
          if (t != null) await t;
          await c.ip.runList(body);
        }
      });
      return null;
    },
    cat: _cat,
    doc: 'repetepour [i début fin pas] [instructions] — boucle avec compteur',
  ),
  prim(
    'tantque',
    const Arity.fixed(2),
    (c) async {
      final body = c.list(1);
      while (await _condition(c, 0)) {
        final t = c.ip.tick();
        if (t != null) await t;
        await c.ip.runList(body);
      }
      return null;
    },
    cat: _cat,
    doc: 'tantque [condition] [instructions]',
  ),
  prim(
    'jusqua',
    const Arity.fixed(2),
    (c) async {
      final body = c.list(1);
      while (!await _condition(c, 0)) {
        final t = c.ip.tick();
        if (t != null) await t;
        await c.ip.runList(body);
      }
      return null;
    },
    cat: _cat,
    doc: 'jusqua [condition] [instructions] — répète jusqu\'à ce que la condition soit vraie',
  ),
  prim(
    'si',
    const Arity(2, 2, 3),
    (c) async {
      if (await _condition(c, 0)) return await c.ip.runList(c.list(1), allowValue: true);
      if (c.count == 3) return await c.ip.runList(c.list(2), allowValue: true);
      return null;
    },
    cat: _cat,
    doc: 'si condition [instructions]  ou  (si condition [alors] [sinon])',
  ),
  prim(
    'sisinon',
    const Arity.fixed(3),
    (c) async {
      final b = await _condition(c, 0);
      return await c.ip.runList(c.list(b ? 1 : 2), allowValue: true);
    },
    cat: _cat,
    doc: 'sisinon condition [si vrai] [si faux]',
  ),
  prim(
    'exec execute',
    const Arity.fixed(1),
    (c) => c.ip.runList(_instructions(c, 0), allowValue: true),
    cat: _cat,
    doc: 'exec [instructions] — exécute une liste',
  ),
  prim(
    'stop',
    const Arity.fixed(0),
    (c) => Error.throwWithStackTrace(const StopSignal(), StackTrace.empty),
    cat: _cat,
    doc: 'termine la procédure en cours',
  ),
  prim(
    'retourne rends',
    const Arity.fixed(1),
    (c) => Error.throwWithStackTrace(OutputSignal(c[0]), StackTrace.empty),
    cat: _cat,
    doc: 'retourne valeur — termine la procédure en renvoyant une valeur',
  ),
  prim(
    'attends',
    const Arity.fixed(1),
    (c) async {
      await c.ip.sleep(Duration(microseconds: (c.dbl(0) * 1e6 / 60).round()));
      return null;
    },
    cat: _cat,
    doc: 'attends n — pause de n soixantièmes de seconde',
  ),
  prim(
    'invoque',
    const Arity(1, 2, -1),
    (c) {
      return c.ip.invoke(c.word(0).text, c.args.sublist(1), c.node);
    },
    cat: _cat,
    doc: '(invoque "nom arg1 arg2 …) — appelle une procédure par son nom',
  ),
  prim(
    'applique',
    const Arity.fixed(2),
    (c) {
      return c.ip.invoke(c.word(0).text, c.list(1).items, c.node);
    },
    cat: _cat,
    doc: 'applique "nom [arguments]',
  ),
  prim(
    'erreur',
    const Arity.fixed(1),
    (c) => throw LogoError(c[0].print(), c.node.pos),
    cat: _cat,
    doc: 'erreur "message — déclenche une erreur',
  ),

  // Variables
  prim(
    'donne',
    const Arity.fixed(2),
    (c) {
      c.ip.setVariable(c.word(0).text.toLowerCase(), c[1]);
      return null;
    },
    cat: _catVar,
    doc: 'donne "nom valeur — affecte une variable',
  ),
  prim(
    'locale',
    const Arity(1, 1, -1),
    (c) {
      for (final a in c.args) {
        if (a is LogoList) {
          for (final w in a.items) {
            c.ip.makeLocal(w.print().toLowerCase());
          }
        } else {
          c.ip.makeLocal((a as LogoWord).text.toLowerCase());
        }
      }
      return null;
    },
    cat: _catVar,
    doc: 'locale "nom — déclare une variable locale',
  ),
  prim(
    'donnelocale',
    const Arity.fixed(2),
    (c) {
      c.ip.makeLocal(c.word(0).text.toLowerCase(), c[1]);
      return null;
    },
    cat: _catVar,
    doc: 'donnelocale "nom valeur',
  ),
  prim(
    'chose',
    const Arity.fixed(1),
    (c) => c.ip.lookup(c.word(0).text.toLowerCase(), c.node.pos),
    cat: _catVar,
    doc: 'chose "nom — valeur de la variable (comme :nom)',
  ),
  prim(
    'nom?',
    const Arity.fixed(1),
    (c) => logoBool(c.ip.hasValue(c.word(0).text.toLowerCase())),
    cat: _catVar,
    doc: 'nom? "x — vrai si la variable x a une valeur',
  ),

  // Procédures
  prim(
    'detaille',
    const Arity.fixed(1),
    (c) {
      final p = c.ip.procedures[c.word(0).text.toLowerCase()];
      if (p == null) throw LogoError('« ${c[0].print()} » n\'est pas une procédure définie', c.node.pos);
      c.ip.host.write('${p.source}\n');
      return null;
    },
    cat: _catProc,
    doc: 'detaille "nom — affiche la définition d\'une procédure',
  ),
  prim(
    'procedures',
    const Arity.fixed(0),
    (c) {
      final names = c.ip.procedures.values.map((p) => LogoWord(p.name)).toList();
      return LogoList(names);
    },
    cat: _catProc,
    doc: 'liste des procédures définies',
  ),
  prim(
    'primitive?',
    const Arity.fixed(1),
    (c) => logoBool(c.ip.primitives.containsKey(c.word(0).text.toLowerCase())),
    cat: _catProc,
    doc: 'primitive? "nom',
  ),
  prim(
    'procedure?',
    const Arity.fixed(1),
    (c) => logoBool(c.ip.procedures.containsKey(c.word(0).text.toLowerCase())),
    cat: _catProc,
    doc: 'procedure? "nom — vrai si définie avec « pour »',
  ),
  prim(
    'defini?',
    const Arity.fixed(1),
    (c) => logoBool(c.ip.arityOf(c.word(0).text.toLowerCase()) != null),
    cat: _catProc,
    doc: 'defini? "nom — primitive ou procédure',
  ),
];

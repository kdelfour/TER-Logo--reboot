import 'dart:math' as math;

import '../errors.dart';
import '../interpreter.dart';
import '../parser.dart';
import '../values.dart';
import 'util.dart';

const _cat = 'Calcul';
const _catLogic = 'Logique';

const _deg = math.pi / 180;

Primitive _unary(String names, num Function(num x) f, String doc) =>
    prim(names, const Arity.fixed(1), (c) => LogoNumber(f(c.number(0))), cat: _cat, doc: doc);

double _checkDomain(PrimCall c, double v) {
  if (v.isNaN) throw LogoError('« ${c.name} » n\'accepte pas « ${c[0].show()} »', c.node.pos);
  return v;
}

List<Primitive> mathPrimitives() => [
      prim('somme', const Arity(0, 2, -1), (c) {
        num s = 0;
        for (var i = 0; i < c.count; i++) {
          s += c.number(i);
        }
        return LogoNumber(s);
      }, cat: _cat, doc: 'somme a b  ou  (somme a b c …)'),
      prim('difference', const Arity.fixed(2), (c) => LogoNumber(c.number(0) - c.number(1)),
          cat: _cat, doc: 'difference a b — a − b'),
      prim('produit', const Arity(0, 2, -1), (c) {
        num p = 1;
        for (var i = 0; i < c.count; i++) {
          p *= c.number(i);
        }
        return LogoNumber(p);
      }, cat: _cat, doc: 'produit a b  ou  (produit a b c …)'),
      prim('quotient', const Arity.fixed(2), (c) {
        final b = c.number(1);
        if (b == 0) throw LogoError('Division par zéro', c.node.pos);
        return LogoNumber(c.number(0) / b);
      }, cat: _cat, doc: 'quotient a b — a ÷ b'),
      prim('reste', const Arity.fixed(2), (c) {
        final a = c.number(0), b = c.number(1);
        if (b == 0) throw LogoError('Division par zéro', c.node.pos);
        return LogoNumber(a.remainder(b));
      }, cat: _cat, doc: 'reste a b — reste de la division (signe de a)'),
      prim('modulo', const Arity.fixed(2), (c) {
        final a = c.number(0), b = c.number(1);
        if (b == 0) throw LogoError('Division par zéro', c.node.pos);
        final r = a % b;
        return LogoNumber(r != 0 && (r < 0) != (b < 0) ? r + b : r);
      }, cat: _cat, doc: 'modulo a b — reste du signe de b'),
      _unary('moins', (x) => -x, 'moins a — opposé de a'),
      _unary('abs', (x) => x.abs(), 'abs a — valeur absolue'),
      _unary('signe', (x) => x.sign, 'signe a — −1, 0 ou 1'),
      _unary('arrondi', (x) => x.round(), 'arrondi a — entier le plus proche'),
      _unary('tronque ent', (x) => x.truncate(), 'tronque a — partie entière'),
      prim('racine', const Arity.fixed(1), (c) => LogoNumber(_checkDomain(c, math.sqrt(c.number(0)))),
          cat: _cat, doc: 'racine a — racine carrée'),
      prim('puissance', const Arity.fixed(2), (c) => LogoNumber(_checkDomain(c, math.pow(c.number(0), c.number(1)).toDouble())),
          cat: _cat, doc: 'puissance a b — a à la puissance b'),
      prim('exp', const Arity.fixed(1), (c) => LogoNumber(math.exp(c.number(0))), cat: _cat, doc: 'exponentielle'),
      prim('ln log', const Arity.fixed(1), (c) => LogoNumber(_checkDomain(c, math.log(c.number(0)))),
          cat: _cat, doc: 'logarithme népérien'),
      prim('log10', const Arity.fixed(1), (c) => LogoNumber(_checkDomain(c, math.log(c.number(0)) / math.ln10)),
          cat: _cat, doc: 'logarithme décimal'),
      prim('sin', const Arity.fixed(1), (c) => LogoNumber(_clean(math.sin(c.number(0) * _deg))),
          cat: _cat, doc: 'sinus (angle en degrés)'),
      prim('cos', const Arity.fixed(1), (c) => LogoNumber(_clean(math.cos(c.number(0) * _deg))),
          cat: _cat, doc: 'cosinus (angle en degrés)'),
      prim('tan', const Arity.fixed(1), (c) => LogoNumber(_clean(math.tan(c.number(0) * _deg))),
          cat: _cat, doc: 'tangente (angle en degrés)'),
      prim('arcsin', const Arity.fixed(1), (c) => LogoNumber(_checkDomain(c, math.asin(c.number(0)) / _deg)),
          cat: _cat, doc: 'arc sinus, en degrés'),
      prim('arccos', const Arity.fixed(1), (c) => LogoNumber(_checkDomain(c, math.acos(c.number(0)) / _deg)),
          cat: _cat, doc: 'arc cosinus, en degrés'),
      prim('arctan', const Arity(1, 1, 2), (c) {
        if (c.count == 2) return LogoNumber(math.atan2(c.number(1), c.number(0)) / _deg);
        return LogoNumber(math.atan(c.number(0)) / _deg);
      }, cat: _cat, doc: 'arc tangente, en degrés'),
      prim('pi', const Arity.fixed(0), (c) => LogoNumber(math.pi), cat: _cat, doc: '3.14159…'),
      prim('hasard', const Arity(1, 1, 2), (c) {
        if (c.count == 2) {
          final a = c.integer(0), b = c.integer(1);
          if (b < a) throw c.badArg(1);
          return LogoNumber(a + c.ip.random.nextInt(b - a + 1));
        }
        final n = c.integer(0);
        if (n <= 0) throw c.badArg(0);
        return LogoNumber(c.ip.random.nextInt(n));
      }, cat: _cat, doc: 'hasard n — entier au hasard entre 0 et n−1'),
      prim('max', const Arity(1, 2, -1), (c) {
        var m = c.number(0);
        for (var i = 1; i < c.count; i++) {
          m = math.max(m, c.number(i));
        }
        return LogoNumber(m);
      }, cat: _cat, doc: 'le plus grand'),
      prim('min', const Arity(1, 2, -1), (c) {
        var m = c.number(0);
        for (var i = 1; i < c.count; i++) {
          m = math.min(m, c.number(i));
        }
        return LogoNumber(m);
      }, cat: _cat, doc: 'le plus petit'),

      // Comparaisons et logique
      prim('egal? egale?', const Arity.fixed(2), (c) => logoBool(logoEquals(c[0], c[1])),
          cat: _catLogic, doc: 'egal? a b'),
      prim('inegal?', const Arity.fixed(2), (c) => logoBool(!logoEquals(c[0], c[1])),
          cat: _catLogic, doc: 'inegal? a b'),
      prim('pluspetit? plp?', const Arity.fixed(2), (c) => logoBool(c.number(0) < c.number(1)),
          cat: _catLogic, doc: 'pluspetit? a b — a < b'),
      prim('plusgrand? plg?', const Arity.fixed(2), (c) => logoBool(c.number(0) > c.number(1)),
          cat: _catLogic, doc: 'plusgrand? a b — a > b'),
      prim('pluspetitou? plpo?', const Arity.fixed(2), (c) => logoBool(c.number(0) <= c.number(1)),
          cat: _catLogic, doc: 'pluspetitou? a b — a ≤ b'),
      prim('plusgrandou? plgo?', const Arity.fixed(2), (c) => logoBool(c.number(0) >= c.number(1)),
          cat: _catLogic, doc: 'plusgrandou? a b — a ≥ b'),
      prim('et', const Arity(0, 2, -1), (c) async {
        for (var i = 0; i < c.count; i++) {
          if (!await _bool(c, i)) return logoFalse;
        }
        return logoTrue;
      }, cat: _catLogic, doc: 'et a b  ou  (et a b c …)'),
      prim('ou', const Arity(0, 2, -1), (c) async {
        for (var i = 0; i < c.count; i++) {
          if (await _bool(c, i)) return logoTrue;
        }
        return logoFalse;
      }, cat: _catLogic, doc: 'ou a b  ou  (ou a b c …)'),
      prim('non', const Arity.fixed(1), (c) async => logoBool(!await _bool(c, 0)), cat: _catLogic, doc: 'non a'),
    ];

Future<bool> _bool(PrimCall c, int i) async {
  final v = c[i];
  final r = v is LogoList ? await c.ip.evalListValue(v, c.name) : v;
  final b = asLogoBool(r);
  if (b == null) throw LogoError('« ${c.name} » attend vrai ou faux, pas « ${r.show()} »', c.node.pos);
  return b;
}

/// Supprime le bruit d'arrondi (sin 180 = 1.2e-16 → 0).
double _clean(double v) => v.abs() < 1e-12 ? 0 : v;

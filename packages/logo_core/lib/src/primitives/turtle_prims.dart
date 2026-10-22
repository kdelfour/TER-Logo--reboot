import 'dart:async';
import 'dart:math' as math;

import '../errors.dart';
import '../interpreter.dart';
import '../parser.dart';
import '../turtle.dart';
import '../values.dart';
import 'util.dart';

const _cat = 'Tortue';
const _catPen = 'Crayon et couleurs';

const _rad = math.pi / 180;

double _round(double v) {
  final r = (v * 1e9).roundToDouble() / 1e9;
  return r == 0 ? 0 : r;
}

FutureOr<LogoValue?> _moveTo(Interpreter ip, double x, double y) {
  final t = ip.turtle;
  final x0 = t.x, y0 = t.y;
  t.x = _round(x);
  t.y = _round(y);
  return ip.emit(MoveEvent(x0, y0, t.x, t.y, t.penDown, t.style));
}

FutureOr<LogoValue?> _forward(Interpreter ip, double d) {
  final t = ip.turtle;
  final h = t.heading * _rad;
  return _moveTo(ip, t.x + d * math.sin(h), t.y + d * math.cos(h));
}

FutureOr<LogoValue?> _turnTo(Interpreter ip, double heading, double delta) {
  final t = ip.turtle;
  final from = t.heading;
  t.heading = normalizeHeading(heading);
  return ip.emit(TurnEvent(from, from + delta));
}

FutureOr<LogoValue?> _right(Interpreter ip, double a) => _turnTo(ip, ip.turtle.heading + a, a);

double _towards(TurtleState t, double x, double y) {
  final dx = x - t.x, dy = y - t.y;
  if (dx == 0 && dy == 0) return t.heading;
  return normalizeHeading(math.atan2(dx, dy) / _rad);
}

LogoValue _num(double v) => LogoNumber(_round(v));

List<Primitive> turtlePrimitives() => [
      prim('avance av', const Arity.fixed(1), (c) => _forward(c.ip, c.dbl(0)),
          cat: _cat, doc: 'avance n — avance de n pas'),
      prim('recule re', const Arity.fixed(1), (c) => _forward(c.ip, -c.dbl(0)),
          cat: _cat, doc: 'recule n — recule de n pas'),
      prim('tournedroite droite td dr', const Arity.fixed(1), (c) => _right(c.ip, c.dbl(0)),
          cat: _cat, doc: 'td angle — tourne à droite (degrés)'),
      prim('tournegauche gauche tg ga', const Arity.fixed(1), (c) => _right(c.ip, -c.dbl(0)),
          cat: _cat, doc: 'tg angle — tourne à gauche (degrés)'),
      prim('fixecap fcap', const Arity.fixed(1), (c) {
        final t = c.ip.turtle;
        final target = normalizeHeading(c.dbl(0));
        var delta = target - t.heading;
        if (delta > 180) delta -= 360;
        if (delta < -180) delta += 360;
        return _turnTo(c.ip, target, delta);
      }, cat: _cat, doc: 'fixecap angle — oriente la tortue (0 = vers le haut)'),
      prim('cap', const Arity.fixed(0), (c) => _num(c.ip.turtle.heading), cat: _cat, doc: 'orientation actuelle'),
      prim('fixepos fpos', const Arity.fixed(1), (c) {
        final (x, y) = c.point(0);
        return _moveTo(c.ip, x, y);
      }, cat: _cat, doc: 'fixepos [x y] — déplace la tortue'),
      prim('fixexy', const Arity.fixed(2), (c) => _moveTo(c.ip, c.dbl(0), c.dbl(1)),
          cat: _cat, doc: 'fixexy x y'),
      prim('fixex', const Arity.fixed(1), (c) => _moveTo(c.ip, c.dbl(0), c.ip.turtle.y), cat: _cat, doc: 'fixex x'),
      prim('fixey', const Arity.fixed(1), (c) => _moveTo(c.ip, c.ip.turtle.x, c.dbl(0)), cat: _cat, doc: 'fixey y'),
      prim('position pos', const Arity.fixed(0),
          (c) => LogoList([_num(c.ip.turtle.x), _num(c.ip.turtle.y)]),
          cat: _cat, doc: 'position [x y]'),
      prim('posx', const Arity.fixed(0), (c) => _num(c.ip.turtle.x), cat: _cat, doc: 'abscisse'),
      prim('posy', const Arity.fixed(0), (c) => _num(c.ip.turtle.y), cat: _cat, doc: 'ordonnée'),
      prim('vers', const Arity.fixed(1), (c) {
        final (x, y) = c.point(0);
        return _num(_towards(c.ip.turtle, x, y));
      }, cat: _cat, doc: 'vers [x y] — cap à prendre pour viser le point'),
      prim('distance', const Arity.fixed(1), (c) {
        final (x, y) = c.point(0);
        final t = c.ip.turtle;
        return _num(math.sqrt((x - t.x) * (x - t.x) + (y - t.y) * (y - t.y)));
      }, cat: _cat, doc: 'distance [x y] — distance au point'),
      prim('origine', const Arity.fixed(0), (c) {
        final r = _moveTo(c.ip, 0, 0);
        final t = c.ip.turtle;
        final from = t.heading;
        t.heading = 0;
        final turn = c.ip.emit(TurnEvent(from, from > 180 ? 360 : 0));
        if (r is Future || turn is Future) {
          return Future.wait([Future.value(r), Future.value(turn)]).then((_) => null);
        }
        return null;
      }, cat: _cat, doc: 'ramène la tortue au centre, tournée vers le haut'),
      prim('videecran ve', const Arity.fixed(0), (c) {
        final t = c.ip.turtle;
        t.x = 0;
        t.y = 0;
        t.heading = 0;
        return c.ip.emit(const ClearEvent(true));
      }, cat: _cat, doc: 'efface l\'écran et ramène la tortue au centre'),
      prim('nettoie', const Arity.fixed(0), (c) => c.ip.emit(const ClearEvent(false)),
          cat: _cat, doc: 'efface les dessins sans bouger la tortue'),
      prim('montretortue mt', const Arity.fixed(0), (c) {
        c.ip.turtle.visible = true;
        return c.ip.emit(const VisibilityEvent(true));
      }, cat: _cat, doc: 'montre la tortue'),
      prim('cachetortue ct', const Arity.fixed(0), (c) {
        c.ip.turtle.visible = false;
        return c.ip.emit(const VisibilityEvent(false));
      }, cat: _cat, doc: 'cache la tortue'),
      prim('visible?', const Arity.fixed(0), (c) => logoBool(c.ip.turtle.visible), cat: _cat, doc: 'tortue visible ?'),
      prim('cercle', const Arity.fixed(1), (c) {
        final t = c.ip.turtle;
        return c.ip.emit(ArcEvent(t.x, t.y, c.dbl(0).abs(), 0, 360, t.style));
      }, cat: _cat, doc: 'cercle r — cercle de rayon r centré sur la tortue'),
      prim('arc', const Arity.fixed(2), (c) {
        final t = c.ip.turtle;
        return c.ip.emit(ArcEvent(t.x, t.y, c.dbl(1).abs(), t.heading, c.dbl(0), t.style));
      }, cat: _cat, doc: 'arc angle r — arc centré sur la tortue, à partir de son cap'),
      prim('point', const Arity.fixed(1), (c) {
        final (x, y) = c.point(0);
        return c.ip.emit(DotEvent(x, y, c.ip.turtle.style));
      }, cat: _cat, doc: 'point [x y] — dessine un point'),
      prim('etiquette etiq', const Arity.fixed(1), (c) {
        final t = c.ip.turtle;
        return c.ip.emit(LabelEvent(t.x, t.y, t.heading, c[0].print(), t.penColor, t.fontSize));
      }, cat: _cat, doc: 'etiquette "texte — écrit à la position de la tortue'),
      prim('fixetaillepolice', const Arity.fixed(1), (c) {
        final s = c.dbl(0);
        if (s <= 0) throw c.badArg(0);
        c.ip.turtle.fontSize = s;
        return null;
      }, cat: _cat, doc: 'taille du texte des étiquettes'),
      prim('vitesse', const Arity.fixed(1), (c) {
        final v = c.integer(0);
        if (v < 0 || v > 500) {
          throw LogoError('« ${c.name} » attend une vitesse entre 0 (instantané) et 500', c.node.pos);
        }
        return c.ip.emit(SpeedEvent(v));
      }, cat: _cat, doc: 'vitesse n — de 1 (lent) à 500, 0 = instantané'),

      // Crayon
      prim('levecrayon lc', const Arity.fixed(0), (c) {
        c.ip.turtle.penDown = false;
        return null;
      }, cat: _catPen, doc: 'la tortue se déplace sans tracer'),
      prim('baissecrayon bc', const Arity.fixed(0), (c) {
        c.ip.turtle.penDown = true;
        return null;
      }, cat: _catPen, doc: 'la tortue trace en se déplaçant'),
      prim('baissecrayon? bc?', const Arity.fixed(0), (c) => logoBool(c.ip.turtle.penDown),
          cat: _catPen, doc: 'crayon baissé ?'),
      prim('gomme', const Arity.fixed(0), (c) {
        c.ip.turtle
          ..penDown = true
          ..mode = PenMode.erase;
        return null;
      }, cat: _catPen, doc: 'la tortue efface sur son passage'),
      prim('dessine', const Arity.fixed(0), (c) {
        c.ip.turtle
          ..penDown = true
          ..mode = PenMode.paint;
        return null;
      }, cat: _catPen, doc: 'revient au tracé normal après « gomme »'),
      prim('fixecouleurcrayon fcc', const Arity.fixed(1), (c) {
        c.ip.turtle.penColor = colorFromValue(c[0], c.name);
        return null;
      }, cat: _catPen, doc: 'fcc n, fcc "rouge ou fcc [r v b]'),
      prim('couleurcrayon cc', const Arity.fixed(0), (c) => colorToValue(c.ip.turtle.penColor),
          cat: _catPen, doc: 'couleur du crayon'),
      prim('fixecouleurfond fcfg fcf', const Arity.fixed(1), (c) {
        final col = colorFromValue(c[0], c.name);
        c.ip.turtle.background = col;
        return c.ip.emit(BackgroundEvent(col));
      }, cat: _catPen, doc: 'couleur du fond'),
      prim('couleurfond cf', const Arity.fixed(0), (c) => colorToValue(c.ip.turtle.background),
          cat: _catPen, doc: 'couleur du fond'),
      prim('fixetaillecrayon ftc fixeepais fepais', const Arity.fixed(1), (c) {
        final w = c.dbl(0);
        if (w < 0 || w > 100) throw c.badArg(0);
        c.ip.turtle.penWidth = w == 0 ? 1 : w;
        return null;
      }, cat: _catPen, doc: 'épaisseur du trait'),
      prim('taillecrayon epais', const Arity.fixed(0), (c) => _num(c.ip.turtle.penWidth),
          cat: _catPen, doc: 'épaisseur du trait'),
      prim('fixetrait ftrait', const Arity.fixed(1), (c) {
        final d = c.integer(0);
        if (d < 0) throw c.badArg(0);
        c.ip.turtle.dash = d % 4;
        return null;
      }, cat: _catPen, doc: 'type de trait : 0 plein, 1 tirets, 2 pointillés, 3 tiret-point'),
      prim('trait', const Arity.fixed(0), (c) => LogoNumber(c.ip.turtle.dash), cat: _catPen, doc: 'type de trait'),
    ];

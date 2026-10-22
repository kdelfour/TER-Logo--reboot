import 'dart:math' as math;

import 'errors.dart';
import 'values.dart';

/// Couleur ARGB 32 bits.
typedef Argb = int;

/// Palette historique (indices utilisés par `fcc`, `fcfg`…).
const List<Argb> logoPalette = [
  0xFF000000, // 0 noir
  0xFFFF0000, // 1 rouge
  0xFF00C000, // 2 vert
  0xFFFFD700, // 3 jaune
  0xFF0000FF, // 4 bleu
  0xFFFF00FF, // 5 magenta
  0xFF00CCFF, // 6 cyan
  0xFFFFFFFF, // 7 blanc
  0xFF808080, // 8 gris
  0xFFC0C0C0, // 9 gris clair
  0xFF800000, // 10 rouge foncé
  0xFF006400, // 11 vert foncé
  0xFF000080, // 12 bleu foncé
  0xFFFF8C00, // 13 orange
  0xFFFF69B4, // 14 rose
  0xFF800080, // 15 violet
  0xFF8B4513, // 16 marron
];

const Map<String, int> colorNames = {
  'noir': 0,
  'rouge': 1,
  'vert': 2,
  'jaune': 3,
  'bleu': 4,
  'magenta': 5,
  'cyan': 6,
  'blanc': 7,
  'gris': 8,
  'grisclair': 9,
  'rougefonce': 10,
  'vertfonce': 11,
  'bleufonce': 12,
  'orange': 13,
  'rose': 14,
  'violet': 15,
  'marron': 16,
};

enum PenMode { paint, erase }

/// Style de trait : couleur, épaisseur, mode et motif de pointillés.
class PenStyle {
  final Argb color;
  final double width;
  final PenMode mode;

  /// 0 plein, 1 tirets, 2 pointillés, 3 tiret-point.
  final int dash;

  const PenStyle(this.color, this.width, this.mode, this.dash);

  @override
  bool operator ==(Object other) =>
      other is PenStyle && other.color == color && other.width == width && other.mode == mode && other.dash == dash;

  @override
  int get hashCode => Object.hash(color, width, mode, dash);
}

/// Événements produits par la tortue, consommés par l'affichage.
sealed class TurtleEvent {
  const TurtleEvent();
}

/// Déplacement de la tortue, tracé si [draw].
class MoveEvent extends TurtleEvent {
  final double x0, y0, x1, y1;
  final bool draw;
  final PenStyle style;
  const MoveEvent(this.x0, this.y0, this.x1, this.y1, this.draw, this.style);
  double get length => math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
}

class TurnEvent extends TurtleEvent {
  final double from, to;
  const TurnEvent(this.from, this.to);
}

/// Arc de cercle centré en ([cx], [cy]). Les angles suivent la convention
/// Logo : 0 vers le haut, sens horaire, en degrés.
class ArcEvent extends TurtleEvent {
  final double cx, cy, radius, start, sweep;
  final PenStyle style;
  const ArcEvent(this.cx, this.cy, this.radius, this.start, this.sweep, this.style);
}

class DotEvent extends TurtleEvent {
  final double x, y;
  final PenStyle style;
  const DotEvent(this.x, this.y, this.style);
}

class LabelEvent extends TurtleEvent {
  final double x, y, heading;
  final String text;
  final Argb color;
  final double fontSize;
  const LabelEvent(this.x, this.y, this.heading, this.text, this.color, this.fontSize);
}

/// Efface les tracés. Si [resetTurtle], la tortue revient aussi à l'origine.
class ClearEvent extends TurtleEvent {
  final bool resetTurtle;
  const ClearEvent(this.resetTurtle);
}

class BackgroundEvent extends TurtleEvent {
  final Argb color;
  const BackgroundEvent(this.color);
}

class VisibilityEvent extends TurtleEvent {
  final bool visible;
  const VisibilityEvent(this.visible);
}

/// Vitesse d'animation demandée par le programme (1 à 500, 0 = instantané).
class SpeedEvent extends TurtleEvent {
  final int speed;
  const SpeedEvent(this.speed);
}

/// État de la tortue. Repère : origine au centre, y vers le haut,
/// cap 0 vers le haut et croissant dans le sens horaire.
class TurtleState {
  double x = 0, y = 0, heading = 0;
  bool penDown = true;
  bool visible = true;
  PenMode mode = PenMode.paint;
  Argb penColor = logoPalette[0];
  Argb background = logoPalette[7];
  double penWidth = 1;
  int dash = 0;
  double fontSize = 14;

  PenStyle get style => PenStyle(penColor, penWidth, mode, dash);

  void reset() {
    x = 0;
    y = 0;
    heading = 0;
    penDown = true;
    visible = true;
    mode = PenMode.paint;
    penColor = logoPalette[0];
    background = logoPalette[7];
    penWidth = 1;
    dash = 0;
    fontSize = 14;
  }
}

double normalizeHeading(double h) {
  var r = h % 360;
  if (r < 0) r += 360;
  // Évite les -0.0 et les 359.99999999 dus aux arrondis.
  if ((r - 360).abs() < 1e-9) r = 0;
  return r;
}

/// Convertit une valeur Logo en couleur : indice de palette, nom, ou
/// liste [r v b] (0 à 255).
Argb colorFromValue(LogoValue v, String procName) {
  if (v is LogoWord) {
    final n = v.asNumber;
    if (n != null) {
      final i = n.round();
      if (i < 0) throw LogoError('« $procName » n\'aime pas « ${v.text} » comme couleur');
      return logoPalette[i % logoPalette.length];
    }
    final idx = colorNames[_stripAccents(v.text.toLowerCase())];
    if (idx != null) return logoPalette[idx];
  }
  if (v is LogoList && v.length == 3) {
    final c = <int>[];
    for (final e in v.items) {
      final n = e is LogoWord ? e.asNumber : null;
      if (n == null) break;
      c.add(n.round().clamp(0, 255));
    }
    if (c.length == 3) return 0xFF000000 | (c[0] << 16) | (c[1] << 8) | c[2];
  }
  throw LogoError('« $procName » n\'aime pas « ${v.show()} » comme couleur');
}

/// Renvoie l'indice de palette si la couleur en fait partie, sinon [r v b].
LogoValue colorToValue(Argb c) {
  final i = logoPalette.indexOf(c);
  if (i >= 0) return LogoNumber(i);
  return LogoList([
    LogoNumber((c >> 16) & 0xFF),
    LogoNumber((c >> 8) & 0xFF),
    LogoNumber(c & 0xFF),
  ]);
}

String _stripAccents(String s) => s
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll(' ', '');

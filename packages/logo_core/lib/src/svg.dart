import 'dart:async';
import 'dart:math' as math;

import 'interpreter.dart';
import 'turtle.dart';

/// Hôte sans interface : accumule la sortie texte et les tracés, et sait
/// produire une image SVG. Sert à la ligne de commande et aux tests.
class RecordingHost implements LogoHost {
  final StringBuffer output = StringBuffer();
  final List<TurtleEvent> events = [];
  final List<String> inputs;

  RecordingHost({List<String>? inputs}) : inputs = inputs ?? [];

  @override
  void write(String text) => output.write(text);

  @override
  Future<String?> readLine(String prompt) async => inputs.isEmpty ? null : inputs.removeAt(0);

  @override
  FutureOr<void> onTurtle(TurtleEvent event) {
    events.add(event);
  }

  /// Événements visibles depuis le dernier effacement.
  List<TurtleEvent> get visibleEvents {
    final i = events.lastIndexWhere((e) => e is ClearEvent);
    return events.sublist(i + 1);
  }

  int get drawnSegments => visibleEvents.whereType<MoveEvent>().where((e) => e.draw).length;

  String toSvg({double margin = 20}) {
    var bg = logoPalette[7];
    for (final e in events) {
      if (e is BackgroundEvent) bg = e.color;
    }
    final shapes = <String>[];
    var minX = -1.0, minY = -1.0, maxX = 1.0, maxY = 1.0;
    void grow(double x, double y, [double r = 0]) {
      minX = math.min(minX, x - r);
      maxX = math.max(maxX, x + r);
      minY = math.min(minY, -y - r);
      maxY = math.max(maxY, -y + r);
    }

    String stroke(PenStyle s) {
      final col = s.mode == PenMode.erase ? bg : s.color;
      final dash = switch (s.dash) {
        1 => ' stroke-dasharray="${_f(8 * s.width)} ${_f(4 * s.width)}"',
        2 => ' stroke-dasharray="${_f(1.5 * s.width)} ${_f(3 * s.width)}"',
        3 => ' stroke-dasharray="${_f(8 * s.width)} ${_f(3 * s.width)} ${_f(1.5 * s.width)} ${_f(3 * s.width)}"',
        _ => '',
      };
      return 'stroke="${_hex(col)}" stroke-width="${_f(s.width)}"$dash';
    }

    for (final e in visibleEvents) {
      switch (e) {
        case MoveEvent(draw: true):
          grow(e.x0, e.y0);
          grow(e.x1, e.y1);
          shapes.add(
            '<line x1="${_f(e.x0)}" y1="${_f(-e.y0)}" x2="${_f(e.x1)}" y2="${_f(-e.y1)}" '
            '${stroke(e.style)} stroke-linecap="round"/>',
          );
        case ArcEvent():
          grow(e.cx, e.cy, e.radius);
          if (e.sweep.abs() >= 360) {
            shapes.add(
              '<circle cx="${_f(e.cx)}" cy="${_f(-e.cy)}" r="${_f(e.radius)}" fill="none" ${stroke(e.style)}/>',
            );
          } else {
            (double, double) at(double a) {
              final r = a * math.pi / 180;
              return (e.cx + e.radius * math.sin(r), -(e.cy + e.radius * math.cos(r)));
            }

            final (sx, sy) = at(e.start);
            final (ex, ey) = at(e.start + e.sweep);
            final large = e.sweep.abs() > 180 ? 1 : 0;
            final sweep = e.sweep > 0 ? 1 : 0;
            shapes.add(
              '<path d="M ${_f(sx)} ${_f(sy)} A ${_f(e.radius)} ${_f(e.radius)} 0 $large $sweep '
              '${_f(ex)} ${_f(ey)}" fill="none" ${stroke(e.style)}/>',
            );
          }
        case DotEvent():
          grow(e.x, e.y, e.style.width);
          shapes.add(
            '<circle cx="${_f(e.x)}" cy="${_f(-e.y)}" r="${_f(math.max(1, e.style.width / 2))}" '
            'fill="${_hex(e.style.color)}"/>',
          );
        case LabelEvent():
          grow(e.x, e.y);
          grow(e.x + e.fontSize * e.text.length * 0.6, e.y + e.fontSize);
          shapes.add(
            '<text x="${_f(e.x)}" y="${_f(-e.y)}" font-family="sans-serif" font-size="${_f(e.fontSize)}" '
            'fill="${_hex(e.color)}">${_escape(e.text)}</text>',
          );
        default:
          break;
      }
    }
    final w = maxX - minX + 2 * margin, h = maxY - minY + 2 * margin;
    final buf = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${_f(minX - margin)} ${_f(minY - margin)} '
        '${_f(w)} ${_f(h)}" width="${_f(w)}" height="${_f(h)}">',
      )
      ..writeln(
        '<rect x="${_f(minX - margin)}" y="${_f(minY - margin)}" width="${_f(w)}" height="${_f(h)}" '
        'fill="${_hex(bg)}"/>',
      );
    for (final s in shapes) {
      buf.writeln(s);
    }
    buf.writeln('</svg>');
    return buf.toString();
  }
}

String _f(double v) {
  final r = (v * 100).roundToDouble() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toString();
}

String _hex(Argb c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

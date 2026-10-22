import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../state/canvas_controller.dart';

/// Position et zoom de la vue sur le dessin.
class CanvasViewport extends ChangeNotifier {
  Offset pan = Offset.zero;
  double zoom = 1;

  /// Coordonnées Logo sous le pointeur.
  Offset? pointer;

  static const minZoom = 0.05, maxZoom = 40.0;

  Offset worldToScreen(Offset w, Size size) =>
      Offset(size.width / 2 + pan.dx + w.dx * zoom, size.height / 2 + pan.dy - w.dy * zoom);

  Offset screenToWorld(Offset s, Size size) =>
      Offset((s.dx - size.width / 2 - pan.dx) / zoom, -(s.dy - size.height / 2 - pan.dy) / zoom);

  void zoomAt(double factor, Offset focus, Size size) {
    final before = screenToWorld(focus, size);
    zoom = (zoom * factor).clamp(minZoom, maxZoom);
    final after = worldToScreen(before, size);
    pan += focus - after;
    notifyListeners();
  }

  void zoomBy(double factor, Size size) => zoomAt(factor, size.center(Offset.zero), size);

  void reset() {
    pan = Offset.zero;
    zoom = 1;
    notifyListeners();
  }

  /// Cadre le dessin entier dans la vue.
  void fit(Rect? bounds, Size size) {
    if (bounds == null || bounds.isEmpty) return reset();
    final r = bounds.inflate(20);
    zoom = math.min(size.width / r.width, size.height / r.height).clamp(minZoom, maxZoom);
    pan = Offset(-r.center.dx * zoom, r.center.dy * zoom);
    notifyListeners();
  }

  void setPointer(Offset? w) {
    pointer = w;
    notifyListeners();
  }
}

class CanvasView extends StatefulWidget {
  final CanvasController controller;
  final CanvasViewport viewport;
  final bool showGrid;

  const CanvasView({super.key, required this.controller, required this.viewport, required this.showGrid});

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  Size _size = Size.zero;

  @override
  Widget build(BuildContext context) {
    final vp = widget.viewport;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (e) => vp.setPointer(vp.screenToWorld(e.localPosition, _size)),
          onExit: (_) => vp.setPointer(null),
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                vp.zoomAt(math.pow(1.0015, -e.scrollDelta.dy).toDouble(), e.localPosition, _size);
              }
            },
            child: GestureDetector(
              onPanUpdate: (d) {
                vp.pan += d.delta;
                vp.setPointer(vp.screenToWorld(d.localPosition, _size));
              },
              onDoubleTap: () => vp.fit(widget.controller.bounds, _size),
              child: ClipRect(
                child: CustomPaint(
                  painter: _DrawingPainter(widget.controller, vp, widget.showGrid, Theme.of(context).brightness),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final CanvasController c;
  final CanvasViewport vp;
  final bool grid;
  final Brightness brightness;

  _DrawingPainter(this.c, this.vp, this.grid, this.brightness) : super(repaint: Listenable.merge([c, vp]));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.background);
    if (grid) _paintGrid(canvas, size);

    canvas.save();
    canvas.translate(size.width / 2 + vp.pan.dx, size.height / 2 + vp.pan.dy);
    canvas.scale(vp.zoom, -vp.zoom);
    c.paintDrawing(canvas, vp.zoom);
    canvas.restore();

    if (c.turtleVisible) {
      final (x, y, h) = c.animatedPose;
      final pos = vp.worldToScreen(Offset(x, y), size);
      paintTurtle(canvas, pos, h, (18 * math.sqrt(vp.zoom)).clamp(10, 40));
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    // Le quadrillage du TER : un carreau = 10 pas.
    final lum = c.background.computeLuminance();
    final ink = lum > 0.5 ? Colors.black : Colors.white;
    var step = 10.0;
    while (step * vp.zoom < 8) {
      step *= 5;
    }
    final minor = Paint()
      ..color = ink.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = ink.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = ink.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final tl = vp.screenToWorld(Offset.zero, size);
    final br = vp.screenToWorld(Offset(size.width, size.height), size);
    for (var x = (tl.dx / step).floor() * step; x <= br.dx; x += step) {
      final sx = vp.worldToScreen(Offset(x, 0), size).dx.roundToDouble() + 0.5;
      final p = x.abs() < 1e-9
          ? axis
          : ((x / (step * 5)).round() * step * 5 - x).abs() < 1e-9
          ? major
          : minor;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), p);
    }
    for (var y = (br.dy / step).floor() * step; y <= tl.dy; y += step) {
      final sy = vp.worldToScreen(Offset(0, y), size).dy.roundToDouble() + 0.5;
      final p = y.abs() < 1e-9
          ? axis
          : ((y / (step * 5)).round() * step * 5 - y).abs() < 1e-9
          ? major
          : minor;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), p);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => old.grid != grid || old.brightness != brightness;
}

/// La tortue, vue de dessus, la tête dans la direction du cap.
void paintTurtle(Canvas canvas, Offset pos, double heading, double size) {
  canvas.save();
  canvas.translate(pos.dx, pos.dy);
  canvas.rotate(heading * math.pi / 180);
  final s = size / 20;
  canvas.scale(s);

  final skin = Paint()..color = const Color(0xFF7BC043);
  final skinDark = Paint()..color = const Color(0xFF4E8A2A);
  final shell = Paint()..color = const Color(0xFF2E7D32);
  final shellLight = Paint()..color = const Color(0xFF66BB6A);
  final outline = Paint()
    ..color = const Color(0xFF1B3D1D)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  // Ombre.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(1.5, 2), width: 22, height: 26),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );

  // Pattes et queue.
  for (final (dx, dy) in [(-9.0, -6.0), (9.0, -6.0), (-8.0, 7.0), (8.0, 7.0)]) {
    canvas.drawOval(Rect.fromCenter(center: Offset(dx, dy), width: 7, height: 5.5), skin);
    canvas.drawOval(Rect.fromCenter(center: Offset(dx, dy), width: 7, height: 5.5), outline);
  }
  final tail = Path()
    ..moveTo(-2, 11)
    ..lineTo(0, 15)
    ..lineTo(2, 11)
    ..close();
  canvas.drawPath(tail, skinDark);

  // Tête.
  canvas.drawOval(Rect.fromCenter(center: const Offset(0, -13), width: 8.5, height: 9), skin);
  canvas.drawOval(Rect.fromCenter(center: const Offset(0, -13), width: 8.5, height: 9), outline);
  final eye = Paint()..color = const Color(0xFF1B1B1B);
  canvas.drawCircle(const Offset(-2.2, -14.5), 1.1, eye);
  canvas.drawCircle(const Offset(2.2, -14.5), 1.1, eye);

  // Carapace.
  final shellRect = Rect.fromCenter(center: const Offset(0, 0.5), width: 17, height: 21);
  canvas.drawOval(shellRect, shell);
  final hex = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 3 * i + math.pi / 6;
    final pt = Offset(math.cos(a) * 4.2, 0.5 + math.sin(a) * 4.8);
    i == 0 ? hex.moveTo(pt.dx, pt.dy) : hex.lineTo(pt.dx, pt.dy);
  }
  hex.close();
  canvas.drawPath(hex, shellLight);
  final seams = Paint()
    ..color = const Color(0xFF1B5E20)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;
  canvas.drawPath(hex, seams);
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 3 * i + math.pi / 6;
    canvas.drawLine(
      Offset(math.cos(a) * 4.2, 0.5 + math.sin(a) * 4.8),
      Offset(math.cos(a) * 8.2, 0.5 + math.sin(a) * 10.2),
      seams,
    );
  }
  canvas.drawOval(shellRect, outline);

  // Petit reflet.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(-3, -4), width: 4, height: 2.5),
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
  canvas.restore();
}

/// Rend le dessin seul (sans quadrillage ni tortue) en image, cadré sur
/// la boîte englobante, pour l'export PNG.
Future<ui.Image> renderDrawingImage(CanvasController c, {double pixelRatio = 2}) async {
  final b = (c.bounds ?? const Rect.fromLTWH(-100, -100, 200, 200)).inflate(20);
  final w = (b.width * pixelRatio).ceil(), h = (b.height * pixelRatio).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c.background);
  canvas.scale(pixelRatio, -pixelRatio);
  canvas.translate(-b.left, -b.bottom);
  c.paintDrawing(canvas, pixelRatio);
  return rec.endRecording().toImage(w, h);
}

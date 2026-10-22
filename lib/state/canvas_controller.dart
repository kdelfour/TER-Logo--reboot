import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:logo_core/logo_core.dart';

/// Élément de la file d'animation : un événement tortue ou une action
/// différée (texte de la console à afficher au bon moment).
sealed class _Item {}

class _EventItem extends _Item {
  final TurtleEvent event;
  _EventItem(this.event);
}

class _ActionItem extends _Item {
  final VoidCallback action;
  _ActionItem(this.action);
}

/// Reçoit les événements de la tortue, les anime à la vitesse choisie et
/// conserve le dessin. Les tracés terminés sont regroupés en `ui.Picture`
/// pour que l'affichage reste fluide même avec des dizaines de milliers de
/// segments.
class CanvasController extends ChangeNotifier {
  static const _maxQueue = 4000;
  static const _bakeEvery = 800;

  Color background = const Color(0xFFFFFFFF);

  // Tracés terminés.
  final List<ui.Picture> _baked = [];
  final List<TurtleEvent> _pending = [];

  /// Tracés depuis le dernier effacement, pour l'export SVG.
  final List<TurtleEvent> history = [];

  // Pose affichée de la tortue.
  double turtleX = 0, turtleY = 0, turtleHeading = 0;
  bool turtleVisible = true;

  /// Boîte englobante des tracés (repère Logo).
  Rect? bounds;

  // Animation.
  final Queue<_Item> _queue = Queue();
  _EventItem? _active;
  double _activeProgress = 0;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _paused = false;
  Completer<void>? _roomInQueue;
  Completer<void>? _idle;

  /// Vitesse : 0 = instantané, 1 (lent) à 500 (rapide).
  int _speed = 100;
  int get speed => _speed;
  set speed(int v) {
    _speed = v.clamp(0, 500);
    if (_speed == 0) _drainAll();
    notifyListeners();
  }

  int _version = 0;

  /// Change à chaque modification du dessin (pour repeindre).
  int get version => _version;

  bool get isAnimating => _active != null || _queue.isNotEmpty;

  @override
  void dispose() {
    _ticker?.dispose();
    for (final p in _baked) {
      p.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Entrée : événements de l'interpréteur
  // -------------------------------------------------------------------------

  FutureOr<void> push(TurtleEvent e) {
    if (_speed == 0 && !isAnimating) {
      _apply(e);
      _changed();
      return null;
    }
    _queue.add(_EventItem(e));
    _ensureTicker();
    if (_queue.length >= _maxQueue) {
      _roomInQueue ??= Completer<void>();
      return _roomInQueue!.future;
    }
    return null;
  }

  /// Exécute [action] quand l'animation aura rattrapé ce point.
  void pushAction(VoidCallback action) {
    if (!isAnimating) {
      action();
    } else {
      _queue.add(_ActionItem(action));
    }
  }

  /// Termine quand toute la file a été animée.
  Future<void> whenIdle() {
    if (!isAnimating) return Future.value();
    _idle ??= Completer<void>();
    return _idle!.future;
  }

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _lastTick = Duration.zero;
    if (isAnimating) _ensureTicker();
  }

  /// Applique immédiatement tout ce qui reste dans la file (bouton Stop).
  void finishNow() => _drainAll();

  // -------------------------------------------------------------------------
  // Animation
  // -------------------------------------------------------------------------

  void _ensureTicker() {
    _ticker ??= Ticker(_onTick, debugLabel: 'tortue');
    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
  }

  // Échelle non linéaire : fine aux basses vitesses, très rapide en haut
  // (1 → 8 pas/s, 100 → ~3 200 pas/s, 500 → ~26 000 pas/s).
  double get _pixelsPerSecond => 8.0 * math.pow(_speed, 1.3);
  double get _degreesPerSecond => 30.0 * math.pow(_speed, 1.3);

  double _durationOf(TurtleEvent e) {
    if (_speed == 0) return 0;
    return switch (e) {
      MoveEvent() => e.length / _pixelsPerSecond,
      TurnEvent() => _turnDelta(e).abs() / _degreesPerSecond,
      ArcEvent() => (e.radius * e.sweep.abs() * math.pi / 180) / _pixelsPerSecond,
      _ => 0,
    };
  }

  void _onTick(Duration elapsed) {
    if (_paused) {
      _lastTick = elapsed;
      return;
    }
    var dt = _lastTick == Duration.zero ? 1 / 60 : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    dt = dt.clamp(0, 0.1);
    var budget = _speed == 0 ? double.infinity : dt;
    final sw = Stopwatch()..start();

    while (budget > 0 && sw.elapsedMilliseconds < 12) {
      if (_active == null) {
        if (_queue.isEmpty) break;
        final item = _queue.removeFirst();
        if (item is _ActionItem) {
          item.action();
          continue;
        }
        _active = item as _EventItem;
        _activeProgress = 0;
      }
      final total = _durationOf(_active!.event);
      final remaining = total * (1 - _activeProgress);
      if (remaining <= budget) {
        budget -= remaining;
        _apply(_active!.event);
        _active = null;
      } else {
        _activeProgress += budget / total;
        budget = 0;
      }
    }
    _releaseBackpressure();
    if (!isAnimating) {
      _ticker?.stop();
      _idle?.complete();
      _idle = null;
    }
    _changed();
  }

  void _releaseBackpressure() {
    if (_roomInQueue != null && _queue.length < _maxQueue ~/ 2) {
      _roomInQueue!.complete();
      _roomInQueue = null;
    }
  }

  void _drainAll() {
    if (_active != null) {
      _apply(_active!.event);
      _active = null;
    }
    while (_queue.isNotEmpty) {
      final item = _queue.removeFirst();
      switch (item) {
        case _EventItem():
          _apply(item.event);
        case _ActionItem():
          item.action();
      }
    }
    _releaseBackpressure();
    _ticker?.stop();
    _idle?.complete();
    _idle = null;
    _changed();
  }

  void _changed() {
    _version++;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Application des événements
  // -------------------------------------------------------------------------

  void _apply(TurtleEvent e) {
    switch (e) {
      case MoveEvent():
        turtleX = e.x1;
        turtleY = e.y1;
        if (e.draw) _addDrawing(e, Rect.fromPoints(Offset(e.x0, e.y0), Offset(e.x1, e.y1)).inflate(e.style.width));
      case TurnEvent():
        turtleHeading = normalizeHeading(e.to);
      case ArcEvent():
        _addDrawing(e, Rect.fromCircle(center: Offset(e.cx, e.cy), radius: e.radius + e.style.width));
      case DotEvent():
        _addDrawing(e, Rect.fromCircle(center: Offset(e.x, e.y), radius: e.style.width + 1));
      case LabelEvent():
        _addDrawing(e, Rect.fromLTWH(e.x, e.y, e.fontSize * e.text.length * 0.6, e.fontSize));
      case ClearEvent():
        _clearDrawing();
        if (e.resetTurtle) {
          turtleX = 0;
          turtleY = 0;
          turtleHeading = 0;
        }
      case BackgroundEvent():
        background = Color(e.color);
        history.add(e);
      case VisibilityEvent():
        turtleVisible = e.visible;
      case SpeedEvent():
        _speed = e.speed;
    }
  }

  void _addDrawing(TurtleEvent e, Rect r) {
    _pending.add(e);
    history.add(e);
    bounds = bounds == null ? r : bounds!.expandToInclude(r);
    if (_pending.length >= _bakeEvery) _bake();
  }

  void _bake() {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final e in _pending) {
      paintEvent(canvas, e, 1);
    }
    _pending.clear();
    _baked.add(rec.endRecording());
    if (_baked.length > 24) {
      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      for (final p in _baked) {
        c2.drawPicture(p);
        p.dispose();
      }
      _baked
        ..clear()
        ..add(rec2.endRecording());
    }
  }

  void _clearDrawing() {
    for (final p in _baked) {
      p.dispose();
    }
    _baked.clear();
    _pending.clear();
    history.removeWhere((e) => e is! BackgroundEvent);
    bounds = null;
  }

  /// Remet l'écran à zéro sans passer par l'interpréteur.
  void reset() {
    _queue.clear();
    _active = null;
    _clearDrawing();
    history.clear();
    background = const Color(0xFFFFFFFF);
    turtleX = 0;
    turtleY = 0;
    turtleHeading = 0;
    turtleVisible = true;
    _releaseBackpressure();
    _changed();
  }

  // -------------------------------------------------------------------------
  // Dessin (repère Logo : y vers le haut)
  // -------------------------------------------------------------------------

  /// Peint le dessin dans [canvas], déjà transformé dans le repère Logo.
  /// [scale] sert à garder des pointillés lisibles.
  void paintDrawing(Canvas canvas, double scale) {
    canvas.saveLayer(null, Paint());
    for (final p in _baked) {
      canvas.drawPicture(p);
    }
    for (final e in _pending) {
      paintEvent(canvas, e, scale);
    }
    final a = _active;
    if (a != null && _activeProgress > 0) {
      final e = a.event;
      if (e is MoveEvent && e.draw) {
        final t = _activeProgress;
        paintEvent(
          canvas,
          MoveEvent(e.x0, e.y0, e.x0 + (e.x1 - e.x0) * t, e.y0 + (e.y1 - e.y0) * t, true, e.style),
          scale,
        );
      } else if (e is ArcEvent) {
        paintEvent(canvas, ArcEvent(e.cx, e.cy, e.radius, e.start, e.sweep * _activeProgress, e.style), scale);
      }
    }
    canvas.restore();
  }

  /// Pose de la tortue en tenant compte de l'animation en cours.
  (double, double, double) get animatedPose {
    final a = _active;
    if (a == null) return (turtleX, turtleY, turtleHeading);
    final e = a.event;
    final t = _activeProgress;
    return switch (e) {
      MoveEvent() => (e.x0 + (e.x1 - e.x0) * t, e.y0 + (e.y1 - e.y0) * t, turtleHeading),
      TurnEvent() => (turtleX, turtleY, e.from + _turnDelta(e) * t),
      _ => (turtleX, turtleY, turtleHeading),
    };
  }
}

/// Rotation affichée : le plus court chemin (td 3000 tourne de 120°).
double _turnDelta(TurnEvent e) {
  var d = (e.to - e.from) % 360;
  if (d > 180) d -= 360;
  return d;
}

Paint _strokePaint(PenStyle s) => Paint()
  ..color = Color(s.color)
  ..strokeWidth = s.width
  ..style = PaintingStyle.stroke
  ..strokeCap = s.dash == 0 ? StrokeCap.round : StrokeCap.butt
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true
  ..blendMode = s.mode == PenMode.erase ? BlendMode.clear : BlendMode.srcOver;

List<double> _dashPattern(PenStyle s) {
  final w = math.max(1.0, s.width);
  return switch (s.dash) {
    1 => [8 * w, 4 * w],
    2 => [1.5 * w, 3 * w],
    3 => [8 * w, 3 * w, 1.5 * w, 3 * w],
    _ => const [],
  };
}

Path _dashed(Path source, List<double> pattern) {
  final out = Path();
  for (final m in source.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    var draw = true;
    while (d < m.length) {
      final len = pattern[i % pattern.length];
      if (draw) out.addPath(m.extractPath(d, math.min(d + len, m.length)), Offset.zero);
      d += len;
      draw = !draw;
      i++;
    }
  }
  return out;
}

/// Dessine un événement dans un canevas exprimé dans le repère Logo.
void paintEvent(Canvas canvas, TurtleEvent e, double scale) {
  switch (e) {
    case MoveEvent():
      final paint = _strokePaint(e.style);
      if (e.style.dash == 0) {
        canvas.drawLine(Offset(e.x0, e.y0), Offset(e.x1, e.y1), paint);
      } else {
        final p = Path()
          ..moveTo(e.x0, e.y0)
          ..lineTo(e.x1, e.y1);
        canvas.drawPath(_dashed(p, _dashPattern(e.style)), paint);
      }
    case ArcEvent():
      final paint = _strokePaint(e.style);
      final rect = Rect.fromCircle(center: Offset(e.cx, e.cy), radius: e.radius);
      // Repère Logo (y vers le haut, cap horaire depuis le haut) → angle
      // trigonométrique : a = 90° − cap.
      final start = (90 - e.start) * math.pi / 180;
      final sweep = -e.sweep * math.pi / 180;
      final path = Path()..addArc(rect, start, sweep.abs() >= 2 * math.pi ? 2 * math.pi - 1e-6 : sweep);
      canvas.drawPath(e.style.dash == 0 ? path : _dashed(path, _dashPattern(e.style)), paint);
    case DotEvent():
      canvas.drawCircle(
        Offset(e.x, e.y),
        math.max(1, e.style.width / 2),
        Paint()
          ..color = Color(e.style.color)
          ..blendMode = e.style.mode == PenMode.erase ? BlendMode.clear : BlendMode.srcOver,
      );
    case LabelEvent():
      final tp = TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(color: Color(e.color), fontSize: e.fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(e.x, e.y);
      canvas.scale(1, -1);
      tp.paint(canvas, Offset(0, -tp.height));
      canvas.restore();
    default:
      break;
  }
}

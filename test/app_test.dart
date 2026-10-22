import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logo_core/logo_core.dart';
import 'package:ter_logo_reboot/main.dart';
import 'package:ter_logo_reboot/state/canvas_controller.dart';

void main() {
  testWidgets('la fenêtre principale s\'affiche', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TerLogoApp());
    await tester.pump();
    expect(find.text('Exécuter'), findsOneWidget);
    expect(find.text('Console'), findsOneWidget);
  });

  test('le canevas applique les événements en mode instantané', () {
    final c = CanvasController()..speed = 0;
    const style = PenStyle(0xFF000000, 1, PenMode.paint, 0);
    c.push(const MoveEvent(0, 0, 0, 100, true, style));
    c.push(const TurnEvent(0, 90));
    expect(c.turtleY, 100);
    expect(c.turtleHeading, 90);
    expect(c.bounds, isNotNull);
    c.push(const ClearEvent(true));
    expect(c.turtleY, 0);
    expect(c.bounds, isNull);
    c.dispose();
  });
}

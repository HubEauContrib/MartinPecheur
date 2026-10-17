import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';

import '../../support/windows_platform.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  const List<(FloodVigilanceLevel, int)> levels = [
    (Vert(), 0),
    (Jaune(), 1),
    (Orange(), 2),
    (Rouge(), 3),
    (NiveauCruesInconnu('x'), 0),
  ];

  for (final double size in <double>[20, 26]) {
    testWidgetsOnWindows('la jauge se rend aux cinq niveaux à $size px', (
      WidgetTester tester,
    ) async {
      for (final (FloodVigilanceLevel level, int bars) in levels) {
        await tester.pumpWidget(
          _host(FloodLevelGauge(level: level, size: size)),
        );
        expect(tester.takeException(), isNull, reason: '$level');
        expect(tester.getSize(find.byType(FloodLevelGauge)), Size(size, size));
        // Seules les barres passent par drawRect (fond et contour : drawRRect).
        expect(
          tester.renderObject(
            find.descendant(
              of: find.byType(FloodLevelGauge),
              matching: find.byType(CustomPaint),
            ),
          ),
          paintsExactlyCountTimes(#drawRect, bars),
          reason: '$level',
        );
      }
    });
  }

  testWidgetsOnWindows("la jauge n'a aucune sémantique propre", (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const FloodLevelGauge(level: Rouge())));
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FloodLevelGauge),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}

// Le badge a une taille (`size`) : le contour reste de 2 px et le liseré de
// Crise de 1 px QUELLE QUE SOIT la taille — seuls la forme, le glyphe, les
// hachures et les points suivent. Un contour de 2 px sur chaque badge est la
// regle du halo de `04-ui.md` § 3 (le badge de 22 n'a pas le droit de tomber
// a 1,6 px, ni celui de 48 de monter a 3,4 px).
//
// Le dessin est fait a la taille REELLE (le `CustomPainter` recoit la vraie
// taille) : un `FittedBox` mettrait aussi le contour a l'echelle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';

Future<RenderObject> _render(
  WidgetTester tester,
  DroughtSeverity severity,
  double size,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: DroughtSeverityBadge(severity: severity, size: size),
      ),
    ),
  );
  final Finder paint = find
      .descendant(
        of: find.byType(DroughtSeverityBadge),
        matching: find.byType(CustomPaint),
      )
      .first;
  // Le dessin a la taille reelle, sans mise a l'echelle par-dessus.
  expect(tester.getSize(paint), Size.square(size));
  expect(
    find.descendant(
      of: find.byType(DroughtSeverityBadge),
      matching: find.byType(FittedBox),
    ),
    findsNothing,
  );
  return tester.renderObject(paint);
}

void main() {
  for (final double size in const <double>[22, 28, 48]) {
    testWidgets('contour de 2 px à la taille $size', (
      WidgetTester tester,
    ) async {
      final RenderObject object = await _render(
        tester,
        const Vigilance(),
        size,
      );
      expect(
        object,
        paints
          // Le remplissage de la forme, puis le contour.
          ..path()
          ..path(
            style: PaintingStyle.stroke,
            strokeWidth: droughtBadgeContourWidth,
            color: droughtBadgeContourColor,
          ),
      );
      expect(droughtBadgeContourWidth, 2);
    });

    testWidgets('Crise à la taille $size : contour de 2 px et liseré blanc '
        'de 1 px', (WidgetTester tester) async {
      final RenderObject object = await _render(tester, const Crise(), size);
      expect(
        object,
        paints
          // Remplissage, liseré intérieur blanc, puis contour.
          ..path()
          ..path(
            style: PaintingStyle.stroke,
            strokeWidth: droughtBadgeInnerBorderWidth,
            color: droughtBadgeInnerBorderColor,
          )
          ..path(
            style: PaintingStyle.stroke,
            strokeWidth: droughtBadgeContourWidth,
            color: droughtBadgeContourColor,
          ),
      );
      expect(droughtBadgeInnerBorderWidth, 1);
    });
  }
}

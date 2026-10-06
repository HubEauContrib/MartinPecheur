// Verrouille le bouton « Restrictions au centre de la carte » refait selon le
// canvas de design du 2026-09-29 (`E1` de T2) : bouton large en pilule, fond
// `primaryActionColor`, libellé visible, indice de geste dessous, réticule
// inerte au centre de la carte.
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

const String _label = 'Restrictions au centre de la carte';

Future<int Function()> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 740),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  int taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: DesignateCenterControl(onDesignate: () => taps++),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => taps;
}

void main() {
  group('bouton', () {
    testWidgets('libellé visible, gras, sémantique exacte, ≥ 52 de haut', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Finder bouton = find.byKey(mapDesignateCenterButtonKey);
      expect(bouton, findsOneWidget);
      final Finder texte = find.descendant(
        of: bouton,
        matching: find.text(_label),
      );
      expect(texte, findsOneWidget);
      final TextStyle? style = tester.widget<Text>(texte).style;
      expect(style?.fontWeight, FontWeight.bold);
      expect(style?.fontSize, inInclusiveRange(16, 17));
      expect(style?.color, onPrimaryActionColor);

      expect(
        tester.getSemantics(bouton),
        matchesSemantics(
          label: _label,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(bouton).height, greaterThanOrEqualTo(52));
      expect(
        tester.getSize(bouton).height,
        greaterThanOrEqualTo(minimumTapTarget),
      );
    });

    testWidgets('fond primaryActionColor, bordure blanche 2, ombre, pilule', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final ShapeDecoration decoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(mapDesignateCenterButtonKey),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox b) => b.decoration)
          .whereType<ShapeDecoration>()
          .first;
      expect(decoration.color, primaryActionColor);
      expect(decoration.shadows, isNotEmpty);
      final StadiumBorder shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, Colors.white);
      expect(shape.side.width, 2);
    });

    testWidgets("l'icône de visée est exclue de la sémantique", (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Finder icone = find.descendant(
        of: find.byKey(mapDesignateCenterButtonKey),
        matching: find.byIcon(Icons.gps_fixed),
      );
      expect(icone, findsOneWidget);
      expect(tester.widget<Icon>(icone).color, onPrimaryActionColor);
      expect(
        find.ancestor(of: icone, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });

    testWidgets('un tap, Entrée et Espace appellent le rappel', (
      WidgetTester tester,
    ) async {
      final int Function() taps = await _pump(tester);

      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      expect(taps(), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps(), 3);
    });

    for (final (Size, double) cas in <(Size, double)>[
      (const Size(360, 640), 1),
      (const Size(360, 640), 2),
      (const Size(390, 844), 2),
    ]) {
      testWidgets(
        'à ${cas.$1.width.toInt()} de large, police ${cas.$2 * 100} % : '
        'libellé complet, aucun débordement',
        (WidgetTester tester) async {
          await _pump(tester, size: cas.$1, textScale: cas.$2);

          expect(tester.takeException(), isNull);
          final Rect bouton = tester.getRect(
            find.byKey(mapDesignateCenterButtonKey),
          );
          expect(bouton.left, greaterThanOrEqualTo(16));
          expect(bouton.right, lessThanOrEqualTo(cas.$1.width - 16));
          final Rect texte = tester.getRect(find.text(_label));
          expect(bouton.contains(texte.topLeft), isTrue);
          expect(bouton.contains(texte.bottomRight), isTrue);
        },
      );
    }
  });

  group('indice', () {
    for (final (TargetPlatform, String) cas in <(TargetPlatform, String)>[
      (TargetPlatform.android, 'ou appui long sur n\'importe quel point'),
      (TargetPlatform.iOS, 'ou appui long sur n\'importe quel point'),
      (
        TargetPlatform.windows,
        'ou clic droit sur n\'importe quel point de la carte',
      ),
      (
        TargetPlatform.linux,
        'ou clic droit sur n\'importe quel point de la carte',
      ),
    ]) {
      testWidgets('${cas.$1.name} : « ${cas.$2} », hors sémantique', (
        WidgetTester tester,
      ) async {
        debugDefaultTargetPlatformOverride = cas.$1;
        try {
          await _pump(tester);

          final Finder indice = find.byKey(mapDesignateCenterHintKey);
          expect(indice, findsOneWidget);
          expect(
            find.descendant(of: indice, matching: find.text(cas.$2)),
            findsOneWidget,
          );
          final TextStyle? style = tester.widget<Text>(find.text(cas.$2)).style;
          expect(style?.fontSize, 14);
          expect(
            find.ancestor(
              of: find.text(cas.$2),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          // Sous le bouton, centré.
          final Rect b = tester.getRect(
            find.byKey(mapDesignateCenterButtonKey),
          );
          final Rect h = tester.getRect(indice);
          expect(h.top, greaterThanOrEqualTo(b.bottom));
          expect(h.center.dx, closeTo(b.center.dx, 1));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('sans coup de dépassement à 360 × 640, police 200 %', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: const Size(360, 640), textScale: 2);

      expect(tester.takeException(), isNull);
      final Rect h = tester.getRect(find.byKey(mapDesignateCenterHintKey));
      expect(h.left, greaterThanOrEqualTo(0));
      expect(h.right, lessThanOrEqualTo(360));
    });
  });

  group('réticule', () {
    testWidgets('48 × 48, inerte : hors pointeur, sémantique et focus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: MapCenterReticle())),
        ),
      );

      final Finder reticule = find.byKey(mapCenterReticleKey);
      expect(reticule, findsOneWidget);
      expect(tester.getSize(reticule), const Size(48, 48));
      expect(tester.getCenter(reticule), const Offset(400, 300));
      expect(
        find.ancestor(of: reticule, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: reticule, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: reticule, matching: find.byType(ExcludeFocus)),
        findsWidgets,
      );
    });
  });
}

// Verrouille [MapControls] (`K1`, 2026-09-23) : trois boutons — `+`, `−`,
// recentrage —, chacun une cible tactile ≥ 44 × 44 pt, espacés d'au moins
// 8 dp, avec un libellé d'accessibilité en français (`04-ui.md` § 3). Ce
// widget est un widget de CONTENU pur : il ne connaît ni `MapViewModel` ni
// `flutter_map` — le câblage caméra (déplacement, `onGestureEnded`) est
// vérifié dans `map_view_test.dart`, sur le rendu complet de `MapView`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    VoidCallback? onZoomIn,
    VoidCallback? onZoomOut,
    VoidCallback? onRecenter,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: MapControls(
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onRecenter: onRecenter ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('les trois boutons sont rendus', (WidgetTester tester) async {
    await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

    expect(find.byKey(mapZoomInButtonKey), findsOneWidget);
    expect(find.byKey(mapZoomOutButtonKey), findsOneWidget);
    expect(find.byKey(mapRecenterButtonKey), findsOneWidget);
  });

  testWidgets('chaque bouton mesure au moins 44 × 44 pt (04-ui.md § 3)', (
    WidgetTester tester,
  ) async {
    await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

    for (final Key key in <Key>[
      mapZoomInButtonKey,
      mapZoomOutButtonKey,
      mapRecenterButtonKey,
    ]) {
      final Size size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    }
  });

  testWidgets(
    "l'espacement entre deux boutons consécutifs est d'au moins 8 dp",
    (WidgetTester tester) async {
      await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

      final Rect zoomIn = tester.getRect(find.byKey(mapZoomInButtonKey));
      final Rect zoomOut = tester.getRect(find.byKey(mapZoomOutButtonKey));
      final Rect recenter = tester.getRect(find.byKey(mapRecenterButtonKey));

      expect(zoomOut.top - zoomIn.bottom, greaterThanOrEqualTo(8));
      expect(recenter.top - zoomOut.bottom, greaterThanOrEqualTo(8));
    },
  );

  testWidgets(
    'chaque bouton porte le libellé exact et enabled est vrai quand le '
    'rappel est fourni (relecture du coordinateur du 2026-09-23)',
    (WidgetTester tester) async {
      await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

      final Semantics zoomIn = tester.widget<Semantics>(
        find.byKey(mapZoomInButtonKey),
      );
      final Semantics zoomOut = tester.widget<Semantics>(
        find.byKey(mapZoomOutButtonKey),
      );
      final Semantics recenter = tester.widget<Semantics>(
        find.byKey(mapRecenterButtonKey),
      );

      expect(zoomIn.properties.button, isTrue);
      expect(zoomIn.properties.label, 'Zoomer');
      expect(zoomIn.properties.enabled, isTrue);
      expect(zoomOut.properties.button, isTrue);
      expect(zoomOut.properties.label, 'Dézoomer');
      expect(zoomOut.properties.enabled, isTrue);
      expect(recenter.properties.button, isTrue);
      expect(recenter.properties.label, 'Recentrer la carte');
      expect(recenter.properties.enabled, isTrue);
    },
  );

  testWidgets('un tap sur + appelle onZoomIn UNE fois', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpControls(tester, onZoomIn: () => calls++, onZoomOut: () {});

    await tester.tap(find.byKey(mapZoomInButtonKey));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('un tap sur − appelle onZoomOut UNE fois', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpControls(tester, onZoomIn: () {}, onZoomOut: () => calls++);

    await tester.tap(find.byKey(mapZoomOutButtonKey));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('un tap sur le recentrage appelle onRecenter UNE fois', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpControls(
      tester,
      onZoomIn: () {},
      onZoomOut: () {},
      onRecenter: () => calls++,
    );

    await tester.tap(find.byKey(mapRecenterButtonKey));
    await tester.pump();

    expect(calls, 1);
  });

  group('désactivation aux bornes (K1)', () {
    testWidgets(
      'onZoomIn nul : + est désactivé (Semantics.enabled faux) et un tap '
      "ne fait rien — c'est le ViewModel (canZoomIn) qui décide, pas ce "
      'widget',
      (WidgetTester tester) async {
        await pumpControls(tester, onZoomIn: null, onZoomOut: () {});

        final Semantics zoomIn = tester.widget<Semantics>(
          find.byKey(mapZoomInButtonKey),
        );
        expect(zoomIn.properties.enabled, isFalse);

        await tester.tap(find.byKey(mapZoomInButtonKey), warnIfMissed: false);
        await tester.pump();
        // Aucune exception : le tap sur un bouton désactivé ne lève pas.
      },
    );

    testWidgets('onZoomOut nul : − est désactivé (Semantics.enabled faux)', (
      WidgetTester tester,
    ) async {
      await pumpControls(tester, onZoomIn: () {}, onZoomOut: null);

      final Semantics zoomOut = tester.widget<Semantics>(
        find.byKey(mapZoomOutButtonKey),
      );
      expect(zoomOut.properties.enabled, isFalse);
    });
  });
}

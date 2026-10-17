// Verrouille [MapControls] (`K1`, 2026-09-23) : trois boutons — `+`, `−`,
// recentrage —, chacun une cible tactile ≥ 44 × 44 pt, espacés d'au moins
// 8 dp, avec un libellé d'accessibilité en français (`04-ui.md` § 3). Ce
// widget est un widget de CONTENU pur : il ne connaît ni `MapViewModel` ni
// `flutter_map` — le câblage caméra (déplacement, `onGestureEnded`) est
// vérifié dans `map_view_test.dart`, sur le rendu complet de `MapView`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// Un test de widget posé sur une plateforme : les cas de la rangée (`S4`
/// d'Ergonomie) sont rejoués sur Windows ET sur Android, où la cible tactile
/// mesure 48 et non 44.
typedef _Test = void Function(
  String description,
  Future<void> Function(WidgetTester tester) body,
);

void _onAndroid(String d, Future<void> Function(WidgetTester tester) body) =>
    testWidgetsOnAndroid('Android : $d', body);

void _onWindows(String d, Future<void> Function(WidgetTester tester) body) =>
    testWidgetsOnWindows(d, body);

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    VoidCallback? onZoomIn,
    VoidCallback? onZoomOut,
    VoidCallback? onRecenter,
    Axis axis = Axis.vertical,
    Widget Function(Widget controls)? wrap,
  }) {
    final Widget controls = MapControls(
      onZoomIn: onZoomIn,
      onZoomOut: onZoomOut,
      onRecenter: onRecenter ?? () {},
      axis: axis,
    );
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: wrap == null ? controls : wrap(controls),
          ),
        ),
      ),
    );
  }

  /// La boîte du groupe : le premier `RenderObject` de [MapControls].
  RenderBox box(WidgetTester tester) =>
      tester.renderObject<RenderBox>(find.byType(MapControls));

  testWidgetsOnWindows('les trois boutons sont rendus', (
    WidgetTester tester,
  ) async {
    await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

    expect(find.byKey(mapZoomInButtonKey), findsOneWidget);
    expect(find.byKey(mapZoomOutButtonKey), findsOneWidget);
    expect(find.byKey(mapRecenterButtonKey), findsOneWidget);
  });

  testWidgetsOnWindows(
    'chaque bouton mesure au moins 44 × 44 pt (04-ui.md § 3)',
    (WidgetTester tester) async {
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
    },
  );

  testWidgetsOnWindows(
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

  testWidgetsOnWindows(
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

  testWidgetsOnWindows('un tap sur + appelle onZoomIn UNE fois', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpControls(tester, onZoomIn: () => calls++, onZoomOut: () {});

    await tester.tap(find.byKey(mapZoomInButtonKey));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgetsOnWindows('un tap sur − appelle onZoomOut UNE fois', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpControls(tester, onZoomIn: () {}, onZoomOut: () => calls++);

    await tester.tap(find.byKey(mapZoomOutButtonKey));
    await tester.pump();

    expect(calls, 1);
  });

  testWidgetsOnWindows('un tap sur le recentrage appelle onRecenter UNE fois', (
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
    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
      'onZoomOut nul : − est désactivé (Semantics.enabled faux)',
      (WidgetTester tester) async {
        await pumpControls(tester, onZoomIn: () {}, onZoomOut: null);

        final Semantics zoomOut = tester.widget<Semantics>(
          find.byKey(mapZoomOutButtonKey),
        );
        expect(zoomOut.properties.enabled, isFalse);
      },
    );
  });

  // `S4` d'Ergonomie : au téléphone, le zoom passe en RANGÉE, dans l'ordre de
  // l'écran — `−`, `+`, recentrer, de gauche à droite. `Axis.vertical` reste
  // le défaut : `+`, `−`, recentrer de haut en bas, comme avant (les cas
  // ci-dessus, inchangés, en sont le filet).
  //
  // Ce qui dépend de la plateforme (la cible de 44 ou de 48) est rejoué sur
  // Windows ET sur Android.
  void rowCases(String where, _Test test) {
    group('axis horizontal : la rangée ($where)', () {
      test('−, +, recentrer de gauche à droite, sur une même ligne, séparés de '
          'mapControlsSpacing, chacun de minimumTapTarget, le groupe étant '
          'leur somme', (WidgetTester tester) async {
        await pumpControls(
          tester,
          onZoomIn: () {},
          onZoomOut: () {},
          axis: Axis.horizontal,
        );

        final Rect zoomOut = tester.getRect(find.byKey(mapZoomOutButtonKey));
        final Rect zoomIn = tester.getRect(find.byKey(mapZoomInButtonKey));
        final Rect recenter = tester.getRect(find.byKey(mapRecenterButtonKey));

        expect(zoomOut.center.dx, lessThan(zoomIn.center.dx));
        expect(zoomIn.center.dx, lessThan(recenter.center.dx));
        expect(zoomOut.center.dy, zoomIn.center.dy);
        expect(zoomIn.center.dy, recenter.center.dy);
        expect(zoomIn.left - zoomOut.right, mapControlsSpacing);
        expect(recenter.left - zoomIn.right, mapControlsSpacing);
        for (final Rect rect in <Rect>[zoomOut, zoomIn, recenter]) {
          expect(rect.size, Size.square(minimumTapTarget));
        }
        expect(
          tester.getSize(find.byType(MapControls)),
          Size(3 * minimumTapTarget + 2 * mapControlsSpacing, minimumTapTarget),
        );
      });

      test('intrinsèques : une seule hauteur, celle d\'un bouton ; la largeur '
          'des trois et de leurs écarts', (WidgetTester tester) async {
        await pumpControls(
          tester,
          onZoomIn: () {},
          onZoomOut: () {},
          axis: Axis.horizontal,
        );

        expect(box(tester).getMinIntrinsicHeight(300), minimumTapTarget);
        expect(box(tester).getMaxIntrinsicHeight(300), minimumTapTarget);
        expect(
          box(tester).getMinIntrinsicWidth(double.infinity),
          3 * minimumTapTarget + 2 * mapControlsSpacing,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('axis vertical : la colonne, par défaut ($where)', () {
      test('+ au-dessus de −, au-dessus de recentrer ; intrinsèques', (
        WidgetTester tester,
      ) async {
        await pumpControls(tester, onZoomIn: () {}, onZoomOut: () {});

        final Rect zoomIn = tester.getRect(find.byKey(mapZoomInButtonKey));
        final Rect zoomOut = tester.getRect(find.byKey(mapZoomOutButtonKey));
        final Rect recenter = tester.getRect(find.byKey(mapRecenterButtonKey));
        expect(zoomOut.top - zoomIn.bottom, mapControlsSpacing);
        expect(recenter.top - zoomOut.bottom, mapControlsSpacing);
        expect(zoomIn.right, zoomOut.right);
        expect(zoomOut.right, recenter.right);
        expect(
          box(tester).getMaxIntrinsicHeight(300),
          3 * minimumTapTarget + 2 * mapControlsSpacing,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }

  // Ce qui ne dépend pas de la plateforme — rappels, libellés, bornes,
  // tabulation — n'est rejoué que sur Windows : Android n'y ajouterait rien.
  void rowBehaviourCases(_Test test) {
    group('axis horizontal : le comportement', () {
      test('chaque bouton garde sa clé, son libellé et son rappel', (
        WidgetTester tester,
      ) async {
        int zoomIn = 0;
        int zoomOut = 0;
        int recenter = 0;
        await pumpControls(
          tester,
          onZoomIn: () => zoomIn++,
          onZoomOut: () => zoomOut++,
          onRecenter: () => recenter++,
          axis: Axis.horizontal,
        );

        await tester.tap(find.byKey(mapZoomOutButtonKey));
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pump();

        expect((zoomOut, zoomIn, recenter), (1, 2, 1));
        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomOutButtonKey))
              .properties
              .label,
          'Dézoomer',
        );
        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomInButtonKey))
              .properties
              .label,
          'Zoomer',
        );
        expect(
          tester
              .widget<Semantics>(find.byKey(mapRecenterButtonKey))
              .properties
              .label,
          'Recentrer la carte',
        );
      });

      test('un bouton aux bornes reste désactivé, à sa place', (
        WidgetTester tester,
      ) async {
        await pumpControls(
          tester,
          onZoomIn: null,
          onZoomOut: () {},
          axis: Axis.horizontal,
        );

        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomInButtonKey))
              .properties
              .enabled,
          isFalse,
        );
        final Rect zoomOut = tester.getRect(find.byKey(mapZoomOutButtonKey));
        final Rect zoomIn = tester.getRect(find.byKey(mapZoomInButtonKey));
        expect(zoomIn.left - zoomOut.right, mapControlsSpacing);
      });

      test(
        'ordre de tabulation : dans un FocusTraversalGroup(OrderedTraversalPolicy) '
        'où les trois partagent un NumericFocusOrder, −, +, recentrer',
        (WidgetTester tester) async {
          await pumpControls(
            tester,
            onZoomIn: () {},
            onZoomOut: () {},
            axis: Axis.horizontal,
            wrap: (Widget controls) => FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: controls,
              ),
            ),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, find.byKey(mapZoomOutButtonKey)),
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focusedWithin(tester, find.byKey(mapZoomInButtonKey)), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, find.byKey(mapRecenterButtonKey)),
            isTrue,
          );
        },
      );
    });
  }

  rowCases('Windows', _onWindows);
  rowCases('Android', _onAndroid);
  rowBehaviourCases(_onWindows);
}

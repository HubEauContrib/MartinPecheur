// Verrouille [MapScaleChips], **extrait** de `map_view.dart` par `K1`
// (2026-09-23) dans son propre fichier (`lib/features/map/view/map_scale_chips.dart`),
// au même titre que [IgnAttributionBadge] (`ign_attribution_badge_test.dart`).
// Aucun changement d'assertion par rapport à la version qui vivait dans
// `map_view_test.dart` (groupe « MapScaleChips — la bascule d échelle,
// T1-U3, UC-001 A6 ») — seuls les imports changent.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

void main() {
  group('MapScaleChips — la bascule d échelle (T1-U3, UC-001 A6)', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      required MapScaleKind scale,
      required void Function(MapScaleKind kind) onSelect,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MapScaleChips(scale: scale, onSelect: onSelect),
            ),
          ),
        ),
      );
    }

    testWidgets('rend une puce par échelle, nommée par mapScaleLabel — '
        'jamais une reformulation locale', (WidgetTester tester) async {
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: (MapScaleKind kind) {},
      );

      for (final MapScaleKind kind in MapScaleKind.values) {
        expect(find.text(mapScaleLabel(kind)), findsOneWidget);
      }
    });

    testWidgets("la puce active est sémantiquement sélectionnée, l'autre "
        'non — la sélection ne tient pas qu à un aplat de couleur '
        '(04-ui.md § 3)', (WidgetTester tester) async {
      for (final MapScaleKind active in MapScaleKind.values) {
        await pumpChips(
          tester,
          scale: active,
          onSelect: (MapScaleKind kind) {},
        );

        for (final MapScaleKind kind in MapScaleKind.values) {
          final Semantics chip = tester.widget<Semantics>(
            find.byKey(ValueKey<MapScaleKind>(kind)),
          );
          expect(
            chip.properties.selected,
            kind == active,
            reason: '$kind, échelle active $active',
          );
          expect(chip.properties.button, isTrue);
          expect(chip.properties.label, mapScaleLabel(kind));
        }
      }
    });

    testWidgets('un tap sur « Débit » appelle onSelect(debit) UNE fois', (
      WidgetTester tester,
    ) async {
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: selected.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      await tester.pump();

      expect(selected, <MapScaleKind>[MapScaleKind.debit]);
    });

    testWidgets("chaque puce porte une action tap pour le lecteur d'écran — "
        '`excludeSemantics` masque celle du geste (relecture du '
        '2026-09-23)', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: selected.add,
      );

      for (final MapScaleKind kind in MapScaleKind.values) {
        final SemanticsNode node = tester.getSemantics(
          find.byKey(ValueKey<MapScaleKind>(kind)),
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: kind.name,
        );

        selected.clear();
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(selected, <MapScaleKind>[kind]);
      }

      handle.dispose();
    });

    testWidgets('un tap sur la puce déjà active la redemande telle quelle — '
        "c'est le ViewModel qui décide que cela ne change rien", (
      WidgetTester tester,
    ) async {
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: selected.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
      );
      await tester.pump();

      expect(selected, <MapScaleKind>[MapScaleKind.ecoulement]);
    });

    testWidgets('chaque puce mesure au moins 44 pt dans les deux dimensions '
        '(04-ui.md § 3, cibles tactiles)', (WidgetTester tester) async {
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: (MapScaleKind kind) {},
      );

      for (final MapScaleKind kind in MapScaleKind.values) {
        final Size size = tester.getSize(
          find.byKey(ValueKey<MapScaleKind>(kind)),
        );
        expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
        expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
      }
    });
  });

  group('MapScaleChips — le choix « Restrictions » (E5 de T2, arbitrage du '
      '2026-10-03)', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      MapScaleKind scale = MapScaleKind.ecoulement,
      bool designationMode = false,
      VoidCallback? onToggle,
      double textScale = 1,
      double width = 800,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              size: Size(width, 600),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MapScaleChips(
                    scale: scale,
                    onSelect: (MapScaleKind kind) {},
                    designationMode: designationMode,
                    onToggleDesignationMode: onToggle,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'sans rappel : exactement deux puces, aucune « Restrictions »',
      (WidgetTester tester) async {
        await pumpChips(tester);

        expect(find.byKey(mapDesignationChipKey), findsNothing);
        expect(find.text(designationChipLabel), findsNothing);
        for (final MapScaleKind kind in MapScaleKind.values) {
          expect(find.byKey(ValueKey<MapScaleKind>(kind)), findsOneWidget);
        }
      },
    );

    testWidgets('avec rappel : troisième puce, libellé exact, APRÈS les deux '
        'autres', (WidgetTester tester) async {
      await pumpChips(tester, onToggle: () {});

      expect(designationChipLabel, 'Restrictions');
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
      expect(find.text('Restrictions'), findsOneWidget);
      final Rect restrictions = tester.getRect(
        find.byKey(mapDesignationChipKey),
      );
      for (final MapScaleKind kind in MapScaleKind.values) {
        final Rect autre = tester.getRect(
          find.byKey(ValueKey<MapScaleKind>(kind)),
        );
        expect(
          restrictions.left,
          greaterThanOrEqualTo(autre.right),
          reason: 'après ${kind.name}',
        );
      }
    });

    testWidgets("`toggled` suit designationMode, JAMAIS `selected` ; la puce "
        "de l'échelle active reste `selected` dans les deux modes", (
      WidgetTester tester,
    ) async {
      for (final bool mode in <bool>[false, true]) {
        for (final MapScaleKind active in MapScaleKind.values) {
          await pumpChips(
            tester,
            scale: active,
            designationMode: mode,
            onToggle: () {},
          );

          final Semantics restrictions = tester.widget<Semantics>(
            find.byKey(mapDesignationChipKey),
          );
          expect(restrictions.properties.toggled, mode);
          expect(restrictions.properties.selected, isNot(isTrue));
          expect(restrictions.properties.button, isTrue);
          expect(restrictions.properties.label, 'Restrictions');
          for (final MapScaleKind kind in MapScaleKind.values) {
            expect(
              tester
                  .widget<Semantics>(find.byKey(ValueKey<MapScaleKind>(kind)))
                  .properties
                  .selected,
              kind == active,
              reason: 'mode $mode, active $active, $kind',
            );
          }
        }
      }
    });

    testWidgets('un tap appelle le rappel UNE fois', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpChips(tester, onToggle: () => calls++);

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('Tab atteint la puce après les deux autres ; Entrée puis '
        'Espace appellent le rappel, une fois chacun', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpChips(tester, onToggle: () => calls++);

      for (int i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets("l'action sémantique tap appelle le rappel une fois", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int calls = 0;
      await pumpChips(tester, onToggle: () => calls++);

      final SemanticsNode node = tester.getSemantics(
        find.byKey(mapDesignationChipKey),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();

      expect(calls, 1);
      handle.dispose();
    });

    testWidgets('au moins 44 pt dans les deux dimensions', (
      WidgetTester tester,
    ) async {
      await pumpChips(tester, onToggle: () {});

      final Size size = tester.getSize(find.byKey(mapDesignationChipKey));
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    });

    testWidgets('à 200 % le libellé « Restrictions » n est pas tronqué', (
      WidgetTester tester,
    ) async {
      await pumpChips(tester, onToggle: () {}, textScale: 2, width: 360);

      expect(tester.takeException(), isNull);
      final Rect chip = tester.getRect(find.byKey(mapDesignationChipKey));
      final Rect text = tester.getRect(find.text('Restrictions'));
      expect(text.width, greaterThan(0));
      expect(chip.left, lessThanOrEqualTo(text.left));
      expect(chip.right, greaterThanOrEqualTo(text.right));
      expect(chip.top, lessThanOrEqualTo(text.top));
      expect(chip.bottom, greaterThanOrEqualTo(text.bottom));
      // Une seule ligne de texte : le mot n'est pas coupé lettre par lettre.
      expect(text.height, lessThan(2 * 12 * 2 * 1.5));
    });
  });
}

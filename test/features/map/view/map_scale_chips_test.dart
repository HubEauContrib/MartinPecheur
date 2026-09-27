// Verrouille [MapScaleChips], **extrait** de `map_view.dart` par `K1`
// (2026-09-23) dans son propre fichier (`lib/features/map/view/map_scale_chips.dart`),
// au même titre que [IgnAttributionBadge] (`ign_attribution_badge_test.dart`).
// Aucun changement d'assertion par rapport à la version qui vivait dans
// `map_view_test.dart` (groupe « MapScaleChips — la bascule d échelle,
// T1-U3, UC-001 A6 ») — seuls les imports changent.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
}

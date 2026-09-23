// Verrouille [IgnAttributionBadge], **extrait** de `map_view.dart` par `K1`
// (2026-09-23) dans son propre fichier
// (`lib/features/map/view/ign_attribution_badge.dart`), au même titre que
// [MapScaleChips] (`map_scale_chips_test.dart`). Aucun changement
// d'assertion par rapport à la version qui vivait dans `map_view_test.dart`
// (groupe « IgnAttributionBadge ») — seuls les imports changent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';

void main() {
  group('IgnAttributionBadge', () {
    testWidgets('affiche l\'attribution IGN et Licence Ouverte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IgnAttributionBadge())),
      );

      expect(find.text(ignAttribution), findsOneWidget);
      expect(ignAttribution, contains('IGN'));
      expect(ignAttribution, contains('Licence Ouverte'));
    });

    testWidgets('porte son propre fond opaque', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IgnAttributionBadge())),
      );

      final DecoratedBox decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      final Color? color = decoration.color;

      expect(color, isNotNull);
      expect(color!.a, greaterThan(0.8));
    });
  });
}

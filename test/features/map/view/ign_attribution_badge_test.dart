// Verrouille [IgnAttributionBadge], **extrait** de `map_view.dart` par `K1`
// (2026-09-23) dans son propre fichier
// (`lib/features/map/view/ign_attribution_badge.dart`), au même titre que
// les puces d'échelle d'alors (devenues le sélecteur de lecture,
// `map_reading_selector_test.dart`). Aucun changement
// d'assertion par rapport à la version qui vivait dans `map_view_test.dart`
// (groupe « IgnAttributionBadge ») — seuls les imports changent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart'
    show ignAttribution;
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';

import '../../../support/windows_platform.dart';

void main() {
  group('IgnAttributionBadge', () {
    testWidgetsOnWindows('affiche l\'attribution IGN et Licence Ouverte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IgnAttributionBadge())),
      );

      expect(find.text(ignAttribution), findsOneWidget);
      expect(ignAttribution, contains('IGN'));
      expect(ignAttribution, contains('Licence Ouverte'));
    });

    testWidgetsOnWindows('porte son propre fond opaque', (
      WidgetTester tester,
    ) async {
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

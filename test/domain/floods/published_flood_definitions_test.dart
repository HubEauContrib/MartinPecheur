import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';

void main() {
  late String page;

  setUpAll(() {
    page = File('test/fixtures/vigicrues/accueil_legende_2026-10-14.html')
        .readAsStringSync()
        .replaceAll('&#039;', "'");
  });

  const List<FloodVigilanceLevel> published = <FloodVigilanceLevel>[
    Vert(),
    Jaune(),
    Orange(),
    Rouge(),
  ];

  test('chaque légende figure telle quelle dans la fixture', () {
    for (final FloodVigilanceLevel level in published) {
      final String? legend = publishedFloodLegend(level);
      expect(legend, isNotNull, reason: '$level');
      expect(page, contains(legend), reason: '$level');
    }
  });

  test('chaque explication non nulle figure telle quelle dans la fixture', () {
    for (final FloodVigilanceLevel level in published) {
      final String? text = publishedFloodExplanation(level);
      if (level is Vert) {
        expect(text, isNull);
      } else {
        expect(text, isNotNull, reason: '$level');
        expect(page, contains(text), reason: '$level');
      }
    }
  });

  test('textes exacts, apostrophes comprises', () {
    expect(
      publishedFloodExplanation(const Jaune()),
      contains("d'activités exposées"),
    );
    expect(publishedFloodExplanation(const Orange()), contains('d’avoir'));
    expect(publishedFloodLegend(const Rouge()), 'Risque de crue majeure');
  });

  test('l\'inconnu n\'a ni légende ni explication', () {
    expect(publishedFloodLegend(const NiveauCruesInconnu(5)), isNull);
    expect(publishedFloodExplanation(const NiveauCruesInconnu(5)), isNull);
  });
}

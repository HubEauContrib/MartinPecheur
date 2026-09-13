// Test de non-régression sur la documentation (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Lie docs/domain-model.md au code dans les deux sens : un type du domaine
// absent du document est un document en retard sur le code ; un type
// documenté et jamais écrit sous lib/domain/ est une promesse (BR-008 le
// rappelle : pas d'agrégat « état de la rivière »).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les seize types du domaine, tels qu'ils existent sous lib/domain/ à la
/// fin de T0 (D7 compris).
const List<String> typesDuDomaine = <String>[
  'StationCode',
  'DepartementCode',
  'Station',
  'HydroObservation',
  'Qualification',
  'Grandeur',
  'Freshness',
  'FlowCategory',
  'Inconnu',
  'Bounds',
  'StationRepository',
  'HydroObservationRepository',
  'LitresPerSecond',
  'Millimetres',
  'CubicMetresPerSecond',
  'Metres',
];

/// Types envisagés mais pas encore écrits sous lib/domain/ (Écoulement
/// ONDE, Restrictions, Sécheresse — hors T0). Les documenter maintenant
/// serait une promesse : un type documenté et jamais écrit.
const List<String> typesHorsPerimetre = <String>[
  'PointOnde',
  'CampagneOnde',
  'ZoneRestriction',
  'NiveauDebitCalcule',
  'ReferencePercentile',
];

void main() {
  group('docs/domain-model.md', () {
    late String contenu;

    setUpAll(() {
      contenu = File('docs/domain-model.md').readAsStringSync();
    });

    test('nomme les seize types du domaine', () {
      for (final String type in typesDuDomaine) {
        expect(
          contenu,
          contains(type),
          reason: '$type est écrit sous lib/domain/ mais absent du document',
        );
      }
    });

    test('inclut un diagramme mermaid classDiagram', () {
      expect(contenu, contains('```mermaid'));
      expect(contenu, contains('classDiagram'));
    });

    test('ne documente aucun type hors périmètre de T0', () {
      for (final String type in typesHorsPerimetre) {
        expect(
          contenu,
          isNot(contains(type)),
          reason:
              '$type est documenté mais jamais écrit sous lib/domain/ : '
              'une promesse, pas un état vivant',
        );
      }
    });
  });
}

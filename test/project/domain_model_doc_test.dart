// Test de non-régression sur la documentation (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Lie docs/domain-model.md au code dans les deux sens : un type du domaine
// absent du document est un document en retard sur le code ; un type
// documenté et jamais écrit sous lib/domain/ est une promesse (BR-008 le
// rappelle : pas d'agrégat « état de la rivière »).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les types du domaine, tels qu'ils existent sous lib/domain/ après le
/// réusinage MVVM du 2026-09-13. `StationPoint` et `StationPointRepository`
/// s'y ajoutent : ils étaient écrits sous lib/domain/ et absents du document,
/// soit exactement le retard que ce test doit attraper. `GeoPoint` s'y ajoute
/// à son tour (T2, M1), puis les trois nomenclatures des restrictions (T2, M2),
/// puis la zone d'alerte, l'arrêté, l'usage cité et la réponse datée au
/// point (T2, M3), puis le contrat `RestrictionSource` et son échec fermé à
/// trois branches (T2, M4), puis le port d'ouverture de lien (T2, B2).
const List<String> typesDuDomaine = <String>[
  'StationCode',
  'DepartementCode',
  'Station',
  'StationPoint',
  'StationPointRepository',
  'HydroObservation',
  'Qualification',
  'Grandeur',
  'Freshness',
  'FlowCategory',
  'Inconnu',
  'Bounds',
  'GeoPoint',
  'DroughtSeverity',
  'GraviteInconnue',
  'ZoneKind',
  'TypeZoneInconnu',
  'UserProfile',
  'AlertZone',
  'RestrictionDecree',
  'DocumentLink',
  'RestrictedUsage',
  'ZonesAtPoint',
  'RestrictionSource',
  'RestrictionLookupFailure',
  'SourceInjoignable',
  'RequeteRefusee',
  'ReponseIllisible',
  'ExternalLinkOpener',
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

    test('nomme les types du domaine', () {
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

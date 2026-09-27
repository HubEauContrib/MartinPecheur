// Verrouille la pastille de zone administrative (`ADR-015`, lot 4 bis, Z4) :
// son libellé annoncé au lecteur d'écran ([areaClusterLabel]), sa taille
// minimale, l'absence de tap-passthrough vers une fiche, et le rendu — un
// seul symbole EXISTANT par échelle (`OndeMarkerShape`/`OndeMarkerPainter`
// sur écoulement, le losange neutre de `StationMarkerPainter` sur débit),
// jamais une teinte ni une forme nouvelle.
//
// Aucun `FlutterMap` ici : [AreaClusterMarker] est un widget de contenu pur,
// comme [StationMarkerDot] et [OndeMarkerShape] — montable seul.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

/// Un agrégat écoulement minimal — région Centre-Val de Loire, 15 points
/// chargés, plus sévère « Assec » récent. Reprend l'exemple du plan T1
/// (« Task Z4 »).
MapAreaCluster _centreValDeLoireAssec({int count = 15}) => MapAreaCluster(
  scale: MapScaleKind.ecoulement,
  level: AreaLevel.region,
  area: const AdministrativeArea(code: '24', label: 'Centre-Val de Loire'),
  latitude: 47.5,
  longitude: 1.5,
  count: count,
  bounds: Bounds(west: 0, south: 47, east: 2, north: 48),
  severest: const Assec(),
  severestAge: CampaignAge.recente,
);

/// Un agrégat débit — département Loir-et-Cher, sans percentile (BR-004),
/// donc sans état classé (`severest`/`severestAge` nuls, `ADR-015`).
MapAreaCluster _loirEtCherDebit({int count = 28}) => MapAreaCluster(
  scale: MapScaleKind.debit,
  level: AreaLevel.departement,
  area: const AdministrativeArea(code: '41', label: 'LOIR-ET-CHER'),
  latitude: 47.6,
  longitude: 1.3,
  count: count,
  bounds: Bounds(west: 0.9, south: 47.3, east: 1.9, north: 48.1),
  severest: null,
  severestAge: null,
);

void main() {
  group('areaClusterLabel', () {
    test('échelle écoulement : compte, zone, état le plus sévère', () {
      expect(
        areaClusterLabel(_centreValDeLoireAssec()),
        'Écoulement : Centre-Val de Loire, '
        "15 points d'observation sur cette vue, "
        'état le plus sévère : À sec',
      );
    });

    test('singulier à un seul membre', () {
      expect(
        areaClusterLabel(_centreValDeLoireAssec(count: 1)),
        'Écoulement : Centre-Val de Loire, '
        "1 point d'observation sur cette vue, "
        'état le plus sévère : À sec',
      );
    });

    test('agrégat non observé (BR-009) : « Non observé », pas « Assec »', () {
      final MapAreaCluster cluster = MapAreaCluster(
        scale: MapScaleKind.ecoulement,
        level: AreaLevel.region,
        area: const AdministrativeArea(
          code: '24',
          label: 'Centre-Val de Loire',
        ),
        latitude: 47.5,
        longitude: 1.5,
        count: 4,
        bounds: null,
        severest: const NonObserve(),
        severestAge: CampaignAge.ancienne,
      );
      expect(
        areaClusterLabel(cluster),
        'Écoulement : Centre-Val de Loire, '
        "4 points d'observation sur cette vue, "
        'état le plus sévère : Non observé',
      );
    });

    test('échelle débit : compte seul, ni « sur cette vue » ni état', () {
      final MapAreaCluster occitanie = MapAreaCluster(
        scale: MapScaleKind.debit,
        level: AreaLevel.region,
        area: const AdministrativeArea(code: '76', label: 'OCCITANIE'),
        latitude: 43.9,
        longitude: 2.2,
        count: 753,
        bounds: Bounds(west: -2, south: 42, east: 5, north: 45),
        severest: null,
        severestAge: null,
      );
      expect(
        areaClusterLabel(occitanie),
        "Débit relatif à l'historique : OCCITANIE, 753 stations",
      );
    });

    test('aucun mot banni (BR-003) ni verbe d\'instruction (BR-014)', () {
      const List<String> motsInterdits = <String>[
        'suffisant',
        'insuffisant',
        'normal',
        'bon',
        'sûr',
        'cliquez',
        'appuyez',
      ];
      final String debit = areaClusterLabel(_loirEtCherDebit()).toLowerCase();
      final String ecoulement = areaClusterLabel(_centreValDeLoireAssec())
          .toLowerCase();
      for (final String mot in motsInterdits) {
        expect(debit.contains(mot), isFalse, reason: mot);
        expect(ecoulement.contains(mot), isFalse, reason: mot);
      }
    });

    test('libellé de zone affiché tel que reçu, sans changement de casse', () {
      expect(areaClusterLabel(_loirEtCherDebit()), contains('LOIR-ET-CHER'));
      expect(
        areaClusterLabel(_centreValDeLoireAssec()),
        contains('Centre-Val de Loire'),
      );
    });
  });

  group('AreaClusterMarker', () {
    testWidgets('mesure au moins 44 x 44 (cible tactile, 04-ui.md § 3)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: AreaClusterMarker(cluster: _centreValDeLoireAssec()),
          ),
        ),
      );

      final Size taille = tester.getSize(find.byType(AreaClusterMarker));
      expect(taille.width, greaterThanOrEqualTo(areaClusterMarkerSize));
      expect(taille.height, greaterThanOrEqualTo(areaClusterMarkerSize));
      expect(areaClusterMarkerSize, greaterThanOrEqualTo(44.0));
    });

    testWidgets('porte un seul nœud Semantics, préfixé par l\'échelle', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: AreaClusterMarker(cluster: _centreValDeLoireAssec()),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Écoulement : Centre-Val de Loire, '
          "15 points d'observation sur cette vue, "
          'état le plus sévère : À sec',
        ),
        findsOneWidget,
      );
      // Un seul nœud sémantique porté par la pastille : le symbole enfant
      // (`OndeMarkerPainter`) n'en ajoute aucun second — sans quoi il serait
      // annoncé séparément (`excludeSemantics`).
      final SemanticsNode racine = tester.getSemantics(
        find.byType(AreaClusterMarker),
      );
      int comptes = 0;
      racine.visitChildren((SemanticsNode enfant) {
        comptes++;
        return true;
      });
      expect(comptes, 0);
      handle.dispose();
    });

    testWidgets('compte à trois chiffres (753) sans déborder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: AreaClusterMarker(cluster: _loirEtCherDebit(count: 753)),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

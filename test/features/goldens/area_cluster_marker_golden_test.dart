// Fige le RENDU de la pastille de zone administrative (`ADR-015`, lot 4
// bis, tâche Z4), ce qu'aucun autre étage de `docs/plan-de-tests.md` § 1 ne
// sait prouver : `area_cluster_marker_test.dart` vérifie déjà le libellé
// annoncé et la taille minimale, il ne dit rien de ce qui se VOIT — que le
// symbole existant de l'état le plus sévère reste reconnaissable une fois
// entouré du badge de compte, que le losange neutre de l'échelle débit ne
// prend aucune teinte nouvelle, et qu'un compte à trois chiffres ne déborde
// pas de la pastille.
//
// ⚠️ [AreaClusterMarker] mesure déjà [areaClusterMarkerSize] (44 px) — bien
// plus que les 12 px d'une pastille de station ou d'un marqueur ONDE. Il ne
// subit donc PAS le `Transform.scale` de [caseAgrandie] (qui fixerait sa
// boîte à [stationMarkerSize], 12 px, et le tronquerait) : ces images
// posent la pastille dans une case de [coteDUneCase] à sa taille RÉELLE,
// exactement le rendu de la carte.
//
// Les images sont plateforme-dépendantes. Voir `golden_harness.dart`.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

import 'golden_harness.dart';

/// Une pastille dans une case de [coteDUneCase], à sa taille réelle — voir
/// l'en-tête de ce fichier sur pourquoi [caseAgrandie] ne convient pas ici.
Widget _case(MapAreaCluster cluster) => SizedBox(
  width: coteDUneCase,
  height: coteDUneCase,
  child: Center(child: AreaClusterMarker(cluster: cluster)),
);

void main() {
  testWidgets(
    'pastille régionale, échelle écoulement, Assec récent, compte 15',
    (WidgetTester tester) async {
      final MapAreaCluster centreValDeLoire = MapAreaCluster(
        scale: MapScaleKind.ecoulement,
        level: AreaLevel.region,
        area: const AdministrativeArea(
          code: '24',
          label: 'Centre-Val de Loire',
        ),
        latitude: 47.5,
        longitude: 1.5,
        count: 15,
        bounds: Bounds(west: 0, south: 47, east: 2, north: 48),
        severest: const Assec(),
        severestAge: CampaignAge.recente,
      );

      await pompeLImage(
        tester,
        contenu: _case(centreValDeLoire),
        taille: const Size(coteDUneCase, coteDUneCase),
      );

      await verifieLImage('area_cluster_marker_region_ecoulement_assec.png');
    },
  );

  testWidgets(
    'pastille départementale, échelle débit, losange neutre, compte 28',
    (WidgetTester tester) async {
      final MapAreaCluster loirEtCher = MapAreaCluster(
        scale: MapScaleKind.debit,
        level: AreaLevel.departement,
        area: const AdministrativeArea(code: '41', label: 'LOIR-ET-CHER'),
        latitude: 47.6,
        longitude: 1.3,
        count: 28,
        bounds: Bounds(west: 0.9, south: 47.3, east: 1.9, north: 48.1),
        severest: null,
        severestAge: null,
      );

      await pompeLImage(
        tester,
        contenu: _case(loirEtCher),
        taille: const Size(coteDUneCase, coteDUneCase),
      );

      await verifieLImage('area_cluster_marker_departement_debit_neutre.png');
    },
  );

  testWidgets('compte à trois chiffres (753, Occitanie) sans déborder', (
    WidgetTester tester,
  ) async {
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

    await pompeLImage(
      tester,
      contenu: _case(occitanie),
      taille: const Size(coteDUneCase, coteDUneCase),
    );

    await verifieLImage('area_cluster_marker_compte_trois_chiffres.png');
  });
}

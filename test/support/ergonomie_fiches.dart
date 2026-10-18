// Aides partagées des tests de la disposition de la carte (tranche
// d'ergonomie) : les fiches station (La Loire à Blois) et tronçon (Blavet aval)
// RÉELLES, et la question « la mise en page de la carte peint-elle cette
// pièce ? » (repli 6). Employées par `map_layout_invariants_test.dart`,
// `map_designation_reticle_test.dart` et, depuis `D5`, par
// `ergonomie_budget_test.dart` (les vraies fiches mesurées).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

/// La fiche station RÉELLE de La Loire à Blois, prête, avec son étoile —
/// [etoile], vide et active par défaut ; `ergonomie_budget_test.dart` y passe
/// l'étoile en échec d'écriture, le pire en-tête (spec § 6.1).
Widget ficheStationBlois({
  Key? key,
  FavoriteStar etoile = const FavoriteStar(filled: false, enabled: true),
}) {
  final StationCode code = StationCode('K447001001');
  final DateTime mesure = DateTime.utc(2026, 8, 27, 8);
  const Qualification qualification = Qualification(
    statusCode: 12,
    statusLabel: 'Pré-validée',
    qualificationCode: 20,
    qualificationLabel: 'Bonne',
  );
  return StationSheetPanel(
    key: key,
    state: Prete(
      StationSheetData(
        station: Station(
          code: code,
          label: 'La Loire à Blois',
          latitude: 47.584957074,
          longitude: 1.335147948,
          departement: DepartementCode('41'),
          riverLabel: 'la Loire',
          inService: true,
        ),
        discharge: HydroObservation(
          station: code,
          measuredAt: mesure,
          grandeur: Grandeur.debit,
          discharge: const CubicMetresPerSecond(47.8),
          level: null,
          qualification: qualification,
        ),
        level: HydroObservation(
          station: code,
          measuredAt: mesure,
          grandeur: Grandeur.hauteur,
          discharge: null,
          level: const Metres(-1.232),
          qualification: qualification,
        ),
        freshness: Freshness.fraiche,
        statusLabel: 'Pré-validée',
        qualificationLabel: 'Bonne',
        stalenessNotice: null,
      ),
    ),
    onClose: () {},
    favoriteStar: etoile,
    onToggleFavorite: () {},
    utcOffsetOf: (_) => const Duration(hours: 2),
  );
}

/// La fiche tronçon RÉELLE « Blavet aval », niveau « Jaune » : la définition
/// citée la plus longue (cas construit, niveau jamais observé en production —
/// `VC-04`), sa carte de vigilance du 17/10/2026 à 14:30 UTC — la date que
/// `mesurerPieces` fait citer à la légende Crues.
Widget ficheTronconBlavet({Key? key}) => FloodSheetPanel(
  key: key,
  state: FicheTronconOuverte(
    section: FloodSection(
      code: FloodSectionCode('TRC1'),
      name: 'Blavet aval',
      territoryCode: '12',
      level: const Jaune(),
      lines: <List<GeoPoint>>[
        <GeoPoint>[
          GeoPoint(latitude: 47.8, longitude: -3.2),
          GeoPoint(latitude: 47.9, longitude: -3.1),
        ],
      ],
    ),
    informationDate: DateTime.utc(2026, 10, 17, 14, 30),
  ),
  onClose: () {},
  onOpenBulletin: () {},
  utcOffsetOf: (_) => const Duration(hours: 2),
);

/// La mise en page de la carte ([RenderMapLayout]) peint-elle la pièce qui
/// porte [f] ? Le repli 6 retire bande et réticule : posés à taille nulle, ni
/// peints ni touchables, mais dans l'arbre. Une pièce hors de la mise en page
/// est tenue pour peinte.
bool peintParLaCarte(WidgetTester tester, Finder f) {
  RenderObject? ro = tester.renderObject(f);
  while (ro != null) {
    final RenderObject? parent = ro.parent;
    if (parent is RenderMapLayout && ro is RenderBox) {
      return parent.paintsChild(ro);
    }
    ro = parent;
  }
  return true;
}

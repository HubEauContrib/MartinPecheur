// Aides partagées des tests de la disposition de la carte (tranche
// d'ergonomie) : les fiches station (La Loire à Blois), tronçon (Blavet aval)
// et, depuis `D7`, point ONDE (K4520001) RÉELLES ; la question « la mise en
// page de la carte peint-elle cette pièce ? » (repli 6) ; et la pose d'une
// fiche seule, pour lire sa mesure mise en avant (arbitrage 18). Employées par
// `map_layout_invariants_test.dart`, `map_designation_reticle_test.dart`, par
// `ergonomie_budget_test.dart` (les vraies fiches mesurées, `D5`) et par les
// tests des trois fiches (`D7`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';
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

/// La fiche ONDE RÉELLE de « LA RIVIERE AUX LOCHES A CHAON » (K4520001, les
/// valeurs de `test/fixtures/onde/observations_station_K4520001_2026-09-13.json`
/// que `onde_summary_sheet_test.dart` recopie) : Assec du 25/08/2026, cinq
/// campagnes, le symbole de légende tel que `main.dart` le fournit. [etoile],
/// vide et active par défaut ; la porte y passe l'étoile en échec d'écriture,
/// le pire en-tête (spec § 6.1). Décision 3 de `D7` : à 200 %, son en-tête et
/// sa mesure mise en avant dépassent ceux de la station, elle entre dans la
/// matrice de la porte.
Widget ficheOndeChaon({
  Key? key,
  FavoriteStar etoile = const FavoriteStar(filled: false, enabled: true),
}) {
  final OndePoint point = OndePoint(
    code: OndeStationCode('K4520001'),
    label: 'LA RIVIERE AUX LOCHES A CHAON',
    latitude: 47.610620493,
    longitude: 2.173858157,
    waterCourseLabel: 'ruisseau la rivière aux loches',
    departement: const AdministrativeArea(code: '41', label: '41'),
  );
  OndeObservation campagne(DateTime date, String code, String libelle) =>
      OndeObservation(
        station: point.code,
        point: point,
        observedAt: date,
        category: flowCategoryFromCode(code),
        rawFlowCode: code,
        officialLabel: libelle,
        campaignCode: '1',
      );
  final List<OndeObservation> campagnes = <OndeObservation>[
    campagne(DateTime.utc(2026, 8, 25), '3', 'Assec'),
    campagne(DateTime.utc(2026, 7, 24), '3', 'Assec'),
    campagne(DateTime.utc(2026, 6, 26), '2', 'Ecoulement non visible'),
    campagne(DateTime.utc(2026, 5, 26), '1a', 'Ecoulement visible acceptable'),
    campagne(DateTime.utc(2025, 9, 26), '1f', 'Ecoulement visible faible'),
  ];
  return OndeSheetPanel(
    key: key,
    state: OndeSheetPrete(
      OndeSheetData(
        point: point,
        latest: campagnes.first,
        history: List<OndeObservation>.unmodifiable(campagnes),
        age: CampaignAge.recente,
        ageInDays: 19,
        officialModalityText: 'code 3 — Assec',
        seasonNotice: ondeSeasonNotice,
      ),
    ),
    onClose: () {},
    favoriteStar: etoile,
    onToggleFavorite: () {},
    categorySymbol: (FlowCategory category, {required bool compact}) =>
        ExcludeSemantics(
          child: OndeMarkerShape(
            category: category,
            age: CampaignAge.recente,
            observedAt: null,
            compact: compact,
          ),
        ),
  );
}

/// [fiche] posée seule, [largeur] de large, le texte à [echelle] : sans borne
/// de hauteur, ou sous une hauteur maximale de [hauteur] (comme la fiche du
/// bas). Rend le rectangle de son cadre (`SheetFrame`) et sa hauteur mise en
/// avant (`sheetFeaturedHeightOf`, arbitrage 18), lue à [largeur].
Future<({Rect cadre, double vedette})> poserFiche(
  WidgetTester tester,
  Widget fiche, {
  required double largeur,
  double echelle = 1,
  double? hauteur,
}) async {
  tester.view.physicalSize = const Size(2400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Widget posee = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: largeur,
      child: hauteur == null
          ? fiche
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: hauteur),
              child: fiche,
            ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(2400, 4000),
          textScaler: TextScaler.linear(echelle),
        ),
        child: Scaffold(
          body: hauteur == null ? SingleChildScrollView(child: posee) : posee,
        ),
      ),
    ),
  );
  return (
    cadre: tester.getRect(find.byType(SheetFrame)),
    vedette: sheetFeaturedHeightOf(
      tester.renderObject<RenderBox>(find.byType(SheetFrame)),
      largeur,
    ),
  );
}

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

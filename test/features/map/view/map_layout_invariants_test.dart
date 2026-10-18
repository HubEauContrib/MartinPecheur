// Les invariants de la disposition de la carte (`D2` d'Ergonomie, R15 ; spec
// § 1, critère 2, et § 9, critères 1, 3, 4, 7 et 8) : ils REMPLACENT les
// mesures au pixel de l'ancienne disposition — `map_overlays_phone_test.dart`,
// `map_sheet_height_test.dart`, `map_entry_buttons_overlap_test.dart`, leurs
// « CONSTAT » compris — par ce qui doit tenir quelle que soit la hauteur des
// pièces.
//
// La matrice est celle de la porte de faisabilité (`S6`,
// `ergonomie_budget_test.dart`) : les quatre tailles garanties, les deux
// échelles de texte, les trois lectures, hors mode et en mode « Restrictions »,
// sans fiche, avec la fiche station de Blois, la fiche tronçon et, depuis
// `D7` (décision 3), la fiche ONDE de Chaon (les vraies), sans avis et avec un
// avis, sans marge système et — au téléphone — avec la marge d'un téléphone :
// 576 configurations. L'avis est celui que la
// carte pose pour la lecture : l'avis d'absence de l'écoulement (« ni station
// ni point »), celui du débit (« ni station »), et sur la lecture Crues, dont
// l'avis d'absence ne porte aucune action, l'avis d'échec qui porte
// « Réessayer » — pour que l'action de l'avis (I-h) s'éprouve sur les trois.
//
// Chaque configuration est montée sur la VRAIE `buildMapOverlays`, dans un
// `Stack` posé sur une carte témoin, en ROBOTO (`chargerRoboto`) :
// - I-a : le sélecteur entier dans la zone sûre, le centre de chaque entrée
//   atteignable (toucher) ;
// - I-b : le « ⚠ Avertissement » de la carte entier et atteignable ;
// - I-d : l'entrée « Restrictions » atteignable ;
//   là où la partie fixe du bloc défile — à 360 × 640 et 200 % (arbitrage
//   13), et fiche du bas ouverte, là où la fiche n'aurait plus sa mesure mise
//   en avant (arbitrages 18 et 19) —, ces trois-là s'atteignent en la faisant
//   défiler (le focus les amène en vue) ;
// - I-c : en mode, le réticule entier dans la zone sûre, là où le rapport le
//   dit, sans aucun élément PEINT qui le recoupe (pièces du bloc, boutons du
//   bas, attribution, pilule, indice, fiche), et le bouton atteignable — sauf
//   quand le rapport dit le repli 6 (`bandWithdrawn`) : bande et réticule ni
//   peints, ni touchables, ni focalisables (Tab ne s'arrête pas sur le
//   bouton, Entrée ne désigne pas) ;
// - I-e : l'en-tête de la fiche entier, dans la fiche et dans la zone sûre
//   (`D5` : il ne cède jamais, seul le corps défile) ; la fiche ne recoupe ni
//   le bloc ni le bas ; la fiche du bas est posée au bas de la zone sûre, son
//   fond blanc prolongé jusqu'au bord de l'écran (spec § 6.5), sa mesure
//   mise en avant entière, sauf la partie fixe à son plancher, une cible
//   tactile, sous lequel elle ne descend jamais (arbitrages 18 et 19, `D7`) ;
//   le panneau latéral à droite, sur toute la hauteur ;
// - I-f : aucune erreur de rendu ;
// - I-g : les replis joués (le rapport de la mise en page) et la hauteur de la
//   fiche sont ceux que `allocateMapLayout(await mesurerPieces(...))` rend, à
//   toutes les configurations — fiche ouverte comprise depuis `D5`, la mesure
//   montant alors la vraie fiche (`ficheReelle`) ;
// - I-h : avec un avis, son action atteignable, au besoin en faisant défiler
//   les avis — sauf en mode, fiche du bas ouverte, là où l'avis s'efface pour
//   que le réticule ne bouge pas (arbitrages 15 et 16) ;
// - I-j : les éléments PEINTS — pièces du bloc, boutons et attribution du
//   bas, pilule et indice de la bande, fiche — ne se recoupent pas deux à
//   deux (rectangles des éléments, jamais les boîtes de la rangée ou de la
//   bande) ;
// - le critère 3 (spec § 9) : la rangée au téléphone, la colonne dès 600 px,
//   l'attribution dessous, le bas posé à sa hauteur entière ;
// - le panneau latéral (spec § 6.5) : son filet se voit, au pixel, à côté de
//   la fiche ; franchir 800 px de large ne recrée pas la fiche ouverte ;
// - la FIXITÉ du réticule (arbitrage 15) : en mode, la même configuration
//   montée sans avis puis avec, réticule identique ;
// - I-i : sur la vraie `MapView`, un tap, un glisser et un cran de molette
//   posés sur la carte visible hors des pièces atteignent la carte ; le fond
//   du bloc, lui, absorbe les gestes (`B1`) : I-i les éprouve hors du bloc ;
// - Review Focus 3 : à 360 × 640 et 390 × 844, fiche station ouverte,
//   l'échelle du texte passe de 200 % à 100 % puis revient : aucune erreur,
//   la fiche reste ouverte, les sous-titres suivent la répartition (à
//   390 × 844, ils reviennent puis repartent ; à 360 × 640, repliés aux deux
//   échelles, arbitrage 17), le rapport ne change qu'une fois par changement
//   d'échelle ;
// - l'ordre de tabulation au téléphone (`K1` de T3, spec § 5.7), sur la
//   rangée du bas.
//
// Un cas qui affirme plusieurs invariants les vérifie TOUS et nomme, dans son
// échec, chacun de ceux qui ne tiennent pas (« I-a : … ») : le décompte des
// rouges par invariant se lit dans la sortie.
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show warningLinkLabel;
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart'
    show floodBulletinButtonKey;
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_bottom.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view/map_sheet_area.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart'
    show ondeCategoryTileKey;
import 'package:martinpecheur/features/shared/favorite_star_button.dart'
    show FavoriteStarButton;
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show
        SheetFrame,
        sheetFeaturedHeightOf,
        sheetFrameBodyKey,
        sheetFrameHeaderKey;
import 'package:martinpecheur/features/shared/tap_target.dart'
    show minimumTapTarget;
import 'package:martinpecheur/features/shared/warning_link.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_fiches.dart';
import '../../../support/ergonomie_mesures.dart';
import '../../../support/focus.dart';
import '../../../support/layout_sizes.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

// --- Les configurations -------------------------------------------------------

/// La fiche ouverte d'une configuration. La fiche ONDE y entre avec `D7`
/// (décision 3), comme dans la porte.
enum _Fiche { aucune, station, troncon, onde }

/// Une configuration de la matrice (voir l'en-tête).
final class _Config {
  const _Config({
    required this.nomTaille,
    required this.taille,
    required this.plateforme,
    required this.echelle,
    required this.lecture,
    required this.enMode,
    required this.fiche,
    required this.avecAvis,
    required this.marge,
  });

  final String nomTaille;
  final Size taille;
  final TargetPlatform plateforme;
  final double echelle;
  final MapScaleKind lecture;
  final bool enMode;
  final _Fiche fiche;
  final bool avecAvis;
  final bool marge;

  _Config avec({bool? avecAvis, double? echelle}) => _Config(
    nomTaille: nomTaille,
    taille: taille,
    plateforme: plateforme,
    echelle: echelle ?? this.echelle,
    lecture: lecture,
    enMode: enMode,
    fiche: fiche,
    avecAvis: avecAvis ?? this.avecAvis,
    marge: marge,
  );

  EdgeInsets get insets => marge ? margeSystemeTelephone : EdgeInsets.zero;

  MapLayoutWidth get largeur => mapLayoutWidthFor(taille.width);

  /// La fiche est posée au bas de l'écran (sous 800 px), pas en panneau.
  bool get ficheDuBas =>
      fiche != _Fiche.aucune &&
      switch (largeur) {
        MapLayoutWidth.compact || MapLayoutWidth.wide => true,
        MapLayoutWidth.panel => false,
      };

  /// Où la partie fixe du bloc peut défiler (la porte, `ergonomie_budget_test`,
  /// le dit du même) : à 360 × 640 et 200 % (arbitrage 13) ; à 200 %, fiche
  /// du bas ouverte (arbitrages 18 et 19) ; à 100 %, seulement à 360 × 640,
  /// fiche station, sous la marge système (arbitrage 19 — avec l'avis d'échec
  /// d'écriture, que ces cas ne posent pas).
  bool get defileAccepte =>
      (taille == const Size(360, 640) && echelle == 2) ||
      (ficheDuBas && echelle == 2) ||
      (taille == const Size(360, 640) &&
          echelle == 1 &&
          fiche == _Fiche.station &&
          marge);

  bool get android => switch (plateforme) {
    TargetPlatform.android => true,
    _ => false,
  };

  /// Le nom de la configuration, celui de `ergonomie_budget_test.dart`.
  String get nom =>
      '$nomTaille, ${(echelle * 100).round()} %, ${_nomLecture(lecture)}, '
      '${enMode ? 'en mode' : 'hors mode'}, ${_nomFiche(fiche)}, '
      '${avecAvis ? 'avis' : 'sans avis'}, ${marge ? 'marge' : 'sans marge'}';
}

String _nomLecture(MapScaleKind lecture) => switch (lecture) {
  MapScaleKind.ecoulement => 'écoulement',
  MapScaleKind.debit => 'débit',
  MapScaleKind.crues => 'crues',
};

String _nomFiche(_Fiche fiche) => switch (fiche) {
  _Fiche.aucune => 'sans fiche',
  _Fiche.station => 'fiche station',
  _Fiche.troncon => 'fiche tronçon',
  _Fiche.onde => 'fiche ONDE',
};

/// La matrice entière, dans l'ordre de `ergonomie_budget_test.dart`.
List<_Config> _matrice() => <_Config>[
  for (final ({String nom, Size taille, TargetPlatform plateforme}) t
      in taillesGaranties)
    for (final double echelle in echellesDeTexte)
      for (final MapScaleKind lecture in MapScaleKind.values)
        for (final bool enMode in <bool>[false, true])
          for (final _Fiche fiche in _Fiche.values)
            for (final bool avecAvis in <bool>[false, true])
              for (final bool marge in <bool>[
                false,
                if (switch (t.plateforme) {
                  TargetPlatform.android => true,
                  _ => false,
                })
                  true,
              ])
                _Config(
                  nomTaille: t.nom,
                  taille: t.taille,
                  plateforme: t.plateforme,
                  echelle: echelle,
                  lecture: lecture,
                  enMode: enMode,
                  fiche: fiche,
                  avecAvis: avecAvis,
                  marge: marge,
                ),
];

/// Déclare un cas sur la plateforme de [c] : « Android : » en tête au
/// téléphone (convention du projet).
void _cas(
  _Config c,
  String invariants,
  Future<void> Function(WidgetTester tester) corps,
) {
  final String titre = '${c.nom} — $invariants';
  if (c.android) {
    testWidgetsOnAndroid('Android : $titre', corps);
  } else {
    testWidgetsOnWindows(titre, corps);
  }
}

// --- Les données de la carte et des fiches ------------------------------------

/// Une station et un point ONDE : la carte n'est pas vide, aucun avis.
StationPoint _uneStation() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074484784,
  longitude: 1.3351479476905552,
);

Map<OndeStationCode, OndeObservation> _uneObservation() {
  final OndePoint point = OndePoint(
    code: OndeStationCode('04170001'),
    label: 'Le Trey à Vilcey-sur-Trey',
    latitude: 48.885312,
    longitude: 6.023145,
    waterCourseLabel: 'Le Trey',
    departement: const AdministrativeArea(code: '54', label: '54'),
  );
  return <OndeStationCode, OndeObservation>{
    point.code: OndeObservation(
      station: point.code,
      point: point,
      observedAt: DateTime.utc(2026, 8, 25),
      category: const Assec(),
      rawFlowCode: '3',
      officialLabel: 'Assec',
      campaignCode: '1',
    ),
  };
}

/// La date de la carte de vigilance que cite la légende Crues : la légende
/// la plus haute est celle qui la cite (arbitrage 9 de T4). La même que
/// `mesurerPieces`.
final DateTime _dateCrues = DateTime.utc(2026, 10, 17, 14, 30);

/// L'avis de la lecture Crues quand un avis est demandé : l'avis d'échec
/// « illisible », qui porte « Réessayer ».
const MapNotice _avisCrues = FloodUnreadable();

/// L'avis que la carte pose pour [lecture] quand le secteur est vide (ou, sur
/// Crues, quand la lecture échoue), tel que `buildMapOverlays` le bâtit.
Widget _avisDe(MapScaleKind lecture) => buildMapNotice(
  switch (lecture) {
    MapScaleKind.ecoulement => const NoDataInArea(),
    MapScaleKind.debit => const NoStationInArea(),
    MapScaleKind.crues => _avisCrues,
  },
  onWiden: () {},
  onClearFilters: () {},
  onRetryFlood: () {},
);

/// La clé de l'action de l'avis de [lecture].
Key _actionDe(MapScaleKind lecture) => switch (lecture) {
  MapScaleKind.ecoulement || MapScaleKind.debit => widenSearchKey,
  MapScaleKind.crues => floodRetryKey,
};

const Key _ficheStationKey = Key('invariants-fiche-station');
const Key _ficheOndeKey = Key('invariants-fiche-onde');
const Key _ficheTronconKey = Key('invariants-fiche-troncon');
const Key _temoinKey = Key('invariants-carte-temoin');

/// La fiche tronçon RÉELLE (`ficheTronconBlavet`), sous la clé des cas.
Widget _ficheTroncon() => ficheTronconBlavet(key: _ficheTronconKey);

// --- Le montage ---------------------------------------------------------------

/// Ce que le montage d'une configuration rend au cas.
final class _Ecran {
  _Ecran(this.rapport, this.erreurs);

  final ValueNotifier<MapLayoutReport?> rapport;
  final List<FlutterErrorDetails> erreurs;
  int designations = 0;
  int tapsTemoin = 0;
}

/// Monte [c] sur la vraie `buildMapOverlays`, au-dessus d'une carte témoin,
/// et laisse la mise en page publier son rapport. [echelle], si fourni, est
/// l'écoute de l'échelle du texte (Review Focus 3).
Future<_Ecran> _monter(
  WidgetTester tester,
  _Config c, {
  ValueNotifier<double>? echelle,
}) async {
  tester.view.physicalSize = c.taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ValueNotifier<MapLayoutReport?> rapport =
      ValueNotifier<MapLayoutReport?>(null);
  addTearDown(rapport.dispose);
  final _Ecran ecran = _Ecran(rapport, <FlutterErrorDetails>[]);

  final Widget surcouches = Scaffold(
    body: FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              key: _temoinKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => ecran.tapsTemoin++,
              child: const SizedBox.expand(),
            ),
          ),
          ...buildMapOverlays(
            scale: c.lecture,
            onSelect: (MapScaleKind _) {},
            onWiden: () {},
            error: null,
            stations: c.avecAvis
                ? const <StationPoint>[]
                : <StationPoint>[_uneStation()],
            ondeObservations: c.avecAvis
                ? const <OndeStationCode, OndeObservation>{}
                : _uneObservation(),
            ondeUnreadableRows: 0,
            filterHidesEverything: false,
            onClearFilters: () {},
            filterActive: false,
            onOpenFilters: () {},
            onZoomIn: () {},
            onZoomOut: () {},
            onRecenter: () {},
            onDesignateCenter: c.enMode ? () => ecran.designations++ : null,
            onToggleDesignationMode: () {},
            // Comme `main.dart` : les trois panneaux toujours fournis, vides
            // à l'état fermé.
            stationSheet: switch (c.fiche) {
              _Fiche.station => ficheStationBlois(key: _ficheStationKey),
              _Fiche.aucune ||
              _Fiche.troncon ||
              _Fiche.onde => const SizedBox.shrink(),
            },
            ondeSheet: switch (c.fiche) {
              _Fiche.onde => ficheOndeChaon(key: _ficheOndeKey),
              _Fiche.aucune ||
              _Fiche.station ||
              _Fiche.troncon => const SizedBox.shrink(),
            },
            floodSheet: switch (c.fiche) {
              _Fiche.troncon => _ficheTroncon(),
              _Fiche.aucune ||
              _Fiche.station ||
              _Fiche.onde => const SizedBox.shrink(),
            },
            onOpenFavorites: () {},
            floodNotices: c.avecAvis
                ? const <MapNotice>[_avisCrues]
                : const <MapNotice>[],
            onRetryFlood: () {},
            floodInformationDate: _dateCrues,
            layoutReport: rapport,
          ),
        ],
      ),
    ),
  );

  MediaQueryData donnees(double e) => MediaQueryData(
    size: c.taille,
    textScaler: TextScaler.linear(e),
    padding: c.insets,
    viewPadding: c.insets,
  );

  final void Function(FlutterErrorDetails)? avant = FlutterError.onError;
  FlutterError.onError = ecran.erreurs.add;
  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: echelle == null
            ? MediaQuery(data: donnees(c.echelle), child: surcouches)
            : ValueListenableBuilder<double>(
                valueListenable: echelle,
                builder: (BuildContext context, double e, Widget? child) =>
                    MediaQuery(data: donnees(e), child: child!),
                child: surcouches,
              ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = avant;
  }
  return ecran;
}

// --- Les vérifications ----------------------------------------------------------

/// Les invariants en échec d'un cas, chacun nommé.
final class _Echecs {
  final List<String> _lignes = <String>[];

  /// Vérifie [verification] au nom de [invariant] ; un échec est noté, la
  /// suite du cas continue.
  Future<void> verifier(
    String invariant,
    Future<void> Function() verification,
  ) async {
    try {
      await verification();
    } on TestFailure catch (echec) {
      _lignes.add('$invariant : ${echec.message?.trim()}');
    }
  }

  void conclure() {
    if (_lignes.isNotEmpty) {
      fail(_lignes.join('\n---\n'));
    }
  }
}

const double _tolerance = 0.5;

/// La zone sûre de [c].
Rect _zoneSure(_Config c) => Rect.fromLTRB(
  c.insets.left,
  c.insets.top,
  c.taille.width - c.insets.right,
  c.taille.height - c.insets.bottom,
);

void _dedans(Rect r, Rect zone, String quoi) {
  expect(
    r.left >= zone.left - _tolerance &&
        r.top >= zone.top - _tolerance &&
        r.right <= zone.right + _tolerance &&
        r.bottom <= zone.bottom + _tolerance,
    isTrue,
    reason: '$quoi $r sort de $zone',
  );
}

/// Deux rectangles se recoupent de plus d'un demi-pixel dans les deux sens.
bool _recoupe(Rect a, Rect b) {
  final Rect i = a.intersect(b);
  return i.width > _tolerance && i.height > _tolerance;
}

bool _present(Finder f) => f.evaluate().isNotEmpty;

void _atteignable(Finder f, String quoi) {
  expect(
    f.hitTestable().evaluate().isNotEmpty,
    isTrue,
    reason: '$quoi : son centre n’est pas atteignable au toucher',
  );
}

/// La couleur peinte au pixel [global] (densité 1) : l'image de la plus proche
/// frontière de peinture qui enveloppe la zone des fiches.
Future<Color> _pixel(WidgetTester tester, Offset global) async {
  RenderObject? ro = tester.renderObject(find.byKey(mapSheetAreaKey));
  while (ro != null && ro is! RenderRepaintBoundary) {
    ro = ro.parent;
  }
  final RenderRepaintBoundary frontiere = ro! as RenderRepaintBoundary;
  final Offset local = frontiere.globalToLocal(global);
  final Color? couleur = await tester.runAsync(() async {
    final ui.Image image = await frontiere.toImage();
    final ByteData? octets = await image.toByteData();
    final int x = local.dx.floor();
    final int y = local.dy.floor();
    final int i = (y * image.width + x) * 4;
    final Color lue = Color.fromARGB(
      octets!.getUint8(i + 3),
      octets.getUint8(i),
      octets.getUint8(i + 1),
      octets.getUint8(i + 2),
    );
    image.dispose();
    return lue;
  });
  return couleur!;
}

/// Un toucher posé en [p] atteint-il l'objet de [f] ?
bool _toucheEn(WidgetTester tester, Finder f, Offset p) {
  final RenderObject cible = tester.renderObject(f);
  final HitTestResult resultat = HitTestResult();
  tester.binding.hitTestInView(resultat, p, tester.view.viewId);
  return resultat.path.any((HitTestEntry e) => identical(e.target, cible));
}

/// Le « ⚠ Avertissement » de la carte : celui qui n'est pas dans une fiche.
Finder _lienDeLaCarte() => find.byElementPredicate((Element e) {
  if (e.widget is! WarningLink) return false;
  bool dansUneFiche = false;
  e.visitAncestorElements((Element a) {
    final Widget w = a.widget;
    if (w is SheetFrame) {
      dansUneFiche = true;
      return false;
    }
    return true;
  });
  return !dansUneFiche;
}, description: 'le « ⚠ Avertissement » de la carte');

Finder _entree(MapScaleKind kind) => find.byKey(ValueKey<MapScaleKind>(kind));

/// Les entrées du sélecteur, avec leur nom.
Map<String, Finder> _entrees() => <String, Finder>{
  for (final MapScaleKind kind in MapScaleKind.values)
    'entrée ${_nomLecture(kind)}': _entree(kind),
  'entrée Restrictions': find.byKey(mapDesignationChipKey),
};

/// La fiche ouverte : la zone des fiches (fiche du bas ou panneau latéral).
/// Elle doit être posée — une zone absente fait échouer le cas.
Finder _fiche(WidgetTester tester) {
  final Finder zone = find.byKey(mapSheetAreaKey);
  expect(zone, findsOneWidget, reason: 'la zone des fiches est posée');
  return zone;
}

/// L'élément qui finit la mesure mise en avant de la fiche de [c] (arbitrage
/// 18) : la tuile Débit, la tuile de la catégorie, la rangée du niveau.
Finder _mesureMiseEnAvant(_Config c) {
  Finder dansLaFiche(Finder f) =>
      find.descendant(of: find.byKey(mapSheetAreaKey), matching: f);
  return switch (c.fiche) {
    _Fiche.station => dansLaFiche(find.byKey(stationDischargeTileKey)),
    _Fiche.onde => dansLaFiche(find.byKey(ondeCategoryTileKey)),
    _Fiche.troncon =>
      find
          .ancestor(
            of: dansLaFiche(find.byType(FloodLevelGauge)),
            matching: find.byType(Row),
          )
          .first,
    _Fiche.aucune => throw StateError('aucune fiche ouverte'),
  };
}

/// Le rapport dit-il l'indice replié (repli 5) ?
bool _indiceReplie(_Ecran e) => e.rapport.value?.allocation.hintFolded ?? false;

/// Les pièces du BLOC qui se peignent : chacune peint la carte blanche sur sa
/// boîte, et une pièce à hauteur nulle ne peint rien. Les trois pièces sont
/// toujours posées : une pièce absente fait échouer le cas.
Map<String, Rect> _bloc(WidgetTester tester) {
  final Map<String, Rect> rects = <String, Rect>{};
  for (final (String, Finder) piece in <(String, Finder)>[
    ('partie fixe du bloc', find.byType(MapReadingBlockFixed)),
    ('avis du bloc', find.byType(MapReadingBlockNotices)),
    ('légende du bloc', find.byType(MapReadingBlockLegend)),
  ]) {
    expect(piece.$2, findsOneWidget, reason: '${piece.$1} posée');
    final Rect r = tester.getRect(piece.$2);
    if (r.width > _tolerance && r.height > _tolerance) rects[piece.$1] = r;
  }
  return rects;
}

/// La fenêtre du défilement de la colonne du bas, ou `null` : la rangée, ou
/// pas de bas. En deçà des quatre tailles, la colonne cède en faisant défiler
/// ses boutons au-dessus de l'attribution (arbitrage 24, `D8`).
Rect? _fenetreDuBas(WidgetTester tester) {
  final Finder defilement = find.descendant(
    of: find.byType(MapBottom),
    matching: find.byType(Scrollable),
  );
  return _present(defilement) ? tester.getRect(defilement.first) : null;
}

/// Les éléments PEINTS du bas de la carte : les cinq boutons et l'attribution
/// — d'un bouton de la colonne, la part qui se voit dans la fenêtre de son
/// défilement (rien, s'il a défilé hors d'elle : il n'y est pas peint).
Map<String, Rect> _bas(WidgetTester tester) {
  final Rect? fenetre = _fenetreDuBas(tester);
  Rect vu(Rect r) => fenetre == null ? r : r.intersect(fenetre);
  return <String, Rect>{
    for (final (String, Finder) p in <(String, Finder)>[
      ('Favoris', find.byKey(mapFavoritesButtonKey)),
      ('Filtres', find.byKey(mapFiltersButtonKey)),
      ('−', find.byKey(mapZoomOutButtonKey)),
      ('+', find.byKey(mapZoomInButtonKey)),
      ('recentrer', find.byKey(mapRecenterButtonKey)),
    ])
      if (_present(p.$2) &&
          vu(tester.getRect(p.$2)).width > 0 &&
          vu(tester.getRect(p.$2)).height > 0)
        p.$1: vu(tester.getRect(p.$2)),
    if (_present(find.byType(IgnAttributionBadge)))
      'attribution': tester.getRect(find.byType(IgnAttributionBadge)),
  };
}

/// Les éléments PEINTS de la bande du bouton : la pilule, et l'indice s'il
/// n'est pas replié.
Map<String, Rect> _bande(WidgetTester tester, _Ecran e) => <String, Rect>{
  if (_present(find.byKey(mapDesignateCenterButtonKey)))
    'pilule': tester.getRect(find.byKey(mapDesignateCenterButtonKey)),
  if (_present(find.byKey(mapDesignateCenterHintKey)) && !_indiceReplie(e))
    'indice': tester.getRect(find.byKey(mapDesignateCenterHintKey)),
};

/// Amène [f] en vue en faisant défiler ses défilements (comme le focus le
/// fait), puis laisse la trame se poser.
Future<void> _amener(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

// --- I-a, I-b, I-d ----------------------------------------------------------------

Future<void> _verifierAtteignables(
  WidgetTester tester,
  _Config c,
  _Ecran e,
  _Echecs echecs,
) async {
  final Rect zone = _zoneSure(c);
  // Les arbitrages 13, 18 et 19 : là seulement, la partie fixe défile ; ses contrôles
  // s'atteignent en la faisant défiler.
  final bool defile =
      c.defileAccepte && (e.rapport.value?.allocation.overflows ?? false);

  await echecs.verifier('I-a', () async {
    if (!defile) {
      final List<Rect> rects = <Rect>[
        for (final Finder f in _entrees().values) tester.getRect(f),
      ];
      final Rect selecteur = rects.reduce(
        (Rect a, Rect b) => a.expandToInclude(b),
      );
      _dedans(selecteur, zone, 'le sélecteur');
    }
    for (final MapEntry<String, Finder> entree in _entrees().entries) {
      if (defile) await _amener(tester, entree.value);
      _dedans(tester.getRect(entree.value), zone, entree.key);
      _atteignable(entree.value, entree.key);
    }
  });
  await echecs.verifier('I-b', () async {
    final Finder lien = _lienDeLaCarte();
    expect(lien, findsOneWidget, reason: 'le « ⚠ Avertissement » de la carte');
    if (defile) await _amener(tester, lien);
    _dedans(tester.getRect(lien), zone, '« ⚠ Avertissement »');
    _atteignable(lien, '« ⚠ Avertissement »');
  });
  await echecs.verifier('I-d', () async {
    final Finder restrictions = find.byKey(mapDesignationChipKey);
    if (defile) await _amener(tester, restrictions);
    _atteignable(restrictions, 'l’entrée « Restrictions »');
  });
  await echecs.verifier('I-f', () async {
    expect(
      e.erreurs,
      isEmpty,
      reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
    );
  });
}

// --- I-c, I-e, I-f ------------------------------------------------------------------

Future<void> _verifierReticuleEtFiche(
  WidgetTester tester,
  _Config c,
  _Ecran e,
  _Echecs echecs,
) async {
  final Rect zone = _zoneSure(c);
  final MapLayoutReport? rapport = e.rapport.value;

  if (c.enMode) {
    await echecs.verifier('I-c', () async {
      expect(
        rapport,
        isNotNull,
        reason: 'la mise en page n’a publié aucun rapport',
      );
      if (rapport!.allocation.bandWithdrawn) {
        // Repli 6 : ni peints, ni touchables, ni focalisables.
        expect(rapport.reticle, isNull, reason: 'réticule retiré au rapport');
        final Finder pilule = find.byKey(mapDesignateCenterButtonKey);
        expect(
          peintParLaCarte(tester, pilule),
          isFalse,
          reason: 'bande peinte',
        );
        expect(
          peintParLaCarte(tester, find.byKey(mapCenterReticleKey)),
          isFalse,
          reason: 'réticule peint',
        );
        expect(pilule.hitTestable(), findsNothing, reason: 'bouton touchable');
        // Ni annoncé (`D3` : la bande retirée est exclue des annonces).
        // Contrôle positif : l'arbre des annonces est bien construit — l'entrée
        // « Restrictions » y est.
        final SemanticsHandle annonces = tester.ensureSemantics();
        await tester.pump();
        expect(
          find.bySemanticsLabel('Restrictions au centre de la carte'),
          findsNothing,
          reason: 'bouton retiré annoncé',
        );
        expect(
          tester.getSemantics(find.byKey(mapDesignationChipKey)).label,
          isNotEmpty,
          reason: 'l’entrée « Restrictions » n’est pas annoncée',
        );
        annonces.dispose();
        // Tab ne s'arrête jamais sur le bouton ; Entrée ne désigne pas.
        // Contrôle positif : la tabulation circule (elle atteint l'entrée
        // « Restrictions »).
        bool surRestrictions = false;
        for (int i = 0; i < 24; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, pilule),
            isFalse,
            reason: 'Tab s’arrête sur le bouton retiré',
          );
          surRestrictions |= focusedWithin(
            tester,
            find.byKey(mapDesignationChipKey),
          );
        }
        expect(surRestrictions, isTrue, reason: 'Tab ne circule pas');
        // Le nœud du bouton LUI-MÊME (celui de son `KeyboardFocusRing`) :
        // demandé, il ne prend pas le focus, et Entrée ne désigne rien.
        final FocusNode? noeud = tester
            .widget<Focus>(
              find.descendant(of: pilule, matching: find.byType(Focus)).first,
            )
            .focusNode;
        expect(noeud, isNotNull, reason: 'le bouton porte son nœud de focus');
        noeud!.requestFocus();
        await tester.pump();
        expect(
          noeud.hasPrimaryFocus,
          isFalse,
          reason: 'le bouton retiré prend le focus',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(e.designations, 0, reason: 'Entrée a désigné');
        return;
      }
      final Finder reticule = find.byKey(mapCenterReticleKey);
      expect(reticule, findsOneWidget);
      final Rect r = tester.getRect(reticule);
      _dedans(r, zone, 'le réticule');
      final Rect? publie = rapport.reticle;
      expect(publie, isNotNull, reason: 'réticule absent du rapport');
      expect(
        (r.center - publie!.center).distance,
        lessThan(_tolerance),
        reason: 'réticule $r, rapport $publie',
      );
      final Map<String, Rect> peints = <String, Rect>{
        ..._bloc(tester),
        ..._bas(tester),
        ..._bande(tester, e),
        if (c.fiche != _Fiche.aucune) 'fiche': tester.getRect(_fiche(tester)),
      };
      final List<String> dessus = <String>[
        for (final MapEntry<String, Rect> p in peints.entries)
          if (_recoupe(p.value, r)) '${p.key} ${p.value}',
      ];
      expect(dessus, isEmpty, reason: 'recoupent le réticule $r');
      _atteignable(
        find.byKey(mapDesignateCenterButtonKey),
        'le bouton « Restrictions au centre de la carte »',
      );
    });
  }

  await echecs.verifier('I-e', () async {
    if (c.fiche == _Fiche.aucune) return;
    final Rect fiche = tester.getRect(_fiche(tester));
    // `D5` : l'en-tête de la fiche — nature, étoile, fermeture,
    // « ⚠ Avertissement » — ne cède jamais (spec § 5.6, § 6.1) ; seul le
    // corps défile. Il est donc entier, dans la fiche et dans la zone sûre, à
    // toutes les configurations : la fiche est visible partout.
    final Rect enTete = tester.getRect(
      find.descendant(
        of: _fiche(tester),
        matching: find.byKey(sheetFrameHeaderKey),
      ),
    );
    expect(enTete.height, greaterThan(0), reason: 'l’en-tête de la fiche');
    _dedans(enTete, fiche, 'l’en-tête de la fiche (dans la fiche)');
    _dedans(enTete, zone, 'l’en-tête de la fiche');
    final Map<String, Rect> autres = <String, Rect>{
      ..._bloc(tester),
      ..._bas(tester),
    };
    final List<String> recoupes = <String>[
      for (final MapEntry<String, Rect> p in autres.entries)
        if (_recoupe(p.value, fiche)) '${p.key} ${p.value}',
    ];
    expect(recoupes, isEmpty, reason: 'la fiche $fiche recoupe');
    if (c.ficheDuBas) {
      expect(
        fiche.bottom,
        moreOrLessEquals(zone.bottom, epsilon: _tolerance),
        reason: 'la fiche du bas $fiche n’est pas au bas de la zone sûre',
      );
      // Arbitrages 18 et 19 : la fiche du bas montre sa mesure mise en avant
      // entière — son corps à son haut, comme à l'ouverture —, sauf là où la
      // partie fixe du bloc est descendue à son plancher, une cible tactile ;
      // elle n'y descend jamais plus bas.
      final MapLayoutAllocation repartition = rapport!.allocation;
      final double vedette = sheetFeaturedHeightOf(
        tester.renderObject<RenderBox>(_fiche(tester)),
        fiche.width,
      );
      final double plancher = minimumTapTarget;
      expect(
        repartition.blockFixed,
        greaterThanOrEqualTo(plancher - _tolerance),
        reason: 'la partie fixe sous son plancher ($repartition)',
      );
      if (repartition.sheet >= vedette - _tolerance) {
        final Rect mesure = tester.getRect(_mesureMiseEnAvant(c));
        expect(
          mesure.bottom,
          lessThanOrEqualTo(fiche.bottom + _tolerance),
          reason: 'la mesure mise en avant $mesure sort de la fiche $fiche',
        );
      } else {
        expect(
          repartition.blockFixed,
          moreOrLessEquals(plancher, epsilon: _tolerance),
          reason:
              'la fiche sous sa mesure mise en avant ($vedette), la partie '
              'fixe au-dessus de son plancher ($repartition)',
        );
      }
      expect(fiche.left, moreOrLessEquals(zone.left, epsilon: _tolerance));
      expect(fiche.right, moreOrLessEquals(zone.right, epsilon: _tolerance));
      // Spec § 6.5, « au bas de l'écran » : le fond blanc de la fiche du bas
      // se prolonge sous la marge système basse (et les marges latérales),
      // jusqu'au bord de l'écran ; son contenu reste dans la zone sûre.
      if (fiche.height > _tolerance) {
        final RenderObject fond = tester.renderObject(
          find
              .descendant(
                of: find.byKey(mapSheetAreaKey),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(
          fond,
          paints..rect(
            rect: Rect.fromLTRB(
              -c.insets.left,
              0,
              fiche.width + c.insets.right,
              fiche.height + c.insets.bottom,
            ),
            color: Colors.white,
          ),
          reason: 'le fond de la fiche du bas ne va pas au bord de l’écran',
        );
      }
    } else {
      expect(
        fiche.right,
        moreOrLessEquals(zone.right, epsilon: _tolerance),
        reason: 'le panneau $fiche n’est pas à droite',
      );
      expect(fiche.top, moreOrLessEquals(zone.top, epsilon: _tolerance));
      expect(fiche.bottom, moreOrLessEquals(zone.bottom, epsilon: _tolerance));
      expect(fiche.width, moreOrLessEquals(mapSidePanelWidth));
    }
  });

  await echecs.verifier('I-f', () async {
    expect(
      e.erreurs,
      isEmpty,
      reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
    );
  });
}

// --- I-j -------------------------------------------------------------------------------

/// I-j : les éléments PEINTS de la carte ne se recoupent pas deux à deux — les
/// trois pièces du bloc (chacune peint la carte blanche sur sa boîte), les
/// cinq boutons et l'attribution du bas, la pilule et l'indice non replié de
/// la bande (sauf au repli 6 : ni peints ni touchables), la fiche ouverte. Ce
/// sont les rectangles des éléments, jamais les boîtes des pièces qui ne
/// peignent rien hors d'eux (la rangée du bas, la bande). Remplace
/// l'invariant de `map_entry_buttons_overlap_test.dart` (« les cinq boutons ne
/// recoupent ni la légende visible, ni le bouton de désignation et son
/// indice ») et vaut pour toutes les paires.
Future<void> _verifierPaires(
  WidgetTester tester,
  _Config c,
  _Ecran e,
  _Echecs echecs,
) async {
  await echecs.verifier('I-j', () async {
    final bool bandeRetiree =
        e.rapport.value?.allocation.bandWithdrawn ?? false;
    final Map<String, Rect> peints = <String, Rect>{
      ..._bloc(tester),
      ..._bas(tester),
      if (c.enMode && !bandeRetiree) ..._bande(tester, e),
      if (c.fiche != _Fiche.aucune) 'fiche': tester.getRect(_fiche(tester)),
    };
    final List<MapEntry<String, Rect>> liste = peints.entries.toList();
    final List<String> recoupes = <String>[
      for (int i = 0; i < liste.length; i++)
        for (int j = i + 1; j < liste.length; j++)
          if (_recoupe(liste[i].value, liste[j].value))
            '${liste[i].key} ${liste[i].value} × '
                '${liste[j].key} ${liste[j].value}',
    ];
    expect(recoupes, isEmpty, reason: 'des éléments peints se recoupent');
  });
  await echecs.verifier('I-f', () async {
    expect(
      e.erreurs,
      isEmpty,
      reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
    );
  });
}

// --- I-h -------------------------------------------------------------------------------

/// En mode, fiche du bas ouverte : l'avis peut s'effacer (arbitrage 16).
bool _avisPeutSEffacer(_Config c) => c.enMode && c.ficheDuBas;

Future<void> _verifierAction(
  WidgetTester tester,
  _Config c,
  _Ecran e,
  _Echecs echecs,
) async {
  await echecs.verifier('I-h', () async {
    final Finder action = find.byKey(_actionDe(c.lecture));
    expect(action, findsOneWidget, reason: 'l’action de l’avis est posée');
    final MapLayoutReport? rapport = e.rapport.value;
    final bool efface =
        rapport != null &&
        rapport.allocation.notices <= _tolerance &&
        _avisPeutSEffacer(c);
    if (efface) {
      // Arbitrage 16 : l'avis s'efface pour que le réticule ne bouge pas ;
      // son action n'est pas atteignable, et c'est accepté.
      expect(action.hitTestable(), findsNothing);
      return;
    }
    final bool defile =
        rapport != null &&
        rapport.allocation.overflows &&
        rapport.allocation.notices <= _tolerance &&
        c.defileAccepte;
    if (defile) {
      // Arbitrage 13 : à 360 × 640 et 200 %, là où les six replis ne
      // suffisent pas, la partie fixe défile « comme en deçà » (arbitrage
      // 10), où seuls « ⚠ Avertissement » et « Restrictions » sont dus (I-a,
      // I-b, I-d les éprouvent) ; l'avis n'y a plus de hauteur.
      expect(action.hitTestable(), findsNothing);
      return;
    }
    // Repli 3 : l'avis défile dans une fenêtre qui peut être plus basse que
    // l'action ; amenée en vue, l'action est atteignable là où elle se voit —
    // au centre de sa partie visible dans la fenêtre des avis.
    await _amener(tester, action);
    final Rect? fenetre = _bloc(tester)['avis du bloc'];
    final Rect visible = tester
        .getRect(action)
        .intersect(fenetre ?? tester.getRect(action))
        .intersect(_zoneSure(c));
    final String etat =
        'action ${tester.getRect(action)}, fenêtre des avis $fenetre, '
        'répartition ${rapport?.allocation}';
    expect(
      visible.width >= 1 && visible.height >= 1,
      isTrue,
      reason: 'l’action ne paraît pas une fois amenée en vue ($etat)',
    );
    expect(
      _toucheEn(tester, action, visible.center),
      isTrue,
      reason: 'l’action n’est pas atteignable en ${visible.center} ($etat)',
    );
  });
  await echecs.verifier('I-f', () async {
    expect(
      e.erreurs,
      isEmpty,
      reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
    );
  });
}

// --- I-i : la vraie MapView ----------------------------------------------------------

final class _Stations implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

final class _NoHydro implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

final class _NoOnde implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async =>
      const OndeSweep(observations: <OndeObservation>[], unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

MapCamera _camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer)));

/// Monte la vraie `MapView` à [taille], désignation câblée, « Favoris » posé,
/// les fiches fournies et fermées (comme `main.dart`).
Future<List<GeoPoint>> _monterCarte(
  WidgetTester tester,
  Size taille, {
  required bool enMode,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<GeoPoint> designes = <GeoPoint>[];
  final MapViewModel viewModel = MapViewModel(
    stationPoints: _Stations(),
    observations: _NoHydro(),
    onde: _NoOnde(),
    delay: (Duration _) => Future<void>.value(),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MapView(
        viewModel: viewModel,
        onPointDesignated: designes.add,
        onStationTap: (StationCode _) {},
        stationSheet: const SizedBox.shrink(),
        onOndeTap: (OndePoint _) {},
        ondeSheet: const SizedBox.shrink(),
        onOpenFavorites: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (enMode) {
    viewModel.toggleDesignationMode();
    await tester.pumpAndSettle();
  }
  return designes;
}

/// Un point de la carte visible hors de toute pièce peinte (marge de 8 px),
/// le plus proche du centre de l'écran.
Offset _pointLibre(WidgetTester tester, Size taille) {
  final List<Rect> pieces = <Rect>[
    for (final Rect r in <Rect>[
      ..._bloc(tester).values,
      ..._bas(tester).values,
      if (_present(find.byKey(mapDesignateCenterButtonKey)))
        tester.getRect(find.byKey(mapDesignateCenterButtonKey)),
      if (_present(find.byKey(mapDesignateCenterHintKey)))
        tester.getRect(find.byKey(mapDesignateCenterHintKey)),
      if (_present(find.byKey(mapCenterReticleKey)))
        tester.getRect(find.byKey(mapCenterReticleKey)),
    ])
      r.inflate(8),
  ];
  final Offset centre = taille.center(Offset.zero);
  Offset? meilleur;
  for (double y = 12; y < taille.height - 12; y += 8) {
    for (double x = 12; x < taille.width - 12; x += 8) {
      final Offset p = Offset(x, y);
      if (pieces.any((Rect r) => r.contains(p))) continue;
      if (meilleur == null ||
          (p - centre).distance < (meilleur - centre).distance) {
        meilleur = p;
      }
    }
  }
  expect(meilleur, isNotNull, reason: 'aucun point libre sur la carte');
  return meilleur!;
}

/// Le toucher posé en [p] atteint-il la carte (un objet du sous-arbre de
/// `FlutterMap`) ?
bool _atteintLaCarte(WidgetTester tester, Offset p) {
  final RenderObject carte = tester.renderObject(find.byType(FlutterMap));
  final HitTestResult resultat = HitTestResult();
  tester.binding.hitTestInView(resultat, p, tester.view.viewId);
  for (final HitTestEntry entree in resultat.path) {
    final HitTestTarget cible = entree.target;
    if (cible is RenderObject) {
      RenderObject? ro = cible;
      while (ro != null) {
        if (identical(ro, carte)) return true;
        ro = ro.parent;
      }
    }
  }
  return false;
}

void _gestes(String nom, Size taille, TargetPlatform plateforme) {
  final bool android = switch (plateforme) {
    TargetPlatform.android => true,
    _ => false,
  };
  void cas(String d, Future<void> Function(WidgetTester tester) corps) {
    if (android) {
      testWidgetsOnAndroid('Android : $d', corps);
    } else {
      testWidgetsOnWindows(d, corps);
    }
  }

  for (final bool enMode in <bool>[false, true]) {
    final String mode = enMode ? 'en mode' : 'hors mode';
    cas('I-i — $nom, $mode : un tap et un clic droit posés sur la carte '
        'visible, hors des pièces, atteignent la carte', (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designes = await _monterCarte(
        tester,
        taille,
        enMode: enMode,
      );
      final Offset p = _pointLibre(tester, taille);
      expect(_atteintLaCarte(tester, p), isTrue, reason: 'tap en $p');
      await tester.tapAt(p, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(designes, hasLength(1), reason: 'clic droit en $p');
    });
    cas('I-i — $nom, $mode : un glisser posé sur la carte visible, hors des '
        'pièces, déplace la carte', (WidgetTester tester) async {
      await _monterCarte(tester, taille, enMode: enMode);
      final Offset p = _pointLibre(tester, taille);
      final LatLng avant = _camera(tester).center;
      await tester.dragFrom(p, const Offset(-30, 0));
      await tester.pumpAndSettle();
      expect(_camera(tester).center, isNot(avant), reason: 'glisser en $p');
    });
    cas('I-i — $nom, $mode : un cran de molette posé sur la carte visible, '
        'hors des pièces, zoome la carte', (WidgetTester tester) async {
      await _monterCarte(tester, taille, enMode: enMode);
      final Offset p = _pointLibre(tester, taille);
      final double avant = _camera(tester).zoom;
      final TestPointer pointeur = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointeur.hover(p));
      await tester.sendEventToBinding(pointeur.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();
      expect(_camera(tester).zoom, isNot(avant), reason: 'molette en $p');
    });
  }

  // Au téléphone, la rangée du bas : l'écart entre « Filtres » et « − » est
  // de la carte.
  if (switch (mapLayoutWidthFor(taille.width)) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  }) {
    Offset dansLEcart(WidgetTester tester) {
      final Rect filtres = tester.getRect(find.byKey(mapFiltersButtonKey));
      final Rect moins = tester.getRect(find.byKey(mapZoomOutButtonKey));
      expect(
        moins.left - filtres.right,
        greaterThan(16),
        reason: 'la rangée n’a pas d’écart entre « Filtres » et « − »',
      );
      return Offset((filtres.right + moins.left) / 2, filtres.center.dy);
    }

    cas('I-i — $nom : un tap et un clic droit posés dans l’écart de la rangée '
        'du bas atteignent la carte', (WidgetTester tester) async {
      final List<GeoPoint> designes = await _monterCarte(
        tester,
        taille,
        enMode: false,
      );
      final Offset p = dansLEcart(tester);
      expect(_atteintLaCarte(tester, p), isTrue, reason: 'tap en $p');
      await tester.tapAt(p, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(designes, hasLength(1), reason: 'clic droit en $p');
    });
    cas('I-i — $nom : un glisser posé dans l’écart de la rangée du bas '
        'déplace la carte', (WidgetTester tester) async {
      await _monterCarte(tester, taille, enMode: false);
      final Offset p = dansLEcart(tester);
      final LatLng avant = _camera(tester).center;
      await tester.dragFrom(p, const Offset(-30, 0));
      await tester.pumpAndSettle();
      expect(_camera(tester).center, isNot(avant));
    });
    cas('I-i — $nom : un cran de molette posé dans l’écart de la rangée du '
        'bas zoome la carte', (WidgetTester tester) async {
      await _monterCarte(tester, taille, enMode: false);
      final Offset p = dansLEcart(tester);
      final double avant = _camera(tester).zoom;
      final TestPointer pointeur = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointeur.hover(p));
      await tester.sendEventToBinding(pointeur.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();
      expect(_camera(tester).zoom, isNot(avant));
    });
  }
}

// --- Les cas ---------------------------------------------------------------------------

void main() {
  setUpAll(chargerRoboto);

  final List<_Config> matrice = _matrice();

  group(
    'I-a, I-b, I-d, I-f — sélecteur, « ⚠ Avertissement » et « Restrictions » '
    'atteignables',
    () {
      for (final _Config c in matrice) {
        _cas(
          c,
          c.defileAccepte
              ? 'I-a, I-b, I-d, I-f : sélecteur, « ⚠ Avertissement » et '
                    '« Restrictions » entiers et atteignables (en faisant '
                    'défiler la partie fixe là où elle défile, arbitrages 13, 18 et 19)'
              : 'I-a, I-b, I-d, I-f : sélecteur, « ⚠ Avertissement » et '
                    '« Restrictions » entiers et atteignables',
          (WidgetTester tester) async {
            final _Ecran e = await _monter(tester, c);
            final _Echecs echecs = _Echecs();
            await _verifierAtteignables(tester, c, e, echecs);
            echecs.conclure();
          },
        );
      }
    },
  );

  group('I-c, I-e, I-f — réticule et fiche', () {
    for (final _Config c in matrice) {
      _cas(
        c,
        c.enMode
            ? 'I-c, I-e, I-f : réticule entier, rien de peint dessus, bouton '
                  'atteignable (ou bande et réticule retirés, repli 6) ; la '
                  'fiche ne recoupe ni le bloc ni le bas'
            : 'I-e, I-f : la fiche ne recoupe ni le bloc ni le bas',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          final _Echecs echecs = _Echecs();
          await _verifierReticuleEtFiche(tester, c, e, echecs);
          echecs.conclure();
        },
      );
    }
  });

  // `D5` : I-g s'étend aux configurations AVEC fiche — la zone des fiches ne
  // cède plus que le corps du cadre, et la mesure monte la VRAIE fiche, celle
  // que l'écran pose (`mesurerPieces(ficheReelle:)`).
  group('I-g — les replis joués sont ceux de la répartition des pièces '
      'mesurées (toutes les configurations, fiche ouverte comprise)', () {
    for (final _Config c in matrice) {
      _cas(
        c,
        'I-g : les replis joués sont ceux de allocateMapLayout sur les pièces '
        'mesurées',
        (WidgetTester tester) async {
          final MapLayoutAllocation attendue = allocateMapLayout(
            await mesurerPieces(
              tester,
              taille: c.taille,
              echelle: c.echelle,
              lecture: c.lecture,
              enMode: c.enMode,
              fiche: switch (c.fiche) {
                _Fiche.aucune => null,
                _Fiche.station => ficheStation,
                _Fiche.troncon => ficheTroncon,
                _Fiche.onde => ficheOnde,
              },
              ficheReelle: switch (c.fiche) {
                _Fiche.aucune => null,
                _Fiche.station => ficheStationBlois(),
                _Fiche.troncon => _ficheTroncon(),
                _Fiche.onde => ficheOndeChaon(),
              },
              avecAvis: c.avecAvis,
              marge: c.insets,
              avis: _avisDe(c.lecture),
            ),
          );
          final _Ecran e = await _monter(tester, c);
          final _Echecs echecs = _Echecs();
          await echecs.verifier('I-g', () async {
            final MapLayoutReport? rapport = e.rapport.value;
            expect(rapport, isNotNull, reason: 'aucun rapport publié');
            final MapLayoutAllocation jouee = rapport!.allocation;
            expect(jouee.folds, attendue.folds, reason: 'replis');
            expect(jouee.overflows, attendue.overflows, reason: 'débord');
            expect(jouee.subtitlesFolded, attendue.subtitlesFolded);
            expect(jouee.hintFolded, attendue.hintFolded);
            expect(jouee.bandWithdrawn, attendue.bandWithdrawn);
            expect(
              jouee.sheet,
              moreOrLessEquals(attendue.sheet),
              reason: 'hauteur de la fiche',
            );
          });
          await echecs.verifier('I-f', () async {
            expect(e.erreurs, isEmpty);
          });
          echecs.conclure();
        },
      );
    }
  });

  group('I-h — l’action de l’avis atteignable', () {
    for (final _Config c in matrice) {
      if (!c.avecAvis) continue;
      _cas(
        c,
        'I-h : l’action de l’avis atteignable, au besoin en faisant défiler '
        'les avis'
        '${_avisPeutSEffacer(c) ? ' — sauf là où l’avis s’efface pour que le '
                  'réticule reste fixe (arbitrages 15 et 16)' : ''}'
        '${c.defileAccepte ? ' — sauf là où la partie fixe défile, comme en '
                  'deçà (arbitrages 13, 18 et 19)' : ''}',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          final _Echecs echecs = _Echecs();
          await _verifierAction(tester, c, e, echecs);
          echecs.conclure();
        },
      );
    }
  });

  group('arbitrage 15 — en mode, le réticule ne bouge pas quand un avis paraît '
      '(test apparié)', () {
    for (final _Config c in matrice) {
      if (!c.enMode || c.avecAvis) continue;
      _cas(c, 'réticule fixe : le même, sans avis puis avec un avis', (
        WidgetTester tester,
      ) async {
        final _Ecran sans = await _monter(tester, c);
        final MapLayoutReport? avant = sans.rapport.value;
        final _Ecran avec = await _monter(tester, c.avec(avecAvis: true));
        final MapLayoutReport? apres = avec.rapport.value;
        expect(avant, isNotNull, reason: 'aucun rapport sans avis');
        expect(apres, isNotNull, reason: 'aucun rapport avec avis');
        expect(
          apres!.reticle,
          avant!.reticle,
          reason: 'le réticule a bougé quand l’avis a paru',
        );
        expect(sans.erreurs, isEmpty);
        expect(avec.erreurs, isEmpty);
      });
    }
  });

  // `D3` d'Ergonomie (spec § 5.5, point 63) : en mode, la bande du bouton ne
  // monte jamais sur le bloc de lecture — aux quatre tailles et EN DEÇÀ, à
  // 360 × 300, à 100 % et 200 %, sans fiche et la fiche station ouverte, avec
  // l'avis (le bloc le plus haut). Là où le repli 6 la retire, il n'y a rien à
  // recouper : le cas le dit.
  group('D3, point 63 — en mode, la bande du bouton ne monte jamais sur le '
      'bloc de lecture, 360 × 300 compris', () {
    for (final ({String nom, Size taille, TargetPlatform plateforme}) t
        in <({String nom, Size taille, TargetPlatform plateforme})>[
          ...taillesGaranties,
          (
            nom: '360 × 300',
            taille: const Size(360, 300),
            plateforme: TargetPlatform.android,
          ),
        ]) {
      for (final double echelle in echellesDeTexte) {
        for (final _Fiche fiche in <_Fiche>[_Fiche.aucune, _Fiche.station]) {
          final _Config c = _Config(
            nomTaille: t.nom,
            taille: t.taille,
            plateforme: t.plateforme,
            echelle: echelle,
            lecture: MapScaleKind.ecoulement,
            enMode: true,
            fiche: fiche,
            avecAvis: true,
            marge: false,
          );
          _cas(
            c,
            'la bande sous le bloc, sans le recouper (ou retirée, repli 6)',
            (WidgetTester tester) async {
              final _Ecran e = await _monter(tester, c);
              final MapLayoutReport? rapport = e.rapport.value;
              expect(rapport, isNotNull, reason: 'aucun rapport publié');
              expect(e.erreurs, isEmpty);
              if (rapport!.allocation.bandWithdrawn) {
                expect(
                  peintParLaCarte(tester, find.byType(DesignationBand)),
                  isFalse,
                  reason: 'la bande retirée est peinte',
                );
                return;
              }
              final Rect bande = tester.getRect(find.byType(DesignationBand));
              final Rect fixe = tester.getRect(
                find.byType(MapReadingBlockFixed),
              );
              expect(
                bande.top,
                greaterThanOrEqualTo(fixe.bottom - _tolerance),
                reason: 'la bande $bande monte sur la partie fixe $fixe',
              );
              final List<String> recoupes = <String>[
                for (final MapEntry<String, Rect> piece in _bloc(
                  tester,
                ).entries)
                  if (_recoupe(piece.value, bande))
                    '${piece.key} ${piece.value}',
              ];
              expect(recoupes, isEmpty, reason: 'la bande $bande recoupe');
            },
          );
        }
      }
    }
  });

  group('I-i — les gestes posés hors des pièces atteignent la carte', () {
    for (final ({String nom, Size taille, TargetPlatform plateforme}) t
        in taillesGaranties) {
      _gestes(t.nom, t.taille, t.plateforme);
    }
  });

  group('I-j — les éléments peints ne se recoupent pas deux à deux', () {
    for (final _Config c in matrice) {
      _cas(
        c,
        'I-j, I-f : bloc, boutons et attribution du bas, pilule et indice, '
        'fiche — aucune paire ne se recoupe',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          final _Echecs echecs = _Echecs();
          await _verifierPaires(tester, c, e, echecs);
          echecs.conclure();
        },
      );
    }
  });

  group('critère 3 — le bas de la carte : rangée au téléphone, colonne dès '
      '600 px (spec § 5.4, § 9)', () {
    for (final ({String nom, Size taille, TargetPlatform plateforme}) t
        in taillesGaranties) {
      for (final double echelle in echellesDeTexte) {
        final _Config c = _Config(
          nomTaille: t.nom,
          taille: t.taille,
          plateforme: t.plateforme,
          echelle: echelle,
          lecture: MapScaleKind.ecoulement,
          enMode: false,
          fiche: _Fiche.aucune,
          avecAvis: false,
          marge: false,
        );
        final bool rangee = switch (c.largeur) {
          MapLayoutWidth.compact => true,
          MapLayoutWidth.wide || MapLayoutWidth.panel => false,
        };
        _cas(
          c,
          rangee
              ? 'critère 3 : une rangée au bas de la carte — « Favoris », '
                    '« Filtres » à gauche, −, +, recentrer à droite — et '
                    'l’attribution dessous ; le bas à sa hauteur entière'
              : 'critère 3 : une colonne au bas à droite — « Favoris », '
                    '« Filtres », +, −, recentrer, à mapControlsSpacing, bords '
                    'droits alignés — et l’attribution dessous ; le bas à sa '
                    'hauteur entière',
          (WidgetTester tester) async {
            final _Ecran e = await _monter(tester, c);
            expect(e.erreurs, isEmpty);
            Rect r(Key k) => tester.getRect(find.byKey(k));
            final Rect favoris = r(mapFavoritesButtonKey);
            final Rect filtres = r(mapFiltersButtonKey);
            final Rect plus = r(mapZoomInButtonKey);
            final Rect moins = r(mapZoomOutButtonKey);
            final Rect recentrer = r(mapRecenterButtonKey);
            final Rect attribution = tester.getRect(
              find.byType(IgnAttributionBadge),
            );
            final double droite = c.taille.width - margeDeSurcouche;
            if (rangee) {
              final List<Rect> ordre = <Rect>[
                favoris,
                filtres,
                moins,
                plus,
                recentrer,
              ];
              for (final Rect b in ordre) {
                expect(
                  b.center.dy,
                  moreOrLessEquals(favoris.center.dy, epsilon: _tolerance),
                  reason: 'les cinq boutons sur une même rangée',
                );
              }
              for (int i = 0; i + 1 < ordre.length; i++) {
                expect(
                  ordre[i].right,
                  lessThanOrEqualTo(ordre[i + 1].left + _tolerance),
                  reason:
                      'ordre de gauche à droite : Favoris, Filtres, −, +, '
                      'recentrer',
                );
              }
              expect(
                favoris.left,
                moreOrLessEquals(margeDeSurcouche, epsilon: _tolerance),
              );
              expect(
                recentrer.right,
                moreOrLessEquals(droite, epsilon: _tolerance),
              );
              expect(
                attribution.top,
                greaterThanOrEqualTo(
                  favoris.bottom + margeDeSurcouche - _tolerance,
                ),
                reason: 'l’attribution sous la rangée',
              );
            } else {
              final List<Rect> ordre = <Rect>[
                favoris,
                filtres,
                plus,
                moins,
                recentrer,
              ];
              for (int i = 0; i + 1 < ordre.length; i++) {
                expect(
                  ordre[i + 1].top - ordre[i].bottom,
                  moreOrLessEquals(mapControlsSpacing, epsilon: _tolerance),
                  reason:
                      'colonne de haut en bas : Favoris, Filtres, +, −, '
                      'recentrer, à mapControlsSpacing',
                );
              }
              for (final Rect b in ordre) {
                expect(
                  b.right,
                  moreOrLessEquals(droite, epsilon: _tolerance),
                  reason: 'bords droits alignés au bord de la carte visible',
                );
              }
              expect(
                recentrer.bottom - favoris.top,
                moreOrLessEquals(
                  5 * favoris.height + 4 * mapControlsSpacing,
                  epsilon: _tolerance,
                ),
                reason: 'cinq boutons et quatre écarts',
              );
              expect(
                attribution.top,
                greaterThanOrEqualTo(
                  recentrer.bottom + margeDeSurcouche - _tolerance,
                ),
                reason: 'l’attribution sous la colonne',
              );
              expect(
                attribution.right,
                moreOrLessEquals(droite, epsilon: _tolerance),
              );
            }
            expect(
              attribution.bottom,
              moreOrLessEquals(
                c.taille.height - margeDeSurcouche,
                epsilon: _tolerance,
              ),
              reason: 'le bas collé au bas de la carte visible',
            );
            // Le bas ne cède jamais : il est posé à sa hauteur entière.
            final RenderBox bas = tester.renderObject(find.byType(MapBottom));
            expect(
              bas.size.height,
              moreOrLessEquals(
                bas.getMaxIntrinsicHeight(bas.size.width),
                epsilon: _tolerance,
              ),
            );
          },
        );
      }
    }
  });

  group('spec § 6.5 — le panneau latéral', () {
    testWidgetsOnWindows(
      '1 280 × 740, fiche station : le filet #C9CFC4 se voit '
      'à gauche du panneau, sur la hauteur de la fiche (peint par-dessus '
      'elle)',
      (WidgetTester tester) async {
        const _Config c = _Config(
          nomTaille: '1 280 × 740',
          taille: Size(1280, 740),
          plateforme: TargetPlatform.windows,
          echelle: 1,
          lecture: MapScaleKind.ecoulement,
          enMode: false,
          fiche: _Fiche.station,
          avecAvis: false,
          marge: false,
        );
        await _monter(tester, c);
        final Rect zone = tester.getRect(find.byKey(mapSheetAreaKey));
        final Rect fiche = tester.getRect(find.byKey(_ficheStationKey));
        expect(zone.left, moreOrLessEquals(1280 - mapSidePanelWidth));
        // Une colonne de pixels du filet, à mi-hauteur de la fiche, puis sous
        // elle : le filet se voit aux deux.
        final Color surLaFiche = await _pixel(
          tester,
          Offset(zone.left + 0.5, fiche.center.dy),
        );
        final Color sousLaFiche = await _pixel(
          tester,
          Offset(zone.left + 0.5, (fiche.bottom + zone.bottom) / 2),
        );
        expect(surLaFiche, mapSidePanelRuleColor, reason: 'à côté de la fiche');
        expect(sousLaFiche, mapSidePanelRuleColor, reason: 'sous la fiche');
        // À droite du filet, le fond de la fiche reste blanc.
        expect(
          await _pixel(tester, Offset(zone.left + 3.5, fiche.center.dy)),
          isNot(mapSidePanelRuleColor),
        );
      },
    );

    testWidgetsOnWindows(
      'fiche tronçon ouverte et défilée, la fenêtre passe de '
      '1 280 à 760 px de large puis revient : la fiche n’est pas recréée '
      '(même défilement, même panneau), aucune erreur',
      (WidgetTester tester) async {
        const _Config c = _Config(
          nomTaille: '1 280 × 740',
          taille: Size(1280, 740),
          plateforme: TargetPlatform.windows,
          echelle: 2,
          lecture: MapScaleKind.ecoulement,
          enMode: false,
          fiche: _Fiche.troncon,
          avecAvis: false,
          marge: false,
        );
        final _Ecran e = await _monter(tester, c);
        // Le défilement du corps de la fiche (`D5`) : le premier sous lui (la
        // fiche tronçon porte d'autres défilements, plus bas).
        final Finder defilement = find
            .descendant(
              of: find.byKey(sheetFrameBodyKey),
              matching: find.byType(Scrollable),
            )
            .first;
        final ScrollableState avant = tester.state<ScrollableState>(defilement);
        final Element panneau = tester.element(find.byKey(_ficheTronconKey));
        expect(
          avant.position.maxScrollExtent,
          greaterThan(0),
          reason: 'la fiche doit être plus haute que le panneau',
        );
        avant.position.jumpTo(avant.position.maxScrollExtent);
        await tester.pump();

        for (final Size taille in <Size>[
          const Size(760, 740),
          const Size(1280, 740),
        ]) {
          tester.view.physicalSize = taille;
          await tester.pumpAndSettle();
          expect(e.erreurs, isEmpty);
          expect(tester.takeException(), isNull);
          expect(
            identical(tester.state<ScrollableState>(defilement), avant),
            isTrue,
            reason:
                'à ${taille.width} px, le défilement de la fiche est recréé',
          );
          expect(
            identical(tester.element(find.byKey(_ficheTronconKey)), panneau),
            isTrue,
            reason: 'à ${taille.width} px, le panneau de la fiche est recréé',
          );
        }
      },
    );
  });

  group('Review Focus 3 — l’échelle du texte change, fiche station ouverte', () {
    // Arbitrage 17 : fiche du bas ouverte, les sous-titres cèdent avant le
    // corps de la fiche — à 360 × 640, ils sont repliés aussi à 100 % ; à
    // 390 × 844, entiers à 100 %, ils reviennent puis repartent.
    for (final ({String nomTaille, Size taille, bool entiersA100}) t
        in <({String nomTaille, Size taille, bool entiersA100})>[
          (
            nomTaille: '360 × 640',
            taille: const Size(360, 640),
            entiersA100: false,
          ),
          (
            nomTaille: '390 × 844',
            taille: const Size(390, 844),
            entiersA100: true,
          ),
        ]) {
      testWidgetsOnAndroid(
        'Android : ${t.nomTaille}, fiche station ouverte, texte '
        '200 % → 100 % → 200 % : aucune erreur, la fiche reste ouverte, son '
        'en-tête entier, les sous-titres suivent la répartition — repliés à '
        '200 %, ${t.entiersA100 ? 'entiers' : 'repliés'} à 100 % —, le rapport ne '
        'change qu’une fois par changement d’échelle',
        (WidgetTester tester) async {
          final _Config c = _Config(
            nomTaille: t.nomTaille,
            taille: t.taille,
            plateforme: TargetPlatform.android,
            echelle: 2,
            lecture: MapScaleKind.ecoulement,
            enMode: false,
            fiche: _Fiche.station,
            avecAvis: false,
            marge: false,
          );
          final ValueNotifier<double> echelle = ValueNotifier<double>(2);
          addTearDown(echelle.dispose);
          final _Ecran e = await _monter(tester, c, echelle: echelle);
          final List<MapLayoutReport?> publies = <MapLayoutReport?>[];
          e.rapport.addListener(() => publies.add(e.rapport.value));

          // Les sous-titres sont peints exactement quand la répartition ne les
          // replie pas.
          void sousTitresSelonLaRepartition(String quand) {
            final bool replies = e.rapport.value!.allocation.subtitlesFolded;
            expect(
              find.text('observé sur le terrain').hitTestable(),
              replies ? findsNothing : findsOneWidget,
              reason: '$quand : sous-titres ${replies ? 'repliés' : 'entiers'}',
            );
          }

          // La fiche reste ouverte ET visible : la zone garde la hauteur que la
          // répartition lui donne, au moins l'en-tête épinglé (`D5`).
          void ficheVisible(String quand) {
            expect(find.byKey(_ficheStationKey), findsOneWidget, reason: quand);
            expect(
              e.rapport.value!.allocation.sheet,
              greaterThan(0),
              reason: '$quand : la répartition ne donne plus rien à la fiche',
            );
            // `D5` : la zone garde au moins l'en-tête épinglé, entier.
            final Rect zone = tester.getRect(find.byKey(mapSheetAreaKey));
            final Rect enTete = tester.getRect(find.byKey(sheetFrameHeaderKey));
            expect(enTete.height, greaterThan(0), reason: quand);
            expect(
              zone.height,
              greaterThanOrEqualTo(enTete.height - _tolerance),
              reason: '$quand : la zone des fiches n’a plus son en-tête',
            );
            expect(
              enTete.top >= zone.top - _tolerance &&
                  enTete.bottom <= zone.bottom + _tolerance,
              isTrue,
              reason: '$quand : l’en-tête $enTete sort de la zone $zone',
            );
          }

          expect(e.erreurs, isEmpty);
          final MapLayoutAllocation a200 = e.rapport.value!.allocation;
          ficheVisible('à 200 %');
          sousTitresSelonLaRepartition('à 200 %');

          for (final (double, int) pas in <(double, int)>[(1, 1), (2, 2)]) {
            echelle.value = pas.$1;
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              publies,
              hasLength(pas.$2),
              reason:
                  'un rapport par changement d’échelle, jamais de va-et-vient',
            );
            ficheVisible('à ${(pas.$1 * 100).round()} %');
            sousTitresSelonLaRepartition('à ${(pas.$1 * 100).round()} %');
          }
          // Revenue à 200 %, la répartition est celle du départ.
          expect(e.rapport.value!.allocation, a200);
          // Review Focus 3 (`D5`, que la zone provisoire empêchait de voir) :
          // fiche station ouverte, les sous-titres sont repliés à 200 % (repli
          // 4) ; à 100 %, entiers ou repliés selon la taille (arbitrage 17),
          // selon `allocateMapLayout`.
          expect(a200.subtitlesFolded, isTrue, reason: 'à 200 %, repliés');
          expect(a200.folds, contains(4), reason: 'à 200 %, le repli 4 joue');
          expect(publies.first!.allocation.subtitlesFolded, !t.entiersA100);
          expect(
            publies.first!.allocation.folds,
            t.entiersA100 ? isNot(contains(4)) : contains(4),
            reason: 'à 100 %, ${t.entiersA100 ? 'entiers' : 'repliés'}',
          );
        },
      );
    }
  });

  group('K1 de T3 — l’ordre de tabulation au téléphone (spec § 5.7)', () {
    for (final ({String nom, Size taille, TargetPlatform plateforme}) t
        in taillesGaranties.where(
          (({String nom, Size taille, TargetPlatform plateforme}) t) =>
              switch (mapLayoutWidthFor(t.taille.width)) {
                MapLayoutWidth.compact => true,
                MapLayoutWidth.wide || MapLayoutWidth.panel => false,
              },
        )) {
      for (final bool enMode in <bool>[false, true]) {
        testWidgetsOnAndroid('Android : Tab à ${t.nom}, 100 %, écoulement, '
            '${enMode ? 'en mode' : 'hors mode'}, avec l’avis : entrées '
            '(quatre) → « Élargir la recherche » → « Favoris » → « Filtres » '
            '→ − → + → recentrer${enMode ? ' → bouton de désignation' : ''} '
            '→ « ⚠ Avertissement »', (WidgetTester tester) async {
          final _Config c = _Config(
            nomTaille: t.nom,
            taille: t.taille,
            plateforme: t.plateforme,
            echelle: 1,
            lecture: MapScaleKind.ecoulement,
            enMode: enMode,
            fiche: _Fiche.aucune,
            avecAvis: true,
            marge: false,
          );
          await _monter(tester, c);
          final List<(String, Finder)> attendus = <(String, Finder)>[
            for (final MapEntry<String, Finder> entree in _entrees().entries)
              (entree.key, entree.value),
            ('Élargir la recherche', find.byKey(widenSearchKey)),
            ('Favoris', find.byKey(mapFavoritesButtonKey)),
            ('Filtres', find.byKey(mapFiltersButtonKey)),
            ('−', find.byKey(mapZoomOutButtonKey)),
            ('+', find.byKey(mapZoomInButtonKey)),
            ('recentrer', find.byKey(mapRecenterButtonKey)),
            if (enMode)
              ('désignation', find.byKey(mapDesignateCenterButtonKey)),
            ('⚠ Avertissement', _lienDeLaCarte()),
          ];
          final List<String> vus = <String>[];
          for (int i = 0; i < 2 * attendus.length; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            for (final (String, Finder) a in attendus) {
              if (focusedWithin(tester, a.$2) &&
                  (vus.isEmpty || vus.last != a.$1)) {
                vus.add(a.$1);
              }
            }
            if (vus.length == attendus.length) break;
          }
          expect(vus, <String>[
            for (final (String, Finder) a in attendus) a.$1,
          ]);
        });
      }
    }
  });

  _groupesI1();
  _groupeReviewFocus5();
  _groupeConstatsEnDeca();
  _groupeBandeANull();
  _groupeEnTeteQuiCede();
  _groupeRangDuBoutonALaColonne();

  // Garde-fou : la matrice est bien celle de la porte de faisabilité.
  test('la matrice compte 576 configurations', () {
    expect(matrice, hasLength(576));
    expect(matrice.where((_Config c) => c.android), hasLength(384));
  });
}

// --- I1 : glisser, clavier, en deçà --------------------------------------------

/// Le centre de [f] est-il atteignable au toucher, dans [zone] ?
bool _atteint(WidgetTester tester, Finder f, Rect zone) =>
    f.hitTestable().evaluate().isNotEmpty &&
    zone.contains(tester.getRect(f).center);

/// Le défilement de la partie fixe du bloc.
ScrollPosition _positionFixe(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(MapReadingBlockFixed),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// La fenêtre de la partie fixe du bloc : ce qui s'en voit dans la zone sûre.
Rect _fenetreFixe(WidgetTester tester, Rect zone) =>
    tester.getRect(find.byType(MapReadingBlockFixed)).intersect(zone);

/// La mesure d'un cas, dite dans son échec : la partie fixe posée, sa
/// position de défilement, la répartition.
String _mesureI1(WidgetTester tester, _Ecran e) {
  final ScrollPosition p = _positionFixe(tester);
  return 'partie fixe ${tester.getRect(find.byType(MapReadingBlockFixed))}, '
      'défilée de ${p.pixels} sur ${p.maxScrollExtent}, répartition '
      '${e.rapport.value?.allocation}';
}

/// Amène [cible] sous le doigt en glissant sur la partie fixe du bloc, vers le
/// haut puis, au bout, vers le bas. Rend `null` si elle est atteinte, sinon ce
/// qui l'empêche. Le glisser part du centre de la fenêtre de la partie fixe
/// et parcourt la moitié de sa hauteur — au moins une cible tactile (`D8`) :
/// sur une fenêtre de 48 px, un demi-glisser de 24 px ne dépasserait guère le
/// seuil d'un glisser au toucher (18 px), et un doigt réel continue au-delà de
/// la fenêtre où il a commencé.
Future<String?> _atteindreEnGlissant(
  WidgetTester tester,
  Finder cible,
  Rect zone,
) async {
  double sens = -1;
  bool retourne = false;
  for (int i = 0; i < 40; i++) {
    if (_atteint(tester, cible, zone)) return null;
    final Rect surface = _fenetreFixe(tester, zone);
    if (surface.width < 1 || surface.height < 1) {
      return 'la partie fixe n’a aucune surface où glisser ($surface)';
    }
    final ScrollPosition p = _positionFixe(tester);
    final double avant = p.pixels;
    await tester.dragFrom(
      surface.center,
      Offset(0, sens * (surface.height / 2).clamp(minimumTapTarget, 200)),
    );
    await tester.pumpAndSettle();
    if ((p.pixels - avant).abs() < _tolerance) {
      if (retourne) return 'le glisser ne la fait plus défiler';
      sens = -sens;
      retourne = true;
    }
  }
  return 'non atteinte après 40 glissers';
}

/// Tab jusqu'à ce que le focus soit dans [cible], puis : le focus l'a-t-il
/// amenée en vue — entière, ou, si elle est plus haute que la fenêtre de la
/// partie fixe, sur toute la hauteur de cette fenêtre ? Rend `null` si oui,
/// sinon ce qui manque.
Future<String?> _atteindreAuClavier(
  WidgetTester tester,
  Finder cible,
  Rect zone,
) async {
  for (int i = 0; i < 40; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    if (focusedWithin(tester, cible)) {
      final Rect r = tester.getRect(cible);
      final Rect fenetre = _fenetreFixe(tester, zone);
      final Rect vu = r.intersect(fenetre);
      final bool enVue =
          vu.width >= 1 &&
          vu.height >= 1 &&
          vu.height >= math.min(r.height, fenetre.height) - _tolerance;
      return enVue
          ? null
          : 'focalisée, mais pas amenée en vue ($r, fenêtre $fenetre)';
    }
  }
  return 'Tab ne l’atteint pas en 40 arrêts';
}

/// Les tailles en deçà qu'éprouvent I1 et D8 : celles de [taillesEnDeca] et
/// 600 × 360, le bord bas de la colonne (mineur m2 de la relecture d'I1).
const List<Size> _taillesEnDecaD8 = <Size>[
  Size(360, 300),
  Size(600, 360),
  Size(640, 360),
  Size(844, 390),
];

/// Les configurations d'I1 : en deçà (spec § 5.6, arbitrage 10, critère 6) et,
/// aux deux téléphones garantis à 200 %, là où la partie fixe défile pour la
/// fiche du bas (arbitrage 18).
List<_Config> _configsI1() => <_Config>[
  for (final Size taille in _taillesEnDecaD8)
    for (final double echelle in echellesDeTexte)
      for (final bool enMode in <bool>[false, true])
        for (final _Fiche fiche in <_Fiche>[_Fiche.aucune, _Fiche.station])
          _Config(
            nomTaille: '${taille.width.round()} × ${taille.height.round()}',
            taille: taille,
            // En deçà, ce sont des téléphones (en paysage pour deux d'entre
            // elles) : une fenêtre Windows ne descend pas sous 800 × 740.
            plateforme: TargetPlatform.android,
            echelle: echelle,
            lecture: MapScaleKind.ecoulement,
            enMode: enMode,
            fiche: fiche,
            avecAvis: true,
            marge: false,
          ),
  for (final ({String nom, Size taille, TargetPlatform plateforme}) t
      in taillesGaranties.take(2))
    for (final bool enMode in <bool>[false, true])
      _Config(
        nomTaille: t.nom,
        taille: t.taille,
        plateforme: t.plateforme,
        echelle: 2,
        lecture: MapScaleKind.debit,
        enMode: enMode,
        fiche: _Fiche.station,
        avecAvis: false,
        marge: false,
      ),
];

/// ⚠️ LIMITE ACCEPTÉE (arbitrage 26 du commanditaire, 2026-10-18 ; mesurée par
/// `D8` d'Ergonomie, garde-fou c, Roboto, Android) : à 360 × 300 et
/// 200 %, fiche station ouverte, l'ordre arbitré (bande et réticule, colonne,
/// en-tête de la fiche jamais sous sa première rangée) ne rend à la partie
/// fixe que 40 px, sous la cible tactile de 48. La première rangée de
/// l'en-tête y fait 114 px (la nature « Station hydrométrique · K447001001 »
/// sur plusieurs lignes, à côté de l'étoile et de la fermeture) ; la rangée du
/// bas, 122, ne cède pas : 292 − (8 + 122 + 8 + 114) = 40. « ⚠ Avertissement »
/// et « Restrictions » y restent atteignables en glissant et au clavier.
/// Acceptée à cette seule taille et cette seule échelle, fiche station ouverte,
/// et verrouillée à sa mesure : la valeur est la hauteur de la fenêtre de la
/// partie fixe ; une mesure qui change fait rougir le cas. Aucun repli de plus.
const Map<String, double> _plancherNonTenuEnDeca = <String, double>{
  '360 × 300, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      40,
  '360 × 300, 200 %, écoulement, en mode, fiche station, avis, sans marge': 40,
};

/// Ce que le titre d'un cas d'I1 dit du plancher de la partie fixe.
String _titrePlancher(_Config c) {
  final double? ecart = _plancherNonTenuEnDeca[c.nom];
  return ecart == null
      ? 'I1, D8 : la partie fixe garde une cible tactile'
      : 'limite acceptée (arbitrage 26) — la partie fixe n’a que '
            '${ecart.round()} px';
}

/// Arbitrages 21 et 24 (`D8`) : la fenêtre de la partie fixe garde au moins
/// une cible tactile, dans la zone sûre — sauf la limite acceptée de
/// [_plancherNonTenuEnDeca] (arbitrage 26), tenue à sa mesure. Rend `null`
/// si oui, sinon la mesure.
String? _plancherTenu(WidgetTester tester, _Config c, Rect zone) {
  final Rect fenetre = _fenetreFixe(tester, zone);
  final double? ecart = _plancherNonTenuEnDeca[c.nom];
  if (ecart != null) {
    return (fenetre.height - ecart).abs() <= _tolerance
        ? null
        : 'limite acceptée (arbitrage 26) : la partie fixe devait avoir $ecart '
              'px, elle en a ${fenetre.height} ($fenetre)';
  }
  return fenetre.height >= minimumTapTarget - _tolerance
      ? null
      : 'la partie fixe n’a que ${fenetre.height} px ($fenetre), sous la '
            'cible tactile de $minimumTapTarget';
}

// `D8` d'Ergonomie (arbitrages 21 à 24) : REMPLACE les « CONSTAT remonté
// (I1) » de `_partieFixeANullEnDeca` (dix configurations où la partie fixe
// recevait 0 px) et les fenêtres de 21, 36 et 10 px de l'écart 3 et du mineur
// m1 (R15). La table est vidée : chaque cas tient l'invariant — la partie
// fixe garde une cible tactile, et « ⚠ Avertissement » et « Restrictions »
// s'atteignent en glissant sur elle et au clavier —, sauf la limite acceptée
// par l'arbitrage 26 ([_plancherNonTenuEnDeca], 40 px, atteignables quand
// même).
void _groupesI1() {
  final List<_Config> configs = _configsI1();
  final Map<String, Finder Function()> cibles = <String, Finder Function()>{
    '« Restrictions »': () => find.byKey(mapDesignationChipKey),
    '« ⚠ Avertissement »': _lienDeLaCarte,
  };

  group('D8 — critère 6 : la partie fixe garde une cible tactile, en deçà', () {
    group('I1 — « ⚠ Avertissement » et « Restrictions » atteignables en '
        'glissant sur le bloc (en deçà, et là où la partie fixe défile)', () {
      for (final _Config c in configs) {
        _cas(
          c,
          '${_titrePlancher(c)} ; atteignables en '
          'glissant sur elle ; aucune erreur de rendu',
          (WidgetTester tester) async {
            final _Ecran e = await _monter(tester, c);
            final Rect zone = _zoneSure(c);
            expect(
              e.erreurs,
              isEmpty,
              reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
            );
            final List<String> echecs = <String>[
              ?_plancherTenu(tester, c, zone),
            ];
            for (final MapEntry<String, Finder Function()> cible
                in cibles.entries) {
              final String? echec = await _atteindreEnGlissant(
                tester,
                cible.value(),
                zone,
              );
              if (echec != null) echecs.add('${cible.key} : $echec');
            }
            expect(echecs, isEmpty, reason: _mesureI1(tester, e));
          },
        );
      }
    });

    group('I1 — « ⚠ Avertissement » et « Restrictions » atteignables au '
        'clavier, le focus les amène en vue (en deçà, et là où la partie fixe '
        'défile)', () {
      for (final _Config c in configs) {
        _cas(
          c,
          '${_titrePlancher(c)} ; Tab les atteint '
          'et les amène en vue ; aucune erreur de rendu',
          (WidgetTester tester) async {
            final _Ecran e = await _monter(tester, c);
            final Rect zone = _zoneSure(c);
            expect(
              e.erreurs,
              isEmpty,
              reason: e.erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
            );
            final List<String> echecs = <String>[
              ?_plancherTenu(tester, c, zone),
            ];
            for (final MapEntry<String, Finder Function()> cible
                in cibles.entries) {
              final String? echec = await _atteindreAuClavier(
                tester,
                cible.value(),
                zone,
              );
              if (echec != null) echecs.add('${cible.key} : $echec');
            }
            expect(echecs, isEmpty, reason: _mesureI1(tester, e));
          },
        );
      }
    });
  });

  // R20 (spec § 5.1, § 11.3) : un téléphone en paysage passe en panneau
  // latéral, par la largeur.
  group('I1 — 844 × 390 passe en panneau latéral (R20)', () {
    for (final double echelle in echellesDeTexte) {
      final _Config c = _Config(
        nomTaille: '844 × 390',
        taille: const Size(844, 390),
        plateforme: TargetPlatform.android,
        echelle: echelle,
        lecture: MapScaleKind.ecoulement,
        enMode: false,
        fiche: _Fiche.station,
        avecAvis: false,
        marge: false,
      );
      _cas(
        c,
        'la fiche station s’ouvre en panneau de 380 px à droite, sur '
        'toute la hauteur ; le bloc et la colonne à sa gauche ; aucune '
        'erreur de rendu',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          expect(e.erreurs, isEmpty);
          expect(c.largeur, MapLayoutWidth.panel);
          final Rect panneau = tester.getRect(_fiche(tester));
          expect(
            panneau,
            rectMoreOrLessEquals(
              const Rect.fromLTRB(844 - mapSidePanelWidth, 0, 844, 390),
              epsilon: _tolerance,
            ),
          );
          for (final Rect piece in <Rect>[
            ..._bloc(tester).values,
            ..._bas(tester).values,
          ]) {
            expect(
              piece.right,
              lessThanOrEqualTo(panneau.left + _tolerance),
              reason: '$piece passe sous le panneau $panneau',
            );
          }
        },
      );
    }
  });
}

// --- I1 : Review Focus 5 ---------------------------------------------------------

/// Review Focus 5 (plan d'Ergonomie, `I1`) : la fiche ouverte, son corps
/// défilé au bout, Tab entre dans la fiche puis la parcourt. Chaque contrôle
/// qui reçoit le focus est entier dans la partie de la fiche qui le porte : un
/// contrôle de l'en-tête dans l'en-tête épinglé, un contrôle du corps dans la
/// fenêtre du corps — jamais sous l'en-tête. La fiche station n'a aucun arrêt
/// dans son corps (étoile et « ⚠ Avertissement » sont dans l'en-tête) ; la
/// fiche tronçon y porte « Lire le bulletin » et l'adresse sélectionnable.
void _groupeReviewFocus5() {
  group('I1, Review Focus 5 — Tab dans une fiche défilée au bout : chaque '
      'contrôle focalisé est entier dans sa partie, jamais sous l’en-tête', () {
    for (final _Fiche fiche in <_Fiche>[_Fiche.station, _Fiche.troncon]) {
      for (final ({String nom, Size taille, TargetPlatform plateforme}) t
          in <({String nom, Size taille, TargetPlatform plateforme})>[
            taillesGaranties.first,
            taillesGaranties.last,
          ]) {
        // Au panneau de 1 280 × 740, à 100 %, le corps tient sans défiler.
        for (final double echelle in <double>[
          if (t.taille.width < mapSidePanelMinWidth) 1,
          2,
        ]) {
          final _Config c = _Config(
            nomTaille: t.nom,
            taille: t.taille,
            plateforme: t.plateforme,
            echelle: echelle,
            lecture: MapScaleKind.ecoulement,
            enMode: false,
            fiche: fiche,
            avecAvis: false,
            marge: false,
          );
          final bool arretsDansLeCorps = switch (fiche) {
            _Fiche.troncon => true,
            _Fiche.station || _Fiche.aucune || _Fiche.onde => false,
          };
          _cas(
            c,
            'Review Focus 5 : corps défilé au bout, Tab de l’étoile '
            '${arretsDansLeCorps ? 'aux contrôles du corps' : 'à « ⚠ Avertissement » de la fiche (aucun arrêt dans le corps)'}'
            ' — chacun entier dans sa partie',
            (WidgetTester tester) async {
              final _Ecran e = await _monter(tester, c);
              expect(e.erreurs, isEmpty);
              final Finder zone = _fiche(tester);
              final Finder enTete = find.descendant(
                of: zone,
                matching: find.byKey(sheetFrameHeaderKey),
              );
              final Finder corps = find.descendant(
                of: zone,
                matching: find.byKey(sheetFrameBodyKey),
              );
              final ScrollPosition position = tester
                  .state<ScrollableState>(
                    find
                        .descendant(
                          of: corps,
                          matching: find.byType(Scrollable),
                        )
                        .first,
                  )
                  .position;
              expect(
                position.maxScrollExtent,
                greaterThan(0),
                reason:
                    'le corps doit défiler pour que le cas dise quelque chose',
              );
              // Deux départs : le corps défilé au bout (le cas du plan), puis
              // ramené en tête — « Lire le bulletin » est alors sous la
              // fenêtre du corps, et c'est le focus qui doit l'y amener.
              for (final (String, double) depart in <(String, double)>[
                ('défilé au bout', position.maxScrollExtent),
                ('ramené en tête', 0),
              ]) {
                position.jumpTo(depart.$2);
                await tester.pumpAndSettle();
                if (arretsDansLeCorps && depart.$2 == 0) {
                  // Contrôle positif : avant le Tab, le bouton n'est pas
                  // entier dans la fenêtre du corps.
                  final Rect bouton = tester.getRect(
                    find.byKey(floodBulletinButtonKey),
                  );
                  expect(
                    bouton.bottom,
                    greaterThan(tester.getRect(corps).bottom),
                    reason: 'le bouton $bouton est déjà en vue',
                  );
                }

                // Tab jusqu'à entrer dans la fiche.
                for (int i = 0; i < 40 && !focusedWithin(tester, zone); i++) {
                  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                  await tester.pumpAndSettle();
                }
                expect(
                  focusedWithin(tester, zone),
                  isTrue,
                  reason: '${depart.$1} : Tab entre dans la fiche',
                );
                final List<String> arrets = <String>[];
                final List<String> ecarts = <String>[];
                int dansLeCorps = 0;
                while (focusedWithin(tester, zone) && arrets.length < 12) {
                  final FocusNode noeud = FocusManager.instance.primaryFocus!;
                  final Rect r = noeud.rect;
                  final bool tete = focusedWithin(tester, enTete);
                  final Rect partie = tester.getRect(tete ? enTete : corps);
                  final String nom = '${noeud.context?.widget.runtimeType} $r';
                  arrets.add('${tete ? 'en-tête' : 'corps'} : $nom');
                  if (!tete) dansLeCorps++;
                  final bool entier =
                      r.top >= partie.top - _tolerance &&
                      r.bottom <= partie.bottom + _tolerance &&
                      r.left >= partie.left - _tolerance &&
                      r.right <= partie.right + _tolerance;
                  if (!entier) {
                    ecarts.add(
                      '$nom hors de '
                      '${tete ? 'l’en-tête' : 'la fenêtre du corps'} $partie',
                    );
                  }
                  if (!tete &&
                      r.top < tester.getRect(enTete).bottom - _tolerance) {
                    ecarts.add('$nom sous l’en-tête ${tester.getRect(enTete)}');
                  }
                  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                  await tester.pumpAndSettle();
                }
                final String vus = '${depart.$1} :\n${arrets.join('\n')}';
                expect(ecarts, isEmpty, reason: vus);
                expect(
                  dansLeCorps,
                  arretsDansLeCorps ? greaterThan(0) : 0,
                  reason: vus,
                );
              }
              expect(e.erreurs, isEmpty);
            },
          );
        }
      }
    }
  });
}

// --- D8 : une bande à 0 px se retire (arbitrage 23) --------------------------------

/// Arbitrage 23 (`D8`) : en mode, sans fiche, une bande du bouton qui n'a pas
/// de place à côté de la colonne reçoit 0 px ; elle se retire comme au repli
/// 6 — ni peinte, ni touchable, ni atteinte par Tab, ni annoncée (I-c, branche
/// du repli 6), le réticule avec elle. À 600 × 360 et 640 × 360 à 200 % (la
/// mesure d'I1, écart 2b). Le retrait par la seule largeur, la hauteur ne
/// manquant pas, est éprouvé sur des nombres (`map_layout_allocation_test`)
/// et sur la pose (`map_layout_test`) : aucune taille mesurée ne le donne.
void _groupeBandeANull() {
  group('D8 — une bande du bouton à 0 px se retire (arbitrage 23)', () {
    for (final Size taille in <Size>[
      const Size(600, 360),
      const Size(640, 360),
    ]) {
      final _Config c = _Config(
        nomTaille: '${taille.width.round()} × ${taille.height.round()}',
        taille: taille,
        plateforme: TargetPlatform.android,
        echelle: 2,
        lecture: MapScaleKind.ecoulement,
        enMode: true,
        fiche: _Fiche.aucune,
        avecAvis: true,
        marge: false,
      );
      _cas(
        c,
        'la bande n’a pas de place : retirée avec le réticule — ni peinte, ni '
        'touchable, ni focalisable, ni annoncée ; I-f',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          final MapLayoutAllocation repartition = e.rapport.value!.allocation;
          // La bande n'a pas de place (`bandFits` faux) : la pilule est plus
          // large que la place à gauche de la colonne — le retrait vient de
          // la largeur (23), pas seulement du plancher (21).
          final double pilule = tester
              .renderObject<RenderBox>(find.byType(DesignationBand))
              .getMinIntrinsicWidth(double.infinity);
          final double place =
              taille.width -
              3 * margeDeSurcouche -
              tester.getSize(find.byType(MapBottom)).width;
          expect(pilule, greaterThan(place), reason: 'la bande a sa place');
          expect(repartition.bandWithdrawn, isTrue, reason: '$repartition');
          expect(repartition.band, 0);
          expect(repartition.reticleBand, 0);
          expect(repartition.folds, contains(6));
          final _Echecs echecs = _Echecs();
          await _verifierReticuleEtFiche(tester, c, e, echecs);
          echecs.conclure();
        },
      );
    }
  });
}

/// Relecture de `D8` (m5) : en police de test, à 700 px, la pilule n'a plus
/// de place à côté de la colonne (arbitrage 23, `map_keyboard_test`) — le
/// rang de tabulation du bouton de désignation n'y était plus éprouvé à la
/// largeur de la colonne. En Roboto, à 700 × 900, la pilule tient : en mode,
/// sans fiche, le bouton suit « recentrer » et précède le « ⚠ Avertissement »
/// de la carte (`K1` de T3, spec § 5.7).
void _groupeRangDuBoutonALaColonne() {
  group('D8 — à la largeur de la colonne, le bouton de désignation garde son '
      'rang de tabulation', () {
    const _Config c = _Config(
      nomTaille: '700 × 900',
      taille: Size(700, 900),
      plateforme: TargetPlatform.android,
      echelle: 1,
      lecture: MapScaleKind.ecoulement,
      enMode: true,
      fiche: _Fiche.aucune,
      avecAvis: true,
      marge: false,
    );
    _cas(
      c,
      'la pilule tient à côté de la colonne ; Tab : … recentrer → bouton de '
      'désignation → « ⚠ Avertissement » de la carte',
      (WidgetTester tester) async {
        final _Ecran e = await _monter(tester, c);
        expect(c.largeur, MapLayoutWidth.wide);
        expect(e.rapport.value!.allocation.bandWithdrawn, isFalse);
        final Finder recentrer = find.byKey(mapRecenterButtonKey);
        final Finder bouton = find.byKey(mapDesignateCenterButtonKey);
        for (int i = 0; i < 30 && !focusedWithin(tester, recentrer); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(focusedWithin(tester, recentrer), isTrue, reason: 'recentrer');
        // Un Tab de plus : le bouton ; encore un : « ⚠ Avertissement ».
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, bouton), isTrue, reason: 'le bouton');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, _lienDeLaCarte()), isTrue, reason: '⚠');
        _atteignable(bouton, 'le bouton de désignation');
        expect(e.erreurs, isEmpty);
      },
    );
  });
}

// --- D8 : l'en-tête de la fiche qui cède (arbitrages 24 à 26) ---------------------

/// ⚠️ ÉCARTS MESURÉS, ARBITRÉS (arbitrages 24 et 25 du commanditaire,
/// 2026-10-18), verrouillés à leur mesure : en deçà, là où l'en-tête de la
/// fiche cède jusqu'à sa première rangée, son « ⚠ Avertissement » est rogné.
/// Il sort alors de l'ordre de tabulation, reste annoncé, et revient dès que la
/// place le montre (arbitrage 25). Valeur : la hauteur posée de la fiche
/// (l'en-tête : 108 à 100 %, 162 à 200 % ; la première rangée : 60 et 114).
const Map<String, double> _enTeteRogneEnDeca = <String, double>{
  '360 × 300, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      114,
  '360 × 300, 200 %, écoulement, en mode, fiche station, avis, sans marge': 114,
  '360 × 300, 100 %, écoulement, hors mode, fiche station, avis, marge': 80,
  '360 × 300, 100 %, écoulement, en mode, fiche station, avis, marge': 80,
  '360 × 300, 200 %, écoulement, hors mode, fiche station, avis, marge': 114,
  '360 × 300, 200 %, écoulement, en mode, fiche station, avis, marge': 114,
};

/// La lecture signalée par la relecture de `D8` (lecture 4), conforme à la
/// consigne et verrouillée à sa mesure : à 600 et 640 × 360, fiche station,
/// le corps de la fiche cède sous sa mesure mise en avant avant la colonne
/// (règle 1 de la consigne de `D8`) — la fiche à son en-tête (108), la tuile
/// du débit sous elle, la colonne à 180 px (sur 300, ou 315 à 200 %).
const Map<String, ({double fiche, double bas})>
_ficheASonEnTeteEnDeca = <String, ({double fiche, double bas})>{
  '600 × 360, 100 %, écoulement, hors mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '600 × 360, 100 %, écoulement, en mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '600 × 360, 200 %, écoulement, hors mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '600 × 360, 200 %, écoulement, en mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '640 × 360, 100 %, écoulement, hors mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '640 × 360, 100 %, écoulement, en mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '640 × 360, 200 %, écoulement, hors mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
  '640 × 360, 200 %, écoulement, en mode, fiche station, avis, sans marge': (
    fiche: 108,
    bas: 180,
  ),
};

/// Arbitrage 25 : le « ⚠ Avertissement » de la fiche [zone], rogné par
/// l'en-tête qui cède — ni entier dans la fiche, ni touchable ; hors de
/// l'ordre de tabulation (Tab ne s'y arrête jamais, l'étoile de la fiche si :
/// contrôle positif) ; toujours annoncé, son action ouvrant la fenêtre et sa
/// phrase datée (son nœud porte le libellé et l'action, et n'est pas caché).
Future<void> _verifierAvertissementRogne(
  WidgetTester tester,
  Finder zone,
) async {
  final Finder lien = find.descendant(
    of: zone,
    matching: find.byType(WarningLink),
  );
  final Finder etoile = find.descendant(
    of: zone,
    matching: find.byType(FavoriteStarButton),
  );
  final Rect r = tester.getRect(lien);
  final Rect fiche = tester.getRect(zone);
  expect(
    r.bottom,
    greaterThan(fiche.bottom + _tolerance),
    reason: 'le « ⚠ » de la fiche $r n’est pas rogné par la fiche $fiche',
  );
  expect(lien.hitTestable(), findsNothing, reason: '« ⚠ » rogné touchable');
  bool surLien = false;
  bool surEtoile = false;
  for (int i = 0; i < 40; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    surLien |= focusedWithin(tester, lien);
    surEtoile |= focusedWithin(tester, etoile);
  }
  expect(surLien, isFalse, reason: 'Tab s’arrête sur le « ⚠ » rogné');
  expect(surEtoile, isTrue, reason: 'Tab ne passe pas par l’étoile');
  final SemanticsHandle annonces = tester.ensureSemantics();
  await tester.pump();
  final SemanticsData noeud = tester
      .getSemantics(
        find.descendant(of: zone, matching: find.byKey(warningLinkKey)),
      )
      .getSemanticsData();
  annonces.dispose();
  expect(noeud.label, contains(warningLinkLabel), reason: 'non annoncé');
  expect(noeud.hasAction(SemanticsAction.tap), isTrue, reason: 'sans action');
  expect(noeud.flagsCollection.isHidden, isFalse, reason: 'annoncé caché');
}

/// Arbitrage 25, sa réciproque : le « ⚠ Avertissement » de la fiche [zone],
/// entier, est un arrêt de Tab.
Future<void> _verifierAvertissementAuClavier(
  WidgetTester tester,
  Finder zone,
) async {
  final Finder lien = find.descendant(
    of: zone,
    matching: find.byType(WarningLink),
  );
  bool surLien = false;
  for (int i = 0; i < 40 && !surLien; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    surLien = focusedWithin(tester, lien);
  }
  expect(surLien, isTrue, reason: 'Tab n’atteint pas le « ⚠ » entier');
}

/// Arbitrages 24 à 26 sous la marge d'un téléphone, et le retour du « ⚠ »
/// quand la place le montre (arbitrage 25). À 360 × 300, fiche station :
/// - à 100 % : la partie fixe à 48, l'en-tête rogné à 80, son « ⚠ » hors Tab
///   et annoncé ;
/// - à 200 % : la partie fixe à 0 (écart accepté, arbitrage 26), l'en-tête à
///   sa première rangée (114) ; la rangée du bas descend de 16 px sur la
///   fiche, et reste DEVANT elle (Important 2 de la relecture : l'arbitrage 22
///   ne vaut qu'à la colonne) : l'attribution est entière et se touche
///   jusqu'à son bas ; l'étoile et la fermeture, à 39–87 px du haut de la
///   fiche, restent touchables.
void _groupeEnTeteQuiCede() {
  group('D8 — arbitrages 25 et 26 : en-tête de fiche rogné, hors Tab', () {
    for (final double echelle in echellesDeTexte) {
      for (final bool enMode in <bool>[false, true]) {
        final _Config c = _Config(
          nomTaille: '360 × 300',
          taille: const Size(360, 300),
          plateforme: TargetPlatform.android,
          echelle: echelle,
          lecture: MapScaleKind.ecoulement,
          enMode: enMode,
          fiche: _Fiche.station,
          avecAvis: true,
          marge: true,
        );
        final double fixe = echelle == 2 ? 0 : 48;
        _cas(
          c,
          'sous la marge : partie fixe $fixe px, fiche à '
          '${_enTeteRogneEnDeca[c.nom]} px ; « ⚠ » de fiche hors Tab, annoncé ; '
          'étoile et fermeture touchables ; attribution entière ; I-f',
          (WidgetTester tester) async {
            final _Ecran e = await _monter(tester, c);
            final MapLayoutAllocation repartition = e.rapport.value!.allocation;
            final _Echecs echecs = _Echecs();
            final Finder zone = _fiche(tester);
            Finder dans(Finder f) => find.descendant(of: zone, matching: f);
            await echecs.verifier('mesures', () async {
              expect(
                repartition.blockFixed,
                moreOrLessEquals(fixe, epsilon: _tolerance),
                reason: 'limite acceptée (arbitrage 26) : $repartition',
              );
              expect(
                repartition.sheet,
                moreOrLessEquals(
                  _enTeteRogneEnDeca[c.nom]!,
                  epsilon: _tolerance,
                ),
                reason: 'CONSTAT (arbitrage 25) : $repartition',
              );
            });
            await echecs.verifier('étoile et fermeture', () async {
              for (final (String, Finder) k in <(String, Finder)>[
                ('fermeture', dans(find.byKey(stationSheetCloseButtonKey))),
                ('étoile', dans(find.byType(FavoriteStarButton))),
              ]) {
                _atteignable(k.$2, '${k.$1} de la fiche');
                _dedans(
                  tester.getRect(k.$2),
                  tester.getRect(zone),
                  '${k.$1} de la fiche',
                );
              }
            });
            await echecs.verifier('l’attribution', () async {
              final Finder attribution = find.byType(IgnAttributionBadge);
              final Rect a = tester.getRect(attribution);
              _dedans(a, _zoneSure(c), 'l’attribution');
              // Touchée jusqu'à son bas : rien ne la recouvre.
              for (final Offset p in <Offset>[
                a.center,
                Offset(a.center.dx, a.bottom - 2),
              ]) {
                expect(
                  _toucheEn(tester, attribution, p),
                  isTrue,
                  reason: 'l’attribution $a recouverte en $p',
                );
              }
            });
            await echecs.verifier('arbitrage 25', () async {
              await _verifierAvertissementRogne(tester, zone);
            });
            await echecs.verifier('I-f', () async {
              expect(e.erreurs, isEmpty);
            });
            echecs.conclure();
          },
        );
      }
    }

    // Arbitrage 25, « celui de la carte reste atteignable » : à 360 × 300 et
    // 100 %, sous la marge, là où le « ⚠ » de la fiche sort de l'ordre de
    // tabulation, celui de la carte s'atteint en glissant sur la partie fixe
    // et au clavier (à 200 %, la partie fixe à 0 : limite de l'arbitrage 26).
    for (final bool enMode in <bool>[false, true]) {
      final _Config c = _Config(
        nomTaille: '360 × 300',
        taille: const Size(360, 300),
        plateforme: TargetPlatform.android,
        echelle: 1,
        lecture: MapScaleKind.ecoulement,
        enMode: enMode,
        fiche: _Fiche.station,
        avecAvis: true,
        marge: true,
      );
      _cas(
        c,
        'sous la marge, le « ⚠ » de la fiche rogné : le « ⚠ Avertissement » '
        'de la carte reste atteignable, en glissant et au clavier '
        '(arbitrage 25)',
        (WidgetTester tester) async {
          final _Ecran e = await _monter(tester, c);
          final Rect zone = _zoneSure(c);
          final List<String> echecs = <String>[
            ?_plancherTenu(tester, c, zone),
            ?await _atteindreEnGlissant(tester, _lienDeLaCarte(), zone),
          ];
          final _Ecran remonte = await _monter(tester, c);
          echecs.addAll(<String>[
            ?await _atteindreAuClavier(tester, _lienDeLaCarte(), zone),
          ]);
          expect(echecs, isEmpty, reason: _mesureI1(tester, remonte));
          expect(e.erreurs, isEmpty);
          expect(remonte.erreurs, isEmpty);
        },
      );
    }

    // « Il revient dès que la place le montre » : 360 × 300, fiche station,
    // sans marge — à 200 %, rogné et hors Tab ; le texte ramené à 100 %,
    // l'en-tête entier, le « ⚠ » de la fiche est de nouveau un arrêt de Tab.
    final _Config retour = _Config(
      nomTaille: '360 × 300',
      taille: const Size(360, 300),
      plateforme: TargetPlatform.android,
      echelle: 2,
      lecture: MapScaleKind.ecoulement,
      enMode: false,
      fiche: _Fiche.station,
      avecAvis: true,
      marge: false,
    );
    _cas(
      retour,
      'le texte ramené à 100 %, le « ⚠ » de la fiche revient dans l’ordre de '
      'tabulation (arbitrage 25)',
      (WidgetTester tester) async {
        final ValueNotifier<double> echelle = ValueNotifier<double>(2);
        addTearDown(echelle.dispose);
        final _Ecran e = await _monter(tester, retour, echelle: echelle);
        final Finder zone = _fiche(tester);
        await _verifierAvertissementRogne(tester, zone);
        echelle.value = 1;
        await tester.pumpAndSettle();
        expect(
          e.rapport.value!.allocation.sheet,
          greaterThanOrEqualTo(
            tester
                    .getRect(
                      find.descendant(
                        of: zone,
                        matching: find.byKey(sheetFrameHeaderKey),
                      ),
                    )
                    .height -
                _tolerance,
          ),
          reason: 'l’en-tête entier à 100 %',
        );
        _atteignable(
          find.descendant(of: zone, matching: find.byType(WarningLink)),
          '« ⚠ Avertissement » de la fiche',
        );
        await _verifierAvertissementAuClavier(tester, zone);
        expect(e.erreurs, isEmpty);
      },
    );
  });
}

// --- I1 : les anciens « CONSTAT » en deçà, remplacés (R15) -----------------------

/// Les tailles des anciens « CONSTAT » en deçà (`task-D2-report.md`, R15) :
/// 360 × 300, 600 × 360, 640 × 360 et 800 × 400 (`map_view_test`, Windows),
/// avec 844 × 390, la dernière de [taillesEnDeca].
const List<(Size, TargetPlatform)> _taillesDesConstats =
    <(Size, TargetPlatform)>[
      (Size(360, 300), TargetPlatform.android),
      (Size(600, 360), TargetPlatform.android),
      (Size(640, 360), TargetPlatform.android),
      (Size(844, 390), TargetPlatform.android),
      (Size(800, 400), TargetPlatform.windows),
    ];

/// Les paires d'éléments PEINTS qui se recoupent (les éléments d'I-j), nommées
/// sans leurs rectangles.
Set<String> _pairesQuiSeRecoupent(WidgetTester tester, _Config c, _Ecran e) {
  final bool bandeRetiree = e.rapport.value?.allocation.bandWithdrawn ?? false;
  final List<MapEntry<String, Rect>> peints = <String, Rect>{
    ..._bloc(tester),
    ..._bas(tester),
    if (c.enMode && !bandeRetiree) ..._bande(tester, e),
    if (c.fiche != _Fiche.aucune) 'fiche': tester.getRect(_fiche(tester)),
  }.entries.toList();
  return <String>{
    for (int i = 0; i < peints.length; i++)
      for (int j = i + 1; j < peints.length; j++)
        if (_recoupe(peints[i].value, peints[j].value))
          '${peints[i].key} × ${peints[j].key}',
  };
}

/// R15 : les « CONSTAT » en deçà de l'ancienne disposition décrivaient des
/// recouvrements (la pilule du bouton sur « ⚠ Avertissement » à 360 × 300, le
/// groupe étendu sur la légende à 640 × 360, la légende dans la zone des
/// contrôles à 800 × 400) et un bas qui défilait (« Favoris » dépassant de
/// 12 px à 600 × 360 et 640 × 360). Leur invariant, sur la nouvelle
/// disposition : aucune paire d'éléments PEINTS ne se recoupe (I-j) ; le bas
/// de la carte est posé dans la zone sûre et ses cinq boutons s'atteignent ;
/// fiche ouverte, son étoile et sa fermeture s'atteignent au toucher ; aucune
/// erreur de rendu.
///
/// `D8` (arbitrages 21 à 24) remplace les « CONSTAT remonté (I1) » de
/// `_recoupementsEnDeca` — à 600 × 360 et 640 × 360, la colonne descendait
/// sur l'en-tête de la fiche (étoile et fermeture hors d'atteinte) ; en mode
/// sans fiche à 200 %, la bande à 0 px se peignait sous l'écran : la table est
/// vidée. Et l'invariant change là où les arbitrages le changent : à la
/// largeur de la colonne, la colonne CÈDE — ses boutons défilent, ancrés en
/// bas, au-dessus de l'attribution, qui reste entière et affichée ; un bouton
/// défilé hors de vue s'atteint en glissant sur la colonne ou au clavier (le
/// focus l'amène en vue). L'en-tête de la fiche peut céder, jamais sous sa
/// première rangée : son « ⚠ Avertissement » s'atteint tant que l'en-tête est
/// entier ; l'étoile et la fermeture, toujours. Rien du bas ne se peint sur la
/// fiche (arbitrage 22).
void _groupeConstatsEnDeca() {
  // Remplace les « CONSTAT » de l'ancienne disposition (R15), puis ceux
  // d'I1 (`D8`).
  group('I1, R15, D8 — en deçà : rien ne se recoupe, le bas et la fiche', () {
    for (final (Size, TargetPlatform) t in _taillesDesConstats) {
      for (final double echelle in echellesDeTexte) {
        for (final bool enMode in <bool>[false, true]) {
          for (final _Fiche fiche in <_Fiche>[_Fiche.aucune, _Fiche.station]) {
            final _Config c = _Config(
              nomTaille: '${t.$1.width.round()} × ${t.$1.height.round()}',
              taille: t.$1,
              plateforme: t.$2,
              echelle: echelle,
              lecture: MapScaleKind.ecoulement,
              enMode: enMode,
              fiche: fiche,
              avecAvis: true,
              marge: false,
            );
            _cas(
              c,
              'R15, D8 : aucune paire peinte ne se recoupe ; le bas dans la '
              'zone sûre, l’attribution entière, ses cinq boutons '
              'atteignables, au besoin en le faisant défiler'
              '${fiche == _Fiche.aucune ? '' : ' ; étoile et fermeture de la fiche touchables, rien du bas sur elle'}'
              ' ; I-f',
              (WidgetTester tester) async {
                final _Ecran e = await _monter(tester, c);
                final _Echecs echecs = _Echecs();
                final MapLayoutAllocation repartition =
                    e.rapport.value!.allocation;
                await echecs.verifier('I-j', () async {
                  expect(
                    _pairesQuiSeRecoupent(tester, c, e),
                    isEmpty,
                    reason: 'les paires peintes qui se recoupent',
                  );
                });
                await echecs.verifier('le bas', () async {
                  final Rect zone = _zoneSure(c);
                  final RenderBox bas = tester.renderObject(
                    find.byType(MapBottom),
                  );
                  // Posé à la hauteur que la répartition lui rend : entière,
                  // ou — la colonne, en deçà — repliée jusqu'à son
                  // attribution au plus.
                  expect(
                    bas.size.height,
                    moreOrLessEquals(repartition.bottom, epsilon: _tolerance),
                    reason: 'le bas posé ($repartition)',
                  );
                  expect(
                    bas.size.height,
                    greaterThanOrEqualTo(
                      bas.getMinIntrinsicHeight(bas.size.width) - _tolerance,
                    ),
                    reason: 'le bas sous sa hauteur repliée',
                  );
                  _dedans(
                    tester.getRect(find.byType(MapBottom)),
                    zone,
                    'le bas',
                  );
                  final Rect attribution = tester.getRect(
                    find.byType(IgnAttributionBadge),
                  );
                  _dedans(attribution, zone, 'l’attribution');
                  _dedans(
                    attribution,
                    tester.getRect(find.byType(MapBottom)),
                    'l’attribution (dans le bas)',
                  );
                  for (final MapEntry<String, Rect> p in _bas(tester).entries) {
                    _dedans(p.value, zone, p.key);
                  }
                  for (final (String, Key) b in <(String, Key)>[
                    ('Favoris', mapFavoritesButtonKey),
                    ('Filtres', mapFiltersButtonKey),
                    ('−', mapZoomOutButtonKey),
                    ('+', mapZoomInButtonKey),
                    ('recentrer', mapRecenterButtonKey),
                  ]) {
                    final Finder bouton = find.byKey(b.$2);
                    // Défilé hors de vue : amené comme le focus l'amène.
                    if (bouton.hitTestable().evaluate().isEmpty) {
                      await _amener(tester, bouton);
                    }
                    _atteignable(bouton, b.$1);
                  }
                  _atteignable(
                    find.byType(IgnAttributionBadge),
                    'l’attribution',
                  );
                });
                if (fiche != _Fiche.aucune) {
                  await echecs.verifier('l’en-tête de la fiche', () async {
                    final Finder zone = _fiche(tester);
                    Finder dans(Finder f) =>
                        find.descendant(of: zone, matching: f);
                    final double enTete = tester
                        .getRect(dans(find.byKey(sheetFrameHeaderKey)))
                        .height;
                    // L'en-tête entier, sauf là où il cède (arbitrage 24),
                    // constaté à sa mesure : son « ⚠ » y est rogné, hors Tab
                    // et annoncé (arbitrage 25).
                    final double? rogne = _enTeteRogneEnDeca[c.nom];
                    if (rogne == null) {
                      expect(
                        repartition.sheet,
                        greaterThanOrEqualTo(enTete - _tolerance),
                        reason: 'l’en-tête de la fiche cède ($repartition)',
                      );
                      _atteignable(
                        dans(find.byType(WarningLink)),
                        '« ⚠ Avertissement » de la fiche',
                      );
                    } else {
                      expect(
                        repartition.sheet,
                        moreOrLessEquals(rogne, epsilon: _tolerance),
                        reason:
                            'CONSTAT (D8, arbitrage 25) : la fiche posée à '
                            '$rogne px — écart corrigé ? retirer la ligne de '
                            '_enTeteRogneEnDeca',
                      );
                      await _verifierAvertissementRogne(tester, zone);
                    }
                    // Arbitrage 26 et relecture de `D8` (lecture 4) : à 600 et
                    // 640 × 360, fiche station, le corps cède sous sa mesure
                    // avant la colonne — la fiche réduite à son en-tête (la
                    // tuile du débit sous elle), la colonne à 180 px.
                    final ({double fiche, double bas})? lecture =
                        _ficheASonEnTeteEnDeca[c.nom];
                    if (lecture != null) {
                      expect(
                        repartition.sheet,
                        moreOrLessEquals(lecture.fiche, epsilon: _tolerance),
                        reason: 'la fiche posée ($repartition)',
                      );
                      expect(
                        repartition.bottom,
                        moreOrLessEquals(lecture.bas, epsilon: _tolerance),
                        reason: 'la colonne posée ($repartition)',
                      );
                      expect(
                        find
                            .byKey(stationDischargeTileKey)
                            .hitTestable()
                            .evaluate(),
                        isEmpty,
                        reason: 'la tuile du débit se voit',
                      );
                    }
                    for (final (String, Finder) k in <(String, Finder)>[
                      (
                        'fermeture',
                        dans(find.byKey(stationSheetCloseButtonKey)),
                      ),
                      ('étoile', dans(find.byType(FavoriteStarButton))),
                    ]) {
                      _atteignable(k.$2, '${k.$1} de la fiche');
                      _dedans(
                        tester.getRect(k.$2),
                        tester.getRect(zone),
                        '${k.$1} de la fiche (entière dans la fiche)',
                      );
                    }
                    final Rect bas = tester
                        .getRect(find.byType(MapBottom))
                        .intersect(tester.getRect(zone));
                    expect(
                      bas.width <= _tolerance || bas.height <= _tolerance,
                      isTrue,
                      reason: 'le bas se pose sur la fiche ($bas)',
                    );
                  });
                }
                await echecs.verifier('I-f', () async {
                  expect(
                    e.erreurs,
                    isEmpty,
                    reason: e.erreurs
                        .map((FlutterErrorDetails d) => '$d')
                        .join('\n'),
                  );
                });
                echecs.conclure();
              },
            );
          }
        }
      }
    }
  });
}

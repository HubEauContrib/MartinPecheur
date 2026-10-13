// La zone des fiches dans la carte (`buildMapOverlays`, bas de la carte) est
// BORNÉE à la hauteur dont la carte dispose et DÉFILE au-delà (arbitrage du
// commanditaire du 2026-10-13). Avant, une fiche plus haute que la carte —
// police à 200 %, téléphone en paysage — débordait de l'écran
// (« A RenderFlex overflowed by N pixels on the bottom ») et son bas était
// inatteignable : mesuré en Roboto, la fiche ONDE prête à 360 × 640 et 200 %
// débordait de 1 202 px, à 640 × 360 et 100 % de 115 px.
//
// Ce que ces tests prouvent, et rien de plus. Les fiches sont les VRAIES
// (`StationSheetPanel`, `OndeSheetPanel`), câblées comme `main.dart` : les deux
// panneaux toujours fournis, l'autre à l'état fermé, une étoile de favori.
// « Ce qu'on VOIT de la fiche » ([_vu]) est le cadre de la fiche ouverte coupé
// par le plus proche `Scrollable` qui la porte, s'il y en a un : la formulation
// ne dépend d'aucune implémentation. « La fenêtre » est le rectangle de ce
// `Scrollable`.
//
// - A. matrice (80 cas : quatre tailles, 100 % et 200 %, hors mode et EN MODE
//   « Restrictions », cinq états de fiche), quatre constats rassemblés et
//   rendus ENSEMBLE : (1) aucune erreur de rendu pendant la pose ; (2) ce
//   qu'on voit de la fiche tient dans la carte (haut à 8 px au moins, bas à
//   32 px du bord hors mode — la marge de l'attribution IGN —, au bord en
//   mode) ; (3) au repos, le HAUT du premier texte est dans ce qu'on voit ;
//   (4) la dernière ligne s'amène dans la fenêtre de défilement : après
//   `ensureVisible`, son BAS est au plus au bas de ce qu'on voit ET au plus à
//   la limite basse de la carte (la même qu'en 2), sans erreur de rendu. Sans
//   défilement, ce qu'on voit est le cadre entier, qui contient toujours la
//   dernière ligne : seule la limite de la carte fait alors rougir le
//   constat 4. Un cas qui déborde échoue sur les constats 1, 2 et 4 à la
//   fois, pas seulement sur le premier — sauf débordement de quelques
//   pixels, qui n'échoue que sur le premier ou les deux premiers ;
// - B. la fiche ONDE prête à 200 % défile réellement aux quatre tailles, et sa
//   fenêtre va exactement de 8 px à la hauteur de la carte moins 32 px (hors
//   mode) — cette égalité verrouille la borne ; B bis : la même, EN MODE, va
//   de 8 px à la hauteur de la carte ; B ter : une fiche qui tient (cas
//   court, hors mode) a son cadre posé à la hauteur de la carte moins 32 px
//   (ONDE) ou moins 40 px (station : l'écart de 8 px et le panneau ONDE
//   fermé sont dessous) — ce qui verrouille aussi la place de la borne
//   (dans l'`Align(centerLeft)`, non autour) ;
// - C. un cran de molette (Windows) et un glisser du doigt (Android) posés sur
//   la fiche la font défiler ;
// - D. NON-RÉGRESSION, verte avant comme après : un tap et un cran de molette
//   posés à droite de la fiche, et un tap posé dans l'écart de 8 px qui la
//   sépare du panneau ONDE fermé, parviennent à la carte dessous ;
// - E. NON-RÉGRESSION, verte avant comme après : aucun défilement de surcouche
//   ne s'attache au `PrimaryScrollController` de la route (même motif que le
//   groupe « défilements de surcouche » de `map_designation_test.dart`) ;
// - F. NON-RÉGRESSION, verte avant comme après : en mode, la fiche garde la
//   priorité sur la bande du bouton de désignation — rien n'en est coupé ;
// - G. deux CONSTAT, des faits mesurés qui ne sont PAS des invariants voulus
//   (même convention que `map_overlays_phone_test.dart`), à corriger À LA MAIN
//   quand l'écran change, jamais en silence — `docs/project-state.md`,
//   point 60 : la position de défilement survit au changement de fiche ; à
//   200 % en portrait, le bas de la fiche défilée au bout reste en partie sous
//   l'attribution IGN.
//
// Les cas B à G posent des configurations déjà couvertes par la matrice A, qui
// affirme seule l'absence d'erreur de rendu : ils ne la répètent pas, pour que
// B et C échouent sur ce qu'ils testent (un défilement absent) et non sur le
// débordement. Seule exception : la seconde pose du CONSTAT de position, une
// autre station, n'est pas dans la matrice.
//
// La plateforme (`N9` de T3) : un cas dont le plus petit côté de la fenêtre
// fait moins de 600 px est un cas de téléphone — en portrait (360 × 640,
// 390 × 844) comme en paysage (640 × 360) —, il tourne sous Android et son
// titre commence par « Android : » ; 800 × 740 tourne sous Windows.
//
// La police : Roboto, depuis le SDK Flutter ([_chargerRoboto]) — pas la police
// de test, où chaque glyphe est un carré d'un em. Windows rend en Segoe UI, non
// mesurée ici : ces pixels sont des mesures de test, pas des constats d'écran.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

/// Tolérance sur les bords, en pixels : la même que celle de la dernière ligne.
const double _tolerance = 0.5;

/// Marge haute de la zone des fiches (`_overlayPadding` de `map_view.dart`).
const double _margeHaute = 8;

/// Marge basse de la zone des fiches HORS MODE (`_sheetBottomPadding` de
/// `map_view.dart`) : elle dégage l'attribution IGN. En mode, la bande du
/// bouton de désignation la porte.
const double _margeAttribution = 32;

/// Charge ROBOTO — toutes les graisses `Roboto-*.ttf` du SDK Flutter — sous la
/// famille `Roboto`, celle que Material demande sur Android, et enregistre les
/// mêmes octets aussi sous « Segoe UI », en substitut de la police de Windows.
///
/// Même procédé que `_chargerRoboto` de `map_overlays_phone_test.dart`, dont
/// ce fichier reprend la politique : si `FLUTTER_ROOT`, le dossier des polices
/// ou les polices manquent, le fichier ÉCHOUE avec un message clair — jamais de
/// repli silencieux sur la police de test, tous les pixels d'ici seraient faux.
Future<void> _chargerRoboto() async {
  final String? racine = Platform.environment['FLUTTER_ROOT'];
  if (racine == null || racine.isEmpty) {
    fail(
      'FLUTTER_ROOT est absent : les polices Roboto du SDK Flutter sont '
      'introuvables. Ce fichier mesure en Roboto, jamais en police de test : '
      'lancer les tests par `flutter test`.',
    );
  }
  final Directory dossier = Directory(
    '$racine/bin/cache/artifacts/material_fonts',
  );
  if (!dossier.existsSync()) {
    fail(
      '${dossier.path} est introuvable : lancer `flutter precache`. Ce '
      'fichier mesure en Roboto, jamais en police de test.',
    );
  }
  final List<File> polices = dossier.listSync().whereType<File>().where((
    File f,
  ) {
    final String nom = f.uri.pathSegments.last.toLowerCase();
    return nom.startsWith('roboto-') && nom.endsWith('.ttf');
  }).toList();
  if (polices.isEmpty) {
    fail(
      'Aucune police Roboto-*.ttf dans ${dossier.path} : lancer '
      '`flutter precache`. Ce fichier mesure en Roboto, jamais en police de '
      'test.',
    );
  }
  final List<Future<ByteData>> octets = <Future<ByteData>>[
    for (final File police in polices)
      Future<ByteData>.value(ByteData.sublistView(police.readAsBytesSync())),
  ];
  for (final String famille in <String>['Roboto', 'Segoe UI']) {
    final FontLoader chargeur = FontLoader(famille);
    for (final Future<ByteData> police in octets) {
      chargeur.addFont(police);
    }
    await chargeur.load();
  }
}

// --- Données réelles des tests des deux fiches (K447001001, K4520001). ---

final DateTime _measuredAt = DateTime.utc(2026, 8, 27, 8);

/// Le décalage UTC → heure locale fixé (`UtcOffsetOf`) : la fiche ne lit pas
/// l'horloge de la machine.
Duration _offset(DateTime _) => const Duration(hours: 2);

StationCode _code() => StationCode('K447001001');

Station _blois() => Station(
  code: _code(),
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
  departement: DepartementCode('41'),
  riverLabel: 'la Loire',
  inService: true,
);

/// Une AUTRE station, pour poser une seconde fiche haute au même emplacement :
/// un double de test, pas une station réelle — seuls son code et son libellé
/// diffèrent de [_blois].
Station _autreStation() => Station(
  code: StationCode('K000000002'),
  label: 'Station de test, autre libellé',
  latitude: 47.584957074,
  longitude: 1.335147948,
  departement: DepartementCode('41'),
  riverLabel: 'la Loire',
  inService: true,
);

const Qualification _qualification = Qualification(
  statusCode: 12,
  statusLabel: 'Pré-validée',
  qualificationCode: 20,
  qualificationLabel: 'Bonne',
);

HydroObservation _discharge() => HydroObservation(
  station: _code(),
  measuredAt: _measuredAt,
  grandeur: Grandeur.debit,
  discharge: const CubicMetresPerSecond(47.8),
  level: null,
  qualification: _qualification,
);

HydroObservation _level() => HydroObservation(
  station: _code(),
  measuredAt: _measuredAt,
  grandeur: Grandeur.hauteur,
  discharge: null,
  level: const Metres(-1.232),
  qualification: _qualification,
);

StationSheetData _avecValeurs() => StationSheetData(
  station: _blois(),
  discharge: _discharge(),
  level: _level(),
  freshness: Freshness.fraiche,
  statusLabel: 'Pré-validée',
  qualificationLabel: 'Bonne',
  stalenessNotice: null,
);

// Ce que `StationSheetViewModel` produit sans aucune observation : ni débit ni
// hauteur, statut « non renseigné », qualification « non qualifiée ».
StationSheetData _sansValeur({Station? station}) => StationSheetData(
  station: station ?? _blois(),
  discharge: null,
  level: null,
  freshness: null,
  statusLabel: 'non renseigné',
  qualificationLabel: 'non qualifiée',
  stalenessNotice: null,
);

OndePoint _chaon() => OndePoint(
  code: OndeStationCode('K4520001'),
  label: 'LA RIVIERE AUX LOCHES A CHAON',
  latitude: 47.610620493,
  longitude: 2.173858157,
  waterCourseLabel: 'ruisseau la rivière aux loches',
  departement: const AdministrativeArea(code: '41', label: '41'),
);

OndeObservation _observation(DateTime at, String code, String label) {
  final OndePoint on = _chaon();
  return OndeObservation(
    station: on.code,
    point: on,
    observedAt: at,
    category: flowCategoryFromCode(code),
    rawFlowCode: code,
    officialLabel: label,
    campaignCode: '1',
  );
}

List<OndeObservation> _history() => <OndeObservation>[
  _observation(DateTime.utc(2026, 8, 25), '3', 'Assec'),
  _observation(DateTime.utc(2026, 7, 24), '3', 'Assec'),
  _observation(DateTime.utc(2026, 6, 26), '2', 'Ecoulement non visible'),
  _observation(
    DateTime.utc(2026, 5, 26),
    '1a',
    'Ecoulement visible acceptable',
  ),
  _observation(DateTime.utc(2025, 9, 26), '1f', 'Ecoulement visible faible'),
];

OndeSheetData _ondePrete() {
  final List<OndeObservation> campaigns = _history();
  return OndeSheetData(
    point: _chaon(),
    latest: campaigns.first,
    history: List<OndeObservation>.unmodifiable(campaigns),
    age: CampaignAge.recente,
    ageInDays: 19,
    officialModalityText: 'code 3 — Assec',
    seasonNotice: ondeSeasonNotice,
  );
}

const FavoriteStar _etoile = FavoriteStar(filled: false, enabled: true);

/// Un cas : l'état de chaque panneau (l'autre est fermé, comme en production),
/// le panneau ouvert, et la dernière ligne de la fiche. Les chercheurs sont des
/// fermetures : un `Finder` se construit à l'usage, jamais à la déclaration.
typedef _Cas = ({
  String nom,
  StationSheetState station,
  OndeSheetState onde,
  Finder Function() panneau,
  Finder Function() derniereLigne,
});

Finder _panneauStation() => find.byType(StationSheetPanel);

Finder _panneauOnde() => find.byType(OndeSheetPanel);

/// Les cinq cas de la matrice. La dernière ligne de la fiche station est sa
/// qualification ; celle de la fiche ONDE prête, le rappel de rythme
/// (`BR-010`) ; les fiches ONDE en cours et en échec n'ont qu'un texte.
List<_Cas> _lesCas() => <_Cas>[
  (
    nom: 'station prête avec valeurs',
    station: Prete(_avecValeurs()),
    onde: const OndeSheetFermee(),
    panneau: _panneauStation,
    derniereLigne: () => find.textContaining('Qualification :'),
  ),
  (
    nom: 'station prête sans valeur',
    station: Prete(_sansValeur()),
    onde: const OndeSheetFermee(),
    panneau: _panneauStation,
    derniereLigne: () => find.textContaining('Qualification :'),
  ),
  (
    nom: 'ONDE en cours',
    station: const Fermee(),
    onde: OndeSheetEnCours(_chaon()),
    panneau: _panneauOnde,
    derniereLigne: () => find.textContaining('Chargement du point'),
  ),
  (
    nom: 'ONDE prête',
    station: const Fermee(),
    onde: OndeSheetPrete(_ondePrete()),
    panneau: _panneauOnde,
    derniereLigne: () => find.text(ondeSeasonNotice),
  ),
  (
    nom: 'ONDE en échec',
    station: const Fermee(),
    onde: OndeSheetEnEchec(_chaon(), StateError('x')),
    panneau: _panneauOnde,
    derniereLigne: () => find.textContaining("n'a pas répondu"),
  ),
];

_Cas _cas(String nom) => _lesCas().singleWhere((_Cas c) => c.nom == nom);

/// Une fiche station prête sans valeur pour [station] : la fiche haute du
/// CONSTAT sur la position de défilement.
_Cas _casStationSansValeur(Station station) => (
  nom: 'station prête sans valeur, ${station.label}',
  station: Prete(_sansValeur(station: station)),
  onde: const OndeSheetFermee(),
  panneau: _panneauStation,
  derniereLigne: () => find.textContaining('Qualification :'),
);

/// Ce qui parvient à la couche « carte » posée sous les surcouches.
final class _Carte {
  int taps = 0;
  int crans = 0;
}

/// Exécute [corps] en CAPTURANT les erreurs de Flutter au lieu de les laisser
/// faire échouer le test, et les rend. Le gestionnaire d'origine est remis
/// avant le retour : le test ne le laisse pas modifié.
Future<List<FlutterErrorDetails>> _capturer(
  Future<void> Function() corps,
) async {
  final List<FlutterErrorDetails> erreurs = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? avant = FlutterError.onError;
  FlutterError.onError = erreurs.add;
  try {
    await corps();
  } finally {
    FlutterError.onError = avant;
  }
  return erreurs;
}

/// Pose les surcouches de la carte à [taille] et [textScale], avec les vraies
/// fiches de [cas], et rend les erreurs de rendu levées pendant la pose —
/// aucune n'est filtrée. Sous les surcouches, une couche « carte » compte les
/// taps et les crans de molette qui lui parviennent ([carte]). Les surcouches
/// sont dans un groupe de tabulation ordonné, comme dans `MapView` (`K2`).
Future<List<FlutterErrorDetails>> _poser(
  WidgetTester tester, {
  required Size taille,
  required double textScale,
  required _Cas cas,
  bool enMode = false,
  _Carte? carte,
}) {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  return _capturer(() async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: (PointerSignalEvent _) => carte?.crans++,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => carte?.taps++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                ...buildMapOverlays(
                  filterHidesEverything: false,
                  onClearFilters: () {},
                  filterActive: false,
                  onOpenFilters: () {},
                  scale: MapScaleKind.debit,
                  onSelect: (MapScaleKind kind) {},
                  onWiden: () {},
                  error: null,
                  stations: <StationPoint>[
                    StationPoint(
                      code: _code(),
                      label: 'La Loire à Blois',
                      latitude: 47.584957074484784,
                      longitude: 1.3351479476905552,
                    ),
                  ],
                  ondeObservations: <OndeStationCode, OndeObservation>{
                    _chaon().code: _history().first,
                  },
                  ondeUnreadableRows: 0,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                  onDesignateCenter: enMode ? () {} : null,
                  onToggleDesignationMode: () {},
                  stationSheet: StationSheetPanel(
                    state: cas.station,
                    onClose: () {},
                    favoriteStar: cas.station is Fermee ? null : _etoile,
                    onToggleFavorite: () {},
                    utcOffsetOf: _offset,
                  ),
                  ondeSheet: OndeSheetPanel(
                    state: cas.onde,
                    onClose: () {},
                    favoriteStar: cas.onde is OndeSheetFermee ? null : _etoile,
                    onToggleFavorite: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

/// Le cadre de la fiche ouverte : le premier `Material` du panneau.
Rect _cadre(WidgetTester tester, Finder panneau) => tester.getRect(
  find.descendant(of: panneau, matching: find.byType(Material)).first,
);

/// Le plus proche `Scrollable` qui porte [panneau] ; vide quand rien ne le
/// porte.
Finder _defilements(Finder panneau) =>
    find.ancestor(of: panneau, matching: find.byType(Scrollable));

/// Ce qu'on VOIT de la fiche ouverte : son cadre ([_cadre]) coupé par le
/// rectangle du plus proche `Scrollable` qui la porte, s'il en existe un —
/// sinon le cadre entier.
Rect _vu(WidgetTester tester, Finder panneau) {
  final Rect cadre = _cadre(tester, panneau);
  final Finder defilements = _defilements(panneau);
  if (defilements.evaluate().isEmpty) {
    return cadre;
  }
  return cadre.intersect(tester.getRect(defilements.first));
}

/// La fenêtre de défilement de [panneau] : le rectangle du plus proche
/// `Scrollable` qui le porte. Échoue, en le disant, quand rien ne le porte.
Rect _fenetre(WidgetTester tester, Finder panneau) {
  final Finder defilements = _defilements(panneau);
  expect(
    defilements,
    findsAtLeastNWidgets(1),
    reason: "la fiche n'est portée par aucun défilement",
  );
  return tester.getRect(defilements.first);
}

/// La première ligne de chaque erreur de [erreurs], séparées par « | ».
String _resume(List<FlutterErrorDetails> erreurs) => erreurs
    .map((FlutterErrorDetails d) => d.exceptionAsString().split('\n').first)
    .join(' | ');

/// [interieur] tient-il entièrement dans [exterieur] ?
bool _dans(Rect interieur, Rect exterieur) =>
    interieur.left >= exterieur.left - _tolerance &&
    interieur.top >= exterieur.top - _tolerance &&
    interieur.right <= exterieur.right + _tolerance &&
    interieur.bottom <= exterieur.bottom + _tolerance;

/// Les deux rectangles ont-ils les mêmes quatre bords ?
bool _egaux(Rect a, Rect b) => _dans(a, b) && _dans(b, a);

/// La position du plus proche défilement qui porte [panneau]. Échoue, en le
/// disant, quand la fiche n'est portée par aucun défilement.
ScrollPosition _position(WidgetTester tester, Finder panneau) {
  final Finder defilements = _defilements(panneau);
  expect(
    defilements,
    findsAtLeastNWidgets(1),
    reason:
        "la fiche n'est portée par aucun défilement : bornée par rien, "
        'elle déborde de la carte et son bas est hors de portée',
  );
  return tester.state<ScrollableState>(defilements.first).position;
}

/// Un cran de molette de [dy] pixels (positif : vers le bas du contenu), posé
/// en [p].
Future<void> _cranDeMolette(WidgetTester tester, Offset p, double dy) async {
  final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(souris.hover(p));
  await tester.sendEventToBinding(souris.scroll(Offset(0, dy)));
  await tester.pump();
}

String _nom(Size taille, double textScale) =>
    '${taille.width.toInt()} × ${taille.height.toInt()}, police '
    '${(textScale * 100).toInt()} %';

String _mode(bool enMode) => enMode ? 'EN MODE Restrictions' : 'hors mode';

/// Un test de widget posé sur la plateforme que [taille] commande : Android
/// quand le plus petit côté de la fenêtre fait moins de 600 px (le titre
/// commence alors par « Android : »), Windows sinon.
void _test(
  Size taille,
  String titre,
  Future<void> Function(WidgetTester tester) corps,
) {
  if (taille.shortestSide < 600) {
    testWidgetsOnAndroid('Android : $titre', corps);
  } else {
    testWidgetsOnWindows(titre, corps);
  }
}

/// Le cas A : les quatre constats (voir l'en-tête), rassemblés et rendus
/// ensemble.
Future<void> _verifierMatrice(
  WidgetTester tester, {
  required Size taille,
  required double textScale,
  required bool enMode,
  required _Cas cas,
}) async {
  final List<String> constats = <String>[];

  final List<FlutterErrorDetails> erreurs = await _poser(
    tester,
    taille: taille,
    textScale: textScale,
    cas: cas,
    enMode: enMode,
  );
  if (erreurs.isNotEmpty) {
    constats.add('1. erreur(s) de rendu pendant la pose : ${_resume(erreurs)}');
  }

  final Finder panneau = cas.panneau();
  final Rect cadre = _cadre(tester, panneau);
  final Rect vu = _vu(tester, panneau);
  final double basMax = enMode
      ? taille.height
      : taille.height - _margeAttribution;
  if (vu.top < _margeHaute - _tolerance) {
    constats.add('2. le haut de la fiche vue (${vu.top}) est à moins de 8');
  }
  if (vu.bottom > basMax + _tolerance) {
    constats.add(
      '2. le bas de la fiche vue (${vu.bottom}) dépasse $basMax '
      '(fiche vue $vu, cadre entier $cadre)',
    );
  }

  final Rect premier = tester.getRect(
    find.descendant(of: panneau, matching: find.byType(Text)).first,
  );
  // Le HAUT du premier texte, pas le texte entier : une phrase plus longue
  // qu'aujourd'hui ne doit pas faire rougir à tort.
  if (premier.top < vu.top - _tolerance || premier.top >= vu.bottom) {
    constats.add(
      '3. le haut du premier texte ($premier) de la fiche n\'est pas dans '
      "ce qu'on voit $vu",
    );
  }

  final Finder derniere = cas.derniereLigne();
  final List<FlutterErrorDetails> erreursDefilement = await _capturer(() async {
    await tester.ensureVisible(derniere);
    await tester.pumpAndSettle();
  });
  if (erreursDefilement.isNotEmpty) {
    constats.add(
      '4. erreur(s) de rendu pendant le défilement : '
      '${_resume(erreursDefilement)}',
    );
  }
  // Le BAS de la dernière ligne, pas la ligne entière. Il doit être au plus
  // au bas de ce qu'on voit ET au plus à la limite basse de la carte : sans
  // défilement, ce qu'on voit est le cadre entier, qui contient toujours la
  // dernière ligne — seule la limite de la carte fait alors rougir ce constat.
  final Rect ligne = tester.getRect(derniere);
  final Rect vuApres = _vu(tester, panneau);
  if (ligne.bottom > vuApres.bottom + _tolerance) {
    constats.add(
      '4. le bas de la dernière ligne ($ligne) reste sous le bas de ce '
      "qu'on voit ($vuApres)",
    );
  }
  if (ligne.bottom > basMax + _tolerance) {
    constats.add(
      '4. le bas de la dernière ligne (${ligne.bottom}) reste sous la limite '
      'basse de la carte ($basMax)',
    );
  }

  expect(
    constats,
    isEmpty,
    reason: '${_nom(taille, textScale)}, ${_mode(enMode)}, ${cas.nom}',
  );
}

void main() {
  setUpAll(_chargerRoboto);

  const List<Size> telephones = <Size>[
    Size(360, 640),
    Size(390, 844),
    Size(640, 360),
  ];
  const Size bureau = Size(800, 740);
  final List<Size> tailles = <Size>[...telephones, bureau];

  // -----------------------------------------------------------------------
  // A. La matrice : 4 tailles × 2 polices × 2 modes × 5 cas = 80 tests
  // -----------------------------------------------------------------------
  group('A. matrice', () {
    for (final Size taille in tailles) {
      for (final double textScale in <double>[1, 2]) {
        for (final bool enMode in <bool>[false, true]) {
          for (final _Cas cas in _lesCas()) {
            _test(
              taille,
              '${_nom(taille, textScale)}, ${_mode(enMode)}, ${cas.nom} : '
              'la fiche tient dans la carte, s’ouvre par le haut, sa '
              'dernière ligne s’amène dans la fenêtre de défilement',
              (WidgetTester tester) => _verifierMatrice(
                tester,
                taille: taille,
                textScale: textScale,
                enMode: enMode,
                cas: cas,
              ),
            );
          }
        }
      }
    }
  });

  // -----------------------------------------------------------------------
  // B. La fiche défile réellement quand elle dépasse, dans une fenêtre dont
  //    les bords sont exacts : c'est ce qui verrouille la borne
  // -----------------------------------------------------------------------
  for (final Size taille in tailles) {
    _test(
      taille,
      '${_nom(taille, 2)}, hors mode, ONDE prête : la fiche est portée par un '
      'défilement dont la fenêtre va de 8 px à la hauteur de la carte moins 32',
      (WidgetTester tester) async {
        await _poser(
          tester,
          taille: taille,
          textScale: 2,
          cas: _cas('ONDE prête'),
        );

        final ScrollPosition position = _position(tester, _panneauOnde());
        expect(position.maxScrollExtent, greaterThan(0), reason: 'à défiler');

        final Rect fenetre = _fenetre(tester, _panneauOnde());
        expect(
          fenetre.top,
          closeTo(_margeHaute, _tolerance),
          reason: 'fenêtre $fenetre',
        );
        expect(
          fenetre.bottom,
          closeTo(taille.height - _margeAttribution, _tolerance),
          reason: 'fenêtre $fenetre, carte ${taille.height} de haut',
        );
      },
    );
  }

  // B bis. EN MODE, la fenêtre va jusqu'à la hauteur de la carte : la bande du
  // bouton de désignation porte la marge basse, la fiche garde la priorité.
  testWidgetsOnAndroid(
    'Android : 360 × 640, police 200 %, EN MODE Restrictions, ONDE prête : la '
    'fenêtre de défilement va de 8 px à la hauteur de la carte',
    (WidgetTester tester) async {
      const Size taille = Size(360, 640);
      await _poser(
        tester,
        taille: taille,
        textScale: 2,
        cas: _cas('ONDE prête'),
        enMode: true,
      );

      final ScrollPosition position = _position(tester, _panneauOnde());
      expect(position.maxScrollExtent, greaterThan(0), reason: 'à défiler');

      final Rect fenetre = _fenetre(tester, _panneauOnde());
      expect(
        fenetre.top,
        closeTo(_margeHaute, _tolerance),
        reason: 'fenêtre $fenetre',
      );
      expect(
        fenetre.bottom,
        closeTo(taille.height, _tolerance),
        reason: 'fenêtre $fenetre, carte ${taille.height} de haut',
      );
    },
  );

  // B ter. Une fiche qui TIENT garde sa place : sa zone est collée au bas de la
  // carte, la marge de l'attribution dessous. La fiche ONDE finit à la hauteur
  // moins 32 ; la fiche station, à la hauteur moins 40 — l'écart de 8 px et le
  // panneau ONDE fermé sont dessous. Une borne posée AUTOUR de l'`Align`, et non
  // dedans, étirerait la zone à la hauteur de la carte et centrerait la fiche.
  for (final (String, double) cas in <(String, double)>[
    ('ONDE prête', _margeAttribution),
    ('station prête avec valeurs', _margeAttribution + 8),
  ]) {
    testWidgetsOnWindows(
      '800 × 740, police 100 %, hors mode, ${cas.$1} : le bas du cadre de la '
      'fiche est à la hauteur de la carte moins ${cas.$2.toInt()}',
      (WidgetTester tester) async {
        await _poser(tester, taille: bureau, textScale: 1, cas: _cas(cas.$1));

        final Rect cadre = _cadre(tester, _cas(cas.$1).panneau());
        expect(
          cadre.bottom,
          closeTo(bureau.height - cas.$2, _tolerance),
          reason: 'cadre $cadre, carte ${bureau.height} de haut',
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // C. Gestes sur la fiche
  // -----------------------------------------------------------------------
  testWidgetsOnWindows(
    '800 × 740, police 200 %, hors mode, ONDE prête : un cran de molette '
    'posé au centre de la fiche vue la fait défiler',
    (WidgetTester tester) async {
      await _poser(
        tester,
        taille: bureau,
        textScale: 2,
        cas: _cas('ONDE prête'),
      );

      final ScrollPosition position = _position(tester, _panneauOnde());
      expect(position.pixels, 0, reason: 'au repos');

      await _cranDeMolette(tester, _vu(tester, _panneauOnde()).center, 100);

      expect(
        position.pixels,
        greaterThan(0),
        reason: 'après un cran de molette',
      );
    },
  );

  testWidgetsOnAndroid(
    'Android : 360 × 640, police 200 %, hors mode, station prête avec '
    'valeurs : un glisser vers le haut posé sur la fiche la fait défiler',
    (WidgetTester tester) async {
      await _poser(
        tester,
        taille: const Size(360, 640),
        textScale: 2,
        cas: _cas('station prête avec valeurs'),
      );

      final ScrollPosition position = _position(tester, _panneauStation());
      expect(position.pixels, 0, reason: 'au repos');

      await tester.dragFrom(
        _vu(tester, _panneauStation()).center,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0), reason: 'après un glisser');
    },
  );

  // -----------------------------------------------------------------------
  // D. Gestes rendus à la carte : verts AVANT comme APRÈS la correction
  // -----------------------------------------------------------------------
  testWidgetsOnWindows(
    '800 × 740, police 100 %, hors mode, station prête avec valeurs : un tap '
    'et un cran de molette posés à droite de la fiche parviennent à la carte '
    '(non-régression, verts avant comme après)',
    (WidgetTester tester) async {
      final _Carte carte = _Carte();
      await _poser(
        tester,
        taille: bureau,
        textScale: 1,
        cas: _cas('station prête avec valeurs'),
        carte: carte,
      );

      final Rect cadre = _cadre(tester, _panneauStation());
      final Offset p = Offset(cadre.right + 40, cadre.center.dy);

      await tester.tapAt(p);
      await tester.pump();
      expect(carte.taps, 1, reason: 'tap en $p, fiche $cadre');

      await _cranDeMolette(tester, p, -100);
      expect(carte.crans, 1, reason: 'molette en $p, fiche $cadre');
    },
  );

  for (final Size taille in <Size>[bureau, const Size(360, 640)]) {
    _test(
      taille,
      '${_nom(taille, 1)}, hors mode, station prête avec valeurs : un tap '
      "posé 4 px sous la fiche, dans l'écart de 8 px qui la sépare du "
      'panneau ONDE fermé, parvient à la carte (non-régression, vert avant '
      'comme après)',
      (WidgetTester tester) async {
        final _Carte carte = _Carte();
        await _poser(
          tester,
          taille: taille,
          textScale: 1,
          cas: _cas('station prête avec valeurs'),
          carte: carte,
        );

        final Rect cadre = _cadre(tester, _panneauStation());
        final Rect onde = tester.getRect(_panneauOnde());
        // Garde-fou : le point tombe bien dans l'écart de 8 px entre les deux
        // panneaux, jamais dans la fiche.
        expect(onde.top - cadre.bottom, closeTo(8, _tolerance));
        final Offset p = Offset(cadre.left + 20, cadre.bottom + 4);

        await tester.tapAt(p);
        await tester.pump();
        expect(carte.taps, 1, reason: 'tap en $p, fiche $cadre, ONDE $onde');
      },
    );
  }

  // -----------------------------------------------------------------------
  // E. Aucun défilement de surcouche ne s'attache à la route : vert AVANT
  //    comme APRÈS
  // -----------------------------------------------------------------------
  testWidgetsOnAndroid(
    'Android : 360 × 640, police 200 %, hors mode, station prête avec '
    'valeurs : aucune position attachée au PrimaryScrollController de la '
    'route (non-régression, vert avant comme après)',
    (WidgetTester tester) async {
      await _poser(
        tester,
        taille: const Size(360, 640),
        textScale: 2,
        cas: _cas('station prête avec valeurs'),
      );

      // Sur Android, un défilement vertical sans contrôleur hérite du
      // `PrimaryScrollController` de la route (`primary` omis) : les
      // surcouches sont des défilements FRÈRES, ils s'y attacheraient
      // ensemble et `PageDown` lèverait « more than one ScrollPosition is
      // attached ».
      final ScrollController primaire = PrimaryScrollController.of(
        tester.element(find.byType(Scaffold)),
      );
      expect(
        primaire.positions,
        isEmpty,
        reason:
            'les surcouches ne doivent pas se brancher au contrôleur de la '
            'route',
      );
    },
  );

  // -----------------------------------------------------------------------
  // F. En mode, la fiche garde la priorité : vert AVANT comme APRÈS
  // -----------------------------------------------------------------------
  testWidgetsOnAndroid(
    'Android : 360 × 640, police 100 %, EN MODE Restrictions, ONDE prête : '
    'rien de la fiche n\'est coupé et elle tient dans l\'écran '
    '(non-régression, vert avant comme après)',
    (WidgetTester tester) async {
      const Size taille = Size(360, 640);
      await _poser(
        tester,
        taille: taille,
        textScale: 1,
        cas: _cas('ONDE prête'),
        enMode: true,
      );

      final Rect cadre = _cadre(tester, _panneauOnde());
      final Rect vu = _vu(tester, _panneauOnde());
      expect(
        _egaux(vu, cadre),
        isTrue,
        reason: 'fiche vue $vu, cadre entier $cadre : la fiche est coupée',
      );
      expect(
        _dans(cadre, Offset.zero & taille),
        isTrue,
        reason: 'cadre $cadre, écran ${Offset.zero & taille}',
      );
    },
  );

  // -----------------------------------------------------------------------
  // G. Deux CONSTAT : des faits mesurés, PAS des invariants voulus. Ils
  //    décrivent l'écran tel qu'il est et se corrigent À LA MAIN quand il
  //    change, jamais en silence (`docs/project-state.md`, point 60).
  // -----------------------------------------------------------------------
  testWidgetsOnAndroid(
    'Android : CONSTAT : à 360 × 640, 200 %, la position de défilement '
    'survit au changement de fiche',
    (WidgetTester tester) async {
      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : fiche défilée au bout, puis
      // une AUTRE fiche haute posée au même emplacement — le défilement garde
      // sa position, la nouvelle fiche s'ouvre sur son bas, son nom et
      // « ⚠ Avertissement » hors champ. Corriger demande de savoir quand la
      // fiche change, ce que `buildMapOverlays` ignore : hors du périmètre
      // arbitré, à trancher par le commanditaire. Une fois corrigé, la position
      // revient à 0 : corriger ce CONSTAT à la main.
      const Size taille = Size(360, 640);
      await _poser(
        tester,
        taille: taille,
        textScale: 2,
        cas: _casStationSansValeur(_blois()),
      );
      final ScrollPosition position = _position(tester, _panneauStation());
      expect(position.maxScrollExtent, greaterThan(0), reason: 'à défiler');
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final double auBout = position.pixels;
      expect(auBout, greaterThan(0), reason: 'défilée au bout');

      await _poser(
        tester,
        taille: taille,
        textScale: 2,
        cas: _casStationSansValeur(_autreStation()),
      );

      expect(
        find.text(_autreStation().label),
        findsOneWidget,
        reason: "l'autre fiche est bien posée",
      );
      expect(
        _position(tester, _panneauStation()).pixels,
        greaterThan(0),
        reason: "la position n'est pas revenue à 0 (avant : $auBout)",
      );
    },
  );

  testWidgetsOnAndroid(
    'Android : CONSTAT : à 360 × 640, 200 %, hors mode, ONDE prête défilée '
    "au bout, le bas de la fiche reste en partie sous l'attribution IGN",
    (WidgetTester tester) async {
      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : la marge basse de la zone
      // des fiches est fixe (`_sheetBottomPadding`, 32 px) et ne suit pas la
      // police ; à 200 % le bandeau d'attribution, opaque et peint après, est
      // plus haut que cette marge et recouvre une partie de la dernière ligne.
      // On ne verrouille pas les pixels exacts, seulement le recoupement.
      await _poser(
        tester,
        taille: const Size(360, 640),
        textScale: 2,
        cas: _cas('ONDE prête'),
      );
      final ScrollPosition position = _position(tester, _panneauOnde());
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      final Rect ligne = tester.getRect(find.text(ondeSeasonNotice));
      final Rect attribution = tester.getRect(find.byType(IgnAttributionBadge));
      expect(
        ligne.overlaps(attribution),
        isTrue,
        reason:
            'dernière ligne $ligne, attribution IGN $attribution : plus de '
            'recoupement — corriger ce CONSTAT à la main',
      );
    },
  );
}

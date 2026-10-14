// Surcouches de la carte aux largeurs de téléphone (constat du 2026-09-29),
// à 360 × 640 et 390 × 844, police à 100 % et à 200 %, HORS MODE puis EN MODE
// « Restrictions » (`E5`, `E5b` de T2). Ce que ces tests prouvent, et rien de
// plus :
//
// - la plateforme (`N9` de T3) : un cas dont le plus petit côté de la fenêtre
//   fait moins de 600 px est un cas de téléphone — en portrait (360 × 640,
//   390 × 844) comme en paysage (600 × 360, 640 × 360) —, il tourne sous
//   Android et son titre commence par « Android : » ; les autres tournent
//   sous Windows. Seule exception, voulue : les verrous de gestes à
//   360 × 640 rejoués sous Windows (section « Gestes rendus à la carte ») ;
// - la police : ce fichier charge ROBOTO, la police d'Android, depuis le SDK
//   Flutter (voir [_chargerRoboto]) — pas la police de test, où chaque glyphe
//   est un carré d'un em. Mesurées en police de test, les trois puces
//   prenaient trois rangées à 360 px et 100 % et poussaient l'avis sous les
//   contrôles de zoom : un artefact de cette police (mesure du 2026-10-03).
//   Windows rend en Segoe UI, non mesurée ici : ces pixels sont des mesures
//   de test, pas des constats d'écran ;
// - le NOMBRE DE RANGÉES des trois puces, motif de cette décision : à 100 %,
//   deux à 360 px et une à 390 px et à 800 × 740 ; à 200 %, trois aux deux
//   largeurs de téléphone et deux à 800 × 740. Un invariant de la décision :
//   si le nombre change, l'avis se déplace et toutes les mesures ci-dessous
//   sont à refaire ;
// - aucune erreur de rendu, avec ou sans fiche de 320 px ouverte (l'aide
//   `_pumpOverlays` l'affirme elle-même, sauf pour un test qui l'ATTEND) ;
// - le contrôle d'avertissement et les trois puces (« Écoulement », « Débit »,
//   « Restrictions ») sont entièrement dans l'écran, leur libellé à
//   l'intérieur de leur boîte ;
// - la colonne du haut laisse passer à la carte les gestes (tap, molette,
//   glisser) posés hors de ses enfants, et la bascule de disposition se fait
//   à 600 px de large ;
// - l'ordre de la colonne : avertissement, puces, avis, puis légende. La
//   légende n'est repoussée que pendant qu'un avis s'affiche : un écart à
//   `BR-008` (« toujours visible »), accepté par le commanditaire le
//   2026-10-03 ;
// - l'ordre de tabulation (`K2`) sous 600 px : puces (trois), l'action de
//   l'avis s'il y en a un (`K1` de T3, arbitrage du commanditaire du
//   2026-10-14), « Favoris » s'il est posé, « Filtres » (`F10b` de T3),
//   contrôles de zoom, puis, EN MODE seulement, bouton de désignation, enfin
//   contrôle d'avertissement ;
// - à 100 %, avec un avis, l'avis est entier dans l'écran, libre de toute
//   surcouche du bas (bouton compris, en mode), et son action « Élargir la
//   recherche » est atteignable ;
// - à 100 %, sans avis, la légende « écoulement » est entière et libre de
//   toute autre surcouche ;
//   ⚠️ ces deux-là, « Favoris » NON posé (quatre boutons dans la colonne du
//   bas). Avec lui, comme dans `main.dart`, à 360 × 640, « écoulement »,
//   l'avis d'absence dépasse de 8 px de sa fenêtre (son action y reste
//   entière) et la légende de 17 px : section `K3`, en fin de fichier, et
//   `map_entry_buttons_overlap_test.dart` (`S10`) ;
// - la colonne du bas à droite à cinq boutons (`K3` de T3) : dans l'écran, de
//   la hauteur de ses cinq boutons, sans recouper la partie visible de la
//   légende ni de l'avis, ni la fiche, ni le bouton de désignation, ni
//   l'attribution — à 360 × 640 avec un avis, à 390 × 844, aux tailles
//   intermédiaires de bureau et à 800 × 740 à 200 % ;
// - `BR-012` : HORS MODE, à 100 % et à 200 %, le centre du contrôle
//   « ⚠ Avertissement » et celui des trois puces sont atteignables ;
// - EN MODE, à 200 %, le centre de la puce « Restrictions », seule sortie du
//   mode, est atteignable : le bouton ne le recouvre pas ;
// - à 100 % comme à 200 %, là où la légende dépasse sa fenêtre, faire défiler
//   la colonne en amène le bord bas dans la fenêtre, au-dessus du groupe
//   « Filtres » ;
// - le défilement du bas à droite (`F10b` de T3) ne capte les gestes que sur
//   ses pièces, sous Windows et sous Android ;
// - en disposition LARGE, aucune erreur de rendu : la colonne gauche (puces
//   et avis) défile au lieu de déborder, et le bas de l'avis s'y amène en la
//   faisant défiler (`E5`, 2026-10-03). En Roboto elle ne défile qu'à
//   600 × 360 et 640 × 360, à 200 % ; ces deux tailles et 800 × 740 (taille
//   minimale de la fenêtre Windows) ont toute la matrice, les autres tailles
//   (700 × 740, 800 × 640, 900 × 640) un seul cas chacune.
//
// Ils ne prouvent PAS que tout ce que la colonne porte est visible ou
// atteignable à tout moment. Les tests « CONSTAT » verrouillent des faits
// mesurés qui ne sont pas des invariants voulus — ils décrivent l'écran tel
// qu'il est, et se corrigent À LA MAIN quand l'écran change, jamais en
// silence. Plusieurs ne tiennent que de quelques pixels (marqués dans le
// fichier) : ce sont les premiers à basculer.
//
// - RETIRÉ le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
//   `F10b` de T3) : « la légende, repoussée sous un avis, est recoupée par
//   les contrôles de zoom à 360 × 640 ; à 200 %, amenée dans la fenêtre, elle
//   passe sous les contrôles de zoom et l'attribution ». La fenêtre de la
//   colonne du haut s'arrête désormais au-dessus de la colonne du bas à
//   droite (boutons d'entrée, contrôles de zoom, attribution) : la partie
//   visible de la légende ne recoupe plus aucune de ces pièces, elle défile
//   — INVARIANT, plus un constat (section « La légende défile », en fin de
//   fichier, et section « Le groupe des boutons d'entrée »). Restait un
//   constat : EN MODE, à 200 %, le bouton de désignation la recoupait encore
//   — plus depuis que « Favoris » est posé (remesuré par `K3` de T3, le
//   2026-10-14 : la fenêtre finit plus haut, au-dessus du bouton) ;
// - à 200 %, l'avis n'est qu'en partie visible au repos : son action s'amène
//   dans la fenêtre en faisant défiler la colonne, hors mode comme EN MODE
//   (elle n'était pas atteignable en mode avant le 2026-10-12) ; la boîte du
//   bouton de désignation recoupe encore celle de l'avis, plus sa partie
//   visible depuis que « Favoris » est posé (`K3` de T3) ;
// - « Favoris » posé (`K3` de T3), à 360 × 640 : à 200 %, aucun avis n'est
//   entier au repos — l'avis de carte vidée par le filtre compris, dont
//   « Effacer les filtres » ne se voit qu'en faisant défiler — ; à 100 %,
//   l'avis d'absence « écoulement » dépasse de 8 px de sa fenêtre ; à
//   600 × 360, « Favoris » dépasse de 12 px de la fenêtre de la colonne du
//   bas et rien de la légende ne paraît au repos ;
// - EN MODE, à 200 %, le bouton de désignation ne recouvre ni le contrôle
//   d'avertissement ni les puces, et la puce « Restrictions » est atteignable
//   sur toute sa surface (mesuré) — mais plus sur une fenêtre plus courte ;
// - EN MODE, la bande du bouton ne capte les gestes que sur la pilule et son
//   indice (invariant : elle était opaque sur toute sa boîte, défaut relevé
//   pendant `E5b`, corrigé le 2026-10-04) ;
// - EN MODE, l'avis recouvre le réticule de désignation dans une partie des
//   cas de carte vide ;
// - une fiche de 320 px recouvre une partie des surcouches du haut ;
// - à 600 × 360 et 640 × 360, 200 %, l'attribution IGN recouvre le bas de
//   l'action de l'avis, une fois la colonne gauche défilée ;
// - sur une fenêtre compacte COURTE (360 × 300), la colonne du haut ne garde
//   que le contrôle « ⚠ Avertissement » : puces, avis et légende sont sous le
//   bord de sa fenêtre au repos (effet de la décision « le haut cède
//   d'abord, jusqu'à une cible tactile », mesuré le 2026-10-13).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show warningLinkLabel;
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/tap_target.dart'
    show minimumTapTarget;
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// Clé de la fiche de test : une hauteur réaliste de 320, comme
/// `map_view_test.dart` (proche des fiches réelles de `station_sheet` et
/// `onde_sheet`).
const Key _ficheKey = Key('fiche-de-test-telephone');
const double _hauteurFiche = 320;

const Size _petit = Size(360, 640);
const Size _grand = Size(390, 844);

const String _controles = 'MapControls';
const String _designation = 'DesignateCenterControl';
const String _attribution = 'IgnAttributionBadge';

/// Charge ROBOTO — toutes les graisses `Roboto-*.ttf` du SDK Flutter — sous la
/// famille `Roboto`, celle que Material demande sur Android, et enregistre les
/// mêmes octets aussi sous « Segoe UI », en substitut.
///
/// Le dossier est celui des polices du SDK, `bin/cache/artifacts/material_fonts`,
/// trouvé par la variable d'environnement `FLUTTER_ROOT` que `flutter test`
/// définit : aucun chemin de poste dans le dépôt. Si la variable, le dossier
/// ou les polices manquent, le fichier ÉCHOUE avec un message clair — jamais
/// de repli silencieux sur la police de test : tous les pixels de ce fichier
/// seraient faux.
///
/// La police chargée vaut pour tout le processus de test de CE fichier. Un
/// précédent existe : `restrictions_scale_text_test.dart` charge lui aussi
/// Roboto (depuis `bc81efe`), avec une autre politique — Regular et Bold
/// seulement, et ses tests sont IGNORÉS (`markTestSkipped`) quand
/// `FLUTTER_ROOT` est absent hors intégration continue. Ici, toutes les
/// graisses, et jamais d'ignorance : les pixels de ce fichier sont tous des
/// mesures. Les autres fichiers de test gardent la police de test.
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
  // `Roboto-*.ttf` : « Roboto-Regular », « Roboto-BoldItalic »… mais ni
  // `RobotoCondensed-*` ni les icônes. La casse des noms varie selon la
  // version du SDK.
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
  // Les mêmes octets sont chargés sous deux familles : « Roboto », celle que
  // Material demande sur Android, et « Segoe UI », celle qu'il demande sur
  // Windows (`Typography.material2021`, `blackRedmond`). Segoe UI n'est PAS
  // chargée ici — la police de Windows n'est pas dans le SDK : les tests de la
  // section « Windows » mesurent donc en Roboto, un SUBSTITUT de Segoe UI, pas
  // sa mesure. Sans lui, Windows retomberait sur la police de test (un carré
  // par glyphe) et chaque largeur de texte serait fausse.
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

/// Une station et un point ONDE : ils ne servent qu'à ce que la carte ne soit
/// pas vide (`mapNoticesFor`) — `buildMapOverlays` ne dessine aucun marqueur.
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

/// La puce de l'échelle [kind].
Finder _puceEchelle(MapScaleKind kind) =>
    find.byKey(ValueKey<MapScaleKind>(kind));

/// La puce « Restrictions » (`E5`).
Finder _puceRestrictions() => find.byKey(mapDesignationChipKey);

/// Les trois puces du sélecteur, avec leur nom.
Map<String, Finder> _lesTroisPuces() => <String, Finder>{
  'puce ${MapScaleKind.ecoulement.name}': _puceEchelle(MapScaleKind.ecoulement),
  'puce ${MapScaleKind.debit.name}': _puceEchelle(MapScaleKind.debit),
  'puce Restrictions': _puceRestrictions(),
};

/// La bande du bouton de désignation : le `ListView` de `_DesignationPlacement`,
/// seul `ListView` au-dessus du bouton. EN MODE seulement.
Finder _bande() => find.ancestor(
  of: find.byType(DesignateCenterControl),
  matching: find.byType(ListView),
);

/// Le nombre de rangées que prennent les trois puces : leurs hauts distincts.
int _rangeesDePuces(WidgetTester tester) {
  final List<double> hauts = <double>[];
  for (final Finder puce in _lesTroisPuces().values) {
    final double haut = _rectOf(tester, puce).top;
    if (!hauts.any((double h) => (h - haut).abs() < 0.5)) {
      hauts.add(haut);
    }
  }
  return hauts.length;
}

/// Pose les surcouches à [size] et [textScale], et **affirme l'absence de
/// toute erreur de rendu** levée pendant la pose — aucune n'est filtrée.
/// Seul un test qui ATTEND une erreur ([attendErreurs], un CONSTAT) les
/// reçoit en retour sans échouer ; les autres ne peuvent pas en laisser
/// passer une.
///
/// Comme `main.dart`, la puce « Restrictions » est toujours fournie
/// ([onBasculerMode], `E5`). Le bouton de désignation, son indice et le
/// réticule n'existent que EN MODE ([enMode]) : `buildMapOverlays` les rend
/// quand `onDesignateCenter` est non nul. Par défaut ([avecAvis]), sans
/// station ni point ONDE, un avis d'absence est affiché (« Élargir la
/// recherche ») : c'est l'état d'une carte vide. Avec `avecAvis: false`, une
/// station et un point ONDE existent : aucun avis. Le bouton « Favoris »
/// n'est posé que si [onOuvrirFavoris] est fourni (`S10` de T3).
/// Sous les surcouches, une couche « carte » compte les taps ([onCarteTap]),
/// les crans de molette ([onCarteMolette]) et les glissers ([onCarteGlisser])
/// qui lui parviennent. Les surcouches sont dans un groupe de tabulation
/// ordonné, comme dans `MapView` (`K2`).
Future<List<FlutterErrorDetails>> _pumpOverlays(
  WidgetTester tester,
  Size size, {
  required MapScaleKind scale,
  double textScale = 1,
  bool enMode = false,
  bool avecFiche = false,
  bool avecAvis = true,
  bool attendErreurs = false,
  bool filtreVideTout = false,
  VoidCallback? onEffacer,
  VoidCallback? onOuvrirFavoris,
  void Function(MapScaleKind kind)? onSelect,
  VoidCallback? onBasculerMode,
  VoidCallback? onCarteTap,
  VoidCallback? onCarteMolette,
  VoidCallback? onCarteGlisser,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final List<FlutterErrorDetails> erreurs = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? avant = FlutterError.onError;
  FlutterError.onError = erreurs.add;
  try {
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
                    onPointerSignal: (PointerSignalEvent _) =>
                        onCarteMolette?.call(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCarteTap,
                      onPanUpdate: (DragUpdateDetails _) =>
                          onCarteGlisser?.call(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                ...buildMapOverlays(
                  filterHidesEverything: filtreVideTout,
                  onClearFilters: onEffacer ?? () {},
                  filterActive: false,
                  onOpenFilters: () {},
                  onOpenFavorites: onOuvrirFavoris,
                  scale: scale,
                  onSelect: onSelect ?? (MapScaleKind kind) {},
                  onWiden: () {},
                  error: null,
                  stations: avecAvis
                      ? const <StationPoint>[]
                      : <StationPoint>[_uneStation()],
                  ondeObservations: avecAvis
                      ? const <OndeStationCode, OndeObservation>{}
                      : _uneObservation(),
                  ondeUnreadableRows: 0,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                  onDesignateCenter: enMode ? () {} : null,
                  onToggleDesignationMode: onBasculerMode ?? () {},
                  stationSheet: avecFiche
                      ? Container(
                          key: _ficheKey,
                          width: double.infinity,
                          height: _hauteurFiche,
                          color: Colors.red,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = avant;
  }
  if (!attendErreurs) {
    expect(
      erreurs,
      isEmpty,
      reason: erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
    );
  }
  return erreurs;
}

/// La fenêtre de la colonne du haut (compacte, ou gauche en disposition
/// large) : ce qu'on voit de la colonne tient dedans, le reste est atteint en
/// la faisant défiler. C'est celle qui porte les puces — en disposition large
/// il y en a deux.
Rect _fenetre(WidgetTester tester) => tester.getRect(
  find.ancestor(
    of: find.byType(MapScaleChips),
    matching: find.byType(SingleChildScrollView),
  ),
);

/// La fenêtre de la colonne du bas à droite : le défilement qui porte les
/// contrôles de zoom.
Rect _fenetreDuBas(WidgetTester tester) => tester.getRect(
  find.ancestor(
    of: find.byType(MapControls),
    matching: find.byType(SingleChildScrollView),
  ),
);

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// La partie VISIBLE de [finder] : sa boîte, coupée par la fenêtre de la
/// colonne. `null` quand rien n'en dépasse dans la fenêtre.
Rect? _visible(WidgetTester tester, Finder finder) {
  final Rect r = _rectOf(tester, finder).intersect(_fenetre(tester));
  return (r.width <= 0 || r.height <= 0) ? null : r;
}

/// Les surcouches du bas, avec lesquelles la colonne du haut se superpose.
/// Le bouton de désignation n'existe qu'EN MODE : hors mode il est absent de
/// l'arbre, donc de l'ensemble.
Map<String, Finder> _bas() => <String, Finder>{
  _controles: find.byType(MapControls),
  if (find.byType(DesignateCenterControl).evaluate().isNotEmpty)
    _designation: find.byType(DesignateCenterControl),
  _attribution: find.byType(IgnAttributionBadge),
};

/// Les noms de [candidats] dont la boîte recoupe la partie visible de
/// [piece].
Set<String> _recoupements(
  WidgetTester tester,
  Finder piece,
  Map<String, Finder> candidats,
) {
  final Rect? v = _visible(tester, piece);
  if (v == null) {
    return <String>{};
  }
  return <String>{
    for (final MapEntry<String, Finder> c in candidats.entries)
      if (v.overlaps(_rectOf(tester, c.value))) c.key,
  };
}

/// L'avis affiché par l'état « carte vide » de [scale].
Finder _avis(MapScaleKind scale) => switch (scale) {
  MapScaleKind.ecoulement => find.byType(NoDataInAreaNotice),
  MapScaleKind.debit => find.byType(NoStationInAreaNotice),
};

/// Le centre de [finder] atteint-il [finder] — rien ne le recouvre ?
bool _atteignable(Finder finder) => finder.hitTestable().evaluate().isNotEmpty;

/// La part (de 0 à 1) des points d'une grille de 2 px, posée sur la boîte de
/// [finder], dont un geste atteint [finder] : 1 quand rien ne la recouvre,
/// 0 quand tout est recouvert.
double _surfaceAtteignable(WidgetTester tester, Finder finder) {
  final Rect boite = _rectOf(tester, finder);
  final RenderObject cible = tester.renderObject(finder);
  int atteints = 0;
  int total = 0;
  for (double x = boite.left + 1; x < boite.right; x += 2) {
    for (double y = boite.top + 1; y < boite.bottom; y += 2) {
      total++;
      final HitTestResult resultat = HitTestResult();
      tester.binding.hitTestInView(resultat, Offset(x, y), tester.view.viewId);
      if (resultat.path.any((HitTestEntry e) => identical(e.target, cible))) {
        atteints++;
      }
    }
  }
  return atteints / total;
}

String _nom(Size size, double textScale, MapScaleKind scale) =>
    '${size.width.toInt()} × ${size.height.toInt()}, police '
    '${(textScale * 100).toInt()} %, échelle ${scale.name}';

String _mode(bool enMode) => enMode ? 'EN MODE Restrictions' : 'HORS MODE';

/// Où en est [finder] dans la fenêtre de la colonne : « cachée », « en
/// partie » ou « entière ».
String _etat(WidgetTester tester, Finder finder) {
  final Rect? v = _visible(tester, finder);
  if (v == null) {
    return 'cachée';
  }
  return v == _rectOf(tester, finder) ? 'entière' : 'en partie';
}

/// Ce que la colonne doit défiler pour que le BORD BAS de la légende arrive
/// au bord bas de la fenêtre ; 0 quand elle n'a rien à défiler.
double _adefiler(WidgetTester tester) => math.max(
  0,
  _rectOf(tester, find.byType(MapLegend)).bottom - _fenetre(tester).bottom,
);

/// Fait défiler la colonne DU DOIGT de [distance], depuis le bout droit de la
/// puce « débit » — hors de la boîte du bouton de désignation, qui recouvre
/// le reste de la puce à 360 × 640 : la colonne ne capte les gestes que sur
/// ses enfants. Le doigt perd `kDragSlopDefault` avant que la colonne ne
/// suive.
Future<void> _defilerDuDoigt(WidgetTester tester, double distance) async {
  final Rect puce = _rectOf(tester, _puceEchelle(MapScaleKind.debit));
  await tester.dragFrom(
    Offset(puce.right - 12, puce.center.dy),
    Offset(0, -(distance + kDragSlopDefault)),
  );
  await tester.pumpAndSettle();
}

/// Disposition LARGE : aucune erreur de rendu (affirmé par [_pumpOverlays]),
/// et le bas de l'avis arrive dans la fenêtre de la colonne gauche, sans rien
/// défiler quand il y est déjà, en la faisant défiler sinon.
///
/// Avant `E5`, la colonne gauche (puces et avis) débordait par le bas : défaut
/// antérieur à la colonne compacte, que la troisième puce a amené à la taille
/// minimale de fenêtre Windows (constat du 2026-10-03).
Future<void> _verifierColonneGauche(
  WidgetTester tester,
  Size taille, {
  required double textScale,
  required MapScaleKind scale,
  required bool enMode,
}) async {
  await _pumpOverlays(
    tester,
    taille,
    textScale: textScale,
    scale: scale,
    enMode: enMode,
  );

  final Rect colonne = _fenetre(tester);
  final Finder lAvis = _avis(scale);
  final Rect repos = _rectOf(tester, lAvis);
  if (repos.bottom > colonne.bottom) {
    await _defilerDuDoigt(tester, repos.bottom - colonne.bottom);
  }

  final Rect atteint = _rectOf(tester, lAvis);
  expect(
    atteint.bottom,
    lessThanOrEqualTo(colonne.bottom + 0.5),
    reason: 'avis=$atteint, fenêtre=$colonne',
  );
}

/// Un test de widget posé sur une plateforme : Android (`testWidgetsOnAndroid`)
/// ou Windows (`testWidgetsOnWindows`). Un titre passé par [_surAndroid]
/// commence par « Android : ».
typedef _Test = void Function(
  String description,
  Future<void> Function(WidgetTester tester) corps,
);

/// L'assistant d'un cas d'une boucle qui mêle tailles de téléphone et tailles
/// de bureau : quand le plus petit côté de la fenêtre fait moins de 600 px,
/// c'est un téléphone, en portrait ou en paysage (600 × 360, 640 × 360), et
/// le cas tourne sous Android ; sinon sous Windows. Une fenêtre Windows ne
/// descend pas sous 800 × 740 (`K3`).
_Test _selonFenetre(Size taille) =>
    taille.shortestSide < 600 ? _surAndroid : _surWindows;

void _surAndroid(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnAndroid('Android : $d', corps);

void _surWindows(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnWindows(d, corps);

/// EN MODE, à [taille], 100 % : un tap, un glisser et un cran de molette posés
/// dans la bande du bouton de désignation, hors de la pilule et de l'indice,
/// atteignent la carte. Ses appelants tournent sous Windows (800 × 740,
/// 800 × 700), où une `Scrollbar` automatique entoure la bande, et sous
/// Android pour le téléphone en paysage (600 × 360).
Future<void> _verifierBande(WidgetTester tester, Size taille) async {
  int taps = 0;
  int glissers = 0;
  int crans = 0;
  await _pumpOverlays(
    tester,
    taille,
    scale: MapScaleKind.ecoulement,
    enMode: true,
    avecAvis: false,
    onCarteTap: () => taps++,
    onCarteGlisser: () => glissers++,
    onCarteMolette: () => crans++,
  );

  // Un point calculé depuis les rectangles mesurés : sur la rangée de la
  // pilule, à mi-chemin entre le bord gauche de la bande et celui de la
  // pilule. Les garde-fous disent s'il retombait hors de la bande ou dans la
  // pilule.
  final Rect bande = _rectOf(tester, _bande());
  final Rect pilule = _rectOf(tester, find.byKey(mapDesignateCenterButtonKey));
  final Offset p = Offset((bande.left + pilule.left) / 2, pilule.center.dy);
  expect(
    bande.contains(p) && p.dx > bande.left,
    isTrue,
    reason: 'le point $p doit être DANS la bande $bande',
  );
  expect(pilule.contains(p), isFalse, reason: 'pilule=$pilule');

  await tester.tapAt(p);
  await tester.pump();
  expect(taps, 1, reason: 'tap en $p, bande=$bande, pilule=$pilule');

  await tester.dragFrom(p, const Offset(0, -30));
  await tester.pump();
  expect(glissers, greaterThan(0), reason: 'glisser en $p');

  final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(souris.hover(p));
  await tester.sendEventToBinding(souris.scroll(const Offset(0, -100)));
  await tester.pump();
  expect(crans, 1, reason: 'molette en $p');
}

/// HORS MODE, à [taille], 100 % : un tap, un glisser et un cran de molette
/// posés dans la boîte du défilement du BAS À DROITE, hors de ses pièces,
/// atteignent la carte (`F10b` de T3). La boîte est large comme l'attribution,
/// bien plus large que les boutons : sans `deferToChild`, et sans
/// `_WithoutScrollbar` sur le bureau, toute cette surface serait morte pour la
/// carte — avant `F10b` c'était une `Column` nue, transparente aux gestes.
Future<void> _verifierBasADroite(WidgetTester tester, Size taille) async {
  int taps = 0;
  int glissers = 0;
  int crans = 0;
  await _pumpOverlays(
    tester,
    taille,
    scale: MapScaleKind.ecoulement,
    avecAvis: false,
    onCarteTap: () => taps++,
    onCarteGlisser: () => glissers++,
    onCarteMolette: () => crans++,
  );

  // Un point calculé depuis les rectangles mesurés : sur la rangée du bouton
  // « − », à mi-chemin entre le bord gauche de la boîte et celui des boutons.
  final Rect boite = _fenetreDuBas(tester);
  final Rect controles = _rectOf(tester, find.byType(MapControls));
  final Offset p = Offset(
    (boite.left + controles.left) / 2,
    controles.center.dy,
  );
  expect(
    boite.contains(p) && p.dx > boite.left,
    isTrue,
    reason: 'le point $p doit être DANS la boîte $boite',
  );
  for (final Finder piece in <Finder>[
    find.byType(MapEntryButtons),
    find.byType(MapControls),
    find.byType(IgnAttributionBadge),
  ]) {
    expect(
      _rectOf(tester, piece).contains(p),
      isFalse,
      reason: '$p tombe dans une pièce de la colonne du bas',
    );
  }

  await tester.tapAt(p);
  await tester.pump();
  expect(taps, 1, reason: 'tap en $p, boîte=$boite, contrôles=$controles');

  await tester.dragFrom(p, const Offset(0, -30));
  await tester.pump();
  expect(glissers, greaterThan(0), reason: 'glisser en $p');

  final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(souris.hover(p));
  await tester.sendEventToBinding(souris.scroll(const Offset(0, -100)));
  await tester.pump();
  expect(crans, 1, reason: 'molette en $p');
}

/// `F10c` de T3 : la mesure de la place du cinquième bouton, « Favoris »,
/// au-dessus de « Filtres » dans `MapEntryButtons` (lot 7). Le rectangle du
/// groupe est étendu vers le haut d'un bouton et d'un espacement ; il est mis
/// en regard de la BOÎTE ENTIÈRE de la légende, du bouton de désignation (EN
/// MODE), de l'attribution et de la fiche. [morsure] est la hauteur dont il
/// mord sur la boîte de la légende : 0 s'il ne la mord pas, sinon ce qu'elle
/// aurait à défiler.
class _PlaceDuCinquieme {
  _PlaceDuCinquieme(WidgetTester tester, this.ecran, this.ficheKey)
    : groupe = tester.getRect(find.byType(MapEntryButtons)),
      legende = tester.getRect(find.byType(MapLegend)),
      fenetre = tester.getRect(
        find.ancestor(
          of: find.byType(MapLegend),
          matching: find.byType(SingleChildScrollView),
        ),
      ),
      designation = tester.getRect(find.byType(DesignateCenterControl)),
      attribution = tester.getRect(find.byType(IgnAttributionBadge)),
      ficheRect = ficheKey == null
          ? null
          : tester.getRect(find.byKey(ficheKey)) {
    etendu = Rect.fromLTRB(
      groupe.left,
      groupe.top - (minimumTapTarget + mapControlsSpacing),
      groupe.right,
      groupe.bottom,
    );
  }

  final Size ecran;
  final Key? ficheKey;
  final Rect groupe;
  final Rect legende;
  final Rect fenetre;
  final Rect designation;
  final Rect attribution;
  final Rect? ficheRect;
  late final Rect etendu;

  Rect get visible => legende.intersect(fenetre);

  double get morsure =>
      etendu.overlaps(legende) ? etendu.intersect(legende).height : 0;

  String get mesure =>
      'écran=$ecran, groupe=$groupe, étendu=$etendu, '
      'légende(boîte)=$legende, légende(visible)=$visible, '
      'fenêtre=$fenetre, désignation=$designation, '
      'attribution=$attribution, fiche=$ficheRect, '
      'morsure sur la boîte de la légende=$morsure px';

  /// Les cinq affirmations de la tâche : dans l'écran, et ne coupe ni la
  /// légende (boîte entière), ni le bouton de désignation, ni l'attribution,
  /// ni la fiche.
  void exiger() {
    exigerHorsLegende();
    expect(etendu.overlaps(legende), isFalse, reason: 'MapLegend : $mesure');
  }

  /// Ce qui reste un invariant même là où la légende est mordue (constat) :
  /// dans l'écran, ni le bouton de désignation, ni l'attribution, ni la
  /// fiche.
  void exigerHorsLegende() {
    expect(etendu.top, greaterThanOrEqualTo(0), reason: mesure);
    expect(etendu.right, lessThanOrEqualTo(ecran.width), reason: mesure);
    expect(
      etendu.overlaps(designation),
      isFalse,
      reason: 'DesignateCenterControl : $mesure',
    );
    expect(
      etendu.overlaps(attribution),
      isFalse,
      reason: 'IgnAttributionBadge : $mesure',
    );
    if (ficheRect != null) {
      expect(etendu.overlaps(ficheRect!), isFalse, reason: 'fiche : $mesure');
    }
  }
}

/// Deux rectangles se recoupent-ils sur une surface non vide ? Un rectangle
/// vide ou inversé — l'intersection de deux boîtes disjointes — ne recoupe
/// rien, ce que `Rect.overlaps` seul ne garantit pas.
bool _recoupe(Rect a, Rect b) =>
    a.width > 0 && a.height > 0 && b.width > 0 && b.height > 0 && a.overlaps(b);

/// La partie VISIBLE de [piece] : sa boîte coupée par la fenêtre du plus
/// proche défilement de type [defilement] qui la porte. `null` quand rien
/// n'en paraît.
Rect? _partieVisible(WidgetTester tester, Finder piece, Type defilement) {
  final Rect v = _rectOf(tester, piece).intersect(
    _rectOf(
      tester,
      find.ancestor(of: piece, matching: find.byType(defilement)).first,
    ),
  );
  return (v.width <= 0 || v.height <= 0) ? null : v;
}

/// `K3` de T3 : la colonne du bas à droite à CINQ boutons — « Favoris »,
/// « Filtres », `+`, `−`, recentrer —, posée par `buildMapOverlays` avec
/// « Favoris » branché, comme la racine de composition le fait depuis `S11`.
/// [colonne] englobe les cinq boutons, du haut de « Favoris » au bas de
/// recentrer. Ce qu'elle ne doit pas recouper est lu par sa PARTIE VISIBLE
/// quand la pièce vit dans un défilement — la légende et l'avis dans leur
/// colonne, le bouton de désignation dans sa bande —, par sa boîte sinon
/// (l'attribution, la fiche).
class _ColonneACinq {
  _ColonneACinq(WidgetTester tester, this.ecran, {Finder? avis, Key? ficheKey})
    : boutons = <String, Rect>{
        'Favoris': tester.getRect(find.byKey(mapFavoritesButtonKey)),
        'Filtres': tester.getRect(find.byKey(mapFiltersButtonKey)),
        '+': tester.getRect(find.byKey(mapZoomInButtonKey)),
        '−': tester.getRect(find.byKey(mapZoomOutButtonKey)),
        'recentrer': tester.getRect(find.byKey(mapRecenterButtonKey)),
      },
      fenetreBas = _fenetreDuBas(tester),
      designationPresente = find
          .byType(DesignateCenterControl)
          .evaluate()
          .isNotEmpty,
      pieces = <String, Rect?>{
        'MapLegend (partie visible)': _partieVisible(
          tester,
          find.byType(MapLegend),
          SingleChildScrollView,
        ),
        if (avis != null)
          'avis (partie visible)': _partieVisible(
            tester,
            avis,
            SingleChildScrollView,
          ),
        if (find.byType(DesignateCenterControl).evaluate().isNotEmpty)
          '$_designation (partie visible)': _partieVisible(
            tester,
            find.byType(DesignateCenterControl),
            ListView,
          ),
        _attribution: tester.getRect(find.byType(IgnAttributionBadge)),
        if (ficheKey != null) 'fiche': tester.getRect(find.byKey(ficheKey)),
      };

  final Size ecran;
  final Map<String, Rect> boutons;

  /// La fenêtre de la colonne du bas à droite, qui défile ancrée en bas.
  final Rect fenetreBas;
  final bool designationPresente;

  /// Les pièces que la colonne ne doit pas recouper ; `null` : rien n'en
  /// paraît.
  final Map<String, Rect?> pieces;

  /// Le rectangle qui englobe les cinq boutons.
  Rect get colonne =>
      boutons.values.reduce((Rect a, Rect b) => a.expandToInclude(b));

  /// `5 × minimumTapTarget + 4 × mapControlsSpacing` : calculée, jamais
  /// écrite (252 sous Windows, 272 sous Android).
  static double get hauteurAttendue =>
      5 * minimumTapTarget + 4 * mapControlsSpacing;

  /// Les pièces dont la partie visible (ou la boîte) recoupe la colonne.
  Set<String> get recoupes => <String>{
    for (final MapEntry<String, Rect?> p in pieces.entries)
      if (p.value != null && _recoupe(colonne, p.value!)) p.key,
  };

  String get mesure {
    final String detail = boutons.entries
        .map((MapEntry<String, Rect> e) => '${e.key}=${e.value}')
        .join(', ');
    final String autres = pieces.entries
        .map((MapEntry<String, Rect?> e) => '${e.key}=${e.value}')
        .join(', ');
    return 'écran=$ecran, colonne=$colonne (hauteur ${colonne.height}, '
        'attendue $hauteurAttendue ; $detail), fenêtre du bas=$fenetreBas, '
        'bouton de désignation présent=$designationPresente, $autres';
  }

  /// L'exigence de la colonne : dans l'écran, entière dans sa fenêtre, de la
  /// hauteur de ses cinq boutons, et sans recouper aucune pièce de [pieces].
  void exiger() {
    final Rect e = Offset.zero & ecran;
    expect(colonne.top, greaterThanOrEqualTo(0), reason: mesure);
    expect(e.expandToInclude(colonne), e, reason: 'hors de l’écran : $mesure');
    expect(
      colonne.height,
      moreOrLessEquals(hauteurAttendue, epsilon: 0.5),
      reason: mesure,
    );
    expect(
      fenetreBas.intersect(colonne),
      colonne,
      reason: 'la colonne dépasse de sa fenêtre : $mesure',
    );
    expect(recoupes, isEmpty, reason: mesure);
  }
}

void main() {
  setUpAll(_chargerRoboto);

  // ---------------------------------------------------------------------
  // La police : Roboto, pas la police de test
  // ---------------------------------------------------------------------
  _surAndroid('la police de ce fichier est ROBOTO : « Avertissement », dans le '
      'style du contrôle, fait environ 95 px (185 en police de test)', (
    WidgetTester tester,
  ) async {
    await _pumpOverlays(tester, _petit, scale: MapScaleKind.ecoulement);

    // Mesure du 2026-10-04 : 94,995 px en Roboto (14 pt, graisse 600),
    // 185,25 px en police de test. La borne sépare les deux sans coller à
    // l'une : si cette affirmation rougit, la police chargée n'est plus
    // Roboto et TOUS les pixels de ce fichier sont à refaire.
    final double largeur = _rectOf(tester, find.text(warningLinkLabel)).width;
    expect(
      largeur,
      inInclusiveRange(90, 100),
      reason:
          'largeur de « $warningLinkLabel » = $largeur '
          '(185 en police de test)',
    );
  });

  // ---------------------------------------------------------------------
  // Aucune erreur de rendu, avertissement et puces entiers dans l'écran
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool avecFiche in <bool>[false, true]) {
          for (final bool enMode in <bool>[false, true]) {
            final String cas =
                '${_nom(size, textScale, scale)}, ${_mode(enMode)}'
                '${avecFiche ? ', fiche de 320 px ouverte' : ''}';

            _surAndroid('$cas : aucune erreur de rendu, avertissement et '
                'trois puces entiers dans l’écran', (
              WidgetTester tester,
            ) async {
              // `_pumpOverlays` affirme l'absence de toute erreur de rendu.
              await _pumpOverlays(
                tester,
                size,
                textScale: textScale,
                scale: scale,
                enMode: enMode,
                avecFiche: avecFiche,
              );

              final Rect ecran = Offset.zero & size;
              final Rect lien = _rectOf(tester, find.byType(WarningLink));
              expect(
                ecran.intersect(lien),
                lien,
                reason: 'WarningLink hors de l’écran : $lien',
              );
              // Le libellé tient dans son contrôle, le contrôle dans l'écran.
              // `Rect.contains` exclut les bords droit et bas : l'inclusion se
              // vérifie par l'intersection.
              final Rect libelle = _rectOf(tester, find.text(warningLinkLabel));
              expect(lien.intersect(libelle), libelle);
              final Map<String, String> libelles = <String, String>{
                for (final MapScaleKind kind in MapScaleKind.values)
                  'puce ${kind.name}': mapScaleLabel(kind),
                'puce Restrictions': designationChipLabel,
              };
              for (final MapEntry<String, Finder> p
                  in _lesTroisPuces().entries) {
                final Rect puce = _rectOf(tester, p.value);
                expect(
                  ecran.intersect(puce),
                  puce,
                  reason: '${p.key} hors de l’écran : $puce',
                );
                final Rect texte = _rectOf(
                  tester,
                  find.descendant(
                    of: p.value,
                    matching: find.text(libelles[p.key]!),
                  ),
                );
                expect(puce.intersect(texte), texte, reason: p.key);
              }
            });
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Le nombre de rangées des trois puces (le motif de la décision Roboto)
  // ---------------------------------------------------------------------
  // `(taille, police, nombre de rangées)`, pour les deux échelles, hors mode et
  // en mode (la puce allumée est en gras, donc plus large). Invariants : en
  // police de test, la troisième puce passait à la ligne là où Roboto la
  // garde sur la rangée (390 px), et l'avis en était poussé sous les
  // contrôles. Marges mesurées le 2026-10-04 :
  // - 360 × 640, 100 % : « Écoulement » et « Débit » prennent la première
  //   rangée ; la troisième, seule sur la seconde (90,6 px), ne tient pas à
  //   côté : il lui manque 16 px au plus juste ;
  // - 390 × 844, 100 % : UNE rangée, qui tient de PEU — de 18,3 à 382 dans
  //   8 à 382, soit 10 px de marge en mode, échelle « débit » (deux puces en
  //   gras), 14 px hors mode « écoulement » : le premier à basculer ;
  // - 360 × 640 et 390 × 844, 200 % : trois rangées, les deux premières puces
  //   seules (457 à 462 px) dépassent déjà la largeur (344 et 374) d'au moins
  //   83 px ;
  // - 800 × 740, 100 % : une rangée de 364 à 372 px dans 516 offerts (800 − 8
  //   − 276 réservés à la légende), 144 px de marge ; 200 % : deux rangées, la
  //   première (457 à 462 px) tient avec 54 px de marge, la troisième
  //   déborderait de 107 px.
  for (final (Size, double, int) cas in <(Size, double, int)>[
    (_petit, 1, 2),
    (_petit, 2, 3),
    (_grand, 1, 1),
    (_grand, 2, 3),
    (const Size(800, 740), 1, 1),
    (const Size(800, 740), 2, 2),
  ]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool enMode in <bool>[false, true]) {
        final _Test sur = _selonFenetre(cas.$1);
        sur('à ${_nom(cas.$1, cas.$2, scale)}, ${_mode(enMode)} : les trois '
            'puces prennent ${cas.$3} rangée${cas.$3 > 1 ? 's' : ''}', (
          WidgetTester tester,
        ) async {
          await _pumpOverlays(
            tester,
            cas.$1,
            textScale: cas.$2,
            scale: scale,
            enMode: enMode,
          );

          expect(
            _rangeesDePuces(tester),
            cas.$3,
            reason:
                'puces=${_rectOf(tester, find.byType(MapScaleChips))}, '
                'écoulement=${_rectOf(tester, _puceEchelle(MapScaleKind.ecoulement))}, '
                'débit=${_rectOf(tester, _puceEchelle(MapScaleKind.debit))}, '
                'Restrictions=${_rectOf(tester, _puceRestrictions())}',
          );
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Gestes rendus à la carte
  // ---------------------------------------------------------------------
  // Les mêmes verrous, sous Android ET sous Windows : le bureau pose une
  // `Scrollbar` automatique autour de chaque défilement vertical, dont le
  // `MouseRegion` opaque absorbait le toucher sur toute la boîte de la
  // colonne. Une fenêtre Windows ne descend pas sous 800 de large (`K3`) : la
  // disposition compacte n'y est jamais montrée, mais la colonne compacte
  // garde la même enveloppe que les deux colonnes larges. C'est la SEULE
  // fenêtre de moins de 600 px de large que ce fichier monte sous Windows,
  // exprès : la `Scrollbar` du bureau ne s'éprouve que là.
  for (final (String, _Test) plateforme in <(String, _Test)>[
    ('', _surAndroid),
    (' — Windows', _surWindows),
  ]) {
    final _Test test = plateforme.$2;
    for (final bool enMode in <bool>[false, true]) {
      group('gestes — à 360 × 640, 100 %, échelle écoulement, un avis affiché, '
          '${_mode(enMode)}${plateforme.$1}', () {
        /// Un point DANS la fenêtre de la colonne, à gauche du contrôle
        /// d'avertissement, hors de tout enfant de la colonne : de la carte
        /// visible, au sens de l'usager.
        Offset pointALaGaucheDuLien(WidgetTester tester) {
          final Rect colonne = _fenetre(tester);
          final Rect lien = _rectOf(tester, find.byType(WarningLink));
          final Offset p = Offset(
            (colonne.left + lien.left) / 2,
            lien.center.dy,
          );
          expect(colonne.contains(p), isTrue, reason: '$p hors de $colonne');
          for (final Finder enfant in <Finder>[
            find.byType(WarningLink),
            find.byType(MapScaleChips),
            find.byType(MapLegend),
            _avis(MapScaleKind.ecoulement),
          ]) {
            expect(
              _rectOf(tester, enfant).contains(p),
              isFalse,
              reason: '$p tombe dans un enfant de la colonne',
            );
          }
          return p;
        }

        test('un tap hors des enfants de la colonne atteint la carte', (
          WidgetTester tester,
        ) async {
          int taps = 0;
          await _pumpOverlays(
            tester,
            _petit,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            onCarteTap: () => taps++,
          );

          await tester.tapAt(pointALaGaucheDuLien(tester));
          await tester.pump();

          expect(taps, 1);
        });

        test('un cran de molette hors des enfants de la colonne atteint '
            'la carte', (WidgetTester tester) async {
          int crans = 0;
          await _pumpOverlays(
            tester,
            _petit,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            onCarteMolette: () => crans++,
          );
          final Offset p = pointALaGaucheDuLien(tester);

          final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(souris.hover(p));
          await tester.sendEventToBinding(souris.scroll(const Offset(0, -100)));
          await tester.pump();

          expect(crans, 1);
        });

        test('un glisser hors des enfants de la colonne atteint la '
            'carte', (WidgetTester tester) async {
          int glissers = 0;
          await _pumpOverlays(
            tester,
            _petit,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            onCarteGlisser: () => glissers++,
          );

          await tester.dragFrom(
            pointALaGaucheDuLien(tester),
            const Offset(0, 80),
          );
          await tester.pump();

          expect(glissers, greaterThan(0));
        });

        test('un tap sur une puce d’échelle atteint la puce, pas la '
            'carte', (WidgetTester tester) async {
          int taps = 0;
          final List<MapScaleKind> choisies = <MapScaleKind>[];
          await _pumpOverlays(
            tester,
            _petit,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            onCarteTap: () => taps++,
            onSelect: choisies.add,
          );

          await tester.tap(_puceEchelle(MapScaleKind.debit));
          await tester.pump();

          expect(choisies, <MapScaleKind>[MapScaleKind.debit]);
          expect(taps, 0);
        });

        test('un tap sur la puce « Restrictions » atteint la puce, pas '
            'la carte', (WidgetTester tester) async {
          int taps = 0;
          int bascules = 0;
          await _pumpOverlays(
            tester,
            _petit,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            onCarteTap: () => taps++,
            onBasculerMode: () => bascules++,
          );

          await tester.tap(_puceRestrictions());
          await tester.pump();

          expect(bascules, 1);
          expect(taps, 0);
        });
      });
    }
  }

  // ---------------------------------------------------------------------
  // Ordre de la colonne : avertissement, puces, avis, puis légende
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surAndroid(
        'ordre de la colonne à ${_nom(size, 1, scale)} : avertissement, '
        'puces (trois), avis, puis légende (la légende n’est repoussée que '
        'pendant qu’un avis s’affiche : écart à BR-008 accepté le '
        '2026-10-03)',
        (WidgetTester tester) async {
          await _pumpOverlays(tester, size, scale: scale);

          final Rect lien = _rectOf(tester, find.byType(WarningLink));
          final Rect puces = _rectOf(tester, find.byType(MapScaleChips));
          final Rect lAvis = _rectOf(tester, _avis(scale));
          final Rect legende = _rectOf(tester, find.byType(MapLegend));

          expect(lien.bottom, lessThanOrEqualTo(puces.top));
          // Les trois puces sont DANS le bloc des puces, la troisième après la
          // deuxième (même rangée, à sa droite, ou rangée suivante).
          final Rect debit = _rectOf(tester, _puceEchelle(MapScaleKind.debit));
          final Rect restrictions = _rectOf(tester, _puceRestrictions());
          expect(puces.intersect(restrictions), restrictions);
          expect(
            restrictions.top > debit.top || restrictions.left >= debit.right,
            isTrue,
            reason: 'débit=$debit, Restrictions=$restrictions',
          );
          expect(
            puces.bottom,
            lessThanOrEqualTo(lAvis.top),
            reason: 'l’avis est sous les puces : $puces, $lAvis',
          );
          expect(
            lAvis.bottom,
            lessThanOrEqualTo(legende.top),
            reason: 'l’avis est au-dessus de la légende : $lAvis, $legende',
          );
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // Ordre de tabulation (`K2`) en disposition compacte
  // ---------------------------------------------------------------------
  // L'ordre visuel de la colonne compacte (avertissement en premier) n'est PAS
  // l'ordre de tabulation : les pièces sont construites une fois, avec leurs
  // `FocusTraversalOrder`, pour les deux dispositions. `map_keyboard_test.dart`
  // le vérifie sur `MapView` à 800 × 600 (large) ; ici, sous 600 px, sans
  // « carte » (aucun `FlutterMap` dans ce banc). Hors mode il n'y a pas de
  // bouton de désignation : l'action de l'avis (`K1` de T3) suit les puces,
  // « Filtres » (`F10b` de T3) la suit, et le contrôle d'avertissement suit
  // les contrôles de zoom ; en mode le bouton s'intercale entre les deux.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      for (final bool enMode in <bool>[false, true]) {
        _surAndroid('Tab à ${_nom(size, textScale, MapScaleKind.ecoulement)}, '
            '${_mode(enMode)} : puces (trois) → « Élargir la recherche » (K1 '
            'de T3) → « Filtres » → contrôles de zoom'
            '${enMode ? ' → bouton de désignation' : ''} → contrôle '
            'd’avertissement, puis reboucle', (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            size,
            textScale: textScale,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
          );

          final List<Finder> ordreAttendu = <Finder>[
            _puceEchelle(MapScaleKind.ecoulement),
            _puceEchelle(MapScaleKind.debit),
            _puceRestrictions(),
            find.byKey(widenSearchKey),
            find.byKey(mapFiltersButtonKey),
            find.byKey(mapZoomInButtonKey),
            find.byKey(mapZoomOutButtonKey),
            find.byKey(mapRecenterButtonKey),
            if (enMode) find.byKey(mapDesignateCenterButtonKey),
            find.byKey(warningLinkKey),
          ];
          for (final Finder attendu in ordreAttendu) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            expect(
              focusedWithin(tester, attendu),
              isTrue,
              reason: 'attendu à ce Tab : $attendu',
            );
          }

          // Un Tab de plus reboucle sur le premier arrêt : rien de ce que
          // Tab atteint n'est resté hors de l'ordre déclaré.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focusedWithin(tester, ordreAttendu.first), isTrue);
        });
      }
    }
  }

  // `K1` de T3 : l'ordre complet sous 600 px, les deux boutons d'entrée posés
  // (« Favoris » puis « Filtres »), et l'action de l'avis, arrêt de Tab juste
  // après les puces (arbitrage du commanditaire du 2026-10-14). À 100 % de
  // police seulement : la boucle ci-dessus couvre déjà 100 % et 200 %.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final bool enMode in <bool>[false, true]) {
      _surAndroid('Tab à ${_nom(size, 1, MapScaleKind.ecoulement)}, '
          '${_mode(enMode)}, « Favoris » posé : puces (trois) → « Élargir la '
          'recherche » → « Favoris » → « Filtres » → contrôles de zoom'
          '${enMode ? ' → bouton de désignation' : ''} → contrôle '
          'd’avertissement, puis reboucle (K1 de T3)', (
        WidgetTester tester,
      ) async {
        await _pumpOverlays(
          tester,
          size,
          scale: MapScaleKind.ecoulement,
          enMode: enMode,
          onOuvrirFavoris: () {},
        );

        final List<Finder> ordreAttendu = <Finder>[
          _puceEchelle(MapScaleKind.ecoulement),
          _puceEchelle(MapScaleKind.debit),
          _puceRestrictions(),
          find.byKey(widenSearchKey),
          find.byKey(mapFavoritesButtonKey),
          find.byKey(mapFiltersButtonKey),
          find.byKey(mapZoomInButtonKey),
          find.byKey(mapZoomOutButtonKey),
          find.byKey(mapRecenterButtonKey),
          if (enMode) find.byKey(mapDesignateCenterButtonKey),
          find.byKey(warningLinkKey),
        ];
        for (final Finder attendu in ordreAttendu) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, attendu),
            isTrue,
            reason: 'attendu à ce Tab : $attendu',
          );
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, ordreAttendu.first), isTrue);
      });
    }
  }

  _surAndroid('Tab à ${_nom(_petit, 1, MapScaleKind.ecoulement)}, HORS MODE, '
      'un filtre masque tous les lieux : puces (trois) → « Effacer les '
      'filtres » → « Favoris » → « Filtres » → contrôles de zoom → contrôle '
      'd’avertissement, puis reboucle ; Entrée sur l’action appelle '
      'onClearFilters UNE fois (K1 de T3)', (WidgetTester tester) async {
    int effacements = 0;
    await _pumpOverlays(
      tester,
      _petit,
      scale: MapScaleKind.ecoulement,
      avecAvis: false,
      filtreVideTout: true,
      onEffacer: () => effacements++,
      onOuvrirFavoris: () {},
    );
    expect(find.byKey(clearFiltersKey), findsOneWidget);

    final List<Finder> ordreAttendu = <Finder>[
      _puceEchelle(MapScaleKind.ecoulement),
      _puceEchelle(MapScaleKind.debit),
      _puceRestrictions(),
      find.byKey(clearFiltersKey),
      find.byKey(mapFavoritesButtonKey),
      find.byKey(mapFiltersButtonKey),
      find.byKey(mapZoomInButtonKey),
      find.byKey(mapZoomOutButtonKey),
      find.byKey(mapRecenterButtonKey),
      find.byKey(warningLinkKey),
    ];
    for (final Finder attendu in ordreAttendu) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        focusedWithin(tester, attendu),
        isTrue,
        reason: 'attendu à ce Tab : $attendu',
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedWithin(tester, ordreAttendu.first), isTrue);

    // Trois Tab de plus, depuis la première puce : l'action.
    for (int i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusedWithin(tester, find.byKey(clearFiltersKey)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(effacements, 1);
  });

  // Sans avis, aucun arrêt ne s'intercale : « Favoris » suit les puces.
  _surAndroid('Tab à ${_nom(_petit, 1, MapScaleKind.ecoulement)}, HORS MODE, '
      'SANS avis, « Favoris » posé : puces (trois) → « Favoris » → « Filtres » '
      '→ contrôles de zoom → contrôle d’avertissement, puis reboucle (K1 de '
      'T3)', (WidgetTester tester) async {
    await _pumpOverlays(
      tester,
      _petit,
      scale: MapScaleKind.ecoulement,
      avecAvis: false,
      onOuvrirFavoris: () {},
    );
    expect(find.byKey(widenSearchKey), findsNothing);
    expect(find.byKey(clearFiltersKey), findsNothing);

    final List<Finder> ordreAttendu = <Finder>[
      _puceEchelle(MapScaleKind.ecoulement),
      _puceEchelle(MapScaleKind.debit),
      _puceRestrictions(),
      find.byKey(mapFavoritesButtonKey),
      find.byKey(mapFiltersButtonKey),
      find.byKey(mapZoomInButtonKey),
      find.byKey(mapZoomOutButtonKey),
      find.byKey(mapRecenterButtonKey),
      find.byKey(warningLinkKey),
    ];
    for (final Finder attendu in ordreAttendu) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        focusedWithin(tester, attendu),
        isTrue,
        reason: 'attendu à ce Tab : $attendu',
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedWithin(tester, ordreAttendu.first), isTrue);
  });

  // ---------------------------------------------------------------------
  // Avis à 100 % (I1)
  // ---------------------------------------------------------------------
  // « Favoris » n'est pas posé ici : quatre boutons dans la colonne du bas,
  // ce que `main.dart` ne rend plus. Posé, à 360 × 640, « écoulement »,
  // l'avis dépasse de 8 px de sa fenêtre et cette boucle rougirait (section
  // `K3`, en fin de fichier : CONSTAT, son action reste entière et
  // atteignable) ; à 390 × 844 il tient (section `K3`, invariant).
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool enMode in <bool>[false, true]) {
        _surAndroid('à ${_nom(size, 1, scale)}, ${_mode(enMode)}, AVEC un avis '
            '(« Favoris » absent, quatre boutons) : l’avis est entier dans '
            'l’écran, libre de toute surcouche du bas, et son action « Élargir '
            'la recherche » est atteignable', (WidgetTester tester) async {
          await _pumpOverlays(tester, size, scale: scale, enMode: enMode);

          final Rect ecran = Offset.zero & size;
          final Rect lAvis = _rectOf(tester, _avis(scale));
          final Rect colonne = _fenetre(tester);
          expect(ecran.intersect(lAvis), lAvis, reason: 'hors écran : $lAvis');
          expect(
            colonne.intersect(lAvis),
            lAvis,
            reason: 'coupé par la fenêtre de la colonne : $lAvis, $colonne',
          );
          expect(
            _recoupements(tester, _avis(scale), _bas()),
            isEmpty,
            reason: 'avis=$lAvis',
          );
          // Marges (Roboto, 360 × 640, « écoulement », la plus haute) : le
          // bas de l'avis (332) est à 112 px du haut des contrôles de zoom
          // (444) et à 172 px du haut du bouton de désignation (504) ; à
          // 390 × 844 il en est plus loin encore. Aucun pixel ne se joue.
          expect(
            find.text(widenSearchLabel).hitTestable().evaluate(),
            isNotEmpty,
            reason: 'action=${_rectOf(tester, find.text(widenSearchLabel))}',
          );
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Légende à 100 % (I2)
  // ---------------------------------------------------------------------
  // « Favoris » n'est pas posé ici : quatre boutons dans la colonne du bas,
  // ce que `main.dart` ne rend plus. Posé, à 360 × 640, la légende
  // « écoulement » a 17 px à défiler et cette boucle rougirait (CONSTAT de
  // `S10`, `map_entry_buttons_overlap_test.dart`) — un effet couvert par
  // l'arbitrage du commanditaire du 2026-10-14 : « Favoris » reste au-dessus
  // de « Filtres », et au téléphone la légende défile un peu plus.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final bool enMode in <bool>[false, true]) {
      _surAndroid(
        'à ${_nom(size, 1, MapScaleKind.ecoulement)}, ${_mode(enMode)}, SANS '
        'avis (« Favoris » absent, quatre boutons) : la légende est entière, '
        'dans l’écran, et ne recoupe ni les contrôles de zoom, ni le bouton '
        'de désignation, ni l’attribution',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            size,
            scale: MapScaleKind.ecoulement,
            enMode: enMode,
            avecAvis: false,
          );

          final Rect ecran = Offset.zero & size;
          final Rect legende = _rectOf(tester, find.byType(MapLegend));
          final Rect colonne = _fenetre(tester);
          expect(ecran.intersect(legende), legende, reason: 'hors écran');
          expect(
            colonne.intersect(legende),
            legende,
            reason: 'coupée par la fenêtre de la colonne : $legende, $colonne',
          );
          expect(
            _recoupements(tester, find.byType(MapLegend), _bas()),
            isEmpty,
            reason: 'légende=$legende',
          );
          // Marge (Roboto, 360 × 640) : le bas de la légende (341) est à
          // 103 px du haut des contrôles (444).
        },
      );
    }
  }

  // `(taille, EN MODE, légende coupée par la fenêtre, ce que la légende
  // recoupe)`. La légende « débit » (247 px de haut en Roboto) sans avis.
  //
  // Depuis le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
  // `F10b` de T3) la fenêtre de la colonne s'arrête au-dessus de la colonne
  // du bas à droite : à 360 × 640 elle finit à 380, le groupe « Filtres »
  // commençant à 388. La légende (176 à 423) y est donc COUPÉE — elle défile —
  // et sa partie visible ne recoupe rien. Avant, la fenêtre ne la coupait pas
  // et elle s'arrêtait à 21 px des contrôles de zoom (444). À 390 × 844 la
  // fenêtre est assez haute : rien n'a changé.
  for (final (Size, bool, bool, Set<String>) cas
      in <(Size, bool, bool, Set<String>)>[
        (_petit, false, true, <String>{}),
        (_petit, true, true, <String>{}),
        (_grand, false, false, <String>{}),
        (_grand, true, false, <String>{}),
      ]) {
    _surAndroid(
      'CONSTAT — à ${_nom(cas.$1, 1, MapScaleKind.debit)}, ${_mode(cas.$2)}, '
      'SANS avis : la légende « débit » (247 px de haut) '
      '${cas.$3 ? 'est coupée par sa fenêtre' : 'n’est pas coupée par sa fenêtre'}'
      ' ; INVARIANT — sa partie visible ne recoupe aucune surcouche du bas',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          scale: MapScaleKind.debit,
          enMode: cas.$2,
          avecAvis: false,
        );

        // ⚠️ Ce test verrouille un FAIT CONSTATÉ, pas un invariant voulu : si
        // la légende « débit » se met à recouper ces surcouches (police plus
        // large, paragraphe plus long), l'écran s'est dégradé — corriger ce
        // test À LA MAIN pour le dire.
        final Rect legende = _rectOf(tester, find.byType(MapLegend));
        final Rect colonne = _fenetre(tester);
        expect(
          legende.bottom > colonne.bottom,
          cas.$3,
          reason: 'légende=$legende, fenêtre=$colonne',
        );
        expect(
          _recoupements(tester, find.byType(MapLegend), _bas()),
          cas.$4,
          reason: 'légende=$legende',
        );
      },
    );
  }

  // `(taille, échelle, EN MODE, légende coupée par la fenêtre, ce que la
  // légende recoupe)`, AVEC un avis : la légende, repoussée sous lui.
  //
  // Depuis le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
  // `F10b` de T3) : à 360 × 640 la fenêtre de la colonne finit à 380, au-dessus
  // du groupe « Filtres » (388). La légende — « écoulement » de 340 à 505,
  // « débit » de 321 à 568 — y est COUPÉE et défile ; sa partie visible ne
  // recoupe plus AUCUNE surcouche du bas, hors mode comme en mode. Avant, la
  // fenêtre ne la coupait pas : elle passait sous les contrôles de zoom (444)
  // et, en mode, sous le bouton de désignation (504) — l'écart à `BR-008`
  // accepté le 2026-10-03, qui disparaît. À 390 × 844 rien ne la recoupe et
  // rien ne la coupe, comme avant.
  for (final (Size, MapScaleKind, bool, bool, Set<String>) cas
      in <(Size, MapScaleKind, bool, bool, Set<String>)>[
        (_petit, MapScaleKind.ecoulement, false, true, <String>{}),
        (_petit, MapScaleKind.ecoulement, true, true, <String>{}),
        (_petit, MapScaleKind.debit, false, true, <String>{}),
        (_petit, MapScaleKind.debit, true, true, <String>{}),
        (_grand, MapScaleKind.ecoulement, false, false, <String>{}),
        (_grand, MapScaleKind.ecoulement, true, false, <String>{}),
        (_grand, MapScaleKind.debit, false, false, <String>{}),
        (_grand, MapScaleKind.debit, true, false, <String>{}),
      ]) {
    _surAndroid(
      'CONSTAT — à ${_nom(cas.$1, 1, cas.$2)}, ${_mode(cas.$3)}, AVEC un '
      'avis : la légende, repoussée sous l’avis, '
      '${cas.$4 ? 'est coupée par sa fenêtre' : 'n’est pas coupée par sa fenêtre'}'
      ' ; INVARIANT — sa partie visible ne recoupe aucune surcouche du bas',
      (WidgetTester tester) async {
        await _pumpOverlays(tester, cas.$1, scale: cas.$2, enMode: cas.$3);

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu — voir plus haut. C'est
        // l'écart à `BR-008` accepté le 2026-10-03 : un avis repousse la
        // légende.
        final Rect legende = _rectOf(tester, find.byType(MapLegend));
        final Rect colonne = _fenetre(tester);
        expect(
          legende.bottom > colonne.bottom,
          cas.$4,
          reason: 'légende=$legende, fenêtre=$colonne',
        );
        expect(
          _recoupements(tester, find.byType(MapLegend), _bas()),
          cas.$5,
          reason: 'légende=$legende',
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // `BR-012` : le contrôle d'avertissement et les puces, atteignables (I3)
  // ---------------------------------------------------------------------
  // HORS MODE il n'y a pas de bouton de désignation : rien ne recouvre la
  // colonne du haut sauf, parfois, les contrôles de zoom et l'attribution,
  // qui sont en bas. À 100 % comme à 200 %, aux deux tailles de téléphone,
  // pour les deux échelles, avec et sans avis : ce n'est PAS un CONSTAT, c'est
  // un invariant (`BR-012` : le contrôle doit rester utilisable).
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool avecAvis in <bool>[true, false]) {
          _surAndroid(
            'BR-012 — à ${_nom(size, textScale, scale)}, HORS MODE, '
            '${avecAvis ? 'AVEC' : 'SANS'} avis : le centre du contrôle '
            '« ⚠ Avertissement » et celui des trois puces sont atteignables',
            (WidgetTester tester) async {
              await _pumpOverlays(
                tester,
                size,
                textScale: textScale,
                scale: scale,
                avecAvis: avecAvis,
              );

              final Map<String, Finder> atteignables = <String, Finder>{
                'WarningLink': find.byType(WarningLink),
                ..._lesTroisPuces(),
              };
              for (final MapEntry<String, Finder> e in atteignables.entries) {
                expect(
                  _atteignable(e.value),
                  isTrue,
                  reason: '${e.key}=${_rectOf(tester, e.value)} recouvert',
                );
              }
            },
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Seuil de la disposition compacte
  // ---------------------------------------------------------------------
  _surAndroid('à 599 px de large la disposition est compacte : la légende est '
      'SOUS les puces', (WidgetTester tester) async {
    await _pumpOverlays(
      tester,
      const Size(599, 900),
      scale: MapScaleKind.ecoulement,
    );

    final Rect puces = _rectOf(tester, find.byType(MapScaleChips));
    final Rect legende = _rectOf(tester, find.byType(MapLegend));
    expect(puces.bottom, lessThanOrEqualTo(legende.top));
  });

  _surWindows('à 600 px de large la disposition est large : la légende est À '
      'DROITE des puces, en haut', (WidgetTester tester) async {
    await _pumpOverlays(
      tester,
      const Size(600, 900),
      scale: MapScaleKind.ecoulement,
    );

    final Rect puces = _rectOf(tester, find.byType(MapScaleChips));
    final Rect legende = _rectOf(tester, find.byType(MapLegend));
    expect(puces.right, lessThanOrEqualTo(legende.left));
    expect(puces.top, lessThan(legende.top));
  });

  // ---------------------------------------------------------------------
  // Disposition LARGE : la colonne gauche défile, aucune erreur de rendu
  // ---------------------------------------------------------------------
  // Les tailles que `project-state.md` citait en débordement avant que la
  // colonne gauche ne défile (`E5`) : 600 × 360 et 640 × 360 (téléphone en
  // paysage), 700 × 740, 800 × 640 et 900 × 640 — rejouées le 2026-10-04 en
  // Roboto ET en police de test : plus AUCUNE erreur de rendu. 800 × 740 est
  // la taille minimale de la fenêtre Windows.
  //
  // En Roboto, seuls 600 × 360 et 640 × 360, à 200 %, ont un avis qui dépasse
  // la fenêtre de la colonne gauche : c'est là que le défilement sert. Ces
  // deux tailles et 800 × 740 (la taille minimale Windows, où le défaut de
  // `E5` avait été mesuré, à 200 %) ont toute la matrice. Les autres tailles
  // ne prouvent rien de plus que « aucune erreur de rendu » : un seul cas
  // chacune, le plus exigeant (200 %, « écoulement », la plus haute, en mode).
  for (final Size taille in <Size>[
    const Size(600, 360),
    const Size(640, 360),
    const Size(800, 740),
  ]) {
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool enMode in <bool>[false, true]) {
          final _Test sur = _selonFenetre(taille);
          sur(
            'disposition LARGE à ${_nom(taille, textScale, scale)}, '
            '${_mode(enMode)}, avis affiché : aucune erreur de rendu, et le '
            'bas de l’avis s’amène dans la fenêtre de la colonne gauche en la '
            'faisant défiler',
            (WidgetTester tester) => _verifierColonneGauche(
              tester,
              taille,
              textScale: textScale,
              scale: scale,
              enMode: enMode,
            ),
          );
        }
      }
    }
  }
  for (final Size taille in <Size>[
    const Size(700, 740),
    const Size(800, 640),
    const Size(900, 640),
  ]) {
    _surWindows(
      'disposition LARGE à ${_nom(taille, 2, MapScaleKind.ecoulement)}, '
      '${_mode(true)}, avis affiché : aucune erreur de rendu (un seul cas à '
      'cette taille : rien n’y défile en Roboto)',
      (WidgetTester tester) => _verifierColonneGauche(
        tester,
        taille,
        textScale: 2,
        scale: MapScaleKind.ecoulement,
        enMode: true,
      ),
    );
  }

  // `(taille, police, échelle, EN MODE, action de l'avis atteignable au repos,
  // hauteur de l'action que l'attribution recouvre une fois la colonne
  // défilée)`. Rejoué en Roboto le 2026-10-04.
  //
  // - À 600 × 360 et 640 × 360, 200 %, l'avis dépasse la fenêtre : au repos
  //   son action n'est pas atteignable, et une fois la colonne défilée
  //   l'attribution IGN (35 px de haut, à droite) en recouvre le bas de
  //   23 px — le centre de l'action, lui, est atteignable (affirmé : il est à
  //   3,5 px au-dessus de l'attribution, de PEU).
  // - À 800 × 740, 200 %, rien ne défile et l'attribution ne recoupe pas
  //   l'action. (En POLICE DE TEST l'attribution y mesurait 66 px, sur deux
  //   lignes, et recouvrait le bas de l'action de 54 px : un artefact de la
  //   police, mesure du 2026-10-04 ; `map_view_test.dart`, qui mesure en
  //   police de test, ne l'a pas encore repris.)
  // - À 600 × 360, 100 %, « écoulement », EN MODE : la pilule du bouton
  //   (134,5 à 465,5 de large) recouvre le bord droit de l'action de l'avis
  //   (x de 134,5 à 159,6, y de 236 à 264) mais pas son centre (89,8, à
  //   44,7 px de la pilule) : l'action est atteignable, comme hors mode. Avant
  //   la correction de la bande (2026-10-04), la bande — un `ListView` opaque
  //   de 64 à 536 de large, plus large que la pilule et son indice — recevait
  //   le geste au centre de l'action, qui n'était pas atteignable : c'est la
  //   seule entrée de ce fichier que la correction a changée.
  for (final (Size, double, MapScaleKind, bool, bool, double) cas
      in <(Size, double, MapScaleKind, bool, bool, double)>[
        (const Size(600, 360), 1, MapScaleKind.ecoulement, false, true, 0),
        (const Size(600, 360), 1, MapScaleKind.ecoulement, true, true, 0),
        (const Size(600, 360), 1, MapScaleKind.debit, false, true, 0),
        (const Size(600, 360), 1, MapScaleKind.debit, true, true, 0),
        (const Size(600, 360), 2, MapScaleKind.ecoulement, false, false, 23),
        (const Size(600, 360), 2, MapScaleKind.ecoulement, true, false, 23),
        (const Size(600, 360), 2, MapScaleKind.debit, false, false, 23),
        (const Size(600, 360), 2, MapScaleKind.debit, true, false, 23),
        (const Size(640, 360), 2, MapScaleKind.ecoulement, false, false, 23),
        (const Size(640, 360), 2, MapScaleKind.ecoulement, true, false, 23),
        (const Size(640, 360), 2, MapScaleKind.debit, false, false, 23),
        (const Size(640, 360), 2, MapScaleKind.debit, true, false, 23),
        (const Size(800, 740), 2, MapScaleKind.ecoulement, false, true, 0),
        (const Size(800, 740), 2, MapScaleKind.ecoulement, true, true, 0),
        (const Size(800, 740), 2, MapScaleKind.debit, false, true, 0),
        (const Size(800, 740), 2, MapScaleKind.debit, true, true, 0),
      ]) {
    final _Test sur = _selonFenetre(cas.$1);
    sur('CONSTAT — disposition LARGE à ${_nom(cas.$1, cas.$2, cas.$3)}, '
        '${_mode(cas.$4)}, avis affiché : l’action de l’avis '
        '${cas.$5 ? 'est' : 'n’est pas'} atteignable au repos ; une fois la '
        'colonne défilée, l’attribution en recouvre le bas de '
        '${cas.$6.toInt()} px'
        '${cas.$6 > 0 ? ' (le centre de l’action reste atteignable)' : ''}', (
      WidgetTester tester,
    ) async {
      await _pumpOverlays(
        tester,
        cas.$1,
        textScale: cas.$2,
        scale: cas.$3,
        enMode: cas.$4,
      );

      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : l'attribution IGN est
      // posée au-dessus de la colonne dans la pile.
      expect(
        _atteignable(find.byKey(widenSearchKey)),
        cas.$5,
        reason: 'action=${_rectOf(tester, find.byKey(widenSearchKey))}',
      );
      final Rect colonne = _fenetre(tester);
      final Rect repos = _rectOf(tester, _avis(cas.$3));
      final bool aDefile = repos.bottom > colonne.bottom;
      if (aDefile) {
        await _defilerDuDoigt(tester, repos.bottom - colonne.bottom);
      }
      // Une fois la colonne défilée, le centre de l'action est atteignable ;
      // quand rien n'a défilé, il l'est comme au repos.
      expect(
        _atteignable(find.byKey(widenSearchKey)),
        cas.$5 || aDefile,
        reason:
            'après défilement : '
            'action=${_rectOf(tester, find.byKey(widenSearchKey))}',
      );
      final Rect action = _rectOf(tester, find.byKey(widenSearchKey));
      final Rect attribution = _rectOf(
        tester,
        find.byType(IgnAttributionBadge),
      );
      final double recouvert = attribution.overlaps(action)
          ? action.bottom - attribution.top
          : 0;
      expect(
        recouvert,
        cas.$6,
        reason: 'action=$action, attribution=$attribution',
      );
    });
  }

  // ---------------------------------------------------------------------
  // Légende qui dépasse sa fenêtre, à 100 % et à 200 %
  // ---------------------------------------------------------------------
  // Affirmation stricte : quand la légende dépasse le bas de la fenêtre,
  // faire défiler la colonne DU DOIGT en amène le bord bas dans la fenêtre,
  // au-dessus du groupe « Filtres », et elle y tient entière si elle est plus
  // basse que la fenêtre n'est haute. Sans table de valeurs mesurées : tout
  // vient de la géométrie du test.
  //
  // Depuis le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
  // `F10b` de T3) la fenêtre s'arrête au-dessus de la colonne du bas à droite :
  // deux cas de plus ont de quoi défiler — 360 × 640, « écoulement », SANS avis
  // (la légende y tenait entière, sous les contrôles de zoom), et 390 × 844,
  // « écoulement », AVEC un avis (299 px à défiler ; il n'y en avait qu'UN,
  // verrouillé à part en CONSTAT « de peu », retiré : ce n'est plus un cas
  // limite). Seul 390 × 844, « écoulement », SANS avis reste hors de la table :
  // la légende y tient entière au repos (voir le CONSTAT ci-dessous).
  //
  // À 100 % aussi, depuis le même arbitrage : la table porte les trois
  // situations où la légende dépasse sa fenêtre à cette échelle de police,
  // toutes à 360 × 640 — « écoulement » AVEC un avis (125 px à défiler),
  // « débit » SANS avis (43 px) et AVEC un avis (188 px). Les cinq autres
  // situations à 100 % (« écoulement » sans avis à 360 × 640, et tout
  // 390 × 844) n'ont rien à défiler : la légende y est entière au repos.
  for (final (double, Size, MapScaleKind, bool) cas
      in <(double, Size, MapScaleKind, bool)>[
        (1, _petit, MapScaleKind.ecoulement, true),
        (1, _petit, MapScaleKind.debit, true),
        (1, _petit, MapScaleKind.debit, false),
        (2, _petit, MapScaleKind.ecoulement, true),
        (2, _petit, MapScaleKind.debit, true),
        (2, _grand, MapScaleKind.ecoulement, true),
        (2, _grand, MapScaleKind.debit, true),
        (2, _petit, MapScaleKind.ecoulement, false),
        (2, _petit, MapScaleKind.debit, false),
        (2, _grand, MapScaleKind.debit, false),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      _surAndroid('à ${_nom(cas.$2, cas.$1, cas.$3)}, ${_mode(enMode)}'
          '${cas.$4 ? ', AVEC un avis' : ', SANS avis'}'
          ' : faire défiler la colonne amène le bord bas de la légende dans la '
          'fenêtre, au-dessus du groupe « Filtres »', (
        WidgetTester tester,
      ) async {
        await _pumpOverlays(
          tester,
          cas.$2,
          textScale: cas.$1,
          scale: cas.$3,
          enMode: enMode,
          avecAvis: cas.$4,
        );

        final Rect colonne = _fenetre(tester);
        Rect legende() => _rectOf(tester, find.byType(MapLegend));
        final double distance = _adefiler(tester);
        final double basAvant = legende().bottom;
        expect(
          distance,
          greaterThan(0),
          reason: 'rien à défiler : fenêtre=$colonne, légende=${legende()}',
        );

        await _defilerDuDoigt(tester, distance);

        expect(
          basAvant - legende().bottom,
          greaterThan(0),
          reason: 'la colonne n’a pas défilé : légende=${legende()}',
        );
        expect(
          legende().bottom,
          lessThanOrEqualTo(colonne.bottom + 0.5),
          reason: 'après défilement : fenêtre=$colonne, légende=${legende()}',
        );
        // La dernière ligne de la légende se lit AU-DESSUS des boutons.
        final Rect groupe = _rectOf(tester, find.byType(MapEntryButtons));
        expect(
          legende().bottom,
          lessThan(groupe.top),
          reason: 'légende=${legende()}, groupe « Filtres »=$groupe',
        );
        final bool entiere =
            legende().top >= colonne.top && legende().bottom <= colonne.bottom;
        expect(
          entiere,
          legende().height <= colonne.height,
          reason: 'après défilement : fenêtre=$colonne, légende=${legende()}',
        );
      });
    }
  }

  // `(taille, échelle, avec un avis, légende au repos, ce qu'elle recoupe
  // HORS MODE, ce qu'elle recoupe EN MODE — une fois amenée au bord bas de la
  // fenêtre, sans rien défiler quand elle y est déjà)`.
  //
  // Depuis le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
  // `F10b` de T3), la partie visible de la légende ne passe plus JAMAIS sous
  // les contrôles de zoom ni sous l'attribution : la fenêtre s'arrête
  // au-dessus d'eux. État au repos, lui aussi changé : avec un avis la légende
  // est désormais CACHÉE sous le bord de la fenêtre (elle était « en partie »
  // visible, sous les boutons), et à 360 × 640, « écoulement », sans avis, elle
  // n'est plus qu'« en partie » visible (elle était entière, sous les
  // contrôles de zoom).
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` : la fenêtre finit à 278 à
  // 360 × 640 et à 482 à 390 × 844, une cible et un écart plus haut. EN MODE,
  // la légende amenée au bord bas de la fenêtre ne recoupe plus le bouton de
  // désignation (haut à 299 et à 503) — elle le recoupait dans les huit cas,
  // quatre boutons posés — et à 390 × 844, « écoulement », sans avis, elle
  // n'est plus entière au repos (« en partie », elle était « entière »).
  for (final (Size, MapScaleKind, bool, String, Set<String>, Set<String>) cas
      in <(Size, MapScaleKind, bool, String, Set<String>, Set<String>)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          true,
          'cachée',
          <String>{},
          <String>{},
        ),
        (_petit, MapScaleKind.debit, true, 'cachée', <String>{}, <String>{}),
        (
          _grand,
          MapScaleKind.ecoulement,
          true,
          'cachée',
          <String>{},
          <String>{},
        ),
        (_grand, MapScaleKind.debit, true, 'cachée', <String>{}, <String>{}),
        (
          _petit,
          MapScaleKind.ecoulement,
          false,
          'en partie',
          <String>{},
          <String>{},
        ),
        (
          _grand,
          MapScaleKind.ecoulement,
          false,
          'en partie',
          <String>{},
          <String>{},
        ),
        (
          _petit,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{},
          <String>{},
        ),
        (
          _grand,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{},
          <String>{},
        ),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$6 : cas.$5;
      _surAndroid('CONSTAT — à ${_nom(cas.$1, 2, cas.$2)}, ${_mode(enMode)}'
          '${cas.$3 ? ', AVEC un avis' : ', SANS avis'}'
          ' : au repos la légende est ${cas.$4} ; amenée dans la fenêtre, elle '
          '${attendu.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                    '${attendu.join(', ')}'}', (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: cas.$2,
          enMode: enMode,
          avecAvis: cas.$3,
          onOuvrirFavoris: () {},
        );

        // ⚠️ FAIT CONSTATÉ pour l'état au repos et pour le bouton de
        // désignation. INVARIANT, lui, depuis le 2026-10-12 : ni les
        // contrôles de zoom ni l'attribution ne recoupent la partie visible
        // de la légende — affirmé à part ci-dessous.
        expect(
          _etat(tester, find.byType(MapLegend)),
          cas.$4,
          reason:
              'au repos : fenêtre=${_fenetre(tester)}, '
              'légende=${_rectOf(tester, find.byType(MapLegend))}',
        );
        final double distance = _adefiler(tester);
        if (distance > 0) {
          await _defilerDuDoigt(tester, distance);
        }
        final Set<String> recoupes = _recoupements(
          tester,
          find.byType(MapLegend),
          _bas(),
        );
        expect(
          recoupes.intersection(<String>{_controles, _attribution}),
          isEmpty,
          reason:
              'après défilement : '
              'légende=${_rectOf(tester, find.byType(MapLegend))}',
        );
        expect(
          recoupes,
          attendu,
          reason:
              'après défilement : '
              'légende=${_rectOf(tester, find.byType(MapLegend))}',
        );
      });
    }
  }

  // `(taille, échelle, ce que la partie visible de l'avis recoupe HORS MODE,
  // ce qu'elle recoupe EN MODE)`. À 200 %, avec un avis, en Roboto : l'avis
  // (344 px à 360 × 640 « écoulement », 307 px sinon).
  //
  // Depuis le 2026-10-12 (arbitrage du commanditaire, « La légende défile »,
  // `F10b` de T3) la fenêtre de la colonne s'arrête au-dessus de la colonne
  // du bas à droite : l'avis n'est plus ENTIER au repos, il est « en partie »
  // visible, et sa partie visible ne passe plus sous les contrôles de zoom ni
  // sous l'attribution. Son action « Élargir la recherche », en bas de l'avis,
  // s'atteint en faisant défiler la colonne. Avant : l'avis était entier dans
  // l'écran et passait SOUS les contrôles (et l'attribution) ; hors mode
  // l'action était atteignable sans défiler, et EN MODE elle ne l'était pas du
  // tout (le bouton de désignation la recouvrait).
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` : la fenêtre finit à 278 à
  // 360 × 640 et à 482 à 390 × 844. L'avis dépasse de sa fenêtre de 304 px
  // (360 × 640, « écoulement »), 267 px (360 × 640, « débit ») et 63 px
  // (390 × 844) — quatre boutons posés : 248 px au plus, 7 px à 390 × 844. EN
  // MODE, sa partie visible ne recoupe plus le bouton de désignation (haut à
  // 299 et à 503) ; quatre boutons posés, elle le recoupait dans les quatre cas,
  // et l'action amenée au bas de la fenêtre n'était qu'à 3,5 px au-dessus du
  // bouton à 360 × 640.
  for (final (Size, MapScaleKind, Set<String>, Set<String>) cas
      in <(Size, MapScaleKind, Set<String>, Set<String>)>[
        (_petit, MapScaleKind.ecoulement, <String>{}, <String>{}),
        (_petit, MapScaleKind.debit, <String>{}, <String>{}),
        (_grand, MapScaleKind.ecoulement, <String>{}, <String>{}),
        (_grand, MapScaleKind.debit, <String>{}, <String>{}),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$4 : cas.$3;
      _surAndroid(
        'CONSTAT — à ${_nom(cas.$1, 2, cas.$2)}, ${_mode(enMode)}, AVEC un '
        'avis : l’avis, en partie visible au repos, '
        '${attendu.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                  '${attendu.join(', ')}'} ; amené dans la fenêtre, son '
        'action est atteignable',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            cas.$1,
            textScale: 2,
            scale: cas.$2,
            enMode: enMode,
            onOuvrirFavoris: () {},
          );

          // ⚠️ FAIT CONSTATÉ pour l'état au repos et pour le bouton de
          // désignation, posé au-dessus de la colonne du haut (arbitrage du
          // 2026-10-03 : à ne pas corriger ici). INVARIANT depuis le
          // 2026-10-12 : ni les contrôles de zoom ni l'attribution ne
          // recoupent la partie visible de l'avis.
          final Finder lAvis = _avis(cas.$2);
          final Rect fenetre = _fenetre(tester);
          expect(
            _etat(tester, lAvis),
            'en partie',
            reason: 'avis=${_rectOf(tester, lAvis)}, fenêtre=$fenetre',
          );
          final Set<String> recoupes = _recoupements(tester, lAvis, _bas());
          expect(
            recoupes.intersection(<String>{_controles, _attribution}),
            isEmpty,
            reason: 'avis=${_rectOf(tester, lAvis)}',
          );
          expect(recoupes, attendu, reason: 'avis=${_rectOf(tester, lAvis)}');

          // L'action, en bas de l'avis, s'amène dans la fenêtre du doigt.
          await _defilerDuDoigt(
            tester,
            _rectOf(tester, lAvis).bottom - fenetre.bottom,
          );
          expect(
            _rectOf(tester, lAvis).bottom,
            lessThanOrEqualTo(fenetre.bottom + 0.5),
            reason: 'avis=${_rectOf(tester, lAvis)}, fenêtre=$fenetre',
          );
          expect(
            _atteignable(find.byKey(widenSearchKey)),
            isTrue,
            reason:
                'action=${_rectOf(tester, find.byKey(widenSearchKey))}, '
                'fenêtre=$fenetre',
          );
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // EN MODE, à 200 % : ce que le bouton de désignation recouvre (I4)
  // ---------------------------------------------------------------------
  // INVARIANT : le centre de la puce « Restrictions » est atteignable — le
  // même critère que `BR-012` pour le contrôle d'avertissement et les puces
  // d'échelle (I3). La puce est la SEULE sortie du mode : si son centre était
  // recouvert, le mode n'aurait plus de sortie tactile, un blocage et non un
  // CONSTAT. Marge (mesure du 2026-10-04) : la puce finit à 230, le bouton
  // commence à 299 à 360 × 640 (69 px) et à 503 à 390 × 844 (273 px).
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool avecAvis in <bool>[true, false]) {
        _surAndroid(
          'EN MODE, à ${_nom(size, 2, scale)}, ${avecAvis ? 'AVEC' : 'SANS'} '
          'avis : le centre de la puce « Restrictions » est atteignable (le '
          'bouton de désignation ne le recouvre pas)',
          (WidgetTester tester) async {
            await _pumpOverlays(
              tester,
              size,
              textScale: 2,
              scale: scale,
              enMode: true,
              avecAvis: avecAvis,
            );

            expect(
              _atteignable(_puceRestrictions()),
              isTrue,
              reason:
                  'puce=${_rectOf(tester, _puceRestrictions())}, bouton='
                  '${_rectOf(tester, find.byType(DesignateCenterControl))}',
            );
          },
        );
      }
    }
  }

  // CONSTAT : la surface entière de la puce est atteignable — 100 % des points
  // d'une grille de 2 px, mesuré le 2026-10-04 aux mêmes cas. Ce n'est PAS un
  // invariant : sur une fenêtre plus courte le bouton la rejoint (voir plus
  // bas), et la surface passe sous 100 % bien avant que le centre ne soit
  // recouvert. Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la
  // colonne du bas à cinq boutons comme dans `main.dart` : inchangé.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool avecAvis in <bool>[true, false]) {
        _surAndroid('CONSTAT — EN MODE, à ${_nom(size, 2, scale)}, '
            '${avecAvis ? 'AVEC' : 'SANS'} avis : toute la surface de la puce '
            '« Restrictions » est atteignable (100 % d’une grille de 2 px)', (
          WidgetTester tester,
        ) async {
          await _pumpOverlays(
            tester,
            size,
            textScale: 2,
            scale: scale,
            enMode: true,
            avecAvis: avecAvis,
            onOuvrirFavoris: () {},
          );

          // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : corriger ce test À LA
          // MAIN si le bouton se rapproche de la puce.
          expect(
            _surfaceAtteignable(tester, _puceRestrictions()),
            1.0,
            reason:
                'puce=${_rectOf(tester, _puceRestrictions())}, bouton='
                '${_rectOf(tester, find.byType(DesignateCenterControl))}',
          );
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // EN MODE : la bande du bouton ne capte les gestes que sur ses enfants
  // ---------------------------------------------------------------------
  // La bande (le `ListView` de `_DesignationPlacement`) est plus large que la
  // pilule et son indice : à 800 × 740, 100 %, sous Windows, elle va de 60 à
  // 740 quand la pilule va de 234,5 à 565,5 (verrouillé dans le groupe
  // « Windows » plus bas). Opaque (le défaut d'un `Scrollable`), elle
  // captait les gestes de la carte sur toute cette largeur. Défaut relevé
  // pendant `E5b`, corrigé le 2026-10-04 par `deferToChild`. 800 × 740 et
  // 800 × 700 tournent sous Windows, 600 × 360 (téléphone en paysage) sous
  // Android (`N9` de T3).
  for (final Size taille in <Size>[
    const Size(800, 740),
    const Size(600, 360),
    const Size(800, 700),
  ]) {
    final _Test sur = _selonFenetre(taille);
    sur(
      'EN MODE, à ${_nom(taille, 1, MapScaleKind.ecoulement)} : un tap, un '
      'glisser et un cran de molette posés dans la bande, hors de la pilule et '
      'de l’indice, atteignent la carte',
      (WidgetTester tester) => _verifierBande(tester, taille),
    );
  }

  // Le défilement du BAS À DROITE (`F10b` de T3, ancré en bas) : même verrou,
  // sous Windows (taille minimale de la fenêtre, `Scrollbar` automatique du
  // bureau) ET sous Android (téléphone).
  for (final Size taille in <Size>[const Size(800, 740), _petit]) {
    final _Test sur = _selonFenetre(taille);
    sur(
      'HORS MODE, à ${_nom(taille, 1, MapScaleKind.ecoulement)} : un tap, un '
      'glisser et un cran de molette posés dans la boîte du défilement du bas '
      'à droite, hors des boutons et de l’attribution, atteignent la carte',
      (WidgetTester tester) => _verifierBasADroite(tester, taille),
    );
  }

  // Le bouton lui-même marche toujours : quand le contenu de la bande dépasse
  // la hauteur restante — 360 × 300, 200 % : la bande (206 px) ne contient pas
  // le bouton et son indice (259 px) —, elle défile, et on la fait défiler en
  // glissant DEPUIS LA PILULE (`deferToChild` : la pilule est un enfant). Le
  // glisser ne va pas à la carte. Un seul cas, volontairement : la bande ne
  // déborde qu'aux largeurs de téléphone, où la pilule la remplit toute ; à
  // 800 de large le contenu (121 px à 200 %) tient dans toute fenêtre où les
  // contrôles du bas, eux, tiennent. Tap, Entrée et Espace sur la pilule sont
  // verrouillés dans `map_designation_test.dart`.
  _surAndroid(
    'EN MODE, à ${_nom(const Size(360, 300), 2, MapScaleKind.ecoulement)} : la '
    'bande déborde et défile quand on glisse depuis la pilule, sans que le '
    'glisser atteigne la carte',
    (WidgetTester tester) async {
      int glissers = 0;
      await _pumpOverlays(
        tester,
        const Size(360, 300),
        textScale: 2,
        scale: MapScaleKind.ecoulement,
        enMode: true,
        avecAvis: false,
        onCarteGlisser: () => glissers++,
      );

      final Rect bande = _rectOf(tester, _bande());
      final Finder controle = find.byType(DesignateCenterControl);
      final Rect avant = _rectOf(tester, controle);
      expect(
        avant.height,
        greaterThan(bande.height),
        reason: 'la bande doit déborder : bande=$bande, contenu=$avant',
      );
      final Rect pilule = _rectOf(
        tester,
        find.byKey(mapDesignateCenterButtonKey),
      );
      expect(
        bande.contains(pilule.center),
        isTrue,
        reason: 'le centre de la pilule doit être dans la bande',
      );

      await tester.dragFrom(pilule.center, const Offset(0, -30));
      await tester.pumpAndSettle();

      final Rect apres = _rectOf(tester, controle);
      expect(
        apres.top,
        lessThan(avant.top),
        reason: 'la bande n’a pas défilé : avant=$avant, après=$apres',
      );
      expect(
        glissers,
        0,
        reason: 'le glisser sur la pilule a atteint la carte',
      );
    },
  );

  // `(taille, part de la puce « Restrictions » atteignable, son centre est
  // atteignable)`, EN MODE, à 200 %. Plus la fenêtre est courte, plus le bouton
  // de désignation (259 px de haut à 200 %, posé en bas) monte vers la puce : à
  // 360 × 572 il la touche tout juste, à 360 × 568 il en recouvre 8 % (la puce
  // finit à 230, le bouton commence à 227), à 360 × 540 il en recouvre 64 % et
  // son centre. À 360 × 330 le mécanisme n'est plus celui-là depuis `F10b`
  // (décision « le haut cède d'abord, jusqu'à une cible tactile ») : à 200 %,
  // sous 362 px de haut (seuil mesuré HORS MODE et SANS AVIS ; ce cas, en
  // mode, n'a pas été remesuré pièce par pièce), la fenêtre du haut ne garde
  // que le contrôle d'avertissement, et la puce est SOUS LE BORD de sa fenêtre —
  // aucune part n'en est atteignable au repos. La puce étant la SEULE sortie
  // du mode, un téléphone aussi court, à 200 %, n'a plus de sortie tactile du
  // mode : à signaler au commanditaire, non corrigé ici.
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` (les chiffres ci-dessus sont
  // ceux de quatre boutons) : la fenêtre du haut perd une cible et un écart, et
  // c'est désormais SON BORD, plus haut que le bouton, qui coupe la puce
  // (180 à 230). À 360 × 568 la fenêtre finit à 206 : 52 % de la puce restent
  // atteignables (92 % avant), son centre (205) de PEU — à 1 px du bord. À
  // 360 × 540 elle finit à 178 : la puce est toute sous le bord, rien n'en est
  // atteignable (36 % avant, centre déjà recouvert).
  for (final (Size, double, bool) cas in <(Size, double, bool)>[
    (const Size(360, 568), 0.52, true),
    (const Size(360, 540), 0.0, false),
    (const Size(360, 330), 0.0, false),
  ]) {
    _surAndroid(
      'CONSTAT — EN MODE, à ${_nom(cas.$1, 2, MapScaleKind.ecoulement)}, AVEC '
      'un avis, « Favoris » posé : la puce « Restrictions » n’est pas toute '
      'atteignable — le bord de la fenêtre de la colonne du haut la coupe '
      '(part atteignable ${cas.$2}, centre '
      '${cas.$3 ? 'atteignable' : 'non atteignable'})',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: MapScaleKind.ecoulement,
          enMode: true,
          onOuvrirFavoris: () {},
        );

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu. Corriger ce test À LA MAIN
        // quand l'écran sera repris.
        expect(
          _surfaceAtteignable(tester, _puceRestrictions()),
          closeTo(cas.$2, 0.005),
          reason:
              'puce=${_rectOf(tester, _puceRestrictions())}, bouton='
              '${_rectOf(tester, find.byType(DesignateCenterControl))}',
        );
        expect(_atteignable(_puceRestrictions()), cas.$3);
      },
    );
  }

  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surAndroid(
        'CONSTAT — EN MODE, à ${_nom(size, 2, scale)}, AVEC un avis : le '
        'bouton de désignation ne recouvre ni le contrôle d’avertissement ni '
        'aucune des trois puces (leurs centres sont atteignables) ; il '
        'recouvre l’avis',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            size,
            textScale: 2,
            scale: scale,
            enMode: true,
          );

          // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (arbitrage du
          // 2026-10-03). Le plan craignait que le bouton recouvre le contrôle
          // d'avertissement et les puces à 360 × 640 : en police de test c'était
          // vrai (le bouton, au libellé plus large, y mesurait 526 px de haut,
          // de 8 à 534), en Roboto non (259 px, de 299 à 558). Corriger ce
          // test À LA MAIN si l'écran change.
          final Rect bouton = _rectOf(
            tester,
            find.byType(DesignateCenterControl),
          );
          final Map<String, Finder> hauts = <String, Finder>{
            'WarningLink': find.byType(WarningLink),
            ..._lesTroisPuces(),
          };
          for (final MapEntry<String, Finder> e in hauts.entries) {
            expect(
              bouton.overlaps(_rectOf(tester, e.value)),
              isFalse,
              reason: '${e.key}=${_rectOf(tester, e.value)}, bouton=$bouton',
            );
            expect(
              _atteignable(e.value),
              isTrue,
              reason: '${e.key} recouvert, bouton=$bouton',
            );
          }
          expect(bouton.overlaps(_rectOf(tester, _avis(scale))), isTrue);
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // EN MODE, carte vide : l'avis recouvre-t-il le réticule ?
  // ---------------------------------------------------------------------
  // `(taille, police, échelle, la partie visible de l'avis recouvre le
  // réticule, le CENTRE du réticule — là où le bouton désigne — est sous
  // l'avis)`. Le réticule est posé sous toutes les autres surcouches : quand
  // l'avis le recouvre, il ne se voit plus là. Rien n'est corrigé ici (arbitré
  // le 2026-10-03 : à 360 × 640 le centre de la carte est dans la colonne du
  // haut).
  //
  // ⚠️ À 360 × 640, 100 %, « débit », l'avis (176 à 313) recouvre le haut du
  // réticule (296 à 344) mais pas son centre (320) : 7 px, de PEU.
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` : à 360 × 640 et 200 %, la
  // fenêtre de la colonne du haut finit à 278, au-dessus du réticule (296 à
  // 344) — la partie visible de l'avis ne le recouvre plus, sur les deux
  // échelles (quatre boutons posés, elle le recouvrait, centre compris). À
  // 100 %, elle finit à 324 : rien ne change.
  for (final (Size, double, MapScaleKind, bool, bool) cas
      in <(Size, double, MapScaleKind, bool, bool)>[
        (_petit, 1, MapScaleKind.ecoulement, true, true),
        (_petit, 1, MapScaleKind.debit, true, false),
        (_petit, 2, MapScaleKind.ecoulement, false, false),
        (_petit, 2, MapScaleKind.debit, false, false),
        (_grand, 1, MapScaleKind.ecoulement, false, false),
        (_grand, 1, MapScaleKind.debit, false, false),
        (_grand, 2, MapScaleKind.ecoulement, true, true),
        (_grand, 2, MapScaleKind.debit, true, true),
        (const Size(800, 740), 1, MapScaleKind.ecoulement, false, false),
        (const Size(800, 740), 1, MapScaleKind.debit, false, false),
        (const Size(800, 740), 2, MapScaleKind.ecoulement, true, true),
        (const Size(800, 740), 2, MapScaleKind.debit, true, true),
        (const Size(800, 700), 1, MapScaleKind.ecoulement, false, false),
        (const Size(800, 700), 1, MapScaleKind.debit, false, false),
        (const Size(800, 700), 2, MapScaleKind.ecoulement, true, true),
        (const Size(800, 700), 2, MapScaleKind.debit, true, true),
      ]) {
    final _Test sur = _selonFenetre(cas.$1);
    sur(
      'CONSTAT — EN MODE, carte vide, à ${_nom(cas.$1, cas.$2, cas.$3)} : '
      'l’avis ${cas.$4 ? 'recouvre' : 'ne recouvre pas'} le réticule'
      '${cas.$4 ? (cas.$5 ? ', centre compris' : ', sans son centre') : ''}',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          textScale: cas.$2,
          scale: cas.$3,
          enMode: true,
          onOuvrirFavoris: () {},
        );

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : le réticule est la
        // surcouche la plus basse de la pile.
        final Rect reticule = _rectOf(tester, find.byKey(mapCenterReticleKey));
        final Rect? visible = _visible(tester, _avis(cas.$3));
        expect(
          visible?.overlaps(reticule) ?? false,
          cas.$4,
          reason: 'avis visible=$visible, réticule=$reticule',
        );
        expect(
          visible?.contains(reticule.center) ?? false,
          cas.$5,
          reason: 'avis visible=$visible, réticule=$reticule',
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Fiche de 320 px ouverte : ce que la fiche recoupe en haut
  // ---------------------------------------------------------------------
  const String lienNom = 'WarningLink';
  const String pucesNom = 'MapScaleChips';
  const String legendeNom = 'MapLegend';
  const String avisNom = 'avis';
  // `(taille, police, échelle, ce que la fiche recoupe parmi les pièces du
  // haut HORS MODE, ce qu'elle recoupe EN MODE)`. En mode la bande du bouton
  // de désignation occupe le bas : la fiche se pose AU-DESSUS et remonte.
  // À 360 × 640, 200 %, en mode, elle remonte jusqu'en haut (8 à 328) et
  // recouvre le contrôle d'avertissement de la carte et les puces ; chaque
  // fiche porte son propre contrôle « ⚠ Avertissement » (`W3c`).
  //
  // Depuis le 2026-10-12 (« La légende défile », `F10b` de T3) : à 200 %,
  // hors mode, la fiche ne recouvre plus que l'AVIS, aux deux tailles et sur
  // les deux échelles. Avant, elle recouvrait aussi la légende ; celle-ci est
  // désormais cachée sous le bord de la fenêtre de la colonne (qui s'arrête
  // au-dessus des boutons du bas), donc plus sous la fiche : elle se lit en
  // faisant défiler la colonne.
  //
  // ⚠️ Pas de cas tenu de peu : le plus proche est 390 × 844, 100 %,
  // « écoulement », hors mode (fiche à 492, légende finissant à 430).
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` : à 360 × 640, 100 %,
  // « écoulement », la fenêtre de la colonne du haut finit à 324, au-dessus de
  // la légende repoussée sous l'avis (qui commence à 340) — la fiche ne
  // recouvre plus que l'avis, hors mode et en mode (quatre boutons posés, la
  // fenêtre finissait à 380 et la fiche recouvrait aussi la légende). Les
  // autres cas ne changent pas.
  for (final (Size, double, MapScaleKind, Set<String>, Set<String>) cas
      in <(Size, double, MapScaleKind, Set<String>, Set<String>)>[
        (
          _petit,
          1,
          MapScaleKind.ecoulement,
          <String>{avisNom},
          <String>{avisNom},
        ),
        (
          _petit,
          1,
          MapScaleKind.debit,
          <String>{avisNom, legendeNom},
          <String>{avisNom, legendeNom},
        ),
        (
          _petit,
          2,
          MapScaleKind.ecoulement,
          <String>{avisNom},
          <String>{lienNom, pucesNom, avisNom},
        ),
        (
          _petit,
          2,
          MapScaleKind.debit,
          <String>{avisNom},
          <String>{lienNom, pucesNom, avisNom},
        ),
        (_grand, 1, MapScaleKind.ecoulement, <String>{}, <String>{legendeNom}),
        (
          _grand,
          1,
          MapScaleKind.debit,
          <String>{legendeNom},
          <String>{legendeNom},
        ),
        (
          _grand,
          2,
          MapScaleKind.ecoulement,
          <String>{avisNom},
          <String>{pucesNom, avisNom},
        ),
        (
          _grand,
          2,
          MapScaleKind.debit,
          <String>{avisNom},
          <String>{pucesNom, avisNom},
        ),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$5 : cas.$4;
      _surAndroid(
        'CONSTAT — fiche de 320 px à ${_nom(cas.$1, cas.$2, cas.$3)}, '
        '${_mode(enMode)} : la fiche '
        '${attendu.isEmpty ? 'ne recouvre aucune pièce du haut' : 'recouvre '
                  '${attendu.join(', ')}'}',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            cas.$1,
            textScale: cas.$2,
            scale: cas.$3,
            enMode: enMode,
            avecFiche: true,
            onOuvrirFavoris: () {},
          );

          // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (arbitrage du
          // 2026-10-03 : à ne pas corriger ici). Si une pièce cesse d'être
          // recouverte, corriger ce test À LA MAIN pour le dire.
          final Rect fiche = _rectOf(tester, find.byKey(_ficheKey));
          final Map<String, Finder> haut = <String, Finder>{
            lienNom: find.byType(WarningLink),
            pucesNom: find.byType(MapScaleChips),
            avisNom: _avis(cas.$3),
            legendeNom: find.byType(MapLegend),
          };
          final Set<String> recouvertes = <String>{
            for (final MapEntry<String, Finder> p in haut.entries)
              if (_visible(tester, p.value)?.overlaps(fiche) ?? false) p.key,
          };
          expect(recouvertes, attendu, reason: 'fiche=$fiche');
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // WINDOWS, 800 × 740 : la première cible du produit
  // ---------------------------------------------------------------------
  // Les mesures à 800 × 740 (la taille minimale de la fenêtre, `K3`), écrites
  // quand les boucles ci-dessus tournaient sous Android, la plateforme par
  // défaut de `flutter test`, pour les rejouer sous Windows. Depuis `N9` de T3
  // les cas de ces boucles qui ne sont pas des tailles de téléphone tournent
  // eux aussi sous Windows : à 800 × 740, ce groupe en répète 21 (rangées de
  // puces, colonne gauche, réticule, bande ; suppression à décider à part),
  // et plus rien ici ne mesure Android à cette taille. Deux choses y changeaient par rapport à Android, pas
  // davantage :
  // - la cible tactile : 44, non 48 (`minimumTapTarget`, `K4`) — d'où la
  //   colonne des contrôles de zoom (44 de large), la marge droite que la
  //   bande réserve (60, non 64) et la hauteur du contrôle d'avertissement et
  //   des puces (44, non 48) ;
  // - l'indice sous le bouton : « ou clic droit sur n'importe quel point de la
  //   carte », plus long que « ou appui long sur n'importe quel point ».
  //
  // ⚠️ Segoe UI, la police de Windows, n'est pas chargée : ces tests mesurent
  // en ROBOTO, substitut (voir [_chargerRoboto]). Les largeurs de texte — la
  // pilule, l'indice, les puces, l'avis — sont celles de Roboto, pas de Segoe
  // UI ; les bornes de la bande, elles, ne dépendent pas de la police.
  group('Windows, 800 × 740 (Roboto pour Segoe UI)', () {
    const Size taille = Size(800, 740);

    testWidgetsOnWindows(
      'la police de remplacement est chargée : « Avertissement » fait '
      'environ 95 px (185 en police de test)',
      (WidgetTester tester) async {
        await _pumpOverlays(tester, taille, scale: MapScaleKind.ecoulement);

        final double largeur = _rectOf(
          tester,
          find.text(warningLinkLabel),
        ).width;
        expect(largeur, inInclusiveRange(90, 100), reason: 'largeur=$largeur');
      },
    );

    testWidgetsOnWindows(
      'CONSTAT — EN MODE, la bande va de 60 à 740 (cible de 44) quand Android '
      '(48) la donne de 64 à 736 ; la pilule va de 234,5 à 565,5',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          taille,
          scale: MapScaleKind.ecoulement,
          enMode: true,
          avecAvis: false,
        );

        expect(minimumTapTarget, 44);
        final Rect bande = _rectOf(tester, _bande());
        final Rect pilule = _rectOf(
          tester,
          find.byKey(mapDesignateCenterButtonKey),
        );
        final Rect indice = _rectOf(
          tester,
          find.byKey(mapDesignateCenterHintKey),
        );
        // La bande ne dépend pas de la police : marge de 8 + colonne des
        // contrôles (44) + marge de 8 de chaque côté.
        expect(bande.left, 60);
        expect(bande.right, 740);
        expect(bande.top, 616);
        expect(bande.bottom, 704);
        // La pilule et l'indice dépendent de la police (Roboto ici).
        expect(pilule.left, closeTo(234.5, 0.1));
        expect(pilule.right, closeTo(565.5, 0.1));
        expect(indice.left, closeTo(238.3, 0.1));
        expect(indice.right, closeTo(561.7, 0.1));
        expect(pilule.left, greaterThan(bande.left));
        expect(pilule.right, lessThan(bande.right));
        expect(indice.bottom, lessThanOrEqualTo(bande.bottom));
      },
    );

    testWidgetsOnWindows(
      'EN MODE : un tap, un glisser et un cran de molette posés dans la bande, '
      'hors de la pilule et de l’indice, atteignent la carte',
      (WidgetTester tester) => _verifierBande(tester, taille),
    );

    // La colonne DROITE (contrôle d'avertissement, légende) est large comme la
    // légende. À l'échelle « débit », à 100 %, la légende (260 de large)
    // dépasse le contrôle (139) : 121 px de la carte, à gauche du contrôle, sont
    // dans la boîte de la colonne mais sur aucun de ses enfants (« écoulement »
    // : 0 px, la légende et le contrôle ont la même largeur). Un geste posé là
    // doit atteindre la carte : ni la `Scrollbar` automatique de Windows ni
    // l'`opaque` par défaut du défilement ne doivent l'absorber.
    group(
      'colonne droite, échelle débit, 100 % : la carte garde ses gestes',
      () {
        Offset pointAGaucheDuLien(WidgetTester tester) {
          final Rect colonne = tester.getRect(
            find
                .ancestor(
                  of: find.byType(WarningLink),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          );
          final Rect lien = _rectOf(tester, find.byType(WarningLink));
          expect(lien.left - colonne.left, closeTo(121, 0.5));
          final Offset p = Offset(
            (colonne.left + lien.left) / 2,
            lien.center.dy,
          );
          expect(colonne.contains(p), isTrue, reason: '$p hors de $colonne');
          expect(lien.contains(p), isFalse, reason: '$p dans le lien');
          return p;
        }

        testWidgetsOnWindows('un tap à gauche du contrôle atteint la carte', (
          WidgetTester tester,
        ) async {
          int taps = 0;
          await _pumpOverlays(
            tester,
            taille,
            scale: MapScaleKind.debit,
            onCarteTap: () => taps++,
          );

          await tester.tapAt(pointAGaucheDuLien(tester));
          await tester.pump();

          expect(taps, 1);
        });

        testWidgetsOnWindows(
          'un cran de molette à gauche du contrôle atteint la carte',
          (WidgetTester tester) async {
            int crans = 0;
            await _pumpOverlays(
              tester,
              taille,
              scale: MapScaleKind.debit,
              onCarteMolette: () => crans++,
            );
            final Offset p = pointAGaucheDuLien(tester);

            final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
            await tester.sendEventToBinding(souris.hover(p));
            await tester.sendEventToBinding(
              souris.scroll(const Offset(0, -100)),
            );
            await tester.pump();

            expect(crans, 1);
          },
        );

        testWidgetsOnWindows(
          'un glisser à gauche du contrôle atteint la carte',
          (WidgetTester tester) async {
            int glissers = 0;
            await _pumpOverlays(
              tester,
              taille,
              scale: MapScaleKind.debit,
              onCarteGlisser: () => glissers++,
            );

            await tester.dragFrom(
              pointAGaucheDuLien(tester),
              const Offset(0, 80),
            );
            await tester.pump();

            expect(glissers, greaterThan(0));
          },
        );
      },
    );

    // Les trois puces : une rangée à 100 %, deux à 200 %.
    for (final (double, int) cas in <(double, int)>[(1, 1), (2, 2)]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool enMode in <bool>[false, true]) {
          testWidgetsOnWindows(
            'à ${_nom(taille, cas.$1, scale)}, ${_mode(enMode)} : les trois '
            'puces prennent ${cas.$2} rangée${cas.$2 > 1 ? 's' : ''}',
            (WidgetTester tester) async {
              await _pumpOverlays(
                tester,
                taille,
                textScale: cas.$1,
                scale: scale,
                enMode: enMode,
              );

              expect(_rangeesDePuces(tester), cas.$2);
            },
          );
        }
      }
    }

    // La disposition large à 200 % : la colonne GAUCHE ne défile pas ; la
    // colonne droite, elle, a de quoi défiler à 200 % sur l'échelle débit.
    // L'action de l'avis est atteignable et l'attribution ne la recoupe pas.
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool enMode in <bool>[false, true]) {
        testWidgetsOnWindows(
          'CONSTAT — disposition LARGE à ${_nom(taille, 2, scale)}, '
          '${_mode(enMode)}, avis affiché : l’action de l’avis est '
          'atteignable, et l’attribution ne la recouvre pas',
          (WidgetTester tester) async {
            await _pumpOverlays(
              tester,
              taille,
              textScale: 2,
              scale: scale,
              enMode: enMode,
            );

            final Rect colonne = _fenetre(tester);
            final Rect avis = _rectOf(tester, _avis(scale));
            expect(avis.bottom, lessThanOrEqualTo(colonne.bottom));
            final Rect action = _rectOf(tester, find.byKey(widenSearchKey));
            final Rect attribution = _rectOf(
              tester,
              find.byType(IgnAttributionBadge),
            );
            expect(_atteignable(find.byKey(widenSearchKey)), isTrue);
            expect(attribution.overlaps(action), isFalse);
          },
        );
      }
    }

    // L'avis recouvre le réticule de désignation EN MODE, carte vide :
    // aucun recouvrement à 100 %, le centre du réticule sous l'avis à 200 %.
    for (final (double, MapScaleKind, bool) cas
        in <(double, MapScaleKind, bool)>[
          (1, MapScaleKind.ecoulement, false),
          (1, MapScaleKind.debit, false),
          (2, MapScaleKind.ecoulement, true),
          (2, MapScaleKind.debit, true),
        ]) {
      testWidgetsOnWindows(
        'CONSTAT — EN MODE, carte vide, à ${_nom(taille, cas.$1, cas.$2)} : '
        'l’avis ${cas.$3 ? 'recouvre, centre compris,' : 'ne recouvre pas'} '
        'le réticule',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            taille,
            textScale: cas.$1,
            scale: cas.$2,
            enMode: true,
          );

          final Rect reticule = _rectOf(
            tester,
            find.byKey(mapCenterReticleKey),
          );
          final Rect? visible = _visible(tester, _avis(cas.$2));
          expect(visible?.overlaps(reticule) ?? false, cas.$3);
          expect(visible?.contains(reticule.center) ?? false, cas.$3);
        },
      );
    }

    // Aucune erreur de rendu, et le bas de l'avis dans la fenêtre de la
    // colonne gauche, à 100 % comme à 200 %.
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool enMode in <bool>[false, true]) {
          testWidgetsOnWindows(
            'disposition LARGE à ${_nom(taille, textScale, scale)}, '
            '${_mode(enMode)}, avis affiché : aucune erreur de rendu, et le '
            'bas de l’avis tient dans la fenêtre de la colonne gauche',
            (WidgetTester tester) => _verifierColonneGauche(
              tester,
              taille,
              textScale: textScale,
              scale: scale,
              enMode: enMode,
            ),
          );
        }
      }
    }
  });

  // ---------------------------------------------------------------------
  // L'avis de carte vidée par le filtre (`F8` de T3)
  // ---------------------------------------------------------------------
  // Écoulement, des observations lues, un filtre qui les masque toutes : la
  // carte écrit « Les filtres masquent tous les lieux… » et propose « Effacer
  // les filtres ». L'action est entière dans l'écran et ne recoupe ni la
  // légende ni les contrôles de zoom — à la taille minimale de Windows et à la
  // taille d'un téléphone.
  for (final (Size, _Test) cas in <(Size, _Test)>[
    (const Size(800, 740), _surWindows),
    (_petit, _surAndroid),
  ]) {
    cas.$2(
      'à ${cas.$1.width.toInt()} × ${cas.$1.height.toInt()}, un filtre qui '
      'masque tout : « Effacer les filtres » est dans l’écran et ne recoupe '
      'ni la légende ni les contrôles de zoom',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          scale: MapScaleKind.ecoulement,
          avecAvis: false,
          filtreVideTout: true,
        );

        expect(find.text(filterHidesEverythingText), findsOneWidget);
        expect(find.byType(NoDataInAreaNotice), findsNothing);

        final Rect action = _rectOf(tester, find.byKey(clearFiltersKey));
        final Rect ecran = Offset.zero & cas.$1;
        expect(
          ecran.contains(action.topLeft) && ecran.contains(action.bottomRight),
          isTrue,
          reason: 'action=$action, écran=$ecran',
        );
        expect(
          action.overlaps(_rectOf(tester, find.byType(MapLegend))),
          isFalse,
          reason: 'action=$action recoupe la légende',
        );
        expect(
          action.overlaps(_rectOf(tester, find.byType(MapControls))),
          isFalse,
          reason: 'action=$action recoupe les contrôles de zoom',
        );
      },
    );
  }

  _surWindows('un tap sur « Effacer les filtres » appelle onEffacer une fois', (
    WidgetTester tester,
  ) async {
    int effacements = 0;
    await _pumpOverlays(
      tester,
      const Size(800, 740),
      scale: MapScaleKind.ecoulement,
      avecAvis: false,
      filtreVideTout: true,
      onEffacer: () => effacements++,
    );

    await tester.tap(find.byKey(clearFiltersKey));
    await tester.pump();

    expect(effacements, 1);
  });

  // ---------------------------------------------------------------------
  // Le groupe des boutons d'entrée (`F10b` de T3, arbitrage 8)
  // ---------------------------------------------------------------------
  // « Filtres » s'ajoute à la colonne du bas à droite, au-dessus des contrôles
  // de zoom. À 360 × 640, à 100 % puis à 200 %, sur les deux échelles, avec et
  // sans fiche, hors mode et en mode, avec et sans avis : le groupe est entier
  // dans l'écran et ne recoupe ni la légende (sa partie visible), ni la fiche,
  // ni le bouton de désignation (sa partie visible), ni l'attribution.
  for (final double textScale in <double>[1, 2]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool avecFiche in <bool>[false, true]) {
        for (final bool enMode in <bool>[false, true]) {
          for (final bool avecAvis in <bool>[false, true]) {
            _surAndroid('${_nom(_petit, textScale, scale)}, ${_mode(enMode)}, '
                '${avecAvis ? 'AVEC' : 'SANS'} avis'
                '${avecFiche ? ', fiche de 320 px ouverte' : ''} : le groupe '
                'des boutons d’entrée est dans l’écran et ne recoupe ni la '
                'partie visible de la légende, ni la fiche, ni la partie '
                'visible du bouton de désignation, ni l’attribution', (
              WidgetTester tester,
            ) async {
              await _pumpOverlays(
                tester,
                _petit,
                textScale: textScale,
                scale: scale,
                enMode: enMode,
                avecFiche: avecFiche,
                avecAvis: avecAvis,
              );

              final Rect ecran = Offset.zero & _petit;
              final Rect groupe = _rectOf(tester, find.byType(MapEntryButtons));
              expect(
                ecran.intersect(groupe),
                groupe,
                reason: 'MapEntryButtons hors de l’écran : $groupe',
              );
              // « Filtres » est juste au-dessus de `+`, à
              // `mapControlsSpacing`.
              expect(
                groupe.bottom + mapControlsSpacing,
                _rectOf(tester, find.byKey(mapZoomInButtonKey)).top,
              );

              final Rect? legende = _visible(tester, find.byType(MapLegend));
              final Rect designation = !enMode
                  ? Rect.zero
                  : _rectOf(
                      tester,
                      find.byType(DesignateCenterControl),
                    ).intersect(_rectOf(tester, _bande()));
              final Map<String, Rect> autres = <String, Rect>{
                'MapLegend (partie visible)': ?legende,
                if (avecFiche) 'fiche': _rectOf(tester, find.byKey(_ficheKey)),
                if (enMode && designation.width > 0 && designation.height > 0)
                  '$_designation (partie visible)': designation,
                _attribution: _rectOf(tester, find.byType(IgnAttributionBadge)),
              };
              final List<String> recoupes = <String>[
                for (final MapEntry<String, Rect> autre in autres.entries)
                  if (groupe.overlaps(autre.value))
                    '${autre.key}=${autre.value}',
              ];
              expect(
                recoupes,
                isEmpty,
                reason: 'MapEntryButtons=$groupe recoupe : $recoupes',
              );
            });
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // « La légende défile » : la colonne du haut s'arrête au-dessus de celle
  // du bas à droite (arbitrage du commanditaire du 2026-10-12, `F10b` de T3)
  // ---------------------------------------------------------------------
  // La fenêtre de la colonne du haut reçoit la hauteur que la colonne du bas à
  // droite lui laisse : elle s'arrête au-dessus du groupe « Filtres », à la
  // marge qu'elle a elle-même au bord de la carte, et suit la hauteur de la
  // fenêtre — aucune hauteur n'est écrite dans ces cas, tout vient des boîtes.

  for (final double hauteur in <double>[560, 640, 700, 844]) {
    _surAndroid(
      'construction — à 360 × ${hauteur.toInt()}, police 100 %, échelle débit, '
      'SANS avis : la fenêtre de la colonne du haut finit au-dessus du groupe '
      '« Filtres », à la marge du bord, tant que la légende ne tient pas ; '
      'jamais plus bas',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          Size(360, hauteur),
          scale: MapScaleKind.debit,
          avecAvis: false,
        );

        final Rect fenetre = _fenetre(tester);
        final Rect groupe = _rectOf(tester, find.byType(MapEntryButtons));
        final Rect legende = _rectOf(tester, find.byType(MapLegend));
        // La marge au bord de la carte, lue sur la fenêtre elle-même.
        final double marge = fenetre.top;
        expect(
          fenetre.bottom,
          lessThanOrEqualTo(groupe.top - marge),
          reason: 'fenêtre=$fenetre, groupe « Filtres »=$groupe',
        );
        if (legende.bottom > fenetre.bottom) {
          // La légende ne tient pas : la fenêtre prend TOUTE la place offerte.
          expect(
            fenetre.bottom,
            groupe.top - marge,
            reason: 'fenêtre=$fenetre, groupe « Filtres »=$groupe',
          );
        }
        // Le groupe, lui, ne dépend pas de la colonne du haut : il est juste
        // au-dessus de `+`, comme toujours.
        expect(
          groupe.bottom + mapControlsSpacing,
          _rectOf(tester, find.byKey(mapZoomInButtonKey)).top,
        );
      },
    );
  }

  _surAndroid('construction — la légende « débit » tient à 360 × 844 et ne '
      'tient plus à 360 × 560 : la même colonne, la fenêtre seule a changé', (
    WidgetTester tester,
  ) async {
    await _pumpOverlays(
      tester,
      const Size(360, 844),
      scale: MapScaleKind.debit,
      avecAvis: false,
    );
    expect(_etat(tester, find.byType(MapLegend)), 'entière');
    final double hautGroupeGrand = _rectOf(
      tester,
      find.byType(MapEntryButtons),
    ).top;
    final double basFenetreGrand = _fenetre(tester).bottom;

    await _pumpOverlays(
      tester,
      const Size(360, 560),
      scale: MapScaleKind.debit,
      avecAvis: false,
    );
    expect(_etat(tester, find.byType(MapLegend)), 'en partie');
    final double hautGroupePetit = _rectOf(
      tester,
      find.byType(MapEntryButtons),
    ).top;
    // Le groupe est monté d'autant que la fenêtre a raccourci (844 − 560), et
    // la fenêtre de la colonne du haut l'a suivi.
    expect(hautGroupeGrand - hautGroupePetit, 844 - 560);
    expect(_fenetre(tester).bottom, lessThan(basFenetreGrand));
    expect(_fenetre(tester).bottom, hautGroupePetit - _fenetre(tester).top);
  });

  // Décision de la boucle principale du 2026-10-12 : sur une fenêtre trop
  // courte, c'est la colonne du BAS qui cède — elle défile, ancrée en bas —,
  // et le contrôle « ⚠ Avertissement » reste visible (`BR-012`).
  for (final bool enMode in <bool>[false, true]) {
    // Le titre dit ce que le cas prouve, mode par mode : HORS MODE le contrôle
    // est atteignable ; EN MODE il ne l'est PAS (CONSTAT, voir plus bas).
    final String atteinte = enMode
        ? 'mais — CONSTAT — la pilule du bouton de désignation recouvre son '
              'centre : il n’est PAS atteignable'
        : 'et il est atteignable';
    _surAndroid('${_nom(const Size(360, 300), 2, MapScaleKind.ecoulement)}, '
        '${_mode(enMode)} : aucune erreur de rendu, le contrôle '
        '« ⚠ Avertissement » est entier dans l’écran et dans sa fenêtre, '
        '$atteinte ; l’attribution est entière au repos, et « Filtres » s’atteint en '
        'faisant défiler la colonne du bas', (WidgetTester tester) async {
      const Size taille = Size(360, 300);
      // `_pumpOverlays` affirme l'absence de toute erreur de rendu.
      await _pumpOverlays(
        tester,
        taille,
        textScale: 2,
        scale: MapScaleKind.ecoulement,
        enMode: enMode,
        avecAvis: false,
      );

      final Rect ecran = Offset.zero & taille;
      final Rect lien = _rectOf(tester, find.byType(WarningLink));
      expect(ecran.intersect(lien), lien, reason: 'lien=$lien');
      expect(
        _fenetre(tester).intersect(lien),
        lien,
        reason: 'lien=$lien, fenêtre du haut=${_fenetre(tester)}',
      );
      // HORS MODE le contrôle est atteignable. EN MODE, CONSTAT antérieur,
      // non corrigé ici : sur une fenêtre aussi courte la pilule du bouton de
      // désignation (bande du bas, posée au-dessus de la colonne du haut dans
      // la pile) remonte jusqu'en haut et recouvre son centre — le même
      // défaut que pour la puce « Restrictions » (voir plus haut,
      // « un téléphone aussi court »). La mise en page, elle, lui garde toute
      // sa place : c'est ce que les deux affirmations ci-dessus tiennent.
      expect(_atteignable(find.byKey(warningLinkKey)), !enMode);
      if (enMode) {
        expect(
          _rectOf(
            tester,
            find.byKey(mapDesignateCenterButtonKey),
          ).contains(lien.center),
          isTrue,
          reason: 'ce qui recouvre le contrôle doit être la pilule',
        );
      }

      // La colonne du bas est ancrée en bas : l'attribution, dernière
      // pièce, est entière dans sa fenêtre ; « Filtres », première pièce,
      // dépasse par le haut.
      final Rect bas = _fenetreDuBas(tester);
      final Rect attribution = _rectOf(
        tester,
        find.byType(IgnAttributionBadge),
      );
      expect(bas.intersect(attribution), attribution);
      expect(ecran.intersect(attribution), attribution);
      final Finder filtres = find.byKey(mapFiltersButtonKey);
      expect(
        _rectOf(tester, filtres).top,
        lessThan(bas.top),
        reason: 'filtres=${_rectOf(tester, filtres)}, fenêtre du bas=$bas',
      );
      // Les deux fenêtres ne se recoupent pas.
      expect(bas.overlaps(_fenetre(tester)), isFalse);

      // Du doigt, depuis un bouton de zoom (`deferToChild`), vers le bas :
      // la colonne défile et « Filtres » entre dans sa fenêtre.
      final Finder recentrer = find.byKey(mapRecenterButtonKey);
      await tester.dragFrom(
        _rectOf(tester, recentrer).center.dy < bas.top
            ? bas.center
            : _rectOf(tester, recentrer).intersect(bas).center,
        Offset(0, bas.top - _rectOf(tester, filtres).top + kDragSlopDefault),
      );
      await tester.pumpAndSettle();

      expect(
        bas.intersect(_rectOf(tester, filtres)),
        _rectOf(tester, filtres),
        reason: 'filtres=${_rectOf(tester, filtres)}, fenêtre du bas=$bas',
      );
      expect(_atteignable(filtres), isTrue);
    });
  }

  // CONSTAT — l'effet de cette décision sur une fenêtre COMPACTE COURTE
  // (360 × 300 : un téléphone en écran divisé). Des faits mesurés en Roboto le
  // 2026-10-13, PAS des invariants voulus : la colonne du bas à droite (244 px
  // à 100 %, 290 px à 200 %) ne laisse à celle du haut que la hauteur d'une
  // cible tactile. Sa fenêtre va de 8 à 56 et ne montre que le contrôle
  // « ⚠ Avertissement » : les puces d'échelle, l'avis et la légende sont SOUS
  // son bord au repos — une régression de `BR-007` (un avis qu'on ne voit pas)
  // et de `BR-008` (une légende qu'on ne voit pas) à cette taille, acceptée
  // par la décision, à dire au commanditaire et à constater en écran divisé à
  // la porte Android. Avant `F10b`, la colonne du haut prenait toute la
  // hauteur (de 8 à 292) et passait SOUS les contrôles de zoom : les puces y
  // étaient entières au repos à 100 % (de 64 à 168), l'avis en partie.
  //
  // Ce qui reste possible, HORS MODE : faire défiler la colonne du haut du
  // doigt DEPUIS LE CONTRÔLE (seul enfant visible, `deferToChild`) amène une
  // puce sous le doigt, dans une fenêtre de 48 px.
  for (final double textScale in <double>[1, 2]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool avecAvis in <bool>[false, true]) {
        for (final bool enMode in <bool>[false, true]) {
          final String suite = enMode
              ? ''
              : ' ; la puce « débit » s’atteint en faisant défiler la colonne '
                    'depuis le contrôle';
          _surAndroid('CONSTAT — à '
              '${_nom(const Size(360, 300), textScale, scale)}, '
              '${_mode(enMode)}, ${avecAvis ? 'AVEC un' : 'SANS'} avis : la '
              'fenêtre de la colonne du haut n’a que la hauteur du contrôle '
              '« ⚠ Avertissement » (de 8 à 56) ; puces'
              '${avecAvis ? ', avis' : ''} et légende sont SOUS son bord au '
              'repos$suite', (WidgetTester tester) async {
            await _pumpOverlays(
              tester,
              const Size(360, 300),
              textScale: textScale,
              scale: scale,
              enMode: enMode,
              avecAvis: avecAvis,
            );

            final Rect fenetre = _fenetre(tester);
            final Rect lien = _rectOf(tester, find.byType(WarningLink));
            expect(fenetre.top, 8);
            expect(fenetre.bottom, 56);
            expect(fenetre.height, minimumTapTarget);
            expect(lien.top, fenetre.top);
            expect(lien.bottom, fenetre.bottom);
            expect(_etat(tester, find.byType(MapScaleChips)), 'cachée');
            if (avecAvis) {
              expect(_etat(tester, _avis(scale)), 'cachée');
            }
            expect(_etat(tester, find.byType(MapLegend)), 'cachée');
            // Les deux fenêtres du bord droit ne se recoupent pas, et
            // l'attribution est entière dans l'écran.
            final Rect bas = _fenetreDuBas(tester);
            expect(bas.top, fenetre.bottom + 8);
            expect(bas.bottom, 292);
            final Rect attribution = _rectOf(
              tester,
              find.byType(IgnAttributionBadge),
            );
            expect(bas.intersect(attribution), attribution);

            if (enMode) {
              return;
            }
            // Du doigt, depuis le contrôle : la puce « débit » vient sous le
            // doigt, son centre dans la fenêtre.
            final Finder puce = _puceEchelle(MapScaleKind.debit);
            expect(_atteignable(puce), isFalse);
            await tester.dragFrom(
              lien.center,
              Offset(
                0,
                -(_rectOf(tester, puce).center.dy -
                    fenetre.center.dy +
                    kDragSlopDefault),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              fenetre.contains(_rectOf(tester, puce).center),
              isTrue,
              reason: 'puce=${_rectOf(tester, puce)}, fenêtre=$fenetre',
            );
            expect(_atteignable(puce), isTrue);
          });
        }
      }
    }
  }

  // CONSTAT — les hauteurs où la décision cesse de jouer, à 360 de large,
  // SANS avis, HORS MODE, mesurées en Roboto par pas de 2 px le 2026-10-13 :
  // `(police, la colonne du bas défile encore à, ne défile plus à, les puces
  // ne sont pas entières au repos à, le sont à)`. Entre les deux seuils la
  // colonne du bas tient entière et la colonne du haut reçoit ce qui reste :
  // les puces n'y sont qu'en partie visibles au repos. La légende, elle, ne
  // tient entière qu'à partir de 602 px (« écoulement ») et 684 px (« débit »)
  // à 100 %, de 828 px (« écoulement ») à 200 %.
  //
  // Remesuré par `K3` de T3 (2026-10-14) avec « Favoris » posé, la colonne du
  // bas à cinq boutons comme dans `main.dart` (les chiffres ci-dessus sont
  // ceux de quatre boutons) : chaque seuil monte de 56 px, une cible et un
  // écart — la colonne du bas ne défile plus à partir de 372 px (418 à 200 %),
  // les puces sont entières au repos à partir de 484 px (592 à 200 %) ; la
  // légende entière à partir de 658 px (« écoulement ») et 740 px (« débit »)
  // à 100 %, 884 px (« écoulement ») à 200 % (mesuré, non verrouillé).
  for (final (double, double, double, double, double) cas
      in <(double, double, double, double, double)>[
        (1, 370, 372, 482, 484),
        (2, 416, 418, 590, 592),
      ]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surAndroid('CONSTAT — à 360 de large, police '
          '${(cas.$1 * 100).toInt()} %, échelle ${scale.name}, HORS MODE, SANS '
          'avis : la colonne du bas à droite défile à ${cas.$2.toInt()} px de '
          'haut et plus à ${cas.$3.toInt()} ; les puces sont entières au repos '
          'à ${cas.$5.toInt()} px de haut, pas à ${cas.$4.toInt()}', (
        WidgetTester tester,
      ) async {
        Future<void> poser(double hauteur) => _pumpOverlays(
          tester,
          Size(360, hauteur),
          textScale: cas.$1,
          scale: scale,
          avecAvis: false,
          onOuvrirFavoris: () {},
        );
        bool leBasDefile() =>
            _rectOf(tester, find.byType(MapEntryButtons)).top <
            _fenetreDuBas(tester).top;

        await poser(cas.$2);
        expect(leBasDefile(), isTrue);
        await poser(cas.$3);
        expect(leBasDefile(), isFalse);
        await poser(cas.$4);
        expect(_etat(tester, find.byType(MapScaleChips)), 'en partie');
        await poser(cas.$5);
        expect(_etat(tester, find.byType(MapScaleChips)), 'entière');
      });
    }
  }

  // Sous Windows, là où la fenêtre est courte pour la légende : 800 × 740,
  // 200 %, échelle débit. La légende dépasse sa fenêtre ; un cran de molette
  // posé sur elle fait défiler la colonne droite (pas de barre : voir
  // `_WithoutScrollbar`), et son bord bas arrive au-dessus du groupe.
  _surWindows('à ${_nom(const Size(800, 740), 2, MapScaleKind.debit)} : la '
      'molette posée sur la légende en amène le bord bas dans la fenêtre, '
      'au-dessus du groupe « Filtres » ; sa partie visible ne recoupe aucune '
      'pièce du bas à droite', (WidgetTester tester) async {
    await _pumpOverlays(
      tester,
      const Size(800, 740),
      textScale: 2,
      scale: MapScaleKind.debit,
      avecAvis: false,
    );

    Rect legende() => _rectOf(tester, find.byType(MapLegend));
    final Rect fenetre = tester.getRect(
      find.ancestor(
        of: find.byType(MapLegend),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final Rect groupe = _rectOf(tester, find.byType(MapEntryButtons));
    final double distance = legende().bottom - fenetre.bottom;
    expect(
      distance,
      greaterThan(0),
      reason: 'rien à défiler : fenêtre=$fenetre, légende=${legende()}',
    );
    expect(fenetre.bottom, groupe.top - fenetre.top);
    for (final Finder piece in <Finder>[
      find.byType(MapEntryButtons),
      find.byType(MapControls),
      find.byType(IgnAttributionBadge),
    ]) {
      expect(
        legende().intersect(fenetre).overlaps(_rectOf(tester, piece)),
        isFalse,
        reason: 'légende visible=${legende().intersect(fenetre)}',
      );
    }

    final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      souris.hover(legende().intersect(fenetre).center),
    );
    await tester.sendEventToBinding(souris.scroll(Offset(0, distance)));
    await tester.pumpAndSettle();

    expect(
      legende().bottom,
      lessThanOrEqualTo(fenetre.bottom + 0.5),
      reason: 'après la molette : fenêtre=$fenetre, légende=${legende()}',
    );
    expect(legende().bottom, lessThan(groupe.top));
  });

  // ---------------------------------------------------------------------
  // `F10c` de T3 — la place du cinquième bouton (« Favoris »)
  // ---------------------------------------------------------------------
  // Mesure anticipée, en Roboto, avec un point sur la carte (aucun avis),
  // EN MODE Restrictions (le bouton de désignation existe), police à 100 %.
  // Le lot 7 posera « Favoris » au-dessus de « Filtres » : le rectangle du
  // groupe, étendu d'un bouton et d'un espacement, est mis en regard de la
  // légende (boîte entière), du bouton de désignation, de l'attribution et de
  // la fiche de 320 px.
  //
  // Arbitrage du commanditaire du 2026-10-14 : « Favoris » reste AU-DESSUS de
  // « Filtres » (arbitrage 8, inchangé). À 800 × 740 (Windows, Roboto pour
  // Segoe UI) la légende tient : INVARIANT. Au téléphone (360 × 640, 640 × 360)
  // elle défilera un peu plus, effet de « La légende défile » : rien n'est
  // recouvert, ce sont des CONSTATS, à vérifier à l'écran à la porte Android.
  // `S10` (rendu réel à cinq boutons) et `K3` remesureront avec le vrai
  // bouton.
  // Morsure mesurée (px) et ce dont la légende dépasse déjà sa fenêtre au repos,
  // par échelle, à 360 × 640 (Roboto, 2026-10-14).
  const Map<MapScaleKind, double> morsure360 = <MapScaleKind, double>{
    MapScaleKind.ecoulement: 9,
    MapScaleKind.debit: 91,
  };
  const Map<MapScaleKind, double> auRepos360 = <MapScaleKind, double>{
    MapScaleKind.ecoulement: 0,
    MapScaleKind.debit: 43,
  };
  for (final bool avecFiche in <bool>[false, true]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (Roboto, mesuré le
      // 2026-10-14) : avec le cinquième bouton la légende aurait à défiler de
      // `morsure360` (au lieu de `auRepos360` aujourd'hui). À corriger À LA MAIN
      // quand l'écran change.
      _surAndroid('CONSTAT — F10c : à ${_nom(_petit, 1, scale)}, EN MODE, '
          '${avecFiche ? "AVEC" : "SANS"} fiche : le groupe étendu mord de '
          '${morsure360[scale]!.toInt()} px sur la boîte de '
          'la légende, sans toucher le reste', (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          _petit,
          scale: scale,
          enMode: true,
          avecAvis: false,
          avecFiche: avecFiche,
        );
        final _PlaceDuCinquieme place = _PlaceDuCinquieme(
          tester,
          _petit,
          avecFiche ? _ficheKey : null,
        );
        // L'invariant : dans l'écran, ni désignation, ni attribution, ni
        // fiche.
        place.exigerHorsLegende();
        // Le constat : la morsure sur la boîte de la légende.
        expect(
          place.morsure,
          moreOrLessEquals(morsure360[scale]!, epsilon: 0.1),
          reason: 'morsure sur la boîte de la légende : ${place.mesure}',
        );
        // Ce dont la légende dépasse déjà sa fenêtre, sans le cinquième bouton.
        expect(
          place.legende.bottom - place.fenetre.bottom,
          moreOrLessEquals(auRepos360[scale]!, epsilon: 0.1),
          reason: 'dépassement au repos : ${place.mesure}',
        );
      });
    }
  }

  // Sous Windows à 800 × 740, Roboto en substitut de Segoe UI (non mesurée).
  for (final bool avecFiche in <bool>[false, true]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surWindows('F10c : à ${_nom(const Size(800, 740), 1, scale)} (Roboto '
          'pour Segoe UI), EN MODE, ${avecFiche ? "AVEC" : "SANS"} fiche : '
          'le groupe des boutons d’entrée étendu d’un bouton ne coupe rien', (
        WidgetTester tester,
      ) async {
        const Size taille = Size(800, 740);
        await _pumpOverlays(
          tester,
          taille,
          scale: scale,
          enMode: true,
          avecAvis: false,
          avecFiche: avecFiche,
        );
        _PlaceDuCinquieme(
          tester,
          taille,
          avecFiche ? _ficheKey : null,
        ).exiger();
      });
    }
  }

  // 640 × 360 (téléphone en paysage, disposition large) : MESURÉ, pas exigé.
  for (final MapScaleKind scale in MapScaleKind.values) {
    _surAndroid(
      'CONSTAT — F10c : à ${_nom(const Size(640, 360), 1, scale)}, EN MODE : '
      'le groupe étendu mord de 92 px sur la boîte de la légende, sans '
      'toucher le reste',
      (WidgetTester tester) async {
        const Size taille = Size(640, 360);
        await _pumpOverlays(
          tester,
          taille,
          scale: scale,
          enMode: true,
          avecAvis: false,
        );
        final _PlaceDuCinquieme place = _PlaceDuCinquieme(tester, taille, null);
        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (Roboto, Android, mesuré le
        // 2026-10-14) : le groupe étendu mord sur la boîte de la légende des
        // deux échelles ; elle aurait à défiler de ce que dit `morsure`.
        expect(
          place.groupe,
          rectMoreOrLessEquals(
            const Rect.fromLTRB(584, 108, 632, 156),
            epsilon: 0.1,
          ),
          reason: place.mesure,
        );
        // Le haut de l'étendu se déduit des constantes, il n'est pas recopié.
        expect(
          place.etendu,
          rectMoreOrLessEquals(
            Rect.fromLTRB(
              584,
              108 - (minimumTapTarget + mapControlsSpacing),
              632,
              156,
            ),
            epsilon: 0.1,
          ),
          reason: place.mesure,
        );
        // La fenêtre de la légende : 8 à 100.
        expect(place.fenetre.top, moreOrLessEquals(8, epsilon: 0.1));
        expect(place.fenetre.bottom, moreOrLessEquals(100, epsilon: 0.1));
        place.exigerHorsLegende();
        expect(place.morsure, moreOrLessEquals(92, epsilon: 0.1));
      },
    );
  }

  // ---------------------------------------------------------------------
  // `K3` de T3 — la colonne à cinq boutons, là où `F10c` et `S10` ne l'ont
  // pas mesurée
  // ---------------------------------------------------------------------
  // « Favoris » est posé (`onOuvrirFavoris`), comme la racine de composition
  // le fait depuis `S11` : la colonne du bas à droite compte cinq boutons
  // ([_ColonneACinq]). ROBOTO ; sous Windows, Roboto enregistrée sous le nom
  // « Segoe UI », un SUBSTITUT — Segoe UI réelle n'est pas mesurée.
  //
  // La règle de la colonne, la même dans `F10c`, `S10` et `K3` : un
  // recouvrement de la colonne avec la partie visible de la légende, l'avis,
  // la fiche, le bouton de désignation ou l'attribution, à 800 × 740 sous
  // Windows ou à 360 × 640 sous Android, ARRÊTE la tâche ; à toute autre
  // taille c'est un « CONSTAT », écrit ici et remonté au commanditaire.
  //
  // Déjà mesuré, cité, non refait : la place anticipée du cinquième bouton
  // (`F10c`, section ci-dessus et `map_view_test.dart`) ; le rendu réel à
  // cinq boutons, MapView entière, EN MODE, sans avis, à 800 × 740, 360 × 640
  // et 640 × 360 (`S10`, `map_entry_buttons_overlap_test.dart`).

  // La hauteur réelle de la colonne, au téléphone (sous Windows :
  // `map_view_test.dart`, groupe « K3 de T3 »).
  _surAndroid('K3 : à ${_nom(_petit, 1, MapScaleKind.ecoulement)}, EN MODE, '
      '« Favoris » posé : du haut de « Favoris » au bas de recentrer, la '
      'colonne mesure 5 × minimumTapTarget + 4 × mapControlsSpacing', (
    WidgetTester tester,
  ) async {
    await _pumpOverlays(
      tester,
      _petit,
      scale: MapScaleKind.ecoulement,
      enMode: true,
      avecAvis: false,
      onOuvrirFavoris: () {},
    );

    final double haut = _rectOf(tester, find.byKey(mapFavoritesButtonKey)).top;
    final double bas = _rectOf(tester, find.byKey(mapRecenterButtonKey)).bottom;
    expect(
      bas - haut,
      moreOrLessEquals(_ColonneACinq.hauteurAttendue, epsilon: 0.5),
      reason: 'Favoris en haut à $haut, recentrer en bas à $bas',
    );
  });

  // 390 × 844 (le second téléphone de ce fichier), fiche de 320 px ouverte.
  for (final double textScale in <double>[1, 2]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool enMode in <bool>[false, true]) {
        _surAndroid('K3 : à ${_nom(_grand, textScale, scale)}, '
            '${_mode(enMode)}, fiche de 320 px ouverte, « Favoris » posé : la '
            'colonne à cinq boutons est dans l’écran, garde sa hauteur et ne '
            'recoupe ni la fiche, ni le bouton de désignation, ni '
            'l’attribution, ni la partie visible de la légende', (
          WidgetTester tester,
        ) async {
          await _pumpOverlays(
            tester,
            _grand,
            textScale: textScale,
            scale: scale,
            enMode: enMode,
            avecAvis: false,
            avecFiche: true,
            onOuvrirFavoris: () {},
          );
          final _ColonneACinq c = _ColonneACinq(
            tester,
            _grand,
            ficheKey: _ficheKey,
          );
          printOnFailure(c.mesure);
          expect(c.designationPresente, enMode, reason: c.mesure);
          c.exiger();
        });
      }
    }
  }

  // Les tailles intermédiaires de bureau (celles de la section « Disposition
  // LARGE » et de `map_view_test.dart`), EN MODE, fiche de 320 px ouverte.
  for (final Size taille in <Size>[
    const Size(800, 700),
    const Size(800, 640),
    const Size(700, 740),
    const Size(900, 640),
  ]) {
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        _surWindows('K3 : à ${_nom(taille, textScale, scale)} (Roboto pour '
            'Segoe UI), EN MODE, fiche de 320 px ouverte, « Favoris » posé : '
            'la colonne à cinq boutons est dans l’écran, garde sa hauteur et '
            'ne recoupe ni la fiche, ni le bouton de désignation, ni '
            'l’attribution, ni la partie visible de la légende', (
          WidgetTester tester,
        ) async {
          await _pumpOverlays(
            tester,
            taille,
            textScale: textScale,
            scale: scale,
            enMode: true,
            avecAvis: false,
            avecFiche: true,
            onOuvrirFavoris: () {},
          );
          final _ColonneACinq c = _ColonneACinq(
            tester,
            taille,
            ficheKey: _ficheKey,
          );
          printOnFailure(c.mesure);
          expect(c.designationPresente, isTrue, reason: c.mesure);
          c.exiger();
        });
      }
    }
  }

  // 800 × 740, 200 %, sous Windows — taille d'arrêt. La colonne garde sa
  // hauteur (des icônes, pas du texte) ; l'avis de carte vidée par le filtre
  // et « Effacer les filtres » sont entiers, dans l'écran, dans la fenêtre de
  // leur colonne (ils se voient sans défiler : constat d du cadrage de T3,
  // § 9) et hors de la colonne.
  for (final MapScaleKind scale in MapScaleKind.values) {
    for (final bool enMode in <bool>[false, true]) {
      _surWindows('K3 : à ${_nom(const Size(800, 740), 2, scale)} (Roboto pour '
          'Segoe UI), ${_mode(enMode)}, un filtre masque tous les lieux, '
          '« Favoris » posé : la colonne garde sa hauteur ; l’avis et « Effacer '
          'les filtres » sont entiers, dans l’écran et dans leur fenêtre, hors '
          'de la colonne', (WidgetTester tester) async {
        const Size taille = Size(800, 740);
        await _pumpOverlays(
          tester,
          taille,
          textScale: 2,
          scale: scale,
          enMode: enMode,
          avecAvis: false,
          filtreVideTout: true,
          onOuvrirFavoris: () {},
        );
        final Finder avis = find.byType(FilterHidesEverythingNotice);
        final _ColonneACinq c = _ColonneACinq(tester, taille, avis: avis);
        printOnFailure(c.mesure);
        c.exiger();

        final Rect ecran = Offset.zero & taille;
        for (final (String, Finder) piece in <(String, Finder)>[
          ('FilterHidesEverythingNotice', avis),
          ('« Effacer les filtres »', find.byKey(clearFiltersKey)),
        ]) {
          final Rect boite = _rectOf(tester, piece.$2);
          final Rect fenetre = _rectOf(
            tester,
            find
                .ancestor(
                  of: piece.$2,
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          );
          expect(
            ecran.intersect(boite),
            boite,
            reason: '${piece.$1}=$boite hors de l’écran',
          );
          expect(
            fenetre.intersect(boite),
            boite,
            reason: '${piece.$1}=$boite coupé par sa fenêtre $fenetre',
          );
          expect(
            _recoupe(c.colonne, boite),
            isFalse,
            reason: '${piece.$1}=$boite recoupe la colonne : ${c.mesure}',
          );
        }
      });
    }
  }

  // 390 × 844, 100 %, AVEC un avis d'absence, « Favoris » posé : ce que `I1`
  // (plus haut, quatre boutons) affirme, mesuré sur la colonne que rend
  // `main.dart`.
  for (final MapScaleKind scale in MapScaleKind.values) {
    for (final bool enMode in <bool>[false, true]) {
      _surAndroid('K3 : à ${_nom(_grand, 1, scale)}, ${_mode(enMode)}, AVEC '
          'un avis, « Favoris » posé : l’avis est entier dans l’écran et dans '
          'sa fenêtre, libre de toute surcouche du bas, son action « Élargir la '
          'recherche » est atteignable ; la colonne à cinq boutons ne recoupe '
          'rien', (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          _grand,
          scale: scale,
          enMode: enMode,
          onOuvrirFavoris: () {},
        );
        final Finder avis = _avis(scale);
        final _ColonneACinq c = _ColonneACinq(tester, _grand, avis: avis);
        printOnFailure(c.mesure);
        c.exiger();

        final Rect lAvis = _rectOf(tester, avis);
        final Rect fenetre = _fenetre(tester);
        final Rect ecran = Offset.zero & _grand;
        expect(ecran.intersect(lAvis), lAvis, reason: 'hors écran : $lAvis');
        expect(
          fenetre.intersect(lAvis),
          lAvis,
          reason: 'coupé par la fenêtre de la colonne : $lAvis, $fenetre',
        );
        expect(
          _recoupements(tester, avis, _bas()),
          isEmpty,
          reason: 'avis=$lAvis',
        );
        expect(
          _atteignable(find.byKey(widenSearchKey)),
          isTrue,
          reason: 'action=${_rectOf(tester, find.byKey(widenSearchKey))}',
        );
      });
    }
  }

  // 600 × 360 (téléphone couché, disposition large), « Favoris » posé, EN
  // MODE, sans avis : la même mesure que `S10` à 640 × 360
  // (`map_entry_buttons_overlap_test.dart`), que le brief de `K3` lui
  // prêtait aussi à 600 × 360 et qu'il n'a pas faite.
  //
  // ⚠️ FAITS CONSTATÉS (Roboto, Android, mesurés le 2026-10-14), pas des
  // invariants voulus — les mêmes qu'à 640 × 360 : la colonne du bas (cinq
  // boutons puis l'attribution, 300 px) est plus haute que sa fenêtre (64 à
  // 352, 288 px), « Favoris » en dépasse de 12 px par le haut et s'atteint en
  // la faisant défiler ; la fenêtre de la légende va de 8 à 56, la boîte de la
  // légende commence à 64 : rien n'en paraît au repos. Rien n'est recoupé.
  const Map<MapScaleKind, double> legendeADefiler600 = <MapScaleKind, double>{
    MapScaleKind.ecoulement: 173,
    MapScaleKind.debit: 255,
  };
  for (final MapScaleKind scale in MapScaleKind.values) {
    _surAndroid('CONSTAT — K3 : à ${_nom(const Size(600, 360), 1, scale)}, '
        'EN MODE, « Favoris » posé : « Favoris » dépasse de 12 px par le haut '
        'de la fenêtre de la colonne du bas ; la fenêtre de la légende va de '
        '8 à 56 et la légende a à défiler de '
        '${legendeADefiler600[scale]!.toInt()} px au repos ; la colonne ne '
        'recoupe rien ; « Favoris » s’atteint en faisant défiler la fenêtre '
        'de la colonne du bas', (WidgetTester tester) async {
      const Size taille = Size(600, 360);
      int ouvertures = 0;
      await _pumpOverlays(
        tester,
        taille,
        scale: scale,
        enMode: true,
        avecAvis: false,
        onOuvrirFavoris: () => ouvertures++,
      );
      final _ColonneACinq c = _ColonneACinq(tester, taille);
      printOnFailure(c.mesure);
      final Rect legende = _rectOf(tester, find.byType(MapLegend));
      final Rect fenetreLegende = _rectOf(
        tester,
        find.ancestor(
          of: find.byType(MapLegend),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final String detail =
          'légende=$legende, fenêtre de la légende=$fenetreLegende, '
          '${c.mesure}';
      expect(
        c.colonne.height,
        moreOrLessEquals(_ColonneACinq.hauteurAttendue, epsilon: 0.5),
        reason: detail,
      );
      expect(c.recoupes, isEmpty, reason: detail);
      expect(
        c.fenetreBas.top - c.colonne.top,
        moreOrLessEquals(12, epsilon: 0.1),
        reason: detail,
      );
      expect(
        fenetreLegende.top,
        moreOrLessEquals(8, epsilon: 0.1),
        reason: detail,
      );
      expect(
        fenetreLegende.bottom,
        moreOrLessEquals(56, epsilon: 0.1),
        reason: detail,
      );
      expect(
        math.max(0, legende.bottom - fenetreLegende.bottom),
        moreOrLessEquals(legendeADefiler600[scale]!, epsilon: 0.1),
        reason: detail,
      );

      // Revue finale de T3 (M9c) : ce que le CHANGELOG de 0.4.0 écrit,
      // « Favoris » s'atteint en faisant défiler. La fenêtre de la colonne du
      // bas défile (elle est ancrée en bas) ; « Favoris » y est alors entier,
      // rien ne le recouvre, et un tap l'active.
      final Finder favoris = find.byKey(mapFavoritesButtonKey);
      await tester.ensureVisible(favoris);
      await tester.pumpAndSettle();
      final Rect fenetreBas = _fenetreDuBas(tester);
      final Rect favorisDefile = _rectOf(tester, favoris);
      final String apres =
          'après défilement : Favoris=$favorisDefile, fenêtre du bas='
          '$fenetreBas';
      expect(
        favorisDefile.top,
        greaterThanOrEqualTo(fenetreBas.top - 0.1),
        reason: apres,
      );
      expect(
        favorisDefile.bottom,
        lessThanOrEqualTo(fenetreBas.bottom + 0.1),
        reason: apres,
      );
      expect(
        favorisDefile.left,
        greaterThanOrEqualTo(fenetreBas.left - 0.1),
        reason: apres,
      );
      expect(
        favorisDefile.right,
        lessThanOrEqualTo(fenetreBas.right + 0.1),
        reason: apres,
      );
      expect(_atteignable(favoris), isTrue, reason: apres);
      await tester.tap(favoris);
      await tester.pumpAndSettle();
      expect(ouvertures, 1, reason: apres);
    });
  }

  // À 360 × 640, AVEC un avis — ce que `S10` (sans avis) n'a pas mesuré :
  // l'avis d'absence ou l'avis de carte vidée par le filtre, à 100 % et à
  // 200 %, hors mode et en mode. INVARIANT (taille d'arrêt) : la colonne ne
  // recoupe la partie visible d'aucune pièce. CONSTAT : ce que l'avis a à
  // défiler au repos, et si son action s'atteint sans défiler. La fenêtre de
  // la colonne du haut s'arrête au-dessus de « Favoris » (arbitrage « La
  // légende défile ») : elle a perdu, avec lui, une cible et un écart.
  //
  // ⚠️ FAITS CONSTATÉS (Roboto, Android, mesurés le 2026-10-14), pas des
  // invariants voulus. `(police, échelle, avis de filtre) → (px à défiler au
  // repos, action atteignable au repos)`, les mêmes hors mode et en mode. À
  // 100 %, « écoulement », l'avis d'absence (176 à 332) dépasse de 8 px sa
  // fenêtre (8 à 324) — son action (272 à 320) y est entière : sans
  // « Favoris » il y tenait (`I1`, plus haut, qui ne le pose pas). À 200 %,
  // la fenêtre finit à 278 : aucun avis n'y tient, et l'action de l'avis de
  // carte vidée par le filtre ne se voit pas sans défiler (constat d du
  // cadrage de T3, § 9, mesuré ici pour la première fois).
  (double, bool) auRepos((double, MapScaleKind, bool) cas) => switch (cas) {
    (1, MapScaleKind.ecoulement, false) => (8, true),
    (1, MapScaleKind.ecoulement, true) => (0, true),
    (1, MapScaleKind.debit, false) => (0, true),
    (1, MapScaleKind.debit, true) => (0, true),
    (2, MapScaleKind.ecoulement, false) => (304, false),
    (2, MapScaleKind.ecoulement, true) => (193, false),
    (2, MapScaleKind.debit, false) => (267, false),
    (2, MapScaleKind.debit, true) => (193, false),
    _ => throw StateError('cas non mesuré : $cas'),
  };
  for (final double textScale in <double>[1, 2]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool filtre in <bool>[false, true]) {
        for (final bool enMode in <bool>[false, true]) {
          final String nomAvis = filtre
              ? 'l’avis de carte vidée par le filtre'
              : 'l’avis d’absence';
          final (double, bool) attendu = auRepos((textScale, scale, filtre));
          _surAndroid('CONSTAT — K3 : à ${_nom(_petit, textScale, scale)}, '
              '${_mode(enMode)}, $nomAvis, « Favoris » posé : '
              '${attendu.$1 == 0 ? 'l’avis est entier au repos' : 'l’avis a ${attendu.$1.toInt()} px à défiler au repos, une partie en reste visible'}'
              ', son action '
              '${attendu.$2 ? 's’atteint sans défiler' : 's’atteint en faisant défiler la colonne'}'
              ' ; la colonne à cinq boutons ne recoupe ni la partie visible de '
              'l’avis, ni celle de la légende, ni le bouton de désignation, ni '
              'l’attribution', (WidgetTester tester) async {
            await _pumpOverlays(
              tester,
              _petit,
              textScale: textScale,
              scale: scale,
              enMode: enMode,
              avecAvis: !filtre,
              filtreVideTout: filtre,
              onOuvrirFavoris: () {},
            );
            final Finder avis = filtre
                ? find.byType(FilterHidesEverythingNotice)
                : _avis(scale);
            final Finder action = find.byKey(
              filtre ? clearFiltersKey : widenSearchKey,
            );
            final _ColonneACinq c = _ColonneACinq(tester, _petit, avis: avis);
            printOnFailure(c.mesure);
            c.exiger();
            // `BR-007` : jamais une carte muette — une partie de l'avis se
            // voit au repos, même quand il dépasse de sa fenêtre.
            expect(
              c.pieces['avis (partie visible)'],
              isNotNull,
              reason: 'rien de l’avis ne paraît au repos : ${c.mesure}',
            );

            final Rect boite = _rectOf(tester, avis);
            final Rect fenetre = _fenetre(tester);
            final double aDefiler = math.max(0, boite.bottom - fenetre.bottom);
            final String detail =
                'avis=$boite, fenêtre=$fenetre, '
                'action=${_rectOf(tester, action)}';
            expect(
              aDefiler,
              moreOrLessEquals(attendu.$1, epsilon: 0.1),
              reason: detail,
            );
            expect(_atteignable(action), attendu.$2, reason: detail);
            // Ce qui dépasse s'amène dans la fenêtre du doigt, et l'action
            // s'atteint alors.
            if (aDefiler > 0) {
              await _defilerDuDoigt(tester, aDefiler);
              expect(
                _rectOf(tester, avis).bottom,
                lessThanOrEqualTo(fenetre.bottom + 0.5),
                reason: 'après défilement : avis=${_rectOf(tester, avis)}',
              );
              expect(
                _atteignable(action),
                isTrue,
                reason: 'après défilement : action=${_rectOf(tester, action)}',
              );
            }
          });
        }
      }
    }
  }
}

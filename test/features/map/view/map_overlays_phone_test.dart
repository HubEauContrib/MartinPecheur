// Surcouches de la carte aux largeurs de téléphone (constat du 2026-09-29),
// à 360 × 640 et 390 × 844, police à 100 % et à 200 %, HORS MODE puis EN MODE
// « Restrictions » (`E5`, `E5b` de T2). Ce que ces tests prouvent, et rien de
// plus :
//
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
// - l'ordre de tabulation (`K2`) sous 600 px : puces (trois), contrôles de
//   zoom, puis, EN MODE seulement, bouton de désignation, enfin contrôle
//   d'avertissement ;
// - à 100 %, avec un avis, l'avis est entier dans l'écran, libre de toute
//   surcouche du bas (bouton compris, en mode), et son action « Élargir la
//   recherche » est atteignable ;
// - à 100 %, sans avis, la légende « écoulement » est entière et libre de
//   toute autre surcouche ;
// - `BR-012` : HORS MODE, à 100 % et à 200 %, le centre du contrôle
//   « ⚠ Avertissement » et celui des trois puces sont atteignables ;
// - EN MODE, à 200 %, le centre de la puce « Restrictions », seule sortie du
//   mode, est atteignable : le bouton ne le recouvre pas ;
// - à 200 %, faire défiler la colonne amène le bord bas de la légende dans la
//   fenêtre ;
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
// - la légende, repoussée sous un avis, est recoupée par les contrôles de
//   zoom (et, en mode, par le bouton) à 360 × 640 ; à 200 %, amenée dans la
//   fenêtre, elle passe sous les contrôles de zoom et l'attribution (et, en
//   mode, sous le bouton), sauf « écoulement » sans avis, entière au repos :
//   sous les contrôles à 360 × 640, sous rien à 390 × 844 hors mode ;
// - à 200 %, EN MODE, le bouton de désignation recouvre l'action de l'avis ;
//   il ne recouvre ni le contrôle d'avertissement ni les puces, et la puce
//   « Restrictions » est atteignable sur toute sa surface (mesuré) — mais plus
//   sur une fenêtre plus courte ;
// - EN MODE, l'avis recouvre le réticule de désignation dans la plupart des
//   cas de carte vide ;
// - une fiche de 320 px recouvre une partie des surcouches du haut ;
// - à 600 × 360 et 640 × 360, 200 %, l'attribution IGN recouvre le bas de
//   l'action de l'avis, une fois la colonne gauche défilée.

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
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

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
/// famille `Roboto`, celle que Material demande sur Android.
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
  final FontLoader chargeur = FontLoader('Roboto');
  for (final File police in polices) {
    chargeur.addFont(
      Future<ByteData>.value(ByteData.sublistView(police.readAsBytesSync())),
    );
  }
  await chargeur.load();
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

/// Le focus courant est-il porté par un élément du sous-arbre de [ancestor] ?
/// Même construction que `map_keyboard_test.dart` : [Focus.of] ne cherche que
/// des ANCÊTRES, jamais l'inverse.
bool _focusedWithin(WidgetTester tester, Finder ancestor) {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  bool found = false;
  void visit(Element element) {
    if (element == focusedContext) {
      found = true;
    }
    element.visitChildren(visit);
  }

  visit(tester.element(ancestor));
  return found;
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
/// station et un point ONDE existent : aucun avis.
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

void main() {
  setUpAll(_chargerRoboto);

  // ---------------------------------------------------------------------
  // La police : Roboto, pas la police de test
  // ---------------------------------------------------------------------
  testWidgets('la police de ce fichier est ROBOTO : « Avertissement », dans le '
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

            testWidgets('$cas : aucune erreur de rendu, avertissement et '
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
        testWidgets(
          'à ${_nom(cas.$1, cas.$2, scale)}, ${_mode(enMode)} : les trois '
          'puces prennent ${cas.$3} rangée${cas.$3 > 1 ? 's' : ''}',
          (WidgetTester tester) async {
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
          },
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Gestes rendus à la carte
  // ---------------------------------------------------------------------
  for (final bool enMode in <bool>[false, true]) {
    group('gestes — à 360 × 640, 100 %, échelle écoulement, un avis affiché, '
        '${_mode(enMode)}', () {
      /// Un point DANS la fenêtre de la colonne, à gauche du contrôle
      /// d'avertissement, hors de tout enfant de la colonne : de la carte
      /// visible, au sens de l'usager.
      Offset pointALaGaucheDuLien(WidgetTester tester) {
        final Rect colonne = _fenetre(tester);
        final Rect lien = _rectOf(tester, find.byType(WarningLink));
        final Offset p = Offset((colonne.left + lien.left) / 2, lien.center.dy);
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

      testWidgets('un tap hors des enfants de la colonne atteint la carte', (
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

      testWidgets('un cran de molette hors des enfants de la colonne atteint '
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

      testWidgets('un glisser hors des enfants de la colonne atteint la '
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

      testWidgets('un tap sur une puce d’échelle atteint la puce, pas la '
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

      testWidgets('un tap sur la puce « Restrictions » atteint la puce, pas '
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

  // ---------------------------------------------------------------------
  // Ordre de la colonne : avertissement, puces, avis, puis légende
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgets(
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
  // bouton de désignation : le contrôle d'avertissement suit les contrôles de
  // zoom ; en mode le bouton s'intercale entre les deux.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      for (final bool enMode in <bool>[false, true]) {
        testWidgets('Tab à ${_nom(size, textScale, MapScaleKind.ecoulement)}, '
            '${_mode(enMode)} : puces (trois) → contrôles de zoom'
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
              _focusedWithin(tester, attendu),
              isTrue,
              reason: 'attendu à ce Tab : $attendu',
            );
          }

          // Un Tab de plus reboucle sur le premier arrêt : rien de ce que
          // Tab atteint n'est resté hors de l'ordre déclaré.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(_focusedWithin(tester, ordreAttendu.first), isTrue);
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Avis à 100 % (I1)
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool enMode in <bool>[false, true]) {
        testWidgets(
          'à ${_nom(size, 1, scale)}, ${_mode(enMode)}, AVEC un avis : l’avis '
          'est entier dans l’écran, libre de toute surcouche du bas, et son '
          'action « Élargir la recherche » est atteignable',
          (WidgetTester tester) async {
            await _pumpOverlays(tester, size, scale: scale, enMode: enMode);

            final Rect ecran = Offset.zero & size;
            final Rect lAvis = _rectOf(tester, _avis(scale));
            final Rect colonne = _fenetre(tester);
            expect(
              ecran.intersect(lAvis),
              lAvis,
              reason: 'hors écran : $lAvis',
            );
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
          },
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Légende à 100 % (I2)
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final bool enMode in <bool>[false, true]) {
      testWidgets(
        'à ${_nom(size, 1, MapScaleKind.ecoulement)}, ${_mode(enMode)}, SANS '
        'avis : la légende est entière, dans l’écran, et ne recoupe ni les '
        'contrôles de zoom, ni le bouton de désignation, ni l’attribution',
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
  // recoupe)`. La légende « débit » (247 px de haut en Roboto) sans avis : à
  // 360 × 640 elle s'arrête à 423, à 21 px des contrôles de zoom (444) —
  // elle ne recoupe rien, de PEU : un seul pixel de police ou de marge de plus
  // et elle les recoupe.
  for (final (Size, bool, bool, Set<String>) cas
      in <(Size, bool, bool, Set<String>)>[
        (_petit, false, false, <String>{}),
        (_petit, true, false, <String>{}),
        (_grand, false, false, <String>{}),
        (_grand, true, false, <String>{}),
      ]) {
    testWidgets(
      'CONSTAT — à ${_nom(cas.$1, 1, MapScaleKind.debit)}, ${_mode(cas.$2)}, '
      'SANS avis : la légende « débit » (247 px de haut) '
      '${cas.$4.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                '${cas.$4.join(', ')}'}'
      '${cas.$3 ? ', et sa fenêtre la coupe' : ', et sa fenêtre ne la coupe pas'}',
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
  // À 360 × 640 elle recoupe les contrôles de zoom (et, en mode, le bouton) :
  // « écoulement » entière (340 à 505, les contrôles commencent à 444),
  // « débit » entière aussi (321 à 568). À 390 × 844 rien ne la recoupe.
  // ⚠️ Tenu de PEU, le premier à basculer : EN MODE, à 360 × 640 « écoulement »,
  // la légende (bas à 505) ne recoupe le bouton de désignation (haut à 504)
  // que d'UN pixel. Elle ne recoupe pas l'attribution, à 107 px près (505
  // contre 612) : rien ne se joue là.
  for (final (Size, MapScaleKind, bool, bool, Set<String>) cas
      in <(Size, MapScaleKind, bool, bool, Set<String>)>[
        (_petit, MapScaleKind.ecoulement, false, false, <String>{_controles}),
        (
          _petit,
          MapScaleKind.ecoulement,
          true,
          false,
          <String>{_controles, _designation},
        ),
        (_petit, MapScaleKind.debit, false, false, <String>{_controles}),
        (
          _petit,
          MapScaleKind.debit,
          true,
          false,
          <String>{_controles, _designation},
        ),
        (_grand, MapScaleKind.ecoulement, false, false, <String>{}),
        (_grand, MapScaleKind.ecoulement, true, false, <String>{}),
        (_grand, MapScaleKind.debit, false, false, <String>{}),
        (_grand, MapScaleKind.debit, true, false, <String>{}),
      ]) {
    testWidgets(
      'CONSTAT — à ${_nom(cas.$1, 1, cas.$2)}, ${_mode(cas.$3)}, AVEC un '
      'avis : la légende, repoussée sous l’avis, '
      '${cas.$5.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                '${cas.$5.join(', ')}'}'
      '${cas.$4 ? ', et sa fenêtre la coupe' : ', et sa fenêtre ne la coupe pas'}',
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
          testWidgets(
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
  testWidgets('à 599 px de large la disposition est compacte : la légende est '
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

  testWidgets('à 600 px de large la disposition est large : la légende est À '
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
          testWidgets(
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
    testWidgets(
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
  // - À 600 × 360, 100 %, « écoulement », EN MODE, la BANDE du bouton de
  //   désignation recouvre l'action de l'avis, et il n'y a rien à défiler :
  //   l'action n'est pas atteignable. Hors mode elle l'est. La bande (un
  //   `ListView` opaque : 64 à 536 de large) déborde la pilule et son indice
  //   (134,5 à 465,5) : c'est elle qui reçoit le geste au centre de l'action
  //   (89,8), à gauche de la pilule.
  for (final (Size, double, MapScaleKind, bool, bool, double) cas
      in <(Size, double, MapScaleKind, bool, bool, double)>[
        (const Size(600, 360), 1, MapScaleKind.ecoulement, false, true, 0),
        (const Size(600, 360), 1, MapScaleKind.ecoulement, true, false, 0),
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
    testWidgets(
      'CONSTAT — disposition LARGE à ${_nom(cas.$1, cas.$2, cas.$3)}, '
      '${_mode(cas.$4)}, avis affiché : l’action de l’avis '
      '${cas.$5 ? 'est' : 'n’est pas'} atteignable au repos ; une fois la '
      'colonne défilée, l’attribution en recouvre le bas de '
      '${cas.$6.toInt()} px'
      '${cas.$6 > 0 ? ' (le centre de l’action reste atteignable)' : ''}',
      (WidgetTester tester) async {
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
      },
    );
  }

  // ---------------------------------------------------------------------
  // Légende à 200 %
  // ---------------------------------------------------------------------
  // Affirmation stricte : quand la légende dépasse le bas de la fenêtre,
  // faire défiler la colonne en amène le bord bas dans la fenêtre, et elle y
  // tient entière si elle est plus basse que la fenêtre n'est haute. Sans
  // table de valeurs mesurées : tout vient de la géométrie du test. Les cas
  // « écoulement, sans avis » ne sont pas là, à 360 × 640 comme à 390 × 844 :
  // la légende y tient entière au repos, rien n'y défile (voir le CONSTAT
  // ci-dessous). Le cas 390 × 844, « écoulement », AVEC un avis non plus : il
  // n'y a qu'UN pixel à défiler (837 contre 836), trop peu pour un invariant
  // — il est verrouillé en CONSTAT « de peu » plus bas. Le plus petit
  // défilement des cas ci-dessous est de 210 px.
  for (final (Size, MapScaleKind, bool) cas in <(Size, MapScaleKind, bool)>[
    (_petit, MapScaleKind.ecoulement, true),
    (_petit, MapScaleKind.debit, true),
    (_grand, MapScaleKind.debit, true),
    (_petit, MapScaleKind.debit, false),
    (_grand, MapScaleKind.debit, false),
  ]) {
    for (final bool enMode in <bool>[false, true]) {
      testWidgets('à ${_nom(cas.$1, 2, cas.$2)}, ${_mode(enMode)}'
          '${cas.$3 ? ', AVEC un avis' : ', SANS avis'}'
          ' : faire défiler la colonne amène le bord bas de la légende dans la '
          'fenêtre', (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: cas.$2,
          enMode: enMode,
          avecAvis: cas.$3,
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

  // CONSTAT « de peu » : à 390 × 844, 200 %, « écoulement », AVEC un avis, la
  // légende (bas à 837) ne dépasse le bas de la fenêtre (836) que d'UN pixel.
  // Le premier à basculer ; sa bascule n'apprendrait rien (un pixel de police
  // ou de marge).
  for (final bool enMode in <bool>[false, true]) {
    testWidgets('CONSTAT — à ${_nom(_grand, 2, MapScaleKind.ecoulement)}, '
        '${_mode(enMode)}, AVEC un avis : il n’y a qu’UN pixel à défiler pour '
        'amener le bord bas de la légende dans la fenêtre (837 contre 836), de '
        'PEU', (WidgetTester tester) async {
      await _pumpOverlays(
        tester,
        _grand,
        textScale: 2,
        scale: MapScaleKind.ecoulement,
        enMode: enMode,
      );

      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : corriger ce test À LA
      // MAIN si la légende ou la fenêtre changent d'un pixel.
      final Rect colonne = _fenetre(tester);
      final double distance = _adefiler(tester);
      expect(
        distance,
        closeTo(1, 0.05),
        reason:
            'fenêtre=$colonne, '
            'légende=${_rectOf(tester, find.byType(MapLegend))}',
      );

      await _defilerDuDoigt(tester, distance);

      expect(
        _rectOf(tester, find.byType(MapLegend)).bottom,
        lessThanOrEqualTo(colonne.bottom + 0.5),
        reason: 'après défilement : fenêtre=$colonne',
      );
    });
  }

  // `(taille, échelle, avec un avis, légende au repos, ce qu'elle recoupe
  // HORS MODE, ce qu'elle recoupe EN MODE — une fois amenée au bord bas de la
  // fenêtre, sans rien défiler quand elle y est déjà)`.
  for (final (Size, MapScaleKind, bool, String, Set<String>, Set<String>) cas
      in <(Size, MapScaleKind, bool, String, Set<String>, Set<String>)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          true,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        (
          _petit,
          MapScaleKind.debit,
          true,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        (
          _grand,
          MapScaleKind.ecoulement,
          true,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        (
          _grand,
          MapScaleKind.debit,
          true,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        // Les deux cas où la légende est entière au repos : rien à défiler.
        // À 390 × 844 hors mode elle ne recoupe RIEN (bas à 522, les contrôles
        // commencent à 602) ; en mode seul le bouton (haut à 503) la recoupe.
        (
          _petit,
          MapScaleKind.ecoulement,
          false,
          'entière',
          <String>{_controles},
          <String>{_controles, _designation},
        ),
        (
          _grand,
          MapScaleKind.ecoulement,
          false,
          'entière',
          <String>{},
          <String>{_designation},
        ),
        (
          _petit,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        (
          _grand,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$6 : cas.$5;
      testWidgets('CONSTAT — à ${_nom(cas.$1, 2, cas.$2)}, ${_mode(enMode)}'
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
        );

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : même amenée dans la
        // fenêtre, la légende passe sous les contrôles et l'attribution
        // (posés au-dessus de la colonne dans la pile), et, en mode, sous
        // le bouton de désignation.
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
        expect(
          _recoupements(tester, find.byType(MapLegend), _bas()),
          attendu,
          reason:
              'après défilement : '
              'légende=${_rectOf(tester, find.byType(MapLegend))}',
        );
      });
    }
  }

  // `(taille, échelle, ce que l'avis recoupe HORS MODE, ce qu'il recoupe EN
  // MODE)`. À 200 %, avec un avis, en Roboto : l'avis (344 px à 360 × 640
  // « écoulement », 307 px sinon) est ENTIER dans l'écran au repos, aux
  // quatre cas, mais il recoupe les surcouches du bas, et EN MODE le bouton
  // de désignation (posé au-dessus de la colonne) recouvre l'action de
  // l'avis : elle n'est plus atteignable. Hors mode elle l'est.
  for (final (Size, MapScaleKind, Set<String>, Set<String>) cas
      in <(Size, MapScaleKind, Set<String>, Set<String>)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          <String>{_controles, _attribution},
          <String>{_controles, _designation, _attribution},
        ),
        (
          _petit,
          MapScaleKind.debit,
          <String>{_controles},
          <String>{_controles, _designation},
        ),
        (_grand, MapScaleKind.ecoulement, <String>{}, <String>{_designation}),
        (_grand, MapScaleKind.debit, <String>{}, <String>{_designation}),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$4 : cas.$3;
      testWidgets(
        'CONSTAT — à ${_nom(cas.$1, 2, cas.$2)}, ${_mode(enMode)}, AVEC un '
        'avis : l’avis, entier au repos, '
        '${attendu.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                  '${attendu.join(', ')}'} et son action '
        '${enMode ? 'n’est pas atteignable : le bouton de désignation la recouvre' : 'est atteignable'}',
        (WidgetTester tester) async {
          await _pumpOverlays(
            tester,
            cas.$1,
            textScale: 2,
            scale: cas.$2,
            enMode: enMode,
          );

          // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : à 200 %, le bouton de
          // désignation, posé au-dessus de la colonne du haut, recouvre
          // l'avis (arbitrage du 2026-10-03 : à ne pas corriger ici). Corriger
          // ce test À LA MAIN quand l'écran sera repris.
          final Finder lAvis = _avis(cas.$2);
          final Rect ecran = Offset.zero & cas.$1;
          expect(
            _etat(tester, lAvis),
            'entière',
            reason:
                'avis=${_rectOf(tester, lAvis)}, fenêtre=${_fenetre(tester)}',
          );
          expect(
            ecran.intersect(_rectOf(tester, lAvis)),
            _rectOf(tester, lAvis),
            reason: 'hors écran : avis=${_rectOf(tester, lAvis)}',
          );
          expect(
            _recoupements(tester, lAvis, _bas()),
            attendu,
            reason: 'avis=${_rectOf(tester, lAvis)}',
          );
          expect(
            _atteignable(find.byKey(widenSearchKey)),
            !enMode,
            reason: 'action=${_rectOf(tester, find.byKey(widenSearchKey))}',
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
        testWidgets(
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
  // recouvert.
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      for (final bool avecAvis in <bool>[true, false]) {
        testWidgets('CONSTAT — EN MODE, à ${_nom(size, 2, scale)}, '
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

  // `(taille, part de la puce « Restrictions » atteignable, son centre est
  // atteignable)`, EN MODE, à 200 %. Plus la fenêtre est courte, plus le bouton
  // de désignation (259 px de haut à 200 %, posé en bas) monte vers la puce : à
  // 360 × 572 il la touche tout juste, à 360 × 568 il en recouvre 8 % (la puce
  // finit à 230, le bouton commence à 227), à 360 × 540 il en recouvre 64 % et
  // son centre, à 360 × 330 il la recouvre entièrement. La puce étant la
  // SEULE sortie du mode, un téléphone aussi court, à 200 %, n'a plus de
  // sortie tactile du mode : à signaler au commanditaire, non corrigé ici.
  for (final (Size, double, bool) cas in <(Size, double, bool)>[
    (const Size(360, 568), 0.92, true),
    (const Size(360, 540), 0.36, false),
    (const Size(360, 330), 0.0, false),
  ]) {
    testWidgets(
      'CONSTAT — EN MODE, à ${_nom(cas.$1, 2, MapScaleKind.ecoulement)}, AVEC '
      'un avis : le bouton de désignation recouvre la puce « Restrictions » '
      '(part atteignable ${cas.$2}, centre '
      '${cas.$3 ? 'atteignable' : 'recouvert'})',
      (WidgetTester tester) async {
        await _pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: MapScaleKind.ecoulement,
          enMode: true,
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
      testWidgets(
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
  for (final (Size, double, MapScaleKind, bool, bool) cas
      in <(Size, double, MapScaleKind, bool, bool)>[
        (_petit, 1, MapScaleKind.ecoulement, true, true),
        (_petit, 1, MapScaleKind.debit, true, false),
        (_petit, 2, MapScaleKind.ecoulement, true, true),
        (_petit, 2, MapScaleKind.debit, true, true),
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
    testWidgets(
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
  // ⚠️ Pas de cas tenu de peu : le plus proche est 390 × 844, 100 %,
  // « écoulement », hors mode (fiche à 492, légende finissant à 430).
  for (final (Size, double, MapScaleKind, Set<String>, Set<String>) cas
      in <(Size, double, MapScaleKind, Set<String>, Set<String>)>[
        (
          _petit,
          1,
          MapScaleKind.ecoulement,
          <String>{avisNom, legendeNom},
          <String>{avisNom, legendeNom},
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
          <String>{avisNom, legendeNom},
          <String>{lienNom, pucesNom, avisNom},
        ),
        (
          _petit,
          2,
          MapScaleKind.debit,
          <String>{avisNom, legendeNom},
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
          <String>{avisNom, legendeNom},
          <String>{pucesNom, avisNom},
        ),
        (
          _grand,
          2,
          MapScaleKind.debit,
          <String>{avisNom, legendeNom},
          <String>{pucesNom, avisNom},
        ),
      ]) {
    for (final bool enMode in <bool>[false, true]) {
      final Set<String> attendu = enMode ? cas.$5 : cas.$4;
      testWidgets(
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
}

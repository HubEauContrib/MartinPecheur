// La colonne à CINQ boutons du bas à droite, rendue pour de vrai (`S10` de T3).
//
// `F10b` n'avait vérifié, au lot 4, qu'un rectangle réservé ; `F10c` a mesuré
// par anticipation, sur `buildMapOverlays` SANS le bouton, la place qu'aurait
// le cinquième. Ici `MapView` est montée en entier, avec `onOpenFavorites` :
// « Favoris », « Filtres », `+`, `−` et recentrer sont de vrais boutons, et les
// rectangles sont lus par `tester.getRect`.
//
// CE QUE LES TESTS EXIGENT (« aucune intersection ») : le rectangle qui
// englobe les cinq boutons ne recoupe ni la PARTIE VISIBLE de la légende (sa
// boîte coupée par sa fenêtre : depuis `F10b` la fenêtre de la colonne du haut
// s'arrête au-dessus de la colonne du bas PAR CONSTRUCTION), ni le bouton de
// désignation et son indice (mode « Restrictions » allumé), ni l'attribution
// IGN, ni un panneau de fiche (station, puis ONDE, de 320 px). Configurations
// bloquantes : 800 × 740 sous Windows, 360 × 640 sous Android, sur les deux
// échelles.
//
// CE QU'ILS CONSTATENT (« CONSTAT — ») : ce que la légende a désormais à
// faire défiler AU REPOS, sa boîte dépassant de sa fenêtre. Arbitrage du
// commanditaire du 2026-10-14 : « Favoris » reste AU-DESSUS de « Filtres »
// (arbitrage 8, inchangé) ; au téléphone la légende défile un peu plus, rien
// n'est recouvert. Ce ne sont pas des invariants voulus : ils décrivent
// l'écran tel qu'il est et se corrigent À LA MAIN quand il change.
//
// POLICE : tout ce fichier mesure en ROBOTO, chargée depuis le SDK Flutter
// (même procédure que `map_overlays_phone_test.dart`), jamais en police de
// test. Sous Windows, les mêmes octets sont enregistrés sous le nom « Segoe
// UI » : c'est un SUBSTITUT, Segoe UI réelle n'est pas mesurée. Ces pixels
// sont des mesures de test, pas des constats d'écran.
//
// 640 × 360 (téléphone couché, disposition large) : rectangles MESURÉS et
// imprimés si le cas échoue (`printOnFailure`) ; le cas n'affirme que
// l'absence d'exception de rendu.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

const Key _ficheStationKey = Key('fiche-station-de-test-S10');
const Key _ficheOndeKey = Key('fiche-onde-de-test-S10');
const double _hauteurFiche = 320;

const Size _bureau = Size(800, 740);
const Size _telephone = Size(360, 640);
const Size _telephoneCouche = Size(640, 360);

/// Le panneau de fiche injecté dans [MapView] : aucun, celui d'une station,
/// celui d'un point ONDE.
enum _Fiche {
  aucune('sans fiche', null),
  station('avec une fiche station de 320 px', _ficheStationKey),
  onde('avec une fiche ONDE de 320 px', _ficheOndeKey);

  const _Fiche(this.libelle, this.cle);

  final String libelle;
  final Key? cle;
}

/// Charge ROBOTO — toutes les graisses `Roboto-*.ttf` du SDK Flutter — sous la
/// famille `Roboto` (Android) et, avec les mêmes octets, sous « Segoe UI »
/// (Windows), en substitut. Même procédure que `map_overlays_phone_test.dart` ;
/// si la variable `FLUTTER_ROOT`, le dossier ou les polices manquent, le
/// fichier ÉCHOUE : jamais de repli silencieux sur la police de test, tous les
/// pixels d'ici seraient faux.
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

/// Une station sans rattachement administratif : un marqueur individuel à tous
/// les niveaux, donc aucun avis « carte vide » sur l'échelle débit.
StationPoint _uneStation() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.0,
  longitude: 2.0,
);

/// Un point ONDE sans rattachement : aucun avis « carte vide » sur l'échelle
/// écoulement.
OndeObservation _uneObservation() {
  final OndePoint point = OndePoint(
    code: OndeStationCode('04170001'),
    label: 'Le Trey à Vilcey-sur-Trey',
    latitude: 47.1,
    longitude: 2.1,
    waterCourseLabel: 'Le Trey',
    departement: null,
  );
  return OndeObservation(
    station: point.code,
    point: point,
    observedAt: DateTime.utc(2026, 9, 1),
    category: const Assec(),
    rawFlowCode: '3',
    officialLabel: 'Assec',
    campaignCode: '1',
  );
}

final class _Stations implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => <StationPoint>[_uneStation()];

  @override
  Future<List<StationPoint>> all() async => <StationPoint>[_uneStation()];
}

final class _NoHydro implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

final class _Onde implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => OndeSweep(
    observations: <OndeObservation>[_uneObservation()],
    unreadableRows: 0,
  );

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

/// Les rectangles lus sur le rendu réel de [MapView].
class _Mesure {
  _Mesure(WidgetTester tester, this.ecran, this.scale, this.fiche)
    : boutons = <String, Rect>{
        'Favoris': tester.getRect(find.byKey(mapFavoritesButtonKey)),
        'Filtres': tester.getRect(find.byKey(mapFiltersButtonKey)),
        '+': tester.getRect(find.byKey(mapZoomInButtonKey)),
        '−': tester.getRect(find.byKey(mapZoomOutButtonKey)),
        'recentrer': tester.getRect(find.byKey(mapRecenterButtonKey)),
      },
      legende = tester.getRect(find.byType(MapLegend)),
      fenetre = tester.getRect(
        find.ancestor(
          of: find.byType(MapLegend),
          matching: find.byType(SingleChildScrollView),
        ),
      ),
      fenetreBas = tester.getRect(
        find.ancestor(
          of: find.byType(MapControls),
          matching: find.byType(SingleChildScrollView),
        ),
      ),
      designation = find.byType(DesignateCenterControl).evaluate().isEmpty
          ? null
          : tester.getRect(find.byType(DesignateCenterControl)),
      attribution = tester.getRect(find.byType(IgnAttributionBadge)),
      ficheRect = fiche.cle == null
          ? null
          : tester.getRect(find.byKey(fiche.cle!));

  final Size ecran;
  final MapScaleKind scale;
  final _Fiche fiche;
  final Map<String, Rect> boutons;
  final Rect legende;
  final Rect fenetre;

  /// La fenêtre de la colonne du bas à droite (boutons d'entrée, zoom,
  /// attribution), qui défile ancrée en bas.
  final Rect fenetreBas;

  /// `null` quand le bouton n'est pas dans l'arbre : une fiche de 320 px sur 360 de
  /// haut prend toute la hauteur et la bande du bouton n'en reçoit plus.
  final Rect? designation;
  final Rect attribution;
  final Rect? ficheRect;

  /// Le rectangle qui englobe les cinq boutons.
  Rect get cinq =>
      boutons.values.reduce((Rect a, Rect b) => a.expandToInclude(b));

  /// La partie visible de la légende : sa boîte coupée par sa fenêtre.
  Rect get visible => legende.intersect(fenetre);

  /// Ce que la légende a à faire défiler au repos pour que son bord bas arrive
  /// au bord bas de sa fenêtre ; 0 quand elle tient.
  double get adefiler =>
      legende.bottom > fenetre.bottom ? legende.bottom - fenetre.bottom : 0;

  String get texte {
    final String detail = boutons.entries
        .map((MapEntry<String, Rect> e) => '${e.key}=${e.value}')
        .join(', ');
    return 'écran=$ecran, échelle=${scale.name}, ${fiche.libelle}, '
        'cinq boutons=$cinq ($detail), '
        'légende(boîte)=$legende, légende(visible)=$visible, '
        'fenêtre=$fenetre, fenêtre du bas=$fenetreBas, désignation=$designation, '
        'attribution=$attribution, fiche=$ficheRect, '
        'légende à défiler au repos=$adefiler px';
  }
}

/// Deux rectangles se recoupent-ils sur une surface non vide ? Un rectangle
/// vide ou inversé ne recoupe rien.
bool _recoupe(Rect a, Rect b) =>
    a.width > 0 && a.height > 0 && b.width > 0 && b.height > 0 && a.overlaps(b);

/// Monte [MapView] en entier au format [size], police à 100 %, EN MODE
/// « Restrictions » (le bouton de désignation et son indice existent), l'échelle
/// [scale] affichée, la fiche [fiche] injectée, « Favoris » branché (sur
/// [onOpenFavorites] s'il est fourni). La carte porte une station et un point
/// ONDE : aucun avis.
Future<_Mesure> _monter(
  WidgetTester tester,
  Size size, {
  required MapScaleKind scale,
  required _Fiche fiche,
  VoidCallback? onOpenFavorites,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final MapViewModel viewModel = MapViewModel(
    stationPoints: _Stations(),
    observations: _NoHydro(),
    onde: _Onde(),
  );
  addTearDown(viewModel.dispose);

  Widget panneau(Key key) => Container(
    key: key,
    width: double.infinity,
    height: _hauteurFiche,
    color: Colors.red,
  );

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapView(
        viewModel: viewModel,
        onOpenFavorites: onOpenFavorites ?? () {},
        onPointDesignated: (GeoPoint _) {},
        onStationTap: fiche == _Fiche.station ? (StationCode _) {} : null,
        stationSheet: fiche == _Fiche.station
            ? panneau(_ficheStationKey)
            : null,
        onOndeTap: fiche == _Fiche.onde ? (OndePoint _) {} : null,
        ondeSheet: fiche == _Fiche.onde ? panneau(_ficheOndeKey) : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  viewModel.selectScale(scale);
  viewModel.toggleDesignationMode();
  await tester.pumpAndSettle();

  expect(viewModel.scale, scale);
  expect(viewModel.designationMode, isTrue);
  for (final Type avis in <Type>[
    NoDataInAreaNotice,
    NoStationInAreaNotice,
    OutsideOndeCoverageNotice,
    SourceUnavailableNotice,
    UnreadableRowsNotice,
    FilterHidesEverythingNotice,
  ]) {
    expect(
      find.byType(avis),
      findsNothing,
      reason: 'un avis $avis déplacerait la légende : la mesure serait autre',
    );
  }
  return _Mesure(tester, size, scale, fiche);
}

void _surAndroid(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnAndroid('Android : $d', corps);

void _surWindows(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnWindows(d, corps);

String _nom(Size size, MapScaleKind scale, _Fiche fiche) =>
    '${size.width.toInt()} × ${size.height.toInt()}, échelle ${scale.name}, '
    '${fiche.libelle}';

/// Ce que le rectangle des cinq boutons ne doit recouper en aucun cas.
void _exigerAucuneIntersection(_Mesure m) {
  // L'invariant ne se vérifie pas à vide : si la partie visible de la légende
  // était vide, `_recoupe` rendrait faux et le cas passerait sans rien dire.
  expect(
    m.visible.height,
    greaterThan(0),
    reason:
        'la partie visible de la légende est vide (${m.visible}) : '
        'l\'absence d\'intersection ne prouverait rien : ${m.texte}',
  );
  expect(
    _recoupe(m.cinq, m.visible),
    isFalse,
    reason:
        'cinq boutons ${m.cinq} × légende (partie visible) ${m.visible} : '
        '${m.texte}',
  );
  final Rect? designation = m.designation;
  expect(
    designation,
    isNotNull,
    reason: 'le bouton de désignation manque au rendu : ${m.texte}',
  );
  expect(
    _recoupe(m.cinq, designation!),
    isFalse,
    reason:
        'cinq boutons ${m.cinq} × bouton de désignation et indice '
        '${m.designation} : ${m.texte}',
  );
  expect(
    _recoupe(m.cinq, m.attribution),
    isFalse,
    reason:
        'cinq boutons ${m.cinq} × attribution IGN ${m.attribution} : '
        '${m.texte}',
  );
  final Rect? fiche = m.ficheRect;
  if (fiche != null) {
    expect(
      _recoupe(m.cinq, fiche),
      isFalse,
      reason: 'cinq boutons ${m.cinq} × fiche $fiche : ${m.texte}',
    );
  }
  final Rect ecran = Offset.zero & m.ecran;
  expect(
    ecran.expandToInclude(m.cinq),
    ecran,
    reason: 'cinq boutons ${m.cinq} hors de l’écran : ${m.texte}',
  );
}

void main() {
  setUpAll(_chargerRoboto);

  // La police de ce fichier est ROBOTO : « Avertissement » fait environ 95 px
  // en Roboto (14 pt, graisse 600), 185 en police de test. Si cette
  // affirmation rougit, tous les pixels d'ici sont à refaire.
  _surAndroid(
    'la police de ce fichier est ROBOTO : « Avertissement » fait environ '
    '95 px (185 en police de test)',
    (WidgetTester tester) async {
      await _monter(
        tester,
        _telephone,
        scale: MapScaleKind.ecoulement,
        fiche: _Fiche.aucune,
      );
      final double largeur = tester.getRect(find.text(warningLinkLabel)).width;
      expect(largeur, inInclusiveRange(90, 100), reason: 'largeur=$largeur');
    },
  );

  // ---------------------------------------------------------------------
  // Bloquant : 800 × 740 sous Windows, 360 × 640 sous Android
  // ---------------------------------------------------------------------
  for (final _Fiche fiche in _Fiche.values) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surWindows(
        '${_nom(_bureau, scale, fiche)} (Roboto pour Segoe UI), EN MODE : les '
        'cinq boutons ne recoupent ni la légende visible, ni le bouton de '
        'désignation et son indice, ni l’attribution, ni la fiche',
        (WidgetTester tester) async {
          final _Mesure m = await _monter(
            tester,
            _bureau,
            scale: scale,
            fiche: fiche,
          );
          printOnFailure(m.texte);
          _exigerAucuneIntersection(m);
        },
      );
      _surAndroid(
        '${_nom(_telephone, scale, fiche)}, EN MODE : les cinq boutons ne '
        'recoupent ni la légende visible, ni le bouton de désignation et son '
        'indice, ni l’attribution, ni la fiche',
        (WidgetTester tester) async {
          final _Mesure m = await _monter(
            tester,
            _telephone,
            scale: scale,
            fiche: fiche,
          );
          printOnFailure(m.texte);
          _exigerAucuneIntersection(m);
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // Écart vertical : « Favoris » → « Filtres » comme « Filtres » → `+`
  // ---------------------------------------------------------------------
  _surWindows(
    '800 × 740 : « Favoris » est au-dessus de « Filtres », même abscisse, '
    'séparé de lui comme « Filtres » l’est de `+`',
    (WidgetTester tester) async {
      final _Mesure m = await _monter(
        tester,
        _bureau,
        scale: MapScaleKind.ecoulement,
        fiche: _Fiche.aucune,
      );
      final Rect favoris = m.boutons['Favoris']!;
      final Rect filtres = m.boutons['Filtres']!;
      final Rect plus = m.boutons['+']!;
      expect(favoris.size, const Size(44, 44), reason: m.texte);
      expect(favoris.right, filtres.right, reason: m.texte);
      expect(favoris.left, filtres.left, reason: m.texte);
      expect(
        filtres.top - favoris.bottom,
        plus.top - filtres.bottom,
        reason: m.texte,
      );
      expect(filtres.top - favoris.bottom, mapControlsSpacing, reason: m.texte);
    },
  );

  _surAndroid(
    '360 × 640 : « Favoris » est au-dessus de « Filtres », même abscisse, '
    'séparé de lui comme « Filtres » l’est de `+`, 48 × 48',
    (WidgetTester tester) async {
      final _Mesure m = await _monter(
        tester,
        _telephone,
        scale: MapScaleKind.ecoulement,
        fiche: _Fiche.aucune,
      );
      final Rect favoris = m.boutons['Favoris']!;
      final Rect filtres = m.boutons['Filtres']!;
      final Rect plus = m.boutons['+']!;
      expect(favoris.size, const Size(48, 48), reason: m.texte);
      expect(favoris.right, filtres.right, reason: m.texte);
      expect(
        filtres.top - favoris.bottom,
        plus.top - filtres.bottom,
        reason: m.texte,
      );
    },
  );

  // ---------------------------------------------------------------------
  // CONSTATS : ce que la légende a à faire défiler au repos
  // ---------------------------------------------------------------------
  // ⚠️ FAITS CONSTATÉS, pas des invariants voulus (Roboto, MapView entière,
  // EN MODE, aucun avis, mesurés le 2026-10-14). À corriger À LA MAIN quand
  // l'écran change.
  //
  // Valeur anticipée par `F10c` (`map_overlays_phone_test.dart`, morsure du
  // groupe étendu d'un bouton sur la BOÎTE de la légende, sans la marge
  // entre les deux colonnes) : 800 × 740 : la légende tient (0 et 0) ;
  // 360 × 640 : 9 px (écoulement) et 91 px (débit). Mesuré avec le vrai
  // bouton : 0 et 0, puis 17 et 99 — huit pixels de plus que F10c, la marge
  // de 8 px que la fenêtre de la légende laisse au-dessus de la colonne du
  // bas (`MapOverlaysLayout`, `padding`), que la morsure ne comptait pas.
  double adefilerAttendu((Size, MapScaleKind) cas) => switch (cas) {
    (_bureau, MapScaleKind.ecoulement) => 0,
    (_bureau, MapScaleKind.debit) => 0,
    (_telephone, MapScaleKind.ecoulement) => 17,
    (_telephone, MapScaleKind.debit) => 99,
    _ => throw StateError('cas non mesuré'),
  };
  for (final MapScaleKind scale in MapScaleKind.values) {
    _surWindows(
      'CONSTAT — ${_nom(_bureau, scale, _Fiche.aucune)} (Roboto pour Segoe '
      'UI), EN MODE : la légende a à défiler de '
      '${adefilerAttendu((_bureau, scale))} px au repos',
      (WidgetTester tester) async {
        final _Mesure m = await _monter(
          tester,
          _bureau,
          scale: scale,
          fiche: _Fiche.aucune,
        );
        expect(
          m.adefiler,
          moreOrLessEquals(adefilerAttendu((_bureau, scale)), epsilon: 0.1),
          reason: m.texte,
        );
      },
    );
    _surAndroid(
      'CONSTAT — ${_nom(_telephone, scale, _Fiche.aucune)}, EN MODE : la '
      'légende a à défiler de ${adefilerAttendu((_telephone, scale))} px au '
      'repos',
      (WidgetTester tester) async {
        final _Mesure m = await _monter(
          tester,
          _telephone,
          scale: scale,
          fiche: _Fiche.aucune,
        );
        expect(
          m.adefiler,
          moreOrLessEquals(adefilerAttendu((_telephone, scale)), epsilon: 0.1),
          reason: m.texte,
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // 640 × 360 : mesuré, pas exigé
  // ---------------------------------------------------------------------
  for (final _Fiche fiche in _Fiche.values) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      _surAndroid(
        '640 × 360, mesure : ${_nom(_telephoneCouche, scale, fiche)}, EN MODE',
        (WidgetTester tester) async {
          final _Mesure m = await _monter(
            tester,
            _telephoneCouche,
            scale: scale,
            fiche: fiche,
          );
          printOnFailure(m.texte);
          // Le cas n'affirme que l'absence d'exception de rendu : un
          // recouvrement ici est un constat remonté, pas un échec.
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (Roboto, Android, mesuré le
  // 2026-10-14) : à 640 × 360 la colonne du bas à droite (cinq boutons, puis
  // l'attribution) est plus haute que sa fenêtre — la fenêtre du haut garde
  // `topMinHeight` (la hauteur du contrôle d'avertissement) et la colonne du
  // bas cède. « Favoris », premier de la colonne, dépasse donc de sa fenêtre
  // par le haut ; il s'atteint en la faisant défiler (elle est ancrée en bas).
  // Sans « Favoris » la colonne tenait (244 px de contenu, 288 de fenêtre) et
  // la fenêtre de la légende allait de 8 à 100 (F10c) ; elle va maintenant de
  // 8 à 56 : la légende, dont la boîte commence à 64, est entièrement sous le
  // bord de sa fenêtre au repos (173 px à défiler sur l'écoulement, 255 sur le
  // débit : cas « CONSTAT — 640 × 360, échelle … » ci-dessous).
  _surAndroid(
    'CONSTAT — 640 × 360, EN MODE : « Favoris » dépasse de la fenêtre de la '
    'colonne du bas de 12 px par le haut, au repos ; il s’atteint en faisant '
    'défiler cette fenêtre',
    (WidgetTester tester) async {
      int ouvertures = 0;
      final _Mesure m = await _monter(
        tester,
        _telephoneCouche,
        scale: MapScaleKind.ecoulement,
        fiche: _Fiche.aucune,
        onOpenFavorites: () => ouvertures++,
      );
      final Rect favoris = m.boutons['Favoris']!;
      expect(m.fenetreBas.bottom, m.attribution.bottom, reason: m.texte);
      expect(
        m.fenetreBas.top - favoris.top,
        moreOrLessEquals(12, epsilon: 0.1),
        reason: m.texte,
      );

      // Revue finale de T3 (M9c) : ce que le CHANGELOG de 0.4.0 écrit,
      // « Favoris » s'atteint en faisant défiler. La fenêtre de la colonne du
      // bas défile (elle est ancrée en bas) ; « Favoris » y est alors entier,
      // rien ne le recouvre, et un tap l'active.
      final Finder bouton = find.byKey(mapFavoritesButtonKey);
      await tester.ensureVisible(bouton);
      await tester.pumpAndSettle();
      final _Mesure apres = _Mesure(
        tester,
        _telephoneCouche,
        MapScaleKind.ecoulement,
        _Fiche.aucune,
      );
      final Rect defile = apres.boutons['Favoris']!;
      expect(
        defile.top,
        greaterThanOrEqualTo(apres.fenetreBas.top - 0.1),
        reason: apres.texte,
      );
      expect(
        defile.bottom,
        lessThanOrEqualTo(apres.fenetreBas.bottom + 0.1),
        reason: apres.texte,
      );
      expect(
        defile.left,
        greaterThanOrEqualTo(apres.fenetreBas.left - 0.1),
        reason: apres.texte,
      );
      expect(
        defile.right,
        lessThanOrEqualTo(apres.fenetreBas.right + 0.1),
        reason: apres.texte,
      );
      expect(bouton.hitTestable(), findsOneWidget, reason: apres.texte);
      await tester.tap(bouton);
      await tester.pumpAndSettle();
      expect(ouvertures, 1, reason: apres.texte);
    },
  );

  // La fenêtre de la légende et ce qu'elle a à défiler, à 640 × 360, par
  // échelle. ⚠️ FAIT CONSTATÉ, pas un invariant voulu (Roboto, Android, mesuré
  // le 2026-10-14) : valeur anticipée avant le vrai bouton par F10c : fenêtre
  // de 8 à 100.
  for (final (MapScaleKind, double) cas in <(MapScaleKind, double)>[
    (MapScaleKind.ecoulement, 173),
    (MapScaleKind.debit, 255),
  ]) {
    _surAndroid(
      'CONSTAT — ${_nom(_telephoneCouche, cas.$1, _Fiche.aucune)}, EN MODE : '
      'la fenêtre de la légende va de 8 à 56 et la légende a à défiler de '
      '${cas.$2.toInt()} px au repos',
      (WidgetTester tester) async {
        final _Mesure m = await _monter(
          tester,
          _telephoneCouche,
          scale: cas.$1,
          fiche: _Fiche.aucune,
        );
        expect(
          m.fenetre.top,
          moreOrLessEquals(8, epsilon: 0.1),
          reason: m.texte,
        );
        expect(
          m.fenetre.bottom,
          moreOrLessEquals(56, epsilon: 0.1),
          reason: m.texte,
        );
        expect(
          m.adefiler,
          moreOrLessEquals(cas.$2, epsilon: 0.1),
          reason: m.texte,
        );
      },
    );
  }
}

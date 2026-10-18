// `D3` d'Ergonomie (spec § 5.5, critère 5 du § 9) : en mode « Restrictions »,
// le bouton désigne le point SOUS le réticule — au centre de la carte visible,
// et non plus au centre de la caméra —, + et − zooment autour de lui, dans les
// bornes de zoom, et le repli 6 retire bande et réticule sans retirer l'appui
// long.
//
// Séparé de `map_designation_test.dart` parce qu'il mesure en ROBOTO
// (`chargerRoboto`, comme la porte `S6` et `map_layout_invariants_test.dart`) :
// en police de test, la pilule est si large qu'à 700 et 800 px de large, fiche
// ouverte, la bande ne tient pas à côté de la colonne et le repli 6 étendu
// (arbitrage 14) la retire — les tailles garanties ne s'éprouveraient plus. Une
// police chargée l'est pour tout le fichier : ici, c'est tout le fichier.
//
// `MapView` est monté en entier, comme dans `map_designation_test.dart`, dont
// les aides sont reprises ici.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart'
    show floodLoadingText, widenSearchKey;
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart'
    show maximumMapZoom, minimumMapZoom;

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_fiches.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

final class _Stations implements StationPointRepository {
  _Stations(this.points);

  final List<StationPoint> points;

  /// Le nombre de chargements d'emprise : un cran de zoom sans effet n'en
  /// demande aucun.
  int chargements = 0;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    chargements++;
    return points;
  }

  @override
  Future<List<StationPoint>> all() async => points;
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

/// Une station au centre initial de la caméra (46,6 N ; 2,2 E), donc au
/// centre de l'écran : sa zone de tap y est posée.
StationPoint _stationAuCentre() => StationPoint(
  code: StationCode('K447001001'),
  label: 'Station du centre',
  latitude: initialMapCenterLatitude,
  longitude: initialMapCenterLongitude,
);

MapCamera _camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer)));

/// Le point que la caméra donne pour la position d'écran [global].
GeoPoint _pointAt(WidgetTester tester, Offset global) {
  final Offset relative = global - tester.getTopLeft(find.byType(FlutterMap));
  final LatLng latLng = _camera(tester).screenOffsetToLatLng(relative);
  return GeoPoint(latitude: latLng.latitude, longitude: latLng.longitude);
}

/// Un test de widget posé sur une plateforme : chaque cas est rejoué sur
/// Android ET sur Windows, la première cible du produit. Un titre passé par
/// [_surAndroid] commence par « Android : ».
typedef _Test = void Function(
  String description,
  Future<void> Function(WidgetTester tester) corps,
);

void _surAndroid(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnAndroid('Android : $d', corps);

void _surWindows(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnWindows(d, corps);

void _expectClose(GeoPoint actual, GeoPoint expected) {
  expect(actual.latitude, closeTo(expected.latitude, 1e-6));
  expect(actual.longitude, closeTo(expected.longitude, 1e-6));
}

/// Le dernier rapport de la mise en page de la carte (`D2` d'Ergonomie) : la
/// carte visible, le réticule, la répartition.
MapLayoutReport? _rapport(WidgetTester tester) =>
    tester.widget<MapLayout>(find.byType(MapLayout)).report.value;

/// Le point de la carte SOUS le réticule (`D3` d'Ergonomie, spec § 5.5) : celui
/// que la caméra rend pour le centre du réticule tel qu'il est posé à l'écran.
GeoPoint _pointSousLeReticule(WidgetTester tester) =>
    _pointAt(tester, tester.getCenter(find.byKey(mapCenterReticleKey)));

/// Le focus principal est-il dans le sous-arbre de [ancestor] ?
bool _focusedWithin(Finder ancestor) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) {
    return false;
  }
  bool found = false;
  void visit(Element element) {
    if (element == focused) {
      found = true;
    }
    element.visitChildren(visit);
  }

  ancestor.evaluate().first.visitChildren(visit);
  return found;
}

// --- D3 d'Ergonomie : le réticule, la désignation et le zoom ------------------

/// Des stations que le test change entre deux chargements : vider la liste
/// puis recharger la même emprise fait paraître l'avis d'absence sans bouger
/// la caméra (Review Focus 2 de `D3`).
final class _StationsMutables implements StationPointRepository {
  List<StationPoint> points = <StationPoint>[_stationAuCentre()];

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => points;

  @override
  Future<List<StationPoint>> all() async => points;
}

/// La source de vigilance, pilotée par le test : chaque appel attend son
/// `Completer` (comme `map_view_flood_test.dart`).
final class _SourceDouble implements FloodVigilanceSource {
  final List<Completer<FloodVigilanceMap>> pending =
      <Completer<FloodVigilanceMap>>[];

  @override
  Future<FloodVigilanceMap> current() {
    final Completer<FloodVigilanceMap> c = Completer<FloodVigilanceMap>();
    pending.add(c);
    return c.future;
  }
}

/// Une carte de vigilance dont un tronçon vert traverse le centre initial de
/// la caméra : la lecture Crues prête n'affiche aucun avis.
FloodVigilanceMap _vigilanceAuCentre() => FloodVigilanceMap(
  informationDate: DateTime.utc(2026, 10, 14, 13, 55),
  sections: <FloodSection>[
    FloodSection(
      code: FloodSectionCode('V1'),
      name: 'Tronçon V1',
      territoryCode: '8',
      level: const Vert(),
      lines: <List<GeoPoint>>[
        <GeoPoint>[
          GeoPoint(latitude: initialMapCenterLatitude, longitude: -6),
          GeoPoint(latitude: initialMapCenterLatitude, longitude: 10),
        ],
      ],
    ),
  ],
  skippedEntities: 0,
);

/// Ce que [_monterD3] rend : de quoi piloter la carte et lire ses rappels.
final class _CarteD3 {
  _CarteD3(this.designated, this.viewModel, this.ficheOuverte);

  final List<GeoPoint> designated;
  final MapViewModel viewModel;
  final ValueNotifier<bool> ficheOuverte;
}

/// La vraie `MapView` à [taille] et à l'échelle de texte [echelle],
/// désignation câblée, le mode « Restrictions » allumé, la fiche station de
/// Blois ouverte si [fiche] (fermée ensuite par `ficheOuverte`), la lecture
/// Crues branchée sur [flood] s'il est fourni, la marge système [marge]
/// posée sur la vue.
Future<_CarteD3> _monterD3(
  WidgetTester tester, {
  required Size taille,
  double echelle = 1,
  bool fiche = true,
  StationPointRepository? stations,
  FloodLayerViewModel? flood,
  FakeViewPadding marge = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = marge;
  tester.view.viewPadding = marge;
  addTearDown(tester.view.reset);
  final List<GeoPoint> designated = <GeoPoint>[];
  final MapViewModel viewModel = MapViewModel(
    stationPoints: stations ?? _Stations(const <StationPoint>[]),
    observations: _NoHydro(),
    onde: _NoOnde(),
    delay: (Duration _) => Future<void>.value(),
  );
  final ValueNotifier<bool> ouverte = ValueNotifier<bool>(fiche);
  addTearDown(ouverte.dispose);
  final Widget ficheStation = ficheStationBlois();
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(echelle)),
        child: child!,
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: ouverte,
        builder: (BuildContext context, bool ouverteMaintenant, Widget? _) =>
            MapView(
              viewModel: viewModel,
              onPointDesignated: designated.add,
              onStationTap: (StationCode _) {},
              stationSheet: ouverteMaintenant
                  ? ficheStation
                  : const SizedBox.shrink(),
              onOndeTap: (OndePoint _) {},
              ondeSheet: const SizedBox.shrink(),
              // La lecture, son rappel et sa fiche vont ensemble (`MapView`).
              floodLayer: flood,
              onFloodSectionTap: flood == null
                  ? null
                  : (FloodSection _, DateTime _) {},
              floodSheet: flood == null ? null : const SizedBox.shrink(),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  viewModel.toggleDesignationMode();
  await tester.pumpAndSettle();
  return _CarteD3(designated, viewModel, ouverte);
}

void main() {
  setUpAll(chargerRoboto);

  // `D3` d'Ergonomie (spec § 5.5, critère 5 du § 9) : le bouton désigne le
  // point SOUS le réticule — au centre de la carte visible, et non plus au
  // centre de la caméra —, + et − zooment autour de lui, et le repli 6 retire bande et
  // réticule sans retirer l'appui long. Chaque cas est rejoué sur Android et
  // sur Windows. Les configurations où le repli 6 joue ou non sont gardées par
  // le rapport de la mise en page : un garde-fou qui rougit dit que la
  // configuration ne prouve plus ce qu'elle doit prouver.
  group('D3 d’Ergonomie — le réticule au centre de la carte visible : '
      'désignation et zoom autour de lui', () {
    final List<(String, _Test, Size)> fichesOuvertes = <(String, _Test, Size)>[
      ('fiche du bas ouverte, 390 × 844', _surAndroid, const Size(390, 844)),
      ('fiche du bas ouverte, 700 × 740', _surWindows, const Size(700, 740)),
      ('panneau ouvert, 800 × 740', _surAndroid, const Size(800, 740)),
      ('panneau ouvert, 800 × 740', _surWindows, const Size(800, 740)),
    ];

    /// Garde-fous : le repli 6 ne joue pas, la fiche réduit la carte visible,
    /// et le réticule est loin du centre de la caméra — sinon désigner le
    /// centre de la caméra passerait pour désigner sous le réticule.
    void gardes(WidgetTester tester, Size taille) {
      final MapLayoutReport? rapport = _rapport(tester);
      expect(rapport, isNotNull, reason: 'aucun rapport publié');
      expect(rapport!.allocation.bandWithdrawn, isFalse, reason: 'repli 6');
      expect(rapport.reticle, isNotNull, reason: 'réticule absent');
      expect(
        rapport.visible.right < taille.width - 1 ||
            rapport.visible.bottom < taille.height - 1,
        isTrue,
        reason: 'la fiche ne réduit pas la carte visible ${rapport.visible}',
      );
      final Offset reticule = tester.getCenter(find.byKey(mapCenterReticleKey));
      expect(
        (reticule - rapport.reticle!.center).distance,
        lessThan(0.5),
        reason: 'le réticule peint n’est pas celui du rapport',
      );
      expect(
        (reticule - tester.getCenter(find.byType(FlutterMap))).distance,
        greaterThan(20),
        reason: 'le réticule $reticule est au centre de la caméra',
      );
    }

    /// Le nombre de nœuds annoncés « Restrictions au centre de la carte ».
    Future<int> annonces(WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pump();
      final int n = find
          .bySemanticsLabel('Restrictions au centre de la carte')
          .evaluate()
          .length;
      handle.dispose();
      return n;
    }

    /// 24 appuis sur Tab : le focus s'est-il arrêté sur [bouton], et sur
    /// l'entrée « Restrictions » (la preuve que la tabulation circule) ?
    Future<({bool bouton, bool restrictions})> tabulation(
      WidgetTester tester,
      Finder bouton,
    ) async {
      bool surLeBouton = false;
      bool surRestrictions = false;
      for (int i = 0; i < 24; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        surLeBouton |= _focusedWithin(bouton);
        surRestrictions |= _focusedWithin(find.byKey(mapDesignationChipKey));
      }
      return (bouton: surLeBouton, restrictions: surRestrictions);
    }

    for (final (String, _Test, Size) cas in fichesOuvertes) {
      cas.$2('${cas.$1}, en mode : le bouton désigne le point sous le '
          'réticule, pas le centre de la caméra', (WidgetTester tester) async {
        final _CarteD3 carte = await _monterD3(tester, taille: cas.$3);
        gardes(tester, cas.$3);

        await tester.tap(find.byKey(mapDesignateCenterButtonKey));
        await tester.pumpAndSettle();

        expect(carte.designated, hasLength(1));
        _expectClose(carte.designated.single, _pointSousLeReticule(tester));
        final LatLng centre = _camera(tester).center;
        expect(
          (carte.designated.single.latitude - centre.latitude).abs() +
              (carte.designated.single.longitude - centre.longitude).abs(),
          greaterThan(1e-3),
          reason: 'le point désigné est le centre de la caméra',
        );
      });

      cas.$2('${cas.$1}, en mode : + puis − gardent le point sous le '
          'réticule', (WidgetTester tester) async {
        await _monterD3(tester, taille: cas.$3);
        gardes(tester, cas.$3);
        final GeoPoint avant = _pointSousLeReticule(tester);
        final double zoom = _camera(tester).zoom;

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
        expect(_camera(tester).zoom, zoom + zoomStep);
        _expectClose(_pointSousLeReticule(tester), avant);

        await tester.tap(find.byKey(mapZoomOutButtonKey));
        await tester.pumpAndSettle();
        expect(_camera(tester).zoom, zoom);
        _expectClose(_pointSousLeReticule(tester), avant);
      });
    }

    // Review Focus 2 : un avis qui paraît ne déplace pas le réticule, et le
    // bouton désigne toujours le même point. Les comparaisons se font
    // LECTURE PAR LECTURE — l'en-tête du bloc change avec la lecture, et c'est
    // lui qui pose le réticule (§ 5.5) : sur le débit, sans avis puis avec
    // l'avis d'absence (la même emprise relue, vide) ; sur Crues, avec l'avis
    // de chargement puis prête, sans avis. Ni le réticule ni le point désigné
    // ne sont comparés d'une lecture à l'autre.
    for (final (String, _Test, Size) cas in <(String, _Test, Size)>[
      ('360 × 640', _surAndroid, const Size(360, 640)),
      ('1 000 × 700', _surWindows, const Size(1000, 700)),
    ]) {
      cas.$2('Review Focus 2 — ${cas.$1}, en mode : l’avis d’absence puis '
          'l’avis de chargement des crues paraissent, le réticule ne bouge '
          'pas et le bouton désigne le même point', (
        WidgetTester tester,
      ) async {
        final _StationsMutables stations = _StationsMutables();
        final _SourceDouble source = _SourceDouble();
        final FloodLayerViewModel flood = FloodLayerViewModel(source: source);
        addTearDown(flood.dispose);
        final _CarteD3 carte = await _monterD3(
          tester,
          taille: cas.$3,
          fiche: false,
          stations: stations,
          flood: flood,
        );
        Future<void> designer() async {
          await tester.tap(find.byKey(mapDesignateCenterButtonKey));
          await tester.pumpAndSettle();
        }

        // Le débit, une station lue : aucun avis.
        await tester.tap(
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(widenSearchKey), findsNothing, reason: 'un avis');
        final Rect? sansAvis = _rapport(tester)?.reticle;
        expect(sansAvis, isNotNull);
        await designer();

        // La même emprise relue, vide : l'avis d'absence paraît.
        stations.points = <StationPoint>[];
        unawaited(
          carte.viewModel.loadFor(
            Bounds(
              west: _camera(tester).visibleBounds.west,
              south: _camera(tester).visibleBounds.south,
              east: _camera(tester).visibleBounds.east,
              north: _camera(tester).visibleBounds.north,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(widenSearchKey), findsOneWidget, reason: 'avis');
        expect(_rapport(tester)?.reticle, sansAvis);
        await designer();

        // La lecture Crues en cours de chargement : son avis paraît…
        await tester.tap(
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.crues)),
        );
        await tester.pumpAndSettle();
        expect(find.text(floodLoadingText), findsOneWidget);
        final Rect? chargement = _rapport(tester)?.reticle;
        expect(chargement, isNotNull);
        await designer();

        // … puis la carte de vigilance lue : plus aucun avis.
        source.pending.last.complete(_vigilanceAuCentre());
        await tester.pumpAndSettle();
        expect(find.text(floodLoadingText), findsNothing);
        expect(_rapport(tester)?.reticle, chargement);
        await designer();

        expect(carte.designated, hasLength(4));
        // Débit : sans avis, puis avec l'avis d'absence.
        _expectClose(carte.designated[1], carte.designated[0]);
        // Crues : avec l'avis de chargement, puis sans avis.
        _expectClose(carte.designated[3], carte.designated[2]);
        _expectClose(carte.designated[3], _pointSousLeReticule(tester));
      });
    }

    // Review Focus 4 : à 360 × 640 et 200 %, la fiche station ouverte, le
    // repli 6 joue (garde-fou) : bande et réticule retirés, l'appui long
    // désigne toujours ; fermer la fiche les rend.
    _surAndroid('Review Focus 4 — 360 × 640, 200 %, fiche station ouverte, en '
        'mode : ni bande ni réticule, Tab ne s’arrête pas sur le bouton, '
        'l’appui long désigne ; la fiche fermée, bande et réticule reviennent ; '
        '« Restrictions » reste allumée', (WidgetTester tester) async {
      final _CarteD3 carte = await _monterD3(
        tester,
        taille: const Size(360, 640),
        echelle: 2,
      );
      bool allumee() => tester
          .widget<Semantics>(find.byKey(mapDesignationChipKey))
          .properties
          .toggled!;
      final Finder bouton = find.byKey(mapDesignateCenterButtonKey);
      final Finder reticule = find.byKey(mapCenterReticleKey);

      final MapLayoutReport? rapport = _rapport(tester);
      expect(rapport, isNotNull);
      expect(
        rapport!.allocation.bandWithdrawn,
        isTrue,
        reason: 'le repli 6 ne joue pas : ${rapport.allocation}',
      );
      expect(rapport.reticle, isNull);
      expect(peintParLaCarte(tester, bouton), isFalse, reason: 'bande peinte');
      expect(peintParLaCarte(tester, reticule), isFalse, reason: 'réticule');
      expect(bouton.hitTestable(), findsNothing, reason: 'bouton touchable');
      expect(allumee(), isTrue);

      // Ni annoncé ni atteint par Tab. Contrôle positif : la tabulation
      // circule bien (elle atteint l'entrée « Restrictions »).
      expect(await annonces(tester), 0, reason: 'le bouton retiré est annoncé');
      final ({bool bouton, bool restrictions}) arrets = await tabulation(
        tester,
        bouton,
      );
      expect(arrets.bouton, isFalse, reason: 'Tab s’arrête sur le bouton');
      expect(arrets.restrictions, isTrue, reason: 'Tab ne circule pas');

      // L'appui long, dans l'écart de la rangée du bas (de la carte).
      final Rect filtres = tester.getRect(find.byKey(mapFiltersButtonKey));
      final Rect moins = tester.getRect(find.byKey(mapZoomOutButtonKey));
      expect(moins.left - filtres.right, greaterThan(16));
      final Offset p = Offset(
        (filtres.right + moins.left) / 2,
        filtres.center.dy,
      );
      await tester.longPressAt(p);
      await tester.pumpAndSettle();
      expect(carte.designated, hasLength(1));
      _expectClose(carte.designated.single, _pointAt(tester, p));

      // La fiche fermée : bande et réticule reviennent.
      carte.ficheOuverte.value = false;
      await tester.pumpAndSettle();
      final MapLayoutReport? ferme = _rapport(tester);
      expect(ferme?.allocation.bandWithdrawn, isFalse);
      expect(ferme?.reticle, isNotNull);
      expect(peintParLaCarte(tester, bouton), isTrue);
      expect(peintParLaCarte(tester, reticule), isTrue);
      expect(bouton.hitTestable(), findsOneWidget);
      expect(allumee(), isTrue);
      // Les contrôles positifs des deux assertions négatives : rendu, le
      // bouton est annoncé et Tab s'y arrête.
      expect(await annonces(tester), 1, reason: 'le bouton rendu est muet');
      expect(
        (await tabulation(tester, bouton)).bouton,
        isTrue,
        reason: 'Tab ne s’arrête pas sur le bouton rendu',
      );
      expect(tester.takeException(), isNull);
    });

    // Constat 1 de la relecture : + et − bornent le zoom AVANT de viser le
    // réticule. Un cran sans effet (zoom maximal ou minimal) ne bouge ni la
    // carte ni le point visé et ne recharge rien ; un cran raccourci par la
    // borne (17,5 → 18) garde le point sous le réticule. Le clavier passe par
    // le même chemin, sans regarder `canZoomIn` ni `canZoomOut`.
    for (final (String, _Test, Size) cas in <(String, _Test, Size)>[
      ('fiche du bas ouverte, 390 × 844', _surAndroid, const Size(390, 844)),
      ('panneau ouvert, 800 × 740', _surWindows, const Size(800, 740)),
    ]) {
      Future<_Stations> monterAuZoom(WidgetTester tester, double zoom) async {
        final _Stations stations = _Stations(const <StationPoint>[]);
        await _monterD3(tester, taille: cas.$3, stations: stations);
        gardes(tester, cas.$3);
        MapController.of(tester.element(find.byType(TileLayer)))
            .move(_camera(tester).center, zoom);
        await tester.pumpAndSettle();
        expect(_camera(tester).zoom, zoom);
        // Le focus sous les raccourcis de la carte : sans lui, une touche
        // n'atteint rien.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        stations.chargements = 0;
        return stations;
      }

      for (final (String, double, LogicalKeyboardKey) borne
          in <(String, double, LogicalKeyboardKey)>[
            ('maximal', maximumMapZoom, LogicalKeyboardKey.numpadAdd),
            ('minimal', minimumMapZoom, LogicalKeyboardKey.minus),
          ]) {
        cas.$2('${cas.$1}, en mode, au zoom ${borne.$1} : la touche '
            '« ${borne.$2 == maximumMapZoom ? '+' : '−'} » ne bouge ni la carte ni le point visé, '
            'et ne recharge rien', (WidgetTester tester) async {
          final _Stations stations = await monterAuZoom(tester, borne.$2);
          final MapCamera avant = _camera(tester);
          final GeoPoint vise = _pointSousLeReticule(tester);

          await tester.sendKeyEvent(borne.$3);
          await tester.pumpAndSettle();

          expect(_camera(tester).zoom, borne.$2);
          expect(_camera(tester).center, avant.center);
          _expectClose(_pointSousLeReticule(tester), vise);
          expect(stations.chargements, 0, reason: 'un rechargement');
        });
      }

      for (final (String, double, double, Future<void> Function(WidgetTester))
          cran
          in <(String, double, double, Future<void> Function(WidgetTester))>[
            (
              'le bouton +',
              maximumMapZoom - 0.5,
              maximumMapZoom,
              (WidgetTester t) => t.tap(find.byKey(mapZoomInButtonKey)),
            ),
            (
              'la touche +',
              maximumMapZoom - 0.5,
              maximumMapZoom,
              (WidgetTester t) => t.sendKeyEvent(LogicalKeyboardKey.numpadAdd),
            ),
            (
              'la touche −',
              minimumMapZoom + 0.5,
              minimumMapZoom,
              (WidgetTester t) => t.sendKeyEvent(LogicalKeyboardKey.minus),
            ),
          ]) {
        cas.$2('${cas.$1}, en mode, au zoom ${cran.$2} : ${cran.$1} amène au '
            'zoom ${cran.$3} et garde le point sous le réticule', (
          WidgetTester tester,
        ) async {
          await monterAuZoom(tester, cran.$2);
          final GeoPoint vise = _pointSousLeReticule(tester);

          await cran.$4(tester);
          await tester.pumpAndSettle();

          expect(_camera(tester).zoom, cran.$3);
          _expectClose(_pointSousLeReticule(tester), vise);
        });
      }
    }

    // Mineur 7 de la relecture : le repère du réticule est celui de la
    // caméra, marge système comprise (la carte va jusqu'aux bords, la mise en
    // page pose ses pièces dans la zone sûre). Une enveloppe posée plus tard
    // autour des surcouches seules (`SafeArea`, `Padding`) décalerait le
    // réticule sans que la caméra le suive : ce cas rougirait.
    for (final (String, _Test, Size, FakeViewPadding) cas
        in <(String, _Test, Size, FakeViewPadding)>[
          (
            '390 × 844, marges haute 24 et basse 34, fiche du bas ouverte',
            _surAndroid,
            const Size(390, 844),
            const FakeViewPadding(top: 24, bottom: 34),
          ),
          (
            '1 000 × 700, marge gauche 48, panneau ouvert',
            _surWindows,
            const Size(1000, 700),
            const FakeViewPadding(left: 48),
          ),
        ]) {
      cas.$2('${cas.$1}, en mode : le bouton désigne le point sous le '
          'réticule peint, et + le garde', (WidgetTester tester) async {
        final _CarteD3 carte = await _monterD3(
          tester,
          taille: cas.$3,
          marge: cas.$4,
        );
        gardes(tester, cas.$3);
        final MapLayoutReport rapport = _rapport(tester)!;
        expect(rapport.visible.left, cas.$4.left, reason: 'zone sûre à gauche');
        expect(rapport.visible.top, cas.$4.top, reason: 'zone sûre en haut');
        expect(
          tester.getCenter(find.byKey(mapCenterReticleKey)).dx,
          closeTo(rapport.visible.center.dx, 0.5),
        );

        await tester.tap(find.byKey(mapDesignateCenterButtonKey));
        await tester.pumpAndSettle();
        expect(carte.designated, hasLength(1));
        _expectClose(carte.designated.single, _pointSousLeReticule(tester));

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
        _expectClose(_pointSousLeReticule(tester), carte.designated.single);
      });
    }
  });
}

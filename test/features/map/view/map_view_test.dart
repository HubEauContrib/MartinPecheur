// Verrouille l'écran carte : le fond IGN est la première couche, les
// stations du viewport deviennent des marqueurs (T0-M4), et l'attribution
// Licence Ouverte est affichée en toutes lettres, sur son propre fond
// opaque. ⚠️ Aucun `FlutterMap` n'est rendu ici : les couches sont produites
// par une fonction PURE, testable sans déclencher de chargement de tuiles —
// refusé par l'environnement de test. La décision « cet événement
// déclenche-t-il un chargement ? » (`shouldRefreshOn`) est, elle aussi,
// testée sans widget.
//
// Le chargement lui-même n'est plus ici : il appartient au ViewModel
// (`test/features/map/view_model/map_view_model_test.dart`), qui le teste
// sans monter aucun widget (R3, arbitrage 2026-09-13).
import 'dart:async' show StreamSubscription;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart' show AreaLevel;
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show initialWarningTitle;
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show sheetFrameBodyKey;
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/ergonomie_fiches.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

StationPoint _blois() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074484784,
  longitude: 1.3351479476905552,
);

StationPoint _guadeloupe() => StationPoint(
  code: StationCode('1011000101'),
  label: 'Grande Rivière à Goyaves',
  latitude: 16.18940247103205,
  longitude: -61.65898959694908,
);

/// Dépôts vides, juste assez pour CONSTRUIRE un [MapViewModel] : les tests
/// qui les utilisent ne montent aucun widget et ne déclenchent donc aucun
/// chargement. Le comportement du ViewModel est verrouillé ailleurs
/// (`test/features/map/view_model/map_view_model_test.dart`).
final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

final class _EmptyHydroObservationRepository
    implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

final class _EmptyOndeObservationRepository
    implements OndeObservationRepository {
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

MapViewModel _viewModel() => MapViewModel(
  stationPoints: _EmptyStationPointRepository(),
  observations: _EmptyHydroObservationRepository(),
  onde: _EmptyOndeObservationRepository(),
);

/// Une caméra minimale, pour construire des `MapEvent` de test — sa valeur
/// n'importe pas pour [shouldRefreshOn], qui ne regarde que le type
/// runtime de l'événement.
MapCamera _testCamera() => MapCamera(
  crs: const Epsg3857(),
  center: const LatLng(initialMapCenterLatitude, initialMapCenterLongitude),
  zoom: initialMapZoom,
  rotation: 0,
  nonRotatedSize: const Size(800, 600),
);

/// Un point ONDE reel du referentiel, avec ses coordonnees : le meme que
/// l'exemple d'annonce de `04-ui.md` § 3.
OndePoint _leTrey() => OndePoint(
  code: OndeStationCode('04170001'),
  label: 'Le Trey à Vilcey-sur-Trey',
  latitude: 48.885312,
  longitude: 6.023145,
  waterCourseLabel: 'Le Trey',
  departement: const AdministrativeArea(code: '54', label: '54'),
);

OndePoint _laSeille() => OndePoint(
  code: OndeStationCode('04170002'),
  label: 'La Seille à Nomeny',
  latitude: 48.895,
  longitude: 6.242,
  waterCourseLabel: 'La Seille',
  departement: const AdministrativeArea(code: '54', label: '54'),
);

OndeObservation _observation(
  OndePoint point, {
  required FlowCategory category,
  required DateTime observedAt,
}) => OndeObservation(
  station: point.code,
  point: point,
  observedAt: observedAt,
  category: category,
  rawFlowCode: '3',
  officialLabel: 'Assec',
  campaignCode: '1',
);

/// Une observation ONDE quelconque : elle distingue « rien a dessiner »
/// de « quelque chose a dessiner » dans les cas d avis de `U6`.
Map<OndeStationCode, OndeObservation> _uneObservation() =>
    _byStation(<OndeObservation>[
      _observation(
        _leTrey(),
        category: const Assec(),
        observedAt: DateTime.utc(2026, 8, 25),
      ),
    ]);

Map<OndeStationCode, OndeObservation> _byStation(
  List<OndeObservation> observations,
) => <OndeStationCode, OndeObservation>{
  for (final OndeObservation observation in observations)
    observation.station: observation,
};

/// Un instant fixe, en UTC : `campaignAgeOf` compare des jours calendaires
/// et exige que `now` soit dans le meme fuseau que `observedAt`, que le
/// mapper rend en UTC (T-08).
DateTime _now() => DateTime.utc(2026, 9, 14);

/// `buildMapLayers` prend `ageOf` depuis H2 (l'âge se calcule maintenant sur
/// l'horloge du `MapViewModel`, `MapViewModel.ondeAgeOf`) — ce repli
/// reproduit ici, sans ViewModel, la même conversion en UTC que faisait la
/// vue.
CampaignAge Function(OndeObservation observation) _ageOf([
  DateTime Function() now = _now,
]) =>
    (OndeObservation observation) =>
        campaignAgeOf(observedAt: observation.observedAt, now: now().toUtc());

/// `ageOf` est **requis** par `buildMapLayers` (correction du 2026-09-23,
/// `H2`) — un repli constant y mentirait sur l'âge d'une campagne (`BR-010`).
/// Ce nom explicite documente les appels de ce fichier qui construisent
/// l'échelle « débit » ou une emprise sans observation ONDE : `ageOf` n'y
/// est JAMAIS invoqué, et cette fonction ne doit donc jamais être appelée —
/// si elle l'était, c'est qu'un test a changé de sens sans que son `ageOf`
/// explicite ait suivi.
CampaignAge _unusedAgeOf(OndeObservation observation) => throw StateError(
  'ageOf ne doit pas être appelé : ce test ne dessine aucun marqueur '
  "ONDE dont l'âge compte",
);

/// Le rapport de mise en page que `buildMapOverlays` publie (`D2` d'Ergonomie),
/// disposé à la fin du cas.
ValueNotifier<MapLayoutReport?> _rapport() {
  final ValueNotifier<MapLayoutReport?> rapport =
      ValueNotifier<MapLayoutReport?>(null);
  addTearDown(rapport.dispose);
  return rapport;
}

void main() {
  group('buildMapLayers', () {
    test('la première couche est le fond de tuiles IGN', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: const <StationPoint>[],
      );

      final Widget first = layers.first;
      expect(first, isA<TileLayer>());
      final TileLayer tileLayer = first as TileLayer;
      expect(tileLayer.urlTemplate, ignTileUrlTemplate);
      expect(tileLayer.tileDimension, ignTileDimension);
      expect(tileLayer.maxNativeZoom, ignMaxNativeZoom);
      // `userAgentPackageName` n'est pas un champ de `TileLayer` (lu dans le
      // paquet installé, flutter_map 8.3.2, tile_layer.dart ligne 264) : il
      // n'est utilisé que pour construire l'en-tête `User-Agent` du
      // `tileProvider` par défaut.
      expect(
        tileLayer.tileProvider.headers['User-Agent'],
        'flutter_map ($ignUserAgentPackageName)',
      );
    });

    test('sans stations, une seule couche est produite', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: const <StationPoint>[],
      );

      expect(layers, hasLength(1));
    });
  });

  // Le groupe « IgnAttributionBadge » vit désormais dans
  // `ign_attribution_badge_test.dart` — extrait par `K1` en même temps que
  // le widget lui-même (`lib/features/map/view/ign_attribution_badge.dart`).

  group('constantes de la carte', () {
    test('centre et zoom initiaux couvrent la France métropolitaine', () {
      expect(initialMapCenterLatitude, closeTo(46.6, 0.5));
      expect(initialMapCenterLongitude, closeTo(2.2, 0.5));
      expect(initialMapZoom, 5);
      expect(minimumMapZoom, lessThan(initialMapZoom));
      expect(maximumMapZoom, ignMaxNativeZoom);
    });
  });

  group('buildMapLayers — marqueurs de stations (T0-M4)', () {
    test('une station produit deux couches : TileLayer puis MarkerLayer', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      expect(layers, hasLength(2));
      expect(layers[0], isA<TileLayer>());
      expect(layers[1], isA<MarkerLayer>());
    });

    test('deux stations produisent deux marqueurs', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois(), _guadeloupe()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('le marqueur de Blois porte ses coordonnées exactes — attention à '
        "l'ordre GeoJSON [longitude, latitude], LatLng prend la latitude en "
        'premier', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.point.latitude, closeTo(47.584957074, 1e-9));
      expect(marker.point.longitude, closeTo(1.335147948, 1e-9));
    });

    test('chaque marqueur est carré, à minimumTapTarget — la ZONE DE '
        'TAP, pas la pastille — avec une pastille décorée dedans, jamais un '
        'glyphe de police', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.width, minimumTapTarget);
      expect(marker.height, minimumTapTarget);
      expect(marker.child, isNot(isA<Icon>()));
      expect(marker.child, isNot(isA<Text>()));
    });

    test("buildMapLayers ne refiltre plus : les stations passées sont toutes "
        'dessinées, marge comprise — le filtre fait foi côté dépôt '
        '(StationPointRepository)', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois(), _guadeloupe()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('une liste de stations vide ne produit qu\'une seule couche — la '
        "couche de marqueurs vide n'est pas ajoutée", () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: const <StationPoint>[],
      );

      expect(layers, hasLength(1));
    });
  });

  group('buildMapLayers — le tap sur un marqueur (T1-U1)', () {
    testWidgetsOnWindows(
      'le rappel onStationTap reçoit le code de la station tapée — '
      'le `child` du marqueur est rendu SEUL, jamais dans un FlutterMap',
      (WidgetTester tester) async {
        final List<StationCode> tapped = <StationCode>[];
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois(), _guadeloupe()],
          onStationTap: tapped.add,
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: minimumTapTarget,
                  height: minimumTapTarget,
                  child: markerLayer.markers[1].child,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(StationMarkerDot));
        await tester.pump();

        expect(tapped, hasLength(1));
        expect(tapped.single, StationCode('1011000101'));
      },
    );

    testWidgetsOnWindows(
      "le marqueur garde son action tap pour le lecteur d'écran — "
      'le geste est l ANCÊTRE du `Semantics`, que `excludeSemantics` ne '
      'masque donc pas (non-régression, relecture du 2026-09-23)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final List<StationCode> tapped = <StationCode>[];
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
          onStationTap: tapped.add,
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: minimumTapTarget,
                  height: minimumTapTarget,
                  child: markerLayer.markers.single.child,
                ),
              ),
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(StationMarkerDot),
        );
        // Le nœud atteint est bien celui du marqueur, pas un ancêtre fusionné.
        expect(node.label, contains('La Loire à Blois'));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(tapped, <StationCode>[StationCode('K447001001')]);

        handle.dispose();
      },
    );

    testWidgetsOnWindows(
      'sans rappel, le marqueur reste inerte — aucune exception au '
      'tap',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: minimumTapTarget,
                  height: minimumTapTarget,
                  child: markerLayer.markers.single.child,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(StationMarkerDot));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'la pastille garde sa taille de 12 px au centre de la zone '
      'de tap de 44',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: minimumTapTarget,
                  height: minimumTapTarget,
                  child: markerLayer.markers.single.child,
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(StationMarkerDot)),
          const Size(stationMarkerSize, stationMarkerSize),
        );
        // Centrée, et pas seulement de la bonne taille : (44 − 26) / 2 = 9 de
        // marge de chaque côté. Le `SizedBox` de test est posé en haut à
        // gauche, l'origine de la pastille est donc directement comparable.
        expect(
          tester.getTopLeft(find.byType(StationMarkerDot)),
          const Offset(9, 9),
        );
      },
    );
  });

  group('buildMapLayers — pastilles de zone administrative (Z4, ADR-015)', () {
    MapAreaCluster centreValDeLoire({int count = 15}) => MapAreaCluster(
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

    test(
      'au niveau région, une pastille par agrégat, plus les individuels',
      () {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.ecoulement,
          stations: const <StationPoint>[],
          clusters: <MapAreaCluster>[centreValDeLoire()],
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        expect(markerLayer.markers, hasLength(1));
        final Marker marker = markerLayer.markers.single;
        expect(marker.child, isA<GestureDetector>());
      },
    );

    test('les pastilles sont dessinées AVANT les marqueurs individuels', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
        clusters: <MapAreaCluster>[
          MapAreaCluster(
            scale: MapScaleKind.debit,
            level: AreaLevel.departement,
            area: const AdministrativeArea(code: '41', label: 'LOIR-ET-CHER'),
            latitude: 47.6,
            longitude: 1.3,
            count: 28,
            bounds: Bounds(west: 0.9, south: 47.3, east: 1.9, north: 48.1),
            severest: null,
            severestAge: null,
          ),
        ],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
      final GestureDetector premier =
          markerLayer.markers.first.child as GestureDetector;
      // `FocusTraversalOrder(KeyboardFocusRing(...))` (`K2`, 2026-09-23)
      // s'intercale désormais entre le `GestureDetector` et
      // `AreaClusterMarker` (focus clavier + ordre de tabulation du groupe
      // « carte ») — voir aussi le groupe « MapView — la sélection d une
      // pastille » plus bas dans ce fichier.
      final FocusTraversalOrder ordre = premier.child! as FocusTraversalOrder;
      expect(ordre.child, isA<KeyboardFocusRing>());
      expect(
        (ordre.child as KeyboardFocusRing).child,
        isA<AreaClusterMarker>(),
      );
    });

    test('niveau individuel (clusters vide) : aucune pastille', () {
      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(1));
      // Un marqueur de station porte `FocusTraversalOrder(GestureDetector(...))`
      // depuis `K2` (2026-09-23, arbitrage du commanditaire — ordre de
      // tabulation du groupe « carte ») : `Marker.child` n'est donc plus
      // directement un `GestureDetector`.
      final FocusTraversalOrder ordre =
          markerLayer.markers.single.child as FocusTraversalOrder;
      expect(
        (ordre.child as GestureDetector).child,
        isNot(isA<AreaClusterMarker>()),
      );
    });

    test('un tap appelle onClusterSelect une seule fois, avec la pastille — '
        "n'ouvre aucune fiche", () async {
      final List<MapAreaCluster> recus = <MapAreaCluster>[];
      final MapAreaCluster cluster = centreValDeLoire();
      bool stationTapAppele = false;
      bool ondeTapAppele = false;

      final List<Widget> layers = buildMapLayers(
        ageOf: _unusedAgeOf,
        scale: MapScaleKind.ecoulement,
        stations: const <StationPoint>[],
        clusters: <MapAreaCluster>[cluster],
        onClusterSelect: recus.add,
        onStationTap: (_) => stationTapAppele = true,
        onOndeTap: (_) => ondeTapAppele = true,
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final GestureDetector detecteur =
          markerLayer.markers.single.child as GestureDetector;
      detecteur.onTap!();

      expect(recus, <MapAreaCluster>[cluster]);
      expect(stationTapAppele, isFalse);
      expect(ondeTapAppele, isFalse);
    });
  });

  // `onStationTap` et `stationSheet` restent OPTIONNELS — la carte de T0
  // n'était pas interactive et ses tests les omettent toujours — mais ils ne
  // sont pas indépendants : une fiche sans tap ne s'ouvrirait jamais, un tap
  // sans fiche n'afficherait rien. L'assert transforme ce câblage à moitié
  // fait en échec immédiat, au lieu d'un écran silencieusement inerte.
  group('MapView — onStationTap et stationSheet vont ensemble', () {
    test('les deux absents : la carte de T0, non interactive', () {
      expect(() => MapView(viewModel: _viewModel()), returnsNormally);
    });

    test('les deux présents : le câblage complet de T1-U1', () {
      expect(
        () => MapView(
          viewModel: _viewModel(),
          onStationTap: (StationCode code) {},
          stationSheet: const SizedBox.shrink(),
        ),
        returnsNormally,
      );
    });

    test('un tap sans fiche lève : rien ne s afficherait', () {
      expect(
        () => MapView(
          viewModel: _viewModel(),
          onStationTap: (StationCode code) {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('une fiche sans tap lève : elle ne s ouvrirait jamais', () {
      expect(
        () => MapView(
          viewModel: _viewModel(),
          stationSheet: const SizedBox.shrink(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('buildMapLayers — l état de chaque station (T1-U2)', () {
    testWidgetsOnWindows(
      'la pastille rend l état que stateOf donne pour SA station',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
          stateOf: (StationCode code) => const SansDonnee(),
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: minimumTapTarget,
                height: minimumTapTarget,
                child: markerLayer.markers.single.child,
              ),
            ),
          ),
        );

        expect(
          tester.widget<StationMarkerDot>(find.byType(StationMarkerDot)).state,
          const SansDonnee(),
        );
      },
    );

    testWidgetsOnWindows(
      'stateOf est interrogé station par station : deux stations, '
      'deux états',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois(), _guadeloupe()],
          stateOf: (StationCode code) => code == StationCode('K447001001')
              ? const Chargee(Freshness.perimee)
              : const SansDonnee(),
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        for (final (int index, StationMapState expected) in <StationMapState>[
          const Chargee(Freshness.perimee),
          const SansDonnee(),
        ].indexed) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: minimumTapTarget,
                  height: minimumTapTarget,
                  child: markerLayer.markers[index].child,
                ),
              ),
            ),
          );

          expect(
            tester
                .widget<StationMarkerDot>(find.byType(StationMarkerDot))
                .state,
            expected,
          );
        }
      },
    );

    testWidgetsOnWindows(
      "l'annonce du marqueur NOMME la station, puis son état — "
      '« La Loire à Blois, Aucune donnée disponible ici. » ; un seul '
      'nœud sémantique par marqueur (04-ui.md § 3)',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
          stateOf: (StationCode code) => const SansDonnee(),
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: minimumTapTarget,
                height: minimumTapTarget,
                child: markerLayer.markers.single.child,
              ),
            ),
          ),
        );

        final Semantics semantics = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byType(StationMarkerDot),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          semantics.properties.label,
          startsWith('${mapScaleLabel(MapScaleKind.debit)} : '),
          reason: "l'annonce nomme l'echelle active en tete (BR-008)",
        );
        expect(semantics.properties.label, contains('La Loire à Blois'));
        expect(
          semantics.properties.label,
          contains(stationMapStateLabel(const SansDonnee())),
        );
        expect(semantics.properties.button, isTrue);
        expect(
          semantics.excludeSemantics,
          isTrue,
          reason:
              'la pastille garde son propre Semantics pour la légende ; sur '
              'la carte le marqueur le masque, sinon chaque station porterait '
              'deux nœuds',
        );
      },
    );

    testWidgetsOnWindows(
      "une station fraîche n'annonce QUE son nom : une mesure "
      "récente n'a pas de libellé d'état (BR-005, BR-007)",
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
          stateOf: (StationCode code) => const Chargee(Freshness.fraiche),
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: minimumTapTarget,
                height: minimumTapTarget,
                child: markerLayer.markers.single.child,
              ),
            ),
          ),
        );

        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byType(StationMarkerDot),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .label,
          '${mapScaleLabel(MapScaleKind.debit)} : La Loire à Blois',
        );
      },
    );

    testWidgetsOnWindows(
      'sans stateOf, toute station est NonChargee — jamais un état '
      'par défaut qui ressemblerait à une absence constatée (BR-007)',
      (WidgetTester tester) async {
        final List<Widget> layers = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: <StationPoint>[_blois()],
        );

        final MarkerLayer markerLayer = layers[1] as MarkerLayer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: minimumTapTarget,
                height: minimumTapTarget,
                child: markerLayer.markers.single.child,
              ),
            ),
          ),
        );

        expect(
          tester.widget<StationMarkerDot>(find.byType(StationMarkerDot)).state,
          const NonChargee(),
        );
      },
    );
  });

  group('buildMapOverlays — les surcouches, sans FlutterMap (T1-U2)', () {
    /// Rend les surcouches SEULES, dans un `Stack` : aucun `FlutterMap`
    /// n'est monté — l'environnement de test refuse le chargement de
    /// tuiles, et le câblage des surcouches n'a rien à voir avec lui.
    Future<void> pumpOverlays(
      WidgetTester tester, {
      MapScaleKind scale = MapScaleKind.ecoulement,
      void Function(MapScaleKind kind)? onSelect,
      VoidCallback? onWiden,
      Object? error,
      MapErrorSource? errorSource,
      List<StationPoint> stations = const <StationPoint>[],
      Map<OndeStationCode, OndeObservation> ondeObservations =
          const <OndeStationCode, OndeObservation>{},
      int ondeUnreadableRows = 0,
      Widget? stationSheet,
      Widget? ondeSheet,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                buildMapOverlays(
                  filterHidesEverything: false,
                  onClearFilters: () {},
                  filterActive: false,
                  onOpenFilters: () {},
                  scale: scale,
                  onSelect: onSelect ?? (MapScaleKind kind) {},
                  onWiden: onWiden ?? () {},
                  error: error,
                  errorSource: errorSource,
                  stations: stations,
                  ondeObservations: ondeObservations,
                  ondeUnreadableRows: ondeUnreadableRows,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                  stationSheet: stationSheet,
                  ondeSheet: ondeSheet,
                  layoutReport: _rapport(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgetsOnWindows(
      'la légende est présente QUEL QUE SOIT error — toujours '
      'visible, jamais repliée (BR-008)',
      (WidgetTester tester) async {
        for (final Object? error in <Object?>[null, StateError('panne')]) {
          await pumpOverlays(tester, error: error);

          expect(find.byType(MapLegend), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows("l'échelle passée est celle que la légende rend", (
      WidgetTester tester,
    ) async {
      for (final MapScaleKind scale in MapScaleKind.values) {
        await pumpOverlays(tester, scale: scale);

        expect(tester.widget<MapLegend>(find.byType(MapLegend)).scale, scale);
      }
    });

    testWidgetsOnWindows(
      "l'avis de panne n'est présent que si error != null, et il "
      'NOMME sa source (BR-007, U6)',
      (WidgetTester tester) async {
        await pumpOverlays(tester, ondeObservations: _uneObservation());
        expect(find.byType(SourceUnavailableNotice), findsNothing);

        await pumpOverlays(
          tester,
          error: StateError('Aucun asset'),
          errorSource: MapErrorSource.referentiel,
        );
        expect(find.byType(SourceUnavailableNotice), findsOneWidget);
        expect(
          tester
              .widget<SourceUnavailableNotice>(
                find.byType(SourceUnavailableNotice),
              )
              .sourceName,
          mapSourceName(MapErrorSource.referentiel),
        );
        expect(
          find.textContaining('Aucun asset'),
          findsNothing,
          reason:
              "la cause technique ne traverse pas l'avis : donnée de "
              "diagnostic, pas texte d'interface — même convention que les "
              'deux fiches',
        );
      },
    );

    testWidgetsOnWindows(
      "le panneau de fiche n'est présent que s'il est fourni",
      (WidgetTester tester) async {
        const Key sheet = Key('fiche');

        await pumpOverlays(tester);
        expect(find.byKey(sheet), findsNothing);

        await pumpOverlays(
          tester,
          stationSheet: const SizedBox.shrink(key: sheet),
        );
        expect(find.byKey(sheet), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      "le panneau ONDE n'est présent que s'il est fourni (T1-U4)",
      (WidgetTester tester) async {
        const Key onde = Key('fiche-onde');

        await pumpOverlays(tester);
        expect(find.byKey(onde), findsNothing);

        await pumpOverlays(tester, ondeSheet: const SizedBox.shrink(key: onde));
        expect(find.byKey(onde), findsOneWidget);
      },
    );

    // Les deux fiches dépendent d'échelles différentes et ne sont jamais
    // ouvertes ensemble en production ; l'empilement reste néanmoins défini
    // et testé, plutôt que laissé au hasard d'un `Stack`.
    testWidgetsOnWindows(
      'les deux panneaux fournis ensemble sont rendus TOUS LES DEUX, '
      "empilés, aucun n'écrase l'autre",
      (WidgetTester tester) async {
        const Key station = Key('fiche-station');
        const Key onde = Key('fiche-onde');

        await pumpOverlays(
          tester,
          stationSheet: const SizedBox(width: 10, height: 10, key: station),
          ondeSheet: const SizedBox(width: 10, height: 10, key: onde),
        );

        expect(find.byKey(station), findsOneWidget);
        expect(find.byKey(onde), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(station)).dy,
          lessThan(tester.getTopLeft(find.byKey(onde)).dy),
          reason: 'le panneau ONDE se pose SOUS le panneau station',
        );
      },
    );

    testWidgetsOnWindows(
      "l'attribution IGN est TOUJOURS présente — une condition "
      "d'usage de la Licence Ouverte, jamais une finition",
      (WidgetTester tester) async {
        for (final Object? error in <Object?>[null, StateError('panne')]) {
          await pumpOverlays(tester, error: error);

          expect(find.byType(IgnAttributionBadge), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows('le contrôle d\'avertissement est TOUJOURS présent, '
        'dans l\'en-tête, au-dessus de la légende, fiche ouverte ou non (W3c, '
        'R4)', (WidgetTester tester) async {
      final Finder dansLEnTete = find.descendant(
        of: find.byType(MapLegendHeader),
        matching: find.byType(WarningLink),
      );
      await pumpOverlays(tester);

      expect(find.byType(WarningLink), findsOneWidget);
      expect(dansLEnTete, findsOneWidget, reason: 'dans l\'en-tête de légende');
      expect(
        tester.getBottomLeft(find.byType(WarningLink)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MapLegend)).dy),
      );

      // R4 : une fiche ouverte ne l'ôte pas, et ne le recouvre pas.
      await pumpOverlays(
        tester,
        stationSheet: const SizedBox(height: 120, child: Text('fiche')),
      );
      expect(dansLEnTete, findsOneWidget, reason: 'fiche ouverte');
      expect(dansLEnTete.hitTestable(), findsOneWidget, reason: 'atteignable');
    });

    // Remplace « l'avis de panne ne recouvre jamais la légende » de
    // l'ancienne disposition (côte à côte) : dans le bloc de lecture, l'avis
    // est dans sa pièce, posée au-dessus de celle de la légende ; les deux
    // fenêtres ne se recoupent pas, même quand leur contenu défile.
    testWidgetsOnWindows(
      "l'avis de panne ne recouvre jamais la légende : il est dans les avis "
      "du bloc, au-dessus d'elle (BR-008, D2 d'Ergonomie)",
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          error: StateError('panne de lecture'),
          errorSource: MapErrorSource.referentiel,
        );

        expect(
          find.ancestor(
            of: find.byType(SourceUnavailableNotice),
            matching: find.byType(MapReadingBlockNotices),
          ),
          findsOneWidget,
        );
        expect(
          tester.getBottomLeft(find.byType(MapReadingBlockNotices)).dy,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byType(MapReadingBlockLegend)).dy,
          ),
        );
        expect(
          tester.getTopLeft(find.byType(SourceUnavailableNotice)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(MapLegend)).dy),
        );
      },
    );

    testWidgetsOnWindows(
      "le tap sur le contrôle d'avertissement ouvre la fenêtre "
      '(W3c)',
      (WidgetTester tester) async {
        await pumpOverlays(tester);

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningTitle), findsOneWidget);
      },
    );
  });

  group(
    'shouldRefreshOn — décide si un événement déclenche une requête d\'emprise',
    () {
      test('MapEventMoveEnd (fin de glisser) déclenche une requête', () {
        expect(
          shouldRefreshOn(
            MapEventMoveEnd(
              source: MapEventSource.dragEnd,
              camera: _testCamera(),
            ),
          ),
          isTrue,
        );
      });

      test(
        'MapEventFlingAnimationEnd (fin de fling) déclenche une requête',
        () {
          expect(
            shouldRefreshOn(
              MapEventFlingAnimationEnd(
                source: MapEventSource.flingAnimationController,
                camera: _testCamera(),
              ),
            ),
            isTrue,
          );
        },
      );

      test(
        "MapEventScrollWheelZoom déclenche une requête — pas de variante "
        "…End dans le paquet, chaque cran de molette est un geste complet",
        () {
          expect(
            shouldRefreshOn(
              MapEventScrollWheelZoom(
                source: MapEventSource.scrollWheel,
                oldCamera: _testCamera(),
                camera: _testCamera(),
              ),
            ),
            isTrue,
          );
        },
      );

      test(
        'MapEventDoubleTapZoomEnd (fin de double-tap) déclenche une requête',
        () {
          expect(
            shouldRefreshOn(
              MapEventDoubleTapZoomEnd(
                source: MapEventSource.doubleTapZoomAnimationController,
                camera: _testCamera(),
              ),
            ),
            isTrue,
          );
        },
      );

      test('MapEventRotateEnd (fin de rotation) déclenche une requête', () {
        expect(
          shouldRefreshOn(
            MapEventRotateEnd(
              source: MapEventSource.custom,
              camera: _testCamera(),
            ),
          ),
          isTrue,
        );
      });

      test("MapEventMove (geste en cours) ne déclenche aucune requête — la "
          'marge couvre le déplacement jusqu\'au relâcher', () {
        expect(
          shouldRefreshOn(
            MapEventMove(
              oldCamera: _testCamera(),
              camera: _testCamera(),
              source: MapEventSource.onDrag,
            ),
          ),
          isFalse,
        );
      });

      test(
        'MapEventMoveStart (début de glisser) ne déclenche aucune requête',
        () {
          expect(
            shouldRefreshOn(
              MapEventMoveStart(
                source: MapEventSource.dragStart,
                camera: _testCamera(),
              ),
            ),
            isFalse,
          );
        },
      );

      test('MapEventTap ne déclenche aucune requête', () {
        expect(
          shouldRefreshOn(
            MapEventTap(
              tapPosition: const LatLng(0, 0),
              source: MapEventSource.tap,
              camera: _testCamera(),
            ),
          ),
          isFalse,
        );
      });
    },
  );

  group('buildMapLayers — une seule famille de marqueurs par échelle '
      '(BR-008, T1-U3)', () {
    List<Widget> layersFor(
      MapScaleKind scale, {
      DateTime? observedAt,
      void Function(OndePoint point)? onOndeTap,
    }) => buildMapLayers(
      scale: scale,
      stations: <StationPoint>[_blois(), _guadeloupe()],
      ondeObservations: _byStation(<OndeObservation>[
        _observation(
          _leTrey(),
          category: const Assec(),
          observedAt: observedAt ?? DateTime.utc(2026, 9, 1),
        ),
        _observation(
          _laSeille(),
          category: const Ecoulement(),
          observedAt: observedAt ?? DateTime.utc(2026, 9, 1),
        ),
      ]),
      ageOf: _ageOf(),
      onOndeTap: onOndeTap,
    );

    Future<void> pumpMarkerChild(WidgetTester tester, Marker marker) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: minimumTapTarget,
                height: minimumTapTarget,
                child: marker.child,
              ),
            ),
          ),
        ),
      );
    }

    testWidgetsOnWindows(
      'échelle « débit » : aucun marqueur ONDE, même quand des '
      'observations sont en mémoire',
      (WidgetTester tester) async {
        final MarkerLayer markerLayer =
            layersFor(MapScaleKind.debit)[1] as MarkerLayer;

        expect(markerLayer.markers, hasLength(2));
        for (final Marker marker in markerLayer.markers) {
          await pumpMarkerChild(tester, marker);
          expect(find.byType(OndeMarkerShape), findsNothing);
          expect(find.byType(StationMarkerDot), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows(
      'échelle « écoulement » : aucun marqueur de station, même '
      'quand le référentiel est chargé',
      (WidgetTester tester) async {
        final MarkerLayer markerLayer =
            layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

        expect(markerLayer.markers, hasLength(2));
        for (final Marker marker in markerLayer.markers) {
          await pumpMarkerChild(tester, marker);
          expect(find.byType(StationMarkerDot), findsNothing);
          expect(find.byType(OndeMarkerShape), findsOneWidget);
        }
      },
    );

    test('le marqueur ONDE est posé sur les coordonnées de SON point', () {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.first;

      expect(marker.point.latitude, closeTo(48.885312, 1e-9));
      expect(marker.point.longitude, closeTo(6.023145, 1e-9));
    });

    test('la zone de tap d un marqueur ONDE mesure 44 pt (04-ui.md § 3)', () {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

      for (final Marker marker in markerLayer.markers) {
        expect(marker.width, minimumTapTarget);
        expect(marker.height, minimumTapTarget);
      }
    });

    test('une emprise sans observation ONDE ne dessine rien, et ne plante '
        'pas — le message hors couverture est l affaire de U6', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.ecoulement,
        stations: <StationPoint>[_blois()],
        ageOf: _ageOf(),
      );

      expect(layers, hasLength(1));
      expect(layers.single, isA<TileLayer>());
    });

    testWidgetsOnWindows('le tap d un marqueur ONDE rend SON point', (
      WidgetTester tester,
    ) async {
      final List<OndePoint> tapped = <OndePoint>[];
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement, onOndeTap: tapped.add)[1]
              as MarkerLayer;

      await pumpMarkerChild(tester, markerLayer.markers[1]);
      await tester.tap(find.byType(OndeMarkerShape));
      await tester.pump();

      expect(tapped, hasLength(1));
      expect(tapped.single.code, OndeStationCode('04170002'));
      expect(tapped.single.label, 'La Seille à Nomeny');
    });

    testWidgetsOnWindows(
      "le marqueur ONDE garde son action tap pour le lecteur "
      "d'écran — le geste est l ANCÊTRE du `Semantics` (non-régression, "
      'relecture du 2026-09-23)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final List<OndePoint> tapped = <OndePoint>[];
        final MarkerLayer markerLayer =
            layersFor(MapScaleKind.ecoulement, onOndeTap: tapped.add)[1]
                as MarkerLayer;

        await pumpMarkerChild(tester, markerLayer.markers[1]);

        final SemanticsNode node = tester.getSemantics(
          find.byType(OndeMarkerShape),
        );
        // Le nœud atteint est bien celui du marqueur, pas un ancêtre fusionné.
        expect(node.label, contains('La Seille à Nomeny'));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(tapped.single.code, OndeStationCode('04170002'));

        handle.dispose();
      },
    );

    testWidgetsOnWindows('sans rappel, le marqueur ONDE reste inerte — aucune '
        'exception au tap', (WidgetTester tester) async {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

      await pumpMarkerChild(tester, markerLayer.markers.first);
      await tester.tap(find.byType(OndeMarkerShape));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgetsOnWindows(
      "l'annonce d'un marqueur ONDE préfixe l'échelle active, puis "
      'la catégorie, le point et la date de campagne (BR-008, BR-010, '
      '04-ui.md § 3)',
      (WidgetTester tester) async {
        final MarkerLayer markerLayer =
            layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

        await pumpMarkerChild(tester, markerLayer.markers.first);

        final Semantics semantics = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byType(OndeMarkerShape),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          semantics.properties.label,
          '${mapScaleLabel(MapScaleKind.ecoulement)} : À sec — Le Trey à '
          'Vilcey-sur-Trey, campagne du 01/09/2026, observation visuelle '
          'ponctuelle',
        );
        expect(semantics.properties.button, isTrue);
        expect(
          semantics.excludeSemantics,
          isTrue,
          reason: 'un marqueur, un seul nœud sémantique',
        );
      },
    );

    testWidgetsOnWindows(
      'passé 60 jours, l annonce porte la date de la dernière '
      'observation et la forme vire au gris (BR-010)',
      (WidgetTester tester) async {
        // 2026-06-01 vu le 2026-09-14 : 105 jours calendaires.
        final MarkerLayer markerLayer =
            layersFor(
                  MapScaleKind.ecoulement,
                  observedAt: DateTime.utc(2026, 6, 1),
                )[1]
                as MarkerLayer;

        await pumpMarkerChild(tester, markerLayer.markers.first);

        expect(
          tester
              .widget<Semantics>(
                find
                    .ancestor(
                      of: find.byType(OndeMarkerShape),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .label,
          contains('dernière observation le 01/06/2026'),
        );
        expect(
          tester.widget<OndeMarkerShape>(find.byType(OndeMarkerShape)).age,
          CampaignAge.ancienne,
        );
      },
    );

    testWidgetsOnWindows("l'âge est calculé avec le `now` injecté, jamais avec "
        "l'horloge du poste — la même observation est récente ou ancienne "
        'selon la date de lecture', (WidgetTester tester) async {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.ecoulement,
        stations: const <StationPoint>[],
        ondeObservations: _byStation(<OndeObservation>[
          _observation(
            _leTrey(),
            category: const Assec(),
            observedAt: DateTime.utc(2026, 6, 1),
          ),
        ]),
        ageOf: _ageOf(() => DateTime.utc(2026, 6, 20)),
      );

      await pumpMarkerChild(tester, (layers[1] as MarkerLayer).markers.single);

      expect(
        tester.widget<OndeMarkerShape>(find.byType(OndeMarkerShape)).age,
        CampaignAge.recente,
      );
    });
  });

  group('buildMapOverlays — les avis d absence et de panne (T1-U6)', () {
    /// Rend les surcouches SEULES : aucun `FlutterMap`, comme partout
    /// ailleurs dans ce fichier.
    Future<void> pumpNotices(
      WidgetTester tester, {
      MapScaleKind scale = MapScaleKind.ecoulement,
      VoidCallback? onWiden,
      Object? error,
      MapErrorSource? errorSource,
      List<StationPoint> stations = const <StationPoint>[],
      Map<OndeStationCode, OndeObservation> ondeObservations =
          const <OndeStationCode, OndeObservation>{},
      int ondeUnreadableRows = 0,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                buildMapOverlays(
                  filterHidesEverything: false,
                  onClearFilters: () {},
                  filterActive: false,
                  onOpenFilters: () {},
                  scale: scale,
                  onSelect: (MapScaleKind kind) {},
                  onWiden: onWiden ?? () {},
                  error: error,
                  errorSource: errorSource,
                  stations: stations,
                  ondeObservations: ondeObservations,
                  ondeUnreadableRows: ondeUnreadableRows,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                  layoutReport: _rapport(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgetsOnWindows(
      "échelle débit et aucune station : la phrase dédiée de "
      "l'arbitrage du 2026-09-18, avec son action — « ni station ni "
      "point » affirmerait une lecture ONDE qui n'a pas eu lieu (BR-008)",
      (WidgetTester tester) async {
        await pumpNotices(tester, scale: MapScaleKind.debit);

        expect(find.byType(NoStationInAreaNotice), findsOneWidget);
        expect(find.byType(NoDataInAreaNotice), findsNothing);
        expect(find.byKey(widenSearchKey), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      "« Élargir la recherche » appelle le rappel reçu : la vue ne "
      'calcule aucune emprise (UC-001 A2)',
      (WidgetTester tester) async {
        int elargissements = 0;
        await pumpNotices(
          tester,
          scale: MapScaleKind.debit,
          onWiden: () => elargissements++,
        );

        // `D2` d'Ergonomie : à 800 × 600 en police de test, l'avis défile dans
        // le bloc (repli 3) ; l'action s'amène en vue avant d'être touchée.
        await tester.ensureVisible(find.byKey(widenSearchKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(widenSearchKey));
        await tester.pump();

        expect(elargissements, 1);
      },
    );

    testWidgetsOnWindows(
      'échelle écoulement, des stations mais aucune observation : '
      'le périmètre du réseau ONDE est nommé (UC-001 A5)',
      (WidgetTester tester) async {
        await pumpNotices(tester, stations: <StationPoint>[_blois()]);

        expect(find.byType(OutsideOndeCoverageNotice), findsOneWidget);
        expect(find.byType(NoDataInAreaNotice), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'des lignes ONDE illisibles : leur compte est dit (T-14)',
      (WidgetTester tester) async {
        await pumpNotices(
          tester,
          ondeObservations: _uneObservation(),
          ondeUnreadableRows: 3,
        );

        expect(
          tester
              .widget<UnreadableRowsNotice>(find.byType(UnreadableRowsNotice))
              .count,
          3,
        );
      },
    );

    testWidgetsOnWindows(
      'aucun avis quand la carte a de quoi parler d elle même',
      (WidgetTester tester) async {
        await pumpNotices(tester, ondeObservations: _uneObservation());

        expect(find.byType(NoDataInAreaNotice), findsNothing);
        expect(find.byType(NoStationInAreaNotice), findsNothing);
        expect(find.byType(OutsideOndeCoverageNotice), findsNothing);
        expect(find.byType(SourceUnavailableNotice), findsNothing);
        expect(find.byType(UnreadableRowsNotice), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "une panne ONDE n'efface pas les stations : les marqueurs de "
      "l'échelle débit sont toujours construits, et l'avis se pose "
      'par-dessus (UC-001 A4)',
      (WidgetTester tester) async {
        final List<StationPoint> stations = <StationPoint>[_blois()];
        final Object panne = StateError('ONDE indisponible');

        // Les marqueurs : `buildMapLayers` ne reçoit PAS l'erreur — c'est
        // structurellement ce qui garantit qu'une panne ne vide pas la carte.
        final List<Widget> couches = buildMapLayers(
          ageOf: _unusedAgeOf,
          scale: MapScaleKind.debit,
          stations: stations,
        );
        final MarkerLayer marqueurs = couches.whereType<MarkerLayer>().single;
        expect(marqueurs.markers, hasLength(1));

        // L'avis : rendu par-dessus, et il nomme l'écoulement.
        await pumpNotices(
          tester,
          scale: MapScaleKind.debit,
          stations: stations,
          error: panne,
          errorSource: MapErrorSource.ecoulement,
        );

        expect(
          tester
              .widget<SourceUnavailableNotice>(
                find.byType(SourceUnavailableNotice),
              )
              .sourceName,
          mapSourceName(MapErrorSource.ecoulement),
        );
        expect(
          find.byType(NoDataInAreaNotice),
          findsNothing,
          reason:
              'une panne explique l absence : « personne ne mesure ici » '
              'serait un constat que personne n a fait (BR-007)',
        );
        expect(
          find.byType(NoStationInAreaNotice),
          findsNothing,
          reason:
              'une panne parle seule, la phrase dédiée débit non plus ne l '
              'accompagne pas',
        );
      },
    );

    testWidgetsOnWindows(
      'la légende et les puces restent rendues sous un avis : une '
      'carte sans marqueur reste une carte (BR-008)',
      (WidgetTester tester) async {
        await pumpNotices(tester, scale: MapScaleKind.debit);

        expect(find.byType(MapLegend), findsOneWidget);
        expect(find.byType(MapReadingSelector), findsOneWidget);
        expect(find.byType(IgnAttributionBadge), findsOneWidget);
      },
    );
  });

  group('buildMapOverlays — les puces de bascule (T1-U3)', () {
    /// Une station est fournie : sans elle, l'écran rendrait en plus un avis
    /// d'absence, parasite pour un groupe qui ne parle que des puces.
    Future<void> pumpScaleOverlays(
      WidgetTester tester, {
      MapScaleKind scale = MapScaleKind.ecoulement,
      void Function(MapScaleKind kind)? onSelect,
      Object? error,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                buildMapOverlays(
                  filterHidesEverything: false,
                  onClearFilters: () {},
                  filterActive: false,
                  onOpenFilters: () {},
                  scale: scale,
                  onSelect: onSelect ?? (MapScaleKind kind) {},
                  onWiden: () {},
                  error: error,
                  errorSource: error == null
                      ? null
                      : MapErrorSource.referentiel,
                  stations: <StationPoint>[_blois()],
                  ondeObservations: _uneObservation(),
                  ondeUnreadableRows: 0,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                  layoutReport: _rapport(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgetsOnWindows('les puces sont rendues, avec l échelle active', (
      WidgetTester tester,
    ) async {
      await pumpScaleOverlays(tester, scale: MapScaleKind.debit);

      expect(
        tester
            .widget<MapReadingSelector>(find.byType(MapReadingSelector))
            .scale,
        MapScaleKind.debit,
      );
    });

    testWidgetsOnWindows(
      'les puces sont rendues MÊME en erreur : une carte en panne '
      "reste une carte dont on change l'échelle (BR-007)",
      (WidgetTester tester) async {
        await pumpScaleOverlays(tester, error: StateError('panne'));

        expect(find.byType(MapReadingSelector), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'le rappel passé aux surcouches est celui que les puces '
      'appellent',
      (WidgetTester tester) async {
        final List<MapScaleKind> selected = <MapScaleKind>[];
        await pumpScaleOverlays(
          tester,
          scale: MapScaleKind.ecoulement,
          onSelect: selected.add,
        );

        await tester.tap(
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        );
        await tester.pump();

        expect(selected, <MapScaleKind>[MapScaleKind.debit]);
      },
    );

    testWidgetsOnWindows('les puces ne recouvrent jamais la légende (BR-008)', (
      WidgetTester tester,
    ) async {
      await pumpScaleOverlays(tester, error: StateError('panne'));

      // Le sélecteur est dans la partie fixe du bloc, la légende dessous
      // (`D2` d’Ergonomie) : ils ne se recoupent jamais.
      expect(
        tester.getBottomLeft(find.byType(MapReadingSelector)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MapLegend)).dy),
      );
    });

    testWidgetsOnWindows(
      "l'avis de panne ne recouvre pas les puces : il se pose "
      'dessous',
      (WidgetTester tester) async {
        await pumpScaleOverlays(tester, error: StateError('panne'));

        expect(
          tester.getBottomLeft(find.byType(MapReadingSelector)).dy,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byType(SourceUnavailableNotice)).dy,
          ),
        );
      },
    );
  });

  // Depuis `U4`, `onOndeTap` et `ondeSheet` sont couplés comme leurs pendants
  // station : une fiche sans tap ne s'ouvrirait jamais, un tap sans fiche
  // n'afficherait rien. L'assert fait échouer tout de suite un câblage à
  // moitié fait, plutôt que de laisser un écran silencieusement inerte.
  group('MapView — onOndeTap et ondeSheet vont ensemble (U4)', () {
    test('les deux présents : le câblage complet de T1-U4', () {
      expect(
        () => MapView(
          viewModel: _viewModel(),
          onOndeTap: (OndePoint point) {},
          ondeSheet: const SizedBox.shrink(),
        ),
        returnsNormally,
      );
    });

    test('un tap ONDE sans fiche lève : rien ne s afficherait', () {
      expect(
        () => MapView(viewModel: _viewModel(), onOndeTap: (OndePoint point) {}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('une fiche ONDE sans tap lève : elle ne s ouvrirait jamais', () {
      expect(
        () => MapView(
          viewModel: _viewModel(),
          ondeSheet: const SizedBox.shrink(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('MapView — la sélection d une pastille recharge l emprise '
      '(relecture du coordinateur, Z4)', () {
    // Deux points ONDE de la MÊME région, très écartés (Ariège / Nord de
    // la Champagne) : leur emprise couvre plusieurs degrés, de sorte que
    // l'ajustement NATUREL de la caméra (`CameraFit.bounds`, sans plancher)
    // retombe SOUS le zoom 7 — exactement le bug relevé par le
    // coordinateur (Occitanie à 412 dp ≈ 6,83). Le plancher `minZoom`
    // (`zoomTargetFor`) doit le remonter à 7 pile, ce qui fait passer
    // `level` de région à département.
    //
    // ⚠️ **Rattachement SYNTHÉTIQUE, signalé comme tel** (relecture du
    // coordinateur) : l'Ariège (09) et les Ardennes (08) appartiennent en
    // réalité à deux régions différentes (Occitanie et Grand Est) ; ces deux
    // points leur sont ici arbitrairement affectés « Grand Est » pour
    // fabriquer un agrégat aux membres écartés, jamais un fait constaté sur
    // le référentiel — l'invariant `CLAUDE.md` sur les fixtures datées et
    // réelles ne s'applique qu'aux données vérifiées par appel, pas aux
    // valeurs synthétiques de ce test, mais mérite d'être dit explicitement.
    OndePoint pointNord() => OndePoint(
      code: OndeStationCode('05500001'),
      label: 'Point nord',
      latitude: 49.5,
      longitude: 4.5,
      waterCourseLabel: 'Ruisseau nord',
      departement: const AdministrativeArea(code: '08', label: 'ARDENNES'),
      region: const AdministrativeArea(code: '44', label: 'Grand Est'),
    );
    OndePoint pointSud() => OndePoint(
      code: OndeStationCode('05500002'),
      label: 'Point sud',
      latitude: 43.0,
      longitude: 1.5,
      waterCourseLabel: 'Ruisseau sud',
      departement: const AdministrativeArea(code: '09', label: 'ARIEGE'),
      region: const AdministrativeArea(code: '44', label: 'Grand Est'),
    );
    // Sans rattachement (BR-007) : reste un marqueur individuel à tous les
    // niveaux, jamais absorbé par la pastille de la région voisine.
    OndePoint pointSansRegion() => OndePoint(
      code: OndeStationCode('05500003'),
      label: 'Point sans région',
      latitude: initialMapCenterLatitude,
      longitude: initialMapCenterLongitude,
      waterCourseLabel: 'Ruisseau isolé',
      departement: null,
    );

    testWidgetsOnWindows(
      'pastille dessinée au démarrage ; seul le point non rattaché est '
      'individuel ; le tap fait passer le niveau de région à département '
      "et relance latestWithinBounds",
      (WidgetTester tester) async {
        final _SpyOndeObservationRepository onde =
            _SpyOndeObservationRepository(<OndeObservation>[
              _observation(
                pointNord(),
                category: const Assec(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
              _observation(
                pointSud(),
                category: const Assec(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
              _observation(
                pointSansRegion(),
                category: const Ecoulement(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
            ]);
        final MapViewModel viewModel = MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: onde,
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(viewModel.level, AreaLevel.region);
        expect(onde.callCount, 1);
        // (a) une pastille est dessinée
        expect(find.byType(AreaClusterMarker), findsOneWidget);
        // (b) seul le point non rattaché est dessiné en individuel — la
        // légende (`MapLegend`, toujours rendue, BR-008) porte ses PROPRES
        // `OndeMarkerShape` pour les six catégories : on ne cherche donc
        // que sous la couche de marqueurs de la carte.
        expect(
          find.descendant(
            of: find.byType(MarkerLayer),
            matching: find.byType(OndeMarkerShape),
          ),
          findsOneWidget,
        );

        // (c) tap sur la pastille : la caméra se déplace (Z4), et ce
        // déplacement doit désormais signaler un geste terminé au
        // ViewModel (relecture du coordinateur — sans elle, `level`
        // resterait bloqué à `region` malgré la caméra qui a bougé).
        // Le tap est invoqué directement sur le `GestureDetector` posé par
        // `_areaClusterMarkers` — `tester.tap()` par coordonnées échoue le
        // hit-test dans ce montage (l'empilement `flutter_map` place
        // d'autres `RenderPointerListener` au même point), sans rapport
        // avec le câblage vérifié ici.
        await _toucherLaPastille(tester);

        expect(viewModel.level, AreaLevel.departement);
        expect(onde.callCount, greaterThanOrEqualTo(2));
      },
    );

    testWidgetsOnWindows(
      'agrégat d un seul membre (CentreOn) : le tap ramène au niveau '
      'individuel (contre-relecture du coordinateur)',
      (WidgetTester tester) async {
        // Un seul membre : `AreaCluster.bounds` est plat (nul),
        // `zoomTargetFor` rend `CentreOn` — pas `CoverBounds`. La cible est
        // `individualMarkersFromZoom` (9) : `_handleClusterSelect` doit
        // l'appliquer via `MapController.move`, puis signaler le geste au
        // ViewModel comme pour `CoverBounds`.
        final _SpyOndeObservationRepository onde =
            _SpyOndeObservationRepository(<OndeObservation>[
              _observation(
                pointNord(),
                category: const Assec(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
            ]);
        final MapViewModel viewModel = MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: onde,
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(viewModel.level, AreaLevel.region);
        expect(find.byType(AreaClusterMarker), findsOneWidget);

        await _toucherLaPastille(tester);

        // Niveau individuel : `levelFor(9)` rend `null` — c'est bien vers
        // `individualMarkersFromZoom` que `CentreOn` a déplacé la caméra.
        expect(viewModel.level, isNull);
      },
    );

    // `D4` d'Ergonomie (arbitrage 12, spec § 5.2, `ADR-015`) : cadrer une
    // pastille se fait dans la carte visible, fiche du bas ouverte.
    // Deux points voisins d'une même région, l'un au nord de l'autre : leur
    // emprise, plus haute que large, remplit la hauteur de la caméra si le
    // cadrage ignore la fiche — et le point sud tombe dessous.
    OndePoint pointVoisin(String code, double latitude, double longitude) =>
        OndePoint(
          code: OndeStationCode(code),
          label: 'Point $code',
          latitude: latitude,
          longitude: longitude,
          waterCourseLabel: 'Ruisseau $code',
          departement: const AdministrativeArea(code: '45', label: 'LOIRET'),
          region: const AdministrativeArea(
            code: '24',
            label: 'Centre-Val de Loire',
          ),
        );

    testWidgetsOnWindows(
      'D4 : fiche du bas ouverte à 700 × 740, la pastille sélectionnée '
      '(CoverBounds) — l emprise des membres est dans la carte visible',
      (WidgetTester tester) async {
        final OndePoint nord = pointVoisin('05500011', 47.6, 2.2);
        final OndePoint sud = pointVoisin('05500012', 46.8, 2.3);
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(true);
        addTearDown(ouverte.dispose);
        final MapViewModel viewModel = await _monterAvecFiche(
          tester,
          taille: const Size(700, 740),
          ouverte: ouverte,
          onde: _SpyOndeObservationRepository(<OndeObservation>[
            for (final OndePoint p in <OndePoint>[nord, sud])
              _observation(
                p,
                category: const Assec(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
          ]),
        );
        expect(viewModel.level, AreaLevel.region);
        final Rect visible = _carteVisibleReduite(tester, const Size(700, 740));

        await _toucherLaPastille(tester);

        final MapCamera camera = _mapCamera(tester);
        for (final OndePoint p in <OndePoint>[nord, sud]) {
          final Offset ecran = camera.latLngToScreenOffset(
            LatLng(p.latitude, p.longitude),
          );
          expect(
            visible.inflate(0.5).contains(ecran),
            isTrue,
            reason: '${p.label} en $ecran, hors de la carte visible $visible',
          );
        }
      },
    );

    testWidgetsOnWindows(
      'D4 : fiche du bas ouverte à 700 × 740, la pastille d un seul membre '
      '(CentreOn) — le membre au centre de la carte visible, zoom 9',
      (WidgetTester tester) async {
        final OndePoint seul = pointVoisin('05500013', 47.2, 2.25);
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(true);
        addTearDown(ouverte.dispose);
        await _monterAvecFiche(
          tester,
          taille: const Size(700, 740),
          ouverte: ouverte,
          onde: _SpyOndeObservationRepository(<OndeObservation>[
            _observation(
              seul,
              category: const Assec(),
              observedAt: DateTime.utc(2026, 9, 1),
            ),
          ]),
        );
        final Rect visible = _carteVisibleReduite(tester, const Size(700, 740));

        await _toucherLaPastille(tester);

        final MapCamera camera = _mapCamera(tester);
        expect(camera.zoom, individualMarkersFromZoom);
        final Offset ecran = camera.latLngToScreenOffset(
          LatLng(seul.latitude, seul.longitude),
        );
        expect(ecran.dx, closeTo(visible.center.dx, 0.5));
        expect(ecran.dy, closeTo(visible.center.dy, 0.5));
      },
    );
  });

  group('MapView — échelle débit, contre-relecture du coordinateur '
      '(seuls les non-rattachés sont des marqueurs individuels)', () {
    testWidgetsOnWindows(
      'zoom 5, niveau région : une pastille pour la station rattachée, '
      'un seul StationMarkerDot individuel pour la station sans région',
      (WidgetTester tester) async {
        final _StationsStub stations = _StationsStub(<StationPoint>[
          StationPoint(
            code: StationCode('K000000001'),
            label: 'Station rattachée',
            latitude: 46.7,
            longitude: 2.1,
            region: const AdministrativeArea(
              code: '24',
              label: 'Centre-Val de Loire',
            ),
          ),
          StationPoint(
            code: StationCode('K000000002'),
            label: 'Station sans région',
            latitude: initialMapCenterLatitude,
            longitude: initialMapCenterLongitude,
          ),
        ]);
        final MapViewModel viewModel = MapViewModel(
          stationPoints: stations,
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        // `loadFor` (appelé par `start`) charge `_stations` quelle que
        // soit l'échelle active au démarrage (`ecoulement`) : basculer
        // vers `débit` ne fait que changer la famille de marqueurs
        // dessinée, pas relire `withinBounds`.
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        expect(viewModel.level, AreaLevel.region);
        expect(find.byType(AreaClusterMarker), findsOneWidget);
        // Seule la station SANS région est un marqueur individuel — la
        // légende (`MapLegend`, BR-008) porte sa PROPRE pastille de
        // référence, hors `MarkerLayer`.
        expect(
          find.descendant(
            of: find.byType(MarkerLayer),
            matching: find.byType(StationMarkerDot),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('MapView — les boutons de zoom (K1) réutilisent EXACTEMENT le '
      'mécanisme de la sélection de pastille : onGestureEnded avec '
      'emprise et zoom résultants, franchissement des seuils ADR-015', () {
    /// Une seule station, avec un département — assez pour que le
    /// regroupement départemental (`ADR-015`) ne soit jamais vide entre les
    /// zooms 7 et 9, et assez pour que le préchargement de l'échelle débit
    /// ait un destinataire au niveau individuel.
    _StationsStub uneStationAvecDepartement() => _StationsStub(<StationPoint>[
      StationPoint(
        code: StationCode('K000000001'),
        label: 'Station de test',
        latitude: initialMapCenterLatitude,
        longitude: initialMapCenterLongitude,
        departement: const AdministrativeArea(code: '45', label: 'Loiret'),
      ),
    ]);

    testWidgetsOnWindows(
      "au zoom maximal, + est désactivé (Semantics.enabled faux) ; au "
      'zoom minimal, − l est — le test passe par le rendu de MapControls, '
      'pas seulement par MapViewModel.canZoomIn/canZoomOut',
      (WidgetTester tester) async {
        final MapViewModel viewModel = MapViewModel(
          stationPoints: uneStationAvecDepartement(),
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        // Au zoom initial (5), les deux boutons restent actifs.
        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomInButtonKey))
              .properties
              .enabled,
          isTrue,
        );
        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomOutButtonKey))
              .properties
              .enabled,
          isTrue,
        );

        await viewModel.onGestureEnded(
          MapViewModel.startupBounds,
          zoom: maximumMapZoom,
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomInButtonKey))
              .properties
              .enabled,
          isFalse,
          reason: 'zoom maximal : + ne doit plus rien pouvoir demander',
        );
        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomOutButtonKey))
              .properties
              .enabled,
          isTrue,
        );

        await viewModel.onGestureEnded(
          MapViewModel.startupBounds,
          zoom: minimumMapZoom,
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Semantics>(find.byKey(mapZoomOutButtonKey))
              .properties
              .enabled,
          isFalse,
          reason: 'zoom minimal : − ne doit plus rien pouvoir demander',
        );
      },
    );

    testWidgetsOnWindows(
      '+ deux fois depuis le zoom initial (5) atteint 7 : level passe de '
      'region à departement',
      (WidgetTester tester) async {
        final MapViewModel viewModel = MapViewModel(
          stationPoints: uneStationAvecDepartement(),
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        expect(viewModel.level, AreaLevel.region);

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
        expect(viewModel.zoom, 6);
        expect(viewModel.level, AreaLevel.region);

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
        expect(viewModel.zoom, 7);
        expect(viewModel.level, AreaLevel.departement);
      },
    );

    testWidgetsOnWindows(
      '+ depuis le zoom 8 atteint 9 : clusters vide (niveau individuel) et '
      'le préchargement de la station visible est lancé',
      (WidgetTester tester) async {
        final _SpyHydroObservationRepository observations =
            _SpyHydroObservationRepository();
        final MapViewModel viewModel = MapViewModel(
          stationPoints: uneStationAvecDepartement(),
          observations: observations,
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        // zoom 5 -> 6 -> 7 -> 8 : trois taps, toujours regroupé.
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(mapZoomInButtonKey));
          await tester.pumpAndSettle();
        }
        expect(viewModel.zoom, 8);
        expect(viewModel.level, AreaLevel.departement);
        expect(observations.callCount, 0, reason: 'toujours regroupé');

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();

        expect(viewModel.zoom, 9);
        expect(viewModel.level, isNull);
        expect(viewModel.clusters, isEmpty);
        expect(
          observations.callCount,
          1,
          reason: 'niveau individuel : la station visible est préchargée',
        );
      },
    );

    testWidgetsOnWindows(
      '− depuis le zoom 9 revient à 8 : pastilles départementales '
      'revenues, aucun nouvel appel findLatest',
      (WidgetTester tester) async {
        final _SpyHydroObservationRepository observations =
            _SpyHydroObservationRepository();
        final MapViewModel viewModel = MapViewModel(
          stationPoints: uneStationAvecDepartement(),
          observations: observations,
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        // zoom 5 -> ... -> 9 : quatre taps, niveau individuel, un
        // préchargement.
        for (int i = 0; i < 4; i++) {
          await tester.tap(find.byKey(mapZoomInButtonKey));
          await tester.pumpAndSettle();
        }
        expect(viewModel.zoom, 9);
        expect(viewModel.level, isNull);
        final int callsAtZoomNeuf = observations.callCount;
        expect(callsAtZoomNeuf, 1);

        await tester.tap(find.byKey(mapZoomOutButtonKey));
        await tester.pumpAndSettle();

        expect(viewModel.zoom, 8);
        expect(viewModel.level, AreaLevel.departement);
        expect(viewModel.clusters, isNotEmpty);
        expect(
          observations.callCount,
          callsAtZoomNeuf,
          reason: 'de retour au niveau regroupé, aucun findLatest de plus',
        );
      },
    );

    testWidgetsOnWindows(
      'le recentrage ramène au zoom de démarrage (5) : niveau région',
      (WidgetTester tester) async {
        final MapViewModel viewModel = MapViewModel(
          stationPoints: uneStationAvecDepartement(),
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        for (int i = 0; i < 4; i++) {
          await tester.tap(find.byKey(mapZoomInButtonKey));
          await tester.pumpAndSettle();
        }
        expect(viewModel.level, isNull);

        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pumpAndSettle();

        expect(viewModel.zoom, initialMapZoom);
        expect(viewModel.level, AreaLevel.region);
      },
    );

    testWidgetsOnWindows(
      'le recentrage ramène aussi le CENTRE (pas seulement le zoom) — '
      "arbitrage du coordinateur du 2026-09-23 : un recentrage décalé "
      "en latitude/longitude ne serait pas un recentrage",
      (WidgetTester tester) async {
        final _BoundsSpyStationsStub stations = _BoundsSpyStationsStub(
          <StationPoint>[
            StationPoint(
              code: StationCode('K000000001'),
              label: 'Station de test',
              latitude: initialMapCenterLatitude,
              longitude: initialMapCenterLongitude,
              departement: const AdministrativeArea(
                code: '45',
                label: 'Loiret',
              ),
            ),
          ],
        );
        final MapViewModel viewModel = MapViewModel(
          stationPoints: stations,
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();

        // Un zoom avant pour bouger la caméra, avant de vérifier que le
        // recentrage la ramène au bon endroit.
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pumpAndSettle();

        final Bounds? lastBounds = stations.lastBounds;
        expect(lastBounds, isNotNull);
        final double centreLatitude =
            (lastBounds!.south + lastBounds.north) / 2;
        final double centreLongitude = (lastBounds.west + lastBounds.east) / 2;
        // ⚠️ La projection Web Mercator (`Epsg3857`) n'est PAS symétrique en
        // latitude : la moyenne des bords nord/sud d'une emprise s'écarte du
        // centre réel de la caméra de quelques dixièmes de degré (mesuré :
        // ≈ 0,73° à 46,6° N). La tolérance reste bien en-dessous d'un
        // décalage de plusieurs degrés — ce qu'une régression romprait — sans
        // exiger une précision que la projection ne permet pas ici. La
        // longitude, elle, N'EST PAS déformée par Mercator (l'axe X reste
        // linéaire) : sa tolérance reste serrée.
        expect(centreLatitude, closeTo(initialMapCenterLatitude, 1.5));
        expect(centreLongitude, closeTo(initialMapCenterLongitude, 0.01));
      },
    );

    // `D4` d'Ergonomie (arbitrage 12, spec § 5.2) : recentrer et zoomer
    // tiennent compte de la partie de la carte que la fiche cache.
    testWidgetsOnWindows(
      'D4 : recentrer, panneau ouvert à 1 280 × 740 — (46,6 ; 2,2) au centre '
      'de la carte visible, zoom 5',
      (WidgetTester tester) async {
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(true);
        addTearDown(ouverte.dispose);
        await _monterAvecFiche(
          tester,
          taille: const Size(1280, 740),
          ouverte: ouverte,
        );
        final Rect visible = _carteVisibleReduite(
          tester,
          const Size(1280, 740),
        );

        // La caméra bouge d'abord : un cran de zoom.
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pumpAndSettle();

        final MapCamera camera = _mapCamera(tester);
        expect(camera.zoom, initialMapZoom);
        final LatLng auCentre = camera.screenOffsetToLatLng(visible.center);
        expect(auCentre.latitude, closeTo(initialMapCenterLatitude, 1e-3));
        expect(auCentre.longitude, closeTo(initialMapCenterLongitude, 1e-3));
      },
    );

    testWidgetsOnWindows(
      'sans fiche, recentrer au démarrage sans avoir bougé : aucun '
      'MapEventMove, aucun appel de plus aux dépôts (D4, identique à avant)',
      (WidgetTester tester) async {
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(false);
        addTearDown(ouverte.dispose);
        final _CountingStations stations = _CountingStations(<StationPoint>[
          _blois(),
        ]);
        final _SpyHydroObservationRepository observations =
            _SpyHydroObservationRepository();
        final _SpyOndeObservationRepository onde =
            _SpyOndeObservationRepository(const <OndeObservation>[]);
        await _monterAvecFiche(
          tester,
          taille: const Size(1280, 740),
          ouverte: ouverte,
          stations: stations,
          observations: observations,
          onde: onde,
        );
        final List<MapEventMove> deplacements = _ecouterLesDeplacements(tester);
        final MapCamera avant = _mapCamera(tester);
        final (int, int, int) appelsAvant = (
          stations.callCount,
          observations.callCount,
          onde.callCount,
        );

        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pumpAndSettle();

        expect(deplacements, isEmpty, reason: 'la caméra a bougé');
        expect(_mapCamera(tester).center, avant.center);
        expect(_mapCamera(tester).zoom, avant.zoom);
        expect(
          (stations.callCount, observations.callCount, onde.callCount),
          appelsAvant,
          reason: 'un dépôt a été rappelé',
        );
      },
    );

    testWidgetsOnWindows(
      'sans fiche, hors mode, + puis − puis recentrer : le centre revient '
      'égal à l initial, et le recentrage n émet aucun MapEventMove',
      (WidgetTester tester) async {
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(false);
        addTearDown(ouverte.dispose);
        await _monterAvecFiche(
          tester,
          taille: const Size(1280, 740),
          ouverte: ouverte,
        );
        final MapCamera initiale = _mapCamera(tester);

        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(mapZoomOutButtonKey));
        await tester.pumpAndSettle();
        expect(_mapCamera(tester).center, initiale.center);
        expect(_mapCamera(tester).zoom, initiale.zoom);

        final List<MapEventMove> deplacements = _ecouterLesDeplacements(tester);
        await tester.tap(find.byKey(mapRecenterButtonKey));
        await tester.pumpAndSettle();

        expect(deplacements, isEmpty, reason: 'le recentrage a bougé');
        expect(_mapCamera(tester).center, initiale.center);
      },
    );

    testWidgetsOnWindows(
      'D4 : + et −, fiche du bas ouverte à 700 × 740 — le point au centre de '
      'la carte visible est le même avant et après',
      (WidgetTester tester) async {
        final ValueNotifier<bool> ouverte = ValueNotifier<bool>(true);
        addTearDown(ouverte.dispose);
        await _monterAvecFiche(
          tester,
          taille: const Size(700, 740),
          ouverte: ouverte,
        );
        final Rect visible = _carteVisibleReduite(tester, const Size(700, 740));

        for (final Key bouton in <Key>[
          mapZoomInButtonKey,
          mapZoomOutButtonKey,
        ]) {
          final double zoomAvant = _mapCamera(tester).zoom;
          final LatLng avant = _mapCamera(tester)
              .screenOffsetToLatLng(visible.center);

          await tester.tap(find.byKey(bouton));
          await tester.pumpAndSettle();

          final MapCamera camera = _mapCamera(tester);
          expect(camera.zoom, isNot(zoomAvant), reason: '$bouton sans effet');
          final LatLng apres = camera.screenOffsetToLatLng(visible.center);
          expect(apres.latitude, closeTo(avant.latitude, 1e-6));
          expect(apres.longitude, closeTo(avant.longitude, 1e-6));
        }
      },
    );
  });

  // `D4` d'Ergonomie, critère 9 (spec § 9) et arbitrage 12 : la carte ne
  // bouge pas quand une fiche s'ouvre, défile ou se ferme.
  group('MapView — critère 9, la carte ne bouge pas sous une fiche (D4 d’Ergonomie)', () {
    // Le texte à 200 % à 1 280 × 740 : la fiche de Blois, en police de test,
    // tient sinon dans le panneau de 740 px et ne défile pas.
    for (final (Size, double) cas in <(Size, double)>[
      (const Size(700, 740), 1),
      (const Size(1280, 740), 2),
    ]) {
      final Size taille = cas.$1;
      testWidgetsOnWindows(
        'à ${taille.width.toInt()} × ${taille.height.toInt()}, texte à '
        '${(cas.$2 * 100).round()} %, la fiche défilée à la molette puis au '
        'glisser : aucun appel de plus aux dépôts, aucun MapEventMove, la '
        'caméra inchangée',
        (WidgetTester tester) async {
          final ValueNotifier<bool> ouverte = ValueNotifier<bool>(false);
          addTearDown(ouverte.dispose);
          final _CountingStations stations = _CountingStations(<StationPoint>[
            _blois(),
          ]);
          final _SpyHydroObservationRepository observations =
              _SpyHydroObservationRepository();
          final _SpyOndeObservationRepository onde =
              _SpyOndeObservationRepository(const <OndeObservation>[]);
          await _monterAvecFiche(
            tester,
            taille: taille,
            echelle: cas.$2,
            ouverte: ouverte,
            stations: stations,
            observations: observations,
            onde: onde,
          );
          final List<MapEventMove> deplacements = _ecouterLesDeplacements(
            tester,
          );
          final MapCamera avant = _mapCamera(tester);
          final (int, int, int) appelsAvant = (
            stations.callCount,
            observations.callCount,
            onde.callCount,
          );

          ouverte.value = true;
          await tester.pumpAndSettle();
          // Garde-fous : la fiche est ouverte, réduit la carte visible, et
          // son corps défile (`D5` : la zone ne défile plus, le corps du cadre
          // défile sous l'en-tête épinglé).
          _carteVisibleReduite(tester, taille);
          final ScrollableState defilement = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(sheetFrameBodyKey),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            defilement.position.maxScrollExtent,
            greaterThan(0),
            reason: 'le corps de la fiche doit être plus haut que sa place',
          );
          // De vrais gestes posés sur le corps de la fiche : une molette, puis
          // un glisser.
          final Rect corps = tester.getRect(find.byKey(sheetFrameBodyKey));
          expect(corps.height, greaterThan(0), reason: 'le corps a une place');
          final Offset surLaFiche = corps.center;
          final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(souris.hover(surLaFiche));
          await tester.sendEventToBinding(souris.scroll(const Offset(0, 120)));
          await tester.pumpAndSettle();
          final double apresMolette = defilement.position.pixels;
          expect(
            apresMolette,
            greaterThan(0),
            reason: 'la molette n’a rien fait',
          );
          // Le glisser remonte le corps : depuis `D7`, la fiche du bas garde
          // sa mesure mise en avant (arbitrage 18) et son corps a moins à
          // défiler — la molette peut l'avoir mené au bout.
          await tester.dragFrom(surLaFiche, const Offset(0, 60));
          await tester.pumpAndSettle();
          expect(
            defilement.position.pixels,
            lessThan(apresMolette),
            reason: 'le glisser n’a rien fait',
          );
          ouverte.value = false;
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(deplacements, isEmpty, reason: 'la carte a bougé');
          final MapCamera apres = _mapCamera(tester);
          expect(apres.center, avant.center);
          expect(apres.zoom, avant.zoom);
          expect(
            (stations.callCount, observations.callCount, onde.callCount),
            appelsAvant,
            reason: 'un dépôt a été rappelé',
          );
        },
      );
    }
  });

  group('MapView — un filtre qui masque tout (F8 de T3)', () {
    /// Deux points ONDE sans région : ils restent des marqueurs individuels à
    /// tous les niveaux, donc dessinés dès le démarrage.
    List<OndeObservation> deuxAssecs() => <OndeObservation>[
      _observation(
        _leTrey(),
        category: const Assec(),
        observedAt: DateTime.utc(2026, 9, 1),
      ),
      _observation(
        _laSeille(),
        category: const Assec(),
        observedAt: DateTime.utc(2026, 9, 1),
      ),
    ];

    Finder marqueursOnde() => find.descendant(
      of: find.byType(MarkerLayer),
      matching: find.byType(OndeMarkerShape),
    );

    final MapFilter sansAssec = MapFilter.none.withCategory(
      const Assec(),
      shown: false,
    );

    testWidgetsOnWindows(
      "deux Assec lus, la case « À sec » décochée : l'avis des filtres "
      "s'affiche seul ; « Effacer les filtres » le retire, ramène le filtre "
      'à MapFilter.none et redessine les deux marqueurs',
      (WidgetTester tester) async {
        final MapViewModel viewModel = MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: _SpyOndeObservationRepository(deuxAssecs()),
        );
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        expect(marqueursOnde(), findsNWidgets(2));
        expect(find.text(filterHidesEverythingText), findsNothing);

        viewModel.applyFilter(sansAssec);
        await tester.pumpAndSettle();

        expect(find.text(filterHidesEverythingText), findsOneWidget);
        expect(find.byKey(clearFiltersKey), findsOneWidget);
        expect(marqueursOnde(), findsNothing);
        expect(find.byType(NoDataInAreaNotice), findsNothing);
        expect(find.byType(OutsideOndeCoverageNotice), findsNothing);
        expect(find.text(widenSearchLabel), findsNothing);

        await tester.tap(find.byKey(clearFiltersKey));
        await tester.pumpAndSettle();

        expect(find.text(filterHidesEverythingText), findsNothing);
        expect(viewModel.filter, MapFilter.none);
        expect(marqueursOnde(), findsNWidgets(2));
      },
    );

    testWidgetsOnWindows(
      'une panne ONDE après un balayage dont le filtre masque tout : seul '
      "l'avis de la source tombée est affiché (une panne parle seule)",
      (WidgetTester tester) async {
        final _SwitchableOndeObservationRepository onde =
            _SwitchableOndeObservationRepository(deuxAssecs());
        final MapViewModel viewModel = MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: onde,
        );
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.applyFilter(sansAssec);
        await tester.pumpAndSettle();
        expect(find.text(filterHidesEverythingText), findsOneWidget);

        onde.fail = true;
        await viewModel.widenSearch();
        await tester.pumpAndSettle();

        expect(viewModel.error, isNotNull);
        expect(viewModel.filterHidesEverything, isTrue);
        expect(find.byType(SourceUnavailableNotice), findsOneWidget);
        expect(find.text(filterHidesEverythingText), findsNothing);
        expect(find.byKey(clearFiltersKey), findsNothing);
      },
    );
  });

  // Le bouton « Favoris » (`S10` de T3, arbitrage 8 du cadrage de T3). La
  // carte rend un rappel injecté et ignore qui l'écoute (`feature-vers-feature`
  // : la tranche carte ne nomme pas la tranche favoris).
  group('MapView — le bouton « Favoris » (S10 de T3)', () {
    testWidgetsOnWindows(
      'MapView(onOpenFavorites: rappel) : un tap sur le bouton de la carte '
      'appelle le rappel, une fois',
      (WidgetTester tester) async {
        int appels = 0;
        final MapViewModel viewModel = _viewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: MapView(
              viewModel: viewModel,
              onOpenFavorites: () => appels++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(mapFavoritesButtonKey), findsOneWidget);
        await tester.tap(find.byKey(mapFavoritesButtonKey));
        await tester.pump();

        expect(appels, 1);
      },
    );

    testWidgetsOnWindows(
      'MapView sans rappel : aucun bouton « Favoris », « Filtres » seul dans '
      'le groupe',
      (WidgetTester tester) async {
        final MapViewModel viewModel = _viewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(mapFavoritesButtonKey), findsNothing);
        expect(find.byKey(mapFiltersButtonKey), findsOneWidget);
        expect(
          tester.getRect(find.byType(MapEntryButtons)),
          tester.getRect(find.byKey(mapFiltersButtonKey)),
        );
      },
    );

    testWidgetsOnWindows(
      'Tab : une puce par échelle → « Élargir la recherche » (avis de carte '
      'vide, K1 de T3) → « Favoris » → « Filtres » → contrôles de zoom ; '
      '« Favoris » est le groupe d’entrée, juste avant « Filtres »',
      (WidgetTester tester) async {
        final MapViewModel viewModel = _viewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: MapView(viewModel: viewModel, onOpenFavorites: () {}),
          ),
        );
        await tester.pumpAndSettle();

        final List<Finder> ordreAttendu = <Finder>[
          // Une puce par échelle (`L1` de T4, 2026-10-15 : deux avant).
          for (final MapScaleKind kind in MapScaleKind.values)
            find.byKey(ValueKey<MapScaleKind>(kind)),
          find.byKey(widenSearchKey),
          find.byKey(mapFavoritesButtonKey),
          find.byKey(mapFiltersButtonKey),
          find.byKey(mapZoomInButtonKey),
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
      },
    );
  });
}

/// Un double PROGRAMMABLE de [StationPointRepository] : `all()` et
/// [withinBounds] rendent tous deux [points], sans filtre — le
/// regroupement par zone (`clusters`, sur l'asset entier) et l'emprise
/// courante (`individualStations`) portent donc sur le MÊME jeu, ce qui
/// suffit à isoler la station non rattachée dans les deux vues.
final class _StationsStub implements StationPointRepository {
  _StationsStub(this.points);

  final List<StationPoint> points;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => points;

  @override
  Future<List<StationPoint>> all() async => points;
}

/// Un double PROGRAMMABLE de [StationPointRepository] qui enregistre la
/// DERNIÈRE emprise demandée à [withinBounds] — c'est ce qui permet de
/// vérifier que le bouton de recentrage (`K1`) ramène la caméra au bon
/// CENTRE, pas seulement au bon zoom (arbitrage du coordinateur du
/// 2026-09-23).
final class _BoundsSpyStationsStub implements StationPointRepository {
  _BoundsSpyStationsStub(this.points);

  final List<StationPoint> points;

  /// La dernière emprise passée à [withinBounds], `null` tant qu'aucun
  /// appel n'a eu lieu.
  Bounds? lastBounds;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    lastBounds = bounds;
    return points;
  }

  @override
  Future<List<StationPoint>> all() async => points;
}

/// Un double de [HydroObservationRepository] qui ne rend jamais de mesure
/// (`SansDonnee`), et COMPTE ses appels — c'est ce compte qui prouve qu'un
/// bouton de zoom (`K1`) a bien lancé (ou pas) le préchargement du niveau
/// individuel, sans dépendre d'une vraie mesure Hub'Eau.
final class _SpyHydroObservationRepository
    implements HydroObservationRepository {
  int callCount = 0;

  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async {
    callCount++;
    return null;
  }
}

/// Un double PROGRAMMABLE de [OndeObservationRepository] : rend toujours
/// [observations] (aucun filtre d'emprise, les tests de ce groupe n'en ont
/// pas besoin), et COMPTE ses appels — c'est ce compte qui prouve qu'un
/// geste (ici une sélection de pastille) a bien relancé un chargement
/// réseau, plutôt que de se contenter de déplacer la caméra en silence.
final class _SpyOndeObservationRepository implements OndeObservationRepository {
  _SpyOndeObservationRepository(this.observations);

  final List<OndeObservation> observations;

  int callCount = 0;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    callCount++;
    return OndeSweep(observations: observations, unreadableRows: 0);
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

/// Comme [_SpyOndeObservationRepository], mais il peut tomber : `fail` à vrai
/// fait lever chaque balayage suivant.
final class _SwitchableOndeObservationRepository
    implements OndeObservationRepository {
  _SwitchableOndeObservationRepository(this.observations);

  final List<OndeObservation> observations;

  bool fail = false;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    if (fail) {
      throw StateError('Hub\'Eau écoulement : panne simulée');
    }
    return OndeSweep(observations: observations, unreadableRows: 0);
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

// --- D4 d'Ergonomie : la caméra et la partie cachée -------------------------

/// Un [StationPointRepository] qui rend [points] et COMPTE ses appels à
/// [withinBounds] : un rechargement des lieux s'y lit (critère 9).
final class _CountingStations implements StationPointRepository {
  _CountingStations(this.points);

  final List<StationPoint> points;

  int callCount = 0;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    callCount++;
    return points;
  }

  @override
  Future<List<StationPoint>> all() async => points;
}

/// La vraie [MapView] à [taille], la fiche station RÉELLE de Blois ouverte
/// tant que [ouverte] est vrai (fermée : un panneau vide, comme `main.dart`).
Future<MapViewModel> _monterAvecFiche(
  WidgetTester tester, {
  required Size taille,
  double echelle = 1,
  required ValueNotifier<bool> ouverte,
  StationPointRepository? stations,
  HydroObservationRepository? observations,
  OndeObservationRepository? onde,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final MapViewModel viewModel = MapViewModel(
    stationPoints: stations ?? _EmptyStationPointRepository(),
    observations: observations ?? _EmptyHydroObservationRepository(),
    onde: onde ?? _EmptyOndeObservationRepository(),
  );
  final Widget fiche = ficheStationBlois();
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
              onStationTap: (StationCode _) {},
              stationSheet: ouverteMaintenant ? fiche : const SizedBox.shrink(),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

/// La caméra de la carte montée.
MapCamera _mapCamera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer)));

/// La carte visible du dernier rapport de la mise en page — garde-fou : une
/// fiche est ouverte et la réduit (sinon le cas ne prouverait rien).
Rect _carteVisibleReduite(WidgetTester tester, Size taille) {
  final MapLayoutReport? rapport = tester
      .widget<MapLayout>(find.byType(MapLayout))
      .report
      .value;
  expect(rapport, isNotNull, reason: 'aucun rapport publié');
  final Rect visible = rapport!.visible;
  expect(
    visible.right < taille.width - 1 || visible.bottom < taille.height - 1,
    isTrue,
    reason: 'la fiche ne réduit pas la carte visible $visible',
  );
  return visible;
}

/// Les `MapEventMove` que la carte montée émet à partir de maintenant : un
/// déplacement de caméra, quel qu'il soit, s'y lit.
List<MapEventMove> _ecouterLesDeplacements(WidgetTester tester) {
  final List<MapEventMove> deplacements = <MapEventMove>[];
  final StreamSubscription<MapEvent> abonnement =
      MapController.of(tester.element(find.byType(TileLayer))).mapEventStream
          .listen((MapEvent e) {
            if (e is MapEventMove) deplacements.add(e);
          });
  addTearDown(abonnement.cancel);
  return deplacements;
}

/// Touche la pastille dessinée : invoque directement le `GestureDetector`
/// posé par `_areaClusterMarkers` (`tester.tap()` par coordonnées échoue le
/// hit-test dans ce montage). Depuis `K2` (2026-09-23), un
/// `FocusTraversalOrder` puis un `KeyboardFocusRing` s'intercalent entre le
/// détecteur et `AreaClusterMarker` : on cherche le détecteur qui l'a pour
/// descendant, pas pour enfant direct.
Future<void> _toucherLaPastille(WidgetTester tester) async {
  final GestureDetector detecteur = tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is GestureDetector &&
          widget.child is FocusTraversalOrder &&
          (widget.child! as FocusTraversalOrder).child is KeyboardFocusRing &&
          ((widget.child! as FocusTraversalOrder).child as KeyboardFocusRing)
                  .child
              is AreaClusterMarker,
    ),
  );
  detecteur.onTap!();
  await tester.pumpAndSettle();
}

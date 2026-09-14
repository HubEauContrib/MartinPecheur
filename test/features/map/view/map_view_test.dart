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
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

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
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => const <OndeObservation>[];

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
  departement: DepartementCode('54'),
);

OndePoint _laSeille() => OndePoint(
  code: OndeStationCode('04170002'),
  label: 'La Seille à Nomeny',
  latitude: 48.895,
  longitude: 6.242,
  waterCourseLabel: 'La Seille',
  departement: DepartementCode('54'),
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

void main() {
  group('buildMapLayers', () {
    test('la première couche est le fond de tuiles IGN', () {
      final List<Widget> layers = buildMapLayers(
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
        scale: MapScaleKind.debit,
        stations: const <StationPoint>[],
      );

      expect(layers, hasLength(1));
    });
  });

  group('IgnAttributionBadge', () {
    testWidgets('affiche l\'attribution IGN et Licence Ouverte', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IgnAttributionBadge())),
      );

      expect(find.text(ignAttribution), findsOneWidget);
      expect(ignAttribution, contains('IGN'));
      expect(ignAttribution, contains('Licence Ouverte'));
    });

    testWidgets('porte son propre fond opaque', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IgnAttributionBadge())),
      );

      final DecoratedBox decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      final Color? color = decoration.color;

      expect(color, isNotNull);
      expect(color!.a, greaterThan(0.8));
    });
  });

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
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      expect(layers, hasLength(2));
      expect(layers[0], isA<TileLayer>());
      expect(layers[1], isA<MarkerLayer>());
    });

    test('deux stations produisent deux marqueurs', () {
      final List<Widget> layers = buildMapLayers(
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
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.point.latitude, closeTo(47.584957074, 1e-9));
      expect(marker.point.longitude, closeTo(1.335147948, 1e-9));
    });

    test('chaque marqueur est carré, à stationMarkerTapTarget — la ZONE DE '
        'TAP, pas la pastille — avec une pastille décorée dedans, jamais un '
        'glyphe de police', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.width, stationMarkerTapTarget);
      expect(marker.height, stationMarkerTapTarget);
      expect(marker.child, isNot(isA<Icon>()));
      expect(marker.child, isNot(isA<Text>()));
    });

    test("buildMapLayers ne refiltre plus : les stations passées sont toutes "
        'dessinées, marge comprise — le filtre fait foi côté dépôt '
        '(StationPointRepository)', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois(), _guadeloupe()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('une liste de stations vide ne produit qu\'une seule couche — la '
        "couche de marqueurs vide n'est pas ajoutée", () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: const <StationPoint>[],
      );

      expect(layers, hasLength(1));
    });
  });

  group('buildMapLayers — le tap sur un marqueur (T1-U1)', () {
    testWidgets('le rappel onStationTap reçoit le code de la station tapée — '
        'le `child` du marqueur est rendu SEUL, jamais dans un FlutterMap', (
      WidgetTester tester,
    ) async {
      final List<StationCode> tapped = <StationCode>[];
      final List<Widget> layers = buildMapLayers(
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
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
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
    });

    testWidgets('sans rappel, le marqueur reste inerte — aucune exception au '
        'tap', (WidgetTester tester) async {
      final List<Widget> layers = buildMapLayers(
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
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
                child: markerLayer.markers.single.child,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StationMarkerDot));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('la pastille garde sa taille de 12 px au centre de la zone '
        'de tap de 44', (WidgetTester tester) async {
      final List<Widget> layers = buildMapLayers(
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
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
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
      // Centrée, et pas seulement de la bonne taille : (44 − 12) / 2 = 16 de
      // marge de chaque côté. Le `SizedBox` de test est posé en haut à
      // gauche, l'origine de la pastille est donc directement comparable.
      expect(
        tester.getTopLeft(find.byType(StationMarkerDot)),
        const Offset(16, 16),
      );
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
    testWidgets('la pastille rend l état que stateOf donne pour SA station', (
      WidgetTester tester,
    ) async {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
        stateOf: (StationCode code) => const SansDonnee(),
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: stationMarkerTapTarget,
              height: stationMarkerTapTarget,
              child: markerLayer.markers.single.child,
            ),
          ),
        ),
      );

      expect(
        tester.widget<StationMarkerDot>(find.byType(StationMarkerDot)).state,
        const SansDonnee(),
      );
    });

    testWidgets('stateOf est interrogé station par station : deux stations, '
        'deux états', (WidgetTester tester) async {
      final List<Widget> layers = buildMapLayers(
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
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
                child: markerLayer.markers[index].child,
              ),
            ),
          ),
        );

        expect(
          tester.widget<StationMarkerDot>(find.byType(StationMarkerDot)).state,
          expected,
        );
      }
    });

    testWidgets("l'annonce du marqueur NOMME la station, puis son état — "
        '« La Loire à Blois, Aucune donnée disponible ici. » ; un seul '
        'nœud sémantique par marqueur (04-ui.md § 3)', (
      WidgetTester tester,
    ) async {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
        stateOf: (StationCode code) => const SansDonnee(),
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: stationMarkerTapTarget,
              height: stationMarkerTapTarget,
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
    });

    testWidgets("une station fraîche n'annonce QUE son nom : une mesure "
        "récente n'a pas de libellé d'état (BR-005, BR-007)", (
      WidgetTester tester,
    ) async {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
        stateOf: (StationCode code) => const Chargee(Freshness.fraiche),
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: stationMarkerTapTarget,
              height: stationMarkerTapTarget,
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
    });

    testWidgets('sans stateOf, toute station est NonChargee — jamais un état '
        'par défaut qui ressemblerait à une absence constatée (BR-007)', (
      WidgetTester tester,
    ) async {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.debit,
        stations: <StationPoint>[_blois()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: stationMarkerTapTarget,
              height: stationMarkerTapTarget,
              child: markerLayer.markers.single.child,
            ),
          ),
        ),
      );

      expect(
        tester.widget<StationMarkerDot>(find.byType(StationMarkerDot)).state,
        const NonChargee(),
      );
    });
  });

  group('buildMapOverlays — les surcouches, sans FlutterMap (T1-U2)', () {
    /// Rend les surcouches SEULES, dans un `Stack` : aucun `FlutterMap`
    /// n'est monté — l'environnement de test refuse le chargement de
    /// tuiles, et le câblage des surcouches n'a rien à voir avec lui.
    Future<void> pumpOverlays(
      WidgetTester tester, {
      MapScaleKind scale = MapScaleKind.ecoulement,
      void Function(MapScaleKind kind)? onSelect,
      Object? error,
      Widget? stationSheet,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: buildMapOverlays(
                scale: scale,
                onSelect: onSelect ?? (MapScaleKind kind) {},
                error: error,
                stationSheet: stationSheet,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('la légende est présente QUEL QUE SOIT error — toujours '
        'visible, jamais repliée (BR-008)', (WidgetTester tester) async {
      for (final Object? error in <Object?>[null, StateError('panne')]) {
        await pumpOverlays(tester, error: error);

        expect(find.byType(MapLegend), findsOneWidget);
      }
    });

    testWidgets("l'échelle passée est celle que la légende rend", (
      WidgetTester tester,
    ) async {
      for (final MapScaleKind scale in MapScaleKind.values) {
        await pumpOverlays(tester, scale: scale);

        expect(tester.widget<MapLegend>(find.byType(MapLegend)).scale, scale);
      }
    });

    testWidgets("le bandeau d'erreur n'est présent que si error != null "
        '(BR-007)', (WidgetTester tester) async {
      await pumpOverlays(tester);
      expect(find.byType(MapErrorBanner), findsNothing);

      await pumpOverlays(tester, error: StateError('Aucun asset'));
      expect(find.byType(MapErrorBanner), findsOneWidget);
      expect(find.textContaining('Aucun asset'), findsOneWidget);
    });

    testWidgets("le panneau de fiche n'est présent que s'il est fourni", (
      WidgetTester tester,
    ) async {
      const Key sheet = Key('fiche');

      await pumpOverlays(tester);
      expect(find.byKey(sheet), findsNothing);

      await pumpOverlays(
        tester,
        stationSheet: const SizedBox.shrink(key: sheet),
      );
      expect(find.byKey(sheet), findsOneWidget);
    });

    testWidgets("l'attribution IGN est TOUJOURS présente — une condition "
        "d'usage de la Licence Ouverte, jamais une finition", (
      WidgetTester tester,
    ) async {
      for (final Object? error in <Object?>[null, StateError('panne')]) {
        await pumpOverlays(tester, error: error);

        expect(find.byType(IgnAttributionBadge), findsOneWidget);
      }
    });

    testWidgets("le bandeau d'erreur ne recouvre jamais la légende : sans "
        "elle l'usager ne sait plus quelle échelle il lit (BR-008)", (
      WidgetTester tester,
    ) async {
      await pumpOverlays(tester, error: StateError('panne de lecture'));

      expect(
        tester.getTopRight(find.byType(MapErrorBanner)).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MapLegend)).dx),
      );
    });
  });

  group('MapErrorBanner — jamais une carte muette (BR-007)', () {
    testWidgets('affiche le message français et error.toString()', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapErrorBanner(error: StateError('Aucun gestionnaire')),
          ),
        ),
      );

      expect(
        find.textContaining("Les stations n'ont pas pu être chargées"),
        findsOneWidget,
      );
      expect(find.textContaining('Aucun gestionnaire'), findsOneWidget);
    });
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

  group('shouldPreloadOn — le débit ne se précharge que sur son échelle '
      '(C-15, NFR-07, relecture du 2026-09-14)', () {
    test("l'échelle « débit » précharge : ses marqueurs sont ceux dont on "
        'lit le débit', () {
      expect(shouldPreloadOn(MapScaleKind.debit), isTrue);
    });

    test("l'échelle « écoulement » ne précharge RIEN — aucune station n'est "
        "dessinée, et Hub'Eau n'a ni SLA ni quota chiffré (C-15)", () {
      expect(shouldPreloadOn(MapScaleKind.ecoulement), isFalse);
    });

    test('une seule échelle précharge — la décision est exhaustive sur '
        "l'énumération, jamais un défaut silencieux (BR-011)", () {
      expect(MapScaleKind.values.where(shouldPreloadOn), <MapScaleKind>[
        MapScaleKind.debit,
      ]);
    });
  });

  group('MapScaleChips — la bascule d échelle (T1-U3, UC-001 A6)', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      required MapScaleKind scale,
      required void Function(MapScaleKind kind) onSelect,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MapScaleChips(scale: scale, onSelect: onSelect),
            ),
          ),
        ),
      );
    }

    testWidgets('rend une puce par échelle, nommée par mapScaleLabel — '
        'jamais une reformulation locale', (WidgetTester tester) async {
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: (MapScaleKind kind) {},
      );

      for (final MapScaleKind kind in MapScaleKind.values) {
        expect(find.text(mapScaleLabel(kind)), findsOneWidget);
      }
    });

    testWidgets("la puce active est sémantiquement sélectionnée, l'autre "
        'non — la sélection ne tient pas qu à un aplat de couleur '
        '(04-ui.md § 3)', (WidgetTester tester) async {
      for (final MapScaleKind active in MapScaleKind.values) {
        await pumpChips(
          tester,
          scale: active,
          onSelect: (MapScaleKind kind) {},
        );

        for (final MapScaleKind kind in MapScaleKind.values) {
          final Semantics chip = tester.widget<Semantics>(
            find.byKey(ValueKey<MapScaleKind>(kind)),
          );
          expect(
            chip.properties.selected,
            kind == active,
            reason: '$kind, échelle active $active',
          );
          expect(chip.properties.button, isTrue);
          expect(chip.properties.label, mapScaleLabel(kind));
        }
      }
    });

    testWidgets('un tap sur « Débit » appelle onSelect(debit) UNE fois', (
      WidgetTester tester,
    ) async {
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: selected.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      await tester.pump();

      expect(selected, <MapScaleKind>[MapScaleKind.debit]);
    });

    testWidgets('un tap sur la puce déjà active la redemande telle quelle — '
        "c'est le ViewModel qui décide que cela ne change rien", (
      WidgetTester tester,
    ) async {
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: selected.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
      );
      await tester.pump();

      expect(selected, <MapScaleKind>[MapScaleKind.ecoulement]);
    });

    testWidgets('chaque puce mesure au moins 44 pt dans les deux dimensions '
        '(04-ui.md § 3, cibles tactiles)', (WidgetTester tester) async {
      await pumpChips(
        tester,
        scale: MapScaleKind.ecoulement,
        onSelect: (MapScaleKind kind) {},
      );

      for (final MapScaleKind kind in MapScaleKind.values) {
        final Size size = tester.getSize(
          find.byKey(ValueKey<MapScaleKind>(kind)),
        );
        expect(size.width, greaterThanOrEqualTo(stationMarkerTapTarget));
        expect(size.height, greaterThanOrEqualTo(stationMarkerTapTarget));
      }
    });
  });

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
      now: _now,
      onOndeTap: onOndeTap,
    );

    Future<void> pumpMarkerChild(WidgetTester tester, Marker marker) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
                child: marker.child,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('échelle « débit » : aucun marqueur ONDE, même quand des '
        'observations sont en mémoire', (WidgetTester tester) async {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.debit)[1] as MarkerLayer;

      expect(markerLayer.markers, hasLength(2));
      for (final Marker marker in markerLayer.markers) {
        await pumpMarkerChild(tester, marker);
        expect(find.byType(OndeMarkerShape), findsNothing);
        expect(find.byType(StationMarkerDot), findsOneWidget);
      }
    });

    testWidgets('échelle « écoulement » : aucun marqueur de station, même '
        'quand le référentiel est chargé', (WidgetTester tester) async {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

      expect(markerLayer.markers, hasLength(2));
      for (final Marker marker in markerLayer.markers) {
        await pumpMarkerChild(tester, marker);
        expect(find.byType(StationMarkerDot), findsNothing);
        expect(find.byType(OndeMarkerShape), findsOneWidget);
      }
    });

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
        expect(marker.width, stationMarkerTapTarget);
        expect(marker.height, stationMarkerTapTarget);
      }
    });

    test('une emprise sans observation ONDE ne dessine rien, et ne plante '
        'pas — le message hors couverture est l affaire de U6', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.ecoulement,
        stations: <StationPoint>[_blois()],
        now: _now,
      );

      expect(layers, hasLength(1));
      expect(layers.single, isA<TileLayer>());
    });

    testWidgets('le tap d un marqueur ONDE rend SON point', (
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

    testWidgets('sans rappel, le marqueur ONDE reste inerte — aucune '
        'exception au tap', (WidgetTester tester) async {
      final MarkerLayer markerLayer =
          layersFor(MapScaleKind.ecoulement)[1] as MarkerLayer;

      await pumpMarkerChild(tester, markerLayer.markers.first);
      await tester.tap(find.byType(OndeMarkerShape));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets("l'annonce d'un marqueur ONDE préfixe l'échelle active, puis "
        'la catégorie, le point et la date de campagne (BR-008, BR-010, '
        '04-ui.md § 3)', (WidgetTester tester) async {
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
    });

    testWidgets('passé 60 jours, l annonce porte la date de la dernière '
        'observation et la forme vire au gris (BR-010)', (
      WidgetTester tester,
    ) async {
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
    });

    testWidgets("l'âge est calculé avec le `now` injecté, jamais avec "
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
        now: () => DateTime.utc(2026, 6, 20),
      );

      await pumpMarkerChild(tester, (layers[1] as MarkerLayer).markers.single);

      expect(
        tester.widget<OndeMarkerShape>(find.byType(OndeMarkerShape)).age,
        CampaignAge.recente,
      );
    });
  });

  group('buildMapOverlays — les puces de bascule (T1-U3)', () {
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
              children: buildMapOverlays(
                scale: scale,
                onSelect: onSelect ?? (MapScaleKind kind) {},
                error: error,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('les puces sont rendues, avec l échelle active', (
      WidgetTester tester,
    ) async {
      await pumpScaleOverlays(tester, scale: MapScaleKind.debit);

      expect(
        tester.widget<MapScaleChips>(find.byType(MapScaleChips)).scale,
        MapScaleKind.debit,
      );
    });

    testWidgets('les puces sont rendues MÊME en erreur : une carte en panne '
        "reste une carte dont on change l'échelle (BR-007)", (
      WidgetTester tester,
    ) async {
      await pumpScaleOverlays(tester, error: StateError('panne'));

      expect(find.byType(MapScaleChips), findsOneWidget);
    });

    testWidgets('le rappel passé aux surcouches est celui que les puces '
        'appellent', (WidgetTester tester) async {
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
    });

    testWidgets('les puces ne recouvrent jamais la légende (BR-008)', (
      WidgetTester tester,
    ) async {
      await pumpScaleOverlays(tester, error: StateError('panne'));

      expect(
        tester.getTopRight(find.byType(MapScaleChips)).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MapLegend)).dx),
      );
    });

    testWidgets("le bandeau d'erreur ne recouvre pas les puces : il se pose "
        'dessous', (WidgetTester tester) async {
      await pumpScaleOverlays(tester, error: StateError('panne'));

      expect(
        tester.getBottomLeft(find.byType(MapScaleChips)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MapErrorBanner)).dy),
      );
    });
  });

  group('MapView — le câblage de U3', () {
    test('onOndeTap est accepté SEUL : le panneau ONDE arrive en U4, et '
        "aucun assert n'exige encore son pendant", () {
      expect(
        () => MapView(viewModel: _viewModel(), onOndeTap: (OndePoint point) {}),
        returnsNormally,
      );
    });

    test("`now` a une valeur par défaut : l'horloge du poste, sauf dans un "
        'test qui la fixe', () {
      final MapView view = MapView(viewModel: _viewModel());

      expect(view.now(), isA<DateTime>());
    });
  });
}

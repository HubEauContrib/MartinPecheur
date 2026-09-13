// Verrouille l'écran carte : le fond IGN est la première couche, les
// stations du viewport deviennent des marqueurs (T0-M4), et l'attribution
// Licence Ouverte est affichée en toutes lettres, sur son propre fond
// opaque. ⚠️ Aucun `FlutterMap` n'est rendu ici : les couches sont produites
// par une fonction PURE, testable sans déclencher de chargement de tuiles —
// refusé par l'environnement de test. La logique d'envoi au bus
// (`MapStationsController`) est, elle aussi, testée sans widget.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/map/ign_tile_template.dart';
import 'package:martinpecheur/features/map/map_screen.dart';

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

void main() {
  group('buildMapLayers', () {
    test('la première couche est le fond de tuiles IGN', () {
      final List<Widget> layers = buildMapLayers(
        stations: const <StationPoint>[],
        camera: null,
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

    test('sans stations et sans caméra, une seule couche est produite', () {
      final List<Widget> layers = buildMapLayers(
        stations: const <StationPoint>[],
        camera: null,
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
        stations: <StationPoint>[_blois()],
        camera: null,
      );

      expect(layers, hasLength(2));
      expect(layers[0], isA<TileLayer>());
      expect(layers[1], isA<MarkerLayer>());
    });

    test('sans caméra, deux stations produisent deux marqueurs', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois(), _guadeloupe()],
        camera: null,
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('le marqueur de Blois porte ses coordonnées exactes — attention à '
        "l'ordre GeoJSON [longitude, latitude], LatLng prend la latitude en "
        'premier', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois()],
        camera: null,
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.point.latitude, closeTo(47.584957074, 1e-9));
      expect(marker.point.longitude, closeTo(1.335147948, 1e-9));
    });

    test('chaque marqueur est carré, à stationMarkerSize, avec une pastille '
        'décorée — jamais un glyphe de police', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois()],
        camera: null,
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.width, stationMarkerSize);
      expect(marker.height, stationMarkerSize);
      expect(marker.child, isNot(isA<Icon>()));
      expect(marker.child, isNot(isA<Text>()));
    });

    test('visibleBounds resserré sur Blois exclut la Guadeloupe', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois(), _guadeloupe()],
        camera: null,
        visibleBounds: (north: 48, south: 47, east: 2, west: 1),
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(1));
      expect(
        markerLayer.markers.single.point.latitude,
        closeTo(47.584957074, 1e-6),
      );
    });

    test('une liste de stations vide ne produit qu\'une seule couche — la '
        "couche de marqueurs vide n'est pas ajoutée", () {
      final List<Widget> layers = buildMapLayers(
        stations: const <StationPoint>[],
        camera: null,
      );

      expect(layers, hasLength(1));
    });
  });

  group('StationMarkerDot', () {
    testWidgets(
      'un cercle avec un contour de 2 px — la couleur ne porte aucun état '
      '(BR-008)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: StationMarkerDot())),
        );

        final DecoratedBox decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final BoxDecoration decoration =
            decoratedBox.decoration as BoxDecoration;

        expect(decoration.shape, BoxShape.circle);
        expect(decoration.border, isNotNull);
        final Border border = decoration.border! as Border;
        expect(border.top.width, 2);
      },
    );
  });

  group('MapStationsController — envoie au bus, sans widget ni FlutterMap', () {
    test(
      'charge deux points au démarrage, en une seule requête au bus',
      () async {
        int appels = 0;
        final Bus bus = Bus();
        bus.register<StationPointsWithinBoundsQuery, List<StationPoint>>((
          StationPointsWithinBoundsQuery query,
        ) async {
          appels++;
          return <StationPoint>[_blois(), _guadeloupe()];
        });
        final MapStationsController controller = MapStationsController(bus);

        await controller.loadInitial();

        expect(appels, 1);
        expect(controller.stations.value, hasLength(2));
      },
    );

    test('refresh — une emprise inchangée ne renvoie pas de requête', () async {
      int appels = 0;
      final Bus bus = Bus();
      bus.register<StationPointsWithinBoundsQuery, List<StationPoint>>((
        StationPointsWithinBoundsQuery query,
      ) async {
        appels++;
        return <StationPoint>[_blois()];
      });
      final MapStationsController controller = MapStationsController(bus);
      final Bounds emprise = Bounds(west: -1, south: 46, east: 3, north: 48);

      await controller.refresh(emprise);
      await controller.refresh(Bounds(west: -1, south: 46, east: 3, north: 48));

      expect(appels, 1);
    });
  });
}

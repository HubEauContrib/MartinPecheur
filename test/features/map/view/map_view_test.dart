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
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';

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

void main() {
  group('buildMapLayers', () {
    test('la première couche est le fond de tuiles IGN', () {
      final List<Widget> layers = buildMapLayers(
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
        stations: <StationPoint>[_blois()],
      );

      expect(layers, hasLength(2));
      expect(layers[0], isA<TileLayer>());
      expect(layers[1], isA<MarkerLayer>());
    });

    test('deux stations produisent deux marqueurs', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois(), _guadeloupe()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('le marqueur de Blois porte ses coordonnées exactes — attention à '
        "l'ordre GeoJSON [longitude, latitude], LatLng prend la latitude en "
        'premier', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois()],
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
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      final Marker marker = markerLayer.markers.single;
      expect(marker.width, stationMarkerSize);
      expect(marker.height, stationMarkerSize);
      expect(marker.child, isNot(isA<Icon>()));
      expect(marker.child, isNot(isA<Text>()));
    });

    test("buildMapLayers ne refiltre plus : les stations passées sont toutes "
        'dessinées, marge comprise — le filtre fait foi côté dépôt '
        '(StationPointRepository)', () {
      final List<Widget> layers = buildMapLayers(
        stations: <StationPoint>[_blois(), _guadeloupe()],
      );

      final MarkerLayer markerLayer = layers[1] as MarkerLayer;
      expect(markerLayer.markers, hasLength(2));
    });

    test('une liste de stations vide ne produit qu\'une seule couche — la '
        "couche de marqueurs vide n'est pas ajoutée", () {
      final List<Widget> layers = buildMapLayers(
        stations: const <StationPoint>[],
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
}

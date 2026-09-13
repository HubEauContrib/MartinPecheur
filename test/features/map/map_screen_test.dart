// Verrouille l'écran carte (T0-M3) : le fond IGN est la première couche,
// `buildMapLayers` ignore encore `stations` et `camera` (M4 les exploitera),
// et l'attribution Licence Ouverte est affichée en toutes lettres, sur son
// propre fond opaque. ⚠️ Aucun `FlutterMap` n'est rendu ici : les couches
// sont produites par une fonction PURE, testable sans déclencher de
// chargement de tuiles — refusé par l'environnement de test.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/features/map/ign_tile_template.dart';
import 'package:martinpecheur/features/map/map_screen.dart';

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
}

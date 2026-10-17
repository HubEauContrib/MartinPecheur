// Le calque des traits de la lecture Crues (M2 de T4) : un seul
// `PolylineLayer<FloodSectionCode>`, dans l'ordre de dessin du domaine, et le
// toucher d'un trait par `hitNotifier` (cadrage § 7.3).
//
// Le calque est monté dans un `FlutterMap` de test, caméra fixe, sans fond de
// tuiles ni `MapView`. Les traits passent par le centre de la carte : leur
// milieu est le centre du `FlutterMap`, les distances se comptent en pixels
// logiques à partir de lui.
//
// Les niveaux 2 à 4 (jaune, orange, rouge) sont des cas construits, niveau
// jamais observé en production — `VC-04`.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/flood_sections_layer.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

const LatLng _center = LatLng(47, 2);
const double _zoom = 10;

CampaignAge _unusedAgeOf(OndeObservation observation) =>
    throw StateError('ageOf ne doit pas être appelé : aucun marqueur ONDE');

/// Un trait horizontal qui passe par [_center], de 0,1° de part et d'autre.
List<GeoPoint> _lineThroughCenter() => <GeoPoint>[
  GeoPoint(latitude: _center.latitude, longitude: _center.longitude - 0.1),
  GeoPoint(latitude: _center.latitude, longitude: _center.longitude + 0.1),
];

FloodSection _section(
  String code,
  FloodVigilanceLevel level, {
  List<List<GeoPoint>>? lines,
}) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: '8',
  level: level,
  lines: lines ?? <List<GeoPoint>>[_lineThroughCenter()],
);

FloodVigilanceMap _map(List<FloodSection> sections) => FloodVigilanceMap(
  informationDate: DateTime.utc(2026, 10, 14, 13, 55),
  sections: sections,
  skippedEntities: 0,
);

Future<void> _pumpLayer(WidgetTester tester, Widget layer) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FlutterMap(
        options: const MapOptions(initialCenter: _center, initialZoom: _zoom),
        children: <Widget>[layer],
      ),
    ),
  );
}

PolylineLayer<FloodSectionCode> _polylineLayer(WidgetTester tester) =>
    tester.widget<PolylineLayer<FloodSectionCode>>(
      find.byType(PolylineLayer<FloodSectionCode>),
    );

/// Touche la carte à [offset] du centre, puis laisse passer le délai du
/// double toucher de `flutter_map` avant de lire le résultat.
Future<void> _tapFromCenter(WidgetTester tester, Offset offset) async {
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)) + offset);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('buildFloodSectionsLayer — les traits', () {
    testWidgetsOnWindows(
      'un seul PolylineLayer ; ordre des traits : vert, jaune, orange, '
      'rouge, inconnu (jaune, orange, rouge : cas construits, niveau jamais '
      'observé en production — VC-04)',
      (WidgetTester tester) async {
        final FloodVigilanceMap map = _map(<FloodSection>[
          _section('I', const NiveauCruesInconnu(9)),
          _section('R', const Rouge()),
          _section('V', const Vert()),
          _section('O', const Orange()),
          _section('J', const Jaune()),
        ]);
        final LayerHitNotifier<FloodSectionCode> notifier =
            ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
        addTearDown(notifier.dispose);

        await _pumpLayer(
          tester,
          buildFloodSectionsLayer(
            map: map,
            hitNotifier: notifier,
            onTap: (FloodSectionCode code) {},
          ),
        );

        expect(find.byType(PolylineLayer<FloodSectionCode>), findsOneWidget);
        final PolylineLayer<FloodSectionCode> layer = _polylineLayer(tester);
        expect(
          <String?>[
            for (final Polyline<FloodSectionCode> p in layer.polylines)
              p.hitValue?.value,
          ],
          <String>['V', 'J', 'O', 'R', 'I'],
        );
        expect(identical(layer.hitNotifier, notifier), isTrue);
      },
    );

    testWidgetsOnWindows(
      'chaque trait : teinte, épaisseur et motif du niveau, contour noir de '
      '2 px de chaque côté, tolérance de la moitié de la cible, '
      'simplification par défaut (cas construits, niveau jamais observé en '
      'production — VC-04)',
      (WidgetTester tester) async {
        final List<FloodSection> sections = <FloodSection>[
          _section('V', const Vert()),
          _section('J', const Jaune()),
          _section('O', const Orange()),
          _section('R', const Rouge()),
          _section('I', const NiveauCruesInconnu(null)),
        ];
        final LayerHitNotifier<FloodSectionCode> notifier =
            ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
        addTearDown(notifier.dispose);

        await _pumpLayer(
          tester,
          buildFloodSectionsLayer(
            map: _map(sections),
            hitNotifier: notifier,
            onTap: (FloodSectionCode code) {},
          ),
        );

        final PolylineLayer<FloodSectionCode> layer = _polylineLayer(tester);
        expect(layer.minimumHitbox, 22);
        expect(layer.minimumHitbox, minimumTapTarget / 2);
        expect(
          layer.simplificationTolerance,
          PolylineLayer<FloodSectionCode>(
            polylines: const <Polyline<FloodSectionCode>>[],
          ).simplificationTolerance,
        );
        for (final (int i, Polyline<FloodSectionCode> p)
            in layer.polylines.indexed) {
          final FloodLevelStyle style = floodLevelStyle(sections[i].level);
          expect(p.color, style.tint, reason: sections[i].code.value);
          expect(p.strokeWidth, style.strokeWidth);
          expect(
            p.pattern,
            style.dotted
                ? const StrokePattern.dotted()
                : const StrokePattern.solid(),
          );
          expect(p.borderColor, floodContourColor);
          expect(p.borderStrokeWidth, 4);
          expect(p.borderStrokeWidth, 2 * floodContourWidth);
        }
        expect(layer.polylines.last.pattern, const StrokePattern.dotted());
        expect(layer.polylines.first.pattern, const StrokePattern.solid());
      },
    );

    testWidgetsOnWindows(
      'un tronçon à deux lignes : deux traits, chacun porte son code',
      (WidgetTester tester) async {
        final FloodSection twoLines = _section(
          'D',
          const Vert(),
          lines: <List<GeoPoint>>[
            _lineThroughCenter(),
            <GeoPoint>[
              GeoPoint(latitude: 47.05, longitude: 1.9),
              GeoPoint(latitude: 47.05, longitude: 2.1),
            ],
          ],
        );
        final LayerHitNotifier<FloodSectionCode> notifier =
            ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
        addTearDown(notifier.dispose);

        await _pumpLayer(
          tester,
          buildFloodSectionsLayer(
            map: _map(<FloodSection>[twoLines]),
            hitNotifier: notifier,
            onTap: (FloodSectionCode code) {},
          ),
        );

        final PolylineLayer<FloodSectionCode> layer = _polylineLayer(tester);
        expect(layer.polylines, hasLength(2));
        expect(
          layer.polylines.map(
            (Polyline<FloodSectionCode> p) => p.hitValue?.value,
          ),
          <String>['D', 'D'],
        );
        expect(layer.polylines[1].points, <LatLng>[
          const LatLng(47.05, 1.9),
          const LatLng(47.05, 2.1),
        ]);
      },
    );
  });

  group('buildFloodSectionsLayer — le toucher', () {
    Future<List<FloodSectionCode>> pumpAndCollect(
      WidgetTester tester,
      List<FloodSection> sections,
    ) async {
      final List<FloodSectionCode> tapped = <FloodSectionCode>[];
      final LayerHitNotifier<FloodSectionCode> notifier =
          ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
      addTearDown(notifier.dispose);
      await _pumpLayer(
        tester,
        buildFloodSectionsLayer(
          map: _map(sections),
          hitNotifier: notifier,
          onTap: tapped.add,
        ),
      );
      return tapped;
    }

    testWidgetsOnWindows('toucher au milieu d’un trait : son code', (
      WidgetTester tester,
    ) async {
      final List<FloodSectionCode> tapped = await pumpAndCollect(
        tester,
        <FloodSection>[_section('V1', const Vert())],
      );

      await _tapFromCenter(tester, Offset.zero);

      expect(tapped, <FloodSectionCode>[FloodSectionCode('V1')]);
    });

    testWidgetsOnWindows('toucher à 20 px du trait (Windows) : reçu', (
      WidgetTester tester,
    ) async {
      final List<FloodSectionCode> tapped = await pumpAndCollect(
        tester,
        <FloodSection>[_section('V1', const Vert())],
      );

      await _tapFromCenter(tester, const Offset(0, 20));

      expect(tapped, <FloodSectionCode>[FloodSectionCode('V1')]);
    });

    testWidgetsOnWindows('toucher à 40 px du trait : rien', (
      WidgetTester tester,
    ) async {
      final List<FloodSectionCode> tapped = await pumpAndCollect(
        tester,
        <FloodSection>[_section('V1', const Vert())],
      );

      await _tapFromCenter(tester, const Offset(0, 40));

      expect(tapped, isEmpty);
    });

    testWidgetsOnWindows(
      'deux traits superposés, rouge sur vert : le code du rouge, le plus '
      'haut dessiné (rouge : cas construit, niveau jamais observé en '
      'production — VC-04)',
      (WidgetTester tester) async {
        final List<FloodSectionCode> tapped = await pumpAndCollect(
          tester,
          <FloodSection>[
            _section('R1', const Rouge()),
            _section('V1', const Vert()),
          ],
        );

        await _tapFromCenter(tester, Offset.zero);

        expect(tapped, <FloodSectionCode>[FloodSectionCode('R1')]);
      },
    );

    // Relecture d'ensemble de T4, point B : le code est relevé À L'APPUI. Le
    // notifier, partagé, est réécrit par tout test de toucher ultérieur
    // (survol compris) avant que le toucher ne soit tranché.
    testWidgetsOnWindows(
      'le notifier remis à null entre l’appui et le relâcher : le code relevé '
      'à l’appui, aucune exception',
      (WidgetTester tester) async {
        final List<FloodSectionCode> tapped = <FloodSectionCode>[];
        final LayerHitNotifier<FloodSectionCode> notifier =
            ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
        addTearDown(notifier.dispose);
        await _pumpLayer(
          tester,
          buildFloodSectionsLayer(
            map: _map(<FloodSection>[_section('V1', const Vert())]),
            hitNotifier: notifier,
            onTap: tapped.add,
          ),
        );

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlutterMap)),
        );
        expect(notifier.value, isNotNull);
        notifier.value = null;
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(tapped, <FloodSectionCode>[FloodSectionCode('V1')]);
      },
    );

    // Sous Windows, une souris qui bouge pendant l'appui relance le test de
    // toucher du calque à chaque `PointerMoveEvent` (`MouseTracker`, appelé
    // par `RendererBinding.dispatchEvent` sans résultat pour ces événements)
    // et réécrit le notifier. Un déplacement de 0,8 px reste sous toutes les
    // tolérances de la souris (toucher, glisser) : le toucher n'est pas
    // annulé, mais il passe la bordure des 22 px du trait.
    testWidgetsOnWindows(
      'souris : appui sur le trait à 21,6 px, déplacement de 0,8 px hors de '
      'la tolérance pendant l’appui, relâcher : le toucher reçoit le trait',
      (WidgetTester tester) async {
        final List<FloodSectionCode> tapped = <FloodSectionCode>[];
        final LayerHitNotifier<FloodSectionCode> notifier =
            ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);
        addTearDown(notifier.dispose);
        await _pumpLayer(
          tester,
          buildFloodSectionsLayer(
            map: _map(<FloodSection>[_section('A', const Vert())]),
            hitNotifier: notifier,
            onTap: tapped.add,
          ),
        );
        final Offset center = tester.getCenter(find.byType(FlutterMap));

        final TestGesture mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: center);
        addTearDown(mouse.removePointer);
        await mouse.down(center + const Offset(0, 21.6));
        expect(notifier.value?.hitValues, <FloodSectionCode>[
          FloodSectionCode('A'),
        ]);
        await mouse.moveTo(center + const Offset(0, 22.4));
        expect(
          notifier.value,
          isNull,
          reason: 'le déplacement pendant l’appui a réécrit le notifier',
        );
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tapped, <FloodSectionCode>[FloodSectionCode('A')]);
      },
    );

    testWidgetsOnAndroid('Android : toucher à 23 px du trait : reçu '
        '(tolérance de 24)', (WidgetTester tester) async {
      final List<FloodSectionCode> tapped = await pumpAndCollect(
        tester,
        <FloodSection>[_section('V1', const Vert())],
      );

      expect(_polylineLayer(tester).minimumHitbox, 24);
      await _tapFromCenter(tester, const Offset(0, 23));

      expect(tapped, <FloodSectionCode>[FloodSectionCode('V1')]);
    });
  });

  group('buildMapLayers — la lecture Crues', () {
    final GeoPoint pin = GeoPoint(latitude: 47, longitude: 2);
    final FloodLabel label = FloodLabel(
      section: _section('O1', const Orange()),
      anchor: GeoPoint(latitude: 47, longitude: 2),
    );
    const Widget floodLayer = SizedBox(key: Key('calque-crues'));

    test('ordre : tuiles, calque de traits, étiquettes, épingle (orange : cas '
        'construit, niveau jamais observé en production — VC-04)', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.crues,
        stations: const <StationPoint>[],
        ageOf: _unusedAgeOf,
        floodLayer: floodLayer,
        floodLabels: <FloodLabel>[label],
        designatedPoint: pin,
      );

      expect(layers, hasLength(4));
      expect(layers[0], isA<TileLayer>());
      expect(identical(layers[1], floodLayer), isTrue);
      expect(layers[2], isA<MarkerLayer>());
      expect((layers[2] as MarkerLayer).markers, hasLength(1));
      expect(layers[3], isA<MarkerLayer>());
    });

    test('hors de la lecture Crues, ni calque de traits ni étiquette', () {
      for (final MapScaleKind scale in <MapScaleKind>[
        MapScaleKind.debit,
        MapScaleKind.ecoulement,
      ]) {
        final List<Widget> layers = buildMapLayers(
          scale: scale,
          stations: const <StationPoint>[],
          ageOf: _unusedAgeOf,
          floodLayer: floodLayer,
          floodLabels: <FloodLabel>[label],
        );

        expect(layers, hasLength(1), reason: '$scale');
        expect(layers.single, isA<TileLayer>());
      }
    });

    test('sans calque ni étiquette, la lecture Crues ne dessine que les '
        'tuiles', () {
      final List<Widget> layers = buildMapLayers(
        scale: MapScaleKind.crues,
        stations: const <StationPoint>[],
        ageOf: _unusedAgeOf,
      );

      expect(layers.single, isA<TileLayer>());
    });
  });
}

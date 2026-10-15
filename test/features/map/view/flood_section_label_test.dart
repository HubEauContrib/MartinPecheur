// L'étiquette d'un tronçon (M2 de T4, cadrage § 7.2 et § 7.4) : jauge puis
// nom du niveau, fond blanc, cible tactile de la plateforme, focalisable au
// clavier, annoncée « crues : vigilance <niveau>, <tronçon> » ; et sa pose
// par `buildMapLayers` selon le niveau individuel.
//
// Les niveaux 2 à 4 (jaune, orange, rouge) sont des cas construits, niveau
// jamais observé en production — `VC-04`.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/flood_section_label.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

FloodSection _section(
  FloodVigilanceLevel level, {
  String code = 'O1',
  String name = 'Blavet',
}) => FloodSection(
  code: FloodSectionCode(code),
  name: name,
  territoryCode: '8',
  level: level,
  lines: <List<GeoPoint>>[
    <GeoPoint>[
      GeoPoint(latitude: 47, longitude: 2),
      GeoPoint(latitude: 47.1, longitude: 2.1),
    ],
  ],
);

CampaignAge _unusedAgeOf(OndeObservation observation) =>
    throw StateError('ageOf ne doit pas être appelé : aucun marqueur ONDE');

/// Double de source : rend toujours la même carte.
final class _Source implements FloodVigilanceSource {
  _Source(this.map);

  final FloodVigilanceMap map;

  @override
  Future<FloodVigilanceMap> current() async => map;
}

Future<void> _pumpLabel(
  WidgetTester tester,
  FloodSection section, {
  VoidCallback? onActivate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FloodSectionLabel(section: section, onActivate: onActivate),
        ),
      ),
    ),
  );
}

void main() {
  group('floodLabelAnnouncement', () {
    test('Vert, Jaune, Orange, Rouge et niveau non reconnu (jaune, orange, '
        'rouge : cas construits, niveau jamais observé en production — '
        'VC-04)', () {
      expect(
        floodLabelAnnouncement(_section(const Vert())),
        'crues : vigilance verte, Blavet',
      );
      expect(
        floodLabelAnnouncement(_section(const Jaune())),
        'crues : vigilance jaune, Blavet',
      );
      expect(
        floodLabelAnnouncement(_section(const Orange())),
        'crues : vigilance orange, Blavet',
      );
      expect(
        floodLabelAnnouncement(_section(const Rouge())),
        'crues : vigilance rouge, Blavet',
      );
      expect(
        floodLabelAnnouncement(_section(const NiveauCruesInconnu(7))),
        'crues : niveau non reconnu, Blavet',
      );
    });
  });

  group('FloodSectionLabel', () {
    testWidgetsOnWindows(
      'orange : texte « Orange » et jauge à deux barres (cas construit, '
      'niveau jamais observé en production — VC-04)',
      (WidgetTester tester) async {
        await _pumpLabel(tester, _section(const Orange()), onActivate: () {});

        expect(find.text('Orange'), findsOneWidget);
        final FloodLevelGauge gauge = tester.widget<FloodLevelGauge>(
          find.byType(FloodLevelGauge),
        );
        expect(gauge.level, const Orange());
        expect(floodLevelStyle(gauge.level).bars, 2);
        // La jauge précède le nom.
        expect(
          tester.getCenter(find.byType(FloodLevelGauge)).dx,
          lessThan(tester.getCenter(find.text('Orange')).dx),
        );
      },
    );

    testWidgetsOnWindows(
      'sémantique « crues : vigilance orange, Blavet », bouton activable '
      '(cas construit, niveau jamais observé en production — VC-04)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        int activations = 0;
        await _pumpLabel(
          tester,
          _section(const Orange()),
          onActivate: () => activations++,
        );

        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('crues : vigilance orange, Blavet'),
        );
        expect(node.label, 'crues : vigilance orange, Blavet');
        expect(
          node,
          isSemantics(
            label: 'crues : vigilance orange, Blavet',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(find.bySemanticsLabel('Orange'), findsNothing);

        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(activations, 1);

        handle.dispose();
      },
    );

    testWidgetsOnWindows(
      'Tab l’atteint, Entrée appelle onActivate (cas construit, niveau '
      'jamais observé en production — VC-04)',
      (WidgetTester tester) async {
        int activations = 0;
        await _pumpLabel(
          tester,
          _section(const Orange()),
          onActivate: () => activations++,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byType(FloodSectionLabel)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(activations, 1);
      },
    );

    testWidgetsOnWindows('un toucher appelle onActivate', (
      WidgetTester tester,
    ) async {
      int activations = 0;
      await _pumpLabel(
        tester,
        _section(const Vert()),
        onActivate: () => activations++,
      );

      await tester.tap(find.byType(FloodSectionLabel));
      await tester.pump();

      expect(activations, 1);
    });

    testWidgetsOnWindows('hauteur : la cible de Windows, 44', (
      WidgetTester tester,
    ) async {
      await _pumpLabel(tester, _section(const Vert()), onActivate: () {});

      final Size size = tester.getSize(find.byType(FloodSectionLabel));
      expect(size.height, minimumTapTarget);
      expect(size.height, 44);
      expect(size.width, floodLabelWidth);
      expect(floodLabelWidth, 168);
    });

    testWidgetsOnAndroid('Android : hauteur : la cible d’Android, 48', (
      WidgetTester tester,
    ) async {
      await _pumpLabel(tester, _section(const Vert()), onActivate: () {});

      final Size size = tester.getSize(find.byType(FloodSectionLabel));
      expect(size.height, minimumTapTarget);
      expect(size.height, 48);
    });

    testWidgetsOnWindows(
      'niveau inconnu : « Niveau non reconnu », annoncé « crues : niveau non '
      'reconnu, Blavet », jamais coupé',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pumpLabel(
          tester,
          _section(const NiveauCruesInconnu('9')),
          onActivate: () {},
        );

        expect(find.text('Niveau non reconnu'), findsOneWidget);
        expect(
          find.bySemanticsLabel('crues : niveau non reconnu, Blavet'),
          findsOneWidget,
        );
        final Text text = tester.widget<Text>(find.text('Niveau non reconnu'));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.overflow, isNot(TextOverflow.clip));
        expect(find.byType(FittedBox), findsOneWidget);
        expect(
          tester.widget<FittedBox>(find.byType(FittedBox)).fit,
          BoxFit.scaleDown,
        );
        // Le contenu tient dans la largeur de l'étiquette.
        expect(
          tester.getSize(find.byType(FittedBox)).width,
          lessThanOrEqualTo(floodLabelWidth),
        );
        expect(tester.takeException(), isNull);

        handle.dispose();
      },
    );
  });

  group('buildMapLayers — étiquettes selon le niveau individuel', () {
    final FloodVigilanceMap map = FloodVigilanceMap(
      informationDate: DateTime.utc(2026, 10, 14, 13, 55),
      sections: <FloodSection>[_section(const Vert(), code: 'V1')],
      skippedEntities: 0,
    );
    final Bounds inside = Bounds(
      west: 1.9,
      south: 46.9,
      east: 2.2,
      north: 47.2,
    );

    Future<List<FloodLabel>> labelsAt({required bool individualLevel}) async {
      final FloodLayerViewModel viewModel = FloodLayerViewModel(
        source: _Source(map),
      );
      addTearDown(viewModel.dispose);
      await viewModel.onViewportChanged(
        inside,
        individualLevel: individualLevel,
      );
      await viewModel.activate();
      return viewModel.labels;
    }

    testWidgetsOnWindows(
      'sous le niveau individuel, un tronçon vert dans l’emprise : aucune '
      'étiquette',
      (WidgetTester tester) async {
        final List<FloodLabel> labels = await labelsAt(individualLevel: false);
        final List<Widget> layers = buildMapLayers(
          scale: MapScaleKind.crues,
          stations: const <StationPoint>[],
          ageOf: _unusedAgeOf,
          floodLabels: labels,
          onFloodSectionTap: (FloodSectionCode code) {},
        );

        expect(layers.whereType<MarkerLayer>(), isEmpty);
      },
    );

    testWidgetsOnWindows(
      'au niveau individuel : une étiquette, à l’ancre, 168 × cible, '
      'premier arrêt du groupe « carte », qui ouvre son tronçon',
      (WidgetTester tester) async {
        final List<FloodLabel> labels = await labelsAt(individualLevel: true);
        final List<FloodSectionCode> opened = <FloodSectionCode>[];
        final List<Widget> layers = buildMapLayers(
          scale: MapScaleKind.crues,
          stations: const <StationPoint>[],
          ageOf: _unusedAgeOf,
          floodLabels: labels,
          onFloodSectionTap: opened.add,
        );

        final Marker marker = layers
            .whereType<MarkerLayer>()
            .single
            .markers
            .single;
        expect(marker.width, floodLabelWidth);
        expect(marker.height, minimumTapTarget);
        expect(
          marker.point,
          LatLng(labels.single.anchor.latitude, labels.single.anchor.longitude),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: marker.width,
                  height: marker.height,
                  child: marker.child,
                ),
              ),
            ),
          ),
        );

        final FloodSectionLabel label = tester.widget<FloodSectionLabel>(
          find.byType(FloodSectionLabel),
        );
        expect(label.section.code, FloodSectionCode('V1'));
        final FocusTraversalOrder order = tester.widget<FocusTraversalOrder>(
          find
              .ancestor(
                of: find.byType(FloodSectionLabel),
                matching: find.byType(FocusTraversalOrder),
              )
              .first,
        );
        expect(order.order, isA<NumericFocusOrder>());
        expect((order.order as NumericFocusOrder).order, 0);

        await tester.tap(find.byType(FloodSectionLabel));
        await tester.pump();
        expect(opened, <FloodSectionCode>[FloodSectionCode('V1')]);
      },
    );
  });
}

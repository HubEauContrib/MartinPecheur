// Verrouille la désignation d'un point sur la carte (`E1` de T2, conception
// `docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md` § 2) :
// appui long ET clic droit à une position d'écran appellent chacun
// `MapView.onPointDesignated` une fois, avec le `GeoPoint` que la caméra donne
// pour cette position ; le tap simple sur le fond n'appelle rien ; le bouton
// « Restrictions au centre de la carte » désigne le centre de la caméra ;
// l'épingle est tenue par l'état de la vue carte, inerte, hors tabulation.
//
// `E5` (2026-10-03) : le bouton, son indice et le réticule n'existent que dans
// le MODE de désignation, que le choix « Restrictions » du sélecteur allume
// (`MapViewModel.designationMode`). Les cas qui portent sur eux montent la
// carte `enMode: true` ; les gestes (appui long, clic droit) sont verrouillés
// dans les deux états.
//
// `MapView` est monté en entier (comme `map_keyboard_test.dart`) : les
// gestes ne peuvent pas se vérifier sur les seules fonctions pures.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
import 'package:martinpecheur/features/map/view/designated_point_pin.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/windows_platform.dart';

final class _Stations implements StationPointRepository {
  _Stations(this.points);

  final List<StationPoint> points;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => points;

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

MapViewModel _viewModel({
  List<StationPoint> stations = const <StationPoint>[],
}) => MapViewModel(
  stationPoints: _Stations(stations),
  observations: _NoHydro(),
  onde: _NoOnde(),
  delay: (Duration _) => Future<void>.value(),
);

MapCamera _camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer)));

/// Le point que la caméra donne pour la position d'écran [global].
GeoPoint _pointAt(WidgetTester tester, Offset global) {
  final Offset relative = global - tester.getTopLeft(find.byType(FlutterMap));
  final LatLng latLng = _camera(tester).screenOffsetToLatLng(relative);
  return GeoPoint(latitude: latLng.latitude, longitude: latLng.longitude);
}

/// La POINTE de l'épingle noire (22/24 de la hauteur du glyphe
/// `location_on`, boîte déplacée par `Transform.translate` comprise) — pas le
/// bas de la boîte de l'épingle.
Offset _pinTip(WidgetTester tester) {
  final Rect glyph = tester.getRect(
    find.descendant(
      of: find.byKey(designatedPointPinKey),
      matching: find.byWidgetPredicate(
        (Widget w) => w is Icon && w.color == Colors.black,
      ),
    ),
  );
  return Offset(glyph.center.dx, glyph.top + glyph.height * 22 / 24);
}

void _expectClose(GeoPoint actual, GeoPoint expected) {
  expect(actual.latitude, closeTo(expected.latitude, 1e-6));
  expect(actual.longitude, closeTo(expected.longitude, 1e-6));
}

/// La bande du bouton : la boîte du `ListView` de `_DesignationPlacement`,
/// seul `ListView` au-dessus du bouton. C'est elle, et non la pilule, qui
/// capte les gestes quand son `hitTestBehavior` est opaque.
Rect _bande(WidgetTester tester) => tester.getRect(
  find.ancestor(
    of: find.byKey(mapDesignateCenterButtonKey),
    matching: find.byType(ListView),
  ),
);

/// Un point DANS la bande du bouton, sur la rangée de la pilule, à mi-chemin
/// entre le bord gauche de la bande et celui de la pilule — donc hors de la
/// pilule et de l'indice. Calculé depuis les rectangles mesurés, jamais par
/// une constante : il ne peut pas retomber hors de la bande, où la carte reçoit
/// les gestes de toute façon et où le test ne prouverait plus rien. Les
/// garde-fous le disent.
Offset _pointDansLaBande(WidgetTester tester) {
  final Rect bande = _bande(tester);
  final Rect bouton = tester.getRect(find.byKey(mapDesignateCenterButtonKey));
  final Rect indice = tester.getRect(find.byKey(mapDesignateCenterHintKey));
  final Offset p = Offset((bande.left + bouton.left) / 2, bouton.center.dy);
  expect(
    bande.contains(p) && p.dx > bande.left,
    isTrue,
    reason: 'le point $p doit être DANS la bande $bande, pas sur son bord',
  );
  expect(
    bouton.contains(p),
    isFalse,
    reason: 'le point $p est dans la pilule $bouton',
  );
  expect(
    indice.contains(p),
    isFalse,
    reason: 'le point $p est dans l’indice $indice',
  );
  return p;
}

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

  final Element root = find.byType(MapView).evaluate().first;
  ancestor.evaluate().first.visitChildren(visit);
  // `root` sert seulement à échouer clairement si la vue n'est pas montée.
  expect(root, isNotNull);
  return found;
}

/// Les arrêts de tabulation parmi [attendus] (indices), dans l'ordre où Tab
/// les atteint, en au plus [maxTabs] appuis.
Future<List<int>> _tabStops(
  WidgetTester tester,
  List<Finder> attendus, {
  int maxTabs = 20,
}) async {
  final List<int> vus = <int>[];
  for (int i = 0; i < maxTabs && vus.length < attendus.length; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (int k = 0; k < attendus.length; k++) {
      if (_focusedWithin(attendus[k]) && (vus.isEmpty || vus.last != k)) {
        vus.add(k);
      }
    }
  }
  return vus;
}

void main() {
  // Fenêtre de 800 × 700 : le centre de la caméra est en (400, 350). Les
  // points d'appui sont hors des surcouches (avis en haut à gauche, légende
  // en haut à droite, contrôles en bas à droite).
  const Offset ecranCentre = Offset(400, 350);
  const Offset ailleurs = Offset(300, 450);

  Future<List<GeoPoint>> pumpMap(
    WidgetTester tester, {
    bool avecRappel = true,
    List<StationPoint> stations = const <StationPoint>[],
    List<StationCode>? stationTaps,
    bool fichesFermees = false,
    bool enMode = false,
  }) async {
    final List<GeoPoint> designated = <GeoPoint>[];
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final MapViewModel viewModel = _viewModel(stations: stations);
    await tester.pumpWidget(
      MaterialApp(
        home: MapView(
          viewModel: viewModel,
          onPointDesignated: avecRappel ? designated.add : null,
          onStationTap: fichesFermees ? (StationCode _) {} : stationTaps?.add,
          stationSheet: (stationTaps == null && !fichesFermees)
              ? null
              : const SizedBox.shrink(),
          // Comme `main.dart` : les deux panneaux fournis, vides à l'état
          // fermé.
          onOndeTap: fichesFermees ? (OndePoint _) {} : null,
          ondeSheet: fichesFermees ? const SizedBox.shrink() : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (stations.isNotEmpty) {
      // Échelle « débit » puis quatre crans de zoom : le niveau individuel
      // (zoom 9), où la station du centre est un marqueur (comme
      // `map_keyboard_test.dart`).
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
    }
    if (enMode) {
      // Le choix « Restrictions » allumé : état du ViewModel, que la vue
      // traduit en bouton, indice et réticule.
      viewModel.toggleDesignationMode();
      await tester.pumpAndSettle();
    }
    return designated;
  }

  group('gestes de désignation', () {
    testWidgets("l'appui long désigne le point sous le doigt, une seule fois", (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, ailleurs));
    });

    testWidgets('le clic droit désigne le point sous le pointeur, une seule '
        'fois', (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.tapAt(ailleurs, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, ailleurs));
    });

    testWidgets("le tap simple sur le fond de carte n'appelle pas le rappel", (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.tapAt(ailleurs);
      // Le délai de double-tap de `flutter_map` (250 ms) doit expirer.
      await tester.pump(const Duration(seconds: 1));

      expect(designated, isEmpty);
    });

    testWidgets("l'appui long commencé SUR un marqueur désigne le lieu sous "
        "le pointeur et n'ouvre pas la fiche", (WidgetTester tester) async {
      final List<StationCode> stationTaps = <StationCode>[];
      final List<GeoPoint> designated = await pumpMap(
        tester,
        stations: <StationPoint>[_stationAuCentre()],
        stationTaps: stationTaps,
      );
      expect(find.byType(MarkerLayer), findsOneWidget);

      await tester.longPressAt(ecranCentre);
      await tester.pumpAndSettle();

      expect(stationTaps, isEmpty);
      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, ecranCentre));
    });

    testWidgets('le tap simple sur un marqueur ouvre toujours sa fiche et ne '
        'désigne rien', (WidgetTester tester) async {
      final List<StationCode> stationTaps = <StationCode>[];
      final List<GeoPoint> designated = await pumpMap(
        tester,
        stations: <StationPoint>[_stationAuCentre()],
        stationTaps: stationTaps,
      );

      await tester.tapAt(ecranCentre);
      await tester.pumpAndSettle();

      expect(stationTaps, <StationCode>[StationCode('K447001001')]);
      expect(designated, isEmpty);
    });

    testWidgets('rappel null : les gestes sont sans effet, sans erreur, et '
        'aucune épingle', (WidgetTester tester) async {
      await pumpMap(tester, avecRappel: false);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();
      await tester.tapAt(ailleurs, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(designatedPointPinKey), findsNothing);
    });

    testWidgets('rappel null, même mode actif : ni puce, ni bouton, ni '
        'indice, ni réticule, et gestes sans effet', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, avecRappel: false, enMode: true);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();
      await tester.tapAt(ailleurs, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(mapDesignationChipKey), findsNothing);
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(find.byKey(designatedPointPinKey), findsNothing);
    });

    testWidgets('MapOptions reste la MÊME instance après une désignation '
        '(setState) : références de méthode, jamais de fermeture (NFR-01)', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester);
      final MapOptions avant = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();

      expect(find.byKey(designatedPointPinKey), findsOneWidget);
      expect(
        identical(
          tester.widget<FlutterMap>(find.byType(FlutterMap)).options,
          avant,
        ),
        isTrue,
      );
    });
  });

  group('hors mode, désignation câblée (E5 de T2)', () {
    testWidgets('ni bouton, ni indice, ni réticule ; la puce « Restrictions » '
        'est là et éteinte', (WidgetTester tester) async {
      await pumpMap(tester);

      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(find.byKey(mapDesignationChipKey))
            .properties
            .toggled,
        isFalse,
      );
    });

    testWidgets("l'appui long désigne quand même, une fois, au bon GeoPoint, "
        "et pose l'épingle", (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, ailleurs));
      expect(find.byKey(designatedPointPinKey), findsOneWidget);
    });

    testWidgets('le clic droit désigne quand même, une fois, au bon GeoPoint, '
        "et pose l'épingle", (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.tapAt(ailleurs, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, ailleurs));
      expect(find.byKey(designatedPointPinKey), findsOneWidget);
    });

    testWidgets('Tab : les deux échelles, « Restrictions », +, −, recentrer, '
        'puis la carte SANS arrêt intermédiaire, puis « ⚠ Avertissement »', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester);

      final List<Finder> attendus = <Finder>[
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        find.byKey(mapDesignationChipKey),
        find.byKey(mapZoomInButtonKey),
        find.byKey(mapZoomOutButtonKey),
        find.byKey(mapRecenterButtonKey),
        find.byType(FlutterMap),
        find.byType(WarningLink),
      ];
      expect(await _tabStops(tester, attendus), <int>[
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ], reason: 'aucun arrêt entre « recentrer » et la carte hors mode');
    });
  });

  group('en mode Restrictions (E5 de T2)', () {
    testWidgets('un tap sur la puce fait apparaître bouton, indice et '
        'réticule (au centre exact, inerte) ; un second tap les retire', (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester);

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
      expect(find.byKey(mapDesignateCenterHintKey), findsOneWidget);
      expect(find.byKey(mapCenterReticleKey), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(mapCenterReticleKey)),
        tester.getCenter(find.byType(FlutterMap)),
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(mapDesignationChipKey))
            .properties
            .toggled,
        isTrue,
      );
      // Allumer le mode ne désigne rien.
      expect(designated, isEmpty);

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(designated, isEmpty);
    });

    testWidgets("marqueurs et légende de l'échelle en cours restent rendus : "
        'un marqueur de station au zoom 9 reste tapable et ouvre sa fiche', (
      WidgetTester tester,
    ) async {
      final List<StationCode> stationTaps = <StationCode>[];
      await pumpMap(
        tester,
        stations: <StationPoint>[_stationAuCentre()],
        stationTaps: stationTaps,
      );
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();

      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(
        tester.widget<MapLegend>(find.byType(MapLegend)).scale,
        MapScaleKind.debit,
      );

      // Le réticule est AU-DESSUS du marqueur (même point) et inerte : le
      // tap atteint le marqueur.
      await tester.tapAt(ecranCentre);
      await tester.pumpAndSettle();

      expect(stationTaps, <StationCode>[StationCode('K447001001')]);
    });

    testWidgets("changer d'échelle en mode garde bouton et réticule, et "
        "'Restrictions' reste allumée", (WidgetTester tester) async {
      await pumpMap(tester, enMode: true);

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
      expect(find.byKey(mapCenterReticleKey), findsOneWidget);
      expect(
        tester.widget<MapLegend>(find.byType(MapLegend)).scale,
        MapScaleKind.debit,
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(mapDesignationChipKey))
            .properties
            .toggled,
        isTrue,
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
            )
            .properties
            .selected,
        isTrue,
      );
    });

    testWidgets('MapOptions reste la MÊME instance après une bascule du mode '
        '(NFR-01)', (WidgetTester tester) async {
      await pumpMap(tester);
      final MapOptions avant = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);

      expect(
        identical(
          tester.widget<FlutterMap>(find.byType(FlutterMap)).options,
          avant,
        ),
        isTrue,
      );
    });

    testWidgets('appui long et clic droit désignent aussi en mode', (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();
      await tester.tapAt(ailleurs, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(designated, hasLength(2));
    });

    testWidgets('Tab : les deux échelles, « Restrictions », +, −, recentrer, '
        'le bouton, la carte, puis « ⚠ Avertissement »', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, enMode: true);

      final List<Finder> attendus = <Finder>[
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        find.byKey(mapDesignationChipKey),
        find.byKey(mapZoomInButtonKey),
        find.byKey(mapZoomOutButtonKey),
        find.byKey(mapRecenterButtonKey),
        find.byKey(mapDesignateCenterButtonKey),
        find.byType(FlutterMap),
        find.byType(WarningLink),
      ];
      expect(await _tabStops(tester, attendus), <int>[
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
    });
  });

  group('bouton « Restrictions au centre de la carte »', () {
    testWidgets('absent quand le rappel est nul', (WidgetTester tester) async {
      await pumpMap(tester, avecRappel: false);

      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
    });

    testWidgets('présent, libellé sémantique exact, au moins minimumTapTarget '
        'de côté', (WidgetTester tester) async {
      await pumpMap(tester, enMode: true);

      final Finder bouton = find.byKey(mapDesignateCenterButtonKey);
      expect(bouton, findsOneWidget);
      expect(
        tester.getSemantics(bouton),
        matchesSemantics(
          label: 'Restrictions au centre de la carte',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      final Size size = tester.getSize(bouton);
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    });

    testWidgets('un tap désigne le centre de la caméra', (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);

      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      final LatLng centre = _camera(tester).center;
      _expectClose(
        designated.single,
        GeoPoint(latitude: centre.latitude, longitude: centre.longitude),
      );
    });

    testWidgets('atteint par Tab, activé par Entrée puis par Espace', (
      WidgetTester tester,
    ) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);

      int essais = 0;
      bool precedentEtaitRecentrage = false;
      while (!_focusedWithin(find.byKey(mapDesignateCenterButtonKey)) &&
          essais < 12) {
        precedentEtaitRecentrage = _focusedWithin(
          find.byKey(mapRecenterButtonKey),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        essais++;
      }
      expect(
        precedentEtaitRecentrage,
        isTrue,
        reason: 'ordre K2 : le bouton suit celui de recentrage',
      );
      expect(
        _focusedWithin(find.byKey(mapDesignateCenterButtonKey)),
        isTrue,
        reason: 'Tab doit atteindre le bouton',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(designated, hasLength(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(designated, hasLength(2));
    });

    testWidgetsOnWindows('52 pt de haut, en bas au centre de la carte, hors '
        'de la colonne des contrôles', (WidgetTester tester) async {
      await pumpMap(tester, enMode: true);

      final Rect bouton = tester.getRect(
        find.byKey(mapDesignateCenterButtonKey),
      );
      expect(bouton.height, greaterThanOrEqualTo(52));
      expect(bouton.center.dx, closeTo(400, 0.5));
      expect(bouton.bottom, greaterThan(500));
      expect(
        find.descendant(
          of: find.byType(MapControls),
          matching: find.byKey(mapDesignateCenterButtonKey),
        ),
        findsNothing,
      );
    });

    testWidgets('Tab : atteint juste APRÈS +, − et recentrer, puis la carte '
        'suit', (WidgetTester tester) async {
      await pumpMap(tester, enMode: true);

      final List<Finder> attendus = <Finder>[
        find.byKey(mapZoomInButtonKey),
        find.byKey(mapZoomOutButtonKey),
        find.byKey(mapRecenterButtonKey),
        find.byKey(mapDesignateCenterButtonKey),
      ];
      final List<int> vus = <int>[];
      for (int i = 0; i < 14 && vus.length < attendus.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (int k = 0; k < attendus.length; k++) {
          if (_focusedWithin(attendus[k]) && (vus.isEmpty || vus.last != k)) {
            vus.add(k);
          }
        }
      }
      expect(vus, <int>[0, 1, 2, 3], reason: 'ordre des contrôles');

      // Le prochain arrêt est la carte elle-même (`mapTraversalOrderCarte`),
      // pas un contrôle ni la fiche.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedWithin(find.byType(FlutterMap)), isTrue);
      for (final Finder f in attendus) {
        expect(_focusedWithin(f), isFalse);
      }
    });
  });

  group('production : fiches FERMÉES mais fournies (main.dart)', () {
    // `main.dart` passe TOUJOURS `stationSheet` et `ondeSheet` (panneaux qui
    // se rendent vides à l'état fermé) : la disposition ne doit pas en
    // dépendre.
    for (final Size taille in <Size>[
      const Size(1920, 1032),
      const Size(800, 740),
    ]) {
      testWidgets(
        'à ${taille.width.toInt()} × ${taille.height.toInt()}, bouton ET '
        'indice sont centrés sur la carte',
        (WidgetTester tester) async {
          tester.view.physicalSize = taille;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final MapViewModel viewModel = _viewModel()..toggleDesignationMode();
          await tester.pumpWidget(
            MaterialApp(
              home: MapView(
                viewModel: viewModel,
                onPointDesignated: (GeoPoint _) {},
                onStationTap: (StationCode _) {},
                stationSheet: const SizedBox.shrink(),
                onOndeTap: (OndePoint _) {},
                ondeSheet: const SizedBox.shrink(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final double centre = tester.getCenter(find.byType(FlutterMap)).dx;
          expect(
            tester.getCenter(find.byKey(mapDesignateCenterButtonKey)).dx,
            closeTo(centre, 1),
          );
          expect(
            tester.getCenter(find.byKey(mapDesignateCenterHintKey)).dx,
            closeTo(centre, 1),
          );
        },
      );
    }
  });

  group('bande du bouton : la carte garde ses gestes', () {
    // Un point DANS la bande horizontale du bouton, mais hors du bouton et de
    // son indice : le conteneur du bouton ne doit rien capter là. Le point est
    // calculé depuis la bande mesurée (`_pointDansLaBande`), pas par une
    // constante : à x = 62 il tombait à 2 px HORS de la bande, et le défaut
    // — une bande opaque — passait inaperçu.
    Future<Offset> dansLaBande(WidgetTester tester) async =>
        _pointDansLaBande(tester);

    testWidgets('appui long', (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);
      final Offset p = await dansLaBande(tester);

      await tester.longPressAt(p);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, p));
    });

    testWidgets('clic droit', (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);
      final Offset p = await dansLaBande(tester);

      await tester.tapAt(p, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(designated, hasLength(1));
    });

    testWidgets('glisser : la carte se déplace', (WidgetTester tester) async {
      await pumpMap(tester, enMode: true);
      final Offset p = await dansLaBande(tester);
      final LatLng avant = _camera(tester).center;

      await tester.dragFrom(p, const Offset(-30, 0));
      await tester.pumpAndSettle();

      expect(_camera(tester).center, isNot(avant));
    });
  });

  group('bande du bouton : molette', () {
    testWidgets('la molette zoome la carte dans la bande, hors du bouton', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, enMode: true);
      final Offset p = _pointDansLaBande(tester);
      final double avant = _camera(tester).zoom;

      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(p));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, isNot(avant));
    });
  });

  group('fiches fermées fournies (main.dart) : gestes hors du bouton', () {
    // (a) dans la bande, hors bouton et indice — le point est calculé depuis
    // la bande mesurée, il ne peut pas retomber hors d'elle ; (b) à gauche
    // AU-DESSUS de la bande. Verrous : la carte doit recevoir les gestes dans
    // les deux cas.
    for (final (String, Offset Function(WidgetTester)) zone
        in <(String, Offset Function(WidgetTester))>[
          ('dans la bande', _pointDansLaBande),
          (
            'au-dessus de la bande',
            (WidgetTester t) => Offset(
              62,
              t.getRect(find.byKey(mapDesignateCenterButtonKey)).top - 24,
            ),
          ),
        ]) {
      Future<Offset> point(WidgetTester tester) async {
        final Rect bouton = tester.getRect(
          find.byKey(mapDesignateCenterButtonKey),
        );
        final Offset p = zone.$2(tester);
        expect(bouton.contains(p), isFalse);
        expect(
          tester.getRect(find.byKey(mapDesignateCenterHintKey)).contains(p),
          isFalse,
        );
        return p;
      }

      testWidgets('${zone.$1} : appui long', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(
          tester,
          fichesFermees: true,
          enMode: true,
        );
        final Offset p = await point(tester);

        await tester.longPressAt(p);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
        _expectClose(designated.single, _pointAt(tester, p));
      });

      testWidgets('${zone.$1} : clic droit', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(
          tester,
          fichesFermees: true,
          enMode: true,
        );
        final Offset p = await point(tester);

        await tester.tapAt(p, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
      });

      testWidgets('${zone.$1} : glisser', (WidgetTester tester) async {
        await pumpMap(tester, fichesFermees: true, enMode: true);
        final Offset p = await point(tester);
        final LatLng avant = _camera(tester).center;

        await tester.dragFrom(p, const Offset(-30, 0));
        await tester.pumpAndSettle();

        expect(_camera(tester).center, isNot(avant));
      });

      testWidgets('${zone.$1} : molette', (WidgetTester tester) async {
        await pumpMap(tester, fichesFermees: true, enMode: true);
        final Offset p = await point(tester);
        final double avant = _camera(tester).zoom;

        final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(p));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
        await tester.pumpAndSettle();

        expect(_camera(tester).zoom, isNot(avant));
      });
    }
  });

  group('indice et réticule', () {
    testWidgets('présents avec le bouton, indice sous lui', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, enMode: true);

      expect(find.byKey(mapDesignateCenterHintKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(mapDesignateCenterHintKey)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(mapDesignateCenterButtonKey)).dy,
        ),
      );
      expect(find.byKey(mapCenterReticleKey), findsOneWidget);
    });

    testWidgets('le réticule est au centre EXACT de la carte, inerte', (
      WidgetTester tester,
    ) async {
      // Une station au centre : sans elle, l'avis d'absence (`BR-007`) que la
      // troisième puce fait descendre jusqu'au centre en police de test
      // capterait lui-même l'appui long (E5), et le test ne porterait plus
      // sur le réticule.
      final List<GeoPoint> designated = await pumpMap(
        tester,
        enMode: true,
        stations: <StationPoint>[_stationAuCentre()],
        stationTaps: <StationCode>[],
      );

      final Offset carte = tester.getCenter(find.byType(FlutterMap));
      expect(tester.getCenter(find.byKey(mapCenterReticleKey)), carte);
      // Un appui long sur le réticule désigne le point de la carte dessous :
      // il n'intercepte aucun geste.
      await tester.longPressAt(carte);
      await tester.pumpAndSettle();
      expect(designated, hasLength(1));
      _expectClose(designated.single, _pointAt(tester, carte));
    });

    testWidgets('absents quand le rappel est nul', (WidgetTester tester) async {
      await pumpMap(tester, avecRappel: false);

      expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
    });
  });

  group('épingle du point désigné', () {
    testWidgets('absente avant toute désignation', (WidgetTester tester) async {
      await pumpMap(tester);

      expect(find.byKey(designatedPointPinKey), findsNothing);
    });

    testWidgets("dessinée au point désigné après un appui long, puis un clic "
        "droit, puis le bouton — une seule épingle, déplacée à chaque fois", (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, enMode: true);

      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();
      expect(find.byKey(designatedPointPinKey), findsOneWidget);
      expect(_pinTip(tester).dx, closeTo(ailleurs.dx, 1));
      expect(_pinTip(tester).dy, closeTo(ailleurs.dy, 1));

      const Offset autre = Offset(500, 450);
      await tester.tapAt(autre, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(designatedPointPinKey), findsOneWidget);
      expect(_pinTip(tester).dx, closeTo(autre.dx, 1));
      expect(_pinTip(tester).dy, closeTo(autre.dy, 1));

      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(designatedPointPinKey), findsOneWidget);
      expect(
        _pinTip(tester).dx,
        closeTo(tester.getTopLeft(find.byType(FlutterMap)).dx + 400, 1),
      );
      expect(
        _pinTip(tester).dy,
        closeTo(tester.getTopLeft(find.byType(FlutterMap)).dy + 350, 1),
      );
    });

    testWidgets("reste là après un déplacement de caméra, et suit le lieu", (
      WidgetTester tester,
    ) async {
      await pumpMap(tester);
      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();
      final Offset avant = _pinTip(tester);

      await tester.dragFrom(const Offset(600, 500), const Offset(-100, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(designatedPointPinKey), findsOneWidget);
      final Offset apres = _pinTip(tester);
      expect(apres.dx, closeTo(avant.dx - 100, 2));
    });

    testWidgets('ne capte aucun tap : un tap à sa position atteint le '
        'marqueur dessous', (WidgetTester tester) async {
      final List<StationCode> stationTaps = <StationCode>[];
      await pumpMap(
        tester,
        stations: <StationPoint>[_stationAuCentre()],
        stationTaps: stationTaps,
      );

      // Désigne le centre de l'écran : la pointe est sur le marqueur, le
      // corps de l'épingle couvre sa moitié haute.
      await tester.longPressAt(ecranCentre);
      await tester.pumpAndSettle();
      expect(find.byKey(designatedPointPinKey), findsOneWidget);

      final Rect pin = tester.getRect(find.byKey(designatedPointPinKey));
      final Offset dansLesDeux = Offset(ecranCentre.dx, ecranCentre.dy - 10);
      expect(pin.contains(dansLesDeux), isTrue);

      await tester.tapAt(dansLesDeux);
      await tester.pumpAndSettle();

      expect(stationTaps, <StationCode>[StationCode('K447001001')]);
    });

    testWidgets("est exclue de la tabulation et de l'arbre sémantique "
        'interactif', (WidgetTester tester) async {
      await pumpMap(tester);
      await tester.longPressAt(ailleurs);
      await tester.pumpAndSettle();

      final Finder pin = find.byKey(designatedPointPinKey);
      expect(
        find.descendant(
          of: pin,
          matching: find.byWidgetPredicate(
            (Widget w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsWidgets,
      );
      for (int i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedWithin(pin), isFalse);
      }

      // Aucun nœud sémantique nommé ou actionnable sur l'épingle.
      final Offset centre = tester.getCenter(pin);
      final List<String> trouves = <String>[];
      void visit(SemanticsNode node, Matrix4 parent) {
        final Matrix4 matrix = node.transform == null
            ? parent
            : parent.multiplied(node.transform!);
        final Rect global = MatrixUtils.transformRect(matrix, node.rect);
        final bool porteQuelqueChose =
            node.label.isNotEmpty ||
            node.getSemanticsData().hasAction(SemanticsAction.tap);
        // Les nœuds plein écran (racine, fond de carte fusionné) contiennent
        // tout point : seuls comptent ceux qui ont la taille d'un contrôle.
        final bool petit = global.width <= 100 && global.height <= 100;
        if (porteQuelqueChose && petit && global.contains(centre)) {
          trouves.add('${node.label} $global');
        }
        node.visitChildren((SemanticsNode c) {
          visit(c, matrix);
          return true;
        });
      }

      visit(
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!,
        Matrix4.identity(),
      );
      expect(trouves, isEmpty);
    });
  });
}

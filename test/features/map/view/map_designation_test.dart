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
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart'
    show maximumMapZoom;
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/windows_platform.dart';

final class _Stations implements StationPointRepository {
  _Stations(this.points, {this.chargements});

  final List<StationPoint> points;

  /// Les emprises demandées, dans l'ordre : un chargement par entrée. Sert à
  /// prouver qu'un geste recharge — ou, pour `NFR-01`, ne recharge PAS.
  final List<Bounds>? chargements;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    chargements?.add(bounds);
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

MapViewModel _viewModel({
  List<StationPoint> stations = const <StationPoint>[],
  List<Bounds>? chargements,
}) => MapViewModel(
  stationPoints: _Stations(stations, chargements: chargements),
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

/// Un `testWidgets` posé sur une plateforme : les verrous de gestes ci-dessous
/// sont rejoués sur Android (la plateforme par défaut de `flutter test`) ET sur
/// Windows, la première cible du produit. Les deux n'ont pas le même
/// comportement de défilement : `MaterialScrollBehavior` pose une `Scrollbar`
/// automatique sur les défilements verticaux du bureau, pas sur ceux d'Android.
typedef _Test = void Function(
  String description,
  Future<void> Function(WidgetTester tester) corps,
);

void _surAndroid(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgets(d, corps);

void _surWindows(String d, Future<void> Function(WidgetTester tester) corps) =>
    testWidgetsOnWindows(d, corps);

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

/// La fenêtre de la colonne DROITE de la disposition large : le
/// `SingleChildScrollView` qui porte le contrôle d'avertissement et la légende.
Rect _colonneDroite(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.byType(WarningLink),
        matching: find.byType(SingleChildScrollView),
      )
      .first,
);

/// Un point DANS la colonne droite, sur la rangée du contrôle d'avertissement,
/// à mi-chemin entre le bord gauche de la colonne et celui du contrôle — donc
/// hors du contrôle et de la légende : de la carte visible, au sens de
/// l'usager. Calculé depuis les rectangles mesurés ; les garde-fous disent s'il
/// retombait hors de la colonne ou dans l'un de ses enfants.
Offset _pointAGaucheDuLien(WidgetTester tester) {
  final Rect colonne = _colonneDroite(tester);
  final Rect lien = tester.getRect(find.byType(WarningLink));
  final Rect legende = tester.getRect(find.byType(MapLegend));
  final Offset p = Offset((colonne.left + lien.left) / 2, lien.center.dy);
  expect(
    colonne.contains(p) && p.dx > colonne.left,
    isTrue,
    reason: 'le point $p doit être DANS la colonne $colonne, pas sur son bord',
  );
  expect(lien.contains(p), isFalse, reason: 'le point $p est dans le lien');
  expect(
    legende.contains(p),
    isFalse,
    reason: 'le point $p est dans la légende',
  );
  return p;
}

/// La fenêtre de la colonne GAUCHE de la disposition large : le
/// `SingleChildScrollView` qui porte les puces d'échelle et les avis.
Rect _colonneGauche(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.byType(MapScaleChips),
        matching: find.byType(SingleChildScrollView),
      )
      .first,
);

/// Un point DANS la colonne gauche, sur la rangée des puces, à mi-chemin entre
/// le bord droit des puces et celui de la colonne — donc hors de tout enfant
/// de la colonne. Les garde-fous disent s'il retombait hors de la colonne ou
/// dans un enfant (cas où la colonne n'a pas de zone vide à cet endroit).
Offset _pointADroiteDesPuces(WidgetTester tester) {
  final Rect colonne = _colonneGauche(tester);
  final Rect puces = tester.getRect(find.byType(MapScaleChips));
  final Offset p = Offset((puces.right + colonne.right) / 2, puces.center.dy);
  expect(
    colonne.contains(p) && p.dx < colonne.right,
    isTrue,
    reason: 'le point $p doit être DANS la colonne $colonne, pas sur son bord',
  );
  expect(puces.contains(p), isFalse, reason: 'le point $p est dans les puces');
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
    Size taille = const Size(800, 700),
    List<Bounds>? chargements,
  }) async {
    final List<GeoPoint> designated = <GeoPoint>[];
    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final MapViewModel viewModel = _viewModel(
      stations: stations,
      chargements: chargements,
    );
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

  // Les verrous de gestes de la bande du bouton et des fiches fermées, posés
  // sur une plateforme donnée. Sur Windows, la fenêtre mesure 800 × 740, sa
  // taille minimale (`K3`) : c'est la plus petite fenêtre que le bureau montre.
  void verrousDeGestes(String suffixe, _Test test, Size taille) {
    group('bande du bouton : la carte garde ses gestes$suffixe', () {
      // Un point DANS la bande horizontale du bouton, mais hors du bouton et
      // de son indice : le conteneur du bouton ne doit rien capter là. Le
      // point est calculé depuis la bande mesurée (`_pointDansLaBande`), pas
      // par une constante : à x = 62 il tombait à 2 px HORS de la bande, et le
      // défaut — une bande opaque — passait inaperçu.
      Future<Offset> dansLaBande(WidgetTester tester) async =>
          _pointDansLaBande(tester);

      test('appui long', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(
          tester,
          enMode: true,
          taille: taille,
        );
        final Offset p = await dansLaBande(tester);

        await tester.longPressAt(p);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
        _expectClose(designated.single, _pointAt(tester, p));
      });

      test('clic droit', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(
          tester,
          enMode: true,
          taille: taille,
        );
        final Offset p = await dansLaBande(tester);

        await tester.tapAt(p, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
      });

      test('glisser : la carte se déplace', (WidgetTester tester) async {
        await pumpMap(tester, enMode: true, taille: taille);
        final Offset p = await dansLaBande(tester);
        final LatLng avant = _camera(tester).center;

        await tester.dragFrom(p, const Offset(-30, 0));
        await tester.pumpAndSettle();

        expect(_camera(tester).center, isNot(avant));
      });
    });

    group('bande du bouton : molette$suffixe', () {
      test('la molette zoome la carte dans la bande, hors du bouton', (
        WidgetTester tester,
      ) async {
        await pumpMap(tester, enMode: true, taille: taille);
        final Offset p = _pointDansLaBande(tester);
        final double avant = _camera(tester).zoom;

        final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(p));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
        await tester.pumpAndSettle();

        expect(_camera(tester).zoom, isNot(avant));
      });
    });

    group('colonne droite (avertissement, légende) : la carte garde ses '
        'gestes$suffixe', () {
      // La colonne est large comme la légende ; le contrôle d'avertissement,
      // plus étroit, laisse à sa gauche une zone qui est de la carte pour
      // l'usager. Hors mode : la colonne ne dépend pas du mode.
      test("clic droit à gauche du contrôle d'avertissement", (
        WidgetTester tester,
      ) async {
        final List<GeoPoint> designated = await pumpMap(tester, taille: taille);
        final Offset p = _pointAGaucheDuLien(tester);

        await tester.tapAt(p, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
        _expectClose(designated.single, _pointAt(tester, p));
      });

      test("appui long à gauche du contrôle d'avertissement", (
        WidgetTester tester,
      ) async {
        final List<GeoPoint> designated = await pumpMap(tester, taille: taille);
        final Offset p = _pointAGaucheDuLien(tester);

        await tester.longPressAt(p);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
      });

      test("glisser à gauche du contrôle d'avertissement : la carte se "
          'déplace', (WidgetTester tester) async {
        await pumpMap(tester, taille: taille);
        final Offset p = _pointAGaucheDuLien(tester);
        final LatLng avant = _camera(tester).center;

        await tester.dragFrom(p, const Offset(-30, 0));
        await tester.pumpAndSettle();

        expect(_camera(tester).center, isNot(avant));
      });

      test("molette à gauche du contrôle d'avertissement : la carte zoome", (
        WidgetTester tester,
      ) async {
        await pumpMap(tester, taille: taille);
        final Offset p = _pointAGaucheDuLien(tester);
        final double avant = _camera(tester).zoom;

        final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(p));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
        await tester.pumpAndSettle();

        expect(_camera(tester).zoom, isNot(avant));
      });
    });

    group('colonne gauche (puces, avis) : la carte garde ses gestes$suffixe', () {
      // Sans station, un avis d'absence est affiché sous les puces : la colonne
      // est large comme l'avis, plus large que les puces, et laisse à droite
      // des puces une zone qui est de la carte pour l'usager.
      test('clic droit à droite des puces', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(tester, taille: taille);
        final Offset p = _pointADroiteDesPuces(tester);

        await tester.tapAt(p, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
        _expectClose(designated.single, _pointAt(tester, p));
      });

      test('appui long à droite des puces', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(tester, taille: taille);
        final Offset p = _pointADroiteDesPuces(tester);

        await tester.longPressAt(p);
        await tester.pumpAndSettle();

        expect(designated, hasLength(1));
      });

      test('glisser à droite des puces : la carte se déplace', (
        WidgetTester tester,
      ) async {
        await pumpMap(tester, taille: taille);
        final Offset p = _pointADroiteDesPuces(tester);
        final LatLng avant = _camera(tester).center;

        await tester.dragFrom(p, const Offset(-30, 0));
        await tester.pumpAndSettle();

        expect(_camera(tester).center, isNot(avant));
      });

      test('molette à droite des puces : la carte zoome', (
        WidgetTester tester,
      ) async {
        await pumpMap(tester, taille: taille);
        final Offset p = _pointADroiteDesPuces(tester);
        final double avant = _camera(tester).zoom;

        final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(p));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
        await tester.pumpAndSettle();

        expect(_camera(tester).zoom, isNot(avant));
      });
    });

    group('fiches fermées fournies (main.dart) : gestes hors du bouton$suffixe', () {
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

        test('${zone.$1} : appui long', (WidgetTester tester) async {
          final List<GeoPoint> designated = await pumpMap(
            tester,
            fichesFermees: true,
            enMode: true,
            taille: taille,
          );
          final Offset p = await point(tester);

          await tester.longPressAt(p);
          await tester.pumpAndSettle();

          expect(designated, hasLength(1));
          _expectClose(designated.single, _pointAt(tester, p));
        });

        test('${zone.$1} : clic droit', (WidgetTester tester) async {
          final List<GeoPoint> designated = await pumpMap(
            tester,
            fichesFermees: true,
            enMode: true,
            taille: taille,
          );
          final Offset p = await point(tester);

          await tester.tapAt(p, buttons: kSecondaryButton);
          await tester.pumpAndSettle();

          expect(designated, hasLength(1));
        });

        test('${zone.$1} : glisser', (WidgetTester tester) async {
          await pumpMap(
            tester,
            fichesFermees: true,
            enMode: true,
            taille: taille,
          );
          final Offset p = await point(tester);
          final LatLng avant = _camera(tester).center;

          await tester.dragFrom(p, const Offset(-30, 0));
          await tester.pumpAndSettle();

          expect(_camera(tester).center, isNot(avant));
        });

        test('${zone.$1} : molette', (WidgetTester tester) async {
          await pumpMap(
            tester,
            fichesFermees: true,
            enMode: true,
            taille: taille,
          );
          final Offset p = await point(tester);
          final double avant = _camera(tester).zoom;

          final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(pointer.hover(p));
          await tester.sendEventToBinding(
            pointer.scroll(const Offset(0, -100)),
          );
          await tester.pumpAndSettle();

          expect(_camera(tester).zoom, isNot(avant));
        });
      }
    });
  }

  verrousDeGestes('', _surAndroid, const Size(800, 700));
  verrousDeGestes(' — Windows', _surWindows, const Size(800, 740));

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

  group('défilements de surcouche : aucun ne s’attache au '
      'PrimaryScrollController de la route', () {
    // Sur les plateformes mobiles, un défilement vertical sans contrôleur
    // hérite du `PrimaryScrollController` de la route
    // (`PrimaryScrollController.shouldInherit`, `SingleChildScrollView` et
    // `ScrollView`). Les surcouches sont des défilements FRÈRES : ils s'y
    // attachent ensemble, et `PageDown` (clavier matériel, focus sur la carte)
    // lève « more than one ScrollPosition is attached » dans `ScrollAction`.
    // `testWidgets` tourne en Android : c'est la plateforme concernée.
    for (final (String, Size, bool) cas in <(String, Size, bool)>[
      ('800 × 700, hors mode', const Size(800, 700), false),
      ('800 × 700, en mode Restrictions', const Size(800, 700), true),
      ('360 × 640, hors mode', const Size(360, 640), false),
      ('360 × 640, en mode Restrictions', const Size(360, 640), true),
    ]) {
      testWidgets('${cas.$1} : aucune position attachée, PageDown depuis la '
          'carte sans erreur', (WidgetTester tester) async {
        await pumpMap(tester, enMode: cas.$3, taille: cas.$2);

        final ScrollController primaire = PrimaryScrollController.of(
          tester.element(find.byType(MapView)),
        );
        expect(
          primaire.positions,
          isEmpty,
          reason:
              'les surcouches ne doivent pas se brancher au contrôleur de '
              'la route',
        );

        // Le focus sur la carte : hors de tout défilement de surcouche.
        for (
          int i = 0;
          i < 20 && !_focusedWithin(find.byType(FlutterMap));
          i++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(_focusedWithin(find.byType(FlutterMap)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });

  // Où est le bord de la caméra par rapport à celui du monde, en pixels : 0 =
  // collé, négatif = la carte montre du vide au-delà du monde. Mesuré sur le
  // centre projeté et la hauteur de la caméra, jamais sur `visibleBounds` :
  // celui-ci arrondit le centre au pixel inférieur (`MapCamera.pixelBounds`,
  // `floor()`), ce qui décale le bord bas d'un pixel — 0,0076° à 85°.
  double ecartAuHautDuMonde(MapCamera camera) =>
      camera.projectAtZoom(camera.center).dy - camera.size.height / 2;
  double ecartAuBasDuMonde(MapCamera camera) =>
      camera.crs.scale(camera.zoom) -
      (camera.projectAtZoom(camera.center).dy + camera.size.height / 2);

  // Un `Tab` pour entrer sous le `Shortcuts` de la carte : sans focus sous lui,
  // une flèche ou `−` n'atteint rien.
  Future<void> entrerSousLesRaccourcis(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }

  // Entrer sous les raccourcis, puis `−` jusqu'au zoom minimal : à ce zoom, un
  // cran de flèche vaut plusieurs degrés.
  Future<void> versLeZoomMinimum(WidgetTester tester) async {
    await entrerSousLesRaccourcis(tester);
    for (int i = 0; i < 6 && _camera(tester).zoom > 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();
    }
    expect(_camera(tester).zoom, 4);
  }

  /// [fois] pressions de [touche], chacune suivie d'un `pumpAndSettle`.
  Future<void> appuyer(
    WidgetTester tester,
    LogicalKeyboardKey touche,
    int fois,
  ) async {
    for (int i = 0; i < fois; i++) {
      await tester.sendKeyEvent(touche);
      await tester.pumpAndSettle();
    }
  }

  group('coordonnées désignées : toujours dans les bornes de GeoPoint', () {
    // `GeoPoint` lève une `ArgumentError` hors de [-90, 90] et [-180, 180].
    // Latitude : la caméra est contrainte au monde (`cameraConstraint:
    // containLatitude()`, arbitrage du commanditaire du 2026-10-06), donc son
    // centre ne sort plus de ±85,0511° ; avant, `flutter_map` 8.3.2 n'appliquait
    // aucune contrainte et la flèche Haut ou Bas poussait le centre au-delà
    // d'un pôle. Longitude : hypothèse vérifiée, et écartée — un point tapé sur
    // une réplique du monde, au-delà de l'antiméridien, a une longitude toujours
    // repliée dans [-180, 180]. Le bouton, l'appui long et le clic droit ne
    // doivent jamais lever.
    for (final (String, LogicalKeyboardKey, LogicalKeyboardKey, double) sens
        in <(String, LogicalKeyboardKey, LogicalKeyboardKey, double)>[
          ('Haut', LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, 1),
          ('Bas', LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp, -1),
        ]) {
      final String nom = sens.$1;
      final LogicalKeyboardKey vers = sens.$2;
      final LogicalKeyboardKey retour = sens.$3;
      final double signe = sens.$4;

      testWidgets('flèche $nom répétée 40 fois au zoom 4 : le centre reste dans '
          'le monde à chaque cran, puis le bouton désigne le point SOUS le '
          'réticule, sans lever', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(tester, enMode: true);
        await versLeZoomMinimum(tester);

        for (int i = 0; i < 40; i++) {
          await tester.sendKeyEvent(vers);
          await tester.pumpAndSettle();
          expect(
            _camera(tester).center.latitude.abs(),
            lessThanOrEqualTo(SphericalMercator.maxLatitude),
            reason: 'cran $i : le centre de la caméra est sorti du monde',
          );
        }
        final MapCamera camera = _camera(tester);
        // Garde-fou : la butée est atteinte — le bord de la carte est celui du
        // monde, ni en deçà (la flèche n'a pas fini sa course), ni au-delà.
        expect(
          signe > 0 ? ecartAuHautDuMonde(camera) : ecartAuBasDuMonde(camera),
          closeTo(0, 1e-6),
        );

        await tester.tap(find.byKey(mapDesignateCenterButtonKey));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(designated, hasLength(1));
        // Le point désigné est celui que la caméra rend pour le centre de
        // l'écran — le point sous le réticule —, et celui de son centre.
        _expectClose(
          designated.single,
          _pointAt(tester, tester.getCenter(find.byType(FlutterMap))),
        );
        expect(
          designated.single.latitude,
          closeTo(camera.center.latitude, 1e-6),
        );
      });

      testWidgets('après 33 flèches $nom, la première flèche en sens inverse '
          'déplace la carte visible : aucune zone morte', (
        WidgetTester tester,
      ) async {
        await pumpMap(tester);
        await versLeZoomMinimum(tester);
        await appuyer(tester, vers, 33);
        // Ce que l'usager voit : le bord de la carte du côté de la butée.
        double bordVisible() => signe > 0
            ? _camera(tester).visibleBounds.north
            : _camera(tester).visibleBounds.south;
        final double avant = bordVisible();

        await tester.sendKeyEvent(retour);
        await tester.pumpAndSettle();

        // Un cran vaut plusieurs degrés à ce zoom : la carte visible recule
        // d'au moins un demi-degré, dans le sens inverse de la butée.
        expect(
          (bordVisible() - avant) * signe,
          lessThan(-0.5),
          reason: 'la première flèche inverse devait ramener la carte',
        );
      });
    }

    for (final (String, LogicalKeyboardKey) sens
        in <(String, LogicalKeyboardKey)>[
          ('Droite', LogicalKeyboardKey.arrowRight),
          ('Gauche', LogicalKeyboardKey.arrowLeft),
        ]) {
      testWidgets('caractérisation flutter_map 8.3.2 : flèche ${sens.$1} '
          'au-delà de ±180 degrés, puis le bouton : une longitude toujours '
          'dans [-180, 180]', (WidgetTester tester) async {
        final List<GeoPoint> designated = await pumpMap(tester, enMode: true);
        await versLeZoomMinimum(tester);

        // Plus d'un tour de la carte : le centre passe l'antiméridien.
        for (int i = 0; i < 60; i++) {
          await tester.sendKeyEvent(sens.$2);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(mapDesignateCenterButtonKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'cran $i');
        }

        expect(designated, hasLength(60));
        for (final GeoPoint p in designated) {
          expect(p.longitude, inInclusiveRange(-180, 180));
        }
      });
    }

    testWidgets("caractérisation flutter_map 8.3.2 : un appui long sur une "
        "réplique du monde, au-delà de l'antiméridien : une longitude dans "
        "[-180, 180], sans lever", (WidgetTester tester) async {
      final List<GeoPoint> designated = await pumpMap(tester, enMode: true);
      await versLeZoomMinimum(tester);

      // Le centre vers l'est jusqu'à 10 degrés de l'antiméridien au plus : le
      // bord droit de la carte (à plus de 30 degrés du centre au zoom 4) est
      // alors sur la réplique suivante du monde.
      for (
        int i = 0;
        i < 80 && !(_camera(tester).center.longitude > 170);
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(_camera(tester).center.longitude, greaterThan(170));

      // `flutter_map` 8.3.2 borne (`_inclusiveLng`, `geo/crs.dart`) la
      // longitude qu'il rend pour un point d'écran : elle ne dépasse pas 180.
      await tester.longPressAt(const Offset(780, 250));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(designated, hasLength(1));
      expect(designated.single.longitude, lessThan(0));
      expect(designated.single.longitude, inInclusiveRange(-180, 180));
    });
  });

  group('caméra contrainte au monde (revue de la PR 17, arbitrage du '
      '2026-10-06)', () {
    // `MapOptions.cameraConstraint: containLatitude()` : `flutter_map` 8.3.2
    // (`camera_constraint.dart`, `ContainCameraLatitude.constrain`) ramène le
    // centre de la caméra pour que ses BORDS haut et bas restent dans les
    // latitudes ±90 — que la projection plafonne à 85,0511° (`crs.dart`,
    // `SphericalMercator.maxLatitude`) — et rend `null` (déplacement refusé)
    // quand le monde est plus bas que la fenêtre. `moveRaw` l'applique à tout
    // déplacement, zoom compris ; ni le redimensionnement ni la création de la
    // caméra ne le font : la vue la rejoue elle-même après un changement de
    // taille (groupe « redimensionner la fenêtre rejoue la contrainte »).
    const double bord = SphericalMercator.maxLatitude;
    const double tolerance = 1e-6;

    for (final Size taille in <Size>[
      const Size(800, 700),
      const Size(800, 740),
      const Size(1920, 1032),
    ]) {
      testWidgets('à ${taille.width.toInt()} × ${taille.height.toInt()}, au '
          'zoom 4 : les flèches Haut puis Bas butent sur le bord du monde, '
          'sans le franchir', (WidgetTester tester) async {
        await pumpMap(tester, taille: taille);
        await versLeZoomMinimum(tester);
        // Garde-fou : le monde (256 × 2^4 = 4 096 px) est plus haut que la
        // fenêtre, la contrainte est satisfiable.
        expect(
          _camera(tester).crs.scale(_camera(tester).zoom),
          greaterThan(taille.height),
        );

        await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
        expect(ecartAuHautDuMonde(_camera(tester)), closeTo(0, tolerance));

        await appuyer(tester, LogicalKeyboardKey.arrowDown, 80);
        expect(ecartAuBasDuMonde(_camera(tester)), closeTo(0, tolerance));
      });
    }

    testWidgets(
      'glisser vers le pôle depuis la butée : la carte ne bouge plus ; '
      'glisser en sens inverse : elle bouge tout de suite',
      (WidgetTester tester) async {
        await pumpMap(tester);
        await versLeZoomMinimum(tester);
        await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
        final double butee = _camera(tester).center.latitude;

        await tester.dragFrom(ailleurs, const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(_camera(tester).center.latitude, closeTo(butee, tolerance));
        expect(ecartAuHautDuMonde(_camera(tester)), closeTo(0, tolerance));

        await tester.dragFrom(ailleurs, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(_camera(tester).center.latitude, lessThan(butee - 1));
      },
    );

    testWidgets('molette : dézoomer depuis la butée nord ne montre rien '
        'au-delà du monde', (WidgetTester tester) async {
      await pumpMap(tester);
      await entrerSousLesRaccourcis(tester);
      await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
      // Prémisse : la butée est atteinte avant le geste — sans elle, le test
      // ne dirait rien du dézoom depuis le bord.
      expect(ecartAuHautDuMonde(_camera(tester)), closeTo(0, tolerance));

      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(ailleurs));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, lessThan(5));
      expect(
        ecartAuHautDuMonde(_camera(tester)),
        greaterThanOrEqualTo(-tolerance),
        reason: 'la carte montre du vide au-delà du bord nord du monde',
      );
    });

    testWidgets('bouton − depuis la butée nord au zoom 5 : le haut de la '
        'carte reste au bord du monde', (WidgetTester tester) async {
      await pumpMap(tester);
      await entrerSousLesRaccourcis(tester);
      await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);

      await tester.tap(find.byKey(mapZoomOutButtonKey));
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, 4);
      expect(ecartAuHautDuMonde(_camera(tester)), closeTo(0, tolerance));
    });

    testWidgets('bouton + depuis la butée nord au zoom 4 : le centre ne bouge '
        'pas et la carte reste dans le monde', (WidgetTester tester) async {
      await pumpMap(tester);
      await versLeZoomMinimum(tester);
      await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
      final double butee = _camera(tester).center.latitude;

      await tester.tap(find.byKey(mapZoomInButtonKey));
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, 5);
      expect(_camera(tester).center.latitude, closeTo(butee, tolerance));
      // Le monde est deux fois plus haut : le haut de la carte a de la marge.
      expect(ecartAuHautDuMonde(_camera(tester)), greaterThan(100));
    });

    // `flutter_map` 8.3.2 n'applique la contrainte qu'aux déplacements
    // (`moveRaw`, `rotateRaw`) : `setNonRotatedSizeWithoutEmittingEvent` change
    // la taille de la caméra sans la rejouer, et l'événement
    // `MapEventNonRotatedSizeChange` ne part qu'après le rendu. La vue le
    // reçoit et rejoue la contrainte par un déplacement vers le centre et le
    // zoom courants (`MapView._handleMapEvent`) : ce groupe verrouille le
    // comportement voulu, pas celui du paquet.
    group('redimensionner la fenêtre rejoue la contrainte', () {
      Future<void> redimensionner(WidgetTester tester, Size taille) async {
        tester.view.physicalSize = taille;
        await tester.pumpAndSettle();
      }

      for (final (String, LogicalKeyboardKey) butee
          in <(String, LogicalKeyboardKey)>[
            ('nord', LogicalKeyboardKey.arrowUp),
            ('sud', LogicalKeyboardKey.arrowDown),
          ]) {
        final bool nord = butee.$1 == 'nord';

        testWidgets('agrandir la fenêtre (700 → 1 032 px de haut) depuis la '
            'butée ${butee.$1} : aucun vide au-delà du monde, et la carte '
            'se recharge une fois sur la caméra recalée', (
          WidgetTester tester,
        ) async {
          final List<Bounds> chargements = <Bounds>[];
          await pumpMap(tester, chargements: chargements);
          await versLeZoomMinimum(tester);
          await appuyer(tester, butee.$2, 80);
          // Prémisse : la butée est atteinte avant le redimensionnement.
          expect(
            nord
                ? ecartAuHautDuMonde(_camera(tester))
                : ecartAuBasDuMonde(_camera(tester)),
            closeTo(0, tolerance),
          );
          final int avant = chargements.length;

          await redimensionner(tester, const Size(800, 1032));

          final MapCamera camera = _camera(tester);
          expect(camera.size.height, 1032);
          expect(
            ecartAuHautDuMonde(camera),
            nord ? closeTo(0, tolerance) : greaterThanOrEqualTo(-tolerance),
            reason: 'la carte montre du vide au-dessus du monde',
          );
          expect(
            ecartAuBasDuMonde(camera),
            nord ? greaterThanOrEqualTo(-tolerance) : closeTo(0, tolerance),
            reason: 'la carte montre du vide au-dessous du monde',
          );
          // Le recalage est un déplacement de caméra : le chemin existant
          // (`_afterCameraMove`) recharge l'emprise résultante, une fois.
          expect(chargements, hasLength(avant + 1));
          final LatLngBounds visibles = camera.visibleBounds;
          expect(
            chargements.last,
            Bounds(
              west: visibles.west,
              south: visibles.south,
              east: visibles.east,
              north: visibles.north,
            ),
          );
        });
      }

      testWidgets('un appui long tout en haut de la carte agrandie, depuis la '
          'butée nord, désigne un point du monde (latitude ≤ 85,06°)', (
        WidgetTester tester,
      ) async {
        final List<GeoPoint> designated = await pumpMap(tester);
        await versLeZoomMinimum(tester);
        await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
        await redimensionner(tester, const Size(800, 1032));

        await tester.longPressAt(const Offset(400, 3));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(designated, hasLength(1));
        expect(designated.single.latitude, lessThanOrEqualTo(bord + 0.01));
      });

      for (final (String, Size) cas in <(String, Size)>[
        ('800 × 1 032 (plus haute)', const Size(800, 1032)),
        ('1 200 × 700 (plus large)', const Size(1200, 700)),
        ('500 × 400 (plus petite)', const Size(500, 400)),
      ]) {
        testWidgets('${cas.$1}, depuis le centre de la France : la caméra ne '
            'bouge pas et rien ne se recharge', (WidgetTester tester) async {
          final List<Bounds> chargements = <Bounds>[];
          await pumpMap(tester, chargements: chargements);
          final MapCamera avant = _camera(tester);
          final int nombre = chargements.length;

          await redimensionner(tester, cas.$2);

          expect(_camera(tester).size, cas.$2);
          expect(_camera(tester).center, avant.center);
          expect(_camera(tester).zoom, avant.zoom);
          expect(chargements, hasLength(nombre));
        });
      }

      testWidgets('rétrécir la fenêtre (1 032 → 700 px de haut) depuis la '
          'butée nord ne crée aucun vide : la caméra ne bouge pas, rien ne '
          'se recharge', (WidgetTester tester) async {
        final List<Bounds> chargements = <Bounds>[];
        await pumpMap(
          tester,
          taille: const Size(800, 1032),
          chargements: chargements,
        );
        await versLeZoomMinimum(tester);
        await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
        expect(ecartAuHautDuMonde(_camera(tester)), closeTo(0, tolerance));
        final MapCamera avant = _camera(tester);
        final int nombre = chargements.length;

        await redimensionner(tester, const Size(800, 700));

        final MapCamera camera = _camera(tester);
        expect(camera.size.height, 700);
        expect(camera.center, avant.center);
        expect(ecartAuHautDuMonde(camera), greaterThanOrEqualTo(-tolerance));
        expect(ecartAuBasDuMonde(camera), greaterThanOrEqualTo(-tolerance));
        expect(chargements, hasLength(nombre));
      });

      testWidgets('une fenêtre qui devient plus haute que le monde au zoom 4 '
          '(4 200 > 4 096 px) : le recalage est refusé, sans lever — la '
          'caméra et le chargement restent tels quels', (
        WidgetTester tester,
      ) async {
        final List<Bounds> chargements = <Bounds>[];
        await pumpMap(tester, chargements: chargements);
        await versLeZoomMinimum(tester);
        await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
        final MapCamera avant = _camera(tester);
        final int nombre = chargements.length;

        await redimensionner(tester, const Size(800, 4200));

        expect(tester.takeException(), isNull);
        expect(_camera(tester).size.height, 4200);
        expect(_camera(tester).center, avant.center);
        expect(_camera(tester).zoom, 4);
        expect(chargements, hasLength(nombre));
      });
    });

    testWidgets('recentrer depuis la butée nord ramène à la caméra de '
        'démarrage', (WidgetTester tester) async {
      await pumpMap(tester);
      await versLeZoomMinimum(tester);
      await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);

      await tester.tap(find.byKey(mapRecenterButtonKey));
      await tester.pumpAndSettle();

      expect(_camera(tester).zoom, initialMapZoom);
      expect(
        _camera(tester).center.latitude,
        closeTo(initialMapCenterLatitude, tolerance),
      );
      expect(
        _camera(tester).center.longitude,
        closeTo(initialMapCenterLongitude, tolerance),
      );
    });

    testWidgets('pivoter la carte depuis la butée nord recule le centre : la '
        'boîte englobante reste dans le monde', (WidgetTester tester) async {
      await pumpMap(tester);
      await versLeZoomMinimum(tester);
      await appuyer(tester, LogicalKeyboardKey.arrowUp, 40);
      final double butee = _camera(tester).center.latitude;

      // `rotateRaw` contraint la caméra pivotée, dont la taille est celle de la
      // boîte englobante (800 × 700 pivotée de 45° : environ 1 060 px de haut).
      MapController.of(tester.element(find.byType(TileLayer))).rotate(45);
      await tester.pumpAndSettle();

      final MapCamera camera = _camera(tester);
      expect(camera.rotation, 45);
      expect(camera.center.latitude, lessThan(butee - 1));
      expect(
        ecartAuHautDuMonde(camera),
        greaterThanOrEqualTo(-tolerance),
        reason: 'le haut de la boîte englobante dépasse le bord du monde',
      );
    });

    testWidgets('les DOM restent atteignables et centrables, au zoom minimal '
        'comme au zoom maximal, dans la plus grande fenêtre (1920 × 1032)', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, taille: const Size(1920, 1032));
      final MapController controleur = MapController.of(
        tester.element(find.byType(TileLayer)),
      );

      for (final (String, double, double) dom in <(String, double, double)>[
        ('Guadeloupe', 16.25, -61.55),
        ('Martinique', 14.64, -61.0),
        ('Guyane', 4.0, -53.0),
        ('La Réunion', -21.12, 55.54),
        ('Mayotte', -12.83, 45.16),
      ]) {
        for (final double zoom in <double>[4, maximumMapZoom]) {
          final bool aboutit = controleur.move(LatLng(dom.$2, dom.$3), zoom);
          await tester.pumpAndSettle();

          expect(aboutit, isTrue, reason: '${dom.$1} au zoom $zoom');
          expect(_camera(tester).zoom, zoom, reason: dom.$1);
          expect(
            _camera(tester).center.latitude,
            closeTo(dom.$2, tolerance),
            reason: dom.$1,
          );
          expect(
            _camera(tester).center.longitude,
            closeTo(dom.$3, tolerance),
            reason: dom.$1,
          );
        }

        // Le chemin d'une pastille de zone (`ClusterZoomTarget.CoverBounds`,
        // `_handleClusterSelect`) : `fitCamera` sur une emprise du territoire.
        final LatLngBounds emprise = LatLngBounds(
          LatLng(dom.$2 - 0.3, dom.$3 - 0.3),
          LatLng(dom.$2 + 0.3, dom.$3 + 0.3),
        );
        final bool cadre = controleur.fitCamera(
          CameraFit.bounds(bounds: emprise, minZoom: 7),
        );
        await tester.pumpAndSettle();

        expect(cadre, isTrue, reason: '${dom.$1} : fitCamera');
        expect(_camera(tester).zoom, greaterThanOrEqualTo(7));
        expect(emprise.contains(_camera(tester).center), isTrue);
      }
    });

    testWidgets("caractérisation flutter_map 8.3.2 : une fenêtre plus haute "
        'que le monde au zoom '
        '4 (4 096 px) refuse le dézoom, et la carte reste au zoom 5', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, taille: const Size(800, 4200));

      await tester.tap(find.byKey(mapZoomOutButtonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_camera(tester).zoom, initialMapZoom);
    });

    group('caractérisation flutter_map 8.3.2 : containLatitude', () {
      const CameraConstraint contrainte = CameraConstraint.containLatitude();

      MapCamera camera(Size taille, LatLng centre) => MapCamera(
        crs: const Epsg3857(),
        center: centre,
        zoom: 4,
        rotation: 0,
        nonRotatedSize: taille,
      );

      test('un centre au-delà du bord est ramené dans le monde', () {
        final MapCamera? resultat = contrainte.constrain(
          camera(const Size(800, 700), const LatLng(95, 0)),
        );

        expect(resultat, isNotNull);
        expect(resultat!.center.latitude, lessThan(bord));
      });

      test('un monde plus bas que la fenêtre : constrain rend null', () {
        expect(
          contrainte.constrain(
            camera(const Size(800, 4200), const LatLng(46.6, 2.2)),
          ),
          isNull,
        );
      });

      // Pourquoi la borne de `_designate` reste : sans hauteur, la contrainte
      // ne ramène rien (le bord haut est le centre), et un centre hors de
      // [-90, 90] passerait tel quel — de même avant la première mise en page
      // (`MapCamera.kImpossibleSize`, hauteur infinie négative).
      for (final (String, Size) cas in <(String, Size)>[
        ('sans hauteur', const Size(800, 0)),
        ('avant la première mise en page', MapCamera.kImpossibleSize),
      ]) {
        test('${cas.$1} : un centre hors de [-90, 90] passe tel quel', () {
          final MapCamera? resultat = contrainte.constrain(
            camera(cas.$2, const LatLng(95, 0)),
          );

          expect(resultat, isNotNull);
          expect(resultat!.center.latitude, 95);
        });
      }
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

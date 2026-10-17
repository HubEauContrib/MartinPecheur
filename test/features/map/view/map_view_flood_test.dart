// La lecture Crues branchée dans `MapView` (M5 de T4 ; cadrage § 7.1, § 7.2,
// § 7.7) : la vue relie ses deux ViewModels — la puce « Vigilance crues »
// active la lecture, un relâchement de geste relit l'emprise, « Réessayer »
// relance — et réemploie le calque des traits comme MÊME instance tant que la
// carte de vigilance ne change pas (Review Focus 1).
//
// `MapView` est monté en entier, comme `map_designation_test.dart` : les
// gestes, la puce et le toucher ne se vérifient pas sur les seules fonctions
// pures. Le double de source est piloté par `Completer` et compte ses
// appels : c'est ce compte qui éprouve, de bout en bout, le Review Focus 2
// (un geste pendant le chargement ne relance rien).
//
// Les niveaux jaune et orange sont des cas construits, niveau jamais observé
// en production — `VC-04`.

import 'dart:async';

import 'package:flutter/gestures.dart' show HitTestEntry, HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show floodWarningWindowText;
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view/flood_section_label.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart'
    show floodCoverageText;
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// Double de la source Vigicrues : chaque appel attend un `Completer` piloté
/// par le test ; le nombre d'appels est celui des `Completer` créés.
final class _SourceDouble implements FloodVigilanceSource {
  final List<Completer<FloodVigilanceMap>> pending =
      <Completer<FloodVigilanceMap>>[];

  int get calls => pending.length;

  Completer<FloodVigilanceMap> get last => pending.last;

  @override
  Future<FloodVigilanceMap> current() {
    final Completer<FloodVigilanceMap> c = Completer<FloodVigilanceMap>();
    pending.add(c);
    return c.future;
  }
}

/// Une station au centre initial de la caméra, quelle que soit l'emprise.
final class _Stations implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => <StationPoint>[_stationAuCentre()];

  @override
  Future<List<StationPoint>> all() async => <StationPoint>[_stationAuCentre()];
}

final class _NoHydro implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

/// Une observation ONDE au centre initial de la caméra, quelle que soit
/// l'emprise.
final class _Onde implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => OndeSweep(
    observations: <OndeObservation>[_observationAuCentre()],
    unreadableRows: 0,
  );

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

StationPoint _stationAuCentre() => StationPoint(
  code: StationCode('K447001001'),
  label: 'Station du centre',
  latitude: initialMapCenterLatitude,
  longitude: initialMapCenterLongitude,
);

OndeObservation _observationAuCentre() {
  final OndePoint point = OndePoint(
    code: OndeStationCode('04170001'),
    label: 'Point du centre',
    latitude: initialMapCenterLatitude,
    longitude: initialMapCenterLongitude,
    waterCourseLabel: 'Le Trey',
    departement: const AdministrativeArea(code: '54', label: '54'),
  );
  return OndeObservation(
    station: point.code,
    point: point,
    observedAt: DateTime.utc(2026, 8, 25),
    category: const Assec(),
    rawFlowCode: '3',
    officialLabel: 'Assec',
    campaignCode: '1',
  );
}

FloodSection _section(
  String code,
  FloodVigilanceLevel level,
  List<GeoPoint> line,
) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: '8',
  level: level,
  lines: <List<GeoPoint>>[line],
);

/// Date de l'information des cartes de ce fichier.
final DateTime _date = DateTime.utc(2026, 10, 14, 13, 55, 31);

/// Un vert qui traverse le centre de la caméra (aucune étiquette sous le
/// niveau individuel), un jaune au nord et un orange au sud, chacun étiqueté
/// (jaune et orange : cas construits, niveau jamais observé en production —
/// `VC-04`).
FloodVigilanceMap _troisTroncons() => FloodVigilanceMap(
  informationDate: _date,
  sections: <FloodSection>[
    _section('V1', const Vert(), <GeoPoint>[
      GeoPoint(latitude: initialMapCenterLatitude, longitude: -6),
      GeoPoint(latitude: initialMapCenterLatitude, longitude: 10),
    ]),
    _section('J1', const Jaune(), <GeoPoint>[
      GeoPoint(latitude: 48.6, longitude: 0),
      GeoPoint(latitude: 48.6, longitude: 4),
    ]),
    _section('O1', const Orange(), <GeoPoint>[
      GeoPoint(latitude: 44.6, longitude: 0),
      GeoPoint(latitude: 44.6, longitude: 4),
    ]),
  ],
  skippedEntities: 0,
);

/// Un seul tronçon jaune, court, en bas à gauche du centre : son étiquette se
/// pose hors des surcouches d'un téléphone (cas construit, niveau jamais
/// observé en production — `VC-04`).
FloodVigilanceMap _unJauneEnBasAGauche() => FloodVigilanceMap(
  informationDate: _date,
  sections: <FloodSection>[
    _section('J9', const Jaune(), <GeoPoint>[
      GeoPoint(latitude: 44.6, longitude: -1),
      GeoPoint(latitude: 44.6, longitude: -0.8),
    ]),
  ],
  skippedEntities: 0,
);

/// Un toucher de trait : le tronçon et la date reçus par `onFloodSectionTap`.
typedef _Toucher = ({FloodSection section, DateTime date});

/// Ce que [_pumpMap] rend : de quoi piloter la carte et lire ses rappels.
final class _Harness {
  _Harness(this.viewModel, this.flood, this.source, this.touchers);

  final MapViewModel viewModel;
  final FloodLayerViewModel flood;
  final _SourceDouble source;
  final List<_Toucher> touchers;
}

Future<_Harness> _pumpMap(
  WidgetTester tester, {
  Size taille = const Size(800, 700),
  Widget floodSheet = const SizedBox.shrink(),
  ScrollController? sheetScrollController,
  VoidCallback? onCloseSheets,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _SourceDouble source = _SourceDouble();
  final MapViewModel viewModel = MapViewModel(
    stationPoints: _Stations(),
    observations: _NoHydro(),
    onde: _Onde(),
    delay: (Duration _) => Future<void>.value(),
  );
  final FloodLayerViewModel flood = FloodLayerViewModel(source: source);
  addTearDown(flood.dispose);
  final List<_Toucher> touchers = <_Toucher>[];
  await tester.pumpWidget(
    MaterialApp(
      home: MapView(
        viewModel: viewModel,
        floodLayer: flood,
        onFloodSectionTap: (FloodSection section, DateTime date) =>
            touchers.add((section: section, date: date)),
        floodSheet: floodSheet,
        sheetScrollController: sheetScrollController,
        onCloseSheets: onCloseSheets,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(viewModel, flood, source, touchers);
}

Finder _puce(MapScaleKind kind) => find.byKey(ValueKey<MapScaleKind>(kind));

Future<void> _choisir(WidgetTester tester, MapScaleKind kind) async {
  await tester.tap(_puce(kind));
  await tester.pumpAndSettle();
}

Future<void> _zoomer(WidgetTester tester, Key bouton, {int fois = 1}) async {
  for (int i = 0; i < fois; i++) {
    await tester.tap(find.byKey(bouton));
    await tester.pumpAndSettle();
  }
}

/// Un glisser de la carte, posé hors des surcouches.
Future<void> _glisser(WidgetTester tester) async {
  await tester.dragFrom(const Offset(300, 450), const Offset(-80, 0));
  await tester.pumpAndSettle();
}

Finder _dansLaCarte(Finder matching) =>
    find.descendant(of: find.byType(FlutterMap), matching: matching);

final Finder _traits = find.byType(PolylineLayer<FloodSectionCode>);

PolylineLayer<FloodSectionCode> _calque(WidgetTester tester) =>
    tester.widget<PolylineLayer<FloodSectionCode>>(_traits);

/// Vrai si un toucher au centre de [finder] atteint son objet de rendu : rien
/// ne le recouvre.
bool _atteignable(WidgetTester tester, Finder finder) {
  final Offset centre = tester.getCenter(finder);
  final RenderObject cible = tester.renderObject(finder);
  final HitTestResult result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, centre, tester.view.viewId);
  return result.path.any((HitTestEntry entry) => entry.target == cible);
}

FocusNode _noeudCarte() => FocusManager.instance.rootScope.descendants
    .firstWhere((FocusNode node) => node.debugLabel == 'carte');

void main() {
  testWidgetsOnWindows(
    'floodLayer, onFloodSectionTap et floodSheet vont ensemble (assert)',
    (WidgetTester tester) async {
      final MapViewModel viewModel = MapViewModel(
        stationPoints: _Stations(),
        observations: _NoHydro(),
        onde: _Onde(),
      );
      final FloodLayerViewModel flood = FloodLayerViewModel(
        source: _SourceDouble(),
      );
      addTearDown(flood.dispose);

      expect(
        () => MapView(viewModel: viewModel, floodLayer: flood),
        throwsAssertionError,
      );
      expect(
        () => MapView(
          viewModel: viewModel,
          onFloodSectionTap: (FloodSection s, DateTime d) {},
        ),
        throwsAssertionError,
      );
      expect(
        () => MapView(viewModel: viewModel, floodSheet: const SizedBox()),
        throwsAssertionError,
      );
      expect(
        () => MapView(
          viewModel: viewModel,
          floodLayer: flood,
          onFloodSectionTap: (FloodSection s, DateTime d) {},
          floodSheet: const SizedBox(),
        ),
        returnsNormally,
      );
    },
  );

  testWidgetsOnWindows(
    'sur la lecture Crues : aucun marqueur de station ni de point ONDE, '
    'aucune pastille (critère 1)',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      // Niveau individuel (zoom 9) sur l'écoulement : le point ONDE du
      // centre est dessiné — sans quoi l'absence plus bas ne prouverait rien.
      await _zoomer(tester, mapZoomInButtonKey, fois: 4);
      expect(_dansLaCarte(find.byType(OndeMarkerShape)), findsOneWidget);
      // Sur le débit, la station du centre l'est aussi.
      await _choisir(tester, MapScaleKind.debit);
      expect(_dansLaCarte(find.byType(StationMarkerDot)), findsOneWidget);

      await _choisir(tester, MapScaleKind.crues);
      expect(_dansLaCarte(find.byType(OndeMarkerShape)), findsNothing);
      expect(_dansLaCarte(find.byType(StationMarkerDot)), findsNothing);
      expect(_dansLaCarte(find.byType(AreaClusterMarker)), findsNothing);

      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(_traits, findsOneWidget);
      expect(_dansLaCarte(find.byType(OndeMarkerShape)), findsNothing);
      expect(_dansLaCarte(find.byType(StationMarkerDot)), findsNothing);
      expect(_dansLaCarte(find.byType(AreaClusterMarker)), findsNothing);

      // Et en dézoomant, au niveau des pastilles.
      await _zoomer(tester, mapZoomOutButtonKey, fois: 4);
      expect(_dansLaCarte(find.byType(AreaClusterMarker)), findsNothing);
    },
  );

  testWidgetsOnWindows(
    'gestes sur Écoulement ou Débit : aucun appel à la source Vigicrues '
    '(critère 16)',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);

      await _zoomer(tester, mapZoomInButtonKey);
      await _glisser(tester);
      await _choisir(tester, MapScaleKind.debit);
      await _zoomer(tester, mapZoomOutButtonKey);
      await _glisser(tester);

      expect(h.source.calls, 0);
      expect(h.flood.state, isA<LectureCruesNonDemandee>());
    },
  );

  testWidgetsOnWindows(
    'Review Focus 1 : même instance de calque après un changement sans '
    'rapport (geste, notification de MapViewModel) ; instance différente '
    'pour une nouvelle carte de vigilance',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _choisir(tester, MapScaleKind.crues);
      final FloodVigilanceMap carte = _troisTroncons();
      h.source.last.complete(carte);
      await tester.pumpAndSettle();
      final PolylineLayer<FloodSectionCode> avant = _calque(tester);
      expect(
        <String?>{
          for (final Polyline<FloodSectionCode> p in avant.polylines)
            p.hitValue?.value,
        },
        <String>{'V1', 'J1', 'O1'},
      );

      // Un geste : la vue relit la source, qui rend la MÊME carte (le cache).
      await _zoomer(tester, mapZoomInButtonKey);
      expect(h.source.calls, 2);
      h.source.last.complete(carte);
      await tester.pumpAndSettle();
      expect(identical(_calque(tester), avant), isTrue);

      // Un glisser, laissé en cours de relecture.
      await _glisser(tester);
      expect(identical(_calque(tester), avant), isTrue);

      // Une notification de MapViewModel sans rapport avec les crues.
      h.viewModel.toggleDesignationMode();
      await tester.pump();
      h.viewModel.toggleDesignationMode();
      await tester.pump();
      expect(identical(_calque(tester), avant), isTrue);

      // Une nouvelle carte de vigilance : un autre calque.
      await _zoomer(tester, mapZoomOutButtonKey);
      final FloodVigilanceMap nouvelle = _unJauneEnBasAGauche();
      h.source.last.complete(nouvelle);
      await tester.pumpAndSettle();
      final PolylineLayer<FloodSectionCode> apres = _calque(tester);
      expect(identical(apres, avant), isFalse);
      expect(
        <String?>[
          for (final Polyline<FloodSectionCode> p in apres.polylines)
            p.hitValue?.value,
        ],
        <String>['J9'],
      );
      // Le notifieur de toucher reste celui de l'état.
      expect(identical(apres.hitNotifier, avant.hitNotifier), isTrue);
    },
  );

  testWidgetsOnWindows(
    'la puce « Vigilance crues » : avis de lecture, aucun trait, légende sans '
    'date ; la source aboutit : traits, légende datée, plus d’avis',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);

      await _choisir(tester, MapScaleKind.crues);
      expect(h.source.calls, 1);
      expect(find.text(floodLoadingText), findsOneWidget);
      expect(_traits, findsNothing);
      expect(find.textContaining('Information de vigilance du '), findsNothing);
      expect(find.text(floodCoverageText), findsNothing);

      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(_traits, findsOneWidget);
      expect(
        find.textContaining('Information de vigilance du 14/10/2026 à '),
        findsOneWidget,
      );
      expect(find.text(floodCoverageText), findsOneWidget);
      expect(find.text(floodLoadingText), findsNothing);
      expect(find.byType(FloodSectionLabel), findsNWidgets(2));
    },
  );

  testWidgetsOnWindows(
    'Review Focus 2 : gestes, aller-retour de puce pendant le chargement → '
    'un seul appel à la source ; la vigilance s’affiche dès qu’il aboutit',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);

      await _choisir(tester, MapScaleKind.crues);
      await _zoomer(tester, mapZoomInButtonKey);
      await _glisser(tester);
      await _choisir(tester, MapScaleKind.ecoulement);
      await _choisir(tester, MapScaleKind.crues);
      expect(h.source.calls, 1);

      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(_traits, findsOneWidget);
      expect(find.byType(FloodSectionLabel), findsWidgets);
    },
  );

  testWidgetsOnWindows(
    'échec : avis injoignable avec « Réessayer » ; un geste ne relance rien ; '
    '« Réessayer » relance une fois, puis les traits',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _choisir(tester, MapScaleKind.crues);
      h.source.last.completeError(const VigilanceInjoignable('réseau'));
      await tester.pumpAndSettle();

      expect(find.text(floodUnavailableText), findsOneWidget);
      expect(find.byKey(floodRetryKey), findsOneWidget);
      expect(_traits, findsNothing);

      await _zoomer(tester, mapZoomInButtonKey);
      await _glisser(tester);
      expect(h.source.calls, 1);

      await tester.tap(find.byKey(floodRetryKey));
      await tester.pumpAndSettle();
      expect(h.source.calls, 2);
      expect(find.text(floodLoadingText), findsOneWidget);

      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(_traits, findsOneWidget);
      expect(find.text(floodUnavailableText), findsNothing);
      expect(find.byKey(floodRetryKey), findsNothing);
    },
  );

  testWidgetsOnWindows(
    'toucher d’un trait : onFloodSectionTap reçoit le tronçon et la date de '
    'la carte',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _choisir(tester, MapScaleKind.crues);
      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();

      // Le vert traverse le centre de la carte, sans étiquette à ce zoom.
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.touchers, hasLength(1));
      expect(h.touchers.single.section.code, FloodSectionCode('V1'));
      expect(h.touchers.single.section.level, const Vert());
      expect(h.touchers.single.date, _date);
    },
  );

  testWidgetsOnWindows(
    'activer une étiquette au clavier ouvre la fiche de son tronçon ; la carte '
    'cède sa place de tabulation aux étiquettes',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _choisir(tester, MapScaleKind.crues);
      // Lecture en cours : rien à focaliser dans la carte, le nœud de secours
      // reste un arrêt de tabulation.
      expect(_noeudCarte().skipTraversal, isFalse);

      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(h.flood.labels, isNotEmpty);
      expect(_noeudCarte().skipTraversal, isTrue);

      // Tab parcourt l'écran jusqu'à la première étiquette de l'ordre du
      // domaine ; Entrée l'active, comme un toucher.
      final FloodLabel premiere = h.flood.labels.first;
      final Finder etiquette = find.byWidgetPredicate(
        (Widget w) =>
            w is FloodSectionLabel && w.section.code == premiere.section.code,
      );
      bool focalisee() {
        final BuildContext? focused =
            FocusManager.instance.primaryFocus?.context;
        return focused != null &&
            find
                .descendant(
                  of: etiquette,
                  matching: find.byWidget(focused.widget),
                )
                .evaluate()
                .isNotEmpty;
      }

      for (int i = 0; i < 30 && !focalisee(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focalisee(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(h.touchers, hasLength(1));
      expect(h.touchers.single.section.code, premiere.section.code);
      expect(h.touchers.single.date, _date);
    },
  );

  testWidgetsOnWindows(
    'fenêtre « ⚠ Avertissement » : sur la lecture Crues elle porte le texte '
    'de crue ; sur l’écoulement, non',
    (WidgetTester tester) async {
      await _pumpMap(tester);

      await tester.tap(find.byType(WarningLink));
      await tester.pumpAndSettle();
      expect(find.text(floodWarningWindowText), findsNothing);
      expect(find.byKey(warningWindowExtraTextKey), findsNothing);
      await tester.tap(find.byKey(warningWindowCloseButtonKey));
      await tester.pumpAndSettle();

      await _choisir(tester, MapScaleKind.crues);
      await tester.tap(find.byType(WarningLink));
      await tester.pumpAndSettle();
      expect(find.text(floodWarningWindowText), findsOneWidget);
      await tester.tap(find.byKey(warningWindowCloseButtonKey));
      await tester.pumpAndSettle();

      await _choisir(tester, MapScaleKind.debit);
      await tester.tap(find.byType(WarningLink));
      await tester.pumpAndSettle();
      expect(find.text(floodWarningWindowText), findsNothing);
    },
  );

  testWidgetsOnWindows(
    'revenir sur l’écoulement : aucun trait, aucune étiquette, les marqueurs '
    'ONDE reviennent',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _zoomer(tester, mapZoomInButtonKey, fois: 4);
      expect(_dansLaCarte(find.byType(OndeMarkerShape)), findsOneWidget);

      await _choisir(tester, MapScaleKind.crues);
      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      expect(_traits, findsOneWidget);
      expect(find.byType(FloodSectionLabel), findsWidgets);

      await _choisir(tester, MapScaleKind.ecoulement);
      expect(_traits, findsNothing);
      expect(find.byType(FloodSectionLabel), findsNothing);
      expect(_dansLaCarte(find.byType(OndeMarkerShape)), findsOneWidget);
    },
  );

  testWidgetsOnWindows(
    'la fiche tronçon injectée est rendue dans la zone des fiches, avec le '
    'défilement de la racine',
    (WidgetTester tester) async {
      const Key ficheKey = Key('fiche-troncon');
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pumpMap(
        tester,
        floodSheet: const SizedBox(key: ficheKey, width: 200, height: 80),
        sheetScrollController: controller,
      );

      expect(find.byKey(ficheKey), findsOneWidget);
      final SingleChildScrollView defilement = tester
          .widget<SingleChildScrollView>(
            find
                .ancestor(
                  of: find.byKey(ficheKey),
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          );
      expect(identical(defilement.controller, controller), isTrue);
    },
  );

  testWidgetsOnAndroid(
    'Android : à 360 × 640, l’avis de lecture s’affiche et s’atteint',
    (WidgetTester tester) async {
      await _pumpMap(tester, taille: const Size(360, 640));

      await _choisir(tester, MapScaleKind.crues);

      final Finder avis = find.text(floodLoadingText);
      expect(avis, findsOneWidget);
      final Rect rect = tester.getRect(avis);
      expect(
        const Rect.fromLTWH(0, 0, 360, 640).contains(rect.center),
        isTrue,
        reason: 'l’avis $rect doit être dans l’écran',
      );
      expect(_atteignable(tester, avis), isTrue);
    },
  );

  testWidgetsOnAndroid(
    'Android : à 360 × 640, une étiquette fait 48 de haut et son toucher '
    'ouvre la fiche',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester, taille: const Size(360, 640));
      await _choisir(tester, MapScaleKind.crues);
      h.source.last.complete(_unJauneEnBasAGauche());
      await tester.pumpAndSettle();

      final Finder etiquette = find.byType(FloodSectionLabel);
      expect(etiquette, findsOneWidget);
      expect(tester.getSize(etiquette).height, 48);
      expect(_atteignable(tester, etiquette), isTrue);

      await tester.tap(etiquette);
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.touchers, hasLength(1));
      expect(h.touchers.single.section.code, FloodSectionCode('J9'));
      expect(h.touchers.single.date, _date);
    },
  );

  // `K1` de T4 (2026-10-15) — le parcours au clavier de la lecture Crues, par
  // la vraie touche (`sendKeyEvent`), sous Windows : Tab atteint les
  // étiquettes dans l'ordre de `FloodLayerViewModel.labels`, puis la fiche
  // tronçon ouverte, puis le contrôle « ⚠ Avertissement » de la carte ;
  // Entrée sur une étiquette ouvre la fiche, Échap la ferme. Le test tient le
  // rôle de la racine de composition (`main.dart`) : il ouvre la fiche sur le
  // rappel du toucher et la ferme sur `onCloseSheets`.
  testWidgetsOnWindows(
    'K1 de T4 — clavier : Tab parcourt les étiquettes dans l’ordre de labels, '
    'puis la fiche tronçon, puis « ⚠ Avertissement » ; Entrée ouvre la fiche, '
    'Échap la ferme',
    (WidgetTester tester) async {
      final ValueNotifier<FloodSheetState> fiche =
          ValueNotifier<FloodSheetState>(const FicheTronconFermee());
      addTearDown(fiche.dispose);
      final _Harness h = await _pumpMap(
        tester,
        floodSheet: ValueListenableBuilder<FloodSheetState>(
          valueListenable: fiche,
          builder: (BuildContext context, FloodSheetState state, Widget? _) =>
              FloodSheetPanel(
                state: state,
                onClose: () => fiche.value = const FicheTronconFermee(),
                onOpenBulletin: () {},
              ),
        ),
        onCloseSheets: () => fiche.value = const FicheTronconFermee(),
      );
      await _choisir(tester, MapScaleKind.crues);
      h.source.last.complete(_troisTroncons());
      await tester.pumpAndSettle();
      // Deux étiquettes : le jaune et l'orange (cas construits) ; le vert
      // n'en a pas sous le niveau individuel.
      expect(h.flood.labels, hasLength(2));

      Finder etiquette(FloodLabel label) => find.byWidgetPredicate(
        (Widget w) =>
            w is FloodSectionLabel && w.section.code == label.section.code,
      );
      Future<void> tab() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      // Tab parcourt l'écran jusqu'à la première étiquette, puis chacune des
      // suivantes, dans l'ordre de `labels`.
      final Finder premiere = etiquette(h.flood.labels.first);
      for (int i = 0; i < 30 && !focusedWithin(tester, premiere); i++) {
        await tab();
      }
      expect(focusedWithin(tester, premiere), isTrue);
      for (final FloodLabel label in h.flood.labels.skip(1)) {
        await tab();
        expect(
          focusedWithin(tester, etiquette(label)),
          isTrue,
          reason: 'étiquette attendue : ${label.section.code}',
        );
      }

      // Entrée sur la dernière étiquette : le rappel du toucher, avec son
      // tronçon et la date de la carte ; la racine ouvre la fiche.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(h.touchers, hasLength(1));
      expect(h.touchers.single.section.code, h.flood.labels.last.section.code);
      expect(h.touchers.single.date, _date);
      fiche.value = FicheTronconOuverte(
        section: h.touchers.single.section,
        informationDate: h.touchers.single.date,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(floodSheetCloseButtonKey), findsOneWidget);

      // Tab : la fiche, puis — ses arrêts passés — le contrôle de la carte.
      final Finder panneau = find.byType(FloodSheetPanel);
      await tab();
      expect(focusedWithin(tester, panneau), isTrue);
      int arretsDansLaFiche = 1;
      while (focusedWithin(tester, panneau) && arretsDansLaFiche < 10) {
        await tab();
        if (focusedWithin(tester, panneau)) {
          arretsDansLaFiche++;
        }
      }
      expect(focusedWithin(tester, panneau), isFalse);
      final Finder lienCarte = find.byWidgetPredicate(
        (Widget w) =>
            w is WarningLink &&
            find
                .ancestor(of: find.byWidget(w), matching: panneau)
                .evaluate()
                .isEmpty,
      );
      expect(lienCarte, findsOneWidget);
      expect(
        focusedWithin(tester, lienCarte),
        isTrue,
        reason: '$arretsDansLaFiche arrêt(s) de Tab dans la fiche',
      );

      // Échap ferme la fiche.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(fiche.value, isA<FicheTronconFermee>());
      expect(find.byKey(floodSheetCloseButtonKey), findsNothing);
    },
  );

  // Relecture d'ensemble de T4, point C : un changement de taille de la
  // fenêtre, sans mouvement de caméra, prévient la lecture Crues de la
  // nouvelle emprise (`MapEventNonRotatedSizeChange`).
  testWidgetsOnWindows(
    'lecture Crues lue, emprise sans tronçon : avis du secteur ; la fenêtre '
    's’élargit jusqu’à inclure un tronçon : avis retiré, étiquette posée '
    '(jaune : cas construit, niveau jamais observé en production — VC-04)',
    (WidgetTester tester) async {
      final _Harness h = await _pumpMap(tester);
      await _choisir(tester, MapScaleKind.crues);
      // À l'est de l'emprise d'une fenêtre de 800 px au zoom de départ
      // (environ 17,6° de longitude de part et d'autre du centre), dans
      // celle d'une fenêtre de 1 400 px (environ 30,8°).
      h.source.last.complete(
        FloodVigilanceMap(
          informationDate: _date,
          sections: <FloodSection>[
            _section('J7', const Jaune(), <GeoPoint>[
              GeoPoint(latitude: initialMapCenterLatitude, longitude: 25),
              GeoPoint(latitude: initialMapCenterLatitude, longitude: 26),
            ]),
          ],
          skippedEntities: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(h.flood.anySectionInBounds, isFalse);
      expect(find.text(noFloodSectionInAreaText), findsOneWidget);
      expect(find.byType(FloodSectionLabel), findsNothing);
      final double zoom = h.viewModel.zoom!;

      tester.view.physicalSize = const Size(1400, 700);
      await tester.pumpAndSettle();

      expect(h.viewModel.zoom, zoom, reason: 'la caméra n’a pas zoomé');
      expect(h.flood.anySectionInBounds, isTrue);
      expect(find.text(noFloodSectionInAreaText), findsNothing);
      expect(find.byType(FloodSectionLabel), findsOneWidget);
    },
  );
}

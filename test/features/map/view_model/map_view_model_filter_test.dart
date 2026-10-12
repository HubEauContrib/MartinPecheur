// Verrouille le filtre de la carte porté par `MapViewModel` (lot 3 de T3),
// sans monter aucun widget : le filtre appliqué, effacé, gardé le temps de la
// session, et les marqueurs individuels qu'il retient. Les faits lus
// (`stations`, `ondeObservations`) ne sont jamais filtrés : les avis
// d'absence s'y décident.
//
// Les doubles de dépôt sont recopiés de `map_view_model_test.dart` (classes
// privées, non importables). Aucune borne de fraîcheur n'est écrite ici : les
// instants se déduisent de `ancienneApres` et `perimeeApres` (`BR-005`).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

const AdministrativeArea _loirEtCher = AdministrativeArea(
  code: '41',
  label: 'Loir-et-Cher',
);
const AdministrativeArea _indreEtLoire = AdministrativeArea(
  code: '37',
  label: 'Indre-et-Loire',
);
const AdministrativeArea _centreValDeLoire = AdministrativeArea(
  code: '24',
  label: 'Centre-Val de Loire',
);

Bounds _loireBounds() => Bounds(west: -1, south: 46, east: 3, north: 48);

/// Une observation ONDE synthétique du jeu du lot 3, datée du 2026-08-25.
OndeObservation _obs(
  String code, {
  required FlowCategory category,
  AdministrativeArea? departement,
  AdministrativeArea? region,
  double latitude = 47.5,
  double longitude = 1.3,
}) {
  final OndeStationCode station = OndeStationCode(code);
  return OndeObservation(
    station: station,
    point: OndePoint(
      code: station,
      label: 'Point $code',
      latitude: latitude,
      longitude: longitude,
      waterCourseLabel: 'La Loire',
      departement: departement,
      region: region,
    ),
    observedAt: DateTime.utc(2026, 8, 25),
    category: category,
    rawFlowCode: null,
    officialLabel: null,
    campaignCode: '2026',
  );
}

/// `A` à `E` : quatre catégories, deux `Inconnu` de codes bruts différents,
/// et un point sans département.
List<OndeObservation> _ondeSet() => <OndeObservation>[
  _obs(
    'K4520001',
    category: const Ecoulement(),
    departement: _loirEtCher,
    region: _centreValDeLoire,
    longitude: 1.1,
  ),
  _obs(
    'K4520002',
    category: const Assec(),
    departement: _loirEtCher,
    region: _centreValDeLoire,
    longitude: 1.2,
  ),
  _obs(
    'K4520003',
    category: const Inconnu('9'),
    departement: _loirEtCher,
    region: _centreValDeLoire,
    longitude: 1.3,
  ),
  _obs(
    'K4520004',
    category: const Inconnu(null),
    departement: _indreEtLoire,
    region: _centreValDeLoire,
    longitude: 1.4,
  ),
  _obs('K4520005', category: const NonObserve(), longitude: 1.5),
];

const String _a = 'K4520001';
const String _b = 'K4520002';
const String _c = 'K4520003';
const String _d = 'K4520004';
const String _e = 'K4520005';

StationPoint _station(
  String code, {
  AdministrativeArea? departement,
  required double longitude,
}) => StationPoint(
  code: StationCode(code),
  label: 'Station $code',
  latitude: 47,
  longitude: longitude,
  departement: departement,
  region: departement == null ? null : _centreValDeLoire,
);

const String _s1 = 'K447000001';
const String _s2 = 'K447000002';
const String _s3 = 'K447000003';
const String _s4 = 'K447000004';

/// `S1` à `S4` : deux stations du `41`, une du `37`, une sans département.
List<StationPoint> _stationSet() => <StationPoint>[
  _station(_s1, departement: _loirEtCher, longitude: 1.1),
  _station(_s2, departement: _loirEtCher, longitude: 1.2),
  _station(_s3, departement: _indreEtLoire, longitude: 1.3),
  _station(_s4, longitude: 1.4),
];

HydroObservation _discharge(StationCode station, DateTime measuredAt) {
  return HydroObservation(
    station: station,
    measuredAt: measuredAt,
    grandeur: Grandeur.debit,
    discharge: const CubicMetresPerSecond(47.8),
    level: null,
    qualification: const Qualification(
      statusCode: 4,
      statusLabel: 'Donnée validée',
      qualificationCode: 1,
      qualificationLabel: 'Bonne',
    ),
  );
}

List<String> _stationCodes(Iterable<StationPoint> points) =>
    points.map((StationPoint point) => point.code.value).toList();

List<String> _ondeCodes(Iterable<OndeObservation> observations) => observations
    .map((OndeObservation observation) => observation.station.value)
    .toList();

final class _StationPointRepositoryDouble implements StationPointRepository {
  int calls = 0;
  Bounds? receivedBounds;
  double? receivedMargin;
  Future<List<StationPoint>> Function(int call)? answer;
  int allCalls = 0;
  Future<List<StationPoint>> Function()? allAnswer;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) {
    calls++;
    receivedBounds = bounds;
    receivedMargin = margin;
    final Future<List<StationPoint>> Function(int call)? configured = answer;
    if (configured == null) {
      return Future<List<StationPoint>>.value(<StationPoint>[]);
    }
    return configured(calls);
  }

  @override
  Future<List<StationPoint>> all() async {
    allCalls++;
    final Future<List<StationPoint>> Function()? configured = allAnswer;
    if (configured == null) {
      return const <StationPoint>[];
    }
    return configured();
  }
}

final class _HydroObservationRepositoryDouble
    implements HydroObservationRepository {
  final List<(StationCode, Grandeur)> requests = <(StationCode, Grandeur)>[];
  Future<HydroObservation?> Function(StationCode station, int call)? answer;

  List<String> get requestedCodes => requests
      .map(((StationCode, Grandeur) request) => request.$1.value)
      .toList();

  @override
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur) {
    requests.add((station, grandeur));
    final Future<HydroObservation?> Function(StationCode, int)? configured =
        answer;
    if (configured == null) {
      return Future<HydroObservation?>.value();
    }
    return configured(station, requests.length);
  }
}

final class _OndeObservationRepositoryDouble
    implements OndeObservationRepository {
  int boundsCalls = 0;
  Bounds? receivedBounds;
  DateTime? receivedSince;
  Future<List<OndeObservation>> Function(int call)? answer;
  int unreadableRows = 0;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    boundsCalls++;
    receivedBounds = bounds;
    receivedSince = since;
    final Future<List<OndeObservation>> Function(int call)? configured = answer;
    final List<OndeObservation> observations = configured == null
        ? <OndeObservation>[]
        : await configured(boundsCalls);
    return OndeSweep(
      observations: observations,
      unreadableRows: unreadableRows,
    );
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) => Future<List<OndeObservation>>.value(<OndeObservation>[]);
}

void main() {
  late _StationPointRepositoryDouble repository;
  late _HydroObservationRepositoryDouble observations;
  late _OndeObservationRepositoryDouble onde;
  late List<Duration> delays;

  /// L'instant de référence de tous les cas datés : 2026-09-13T10:00Z.
  DateTime nowAtTen() => DateTime.utc(2026, 9, 13, 10);

  MapViewModel build({DateTime Function()? now}) {
    return MapViewModel(
      stationPoints: repository,
      observations: observations,
      onde: onde,
      now: now ?? nowAtTen,
      delay: (Duration duration) {
        delays.add(duration);
        return Future<void>.value();
      },
    );
  }

  final MapFilter sansAssec = MapFilter.none.withCategory(
    const Assec(),
    shown: false,
  );
  final MapFilter moinsDe2h = MapFilter.none.withDischargeFreshness(
    DischargeFreshnessCriterion.moinsDe2h,
  );
  final MapFilter moinsDe24h = MapFilter.none.withDischargeFreshness(
    DischargeFreshnessCriterion.moinsDe24h,
  );

  setUp(() {
    repository = _StationPointRepositoryDouble();
    observations = _HydroObservationRepositoryDouble();
    onde = _OndeObservationRepositoryDouble();
    delays = <Duration>[];
  });

  group('le filtre appliqué', () {
    test('au départ : aucun critère, filtre inactif', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      expect(viewModel.filter, MapFilter.none);
      expect(viewModel.filterActive, isFalse);
    });

    test('un MapViewModel neuf ne reprend pas le filtre du précédent : rien '
        "n'est relu d'un stockage", () {
      final MapViewModel first = build();
      addTearDown(first.dispose);
      first.applyFilter(sansAssec.withDepartement('41'));

      final MapViewModel second = build();
      addTearDown(second.dispose);

      expect(second.filter, MapFilter.none);
      expect(second.filterActive, isFalse);
    });

    test('applyFilter pose le filtre et notifie une fois ; le filtre est '
        "gardé au changement d'échelle (session)", () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.applyFilter(sansAssec);

      expect(notifications, 1);
      expect(viewModel.filter, sansAssec);
      expect(viewModel.filterActive, isTrue);

      viewModel.selectScale(MapScaleKind.debit);

      expect(viewModel.filterActive, isFalse);
      expect(viewModel.filter, sansAssec);

      viewModel.selectScale(MapScaleKind.ecoulement);

      expect(viewModel.filterActive, isTrue);
      expect(viewModel.filter, sansAssec);
    });

    test("applyFilter d'un filtre égal au courant ne notifie pas", () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.applyFilter(sansAssec);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.applyFilter(
        MapFilter.none.withCategory(const Assec(), shown: false),
      );

      expect(notifications, 0);
      expect(viewModel.filter, sansAssec);
    });

    test('clearFilter remet aucun critère et notifie une fois', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.applyFilter(
        sansAssec
            .withDepartement('41')
            .withDischargeFreshness(DischargeFreshnessCriterion.moinsDe2h),
      );
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.clearFilter();

      expect(viewModel.filter, MapFilter.none);
      expect(viewModel.filterActive, isFalse);
      expect(notifications, 1);
    });

    test('clearFilter sans critère ne notifie pas', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.clearFilter();

      expect(notifications, 0);
    });

    test("applyFilter et clearFilter n'appellent aucun dépôt", () async {
      repository.answer = (int _) async => _stationSet();
      onde.answer = (int _) async => _ondeSet();
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      final int pointCalls = repository.calls;
      final int ondeCalls = onde.boundsCalls;

      viewModel.applyFilter(moinsDe2h.withDepartement('41'));
      viewModel.clearFilter();
      await pumpEventQueue();

      expect(repository.calls, pointCalls);
      expect(repository.allCalls, 0);
      expect(onde.boundsCalls, ondeCalls);
      expect(observations.requests, isEmpty);
    });
  });

  group('écoulement, niveau individuel', () {
    Future<MapViewModel> loaded() async {
      onde.answer = (int _) async => _ondeSet();
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      return viewModel;
    }

    final MapFilter toutesDecochees = filterableFlowCategories.fold(
      MapFilter.none,
      (MapFilter filter, FlowCategory category) =>
          filter.withCategory(category, shown: false),
    );

    final Map<String, (MapFilter, List<String>)> cases =
        <String, (MapFilter, List<String>)>{
          'aucun critère : les cinq': (
            MapFilter.none,
            <String>[_a, _b, _c, _d, _e],
          ),
          'Assec décochée': (sansAssec, <String>[_a, _c, _d, _e]),
          'Inconnu décochée : les deux Inconnu sortent, quelle que soit leur '
              'valeur brute': (
            MapFilter.none.withCategory(const Inconnu(null), shown: false),
            <String>[_a, _b, _e],
          ),
          'département 41 : le point sans département reste': (
            MapFilter.none.withDepartement('41'),
            <String>[_a, _b, _c, _e],
          ),
          'département 41 et Assec décochée': (
            sansAssec.withDepartement('41'),
            <String>[_a, _c, _e],
          ),
          'six cases décochées : aucun marqueur': (toutesDecochees, <String>[]),
        };

    for (final MapEntry<String, (MapFilter, List<String>)> entry
        in cases.entries) {
      test(entry.key, () async {
        final MapViewModel viewModel = await loaded();
        final (MapFilter filter, List<String> expected) = entry.value;

        viewModel.applyFilter(filter);

        expect(_ondeCodes(viewModel.individualOndeObservations), expected);
        expect(
          _ondeCodes(viewModel.orderedIndividualOndeObservations).toSet(),
          expected.toSet(),
        );
        expect(
          viewModel.ondeObservations,
          hasLength(5),
          reason: 'les faits lus ne sont pas filtrés',
        );
      });
    }
  });

  group('débit, niveau individuel', () {
    /// `S1` fraîche, `S2` ancienne, `S3` périmée, `S4` en échec.
    void answerBySet() {
      final DateTime now = nowAtTen();
      final Map<String, DateTime> measuredAt = <String, DateTime>{
        _s1: now.subtract(ancienneApres ~/ 2),
        _s2: now.subtract(ancienneApres + const Duration(hours: 1)),
        _s3: now.subtract(perimeeApres + const Duration(hours: 1)),
      };
      observations.answer = (StationCode station, int _) async {
        final DateTime? instant = measuredAt[station.value];
        if (instant == null) {
          throw StateError('source en panne pour ${station.value}');
        }
        return _discharge(station, instant);
      };
    }

    Future<MapViewModel> onDischarge({DateTime Function()? now}) async {
      repository.answer = (int _) async => _stationSet();
      final MapViewModel viewModel = build(now: now);
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);
      await viewModel.loadFor(_loireBounds());
      return viewModel;
    }

    final Map<String, (MapFilter, List<String>)> cases =
        <String, (MapFilter, List<String>)>{
          'aucun critère : les quatre': (
            MapFilter.none,
            <String>[_s1, _s2, _s3, _s4],
          ),
          'moins de 2 h : la fraîche, et la station en échec reste': (
            moinsDe2h,
            <String>[_s1, _s4],
          ),
          'moins de 24 h : la périmée seule sort': (
            moinsDe24h,
            <String>[_s1, _s2, _s4],
          ),
          'département 41 : la station sans département reste': (
            MapFilter.none.withDepartement('41'),
            <String>[_s1, _s2, _s4],
          ),
          'département 41 et moins de 2 h': (
            moinsDe2h.withDepartement('41'),
            <String>[_s1, _s4],
          ),
        };

    for (final MapEntry<String, (MapFilter, List<String>)> entry
        in cases.entries) {
      test(entry.key, () async {
        answerBySet();
        final MapViewModel viewModel = await onDischarge();
        await viewModel.preloadVisibleStations();
        final (MapFilter filter, List<String> expected) = entry.value;

        viewModel.applyFilter(filter);

        expect(viewModel.stateOf(StationCode(_s4)), isA<EnEchec>());
        expect(_stationCodes(viewModel.individualStations), expected);
        expect(
          _stationCodes(viewModel.orderedIndividualStations).toSet(),
          expected.toSet(),
        );
        expect(
          viewModel.stations,
          hasLength(4),
          reason: 'les faits lus ne sont pas filtrés',
        );
      });
    }

    test('avant tout préchargement, moins de 2 h garde les quatre stations '
        'non chargées', () async {
      final MapViewModel viewModel = await onDischarge();

      viewModel.applyFilter(moinsDe2h);

      expect(observations.requests, isEmpty);
      for (final StationPoint point in viewModel.stations) {
        expect(viewModel.stateOf(point.code), isA<NonChargee>());
      }
      expect(_stationCodes(viewModel.individualStations), <String>[
        _s1,
        _s2,
        _s3,
        _s4,
      ]);
    });

    test('une station sans donnée reste sous moins de 2 h', () async {
      observations.answer = (StationCode _, int _) async => null;
      final MapViewModel viewModel = await onDischarge();
      await viewModel.preloadVisibleStations();

      viewModel.applyFilter(moinsDe2h);

      expect(viewModel.stateOf(StationCode(_s1)), isA<SansDonnee>());
      expect(_stationCodes(viewModel.individualStations), <String>[
        _s1,
        _s2,
        _s3,
        _s4,
      ]);
    });

    test('filtre inactif : individualStations est la liste même de stations, '
        'sans copie', () async {
      final MapViewModel viewModel = await onDischarge();

      expect(viewModel.filterActive, isFalse);
      expect(identical(viewModel.individualStations, viewModel.stations), true);

      // Une case décochée ne joue pas sur l'échelle débit : toujours inactif.
      viewModel.applyFilter(sansAssec);

      expect(viewModel.filterActive, isFalse);
      expect(identical(viewModel.individualStations, viewModel.stations), true);
    });

    test('sous le zoom 9, une station sans zone reste individuelle, et le '
        'critère de fraîcheur la retient ou non', () async {
      final DateTime now = nowAtTen();
      observations.answer = (StationCode station, int _) async => _discharge(
        station,
        now.subtract(perimeeApres + const Duration(hours: 1)),
      );
      repository.answer = (int _) async => _stationSet();
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);
      await viewModel.onGestureEnded(
        _loireBounds(),
        zoom: individualMarkersFromZoom - 1,
      );
      await viewModel.preloadVisibleStations();

      // Sans critère : la seule station sans département, périmée ou non.
      expect(_stationCodes(viewModel.individualStations), <String>[_s4]);

      viewModel.applyFilter(moinsDe24h);

      expect(viewModel.stateOf(StationCode(_s4)), isA<Chargee>());
      expect(viewModel.individualStations, isEmpty);
      expect(viewModel.stations, hasLength(4));
    });

    /// Une mesure vieillit à l'écran sans nouvelle requête (`BR-005`) : elle
    /// sort du filtre à la lecture qui suit le passage de la [borne].
    Future<void> vieillit(MapFilter filter, Duration borne) async {
      final DateTime m = nowAtTen();
      DateTime clock = m.add(borne - const Duration(seconds: 1));
      observations.answer = (StationCode station, int _) async =>
          station.value == _s1 ? _discharge(station, m) : null;
      final MapViewModel viewModel = await onDischarge(now: () => clock);
      await viewModel.preloadVisibleStations();
      viewModel.applyFilter(filter);
      final int requests = observations.requests.length;
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      expect(_stationCodes(viewModel.individualStations), contains(_s1));

      // La borne pile appartient à l'état le plus sévère.
      clock = m.add(borne);

      expect(_stationCodes(viewModel.individualStations), isNot(contains(_s1)));
      expect(viewModel.stations, hasLength(4));
      expect(
        observations.requests,
        hasLength(requests),
        reason: 'aucune requête de plus',
      );
      expect(notifications, 0);
    }

    test(
      'une mesure qui atteint ancienneApres sort de moins de 2 h, sans '
      'requête ni notification',
      () => vieillit(moinsDe2h, ancienneApres),
    );

    test(
      'une mesure qui atteint perimeeApres sort de moins de 24 h, sans '
      'requête ni notification',
      () => vieillit(moinsDe24h, perimeeApres),
    );
  });
}

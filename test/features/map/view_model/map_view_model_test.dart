// Verrouille le ViewModel de la carte, sans monter aucun widget et sans
// rendre de `FlutterMap`. Les premiers cas sont ceux de
// `MapStationsController` (T0-M4), reecrits sur `MapViewModel` : appel type
// au depot au lieu d'un message envoye a un registre (R3, arbitrage
// 2026-09-13).
//
// V2 y ajoute l'echelle active (BR-008), l'etat par station (BR-007) et le
// prechargement borne (NFR-07). Deux injections rendent ces cas
// deterministes et INSTANTANES : `now` — les bornes de BR-005 se testent
// aux valeurs exactes plutot qu'a ce que la machine affiche — et `delay`,
// qui compte les attentes de l'etalement sans jamais attendre. Sans cette
// seconde injection, un test du prechargement de 20 stations durerait
// 4 secondes de mur.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

/// Codes reels des fixtures du projet (D1) : une station de metropole, une
/// d'outre-mer. Les codes synthetiques de `_grid` en derivent le prefixe.
StationPoint _blois() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
);

StationPoint _guadeloupe() => StationPoint(
  code: StationCode('1011000101'),
  label: 'Grande Rivière à Goyaves',
  latitude: 16.189402,
  longitude: -61.658989,
);

/// Un point synthetique a coordonnees choisies, pour les cas de selection
/// par proximite : le code garde le prefixe reel `K44700` et se termine par
/// [suffix], quatre caracteres A-Z0-9 — dix caracteres au total, la seule
/// forme que `StationCode` accepte (C-05).
StationPoint _point(String suffix, {required double lat, required double lon}) {
  return StationPoint(
    code: StationCode('K44700$suffix'),
    label: 'Station $suffix',
    latitude: lat,
    longitude: lon,
  );
}

/// [count] points alignes en longitude croissante, de plus en plus loin du
/// meridien 0 : l'ordre de la liste est donc deja l'ordre de proximite au
/// centre de `_wideBounds`, ce qui rend lisible le cas « les 20 plus
/// proches ».
List<StationPoint> _grid(int count) => <StationPoint>[
  for (int i = 0; i < count; i++)
    _point(i.toString().padLeft(4, '0'), lat: 46, lon: i.toDouble() / 100),
];

/// Emprise large centree sur (46, 0), pour `_grid`.
Bounds _wideBounds() => Bounds(west: -5, south: 41, east: 5, north: 51);

Bounds _loireBounds() => Bounds(west: -1, south: 46, east: 3, north: 48);

/// Une observation de debit datee, aux valeurs reelles de la fixture
/// (47 800 l/s recus, soit 47,8 m³/s apres conversion — BR-002, C-02).
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

/// Une observation d'ecoulement ONDE datee, pour une station a huit
/// caracteres (T-04).
OndeObservation _onde(String code, DateTime observedAt) {
  final OndeStationCode station = OndeStationCode(code);
  return OndeObservation(
    station: station,
    point: OndePoint(
      code: station,
      label: 'Point $code',
      latitude: 47.5,
      longitude: 1.3,
      waterCourseLabel: 'La Loire',
      departement: DepartementCode('41'),
    ),
    observedAt: observedAt,
    category: const Ecoulement(),
    rawFlowCode: '1a',
    officialLabel: 'Ecoulement visible acceptable',
    campaignCode: '2026',
  );
}

/// Double de test du depot de points : compte les appels, note l'emprise
/// recue, et rend ce qu'on lui a dit de rendre — ou leve.
final class _StationPointRepositoryDouble implements StationPointRepository {
  int calls = 0;
  Bounds? receivedBounds;
  double? receivedMargin;
  Future<List<StationPoint>> Function(int call)? answer;

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
}

/// Double du depot hydrometrique : retient chaque couple demande, dans
/// l'ORDRE des appels — c'est cet ordre qui prouve la selection par
/// proximite.
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

/// Double du depot ONDE : note l'emprise et la borne `since` recues.
final class _OndeObservationRepositoryDouble
    implements OndeObservationRepository {
  int boundsCalls = 0;
  Bounds? receivedBounds;
  DateTime? receivedSince;
  Future<List<OndeObservation>> Function(int call)? answer;

  /// Nombre de lignes illisibles rendu AVEC chaque balayage (`U6`, T-14) :
  /// reglable entre deux appels, comme le ferait une emprise propre apres
  /// une emprise sale.
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

  /// L'instant de reference de tous les cas dates : 2026-09-13T10:00Z.
  DateTime nowAtTen() => DateTime.utc(2026, 9, 13, 10);

  /// Construit le ViewModel avec les trois doubles et une attente qui
  /// COMPTE sans attendre — le prechargement s'execute alors en un tour de
  /// boucle d'evenements, pas en quatre secondes.
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

  setUp(() {
    repository = _StationPointRepositoryDouble();
    observations = _HydroObservationRepositoryDouble();
    onde = _OndeObservationRepositoryDouble();
    delays = <Duration>[];
  });

  test('charge deux points au demarrage, en un seul appel au depot', () async {
    repository.answer = (int _) async => <StationPoint>[
      _blois(),
      _guadeloupe(),
    ];
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);

    await viewModel.loadInitial();

    expect(repository.calls, 1);
    expect(viewModel.stations, hasLength(2));
    expect(viewModel.error, isNull);
    expect(
      repository.receivedBounds,
      same(MapViewModel.startupBounds),
      reason:
          "l'emprise de demarrage est celle du ViewModel, jamais une "
          'valeur reconstruite au vol',
    );
  });

  test('loadFor notifie deux fois quand l\'ONDE repond : une fois pour les '
      'points, une pour l\'ONDE (UC-001 § 4)', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.loadFor(_loireBounds());

    expect(notifications, 2);
    expect(viewModel.stations, hasLength(1));
  });

  test("loadFor ne notifie qu'une fois en echelle debit : aucune ONDE a "
      'attendre', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);
    viewModel.selectScale(MapScaleKind.debit);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.loadFor(_loireBounds());

    expect(notifications, 1);
  });

  test('loadFor notifie DES QUE les points sont poses, avant meme que '
      "l'ONDE reponde : les marqueurs sont immediats, l'ONDE suit "
      '(UC-001 § 4)', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final Completer<List<OndeObservation>> ondeCompleter =
        Completer<List<OndeObservation>>();
    onde.answer = (int _) => ondeCompleter.future;
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    final Future<void> pending = viewModel.loadFor(_loireBounds());
    await pumpEventQueue();

    expect(
      viewModel.stations,
      hasLength(1),
      reason:
          "les points viennent d'un asset local : rien ne doit les "
          "retarder derriere l'ONDE",
    );
    expect(viewModel.error, isNull);
    expect(notifications, 1);
    expect(viewModel.ondeObservations, isEmpty);

    ondeCompleter.complete(<OndeObservation>[
      _onde('K4520001', DateTime.utc(2026, 8, 25)),
    ]);
    await pending;

    expect(viewModel.ondeObservations, hasLength(1));
    expect(notifications, 2);
  });

  test('loadFor — une emprise inchangee ne renvoie pas de requete', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);

    await viewModel.loadFor(_loireBounds());
    await viewModel.loadFor(_loireBounds());

    expect(repository.calls, 1);
  });

  test(
    'loadFor sur un ViewModel dispose ne leve rien et ne notifie pas',
    () async {
      final Completer<List<StationPoint>> completer =
          Completer<List<StationPoint>>();
      repository.answer = (int _) => completer.future;
      final MapViewModel viewModel = build();
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      final Future<void> pending = viewModel.loadFor(_loireBounds());
      viewModel.dispose();
      completer.complete(<StationPoint>[_blois()]);

      await expectLater(pending, completes);
      expect(notifications, 0);
    },
  );

  test('un depot qui leve rend une erreur visible via error, plutot que de '
      'la laisser remonter (BR-007)', () async {
    repository.answer = (int _) async => throw StateError('panne de depot');
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);

    await viewModel.loadFor(_loireBounds());

    expect(viewModel.error, isA<StateError>());
    expect(viewModel.stations, isEmpty);
  });

  test('un chargement reussi efface une erreur precedente, sur la MEME '
      'emprise', () async {
    repository.answer = (int call) async {
      if (call == 1) {
        throw StateError('panne temporaire');
      }
      return <StationPoint>[_blois()];
    };
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);
    final Bounds bounds = _loireBounds();

    await viewModel.loadFor(bounds);
    expect(viewModel.error, isNotNull);

    await viewModel.loadFor(bounds);
    expect(viewModel.error, isNull);
    expect(viewModel.stations, hasLength(1));
  });

  test(
    'apres un echec, un nouveau chargement sur la MEME emprise rappelle '
    'le depot : une emprise qui a echoue ne compte pas comme chargee, '
    "sinon l'ecran reste en erreur jusqu'a ce que l'usager bouge la carte",
    () async {
      repository.answer = (int call) async {
        if (call == 1) {
          throw StateError('panne temporaire');
        }
        return <StationPoint>[_blois()];
      };
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      final Bounds bounds = _loireBounds();

      await viewModel.loadFor(bounds);
      await viewModel.loadFor(bounds);

      expect(repository.calls, 2);
    },
  );

  test('deux chargements rapproches sur des emprises differentes : la '
      'reponse de la premiere, plus lente, ne doit pas ecraser celle de la '
      'seconde', () async {
    final Completer<List<StationPoint>> slow = Completer<List<StationPoint>>();
    final Completer<List<StationPoint>> fast = Completer<List<StationPoint>>();
    repository.answer = (int call) => call == 1 ? slow.future : fast.future;
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);

    final Future<void> firstLoad = viewModel.loadFor(_loireBounds());
    final Future<void> secondLoad = viewModel.loadFor(
      Bounds(west: -62, south: 15, east: -61, north: 17),
    );

    fast.complete(<StationPoint>[_guadeloupe()]);
    await secondLoad;
    slow.complete(<StationPoint>[_blois()]);
    await firstLoad;

    expect(repository.calls, 2);
    expect(
      viewModel.stations.single.code.value,
      _guadeloupe().code.value,
      reason:
          "l'etat doit finir sur l'emprise demandee en DERNIER, quel que "
          "soit l'ordre d'arrivee des reponses",
    );
  });

  test("stations expose une vue immuable : un appelant ne peut pas y "
      'ajouter un point', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = build();
    addTearDown(viewModel.dispose);

    await viewModel.loadInitial();

    expect(() => viewModel.stations.add(_guadeloupe()), throwsUnsupportedError);
  });

  group('echelle active (BR-008)', () {
    test("l'echelle par defaut est l'ecoulement (UC-001 § 3)", () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      expect(viewModel.scale, MapScaleKind.ecoulement);
    });

    test('selectScale(debit) notifie une fois, et une seule', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.selectScale(MapScaleKind.debit);

      expect(viewModel.scale, MapScaleKind.debit);
      expect(notifications, 1);
    });

    test("selectScale sur l'echelle DEJA active ne notifie pas : la vue ne "
        'reconstruit pas 4 150 marqueurs pour un choix sans effet', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.selectScale(MapScaleKind.ecoulement);

      expect(notifications, 0);
    });
  });

  group('etat par station (BR-007)', () {
    test('une station jamais chargee porte NonChargee, jamais SansDonnee '
        "— un ecran en cours de chargement n'affiche pas d'etat par "
        'defaut', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      expect(viewModel.stateOf(StationCode('K447001001')), const NonChargee());
    });

    test('une observation du 2026-09-13T09:00Z vue a 10:00Z rend '
        'Chargee(fraiche) — la fraicheur se calcule sur la date de MESURE '
        '(BR-001, BR-005)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      observations.answer = (StationCode station, int _) async =>
          _discharge(station, DateTime.utc(2026, 9, 13, 9));
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());
      await viewModel.preloadVisibleStations();

      expect(
        viewModel.stateOf(StationCode('K447001001')),
        const Chargee(Freshness.fraiche),
      );
    });

    test('un depot qui rend null pour une station rend SansDonnee : une '
        'absence constatee, jamais une erreur', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      observations.answer = (StationCode _, int _) async => null;
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());
      await viewModel.preloadVisibleStations();

      expect(viewModel.stateOf(StationCode('K447001001')), const SansDonnee());
    });

    test('une panne sur UNE station rend EnEchec avec sa cause, et les '
        'autres stations gardent leur etat (UC-001 A4)', () async {
      repository.answer = (int _) async => <StationPoint>[
        _point('000A', lat: 46, lon: 0),
        _point('000B', lat: 46, lon: 1),
      ];
      final StateError panne = StateError('Hub Eau indisponible');
      observations.answer = (StationCode station, int _) async {
        if (station.value == 'K44700000B') {
          throw panne;
        }
        return _discharge(station, DateTime.utc(2026, 9, 13, 9));
      };
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations();

      expect(viewModel.stateOf(StationCode('K44700000B')), EnEchec(panne));
      expect(
        viewModel.stateOf(StationCode('K44700000A')),
        const Chargee(Freshness.fraiche),
        reason:
            'une source defaillante ne doit pas effacer ce que les autres '
            'ont deja rendu (BR-007, UC-001 A4)',
      );
    });
  });

  group('prechargement borne et annulable (NFR-07)', () {
    test('50 stations visibles donnent 20 requetes de debit, pas 50 : une '
        'API sans quota documente ne recoit pas 50 appels par geste '
        '(C-12)', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(20));
      expect(
        observations.requests.every(
          ((StationCode, Grandeur) request) => request.$2 == Grandeur.debit,
        ),
        isTrue,
        reason:
            'la carte precharge le DEBIT, jamais la hauteur : une hauteur '
            "n'a pas d'echelle sur la carte (BR-008)",
      );
    });

    test('5 stations visibles donnent 5 requetes : la borne plafonne, elle '
        'ne complete pas', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(5));
    });

    test(
      'une emprise sans station ne declenche aucune requete (UC-001 A2)',
      () async {
        repository.answer = (int _) async => <StationPoint>[];
        final MapViewModel viewModel = build();
        addTearDown(viewModel.dispose);

        await viewModel.loadFor(_wideBounds());
        await viewModel.preloadVisibleStations(limit: 20);

        expect(observations.requests, isEmpty);
        expect(delays, isEmpty);
      },
    );

    test('preloadVisibleStations(limit: 0) ne fait aucun appel et ne '
        'notifie pas', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.preloadVisibleStations(limit: 0);

      expect(observations.requests, isEmpty);
      expect(notifications, 0);
    });

    test('preloadVisibleStations(limit: -1) ne fait aucun appel et ne '
        'notifie pas', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.preloadVisibleStations(limit: -1);

      expect(observations.requests, isEmpty);
      expect(notifications, 0);
    });

    test('le prechargement notifie une fois PAR ETAT DE STATION recu : 5 '
        'stations visibles donnent 5 notifications, jamais une seule a la '
        'fin', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.preloadVisibleStations(limit: 20);

      expect(notifications, 5);
    });

    test('cancelPreload() pendant la 3e requete arrete la boucle : aucune '
        'requete supplementaire', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());

      observations.answer = (StationCode station, int call) async {
        if (call == 3) {
          viewModel.cancelPreload();
        }
        return _discharge(station, DateTime.utc(2026, 9, 13, 9));
      };

      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(3));
    });

    test(
      'un nouveau geste annule le prechargement en cours avant d en '
      'lancer un autre : les requetes de l emprise quittee cessent',
      () async {
        repository.answer = (int call) async =>
            call == 1 ? _grid(50) : <StationPoint>[_guadeloupe()];
        final MapViewModel viewModel = build();
        addTearDown(viewModel.dispose);
        await viewModel.loadFor(_wideBounds());

        observations.answer = (StationCode station, int call) async {
          if (call == 2) {
            // Le geste suivant, pendant que le prechargement tourne.
            await viewModel.loadFor(
              Bounds(west: -62, south: 15, east: -61, north: 17),
            );
          }
          return _discharge(station, DateTime.utc(2026, 9, 13, 9));
        };

        await viewModel.preloadVisibleStations(limit: 20);
        final int afterCancel = observations.requests.length;

        await viewModel.preloadVisibleStations(limit: 20);

        expect(
          afterCancel,
          2,
          reason: "le prechargement de l'emprise quittee s'arrete net",
        );
        expect(observations.requestedCodes.sublist(afterCancel), <String>[
          '1011000101',
        ], reason: "le prechargement suivant porte sur la NOUVELLE emprise");
      },
    );

    test('les stations retenues sont les plus proches du centre de '
        "l'emprise, l'egalite tranchee par le code station", () async {
      // Centre de `_wideBounds` : (46, 0).
      repository.answer = (int _) async => <StationPoint>[
        _point('000D', lat: 46, lon: 4), // le plus loin
        _point('000C', lat: 46, lon: 1), // a egalite avec B
        _point('000B', lat: 47, lon: 0), // a egalite avec C
        _point('000A', lat: 46, lon: 0), // le plus proche
      ];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 3);

      expect(
        observations.requestedCodes,
        <String>['K44700000A', 'K44700000B', 'K44700000C'],
        reason:
            "A est au centre ; B et C sont a 1 degre — l'egalite se tranche "
            "par le code, jamais par l'ordre du referentiel, sinon deux "
            'executions ne prechargeraient pas les memes stations',
      );
    });

    test('le prechargement espace les requetes de 200 ms (decision 4 du '
        'plan T1) : une attente ENTRE deux requetes, jamais avant la '
        'premiere', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(5));
      expect(delays, hasLength(4));
      expect(delays.toSet(), <Duration>{const Duration(milliseconds: 200)});
    });

    test('un second prechargement sur la MEME emprise ne refait aucun appel '
        'et ne notifie pas : les etats deja connus sont sautes — sinon la '
        'vue reecrit 20 etats connus et reconstruit 20 fois les 4 150 '
        'marqueurs (NFR-01)', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 20);
      expect(observations.requests, hasLength(5));
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(5));
      expect(notifications, 0);
      expect(delays, hasLength(4), reason: 'aucune attente supplementaire');
    });

    test('une station EnEchec est RETENTEE au prechargement suivant, une '
        'station Chargee ou SansDonnee ne l est pas (UC-001 A4)', () async {
      repository.answer = (int _) async => <StationPoint>[
        _point('000A', lat: 46, lon: 0),
        _point('000B', lat: 46, lon: 1),
      ];
      observations.answer = (StationCode station, int _) async {
        if (station.value == 'K44700000B') {
          throw StateError('Hub Eau indisponible');
        }
        return _discharge(station, DateTime.utc(2026, 9, 13, 9));
      };
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_wideBounds());
      await viewModel.preloadVisibleStations(limit: 20);
      expect(observations.requestedCodes, <String>['K44700000A', 'K44700000B']);

      observations.answer = (StationCode station, int _) async =>
          _discharge(station, DateTime.utc(2026, 9, 13, 9));
      await viewModel.preloadVisibleStations(limit: 20);

      expect(
        observations.requestedCodes.sublist(2),
        <String>['K44700000B'],
        reason:
            'A est Chargee et ne vaut pas une seconde requete ; B a echoue '
            'et merite un nouvel essai',
      );
      expect(
        viewModel.stateOf(StationCode('K44700000B')),
        const Chargee(Freshness.fraiche),
      );
    });

    test('la borne porte sur les REQUETES, pas sur les stations regardees : '
        'le prechargement suivant retient les 20 plus proches PARMI LES '
        'NON CHARGEES', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_wideBounds());

      await viewModel.preloadVisibleStations(limit: 20);
      expect(observations.requestedCodes.first, 'K447000000');
      expect(observations.requestedCodes.last, 'K447000019');

      await viewModel.preloadVisibleStations(limit: 20);

      expect(observations.requests, hasLength(40));
      expect(observations.requestedCodes.sublist(20).first, 'K447000020');
      expect(observations.requestedCodes.sublist(20).last, 'K447000039');
    });

    test('un dispose() pendant le prechargement ne notifie plus et ne leve '
        'aucune assertion', () async {
      repository.answer = (int _) async => _grid(5);
      final MapViewModel viewModel = build();
      await viewModel.loadFor(_wideBounds());

      int notifications = 0;
      viewModel.addListener(() => notifications++);
      final Completer<HydroObservation?> pending =
          Completer<HydroObservation?>();
      observations.answer = (StationCode _, int _) => pending.future;

      final Future<void> preload = viewModel.preloadVisibleStations(limit: 20);
      viewModel.dispose();
      pending.complete(
        _discharge(StationCode('K447000000'), DateTime.utc(2026, 9, 13, 9)),
      );

      await expectLater(preload, completes);
      expect(notifications, 0);
      expect(observations.requests, hasLength(1));
    });
  });

  group("observations d'ecoulement ONDE (BR-010)", () {
    test("sur l'echelle ecoulement, loadFor alimente ondeObservations pour "
        "l'emprise, avec since = now - 60 jours (BR-010, T-03)", () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => <OndeObservation>[
        _onde('K4520001', DateTime.utc(2026, 8, 25)),
      ];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      final Bounds bounds = _loireBounds();

      await viewModel.loadFor(bounds);

      expect(onde.boundsCalls, 1);
      expect(onde.receivedBounds, bounds);
      expect(
        onde.receivedSince,
        nowAtTen().subtract(campagneAncienneApres),
        reason:
            'la carte ne remonte jamais plus loin qu une campagne recente '
            '(BR-010) — le seuil vient de campagneAncienneApres, jamais '
            "d'un 60 recopie ici",
      );
      expect(
        viewModel.ondeObservations.keys.map(
          (OndeStationCode code) => code.value,
        ),
        <String>['K4520001'],
        reason: 'la cle est observation.station',
      );
    });

    test("sur l'echelle debit, aucun appel ONDE n'est emis (BR-008 : une "
        'seule echelle a la fois)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);

      await viewModel.loadFor(_loireBounds());

      expect(onde.boundsCalls, 0);
      expect(viewModel.ondeObservations, isEmpty);
    });

    test("repasser de debit a ecoulement recharge l'ONDE pour l'emprise "
        'courante : marqueurs et legende changent ENSEMBLE (BR-008, '
        'UC-001 A6)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => <OndeObservation>[
        _onde('K4520001', DateTime.utc(2026, 8, 25)),
      ];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);
      final Bounds bounds = _loireBounds();
      await viewModel.loadFor(bounds);
      expect(onde.boundsCalls, 0);

      viewModel.selectScale(MapScaleKind.ecoulement);
      await pumpEventQueue();

      expect(onde.boundsCalls, 1);
      expect(onde.receivedBounds, bounds);
      expect(viewModel.ondeObservations, hasLength(1));
    });

    test('une panne ONDE est posee dans error, et les points de station '
        'restent affiches (BR-007, UC-001 A4)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => throw StateError('ONDE indisponible');
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());

      expect(viewModel.error, isA<StateError>());
      expect(
        viewModel.stations,
        hasLength(1),
        reason:
            'les autres sources continuent de fonctionner : une panne ONDE '
            'ne vide pas la carte (UC-001 A4)',
      );
    });

    test("passer de l'ecoulement au debit CONSERVE ondeObservations : la "
        "map n'est pas videe, le retour a l'ecoulement a de quoi dessiner "
        'pendant le rechargement (BR-008 porte sur l affichage, pas sur '
        'la memoire)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => <OndeObservation>[
        _onde('K4520001', DateTime.utc(2026, 8, 25)),
      ];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      expect(
        viewModel.ondeObservations,
        isNotEmpty,
        reason: 'le cas ne prouve rien si la map part deja vide',
      );

      viewModel.selectScale(MapScaleKind.debit);

      expect(viewModel.ondeObservations, hasLength(1));
    });

    test('ondeObservations expose une vue immuable', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());

      expect(
        () => viewModel.ondeObservations[OndeStationCode('K4520001')] = _onde(
          'K4520001',
          DateTime.utc(2026, 8, 25),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('ondeUnreadableRows — le compte rattache a l emprise (U6, T-14)', () {
    test('zero par defaut, avant tout chargement', () {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      expect(viewModel.ondeUnreadableRows, 0);
    });

    test(
      'reflete le compte rendu par le depot pour l emprise courante',
      () async {
        repository.answer = (int _) async => <StationPoint>[_blois()];
        onde.answer = (int _) async => <OndeObservation>[
          _onde('K4520001', DateTime.utc(2026, 8, 25)),
        ];
        onde.unreadableRows = 3;
        final MapViewModel viewModel = build();
        addTearDown(viewModel.dispose);

        await viewModel.loadFor(_loireBounds());

        expect(viewModel.ondeUnreadableRows, 3);
      },
    );

    test('repasse a zero sur une emprise propre : le compte decrit CETTE '
        "emprise, jamais la session", () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => <OndeObservation>[
        _onde('K4520001', DateTime.utc(2026, 8, 25)),
      ];
      onde.unreadableRows = 3;
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      expect(viewModel.ondeUnreadableRows, 3);

      onde.unreadableRows = 0;
      await viewModel.loadFor(Bounds(west: 4, south: 43, east: 6, north: 45));

      expect(viewModel.ondeUnreadableRows, 0);
    });

    test("sur l'echelle debit, aucun appel ONDE n'est emis : le compte reste "
        'a zero (BR-008)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.unreadableRows = 7;
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);

      await viewModel.loadFor(_loireBounds());

      expect(onde.boundsCalls, 0);
      expect(viewModel.ondeUnreadableRows, 0);
    });
  });

  group('errorSource — nommer la source qui a echoue (U6, BR-007)', () {
    test('aucune erreur : errorSource est nul', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());

      expect(viewModel.error, isNull);
      expect(viewModel.errorSource, isNull);
    });

    test('le referentiel en echec : errorSource vaut referentiel', () async {
      repository.answer = (int _) async => throw StateError('asset illisible');
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());

      expect(viewModel.error, isA<StateError>());
      expect(viewModel.errorSource, MapErrorSource.referentiel);
    });

    test("l'ONDE en echec : errorSource vaut ecoulement — la vue nomme la "
        "source SANS inspecter le message d'erreur", () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int _) async => throw StateError('ONDE indisponible');
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.loadFor(_loireBounds());

      expect(viewModel.errorSource, MapErrorSource.ecoulement);
      expect(
        viewModel.stations,
        hasLength(1),
        reason:
            'une panne ONDE nomme sa source et laisse les stations '
            'affichees (UC-001 A4)',
      );
    });

    test('un chargement qui reussit apres un echec efface la source avec '
        "l'erreur", () async {
      repository.answer = (int call) async => call == 1
          ? throw StateError('asset illisible')
          : <StationPoint>[_blois()];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      expect(viewModel.errorSource, MapErrorSource.referentiel);

      await viewModel.loadFor(_loireBounds());

      expect(viewModel.error, isNull);
      expect(viewModel.errorSource, isNull);
    });

    test("un balayage ONDE qui aboutit efface l'erreur qu'une panne ONDE "
        'avait posee : sans cela, l avis « ONDE n a pas repondu » resterait '
        'affiche PAR-DESSUS les marqueurs revenus (BR-007, U6)', () async {
      repository.answer = (int _) async => <StationPoint>[_blois()];
      onde.answer = (int call) async => call == 1
          ? throw StateError('ONDE indisponible')
          : <OndeObservation>[_onde('K4520001', DateTime.utc(2026, 8, 25))];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(_loireBounds());
      expect(
        viewModel.errorSource,
        MapErrorSource.ecoulement,
        reason: 'le cas ne prouve rien si la panne n a pas eu lieu',
      );

      // Aller-retour d'echelle : c'est le seul geste qui relance l'ONDE sur
      // l'emprise courante, sans toucher au referentiel (BR-008, UC-001 A6).
      viewModel.selectScale(MapScaleKind.debit);
      viewModel.selectScale(MapScaleKind.ecoulement);
      await pumpEventQueue();

      expect(viewModel.error, isNull);
      expect(viewModel.errorSource, isNull);
      expect(
        viewModel.ondeObservations,
        hasLength(1),
        reason:
            'les observations sont revenues : une erreur perimee ne doit '
            'plus masquer ce que la carte dessine',
      );
    });
  });

  group('widenSearch — elargir la recherche (U6, UC-001 A2)', () {
    test('double la hauteur ET la largeur autour du centre de la derniere '
        'emprise demandee, puis recharge', () async {
      repository.answer = (int _) async => <StationPoint>[];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      // Centre (1, 47), largeur 4, hauteur 2.
      await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));
      expect(repository.calls, 1);

      await viewModel.widenSearch();

      expect(repository.calls, 2);
      final Bounds? elargie = repository.receivedBounds;
      expect(elargie?.west, -3);
      expect(elargie?.east, 5);
      expect(elargie?.south, 45);
      expect(elargie?.north, 49);
    });

    test('deux elargissements successifs doublent deux fois : la carte ne '
        'reste pas bloquee sur une emprise deja elargie', () async {
      repository.answer = (int _) async => <StationPoint>[];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));

      await viewModel.widenSearch();
      await viewModel.widenSearch();

      expect(repository.calls, 3);
      expect(repository.receivedBounds?.west, -7);
      expect(repository.receivedBounds?.east, 9);
      expect(repository.receivedBounds?.south, 43);
      expect(repository.receivedBounds?.north, 51);
    });

    test('les bords restent dans le domaine des coordonnees : la latitude ne '
        'depasse jamais 90 degres, la longitude 180', () async {
      repository.answer = (int _) async => <StationPoint>[];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.loadFor(
        Bounds(west: -170, south: -80, east: 170, north: 80),
      );

      await viewModel.widenSearch();

      expect(repository.receivedBounds?.west, -180);
      expect(repository.receivedBounds?.east, 180);
      expect(repository.receivedBounds?.south, -90);
      expect(repository.receivedBounds?.north, 90);
    });

    test('aucune emprise chargee : elargir ne demande rien — il n y a rien a '
        'elargir', () async {
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.widenSearch();

      expect(repository.calls, 0);
    });
  });

  // Le groupe « bandeau d'avertissement — fermeture pour la session » (W3b)
  // vivait ici : cet état (visible/masqué, fermeture, réaffichage) est
  // retiré par l'arbitrage du commanditaire du 2026-09-23 (`W3c`, « trop de
  // bandeaux à l'écran ») — le contrôle qui le remplace
  // (`lib/features/shared/warning_link.dart`) ne porte aucun état de session
  // dans ce ViewModel.

  group('start() et onGestureEnded() — l enchainement charger-puis-precharger '
      'rapatrie de la vue (H2, 2026-09-22)', () {
    test('start() sur l echelle ecoulement (par defaut) ne precharge rien : '
        'zero appel findLatest', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.start();

      expect(observations.requests, isEmpty);
    });

    test('selectScale(debit) APRES start() lance le prechargement, borne a '
        '20', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.start();

      viewModel.selectScale(MapScaleKind.debit);
      // `selectScale` lance le prechargement en tir-et-oublie : le
      // `delay` injecte rend Future.value() (aucun vrai minuteur), donc
      // une seule attente suffit a vider la chaine de micro-taches —
      // comme le faisait `_handleScaleSelected` cote vue.
      await Future<void>.delayed(Duration.zero);

      expect(observations.requests, hasLength(20));
    });

    test(
      'onGestureEnded sur l echelle debit charge PUIS precharge : 50 '
      'stations dans l emprise donnent 20 appels, dans l ordre de '
      'proximite, chacun sauf le premier precede d un delay de 200 ms',
      () async {
        repository.answer = (int _) async => _grid(50);
        final MapViewModel viewModel = build();
        addTearDown(viewModel.dispose);
        viewModel.selectScale(MapScaleKind.debit);

        await viewModel.onGestureEnded(_wideBounds());

        expect(observations.requests, hasLength(20));
        expect(
          delays,
          List<Duration>.filled(19, preloadInterval),
          reason:
              '20 requetes, 19 attentes ENTRE elles, jamais avant la '
              'premiere',
        );
      },
    );

    test('onGestureEnded sur l echelle ecoulement ne precharge rien : zero '
        'appel hydrometrie (C-15, NFR-07)', () async {
      repository.answer = (int _) async => _grid(50);
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.onGestureEnded(_wideBounds());

      expect(observations.requests, isEmpty);
    });

    test('aucun findLatest tant que loadFor n est pas termine : le '
        'prechargement attend la reponse du referentiel', () async {
      final Completer<List<StationPoint>> completer =
          Completer<List<StationPoint>>();
      repository.answer = (int _) => completer.future;
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);

      final Future<void> gesture = viewModel.onGestureEnded(_wideBounds());
      await Future<void>.delayed(Duration.zero);
      expect(
        observations.requests,
        isEmpty,
        reason:
            "le prechargement n'a rien a precharger tant que loadFor "
            "n'a pas repondu",
      );

      completer.complete(_grid(5));
      await gesture;

      expect(observations.requests, hasLength(5));
    });

    test('un changement d echelle PENDANT le chargement empeche le '
        'prechargement : l echelle est relue APRES le chargement, jamais '
        'avant', () async {
      final Completer<List<StationPoint>> completer =
          Completer<List<StationPoint>>();
      repository.answer = (int _) => completer.future;
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);

      final Future<void> gesture = viewModel.onGestureEnded(_wideBounds());
      viewModel.selectScale(MapScaleKind.ecoulement);
      completer.complete(_grid(5));
      await gesture;

      expect(observations.requests, isEmpty);
    });

    test('un second onGestureEnded pendant un prechargement annule le '
        'premier : plus aucun appel de la premiere serie une fois la '
        'seconde partie', () async {
      repository.answer = (int call) async =>
          call == 1 ? _grid(50) : <StationPoint>[_guadeloupe()];
      final MapViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      viewModel.selectScale(MapScaleKind.debit);

      observations.answer = (StationCode station, int call) async {
        if (call == 2) {
          // Le second geste, pendant que le premier prechargement
          // tourne encore.
          await viewModel.onGestureEnded(
            Bounds(west: -62, south: 15, east: -61, north: 17),
          );
        }
        return _discharge(station, DateTime.utc(2026, 9, 13, 9));
      };

      await viewModel.onGestureEnded(_wideBounds());

      expect(
        observations.requests,
        hasLength(3),
        reason:
            '2 requetes de la premiere serie avant l annulation, puis '
            '1 pour la Guadeloupe de la seconde',
      );
      expect(observations.requestedCodes.last, '1011000101');
    });
  });

  group('ondeAgeOf — l age de campagne sur l horloge du ViewModel (H2, '
      'BR-010)', () {
    test('observation du 2026-08-25 vue au 2026-09-13 est recente', () {
      final MapViewModel viewModel = build(
        now: () => DateTime.utc(2026, 9, 13),
      );
      addTearDown(viewModel.dispose);

      expect(
        viewModel.ondeAgeOf(_onde('12345678', DateTime.utc(2026, 8, 25))),
        CampaignAge.recente,
      );
    });

    test('la borne des 59 jours reste recente, 60 jours bascule en ancienne '
        '(BR-010)', () {
      final MapViewModel viewModel = build(
        now: () => DateTime.utc(2026, 9, 13),
      );
      addTearDown(viewModel.dispose);

      expect(
        viewModel.ondeAgeOf(_onde('12345678', DateTime.utc(2026, 7, 16))),
        CampaignAge.recente,
        reason: '59 jours calendaires',
      );
      expect(
        viewModel.ondeAgeOf(_onde('12345678', DateTime.utc(2026, 7, 15))),
        CampaignAge.ancienne,
        reason: '60 jours calendaires (BR-010)',
      );
    });
  });
}

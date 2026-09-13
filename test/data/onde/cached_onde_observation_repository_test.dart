// Ce test ne redémontre pas la politique de cache elle-même — c'est le
// rôle de `test/data/cache/cache_policy_test.dart`. Il démontre que
// `CachedOndeObservationRepository` la BRANCHE correctement pour ses DEUX
// méthodes : une fermeture par clé et par TTL (piège d'usage de
// `withCachePolicy`), un TTL qui dépend du mois courant et non d'une saison
// codée en dur, et une liste vide mise en cache comme une valeur ordinaire
// (BR-007).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/onde/cached_onde_observation_repository.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show OndeObservationRepository;

OndeObservation _observation(String code, DateTime date) => OndeObservation(
  station: OndeStationCode(code),
  observedAt: date,
  category: const Assec(),
  rawFlowCode: '3',
  officialLabel: null,
  campaignCode: null,
);

/// Dépôt bouchon : compte les appels par clé pour les deux méthodes, rend
/// une valeur réglable par clé (liste vide par défaut — une absence,
/// BR-007), et peut lever à la demande pour simuler un rafraîchissement en
/// échec.
final class _DepotOndeBouchon implements OndeObservationRepository {
  final Map<(Bounds, DateTime), int> appelsBoundsParCle =
      <(Bounds, DateTime), int>{};
  final Map<(Bounds, DateTime), List<OndeObservation>> valeursBounds =
      <(Bounds, DateTime), List<OndeObservation>>{};
  final Map<(OndeStationCode, int), int> appelsStationParCle =
      <(OndeStationCode, int), int>{};
  final Map<(OndeStationCode, int), List<OndeObservation>> valeursStation =
      <(OndeStationCode, int), List<OndeObservation>>{};
  bool leve = false;
  Duration delai = Duration.zero;

  int get appelsBounds =>
      appelsBoundsParCle.values.fold(0, (int total, int n) => total + n);
  int get appelsStation =>
      appelsStationParCle.values.fold(0, (int total, int n) => total + n);

  @override
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    final (Bounds, DateTime) cle = (bounds, since);
    appelsBoundsParCle.update(cle, (int n) => n + 1, ifAbsent: () => 1);
    if (delai > Duration.zero) {
      await Future<void>.delayed(delai);
    }
    if (leve) {
      throw const FormatException('dépôt en échec');
    }
    return valeursBounds[cle] ?? <OndeObservation>[];
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final (OndeStationCode, int) cle = (station, limit);
    appelsStationParCle.update(cle, (int n) => n + 1, ifAbsent: () => 1);
    if (delai > Duration.zero) {
      await Future<void>.delayed(delai);
    }
    if (leve) {
      throw const FormatException('dépôt en échec');
    }
    return valeursStation[cle] ?? <OndeObservation>[];
  }
}

void main() {
  final Bounds bounds = Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8);
  final Bounds autreBounds = Bounds(
    west: 0.0,
    south: 46.0,
    east: 1.0,
    north: 47.0,
  );

  group('ondeTtlFor — mois courant, jamais une saison codée ailleurs', () {
    test('juillet : 30 j (en saison)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 7, 15)), ondeTtlInSeason);
    });

    test('février : 90 j (hors saison)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 2, 15)), ondeTtlOffSeason);
    });

    test('1er mai : 30 j (borne basse incluse)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 5, 1)), ondeTtlInSeason);
    });

    test('30 septembre : 30 j (borne haute incluse)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 9, 30)), ondeTtlInSeason);
    });

    test('1er octobre : 90 j (juste après la borne haute)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 10, 1)), ondeTtlOffSeason);
    });

    test('30 avril : 90 j (juste avant la borne basse)', () {
      expect(ondeTtlFor(DateTime.utc(2026, 4, 30)), ondeTtlOffSeason);
    });
  });

  group('latestWithinBounds — cache', () {
    test('cache vide : un appel, valeur rendue ; relecture même clé : zéro '
        'appel', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime since = DateTime.utc(2026, 7, 15);
      bouchon.valeursBounds[(bounds, since)] = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];
      final DateTime maintenant = DateTime.utc(2026, 7, 20);

      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(
            inner: bouchon,
            now: () => maintenant,
          );

      final List<OndeObservation> premier = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(premier, hasLength(1));
      expect(bouchon.appelsBounds, 1);

      final List<OndeObservation> second = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(second, hasLength(1));
      expect(bouchon.appelsBounds, 1);
    });

    test(
      'une liste vide mise en cache : relecture, zéro appel (BR-007)',
      () async {
        final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
        final DateTime since = DateTime.utc(2026, 7, 15);
        final DateTime maintenant = DateTime.utc(2026, 7, 20);

        final CachedOndeObservationRepository depot =
            CachedOndeObservationRepository(
              inner: bouchon,
              now: () => maintenant,
            );

        final List<OndeObservation> premier = await depot.latestWithinBounds(
          bounds,
          since: since,
        );
        expect(premier, isEmpty);
        expect(bouchon.appelsBounds, 1);

        final List<OndeObservation> second = await depot.latestWithinBounds(
          bounds,
          since: since,
        );
        expect(second, isEmpty);
        expect(bouchon.appelsBounds, 1);
      },
    );

    test('bounds différent ou since différent : entrées distinctes', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime since = DateTime.utc(2026, 7, 15);
      final DateTime autreSince = DateTime.utc(2026, 8, 1);
      final DateTime maintenant = DateTime.utc(2026, 7, 20);

      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(
            inner: bouchon,
            now: () => maintenant,
          );

      await depot.latestWithinBounds(bounds, since: since);
      await depot.latestWithinBounds(autreBounds, since: since);
      await depot.latestWithinBounds(bounds, since: autreSince);
      expect(bouchon.appelsBounds, 3);

      // Une relecture de chacune des trois clés vient du cache.
      await depot.latestWithinBounds(bounds, since: since);
      await depot.latestWithinBounds(autreBounds, since: since);
      await depot.latestWithinBounds(bounds, since: autreSince);
      expect(bouchon.appelsBounds, 3);
    });

    test('since normalisé à son jour calendaire : UTC minuit et local 10 h '
        'du même jour partagent la même entrée', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime sinceUtcMinuit = DateTime.utc(2026, 7, 15);
      final DateTime sinceLocal10h = DateTime(2026, 7, 15, 10);
      bouchon.valeursBounds[(bounds, sinceUtcMinuit)] = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];
      final DateTime maintenant = DateTime.utc(2026, 7, 20);

      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(
            inner: bouchon,
            now: () => maintenant,
          );

      await depot.latestWithinBounds(bounds, since: sinceUtcMinuit);
      expect(bouchon.appelsBounds, 1);

      final List<OndeObservation> second = await depot.latestWithinBounds(
        bounds,
        since: sinceLocal10h,
      );
      expect(second, hasLength(1));
      expect(bouchon.appelsBounds, 1);
    });

    test('périmé (31 j, en saison) : ancienne liste immédiate, '
        'rafraîchissement en tâche de fond', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime since = DateTime.utc(2026, 7, 15);
      final List<OndeObservation> ancienne = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];
      final List<OndeObservation> nouvelle = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 9, 1)),
      ];
      bouchon.valeursBounds[(bounds, since)] = ancienne;

      DateTime horloge = DateTime.utc(2026, 7, 1);
      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(inner: bouchon, now: () => horloge);

      final List<OndeObservation> premier = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(premier.single.observedAt, ancienne.single.observedAt);
      expect(bouchon.appelsBounds, 1);

      horloge = horloge.add(const Duration(days: 31));
      bouchon.valeursBounds[(bounds, since)] = nouvelle;

      final List<OndeObservation> second = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(second.single.observedAt, ancienne.single.observedAt);
      // `load` s'exécute de façon synchrone dans `refresh()`
      // (`Future.sync`, `cache_policy.dart`) : le compteur du bouchon vaut
      // déjà 2 avant tout `await` supplémentaire.
      expect(bouchon.appelsBounds, 2);

      await Future<void>.delayed(Duration.zero);

      final List<OndeObservation> troisieme = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(troisieme.single.observedAt, nouvelle.single.observedAt);
      expect(bouchon.appelsBounds, 2);
    });

    test('quatre lectures simultanées sur une entrée périmée : un seul '
        'appel (C-12)', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon()
        ..delai = const Duration(milliseconds: 10);
      final DateTime since = DateTime.utc(2026, 7, 15);
      bouchon.valeursBounds[(bounds, since)] = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];

      DateTime horloge = DateTime.utc(2026, 7, 1);
      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(inner: bouchon, now: () => horloge);

      await depot.latestWithinBounds(bounds, since: since);
      expect(bouchon.appelsBounds, 1);

      horloge = horloge.add(const Duration(days: 31));
      await Future.wait<List<OndeObservation>>(<Future<List<OndeObservation>>>[
        depot.latestWithinBounds(bounds, since: since),
        depot.latestWithinBounds(bounds, since: since),
        depot.latestWithinBounds(bounds, since: since),
        depot.latestWithinBounds(bounds, since: since),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Le premier appel (mise en cache initiale), plus un seul appel
      // dédupliqué pour les quatre lectures périmées simultanées.
      expect(bouchon.appelsBounds, 2);
    });

    test('changement de saison entre deux lectures (septembre → octobre) : '
        'la valeur en cache reste rendue, aucun appel si l âge est sous '
        '90 j', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime since = DateTime.utc(2026, 7, 15);
      bouchon.valeursBounds[(bounds, since)] = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];

      // 26 septembre : en saison, TTL 30 j.
      DateTime horloge = DateTime.utc(2026, 9, 26);
      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(inner: bouchon, now: () => horloge);

      await depot.latestWithinBounds(bounds, since: since);
      expect(bouchon.appelsBounds, 1);

      // 1er octobre : hors saison, TTL 90 j — nouvelle fermeture (clé + TTL
      // changés), mais l'entrée de cache est partagée : l'âge (5 j) reste
      // sous les 90 j, aucun appel.
      horloge = horloge.add(const Duration(days: 5));
      final List<OndeObservation> second = await depot.latestWithinBounds(
        bounds,
        since: since,
      );

      expect(second, hasLength(1));
      expect(bouchon.appelsBounds, 1);
    });

    test('un rafraîchissement en échec conserve la dernière valeur connue '
        '(BR-007)', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final DateTime since = DateTime.utc(2026, 7, 15);
      final List<OndeObservation> ancienne = <OndeObservation>[
        _observation('K4640001', DateTime.utc(2026, 8, 25)),
      ];
      bouchon.valeursBounds[(bounds, since)] = ancienne;

      DateTime horloge = DateTime.utc(2026, 7, 1);
      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(inner: bouchon, now: () => horloge);

      await depot.latestWithinBounds(bounds, since: since);
      expect(bouchon.appelsBounds, 1);

      horloge = horloge.add(const Duration(days: 31));
      bouchon.leve = true;

      final List<OndeObservation> second = await depot.latestWithinBounds(
        bounds,
        since: since,
      );
      expect(second.single.observedAt, ancienne.single.observedAt);

      await Future<void>.delayed(Duration.zero);
      expect(bouchon.appelsBounds, 2);
    });
  });

  group('historyFor — cache', () {
    test('cache vide : un appel, valeur rendue ; relecture même clé : zéro '
        'appel', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final OndeStationCode station = OndeStationCode('K4520001');
      bouchon.valeursStation[(station, 5)] = <OndeObservation>[
        _observation('K4520001', DateTime.utc(2026, 8, 25)),
      ];
      final DateTime maintenant = DateTime.utc(2026, 7, 20);

      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(
            inner: bouchon,
            now: () => maintenant,
          );

      final List<OndeObservation> premier = await depot.historyFor(
        station,
        limit: 5,
      );
      expect(premier, hasLength(1));
      expect(bouchon.appelsStation, 1);

      final List<OndeObservation> second = await depot.historyFor(
        station,
        limit: 5,
      );
      expect(second, hasLength(1));
      expect(bouchon.appelsStation, 1);
    });

    test('limit différent : entrée distincte', () async {
      final _DepotOndeBouchon bouchon = _DepotOndeBouchon();
      final OndeStationCode station = OndeStationCode('K4520001');
      final DateTime maintenant = DateTime.utc(2026, 7, 20);

      final CachedOndeObservationRepository depot =
          CachedOndeObservationRepository(
            inner: bouchon,
            now: () => maintenant,
          );

      await depot.historyFor(station, limit: 5);
      await depot.historyFor(station, limit: 10);
      expect(bouchon.appelsStation, 2);

      await depot.historyFor(station, limit: 5);
      await depot.historyFor(station, limit: 10);
      expect(bouchon.appelsStation, 2);
    });
  });
}

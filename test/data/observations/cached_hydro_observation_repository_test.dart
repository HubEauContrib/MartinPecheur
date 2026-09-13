// Ce test ne redémontre pas la politique de cache elle-même — c'est le
// rôle de `test/data/cache/cache_policy_test.dart`. Il démontre que
// `CachedHydroObservationRepository` la BRANCHE correctement : une
// fermeture par clé (station, grandeur), un TTL unique de vingt minutes
// (`docs/03-conception.md § 4.1`), `networkAvailable` transmis, et une
// absence (`null`, BR-007) mise en cache comme une valeur ordinaire.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

/// Qualification vide, réutilisée telle quelle : aucun cas de ce fichier ne
/// porte sur son contenu.
const Qualification _qualificationVide = Qualification(
  statusCode: null,
  statusLabel: null,
  qualificationCode: null,
  qualificationLabel: null,
);

HydroObservation _observationDebit(StationCode station, double valeur) {
  return HydroObservation(
    station: station,
    measuredAt: DateTime(2026, 9, 13, 8),
    grandeur: Grandeur.debit,
    discharge: CubicMetresPerSecond(valeur),
    level: null,
    qualification: _qualificationVide,
  );
}

HydroObservation _observationHauteur(StationCode station, double valeur) {
  return HydroObservation(
    station: station,
    measuredAt: DateTime(2026, 9, 13, 8),
    grandeur: Grandeur.hauteur,
    discharge: null,
    level: Metres(valeur),
    qualification: _qualificationVide,
  );
}

/// Dépôt bouchon : compte les appels par clé, rend une valeur réglable par
/// clé (`null` par défaut — une absence, BR-007), et peut lever à la
/// demande pour simuler un rafraîchissement en échec.
final class _DepotHydroBouchon implements HydroObservationRepository {
  final Map<(StationCode, Grandeur), int> appelsParCle =
      <(StationCode, Grandeur), int>{};
  final Map<(StationCode, Grandeur), HydroObservation?> valeurs =
      <(StationCode, Grandeur), HydroObservation?>{};
  bool leve = false;
  Duration delai = Duration.zero;

  int get appels =>
      appelsParCle.values.fold(0, (int total, int n) => total + n);

  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async {
    final (StationCode, Grandeur) cle = (station, grandeur);
    appelsParCle.update(cle, (int n) => n + 1, ifAbsent: () => 1);
    if (delai > Duration.zero) {
      await Future<void>.delayed(delai);
    }
    if (leve) {
      throw const FormatException('dépôt en échec');
    }
    return valeurs[cle];
  }
}

void main() {
  final DateTime maintenant = DateTime(2026, 9, 13, 12);

  test('observationsTrTtl vaut vingt minutes, comme fixé par '
      '03-conception.md § 4.1', () {
    expect(observationsTrTtl, const Duration(minutes: 20));
  });

  test("un cache vide appelle inner une fois, rend et écrit la valeur ; une "
      "seconde lecture immédiate n'appelle plus inner", () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode code = StationCode('K447001001');
    final HydroObservation attendue = _observationDebit(code, 47.8);
    bouchon.valeurs[(code, Grandeur.debit)] = attendue;

    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => maintenant);

    final HydroObservation? premier = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(premier?.discharge, attendue.discharge);
    expect(bouchon.appels, 1);

    final HydroObservation? second = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(second?.discharge, attendue.discharge);
    expect(bouchon.appels, 1);
  });

  test('un cache de dix-neuf minutes rend la valeur en cache, aucun appel '
      'supplémentaire', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode code = StationCode('K447001001');
    bouchon.valeurs[(code, Grandeur.debit)] = _observationDebit(code, 47.8);

    DateTime horloge = maintenant;
    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => horloge);

    await depot.findLatest(code, Grandeur.debit);
    expect(bouchon.appels, 1);

    horloge = horloge.add(const Duration(minutes: 19));
    final HydroObservation? second = await depot.findLatest(
      code,
      Grandeur.debit,
    );

    expect(second?.discharge, const CubicMetresPerSecond(47.8));
    expect(bouchon.appels, 1);
  });

  test('un cache d exactement vingt minutes rend l ancienne valeur '
      'immédiatement, puis se rafraîchit en tâche de fond', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode code = StationCode('K447001001');
    final (StationCode, Grandeur) cle = (code, Grandeur.debit);
    final HydroObservation ancienne = _observationDebit(code, 10);
    final HydroObservation nouvelle = _observationDebit(code, 20);
    bouchon.valeurs[cle] = ancienne;

    DateTime horloge = maintenant;
    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => horloge);

    final HydroObservation? premier = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(premier?.discharge, ancienne.discharge);
    expect(bouchon.appels, 1);

    horloge = horloge.add(const Duration(minutes: 20));
    bouchon.valeurs[cle] = nouvelle;

    final HydroObservation? second = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(second?.discharge, ancienne.discharge);
    // `Future.sync(load)` invoque `load` SYNCHRONIQUEMENT dans `refresh()`
    // (`cache_policy.dart`), lui-même appelé sans `await` juste après
    // `readCache()` dans la fermeture rendue par `withCachePolicy` : le
    // compteur du bouchon, incrémenté avant tout `await` de
    // `_DepotHydroBouchon.findLatest`, vaut donc déjà 2 au moment où
    // `depot.findLatest` ci-dessus rend sa valeur — pas seulement après un
    // tour de boucle supplémentaire (vérifié sur 200 itérations).
    expect(bouchon.appels, 2);

    await Future<void>.delayed(Duration.zero);
    expect(bouchon.appels, 2);

    final HydroObservation? troisieme = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(troisieme?.discharge, nouvelle.discharge);
    expect(bouchon.appels, 2);
  });

  test('un cache périmé sans réseau disponible rend la valeur en cache, '
      'aucun appel réseau', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode code = StationCode('K447001001');
    bouchon.valeurs[(code, Grandeur.debit)] = _observationDebit(code, 47.8);

    DateTime horloge = maintenant;
    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(
          inner: bouchon,
          now: () => horloge,
          networkAvailable: () => false,
        );

    await depot.findLatest(code, Grandeur.debit);
    expect(bouchon.appels, 1);

    horloge = horloge.add(const Duration(hours: 2));
    final HydroObservation? second = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    await Future<void>.delayed(Duration.zero);

    expect(second?.discharge, const CubicMetresPerSecond(47.8));
    expect(bouchon.appels, 1);
  });

  test('quatre lectures simultanées sur une entrée périmée ne déclenchent '
      'qu un seul appel (C-12)', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon()
      ..delai = const Duration(milliseconds: 10);
    final StationCode code = StationCode('K447001001');
    bouchon.valeurs[(code, Grandeur.debit)] = _observationDebit(code, 47.8);

    DateTime horloge = maintenant;
    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => horloge);

    await depot.findLatest(code, Grandeur.debit);
    expect(bouchon.appels, 1);

    horloge = horloge.add(const Duration(hours: 2));
    final List<HydroObservation?> resultats =
        await Future.wait<HydroObservation?>(<Future<HydroObservation?>>[
          depot.findLatest(code, Grandeur.debit),
          depot.findLatest(code, Grandeur.debit),
          depot.findLatest(code, Grandeur.debit),
          depot.findLatest(code, Grandeur.debit),
        ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    for (final HydroObservation? resultat in resultats) {
      expect(resultat?.discharge, const CubicMetresPerSecond(47.8));
    }
    // Le premier appel (mise en cache initiale), plus un seul appel
    // dédupliqué pour les quatre lectures périmées simultanées.
    expect(bouchon.appels, 2);
  });

  test(
    'un rafraîchissement en échec conserve la dernière valeur connue ; une '
    'lecture suivante avec inner réparé rend la nouvelle valeur (BR-007)',
    () async {
      final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
      final StationCode code = StationCode('K447001001');
      final (StationCode, Grandeur) cle = (code, Grandeur.debit);
      final HydroObservation ancienne = _observationDebit(code, 10);
      final HydroObservation nouvelle = _observationDebit(code, 20);
      bouchon.valeurs[cle] = ancienne;

      DateTime horloge = maintenant;
      final CachedHydroObservationRepository depot =
          CachedHydroObservationRepository(inner: bouchon, now: () => horloge);

      await depot.findLatest(code, Grandeur.debit);
      expect(bouchon.appels, 1);

      horloge = horloge.add(const Duration(hours: 2));
      bouchon.leve = true;

      final HydroObservation? second = await depot.findLatest(
        code,
        Grandeur.debit,
      );
      expect(second?.discharge, ancienne.discharge);

      await Future<void>.delayed(Duration.zero);
      expect(bouchon.appels, 2);

      bouchon.leve = false;
      bouchon.valeurs[cle] = nouvelle;

      final HydroObservation? troisieme = await depot.findLatest(
        code,
        Grandeur.debit,
      );
      expect(troisieme?.discharge, ancienne.discharge);

      await Future<void>.delayed(Duration.zero);
      expect(bouchon.appels, 3);

      final HydroObservation? quatrieme = await depot.findLatest(
        code,
        Grandeur.debit,
      );
      expect(quatrieme?.discharge, nouvelle.discharge);
      expect(bouchon.appels, 3);
    },
  );

  test('un cache vide dont inner lève laisse remonter l exception', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon()..leve = true;
    final StationCode code = StationCode('K447001001');

    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => maintenant);

    await expectLater(
      depot.findLatest(code, Grandeur.debit),
      throwsA(isA<FormatException>()),
    );
    expect(bouchon.appels, 1);
  });

  test('les clés (station, grandeur) ne partagent jamais une entrée : deux '
      'grandeurs et deux stations restent indépendantes', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode stationA = StationCode('K447001001');
    final StationCode stationB = StationCode('K447001002');

    bouchon.valeurs[(stationA, Grandeur.debit)] = _observationDebit(
      stationA,
      47.8,
    );
    bouchon.valeurs[(stationA, Grandeur.hauteur)] = _observationHauteur(
      stationA,
      1.2,
    );
    bouchon.valeurs[(stationB, Grandeur.debit)] = _observationDebit(
      stationB,
      3.4,
    );

    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => maintenant);

    final HydroObservation? debitA = await depot.findLatest(
      stationA,
      Grandeur.debit,
    );
    final HydroObservation? hauteurA = await depot.findLatest(
      stationA,
      Grandeur.hauteur,
    );
    final HydroObservation? debitB = await depot.findLatest(
      stationB,
      Grandeur.debit,
    );

    expect(debitA?.discharge, const CubicMetresPerSecond(47.8));
    expect(hauteurA?.level, const Metres(1.2));
    expect(debitB?.discharge, const CubicMetresPerSecond(3.4));
    expect(bouchon.appels, 3);

    // Une seconde lecture immédiate de chaque clé vient du cache, sans
    // appel de plus : les trois clés restent bien distinctes.
    await depot.findLatest(stationA, Grandeur.debit);
    await depot.findLatest(stationA, Grandeur.hauteur);
    await depot.findLatest(stationB, Grandeur.debit);
    expect(bouchon.appels, 3);
  });

  test('une absence (valeur null, BR-007) est mise en cache : elle n est '
      'pas redemandée avant le TTL', () async {
    final _DepotHydroBouchon bouchon = _DepotHydroBouchon();
    final StationCode code = StationCode('K447001001');

    DateTime horloge = maintenant;
    final CachedHydroObservationRepository depot =
        CachedHydroObservationRepository(inner: bouchon, now: () => horloge);

    final HydroObservation? premier = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(premier, isNull);
    expect(bouchon.appels, 1);

    horloge = horloge.add(const Duration(minutes: 19));
    final HydroObservation? second = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(second, isNull);
    expect(bouchon.appels, 1);
  });

  test('un ttl de durée nulle est refusé à la construction du dépôt', () {
    expect(
      () => CachedHydroObservationRepository(
        inner: _DepotHydroBouchon(),
        ttl: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}

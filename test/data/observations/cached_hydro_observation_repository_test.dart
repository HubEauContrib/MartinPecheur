// Ce test ne redemontre pas la politique de cache elle-meme — c'est le
// role de `test/data/cache/cache_policy_test.dart`. Il demontre que
// `CachedHydroObservationRepository` la BRANCHE correctement : une
// fermeture par cle (station, grandeur), un TTL unique de vingt minutes
// (`docs/03-conception.md § 4.1`), `networkAvailable` transmis, et une
// absence (`null`, BR-007) mise en cache comme une valeur ordinaire.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

/// Qualification vide, reutilisee telle quelle : aucun cas de ce fichier ne
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

/// Depot bouchon : compte les appels par cle, rend une valeur reglable par
/// cle (`null` par defaut — une absence, BR-007), et peut lever a la
/// demande pour simuler un rafraichissement en echec.
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
      throw const FormatException('depot en echec');
    }
    return valeurs[cle];
  }
}

void main() {
  final DateTime maintenant = DateTime(2026, 9, 13, 12);

  test('observationsTrTtl vaut vingt minutes, comme fixe par '
      '03-conception.md § 4.1', () {
    expect(observationsTrTtl, const Duration(minutes: 20));
  });

  test("un cache vide appelle inner une fois, rend et ecrit la valeur ; une "
      "seconde lecture immediate n'appelle plus inner", () async {
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
      'supplementaire', () async {
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
      'immediatement, puis se rafraichit en tache de fond', () async {
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
    // La borne appartient a l'etat perime (docs/03-conception.md § 4.1) :
    // l'ancienne valeur est rendue, peu importe qu'au moment precis de
    // cette assertion le rafraichissement synchrone (Future.sync) ait deja
    // ou non incremente le compteur — seul le comportement apres un tour
    // de boucle est verifie (meme prudence que cache_policy_test.dart).
    expect(second?.discharge, ancienne.discharge);

    await Future<void>.delayed(Duration.zero);
    expect(bouchon.appels, 2);

    final HydroObservation? troisieme = await depot.findLatest(
      code,
      Grandeur.debit,
    );
    expect(troisieme?.discharge, nouvelle.discharge);
    expect(bouchon.appels, 2);
  });

  test('un cache perime sans reseau disponible rend la valeur en cache, aucun '
      'appel reseau', () async {
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

  test('quatre lectures simultanees sur une entree perimee ne declenchent '
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
    // deduplique pour les quatre lectures perimees simultanees.
    expect(bouchon.appels, 2);
  });

  test(
    'un rafraichissement en echec conserve la derniere valeur connue ; une '
    'lecture suivante avec inner repare rend la nouvelle valeur (BR-007)',
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

  test('un cache vide dont inner leve laisse remonter l exception', () async {
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

  test('les cles (station, grandeur) ne partagent jamais une entree : deux '
      'grandeurs et deux stations restent independantes', () async {
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

    // Une seconde lecture immediate de chaque cle vient du cache, sans
    // appel de plus : les trois cles restent bien distinctes.
    await depot.findLatest(stationA, Grandeur.debit);
    await depot.findLatest(stationA, Grandeur.hauteur);
    await depot.findLatest(stationB, Grandeur.debit);
    expect(bouchon.appels, 3);
  });

  test('une absence (valeur null, BR-007) est mise en cache : elle n est pas '
      'redemandee avant le TTL', () async {
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

  test('un ttl de duree nulle est refuse a la construction du depot', () {
    expect(
      () => CachedHydroObservationRepository(
        inner: _DepotHydroBouchon(),
        ttl: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}

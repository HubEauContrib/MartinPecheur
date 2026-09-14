// Verifie que les interfaces de depots sont implementables sans
// infrastructure : les doubles ci-dessous ne dependent que du domaine.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Le point réel de la station K4520001 (D8), relevé sur la fixture
/// `test/fixtures/onde/observations_station_K4520001_2026-09-13.json`.
OndePoint _pointK4520001() => OndePoint(
  code: OndeStationCode('K4520001'),
  label: 'LA RIVIERE AUX LOCHES A CHAON',
  latitude: 47.610620493,
  longitude: 2.173858157,
  waterCourseLabel: 'ruisseau la rivière aux loches',
  departement: DepartementCode('41'),
);

/// Double en memoire de [StationRepository] : une seule methode, comme son
/// interface depuis la relecture du 2026-09-13. Verifie que le contrat est
/// implementable sans infrastructure.
final class InMemoryStationRepository implements StationRepository {
  InMemoryStationRepository(this._stations);

  final List<Station> _stations;

  @override
  Future<Station?> findByCode(StationCode code) async {
    for (final Station station in _stations) {
      if (station.code == code) {
        return station;
      }
    }
    return null;
  }
}

/// Double de [HydroObservationRepository] qui ne connait aucune observation.
final class NullHydroObservationRepository
    implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

/// Double en memoire de [OndeObservationRepository] : verifie que le
/// contrat est implementable sans infrastructure.
final class InMemoryOndeObservationRepository
    implements OndeObservationRepository {
  InMemoryOndeObservationRepository(this._observations);

  final List<OndeObservation> _observations;

  @override
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => _observations
      // since est INCLUSIF, comme date_observation_min cote API : une
      // observation datee exactement a since est retenue.
      .where((OndeObservation o) => !o.observedAt.isBefore(since))
      .toList();

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final List<OndeObservation> history =
        _observations
            .where((OndeObservation o) => o.station == station)
            .toList()
          // Le contrat promet « le plus recent en tete » : le double trie donc
          // explicitement, plutot que de rendre l'ordre d'insertion par chance.
          ..sort(
            (OndeObservation a, OndeObservation b) =>
                b.observedAt.compareTo(a.observedAt),
          );

    return history.take(limit).toList();
  }
}

/// Double en memoire de [AcknowledgementRepository] : rend telle quelle la
/// valeur stockee — le depot reste bete, il ne decide pas qu'une chaine vide
/// ne vaut pas acquittement (c'est `WarningsViewModel` qui en decide).
/// Verifie que le contrat est implementable sans infrastructure.
final class InMemoryAcknowledgementRepository
    implements AcknowledgementRepository {
  String? _storedVersion;

  @override
  Future<String?> readAcknowledgedVersion() async => _storedVersion;

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    _storedVersion = version;
  }
}

void main() {
  group('StationRepository — contrat implementable sans infrastructure', () {
    final Station blois = Station(
      code: StationCode('K447001001'),
      label: 'Blois',
      latitude: 47.5861,
      longitude: 1.3359,
      departement: DepartementCode('41'),
      riverLabel: 'La Loire',
      inService: true,
    );
    final Station goyaves = Station(
      code: StationCode('R123456001'),
      label: 'Goyaves',
      latitude: 16.25,
      longitude: -61.55,
      departement: DepartementCode('971'),
      riverLabel: 'La Goyave',
      inService: true,
    );
    final InMemoryStationRepository repository = InMemoryStationRepository(
      <Station>[blois, goyaves],
    );

    test('findByCode trouve une station existante', () async {
      final Station? found = await repository.findByCode(
        StationCode('K447001001'),
      );

      expect(found, blois);
    });

    test(
      'findByCode renvoie null pour un code absent du referentiel',
      () async {
        final Station? found = await repository.findByCode(
          StationCode('ZZZZZZZZZZ'),
        );

        expect(found, isNull);
      },
    );
  });

  group('HydroObservationRepository — contrat implementable par un double', () {
    test('un double peut rendre null pour une observation inconnue', () async {
      final NullHydroObservationRepository repository =
          NullHydroObservationRepository();

      final HydroObservation? observation = await repository.findLatest(
        StationCode('K447001001'),
        Grandeur.debit,
      );

      expect(observation, isNull);
    });

    test(
      'Grandeur porte exactement trois valeurs (hauteur, debit, inconnu)',
      () {
        expect(Grandeur.values.length, 3);
      },
    );
  });

  group(
    'OndeObservationRepository — contrat implementable sans infrastructure',
    () {
      final OndeObservation ancienne = OndeObservation(
        station: OndeStationCode('K4520001'),
        point: _pointK4520001(),
        observedAt: DateTime.utc(2026, 7, 1),
        category: const Ecoulement(),
        rawFlowCode: '1',
        officialLabel: 'Ecoulement visible',
        campaignCode: '109800',
      );
      final OndeObservation recente = OndeObservation(
        station: OndeStationCode('K4520001'),
        point: _pointK4520001(),
        observedAt: DateTime.utc(2026, 8, 25),
        category: const Assec(),
        rawFlowCode: '3',
        officialLabel: 'Assec',
        campaignCode: '109905',
      );
      final InMemoryOndeObservationRepository repository =
          InMemoryOndeObservationRepository(<OndeObservation>[
            ancienne,
            recente,
          ]);

      test('le contrat s\'implemente sans infrastructure : le double filtre '
          'since — exclut ce qui precede, inclut ce qui est date exactement '
          'a since', () async {
        final List<OndeObservation> observations = await repository
            .latestWithinBounds(
              Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
              since: DateTime.utc(2026, 8, 1),
            );

        expect(observations, hasLength(1));
        expect(observations.single.observedAt, recente.observedAt);

        final List<OndeObservation> observationsSinceExact = await repository
            .latestWithinBounds(
              Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
              since: recente.observedAt,
            );

        expect(
          observationsSinceExact,
          hasLength(1),
          reason:
              'since est INCLUSIF, comme date_observation_min cote API : '
              'une observation datee exactement a since est retenue.',
        );
      });

      test('le contrat s\'implemente sans infrastructure : le double rend '
          "l'historique le plus recent en tete", () async {
        final List<OndeObservation> observations = await repository.historyFor(
          OndeStationCode('K4520001'),
        );

        expect(observations, hasLength(2));
        expect(observations.first, same(recente));
        expect(observations.last, same(ancienne));
      });
    },
  );

  group(
    'AcknowledgementRepository — contrat implementable sans infrastructure',
    () {
      test('stockage vide : readAcknowledgedVersion rend null', () async {
        final InMemoryAcknowledgementRepository repository =
            InMemoryAcknowledgementRepository();

        expect(await repository.readAcknowledgedVersion(), isNull);
      });

      test(
        'apres writeAcknowledgedVersion, la version ecrite est relue telle '
        'quelle — y compris une chaine vide, que le depot ne juge pas',
        () async {
          final InMemoryAcknowledgementRepository repository =
              InMemoryAcknowledgementRepository();

          await repository.writeAcknowledgedVersion('2026-09-13.1');
          expect(await repository.readAcknowledgedVersion(), '2026-09-13.1');

          await repository.writeAcknowledgedVersion('');
          expect(await repository.readAcknowledgedVersion(), '');
        },
      );
    },
  );
}

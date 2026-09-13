// Verifie que les interfaces de depots sont implementables sans
// infrastructure : les doubles ci-dessous ne dependent que du domaine.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

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
      .where((OndeObservation o) => o.observedAt.isAfter(since))
      .toList();

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => _observations
      .where((OndeObservation o) => o.station == station)
      .take(limit)
      .toList();
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
        observedAt: DateTime.utc(2026, 7, 1),
        category: const Ecoulement(),
        rawFlowCode: '1',
        officialLabel: 'Ecoulement visible',
        campaignCode: '109800',
      );
      final OndeObservation recente = OndeObservation(
        station: OndeStationCode('K4520001'),
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

      test('latestWithinBounds filtre par since', () async {
        final List<OndeObservation> observations = await repository
            .latestWithinBounds(
              Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
              since: DateTime.utc(2026, 8, 1),
            );

        expect(observations, hasLength(1));
        expect(observations.single.observedAt, recente.observedAt);
      });

      test('historyFor rend les observations d\'une station', () async {
        final List<OndeObservation> observations = await repository.historyFor(
          OndeStationCode('K4520001'),
        );

        expect(observations, hasLength(2));
        expect(observations.first.observedAt, ancienne.observedAt);
        expect(observations.last.observedAt, recente.observedAt);
      });
    },
  );
}

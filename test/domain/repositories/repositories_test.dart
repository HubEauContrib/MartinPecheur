// Verifie que les interfaces de depots sont implementables sans
// infrastructure : les doubles ci-dessous ne dependent que du domaine.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
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

void main() {
  group('Bounds', () {
    test('expose ses quatre bords', () {
      final Bounds bounds = Bounds(west: -1, south: 46, east: 3, north: 48);

      expect(bounds.west, -1);
      expect(bounds.south, 46);
      expect(bounds.east, 3);
      expect(bounds.north, 48);
    });

    test('un bord est a l ouest de l ouest est refuse a la construction', () {
      expect(
        () => Bounds(west: 3, south: 46, east: -1, north: 48),
        throwsArgumentError,
      );
    });

    test('un bord nord au sud du bord sud est refuse a la construction', () {
      expect(
        () => Bounds(west: -1, south: 48, east: 3, north: 46),
        throwsArgumentError,
      );
    });
  });

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
}

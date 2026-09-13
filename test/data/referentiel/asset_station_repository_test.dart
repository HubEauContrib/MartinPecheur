// Verrouille AssetStationRepository : filtrage par emprise, par code et par
// departement sur un extrait reel du referentiel, construit directement sur
// les entites Station completes (arbitrage 2026-09-13) — plus aucune
// sentinelle, plus aucune hypothese non verifiee sur l'etat de service.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

void main() {
  late List<Station> extrait;

  setUpAll(() {
    final StationsReadResult result = parseStations(
      _readFixture('referentiel/stations_extrait_2026-09-13.json'),
    );
    extrait = result.stations;
  });

  group('findByCode — extrait reel du 2026-09-13', () {
    test('un code present rend la Station correspondante', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final Station? trouvee = await repository.findByCode(
        StationCode('K447001001'),
      );

      expect(trouvee, isNotNull);
      expect(trouvee!.code.value, 'K447001001');
      expect(trouvee.label, contains('La Loire'));
      expect(trouvee.latitude, closeTo(47.584957074, 1e-9));
      expect(trouvee.longitude, closeTo(1.335147948, 1e-9));
    });

    test('un code absent rend null — jamais une erreur (BR-007)', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final Station? absente = await repository.findByCode(
        StationCode('ZZZZZZZZZZ'),
      );

      expect(absente, isNull);
    });

    test('le departement, le cours d\'eau et l\'etat de service viennent '
        'du referentiel, jamais d\'une sentinelle', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final Station? trouvee = await repository.findByCode(
        StationCode('K447001001'),
      );

      expect(trouvee!.departement, DepartementCode('41'));
      expect(trouvee.riverLabel, 'la Loire');
      expect(trouvee.inService, isTrue);
    });
  });

  group('findWithinBounds — extrait reel du 2026-09-13', () {
    test(
      'ne rend que les stations dans une emprise resserree sur Blois',
      () async {
        final AssetStationRepository repository = AssetStationRepository(
          extrait,
        );

        final List<Station> dansEmprise = await repository.findWithinBounds(
          Bounds(west: 1, south: 47, east: 2, north: 48),
        );

        expect(dansEmprise, hasLength(1));
        expect(dansEmprise.single.code.value, 'K447001001');
      },
    );

    test('une emprise couvrant la France entiere rend toutes les stations '
        "de l'extrait", () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final List<Station> dansEmprise = await repository.findWithinBounds(
        Bounds(west: -5.5, south: 41, east: 10, north: 51.5),
      );

      // La Guadeloupe (extrait) est hors de cette emprise metropolitaine —
      // seule Blois y tombe.
      expect(dansEmprise, hasLength(1));
      expect(dansEmprise.single.code.value, 'K447001001');
    });

    test('bornes incluses, sans marge : un point exactement sur le bord '
        'nord/est est retenu', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final List<Station> dansEmprise = await repository.findWithinBounds(
        Bounds(
          west: 1,
          south: 40,
          east: 1.3351479476905552,
          north: 47.584957074484784,
        ),
      );

      expect(dansEmprise, hasLength(1));
      expect(dansEmprise.single.code.value, 'K447001001');
    });
  });

  group('findByDepartement — extrait reel du 2026-09-13', () {
    test('le departement 971 ne rend que Goyaves', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final List<Station> deGoyaves = await repository.findByDepartement(
        DepartementCode('971'),
      );

      expect(deGoyaves, hasLength(1));
      expect(deGoyaves.single.code.value, '1011000101');
    });

    test('un departement absent de l\'extrait rend une liste vide', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final List<Station> deLIsere = await repository.findByDepartement(
        DepartementCode('38'),
      );

      expect(deLIsere, isEmpty);
    });
  });
}

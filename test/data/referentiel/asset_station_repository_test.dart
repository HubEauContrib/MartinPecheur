// Verrouille AssetStationRepository : filtrage par emprise et par code sur
// un extrait reel du referentiel, l'ecart documente sur le departement
// (sentinelle, jamais une valeur plausible) et le refus explicite de
// findByDepartement — un StationPoint ne porte pas le departement, la
// methode ne doit ni fabriquer un resultat vide (confondu avec une absence
// reelle, BR-007) ni planter en silence : elle leve, documentee « T1 ».
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

void main() {
  late List<StationPoint> extrait;

  setUpAll(() {
    final StationsReadResult result = parseStations(
      _readFixture('referentiel/stations_extrait_2026-09-13.json'),
    );
    extrait = result.points;
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

    test('le departement est la sentinelle documentee, jamais une valeur '
        'plausible', () async {
      final AssetStationRepository repository = AssetStationRepository(extrait);

      final Station? trouvee = await repository.findByCode(
        StationCode('K447001001'),
      );

      expect(trouvee!.departement, sentinelDepartementInconnu);
      expect(trouvee.riverLabel, isNull);
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
  });

  group(
    'findByDepartement — non implementable sans enrichir le referentiel',
    () {
      test('leve un UnimplementedError documentant le manque (T1)', () async {
        final AssetStationRepository repository = AssetStationRepository(
          extrait,
        );

        expect(
          () => repository.findByDepartement(DepartementCode('41')),
          throwsA(
            isA<UnimplementedError>().having(
              (UnimplementedError e) => e.message,
              'message',
              contains('T1'),
            ),
          ),
        );
      });
    },
  );
}

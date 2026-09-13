// Verrouille AssetStationRepository : la recherche par code sur un extrait
// reel du referentiel, construite directement sur les entites Station
// completes (arbitrage 2026-09-13) — plus aucune sentinelle, plus aucune
// hypothese non verifiee sur l'etat de service.
//
// Plus de cas d'emprise ici depuis la relecture du 2026-09-13 :
// `findWithinBounds` a ete retiree faute d'appelant, et l'inclusion d'une
// emprise est verifiee une seule fois, la ou elle est calculee
// (`test/domain/geo/viewport_filter_test.dart`, puis
// `test/data/referentiel/asset_station_point_repository_test.dart`). La
// recopier ici en aurait fait une seconde definition de la meme regle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
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
}

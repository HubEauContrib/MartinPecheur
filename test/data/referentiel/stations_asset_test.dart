// Verrouille l'analyse du referentiel : l'ordre GeoJSON [longitude,
// latitude], le comptage des entites ecartees (BR-007), et les 4 150 points
// du referentiel reel. Un test lit l'asset entier — lent, normal ; toute
// entite ecartee doit etre expliquee avant de passer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/station/station.dart';

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

Map<String, dynamic> _featureWith({
  Object? geometry = const <String, dynamic>{
    'type': 'Point',
    'coordinates': <double>[1.335147948, 47.584957074],
  },
  String? codeStation = 'K447001001',
  Object? codeDepartement = '41',
  Object? enService = true,
  Object? libelleCoursEau = 'la Loire',
}) => <String, dynamic>{
  'type': 'Feature',
  'properties': <String, dynamic>{
    'code_station': codeStation,
    'libelle_station': 'La Loire à Blois',
    'code_departement': codeDepartement,
    'en_service': enService,
    'libelle_cours_eau': libelleCoursEau,
  },
  'geometry': geometry,
};

String _collectionOf(List<Map<String, dynamic>> features) => jsonEncode(
  <String, dynamic>{'type': 'FeatureCollection', 'features': features},
);

void main() {
  group('parseStations — extrait reel du 2026-09-13', () {
    late StationsReadResult result;

    setUpAll(() {
      result = parseStations(
        _readFixture('referentiel/stations_extrait_2026-09-13.json'),
      );
    });

    test("les deux stations de l'extrait sont lues, aucune ecartee", () {
      expect(result.points, hasLength(2));
      expect(result.skipped, 0);
    });

    test('les coordonnees sont lues dans l\'ordre GeoJSON — coordinates[0] '
        'est la longitude', () {
      final StationPoint guadeloupe = result.points.first;
      expect(guadeloupe.longitude, closeTo(-61.658989, 1e-5));
      expect(guadeloupe.latitude, closeTo(16.189402, 1e-5));
    });

    test('le code et le libelle sont lus', () {
      final StationPoint guadeloupe = result.points.first;
      expect(guadeloupe.code.value, '1011000101');
      expect(guadeloupe.label, contains('Grande Rivière'));
    });

    test("l'ordre du fichier est preserve", () {
      expect(
        result.points.map((StationPoint p) => p.code.value).toList(),
        <String>['1011000101', 'K447001001'],
      );
    });

    test('les deux entites Station sont completes, aucune ecartee', () {
      expect(result.stations, hasLength(2));
      expect(result.stationsSkipped, 0);
    });

    test('Blois porte le departement, le cours d\'eau et l\'etat de '
        'service du referentiel', () {
      final Station blois = result.stations.firstWhere(
        (Station s) => s.code.value == 'K447001001',
      );

      expect(blois.departement.value, '41');
      expect(blois.riverLabel, 'la Loire');
      expect(blois.inService, isTrue);
    });

    test('Goyaves (DOM) porte le departement 971 et son cours d\'eau', () {
      final Station goyaves = result.stations.firstWhere(
        (Station s) => s.code.value == '1011000101',
      );

      expect(goyaves.departement.value, '971');
      expect(goyaves.riverLabel, 'Grande Rivière à Goyaves');
      expect(goyaves.inService, isTrue);
    });
  });

  group('parseStations — entites Station ecartees, comptees (BR-007)', () {
    test('code_departement absent : le point reste valide, l\'entite est '
        'ecartee sans sentinelle', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(codeDepartement: null),
        ]),
      );

      expect(result.points, hasLength(1));
      expect(result.skipped, 0);
      expect(result.stations, isEmpty);
      expect(result.stationsSkipped, 1);
    });

    test('en_service absent : l\'entite est ecartee', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[_featureWith(enService: null)]),
      );

      expect(result.stations, isEmpty);
      expect(result.stationsSkipped, 1);
    });

    test('en_service non booleen : l\'entite est ecartee', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[_featureWith(enService: 'oui')]),
      );

      expect(result.stations, isEmpty);
      expect(result.stationsSkipped, 1);
    });

    test('libelle_cours_eau absent : riverLabel est null, l\'entite n\'est '
        'pas ecartee pour autant', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(libelleCoursEau: null),
        ]),
      );

      expect(result.stations, hasLength(1));
      expect(result.stationsSkipped, 0);
      expect(result.stations.single.riverLabel, isNull);
    });

    test('libelle_cours_eau vide : riverLabel est null, jamais une chaine '
        'vide (BR-007)', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(libelleCoursEau: ''),
        ]),
      );

      expect(result.stations.single.riverLabel, isNull);
    });
  });

  group('parseStations — entites ecartees, comptees (BR-007)', () {
    test('geometry: null est ecartee', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[_featureWith(geometry: null)]),
      );

      expect(result.points, isEmpty);
      expect(result.skipped, 1);
    });

    test('coordinates incompletes ([1.0]) sont ecartees', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(
            geometry: <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[1.0],
            },
          ),
        ]),
      );

      expect(result.points, isEmpty);
      expect(result.skipped, 1);
    });

    test("code_station 'K4470010' (code site, huit caracteres) est ecarte "
        '(C-05)', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(codeStation: 'K4470010'),
        ]),
      );

      expect(result.points, isEmpty);
      expect(result.skipped, 1);
    });

    test('features vide : aucun point, aucune entite ecartee', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[]),
      );

      expect(result.points, isEmpty);
      expect(result.skipped, 0);
    });
  });

  group('parseStations — entree illisible', () {
    test("un tableau JSON ('[]') leve une FormatException — ce n'est pas un "
        'objet FeatureCollection', () {
      expect(() => parseStations('[]'), throwsA(isA<FormatException>()));
    });

    test("une chaine qui n'est pas du JSON leve une FormatException", () {
      expect(
        () => parseStations('pas du json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Configuration', () {
    test("pubspec.yaml declare l'asset du referentiel", () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/referentiel/stations.json'));
    });
  });

  group('parseStations — asset reel (test lent)', () {
    test('les 4 150 stations du referentiel sont lues comme points, aucune '
        'ecartee', () {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();

      final StationsReadResult result = parseStations(jsonText);

      expect(result.points, hasLength(4150));
      expect(result.skipped, 0);
    });

    // Fait constate le 2026-09-13 sur assets/referentiel/stations.json : 37
    // entites n'ont pas de `code_departement` — des stations hors de France
    // (Rhin en Allemagne/Suisse, Meuse/Semois/Escaut en Belgique...) plus
    // deux stations corses (Y880000101, Y971000201). Ce n'est pas un bug de
    // parsing : le referentiel Hub'Eau porte des stations transfrontalieres
    // sans departement francais. Elles restent dans `points` (la carte les
    // affiche) mais sont ecartees de `stations` plutot que de recevoir un
    // departement invente (BR-007).
    test('4 113 entites Station completes, 37 ecartees pour departement '
        'absent — un fait sur le referentiel, pas un bug', () {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();

      final StationsReadResult result = parseStations(jsonText);

      expect(result.stations, hasLength(4113));
      expect(result.stationsSkipped, 37);
    });
  });
}

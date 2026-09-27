// Verrouille l'analyse du referentiel : l'ordre GeoJSON [longitude,
// latitude], le comptage des entites ecartees (BR-007), et les 4 150 points
// du referentiel reel. Un test lit l'asset entier — lent, normal ; toute
// entite ecartee doit etre expliquee avant de passer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

Map<String, dynamic> _featureWith({
  Object? geometry = const <String, dynamic>{
    'type': 'Point',
    'coordinates': <double>[1.335147948, 47.584957074],
  },
  String? codeStation = 'K447001001',
  Object? codeDepartement = '41',
  Object? codeRegion,
  Object? enService = true,
  Object? libelleCoursEau = 'la Loire',
  Object? codeProjection,
  Object? coordonneeXStation,
  Object? coordonneeYStation,
}) => <String, dynamic>{
  'type': 'Feature',
  'properties': <String, dynamic>{
    'code_station': codeStation,
    'libelle_station': 'La Loire à Blois',
    'code_departement': codeDepartement,
    'code_region': codeRegion,
    'en_service': enService,
    'libelle_cours_eau': libelleCoursEau,
    'code_projection': codeProjection,
    'coordonnee_x_station': coordonneeXStation,
    'coordonnee_y_station': coordonneeYStation,
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

    // ADR-015 : l'extrait ne porte ni code_region ni libelle_departement —
    // region est donc null et le libelle du departement replie sur son code
    // (BR-007), comme libelle_station le fait deja.
    test('Blois (StationPoint) : region null (champ absent), departement '
        'code 41 et libelle replie sur le code (libelle absent)', () {
      final StationPoint blois = result.points.firstWhere(
        (StationPoint p) => p.code.value == 'K447001001',
      );

      expect(blois.region, isNull);
      expect(
        blois.departement,
        const AdministrativeArea(code: '41', label: '41'),
      );
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

  group('parseStations — region/departement mal formes (ADR-015), jamais un '
      'point ecarte pour autant (BR-007)', () {
    test('code_region entier (76, pas une chaine) : region null, le point '
        "n'est ni ecarte ni modifie ailleurs", () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[_featureWith(codeRegion: 76)]),
      );

      expect(result.points, hasLength(1));
      expect(result.skipped, 0);
      expect(result.points.single.region, isNull);
      // Le departement, lui, est toujours valide (41) : le defaut de region
      // ne rejaillit pas sur le departement, chacun est analyse a part.
      expect(
        result.points.single.departement,
        const AdministrativeArea(code: '41', label: '41'),
      );
    });

    test("code_departement mal forme ('XYZ') : departement null au niveau "
        "du StationPoint, le point n'est pas ecarte (a la difference de "
        'Station, qui refuse toujours ce departement)', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(codeDepartement: 'XYZ'),
        ]),
      );

      expect(result.points, hasLength(1));
      expect(result.skipped, 0);
      expect(result.points.single.departement, isNull);
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

    // ADR-015 (2026-09-22) : les mêmes 37 entités sans code_departement sont
    // aussi celles sans code_region — le rattachement administratif de la
    // carte suit exactement le même partage que celui de Station.
    test('4 113 StationPoint avec region et departement non nuls, 37 avec '
        'les deux nuls — le même partage que Station/stationsSkipped', () {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();

      final StationsReadResult result = parseStations(jsonText);

      final int avecLesDeux = result.points
          .where((StationPoint p) => p.region != null && p.departement != null)
          .length;
      final int sansAucune = result.points
          .where((StationPoint p) => p.region == null && p.departement == null)
          .length;

      expect(avecLesDeux, 4113);
      expect(sansAucune, 37);
      expect(avecLesDeux + sansAucune, result.points.length);
    });

    // C-18 (2026-09-23) : 54 stations métropolitaines ont `code_projection
    // 31` — pour elles, `latitude_station`/`longitude_station` (et
    // `geometry.coordinates`, qui les recopie) sont INVERSÉES.
    // `coordonnee_x_station`/`coordonnee_y_station` sont justes. Vérifié par
    // appel réel le 2026-09-23 à 12:38:59 UTC :
    // https://hubeau.eaufrance.fr/api/v2/hydrometrie/referentiel/stations
    // ?code_station=H000000201,H004000101&fields=code_station,
    // latitude_station,longitude_station,coordonnee_x_station,
    // coordonnee_y_station,code_projection,code_departement&format=json
    // → HTTP 200, api_version 2.0.1 : pour les deux, code_projection 31,
    // latitude_station/longitude_station inversées, coordonnee_x/y_station
    // justes (H000000201 : x 4.099322, y 49.989435, dép. 59 ; H004000101 :
    // x 3.6304581, y 49.8976718, dép. 02).
    test('H000000201 (code_projection 31) : latitude lue depuis '
        'coordonnee_y_station, longitude depuis coordonnee_x_station', () {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();
      final StationsReadResult result = parseStations(jsonText);

      final StationPoint anor = result.points.firstWhere(
        (StationPoint p) => p.code.value == 'H000000201',
      );

      expect(anor.latitude, closeTo(49.989435, 1e-6));
      expect(anor.longitude, closeTo(4.099322, 1e-6));
    });

    // `J543211003` (dép. 56, projection 26) N'est PAS une inversion : point
    // ouvert, listé nommément, jamais corrigé ni inventé (consigne du
    // commanditaire, 2026-09-23).
    test("aucun StationPoint d'une région métropolitaine (codes hors 01, "
        '02, 03, 04, 06 — DOM) n\'a une position hors de la France '
        "métropolitaine (latitude hors [41 ; 51.5] ou longitude hors "
        "[-5.5 ; 10]), sauf J543211003 (point ouvert, non traité)", () {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();
      final StationsReadResult result = parseStations(jsonText);

      const Set<String> codesRegionsDom = <String>{
        '01',
        '02',
        '03',
        '04',
        '06',
      };
      const String pointOuvert = 'J543211003';

      final List<StationPoint> horsEmprise = result.points.where((
        StationPoint p,
      ) {
        if (p.code.value == pointOuvert) {
          return false;
        }
        final AdministrativeArea? region = p.region;
        if (region == null || codesRegionsDom.contains(region.code)) {
          return false;
        }
        return p.latitude < 41 ||
            p.latitude > 51.5 ||
            p.longitude < -5.5 ||
            p.longitude > 10;
      }).toList();

      expect(
        horsEmprise.map((StationPoint p) => p.code.value).toList(),
        isEmpty,
      );
    });
  });

  group('parseStations — code_projection 31 (C-18), position lue depuis '
      'coordonnee_x/y_station', () {
    test('projection 31 avec X/Y numériques : longitude = X, latitude = Y, '
        'pas geometry.coordinates', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(
            // geometry porte les valeurs INVERSEES, comme sur l'asset reel.
            geometry: <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[49.989435, 4.099322],
            },
            codeProjection: 31,
            coordonneeXStation: 4.099322,
            coordonneeYStation: 49.989435,
          ),
        ]),
      );

      final StationPoint point = result.points.single;
      expect(point.longitude, closeTo(4.099322, 1e-6));
      expect(point.latitude, closeTo(49.989435, 1e-6));
    });

    test('projection 26 : geometry.coordinates lue meme si X/Y presents '
        '(seule la projection 31 est concernee)', () {
      final StationsReadResult result = parseStations(
        _collectionOf(<Map<String, dynamic>>[
          _featureWith(
            geometry: const <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[3.6304581, 49.8976718],
            },
            codeProjection: 26,
            coordonneeXStation: 499629.0,
            coordonneeYStation: 5330897.0,
          ),
        ]),
      );

      final StationPoint point = result.points.single;
      expect(point.longitude, closeTo(3.6304581, 1e-6));
      expect(point.latitude, closeTo(49.8976718, 1e-6));
    });

    test(
      'projection 31 sans X/Y numeriques : repli sur geometry.coordinates',
      () {
        final StationsReadResult result = parseStations(
          _collectionOf(<Map<String, dynamic>>[
            _featureWith(
              geometry: const <String, dynamic>{
                'type': 'Point',
                'coordinates': <double>[1.335147948, 47.584957074],
              },
              codeProjection: 31,
              coordonneeXStation: null,
              coordonneeYStation: null,
            ),
          ]),
        );

        final StationPoint point = result.points.single;
        expect(point.longitude, closeTo(1.335147948, 1e-6));
        expect(point.latitude, closeTo(47.584957074, 1e-6));
      },
    );
  });
}

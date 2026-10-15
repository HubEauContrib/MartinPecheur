// Verrouille `mapFloodVigilance` et `floodLevelFromWire`, seul point de
// conversion du GeoJSON national de Vigicrues vers le domaine (W1 de T4,
// cadrage § 6).
//
// Les cas partent de la fixture REELLE
// `test/fixtures/vigicrues/infovigicru_extrait_territoire_8_2026-10-14.geojson`
// (extrait declare, `VC-03`). Aucune fixture n'est fabriquee : les cas
// illisibles, les entites cassees et les niveaux 2 a 4 sont des VARIANTES EN
// MEMOIRE de la fixture, un seul champ modifie a la fois. Les niveaux 2 a 4
// n'ont jamais ete publies le 2026-10-14 : chaque cas qui les emploie est
// nomme « cas construit, niveau jamais observe en production — VC-04 ».
//
// Tout ou rien a la racine, a `features` et a la date ; entite par entite
// ensuite : une entite cassee est ecartee et comptee, les autres restent.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/floods/flood_vigilance_mapper.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

const String _fixturePath =
    'test/fixtures/vigicrues/'
    'infovigicru_extrait_territoire_8_2026-10-14.geojson';

/// La fixture decodee — une nouvelle copie a chaque appel : une variante
/// modifiee ne contamine pas le cas suivant.
Map<String, dynamic> _fixture() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<dynamic> _features(Map<String, dynamic> root) =>
    root['features'] as List<dynamic>;

/// L'entite de code [code] dans [root].
Map<String, dynamic> _entity(Map<String, dynamic> root, String code) =>
    _features(root).cast<Map<String, dynamic>>().firstWhere(
      (Map<String, dynamic> f) =>
          (f['properties'] as Map<String, dynamic>)['CdEntCru'] == code,
    );

Map<String, dynamic> _properties(Map<String, dynamic> entity) =>
    entity['properties'] as Map<String, dynamic>;

Map<String, dynamic> _geometry(Map<String, dynamic> entity) =>
    entity['geometry'] as Map<String, dynamic>;

/// Les deux premiers points de la premiere ligne de [entity], lus dans la
/// fixture : une ligne valide de deux points.
List<dynamic> _twoFixturePoints(Map<String, dynamic> entity) {
  final List<dynamic> lines = _geometry(entity)['coordinates'] as List<dynamic>;
  final List<dynamic> first = lines.first as List<dynamic>;
  return <dynamic>[first[0], first[1]];
}

/// Variante de la fixture : [mutate] recoit l'entite `BT5` et la modifie ;
/// les quatorze autres restent celles de la fixture.
FloodVigilanceMap _mapBt5Variant(void Function(Map<String, dynamic>) mutate) {
  final Map<String, dynamic> root = _fixture();
  mutate(_entity(root, 'BT5'));
  return mapFloodVigilance(root);
}

/// Variante de la fixture dont la date de l'information vaut [date].
Map<String, dynamic> _withDate(Object? date) =>
    _fixture()..['DtHrInfoVigiCru'] = date;

Set<String> _codes(FloodVigilanceMap map) => <String>{
  for (final FloodSection section in map.sections) section.code.value,
};

FloodSection _bt5(FloodVigilanceMap map) =>
    map.sectionByCode(FloodSectionCode('BT5'))!;

Matcher get _illisible => throwsA(isA<VigilanceIllisible>());

/// Niveau inconnu portant exactement [raw] — valeur ET type : `2.0` n'est
/// pas `2` ici, meme si `2.0 == 2` vaut vrai en Dart.
Matcher _unknownWithRaw(Object? raw) => isA<NiveauCruesInconnu>()
    .having((NiveauCruesInconnu l) => l.raw, 'raw', raw)
    .having(
      (NiveauCruesInconnu l) => l.raw.runtimeType,
      'raw.runtimeType',
      raw.runtimeType,
    );

void main() {
  group('mapFloodVigilance — fixture reelle (VC-03 a VC-05)', () {
    test('15 troncons, aucun ecarte, tous Vert, date de l information en '
        'UTC', () {
      final FloodVigilanceMap map = mapFloodVigilance(_fixture());

      expect(map.sections, hasLength(15));
      expect(map.skippedEntities, 0);
      expect(map.informationDate, DateTime.utc(2026, 10, 14, 13, 55, 31));
      expect(map.informationDate.isUtc, isTrue);
      for (final FloodSection section in map.sections) {
        expect(section.level, const Vert(), reason: section.code.value);
      }
    });

    test('le troncon BT5 s appelle Blavet, territoire 8', () {
      final FloodSection bt5 = _bt5(mapFloodVigilance(_fixture()));

      expect(bt5.name, 'Blavet');
      expect(bt5.territoryCode, '8');
    });

    test('[longitude, latitude] devient GeoPoint(latitude:, longitude:) : la '
        'latitude du premier point est la SECONDE coordonnee de la '
        'fixture', () {
      final Map<String, dynamic> raw = _fixture();
      final List<dynamic> rawFirstPoint =
          _twoFixturePoints(_entity(raw, 'BT5')).first as List<dynamic>;

      final GeoPoint first = _bt5(mapFloodVigilance(raw)).lines.first.first;

      expect(first.latitude, (rawFirstPoint[1] as num).toDouble());
      expect(first.longitude, (rawFirstPoint[0] as num).toDouble());
      expect(first.latitude, isNot(first.longitude));
    });

    test('chaque ligne garde tous ses points, dans l ordre de la fixture', () {
      final Map<String, dynamic> raw = _fixture();
      final List<dynamic> rawLines =
          _geometry(_entity(raw, 'BT5'))['coordinates'] as List<dynamic>;

      final FloodSection bt5 = _bt5(mapFloodVigilance(raw));

      expect(bt5.lines, hasLength(rawLines.length));
      for (int i = 0; i < rawLines.length; i++) {
        final List<dynamic> rawLine = rawLines[i] as List<dynamic>;
        expect(bt5.lines[i], hasLength(rawLine.length));
        final List<dynamic> rawLast = rawLine.last as List<dynamic>;
        expect(bt5.lines[i].last.latitude, (rawLast[1] as num).toDouble());
        expect(bt5.lines[i].last.longitude, (rawLast[0] as num).toDouble());
      }
    });
  });

  group('floodLevelFromWire — nomenclature Sandre 837 (VC-04, BR-011)', () {
    test('1 est Vert', () {
      expect(floodLevelFromWire(1), const Vert());
    });

    test('2 est Jaune (cas construit, niveau jamais observe en production — '
        'VC-04)', () {
      expect(floodLevelFromWire(2), const Jaune());
    });

    test('3 est Orange (cas construit, niveau jamais observe en production — '
        'VC-04)', () {
      expect(floodLevelFromWire(3), const Orange());
    });

    test('4 est Rouge (cas construit, niveau jamais observe en production — '
        'VC-04)', () {
      expect(floodLevelFromWire(4), const Rouge());
    });

    for (final Object? raw in <Object?>[0, 5, 2.0, '2', null, true]) {
      test('${raw is String ? "'$raw'" : raw} (${raw.runtimeType}) est un '
          'niveau inconnu qui porte la valeur brute', () {
        expect(floodLevelFromWire(raw), _unknownWithRaw(raw));
      });
    }
  });

  group('mapFloodVigilance — racine illisible, tout ou rien', () {
    test('null', () {
      expect(() => mapFloodVigilance(null), _illisible);
    });

    test('un tableau vide', () {
      expect(() => mapFloodVigilance(<Object?>[]), _illisible);
    });

    test('une chaine', () {
      expect(() => mapFloodVigilance('x'), _illisible);
    });

    test('un objet de type Feature', () {
      expect(
        () => mapFloodVigilance(<String, Object?>{'type': 'Feature'}),
        _illisible,
      );
    });

    test('type Feature, le reste de la fixture intact', () {
      expect(
        () => mapFloodVigilance(_fixture()..['type'] = 'Feature'),
        _illisible,
      );
    });

    test('features absent', () {
      expect(
        () => mapFloodVigilance(_fixture()..remove('features')),
        _illisible,
      );
    });

    test('features est un objet', () {
      expect(
        () => mapFloodVigilance(_fixture()..['features'] = <String, Object?>{}),
        _illisible,
      );
    });
  });

  group('mapFloodVigilance — date de l information (BR-001, Review '
      'Focus 3)', () {
    test('absente : illisible', () {
      expect(
        () => mapFloodVigilance(_fixture()..remove('DtHrInfoVigiCru')),
        _illisible,
      );
    });

    test('un nombre (42) : illisible', () {
      expect(() => mapFloodVigilance(_withDate(42)), _illisible);
    });

    test("'pas une date' : illisible", () {
      expect(() => mapFloodVigilance(_withDate('pas une date')), _illisible);
    });

    test("'2026-10-14T13:55:31', SANS fuseau explicite : illisible — jamais "
        'lue en heure locale', () {
      expect(
        () => mapFloodVigilance(_withDate('2026-10-14T13:55:31')),
        _illisible,
      );
    });

    test("'…Z' et '…+02:00' donnent le meme instant UTC", () {
      final FloodVigilanceMap zulu = mapFloodVigilance(
        _withDate('2026-10-14T13:55:31Z'),
      );
      final FloodVigilanceMap paris = mapFloodVigilance(
        _withDate('2026-10-14T15:55:31+02:00'),
      );

      expect(zulu.informationDate, DateTime.utc(2026, 10, 14, 13, 55, 31));
      expect(paris.informationDate, DateTime.utc(2026, 10, 14, 13, 55, 31));
      expect(zulu.informationDate.isUtc, isTrue);
      expect(paris.informationDate.isUtc, isTrue);
    });
  });

  group('mapFloodVigilance — entite ecartee et comptee, les autres '
      'gardees', () {
    final Map<String, void Function(Map<String, dynamic>)> cases =
        <String, void Function(Map<String, dynamic>)>{
          'sans code': (Map<String, dynamic> e) =>
              _properties(e).remove('CdEntCru'),
          'code vide': (Map<String, dynamic> e) =>
              _properties(e)['CdEntCru'] = '',
          'code nombre': (Map<String, dynamic> e) =>
              _properties(e)['CdEntCru'] = 5,
          'sans nom': (Map<String, dynamic> e) =>
              _properties(e).remove('lbentcru'),
          'sans territoire': (Map<String, dynamic> e) =>
              _properties(e).remove('cdensup_1'),
          'geometry Point': (Map<String, dynamic> e) =>
              _geometry(e)['type'] = 'Point',
          'geometry LineString (jamais observe, VC-03)': (
            Map<String, dynamic> e,
          ) => _geometry(e)['type'] = 'LineString',
          'coordinates absent': (Map<String, dynamic> e) =>
              _geometry(e).remove('coordinates'),
        };

    for (final MapEntry<String, void Function(Map<String, dynamic>)> entry
        in cases.entries) {
      test(entry.key, () {
        final FloodVigilanceMap map = _mapBt5Variant(entry.value);

        expect(map.skippedEntities, 1);
        expect(map.sections, hasLength(14));
        expect(_codes(map), isNot(contains('BT5')));
        expect(map.informationDate, DateTime.utc(2026, 10, 14, 13, 55, 31));
      });
    }

    test('une entite qui n est pas un objet', () {
      final Map<String, dynamic> root = _fixture();
      _features(root)[0] = 'x';

      final FloodVigilanceMap map = mapFloodVigilance(root);

      expect(map.skippedEntities, 1);
      expect(map.sections, hasLength(14));
    });

    test('properties qui n est pas un objet', () {
      final FloodVigilanceMap map = _mapBt5Variant(
        (Map<String, dynamic> e) => e['properties'] = <Object?>[],
      );

      expect(map.skippedEntities, 1);
      expect(_codes(map), isNot(contains('BT5')));
    });

    test('deux entites cassees : skippedEntities == 2', () {
      final Map<String, dynamic> root = _fixture();
      _properties(_entity(root, 'BT5')).remove('CdEntCru');
      _geometry(_entity(root, 'BT6'))['type'] = 'LineString';

      final FloodVigilanceMap map = mapFloodVigilance(root);

      expect(map.skippedEntities, 2);
      expect(map.sections, hasLength(13));
      expect(_codes(map), isNot(contains('BT6')));
    });
  });

  group('mapFloodVigilance — lignes retirees une a une', () {
    test('une ligne d un seul point est retiree, l autre gardee : l entite '
        'reste', () {
      late List<dynamic> valid;
      final FloodVigilanceMap map = _mapBt5Variant((Map<String, dynamic> e) {
        valid = _twoFixturePoints(e);
        _geometry(e)['coordinates'] = <dynamic>[
          <dynamic>[valid.first],
          valid,
        ];
      });

      expect(map.skippedEntities, 0);
      final FloodSection bt5 = _bt5(map);
      expect(bt5.lines, hasLength(1));
      expect(bt5.lines.single, hasLength(2));
      expect(
        bt5.lines.single.first.latitude,
        ((valid.first as List<dynamic>)[1] as num).toDouble(),
      );
    });

    test('toutes les lignes invalides : l entite est ecartee', () {
      final FloodVigilanceMap map = _mapBt5Variant((Map<String, dynamic> e) {
        final List<dynamic> valid = _twoFixturePoints(e);
        _geometry(e)['coordinates'] = <dynamic>[
          <dynamic>[valid.first],
          <dynamic>[
            <dynamic>['x', 48.0],
            valid.last,
          ],
        ];
      });

      expect(map.skippedEntities, 1);
      expect(_codes(map), isNot(contains('BT5')));
    });

    test('une latitude de 95 retire la ligne, sans ArgumentError', () {
      final FloodVigilanceMap map = _mapBt5Variant((Map<String, dynamic> e) {
        final List<dynamic> valid = _twoFixturePoints(e);
        final num longitude = (valid.first as List<dynamic>)[0] as num;
        _geometry(e)['coordinates'] = <dynamic>[
          <dynamic>[
            <dynamic>[longitude, 95],
            valid.last,
          ],
          valid,
        ];
      });

      expect(map.skippedEntities, 0);
      expect(_bt5(map).lines, hasLength(1));
    });
  });

  group('mapFloodVigilance — niveau de l entite', () {
    test('NivInfViCr: 3 est Orange (cas construit, niveau jamais observe en '
        'production — VC-04)', () {
      final FloodVigilanceMap map = _mapBt5Variant(
        (Map<String, dynamic> e) => _properties(e)['NivInfViCr'] = 3,
      );

      expect(_bt5(map).level, const Orange());
    });

    test('NivInfViCr absent : NiveauCruesInconnu(null), l entite n est PAS '
        'ecartee', () {
      final FloodVigilanceMap map = _mapBt5Variant(
        (Map<String, dynamic> e) => _properties(e).remove('NivInfViCr'),
      );

      expect(map.skippedEntities, 0);
      expect(map.sections, hasLength(15));
      expect(_bt5(map).level, _unknownWithRaw(null));
    });
  });

  group('mapFloodVigilance — champs inconnus ignores (BR-011)', () {
    test('un champ ajoute a la racine et a une entite : aucun effet', () {
      final FloodVigilanceMap reference = mapFloodVigilance(_fixture());

      final Map<String, dynamic> root = _fixture()..['champInedit'] = 42;
      _properties(_entity(root, 'BT5'))['champInedit'] = <String, Object?>{};
      _entity(root, 'BT5')['champInedit'] = 'x';
      final FloodVigilanceMap map = mapFloodVigilance(root);

      expect(map.informationDate, reference.informationDate);
      expect(map.skippedEntities, reference.skippedEntities);
      expect(_codes(map), _codes(reference));
      expect(_bt5(map).name, _bt5(reference).name);
      expect(_bt5(map).lines, _bt5(reference).lines);
    });
  });
}

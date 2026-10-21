// Verrouille la forme stockée des favoris (S2 de T3) : une chaîne JSON
// `{ version, favoris }`. Deux échelles d'illisible : l'entrée devient un
// `UnreadableFavorite`, gardé à sa place et réécrit tel quel ; la valeur
// lève `ListeDeFavorisIllisible` et ne rend jamais une liste vide. Le code
// ONDE s'écrit verbatim, espaces compris.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/preferences/favorites_codec.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

const String _ondeEntry =
    '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
    '{"code":" O968 5312 ","libelle":"LA BONNEURE A MILLANCAY",'
    '"latitude":47.444182169,"longitude":1.78116675,'
    '"cours_d_eau":"la Bonne Heure",'
    '"departement":{"code":"41","libelle":"41"},"region":null}}';

const String _stationEntry =
    '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
    '"code":"K447001001","libelle":"La Loire à Blois"}';

const String _designatedEntry =
    '{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z",'
    '"libelle":"Chez moi","latitude":46.2,"longitude":5.2}';

/// La valeur stockée portant [entries], en version 1.
String _value(List<String> entries) =>
    '{"version":1,"favoris":[${entries.join(',')}]}';

/// L'exemple entier du plan : un point ONDE, une station, un type inconnu.
final String _example = _value(<String>[
  _ondeEntry,
  _stationEntry,
  _designatedEntry,
]);

OndePoint _ondePoint({
  String code = 'K4640001',
  String? waterCourseLabel = 'la Bonne Heure',
  AdministrativeArea? departement = const AdministrativeArea(
    code: '41',
    label: '41',
  ),
  AdministrativeArea? region,
}) => OndePoint(
  code: OndeStationCode(code),
  label: 'LA BONNEURE A MILLANCAY',
  latitude: 47.444182169,
  longitude: 1.78116675,
  waterCourseLabel: waterCourseLabel,
  departement: departement,
  region: region,
);

OndePointFavorite _ondeFavorite({
  String code = 'K4640001',
  String? waterCourseLabel = 'la Bonne Heure',
  AdministrativeArea? departement = const AdministrativeArea(
    code: '41',
    label: '41',
  ),
  AdministrativeArea? region,
}) => OndePointFavorite(
  point: _ondePoint(
    code: code,
    waterCourseLabel: waterCourseLabel,
    departement: departement,
    region: region,
  ),
  addedAt: DateTime.utc(2026, 10, 12, 8, 30),
);

StationFavorite _stationFavorite() => StationFavorite(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  addedAt: DateTime.utc(2026, 10, 11, 17, 5),
);

/// L'unique favori d'une valeur à une seule entrée [entry].
Favorite _single(String entry) {
  final List<Favorite> favorites = decodeFavorites(_value(<String>[entry]));
  expect(favorites, hasLength(1));
  return favorites.single;
}

void main() {
  test('la version de la forme stockée est 1', () {
    expect(favoritesFormatVersion, 1);
  });

  group('aller-retour', () {
    test('un point ONDE et une station reviennent égaux, dans cet ordre', () {
      final OndePointFavorite onde = _ondeFavorite();
      final StationFavorite station = _stationFavorite();

      final List<Favorite> read = decodeFavorites(
        encodeFavorites(<Favorite>[onde, station]),
      );

      expect(read, <Favorite>[onde, station]);
    });

    test('code ONDE à espaces de bord : rendu verbatim, longueur 11', () {
      final List<Favorite> read = decodeFavorites(
        encodeFavorites(<Favorite>[_ondeFavorite(code: ' O968 5312 ')]),
      );

      final OndePointFavorite onde = read.single as OndePointFavorite;
      expect(onde.point.code.value, ' O968 5312 ');
      expect(onde.point.code.value.length, 11);
    });

    test("code ONDE à espace intérieur : 'A721 3011' ne revient pas "
        "'A7213011'", () {
      final List<Favorite> read = decodeFavorites(
        encodeFavorites(<Favorite>[_ondeFavorite(code: 'A721 3011')]),
      );

      final OndePointFavorite onde = read.single as OndePointFavorite;
      expect(onde.point.code.value, 'A721 3011');
      expect(onde.point.code.value, isNot('A7213011'));
    });

    test('station K447001001 et point ONDE de même code : deux favoris, de '
        'deux types', () {
      final List<Favorite> read = decodeFavorites(
        encodeFavorites(<Favorite>[
          _stationFavorite(),
          _ondeFavorite(code: 'K447001001'),
        ]),
      );

      expect(read, hasLength(2));
      expect(read[0], isA<StationFavorite>());
      expect(read[1], isA<OndePointFavorite>());
      expect((read[0] as StationFavorite).code.value, 'K447001001');
      expect((read[1] as OndePointFavorite).point.code.value, 'K447001001');
    });

    test('point ONDE sans cours d eau, ni département, ni région : égal, et '
        'les absences sont écrites null', () {
      final OndePointFavorite onde = _ondeFavorite(
        waterCourseLabel: null,
        departement: null,
      );

      final String text = encodeFavorites(<Favorite>[onde]);

      expect(text, contains('"cours_d_eau":null'));
      expect(text, contains('"departement":null'));
      expect(text, contains('"region":null'));
      expect(decodeFavorites(text), <Favorite>[onde]);
    });

    test('point ONDE portant une région : égal après aller-retour', () {
      final OndePointFavorite onde = _ondeFavorite(
        region: const AdministrativeArea(
          code: '24',
          label: 'Centre-Val de Loire',
        ),
      );

      expect(decodeFavorites(encodeFavorites(<Favorite>[onde])), <Favorite>[
        onde,
      ]);
    });
  });

  group('texte exact', () {
    test('une station', () {
      expect(
        encodeFavorites(<Favorite>[
          StationFavorite(
            code: StationCode('K447001001'),
            label: 'La Loire à Blois',
            addedAt: DateTime.utc(2026, 10, 11, 17, 5),
          ),
        ]),
        '{"version":1,"favoris":[{"type":"station",'
        '"ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001",'
        '"libelle":"La Loire à Blois"}]}',
      );
    });

    test('aucun favori', () {
      expect(encodeFavorites(const <Favorite>[]), '{"version":1,"favoris":[]}');
    });

    test('un point ONDE : sept champs, dans l ordre de l exemple', () {
      expect(
        encodeFavorites(<Favorite>[_ondeFavorite(code: ' O968 5312 ')]),
        _value(<String>[_ondeEntry]),
      );
    });
  });

  group('type inconnu', () {
    test('la troisième entrée de l exemple est rendue illisible, les deux '
        'autres sont lues, ordre gardé', () {
      final List<Favorite> read = decodeFavorites(_example);

      expect(read, hasLength(3));
      expect(read[0], _ondeFavorite(code: ' O968 5312 '));
      expect(read[1], _stationFavorite());
      expect(
        read[2],
        const UnreadableFavorite(
          raw: '{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z","libelle":"Chez moi","latitude":46.2,"longitude":5.2}',
          label: 'Chez moi',
        ),
      );
    });

    test('réécrit tel quel : même liste après réécriture, la troisième entrée '
        'garde ses cinq clés et sa position', () {
      final List<Favorite> read = decodeFavorites(_example);

      final String rewritten = encodeFavorites(read);

      expect(decodeFavorites(rewritten), read);
      expect(rewritten, _example);
      final Map<String, Object?> root =
          jsonDecode(rewritten) as Map<String, Object?>;
      final List<Object?> entries = root['favoris']! as List<Object?>;
      final Map<String, Object?> third = entries[2]! as Map<String, Object?>;
      expect(third.keys.toList(), <String>[
        'type',
        'ajoute_le',
        'libelle',
        'latitude',
        'longitude',
      ]);
      expect(third['type'], 'point_designe');
    });

    test('type absent : illisible', () {
      final Favorite read = _single(
        '{"ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001",'
        '"libelle":"La Loire à Blois"}',
      );

      expect(read, isA<UnreadableFavorite>());
      expect((read as UnreadableFavorite).label, 'La Loire à Blois');
    });
  });

  group('entrée malformée d un type connu', () {
    test('station au code refusé par StationCode', () {
      const String entry =
          '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z","code":"k447","libelle":"La Loire à Blois"}';

      expect(
        _single(entry),
        const UnreadableFavorite(raw: entry, label: 'La Loire à Blois'),
      );
    });

    test('station au libellé absent, puis blanc', () {
      final Favorite absent = _single(
        '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
        '"code":"K447001001"}',
      );
      final Favorite blank = _single(
        '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
        '"code":"K447001001","libelle":"  "}',
      );

      expect(absent, isA<UnreadableFavorite>());
      expect((absent as UnreadableFavorite).label, isNull);
      expect(blank, isA<UnreadableFavorite>());
      expect((blank as UnreadableFavorite).label, isNull);
    });

    test('point ONDE sans latitude : libellé pris dans le point', () {
      const String entry =
          '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY","longitude":1.78}}';

      expect(
        _single(entry),
        const UnreadableFavorite(raw: entry, label: 'LA BONNEURE A MILLANCAY'),
      );
    });

    test('point ONDE au code blanc, sans point, au cours d eau non chaîne, au '
        'département sans libellé, à la région non objet', () {
      const String head =
          '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z"';
      const String coords =
          '"libelle":"LA BONNEURE A MILLANCAY","latitude":47.4,"longitude":1.78';
      final List<String> entries = <String>[
        '$head,"point":{"code":"   ",$coords}}',
        '$head}',
        '$head,"point":"K4640001"}',
        '$head,"point":{"code":"K4640001",$coords,"cours_d_eau":3}}',
        '$head,"point":{"code":"K4640001",$coords,'
            '"departement":{"code":"41"}}}',
        '$head,"point":{"code":"K4640001",$coords,"region":"24"}}',
        '$head,"point":{"code":"K4640001","latitude":47.4,"longitude":1.78}}',
      ];

      for (final String entry in entries) {
        expect(_single(entry), isA<UnreadableFavorite>(), reason: entry);
      }
    });

    test('point ONDE lisible sans les trois clés facultatives : absences', () {
      final Favorite read = _single(
        '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
        '{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY",'
        '"latitude":47.444182169,"longitude":1.78116675}}',
      );

      expect(read, _ondeFavorite(waterCourseLabel: null, departement: null));
    });

    test('ajoute_le valant « hier », sans Z, absent ou non chaîne', () {
      for (final String addedAt in <String>[
        '"ajoute_le":"hier",',
        '"ajoute_le":"2026-10-11T17:05:00.000",',
        '"ajoute_le":1760202300000,',
        '',
      ]) {
        final Favorite read = _single(
          '{"type":"station",$addedAt"code":"K447001001",'
          '"libelle":"La Loire à Blois"}',
        );

        expect(read, isA<UnreadableFavorite>(), reason: addedAt);
        expect((read as UnreadableFavorite).label, 'La Loire à Blois');
      }
    });

    test(
      'entrée 42, "x", null : illisible, sans libellé, texte brut gardé',
      () {
        expect(_single('42'), const UnreadableFavorite(raw: '42'));
        expect(_single('"x"'), const UnreadableFavorite(raw: '"x"'));
        expect(_single('null'), const UnreadableFavorite(raw: 'null'));
      },
    );

    test('trois entrées dont celle du milieu est illisible : trois favoris, '
        'jamais tout ou rien', () {
      final List<Favorite> read = decodeFavorites(
        _value(<String>[_stationEntry, '42', _ondeEntry]),
      );

      expect(read, hasLength(3));
      expect(read[0], _stationFavorite());
      expect(read[1], const UnreadableFavorite(raw: '42'));
      expect(read[2], _ondeFavorite(code: ' O968 5312 '));
    });
  });

  group('valeur illisible', () {
    for (final String stored in <String>[
      'pas du json',
      '',
      '[]',
      '"x"',
      '{"favoris":[]}',
      '{"version":"1","favoris":[]}',
      '{"version":0,"favoris":[]}',
      '{"version":2,"favoris":[]}',
      '{"version":1}',
      '{"version":1,"favoris":{}}',
      '{"version":1.5,"favoris":[]}',
    ]) {
      test('« $stored » lève ListeDeFavorisIllisible', () {
        expect(
          () => decodeFavorites(stored),
          throwsA(isA<ListeDeFavorisIllisible>()),
        );
      });
    }

    test('rien de stocké : liste vide', () {
      expect(decodeFavorites(null), isEmpty);
    });
  });

  group('coordonnées', () {
    String entryWithLatitude(String latitude) =>
        '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
        '{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY",'
        '"latitude":$latitude,"longitude":1.78116675,"cours_d_eau":null,'
        '"departement":null,"region":null}}';

    test('latitude écrite 47 (entier JSON) : lue 47.0', () {
      final Favorite read = _single(entryWithLatitude('47'));

      expect(read, isA<OndePointFavorite>());
      expect((read as OndePointFavorite).point.latitude, 47.0);
    });

    test('latitude écrite en chaîne : entrée illisible', () {
      final Favorite read = _single(entryWithLatitude('"47.4"'));

      expect(read, isA<UnreadableFavorite>());
      expect((read as UnreadableFavorite).label, 'LA BONNEURE A MILLANCAY');
    });
  });

  test('deux entrées station de même code : deux StationFavorite rendus', () {
    final List<Favorite> read = decodeFavorites(
      _value(<String>[_stationEntry, _stationEntry]),
    );

    expect(read, <Favorite>[_stationFavorite(), _stationFavorite()]);
    expect(sameFavoritePlace(read[0], read[1]), isTrue);
  });

  group('entrée illisible qui ne peut pas être réécrite telle quelle', () {
    // `1e999` se décode en infini, que JSON ne sait pas réécrire : la garder
    // serait mentir, la laisser tomber perdrait une donnée. Échelle de la
    // valeur.
    test('point ONDE à la latitude 1e999 : lève ListeDeFavorisIllisible', () {
      expect(
        () => decodeFavorites(
          _value(<String>[
            _stationEntry,
            '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
                '{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY",'
                '"latitude":1e999,"longitude":1.78116675}}',
          ]),
        ),
        throwsA(isA<ListeDeFavorisIllisible>()),
      );
    });

    test('type inconnu portant un nombre 1e999 : lève '
        'ListeDeFavorisIllisible', () {
      expect(
        () => decodeFavorites(
          _value(<String>[
            '{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z",'
                '"libelle":"Chez moi","latitude":1e999,"longitude":5.2}',
          ]),
        ),
        throwsA(isA<ListeDeFavorisIllisible>()),
      );
    });
  });

  group('choix de lecture', () {
    test('ajoute_le à décalage explicite : lu, et réécrit en UTC', () {
      final Favorite read = _single(
        '{"type":"station","ajoute_le":"2026-10-11T19:05:00.000+02:00",'
        '"code":"K447001001","libelle":"La Loire à Blois"}',
      );

      expect(read, _stationFavorite());
      expect(
        encodeFavorites(<Favorite>[read]),
        contains('"ajoute_le":"2026-10-11T17:05:00.000Z"'),
      );
    });

    test('libellé blanc : point ONDE lu, station illisible', () {
      final Favorite onde = _single(
        '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
        '{"code":"K4640001","libelle":"  ","latitude":47.444182169,'
        '"longitude":1.78116675}}',
      );
      final Favorite station = _single(
        '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
        '"code":"K447001001","libelle":"  "}',
      );

      expect(onde, isA<OndePointFavorite>());
      expect((onde as OndePointFavorite).point.label, '  ');
      expect(station, isA<UnreadableFavorite>());
    });
  });

  group('clé inconnue', () {
    test('à la racine : ignorée, sans lever', () {
      expect(decodeFavorites('{"version":1,"favoris":[],"autre":1}'), isEmpty);
    });

    test('dans une entrée station lisible : ignorée, et non réécrite', () {
      final List<Favorite> read = decodeFavorites(
        _value(<String>[
          '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
              '"code":"K447001001","libelle":"La Loire à Blois","seuil":3}',
        ]),
      );

      expect(read, <Favorite>[_stationFavorite()]);
      expect(encodeFavorites(read), isNot(contains('"seuil"')));
    });
  });

  test('favorites_codec.dart n importe ni package:flutter ni '
      'shared_preferences', () {
    final String source = File('lib/data/preferences/favorites_codec.dart')
        .readAsStringSync();
    final Iterable<String> imports = const LineSplitter()
        .convert(source)
        .where((String line) => line.trimLeft().startsWith('import '));

    expect(imports, isNotEmpty);
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('shared_preferences')));
    for (final String line in imports) {
      expect(
        line.contains("'dart:convert'") ||
            line.contains("'package:martinpecheur/domain/"),
        isTrue,
        reason: line,
      );
    }
  });

  group('le favori tronçon (M1 de T5)', () {
    const String sectionEntry =
        '{"type":"troncon","ajoute_le":"2026-10-13T09:00:00.000Z",'
        '"code":"LP106","nom":"Loire amont"}';

    FloodSectionFavorite section() => FloodSectionFavorite(
      code: FloodSectionCode('LP106'),
      name: 'Loire amont',
      addedAt: DateTime.utc(2026, 10, 13, 9),
    );

    test('texte exact : type, ajoute_le, code, nom', () {
      expect(
        encodeFavorites(<Favorite>[section()]),
        _value(<String>[sectionEntry]),
      );
    });

    test('aller-retour des quatre types, dans l ordre', () {
      final List<Favorite> favorites = <Favorite>[
        _ondeFavorite(),
        section(),
        _stationFavorite(),
        decodeFavorites(_value(<String>[_designatedEntry])).single,
      ];

      final List<Favorite> read = decodeFavorites(encodeFavorites(favorites));

      expect(read, favorites);
      expect(read[1], isA<FloodSectionFavorite>());
      expect(read[3], isA<UnreadableFavorite>());
    });

    test('la version écrite reste 1', () {
      final Map<String, Object?> root = jsonDecode(
        encodeFavorites(<Favorite>[section()]),
      ) as Map<String, Object?>;
      expect(root['version'], 1);
    });

    for (final (String why, String entry) in <(String, String)>[
      ('code vide', '{"type":"troncon","code":""}'),
      (
        'code vide avec date et nom',
        '{"type":"troncon","ajoute_le":"2026-10-13T09:00:00.000Z",'
            '"code":"","nom":"Loire amont"}',
      ),
      (
        'nom blanc',
        '{"type":"troncon","ajoute_le":"2026-10-13T09:00:00.000Z",'
            '"code":"LP106","nom":"  "}',
      ),
      (
        'nom absent',
        '{"type":"troncon","ajoute_le":"2026-10-13T09:00:00.000Z",'
            '"code":"LP106"}',
      ),
      (
        'date sans fuseau',
        '{"type":"troncon","ajoute_le":"2026-10-13T09:00:00",'
            '"code":"LP106","nom":"Loire amont"}',
      ),
    ]) {
      test('$why : gardé en UnreadableFavorite et réécrit à l identique', () {
        final List<Favorite> read = decodeFavorites(_value(<String>[entry]));

        expect(read.single, isA<UnreadableFavorite>());
        expect(
          encodeFavorites(read),
          _value(<String>[jsonEncode(jsonDecode(entry))]),
        );
      });
    }
  });

  group('plage des coordonnées d un point ONDE (M1 de T5)', () {
    String entry(String latitude, String longitude) =>
        '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
        '{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY",'
        '"latitude":$latitude,"longitude":$longitude,"cours_d_eau":null,'
        '"departement":null,"region":null}}';

    for (final (String latitude, String longitude) in <(String, String)>[
      ('91', '1.7'),
      ('-91', '1.7'),
      ('47.4', '181'),
      ('47.4', '-181'),
    ]) {
      test('latitude $latitude, longitude $longitude : illisible', () {
        expect(_single(entry(latitude, longitude)), isA<UnreadableFavorite>());
      });
    }

    for (final (String latitude, String longitude) in <(String, String)>[
      ('90', '180'),
      ('-90', '-180'),
    ]) {
      test('latitude $latitude, longitude $longitude : bornes lues', () {
        expect(_single(entry(latitude, longitude)), isA<OndePointFavorite>());
      });
    }
  });
}

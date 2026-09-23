// Verrouille le mapper ONDE comme seul point de passage (BR-002) entre une
// ligne brute de `/ecoulement/observations` et le domaine. `code_campagne`
// est lu en `Object?` et rendu en `String` sans jamais passer par un `as
// int` (T-07) : `/campagnes` le rend en entier, mais ce endpoint n'a plus
// d'appelant (retiré le 2026-09-14) — `_campaignCode` reste tolérant aux
// deux formes malgré tout.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';

Map<String, dynamic> _readFixtureRow(String path, {int index = 0}) {
  final String content = File('test/fixtures/$path').readAsStringSync();
  final Map<String, dynamic> decoded =
      jsonDecode(content) as Map<String, dynamic>;
  final List<dynamic> data = decoded['data'] as List<dynamic>;
  return data.cast<Map<String, dynamic>>()[index];
}

void main() {
  group('mapOndeObservation — fixture réelle du 2026-09-13', () {
    test('première observation de la station K4520001', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_K4520001_2026-09-13.json',
      );

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.station.value, 'K4520001');
      expect(observation.observedAt, DateTime.utc(2026, 8, 25));
      expect(observation.category, const Assec());
      expect(observation.officialLabel, 'Assec');
      expect(observation.rawFlowCode, '3');
      expect(observation.campaignCode, '109905');
      // Le point est lu sur la même ligne, via mapOndePoint réutilisé (D8).
      expect(observation.point.label, 'LA RIVIERE AUX LOCHES A CHAON');
      expect(observation.point.latitude, closeTo(47.610620493, 1e-9));
    });

    test('une ligne sans latitude : FormatException, propagée depuis '
        'mapOndePoint (D8)', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_K4520001_2026-09-13.json',
      )..remove('latitude');

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });
  });

  group('mapOndeObservation — fixture réelle du 2026-09-14, code à espace '
      'intérieur (T-14)', () {
    test("la station 'A721 3011' se lit sans perdre son espace : le code "
        "traverse le mapper verbatim, le point et la catégorie sont lus", () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_A721_3011_espace_2026-09-14.json',
      );

      final OndeObservation observation = mapOndeObservation(ligne);

      // Le code porte un espace intérieur et neuf caractères : la forme à
      // huit caractères de T-04 n'était vraie que de l'échantillon Loire.
      expect(observation.station.value, 'A721 3011');
      expect(observation.observedAt, DateTime.utc(2026, 9, 8));
      expect(observation.category, const Ecoulement());
      expect(observation.rawFlowCode, '1a');
      expect(observation.point.label, 'Le Trey à Vilcey-sur-Trey');
      expect(observation.point.waterCourseLabel, 'Le Trey');
      // Fixture capturée avec l'ancienne liste à dix champs (avant Z2) :
      // libelle_departement absent, le libellé replie sur le code (BR-007).
      expect(
        observation.point.departement,
        const AdministrativeArea(code: '54', label: '54'),
      );
      expect(observation.point.region, isNull);
      expect(observation.point.latitude, closeTo(48.931956125, 1e-9));
      expect(observation.point.longitude, closeTo(5.964665997, 1e-9));
    });

    test("'A721 3011' et 'A7213011' restent deux stations distinctes après "
        "le mapper — l'API en rend deux historiques différents (count 40 "
        'contre 63, T-14) : les fondre en une seule masquerait un point', () {
      final OndeObservation avecEspace = mapOndeObservation(
        _readFixtureRow(
          'onde/observations_station_A721_3011_espace_2026-09-14.json',
        ),
      );
      final OndeObservation sansEspace = mapOndeObservation(
        _readFixtureRow(
          'onde/observations_station_A7213011_sans_espace_2026-09-14.json',
        ),
      );

      expect(avecEspace.station.value, 'A721 3011');
      expect(sansEspace.station.value, 'A7213011');
      expect(avecEspace.station == sansEspace.station, isFalse);
      // Même rivière en apparence, deux libellés distincts dans le
      // référentiel — constat brut, non interprété (T-14).
      expect(avecEspace.point.label, 'Le Trey à Vilcey-sur-Trey');
      expect(sansEspace.point.label, 'Le Trey à Vilcey sur Trey');
    });
  });

  group('mapOndePoint — fixture réelle du 2026-09-13', () {
    test('première observation de la station K4520001 lue comme un point', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_K4520001_2026-09-13.json',
      );

      final OndePoint point = mapOndePoint(ligne);

      expect(point.code.value, 'K4520001');
      expect(point.label, 'LA RIVIERE AUX LOCHES A CHAON');
      expect(point.latitude, closeTo(47.610620493, 1e-9));
      expect(point.longitude, closeTo(2.173858157, 1e-9));
      expect(point.waterCourseLabel, 'ruisseau la rivière aux loches');
      // Fixture non filtrée : porte code_region/libelle_region et
      // libelle_departement, vérifié par appel réel le 2026-09-23 (T-16).
      expect(
        point.departement,
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
      );
      expect(
        point.region,
        const AdministrativeArea(code: '24', label: 'Centre-Val de Loire'),
      );
    });
  });

  group('mapOndePoint — région et département (ADR-015)', () {
    test('première ligne de la fixture bbox Loire : région et département '
        'lus directement, la fixture les porte sans filtre `fields`', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_bbox_loire_2026-09-13.json',
      );

      final OndePoint point = mapOndePoint(ligne);

      expect(
        point.region,
        const AdministrativeArea(code: '24', label: 'Centre-Val de Loire'),
      );
      expect(
        point.departement,
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
      );
    });

    test('fixture capturée SANS ces trois champs '
        '(observations_station_P9130001, avant `T-16`) : région null, '
        'département de code lu et de libellé replié sur le code — aucune '
        'exception', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_P9130001_code_ecoulement_null_2026-09-14.json',
      );

      final OndePoint point = mapOndePoint(ligne);

      expect(point.region, isNull);
      expect(
        point.departement,
        const AdministrativeArea(code: '33', label: '33'),
      );
    });

    test(
      'code_departement mal formé lève comme aujourd\'hui (DepartementCode)',
      () {
        final Map<String, dynamic> ligne = _readFixtureRow(
          'onde/observations_bbox_loire_2026-09-13.json',
        )..['code_departement'] = 'XYZ';

        expect(() => mapOndePoint(ligne), throwsArgumentError);
      },
    );

    test('code_region numérique : FormatException, comme tout autre champ '
        'texte (via _text)', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_bbox_loire_2026-09-13.json',
      )..['code_region'] = 24;

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });
  });

  group("mapOndeObservation — catégories d'écoulement (C-10, BR-011)", () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'date_observation': '2026-08-25',
      'code_campagne': '109905',
      // latitude/longitude requises depuis D8 : mapOndeObservation délègue
      // désormais à mapOndePoint. Valeurs réelles de K4520001.
      'latitude': 47.610620493,
      'longitude': 2.173858157,
    };

    void expectCategory(String? rawCode, FlowCategory attendue) {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_ecoulement'] = rawCode;

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.category, attendue);
      expect(observation.rawFlowCode, rawCode);
    }

    test(
      "'1a' -> Ecoulement()",
      () => expectCategory('1a', const Ecoulement()),
    );
    test(
      "'1f' -> EcoulementFaible()",
      () => expectCategory('1f', const EcoulementFaible()),
    );
    test(
      "'2' -> EcoulementNonVisible()",
      () => expectCategory('2', const EcoulementNonVisible()),
    );
    test("'3' -> Assec()", () => expectCategory('3', const Assec()));
    test("'4' -> NonObserve()", () => expectCategory('4', const NonObserve()));
    test(
      "'9z' -> Inconnu('9z')",
      () => expectCategory('9z', const Inconnu('9z')),
    );

    test("code_ecoulement absent -> Inconnu(null), ne lève pas", () {
      final Map<String, dynamic> ligne = baseRow();

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.category, const Inconnu(null));
      expect(observation.rawFlowCode, isNull);
    });

    test("code_ecoulement vide ('') -> Inconnu(null), jamais Inconnu('') — "
        "une chaîne vide n'est pas un code (BR-007)", () {
      final Map<String, dynamic> ligne = baseRow()..['code_ecoulement'] = '';

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.category, const Inconnu(null));
      expect(observation.rawFlowCode, isNull);
    });

    test('code_ecoulement numérique (3) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['code_ecoulement'] = 3;

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });
  });

  group('mapOndeObservation — lignes synthétiques dérivées', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'date_observation': '2026-08-25',
      'code_ecoulement': '3',
      'libelle_ecoulement': 'Assec',
      'code_campagne': '109905',
      // latitude/longitude requises depuis D8 : mapOndeObservation délègue
      // désormais à mapOndePoint. Valeurs réelles de K4520001.
      'latitude': 47.610620493,
      'longitude': 2.173858157,
    };

    test("code_station d'une longueur inattendue ('K452000', sept "
        'caractères) : accepté verbatim, plus refusé — la forme à huit '
        "caractères de T-04 n'est vraie que de l'échantillon Loire (T-14)", () {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_station'] = 'K452000';

      expect(mapOndeObservation(ligne).station.value, 'K452000');
    });

    test('code_station entièrement blanc : ArgumentError — un code blanc '
        "n'identifie aucune station (BR-007)", () {
      final Map<String, dynamic> ligne = baseRow()..['code_station'] = '   ';

      expect(() => mapOndeObservation(ligne), throwsArgumentError);
    });

    test('code_station absent : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_station');

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test(
      "code_station vide ('') : FormatException — _text normalise la "
      "chaîne vide en absence avant d'atteindre OndeStationCode (BR-007)",
      () {
        final Map<String, dynamic> ligne = baseRow()..['code_station'] = '';

        expect(
          () => mapOndeObservation(ligne),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('code_station numérique (12345678) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['code_station'] = 12345678;

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('date_observation absente : FormatException (BR-001)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('date_observation');

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test("date_observation illisible ('25/08/2026') : FormatException "
        '(BR-001)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['date_observation'] = '25/08/2026';

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test("date_observation avec heure ('2026-08-25T10:00:00') : seule la date "
        'est lue, aucune heure conservée', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['date_observation'] = '2026-08-25T10:00:00';

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.observedAt, DateTime.utc(2026, 8, 25));
    });

    test(
      "date_observation avec heure et fuseau ('2026-08-26T00:30:00+02:00') : "
      "le jour reste le 26, aucun recul au 25",
      () {
        final Map<String, dynamic> ligne = baseRow()
          ..['date_observation'] = '2026-08-26T00:30:00+02:00';

        final OndeObservation observation = mapOndeObservation(ligne);

        expect(observation.observedAt, DateTime.utc(2026, 8, 26));
      },
    );

    test("date_observation avec un mois hors plage ('2026-13-01') : "
        'FormatException explicite, le débordement de DateTime.utc est '
        'détecté et refusé', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['date_observation'] = '2026-13-01';

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('campaignCode absent : null, jamais une chaîne vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_campagne');

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.campaignCode, isNull);
    });

    test("code_campagne vide ('') : campaignCode à null, jamais une chaîne "
        'vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..['code_campagne'] = '';

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.campaignCode, isNull);
    });

    test('officialLabel absent : null, jamais une chaîne vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..remove('libelle_ecoulement');

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.officialLabel, isNull);
    });

    test('libelle_ecoulement numérique (5) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['libelle_ecoulement'] = 5;

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('champ inédit (champ_inedit) : lu sans échouer (BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['champ_inedit'] = 1;

      expect(() => mapOndeObservation(ligne), returnsNormally);
    });
  });

  group('mapOndePoint — lignes synthétiques dérivées', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'libelle_station': 'LA RIVIERE AUX LOCHES A CHAON',
      'code_departement': '41',
      'libelle_cours_eau': 'ruisseau la rivière aux loches',
      'latitude': 47.610620493,
      'longitude': 2.173858157,
    };

    test("code_station d'une longueur inattendue ('K452000', sept "
        'caractères) : accepté verbatim, plus refusé (T-14)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_station'] = 'K452000';

      expect(mapOndePoint(ligne).code.value, 'K452000');
    });

    test('code_station entièrement blanc : ArgumentError (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..['code_station'] = '   ';

      expect(() => mapOndePoint(ligne), throwsArgumentError);
    });

    test('code_station absent : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_station');

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('code_station numérique (12345678) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['code_station'] = 12345678;

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('libelle_station absent : label replié sur le code, jamais une '
        'chaîne vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('libelle_station');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.label, 'K4520001');
    });

    test("libelle_station vide ('') : label replié sur le code, comme une "
        'absence (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..['libelle_station'] = '';

      final OndePoint point = mapOndePoint(ligne);

      expect(point.label, 'K4520001');
    });

    test('code_departement absent : departement à null', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_departement');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.departement, isNull);
    });

    test('code_departement numérique (41) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['code_departement'] = 41;

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('libelle_cours_eau absent : waterCourseLabel à null', () {
      final Map<String, dynamic> ligne = baseRow()..remove('libelle_cours_eau');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.waterCourseLabel, isNull);
    });

    test('libelle_cours_eau numérique (42) : FormatException, jamais un '
        'TypeError nu', () {
      final Map<String, dynamic> ligne = baseRow()..['libelle_cours_eau'] = 42;

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test("libelle_cours_eau ('Ruisseau LA Rivière') : waterCourseLabel "
        'identique, casse intacte — aucune règle de casse (T-09)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['libelle_cours_eau'] = 'Ruisseau LA Rivière';

      final OndePoint point = mapOndePoint(ligne);

      expect(point.waterCourseLabel, 'Ruisseau LA Rivière');
    });

    test('latitude/longitude en entier (coordonnée ronde) : converties en '
        'double malgré tout', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['latitude'] = 47
        ..['longitude'] = 2;

      final OndePoint point = mapOndePoint(ligne);

      expect(point.latitude, 47.0);
      expect(point.longitude, 2.0);
    });

    test('latitude absente : FormatException — un point sans coordonnées '
        "n'est pas plaçable", () {
      final Map<String, dynamic> ligne = baseRow()..remove('latitude');

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('longitude absente : FormatException — un point sans coordonnées '
        "n'est pas plaçable", () {
      final Map<String, dynamic> ligne = baseRow()..remove('longitude');

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('geometry présente mais ignorée : latitude/longitude à plat font '
        'foi seules (T-09)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['geometry'] = <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[99.0, 99.0],
        };

      final OndePoint point = mapOndePoint(ligne);

      expect(point.latitude, closeTo(47.610620493, 1e-9));
      expect(point.longitude, closeTo(2.173858157, 1e-9));
    });

    test('champ inédit (champ_inedit) : lu sans échouer (BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['champ_inedit'] = 1;

      expect(() => mapOndePoint(ligne), returnsNormally);
    });
  });
}

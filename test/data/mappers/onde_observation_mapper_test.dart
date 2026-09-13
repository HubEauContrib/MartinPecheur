// Verrouille le mapper ONDE comme seul point de passage (BR-002) entre une
// ligne brute de `/ecoulement/observations` ou `/ecoulement/campagnes` et le
// domaine. Le cas central est T-07 : `code_campagne` est un entier côté
// `/campagnes` et une chaîne côté `/observations` — les deux doivent rendre
// la même chaîne, sans jamais passer par un `as int`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/station/station.dart';

Map<String, dynamic> _readFixtureRow(String path, {int index = 0}) {
  final String content = File('test/fixtures/$path').readAsStringSync();
  final Map<String, dynamic> decoded =
      jsonDecode(content) as Map<String, dynamic>;
  final List<dynamic> data = decoded['data'] as List<dynamic>;
  return data.cast<Map<String, dynamic>>()[index];
}

void main() {
  group('mapOndeObservation — fixture reelle du 2026-09-13', () {
    test('premiere observation de la station K4520001', () {
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
    });
  });

  group('mapOndeCampaign — fixture reelle du 2026-09-13', () {
    test('premiere campagne du departement 41', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/campagnes_departement_41_2026-09-13.json',
      );

      final OndeCampaign campagne = mapOndeCampaign(ligne);

      expect(campagne.code, '109905');
      expect(campagne.date, DateTime.utc(2026, 8, 25));
      expect(campagne.rawTypeLabel, 'usuelle');
      expect(campagne.modalityCount, 5);
    });

    test('code_campagne entier (109905) rend la meme chaine que la forme '
        "chaine cote observations — c'est T-07", () {
      final Map<String, dynamic> campagneLigne = _readFixtureRow(
        'onde/campagnes_departement_41_2026-09-13.json',
      );
      final Map<String, dynamic> observationLigne = _readFixtureRow(
        'onde/observations_station_K4520001_2026-09-13.json',
      );

      final OndeCampaign campagne = mapOndeCampaign(campagneLigne);
      final OndeObservation observation = mapOndeObservation(observationLigne);

      expect(campagne.code, '109905');
      expect(observation.campaignCode, '109905');
    });
  });

  group('mapOndePoint — fixture reelle du 2026-09-13', () {
    test('premiere observation de la station K4520001 lue comme un point', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'onde/observations_station_K4520001_2026-09-13.json',
      );

      final OndePoint point = mapOndePoint(ligne);

      expect(point.code.value, 'K4520001');
      expect(point.label, 'LA RIVIERE AUX LOCHES A CHAON');
      expect(point.latitude, closeTo(47.610620493, 1e-9));
      expect(point.longitude, closeTo(2.173858157, 1e-9));
      expect(point.waterCourseLabel, 'ruisseau la rivière aux loches');
      expect(point.departement, DepartementCode('41'));
    });
  });

  group('mapOndeObservation — categories d ecoulement (C-10, BR-011)', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'date_observation': '2026-08-25',
      'code_campagne': '109905',
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

    test('code_ecoulement absent -> Inconnu(null), ne leve pas', () {
      final Map<String, dynamic> ligne = baseRow();

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.category, const Inconnu(null));
      expect(observation.rawFlowCode, isNull);
    });
  });

  group('mapOndeObservation — lignes synthetiques derivees', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'date_observation': '2026-08-25',
      'code_ecoulement': '3',
      'libelle_ecoulement': 'Assec',
      'code_campagne': '109905',
    };

    test("code_station de mauvaise forme ('K452000') : ArgumentError", () {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_station'] = 'K452000';

      expect(() => mapOndeObservation(ligne), throwsArgumentError);
    });

    test('code_station absent : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_station');

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('date_observation absente : FormatException (BR-001)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('date_observation');

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test("date_observation illisible ('hier') : FormatException (BR-001)", () {
      final Map<String, dynamic> ligne = baseRow()
        ..['date_observation'] = 'hier';

      expect(() => mapOndeObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('campaignCode absent : null, jamais une chaine vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_campagne');

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.campaignCode, isNull);
    });

    test('officialLabel absent : null, jamais une chaine vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()
        ..remove('libelle_ecoulement');

      final OndeObservation observation = mapOndeObservation(ligne);

      expect(observation.officialLabel, isNull);
    });

    test('champ inedit (champ_inedit) : lu sans echouer (BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['champ_inedit'] = 1;

      expect(() => mapOndeObservation(ligne), returnsNormally);
    });
  });

  group('mapOndePoint — lignes synthetiques derivees', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K4520001',
      'libelle_station': 'LA RIVIERE AUX LOCHES A CHAON',
      'code_departement': '41',
      'libelle_cours_eau': 'ruisseau la rivière aux loches',
      'latitude': 47.610620493,
      'longitude': 2.173858157,
    };

    test("code_station de mauvaise forme ('K452000') : ArgumentError", () {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_station'] = 'K452000';

      expect(() => mapOndePoint(ligne), throwsArgumentError);
    });

    test('code_station absent : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_station');

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('libelle_station absent : label replie sur le code, jamais une '
        'chaine vide (BR-007)', () {
      final Map<String, dynamic> ligne = baseRow()..remove('libelle_station');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.label, 'K4520001');
    });

    test('code_departement absent : departement a null', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_departement');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.departement, isNull);
    });

    test('libelle_cours_eau absent : waterCourseLabel a null', () {
      final Map<String, dynamic> ligne = baseRow()..remove('libelle_cours_eau');

      final OndePoint point = mapOndePoint(ligne);

      expect(point.waterCourseLabel, isNull);
    });

    test('latitude/longitude en entier (coordonnee ronde) : converties en '
        'double malgre tout', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['latitude'] = 47
        ..['longitude'] = 2;

      final OndePoint point = mapOndePoint(ligne);

      expect(point.latitude, 47.0);
      expect(point.longitude, 2.0);
    });

    test('latitude absente : FormatException — un point sans coordonnees '
        "n'est pas placable", () {
      final Map<String, dynamic> ligne = baseRow()..remove('latitude');

      expect(() => mapOndePoint(ligne), throwsA(isA<FormatException>()));
    });

    test('geometry presente mais ignoree : latitude/longitude a plat font '
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

    test('champ inedit (champ_inedit) : lu sans echouer (BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['champ_inedit'] = 1;

      expect(() => mapOndePoint(ligne), returnsNormally);
    });
  });

  group('mapOndeCampaign — lignes synthetiques derivees', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_campagne': 109905,
      'date_campagne': '2026-08-25',
      'nombre_modalite_ecoulement': 5,
      'libelle_type_campagne': 'usuelle',
    };

    test('code_campagne absent : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..remove('code_campagne');

      expect(() => mapOndeCampaign(ligne), throwsA(isA<FormatException>()));
    });

    test('date_campagne illisible : FormatException (BR-001)', () {
      final Map<String, dynamic> ligne = baseRow()..['date_campagne'] = 'hier';

      expect(() => mapOndeCampaign(ligne), throwsA(isA<FormatException>()));
    });

    test('nombre_modalite_ecoulement absent : modalityCount a null', () {
      final Map<String, dynamic> ligne = baseRow()
        ..remove('nombre_modalite_ecoulement');

      final OndeCampaign campagne = mapOndeCampaign(ligne);

      expect(campagne.modalityCount, isNull);
    });

    test('champ inedit (champ_inedit) : lu sans echouer (BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['champ_inedit'] = 1;

      expect(() => mapOndeCampaign(ligne), returnsNormally);
    });
  });
}

// Verrouille le mapper comme seul point de conversion (BR-002) : cinq cas
// sur les fixtures reelles du 2026-09-13, huit sur des lignes synthetiques
// derivees. Toute regression sur les unites, les dates ou C-05 doit rougir
// ici avant d'atteindre l'ecran.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/mappers/hydro_observation_mapper.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

Map<String, dynamic> _readFixtureRow(String path, {int index = 0}) {
  final String content = File('test/fixtures/$path').readAsStringSync();
  final Map<String, dynamic> decoded =
      jsonDecode(content) as Map<String, dynamic>;
  final List<dynamic> data = decoded['data'] as List<dynamic>;
  return data.cast<Map<String, dynamic>>()[index];
}

void main() {
  group('mapHydroObservation — fixtures reelles du 2026-09-13', () {
    test('fixture Q : discharge converti, level absent', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'hubeau/observations_tr_K447001001_Q_2026-09-13.json',
      );

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.discharge, const CubicMetresPerSecond(47.8));
      expect(observation.grandeur, Grandeur.debit);
      expect(observation.level, isNull);
    });

    test('fixture H : level negatif, discharge absent', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'hubeau/observations_tr_K447001001_H_2026-09-13.json',
      );

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.level, const Metres(-1.232));
      expect(observation.discharge, isNull);
    });

    test('fixture Q : statusCode, statusLabel et qualificationLabel '
        'recopies tels quels (BR-006)', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'hubeau/observations_tr_K447001001_Q_2026-09-13.json',
      );

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.qualification.statusCode, 12);
      expect(observation.qualification.statusLabel, 'Pré-validée');
      expect(observation.qualification.qualificationLabel, 'Bonne');
    });

    test('fixture Q : measuredAt en UTC, perimee vue le 2026-09-13 a midi', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'hubeau/observations_tr_K447001001_Q_2026-09-13.json',
      );

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.measuredAt.isUtc, isTrue);
      expect(
        observation.freshnessAt(DateTime.utc(2026, 9, 13, 12)),
        Freshness.perimee,
      );
    });

    test('fixture site (code_station null) : refusee par FormatException '
        '(C-05)', () {
      final Map<String, dynamic> ligne = _readFixtureRow(
        'hubeau/observations_tr_site_K4470010_2026-09-13.json',
        index: 1,
      );

      expect(() => mapHydroObservation(ligne), throwsA(isA<FormatException>()));
    });
  });

  group('mapHydroObservation — lignes synthetiques', () {
    Map<String, dynamic> baseRow() => <String, dynamic>{
      'code_station': 'K447001001',
      'date_obs': '2026-08-27T08:00:00Z',
      'grandeur_hydro': 'Q',
      'resultat_obs': 47800.0,
      'code_statut': 12,
      'libelle_statut': 'Pré-validée',
      'code_qualification_obs': 20,
      'libelle_qualification_obs': 'Bonne',
    };

    test("code_station de mauvaise forme ('K4470010') : ArgumentError", () {
      final Map<String, dynamic> ligne = baseRow()
        ..['code_station'] = 'K4470010';

      expect(() => mapHydroObservation(ligne), throwsArgumentError);
    });

    test("date_obs illisible ('hier') : FormatException", () {
      final Map<String, dynamic> ligne = baseRow()..['date_obs'] = 'hier';

      expect(() => mapHydroObservation(ligne), throwsA(isA<FormatException>()));
    });

    test('date_obs absente (null) : FormatException', () {
      final Map<String, dynamic> ligne = baseRow()..['date_obs'] = null;

      expect(() => mapHydroObservation(ligne), throwsA(isA<FormatException>()));
    });

    test("grandeur_hydro inconnue ('X') : discharge et level absents "
        '(BR-011)', () {
      final Map<String, dynamic> ligne = baseRow()..['grandeur_hydro'] = 'X';

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.grandeur, Grandeur.inconnu);
      expect(observation.discharge, isNull);
      expect(observation.level, isNull);
    });

    test('resultat_obs absent (null) : discharge absent', () {
      final Map<String, dynamic> ligne = baseRow()..['resultat_obs'] = null;

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.discharge, isNull);
    });

    test('resultat_obs a zero : discharge non nul, valeur zero — un assec '
        "n'est pas une absence (BR-007)", () {
      final Map<String, dynamic> ligne = baseRow()..['resultat_obs'] = 0;

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.discharge, isNotNull);
      expect(observation.discharge, const CubicMetresPerSecond(0));
    });

    test('resultat_obs en entier (47800) : converti en 47,8 malgre tout', () {
      final Map<String, dynamic> ligne = baseRow()..['resultat_obs'] = 47800;

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.discharge, const CubicMetresPerSecond(47.8));
    });

    test('qualification absente (quatre cles retirees) : champs a null', () {
      final Map<String, dynamic> ligne = baseRow()
        ..remove('code_statut')
        ..remove('libelle_statut')
        ..remove('code_qualification_obs')
        ..remove('libelle_qualification_obs');

      final HydroObservation observation = mapHydroObservation(ligne);

      expect(observation.qualification.statusCode, isNull);
      expect(observation.qualification.statusLabel, isNull);
      expect(observation.qualification.qualificationCode, isNull);
      expect(observation.qualification.qualificationLabel, isNull);
    });

    test('cle inedite (champ_inedit_2027) : ignoree, ne fait pas planter '
        'le mapper', () {
      final Map<String, dynamic> ligne = baseRow()
        ..['champ_inedit_2027'] = 'valeur surprise';

      expect(() => mapHydroObservation(ligne), returnsNormally);
    });

    test('resultat_obs en chaine ("47800.0") : refuse a la frontiere, jamais un TypeError nu', () {
      final Map<String, dynamic> ligne = <String, dynamic>{
        'code_station': 'K447001001',
        'date_obs': '2026-08-27T08:00:00Z',
        'grandeur_hydro': 'Q',
        'resultat_obs': '47800.0',
      };
      expect(() => mapHydroObservation(ligne), throwsFormatException);
    });
  });
}

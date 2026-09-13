// Verrouille la conversion deja faite (BR-002), l'absence jamais remplacee
// par zero (BR-007), la date de MESURE (BR-001), la branche inconnue
// obligatoire (BR-011) et la qualification transportee telle quelle
// (BR-006).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

void main() {
  group('grandeurFromCode (BR-011)', () {
    test("'Q' devient debit, 'H' devient hauteur — casse non normalisee", () {
      expect(grandeurFromCode('Q'), Grandeur.debit);
      expect(grandeurFromCode('H'), Grandeur.hauteur);
    });

    test("null, 'X' et 'q' deviennent inconnu — un code inconnu n'est "
        'jamais assimile a debit (afficherait des metres comme des '
        "m³/s)", () {
      expect(grandeurFromCode(null), Grandeur.inconnu);
      expect(grandeurFromCode('X'), Grandeur.inconnu);
      expect(grandeurFromCode('q'), Grandeur.inconnu);
    });
  });

  group('HydroObservation — deja convertie (BR-002)', () {
    test('une observation de debit porte un CubicMetresPerSecond et un '
        "level null — relevee sur K447001001 le 2026-09-13", () {
      final HydroObservation observation = HydroObservation(
        station: StationCode('K447001001'),
        measuredAt: DateTime.utc(2026, 9, 13, 8),
        grandeur: Grandeur.debit,
        discharge: const CubicMetresPerSecond(47.8),
        level: null,
        qualification: const Qualification(
          statusCode: null,
          statusLabel: null,
          qualificationCode: null,
          qualificationLabel: null,
        ),
      );

      expect(observation.discharge, const CubicMetresPerSecond(47.8));
      expect(observation.level, isNull);
    });

    test('une observation de hauteur porte un Metres negatif et un '
        'discharge null — la conversion ne redresse jamais le signe', () {
      final HydroObservation observation = HydroObservation(
        station: StationCode('K447001001'),
        measuredAt: DateTime.utc(2026, 9, 13, 8),
        grandeur: Grandeur.hauteur,
        discharge: null,
        level: const Metres(-1.232),
        qualification: const Qualification(
          statusCode: null,
          statusLabel: null,
          qualificationCode: null,
          qualificationLabel: null,
        ),
      );

      expect(observation.level, const Metres(-1.232));
      expect(observation.discharge, isNull);
    });
  });

  group('freshnessAt (BR-001, BR-005)', () {
    test("une mesure du 2026-08-27T08:00Z est perimee lue le "
        '2026-09-13T12:00Z, et fraiche lue le 2026-08-27T09:00Z', () {
      final HydroObservation observation = HydroObservation(
        station: StationCode('K447001001'),
        measuredAt: DateTime.utc(2026, 8, 27, 8),
        grandeur: Grandeur.debit,
        discharge: const CubicMetresPerSecond(47.8),
        level: null,
        qualification: const Qualification(
          statusCode: null,
          statusLabel: null,
          qualificationCode: null,
          qualificationLabel: null,
        ),
      );

      expect(
        observation.freshnessAt(DateTime.utc(2026, 9, 13, 12)),
        Freshness.perimee,
      );
      expect(
        observation.freshnessAt(DateTime.utc(2026, 8, 27, 9)),
        Freshness.fraiche,
      );
    });
  });

  group('Qualification (BR-006)', () {
    test('la qualification relevee le 2026-09-13 est conservee telle '
        "quelle — statusCode 12 'Pré-validée', qualificationCode 20 "
        "'Bonne'", () {
      const Qualification qualification = Qualification(
        statusCode: 12,
        statusLabel: 'Pré-validée',
        qualificationCode: 20,
        qualificationLabel: 'Bonne',
      );

      expect(qualification.statusCode, 12);
      expect(qualification.statusLabel, 'Pré-validée');
      expect(qualification.qualificationCode, 20);
      expect(qualification.qualificationLabel, 'Bonne');
    });

    test('une qualification entierement absente (quatre null) est '
        'acceptee', () {
      const Qualification qualification = Qualification(
        statusCode: null,
        statusLabel: null,
        qualificationCode: null,
        qualificationLabel: null,
      );

      expect(qualification.statusCode, isNull);
      expect(qualification.statusLabel, isNull);
      expect(qualification.qualificationCode, isNull);
      expect(qualification.qualificationLabel, isNull);
    });
  });
}

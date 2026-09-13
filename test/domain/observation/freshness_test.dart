// Verrouille les bornes absolues de BR-005 (2 h puis 24 h), sur la date de
// MESURE et jamais de récupération (BR-001). `now` est un paramètre : sans
// lui, les bornes ne sont pas testables.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';

void main() {
  group('Fraîcheur d\'une observation (BR-005)', () {
    test('un âge de 1 min ou de 1 h 59 est fraiche', () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        Freshness.fraiche,
      );
      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 1, minutes: 59)),
          now: now,
        ),
        Freshness.fraiche,
      );
    });

    test('un âge de 2 h exactement est ancienne — la borne est la plus '
        'sévère', () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        Freshness.ancienne,
      );
    });

    test('un âge de 2 h 1 min ou de 23 h 59 est ancienne', () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 2, minutes: 1)),
          now: now,
        ),
        Freshness.ancienne,
      );
      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 23, minutes: 59)),
          now: now,
        ),
        Freshness.ancienne,
      );
    });

    test('un âge de 24 h exactement est perimee — la borne est la plus '
        'sévère', () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 24)),
          now: now,
        ),
        Freshness.perimee,
      );
    });

    test('un âge de 24 h 1 min est perimee, comme les dix-sept jours '
        "constatés sur K447001001 le 2026-09-13", () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(
          measuredAt: now.subtract(const Duration(hours: 24, minutes: 1)),
          now: now,
        ),
        Freshness.perimee,
      );
      expect(
        freshnessOf(
          measuredAt: DateTime.utc(2026, 8, 27, 8),
          now: DateTime.utc(2026, 9, 13, 12),
        ),
        Freshness.perimee,
      );
    });

    test('une mesure datée dans le futur est fraiche : un âge négatif est une '
        "anomalie de la source, pas une donnée vieille", () {
      final DateTime now = DateTime.utc(2026, 9, 13, 12);

      expect(
        freshnessOf(measuredAt: now.add(const Duration(hours: 3)), now: now),
        Freshness.fraiche,
      );
    });

    test("difference compare des instants absolus : une mesure UTC à -3 h "
        'reste ancienne même comparée à un now exprimé en heure locale '
        '(pas de toUtc() "au cas où")', () {
      final DateTime measuredAtUtc = DateTime.utc(2026, 9, 13, 9);
      final DateTime nowLocal = DateTime.utc(2026, 9, 13, 12).toLocal();

      expect(
        freshnessOf(measuredAt: measuredAtUtc, now: nowLocal),
        Freshness.ancienne,
      );
    });

    test('ancienneApres vaut 2 h et perimeeApres vaut 24 h', () {
      expect(ancienneApres, const Duration(hours: 2));
      expect(perimeeApres, const Duration(hours: 24));
    });
  });
}

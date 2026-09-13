// Verrouille la borne de BR-010 (60 jours), sur la date d'OBSERVATION de la
// campagne. L'age se compte en JOURS entiers (T-08) : l'API ONDE ne donne
// pas d'heure, une observation d'ecoulement n'est jamais datee a la minute
// pres. `now` est un parametre, comme pour freshnessOf — meme parade pour un
// age negatif.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';

void main() {
  group('Age d\'une campagne ONDE (BR-010, T-08)', () {
    test('campaignAgeInDays(2026-08-25 -> 2026-09-13) vaut 19 jours, '
        'recente', () {
      final DateTime observedAt = DateTime.utc(2026, 8, 25);
      final DateTime now = DateTime.utc(2026, 9, 13);

      expect(campaignAgeInDays(observedAt: observedAt, now: now), 19);
      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });

    test('59 jours est recente', () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.subtract(const Duration(days: 59));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });

    test('60 jours exactement est ancienne — la borne est la plus severe', () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.subtract(const Duration(days: 60));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.ancienne,
      );
    });

    test('61 jours est ancienne', () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.subtract(const Duration(days: 61));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.ancienne,
      );
    });

    test('cas hors saison : 2025-09-26 vu le 2026-02-15 (142 j) est '
        'ancienne', () {
      expect(
        campaignAgeOf(
          observedAt: DateTime.utc(2025, 9, 26),
          now: DateTime.utc(2026, 2, 15),
        ),
        CampaignAge.ancienne,
      );
      expect(
        campaignAgeInDays(
          observedAt: DateTime.utc(2025, 9, 26),
          now: DateTime.utc(2026, 2, 15),
        ),
        142,
      );
    });

    test('une observation datee dans le futur est recente : un age negatif '
        "est une anomalie de la source, pas une donnee vieille", () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.add(const Duration(days: 3));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });
  });
}

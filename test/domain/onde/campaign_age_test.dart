// Verrouille la borne de BR-010 (60 jours), sur la date d'OBSERVATION de la
// campagne. L'âge se compte en JOURS CALENDAIRES (T-08) : l'API ONDE ne
// donne pas d'heure, une observation d'écoulement n'est jamais datée à la
// minute près — deux dates se comparent par leur calendrier, jamais par une
// durée absolue en instants. `now` est un paramètre, comme pour
// freshnessOf — même parade pour un âge négatif.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';

void main() {
  group("Age d'une campagne ONDE (BR-010, T-08)", () {
    test('campaignAgeInDays(2026-08-25 -> 2026-09-13) vaut 19 jours, '
        'récente', () {
      final DateTime observedAt = DateTime.utc(2026, 8, 25);
      final DateTime now = DateTime.utc(2026, 9, 13);

      expect(campaignAgeInDays(observedAt: observedAt, now: now), 19);
      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });

    test('59 jours est récente', () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.subtract(const Duration(days: 59));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });

    test('60 jours exactement est ancienne — la borne est la plus sévère', () {
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

    test('une observation datée dans le futur est récente : un âge négatif '
        "est une anomalie de la source, pas une donnée vieille", () {
      final DateTime now = DateTime.utc(2026, 9, 13);
      final DateTime observedAt = now.add(const Duration(days: 3));

      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.recente,
      );
    });

    test("l'âge se compte en jours calendaires, pas en durée absolue : 60 "
        'jours calendaires entre le 2026-01-29 et le 2026-03-30 restent '
        "ancienne même si la transition d'heure d'été de fin mars "
        'raccourcit la durée réelle écoulée (heure LOCALE, T-08)', () {
      final DateTime observedAt = DateTime(2026, 1, 29);
      final DateTime now = DateTime(2026, 3, 30, 0, 30);

      expect(campaignAgeInDays(observedAt: observedAt, now: now), 60);
      expect(
        campaignAgeOf(observedAt: observedAt, now: now),
        CampaignAge.ancienne,
      );
    });

    test("cas deterministe en UTC : l'ancien calcul en duree absolue rendait "
        '59 jours, quel que soit le fuseau — 2026-07-15T23:59Z vu le '
        '2026-09-13T00:01Z est bien 60 jours calendaires', () {
      final DateTime observedAt = DateTime.utc(2026, 7, 15, 23, 59);
      final DateTime now = DateTime.utc(2026, 9, 13, 0, 1);

      expect(campaignAgeInDays(observedAt: observedAt, now: now), 60);
    });
  });
}

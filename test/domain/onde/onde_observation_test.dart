// OndeCampaign et OndeObservation sont des classes immuables simples : la
// conversion depuis l'API (code_campagne int vs chaîne, T-07) vit dans le
// mapper de D3, pas ici. Ce test vérifie le port des champs, y compris
// rawFlowCode conservé tel que reçu même quand category est Inconnu
// (BR-011). Les valeurs de la campagne reprennent la première entrée de la
// fixture réelle `test/fixtures/onde/campagnes_departement_41_2026-09-13.json`
// : `nombre_modalite_ecoulement` y vaut 5 — le nombre de modalités de
// l'échelle d'écoulement du protocole, pas un nombre de points.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndeCampaign', () {
    test("porte les champs d'une campagne, relevés sur la campagne 109905", () {
      final OndeCampaign campaign = OndeCampaign(
        code: '109905',
        date: DateTime.utc(2026, 8, 25),
        rawTypeLabel: 'usuelle',
        modalityCount: 5,
      );

      expect(campaign.code, '109905');
      expect(campaign.date, DateTime.utc(2026, 8, 25));
      expect(campaign.rawTypeLabel, 'usuelle');
      expect(campaign.modalityCount, 5);
    });

    test('modalityCount est nullable — une absence', () {
      final OndeCampaign campaign = OndeCampaign(
        code: '109905',
        date: DateTime.utc(2026, 8, 25),
        rawTypeLabel: 'usuelle',
        modalityCount: null,
      );

      expect(campaign.modalityCount, isNull);
    });
  });

  group('OndeObservation (BR-011)', () {
    test("porte les champs d'une observation d'assec", () {
      final OndeObservation observation = OndeObservation(
        station: OndeStationCode('K4520001'),
        observedAt: DateTime.utc(2026, 8, 25),
        category: const Assec(),
        rawFlowCode: '3',
        officialLabel: 'Assec',
        campaignCode: '109905',
      );

      expect(observation.station, OndeStationCode('K4520001'));
      expect(observation.observedAt, DateTime.utc(2026, 8, 25));
      expect(observation.category, const Assec());
      expect(observation.rawFlowCode, '3');
      expect(observation.officialLabel, 'Assec');
      expect(observation.campaignCode, '109905');
    });

    test('rawFlowCode est conservé tel que reçu, non normalisé, même quand '
        'category est Inconnu', () {
      final OndeObservation observation = OndeObservation(
        station: OndeStationCode('K4520001'),
        observedAt: DateTime.utc(2026, 8, 25),
        category: const Inconnu('9Z'),
        rawFlowCode: '9Z',
        officialLabel: null,
        campaignCode: null,
      );

      expect(observation.category, const Inconnu('9Z'));
      expect(observation.rawFlowCode, '9Z');
      expect(observation.officialLabel, isNull);
      expect(observation.campaignCode, isNull);
    });
  });
}

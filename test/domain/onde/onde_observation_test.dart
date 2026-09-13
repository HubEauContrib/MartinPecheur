// OndeCampaign et OndeObservation sont des classes immuables simples : la
// conversion depuis l'API (code_campagne int vs chaine, T-07) vit dans le
// mapper de D3, pas ici. Ce test verifie le port des champs, y compris
// rawFlowCode conserve tel que recu meme quand category est Inconnu
// (BR-011).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndeCampaign', () {
    test('porte les champs d\'une campagne', () {
      final OndeCampaign campaign = OndeCampaign(
        code: '109905',
        date: DateTime.utc(2026, 8, 25),
        rawTypeLabel: 'usuelle',
        modalityCount: 4150,
      );

      expect(campaign.code, '109905');
      expect(campaign.date, DateTime.utc(2026, 8, 25));
      expect(campaign.rawTypeLabel, 'usuelle');
      expect(campaign.modalityCount, 4150);
    });

    test('modalityCount est nullable — une absence, jamais un zero '
        '(BR-007)', () {
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
    test('porte les champs d\'une observation d\'assec', () {
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

    test('rawFlowCode est conserve tel que recu, non normalise, meme quand '
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

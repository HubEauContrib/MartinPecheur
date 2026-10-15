// Verrouille `VigicruesFloodVigilanceSource` et son transport (W2 de T4,
// cadrage § 6) : l'adresse finale appelee, la correspondance des echecs
// (la meme que celle de la source des restrictions), le delai propre de 20 s.
// Aucun appel reseau : `MockClient` sert des reponses preparees, l'attente de
// rejeu est injectee et n'attend pas.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/floods/vigicrues_endpoint.dart';
import 'package:martinpecheur/data/floods/vigicrues_flood_vigilance_source.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';

const String _fixturePath =
    'test/fixtures/vigicrues/'
    'infovigicru_extrait_territoire_8_2026-10-14.geojson';

VigicruesFloodVigilanceSource _source(MockClient mock) {
  return VigicruesFloodVigilanceSource(
    client: JsonHttpClient(
      httpClient: mock,
      jitter: () => 0,
      sleep: (Duration duree) async {},
      requestTimeout: vigicruesRequestTimeout,
    ),
  );
}

void main() {
  group('VigicruesFloodVigilanceSource', () {
    test('200 + fixture : 15 troncons, requete GET sur l adresse finale '
        'exactement', () async {
      final List<http.BaseRequest> requetes = <http.BaseRequest>[];
      final List<int> corps = File(_fixturePath).readAsBytesSync();
      final VigicruesFloodVigilanceSource source = _source(
        MockClient((http.Request requete) async {
          requetes.add(requete);
          return http.Response.bytes(corps, 200);
        }),
      );

      final FloodVigilanceMap carte = await source.current();

      expect(carte.sections, hasLength(15));
      expect(requetes, hasLength(1));
      expect(requetes.single.method, 'GET');
      expect(requetes.single.url, vigicruesInformationUri);
    });

    test('200 + corps HTML : VigilanceIllisible', () async {
      final VigicruesFloodVigilanceSource source = _source(
        MockClient((http.Request _) async => http.Response('<html>', 200)),
      );

      await expectLater(source.current(), throwsA(isA<VigilanceIllisible>()));
    });

    test('404 : VigilanceRefusee(statusCode: 404)', () async {
      final VigicruesFloodVigilanceSource source = _source(
        MockClient((http.Request _) async => http.Response('absent', 404)),
      );

      await expectLater(
        source.current(),
        throwsA(
          isA<VigilanceRefusee>().having(
            (VigilanceRefusee e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('500 a chaque tentative : VigilanceInjoignable', () async {
      int appels = 0;
      final VigicruesFloodVigilanceSource source = _source(
        MockClient((http.Request _) async {
          appels++;
          return http.Response('panne', 500);
        }),
      );

      await expectLater(source.current(), throwsA(isA<VigilanceInjoignable>()));
      expect(appels, 4);
    });

    test('ClientException : VigilanceInjoignable', () async {
      final VigicruesFloodVigilanceSource source = _source(
        MockClient((http.Request _) async {
          throw http.ClientException('coupure');
        }),
      );

      await expectLater(source.current(), throwsA(isA<VigilanceInjoignable>()));
    });

    test('200 + FeatureCollection vide sans date : VigilanceIllisible '
        '(BR-001)', () async {
      final VigicruesFloodVigilanceSource source = _source(
        MockClient(
          (http.Request _) async =>
              http.Response('{"type":"FeatureCollection","features":[]}', 200),
        ),
      );

      await expectLater(source.current(), throwsA(isA<VigilanceIllisible>()));
    });
  });

  group('vigicruesJsonClient', () {
    test('porte le delai propre de Vigicrues', () {
      final JsonHttpClient client = vigicruesJsonClient(
        MockClient((http.Request _) async => http.Response('{}', 200)),
      );

      expect(client.requestTimeout, vigicruesRequestTimeout);
    });

    test('vigicruesRequestTimeout vaut 20 s (2,2 Mo non compresses)', () {
      expect(vigicruesRequestTimeout, const Duration(seconds: 20));
    });
  });
}

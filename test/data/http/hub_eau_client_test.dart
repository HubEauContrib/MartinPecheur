// Verrouille le client de l'API hydrométrie v2 : les URI qu'il construit
// (C-04, C-05, C-08), la distinction succès/échec du domaine HTTP (C-06,
// C-12), et les trois pannes que distingue HubEauFailure. Aucun appel ne
// touche l'API réelle : http.testing.MockClient sert des réponses
// préparées, et l'attente entre tentatives est injectée pour ne jamais
// dormir — delayForAttempt lui-même reste vérifié seul dans retry_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';

void main() {
  final StationCode station = StationCode('K447001001');
  final Uri cible = Uri.parse(
    'https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr',
  );

  group('observationsTrUri (C-05, C-08)', () {
    test('construit host, chemin, code_entite, grandeur_hydro et size', () {
      final Uri uri = observationsTrUri(
        station: station,
        grandeur: Grandeur.debit,
        size: 2,
      );

      expect(uri.host, 'hubeau.eaufrance.fr');
      expect(uri.path, '/api/v2/hydrometrie/observations_tr');
      expect(uri.queryParameters['code_entite'], 'K447001001');
      expect(uri.queryParameters['grandeur_hydro'], 'Q');
      expect(uri.queryParameters['size'], '2');
    });

    test('Grandeur.inconnu lève : on ne demande jamais la grandeur qu\'on ne '
        'sait pas lire (BR-007)', () {
      expect(
        () => observationsTrUri(station: station, grandeur: Grandeur.inconnu),
        throwsArgumentError,
      );
    });

    test('size au-delà de maxPageSize lève (C-08)', () {
      expect(
        () => observationsTrUri(
          station: station,
          grandeur: Grandeur.debit,
          size: 20001,
        ),
        throwsArgumentError,
      );
    });
  });

  group('obsElabUri (C-04)', () {
    test('date_debut_obs_elab est requis, formaté AAAA-MM-JJ en UTC, avec '
        'grandeur_hydro_elab=QmnJ', () {
      final Uri uri = obsElabUri(
        station: station,
        since: DateTime.utc(2026, 8),
      );

      expect(uri.path, '/api/v2/hydrometrie/obs_elab');
      expect(uri.queryParameters['date_debut_obs_elab'], '2026-08-01');
      expect(uri.queryParameters['grandeur_hydro_elab'], 'QmnJ');
    });
  });

  group('referentielStationUri', () {
    test('construit le chemin du référentiel et code_station', () {
      final Uri uri = referentielStationUri(station);

      expect(uri.path, '/api/v2/hydrometrie/referentiel/stations');
      expect(uri.queryParameters['code_station'], 'K447001001');
    });
  });

  group('HubEauClient.getJson — succès (C-06)', () {
    test('200 décode le corps, aucune attente enregistrée', () async {
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, int>{'count': 1}), 200);
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        sleep: (Duration duree) async {
          attentes.add(duree);
        },
      );

      final Map<String, dynamic> corps = await client.getJson(cible);

      expect(corps['count'], 1);
      expect(attentes, isEmpty);
    });

    test('206 est décodé comme un 200 (C-06)', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, int>{'count': 2}), 206);
      });
      final HubEauClient client = HubEauClient(httpClient: mock);

      final Map<String, dynamic> corps = await client.getJson(cible);

      expect(corps['count'], 2);
    });

    test(
      "l'en-tête Accept: application/json est reçu par le MockClient",
      () async {
        String? accept;
        final http.Client mock = MockClient((http.Request request) async {
          accept = request.headers['Accept'];
          return http.Response(jsonEncode(<String, int>{}), 200);
        });
        final HubEauClient client = HubEauClient(httpClient: mock);

        await client.getJson(cible);

        expect(accept, 'application/json');
      },
    );
  });

  group('HubEauClient.getJson — recul exponentiel (C-12)', () {
    test(
      '503 deux fois puis 200 : 3 appels, attentes [500 ms, 1000 ms]',
      () async {
        int appels = 0;
        final List<Duration> attentes = <Duration>[];
        final http.Client mock = MockClient((http.Request request) async {
          appels++;
          if (appels <= 2) {
            return http.Response('service indisponible', 503);
          }
          return http.Response(jsonEncode(<String, int>{'count': 0}), 200);
        });
        final HubEauClient client = HubEauClient(
          httpClient: mock,
          jitter: () => 0,
          sleep: (Duration duree) async {
            attentes.add(duree);
          },
        );

        await client.getJson(cible);

        expect(appels, 3);
        expect(attentes, <Duration>[
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 1000),
        ]);
      },
    );

    test('429 puis 200 : 2 appels', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        if (appels == 1) {
          return http.Response('trop de requêtes', 429);
        }
        return http.Response(jsonEncode(<String, int>{'count': 0}), 200);
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        jitter: () => 0,
        sleep: (Duration duree) async {},
      );

      await client.getJson(cible);

      expect(appels, 2);
    });

    test(
      '503 constant, maxAttempts 4 : 4 appels, 3 attentes, puis échec',
      () async {
        int appels = 0;
        final List<Duration> attentes = <Duration>[];
        final http.Client mock = MockClient((http.Request request) async {
          appels++;
          return http.Response('service indisponible', 503);
        });
        final HubEauClient client = HubEauClient(
          httpClient: mock,
          maxAttempts: 4,
          jitter: () => 0,
          sleep: (Duration duree) async {
            attentes.add(duree);
          },
        );

        await expectLater(client.getJson(cible), throwsA(isA<HubEauFailure>()));

        expect(appels, 4);
        expect(attentes.length, 3);
      },
    );
  });

  group('HubEauClient.getJson — pannes non rejouables', () {
    test('400 échoue immédiatement, 1 appel, aucune attente', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response(
          jsonEncode(<String, String>{'message': 'ValidatePageSize'}),
          400,
        );
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        sleep: (Duration duree) async {
          attentes.add(duree);
        },
      );

      await expectLater(client.getJson(cible), throwsA(isA<HubEauFailure>()));

      expect(appels, 1);
      expect(attentes, isEmpty);
    });

    test('403 échoue immédiatement, 1 appel (C-01)', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('interdit', 403);
      });
      final HubEauClient client = HubEauClient(httpClient: mock);

      await expectLater(client.getJson(cible), throwsA(isA<HubEauFailure>()));

      expect(appels, 1);
    });
  });

  group('HubEauClient.getJson — trois pannes distinguées', () {
    test('une panne réseau répétée porte le message de l\'exception', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        throw http.ClientException('connexion perdue');
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        maxAttempts: 3,
        jitter: () => 0,
        sleep: (Duration duree) async {},
      );

      await expectLater(
        client.getJson(cible),
        throwsA(
          isA<HubEauFailure>().having(
            (HubEauFailure echec) => echec.message,
            'message',
            contains('connexion perdue'),
          ),
        ),
      );
      expect(appels, 3);
    });

    test('un corps illisible malgré un succès 206 porte "illisible" dans le '
        'message', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response('{tronq', 206);
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        maxAttempts: 2,
        jitter: () => 0,
        sleep: (Duration duree) async {},
      );

      await expectLater(
        client.getJson(cible),
        throwsA(
          isA<HubEauFailure>().having(
            (HubEauFailure echec) => echec.message,
            'message',
            contains('illisible'),
          ),
        ),
      );
    });

    test('un corps JSON qui est un tableau échoue immédiatement', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response('[1,2,3]', 200);
      });
      final HubEauClient client = HubEauClient(
        httpClient: mock,
        maxAttempts: 1,
      );

      await expectLater(client.getJson(cible), throwsA(isA<HubEauFailure>()));
    });
  });

  group('HubEauClient.close', () {
    test('close() est appelable sans lever', () {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('{}', 200),
      );
      final HubEauClient client = HubEauClient(httpClient: mock);

      expect(client.close, returnsNormally);
    });
  });

  group('Fixture réelle (2026-09-13)', () {
    test("la fixture observations_tr K447001001 Q servie par le MockClient "
        'se décode', () async {
      final String fixture = File(
        'test/fixtures/hubeau/observations_tr_K447001001_Q_2026-09-13.json',
      ).readAsStringSync();
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(fixture, 200);
      });
      final HubEauClient client = HubEauClient(httpClient: mock);

      final Map<String, dynamic> corps = await client.getJson(
        observationsTrUri(station: station, grandeur: Grandeur.debit, size: 2),
      );

      expect(corps['count'], 206);
      final List<dynamic> lignes = corps['data'] as List<dynamic>;
      final Map<String, dynamic> premiere = lignes[0] as Map<String, dynamic>;
      expect(premiere['resultat_obs'], 47800.0);
    });
  });
}

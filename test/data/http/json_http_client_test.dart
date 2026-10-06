// Verrouille le transport JSON à rejeu extrait de HubEauClient (D1 de T2) :
// une racine tableau ou objet rendue telle quelle, la distinction succès/échec
// du domaine HTTP (C-06, C-12), le plafond de tentatives et la gigue injectée
// (NFR-07), et les trois échecs typés — statut, panne réseau, corps illisible.
// Aucun appel ne touche une API réelle : http.testing.MockClient sert des
// réponses préparées, et l'attente entre tentatives est injectée pour ne
// jamais dormir — delayForAttempt lui-même reste vérifié seul dans
// retry_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/data/http/retry.dart';

/// Un minuteur créé pendant l'exécution espionnée, avec la durée demandée.
typedef _Minuteur = ({Duration duree, Timer minuteur});

/// Exécute [corps] dans une zone qui note chaque minuteur créé. Avec
/// [declencherAussitot], le minuteur part tout de suite au lieu d'attendre sa
/// durée : le test voit la durée réellement demandée (10 s par défaut) sans
/// l'attendre.
Future<T> _espionnerMinuteurs<T>(
  Future<T> Function() corps,
  List<_Minuteur> minuteurs, {
  bool declencherAussitot = false,
}) {
  return runZoned(
    corps,
    zoneSpecification: ZoneSpecification(
      createTimer:
          (
            Zone self,
            ZoneDelegate parent,
            Zone zone,
            Duration duree,
            void Function() action,
          ) {
            final Timer minuteur = parent.createTimer(
              zone,
              declencherAussitot ? Duration.zero : duree,
              action,
            );
            minuteurs.add((duree: duree, minuteur: minuteur));
            return minuteur;
          },
    ),
  );
}

void main() {
  final Uri cible = Uri.parse('https://exemple.test/api/ressource');

  JsonHttpClient clientSur(
    http.Client mock, {
    List<Duration>? attentes,
    int maxAttempts = 4,
    double Function()? jitter,
    Duration? requestTimeout,
  }) {
    return JsonHttpClient(
      httpClient: mock,
      maxAttempts: maxAttempts,
      jitter: jitter ?? () => 0,
      sleep: (Duration duree) async {
        attentes?.add(duree);
      },
      requestTimeout: requestTimeout ?? defaultRequestTimeout,
    );
  }

  group('JsonHttpClient.getJson — racine du corps', () {
    test('une racine tableau est rendue telle quelle, en List', () async {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('[{"a":1},{"a":2}]', 200),
      );

      final Object? corps = await clientSur(mock).getJson(cible);

      expect(corps, isA<List<dynamic>>());
      expect(corps, <Object>[
        <String, Object>{'a': 1},
        <String, Object>{'a': 2},
      ]);
    });

    test('une racine objet est rendue en Map', () async {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('{"count":0}', 200),
      );

      final Object? corps = await clientSur(mock).getJson(cible);

      expect(corps, isA<Map<String, dynamic>>());
      expect(corps, <String, Object>{'count': 0});
    });

    test('206 est un succès (C-06)', () async {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('[]', 206),
      );

      expect(await clientSur(mock).getJson(cible), isEmpty);
    });

    test("204 n'est pas un succès : échec de statut, sans rejeu", () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('', 204);
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpStatusFailure>().having(
            (JsonHttpStatusFailure echec) => echec.statusCode,
            'statusCode',
            204,
          ),
        ),
      );
      expect(appels, 1);
      expect(attentes, isEmpty);
    });
  });

  group('JsonHttpClient.getJson — rejeu (C-12, NFR-07)', () {
    test('429 puis 200 : succès après une seule attente', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return appels == 1
            ? http.Response('trop de requetes', 429)
            : http.Response('[]', 200);
      });

      await clientSur(mock, attentes: attentes).getJson(cible);

      expect(appels, 2);
      expect(attentes.length, 1);
    });

    test('503 × 4 : JsonHttpStatusFailure(503) après trois attentes', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('service indisponible', 503);
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpStatusFailure>()
              .having(
                (JsonHttpStatusFailure echec) => echec.statusCode,
                'statusCode',
                503,
              )
              .having(
                (JsonHttpStatusFailure echec) => echec.message,
                'message',
                'statut 503 : service indisponible',
              ),
        ),
      );
      expect(appels, 4);
      expect(attentes.length, 3);
    });

    test('le plafond par défaut est de quatre tentatives (NFR-07)', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('panne', 500);
      });
      final JsonHttpClient client = JsonHttpClient(
        httpClient: mock,
        jitter: () => 0,
        sleep: (Duration duree) async {},
      );

      await expectLater(
        client.getJson(cible),
        throwsA(isA<JsonHttpStatusFailure>()),
      );
      expect(appels, 4);
    });

    test('400 : JsonHttpStatusFailure(400) immédiat, zéro attente', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('requete invalide', 400);
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpStatusFailure>()
              .having(
                (JsonHttpStatusFailure echec) => echec.statusCode,
                'statusCode',
                400,
              )
              .having(
                (JsonHttpStatusFailure echec) => echec.body,
                'body',
                'requete invalide',
              ),
        ),
      );
      expect(appels, 1);
      expect(attentes, isEmpty);
    });

    test('la gigue injectée est transmise à delayForAttempt', () async {
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('panne', 503),
      );

      await expectLater(
        clientSur(mock, attentes: attentes, jitter: () => 0.5).getJson(cible),
        throwsA(isA<JsonHttpStatusFailure>()),
      );

      expect(attentes, <Duration>[
        delayForAttempt(0, jitter: () => 0.5),
        delayForAttempt(1, jitter: () => 0.5),
        delayForAttempt(2, jitter: () => 0.5),
      ]);
      expect(attentes, const <Duration>[
        Duration(milliseconds: 750),
        Duration(milliseconds: 1500),
        Duration(milliseconds: 3000),
      ]);
    });

    test('maxAttempts < 1 lève ArgumentError au constructeur', () {
      expect(
        () => JsonHttpClient(
          httpClient: MockClient(
            (http.Request request) async => http.Response('[]', 200),
          ),
          maxAttempts: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('JsonHttpClient.getJson — pannes réseau', () {
    test('ClientException rejouée, puis JsonHttpNetworkFailure', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        throw http.ClientException('connexion perdue');
      });

      await expectLater(
        clientSur(mock, attentes: attentes, maxAttempts: 3).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            'panne réseau : connexion perdue',
          ),
        ),
      );
      expect(appels, 3);
      expect(attentes.length, 2);
    });

    test('un client déjà fermé échoue immédiatement, sans rejeu', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        throw http.ClientException('Client is already closed.');
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            'client HTTP déjà fermé, non rejouable : '
                'Client is already closed.',
          ),
        ),
      );
      expect(appels, 1);
      expect(attentes, isEmpty);
    });

    test('une HandshakeException est rejouée comme une panne réseau', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        throw const HandshakeException('poignee de main');
      });

      await expectLater(
        clientSur(mock, maxAttempts: 3).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            allOf(startsWith('panne réseau : '), contains('poignee de main')),
          ),
        ),
      );
      expect(appels, 3);
    });

    test('une FormatException levée par le transport (gzip corrompu, '
        'redirection mal formée) est une panne rejouable : maxAttempts '
        'appels, puis JsonHttpNetworkFailure, jamais une FormatException '
        'nue', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        throw const FormatException('Filter error, bad data');
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            allOf(
              startsWith('réponse corrompue pendant le transfert : '),
              contains('Filter error, bad data'),
            ),
          ),
        ),
      );
      expect(appels, 4);
      expect(attentes.length, 3);
    });

    test('une FormatException du transport puis une réponse saine : le JSON '
        'est rendu après une attente', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        if (appels == 1) {
          throw const FormatException('Filter error, bad data');
        }
        return http.Response('{"ok":true}', 200);
      });

      final Object? corps = await clientSur(
        mock,
        attentes: attentes,
      ).getJson(cible);

      expect(corps, <String, Object>{'ok': true});
      expect(appels, 2);
      expect(attentes.length, 1);
    });
  });

  group('JsonHttpClient.getJson — délai d\'attente par tentative', () {
    const Duration delaiCourt = Duration(milliseconds: 20);

    test('une réponse qui n\'arrive jamais : maxAttempts tentatives, les '
        'attentes de rejeu entre elles, puis JsonHttpNetworkFailure', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) {
        appels++;
        return Completer<http.Response>().future;
      });

      await expectLater(
        clientSur(
          mock,
          attentes: attentes,
          requestTimeout: delaiCourt,
        ).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            'délai d\'attente de 20 ms dépassé',
          ),
        ),
      );
      expect(appels, 4);
      expect(attentes, const <Duration>[
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 2000),
      ]);
    });

    test('le corps qui ne finit jamais d\'arriver est borné lui aussi : 4 '
        'tentatives puis JsonHttpNetworkFailure', () async {
      // Les en-têtes arrivent (statut 200), le corps jamais : le flux reste
      // ouvert. `Client.get` lit le corps avant de rendre sa réponse
      // (`Response.fromStream`), donc le délai couvre aussi cette lecture.
      int appels = 0;
      final List<StreamController<List<int>>> corps =
          <StreamController<List<int>>>[];
      addTearDown(() {
        for (final StreamController<List<int>> flux in corps) {
          unawaited(flux.close());
        }
      });
      final http.Client mock = MockClient.streaming((
        http.BaseRequest request,
        http.ByteStream bodyStream,
      ) async {
        appels++;
        final StreamController<List<int>> flux = StreamController<List<int>>();
        corps.add(flux);
        return http.StreamedResponse(flux.stream, 200);
      });

      await expectLater(
        clientSur(
          mock,
          requestTimeout: const Duration(milliseconds: 20),
        ).getJson(cible),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            'délai d\'attente de 20 ms dépassé',
          ),
        ),
      );
      expect(appels, 4);
    });

    test('première tentative pendue, seconde qui répond : le JSON est rendu '
        'après une attente', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) {
        appels++;
        if (appels == 1) {
          return Completer<http.Response>().future;
        }
        return Future<http.Response>.value(http.Response('{"ok":true}', 200));
      });

      final Object? corps = await clientSur(
        mock,
        attentes: attentes,
        requestTimeout: delaiCourt,
      ).getJson(cible);

      expect(corps, <String, Object>{'ok': true});
      expect(appels, 2);
      expect(attentes, const <Duration>[Duration(milliseconds: 500)]);
    });

    test('le résultat tardif de la tentative abandonnée est ignoré, sans '
        'erreur non gérée', () async {
      int appels = 0;
      final Completer<http.Response> tardive = Completer<http.Response>();
      final http.Client mock = MockClient((http.Request request) {
        appels++;
        if (appels == 1) {
          return tardive.future;
        }
        return Future<http.Response>.value(http.Response('{"ok":true}', 200));
      });

      final Object? corps = await clientSur(
        mock,
        requestTimeout: delaiCourt,
      ).getJson(cible);
      tardive.completeError(http.ClientException('réponse tardive'));
      // Laisse l'erreur tardive atteindre ses écouteurs : une erreur non
      // gérée ferait échouer ce test (zone d'erreur du test).
      await Future<void>.delayed(Duration.zero);

      expect(corps, <String, Object>{'ok': true});
      expect(appels, 2);
    });

    test('une réponse qui arrive avant le délai n\'est pas touchée, et le '
        'minuteur ne reste pas pendant', () async {
      final List<_Minuteur> minuteurs = <_Minuteur>[];
      final http.Client mock = MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{"ok":true}', 200);
      });

      final Object? corps = await _espionnerMinuteurs(
        () => clientSur(
          mock,
          requestTimeout: const Duration(seconds: 5),
        ).getJson(cible),
        minuteurs,
      );

      expect(corps, <String, Object>{'ok': true});
      expect(
        minuteurs.map((_Minuteur m) => m.duree),
        contains(const Duration(seconds: 5)),
        reason: 'le délai d\'attente a bien été armé',
      );
      expect(
        minuteurs.every((_Minuteur m) => !m.minuteur.isActive),
        isTrue,
        reason: 'aucun minuteur ne reste actif une fois la réponse reçue',
      );
    });

    test('par défaut, chaque tentative est bornée à 10 s (arbitrage du '
        'commanditaire, 2026-10-06)', () async {
      int appels = 0;
      final List<_Minuteur> minuteurs = <_Minuteur>[];
      final http.Client mock = MockClient((http.Request request) {
        appels++;
        return Completer<http.Response>().future;
      });
      final JsonHttpClient client = JsonHttpClient(
        httpClient: mock,
        jitter: () => 0,
        sleep: (Duration duree) async {},
      );

      await expectLater(
        _espionnerMinuteurs(
          () => client.getJson(cible),
          minuteurs,
          declencherAussitot: true,
        ),
        throwsA(
          isA<JsonHttpNetworkFailure>().having(
            (JsonHttpNetworkFailure echec) => echec.message,
            'message',
            'délai d\'attente de 10 s dépassé',
          ),
        ),
      );

      expect(defaultRequestTimeout, const Duration(seconds: 10));
      expect(client.requestTimeout, defaultRequestTimeout);
      expect(appels, 4);
      expect(
        minuteurs.map((_Minuteur m) => m.duree).toList(),
        List<Duration>.filled(4, const Duration(seconds: 10)),
      );
    });
  });

  group('JsonHttpClient.getJson — corps illisible', () {
    test('200 non JSON : rejoué, puis JsonHttpUnreadableBody(200)', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('<html>', 200);
      });

      await expectLater(
        clientSur(mock, attentes: attentes, maxAttempts: 2).getJson(cible),
        throwsA(
          isA<JsonHttpUnreadableBody>()
              .having(
                (JsonHttpUnreadableBody echec) => echec.statusCode,
                'statusCode',
                200,
              )
              .having(
                (JsonHttpUnreadableBody echec) => echec.message,
                'message',
                startsWith('corps illisible (statut 200) : '),
              ),
        ),
      );
      expect(appels, 2);
      expect(attentes.length, 1);
    });

    test('503 dont le corps n\'est pas de l\'UTF-8 (FF FE FD) : rejoué, puis '
        'JsonHttpStatusFailure(503), jamais une FormatException nue', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response.bytes(<int>[0xFF, 0xFE, 0xFD], 503);
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpStatusFailure>().having(
            (JsonHttpStatusFailure echec) => echec.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
      expect(appels, 4);
      expect(attentes.length, 3);
    });

    test('400 dont le corps n\'est pas de l\'UTF-8 (FF FE FD) : '
        'JsonHttpStatusFailure(400) immédiat, sans rejeu', () async {
      int appels = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response.bytes(<int>[0xFF, 0xFE, 0xFD], 400);
      });

      await expectLater(
        clientSur(mock, attentes: attentes).getJson(cible),
        throwsA(
          isA<JsonHttpStatusFailure>().having(
            (JsonHttpStatusFailure echec) => echec.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
      expect(appels, 1);
      expect(attentes, isEmpty);
    });

    test('un 200 dont le corps n\'est pas de l\'UTF-8 reste un corps '
        'illisible : le décodage de succès est strict', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        // `["\xFF"]` : un tableau JSON valide une fois l'octet FF décodé avec
        // tolérance (en caractère de remplacement U+FFFD). Seul un décodage
        // strict le refuse — des octets qui ne sont pas du JSON même tolérés
        // (FF FE FD) ne distingueraient pas les deux décodages.
        return http.Response.bytes(<int>[0x5B, 0x22, 0xFF, 0x22, 0x5D], 200);
      });

      await expectLater(
        clientSur(mock, maxAttempts: 2).getJson(cible),
        throwsA(isA<JsonHttpUnreadableBody>()),
      );
      expect(appels, 2);
    });
  });

  group('JsonHttpClient.getJson — requête et décodage', () {
    test(
      'sans charset, "Pré-validée" se décode en UTF-8, pas en latin1',
      () async {
        final http.Client mock = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode('[{"libelle":"Pré-validée"}]'),
            200,
          );
        });

        final Object? corps = await clientSur(mock).getJson(cible);

        final List<dynamic> lignes = corps! as List<dynamic>;
        final Map<String, dynamic> premiere = lignes[0] as Map<String, dynamic>;
        expect(premiere['libelle'], 'Pré-validée');
      },
    );

    test("l'en-tête Accept: application/json est envoyé", () async {
      String? accept;
      final http.Client mock = MockClient((http.Request request) async {
        accept = request.headers['Accept'];
        return http.Response('{}', 200);
      });

      await clientSur(mock).getJson(cible);

      expect(accept, 'application/json');
    });
  });

  group('JsonHttpClient.close', () {
    test('close() ferme le client sous-jacent, une fois', () {
      final _ClientEspion espion = _ClientEspion();
      final JsonHttpClient client = clientSur(espion);

      client.close();

      expect(espion.fermetures, 1);
    });
  });

  group('Une seule boucle de rejeu dans lib/data/http/', () {
    test('"for (int attempt" n\'apparaît qu\'une fois, dans '
        'json_http_client.dart', () {
      final List<String> porteurs = <String>[];
      int occurrences = 0;
      for (final FileSystemEntity entite in Directory(
        'lib/data/http',
      ).listSync()) {
        if (entite is! File || !entite.path.endsWith('.dart')) {
          continue;
        }
        final int ici = 'for (int attempt'
            .allMatches(entite.readAsStringSync())
            .length;
        if (ici > 0) {
          occurrences += ici;
          porteurs.add(entite.uri.pathSegments.last);
        }
      }

      expect(occurrences, 1);
      expect(porteurs, <String>['json_http_client.dart']);
    });
  });
}

/// Client HTTP qui compte les appels à [close], pour prouver que
/// [JsonHttpClient.close] ferme bien le client qu'il a reçu.
final class _ClientEspion extends http.BaseClient {
  int fermetures = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError('aucun envoi attendu');
  }

  @override
  void close() {
    fermetures++;
  }
}

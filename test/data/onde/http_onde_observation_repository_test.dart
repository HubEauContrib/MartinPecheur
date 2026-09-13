// Verrouille HttpOndeObservationRepository : la lecture ONDE par emprise et
// par station, adossée au client Hub'Eau déjà verrouillé
// (`hub_eau_client_test.dart`) et au mapper déjà verrouillé
// (`onde_observation_mapper_test.dart`). L'invariant propre à ce dépôt, non
// couvert ailleurs, est le regroupement d'une observation par station dans
// `latestWithinBounds` : l'API rend une ligne par campagne et par point
// (T-04, `count` 96 pour la seule station K4520001), et une liste
// désordonnée prouve que le regroupement compare les dates plutôt que de se
// fier à `sort=desc`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/onde/http_onde_observation_repository.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

String _readFixture(String path) =>
    File('test/fixtures/onde/$path').readAsStringSync();

void main() {
  final Bounds bounds = Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8);
  final DateTime since = DateTime.utc(2026, 7, 15);

  group('latestWithinBounds — fixture réelle (2026-09-13)', () {
    test('une seule observation par code de station, la plus récente ; '
        "l'URI porte bbox et date_observation_min", () async {
      http.Request? capturedRequest;
      final http.Client mock = MockClient((http.Request request) async {
        capturedRequest = request;
        final String fixture = _readFixture(
          'observations_bbox_loire_2026-09-13.json',
        );
        return http.Response.bytes(utf8.encode(fixture), 200);
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      final List<OndeObservation> observations = await repository
          .latestWithinBounds(bounds, since: since);

      // La fixture porte trente lignes pour quinze codes de station
      // distincts (deux campagnes chacun) — constaté par
      // `grep -o '"code_station":"[^"]*"' … | sort -u`.
      expect(observations, hasLength(15));
      expect(
        observations.map((OndeObservation o) => o.station).toSet(),
        hasLength(15),
      );

      final OndeObservation k4640001 = observations.singleWhere(
        (OndeObservation o) => o.station == OndeStationCode('K4640001'),
      );
      expect(k4640001.observedAt, DateTime.utc(2026, 8, 25));
      // Le point est porté par l'observation (D8), lu sur la même ligne —
      // première ligne de la fixture bbox pour ce code de station.
      expect(k4640001.point.latitude, closeTo(47.444182169, 1e-9));
      expect(k4640001.point.longitude, closeTo(1.78116675, 1e-9));

      final Uri? uri = capturedRequest?.url;
      expect(uri?.path, '/api/v1/ecoulement/observations');
      expect(uri?.queryParameters['bbox'], '1.0,47.3,1.8,47.8');
      expect(uri?.queryParameters['date_observation_min'], '2026-07-15');
    });
  });

  group('latestWithinBounds — regroupement par date, pas par ordre (T-04)', () {
    test('deux lignes pour le même code, la plus récente en second : '
        "l'entrée retenue est la plus récente", () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'count': 2,
            'data': <Object?>[
              <String, Object?>{
                'code_station': 'A1234567',
                'date_observation': '2026-01-01',
                'code_ecoulement': '3',
                'latitude': 47.5,
                'longitude': 1.5,
              },
              <String, Object?>{
                'code_station': 'A1234567',
                'date_observation': '2026-06-01',
                'code_ecoulement': '1a',
                'latitude': 47.5,
                'longitude': 1.5,
              },
            ],
          }),
          200,
        );
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      final List<OndeObservation> observations = await repository
          .latestWithinBounds(bounds, since: since);

      expect(observations, hasLength(1));
      expect(observations.single.observedAt, DateTime.utc(2026, 6, 1));
    });
  });

  group('latestWithinBounds — absence (BR-007, UC-001 A5)', () {
    test('{"count":0,"data":[]} en 200 rend une liste vide, jamais une '
        'erreur', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'count': 0, 'data': <Object?>[]}),
          200,
        );
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      final List<OndeObservation> observations = await repository
          .latestWithinBounds(bounds, since: since);

      expect(observations, isEmpty);
    });
  });

  group('latestWithinBounds — panne de source (UC-001 A4)', () {
    test('503 sur toutes les tentatives : HubEauFailure propagée, le test '
        'ne dort pas', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('service indisponible', 503);
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(
            HubEauClient(
              httpClient: mock,
              maxAttempts: 2,
              jitter: () => 0,
              sleep: (Duration duree) async {},
            ),
          );

      await expectLater(
        repository.latestWithinBounds(bounds, since: since),
        throwsA(isA<HubEauFailure>()),
      );
      expect(appels, 2);
    });
  });

  group('latestWithinBounds — corps inattendu (UC-001 A4)', () {
    test('data absent (clé manquante) : FormatException, pas une liste '
        'vide', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, Object?>{'count': 0}), 200);
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.latestWithinBounds(bounds, since: since),
        throwsA(isA<FormatException>()),
      );
    });

    test("une ligne sans date_observation : la FormatException du mapper "
        'est propagée, pas avalée', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'count': 1,
            'data': <Object?>[
              <String, Object?>{'code_station': 'A1234567'},
            ],
          }),
          200,
        );
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.latestWithinBounds(bounds, since: since),
        throwsA(isA<FormatException>()),
      );
    });

    test("data d'un type inattendu (un entier) : FormatException", () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, Object?>{'data': 3}), 200);
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.latestWithinBounds(bounds, since: since),
        throwsA(isA<FormatException>()),
      );
    });

    test("une ligne de data qui n'est pas un objet (un entier) : "
        'FormatException', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <Object?>[1],
          }),
          200,
        );
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.latestWithinBounds(bounds, since: since),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('historyFor — tri et troncature côté client', () {
    test('trois lignes désordonnées, limit:2 : triées décroissantes PUIS '
        'tronquées — la troncature vient après le tri, pas avant', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'count': 3,
            'data': <Object?>[
              <String, Object?>{
                'code_station': 'A1234567',
                'date_observation': '2026-01-01',
                'code_ecoulement': '3',
                'latitude': 47.5,
                'longitude': 1.5,
              },
              <String, Object?>{
                'code_station': 'A1234567',
                'date_observation': '2026-06-01',
                'code_ecoulement': '1a',
                'latitude': 47.5,
                'longitude': 1.5,
              },
              <String, Object?>{
                'code_station': 'A1234567',
                'date_observation': '2026-03-01',
                'code_ecoulement': '2',
                'latitude': 47.5,
                'longitude': 1.5,
              },
            ],
          }),
          200,
        );
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      final List<OndeObservation> observations = await repository.historyFor(
        OndeStationCode('A1234567'),
        limit: 2,
      );

      expect(observations, hasLength(2));
      expect(observations[0].observedAt, DateTime.utc(2026, 6, 1));
      expect(observations[1].observedAt, DateTime.utc(2026, 3, 1));
    });
  });

  group('historyFor — fixture réelle (2026-09-13)', () {
    test('au plus 5 observations, décroissantes en date, la première '
        '2026-08-25 (T-04) ; le mock reçoit code_station et size', () async {
      http.Request? capturedRequest;
      final http.Client mock = MockClient((http.Request request) async {
        capturedRequest = request;
        final String fixture = _readFixture(
          'observations_station_K4520001_2026-09-13.json',
        );
        return http.Response.bytes(utf8.encode(fixture), 206);
      });
      final HttpOndeObservationRepository repository =
          HttpOndeObservationRepository(HubEauClient(httpClient: mock));

      final List<OndeObservation> observations = await repository.historyFor(
        OndeStationCode('K4520001'),
        limit: 5,
      );

      // La fixture porte dix lignes (`count` 96, dix retenues par la
      // capture) : le dépôt tronque à `limit` côté client, l'API n'ayant
      // reçu que `size=5` sans garantie qu'elle le respecte à la lettre.
      expect(observations, hasLength(5));
      expect(observations.first.observedAt, DateTime.utc(2026, 8, 25));
      for (int i = 1; i < observations.length; i++) {
        expect(
          observations[i - 1].observedAt.isAfter(observations[i].observedAt),
          isTrue,
        );
      }

      final Uri? uri = capturedRequest?.url;
      expect(uri?.queryParameters['code_station'], 'K4520001');
      expect(uri?.queryParameters['size'], '5');
    });
  });
}

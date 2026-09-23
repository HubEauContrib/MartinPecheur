// Verrouille HttpHydroObservationRepository : la dernière observation
// connue pour une station et une grandeur, adossée au client Hub'Eau v2 déjà
// verrouillé (`hub_eau_client_test.dart`) et au mapper déjà verrouillé
// (`hydro_observation_mapper_test.dart`). Rien n'est retesté ici sur la
// forme de l'URI ou la conversion d'unité (BR-002) : seule la composition
// des deux est vérifiée, plus les invariants propres au dépôt — une absence
// rend `null` (BR-007), une panne de source lève, qu'elle vienne du client
// (`HubEauFailure`) ou d'un corps inattendu que le mapper ou ce dépôt ne
// savent pas lire (`FormatException`).
//
// Pas de findLatestForAll : amendement du 2026-09-13 (voir le plan T1,
// tâche D5) — le préchargement borné et annulable vit dans MapViewModel
// (V2), qui appelle findLatest station par station.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/observations/http_hydro_observation_repository.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

String _readFixture(String path) =>
    File('test/fixtures/hubeau/$path').readAsStringSync();

void main() {
  final StationCode station = StationCode('K447001001');

  group('findLatest — fixtures réelles (2026-09-13)', () {
    test('débit (Q) : discharge converti, measuredAt UTC, size=1 demande '
        'la ligne la plus récente', () async {
      http.Request? capturedRequest;
      final http.Client mock = MockClient((http.Request request) async {
        capturedRequest = request;
        final String fixture = _readFixture(
          'observations_tr_K447001001_Q_2026-09-13.json',
        );
        return http.Response.bytes(utf8.encode(fixture), 206);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      final HydroObservation? observation = await repository.findLatest(
        station,
        Grandeur.debit,
      );

      expect(observation, isNotNull);
      expect(observation!.discharge, const CubicMetresPerSecond(47.8));
      expect(observation.measuredAt, DateTime.utc(2026, 8, 27, 8));

      final Uri? uri = capturedRequest?.url;
      expect(uri?.path, '/api/v2/hydrometrie/observations_tr');
      expect(uri?.queryParameters['code_entite'], 'K447001001');
      expect(uri?.queryParameters['grandeur_hydro'], 'Q');
      expect(uri?.queryParameters['size'], '1');
    });

    test('hauteur (H) : level converti, signe conservé, aucun contrôle '
        'ajouté, et grandeur_hydro=H dans la requête reçue', () async {
      http.Request? capturedRequest;
      final http.Client mock = MockClient((http.Request request) async {
        capturedRequest = request;
        final String fixture = _readFixture(
          'observations_tr_K447001001_H_2026-09-13.json',
        );
        return http.Response.bytes(utf8.encode(fixture), 206);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      final HydroObservation? observation = await repository.findLatest(
        station,
        Grandeur.hauteur,
      );

      expect(observation, isNotNull);
      expect(observation!.level, const Metres(-1.232));
      expect(observation.measuredAt, DateTime.utc(2026, 8, 27, 8));
      expect(capturedRequest?.url.queryParameters['grandeur_hydro'], 'H');
    });
  });

  group('findLatest — absence (BR-007)', () {
    test('{"count":0,"data":[]} en 200 rend null, jamais une exception ni '
        'un zéro', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'count': 0, 'data': <Object?>[]}),
          200,
        );
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      final HydroObservation? observation = await repository.findLatest(
        station,
        Grandeur.debit,
      );

      expect(observation, isNull);
    });
  });

  group('findLatest — panne de source (T-10)', () {
    test('503 sur toutes les tentatives : HubEauFailure propagée, le test '
        'ne dort pas', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('service indisponible', 503);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(
            HubEauClient(
              httpClient: mock,
              maxAttempts: 2,
              jitter: () => 0,
              sleep: (Duration duree) async {},
            ),
          );

      await expectLater(
        repository.findLatest(station, Grandeur.debit),
        throwsA(isA<HubEauFailure>()),
      );
      expect(appels, 2);
    });
  });

  group('findLatest — grandeur inconnue (BR-007, BR-011)', () {
    test('Grandeur.inconnu lève un ArgumentError, aucun appel HTTP', () async {
      int appels = 0;
      final http.Client mock = MockClient((http.Request request) async {
        appels++;
        return http.Response('{}', 200);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.findLatest(station, Grandeur.inconnu),
        throwsArgumentError,
      );
      expect(appels, 0);
    });
  });

  group('findLatest — corps inattendu, une panne de source (UC-001 A4)', () {
    test('une ligne sans date_obs : la FormatException du mapper est '
        'propagée, pas avalée', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'count': 1,
            'data': <Object?>[
              <String, Object?>{
                'code_station': 'K447001001',
                'grandeur_hydro': 'Q',
                'resultat_obs': 47800.0,
              },
            ],
          }),
          200,
        );
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.findLatest(station, Grandeur.debit),
        throwsA(isA<FormatException>()),
      );
    });

    test('data absent (clé manquante) : FormatException, pas null', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, Object?>{'count': 0}), 200);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.findLatest(station, Grandeur.debit),
        throwsA(isA<FormatException>()),
      );
    });

    test('data d\'un type inattendu (un entier) : FormatException', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, Object?>{'data': 3}), 200);
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.findLatest(station, Grandeur.debit),
        throwsA(isA<FormatException>()),
      );
    });

    test('une ligne de data qui n\'est pas un objet (un entier) : '
        'FormatException', () async {
      final http.Client mock = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <Object?>[1],
          }),
          200,
        );
      });
      final HttpHydroObservationRepository repository =
          HttpHydroObservationRepository(HubEauClient(httpClient: mock));

      await expectLater(
        repository.findLatest(station, Grandeur.debit),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

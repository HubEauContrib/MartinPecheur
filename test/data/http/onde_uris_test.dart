// Verrouille les trois constructeurs d'URI vers l'API écoulement ONDE v1
// (C-08, T-01 à T-05) et prouve, par un aller-retour sur une fixture réelle,
// que `HubEauClient.getJson` — déjà indépendant de l'endpoint — sert aussi
// bien ONDE qu'hydrométrie (206 en succès, C-06). Aucun test de rejeu ici :
// 404 non rejoué, 503 rejoué, UTF-8 sans charset sont déjà verrouillés dans
// test/data/http/hub_eau_client_test.dart, pas recopiés.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/http/onde_uris.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Liste maintenue en double avec `_observationFields`
/// (`lib/data/http/onde_uris.dart`) : un ajout de lecture dans
/// `onde_observation_mapper.dart` impose de toucher les deux.
/// `fields` doit coïncider exactement avec cet ensemble sur les deux URI
/// d'observations.
const Set<String> _expectedFields = <String>{
  'code_station',
  'date_observation',
  'code_ecoulement',
  'libelle_ecoulement',
  'code_campagne',
  'latitude',
  'longitude',
  'libelle_station',
  'libelle_cours_eau',
  'code_departement',
};

void main() {
  group('ondeObservationsWithinBoundsUri (T-01, T-03)', () {
    test('construit host, chemin, bbox, date_observation_min et size', () {
      final Uri uri = ondeObservationsWithinBoundsUri(
        bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
        since: DateTime.utc(2026, 7, 15),
      );

      expect(uri.host, 'hubeau.eaufrance.fr');
      expect(uri.path, '/api/v1/ecoulement/observations');
      expect(uri.queryParameters['bbox'], '1.0,47.3,1.8,47.8');
      expect(uri.queryParameters['date_observation_min'], '2026-07-15');
      expect(uri.queryParameters['size'], '1000');
    });

    test("le bbox s'écrit ouest,sud,est,nord dans cet ordre exact, avec quatre "
        'valeurs distinctes', () {
      final Uri uri = ondeObservationsWithinBoundsUri(
        bounds: Bounds(west: 1.0, south: 2.0, east: 3.0, north: 4.0),
        since: DateTime.utc(2026, 1, 1),
      );

      final List<String> bbox = uri.queryParameters['bbox']!.split(',');
      expect(bbox, <String>['1.0', '2.0', '3.0', '4.0']);
    });

    test("l'URI porte sort=desc : sans lui, la dernière observation n'est pas "
        'la première rendue (T-02)', () {
      final Uri uri = ondeObservationsWithinBoundsUri(
        bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
        since: DateTime.utc(2026, 7, 15),
      );

      expect(uri.queryParameters['sort'], 'desc');
    });

    test('fields vaut exactement les dix champs attendus (liste maintenue en '
        'double avec le mapper, voir commentaire de _observationFields)', () {
      final Uri uri = ondeObservationsWithinBoundsUri(
        bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
        since: DateTime.utc(2026, 7, 15),
      );

      final Set<String> fields = uri.queryParameters['fields']!
          .split(',')
          .toSet();

      expect(fields, _expectedFields);
    });

    test('les virgules sont encodées en %2C (forme vérifiée par appel réel le '
        '2026-09-13, voir docs/sources/onde.md, T-12, T-13)', () {
      final Uri uri = ondeObservationsWithinBoundsUri(
        bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
        since: DateTime.utc(2026, 7, 15),
      );

      expect(uri.toString(), contains('bbox=1.0%2C47.3%2C1.8%2C47.8'));
    });

    test('size: 0 lève ArgumentError (C-08)', () {
      expect(
        () => ondeObservationsWithinBoundsUri(
          bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
          since: DateTime.utc(2026, 7, 15),
          size: 0,
        ),
        throwsArgumentError,
      );
    });

    test('size: 20001 lève ArgumentError (C-08)', () {
      expect(
        () => ondeObservationsWithinBoundsUri(
          bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
          since: DateTime.utc(2026, 7, 15),
          size: 20001,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ondeObservationsForStationUri (T-04)', () {
    test('construit chemin, code_station, size et sort=desc', () {
      final Uri uri = ondeObservationsForStationUri(
        OndeStationCode('K4520001'),
        size: 5,
      );

      expect(uri.path, '/api/v1/ecoulement/observations');
      expect(uri.queryParameters['code_station'], 'K4520001');
      expect(uri.queryParameters['size'], '5');
      expect(uri.queryParameters['sort'], 'desc');
    });

    test('fields vaut exactement les dix champs attendus (liste maintenue en '
        'double avec le mapper, voir commentaire de _observationFields)', () {
      final Uri uri = ondeObservationsForStationUri(
        OndeStationCode('K4520001'),
        size: 5,
      );

      final Set<String> fields = uri.queryParameters['fields']!
          .split(',')
          .toSet();

      expect(fields, _expectedFields);
    });

    test('size: 0 lève ArgumentError (C-08)', () {
      expect(
        () =>
            ondeObservationsForStationUri(OndeStationCode('K4520001'), size: 0),
        throwsArgumentError,
      );
    });
  });

  group('ondeCampagnesUri (T-05)', () {
    test('construit chemin, code_departement et size', () {
      final Uri uri = ondeCampagnesUri(departement: DepartementCode('41'));

      expect(uri.path, '/api/v1/ecoulement/campagnes');
      expect(uri.queryParameters['code_departement'], '41');
      expect(uri.queryParameters['size'], '20');
    });

    test('size: 20001 lève ArgumentError (C-08)', () {
      expect(
        () => ondeCampagnesUri(departement: DepartementCode('41'), size: 20001),
        throwsArgumentError,
      );
    });
  });

  group('Fixture réelle (2026-09-13) — HubEauClient réutilisé pour ONDE', () {
    test('la fixture observations_station_K4520001 servie en 206 se décode '
        '(T-09, C-06)', () async {
      final String fixture = File(
        'test/fixtures/onde/observations_station_K4520001_2026-09-13.json',
      ).readAsStringSync();
      String? cheminAppele;
      final http.Client mock = MockClient((http.Request request) async {
        cheminAppele = request.url.path;
        // .bytes + utf8.encode : la fixture est un fichier UTF-8 (comme le
        // serait la réponse réelle d'Hub'Eau) ; http.Response(String, ...)
        // sans en-tête Content-Type ré-encoderait en latin1, corrompant
        // l'accent de « rivière » avant même d'atteindre le client.
        return http.Response.bytes(utf8.encode(fixture), 206);
      });
      final HubEauClient client = HubEauClient(httpClient: mock);

      final Map<String, dynamic> corps = await client.getJson(
        ondeObservationsForStationUri(OndeStationCode('K4520001')),
      );

      expect(cheminAppele, '/api/v1/ecoulement/observations');
      expect(corps['count'], 96);
      final List<dynamic> lignes = corps['data'] as List<dynamic>;
      final Map<String, dynamic> premiere = lignes[0] as Map<String, dynamic>;
      expect(premiere['libelle_cours_eau'], 'ruisseau la rivière aux loches');
    });
  });
}

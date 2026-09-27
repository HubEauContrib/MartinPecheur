// Verrouille les deux constructeurs d'URI vers l'API écoulement ONDE v1
// (C-08, T-01 à T-04) et prouve, par un aller-retour sur une fixture réelle,
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
  // ADR-015 (2026-09-22) : treize champs désormais, vérifiés par appel réel
  // le 2026-09-23 (T-16, docs/sources/onde.md).
  'code_region',
  'libelle_region',
  'libelle_departement',
};

/// Les DIX champs demandés le 2026-09-14 (T-14), avant `ADR-015` — un fait
/// historique figé dans `test/fixtures/onde/
/// observations_station_A721_3011_espace_2026-09-14.json` (son champ
/// `first`), jamais mis à jour : ce n'est pas ce que l'app construit
/// aujourd'hui (`_expectedFields`, treize champs), seulement ce qu'elle
/// construisait alors.
const Set<String> _dixChampsHistoriquesDuT14 = <String>{
  'code_station',
  'libelle_station',
  'code_departement',
  'libelle_cours_eau',
  'code_campagne',
  'date_observation',
  'code_ecoulement',
  'libelle_ecoulement',
  'latitude',
  'longitude',
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

    test(
      'fields vaut exactement les treize champs attendus (liste maintenue en '
      'double avec le mapper, voir commentaire de _observationFields)',
      () {
        final Uri uri = ondeObservationsWithinBoundsUri(
          bounds: Bounds(west: 1.0, south: 47.3, east: 1.8, north: 47.8),
          since: DateTime.utc(2026, 7, 15),
        );

        final Set<String> fields = uri.queryParameters['fields']!
            .split(',')
            .toSet();

        expect(fields, _expectedFields);
      },
    );

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

    test(
      'fields vaut exactement les treize champs attendus (liste maintenue en '
      'double avec le mapper, voir commentaire de _observationFields)',
      () {
        final Uri uri = ondeObservationsForStationUri(
          OndeStationCode('K4520001'),
          size: 5,
        );

        final Set<String> fields = uri.queryParameters['fields']!
            .split(',')
            .toSet();

        expect(fields, _expectedFields);
      },
    );

    test('size: 0 lève ArgumentError (C-08)', () {
      expect(
        () =>
            ondeObservationsForStationUri(OndeStationCode('K4520001'), size: 0),
        throwsArgumentError,
      );
    });

    test("un code à espace intérieur ('A721 3011') passe l'espace au fil sous "
        'la forme `+`, que `Uri(queryParameters:)` produit — forme acceptée '
        "par l'API, vérifiée par appel réel le 2026-09-14 (T-14)", () {
      final Uri uri = ondeObservationsForStationUri(
        OndeStationCode('A721 3011'),
        size: 3,
      );

      // Ce que l'app émet réellement au fil : `+`, pas `%20`. Les deux
      // rendent 206 et `count` 40 (T-14) ; l'API réécrit de toute façon le
      // séparateur en `%20` dans le champ `first` de sa réponse — visible
      // dans la fixture citée plus bas — comme elle réécrit les virgules
      // nues (T-12).
      expect(uri.toString(), contains('code_station=A721+3011'));
      // Et l'espace survit à l'aller-retour : ni perdu, ni doublé, ni `trim`é.
      expect(uri.queryParameters['code_station'], 'A721 3011');
    });

    test("l'espace n'est jamais supprimé : 'A721 3011' et 'A7213011' "
        "construisent deux URI distinctes — l'API rend deux historiques "
        'différents (count 40 contre 63, T-14)', () {
      final Uri avecEspace = ondeObservationsForStationUri(
        OndeStationCode('A721 3011'),
      );
      final Uri sansEspace = ondeObservationsForStationUri(
        OndeStationCode('A7213011'),
      );

      expect(avecEspace.queryParameters['code_station'], 'A721 3011');
      expect(sansEspace.queryParameters['code_station'], 'A7213011');
      expect(avecEspace, isNot(sansEspace));
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

    test("l'URI construite pour 'A721 3011' porte le même code_station et "
        "le même chemin que celle que l'API a elle-même rendue dans le "
        'champ `first` de la capture du 2026-09-14 (T-14) ; ses treize '
        'champs actuels restent un sur-ensemble des dix champs historiques '
        'de cette capture', () {
      final Map<String, dynamic> capture = jsonDecode(
        File(
          'test/fixtures/onde/'
          'observations_station_A721_3011_espace_2026-09-14.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final Uri rendueParLApi = Uri.parse(capture['first'] as String);

      final Uri construite = ondeObservationsForStationUri(
        OndeStationCode('A721 3011'),
        size: 3,
      );

      // Comparaison sur les paramètres décodés, pas sur la chaîne : l'API
      // réécrit l'espace en `%20` et les virgules de `fields` en clair,
      // quand `Uri(queryParameters:)` émet `+` et `%2C`. Les trois formes
      // désignent la même requête, et les trois sont acceptées (T-12, T-14).
      expect(
        rendueParLApi.queryParameters['code_station'],
        construite.queryParameters['code_station'],
      );
      expect(construite.queryParameters['code_station'], 'A721 3011');
      expect(rendueParLApi.path, construite.path);
      // La fixture a été capturée le 2026-09-14, AVANT `ADR-015` — le champ
      // `first` qu'elle porte reflète encore les dix champs d'alors, pas les
      // treize actuels. Comparaison contre ce fait historique, jamais contre
      // `_expectedFields` (qui, lui, décrit ce que l'app construit AUJOURD'HUI).
      expect(
        rendueParLApi.queryParameters['fields']!.split(',').toSet(),
        _dixChampsHistoriquesDuT14,
      );
      // Le lien avec l'app d'aujourd'hui : ses treize champs contiennent
      // TOUJOURS les dix de cette capture historique — `ADR-015` en a
      // ajouté trois, il n'en a retiré aucun.
      expect(
        construite.queryParameters['fields']!.split(',').toSet(),
        containsAll(_dixChampsHistoriquesDuT14),
      );
    });
  });
}

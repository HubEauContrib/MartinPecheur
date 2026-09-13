// Les deux constructeurs d'URI vers l'API écoulement ONDE v1 de Hub'Eau.
// Aucun client ici : `HubEauClient.getJson` (`lib/data/http/hub_eau_client.
// dart`) est déjà indépendant de l'endpoint — il prend n'importe quelle URI
// du même hôte, rejoue sur 429/5xx, accepte 200 et 206 (C-06), décode en
// UTF-8 explicite. Recréer un `OndeClient` aurait recopié cette logique de
// rejeu, ce que le produit interdit. `checkPageSize` et `formatDateUtc` sont
// réutilisés depuis `lib/data/http/hub_eau_paging.dart` — pas depuis
// `hub_eau_client.dart` : ce fichier n'a aucune raison de dépendre du module
// d'un autre endpoint pour deux fonctions utilitaires communes.
//
// `date_observation_min` est requis sur la recherche par emprise : sans
// borne, l'API ONDE renverrait l'historique complet plutôt que les
// observations récentes (T-01). `sort=desc` et `fields` sont posés sur les
// deux URI d'`/observations` : sans `sort`, la « dernière » observation
// n'est pas la première rendue (T-02) ; `fields` ne retient que les champs
// que lisent `mapOndeObservation` et `mapOndePoint`
// (`lib/data/mappers/onde_observation_mapper.dart`), jamais recopiés à la
// main ailleurs.
import 'package:martinpecheur/data/http/hub_eau_paging.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

/// Hôte unique de Hub'Eau — le même que l'hydrométrie v2, ONDE n'étant
/// qu'un autre endpoint de la même plateforme (constaté le 2026-07-30,
/// `docs/01-analyse.md`).
const String _host = 'hubeau.eaufrance.fr';

/// Préfixe de chemin commun aux endpoints ONDE v1.
const String _basePath = '/api/v1/ecoulement';

/// Champs Hub'Eau retenus sur `/observations` : exactement ceux que lisent
/// `mapOndeObservation` et `mapOndePoint`
/// (`lib/data/mappers/onde_observation_mapper.dart`), pas un de plus
/// (YAGNI) — `code_cours_eau` n'y figure pas, le mapper ne lit que
/// `libelle_cours_eau`. `fields` est accepté par l'API, forme exacte
/// vérifiée par appel réel (`T-13`, `docs/sources/onde.md`). Cette liste est
/// maintenue en double avec `test/data/http/onde_uris_test.dart` : un ajout
/// de lecture dans `onde_observation_mapper.dart` impose une mise à jour ici
/// **et** dans son test.
const List<String> _observationFields = <String>[
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
];

/// URI de `/observations` filtrée par emprise, depuis [since] (inclus).
/// [since] est requis : sans borne, l'API renverrait l'historique complet
/// plutôt que les observations récentes qui peuplent la carte (T-01).
Uri ondeObservationsWithinBoundsUri({
  required Bounds bounds,
  required DateTime since,
  int size = 1000,
}) {
  checkPageSize(size);
  return _observationsUri(<String, String>{
    // ouest,sud,est,nord dans cet ordre exact : inverser deux valeurs ne
    // lève aucune erreur, la carte se remplit simplement d'autre chose, et
    // cela ne se voit qu'à l'écran. Chaque coordonnée passe par
    // `double.toString()`, sans arrondi ; sous `1e-6`, `double.toString()`
    // rend une notation exponentielle (`3e-7`) — forme elle aussi acceptée
    // par l'API (`T-13`).
    'bbox': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
    'date_observation_min': formatDateUtc(since),
    'size': '$size',
  });
}

/// URI de `/observations` filtrée par [station], pour la fiche station.
Uri ondeObservationsForStationUri(OndeStationCode station, {int size = 10}) {
  checkPageSize(size);
  return _observationsUri(<String, String>{
    'code_station': station.value,
    'size': '$size',
  });
}

Uri _observationsUri(Map<String, String> specificParameters) {
  return _uri('observations', <String, String>{
    ...specificParameters,
    'sort': 'desc',
    'fields': _observationFields.join(','),
  });
}

Uri _uri(String path, Map<String, String> queryParameters) {
  return Uri(
    scheme: 'https',
    host: _host,
    path: '$_basePath/$path',
    queryParameters: queryParameters,
  );
}

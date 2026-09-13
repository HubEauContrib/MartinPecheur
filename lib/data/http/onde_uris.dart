// Les trois constructeurs d'URI vers l'API écoulement ONDE v1 de Hub'Eau.
// Aucun client ici : `HubEauClient.getJson` (`lib/data/http/hub_eau_client.
// dart`) est déjà indépendant de l'endpoint — il prend n'importe quelle URI
// du même hôte, rejoue sur 429/5xx, accepte 200 et 206 (C-06), décode en
// UTF-8 explicite. Recréer un `OndeClient` aurait recopié cette logique de
// rejeu, ce que le produit interdit. `checkPageSize` et `formatDateUtc` sont
// réutilisés depuis `hub_eau_client.dart`, jamais recopiés.
//
// `date_observation_min` est requis sur la recherche par emprise : sans
// borne, l'API ONDE renverrait l'historique complet plutôt que les
// observations récentes (T-01). `sort=desc` et `fields` sont posés sur les
// deux URI d'`/observations` : sans `sort`, la « dernière » observation
// n'est pas la première rendue (T-02) ; `fields` ne retient que les champs
// que lisent `mapOndeObservation` et `mapOndePoint`
// (`lib/data/mappers/onde_observation_mapper.dart`), jamais recopiés à la
// main ailleurs.
import 'package:martinpecheur/data/http/hub_eau_client.dart'
    show checkPageSize, formatDateUtc;
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

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
/// `libelle_cours_eau`. `fields` est accepté par l'API (T-02, constaté le
/// 2026-09-13).
const String _observationFields =
    'code_station,libelle_station,code_departement,libelle_cours_eau,'
    'code_campagne,date_observation,code_ecoulement,libelle_ecoulement,'
    'latitude,longitude';

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
    // cela ne se voit qu'à l'écran.
    'bbox': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
    'date_observation_min': formatDateUtc(since.toUtc()),
    'size': '$size',
  });
}

/// URI de `/observations` filtrée par [station], pour la fiche station.
Uri ondeObservationsForStationUri(OndeStationCode station, {int limit = 10}) {
  checkPageSize(limit);
  return _observationsUri(<String, String>{
    'code_station': station.value,
    'size': '$limit',
  });
}

Uri _observationsUri(Map<String, String> specificParameters) {
  return _uri('observations', <String, String>{
    ...specificParameters,
    'sort': 'desc',
    'fields': _observationFields,
  });
}

/// URI de `/campagnes`, filtrée sur un unique [departement].
Uri ondeCampagnesUri({required DepartementCode departement, int size = 20}) {
  checkPageSize(size);
  return _uri('campagnes', <String, String>{
    'code_departement': departement.value,
    'size': '$size',
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

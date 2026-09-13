// Depot bete, comme le veut `domain/repositories/repositories.dart` : il
// lit la derniere observation via `HubEauClient`, ne calcule ni fraicheur ni
// conversion — deja faites par `mapHydroObservation` (BR-002). `size=1` :
// `observations_tr` rend les observations triees, la premiere ligne est la
// plus recente (constate sur `observations_tr_K447001001_Q_2026-09-13.json`
// — la premiere ligne date de 08:00:00Z, la seconde de 07:27:30Z, la meme
// journee).
//
// Une reponse vide (`count:0`, `data: []`) rend `null` : une absence de
// donnee n'est jamais une erreur ni un zero (BR-007). Une panne de source
// (`HubEauFailure`, un corps que `mapHydroObservation` ne sait pas lire)
// n'est en revanche jamais avalee : elle remonte telle quelle, pour que
// l'ecran puisse nommer la source defaillante (UC-001 A4). `Grandeur.inconnu`
// leve avant meme l'appel HTTP, via `grandeurCode` dans `observationsTrUri` —
// on n'interroge jamais une grandeur qu'on ne sait pas lire (BR-011).
//
// Pas de `findLatestForAll` ici : amendement du 2026-09-13 (plan T1, tache
// D5) — la methode ne figurait sur aucune interface, et le prechargement
// borne a 20 stations et annulable entre deux appels vit dans `MapViewModel`
// (V2), qui appelle `findLatest` station par station avec un espacement
// injecte. Un lot au niveau du depot n'aurait ete appele par personne et
// n'aurait pas pu etre annule a mi-course (YAGNI).

import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/mappers/hydro_observation_mapper.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';

/// Depot des observations hydrometriques, adosse au client Hub'Eau v2.
final class HttpHydroObservationRepository
    implements HydroObservationRepository {
  HttpHydroObservationRepository(this._client);

  final HubEauClient _client;

  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async {
    final Map<String, dynamic> body = await _client.getJson(
      observationsTrUri(station: station, grandeur: grandeur, size: 1),
    );

    final List<dynamic>? rows = body['data'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) {
      return null;
    }

    return mapHydroObservation(rows.first as Map<String, dynamic>);
  }
}

// Dépôt bête, comme le veut `domain/repositories/repositories.dart` : il
// lit la dernière observation via `HubEauClient`, ne calcule ni fraîcheur ni
// conversion — déjà faites par `mapHydroObservation` (BR-002). `size=1` :
// `observations_tr` rend les observations triées, la première ligne est la
// plus récente (constaté sur `observations_tr_K447001001_Q_2026-09-13.json`
// — la première ligne date de 08:00:00Z, la seconde de 07:27:30Z, la même
// journée).
//
// Une réponse vide (`count:0`, `data: []`) rend `null` : une absence de
// donnée n'est jamais une erreur ni un zéro (BR-007). Deux causes distinctes
// remontent en revanche telles quelles, jamais avalées, pour que l'écran
// puisse nommer la source défaillante (UC-001 A4) : une `HubEauFailure`
// levée par le client (statut, panne réseau, corps illisible malgré un
// succès), ou une `FormatException` levée par le mapper ou par ce dépôt sur
// un corps qui prétend être un succès mais ne ressemble à rien de connu —
// `data` absent, d'un type inattendu, ou une ligne qui n'est pas un objet.
// `Grandeur.inconnu` lève avant même l'appel HTTP, via `grandeurCode` dans
// `observationsTrUri` — on n'interroge jamais une grandeur qu'on ne sait pas
// lire (BR-011).
//
// Pas de `findLatestForAll` ici : amendement du 2026-09-13 (plan T1, tâche
// D5) — la méthode ne figurait sur aucune interface, et le préchargement
// borné à 20 stations et annulable entre deux appels vit dans `MapViewModel`
// (V2), qui appelle `findLatest` station par station avec un espacement
// injecté. Un lot au niveau du dépôt n'aurait été appelé par personne et
// n'aurait pas pu être annulé à mi-course (YAGNI).

import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/mappers/hydro_observation_mapper.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';

/// Dépôt des observations hydrométriques, adossé au client Hub'Eau v2.
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

    // `data` absent (clé manquante) ou d'un type autre qu'une liste est un
    // corps inattendu, pas une absence (UC-001 A4) : `body['data']` sur une
    // clé manquante rend `null`, qui échoue le test `is! List` au même
    // titre qu'un entier ou une chaîne — un seul contrôle couvre les deux
    // cas, sans lecture non typée (`as List<dynamic>?` nu).
    final Object? rawRows = body['data'];
    if (rawRows is! List<dynamic>) {
      throw FormatException('data absent ou mal formé : $rawRows');
    }
    if (rawRows.isEmpty) {
      // Seule une liste VIDE est une absence de donnée (BR-007) : la
      // station n'a simplement rien transmis pour cette grandeur.
      return null;
    }

    final Object? firstRow = rawRows.first;
    if (firstRow is! Map<String, dynamic>) {
      throw FormatException(
        'une ligne de data attendue en objet, reçue : $firstRow',
      );
    }

    return mapHydroObservation(firstRow);
  }
}

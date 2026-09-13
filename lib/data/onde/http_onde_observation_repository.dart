// Dépôt bête, comme le veut `domain/repositories/repositories.dart` : il
// lit via `HubEauClient` (aucun `OndeClient` — retiré en D4, la logique de
// rejeu et de décodage est déjà commune aux deux endpoints Hub'Eau), ne
// calcule ni fraîcheur ni conversion — `mapOndeObservation` s'en charge déjà
// (BR-002).
//
// `latestWithinBounds` regroupe ici, pas au décorateur de cache : l'API
// ONDE rend une ligne par campagne et par point (T-04, `count` 96 pour la
// seule station K4520001), et la carte n'affiche qu'une observation par
// station. `sort=desc` (posé par `ondeObservationsWithinBoundsUri`) rend en
// principe la plus récente en tête, mais le regroupement compare les dates
// (`observedAt`) plutôt que de s'y fier : plus robuste, et une réponse
// désordonnée ne romprait pas l'invariant en silence.
//
// `historyFor` trie et tronque côté client, pour la même raison : l'API a
// reçu `size=limit`, mais rien ne garantit qu'elle le respecte à la lettre
// ni qu'elle rend déjà l'ordre attendu.
//
// Une réponse vide (`count:0`, `data: []`) rend une liste vide : une
// absence de donnée n'est jamais une erreur (BR-007, UC-001 A5). Une
// `HubEauFailure` (statut, panne réseau, corps illisible malgré un succès)
// ou une `FormatException` (corps qui prétend être un succès mais ne
// ressemble à rien de connu — `data` absent, d'un type inattendu, une ligne
// qui n'est pas un objet, ou une ligne que `mapOndeObservation` ne sait pas
// lire) remontent telles quelles, jamais avalées (UC-001 A4).

import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/http/onde_uris.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show OndeObservationRepository;

/// Dépôt des observations d'écoulement ONDE, adossé au client Hub'Eau
/// commun (`HubEauClient` — aucun `OndeClient` distinct, retiré en D4).
final class HttpOndeObservationRepository implements OndeObservationRepository {
  HttpOndeObservationRepository(this._client);

  final HubEauClient _client;

  @override
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    final Map<String, dynamic> body = await _client.getJson(
      ondeObservationsWithinBoundsUri(bounds: bounds, since: since),
    );
    final List<OndeObservation> rows = _rows(body);

    // Une observation par station, la plus récente : comparée par date,
    // jamais par position dans la réponse (T-04).
    final Map<OndeStationCode, OndeObservation> latestByStation =
        <OndeStationCode, OndeObservation>{};
    for (final OndeObservation observation in rows) {
      final OndeObservation? current = latestByStation[observation.station];
      if (current == null ||
          observation.observedAt.isAfter(current.observedAt)) {
        latestByStation[observation.station] = observation;
      }
    }
    return latestByStation.values.toList();
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final Map<String, dynamic> body = await _client.getJson(
      ondeObservationsForStationUri(station, size: limit),
    );
    final List<OndeObservation> rows = _rows(body)
      ..sort(
        (OndeObservation a, OndeObservation b) =>
            b.observedAt.compareTo(a.observedAt),
      );
    return rows.take(limit).toList();
  }

  /// Convertit `body['data']` en observations. Lève une [FormatException]
  /// si `data` est absent, d'un type autre qu'une liste, ou si une ligne
  /// n'est pas un objet — même règle que `HttpHydroObservationRepository`
  /// (D5). Une ligne que [mapOndeObservation] ne sait pas lire lève telle
  /// quelle, jamais avalée.
  List<OndeObservation> _rows(Map<String, dynamic> body) {
    final Object? rawRows = body['data'];
    if (rawRows is! List<dynamic>) {
      throw FormatException('data absent ou mal formé : $rawRows');
    }

    return rawRows.map((Object? row) {
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'une ligne de data attendue en objet, reçue : $row',
        );
      }
      return mapOndeObservation(row);
    }).toList();
  }
}

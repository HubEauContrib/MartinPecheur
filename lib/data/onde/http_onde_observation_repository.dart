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
// ou une `FormatException` **structurelle** (corps qui prétend être un
// succès mais ne ressemble à rien de connu — `data` absent, d'un type
// inattendu, une ligne qui n'est pas un objet) remontent telles quelles,
// jamais avalées (UC-001 A4).
//
// ⚠️ **Une ligne individuellement illisible n'est pas une panne de source**
// (contrat révisé le 2026-09-14, bug vu à l'écran). Auparavant, l'exception
// que `mapOndeObservation` levait sur une ligne remontait telle quelle : la
// carte affichait un bandeau rouge et **zéro station**. Sur la page
// nationale du 2026-09-14, 507 lignes sur 10 234 étaient refusées (codes de
// station à espaces, `T-14`) : 9 727 lignes lisibles ont disparu pour 507
// illisibles. Désormais, une `FormatException` ou une `ArgumentError` levée
// **par le mapper sur une ligne** est ignorée et **comptée**
// (`OndeSweep.unreadableRows`) : l'absence s'explique (BR-007), elle ne se
// propage pas. La frontière est nette — ce qui décrit la **forme de la
// réponse** reste fatal, ce qui décrit **une ligne** ne l'est pas.
//
// ⚠️ Depuis `U6`, ce compte est **rattaché à l'appel** et non plus à
// l'instance : `latestWithinBounds` rend un `OndeSweep`, et le champ mutable
// `skippedRowCount` a disparu — il n'avait aucun lecteur en production, et un
// cumul de session ne peut pas s'écrire à l'écran (« N points non lisibles
// sur cette emprise » parle de CETTE emprise). `historyFor`, lui, garde sa
// liste nue : une fiche n'a pas d'emprise, et personne n'y afficherait ce
// chiffre (YAGNI).

import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/http/onde_uris.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show OndeObservationRepository, OndeSweep;

/// Dépôt des observations d'écoulement ONDE, adossé au client Hub'Eau
/// commun (`HubEauClient` — aucun `OndeClient` distinct, retiré en D4).
final class HttpOndeObservationRepository implements OndeObservationRepository {
  HttpOndeObservationRepository(this._client);

  final HubEauClient _client;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    final Map<String, dynamic> body = await _client.getJson(
      ondeObservationsWithinBoundsUri(bounds: bounds, since: since),
    );
    final _ReadRows read = _rows(body);

    // Une observation par station, la plus récente : comparée par date,
    // jamais par position dans la réponse (T-04).
    final Map<OndeStationCode, OndeObservation> latestByStation =
        <OndeStationCode, OndeObservation>{};
    for (final OndeObservation observation in read.observations) {
      final OndeObservation? current = latestByStation[observation.station];
      if (current == null ||
          observation.observedAt.isAfter(current.observedAt)) {
        latestByStation[observation.station] = observation;
      }
    }
    // Le compte porte sur les LIGNES refusées par le mapper, jamais sur les
    // stations : deux campagnes illisibles du même point comptent deux, et
    // c'est ce que dit « N points d'observation non lisibles » — un point
    // dont aucune ligne n'est lisible n'a pas de station à regrouper.
    return OndeSweep(
      observations: latestByStation.values.toList(),
      unreadableRows: read.unreadableRows,
    );
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final Map<String, dynamic> body = await _client.getJson(
      ondeObservationsForStationUri(station, size: limit),
    );
    final List<OndeObservation> rows = _rows(body).observations
      ..sort(
        (OndeObservation a, OndeObservation b) =>
            b.observedAt.compareTo(a.observedAt),
      );
    return rows.take(limit).toList();
  }

  /// Convertit `body['data']` en observations.
  ///
  /// Lève une [FormatException] si `data` est absent, d'un type autre qu'une
  /// liste, ou si une ligne n'est pas un objet — même règle que
  /// `HttpHydroObservationRepository` (D5) : ces trois cas décrivent la
  /// **forme de la réponse**, pas son contenu, et une réponse informe est
  /// une panne de source (UC-001 A4).
  ///
  /// En revanche, une ligne que [mapOndeObservation] ne sait pas lire —
  /// [FormatException] sur un champ, [ArgumentError] sur le code de station
  /// — est **ignorée et comptée** dans [_ReadRows.unreadableRows] : une ligne
  /// illisible ne fait pas disparaître les autres (`T-14`, BR-007). Seules
  /// ces deux exceptions sont rattrapées ; toute autre remonte, un bug du
  /// mapper ne devant pas se déguiser en donnée manquante. ⚠️ [RangeError]
  /// et [IndexError] **dérivent** d'[ArgumentError] dans le SDK : ils sont
  /// relancés explicitement avant la clause générale, sinon un `substring`
  /// ou un index fautif du mapper serait compté comme une ligne illisible.
  /// Ce bord n'est pas couvert par un test : le mapper n'est pas injectable
  /// ici et aucune ligne réelle ne le déclenche.
  _ReadRows _rows(Map<String, dynamic> body) {
    final Object? rawRows = body['data'];
    if (rawRows is! List<dynamic>) {
      throw FormatException('data absent ou mal formé : $rawRows');
    }

    final List<OndeObservation> observations = <OndeObservation>[];
    int unreadableRows = 0;
    for (final Object? row in rawRows) {
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'une ligne de data attendue en objet, reçue : $row',
        );
      }
      try {
        observations.add(mapOndeObservation(row));
      } on FormatException {
        unreadableRows++;
      } on RangeError {
        // Dérive d'ArgumentError : un index fautif est un bug, pas une ligne.
        rethrow;
      } on ArgumentError {
        unreadableRows++;
      }
    }
    return (observations: observations, unreadableRows: unreadableRows);
  }
}

/// Ce que [HttpOndeObservationRepository._rows] rend : les lignes lues, et
/// celles qu'il a fallu laisser de côté. Un `record` nommé et non un
/// [OndeSweep] : `historyFor` passe par la même lecture sans avoir de compte
/// à publier, et le type du domaine décrit ce qui SORT du dépôt, pas son
/// mécanisme interne.
typedef _ReadRows = ({List<OndeObservation> observations, int unreadableRows});

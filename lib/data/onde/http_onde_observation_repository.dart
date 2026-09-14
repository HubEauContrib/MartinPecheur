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
// (`skippedRowCount`) : l'absence s'explique (BR-007), elle ne se propage
// pas. La frontière est nette — ce qui décrit la **forme de la réponse**
// reste fatal, ce qui décrit **une ligne** ne l'est pas.

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

  int _skippedRowCount = 0;

  /// Nombre de lignes ignorées parce qu'illisibles, **cumulé sur la durée de
  /// vie de cette instance** et jamais remis à zéro. Cumulé plutôt que par
  /// appel : le dépôt est enveloppé par `CachedOndeObservationRepository`, si
  /// bien qu'un appel peut être servi par le cache sans relire aucune ligne
  /// — un compteur « du dernier appel » serait alors périmé sans que rien ne
  /// le dise. Un compteur monotone n'a pas ce piège : il se lit comme « voilà
  /// ce que cette session a laissé de côté », jamais comme un chiffre d'écran.
  ///
  /// C'est un compteur de **diagnostic** : il explique une absence (BR-007),
  /// il ne se destine pas tel quel à un libellé « N stations ignorées » sur
  /// un écran — ce chiffre-là devrait accompagner les lignes d'un appel
  /// donné, pas vivre dans un champ mutable.
  int get skippedRowCount => _skippedRowCount;

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
  /// — est **ignorée et comptée** dans [skippedRowCount] : une ligne
  /// illisible ne fait pas disparaître les autres (`T-14`, BR-007). Seules
  /// ces deux exceptions sont rattrapées ; toute autre remonte, un bug du
  /// mapper ne devant pas se déguiser en donnée manquante. ⚠️ [RangeError]
  /// et [IndexError] **dérivent** d'[ArgumentError] dans le SDK : ils sont
  /// relancés explicitement avant la clause générale, sinon un `substring`
  /// ou un index fautif du mapper serait compté comme une ligne illisible.
  /// Ce bord n'est pas couvert par un test : le mapper n'est pas injectable
  /// ici et aucune ligne réelle ne le déclenche.
  List<OndeObservation> _rows(Map<String, dynamic> body) {
    final Object? rawRows = body['data'];
    if (rawRows is! List<dynamic>) {
      throw FormatException('data absent ou mal formé : $rawRows');
    }

    final List<OndeObservation> observations = <OndeObservation>[];
    for (final Object? row in rawRows) {
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'une ligne de data attendue en objet, reçue : $row',
        );
      }
      try {
        observations.add(mapOndeObservation(row));
      } on FormatException {
        _skippedRowCount++;
      } on RangeError {
        // Dérive d'ArgumentError : un index fautif est un bug, pas une ligne.
        rethrow;
      } on ArgumentError {
        _skippedRowCount++;
      }
    }
    return observations;
  }
}

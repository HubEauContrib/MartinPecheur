// Le client de l'API hydrométrie v2, et les seuls constructeurs d'URI vers
// elle (ADR-001 : uniquement la v2, la v1 est arrêtée depuis le 05/05/2025,
// C-01). `date_debut_obs_elab` est un paramètre requis de [obsElabUri],
// jamais optionnel : sans lui, `sort` est ignoré et la réponse commence au
// 1er janvier 1900 (C-04, reproduit le 2026-09-13, voir
// docs/sources/hubeau-hydrometrie.md). `size` au-delà de [maxPageSize] fait
// répondre l'API en 400 (C-08) — on refuse à la construction plutôt que de
// laisser partir une requête qui échouera à coup sûr. `code_entite` et
// `code_station` ne reçoivent qu'un [StationCode] à dix caractères, jamais un
// code site à huit (C-05).
//
// Trois pannes sont distinguées dans [HubEauFailure.message], parce que
// trois causes différentes appellent trois diagnostics différents : un
// statut HTTP hors succès, une panne réseau (`http.ClientException` — le
// client HTTP la lève sur coupure, échec DNS ou TLS, sans le moindre statut ;
// c'est la panne transitoire la plus courante, et elle est rejouable), un
// corps qui prétend être un succès mais ne se décode pas en JSON (rejouable
// aussi — un 206 tronqué en cours de transfert n'est pas la faute de la
// requête). Un statut non rejouable (4xx sauf 429, `isRetryable` en décide
// à lui seul, C-06/C-12) échoue immédiatement, sans attente : le rejouer ne
// corrigerait pas une requête mal formée.
//
// Le tirage aléatoire de la gigue n'existe qu'à un seul endroit du produit,
// `lib/data/http/retry.dart` : ce fichier n'importe pas `dart:math`, et
// délègue à [delayForAttempt] pour chaque délai d'attente.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/http_status.dart';
import 'package:martinpecheur/data/http/retry.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Taille de page maximale acceptée par l'API hydrométrie v2 avant de
/// répondre `400` (C-08, constaté sur `/observations_tr`).
const int maxPageSize = 20000;

/// Hôte unique de l'API hydrométrie v2 (ADR-001).
const String _host = 'hubeau.eaufrance.fr';

/// Préfixe de chemin commun à tous les endpoints hydrométrie v2.
const String _basePath = '/api/v2/hydrometrie';

/// Traduit [grandeur] en code API (`H`/`Q`). [Grandeur.inconnu] lève : on ne
/// demande jamais la grandeur qu'on ne sait pas lire (BR-007, BR-011).
String grandeurCode(Grandeur grandeur) {
  switch (grandeur) {
    case Grandeur.hauteur:
      return 'H';
    case Grandeur.debit:
      return 'Q';
    case Grandeur.inconnu:
      throw ArgumentError.value(
        grandeur,
        'grandeur',
        'Grandeur.inconnu ne correspond à aucun code API interrogeable '
            '(BR-007)',
      );
  }
}

/// URI de `/observations_tr` (temps réel, pagination par curseur).
Uri observationsTrUri({
  required StationCode station,
  required Grandeur grandeur,
  int size = 100,
}) {
  _checkSize(size);
  return _uri('observations_tr', <String, String>{
    'code_entite': station.value,
    'grandeur_hydro': grandeurCode(grandeur),
    'size': '$size',
  });
}

/// URI de `/obs_elab` (données journalières élaborées, débit moyen
/// `QmnJ`). [since] est **requis** : sans lui, `sort` est ignoré côté API et
/// la réponse commence au 1er janvier 1900 (C-04).
Uri obsElabUri({
  required StationCode station,
  required DateTime since,
  int size = 1000,
}) {
  _checkSize(size);
  return _uri('obs_elab', <String, String>{
    'code_entite': station.value,
    'grandeur_hydro_elab': 'QmnJ',
    'date_debut_obs_elab': _formatDate(since.toUtc()),
    'size': '$size',
  });
}

/// URI de `/referentiel/stations`, filtrée sur un unique [station].
Uri referentielStationUri(StationCode station) {
  return _uri('referentiel/stations', <String, String>{
    'code_station': station.value,
  });
}

void _checkSize(int size) {
  if (size > maxPageSize) {
    throw ArgumentError.value(
      size,
      'size',
      'dépasse maxPageSize ($maxPageSize) — l\'API répond 400 (C-08)',
    );
  }
}

String _formatDate(DateTime utc) {
  final String year = utc.year.toString().padLeft(4, '0');
  final String month = utc.month.toString().padLeft(2, '0');
  final String day = utc.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Uri _uri(String path, Map<String, String> queryParameters) {
  return Uri(
    scheme: 'https',
    host: _host,
    path: '$_basePath/$path',
    queryParameters: queryParameters,
  );
}

/// Échec de [HubEauClient.getJson], une fois toutes les tentatives
/// épuisées (ou immédiatement, pour une panne non rejouable). [message]
/// distingue la cause : un statut (`statut 400 …`), une panne réseau, ou un
/// corps illisible.
final class HubEauFailure implements Exception {
  const HubEauFailure(this.message);

  final String message;

  @override
  String toString() => 'HubEauFailure: $message';
}

/// Attente réelle entre deux tentatives — jamais utilisée dans un test, où
/// [HubEauClient.new] reçoit un `sleep` injecté qui n'attend pas vraiment.
Future<void> _sleep(Duration duration) => Future<void>.delayed(duration);

/// Client HTTP de l'API hydrométrie v2, avec recul exponentiel à gigue
/// injectée (C-12) sur les pannes rejouables.
final class HubEauClient {
  HubEauClient({
    required http.Client httpClient,
    Future<void> Function(Duration) sleep = _sleep,
    double Function()? jitter,
    this.maxAttempts = 4,
  }) : _httpClient = httpClient, // ignore: prefer_initializing_formals
       _sleepFn = sleep,
       _jitter = jitter; // ignore: prefer_initializing_formals

  final http.Client _httpClient;

  // Nommé différemment de la fonction de sommet `_sleep` : les deux
  // partagent une portée dans le corps de la classe (le paramètre par
  // défaut `= _sleep` est résolu ici), et un champ homonyme masquerait la
  // fonction de sommet au profit d'un accès à `this` non constant.
  final Future<void> Function(Duration) _sleepFn;
  final double Function()? _jitter;

  /// Nombre maximal de tentatives, première comprise. La dernière n'attend
  /// jamais avant d'abandonner.
  final int maxAttempts;

  /// Récupère [uri] et renvoie son corps décodé en objet JSON.
  ///
  /// Rejoue sur 429 et 5xx (`isRetryable`, C-12), sur une panne réseau
  /// (`http.ClientException`) et sur un corps illisible malgré un statut de
  /// succès. Échoue immédiatement, sans attente, sur un statut non
  /// rejouable ou sur un corps JSON qui n'est pas un objet.
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    HubEauFailure? lastFailure;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final http.Response response = await _httpClient.get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        );

        if (isSuccess(response.statusCode)) {
          final Object? decoded;
          try {
            decoded = jsonDecode(response.body);
          } on FormatException catch (error) {
            lastFailure = HubEauFailure(
              'corps illisible (statut ${response.statusCode}) : $error',
            );
            await _waitBeforeNextAttempt(attempt);
            continue;
          }

          if (decoded is Map<String, dynamic>) {
            return decoded;
          }

          throw const HubEauFailure(
            'corps JSON invalide : un objet est attendu, reçu autre chose '
            '(un tableau par exemple)',
          );
        }

        if (!isRetryable(response.statusCode)) {
          throw HubEauFailure(
            'statut ${response.statusCode} : ${response.body}',
          );
        }

        lastFailure = HubEauFailure(
          'statut ${response.statusCode} : ${response.body}',
        );
      } on http.ClientException catch (error) {
        lastFailure = HubEauFailure('panne réseau : ${error.message}');
      }

      await _waitBeforeNextAttempt(attempt);
    }

    throw lastFailure!;
  }

  Future<void> _waitBeforeNextAttempt(int attempt) async {
    if (attempt == maxAttempts - 1) {
      return;
    }
    final double Function()? jitter = _jitter;
    final Duration delay = jitter == null
        ? delayForAttempt(attempt)
        : delayForAttempt(attempt, jitter: jitter);
    await _sleepFn(delay);
  }

  /// Ferme le client HTTP sous-jacent.
  void close() => _httpClient.close();
}

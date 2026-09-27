// Le transport JSON à rejeu du produit — **la seule boucle de rejeu** de
// `lib/data/http/`. Extrait de `HubEauClient` (D1 de T2) parce qu'une API
// publique rend une racine **tableau**, que `HubEauClient` refuse à bon
// droit : recopier la boucle pour elle est ce que le produit interdit. Ce
// client ne juge donc pas la forme de la racine — il rend un `Object?`
// (`List`, `Map`, ou scalaire), et chaque appelant exige la forme qu'il
// attend. `HubEauClient` exige un objet, et enveloppe les échecs d'ici dans
// `HubEauFailure` en recopiant leur [JsonHttpFailure.message].
//
// Il rejoue sur 429/5xx (`isRetryable`), accepte 200 et 206 (`isSuccess`,
// C-06) — ces deux fonctions restent les seuls juges du statut —, décode en
// UTF-8 explicite, avec attente et gigue injectées (NFR-07 : quatre
// tentatives au plus par défaut, recul plafonné à 30 s par
// `delayForAttempt`).
//
// Trois pannes sont distinguées **par type**, parce que trois causes
// différentes appellent trois diagnostics différents, et qu'un appelant doit
// pouvoir distinguer une requête refusée d'une source injoignable sans
// analyser un message : un statut HTTP hors succès
// ([JsonHttpStatusFailure]), une panne réseau ([JsonHttpNetworkFailure] :
// `http.ClientException`, levée par `IOClient` sur coupure ou échec DNS —
// mais **pas** sur un échec TLS : `IOClient.send` n'enveloppe que
// `SocketException` et `HttpException` (`package:http` 1.6.0,
// `io_client.dart`), donc `HandshakeException` et `TlsException`
// (`dart:io`) traversent tels quels et sont rattrapées ici via `on
// IOException`, avec le même traitement rejouable — sans le moindre statut,
// c'est la panne transitoire la plus courante), un corps qui prétend être un
// succès mais ne se décode pas en JSON ([JsonHttpUnreadableBody], rejouable
// aussi — un 206 tronqué en cours de transfert n'est pas la faute de la
// requête). Un statut non rejouable (4xx sauf 429, `isRetryable` en décide à
// lui seul, C-06/C-12) échoue immédiatement, sans attente : le rejouer ne
// corrigerait pas une requête mal formée. Un client déjà fermé
// (`ClientException` dont le message contient « already closed ») n'est pas
// davantage rejoué : aucune attente ne rouvrira le client.
//
// Le corps est toujours décodé en UTF-8 explicite (`utf8.decode
// (response.bodyBytes)`), jamais via `response.body` : JSON est UTF-8 par
// définition (RFC 8259), alors que `response.body` retombe sur latin1 dès
// que l'en-tête `Content-Type` ne précise pas de charset (`package:http`
// 1.6.0, `response.dart`) — un accent d'un libellé (`Pré-validée`)
// arriverait alors corrompu jusqu'à l'écran.
//
// Le tirage aléatoire de la gigue n'existe qu'à un seul endroit du produit,
// `lib/data/http/retry.dart` : ce fichier n'importe pas `dart:math`, et
// délègue à [delayForAttempt] pour chaque délai d'attente.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/http_status.dart';
import 'package:martinpecheur/data/http/retry.dart';

/// Échec de [JsonHttpClient.getJson], une fois toutes les tentatives
/// épuisées (ou immédiatement, pour une panne non rejouable). La branche
/// dit la cause ; [message] la décrit, dans les termes que `HubEauFailure`
/// porte depuis T0.
sealed class JsonHttpFailure implements Exception {
  const JsonHttpFailure();

  /// Description lisible de la panne.
  String get message;
}

/// Statut HTTP hors succès (`isSuccess`), rejouable ou non.
final class JsonHttpStatusFailure extends JsonHttpFailure {
  const JsonHttpStatusFailure({required this.statusCode, required this.body});

  final int statusCode;

  /// Corps de la réponse, décodé en UTF-8.
  final String body;

  @override
  String get message => 'statut $statusCode : $body';

  @override
  String toString() => 'JsonHttpStatusFailure: $message';
}

/// Panne réseau (coupure, DNS, TLS) ou client déjà fermé : aucun statut
/// n'est parvenu.
final class JsonHttpNetworkFailure extends JsonHttpFailure {
  const JsonHttpNetworkFailure(this.message);

  @override
  final String message;

  @override
  String toString() => 'JsonHttpNetworkFailure: $message';
}

/// Statut de succès, mais corps qui ne se décode pas en JSON.
final class JsonHttpUnreadableBody extends JsonHttpFailure {
  const JsonHttpUnreadableBody({
    required this.statusCode,
    required this.detail,
  });

  final int statusCode;

  /// Erreur de décodage, telle que levée par `jsonDecode`.
  final String detail;

  @override
  String get message => 'corps illisible (statut $statusCode) : $detail';

  @override
  String toString() => 'JsonHttpUnreadableBody: $message';
}

/// Attente réelle entre deux tentatives — jamais utilisée dans un test, où
/// [JsonHttpClient.new] reçoit un `sleep` injecté qui n'attend pas vraiment.
Future<void> _sleep(Duration duration) => Future<void>.delayed(duration);

/// Client HTTP GET qui rend un corps JSON quelconque, avec recul exponentiel
/// à gigue injectée (C-12, NFR-07) sur les pannes rejouables.
final class JsonHttpClient {
  /// Lève [ArgumentError] si [maxAttempts] est inférieur à 1 : une tentative
  /// est le minimum pour qu'un appel ait un sens. Sans [sleep], l'attente
  /// est réelle (`Future.delayed`).
  JsonHttpClient({
    required http.Client httpClient,
    Future<void> Function(Duration)? sleep,
    double Function()? jitter,
    this.maxAttempts = 4,
  }) : _httpClient = httpClient, // ignore: prefer_initializing_formals
       _sleepFn = sleep ?? _sleep,
       // ignore: prefer_initializing_formals
       _jitter = jitter {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'doit être au moins 1 (une tentative)',
      );
    }
  }

  final http.Client _httpClient;

  // Nommé différemment de la fonction de sommet `_sleep` : les deux
  // partagent une portée dans le corps de la classe (le repli
  // `sleep ?? _sleep` y est résolu), et un champ homonyme masquerait la
  // fonction de sommet.
  final Future<void> Function(Duration) _sleepFn;
  final double Function()? _jitter;

  /// Nombre maximal de tentatives, première comprise. La dernière n'attend
  /// jamais avant d'abandonner. Doit être au moins 1 — vérifié au
  /// constructeur, qui lève [ArgumentError] sinon.
  final int maxAttempts;

  /// Récupère [uri] et renvoie son corps JSON décodé, quelle que soit la
  /// forme de sa racine (`List`, `Map` ou scalaire), décodé en UTF-8
  /// explicite (JSON est UTF-8 par définition, RFC 8259).
  ///
  /// Rejoue sur 429 et 5xx (`isRetryable`, C-12), sur une panne réseau
  /// (`http.ClientException`), sur une panne TLS qui traverse `IOClient`
  /// sans être enveloppée (`HandshakeException`/`TlsException`, `on
  /// IOException`) et sur un corps illisible malgré un statut de succès.
  /// Échoue immédiatement, sans attente, sur un statut non rejouable ou sur
  /// un client déjà fermé (`ClientException` dont le message contient
  /// « already closed ») : aucune attente ne le rouvrira.
  ///
  /// Lève toujours un [JsonHttpFailure].
  Future<Object?> getJson(Uri uri) async {
    JsonHttpFailure? lastFailure;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final http.Response response = await _httpClient.get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        );

        if (isSuccess(response.statusCode)) {
          try {
            return jsonDecode(utf8.decode(response.bodyBytes));
          } on FormatException catch (error) {
            lastFailure = JsonHttpUnreadableBody(
              statusCode: response.statusCode,
              detail: '$error',
            );
          }
        } else {
          final JsonHttpStatusFailure failure = JsonHttpStatusFailure(
            statusCode: response.statusCode,
            body: utf8.decode(response.bodyBytes),
          );
          if (!isRetryable(response.statusCode)) {
            throw failure;
          }
          lastFailure = failure;
        }
      } on http.ClientException catch (error) {
        if (error.message.contains('already closed')) {
          throw JsonHttpNetworkFailure(
            'client HTTP déjà fermé, non rejouable : ${error.message}',
          );
        }
        lastFailure = JsonHttpNetworkFailure('panne réseau : ${error.message}');
      } on IOException catch (error) {
        // `IOClient.send` n'enveloppe en `ClientException` que
        // `SocketException` et `HttpException` — une panne TLS
        // (`HandshakeException`/`TlsException`) traverse sans enveloppe,
        // et atterrit ici plutôt que dans le catch ci-dessus.
        lastFailure = JsonHttpNetworkFailure('panne réseau : $error');
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

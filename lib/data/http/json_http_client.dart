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
// UTF-8 explicite, avec attente de rejeu et gigue injectées (NFR-07 : quatre
// tentatives au plus par défaut, recul plafonné à 30 s par
// `delayForAttempt`). Chaque tentative est bornée à [defaultRequestTimeout]
// (10 s, surchargeable au constructeur) : sans borne, un serveur qui accepte
// la connexion et ne répond pas ferait attendre `getJson` sans fin.
//
// Une tentative qui dépasse son délai est **annulée**, pas seulement
// abandonnée : la requête part en `AbortableRequest` (`Client.send`,
// `package:http` 1.6.0, `abortable.dart`) et son `abortTrigger` est complété
// au dépassement, avant l'attente de rejeu — sinon chaque appel laissait
// jusqu'à quatre connexions ouvertes sur un serveur lent, à rebours de NFR-07
// (charge sur les sources publiques). Dans les deux cas mesurés (serveur
// muet ; en-têtes envoyés puis corps calé), `IOClient` ferme alors la
// connexion : avant la réponse, il avorte la requête
// (`HttpClientRequest.abort`) ; pendant la lecture du corps, il injecte
// `RequestAbortedException` dans le flux et annule l'abonnement à la réponse
// (`io_client.dart`). Constaté contre un serveur TCP local le 2026-10-06 : les
// quatre connexions sont fermées, dans les deux cas. Ce qui n'est **pas**
// annulé : la phase de connexion (DNS, connexion TCP, poignée de main TLS).
// `IOClient.send` n'enregistre l'`abortTrigger` qu'**après** `openUrl`, donc
// une tentative abandonnée pendant cette phase garde sa connexion en cours
// jusqu'à ce que le système ou le serveur la termine ; elle est avortée dès
// que `openUrl` rend la main (lu dans le code, non mesuré). Constaté pour la
// poignée de main TLS seule (serveur local qui accepte et ne répond pas à
// `https://` : connexion toujours ouverte deux secondes après l'annulation,
// `HandshakeException` à la coupure du serveur) ; lu dans le code, non mesuré,
// pour le DNS et la connexion TCP. `http.Client()`, tel que `main.dart` le
// construit, ne règle aucun `connectionTimeout`. Pas davantage annulée : une
// redirection suivie vers une autre origine (autre hôte, autre port ou autre
// schéma), tant que les en-têtes de la réponse redirigée ne sont pas arrivés :
// l'annulation détruit la connexion d'origine, laisse ouverte celle de la
// redirection, et peut faire échouer une autre requête en vol qui réutilisait
// la connexion d'origine. Constaté contre deux serveurs locaux le 2026-10-06 ;
// aucune des sources appelées ne redirige à ce jour. `MockClient` n'observe
// pas `abortTrigger` : `Future.timeout` reste nécessaire pour rendre la main à
// l'appelant avec lui, et avec tout client qui n'annule pas.
//
// Trois pannes sont distinguées **par type**, parce que trois causes
// différentes appellent trois diagnostics différents, et qu'un appelant doit
// pouvoir distinguer une requête refusée d'une source injoignable sans
// analyser un message : un statut HTTP hors succès
// ([JsonHttpStatusFailure]), une panne réseau ([JsonHttpNetworkFailure]), un
// corps qui prétend être un succès mais ne se décode pas en JSON
// ([JsonHttpUnreadableBody], rejouable aussi — un 206 tronqué en cours de
// transfert n'est pas la faute de la requête). La panne réseau recouvre :
// - `http.ClientException`, levée par `IOClient` sur coupure ou échec DNS ;
// - un échec TLS, qui n'est **pas** enveloppé : `IOClient.send` n'enveloppe
//   que `SocketException` et `HttpException` (`package:http` 1.6.0,
//   `io_client.dart`), donc `HandshakeException` et `TlsException`
//   (`dart:io`) traversent tels quels et sont rattrapées ici via `on
//   IOException`, avec le même traitement rejouable — sans le moindre statut,
//   c'est la panne transitoire la plus courante ;
// - une `FormatException` levée par le transport lui-même, avant qu'aucune
//   `http.Response` ne soit rendue, qui traverse `IOClient` pour la même
//   raison : un corps annoncé
//   `Content-Encoding: gzip` mais corrompu (`Filter error, bad data`), ou une
//   redirection dont `Location` est mal formée. Rejouable, comme les autres ;
// - un délai d'attente de tentative dépassé (`TimeoutException`), rejouable.
//
// Un statut non rejouable (4xx sauf 429, `isRetryable` en décide à lui seul,
// C-06/C-12) échoue immédiatement, sans attente : le rejouer ne corrigerait
// pas une requête mal formée. Un client déjà fermé (`ClientException` dont le
// message contient « already closed ») n'est pas davantage rejoué : aucune
// attente ne rouvrira le client. Ainsi, ni `FormatException` ni
// `TimeoutException` ne sort nue de `getJson`. Restent hors du contrat,
// parce que ce sont des `Error` et qu'on n'en attrape pas : une redirection
// vers un schéma autre que `http`/`https` ou sans hôte, et un statut
// inférieur à 100 (`ArgumentError`, constatées contre un serveur local le
// 2026-10-06, jamais sur une API réelle). Elles sortent telles quelles,
// comme un bogue.
//
// Le corps est toujours décodé en UTF-8 explicite (`utf8.decode
// (response.bodyBytes)`), jamais via `response.body` : JSON est UTF-8 par
// définition (RFC 8259), alors que `response.body` retombe sur latin1 dès
// que l'en-tête `Content-Type` ne précise pas de charset (`package:http`
// 1.6.0, `response.dart`) — un accent d'un libellé (`Pré-validée`)
// arriverait alors corrompu jusqu'à l'écran. Le décodage est strict pour un
// succès (un octet invalide rend le corps illisible, rejouable) ; seul le
// corps d'un échec, qui n'est qu'un diagnostic, est décodé avec
// `allowMalformed` : il ne doit ni sauter le rejeu ni faire échapper une
// `FormatException` nue.
//
// Le tirage aléatoire de la gigue n'existe qu'à un seul endroit du produit,
// `lib/data/http/retry.dart` : ce fichier n'importe pas `dart:math`, et
// délègue à [delayForAttempt] pour chaque attente de rejeu.
import 'dart:async';
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

  /// Corps de la réponse, décodé en UTF-8 **avec tolérance**
  /// (`allowMalformed`) : un octet invalide devient U+FFFD plutôt que de
  /// lever. Ce n'est qu'un diagnostic — un échec ne doit pas dépendre de
  /// l'encodage de son propre message.
  final String body;

  @override
  String get message => 'statut $statusCode : $body';

  @override
  String toString() => 'JsonHttpStatusFailure: $message';
}

/// Panne réseau (coupure, DNS, TLS), réponse corrompue pendant le transfert
/// (gzip invalide, redirection mal formée), délai d'attente de tentative
/// dépassé, ou client déjà fermé : aucune réponse exploitable n'est parvenue.
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

/// Durée maximale d'**une tentative** (envoi, réponse et lecture du corps
/// comprises), avant qu'elle soit annulée et rejouée comme une panne réseau :
/// 10 s. Arbitrage du commanditaire du 2026-10-06 : sans borne, un
/// serveur qui accepte la connexion et ne répond pas laisse `getJson` — et
/// l'écran qui l'attend — sans fin, sans bouton « Réessayer ». Surchargeable
/// au constructeur de [JsonHttpClient], pour les tests. Avec quatre tentatives
/// et les attentes de rejeu (`retry.dart`), le pire cas avant l'échec est de
/// 43,5 à 47 s ; un serveur lent mais vivant, qui répondrait en plus de 10 s,
/// échoue lui aussi.
const Duration defaultRequestTimeout = Duration(seconds: 10);

/// Attente réelle entre deux tentatives — jamais utilisée dans un test, où
/// [JsonHttpClient.new] reçoit un `sleep` injecté qui n'attend pas vraiment.
Future<void> _sleep(Duration duration) => Future<void>.delayed(duration);

/// [duration] en secondes entières si elle l'est (`10 s`), sinon en
/// millisecondes (`20 ms`) : le message d'un délai dépassé reste exact pour
/// la durée injectée dans un test comme pour la valeur par défaut.
String _describeDuration(Duration duration) {
  return duration.inMilliseconds % 1000 == 0
      ? '${duration.inSeconds} s'
      : '${duration.inMilliseconds} ms';
}

/// Client HTTP GET qui rend un corps JSON quelconque, avec recul exponentiel
/// à gigue injectée (C-12, NFR-07) sur les pannes rejouables, chaque
/// tentative étant bornée à [requestTimeout].
final class JsonHttpClient {
  /// Lève [ArgumentError] si [maxAttempts] est inférieur à 1 : une tentative
  /// est le minimum pour qu'un appel ait un sens. Sans [sleep], l'attente
  /// est réelle (`Future.delayed`). Sans [requestTimeout], chaque tentative
  /// est bornée à [defaultRequestTimeout].
  JsonHttpClient({
    required this._httpClient,
    Future<void> Function(Duration)? sleep,
    this._jitter,
    this.maxAttempts = 4,
    this.requestTimeout = defaultRequestTimeout,
  }) : _sleepFn = sleep ?? _sleep {
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

  /// Durée maximale d'une tentative, corps lu compris. Au-delà, la tentative
  /// est annulée et rejouée comme une panne réseau
  /// ([JsonHttpNetworkFailure]).
  final Duration requestTimeout;

  /// Récupère [uri] et renvoie son corps JSON décodé, quelle que soit la
  /// forme de sa racine (`List`, `Map` ou scalaire), décodé en UTF-8
  /// explicite (JSON est UTF-8 par définition, RFC 8259).
  ///
  /// Rejoue sur 429 et 5xx (`isRetryable`, C-12), sur une panne réseau
  /// (`http.ClientException`), sur une panne TLS qui traverse `IOClient`
  /// sans être enveloppée (`HandshakeException`/`TlsException`, `on
  /// IOException`), sur une `FormatException` levée par le transport
  /// lui-même (corps `gzip` corrompu, redirection mal formée), sur une
  /// tentative qui dépasse [requestTimeout] et sur un corps illisible malgré
  /// un statut de succès. Échoue immédiatement, sans attente, sur un statut
  /// non rejouable ou sur un client déjà fermé (`ClientException` dont le
  /// message contient « already closed ») : aucune attente ne le rouvrira.
  ///
  /// Une tentative qui dépasse [requestTimeout] est annulée
  /// (`AbortableRequest.abortTrigger`, par `Client.send`) avant l'attente de
  /// rejeu : dans les deux cas mesurés (serveur muet ; en-têtes envoyés puis
  /// corps calé), `IOClient` ferme sa connexion. Son résultat ou son erreur
  /// tardifs — dont l'exception d'annulation — sont ignorés (`Future.timeout`),
  /// sans erreur non gérée. Une réponse arrivée dans le délai n'est jamais
  /// annulée. La phase de connexion (DNS, TCP, poignée de main TLS) n'est pas
  /// interrompue par l'annulation, pas plus qu'une redirection suivie vers une
  /// autre origine (autre hôte, autre port ou autre schéma) tant que les
  /// en-têtes de la réponse redirigée ne sont pas arrivés : l'annulation
  /// détruit la connexion d'origine, laisse ouverte celle de la redirection, et
  /// peut faire échouer une autre requête en vol qui réutilisait la connexion
  /// d'origine. Constaté contre deux serveurs locaux le 2026-10-06 ; aucune des
  /// sources appelées ne redirige à ce jour. Voir l'en-tête de ce fichier.
  ///
  /// Toute panne attrapée ici sort en [JsonHttpFailure]
  /// ([JsonHttpNetworkFailure], [JsonHttpStatusFailure],
  /// [JsonHttpUnreadableBody]). Une `Error` n'est pas attrapée.
  Future<Object?> getJson(Uri uri) async {
    JsonHttpFailure? lastFailure;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final http.Response response = await _fetchWithin(uri);

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
          // `allowMalformed` pour CE corps seulement : c'est un diagnostic,
          // pas une donnée. Un corps d'échec qui n'est pas de l'UTF-8 valide
          // ne doit ni sauter le rejeu ni échapper en `FormatException` nue.
          // Le décodage du corps de succès, lui, reste strict.
          final JsonHttpStatusFailure failure = JsonHttpStatusFailure(
            statusCode: response.statusCode,
            body: utf8.decode(response.bodyBytes, allowMalformed: true),
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
      } on TimeoutException {
        // `Future.timeout` de `_fetchWithin` : la tentative n'a pas abouti
        // dans [requestTimeout]. Panne réseau rejouable, comme une coupure.
        lastFailure = JsonHttpNetworkFailure(
          "délai d'attente de ${_describeDuration(requestTimeout)} dépassé",
        );
      } on FormatException catch (error) {
        // Une `FormatException` NUE qui sort de l'envoi (`send`) ou de la
        // lecture du corps (`Response.fromStream`) vient du transport
        // lui-même, hors de toute réponse : `IOClient` ne convertit que
        // `SocketException` et `HttpException`. Deux cas établis par
        // exécution : un corps annoncé `Content-Encoding: gzip` mais
        // corrompu (`Filter error, bad data`), et une redirection dont
        // `Location` est mal formée (`Uri.parse`). C'est une panne de
        // transfert, rejouable comme les autres. Le décodage JSON du corps de
        // succès a son propre `try`, plus haut : il reste un
        // `JsonHttpUnreadableBody`.
        lastFailure = JsonHttpNetworkFailure(
          'réponse corrompue pendant le transfert : $error',
        );
      }

      await _waitBeforeNextAttempt(attempt);
    }

    throw lastFailure!;
  }

  /// Une tentative : requête `GET` annulable, corps lu, le tout borné à
  /// [requestTimeout]. Au dépassement, l'annulation est déclenchée **avant**
  /// que l'échec ne remonte, donc avant la tentative suivante.
  ///
  /// `Future.timeout` reste nécessaire : il rend la main à l'appelant même
  /// d'un client qui n'observe pas `abortTrigger` (`MockClient`, par
  /// exemple, ne l'observe pas). Une erreur qui arrive tard sur le futur
  /// abandonné — l'exception d'annulation que `IOClient` injecte dans
  /// l'envoi ou dans le corps — n'est jamais non gérée : `Future.timeout`
  /// s'abonne au futur d'origine avec un gestionnaire d'erreur
  /// (`future_impl.dart`, SDK 3.13.3), et l'ignore une fois le délai écoulé.
  Future<http.Response> _fetchWithin(Uri uri) {
    final Completer<void> cancellation = Completer<void>();
    return _fetch(uri, cancellation.future).timeout(
      requestTimeout,
      onTimeout: () {
        cancellation.complete();
        throw TimeoutException('Future not completed', requestTimeout);
      },
    );
  }

  Future<http.Response> _fetch(Uri uri, Future<void> abortTrigger) async {
    final http.AbortableRequest request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abortTrigger,
    )..headers['Accept'] = 'application/json';
    return http.Response.fromStream(await _httpClient.send(request));
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

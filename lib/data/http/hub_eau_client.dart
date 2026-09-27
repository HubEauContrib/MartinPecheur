// [HubEauClient.getJson] sert **tous** les endpoints Hub'Eau — hydrométrie
// v2 et écoulement ONDE v1 (`lib/data/http/onde_uris.dart`) : il prend
// n'importe quelle URI du même hôte et exige une racine JSON **objet**.
// Le rejeu (429/5xx, `isRetryable`), l'acceptation de 200 et 206
// (`isSuccess`, C-06), le décodage UTF-8 explicite, l'attente et la gigue
// injectées vivent dans le transport qu'il délègue,
// `lib/data/http/json_http_client.dart` (extrait en D1 de T2) — la seule
// boucle de rejeu du produit. Recréer un second client, pour ONDE ou une
// autre API, aurait recopié cette logique de rejeu — ce que le produit
// interdit. Les constructeurs d'URI de ce fichier, eux, restent propres à
// l'hydrométrie v2 (ADR-001 : uniquement la v2, la v1 est arrêtée depuis le 05/05/2025,
// C-01) ; `checkPageSize`, `maxPageSize` et `formatDateUtc` vivent dans
// `lib/data/http/hub_eau_paging.dart`, communs aux deux endpoints, pour que
// `onde_uris.dart` n'ait pas à importer ce fichier pour deux fonctions
// utilitaires. `date_debut_obs_elab` est un paramètre requis de [obsElabUri],
// jamais optionnel : sans lui, `sort` est ignoré et la réponse commence au
// 1er janvier 1900 (C-04, reproduit le 2026-09-13, voir
// docs/sources/hubeau-hydrometrie.md). `size` au-delà de [maxPageSize] fait
// répondre l'API en 400 (C-08) — on refuse à la construction plutôt que de
// laisser partir une requête qui échouera à coup sûr. `code_entite` et
// `code_station` ne reçoivent qu'un [StationCode] à dix caractères, jamais un
// code site à huit (C-05).
//
// Les trois pannes que le transport distingue par type — statut HTTP hors
// succès, panne réseau (TLS comprise), corps illisible malgré un succès —
// arrivent ici en [JsonHttpFailure] et repartent en [HubEauFailure], dont le
// [HubEauFailure.message] recopie mot pour mot celui du transport : le
// contrat de ce client n'a pas bougé à l'extraction. Une racine JSON qui
// n'est pas un objet (un tableau par exemple) échoue immédiatement, sans
// rejeu : aucun endpoint Hub'Eau n'en rend, et la rejouer ne changerait pas
// sa forme.
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/hub_eau_paging.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';

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
  checkPageSize(size);
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
  checkPageSize(size);
  return _uri('obs_elab', <String, String>{
    'code_entite': station.value,
    'grandeur_hydro_elab': 'QmnJ',
    'date_debut_obs_elab': formatDateUtc(since),
    'size': '$size',
  });
}

/// URI de `/referentiel/stations`, filtrée sur un unique [station].
Uri referentielStationUri(StationCode station) {
  return _uri('referentiel/stations', <String, String>{
    'code_station': station.value,
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

/// Client HTTP de l'API hydrométrie v2, avec recul exponentiel à gigue
/// injectée (C-12) sur les pannes rejouables — délégués à [JsonHttpClient].
final class HubEauClient {
  /// Lève [ArgumentError] si [maxAttempts] est inférieur à 1 : une tentative
  /// est le minimum pour qu'un appel ait un sens (vérifié par
  /// [JsonHttpClient.new]). Sans [sleep], l'attente réelle par défaut est
  /// celle du transport.
  HubEauClient({
    required http.Client httpClient,
    Future<void> Function(Duration)? sleep,
    double Function()? jitter,
    this.maxAttempts = 4,
  }) : _transport = JsonHttpClient(
         httpClient: httpClient,
         sleep: sleep,
         jitter: jitter,
         maxAttempts: maxAttempts,
       );

  final JsonHttpClient _transport;

  /// Nombre maximal de tentatives, première comprise. La dernière n'attend
  /// jamais avant d'abandonner. Doit être au moins 1 — vérifié au
  /// constructeur, qui lève [ArgumentError] sinon.
  final int maxAttempts;

  /// Récupère [uri] par [JsonHttpClient.getJson] et renvoie son corps décodé
  /// en objet JSON, décodé en UTF-8 explicite (JSON est UTF-8 par
  /// définition, RFC 8259). Tout échec du transport est rendu en
  /// [HubEauFailure], avec le même message.
  ///
  /// Rejoue sur 429 et 5xx (`isRetryable`, C-12), sur une panne réseau
  /// (`http.ClientException`), sur une panne TLS qui traverse `IOClient`
  /// sans être enveloppée (`HandshakeException`/`TlsException`, `on
  /// IOException`) et sur un corps illisible malgré un statut de succès.
  /// Échoue immédiatement, sans attente, sur un statut non rejouable, sur
  /// un corps JSON qui n'est pas un objet, ou sur un client déjà fermé
  /// (`ClientException` dont le message contient « already closed ») :
  /// aucune attente ne le rouvrira.
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final Object? decoded;
    try {
      decoded = await _transport.getJson(uri);
    } on JsonHttpFailure catch (failure) {
      throw HubEauFailure(failure.message);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw HubEauFailure(
      'corps JSON invalide : un objet est attendu, reçu '
      '${decoded.runtimeType} (un tableau par exemple)',
    );
  }

  /// Ferme le client HTTP sous-jacent.
  void close() => _transport.close();
}

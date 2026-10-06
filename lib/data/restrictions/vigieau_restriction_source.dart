// `RestrictionSource` sur VigiEau (D3 de T2, conception T2 § 3 et § 4.2) :
// URI (`vigieau_uris.dart`), transport partage (`JsonHttpClient`, D1),
// mapper (`zones_mapper.dart`), horloge injectee pour `retrievedAt`.
//
// Correspondance des echecs — trois branches fermees, jamais un `message`
// unique (`RestrictionLookupFailure`) :
// - `JsonHttpStatusFailure` : `isRetryable(statusCode)` (429/5xx, rejeux
//   epuises) → `SourceInjoignable` — la source n'a pas su repondre du tout ;
//   tout autre statut (400, 409…) → `RequeteRefusee(statusCode)` — la
//   source A repondu, mais a refuse ce point. Le corps d'un echec, meme s'il
//   n'est pas de l'UTF-8 valide, ne change rien a cette distinction : il est
//   decode avec tolerance (`allowMalformed`) par `JsonHttpClient`, c'est un
//   diagnostic ;
// - `JsonHttpNetworkFailure` (panne reseau ou TLS, reponse corrompue pendant
//   le transfert, delai d'attente d'une tentative depasse — apres rejeux)
//   → `SourceInjoignable` ;
// - `JsonHttpUnreadableBody` (succes HTTP, corps non JSON) → `ReponseIllisible` ;
// - `ReponseIllisible` du mapper (racine non tableau, champ obligatoire
//   absent ou mal type, AR-2) → propagee telle quelle, sans clause : ce
//   n'est aucun des types attrapes ici.
//
// Aucune `Exception` levee par un transport `package:http` ne s'echappe sous
// un autre type (conception T2 § 3). `getJson` attrape tout ce qui sort de
// l'envoi de la requete et de la lecture de son corps (`Client.send`,
// `Response.fromStream`) : `ClientException`, `IOException` (une panne TLS, que
// `IOClient` n'enveloppe pas), `FormatException` (corps `gzip` corrompu,
// redirection mal formee — levees par le transport avant qu'aucune
// `http.Response` ne soit rendue) et `TimeoutException` (delai d'attente
// depasse) ; il decode le corps d'un echec avec tolerance (`allowMalformed`),
// de sorte que seul un corps de succes illisible devient `JsonHttpUnreadableBody`.
// `zonesUri` ne leve rien (`GeoPoint` valide ses coordonnees a la construction)
// et `mapZones` ne leve que `ReponseIllisible`. Restent des `Error`, jamais
// attrapees ici : `ArgumentError` sur une redirection vers un schema non HTTP ou
// sans hote, ou sur un statut inferieur a 100 ; le ViewModel les recoit par sa
// clause `on Error`.
import 'package:martinpecheur/data/http/http_status.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/data/restrictions/vigieau_uris.dart';
import 'package:martinpecheur/data/restrictions/zones_mapper.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// `RestrictionSource` sur l'API VigiEau, version `0.1`. Un appel par
/// point, sans `profil` (AR-1) : le filtrage par profil se fait dans le
/// domaine, sur `AlertZone.usagesFor`.
final class VigieauRestrictionSource implements RestrictionSource {
  /// [now] fournit l'horloge de `retrievedAt` ; sans elle, `DateTime.now`
  /// (reelle). Les tests injectent une horloge fixe.
  VigieauRestrictionSource({required this._client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final JsonHttpClient _client;
  final DateTime Function() _now;

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) async {
    try {
      final Object? json = await _client.getJson(zonesUri(point));
      return mapZones(json, point: point, retrievedAt: _now().toUtc());
    } on JsonHttpStatusFailure catch (echec) {
      if (isRetryable(echec.statusCode)) {
        throw SourceInjoignable(echec.message);
      }
      throw RequeteRefusee(
        statusCode: echec.statusCode,
        diagnostic: echec.message,
      );
    } on JsonHttpNetworkFailure catch (echec) {
      throw SourceInjoignable(echec.message);
    } on JsonHttpUnreadableBody catch (echec) {
      throw ReponseIllisible(echec.message);
    }
  }
}

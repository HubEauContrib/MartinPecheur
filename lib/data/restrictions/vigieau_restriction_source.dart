// `RestrictionSource` sur VigiEau (D3 de T2, conception T2 § 3 et § 4.2) :
// URI (`vigieau_uris.dart`), transport partage (`JsonHttpClient`, D1),
// mapper (`zones_mapper.dart`), horloge injectee pour `retrievedAt`.
//
// Correspondance des echecs — trois branches fermees, jamais un `message`
// unique (`RestrictionLookupFailure`) :
// - `JsonHttpStatusFailure` : `isRetryable(statusCode)` (429/5xx, rejeux
//   epuises) → `SourceInjoignable` — la source n'a pas su repondre du tout ;
//   tout autre statut (400, 409…) → `RequeteRefusee(statusCode)` — la
//   source A repondu, mais a refuse ce point ;
// - `JsonHttpNetworkFailure` (panne reseau ou TLS) → `SourceInjoignable` ;
// - `JsonHttpUnreadableBody` (succes HTTP, corps non JSON) → `ReponseIllisible` ;
// - `ReponseIllisible` du mapper (racine non tableau, champ obligatoire
//   absent ou mal type, AR-2) → propagee telle quelle ;
// - `FormatException` BRUTE : `JsonHttpStatusFailure.body` decode le corps
//   en UTF-8 explicite (`utf8.decode(response.bodyBytes)`) au moment ou il
//   est construit, hors de toute boucle `try`/`catch` de `JsonHttpClient`
//   (D1) — un corps d'echec qui n'est pas de l'UTF-8 valide fait donc
//   s'echapper une `FormatException` NUE de `getJson`. Elle est rattrapee
//   ici comme une reponse illisible : c'est une exception de decodage, au
//   meme titre qu'un corps de succes non JSON.
//
// Rien ne s'echappe sous un autre type (conception T2 § 3) : les cinq
// branches ci-dessus couvrent tout ce que `JsonHttpClient.getJson` et
// `mapZones` peuvent lever.
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
    } on ReponseIllisible {
      rethrow;
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
    } on FormatException catch (erreur) {
      throw ReponseIllisible('$erreur');
    }
  }
}

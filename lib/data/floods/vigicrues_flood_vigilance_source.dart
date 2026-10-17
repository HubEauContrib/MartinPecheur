// `FloodVigilanceSource` sur Vigicrues (W2 de T4, cadrage § 6) : adresse
// (`vigicrues_endpoint.dart`), transport partage (`JsonHttpClient`), mapper
// (`flood_vigilance_mapper.dart`).
//
// Correspondance des echecs, la meme que celle de la source des restrictions :
// - `JsonHttpStatusFailure` : statut rejouable (429/5xx, rejeux epuises) →
//   `VigilanceInjoignable` ; tout autre statut → `VigilanceRefusee` ;
// - `JsonHttpNetworkFailure` → `VigilanceInjoignable` ;
// - `JsonHttpUnreadableBody` (succes HTTP, corps non JSON — les erreurs de
//   Vigicrues sont en HTML, `VC-10`) → `VigilanceIllisible` ;
// - `VigilanceIllisible` du mapper → propagee telle quelle.
import 'package:martinpecheur/data/floods/flood_vigilance_mapper.dart';
import 'package:martinpecheur/data/floods/vigicrues_endpoint.dart';
import 'package:martinpecheur/data/http/http_status.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';

/// La carte de vigilance crues lue sur le GeoJSON national de Vigicrues.
final class VigicruesFloodVigilanceSource implements FloodVigilanceSource {
  VigicruesFloodVigilanceSource({required this._client});

  final JsonHttpClient _client;

  @override
  Future<FloodVigilanceMap> current() async {
    try {
      final Object? json = await _client.getJson(vigicruesInformationUri);
      return mapFloodVigilance(json);
    } on JsonHttpStatusFailure catch (echec) {
      if (isRetryable(echec.statusCode)) {
        throw VigilanceInjoignable(echec.message);
      }
      throw VigilanceRefusee(
        statusCode: echec.statusCode,
        diagnostic: echec.message,
      );
    } on JsonHttpNetworkFailure catch (echec) {
      throw VigilanceInjoignable(echec.message);
    } on JsonHttpUnreadableBody catch (echec) {
      throw VigilanceIllisible(echec.message);
    }
  }
}

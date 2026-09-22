// Implémentation d'AcknowledgementRepository adossée à `shared_preferences`
// (ADR-011) : une seule clé, une seule chaîne — jamais un booléen (BR-012).
// Le dépôt reste bête (cf. domain/repositories/repositories.dart) : une
// valeur inattendue (chaîne vide) est rendue telle quelle, ce n'est pas à
// lui de décider qu'elle ne vaut pas acquittement.
//
// Signature du plan (`docs/superpowers/plans/2026-09-13-t1-...md`, tâche
// W1) : `SharedPreferences? preferences` injecté pour les tests, résolu par
// défaut via `SharedPreferences.getInstance()`. Le paquet 2.5.5 documente
// cette classe comme l'API historique et suggère `SharedPreferencesAsync`
// ou `SharedPreferencesWithCache` pour du code neuf, sans la déprécier :
// la signature du plan compile proprement, elle est donc conservée telle
// quelle ici. Migrer vers l'API async ne toucherait que ce fichier : c'est
// ce que garantit l'interface du domaine.
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show AcknowledgementRepository;
import 'package:shared_preferences/shared_preferences.dart';

/// Clé de stockage de la version acquittée — nommée une seule fois ici.
const String _acknowledgedVersionKey = 'acknowledged_warning_version';

/// Dépôt de l'acquittement de l'avertissement initial (BR-012), adossé à
/// `shared_preferences` (ADR-011).
final class SharedPreferencesAcknowledgementRepository
    implements AcknowledgementRepository {
  SharedPreferencesAcknowledgementRepository({this._preferences});

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _resolved async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<String?> readAcknowledgedVersion() async {
    final SharedPreferences preferences = await _resolved;
    return preferences.getString(_acknowledgedVersionKey);
  }

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    final SharedPreferences preferences = await _resolved;
    await preferences.setString(_acknowledgedVersionKey, version);
  }
}

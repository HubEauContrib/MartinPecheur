// Double de `SharedPreferences` (S3 de T3), calqué sur ce que fait le paquet
// 2.5.5 (`lib/src/shared_preferences_legacy.dart`) : `getString` lit le cache
// mémoire, `setString` ÉCRIT LE CACHE AVANT d'appeler le magasin. Après une
// écriture en échec, le cache porte donc une valeur que le magasin n'a pas.
//
// Seules `getString` et `setString` sont réalisées : tout autre membre lève
// un `NoSuchMethodError`, ce qui verrouille le dépôt sur ces deux-là.
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

final class FakeSharedPreferences implements SharedPreferences {
  /// [initial] remplit le cache ET le magasin.
  FakeSharedPreferences([
    Map<String, Object> initial = const <String, Object>{},
  ]) : cache = Map<String, Object>.of(initial),
       disk = Map<String, Object>.of(initial);

  /// Ce que rend `getString` : le cache mémoire du paquet.
  final Map<String, Object> cache;

  /// Ce que le magasin a réellement écrit.
  final Map<String, Object> disk;

  /// L'issue des écritures à venir, consommée dans l'ordre : `true` écrit le
  /// magasin, `false` le refuse, tout autre objet est levé. Vide : `true`.
  final List<Object> writeOutcomes = <Object>[];

  /// Toute valeur passée à `setString`, dans l'ordre, quelle que soit l'issue.
  final List<String> writtenValues = <String>[];

  /// Posée : `setString` attend qu'elle aboutisse, le cache déjà écrit.
  Completer<void>? writeGate;

  @override
  String? getString(String key) => cache[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    writtenValues.add(value);
    cache[key] = value;
    await writeGate?.future;

    final Object outcome = writeOutcomes.isEmpty
        ? true
        : writeOutcomes.removeAt(0);
    if (outcome == true) {
      disk[key] = value;
      return true;
    }
    if (outcome == false) {
      return false;
    }
    throw outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Egalite structurelle des collections et validation UTC, partagees par le
// modele des restrictions (`alert_zone.dart`, `zones_at_point.dart`) —
// conception T2 § 2. Dart pur, AUCUN import : ni `package:collection`, ni
// `package:flutter/foundation.dart`, verrouille par le confinement du
// domaine (`test/architecture/domain_isolation_test.dart`). Factorise
// depuis les deux fichiers, qui portaient chacun une copie de ces mêmes
// fonctions.

/// Egalite structurelle de deux listes : meme longueur, memes elements dans
/// le meme ordre.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Egalite structurelle de deux ensembles : meme cardinal, memes elements,
/// independante de l'ordre.
bool setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  return a.every(b.contains);
}

/// Hash d'un ensemble, coherent avec [setEquals] : un XOR des hash de
/// chaque element, qui ne depend donc pas de leur ordre.
int setHash<T>(Set<T> set) {
  int hash = 0;
  for (final T item in set) {
    hash ^= item.hashCode;
  }
  return hash;
}

/// Valide que [value] est en UTC ; leve une [ArgumentError] nommee [name]
/// sinon. Une date de validite ou un instant de recuperation en heure
/// locale se lirait a la mauvaise date apres minuit (`BR-001`).
DateTime requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'doit etre en UTC');
  }
  return value;
}

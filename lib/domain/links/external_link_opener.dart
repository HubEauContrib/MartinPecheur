// Le port d'ouverture de lien (T2, B2 ; conception T2 § 6, `O10`) : un
// ViewModel demande l'ouverture d'une adresse HORS de l'application — l'arrete
// en PDF, le site public de la source — sans connaitre la bibliotheque qui le
// fait. L'implementation vit sous `lib/data/links/`, choisie par `main.dart` ;
// aucune tranche n'importe la bibliotheque (`ADR-014`, `features-vers-data`).
//
// Un echec d'ouverture est un RESULTAT (`false`), pas une exception : l'ecran
// laisse alors l'adresse brute visible (`UC-002 A6`), sans pretendre que le
// document existe.
//
// ⚠️ Ce fichier vit sous `lib/domain/` : Dart pur, aucun `package:flutter`
// (`test/architecture/domain_isolation_test.dart`).

/// Ouvre une adresse hors de l'application.
abstract interface class ExternalLinkOpener {
  /// Demande l'ouverture de [uri] hors de l'application. Rend `true` si la
  /// plateforme a accepte de l'ouvrir, `false` sinon — jamais une exception
  /// de plateforme.
  Future<bool> open(Uri uri);
}

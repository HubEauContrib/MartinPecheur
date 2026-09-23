// La pagination et le format de date communs à tous les endpoints Hub'Eau —
// hydrométrie v2 (`lib/data/http/hub_eau_client.dart`) et écoulement ONDE v1
// (`lib/data/http/onde_uris.dart`). Extrait dans son propre fichier, sans
// aucun import, pour qu'`onde_uris.dart` n'ait pas à dépendre de
// `hub_eau_client.dart` — un endpoint n'a aucune raison d'importer le module
// d'un autre pour deux fonctions utilitaires.
//
// `checkPageSize` et `formatDateUtc` sont réutilisées telles quelles par les
// constructeurs d'URI des deux endpoints, jamais recopiées : c'est le point
// que verrouille `test/data/http/hub_eau_paging_test.dart`.

/// Taille de page maximale acceptée par Hub'Eau avant de répondre `400`
/// (C-08, constaté sur `/observations_tr`) — commune aux endpoints
/// hydrométrie v2 et ONDE v1, pas propre à un seul.
const int maxPageSize = 20000;

/// Vérifie qu'une taille de page est acceptable pour Hub'Eau (au moins 1, au
/// plus [maxPageSize]) — commune à l'hydrométrie et à ONDE, toutes deux
/// exposées par la même famille d'API. Lève une [ArgumentError] sinon.
void checkPageSize(int size) {
  if (size < 1) {
    throw ArgumentError.value(size, 'size', 'doit être au moins 1');
  }
  if (size > maxPageSize) {
    throw ArgumentError.value(
      size,
      'size',
      'dépasse maxPageSize ($maxPageSize) — l\'API répond 400 (C-08)',
    );
  }
}

/// Formate [date] en `AAAA-MM-JJ`, tel qu'attendu par les paramètres de date
/// Hub'Eau. Convertit lui-même en UTC (`date.toUtc()`) : une date locale
/// n'est jamais formatée telle quelle, l'appelant n'a pas à y penser.
String formatDateUtc(DateTime date) {
  final DateTime utc = date.toUtc();
  final String year = utc.year.toString().padLeft(4, '0');
  final String month = utc.month.toString().padLeft(2, '0');
  final String day = utc.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

// Le seul formateur de date du projet (Task H1, ajoutée le 2026-09-22, avant
// `W4`). Avant lui, le formatage de date était recopié dans QUATRE fichiers
// d'affichage — `_utcDateAndTime` (`station_sheet_view_model.dart`),
// `formatMeasuredAt` (`station_summary_sheet.dart`), `formatCampaignDate`
// (`onde_summary_sheet.dart`), `_formatObservationDate` (`onde_marker.dart`) —,
// les trois premiers en UTC explicite. `lib/data/http/hub_eau_paging.dart`
// formate aussi une date avec `padLeft(2` : c'est le format FILAIRE
// `AAAA-MM-JJ` de l'API, pas un affichage, il n'est pas concerné.
//
// Deux natures de date, jamais confondues (décision 12, arbitrage du
// 2026-09-22) :
// - un INSTANT (une mesure hydrométrique, `2026-08-27T08:00:00Z`) s'affiche
//   en HEURE LOCALE, SANS suffixe de fuseau — « 27/08/2026 à 10:00 » pour une
//   mesure de 08:00 UTC en été (UTC+2, Paris). Le décalage est demandé POUR
//   CET INSTANT : l'heure d'été dépend de la date affichée, pas du jour où
//   l'on regarde.
// - une DATE CALENDAIRE (une campagne ONDE, sans heure, `T-08`) ne se
//   convertit JAMAIS : la lire dans un fuseau à l'ouest de Greenwich la
//   reculerait d'un jour.
//
// Le fuseau est INJECTÉ partout où un test l'observe : sans cela, le résultat
// dépendrait de la machine qui lance `flutter test` (CLAUDE.md,
// anti-hallucination — un fait constaté, jamais supposé).
//
// Emplacement : `lib/domain/formatting/`, jamais une tranche. Ce formateur
// est lu par un ViewModel (`StationSheetViewModel`) et par des vues de TROIS
// tranches (`station_sheet`, `onde_sheet`, `map`) — une tranche ne peut pas
// l'héberger (`feature-vers-feature`), et `lib/features/shared/` est réservé
// aux WIDGETS (amendement d'`ADR-014`). Le domaine porte déjà des textes
// affichés en Dart pur (`flowCategoryLabel`, `stationMapStateLabel`) : ce
// fichier suit le même principe.
//
// Aucun import hors `dart:core` : `test/architecture/domain_isolation_test.dart`
// reste vert.

/// Le décalage horaire à appliquer à l'instant UTC [utcInstant] pour
/// l'afficher en heure locale. Injecté partout où un test l'observe — sans
/// cela, le résultat dépendrait du fuseau de la machine qui exécute le test.
typedef UtcOffsetOf = Duration Function(DateTime utcInstant);

/// La SEULE lecture du fuseau de la machine, utilisée par défaut en
/// production : le décalage de [utcInstant] converti en heure locale de ce
/// poste.
Duration systemUtcOffsetOf(DateTime utcInstant) =>
    utcInstant.toLocal().timeZoneOffset;

/// Formate l'INSTANT [instant] en `'JJ/MM/AAAA à HH:MM'`, en heure locale et
/// SANS suffixe de fuseau (décision 12). [offsetOf] est demandé pour
/// l'instant lui-même, ramené en UTC au préalable — l'heure d'été dépend de
/// la date affichée, pas du jour où l'on regarde.
String formatLocalDateTime(
  DateTime instant, {
  UtcOffsetOf offsetOf = systemUtcOffsetOf,
}) {
  final DateTime utcInstant = instant.toUtc();
  final DateTime local = utcInstant.add(offsetOf(utcInstant));
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/'
      '${local.year} à ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// Formate la DATE CALENDAIRE [date] en `'JJ/MM/AAAA'`, SANS aucune
/// conversion de fuseau : une campagne ONDE n'a pas d'heure (`T-08`), et la
/// convertir la reculerait d'un jour à l'ouest de Greenwich. Les composantes
/// sont lues en UTC — c'est la convention du mapper, qui rend `observedAt`
/// en UTC.
String formatCalendarDate(DateTime date) {
  final DateTime utc = date.toUtc();
  return '${_twoDigits(utc.day)}/${_twoDigits(utc.month)}/${utc.year}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

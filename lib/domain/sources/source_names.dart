// Noms de source affichés (Task W4). Dart pur, transverse — hors de
// `warning_texts.dart` : un nom de source n'est pas un texte d'avertissement.
//
// Les premiers lecteurs sont les DEUX fiches, pas la fenêtre d'avertissement
// (`WarningLink`, `lib/features/shared/warning_link.dart`) — celle-ci ne
// nomme aucune source, seulement le texte général et une phrase datée :
// - `_MeasurementLine` (`lib/features/station_sheet/view/station_summary_sheet.dart`),
//   qui nomme [hydrometrieSourceName] à côté du débit et de la hauteur, dans
//   le MÊME `Text` que la valeur et sa date (`BR-001`, point 32) ;
// - `_campagneLine` (`lib/features/onde_sheet/view/onde_summary_sheet.dart`),
//   même principe pour [ondeSourceName] et la date de campagne ;
// - `mapSourceName` (`lib/features/map/view/map_empty_states.dart`), qui
//   RÉUTILISE [ondeSourceName] au lieu de recopier la chaîne : un concept,
//   un mot (`glossary.md`).
//
// ⚠️ Ce fichier vit sous `lib/domain/` : aucun `package:flutter`, aucune
// dépendance d'infrastructure (`test/architecture/domain_isolation_test.dart`).

/// Nom affiché de la source hydrométrie Hub'Eau, rendu à côté du débit et de
/// la hauteur sur la fiche station (`BR-001`, point 32).
const String hydrometrieSourceName = "Hub'Eau hydrométrie";

/// Nom affiché de la source écoulement ONDE Hub'Eau — IDENTIQUE à la chaîne
/// que `mapSourceName(MapErrorSource.ecoulement)` rendait déjà avant `W4` :
/// `mapSourceName` la réutilise désormais, il ne la recopie plus.
const String ondeSourceName = "Hub'Eau écoulement ONDE";

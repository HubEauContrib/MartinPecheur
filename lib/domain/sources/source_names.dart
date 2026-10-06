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
// [restrictionsSourceName] et [restrictionsPublicSiteUrl] s'ajoutent en T2
// (M4) : l'écran d'échec des restrictions (`BR-007`, « message par source »)
// nomme la source et pointe vers son site public — les deux doivent rester
// disponibles quand `RestrictionSource` lève, donc vivre ici plutôt que dans
// `lib/data/restrictions/`. Seul endroit hors de ce module et de
// `lib/main.dart` où le nom de la source (casse indifférente) est admis
// (confinement redéfini, `test/data/restrictions/restriction_source_test.dart`).
// Le vocabulaire technique de l'API (hôte d'API, noms de champs…) reste
// interdit ici : `restrictionsPublicSiteUrl` est le site public, pas l'hôte
// d'API.
//
// Les QUATRE noms sont lus par l'écran « D'où vient cette donnée ? »
// (`lib/features/shared/data_sources_view.dart`, T2 `S1`) : ni lui ni les
// autres lecteurs n'en recopient la chaîne.
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

/// Nom affiché de la source des restrictions et zones d'alerte sécheresse
/// (T2, M4). VigiEau est en version 0.1, derrière `RestrictionSource` : ce
/// nom reste disponible quand la source ne répond pas (`SourceInjoignable`,
/// `RequeteRefusee`, `ReponseIllisible`).
const String restrictionsSourceName = 'VigiEau';

/// Adresse du site public de la source des restrictions, à distinguer de
/// l'hôte d'API (celui-ci reste confiné à `lib/data/restrictions/`). Sans
/// `www.` : jamais vérifié autrement que par appel réel
/// (`docs/sources/vigieau.md`).
const String restrictionsPublicSiteUrl = 'https://vigieau.gouv.fr/';

/// Nom affiché du fond de carte, rendu par l'écran « D'où vient cette
/// donnée ? » (T2, `S1`). [ignAttribution] le RÉUTILISE au lieu de le
/// recopier : un concept, un mot (`glossary.md`). Il vit ici, et non dans la
/// tranche carte, parce que `features/shared/` — où vit l'écran des sources —
/// n'importe aucune tranche (`shared-sans-tranche`,
/// `test/architecture/layers_test.dart`).
const String ignSourceName = 'IGN Géoplateforme';

/// Attribution exigée par la Licence Ouverte pour le fond de carte — UNE
/// seule définition, lue par la carte (`ign_attribution_badge.dart`,
/// `map_view.dart`) et par l'écran « D'où vient cette donnée ? »
/// (`lib/features/shared/data_sources_view.dart`) : jamais une chaîne
/// recopiée dans un widget.
const String ignAttribution = '© $ignSourceName — Licence Ouverte';

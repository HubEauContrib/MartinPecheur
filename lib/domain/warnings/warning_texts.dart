// Les textes de TOUS les avertissements du produit (`BR-012`, `BR-013`,
// `BR-014`) vivent ICI, en Dart pur — jamais écrits dans un widget. C'est ce
// qui permet de les balayer (mots bannis, verbes d'instruction) sans monter
// aucun rendu, et c'est le fichier que `test/project/warning_texts_version_test.dart`
// verrouille caractère pour caractère.
//
// ⚠️ Ce fichier vit sous `lib/domain/` : aucun `package:flutter`, aucune
// dépendance d'infrastructure (`test/architecture/domain_isolation_test.dart`).
//
// Cette première tranche (tâche `W2`) ne pose que le texte du modal du
// premier lancement (`UC-006`, emplacement 1 de `04-ui.md § 5`). Les textes
// de `W3` (bandeau, emplacement 2), `W4` (encart daté, emplacement 3) et
// `W5` (encart renforcé, emplacement 4) s'ajoutent ici au fil de ces tâches,
// chacun avec son propre verrou — seul le texte du modal du premier
// lancement est couvert par [warningTextVersion] (arbitrage du
// coordinateur, 2026-09-22).
//
// Provenance de chaque texte, recopié mot pour mot (aucune phrase inventée) :
// - [initialWarningBody] : `docs/use-cases/UC-006-acquitter-l-avertissement-initial.md`,
//   § Flux nominal, étape 2 — seule la première lettre est mise en
//   majuscule pour ouvrir la phrase (le texte source suit un « Le texte
//   énonce : », qui n'est pas lui-même un texte d'écran).
// - [initialWarningCheckboxLabel] : même document, § Flux nominal, étape 4,
//   citation déjà autonome, recopiée sans modification.
// - [initialWarningButtonLabel] : même document, § Flux nominal, étapes 3
//   et 5, et `docs/br/BR-012-l-avertissement-initial-exige-un-acquittement-explicite.md`
//   (« jamais "OK", "Continuer" ni "Fermer" »).
// - [initialWarningTitle] : `docs/04-ui.md`, lignes 164-165, wireframe
//   « Filtres · Avertissement initial » (« Des informations, / pas une
//   autorisation », rejointes sur une seule ligne).
//
// ⚠️ Le lien « Relire le détail des sources » (`04-ui.md § 1`, wireframe) est
// RETIRÉ du modal en T1 (arbitrage du commanditaire, 2026-09-22) : l'écran
// « D'où vient cette donnée ? » portera son propre lien plus tard. Aucune
// constante ne le représente plus ici.

import 'package:martinpecheur/domain/formatting/display_date.dart';

/// Version actuellement en vigueur du texte du modal d'acquittement initial
/// (`UC-006`, `BR-012`). C'est cette chaîne — jamais un booléen — qui est
/// comparée à la version stockée par [WarningsViewModel] : changer le texte
/// du modal sans changer cette version laisse `test/project/warning_texts_version_test.dart`
/// rouge (`UC-006 A3`).
const String warningTextVersion = '2026-09-13.1';

/// Titre du modal bloquant du premier lancement (`04-ui.md`, lignes
/// 164-165, wireframe « Filtres · Avertissement initial »).
const String initialWarningTitle = 'Des informations, pas une autorisation';

/// Corps du modal bloquant du premier lancement (`UC-006 § 2`, emplacement 1
/// de `04-ui.md § 5`).
const String initialWarningBody =
    "Données publiques Hub'Eau, indicatives, partielles, parfois anciennes, "
    'non validées ; elles ne tiennent pas compte des lâchers de barrage ; '
    'elles ne remplacent jamais un arrêté préfectoral, une décision '
    "d'irrigation, ni une évaluation de sécurité avant de se baigner, "
    'naviguer ou traverser.';

/// Libellé de la case à cocher du modal (`UC-006 § 2`, étape 4). Jamais
/// précochée (`BR-012`).
const String initialWarningCheckboxLabel =
    "J'ai lu et compris que ces données ne valent ni autorisation ni "
    'consigne de sécurité.';

/// Libellé du bouton d'acquittement — engage, jamais « OK », « Continuer »
/// ni « Fermer » (`BR-012`, `UC-006 § 2`).
const String initialWarningButtonLabel = "J'ai compris ces limites";

/// Phrase affichée sous le bouton du modal quand l'écriture locale de
/// l'acquittement échoue (`UC-006 A6`, arbitrage du commanditaire du
/// 2026-09-22, point 37). Le blocage reste (`BR-012`) ; cette phrase
/// n'entre PAS dans [warningTextVersion] — ce n'est pas le texte acquitté,
/// elle a son propre verrou (`test/domain/warnings/warning_texts_test.dart`).
const String initialWarningWriteFailedText =
    "Votre choix n'a pas pu être enregistré. Vous pouvez réessayer.";

// ---------------------------------------------------------------------------
// Tâche `W3` — bandeau permanent de la carte (emplacement 2 de
// `04-ui.md § 5`). ⚠️ HORS VERROU DE VERSION : `warningTextVersion` ne
// couvre QUE le texte du modal (arbitrage du coordinateur, 2026-09-22) — ce
// texte-ci est figé par son propre test,
// `test/features/map/view/map_warning_banner_test.dart`.
// ---------------------------------------------------------------------------

/// Texte du bandeau permanent de la carte, recopié du wireframe
/// (`docs/04-ui.md § 1`, l. ~15-16 : « ⚠ Données indicatives. Ni
/// autorisation, ni garantie. »).
const String mapBannerText =
    'Données indicatives. Ni autorisation, ni garantie.';

/// Libellé de l'action du bandeau qui ouvre la feuille de relecture des
/// textes du modal initial (`docs/04-ui.md § 1`, l. 16 : « Ce que ça dit> »).
const String mapExplainActionLabel = 'Ce que ça dit';

/// Libellé du bouton de fermeture de la feuille de relecture — choix du
/// coordinateur, 2026-09-22 : ce n'est pas une fiche, donc pas
/// `'Fermer la fiche'` ; « Fermer » seul n'est interdit que pour le bouton
/// d'acquittement du modal initial (`BR-012`, `initialWarningButtonLabel`),
/// jamais pour une fermeture de lecture seule comme celle-ci.
const String warningReviewCloseLabel = 'Fermer';

// ---------------------------------------------------------------------------
// Tâche `W4` — encart daté de chaque fiche (emplacement 3 de
// `04-ui.md § 5`). ⚠️ HORS VERROU DE VERSION : `warningTextVersion` ne
// couvre QUE le texte du modal (arbitrage du coordinateur, 2026-09-22) — ce
// texte-ci est figé par son propre test,
// `test/features/shared/sheet_warning_card_test.dart`.
//
// Provenance, recopiée mot pour mot (aucune phrase inventée) :
// - version station : `docs/use-cases/UC-003-consulter-une-station-hydrometrique.md`
//   § Flux nominal, étape 1 — « Mesure brute du {date} à {heure}, non
//   validée. La station ne voit pas les lâchers de barrage. »
// - version ONDE : `docs/use-cases/UC-004-consulter-un-point-onde.md`
//   § Flux nominal, étape 1 — « Observation du {date}, lors d'une campagne
//   ponctuelle. Ce n'est pas une mesure de débit, et la situation a pu
//   changer depuis. » Le titre « OBSERVATION VISUELLE PONCTUELLE », plus
//   insistant, vient de `docs/04-ui.md § 1`, wireframe « Fiche point ONDE ».
// ---------------------------------------------------------------------------

/// Les deux fiches qui portent l'encart daté de tête (`04-ui.md § 5`,
/// emplacement 3) : station hydrométrique et point ONDE. La version ONDE
/// est PLUS INSISTANTE (`04-ui.md § 1`) que la version station.
enum SheetWarningKind { station, onde }

/// Le texte de l'encart daté pour [kind], [date] insérée à l'endroit prévu
/// par le texte source. [offsetOf] est le décalage UTC → heure locale,
/// demandé pour [date] (`H1`) — utilisé pour la version station, un
/// INSTANT ; sans effet pour la version ONDE, une DATE CALENDAIRE qui ne se
/// convertit jamais (`T-08`).
String sheetWarningText(
  SheetWarningKind kind,
  DateTime date, {
  UtcOffsetOf offsetOf = systemUtcOffsetOf,
}) => switch (kind) {
  SheetWarningKind.station =>
    'Mesure brute du ${formatLocalDateTime(date, offsetOf: offsetOf)}, non '
        'validée. La station ne voit pas les lâchers de barrage.',
  SheetWarningKind.onde =>
    'OBSERVATION VISUELLE PONCTUELLE\n'
        "Observation du ${formatCalendarDate(date)}, lors d'une campagne "
        "ponctuelle. Ce n'est pas une mesure de débit, et la situation a pu "
        'changer depuis.',
};

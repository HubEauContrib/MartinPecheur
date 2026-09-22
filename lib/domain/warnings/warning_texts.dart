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

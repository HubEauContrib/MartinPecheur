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
// de `W4` (phrase datée propre à chaque fiche) et `W5` (encart renforcé,
// emplacement 4) s'ajoutent ici au fil de ces tâches, chacun avec son
// propre verrou — seul le texte du modal du premier lancement est couvert
// par [warningTextVersion] (arbitrage du coordinateur, 2026-09-22).
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
// Tâches `W3`/`W3b` — bandeau d'avertissement de la carte et menu associé :
// RETIRÉS par l'arbitrage du commanditaire du 2026-09-23 (`W3c`, « trop de
// bandeaux à l'écran »). Le widget du bandeau, sa feuille de relecture et le
// bouton de menu disparaissent avec eux ; les libellés qui n'ont plus de
// lecteur disparaissent aussi. À leur place : un seul contrôle, sur la carte
// ET en tête de chaque fiche — voir la section `W3c` plus bas.
// ---------------------------------------------------------------------------

/// Libellé de fermeture d'une fenêtre ou d'une feuille en LECTURE SEULE —
/// jamais un acquittement (`BR-012` ne s'applique qu'au bouton du modal
/// initial, `initialWarningButtonLabel`). Choix du coordinateur, 2026-09-22.
const String warningReviewCloseLabel = 'Fermer';

// ---------------------------------------------------------------------------
// Tâche `W3c` — arbitrage du commanditaire du 2026-09-23, qui remplace le
// bandeau de carte (`W3`), le menu (`W3b`) et l'encart daté de tête de fiche
// (`W4`, le WIDGET seulement — `sheetWarningText` et [SheetWarningKind]
// restent) par un seul contrôle, `WarningLink`
// (`lib/features/shared/warning_link.dart`) : une icône et ce libellé,
// posé sur la carte ET en tête de chaque fiche, qui ouvre la MÊME fenêtre —
// le texte général du modal initial, complété sous lui par la phrase propre
// à la fiche quand elle a une date. ⚠️ HORS VERROU DE VERSION :
// `warningTextVersion` ne couvre QUE le texte du modal initial. Ce libellé
// est figé par son propre test, `test/features/shared/warning_link_test.dart`.
// ---------------------------------------------------------------------------

/// Libellé du contrôle qui ouvre la fenêtre d'avertissement, sur la carte et
/// en tête de chaque fiche (`W3c`, arbitrage du commanditaire du
/// 2026-09-23).
const String warningLinkLabel = 'Avertissement';

// ---------------------------------------------------------------------------
// Tâche `W4` — phrase datée propre à chaque fiche (emplacement 3 de
// `04-ui.md § 5`). ⚠️ Le WIDGET d'encart qui la rendait en tête de fiche est
// retiré par `W3c` (arbitrage du commanditaire du 2026-09-23) : la phrase se
// lit désormais dans la fenêtre de `WarningLink`
// (`lib/features/shared/warning_link.dart`), sous le texte général. Le TEXTE
// lui-même, [sheetWarningText] et [SheetWarningKind], ne change pas — figé
// par son propre test, `test/domain/warnings/warning_texts_test.dart`. ⚠️
// HORS VERROU DE VERSION : `warningTextVersion` ne couvre QUE le texte du
// modal (arbitrage du coordinateur, 2026-09-22).
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

/// Les deux fiches qui portent la phrase datée propre à la fiche
/// (`04-ui.md § 5`, emplacement 3) : station hydrométrique et point ONDE. La
/// version ONDE est PLUS INSISTANTE (`04-ui.md § 1`) que la version station.
enum SheetWarningKind { station, onde }

/// La phrase datée propre à la fiche pour [kind], [date] insérée à l'endroit
/// prévu par le texte source. [offsetOf] est le décalage UTC → heure locale,
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

// ---------------------------------------------------------------------------
// Tâche `W5` — texte de l'encart renforcé (`BR-013`), emplacement 4 de
// `04-ui.md § 5`. Révision du plan T1 du 2026-09-22 (décision 11) : le
// WIDGET part en T2 avec le premier écran de disponibilité de la ressource
// au sens de `BR-013` — aucun écran de T1 n'en est un. Seul le TEXTE est
// écrit ici, pour être balayé et figé par son test dès maintenant. ⚠️ HORS
// VERROU DE VERSION : `warningTextVersion` ne couvre QUE le texte du modal
// (arbitrage du coordinateur, 2026-09-22) — ce texte-ci est figé par son
// propre test, `test/domain/warnings/warning_texts_test.dart`.
//
// Le nom du service n'apparaît pas ici : `ADR-004` le confine à son module,
// verrouillé par un test.
//
// Provenance, recopiée mot pour mot (aucune phrase inventée) :
// `docs/04-ui.md § 1`, wireframe de l'écran de sécheresse et de
// disponibilité de la ressource, avertissement renforcé (lignes 116-129).
// Les lignes du wireframe sont rejointes à l'endroit où la largeur de la
// boîte ASCII les a coupées, sans ajouter ni retirer un mot ; la ligne
// blanche du wireframe (l. 125) sépare les deux phrases en deux
// paragraphes.
// ---------------------------------------------------------------------------

/// Titre de l'encart renforcé, en capitales comme le wireframe
/// (`docs/04-ui.md § 1`, l. 116-117 : « ⚠ NE FONDEZ AUCUNE DÉCISION SUR /
/// CET ÉCRAN », rejointes sur une seule ligne).
const String reinforcedWarningHeadline =
    'NE FONDEZ AUCUNE DÉCISION SUR CET ÉCRAN';

/// Corps de l'encart renforcé (`docs/04-ui.md § 1`, l. 119-127) : les
/// arrêtés préfectoraux font seuls foi, et les données ne remplacent pas
/// non plus une évaluation de sécurité (`BR-013`).
const String reinforcedWarningBody =
    "Les seules règles qui s'appliquent chez vous sont celles des arrêtés "
    'préfectoraux. Consultez-les avant tout prélèvement, arrosage ou '
    "irrigation : ce que vous lisez ici n'autorise rien et n'interdit "
    'rien.\n\n'
    'Ces données ne remplacent pas non plus une évaluation de sécurité.';

/// Libellé de l'action de l'encart renforcé, vers les arrêtés en vigueur
/// (`docs/04-ui.md § 1`, l. 129 : « [ Consulter les arrêtés en vigueur ] »).
const String reinforcedWarningActionLabel = 'Consulter les arrêtés en vigueur';

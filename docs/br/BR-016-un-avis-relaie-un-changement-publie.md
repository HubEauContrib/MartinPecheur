# BR-016 — Un avis relaie un changement publié ; le silence n'est jamais une absence

- **Statut :** Accepté
- **Date :** 2026-10-17
- **Contexte borné :** Suivi · Avertissement

## Règle

> Sur un lieu suivi, l'application signale par un avis un changement d'un niveau **publié** — la vigilance crues d'un tronçon par Vigicrues, la gravité des zones d'alerte sécheresse par VigiEau — constaté entre deux vérifications faites depuis l'appareil, quand l'application est ouverte. Elle ne calcule aucun niveau : le seuil de crue choisi par l'usager est un niveau publié, comparé à un autre niveau publié. Une vérification impossible est dite par un avis ; elle n'est jamais tue. Tout écran qui montre un avis porte l'avertissement de suivi.

## Justification

La vérification relit depuis l'appareil, sans serveur ni engagement de délai : un avis dépend d'une ouverture de l'application. Un changement survenu puis défait entre deux ouvertures n'est pas vu, et l'avertissement le dit. Comparer deux niveaux publiés n'est pas calculer un niveau : le seuil choisi par l'usager reste un niveau de la nomenclature de la source, jamais un seuil hydrologique (`BR-015`, `BR-003`) ; chaque avis garde une seule échelle (`BR-008`).

## Invariants & cas limites

- Chaque avis porte son échelle (une seule, `BR-008`), le lieu, le niveau publié et le précédent, la date de l'information ou de l'arrêté, la source et la date de réception (`BR-001`).
- La première lecture réussie d'un lieu produit un avis « Suivi commencé » qui dit l'état publié lu.
- Niveau ou gravité non reconnus → avis (`BR-011`).
- Une série d'échecs se compte par lieu et par source, et un seul avis « Vérification impossible » par source et par vérification nomme les lieux dont la série s'ouvre.
- Un stockage illisible est dit, jamais tu.
- Une zone plus citée n'est jamais dite « levée » ; aucun avis ne dit « fin de vigilance » ni « danger écarté ».
- Un changement survenu et défait entre deux vérifications n'est pas vu, et l'avertissement le dit.
- 100 avis gardés au plus.
- Encart non repliable en tête d'« Avis reçus », texte repris sous chaque réglage « Me prévenir », fenêtre « ⚠ Avertissement » de l'écran ; distinct de l'encart de `BR-015` et de celui de `BR-013`.

## Vérifiable par

`test/domain/follow_up/follow_up_rules_test.dart`, `test/domain/follow_up/follow_up_check_test.dart` et l'encart d'« Avis reçus » (tests écrits avec les tâches du plan de T5).

## Liens

- Use cases : `UC-010`
- ADR liés : `ADR-017`
- Voir aussi : `BR-015`, `BR-013`, `BR-008`

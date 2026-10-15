# BR-015 — Relayer la vigilance crues, ne rien prédire

- **Statut :** Accepté
- **Date :** 2026-10-14
- **Contexte borné :** Crues · Avertissement

## Règle

> L'application **relaie** le niveau de vigilance crues publié par Vigicrues pour un tronçon, daté et attribué. Elle ne calcule, ne déduit ni ne prévoit aucun niveau, seuil ou risque de crue, et ne rapproche jamais un débit, une hauteur ou un écoulement d'un risque de crue. Tout écran qui montre le niveau d'un tronçon porte l'avertissement de crue.

## Justification

L'application n'a ni serveur ni engagement de délai : une vigilance relayée peut avoir changé depuis sa date. Une déduction tirée d'un débit mêlerait deux natures que `BR-008` sépare : la vigilance est une publication de l'État, le niveau de débit, une statistique (`ADR-002`).

## Invariants & cas limites

- Un encart d'avertissement figure **en tête de la fiche tronçon, non repliable, avant le niveau**, annoncé en priorité au lecteur d'écran. Son titre est « CE N'EST PAS UN SYSTÈME D'ALERTE » ; son corps : « Cette application reprend la vigilance publiée par Vigicrues, à la date indiquée ; elle ne remplace ni le bulletin de Vigicrues, ni les consignes des autorités et des secours. » (cadrage de T4, § 12.2).
- La fenêtre « ⚠ Avertissement » porte l'avertissement de crue : sur la carte quand la lecture Crues est active, et sur la fiche.
- Aucun texte ne présente l'application comme un système d'alerte ; aucun mot de garantie (`BR-014`).
- Cet encart est distinct de celui de `BR-013`, qui porte sur la ressource et les arrêtés.

## Vérifiable par

Test de contenu des textes de crue (`test/domain/warnings/warning_texts_test.dart`) ; test d'écran de l'encart en tête de fiche, non repliable, région annoncée (`F3`).

## Liens

- Use cases : `UC-009`
- ADR liés : `ADR-016`
- Voir aussi : `BR-013`, `BR-014`, `BR-008`

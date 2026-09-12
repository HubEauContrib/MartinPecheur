# BR-002 — Le débit est affiché en m³/s, la hauteur en mètres

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Hydrometrie

## Règle

> Le débit est affiché en **mètres cubes par seconde**, la hauteur en **mètres**.
> La conversion depuis les unités de l'API se fait dans la couche de mapping.
> **Aucune valeur brute d'API n'atteint la vue.**

## Justification

Hub'Eau ne renvoie **pas** les unités attendues. Documentation officielle, verbatim : *« mm pour les hauteurs d'eau ; l/s pour les débits »*.

Vérifié sur données réelles le 2026-07-30 :

| Station | Champ | Valeur brute | Valeur réelle |
|---|---|---|---|
| `K447001001` (Loire à Blois) | `resultat_obs` | `53000.0` | **53 m³/s** |
| `K447001001` | `resultat_obs_elab` (QmnJ) | `350571.0` | **350,6 m³/s** |

Afficher la valeur brute produirait **une erreur d'un facteur 1000**. Un débit de 53 m³/s annoncé « 53 000 » n'est pas une imprécision : c'est une information fausse, sur laquelle un usager de loisir ou un irrigant peut fonder une décision.

## Invariants & cas limites

- Division par 1000 pour `resultat_obs` (grandeur `Q`) et pour `resultat_obs_elab`.
- Division par 1000 pour la hauteur (grandeur `H`), de mm en m.
- La conversion a lieu **une seule fois**, dans le mapper. Une double conversion est aussi fausse qu'une absence de conversion.
- Le type stocké est explicite : `ValeurM3S`, `ValeurM`. Jamais `Valeur` seul.
- Arrondi d'affichage à une décimale ; la valeur stockée conserve sa précision.
- Valeur nulle : voir `BR-007`, pas de zéro par défaut.

## Vérifiable par

Test unitaire du mapper sur les deux valeurs réelles ci-dessus : `53000.0 → 53.0` et `350571.0 → 350.571`. Test d'architecture interdisant toute référence au type de réponse d'API depuis la couche UI.

## Liens

- Use cases : `UC-003`
- ADR liés : `ADR-001`
- Contrainte d'API : `C-02`, voir [`01-analyse.md § 4`](../01-analyse.md)

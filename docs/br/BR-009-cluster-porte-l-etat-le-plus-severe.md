# BR-009 — Un cluster porte l'état le plus sévère qu'il contient

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Carte

## Règle

> Un cluster de marqueurs affiche **l'état le plus sévère** parmi ceux qu'il regroupe,
> jamais une moyenne, jamais l'état majoritaire.

## Justification

Un cluster regroupant 19 points en écoulement normal et 1 point à sec doit signaler l'assec. Une moyenne le ferait disparaître ; un état majoritaire aussi.

L'assec est précisément l'information que l'usager cherche, et c'est statistiquement la moins fréquente : 4 815 assecs pour 28 142 observations d'écoulement visible depuis le 2026-01-01. Une agrégation par moyenne rendrait le produit aveugle à son propre signal.

## Invariants & cas limites

- Ordre de sévérité par échelle :

| Échelle | Du moins au plus sévère |
|---|---|
| Écoulement | Écoulement → Écoulement faible → Non visible → **À sec** |
| Débit | Habituel → Haut / Bas → Très haut / **Très bas** |
| Sécheresse | Vigilance → Alerte → Alerte renforcée → **Crise** |

- « Non observé » et « Indéterminé » **ne participent pas** au classement de sévérité : un cluster de points non observés affiche « Non observé », mais un seul point observé lui donne son état.
- Le compte affiché sur le cluster est le nombre **total** de points, pas le nombre de points dans l'état le plus sévère.
- Sur l'échelle 2, la sévérité est **bilatérale** : « Très haut » et « Très bas » sont tous deux plus sévères qu'« Habituel ». En cas d'égalité de rang, « Très bas » l'emporte — c'est l'usage principal du produit.
- Le tap sur un cluster zoome ; il n'ouvre pas de fiche.

## Vérifiable par

Test unitaire sur l'agrégateur : un ensemble de 19 `Ecoulement` + 1 `Assec` renvoie `Assec` ; un ensemble de `NonObserve` + 1 `Ecoulement` renvoie `Ecoulement` ; un ensemble contenant `TresHaut` et `TresBas` renvoie `TresBas`.

## Liens

- Use cases : `UC-001`
- ADR liés : `ADR-005`, `ADR-006`
- Écran : [`04-ui.md § 4`](../04-ui.md)
- Voir aussi : `BR-008`

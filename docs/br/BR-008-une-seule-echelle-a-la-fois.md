# BR-008 — Une seule échelle d'état est active à la fois

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Carte

## Règle

> Les trois échelles d'état — **écoulement**, **niveau de débit**, **sévérité sécheresse** —
> ne sont jamais superposées sur un même marqueur ni affichées simultanément sur la carte.
> Une seule est active, choisie par le filtre, et la **légende l'indique en permanence**.

## Justification

Les trois échelles ont des **natures différentes** et ne se comparent pas :

| Échelle | Nature | Ce qu'elle dit |
|---|---|---|
| Écoulement ONDE | **Fait observé** | Ce qu'un agent a vu, un jour donné |
| Niveau de débit | **Statistique** | Comment la valeur se situe face à 30 ans d'historique |
| Sévérité sécheresse | **Décision administrative** | Ce que le préfet a arrêté |

Superposer un fait observé, un calcul et une décision préfectorale sur une même carte, avec une échelle chromatique continue, laisserait croire à un indicateur unique de gravité. C'est précisément la confusion que `ADR-002` cherche à éviter.

C'est aussi ce qui **autorise la réutilisation de teintes** d'une échelle à l'autre : le contexte lève l'ambiguïté, et chaque échelle a sa propre famille de formes (formes pleines · chevrons · badges).

## Invariants & cas limites

- La légende est **toujours visible**, jamais repliée : elle porte le nom de l'échelle active et ses états.
- Le changement d'échelle est explicite, via les chips de filtre. Il n'y a pas d'échelle « automatique » selon le zoom.
- Un marqueur peut exister dans plusieurs échelles (une station hydrométrique dans une zone de restriction) : il n'affiche que l'état de l'échelle active.
- La fiche de détail, elle, présente **toutes** les informations disponibles — la règle porte sur la carte, pas sur le détail.
- En lecture d'écran, l'annonce du marqueur nomme l'échelle : *« écoulement : à sec »*, jamais *« à sec »* seul.

## Vérifiable par

Test d'interface : après sélection d'une échelle, aucun marqueur ne porte de symbole appartenant à une autre famille de formes. Test vérifiant que la légende affichée correspond à l'échelle sélectionnée.

## Liens

- Use cases : `UC-001`
- ADR liés : `ADR-002`, `ADR-006`
- Écran : [`04-ui.md § 2`](../04-ui.md)
- Voir aussi : `BR-009`

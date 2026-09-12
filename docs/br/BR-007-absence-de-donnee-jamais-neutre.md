# BR-007 — L'absence de donnée n'est jamais un état neutre

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Carte · Referentiel

## Règle

> Aucun écran vide, aucun marqueur absent et aucune valeur manquante ne doit suggérer
> une situation normale. Les formulations **« rien à signaler », « tout va bien »,
> « aucun problème détecté »** sont interdites.
> Formulation de repli : **« Aucune donnée disponible ici. »**

## Justification

Une carte sans marqueur se lit spontanément comme « il n'y a pas de problème ici ». C'est l'inverse : cela signifie que **personne ne mesure**.

Les zones non couvertes sont considérables et vérifiées :

| Réalité mesurée | Conséquence |
|---|---|
| 6 454 stations hydrométriques pour l'ensemble du réseau hydrographique français, dont **4 140 en service** | La très grande majorité des cours d'eau n'a aucune station |
| ONDE : 3 548 points, **France hexagonale et Corse uniquement** — département 974 → **0 station** | Aucune couverture outre-mer |
| ONDE ne suit que **certains petits cours d'eau**, sur des points choisis | Un cours d'eau sans point n'est jamais observé |

Un agriculteur qui ne voit aucune alerte sur sa zone doit comprendre qu'il n'y a **pas d'information**, et non qu'il n'y a pas de restriction.

## Invariants & cas limites

- Zone sans station : *« Il n'y a ni station de mesure ni point d'observation dans le secteur affiché. Ce n'est pas un signe que tout va bien : c'est simplement que personne ne mesure ici. »*
- Zone hors couverture ONDE : le message nomme le périmètre réel du réseau.
- Valeur manquante (`resultat_obs` nul) : *« La station n'a pas transmis de valeur pour ce paramètre. »* — jamais `0`, jamais un tiret seul.
- Échec de chargement : message par source. Les autres sources restent affichées. **Jamais d'écran blanc.**
- Niveau de gravité inconnu : *« Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de votre préfecture. »*
- La règle vaut aussi pour les états de chargement : un écran en cours de chargement n'affiche pas d'état par défaut.

## Vérifiable par

Test de contenu : aucune occurrence de « rien à signaler », « tout va bien », « aucun problème » dans les ressources. Test d'instantané sur chaque état vide, vérifiant la présence d'une formulation explicite d'absence.

## Liens

- Use cases : `UC-001`, `UC-002`, `UC-005`
- ADR liés : `ADR-007`
- Voir aussi : `BR-004`, `BR-014`

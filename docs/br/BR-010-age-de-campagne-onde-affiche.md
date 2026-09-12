# BR-010 — L'âge de la campagne ONDE est toujours affiché

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Ecoulement

## Règle

> Tout point ONDE affiche la **date de sa dernière campagne**.
> Au-delà de **60 jours**, l'état est affiché en gris, accompagné de la mention
> « dernière observation le JJ/MM ».

## Justification

ONDE n'est pas une mesure continue : ce sont des **observations visuelles ponctuelles**, lors de campagnes de terrain. Fréquence vérifiée le 2026-07-30 sur le département 41, année 2025 :

```
2025-05-26 · 2025-06-26 · 2025-07-25 · 2025-08-25 · 2025-09-26
```

Soit **une campagne par mois, de mai à septembre**. Répartition nationale 2026 comptée sur 397 campagnes : 104 en mai, 120 en juin, 155 en juillet — contre 3 en janvier, 2 en février, 1 en mars.

**D'octobre à avril, la donnée d'écoulement a couramment plusieurs mois d'âge.** Un point affiché « eau qui coule » en février porte une observation de septembre. Sans son âge, c'est une information trompeuse.

## Invariants & cas limites

- L'âge se calcule sur `date_observation`, pas sur `date_campagne` ni sur la date de publication.
- Le seuil de 60 jours est indépendant de la saison : une campagne complémentaire en mars produit une donnée fraîche, qui doit être traitée comme telle.
- Les campagnes sont de deux types : `usuelle` et `complémentaire` (déclenchée en situation de crise). Les libellés réels sont en **minuscules**, contrairement à la spécification qui annonce `Usuelle` — comparer en minuscules.
- La latence de publication est faible : environ **2 jours** entre observation et disponibilité. Ce n'est pas la latence qui pose problème, c'est l'espacement des campagnes.
- Hors saison, la fiche affiche en complément : *« Campagnes de mai à septembre seulement, environ une par mois. Entre deux campagnes, personne n'observe ce point. »*
- Cette règle est indépendante de `BR-005` : une campagne de 3 semaines est **normale**, pas périmée.

## Vérifiable par

Test unitaire aux bornes : 59 jours → état coloré, 61 jours → état gris avec mention. Test de comparaison de libellé de type de campagne insensible à la casse.

## Liens

- Use cases : `UC-004`
- ADR liés : `ADR-006`
- Contrainte d'API : `C-10`
- Voir aussi : `BR-001`, `BR-005`

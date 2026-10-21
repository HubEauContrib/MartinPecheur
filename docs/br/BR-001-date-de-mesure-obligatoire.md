# BR-001 — Aucune valeur sans sa date de mesure

- **Statut :** Accepté · **amendé le 2026-10-14 (T4, vigilance crues)** · **amendé le 2026-10-17 (T5, suivi)**
- **Date :** 2026-07-30
- **Contexte borné :** Hydrometrie · Ecoulement · Restrictions · Crues

## Règle

> Aucune valeur mesurée ou observée n'est affichée sans sa date, et sa source, visibles
> au même endroit. Une valeur sans date est un **défaut bloquant**, pas un affichage
> dégradé.

## Justification

La fraîcheur du « temps réel » Hub'Eau est **station-dépendante**, et l'écart est considérable. Mesuré le 2026-07-30 à 17:37 UTC :

| Station | Dernière observation | Âge réel |
|---|---|---|
| `V720001002` | 2026-07-30T17:30Z | **7 minutes** |
| `K447001001` | 2026-07-21T11:30Z | **9 jours** |

Les deux sont servies par le même endpoint, avec la même promesse de mise à jour toutes les 5 minutes. Un usager qui lit « 3,2 m³/s » sans date ne peut pas distinguer ces deux situations. Sur une décision de franchissement ou d'irrigation, l'écart est déterminant.

## Invariants & cas limites

- S'applique à **toute** valeur : débit, hauteur, modalité d'écoulement, niveau de gravité.
- S'applique aussi à la donnée servie **depuis le cache** : la date affichée est celle de la **mesure**, jamais celle de la récupération.
- Une observation ONDE porte la **date de campagne**, pas la date de publication.
- Un niveau de gravité VigiEau porte la **date de début de validité de l'arrêté**.
- Valeur nulle : on affiche l'absence et la date de la tentative, pas un blanc.
- Violation : la vue ne doit pas pouvoir se construire. Le type de rendu porte la date comme champ requis, non nullable.
- Vigilance crues : la date de l'information de vigilance (`DtHrInfoVigiCru`) figure sur la légende de la lecture et sur la fiche du tronçon, avec « © VIGICRUES ». Une carte de vigilance sans date lisible n'est pas affichée.
- Avis (T5) : chaque avis porte la date de l'information de vigilance ou la date d'entrée en vigueur de l'arrêté, et sa date de réception.

## Vérifiable par

Test de composant : construire une vue de valeur sans date échoue à la compilation (champ requis) ; test d'instantané sur chaque écran affichant une mesure, vérifiant la présence d'un horodatage.

## Liens

- Use cases : `UC-003`, `UC-004`, `UC-005`, `UC-009`, `UC-010`
- ADR liés : `ADR-001`, `ADR-016`, `ADR-017`
- Contraintes d'API : `C-01`, voir [`01-analyse.md § 5`](../01-analyse.md)
- Voir aussi : `BR-005` (péremption), `BR-006` (statut de qualification)

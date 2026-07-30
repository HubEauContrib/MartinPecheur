# ADR-007 — Écarter la qualité de l'eau de la v1

- **Statut :** Accepté
- **Date :** 2026-07-30

## Contexte

Le cadrage citait la **qualité de l'eau** parmi les quatre axes du produit, via l'API `qualite_eau_potable`, et proposait d'évaluer `qualite_rivieres`, `temperature`, `hydrobio` et `etat_piscicole`.

Vérifications du 2026-07-30 :

| API | Constat mesuré | Problème |
|---|---|---|
| `qualite_eau_potable` v1 | Maille **UDI** (unité de distribution). Dernier prélèvement département 41 : **2026-05-06**, soit ~2,8 mois de latence | Décrit **l'eau du robinet après traitement**, pas la rivière. L'eau distribuée peut venir d'un forage à 30 km, après chloration et filtration. La conformité ARS répond à des seuils de **potabilité**, pas écologiques |
| `qualite_rivieres` v2 | Dernier prélèvement département 41 : **2026-03-05**, publié le 2026-06-14 | ~5 mois de latence sur le prélèvement. Paramètres bruts illisibles : un exemple réel renvoyé est « Température de réception de l'échantillon au laboratoire ». Exige une liste blanche de paramètres et une grille SEQ-Eau |
| `hydrobio` v1 | Prélèvements récents (2026-06-26) | Indices non interprétables sans grille de classes. Exemple réel : « Score de la métrique nombre d'espèces rhéophiles », résultat `5.885454`, unité `X`. Fréquence annuelle |
| `etat_piscicole` v1 | Opération récente (2026-07-24) | 57 205 opérations au total, sur des décennies : quelques passages par station et par décennie. Donnée scientifique ponctuelle |
| `temperature` v1 | 869 stations au référentiel | Réseau largement résiduel. `sort=desc` non fiable ; une date à `2026-11-03` (dans le futur) observée |
| `indicateurs_services` | Chemin réel : `/api/v0/indicateurs_services_publics_eau_assainissement` | Performance des services d'eau (prix du m³, rendement réseau). Hors sujet. API en **v0** |

Le risque décisif porte sur `qualite_eau_potable` : afficher « eau conforme » sur une fiche de cours d'eau serait lu par un usager comme « je peux m'y baigner ». C'est un contresens sur une question de sécurité.

## Décision

**Aucune donnée de qualité de l'eau n'est affichée en v1.**

`temperature` est **conservée en option, priorité basse**, pour le seul persona pêcheur, et uniquement selon le principe « si une station en mesure à proximité ». Jamais comme donnée principale, jamais comme indicateur d'état de la rivière.

Si un module « eau du robinet de ma commune » est ajouté un jour, ce sera un **écran séparé, explicitement nommé**, jamais un onglet de la fiche cours d'eau.

## Conséquences

- ➕ Le risque de contresens sur la baignade est supprimé à la racine.
- ➕ Le produit ne promet que ce qu'il peut tenir : écoulement, débit, restrictions.
- ➖ Un des quatre axes annoncés au cadrage n'est pas livré. À porter explicitement auprès du commanditaire — c'est une réduction de périmètre, pas un oubli.
- ➖ Les usagers de loisir (baignade) n'obtiennent pas de réponse sur la qualité sanitaire. L'app ne doit pas laisser croire qu'elle y répond (`BR-007`).

## Alternatives écartées

- **Afficher `qualite_eau_potable` avec un avertissement** : un avertissement ne corrige pas un contresens structurel. L'usager retient l'indicateur, pas la note de bas de page.
- **Afficher `qualite_rivieres` brute** : latence de plusieurs mois et paramètres illisibles. Incompatible avec « l'état de ma rivière aujourd'hui ».
- **Construire une grille SEQ-Eau** : chantier à part entière, disproportionné pour une v1, et exigeant une expertise hydrobiologique que le projet n'a pas.

## Si la décision est revue

`qualite_rivieres` est le candidat le plus sérieux, à condition de livrer d'abord la liste blanche de `code_parametre` et la grille d'interprétation. C'est un lot autonome : aucune autre partie du produit n'en dépend.

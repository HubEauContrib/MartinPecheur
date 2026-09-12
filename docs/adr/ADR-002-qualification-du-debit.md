# ADR-002 — Ne jamais qualifier un débit de « suffisant »

- **Statut :** Accepté · *tranché par défaut, sans arbitrage du commanditaire*
- **Date :** 2026-07-30

## Contexte

La question fondatrice du produit — « le débit est-il suffisant ? » — suppose un seuil de référence. Recherche exhaustive menée le 2026-07-30 :

| Piste | Résultat vérifié |
|---|---|
| Hub'Eau hydrométrie v2 | 4 ressources au total. **Aucun seuil, percentile, DOE ni DCR** |
| HydroPortail | Calcule module, QMNA5, VCN3 — **aucune API REST** (`/api-docs`, `/rest/hydro/stations` → 404) |
| SANDRE | `referentiels/v1/zar.json` → 404 |
| VigiEau | Niveau de gravité **administratif** par zone, jamais le débit-seuil, sans lien à une station |

Les DOE et DCR sont fixés dans les SDAGE et arrêtés-cadres préfectoraux, **publiés en PDF non structuré**.

Trois options étaient ouvertes : (a) comparaison à l'historique de la station, (b) source externe de seuils réglementaires, (c) affichage brut contextualisé.

## Décision

**Le produit ne répond jamais à « le débit est-il suffisant ? ».** Il répond à deux questions distinctes, qu'il ne mélange jamais :

| Question | Réponse | Nature | Source |
|---|---|---|---|
| Ce débit est-il **inhabituel pour la saison** ? | Percentile face au même jour calendaire sur 30 ans | **Statistique** | `obs_elab/QmnJ` |
| Qu'est-ce qui est **interdit chez moi** ? | Niveau de gravité, usages restreints, PDF de l'arrêté | **Réglementaire** | VigiEau |

L'option (b) est écartée **par absence de source**, pas par choix. L'option (a) est retenue sous la forme de l'ADR-003. L'option (c) constitue le socle et le repli quand l'historique est insuffisant.

**Les mots « suffisant », « insuffisant », « normal », « bon », « sûr » sont bannis de l'interface** pour qualifier un débit. Formulation imposée : *« Bas — plus faible que d'habitude à cette période de l'année. »*

## Conséquences

- ➕ Aucun seuil inventé.
- ➕ La frontière entre le statistique et le réglementaire est explicite pour l'usager.
- ➕ La responsabilité juridique reste chez l'autorité qui la détient.
- ➖ Le produit ne répond pas à la question que l'usager se pose spontanément. Inconfort assumé : y répondre exigerait d'inventer un seuil.

**Limites à porter dans l'interface** — un percentile n'est pas un seuil réglementaire ; l'historique inclut des décennies déjà influencées par les prélèvements et les ouvrages ; le changement climatique déplace la référence, donc **un débit « habituel » peut être écologiquement dégradé**. Détail en [`02-specifications.md § 1.4`](../02-specifications.md).

## Alternatives écartées

- **Source externe de seuils réglementaires** : écartée **par absence de source**, pas par choix. Vérifié sur Hub'Eau, HydroPortail et SANDRE.
- **Affichage brut seul, sans aucun contexte** : honnête mais laisse l'usager sans repère. Conservé comme socle et comme repli quand l'historique est insuffisant.

## Si la décision est revue

Le repli est l'option (c) seule : débit brut, date, statut, courbe avec minimum et maximum historiques, aucune catégorisation. Suppression de l'échelle 2 de la carte et de l'asset de l'ADR-003. Aucune autre partie du produit n'est touchée.

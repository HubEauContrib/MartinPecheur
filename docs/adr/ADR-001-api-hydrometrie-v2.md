# ADR-001 — Cibler l'API hydrométrie v2

- **Statut :** Accepté
- **Date :** 2026-07-30

## Contexte

Le cadrage initial désignait `https://hubeau.eaufrance.fr/api/v1/hydrometrie/api-docs` comme source du débit.

Vérification par appel HTTP réel le 2026-07-30 :

| URL | Réponse |
|---|---|
| `/api/v1/hydrometrie/api-docs` | **HTTP 403 Forbidden** (deux tentatives, deux clients) |
| `/api/v2/hydrometrie/api-docs` | **HTTP 200**, Swagger 2.0, `info.version = 2.0.1` |

L'historique de la page officielle indique : v2 le 15/10/2024, **arrêt de la version 1 le 05/05/2025**.

Il n'existe pas de version unique Hub'Eau : `ecoulement`, `qualite_eau_potable`, `temperature`, `hydrobio`, `etat_piscicole` sont en v1 ; `qualite_rivieres` en v2 ; les indicateurs de services en v0.

## Décision

Toute consommation de l'hydrométrie cible **`/api/v2/hydrometrie`**. La version est portée par la configuration de chaque client HTTP nommé, jamais codée en dur dans un appel.

## Conséquences

- ➕ La source ciblée est celle qui existe ; l'application n'est pas morte au premier lancement.
- ➖ Aucune : la v1 n'est plus une option.

**Vigilances induites**, issues de la lecture du Swagger v2 :

| Point | Effet |
|---|---|
| Débit en **l/s**, hauteur en **mm** | Diviser par 1000 dans le mapper (BR-01) |
| `observations_tr` limité à **1 mois glissant** | L'historique passe par `obs_elab` |
| `obs_elab` **sans paramètre `sort`** | Toujours passer `date_debut_obs_elab` (BR-04) |
| Codes site vs station | N'interroger que des codes station (BR-05) |
| **HTTP 206** en succès partiel | Normaliser 200 et 206 (BR-06) |
| `code_methode_obs = 8` absent de la doc mais présent en production | Branche par défaut obligatoire (BR-12) |

## Si la décision est revue

Sans objet. Elle constate un fait, elle n'arbitre rien.

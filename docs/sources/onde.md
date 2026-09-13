# Source — Écoulement ONDE

Base URL : `https://hubeau.eaufrance.fr/api/v1/ecoulement` · `api_version` **1.2.0** (relevée
le 2026-09-13) · aucune authentification · Licence Ouverte Etalab. Rôle : observations
visuelles de terrain. Décision liée : `ADR-006` — quatre catégories d'affichage.

⚠️ **Ce n'est pas une mesure, c'est un regard** : des agents se déplacent quelques fois par
an, de mai à septembre. Entre deux campagnes, personne ne regarde — `BR-010` impose
d'afficher l'âge de la campagne pour cette raison.

## Endpoints

| Endpoint | Pagination | Fixture |
|---|---|---|
| `/observations` | `page` + `size` | `observations_departement_41_2026-09-13.json` |
| `/campagnes` | — | 🔄 à capturer avec l'écran d'écoulement (T1) |

## Faits constatés le 2026-09-13

Appel `/observations?code_departement=41&size=300` → HTTP **206**, `count` **2 821**.

- `code_ecoulement` est une chaîne : `"1a"` **116**, `"1f"` **95**, `"2"` **24**, `"3"` **65**
  — un parsing en entier échoue sur `"1a"` (`C-10`).
- `"1"` et `"4"` sont absents de cet échantillon (constatés le 2026-08-01 sur huit
  départements, non revérifiés aujourd'hui) → acceptés sans être exigés (`BR-011`).
- Libellés relevés dans la fixture : `"1a"` « Ecoulement visible acceptable », `"1f"`
  « Ecoulement visible faible », `"2"` « Ecoulement non visible », `"3"` « Assec ».
- Le code de station fait **huit caractères** (exemple réel : `"K4520001"`) : ce n'est pas un
  code de station hydrométrique — les deux référentiels sont distincts, `StationCode` ne
  s'applique pas ici.
- Les coordonnées sont fournies deux fois : `latitude`/`longitude` à plat **et** un objet
  `geometry` GeoJSON, concordants sur l'échantillon.
- `"date_observation":"2026-08-25"` — une date sans heure.

⚠️ **Le libellé `"Assec"` de l'API n'est pas ce qu'on affiche** : `glossary.md` proscrit le
mot, l'écran dit **« À sec »** ; le libellé officiel reste conservé pour la traçabilité.

## Non vérifié

- `code_ecoulement` à `null` : aucune occurrence dans cet échantillon (0 sur 2 821, vérifié
  par `grep` le 2026-09-13) ; un relevé antérieur (2026-08-01) en donnait 30 sur 7 000 — plus
  fréquent que le code `"4"`, à revérifier si le cas se reproduit.
- La casse des libellés de campagne (`"usuelle"` en minuscules, `C-10`) — constatée le
  2026-07-30, non revérifiée aujourd'hui.
- L'absence de station en DOM (`974` → 0 station) — non revérifiée.
- `/campagnes` : aucun appel en T0.

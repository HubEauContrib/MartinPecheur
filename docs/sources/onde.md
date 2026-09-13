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
| `/observations` | `page` + `size` | `observations_departement_41_2026-09-13.json`, `observations_bbox_loire_2026-09-13.json`, `observations_station_K4520001_2026-09-13.json` |
| `/campagnes` | `page` + `size` | `campagnes_departement_41_2026-09-13.json` |

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

### Campagnes et emprise géographique — capturés le 2026-09-13

- `T-01` `/v1/ecoulement/observations` accepte `bbox` (`bbox=1.0,47.3,1.8,47.8` → 206, count
  1 448 le matin du 2026-09-13). La carte n'a pas besoin de passer par le département.
- `T-02` le même endpoint accepte `sort=desc` et `fields` : 206 sans erreur.
- `T-03` il accepte `date_observation_min` — `2026-07-15` sur la même emprise → count 30
  contre 1 448. Fixture : `observations_bbox_loire_2026-09-13.json`.
- `T-04` `?code_station=K4520001&sort=desc` → 206, count 96, trois dernières campagnes
  2026-08-25 code "3", 2026-07-24 code "3", 2026-06-26 code "2". Le code à 8 caractères est
  la clé de l'historique d'un point. Fixture : `observations_station_K4520001_2026-09-13.json`.
- `T-05` `/v1/ecoulement/campagnes?code_departement=41` → 206, count 96, api_version 1.2.0,
  champs : `code_campagne`, `date_campagne`, `nombre_modalite_ecoulement`,
  `code_type_campagne`, `libelle_type_campagne`, `code_reseau`, `code_departement`. Fixture :
  `campagnes_departement_41_2026-09-13.json`.
- `T-06` `libelle_type_campagne` en minuscules (`"usuelle"`, `"complémentaire"`) — `C-10`
  reproduit, comparaison en minuscules.
- `T-08` `date_observation` est une date sans heure (`"2026-08-25"`) : `BR-010` se calcule en
  jours.
- `T-09` une observation ONDE porte les coordonnées deux fois — `latitude`/`longitude` à plat
  et `geometry` GeoJSON — plus `code_cours_eau`, `libelle_cours_eau` (minuscules, accentué),
  `code_departement`, `code_commune`.

⚠️ `T-07` **`code_campagne` change de type selon l'endpoint** : entier dans `/campagnes`
(`109905`), chaîne dans `/observations` (`"109905"`) — un modèle qui le type `int` casse sur
l'un des deux.

## Non vérifié

- `code_ecoulement` à `null` : aucune occurrence dans cet échantillon (0 sur 2 821, vérifié
  par `grep` le 2026-09-13) ; un relevé antérieur (2026-08-01) en donnait 30 sur 7 000 — plus
  fréquent que le code `"4"`, à revérifier si le cas se reproduit. Sur l'emprise bbox filtrée
  par `date_observation_min` (`Q-05`), 0 occurrence sur 30 — `Inconnu(null)` reste un cas
  synthétique en test, jamais rencontré dans une fixture.
- L'absence de station en DOM (`974` → 0 station) — non revérifiée.

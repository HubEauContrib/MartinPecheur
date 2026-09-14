# Statuts HTTP des captures

Les fixtures de `test/fixtures/` ne stockent que le corps de la réponse ; le statut HTTP
de la capture d'origine n'était conservé nulle part. Ce fichier répare ça pour l'avenir
(ce tableau à mettre à jour à chaque nouvelle fixture) et consigne, pour les captures déjà
faites, un statut **rejoué aujourd'hui** — ce n'est pas le statut d'origine, on ne réécrit
pas l'histoire.

| Fixture | URL | Statut à la capture | Statut constaté aujourd'hui (2026-09-13) |
|---|---|---|---|
| `hubeau/observations_tr_K447001001_Q_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr?code_entite=K447001001&grandeur_hydro=Q&size=2` | rapporté par l'opérateur, non conservé | `206` |
| `hubeau/observations_tr_K447001001_H_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr?code_entite=K447001001&grandeur_hydro=H&size=1` | rapporté par l'opérateur, non conservé | `206` |
| `hubeau/observations_tr_site_K4470010_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr?code_entite=K4470010&grandeur_hydro=Q&size=2` | rapporté par l'opérateur, non conservé | `206` |
| `hubeau/obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/obs_elab?code_entite=K447001001&grandeur_hydro_elab=QmnJ&date_debut_obs_elab=2026-08-01&size=3` | rapporté par l'opérateur, non conservé | `206` |
| `hubeau/obs_elab_K447001001_sans_date_debut_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/obs_elab?code_entite=K447001001&grandeur_hydro_elab=QmnJ&size=2` | rapporté par l'opérateur, non conservé | `206` |
| `hubeau/obs_elab_K447001001_depuis_2026-09-01_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/obs_elab?code_entite=K447001001&grandeur_hydro_elab=QmnJ&date_debut_obs_elab=2026-09-01&size=2` | `200` (capturé le 2026-09-13 avec `curl -w`, conservé cette fois) | `200` |
| `hubeau/referentiel_stations_K447001001_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v2/hydrometrie/referentiel/stations?code_station=K447001001&page=1&size=1` | rapporté par l'opérateur, non conservé | `200` |
| `onde/observations_departement_41_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?code_departement=41&size=300` | rapporté par l'opérateur, non conservé | `206` |
| `onde/campagnes_departement_41_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/campagnes?code_departement=41&size=20` | `206` (capturé le 2026-09-13 avec `curl -w`, conservé cette fois), `time_total` 0,52 s, `count` 96 | `206` |
| `onde/observations_bbox_loire_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?bbox=1.0,47.3,1.8,47.8&date_observation_min=2026-07-15&size=30&sort=desc` | `200` (capturé le 2026-09-13 avec `curl -w`, conservé cette fois), `time_total` 0,23 s, `count` 30 | `200` |
| `onde/observations_station_K4520001_2026-09-13.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?code_station=K4520001&sort=desc&size=10` | `206` (capturé le 2026-09-13 avec `curl -w`, conservé cette fois), `time_total` 0,20 s, `count` 96 | `206` |
| `onde/observations_station_A721_3011_espace_2026-09-14.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?code_station=A721%203011&sort=desc&fields=…&size=3` | `206` (capturé le **2026-09-14**), `count` **40** | non rejoué |
| `onde/observations_station_A7213011_sans_espace_2026-09-14.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?code_station=A7213011&sort=desc&fields=…&size=3` | `206` (capturé le **2026-09-14**), `count` **63** | non rejoué |
| `onde/observations_station_P9130001_code_ecoulement_null_2026-09-14.json` | `https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?code_station=P9130001&sort=desc&fields=…&size=3` | `206` (capturé le **2026-09-14**), `count` **126** | non rejoué |
| `referentiel/stations_extrait_2026-09-13.json` | — | non applicable — copie déclarée de `assets/referentiel/stations.json`, pas un appel HTTP | non applicable |

Les trois captures du **2026-09-14** portent leur statut d'origine et n'ont pas été rejouées :
la colonne de droite ne réécrit pas une vérification qui n'a pas eu lieu. Leur `fields` est la
liste des dix champs de `lib/data/http/onde_uris.dart`, abrégée ici en `…` et lisible verbatim
dans le champ `first` de chaque fixture. Ce qu'elles prouvent : `T-14`, `docs/sources/onde.md`.

Les URL ci-dessus omettent `cursor=` (vide au premier appel, reconstituée depuis le champ
`first` de chaque fixture) ; elles reproduisent sinon exactement les paramètres de la
capture d'origine.

`206` est un succès au même titre que `200` (`C-06`, `01-analyse.md`, vérifié le
2026-07-30) : les deux statuts constatés aujourd'hui sur ce tableau le confirment à nouveau.

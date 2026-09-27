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

## VigiEau — capturées le 2026-09-27 (cadrage T2, `VG-01` à `VG-11`)

Toutes UTC. Base `https://api.vigieau.beta.gouv.fr/api` sauf le Swagger (racine, voir `VG-01`).
Détail et interprétation : `docs/sources/vigieau.md`.

| Fixture | URL | Heure UTC | Statut | Ce qu'elle prouve |
|---|---|---|---|---|
| `vigieau/swagger_2026-09-27.json` | `https://api.vigieau.beta.gouv.fr/swagger-json` (racine, pas `/api/swagger-json` → 404) | 11:23:56 | `200` | `VG-01` : `version: "0.1"` toujours, forme des DTO (`ZoneDto`, `UsageDto`, `DepartementDto`, `ArreteDto`) |
| `vigieau/departements_2026-09-27.json` | `/departements` | 11:24:29 | `200` | `VG-04` : nomenclature `niveauGravite` complète observée (`vigilance`, `alerte`, `alerte_renforcee`, `crise`) sur 101 départements ; en-têtes `X-RateLimit-*` |
| `vigieau/zones_ain_bourg-en-bresse_sans_profil_2026-09-27.json` | `/zones?lat=46.2&lon=5.226` | 11:25:24 | `200` | `VG-02`, `VG-11` : 3 zones au même point (`SOU`, `SUP`, `AEP`), sans `profil` toutes les `usages` sont rendus (45/27/19) |
| `vigieau/zones_ain_bourg-en-bresse_profil_particulier_2026-09-27.json` | `/zones?lat=46.2&lon=5.226&profil=particulier` | 11:25:25 | `200` | `VG-05` : filtrage serveur des `usages` par profil (30/22/16, contre 45/27/19 sans profil) |
| `vigieau/zones_ain_bourg-en-bresse_profil_exploitation_2026-09-27.json` | `/zones?lat=46.2&lon=5.226&profil=exploitation` | 11:25:25 | `200` | `VG-05` : filtrage par profil (26/20/12) |
| `vigieau/zones_ain_bourg-en-bresse_profil_collectivite_accentue_2026-09-27.json` | `/zones?lat=46.2&lon=5.226&profil=collectivit%C3%A9` | 11:25:27 | `200` | `VG-05` : la valeur d'énumération du Swagger (`collectivité`, accentuée) rend **zéro usage** sur les trois zones — écart avec la doc |
| `vigieau/zones_ain_bourg-en-bresse_profil_collectivite_sans_accent_2026-09-27.json` | `/zones?lat=46.2&lon=5.226&profil=collectivite` | 11:26:26 | `200` | `VG-05` : la valeur **sans accent** rend 35/22/16 usages, cohérent avec le compte de `concerneCollectivite=true` de la réponse sans profil — c'est la valeur qui fonctionne réellement |
| `vigieau/zones_ain_bourg-en-bresse_profil_entreprise_2026-09-27.json` | `/zones?lat=46.2&lon=5.226&profil=entreprise` | 11:25:25 | `200` | `VG-05` : filtrage par profil (36/23/17) |
| `vigieau/zones_guyane_aucune_zone_2026-09-27.json` | `/zones?lat=4.9&lon=-52.3` | 11:26:03 | `200` | `VG-03` : aucune zone → `200` avec `[]`, jamais `404` |
| `vigieau/zones_atlantique_hors_france_2026-09-27.json` | `/zones?lat=45.0&lon=-30.0` | 11:26:04 | `200` | `VG-03` : point en mer, hors France → `200` avec `[]` |
| `vigieau/zones_coordonnees_invalides_400_2026-09-27.json` | `/zones?lat=999&lon=999` | 11:26:05 | `400` | `VG-10` : coordonnées hors plage → `400`, message explicite (`lon must be a longitude string or number`, `lat must be a latitude string or number`) |
| `vigieau/zones_corse_ajaccio_2026-09-27.json` | `/zones?lat=41.9192&lon=8.7386` | 11:26:06 | `200` | `VG-11` : Corse, 3 zones (`SUP`/`AEP`/`SOU`) au niveau `alerte` |
| `vigieau/zones_paris_vigilance_2026-09-27.json` | `/zones?lat=48.8566&lon=2.3522` | 11:26:07 | `200` | `VG-04` : niveau `vigilance` constaté en réponse réelle (Paris, 3 zones) |
| `vigieau/zones_ariege_foix_crise_2026-09-27.json` | `/zones?lat=42.9648&lon=1.6052` | 11:26:31 | `200` | `VG-04` : niveau `crise` constaté en réponse réelle (Ariège, 2 zones `AEP`/`SUP`) ; `VG-08` : `dateDebutValidite`/`dateFinValidite` ISO 8601 UTC |
| `vigieau/zones_commune_45210_409_2026-09-27.json` | `/zones?commune=45210` | 11:26:32 | `409` | `C-14` reconfirmé aujourd'hui : `"La commune comporte plusieurs zones d'alerte de même type."` |
| `vigieau/arretes_restrictions_departement_03_2026-09-27.json` | `/arretes_restrictions?departement=03` | 11:27:07 | `200` | Reconfirme le `[]` du 2026-07-30 — sémantique du paramètre toujours **non élucidée** |

Une requête supplémentaire, non gardée en fixture (corps d'erreur non informatif pour une future
implémentation) : `GET` sur le PDF de l'arrêté d'Ariège (`curl -I`, 11:26:51 UTC) →
`200`, `Content-Type: application/pdf`, `Content-Length: 7 240 160` — `VG-07`.
`/api/zones/v2` et `/api/zones_v2`-style essais et `/api/arretes_restrictions` sans paramètre
n'ont pas été conservés en fixture (hors du besoin de T2, § 5 du cadrage limite `VG-12`/`VG-13`).

Politesse respectée : 21 appels HTTP au total pour cette capture (dont le `HEAD` du PDF), espacés
d'au moins une seconde, aucun balayage.

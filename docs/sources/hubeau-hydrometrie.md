# Source — Hydrométrie Hub'Eau

Base URL : `https://hubeau.eaufrance.fr/api/v2/hydrometrie` · `api_version` **2.0.1**
(relevée le 2026-09-13, présente dans chaque réponse) · aucune authentification ·
Licence Ouverte Etalab, **citation de l'auteur obligatoire** ; version de la licence non
précisée aux CGU consultées : *non vérifié*. Rôle : débit, hauteur, historique journalier,
référentiel des stations. Décision liée : `ADR-001` — cibler exclusivement la v2, la v1 est
arrêtée depuis le 05/05/2025 (`403` constaté lors du cadrage, `C-01` ; non revérifié
aujourd'hui).

## Endpoints

| Endpoint | Pagination | Fixture |
|---|---|---|
| `/observations_tr` | curseur | `observations_tr_K447001001_Q_2026-09-13.json` |
| `/obs_elab` (`grandeur_hydro_elab=QmnJ`) | curseur | `obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json` |
| `/referentiel/stations` | `page` + `size` | `referentiel_stations_K447001001_2026-09-13.json` |

## Faits constatés le 2026-09-13

- Le débit arrive en litres/seconde (`47800.0` = 47,8 m³/s) → division par mille dans le
  mapper, une seule fois (`BR-002`).
- La hauteur arrive en millimètres et peut être négative (`-1232.0` = −1,232 m) → aucun
  contrôle de signe dans le mapper.
- `206` est un succès : `size=2` → `206` ; `date_debut_obs_elab=2026-09-01` (aucune donnée)
  → `count=0` et `200` → `isSuccess` accepte les deux codes (`C-06`).
- Un code **site** renvoie tout en double : `code_entite=K4470010` → `count` **412**, dont
  une ligne à `code_station: null` ; le code **station** `K447001001` seul → `count` **206**
  → `StationCode` refuse les huit caractères d'un code site (`C-05`). Écart avec un relevé
  antérieur qui annonçait 430/216 : cette fixture-ci fait foi.
- `obs_elab` ignore `sort` : sans `date_debut_obs_elab`, première ligne `1900-01-01`,
  `resultat_obs_elab` `155000.0`, `count` `44733` → `date_debut_obs_elab` est un paramètre
  **requis** du constructeur d'URI, jamais optionnel (`C-04`).
- Latence de `obs_elab` : `date_debut_obs_elab=2026-09-01` → `count` `0`, `200` ; `2026-08-01`
  → `count` `26`, statut « Donnée pré-validée » → l'historique du mois courant n'existe pas
  encore côté API.
- Le champ de qualification change de nom selon l'endpoint : `observations_tr` expose
  `libelle_qualification_obs`, `obs_elab` expose `libelle_qualification` → deux mappers,
  jamais un nom réutilisé de mémoire.
- Le référentiel nomme les coordonnées et le département différemment des observations :
  `latitude_station`/`longitude_station` contre `latitude`/`longitude`.
- La dernière observation temps réel de `K447001001` date du `2026-08-27T08:00:00Z`, soit
  **dix-sept jours** avant cette capture → `BR-005` s'applique dès une station de référence,
  pas seulement à un cas limite.

## Contraintes subies

Renvoi au tableau `C-xx` de `01-analyse.md § 4` : `C-01`, `C-02`, `C-03`, `C-04`, `C-05`,
`C-06`, `C-07`, `C-08`, `C-09`, `C-12`, `C-15`, `C-17`.

## Référentiel figé

`assets/referentiel/stations.json` — **6 604 249 octets** (`ls -l`, 2026-09-13), `"count":
4150`, `api_version` `2.0.1`, obtenu avec `en_service=1&format=geojson&page=1&size=10000`
(constaté dans l'en-tête du fichier). Versionné dans l'app parce que la carte ne peut pas
attendre 6,6 Mo au premier lancement et qu'aucun filtre géographique n'existe sur cet
endpoint (`C-09`). ⚠️ Le GeoJSON ordonne `[longitude, latitude]` — les inverser ne lève
aucune erreur.

## Non vérifié

- Le quota réel : `curl -sI` sur `/observations_tr` le 2026-09-13 ne renvoie aucun en-tête
  `X-RateLimit-*` ; les CGU ne chiffrent rien (`C-12`) — throttle client à l'aveugle.
- Le comportement sous charge concurrente.
- La stabilité du curseur de pagination entre deux appels espacés dans le temps.

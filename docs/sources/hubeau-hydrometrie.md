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
| `/observations_tr` (`grandeur_hydro=Q`) | curseur | `observations_tr_K447001001_Q_2026-09-13.json` |
| `/observations_tr` (`grandeur_hydro=H`) | curseur | `observations_tr_K447001001_H_2026-09-13.json` |
| `/observations_tr` (code **site**, `C-05`) | curseur | `observations_tr_site_K4470010_2026-09-13.json` |
| `/obs_elab` (`grandeur_hydro_elab=QmnJ`, avec `date_debut_obs_elab`) | curseur | `obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json`, `obs_elab_K447001001_depuis_2026-09-01_2026-09-13.json` |
| `/obs_elab` (sans `date_debut_obs_elab`, `C-04`) | curseur | `obs_elab_K447001001_sans_date_debut_2026-09-13.json` |
| `/referentiel/stations` | `page` + `size` | `referentiel_stations_K447001001_2026-09-13.json` |
| `/referentiel/stations` (extrait GeoJSON, `[lon, lat]`) | — copie déclarée, pas un appel | `test/fixtures/referentiel/stations_extrait_2026-09-13.json` |

Statuts HTTP constatés à la capture de chacune (quand ils l'ont été) et rejoués aujourd'hui :
`test/fixtures/CAPTURES.md`.

## Comportement du client

`HubEauClient.getJson` (`lib/data/http/hub_eau_client.dart`) rejoue sur 429 et 5xx en
espaçant les tentatives via `delayForAttempt` (`lib/data/http/retry.dart`, C-12), et accepte
206 comme un succès au même titre que 200 (C-06). Un 4xx hors 429 échoue immédiatement, sans
attente : ce n'est pas une panne transitoire.

```mermaid
sequenceDiagram
    participant Écran as Écran / handler
    participant Client as HubEauClient
    participant Retry as retry.dart
    participant API as Hub'Eau v2

    Écran->>Client: getJson(uri)
    Client->>API: GET (tentative 0)
    API-->>Client: 503
    Client->>Retry: delayForAttempt(0)
    Retry-->>Client: délai à gigue
    Client->>API: GET (tentative 1)
    API-->>Client: 206 + corps
    Client-->>Écran: corps décodé

    Écran->>Client: getJson(uri)
    Client->>API: GET (tentative 0)
    API-->>Client: 400
    Client-->>Écran: HubEauFailure (échec immédiat, aucune attente)
```

## Faits constatés le 2026-09-13

- Le débit arrive en litres/seconde (`47800.0` = 47,8 m³/s) → division par mille dans le
  mapper, une seule fois (`BR-002`). Fixture : `observations_tr_K447001001_Q_2026-09-13.json`.
- La hauteur arrive en millimètres et peut être négative (`-1232.0` = −1,232 m) → aucun
  contrôle de signe dans le mapper. Fixture : `observations_tr_K447001001_H_2026-09-13.json`.
- `206` est un succès au même titre que `200` (`C-06`, `01-analyse.md`, vérifié le
  2026-07-30) : `size=2` sur `observations_tr` renvoie `206`, `size=2` avec
  `date_debut_obs_elab=2026-09-01` (aucune donnée) renvoie `200` avec `count=0` → les deux
  codes traversent `isSuccess`. Statuts HTTP de chaque capture, y compris ceux rejoués
  aujourd'hui : `test/fixtures/CAPTURES.md`.
- Un code **site** renvoie tout en double : `code_entite=K4470010` → `count` **412**, dont
  une ligne à `code_station: null` ; le code **station** `K447001001` seul → `count` **206**
  → `StationCode` refuse les huit caractères d'un code site (`C-05`). Fixture (code site) :
  `observations_tr_site_K4470010_2026-09-13.json`. Écart avec un relevé antérieur qui
  annonçait 430/216 : cette fixture-ci fait foi.
- `obs_elab` ignore `sort` : sans `date_debut_obs_elab`, première ligne `1900-01-01`,
  `resultat_obs_elab` `155000.0`, `count` `44733` → `date_debut_obs_elab` est un paramètre
  **requis** du constructeur d'URI, jamais optionnel (`C-04`). Fixture :
  `obs_elab_K447001001_sans_date_debut_2026-09-13.json`.
- Latence de `obs_elab` : `date_debut_obs_elab=2026-09-01` → `count` `0`, `200` (fixture
  `obs_elab_K447001001_depuis_2026-09-01_2026-09-13.json`) ; `2026-08-01` → `count` `26`,
  statut « Donnée pré-validée » (fixture
  `obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json`) → l'historique du mois courant
  n'existe pas encore côté API.
- Le champ de qualification change de nom selon l'endpoint : `observations_tr` expose
  `libelle_qualification_obs`, `obs_elab` expose `libelle_qualification` → deux mappers,
  jamais un nom réutilisé de mémoire.
- Le référentiel nomme les coordonnées et le département différemment des observations :
  `latitude_station`/`longitude_station` contre `latitude`/`longitude`. Fixture :
  `referentiel_stations_K447001001_2026-09-13.json`.
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
endpoint (`C-09`, `01-analyse.md` : **6 454 lignes** sans le filtre `en_service` — l'écart
avec les **4 150** de l'asset versionné, filtré, ci-dessus). ⚠️ Le GeoJSON ordonne
`[longitude, latitude]` — les inverser ne lève aucune erreur ; petit extrait déclaré de ce
fichier : `test/fixtures/referentiel/stations_extrait_2026-09-13.json`.

## Non vérifié

- Le quota réel : `curl -sI` sur `/observations_tr` le 2026-09-13 ne renvoie aucun en-tête
  `X-RateLimit-*` ; les CGU ne chiffrent rien (`C-12`) — throttle client à l'aveugle.
- Le comportement sous charge concurrente.
- La stabilité du curseur de pagination entre deux appels espacés dans le temps.

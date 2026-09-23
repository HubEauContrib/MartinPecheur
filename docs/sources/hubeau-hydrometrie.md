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
attente : ce n'est pas une panne transitoire. Un corps qui prétend être un succès mais ne se
décode pas en JSON (206 tronqué en cours de transfert, par exemple) est rejoué au même titre
qu'une panne réseau. Le corps est toujours décodé en UTF-8 explicite
(`utf8.decode(response.bodyBytes)`), jamais via `response.body` qui retombe sur latin1 sans
en-tête `Content-Type`. Une panne TLS (`HandshakeException`/`TlsException`) traverse
`IOClient` sans être enveloppée en `ClientException` et est rejouée comme une panne réseau ;
un client déjà fermé (`ClientException` « already closed ») ne l'est pas. Les tentatives
épuisées (`maxAttempts`, 4 par défaut) lèvent `HubEauFailure`.

```mermaid
sequenceDiagram
    participant Écran as Écran / handler
    participant Client as HubEauClient
    participant Retry as retry.dart
    participant API as Hub'Eau v2
    Note over Écran,API: Panne transitoire (503) puis succès (206)
    Écran->>Client: getJson(uri)
    Client->>API: GET (tentative 0)
    API-->>Client: 503
    Client->>Retry: delayForAttempt(0)
    Retry-->>Client: délai à gigue
    Client->>API: GET (tentative 1)
    API-->>Client: 206 + corps
    Client-->>Écran: corps décodé
    Note over Écran,API: Statut non rejouable — échec immédiat, sans attente
    Écran->>Client: getJson(uri)
    Client->>API: GET (tentative 0)
    API-->>Client: 400
    Client-->>Écran: HubEauFailure
    Note over Écran,API: Corps illisible malgré un succès — rejouable aussi
    Écran->>Client: getJson(uri)
    Client->>API: GET (tentative 0)
    API-->>Client: 206, corps tronqué
    Client->>Retry: delayForAttempt(0)
    Retry-->>Client: délai à gigue
    Client->>API: GET (tentative 1)
    API-->>Client: 200 + corps
    Client-->>Écran: corps décodé
    Note over Écran,API: Épuisement des tentatives (maxAttempts=4)
    Écran->>Client: getJson(uri)
    loop 4 tentatives, 503 constant
        Client->>API: GET
        API-->>Client: 503
    end
    Client-->>Écran: HubEauFailure (4 appels, 3 attentes)
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

Fait constaté le 2026-09-13, en lisant l'asset (`parseStations`,
`test/data/referentiel/stations_asset_test.dart`) : sur les **4 150** points, **4 113**
entités `Station` complètes, **37** écartées de `stations` pour `code_departement` absent ou
mal formé — des stations transfrontalières (le Rhin en Allemagne/Suisse, la Meuse et la
Semois/l'Escaut en Belgique) plus deux stations corses (`Y880000101`, `Y971000201`). Ce n'est
pas un bug de l'analyse : le référentiel Hub'Eau porte ces stations sans département français.
Les 37 restent dans `points` — la carte les affiche — mais sont écartées de `stations` plutôt
que de recevoir un département inventé (`BR-007`).

## Panne constatée le 2026-09-13

`T-10` `/v2/hydrometrie/observations_tr` est indisponible.

- **Le matin du 2026-09-13** : **503 sur 19 tentatives** réparties sur ~25 min, plus **un
  502 après 67 s** et **un timeout sans réponse** — ces deux derniers pèsent sur la
  politique de retry (`D5`) au même titre que les 503.
- **L'après-midi, SEPT appels, tous 500**, corps identique à chaque fois :
  `{"code":"Internal server error","message":"","field_errors":null}`, en trois lots :
  - **13:34:49 UTC** : `Q-01` (codes multiples, `size=4`), `Q-02` (`bbox`, `size=3`), `Q-03`
    (`fields`, `size=1`) ;
  - **13:35:03 UTC** : forme garantie
    (`…observations_tr?code_entite=K447001001&grandeur_hydro=Q&size=2`), puis `Q-01` rejouée ;
  - **13:35:26 UTC** : forme garantie (`…&size=1`), puis `Q-02` rejouée.

Au même moment (13:35:03 UTC), `/v2/hydrometrie/referentiel/stations?code_station=K447001001&size=1`
répondait normalement (`count` 1, `api_version` 2.0.1) : c'est l'endpoint d'observations qui
est en panne, pas l'API entière.

## Constaté le 2026-09-18

`T-15` reprise de `Q-01` à `Q-04` (`T-10`) : l'endpoint répond de nouveau. Tous les appels
ci-dessous sont datés en UTC, `api_version` **2.0.1** à chaque réponse.

- **Forme garantie**, seule station :
  `https://hubeau.eaufrance.fr/api/v2/hydrometrie/observations_tr?code_entite=K447001001&grandeur_hydro=Q&size=1`
  → **206**, **09:00:35 UTC**, `count` **128**. Champs présents dans `data[0]` :
  `code_site`, `code_station`, `grandeur_hydro`, `date_debut_serie`, `date_fin_serie`,
  `code_systeme_alti_serie`, `date_obs`, `resultat_obs`, `code_methode_obs`,
  `libelle_methode_obs`, `code_qualification_obs`, `libelle_qualification_obs`, `longitude`,
  `latitude`, `code_statut`, `libelle_statut`, `code_continuite`, `libelle_continuite`.

- **`Q-01` codes multiples** — le code documenté `K4620020` n'est pas une station valide :
  interrogé seul (`…observations_tr?code_entite=K4620020&grandeur_hydro=Q&size=4`, **09:01:04
  UTC**) → **200**, `count` **0**, `data` vide. Combiné à `K447001001`
  (`…code_entite=K447001001,K4620020&grandeur_hydro=Q&size=4`, **09:00:48 UTC**) → **206**,
  `count` **128** (identique à la station seule), les 4 lignes renvoyées sont toutes
  `K447001001`, triées par `date_obs` décroissant.
  Essai refait avec **deux vrais codes station à 10 caractères** — `K447001001` (Blois) et
  `K479301001` (station proche, `assets/referentiel/stations.json`, ~5 km) :
  `…observations_tr?code_entite=K447001001,K479301001&grandeur_hydro=Q&size=4` → **206**,
  **09:01:14 UTC**, `count` **8761**. Les 4 lignes sont **toutes** `K479301001` (dernière
  observation **2026-09-18T08:45:00Z**, `code_methode_obs` **8** « Calculée », non documenté
  — cf. `docs/01-analyse.md`) ; **aucune** ligne `K447001001` (dernière observation connue
  **2026-08-27T08:00:00Z**, dix-sept jours plus tôt). Rejoué avec `size=20`
  (**09:01:31 UTC**) : les **20** lignes restent toutes `K479301001` —
  `K447001001` n'apparaît à aucun moment. **Constat : le tri est global sur le pool combiné
  des codes demandés, par `date_obs` décroissant, sans garantie d'au moins une mesure par
  station.** Une station moins fraîche que les autres codes du lot peut n'apparaître dans
  aucune page tant que `size` ne couvre pas tout son retard.

- **`Q-02` par emprise (`bbox`)** :
  `…observations_tr?bbox=1.0,47.3,1.8,47.8&grandeur_hydro=Q&size=3` → **206**, **09:01:41
  UTC**, `count` **119726**. Rejoué avec `size=20` (**09:01:52 UTC**) : seulement **2** codes
  station distincts non nuls (`K479301001`, `K480001002`) sur les 20 lignes, plus **10**
  lignes à `code_station: null` (même `code_site`, mêmes `date_obs`/`resultat_obs` qu'une
  ligne station — motif de doublon déjà observé pour un code site, `C-05`, mais ici produit
  par le filtre `bbox` sans qu'aucun code site n'ait été demandé explicitement). Même
  constat que `Q-01` : tri global par `date_obs` décroissant sur toutes les stations de
  l'emprise, pas de garantie d'une mesure par station.
  Paramètre `sort` : **accepté**. `…&size=3&sort=desc` (**09:02:03 UTC**, **206**) donne le
  même ordre que sans `sort` (le plus récent d'abord, `2026-09-18T08:45:00Z`) ;
  `…&size=3&sort=asc` (**09:02:03 UTC** dans le même lot, **206**) inverse l'ordre — plus
  ancien d'abord dans le pool retourné (`2026-08-19T09:05:00Z` en tête). `sort=desc` est donc
  le comportement par défaut de l'endpoint.

- **`Q-03` `fields` + `size=1`** :
  sans `fields` (`…code_entite=K447001001&grandeur_hydro=Q&size=1`, **09:02:18 UTC**) → **206**,
  `size_download` **901** octets. Avec `fields=code_station,date_obs,resultat_obs` : premier
  essai (**09:02:18–09:04:21 UTC**, dans le même lot) → **503** HTML (« Service Unavailable »,
  page Apache générique, différente du corps JSON `{"code":"Internal server error"...}` de la
  panne du 13), après plus de 2 min sans réponse — rejoué immédiatement
  (**09:04:34 UTC**) → **206**, `size_download` **558** octets, `data[0]` réduit exactement
  aux trois champs demandés : `{"code_station":"K447001001","date_obs":"2026-08-27T08:00:00Z","resultat_obs":47800.0}`.
  `fields` fonctionne bien quand l'endpoint répond, mais un 503 isolé est survenu au milieu
  d'un lot par ailleurs sain — panne courte, pas rejouée sur plusieurs tentatives.

- **`Q-04` latence** — 10 appels sur la forme garantie, espacés de 3 s, **09:04:43 →
  09:05:33 UTC**, `curl -s -o /dev/null -w '%{http_code} %{time_total}'` : tous **206**.
  Valeurs brutes de `time_total` (s), dans l'ordre : `1.264`, `0.230`, `0.546`, `0.250`,
  `1.388`, `1.607`, `3.681`, `3.257`, `2.143`, `4.069`. Triées : `0.230`, `0.250`, `0.546`,
  `1.264`, `1.388`, `1.607`, `2.143`, `3.257`, `3.681`, `4.069` → **min 0,230 s**,
  **max 4,069 s**, **médiane 1,498 s** (moyenne des 5ᵉ et 6ᵉ valeurs). Échantillon de dix
  appels sur une fenêtre de 50 s un seul jour : ne pas figer un seuil de préchargement dessus
  sans remesure.

- **En-têtes** — `curl -sI` sur la forme garantie, **09:05:44 UTC** → **206 Partial
  Content**. Présents : `Date`, `Vary`, `Content-Type`, `Link` (pagination `first`/`prev`/
  `next`), `Content-Security-Policy`, `Strict-Transport-Security`, `Referrer-Policy`,
  `Permissions-Policy`, `Access-Control-Allow-Origin: *`, `Connection: close`,
  `Transfer-Encoding: chunked`. **Aucun** en-tête `X-RateLimit-*` ni en-tête de cache
  (`Cache-Control`, `ETag`, `Expires` absents) — confirme `C-15`, throttle client à l'aveugle.

Réponses brutes (petites) archivées hors dépôt :
`q01_original.json`, `q01_k4620020_seul.json`, `q01_deux_stations.json`,
`q01_deux_stations_size20.json`, `q02_bbox_size3.json`, `q02_bbox_size20.json`,
`q02_bbox_sort_desc.json`, `q02_bbox_sort_asc.json`, `q03_sans_fields.json`,
`q03_avec_fields.json`, `q04_latence.txt`, `entetes.txt` — dossier scratchpad de la session,
pas dans le dépôt.

## Non vérifié

- Le comportement sous charge concurrente.
- La stabilité du curseur de pagination entre deux appels espacés dans le temps.
- Le doublon `code_station: null` sous `bbox` (vu le 2026-09-18 sur 10 lignes/20) : sa
  fréquence et sa cause exacte ne sont pas creusées au-delà du constat ci-dessus.
- `Q-01` à `Q-03` : mesurés une seule fois chacun, le 2026-09-18, sur un jeu de codes/emprise
  particulier — pas de campagne répétée à des heures différentes.

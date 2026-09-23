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
| `/observations` | `page` + `size` | `observations_departement_41_2026-09-13.json`, `observations_bbox_loire_2026-09-13.json`, `observations_station_K4520001_2026-09-13.json`, `observations_station_A721_3011_espace_2026-09-14.json`, `observations_station_A7213011_sans_espace_2026-09-14.json`, `observations_station_P9130001_code_ecoulement_null_2026-09-14.json` |
| `/campagnes` | `page` + `size` (constaté via le champ `next` de la fixture : `page=2&size=20`) | `campagnes_departement_41_2026-09-13.json` |

## Faits constatés le 2026-09-13

Appel `/observations?code_departement=41&size=300` → HTTP **206**, `count` **2 821**.

- `code_ecoulement` est une chaîne : `"1a"` **116**, `"1f"` **95**, `"2"` **24**, `"3"` **65**
  — un parsing en entier échoue sur `"1a"` (`C-10`).
- `"1"` et `"4"` sont absents de cet échantillon (constatés le 2026-08-01 sur huit
  départements, non revérifiés aujourd'hui) → acceptés sans être exigés (`BR-011`).
- Libellés relevés dans la fixture : `"1a"` « Ecoulement visible acceptable », `"1f"`
  « Ecoulement visible faible », `"2"` « Ecoulement non visible », `"3"` « Assec ».
- ⚠️ ~~Le code de station fait **huit caractères**~~ — **invalidé le 2026-09-14, voir `T-14`**.
  Huit caractères est vrai de cet échantillon (`"K4520001"`) et **faux à l'échelle
  nationale** : 147 codes distincts y sortent de `^[A-Z0-9]{8}$`. Le code de station ONDE est
  une **chaîne libre**. Ce qui reste vrai : ce n'est pas un code de station hydrométrique —
  les deux référentiels sont distincts, `StationCode` ne s'applique pas ici, et c'est
  désormais le **type** qui le garantit, plus la forme.
- Coordonnées et date d'observation : constatés sur les fixtures bbox et station, voir
  `T-08` et `T-09` ci-dessous.

⚠️ **Le libellé `"Assec"` de l'API n'est pas ce qu'on affiche** : `glossary.md` proscrit le
mot, l'écran dit **« À sec »** ; le libellé officiel reste conservé pour la traçabilité.

### Campagnes et emprise géographique — capturées le 2026-09-13

- `T-01` `/v1/ecoulement/observations` accepte `bbox`
  (`…/v1/ecoulement/observations?bbox=1.0,47.3,1.8,47.8&size=3` → 206, count 1 448 le matin
  du 2026-09-13). La carte n'a pas besoin de passer par le département.
- `T-02` le même endpoint accepte `sort=desc` et `fields`
  (`https://hubeau.eaufrance.fr/api/v1/ecoulement/observations?bbox=1.0,47.3,1.8,47.8&sort=desc&fields=code_station,date_observation,code_ecoulement,libelle_ecoulement,latitude,longitude&size=3`
  → 206 sans erreur).
- `T-03` il accepte `date_observation_min` — `2026-07-15` sur la même emprise → count 30
  contre 1 448. Fixture : `observations_bbox_loire_2026-09-13.json`.
- `T-04` `?code_station=K4520001&sort=desc` → 206, count 96, trois dernières campagnes
  2026-08-25 code "3", 2026-07-24 code "3", 2026-06-26 code "2". Le code de station est la clé
  de l'historique d'un point. Fixture : `observations_station_K4520001_2026-09-13.json`.
  ⚠️ **Amendé le 2026-09-14** : la partie « le code fait **8 caractères** » est **fausse en
  général** — vraie de la Loire, fausse à l'échelle nationale, où 147 codes distincts portent
  un espace ou une autre longueur (`T-14`). Le reste du fait tient : `?code_station=` rend
  bien l'historique complet d'un point.
- `T-05` `/v1/ecoulement/campagnes?code_departement=41` → 206, count 96, api_version 1.2.0,
  **10 champs** : `code_campagne`, `date_campagne`, `nombre_modalite_ecoulement`,
  `code_type_campagne`, `libelle_type_campagne`, `code_reseau`, `libelle_reseau`,
  `uri_reseau`, `code_departement`, `libelle_departement`. Fixture :
  `campagnes_departement_41_2026-09-13.json`.
- `T-06` `libelle_type_campagne` en minuscules (`"usuelle"`, `"complémentaire"`) — `C-10`
  reproduit, comparaison en minuscules.
- `T-08` `date_observation` est une date sans heure (`"2026-08-25"`) : `BR-010` se calcule en
  jours.
- `T-09` une observation ONDE porte les coordonnées deux fois — `latitude`/`longitude` à plat
  et `geometry` GeoJSON, **concordantes sur l'échantillon** (vérifié le 2026-09-13 sur la
  fixture bbox : première ligne `latitude` 47.444182169 / `longitude` 1.78116675 contre
  `geometry.coordinates` `[1.7811667496231998, 47.44418216904609]`, ordre
  `[longitude, latitude]`) — plus `code_cours_eau`, `libelle_cours_eau`, `code_departement`,
  `code_commune`. **La casse de `libelle_cours_eau` n'obéit à aucune règle** : les 15
  libellés distincts de la fixture bbox portent chacun une majuscule, souvent sur l'article
  (`"La Masse"`, `"La Rennes"`), parfois sur le nom propre seul (`"la Bonne Heure"`,
  accentué : `"le Vézenne"`) — mais la fixture station donne `"ruisseau la rivière aux
  loches"`, **entièrement en minuscules**. Jamais de comparaison ni d'affichage normalisé sur
  ce champ.
- `Q-05` `code_ecoulement` à `null` : **répondu** — zéro occurrence sur les deux nouvelles
  fixtures (0 sur 30 en bbox, 0 sur 10 en station). `Inconnu(null)` reste un cas synthétique
  en test, jamais rencontré dans une fixture capturée aujourd'hui.
  ⚠️ **Amendé le 2026-09-14** : cette conclusion ne valait que de l'emprise Loire. À l'échelle
  nationale, `code_ecoulement` est `null` sur **700 lignes sur 10 234** — voir `T-14 e`.
- `T-12` **la forme filaire à virgules encodées (`%2C`) est acceptée**, constaté le 2026-09-13
  15:47 UTC :
  `…/v1/ecoulement/observations?bbox=1.0%2C47.3%2C1.8%2C47.8&date_observation_min=2026-07-15&size=2&sort=desc&fields=code_station%2Cdate_observation%2Ccode_ecoulement`
  → HTTP **206**, `count` **30** (identique à la forme à virgules nues au même instant), et
  `fields` **honoré** : les lignes de `data` ne portent que `code_station`,
  `date_observation`, `code_ecoulement` (première ligne :
  `{"code_station":"K4640001","date_observation":"2026-08-25","code_ecoulement":"3"}`).
  L'API réécrit les virgules nues dans `first`/`next`. Enjeu : `Uri(queryParameters:)` de Dart
  encode toujours la virgule en `%2C` — c'est la forme filaire réellement émise par l'app, et
  elle est acceptée.
- `T-13` **la forme filaire exacte émise par l'app est acceptée**, précision flottante complète
  comprise, constaté le 2026-09-13 15:56:45 UTC :
  `…/v1/ecoulement/observations?bbox=1.000000000000001%2C47.300000000000004%2C1.7811667496231998%2C47.799999999999997&date_observation_min=2026-07-15&sort=desc&fields=code_station%2Clibelle_station%2Ccode_departement%2Clibelle_cours_eau%2Ccode_campagne%2Cdate_observation%2Ccode_ecoulement%2Clibelle_ecoulement%2Clatitude%2Clongitude&size=2`
  → HTTP **206**, `count` **30**, chaque ligne de `data` porte **exactement les dix clés
  demandées** (première ligne :
  `{"code_station":"K4640001","libelle_station":"LA BONNEURE A MILLANCAY","code_departement":"41","libelle_cours_eau":"la Bonne Heure","code_campagne":"109905","date_observation":"2026-08-25","code_ecoulement":"3","libelle_ecoulement":"Assec","longitude":1.78116675,"latitude":47.444182169}`).
  Bbox à quinze décimales, du même ordre que ce qu'émet la carte : dix champs, virgules en
  `%2C` (`47.799999999999997` n'est pas nécessairement ce que `double.toString()` produirait
  pour cette valeur précise — l'appel vérifie que l'API accepte cet ordre de précision, pas
  une capture verbatim de l'app). Complément : `bbox=3e-7%2C47.3%2C1.8%2C47.8&size=1` (notation
  exponentielle, celle que `double.toString()` produit sous `1e-6`) → **206**, `count` **5057**
  — l'API la parse aussi.

### Codes de station hors forme — constaté le 2026-09-14

> ⚠️ **Numérotation** : le commanditaire a demandé ce fait sous le numéro `T-11`. `T-11` est
> **déjà pris** par le relevé `shared_preferences` du plan T1
> (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`, l. 56, 757 et 771).
> Un numéro ne se réutilise pas : ce fait est donc `T-14`, premier libre.

- `T-14` 🚨 **Le code de station ONDE est une chaîne libre, pas un code à huit caractères.**
  L'appel
  `…/v1/ecoulement/observations?bbox=-5.5,41,10,51.5&date_observation_min=2026-07-15&size=20000&sort=desc&fields=…` — appel du 2026-09-13 à 23:45 UTC (2026-09-14 01:45 heure de Paris), HTTP 200, 7,5 s
  (France entière) → HTTP **200**, `count` **10 234**, `api_version` `1.2.0`, **3 302 codes de
  station distincts**. Sur ces 10 234 lignes, **507** portent un code qui **ne satisfait pas**
  `^[A-Z0-9]{8}$`, soit **147 codes distincts** :

  | Forme | Codes distincts | Lignes | Exemples |
  |---|---|---|---|
  | `X999 9999` — espace intérieur, 9 caractères | 129 | 453 | `A721 3011`, `S131 5011`, `D015 8503` |
  | espace(s) de bord | 10 | 35 | `" O968 5312 "`, `"L053 0001 "`, `"O073 0001 "` |
  | autres | 8 | 19 | `X123 472` … `X123 478` (espace, 8 caractères), `S224` (4 caractères) |

  **Aucune minuscule** dans l'échantillon. Comptes recalculés le 2026-09-14 sur la page
  conservée hors dépôt (3,1 Mo, non versionnée : trop grosse).

- `T-14 a` **L'espace est significatif pour l'API** — cinq appels réels du 2026-09-13 (23:45-23:50 UTC) :

  | Requête | HTTP | `count` | `libelle_station` |
  |---|---|---|---|
  | `?code_station=A721%203011` | 206 | **40** | « Le Trey à Vilcey-sur-Trey » |
  | `?code_station=A7213011` | 206 | **63** | « Le Trey à Vilcey sur Trey » |
  | `?code_station=X123%20472` | 206 | 14 | — |
  | `?code_station=X123472` | 206 | **0** | — |
  | `?code_station=S224` | 206 | 43 | — |

  **Deux codes distincts pour ce qui ressemble à la même station** — constat brut, aucune
  interprétation : rien ne dit ici s'il s'agit d'un doublon de référentiel, d'un changement de
  code, ou de deux points réellement différents. Le produit ne fusionne donc rien : il
  conserve le code **verbatim** (ni `trim`, ni suppression d'espace, ni normalisation de
  casse), car transformer le code change la station interrogée. Fixtures :
  `observations_station_A721_3011_espace_2026-09-14.json` (count 40) et
  `observations_station_A7213011_sans_espace_2026-09-14.json` (count 63).

- `T-14 b` **Les codes à espaces de bord ne sont retrouvables sous aucune forme** :
  `?code_station=%20O968%205312%20` → `count` **0**, et `?code_station=O968%205312` → `count`
  **0** — alors que le code apparaît bien, tel quel, dans la réponse par emprise. **Non
  élucidé**, consigné en « Non vérifié » ci-dessous.

- `T-14 c` **Forme filaire émise par l'app** : `Uri(queryParameters:)` de Dart encode l'espace
  en **`+`**, pas en `%20`. Vérifié le 2026-09-13 à 23:54 UTC (2026-09-14 01:54 heure de Paris ; les fixtures portent la date locale) :
  `?code_station=A721+3011&sort=desc&size=1` → HTTP **206**, `count` **40** — la même réponse
  que `%20`, et l'API réécrit de toute façon le séparateur en `%20` dans son champ `first`
  (comme elle réécrit les virgules nues, `T-12`). Les deux formes sont donc acceptées.
  ⚠️ Un **503 transitoire** est survenu sur deux de ces appels, rejoué en 206 à la tentative
  suivante (23:56 UTC) : `C-15` / `T-10`, pas un refus de la forme.

- `T-14 d` **Conséquence produit** (bug vu à l'écran le 2026-09-14) : la validation
  `^[A-Z0-9]{8}$` d'alors levait sur ces 507 lignes, l'exception remontait jusqu'à
  `MapViewModel`, et la carte affichait un bandeau rouge avec **zéro station** — 10 233 lignes
  lisibles perdues pour 507 illisibles. Corrigé le même jour : code verbatim, et **ligne
  illisible ignorée et comptée** au dépôt (`BR-007` — l'absence s'explique par le compte).

- `T-14 e` **`code_ecoulement` à `null` est courant à l'échelle nationale** : **700 lignes sur
  10 234** (6,8 %), `libelle_ecoulement` `null` sur les mêmes 700. Elles ne sont **pas**
  concentrées sur une campagne : **29 codes de campagne**, **20 dates d'observation** du
  2026-07-17 au 2026-09-11, **17 départements** (les plus fournis : `64` → 128, `46` → 79,
  `47` → 61, `09` → 55). Aucune interprétation ici — « campagne en cours, saisie pas encore
  faite » reste une **hypothèse non vérifiée**. Fixture d'une station concernée :
  `observations_station_P9130001_code_ecoulement_null_2026-09-14.json` (count 126 ; deux
  lignes à `code_ecoulement` null, campagnes `110352` du 2026-09-11 et `110351` du 2026-09-10, puis une ligne à `"3"`).
  ⚠️ Ce fait **amende `Q-05`** ci-dessus, qui concluait « zéro occurrence » sur deux fixtures
  locales de 30 et 10 lignes : `Inconnu(null)` **n'est plus un cas synthétique**, c'est un cas
  réel et fréquent hors de la Loire.

⚠️ `T-07` **`code_campagne` change de type selon l'endpoint** : entier dans `/campagnes`
(`109905`), chaîne dans `/observations` (`"109905"`) — un modèle qui le type `int` casse sur
l'un des deux.

## Non vérifié

- **Pourquoi les codes à espaces de bord ne se retrouvent pas** (`T-14 b`) : `" O968 5312 "`
  apparaît dans la réponse par emprise, mais ni `%20O968%205312%20` ni `O968%205312` ne
  rendent quoi que ce soit en recherche par `code_station`. Aucune hypothèse retenue.
- **Ce que sont `A721 3011` et `A7213011`** (`T-14 a`) : deux codes, deux historiques, deux
  libellés proches. Doublon de référentiel ? Recodage ? Deux points distincts ? **Inconnu** —
  aucune fusion, aucune déduplication tant que ce n'est pas établi.
- **Pourquoi 700 lignes n'ont pas de `code_ecoulement`** (`T-14 e`) : 29 campagnes, 17
  départements, sur deux mois. « Campagne en cours » n'est qu'une hypothèse.
- La récurrence de `code_ecoulement` à `null` sur d'autres emprises est désormais connue à l'échelle nationale (`T-14 e` : 700 lignes sur 10 234, 29 campagnes, 17 départements) ; sur la Loire : 0
  occurrence dans l'échantillon départemental (0 sur 2 821, vérifié par `grep` le
  2026-09-13) et dans les deux fixtures de `Q-05` ci-dessus, mais un relevé antérieur
  (2026-08-01) en donnait 30 sur 7 000 — plus fréquent que le code `"4"` — à revérifier si le
  cas se reproduit sur une autre emprise ou un autre département.
- L'absence de station en DOM (`974` → 0 station) — non revérifiée.

# Source — Vigicrues (vigilance crues)

Adresse retenue `https://www.vigicrues.gouv.fr/services/InfoVigiCru.geojson` (l'adresse publiée
`…/services/1/InfoVigiCru.geojson` y redirige, `VC-01`) · aucune authentification · licence :
**Licence Ouverte (Etalab)**, attribution « © VIGICRUES » et date de dernière mise à jour
(`VC-09`) · éditeur : Service central d'hydrométéorologie et d'appui à la prévision des
inondations (SCHAPI), réseau Vigicrues. Rôle : niveau de vigilance crues publié par tronçon de
cours d'eau, pour la quatrième lecture de la carte (T4). Décision liée : ADR à écrire au cadrage
détaillé de T4 (source derrière une interface, sur le modèle d'[`ADR-004`](../adr/ADR-004-integration-vigieau.md)).

⚠️ **Lot 0 de T4, appels réels du 2026-10-14 entre 14:30 et 14:37 UTC**, depuis un seul poste,
par `curl`. Un jour de **vigilance verte nationale** : seul le niveau `1` est publié ce jour-là,
les niveaux `2` à `4` ne sont connus que par leur nomenclature (`VC-04`). Aucune panne réelle
n'a été observée (`VC-10`).

🚦 **Arbitrage du commanditaire, 2026-10-14** (question fermée, après correction d'un fait,
voir « Arbitrages ») : **un appel national au GeoJSON, mis en cache**, par exception motivée à
`NFR-07` (« aucun appel national en bloc », [`nfr.md`](../nfr.md)) — l'amendement de `NFR-07`
se fait au cadrage détaillé de T4.

## Adresses vérifiées le 2026-10-14

| Adresse | Rôle | Statut | Fixture |
|---|---|---|---|
| `GET /services/1/InfoVigiCru.geojson` | adresse publiée (documentation `v1.1`, jeu data.gouv) | `302` → `/services/InfoVigiCru.geojson` | — (en-têtes seulement, `CAPTURES.md`) |
| `GET /services/InfoVigiCru.geojson` | tronçons, tracés, niveau, date de l'information | `200` | `vigicrues/infovigicru_extrait_territoire_8_2026-10-14.geojson` (**extrait**, `VC-03`) |
| `GET /services/TerEntVigiCru.json` | référentiel des territoires (codes, noms) | `200` | `vigicrues/territoires_2026-10-14.json` |
| `GET /services/TronEntVigiCru.json?CdEntVigiCru=AP1&TypEntVigiCru=8` | détail d'un tronçon, ses stations | `200` | `vigicrues/troncon_AP1_stations_2026-10-14.json` |
| `GET https://api.sandre.eaufrance.fr/referentiels/v1/nsa/837.json` | nomenclature Sandre 837, niveaux de vigilance | `200` | `vigicrues/sandre_nomenclature_837_2026-10-14.json` |
| `GET /` (page d'accueil) | légende publiée des quatre niveaux | `200` | `vigicrues/accueil_legende_2026-10-14.html` |
| `GET /territoire/rss?CdEntVigiCru=…` | flux RSS par tronçon — **écarté** (`VC-12`) | `200` | `vigicrues/rss_national_aucune_vigilance_2026-10-14.xml`, `rss_troncon_BT5_2026-10-14.xml`, `rss_troncons_BT5_AP1_2026-10-14.xml`, `rss_territoire_8_quinze_troncons_2026-10-14.xml`, `rss_code_inconnu_repli_national_2026-10-14.xml`, `rss_parametre_invalide_200_2026-10-14.html` |
| `GET /bulletin_local/8`, `/bulletin_local/29`, `/bulletin_national` | bulletins, pages HTML | `200` | — (texte relevé, `VC-05`, `VC-08`) |

Chemins relatifs à `https://www.vigicrues.gouv.fr` sauf mention. Les chemins `/services/v1.1/…`
de la documentation redirigent tous (`302`) vers le même chemin sans version.

## Faits constatés le 2026-10-14

### `VC-01` — adresse, redirection, en-têtes

`/services/1/InfoVigiCru.geojson` répond `302`, `Location: /services/InfoVigiCru.geojson`. Celle-ci
répond `200`, `Content-Type: application/json; charset=utf-8`, **2 245 691 octets**,
`Cache-Control: max-age=120`, en 0,35 s environ depuis ce poste. **Aucune compression** : avec
`Accept-Encoding: gzip`, la réponse revient sans `Content-Encoding`, à la même taille. Chaque
réponse porte un en-tête `Link` vers `http://www.vigicrues.gouv.fr/api/docs.jsonld`, qui redirige
(`301`) vers `https://…/api/docs.jsonld`, lequel répond `500`, `text/html` (rejoué à 14:55:40 UTC,
`VC-10`). Le jeu data.gouv « Tronçons de cours d'eau Vigicrues, simplifiés avec niveau de
vigilance crues » (SCHAPI, licence `fr-lo`, dernière modification 2022-10-17) pointe sur
`…/services/1/InfoVigiCru.geojson/` : aucune autre source structurée de la vigilance n'y est
publiée parmi les jeux lus (recherche `vigicrues` sur l'API data.gouv à 14:34:31 UTC : 12 jeux au
total, les 10 premiers lus).

### `VC-02` — portée : un appel national, sans filtre

**Le GeoJSON ne se filtre pas.** Cinq jeux de paramètres essayés à 14:31:19 UTC — territoire
(`CdEntVigiCru=8&TypEntVigiCru=5`), tronçon (`CdEntVigiCru=AP1&TypEntVigiCru=8`), `CdEntCru=AP1`,
`bbox=-2,47,-1,48`, `NivInfViCr=2` — rendent tous `200` et **2 245 691 octets**, la collection
entière. La documentation `v1.1` (`/services/v1.1`) ne lui connaît que la forme « pas de
paramètres ». **Contredit `NFR-07`** (« aucun appel national en bloc ») : arrêt et question au
commanditaire, réponse le jour même (voir « Arbitrages »).

### `VC-03` — forme du document

`FeatureCollection`, `name` « template-vigicrues-v1.1-WGS84.geojson », clés de premier niveau
`type`, `name`, `bbox`, `features`, `RefInfoVigiCru`, `DtHrInfoVigiCru` ; **pas de membre `crs`**.
**337 entités, toutes en `MultiLineString`**, coordonnées en `[longitude, latitude]` WGS84
(exemple : `[9.1952…, 42.4827…]`, Golo aval, Corse), jusqu'à 15 décimales (artefacts de virgule
flottante). Chaque entité porte, à côté de `type`, `properties` et `geometry`, une clé `id` égale
à `properties.id` (337 sur 337).

⚠️ **La `bbox` déclarée ne contient pas toutes les données** : `[-4.1486, 42.4018, 8.2333,
50.8871]`, quand l'emprise réelle des tracés, calculée sur le document, est `[-4.1486, 41.9803,
9.5499, 50.8871]` — les 4 tronçons corses (territoire `26`) en sortent. Elle ne sert donc pas
d'emprise des données.

Propriétés de chaque entité (14) : `CdTCC`, `id`, `CdEntCru` (code du tronçon, par exemple
`BT5`), `typentcru` (`"8"` partout : tronçon), `lbentcru` (libellé, par exemple « Blavet »),
`acroentcru`, `cddient_1`, `dhcentcru`, `dhmentcru`, `stentcru` (`"Validé"` partout),
`cdensup_1` (code du territoire, `VC-08`), `typensup_1` (`"5"` partout : territoire), `cdint`,
`NivInfViCr` (niveau, `VC-04`). Tous les codes sont des **chaînes** ; `NivInfViCr` est un
**nombre** JSON (`1`, pas `"1"`). Aucun code de tronçon en double.

La fixture est un **extrait déclaré** : les 15 entités du territoire `8` (Vilaine-Côtiers
Bretons), recopiées sans modification, avec les cinq autres membres de premier niveau du document
d'origine tels quels (`bbox` reste celle de la France). Le document complet n'est pas versionné
(2,2 Mo) ; son empreinte SHA-256 au 2026-10-14 à 14:30:49 UTC :
`ccbc55bfb043091c29e9b97b8d5f5f3b420c1577380b5ddb1bcb852cdb7615d6`.

### `VC-04` — codage des niveaux

**`NivInfViCr` prend les valeurs de la nomenclature Sandre n° 837**, « Niveau de vigilance de
l'information de vigilance crues » (statut « Validé », mise à jour 2016-07-26, quatre éléments),
selon le dictionnaire Sandre VIC 1.1, qui définit le niveau comme le risque encouru « dans les
24 heures suivant la date d'émission de l'information de vigilance crues ». Nomenclature relue par
appel réel à 14:32:59 UTC (fixture `sandre_nomenclature_837_2026-10-14.json`) :

| Code | Mnémonique | Libellé Sandre |
|---|---|---|
| `1` | Vert | Pas de vigilance particulière |
| `2` | Jaune | Attention requise |
| `3` | Orange | Grande vigilance |
| `4` | Rouge | Vigilance absolue |

**Seul `1` est observé en production** (337 entités sur 337, le 2026-10-14). Les codes `2` à `4`
sont **documentés, non observés** : leur forme dans le GeoJSON (nombre comme `1` ?) n'est pas
constatée. Toute autre valeur, absente ou `null`, est à lire « niveau inconnu » (`BR-011`).

### `VC-05` — date de l'information

**Le document est daté au premier niveau** — ⚠️ *le relevé de 14:24 UTC, qui n'avait lu que les
propriétés des entités, disait le contraire* :

- `DtHrInfoVigiCru` : `"2026-10-14T13:55:31+00:00"` (ISO 8601, décalage explicite) ;
- `RefInfoVigiCru` : `"14102026_16"` (la production de 16 h du 14 octobre, lecture probable du
  nom, non documentée).

Rejoué à 14:36:45 UTC : mêmes valeurs. `13:55:31` UTC est 15 h 55 à Paris : c'est la date du
bulletin national (« publié le 14.10.2026 à 15h55 », page d'accueil ; « Date de publication de
l'information 14.10.2026 à 15h55 » sur `/bulletin_national`, `/bulletin_local/8` et
`/bulletin_local/29`) et le `pubDate` du flux RSS national (`Wed, 14 Oct 2026 15:55:31 +0200`).
Les bulletins annoncent aussi une « Date de prochaine actualisation au plus tard »
(15.10.2026 à 10h00) **que le GeoJSON ne porte pas**. Rythme annoncé par la page d'accueil :
« Production de l'information au moins deux fois par jour, à 10h et 16h » (non mesuré).

`dhcentcru` et `dhmentcru` datent, **d'après leur nom**, la création et la modification du
tronçon, pas la vigilance (format `"2020/09/15 09:00:00.000"`, sans fuseau ; de 2006 à 2025 sur le
document, dont 16 tronçons en octobre 2025). Leur sens n'est pas documenté : les champs
correspondants du référentiel (`DtHrCreatEntVigiCru`, `DtHrMajEntVigiCru`) valent « A renseigner
obligatoirement ».

### `VC-06` — poids des tracés

56 110 points, 537 lignes, au plus 910 points pour un tronçon (`MP12`). Simplification de
Douglas-Peucker mesurée sur le document (script hors dépôt, `node`, coordonnées arrondies à 5
décimales) :

| Tolérance | Points | JSON | Compressé (gzip) |
|---|---|---|---|
| aucune — document servi, toutes propriétés, coordonnées d'origine | 56 110 | 2 245 691 o | 812 081 o |
| ~56 m (0,0005°) — tracés seuls, 5 décimales | 54 889 | 1 046 388 o | 354 482 o |
| ~111 m (0,001°) | 35 661 | 682 320 o | 237 797 o |
| ~222 m (0,002°) | 20 515 | 395 695 o | 142 535 o |

De la première ligne à la deuxième, le gain vient surtout du retrait des propriétés et de
l'arrondi (−2 % de points seulement) ; les lignes suivantes, sur la même base, mesurent la
simplification. **Effet sur `NFR-01` non mesuré** : aucune construction n'a dessiné ces tracés.

### `VC-07` — couverture

Le GeoJSON compte **337** tronçons ; le référentiel `TronEntVigiCru.json` en compte **341**. Les
quatre absents du GeoJSON sont en Guyane : `GU1` Lawa amont, `GU2` Lawa aval, `GU3` Moyenne vallée
du Maroni, `GU4` Basse vallée du Maroni. Le GeoJSON couvre la métropole et la Corse (18 codes de
territoire dans `cdensup_1`) ; le référentiel des territoires en liste 20, dont `973` (Guyane) et
`999` (National). La Réunion a son propre site (`vigicrues-reunion.re`, lien de la page
d'accueil), non relevé. **Un cours d'eau hors de ces tronçons n'est pas suivi par Vigicrues** —
le réseau « ne couvre pas tous les cours d'eau » (mentions légales).

### `VC-08` — territoire et bulletin à lier

`cdensup_1` est le code du **territoire de vigilance** du tronçon (`typensup_1` = `5`). Son nom
n'est pas dans le GeoJSON : il est dans `TerEntVigiCru.json` (20 territoires, 5 669 octets,
fixture `territoires_2026-10-14.json` ; par exemple `8` → « Vilaine-Côtiers Bretons », `29` →
« Bassins du Nord »). Le bulletin du territoire se lit à
`https://www.vigicrues.gouv.fr/bulletin_local/<cdensup_1>` (`200`, HTML, vérifié pour `8` et `29`) ;
l'ancienne forme `http://…/bulletin-local.php?CdEntVigiCru=8`, encore citée par le flux RSS, y
mène par `301` (vers `https`) puis `302` (rejoué à 14:55:34 UTC). Bulletin national : `/bulletin_national`. Aucun bulletin n'est servi en
PDF ni en donnée structurée.

### `VC-09` — licence et attribution

Pied de page de chaque page : « Sauf mention contraire, tous les contenus de ce site sont sous
licence etalab-2.0 ». Mentions légales (`/categorie/2`, relues à 14:32:59 UTC), en substance :

- réutilisation **libre et gratuite** sous Licence Ouverte, à condition que l'information **ne
  soit pas altérée**, que **son sens ne soit pas dénaturé**, et que **sa source, « © VIGICRUES »,
  et la date de sa dernière mise à jour soient mentionnées** ;
- **marque et logo** VIGICRUES déposés : toute reproduction est **interdite sans accord** ;
- un lien vers le site est permis sans autorisation, à condition que **l'intitulé du lien
  mentionne explicitement www.vigicrues.gouv.fr** ;
- les tracés de tronçons dérivent de la BD CARTHAGE®, elle aussi sous Licence Ouverte ;
- aucune garantie de disponibilité ; formats susceptibles d'évoluer **sans préavis** (FAQ,
  `/categorie/1`, qui annonce aussi une vigilance « bientôt disponible sous une forme
  structurée » avec le Sandre, sans date).

### `VC-10` — erreurs et pannes

Les erreurs sont servies en **HTML**, jamais en JSON : un chemin inconnu sous `/services/` répond
`404`, `text/html` (34 380 octets) ; `api/docs.jsonld` répond `500`, `text/html`. **Aucune panne du
GeoJSON n'a été observée** ; ni délai, ni coupure, ni réponse tronquée n'ont pu être provoqués.
Le flux RSS, lui, répond `200` à une erreur (`VC-12`).

### `VC-11` — lien station–tronçon

Le détail d'un tronçon (`TronEntVigiCru.json?CdEntVigiCru=AP1&TypEntVigiCru=8`) liste ses
**stations de vigilance** (`aNMoinsUn`, six pour `AP1` Sambre : `D019223001`, `D016221001`,
`D019801101`, `D019801201`, `D015850001`, `D019701001`). Ce sont des codes de station Hub'Eau à 10
caractères, **tous les six présents** dans `assets/referentiel/stations.json`. Le lien inverse est
vide : le détail d'une station (`StaEntVigiCru.json?CdEntVigiCru=E351122001&TypEntVigiCru=7`, la
Lys à Delettes, `200` à 14:30:57 UTC, sans fixture) porte, pour son tronçon et son territoire,
`CdEntVigiCruSuperieur` « A renseigner ». Beaucoup de champs du référentiel valent la chaîne « A renseigner
obligatoirement ». Le GeoJSON, lui, ne porte aucune station.

### `VC-12` — flux RSS par tronçon (écarté)

`/territoire/rss?CdEntVigiCru=BT5,AP1` se filtre par une liste de codes séparés par des virgules
(2 à 20 Ko, `text/xml`, « v1.7.0b1 ») ; le niveau y est un **mot** dans le titre (« Blavet :
vert ») ; la date de l'item est l'« Actualisation de la page du territoire », **pas celle de
l'information en cours** (13 octobre à 16 h 27 pour le territoire 8, quand le bulletin du même
territoire dit 14 octobre à 15 h 55). Deux pièges, tous deux en `200` :

- un **code inconnu** (`ZZ999`) rend le message national « Pas de vigilance particulière
  requise » — qui se lirait « vert » ;
- un **paramètre invalide** (vide, `';`, ou un code de territoire comme `8`) rend un corps HTML de
  39 octets : « Param&egrave;tre CdEntVigiCru invalide. ».

Écarté par l'arbitrage du 2026-10-14 (voir « Arbitrages »).

### `VC-13` — définitions publiées des niveaux

La page d'accueil de Vigicrues publie une légende courte et, pour trois niveaux, une explication.
Recopiées au caractère près (fixture `accueil_legende_2026-10-14.html`, entités HTML décodées,
apostrophes d'origine) :

| Niveau | Légende | Explication |
|---|---|---|
| Rouge | Risque de crue majeure | Risque de crue majeure. Menace directe et généralisée de la sécurité des personnes et des biens. |
| Orange | Risque de crue génératrice de débordements importants | Risque de crue génératrice de débordements importants susceptibles d’avoir un impact significatif sur la vie collective et la sécurité des biens et des personnes. |
| Jaune | Risque de crue génératrice de débordements | Risque de crue génératrice de débordements et de dommages localisés ou de montée rapide et dangereuse des eaux, nécessitant une vigilance particulière notamment dans le cas d'activités exposées et/ou saisonnières. |
| Vert | Pas de vigilance particulière requise | — (aucune) |

**Écarts avec la nomenclature Sandre 837** (`DefElement`) : orange, « la sécurité des
**personnes et des biens** » et « d'avoir » (apostrophe droite) côté Sandre, « la sécurité des
**biens et des personnes** » et « d’avoir » (apostrophe courbe) côté Vigicrues ; vert, « Pas de
vigilance particulière requise. » avec point côté Sandre, et aussi côté Vigicrues dans la bannière
de la page d'accueil et le corps des flux RSS — seule la légende l'écrit sans point. Jaune et
rouge : identiques. Le choix du texte cité revient au cadrage détaillé (`BR-014`).

## Arbitrages

| Date | Question | Réponse du commanditaire |
|---|---|---|
| 2026-10-14 | La seule source qui porte tracés et niveaux est un appel national de 2,2 Mo, sans filtre ni date — quelle voie pour T4 ? | « Tracés embarqués + RSS » — **réponse donnée sur un fait faux** : le GeoJSON est daté (`VC-05`) |
| 2026-10-14 | Correction : le GeoJSON est daté, et la date du RSS par tronçon n'est pas celle de la vigilance en cours (`VC-12`). Le choix tient-il ? | **« Passer à B, GeoJSON »** : un appel national mis en cache, niveaux chiffrés Sandre 837, date et tracés dans le même document, aucune bibliothèque ; `NFR-07` **à amender** pour Vigicrues avec son motif (au cadrage détaillé) ; `NFR-01` à mesurer à la porte |

## Non vérifié

- Les niveaux `2`, `3`, `4` en production, et leur forme dans le GeoJSON (`VC-04`) — à constater
  au premier épisode de vigilance.
- La taille et la forme du document un jour de vigilance (un tronçon en jaune porte-t-il d'autres
  propriétés ?).
- Une panne réelle : délai, coupure, document tronqué, `5xx` du GeoJSON (`VC-10`).
- Le rythme réel de publication (annoncé : au moins à 10 h et 16 h).
- Le délai et le poids de l'appel sur Android, sur réseau mobile.
- L'effet des 56 110 points sur la fluidité de la carte (`NFR-01`, `VC-06`).
- Le sens exact de `RefInfoVigiCru` et des champs `CdTCC`, `cddient_1`, `cdint`, `acroentcru`.

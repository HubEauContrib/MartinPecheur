# Source — VigiEau (restrictions sécheresse)

Base URL `https://api.vigieau.beta.gouv.fr/api` · Swagger à la **racine**, pas sous `/api` :
`https://api.vigieau.beta.gouv.fr/swagger-json` (`/api/swagger-json` et `/api/api-docs`
répondent `404`) · `version` **`0.1`** (relevée le 2026-09-27, identique au 2026-07-30) · aucune
authentification · Licence Ouverte 2.0. Rôle : niveau de gravité sécheresse et usages restreints
par zone d'alerte, au point désigné. Décision liée : `ADR-004` (à amender, Q3 du cadrage T2).

⚠️ **API en version `0.1`, deux mois séparent cette capture de la précédente** (`C-16`) : ce qui
suit reconfirme, précise ou contredit `ADR-004`/`01-analyse.md § 3.1` du 2026-07-30 — jamais une
recopie.

## Endpoints vérifiés le 2026-09-27

| Endpoint | Rôle | Fixture |
|---|---|---|
| `GET /swagger-json` (racine) | schéma OpenAPI complet | `vigieau/swagger_2026-09-27.json` |
| `GET /departements` | niveau de gravité maximum par département, par type d'eau | `vigieau/departements_2026-09-27.json` |
| `GET /zones?lat=&lon=&profil=` | zones d'alerte au point, usages filtrés par profil | `vigieau/zones_ain_bourg-en-bresse_*`, `zones_corse_ajaccio_2026-09-27.json`, `zones_paris_vigilance_2026-09-27.json`, `zones_ariege_foix_crise_2026-09-27.json`, `zones_guyane_aucune_zone_2026-09-27.json`, `zones_atlantique_hors_france_2026-09-27.json`, `zones_coordonnees_invalides_400_2026-09-27.json` |
| `GET /zones?commune=` | conflit sur commune à plusieurs zones | `vigieau/zones_commune_45210_409_2026-09-27.json` |
| `GET /arretes_restrictions?departement=` | sémantique non élucidée | `vigieau/arretes_restrictions_departement_03_2026-09-27.json` |
| `HEAD` sur `arrete.cheminFichier` | accessibilité du PDF | non gardé en fixture (en-têtes seulement, voir `CAPTURES.md`) |

## Faits constatés le 2026-09-27

### `VG-01` — l'API répond-elle encore, à la même adresse, en version `0.1` ?

**Oui, avec un écart d'adresse.** `https://api.vigieau.beta.gouv.fr/api/swagger-json` (l'adresse
citée par `ADR-004`) répond **404** aujourd'hui ; le schéma complet est servi à la **racine du
domaine** : `https://api.vigieau.beta.gouv.fr/swagger-json` → `200`. `version` reste **`0.1`**,
`title` reste `"API VigiEau"`. Fixture : `vigieau/swagger_2026-09-27.json`.

### `VG-02` — forme de la réponse, plusieurs zones, plusieurs zones du même type ?

`/zones` rend une **liste JSON** d'objets `ZoneDto` (jamais un objet unique). Sur les cinq points
interrogés qui portent au moins une zone, **chacun en porte trois** : un `SUP`, un `SOU`, un
`AEP` simultanément (Ain, Corse, Paris) ou deux sur le point d'Ariège (`AEP`, `SUP` — le `SOU`
n'y est pas remonté, sans qu'on sache s'il est absent ou d'un niveau différent non atteint par ce
point précis). **Aucune occurrence de deux zones du même type au même point** n'a été observée
par `lat`/`lon` dans cet échantillon ; le cas existe **par commune** (`?commune=45210` → `409`,
voir `VG-10`), pas confirmé par point exact.

### `VG-03` — « aucune restriction » et les points hors zone

**`200` avec un corps `[]`, jamais `404`.** Constaté sur un point en Guyane (`4.9,-52.3`, le
département `973` n'a d'ailleurs aucune valeur `niveauGravite*Max` dans `/departements`) et sur
un point en pleine mer (Atlantique, `45.0,-30.0`). Fixtures :
`vigieau/zones_guyane_aucune_zone_2026-09-27.json`,
`vigieau/zones_atlantique_hors_france_2026-09-27.json`. La Corse et les DOM avec zone active
(Guadeloupe, Martinique, La Réunion) ont été vus dans `/departements` — non creusés par point
faute de budget d'appels, listés en « Non vérifié ».

### `VG-04` — nomenclature exacte de `niveauGravite`

Le schéma `ZoneDto`/`DepartementDto` déclare l'énumération fermée
`["vigilance", "alerte", "alerte_renforcee", "crise"]`. **Les quatre valeurs sont désormais
observées en réponse réelle**, ce qui n'était pas le cas le 2026-07-30 (`vigilance` non
observée) :

| Valeur | Constatée où |
|---|---|
| `vigilance` | Paris (`zones_paris_vigilance_2026-09-27.json`), et 3 départements dans `/departements` (`75`, `92`, `93`) |
| `alerte` | Ain, Corse |
| `alerte_renforcee` | 15-16 départements dans `/departements` |
| `crise` | Ariège (`zones_ariege_foix_crise_2026-09-27.json`), et 77-78 départements dans `/departements` — la valeur la plus fréquente fin septembre |

Aucune valeur « aucun » ni `null` n'a été vue : l'absence de restriction se lit par l'absence de
zone (`VG-03`), jamais par une valeur de gravité neutre — confirme `BR-011` et `BR-007`.
`niveauGraviteAepMax` est `null` sur `973` (Guyane) et `976` (Mayotte) dans `/departements`,
cohérent avec `VG-03`.

### `VG-05` — valeurs de `profil`, obligatoire, effet sur `usages[]`

Le schéma déclare `["particulier", "entreprise", "collectivité", "exploitation"]` — **avec accent
sur `collectivité`**. `profil` n'est **pas obligatoire** (`/zones` sans `profil` répond `200` et
rend l'union de tous les usages). **Le filtrage est fait côté serveur**, pas par des drapeaux
laissés au client : sur le point de l'Ain, le nombre d'`usages` par zone varie avec `profil`
(zone `SOU`, 45 usages sans profil → 30 en `particulier`, 26 en `exploitation`, 36 en
`entreprise`).

🚨 **Écart avec le schéma documenté** : `profil=collectivit%C3%A9` (la valeur accentuée du
Swagger, correctement URL-encodée) répond `200` mais rend **zéro usage** sur les trois zones
(fixture `zones_ain_bourg-en-bresse_profil_collectivite_accentue_2026-09-27.json`), alors que la
réponse sans profil compte **35** usages à `concerneCollectivite: true` sur la seule zone `SOU`.
`profil=collectivite` (**sans accent**) rend au contraire **35** usages sur cette même zone
(fixture `..._profil_collectivite_sans_accent_2026-09-27.json`) — exactement la valeur attendue.
**La valeur qui fonctionne réellement est `collectivite`, sans accent ; celle du Swagger
(`collectivité`) est silencieusement ignorée et rend une liste vide, sans erreur.** Aucune
release note consultée pour expliquer l'écart — à retenir comme piège d'intégration (candidat à
un futur `C-xx`).

### `VG-06` — forme d'un usage

`UsageDto` : `id` (numérique), `thematique` (ex. `"Abreuver"`), `nom` (ex.
`"Abreuvement des animaux"`), `description` — c'est ce champ qui porte le texte à citer tel quel
(ex. constaté : `"Prévenir les agriculteurs"`, `"Arrosage interdit de 8h à 20h."` en exemple du
schéma) — et quatre booléens `concerneParticulier`, `concerneEntreprise`, `concerneCollectivite`,
`concerneExploitation`. Aucun champ horaires structuré ni champ dérogation séparé : tout est dans
`description`, en texte libre.

### `VG-07` — `arrete.cheminFichier`, arrêté-cadre

`cheminFichier` est une **URL absolue** (constaté : hébergement S3 OVH,
`https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/…`). `HEAD` sur l'URL de l'arrêté
d'Ariège (11:26:51 UTC) → `200`, `Content-Type: application/pdf`, `Content-Length` **7 240 160**
octets (non téléchargé, seul l'en-tête a été demandé). Le schéma déclare aussi
`cheminFichierArreteCadre` (URL du PDF de l'arrêté-cadre) — présent dans le DTO, non vérifié par
un appel séparé (voir « Non vérifié »).

### `VG-08` — dates

`arrete.dateDebutValidite` **et** `arrete.dateFinValidite` sont toutes deux présentes, en ISO 8601
UTC avec heure (ex. `"2026-08-20T00:00:00.000Z"`, `"2026-10-31T00:00:00.000Z"` sur la zone `SOU`
de l'Ain) — pas seulement une date de début, à l'inverse de ce que citait `01-analyse.md § 3.1`.
Aucun champ de date de mise à jour de la donnée n'existe sur `ZoneDto` ; `/departements` porte en
revanche `availability.AEP.asOf` (ex. `"2026-09-27T00:44:28.228Z"`), une fraîcheur au niveau
département, pour l'eau potable seulement.

### `VG-09` — identité de la zone

Chaque zone porte `id` (numérique interne), `code` (ex. `"84_01_4"`, `"01_ZONE_SUP"` en exemple
du schéma) et `nom`, un libellé lisible réel — constaté : `"Dombes - Certines - Nord"`,
`"Rivières de Bresse"`, `"Zone 3"` (Corse), `"Bassins de la Marne et de la Seine"` (Paris),
`"Zone d'alerte n°4.3_Les affluents de l'Ariège aval"` (Ariège), `"UDI_crise"` (zone `AEP`
d'Ariège). Le style de libellé varie beaucoup d'une zone à l'autre — aucun format uniforme,
aucune garantie de longueur. ⚠️ `code` peut être **`null`** : c'est le cas de la zone `AEP` d'Ariège
(`zones_ariege_foix_crise_2026-09-27.json`) — le code ne peut donc pas servir seul d'identifiant affiché.

### `VG-10` — codes d'erreur, latence

- **`400`** sur coordonnées hors plage : `?lat=999&lon=999` →
  `{"message":["lon must be a longitude string or number","lat must be a latitude string or number"],"error":"Bad Request","statusCode":400}`.
- **`409`** reconfirmé aujourd'hui sur `?commune=45210` (`C-14`) :
  `{"statusCode":409,"message":"La commune comporte plusieurs zones d'alerte de même type."}`.
- **`429`/`5xx`** : non observés — non provoqués, la politesse de capture (≤ 1 requête/s,
  ≤ 60 appels) ne permet pas de les déclencher volontairement.
- **En-têtes de limite** : `X-RateLimit-Limit: 300`, `X-RateLimit-Remaining`, et — nouveau par
  rapport au 2026-07-30 — `X-RateLimit-Reset: 1` est désormais présent sur `/departements`. Sa
  fenêtre exacte (1 seconde ? 1 unité d'une autre échelle ?) reste **non élucidée** : la valeur
  seule ne suffit pas à la déterminer sans essai supplémentaire hors politesse.
- **Latence** : tous les appels de cette capture ont répondu en 0,07 à 0,24 s (`time_total`,
  hors le `HEAD` du PDF, 0,24 s) — échantillon d'un seul jour, aucune mesure sous charge.

### `VG-11` — `SOU` et `AEP` au même point qu'une zone `SUP`

**Oui, confirmé sur cinq points sur cinq testés qui portent une zone.** Ain, Corse et Paris
rendent chacun trois zones simultanées (`SUP`, `SOU`, `AEP`) ; l'Ariège en rend deux (`AEP`,
`SUP`). Les niveaux de gravité et les usages **diffèrent par type de zone au même point** — sur
l'Ain, `SOU` est à `vigilance` quand `SUP`/`AEP` sont à `alerte`, avec des jeux d'usages propres à
chaque zone (45 usages sur `SOU`, 27 sur `SUP`, 19 sur `AEP`, sans profil). `Q5` (filtrage `SUP`
seul) omettrait donc silencieusement des zones actives d'un autre type, avec un niveau parfois
plus sévère.

## Écarts avec ce qui était écrit le 2026-07-30 (`ADR-004`, `01-analyse.md § 3.1`)

| Écrit le 2026-07-30 | Constaté le 2026-09-27 |
|---|---|
| Swagger à `/api/swagger-json` | **404** à cette adresse ; le schéma est à `/swagger-json` (racine du domaine, hors `/api`) |
| `vigilance` « non observée », existence seulement attendue | **Observée** en réponse réelle (Paris) et dans `/departements` (3 départements) |
| Filtrage par profil non détaillé | Confirmé **serveur**, par comptage d'usages ; **une valeur d'énumération du Swagger ne fonctionne pas** (`collectivité` accentué → 0 usage, `collectivite` sans accent → le bon compte) |
| `/arretes_restrictions?departement=03` → `[]`, sémantique non élucidée | **Identique** aujourd'hui : `[]`, sémantique **toujours** non élucidée |
| Filtrage `type = "SUP"` retenu par la décision | `SOU`/`AEP` confirmés présents au même point que `SUP`, avec niveaux et usages propres (`VG-11`) — matière à Q5 du cadrage T2 |
| Aucune mention d'un `X-RateLimit-Reset` | Présent aujourd'hui sur `/departements` ; fenêtre non déterminée |

## Non vérifié

- **La fenêtre exacte de `X-RateLimit-Reset`** (valeur `1` vue une fois, unité non déterminée).
- **`429` et `5xx`** : jamais provoqués, comportement du client à cet égard non observable
  aujourd'hui.
- **`cheminFichierArreteCadre`** : champ présent dans le schéma, **aucun appel `HEAD` séparé**
  n'a été fait dessus (le point d'Ariège en portait un dans `arrete`, non testé isolément).
- **Deux zones du même type au même point exact (hors commune)** : non rencontré dans
  l'échantillon de cinq points ; le cas `409` n'a été observé que par `commune`.
- **Points DOM autres que la Guyane** (Guadeloupe, Martinique, La Réunion, Mayotte) et la Corse
  au-delà d'Ajaccio : vus seulement au niveau département dans `/departements`, aucun appel
  `lat`/`lon` dédié faute de budget — les niveaux de gravité de ces départements
  (`crise`/`alerte_renforcee`/`alerte`/`aucune donnée` pour la Guyane et Mayotte) sont, eux,
  constatés.
- **`vigilance` par point autre que Paris** : un seul point testé porte ce niveau.
- **Cas `alerte_renforcee` par point exact** : présent dans `/departements` (16 départements),
  **aucun point précis interrogé** dans cette capture pour ce niveau — seuls `alerte` (Ain,
  Corse), `vigilance` (Paris) et `crise` (Ariège) l'ont été par appel `/zones`. Non capturé,
  écrit tel quel plutôt que supposé.
- **`crise` récent ou levé** : sans objet ici — `crise` est au contraire le niveau **le plus
  fréquent** constaté fin septembre 2026, à l'inverse de la mise en garde du cadrage T2 sur un
  hypothétique manque de cas.

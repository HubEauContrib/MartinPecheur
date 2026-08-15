# État du projet

**Mis à jour :** 2026-08-15

## Où on en est

🚨 **Bascule de stack le 2026-07-31.** Le commanditaire a révisé son arbitrage .NET : le projet
passe à **React Native** et **abandonne Windows** ([`ADR-010`](adr/ADR-010-react-native.md)).

**L'implémentation repart de zéro.** Le cadrage produit, lui, est intact — il ne dépendait pas
de la stack.

## Ce qui est acquis

| Sujet | État |
|---|---|
| Analyse des APIs | ✅ Vérifiée par appels HTTP réels les 2026-07-30 et 07-31 |
| Question centrale du « débit suffisant » | ✅ Tranchée (`ADR-002`) et documentée avec ses limites |
| Sources retenues et écartées | ✅ 7 APIs évaluées, motifs documentés |
| Règles métier | ✅ 14 règles, chacune avec son test |
| Cas d'usage | ✅ 6 cas, flux nominaux et alternatifs |
| Avertissements | ✅ Les 4 emplacements spécifiés, textes rédigés |
| Stack | ✅ **Tranchée le 2026-07-31** — React Native (`ADR-010`), arbitrage du commanditaire |
| Hors-ligne cartographique | ✅ **N'est plus un risque** — `OfflineManager.createPack` vérifié le 2026-07-31 |

## Code

**L'implémentation React Native a commencé le 2026-07-31.** Le plan suivi est
[`T0 — Socle React Native`](superpowers/plans/2026-07-31-t0-socle-react-native.md).

| Tâche | Livrable | État |
|---|---|---|
| `S1` | Projet Expo `57.0.9`, TypeScript `6.0.3`, code sous `src/` | ✅ `08bf832` |
| `S2` | `tsconfig` durci — `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, alias de couches | ✅ `08bf832` |
| `S3` | Jest projet `unit` (node, sans `jest-expo`) + ESLint + test d'architecture | ✅ `8c6ed61` |
| `S4` | Référentiel figé — **4 150 stations**, 6 604 249 octets, tous codes à 10 caractères | ✅ `0a76733` |
| `D1` | **Conversion d'unités avec types *branded*** — 10 tests | ✅ `17d3359` |
| `D2` | Nomenclature ONDE close, branche `Inconnu`, garde `never` | ✅ `37cd92a` |
| `D3` | Fraîcheur d'observation aux bornes de `BR-005` (2 h / 24 h) | ✅ `20842be` |
| `D4` | Entités `Station`, `HydroObservation`, `Qualification` + interfaces de dépôt | ✅ `42948e8` |
| `N1` | `isSuccess` — 200 **et** 206 (`C-06`) | ✅ `5504b3c` |
| `N2` | `delayForAttempt` — backoff exponentiel à gigue injectée (`C-15`) | ✅ `5504b3c` |
| `N3` | Mapper `observations_tr` — conversion appliquée **une seule fois** | ✅ `b13a11b` |
| `N4` | Client Hub'Eau — retry sur 429/5xx, jamais sur 4xx | ✅ `dbb74d3` |
| `N5` | Décorateur `CachePolicy` **unique** — stale-while-revalidate | ✅ `2cf3ad2` |
| `S5` | Bibliothèque SQLite → `ADR-011` | 🔄 mesurable sur l'émulateur ; le critère « entrée de gamme » demande en plus un **appareil réel** |
| `M1`–`M5` | Carte MapLibre, fond IGN, hors-ligne, mesure | 🔄 **débloqué** — outillage présent, `ANDROID_HOME` à poser |
| `P1`–`P4` | Outillage percentiles | 🔄 à faire — indépendant, aucun appareil requis |

**Chaîne de vérification verte :** `npm run verify` → `tsc --noEmit` sans erreur, ESLint propre,
**67 tests** sur 10 suites *(mesuré le 2026-08-15)*.

> ⚠️ **Deux écarts entre le plan T0 et le code livré**, constatés en exécutant `N3` et `N4`. Le code
> a raison, le plan est une esquisse antérieure :
>
> | Le plan écrit | `D2`/`D4` ont livré |
> |---|---|
> | `HydroObservation.libelleQualification: string \| null` | un objet `Qualification` à 4 champs — `BR-006` demande le **statut** aussi, pas seulement la qualification |
> | `delayForAttempt(attempt, 500, 30_000)` | `delayForAttempt(attempt, jitter?)` — base et plafond sont des constantes du module |

### Ce qui a été contre-éprouvé, et pas seulement écrit

Un garde-fou qu'on n'a pas vu mordre n'est pas un garde-fou. Trois vérifications faites le
2026-07-31 :

| Garde-fou | Contre-épreuve | Résultat |
|---|---|---|
| Types *branded* (`BR-002`) | Retirer un `@ts-expect-error` | `TS2345: Argument of type 'number' is not assignable to parameter of type 'LitresPerSecond'` |
| Test d'architecture | Ajouter `import { Platform } from "react-native"` dans `domain/` | `src/domain/units/conversions.ts importe « react-native »` — 1 failed |
| ESLint `no-restricted-imports` | idem | `'react-native' import is restricted` — 1 error |

### Le code .NET

Retiré du working tree le 2026-07-31 sur arbitrage du commanditaire (`74afe6d`). Il reste
intégralement dans l'historique git et n'est repris nulle part :

| Tâche | Livrable .NET | Sort |
|---|---|---|
| `A1` | `src/MartinPecheur.App` (MAUI Blazor Hybrid, 3 cibles vertes) | 🗑️ caduc — `696be3a` |
| `B0` | Vérification `BrilliantMediator` (aucun *behavior*) | 🗑️ sans objet |
| `B1` | `Domain`, `Application`, `Data`, `tests/` | 🗑️ caduc — `22e9850` |
| `B3a` | `MeasurementUnits.cs`, 8 tests verts | 🗑️ caduc — **à réécrire en TypeScript** |

> `B3a` mérite d'être refait **en premier** sur la nouvelle stack : la conversion d'unités reste
> le bug le plus coûteux du projet, et TypeScript la protège moins bien que C#.

## Constats d'API du 2026-07-31 — à reporter dans `01-analyse.md`

Relevés pendant `A2`, avant la bascule. Indépendants de la stack :

| Constat | Détail |
|---|---|
| `size` plafonne à **10000** | Le plan T0 écrivait `size=20000` → **HTTP 400** `ValidatePageSize` |
| **200 et 206 coexistent** | `size=1` → **206** ; `size=5000` (≥ 4 140 résultats) → **200**. Confirme `C-06` en production |
| Volume | **4 140 stations** en service, **6,57 Mo** en GeoJSON brut, 0 géométrie manquante. ⚠️ **Re-mesuré le 2026-08-15 : 4 150 stations, 6 604 249 octets** — le référentiel bouge |
| Codes station | 4 150 codes distincts, **tous à 10 caractères** — cohérent avec `C-05` |

## Ce qui bloque, ou reste à trancher

| # | Sujet | Nature |
|---|---|---|
| 1 | ~~Le plan T0 est écrit pour .NET~~ — **levé le 2026-07-31** : [`T0 — Socle React Native`](superpowers/plans/2026-07-31-t0-socle-react-native.md) le remplace | Clos |
| 2 | Trois ADR tranchés **sans arbitrage du commanditaire** : `ADR-002`, `ADR-004`, `ADR-006` | Décisions par défaut, réversibles. Chacune porte sa section « Si la décision est revue » |
| 3 | **Réduction de périmètre à valider** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 4 | Le cadrage annonçait **3 modalités ONDE** ; il y en a **6** (`ADR-006`) | Corrigé dans la spec |
| 5 | Poids réel de l'asset de percentiles | À mesurer, pas à estimer |
| 6 | Script de build des percentiles | Lot d'outillage à chiffrer (`ADR-003`) |
| 7 | **Hôte macOS** pour produire un build iOS | **Matériel.** Bloquant pour livrer iOS, pas pour développer |
| 7 bis | ~~Outillage Android~~ — **levé le 2026-08-15** : inventaire refait (tableau ci-dessous), tout est en place, `ANDROID_HOME` compris. Le lot 3 n'a jamais été bloqué | Clos |
| 8 | Bibliothèque SQLite, bibliothèque de graphes, outil de test | À trancher (`ADR-010` § « Points à vérifier ») |
| 9 | ~~Téléchargement de tuiles hors-ligne~~ — **levé le 2026-07-31** : `OfflineManager.createPack` le fournit | Clos par `ADR-010` |
| 10 | ~~Behaviors BrilliantMediator~~, ~~AOT et trimming~~, ~~portage Windows~~ | Sans objet depuis `ADR-010` |

## Vérifications du 2026-07-31 — carte et hors-ligne

Faites avant d'écrire le plan T0, par appel réel et lecture de code source.

| Fait | Constat | Source |
|---|---|---|
| WMTS IGN — capacités | **HTTP 200**, `application/xml`, 2,86 Mo | `data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetCapabilities&VERSION=1.0.0` |
| WMTS IGN — tuile | **HTTP 200**, `image/png`, **256×256** en `TILEMATRIXSET=PM` — donc adressable en `{z}/{x}/{y}` | même hôte, `REQUEST=GetTile&TILEMATRIX=5&TILECOL=16&TILEROW=11` |
| MapLibre télécharge bien le raster hors-ligne | `SourceType::Raster` traité **à l'identique** de `SourceType::Vector` → `queueTiles` → `Resource::tile(tileset.tiles[0], …)` | `maplibre-native`, `platform/default/src/mbgl/storage/offline_download.cpp` L191, L304, L451 |
| Version courante | `@maplibre/maplibre-react-native@11.3.6`, publiée le 2026-06-25 — v11 confirmée | `registry.npmjs.org` |
| API v11 confirmée | `createPack(options, progressListener, errorListener)` ; `OfflinePackCreateOptions { mapStyle, bounds, minZoom?=10, maxZoom?=20, metadata? }` ; packs identifiés par `pack.id` ; `addListener(packId)` / `removeListener(packId)` | `package/src/modules/offline/OfflineManager.ts` |

> **Ce que cela change :** le hors-ligne raster n'est plus une hypothèse en l'air — le chemin de
> code existe et le fond IGN est consommable en `{z}/{x}/{y}`. **Ce n'est pas pour autant vérifié :**
> rien n'a été exécuté. La distinction est maintenue ci-dessous.

## Points non vérifiés, assumés comme tels

- **Que `createPack` télécharge effectivement les tuiles d'un WMTS IGN à l'exécution.** Le code C++ le prévoit ; aucune exécution ne l'a constaté. C'est l'hypothèse qui porte tout le hors-ligne — tâche `M4` du plan T0.
- **Que l'URL KVP du WMTS IGN survive au *templating* de MapLibre.** Elle contient `?` et `&` ; l'expansion `{z}/{x}/{y}` n'a pas été observée dessus — tâche `M2`.
- **Que `tileset.tiles[0]` suffise.** MapLibre n'utilise que la **première** URL du tableau `tiles` pour le hors-ligne : déclarer des miroirs ne les téléchargerait pas.
- **Le chemin raster hors-ligne n'a aucun test amont** : `test/storage/offline_download.test.cpp` de `maplibre-native` ne contient **aucune** occurrence de « raster ».
- **Le volume d'un pack départemental.** Un raster 256 px produit ~4× plus de tuiles qu'un vectoriel 512 px au même zoom.
- Comportement de `maplibre-react-native` v11+ **en volume réel** (~4 140 points, clustering) sur Android d'entrée de gamme. Attendu bien meilleur qu'un WebView, mais **non mesuré**.
- Version exacte de la Licence Ouverte Etalab pour Hub'Eau (1.0 ou 2.0).
- Fenêtre du `X-RateLimit-Limit: 300` de VigiEau.
- Sémantique du paramètre `departement` de VigiEau `/arretes_restrictions`.
- Existence du niveau `vigilance` dans VigiEau — non observé le 2026-07-30.
- Mapping entre `nombre_modalite_ecoulement` (4 ou 5) et les codes ONDE disponibles.

## Prochaine étape

Le plan T0 est réécrit : [`T0 — Socle React Native`](superpowers/plans/2026-07-31-t0-socle-react-native.md).
Il s'exécute lot par lot — socle, domaine, données, carte, outillage percentiles.

**Au 2026-08-15, les lots 0 (hors `S5`), 1 et 2 sont livrés** — 12 tâches sur 23. Ce qui reste se
partage en deux, et la coupure n'est pas dans le plan : elle est dans le matériel.

| Reste | Peut démarrer ? |
|---|---|
| **Lot 4** — `P1`–`P4`, outillage percentiles | ✅ **Oui, tout de suite.** Script Node hors application, aucun appareil |
| **Lot 3** — `M1`–`M5`, carte | ✅ **Oui, tout de suite** — outillage complet, `ANDROID_HOME` posé, AVD Pixel 7 API 36 prêt |
| `S5` — bibliothèque SQLite | 🔄 Mesurable sur l'émulateur ; « entrée de gamme » demandera un appareil réel |

### Inventaire de l'outillage Android — mesuré le 2026-08-15

Le constat publié plus tôt dans la journée disait cet outillage absent. **Il était faux sur les
cinq lignes** : les sondes de chemins renvoyaient `False` sur des répertoires qui existent, et la
lecture de `ANDROID_HOME` le donnait vide alors qu'il est posé en `HKCU\Environment`. Refait en
lisant le registre plutôt que l'environnement du processus :

| Élément | État |
|---|---|
| JDK | ✅ `Microsoft.OpenJDK.17` `17.0.20.8` — `javac 17.0.20`, `JAVA_HOME` en portée *Machine* |
| Android Studio | ✅ `2026.1.3.7` — `C:\Program Files\Android\Android Studio\bin\studio64.exe` |
| **SDK complet** | ✅ `C:\Program Files (x86)\Android\android-sdk` — plateformes `android-35` **et `android-36`**, image `android-36/google_apis_playstore/x86_64`, `cmdline-tools/latest`, `build-tools 36.0.0`, `adb 36.0.0` |
| SDK d'Android Studio | ⚠️ `%LOCALAPPDATA%\Android\Sdk` — **`android-37.0` seulement, aucune image système, pas de `cmdline-tools`.** C'est exactement le piège de l'installation « Standard » décrit au `README` |
| AVD | ✅ `pixel_7_-_api_36_0` — `x86_64`, `google_apis_playstore` |
| `ANDROID_HOME` | ✅ `C:\Program Files (x86)\Android\android-sdk` — portée *User* (`HKCU\Environment`), pointe bien sur le SDK complet |

> **Le SDK utilisable est celui de Visual Studio**, hérité des workloads .NET Android de la stack
> abandonnée : c'est lui qui porte l'API 36 qu'Expo SDK 57 réclame. ⚠️ Il vit sous
> `Program Files (x86)`, donc **non inscriptible sans élévation** : si Gradle veut y installer un
> paquet manquant, il échouera. Le repli est de compléter le SDK d'Android Studio, qui est en zone
> utilisateur.

L'ancien plan ([`T0 — Spike carte & socle données`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md))
reste au dépôt pour l'historique, mais **ne doit plus être exécuté** : sa voie A est un spike
`BlazorWebView` sans objet, et sa voie B est en C#.

Ce qui a changé dans la logique du plan : **le spike carte a perdu son caractère bloquant.** Il
existait pour lever un doute sur le WebView ; MapLibre Native le rend sans objet. La séquence est
redevenue linéaire — socle, domaine, carte — au lieu de trois voies dont une conditionnait tout.

⚠️ **Ce qui reste vrai malgré cela :** `M4` — constater le pack hors-ligne raster sur l'IGN — est la
seule tâche dont l'échec remettrait en cause une décision d'architecture. Elle n'est plus
*bloquante*, mais elle ne se repousse pas en fin de tranche.

⚠️ **Ce qui reste vrai malgré la bascule :** la mesure sur un **Android d'entrée de gamme réel**
garde son intérêt. Le rendu natif est attendu bien meilleur, mais « attendu » n'est pas « mesuré ».

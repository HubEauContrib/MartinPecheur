# État du projet

**Mis à jour :** 2026-08-15 — après exécution de `M4`

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
| Hors-ligne cartographique | 🚨 **Redevenu un risque, et le plus sérieux du projet.** Le constat du 2026-07-31 était une **lecture de code source**, pas une exécution. Exécutée le **2026-08-15**, `OfflineManager.createPack` **tue le processus** — [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) |

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
| `M1` | **MapLibre 11.3.6 compile et l'app démarre sur l'émulateur** — APK de 58 Mo | ✅ `b035424` |
| `M2` | **Fond IGN raster affiché sur émulateur — `NV-2` levé** : le gabarit KVP survit à l'expansion `{z}/{x}/{y}` | ✅ `0c3596a` |
| `M4` | **Pack hors-ligne — exécuté, résultat négatif.** `createPack` plante en natif (`SIGABRT`, `std::regex_error`, fil `DatabaseFileSource`), **4 essais sur 4**. `NV-1`, `NV-3`, `NV-4`, `NV-6` **non levés** | 🚨 `ADR-012` |
| `M3`, `M5` | Marqueurs et clustering, mesure sur appareil réel | 🔄 à faire |
| `P1` | Script d'aspiration `obs_elab` — `C-04` reconfirmé par appel réel | ✅ `e535e27` |
| `P2`–`P4` | Percentiles par quinzaine, format d'asset, régénération | 🔄 à faire |

**Chaîne de vérification verte :** `npm run verify` → `tsc --noEmit` sans erreur, ESLint propre,
**118 tests** sur 14 suites *(mesuré le 2026-08-15, après `M4`)*.

> ⚠️ **Cinq écarts entre le plan T0 et le code livré.** Le code a raison, le plan est une esquisse
> antérieure. Les trois derniers ont été constatés **par exécution** en jouant `M4` :
>
> | Le plan écrit | Le constat |
> |---|---|
> | `HydroObservation.libelleQualification: string \| null` | `D2`/`D4` ont livré un objet `Qualification` à 4 champs — `BR-006` demande le **statut** aussi |
> | `delayForAttempt(attempt, 500, 30_000)` | `delayForAttempt(attempt, jitter?)` — base et plafond sont des constantes du module |
> | `mapStyle: JSON.stringify(ignRasterStyle)` | `mapStyle` est une **URL de style**. Un style sérialisé donne `Unable to parse resourceUrl {"version":8,…` |
> | *(rien sur les URI `data:`)* | Une URI `data:` **n'est pas résolue** : région `active`, `tuiles=0`, **aucune erreur**. Échec silencieux |
> | *(rien sur le plafond de tuiles)* | Le plafond par défaut est **6000** ; le dépasser **interrompt** le téléchargement et laisse un pack tronqué |

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
| 9 | 🚨 **Téléchargement de tuiles hors-ligne — ROUVERT le 2026-08-15.** Le « levé » du 2026-07-31 reposait sur une lecture de code, pas sur une exécution. Exécuté, `createPack` **plante** | **Arbitrage du commanditaire** — [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) |
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

- 🚨 **Que `createPack` télécharge les tuiles d'un WMTS IGN.** **Toujours pas vérifié au 2026-08-15, et désormais non testable :** l'appel plante avant qu'une tuile soit téléchargée. **Ni confirmé, ni infirmé** — `ADR-012`.
- 🚨 **Que `tileset.tiles[0]` suffise** (`NV-3`) — bloqué par le même plantage.
- 🚨 **Le volume d'un pack départemental** (`NV-4`) — **aucun octet mesuré**, bloqué par le même plantage.
- 🚨 **Le chemin raster hors-ligne n'a aucun test amont** (`NV-6`) : `test/storage/offline_download.test.cpp` de `maplibre-native` ne contient aucune occurrence de « raster ». Non levé.
- **Que le plantage de `createPack` soit propre à l'émulateur `x86_64`.** Le constat porte sur **un seul environnement**. Ni `arm64` réel, ni iOS — c'est l'essai le moins cher pour réduire la portée du problème.
- ~~Que l'URL KVP du WMTS IGN survive au *templating*~~ — **levé le 2026-08-15** (`M2`).
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

### `M1` — ✅ **résolu le 2026-08-15**

**L'APK se compile et l'application démarre sur l'émulateur** (`app-debug.apk`, 58 Mo). MapLibre
`11.3.6` et son code natif sont dans le binaire.

**La correction :** basculer `ANDROID_HOME` du SDK Visual Studio
(`C:\Program Files (x86)\Android\android-sdk`) vers le SDK utilisateur
(`%LOCALAPPDATA%\Android\Sdk`) — **sans espace ni parenthèse, et inscriptible sans élévation**.
Un seul changement, qui a levé les trois obstacles d'un coup :

- `clang++.exe` garde son nom complet, donc clang compile en C++ et lie la STL ;
- Gradle a pu **installer lui-même** `build-tools;35.0.0`, ce que le SDK en lecture seule
  interdisait ;
- le NDK `27.1.12297006`, recopié à ce même emplacement, est trouvé sans réglage particulier.

> Aucun contournement n'a survécu : le `buildToolsVersion` forcé dans `android/build.gradle` a été
> effacé par `expo prebuild --clean` et **n'a pas eu besoin d'être remis**. Le SDK Visual Studio est
> intact — rien n'a été désinstallé, seulement copié.

<details>
<summary>Historique du diagnostic — trois obstacles, cinq hypothèses fausses</summary>

### Ce qui bloquait le build natif, avant le 2026-08-15

Trois obstacles rencontrés en séquence, tous de la même famille : **le SDK vient de Visual Studio
et ne contient pas les versions qu'attend l'écosystème React Native.**

| # | Obstacle | État |
|---|---|---|
| 1 | `build-tools;35.0.0` réclamée par le module `:expo`, absente (seule la 36.0.0 est là). Gradle tente de l'installer et échoue : écriture refusée sous `Program Files (x86)` | ✅ **contourné** — forcer `buildToolsVersion = "36.0.0"` sur tous les sous-projets dans `android/build.gradle` fait passer le build de 28 à 144 tâches |
| 2 | Installation par `sdkmanager` en ligne de commande | 🚫 **échoue en silence** : n'affiche que `Failed to read or create install properties file`, ne renvoie aucun code d'erreur, et n'écrit rien. Piège à connaître |
| 3 | Le link C++ d'`expo-modules-core` ne résout ni `operator new`, ni `operator delete`, ni `std::__ndk1::…`. **Cause réelle : le SDK est installé sous `C:\Program Files (x86)\…`.** Le NDK ne supporte pas les espaces ni les parenthèses dans son chemin : Windows le réduit en notation 8.3, `clang++.exe` devient `CLANG_~1.EXE`, et **clang choisit son mode C ou C++ d'après son propre nom d'exécutable**. Privé de ses `++`, il compile en C et ne lie pas la bibliothèque standard C++ | 🚫 **non résolu** — c'est le point d'arrêt |

> ⚠️ Deux diagnostics **faux** ont été écrits ici avant celui-ci : « NDK trop ancien » et « NDK
> incomplet ». Les deux sont démentis — le NDK `27.1.12297006` (r27b, 2,3 Go) est complet, et
> `libc++_shared.so` est présent pour **les quatre** architectures cibles, x86_64 comprise. Le NDK
> n'est pas en cause : **son chemin l'est**.

**La correction, pour la reprise.** Le SDK utilisateur `C:\Users\<user>\AppData\Local\Android\Sdk`
ne contient **ni espace ni parenthèse** et il est **inscriptible sans élévation** — il lève donc
les points 1, 2 et 3 d'un coup :

1. Par l'assistant d'Android Studio (`SDK Manager`), installer dans **ce** SDK : `SDK Platform 36`,
   `Build-Tools 36`, `NDK 27.1.12297006`, et une image système x86_64.
2. Pointer `ANDROID_HOME` dessus, puis rouvrir le terminal.
3. `npx expo prebuild --platform android --clean` puis `npx expo run:android`.

Le contournement `buildToolsVersion` d'`android/build.gradle` deviendra alors **inutile** : à ne
pas pérenniser en config plugin tant que ce chemin n'a pas été essayé.

</details>

> ⚠️ **À retenir pour toute nouvelle machine :** installer le SDK Android sur un chemin **sans
> espace ni parenthèse**. Le NDK ne le supporte pas, et le symptôme — des symboles C++ manquants au
> link — ne désigne jamais le chemin. Ne pas réutiliser un SDK hérité des workloads .NET de Visual
> Studio.

> Le contournement du point 1 vit dans `android/`, **régénéré par `expo prebuild`** : il disparaîtra
> au prochain prebuild. S'il faut le garder, il devra devenir un config plugin Expo versionné — et
> ce serait alors inscrire une particularité d'un poste dans le dépôt, à peser.

**Piste pour la reprise :** installer un NDK conforme à RN `0.86.2` via l'assistant d'Android Studio
(qui gère l'élévation), dans le SDK utilisateur qui, lui, est inscriptible. **Ne pas re-tenter
`sdkmanager` en ligne de commande** — voir le point 2.

L'ancien plan ([`T0 — Spike carte & socle données`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md))
reste au dépôt pour l'historique, mais **ne doit plus être exécuté** : sa voie A est un spike
`BlazorWebView` sans objet, et sa voie B est en C#.

Ce qui a changé dans la logique du plan : **le spike carte a perdu son caractère bloquant.** Il
existait pour lever un doute sur le WebView ; MapLibre Native le rend sans objet. La séquence est
redevenue linéaire — socle, domaine, carte — au lieu de trois voies dont une conditionnait tout.

🚨 **Et c'est exactement ce qui s'est produit.** `M4` était la seule tâche dont l'échec remettrait
en cause une décision d'architecture. **Exécutée le 2026-08-15, elle a échoué** — non pas parce que
le raster hors-ligne ne marche pas, mais parce que `createPack` fait mourir le processus avant de
pouvoir le dire. Ne pas l'avoir repoussée en fin de tranche est ce qui a permis de le découvrir
avant que des écrans en dépendent. Arbitrage :
[`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md).

⚠️ **Ce qui reste vrai malgré la bascule :** la mesure sur un **Android d'entrée de gamme réel**
garde son intérêt. Le rendu natif est attendu bien meilleur, mais « attendu » n'est pas « mesuré ».

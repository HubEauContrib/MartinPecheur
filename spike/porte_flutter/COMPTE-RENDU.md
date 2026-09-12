# Porte de spike Flutter — compte rendu

- **Date d'exécution :** 2026-09-09
- **Verdict :** `F1` ✅ Windows · `F2` ⏸ **non tranchée — remesure différée (arbitrage 2026-09-12)** · `F3` ✅
- **Branche :** `feat/bascule-flutter-trois-cibles`, créée depuis `dev` (`81f380e`)
- **Projet jetable :** `spike/porte_flutter/` — rien n'est écrit dans `lib/` à la racine
- **Plan suivi :** [`2026-08-24-porte-spike-flutter.md`](../../docs/superpowers/plans/2026-08-24-porte-spike-flutter.md), à partir de la Task 3
- **Design :** [`2026-08-24-bascule-flutter-trois-cibles-design.md`](../../docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md), section 7
- **Mise à jour :** 2026-09-12 — Android ignoré jusqu'à nouvel ordre, `F2b`/`F2c` codées (`207edec`) non mesurées.

> ⚠️ Ce document distingue ce qui est **constaté** (à l'écran, dans une sortie de commande) de ce qui
> est **déduit**. Une case ⏳ est une case vide, pas un « probablement ».

---

## 1. Versions réellement liées

Relevées par `flutter pub deps --style=compact` le 2026-09-09, après `flutter pub add`. On vérifie
ce qui est lié, on ne le suppose pas — c'est la leçon de l'option E d'`ADR-012`.

| Composant | Version liée | Licence | Note |
|---|---|---|---|
| Flutter | **3.47.1** stable (revision `6655482ec0`, 2026-08-19) | BSD-3-Clause | `C:\Users\oliver254\develop\flutter`, hors PATH |
| Dart | **3.13.1** | BSD-3-Clause | |
| `flutter_map` | **8.3.2** | BSD-3-Clause | dernière publiée (pub.dev, 2026-09-09) |
| `flutter_map_marker_cluster` | **8.2.2** | BSD-3-Clause | contrainte `flutter_map: ^8.2.2`, compatible 8.3.x. Dernière publication il y a 11 mois |
| `latlong2` | **0.9.1** | Apache-2.0 | ⚠️ pub.dev propose `0.10.1`, mais la résolution tombe sur `0.9.1` par contrainte transitive. Conforme au « 0.9.x » attendu par le plan |

🚨 `flutter_map` **n'a pas été tiré vers le bas** par le clustering : la 8.3.2 est liée. Le raisonnement
de la spec, écrit pour la 8.x, tient.

### Les signatures ont été lues, pas devinées

Le plan T0 précédent s'était trompé neuf fois en décrivant une API de mémoire. Ici, chaque signature
a été relevée **avant** d'écrire, sur `pub.dev/documentation` puis dans le paquet installé
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\…`), le 2026-09-09 :

| Hypothèse du plan | Constat | Écart |
|---|---|---|
| `TileLayer(urlTemplate:, tileDimension:, maxNativeZoom:, userAgentPackageName:)` | Tous présents en 8.3.2. `tileSize` existe encore mais est `@Deprecated` | aucun |
| `Marker(point:, width:, height:, child:)` | Exact — `child`, plus de `builder` | aucun |
| `MapOptions(initialCenter:, initialZoom:, minZoom:, maxZoom:)` | Exact. Aucun paramètre requis | aucun |
| `MarkerClusterLayerWidget(options: MarkerClusterLayerOptions(maxClusterRadius:, size:, markers:, builder:))` | Exact — `typedef ClusterWidgetBuilder = Widget Function(BuildContext, List<Marker>)`, constructeur non `const`, `maxZoom` par défaut `17.0` | aucun |
| `SchedulerBinding.instance.addTimingsCallback` / `removeTimingsCallback`, `FrameTiming.buildDuration` / `rasterDuration` | Exact, lu dans `packages/flutter/lib/src/scheduler/binding.dart` du SDK | aucun |
| *(rien sur l'attribution)* | `TileLayer` n'a aucun paramètre d'attribution ; `SimpleAttributionWidget` et `RichAttributionWidget` existent. Le spike pose un simple `Text`, ce qui suffit à la Licence Ouverte | point manquant du plan, pas une contradiction |
| *(rien sur le cache)* | Cache de tuiles intégré **depuis 8.2**, actif par défaut hors web (`BuiltInMapCachingProvider`, 1 Go). C'est le comportement que `UC-001 A3` devra décrire | information nouvelle |

---

## 2. Les trois épreuves

| Épreuve | Cible | Résultat | Preuve |
|---|---|---|---|
| `F1` fond IGN | **Windows** — `flutter run -d windows` | ✅ **Le plan IGN de Bordeaux s'affiche.** Souris : le glisser déplace la carte ; **la molette ne zoome pas** (voir § 4) | constat du commanditaire à l'écran, 2026-09-09 |
| `F1` fond IGN | **Android** — émulateur `Pixel_7`, `x86_64`, Android 16 (API 36) | ✅ **Le plan IGN s'affiche.** ⚠️ Pas sur appareil réel : le Galaxy A54 n'a pas été vu par `adb` (§ 4) | constat du commanditaire, 2026-09-09 |
| `F2` 4 150 marqueurs clusterisés | émulateur `Pixel_7`, commande donnée en `--profile` (⏳ mode à confirmer) | ⚠️ **rouge sur la règle fixée d'avance** — `trames 213` · `raster p50 1,9 ms` · **`p90 16,2 ms`** · `p99 143,1 ms` · `build p90 1,5 ms` · **`jank 19 soit 8,9 %`**. Le p90 tient le budget (≤ 16,7 ms), le jank dépasse le seuil (< 5 %) | relevé de l'encart par le commanditaire, 2026-09-09 |
| `F3` exécutable Windows | `flutter build windows --release`, puis `porte_flutter.exe` lancé **seul** | ✅ **`√ Built`, la fenêtre s'ouvre hors de Flutter et affiche la carte** (écran `F2` ouvert). Dossier `Release` : **33 Mo, 14 fichiers**, dont `flutter_windows.dll` 20,3 Mo | constat du commanditaire · taille mesurée par `du` |

**Lecture de `F2`, fixée d'avance** (plan, Task 9 step 7) : vert si `raster p90` ≤ 16,7 ms **et**
`jank` < 5 % ; rouge sinon. Le plan prévoit alors : *« Ni arrêt ni feu vert : appliquer le repli
viewport prévu par `04-ui.md`, remesurer, et ne pas escamoter le chiffre. »*

### Ce que les chiffres de `F2` disent, et ce qu'ils ne disent pas

- **213 trames en 30 s** n'est pas 7 images par seconde : Flutter ne rend une image que quand
  quelque chose change. C'est le nombre d'images produites pendant les gestes, et un échantillon
  **petit** — 19 trames en retard suffisent à faire 8,9 %.
- **`p50` 1,9 ms et `build p90` 1,5 ms** : le coût n'est ni dans la construction des widgets ni
  dans la rastérisation ordinaire. Il est concentré sur quelques trames.
- **`p99` 143 ms** : une poignée d'images très longues. Déduction, non vérifiée : le **recalcul des
  clusters** à chaque changement de zoom, ou l'animation de dégroupage — c'est exactement ce que
  la spec redoutait de `flutter_map_marker_cluster`, dont la doc dit qu'il privilégie l'animation
  sur la vitesse.
- **Émulateur `x86_64`, GPU hôte** : une borne haute. Un téléphone `arm64` avec GPU réel est
  attendu meilleur, mais « attendu » n'est pas « mesuré » (`NV-5`).

### Remesure — deux variantes, mêmes gestes, même encart

| Variante | Ce qu'elle change | Ce qu'elle teste | Résultat |
|---|---|---|---|
| `F2` | référence — `flutter_map_marker_cluster` par défaut | | jank 8,9 % (ci-dessus) |
| `F2b` | même clustering, **animations désactivées**, pas de spiderfy, pas de polygone | l'animation est-elle le coût ? | ⏸ différée (arbitrage 2026-09-12) |
| `F2c` | **pas de clustering** — `MarkerLayer` limité au **viewport plus une marge**, marqueurs dessinés en pastille légère | le repli que `04-ui.md` prévoit | ⏸ différée (arbitrage 2026-09-12) |

Le code des deux variantes est au commit `207edec`, prêt pour une remesure le jour où Android revient.

---

## 3. Ce qui a été livré

Tout est sur `feat/bascule-flutter-trois-cibles`, un commit par tâche, `flutter analyze` sans
remarque et `flutter test` vert à chaque étape (**18 tests** au commit `d361146`, **26 tests**
constatés le 2026-09-12 après `207edec`). Chaque tâche a
été implémentée par un sous-agent puis relue par un second : cinq revues, cinq ✅.

| Tâche | Commit | Contenu |
|---|---|---|
| 3 | `eb581a0` | `flutter create --platforms=android,windows --org fr.martinpecheur`, trois paquets, `.gitignore` |
| 4 | `6a5c0e3` | `ign_tile_template.dart` — gabarit WMTS KVP, ordre `TILECOL`/`TILEROW` verrouillé par test (5) |
| 5 | `f2cdcad` | `f1_fond_ign.dart`, menu, test de fumée, permission `INTERNET` dans le manifeste principal |
| 7 | `07fe250` | `stations_asset.dart` — lecture du GeoJSON, ordre lon/lat verrouillé (4 tests). Asset copié (6 604 249 octets), non versionné |
| 8 | `47a6505` | `frame_stats.dart` — percentiles et jank, Dart pur (7 tests) |
| 9 | `d361146` | `frame_recorder.dart` (`addTimingsCallback`), `f2_marqueurs.dart` — clustering + encart de mesure à l'écran |
| — | `a3276d0` | épingle du NDK 27.1 (voir § 4) |
| 9 bis | `207edec` | variantes `F2b` et `F2c` pour la remesure — ⏸ jamais mesurées |

Ce qui n'a **pas** été fait, à dessein : aucune ligne dans `lib/` à la racine, aucun `ADR-013`,
aucune modification de `docs/` hors ce compte rendu. La règle d'arrêt du design l'interdit avant
le verdict.

---

## 4. Le poste, tel qu'il s'est révélé

Cinq écarts avec le brief du 2026-09-09, tous constatés par exécution.

| # | Constat | Conséquence |
|---|---|---|
| 1 | **`flutter doctor` affiche `X Android license status unknown` à tort.** Le fichier `licenses/android-sdk-license` existe avec le hachage standard. Flutter 3.47.1 lit la sortie de `sdkmanager --licenses`, or `sdkmanager` est déprécié dans les `cmdline-tools` **23.0** et n'imprime plus rien d'exploitable. Issue [flutter/flutter#191487](https://github.com/flutter/flutter/issues/191487), corrigée après la 3.47.1 | Arbitrage du commanditaire : avancer. **Tranché par l'exécution** : l'APK profile (66 Mo) a été produit |
| 2 | **Le NDK `28.2.13676358` exigé par Flutter 3.47.1 est absent** ; seul le `27.1.12297006` est là. Gradle tente de l'installer via `sdkmanager.bat`, qui plante (`0xC0000409`) | `ndkVersion` épinglé à `27.1.12297006` dans le spike (`a3276d0`). Aucun code natif dans le spike. **Dette pour la phase 2** : installer le NDK 28.2 ou reconduire l'épingle. ⏸ différé (arbitrage 2026-09-12) |
| 3 | **`adb` ne voit pas le Galaxy A54** (ni `flutter devices`, ni `adb devices -l`, câble branché, mode USB et autorisation vérifiés côté téléphone sans effet) | `F1` Android constaté sur émulateur, pas sur matériel. La preuve « appareil réel » reste à faire — l'APK profile est prêt pour une installation manuelle. ⏸ différé (arbitrage 2026-09-12) |
| 4 | **Aucun AVD sur le poste**, et les dossiers `system-images` du SDK utilisateur étaient **vides** (0 octet). L'ancien SDK Visual Studio conservait une image `android-36` `x86_64` complète (2,3 Go) | Image recopiée dans le SDK utilisateur, AVD `Pixel_7` recréé par `avdmanager` (Android 16, Google Play). Aucun téléchargement |
| 5 | **Sur Windows, la molette ne zoome pas** ; le glisser fonctionne | Constat brut, non diagnostiqué. `flutter_map` active `scrollWheelZoom` par défaut dans `InteractionOptions.flags` : à instruire dans le **lot clavier/souris** qu'`ADR-009` avait chiffré et qu'`ADR-013` doit reprendre. Ce n'est pas un critère de `F1`, qui ne demandait que « manipulable à la souris ou pas du tout » |

Le poste est par ailleurs conforme : Flutter 3.47.1 hors PATH, Visual Studio 2026 avec le workload
C++ (vert), Windows vert.

---

## 5. Ce qui reste non vérifié

- **Android, en entier** — ignoré jusqu'à nouvel ordre (arbitrage 2026-09-12). `NV-5` (tenue sur
  Android **réel**, a fortiori d'entrée de gamme — toutes les mesures sont sur émulateur `x86_64`),
  le mode de la mesure `F2` (la commande donnée était `--profile`, le commanditaire n'a pas
  confirmé que Flutter l'a acceptée sur l'émulateur ; en debug, les chiffres seraient gonflés), le
  NDK 27.1 (suffit-il **au-delà du spike**, une fois des plugins natifs ajoutés comme SQLite) et le
  Galaxy A54 (non vu par `adb`, § 4) restent ouverts sans date.
- **iOS** — aucune cible construite, faute d'hôte macOS. Elle n'est pas déclarée dans le projet
  jetable, pour ne pas afficher un support non éprouvé.
- Le comportement du **cache de tuiles** de `flutter_map` hors réseau : constaté dans la doc,
  jamais exécuté.
- La cause de l'absence de zoom à la molette sur Windows.

---

## 6. Recommandation

Verdict proposé favorable sur `F1` (Windows) et `F3` ; `F2` reste non tranchée, faute de remesure.
`F2c` (viewport plus marge, sans clustering) est retenue comme approche par défaut de la carte de
production tant qu'aucune mesure ne réhabilite le clustering. La porte est franchie **sur Windows
seul** ; l'épreuve Android reste due.

✅ Arbitrage rendu le 2026-09-12 : verdict favorable sur `F1` + `F3`, `F2c` par défaut. Phase 1 (arbre git frais) engagée.

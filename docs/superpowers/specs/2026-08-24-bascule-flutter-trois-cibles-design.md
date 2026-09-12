# Bascule Flutter — Android, iOS et Windows

- **Date :** 2026-08-24
- **Statut :** Design validé avec le commanditaire. **Conditionné à une porte de spike** — voir « La porte ».
- **Origine :** demande du commanditaire — *« changer de technologie pour qu'ils soient utilisables sur android windows et ios »*, puis *« on ne fait pas hors ligne pour l'instant »*, puis *« enlever pour l'instant le cours de la rivière »*
- **Prépare :** `ADR-013` (Flutter et retour de la cible Windows)
- **Clôt :** [`ADR-012`](../../adr/ADR-012-hors-ligne-cartographique-bloque.md) sur son **option C**

> 🚨 **Troisième jet de code applicatif.** `ADR-010` a jeté `A1`/`B1`/`B3a` en .NET le 2026-07-31.
> Ce design jette `S1`–`N5` et `M1`–`M3` en TypeScript. C'est le coût réel, il est écrit ici pour
> qu'il ne soit pas découvert après coup.

---

## 1. Ce qui est demandé, et ce qui l'a motivé

Quatre arbitrages du commanditaire, le 2026-08-24 :

| # | Décision | Conséquence |
|---|---|---|
| 1 | **Windows redevient une cible produit**, aux côtés d'Android et iOS | Des usagers consulteront l'état de la rivière depuis un PC. Ce n'est pas un confort de développement : le lot responsive et clavier/souris qu'`ADR-009` avait chiffré revient au périmètre |
| 2 | **Le hors-ligne cartographique sort de la v1** | C'est l'**option C** d'[`ADR-012`](../../adr/ADR-012-hors-ligne-cartographique-bloque.md), resté ouvert depuis l'épuisement de l'option E |
| 3 | **Les tracés de cours d'eau sortent de la v1** | Envisagés puis retirés le jour même. La carte reste à deux couches — fond et marqueurs. Faits vérifiés conservés en section 6 |
| 4 | Le critère de choix est **la qualité technique**, pas la préservation du socle TypeScript | Une réécriture est acceptée si elle est justifiée |

⚠️ **La justification de la bascule est Windows, et Windows seul.** Le hors-ligne étant retiré, on ne
change plus de stack pour sortir de l'impasse `createPack`. `ADR-013` doit le dire ainsi et pas
autrement : écrire « on quitte React Native à cause d'`ADR-012` » serait faux à la date où on l'écrit.

---

## 2. Le fait structurant

> **Aucune stack ne fournit une carte *native* sur Windows, sauf une.**

MapLibre Native n'a de liaison ni React Native ni Flutter pour Windows. Le seul moteur
cartographique multi-plateforme couvrant Android, iOS **et** Windows sans passer par une WebView est
**`flutter_map`**, en Dart pur.

C'est ce fait, et lui seul, qui sélectionne Flutter. Les approches « tout web » (Tauri 2,
Capacitor + Electron) et le retour à MAUI Blazor Hybrid achètent le multi-plateforme au prix d'une
carte en WebView — le prix qu'`ADR-005` avait chiffré et qu'`ADR-010` s'était félicité de supprimer.

### Faits vérifiés le 2026-08-24, par appel HTTP

> ⚠️ **Niveau de preuve : documentation et métadonnées lues. Rien n'a été exécuté.** C'est
> exactement le niveau sur lequel `ADR-010` a affirmé « le hors-ligne cartographique cesse d'être un
> risque », et `M4` l'a démenti trois mois plus tard. D'où la porte de la section 7.

| Fait | Constat |
|---|---|
| Flutter — Android, iOS, Windows | Les trois en tier **`Supported`**, aucune mention `beta`. Android 24→37, iOS 15→26, Windows 10 et 11, `x64` **et** `Arm64` |
| `flutter_map` **8.3.1** (publiée il y a ~54 j) | Plateformes verbatim : *« Android, iOS, Linux, macOS, web, Windows »*. **BSD-3-Clause**, 2,17 k likes, 662 k téléchargements. 100 % Dart |
| `maplibre_gl` **0.27.0** (il y a 4 j) | *« Not supported: desktop targets (Windows, macOS, Linux) »* — **Windows exclu** |
| `maplibre` (maplibre.dart) **0.3.5** | Windows listé, mais : *« Windows & macOS: maplibre-gl-js through a WebView »*. Ce n'est pas du natif |
| `react-native-windows` | Version courante **0.84** ; le projet est en `react-native` **0.86.2**. L'écosystème est en retard, et `maplibre-react-native` ne couvre pas Windows de toute façon |
| `drift` **2.34.3** (il y a 27 j) | **MIT**, plateformes Android, iOS, Linux, macOS, web **et Windows**, 1,12 M téléchargements |
| `sqflite` **2.4.3** | Plateformes « Android, iOS, macOS ». **Windows absent** — renvoyé vers `sqflite_common_ffi` |
| `flutter_map_marker_cluster` **8.2.2** | Contrainte `flutter_map: ^8.2.2` — **compatible 8.x**. BSD-3, 224 likes, 85,4 k téléchargements |
| `flutter_map_supercluster` **4.3.0** | 🚨 Contrainte `flutter_map: ^5.0.0`, **publié il y a 3 ans — inutilisable en 8.x** |

### Le poste de développement, sondé le 2026-08-24

| Outil | État |
|---|---|
| **Flutter / Dart** | 🚨 **Absents** — `where.exe flutter` et `where.exe dart` ne renvoient rien. Le SDK est à installer |
| **Visual Studio Professional 2026** | Installé, mais 🚨 **sans la charge « Desktop development with C++ »** (`vswhere -requires Microsoft.VisualStudio.Workload.NativeDesktop` → aucune installation). **`F3` est bloqué tant qu'elle n'est pas ajoutée** |
| JDK 17, `ANDROID_HOME`, AVD `Pixel_7` | ✅ En place |

---

## 3. Périmètre — ce qui survit, ce qui est jeté

### Survit intact

| Quoi | Pourquoi |
|---|---|
| **Tout `docs/`** — cadrage `01`→`04`, 14 `BR`, 6 `UC`, 17 contraintes `C-xx`, `ADR-001/002/003/004/006/007` | Indépendant de la stack. A déjà survécu à deux bascules |
| **`tools/percentiles/` en TypeScript**, 5 suites de tests | Générateur d'asset **au build**, sous Node. Il produit un JSON que l'app lit ; rien ne justifie de le réécrire en Dart. Il déménage dans `tools/package.json` |
| **`assets/referentiel/stations.json`** — 4 150 stations, 6,6 Mo, figé en `S4` | Données, pas du code |
| Les faits vérifiés sur Hub'Eau et VigiEau | Vérifiés par appel réel, datés |

### Jeté

`lib/` remplace `src/`. Partent : `src/domain/`, `src/data/`, `src/application/` (10 suites),
`src/features/map/` en entier (4 suites), `plugins/withReleaseSigning.js` et
`plugins/withMapLibreNativeVersion.js` — les *config plugins* Expo n'ont pas d'équivalent Flutter,
la signature de release se refait en `key.properties` + `build.gradle`, c'est un transposé direct —
ainsi que `app.json`, `tsconfig.json`, `jest.config.js` et `eslint.config.js` à la racine.

⚠️ **Changement de régime sur le natif.** `.gitignore` exclut aujourd'hui `/android` et `/ios`
parce qu'`expo prebuild` les régénère. **Flutter, non** : `android/`, `ios/` et `windows/` sont
versionnés et se modifient à la main. Trois dossiers de plus au dépôt, et la signature de release y
vit désormais pour de bon.

---

## 4. Le hors-ligne — ce qui est retiré, et où on s'arrête

Les documents emploient « hors ligne » pour **deux choses différentes**. Les confondre supprimerait
des règles de sûreté.

| | Sort de la v1 | Reste |
|---|---|---|
| **Hors-ligne cartographique** — pré-télécharger les tuiles d'une emprise. `UC-005`, `US-10`, `US-20`, `UC-003` étape 6 | ✅ retiré | |
| **Dégradation réseau** — afficher la dernière réponse Hub'Eau/VigiEau en cache, **avec sa date et un bandeau**. `BR-005`, `BR-013`, `UC-002 A5`, `02-specifications.md:130` | | ✅ **gardé** |

`BR-005` énonce : *« l'absence de réseau n'excuse pas l'absence de signalement »*. `BR-013` :
*« Reste affiché en mode hors ligne, où il est plus nécessaire encore »*. Ces règles portent sur le
fait de ne jamais présenter une donnée périmée comme fraîche — le décorateur `CachePolicy` (`N5`)
les porte déjà, et il est transposé en Dart.

L'asset percentiles d'`ADR-003` (« fonctionne hors ligne par construction ») est un fichier
embarqué, pas du réseau : **inchangé**.

### Ce que le retrait libère, et ce qu'il coûte

- ➕ Le conflit de licence disparaît : `flutter_map_tile_caching` est en **GPL-3.0** (version
  `10.1.1`, publiée il y a **17 mois**) et le dépôt est en **MIT**. Le sujet n'existe plus.
- ➕ Le préalable non technique disparaît : plus besoin de vérifier si les conditions d'usage de la
  Géoplateforme autorisent d'aspirer un département. **L'obligation d'attribution
  « © IGN Géoplateforme — Licence Ouverte » reste, elle.**
- ➕ `offline_tiles` (`0.5.6`, BSD-3, **1 like, 265 téléchargements**) n'a pas à être évalué. On ne
  misait de toute façon pas un `Must` sur ce niveau d'adoption.
- ➖ **`UC-005` était un `Must`.** C'est une réduction de promesse produit, pas un allègement
  technique — `ADR-012` le qualifie lui-même ainsi.

### Une question produit apparaît en retirant le hors-ligne

`UC-001 A3` renvoyait à `UC-005` pour le cas « pas de réseau ». Sans `UC-005`, le renvoi est mort.
Réponse gratuite : **`flutter_map` cache les tuiles déjà parcourues depuis la 8.2.0** — la doc
distingue explicitement *caching* (« store tiles **as the user loads them** ») de *bulk downloading*
(« download an entire area/region **in one shot** »). Le fond reste donc visible là où l'usager est
déjà passé, vide ailleurs. **Ce n'est pas une fonctionnalité, c'est le comportement par défaut** :
il coûte zéro et il faut simplement le décrire dans `UC-001 A3`.

---

## 5. Architecture

### Disposition du dépôt

```
pubspec.yaml                      ← racine = projet Flutter
lib/
  domain/                         ← Dart pur : aucun import de package:flutter
  data/                           ← Hub'Eau, VigiEau, stockage local
  application/                    ← Query/Command + CachePolicy
  features/map/                   ← carte, clustering
  main.dart
test/
  architecture/                   ← le verrou de frontière, transposé
android/  ios/  windows/          ← versionnés
assets/
  referentiel/stations.json       ← inchangé, 4 150 stations
  percentiles/                    ← produit par tools/
tools/                            ← reste en TypeScript / Node
  package.json  tsconfig.json  jest.config.js  eslint.config.js
  percentiles/                    ← inchangé, 5 suites de tests
docs/                             ← inchangé
```

### Les invariants transposés — deux d'entre eux se renforcent

| Invariant | Aujourd'hui (TypeScript) | En Dart |
|---|---|---|
| **`BR-002` — unités typées** | `type M3S = number & {__brand}` : *branded type* **effacé à l'exécution**, et un `as` suffit à le contourner | **`extension type M3S(double value)`** — type distinct **au compilateur**, coût nul à l'exécution, non contournable par une conversion implicite. **Strictement plus fort** |
| **`BR-011` — nomenclature close + `Inconnu`** | union + `switch` gardé par `never` : oublier la garde passe inaperçu | **`sealed class`** + `switch` exhaustif : oublier une branche est une **erreur de compilation**, plus un test à écrire |
| **`domain/` ne dépend de rien** | test d'architecture (lecture des imports) + `no-restricted-imports` ESLint | Même double verrou. ⚠️ **Le piège change de forme** : la tentation n'est plus React mais `package:flutter/material.dart` pour un `Color`, ou `package:latlong2` pour un point. Le test doit interdire les deux dans `lib/domain/` |
| **CQRS léger** | `Query`/`Command` + registre + `CachePolicy` — prévus en T1, jamais codés | `sealed class Query<T>`, registre `Map<Type, Handler>`, `CachePolicy` en décorateur. **Toujours aucune bibliothèque de médiateur** |
| **Conversion une seule fois** | mapper `hydroObservationMapper` | Idem, un seul point |

C'est le seul endroit où la bascule *rend* quelque chose : `ADR-010` listait la faiblesse de
TypeScript sur ces deux invariants comme un ➖ explicite, avec la mention « ce n'est pas
automatique — c'est une discipline à tenir ». En Dart, elle redevient automatique.

### La carte — deux couches, toutes en rendu Dart natif

| Couche | Contenu | Source |
|---|---|---|
| **Fond** | `TileLayer` sur le WMTS IGN `PLANIGNV2`, gabarit KVP `TILEMATRIX`/`TILECOL`/`TILEROW` déjà éprouvé en `M2` | `data.geopf.fr/wmts`, en ligne |
| **Marqueurs** | `flutter_map_marker_cluster` — voir l'avertissement ci-dessous | `referentiel/stations.json`, 4 150 stations |

C'est le périmètre exact de `M2` + `M3`, transposé. Les cours d'eau restent **dessinés dans le fond
raster** — `04-ui.md:259` (« linéaire hydrographique visible ») est satisfait sans couche vectorielle.

🚨 **Le clustering est le maillon faible, et il l'est plus qu'annoncé initialement.** Vérifié le
2026-08-24 : `flutter_map_supercluster` — le portage de l'algorithme Supercluster utilisé en `M3`
aujourd'hui — est en **`4.3.0`, publié il y a trois ans**, avec la contrainte `flutter_map: ^5.0.0`.
**Il ne fonctionne pas avec la 8.x.** Le seul clustering maintenu pour la 8.x est
`flutter_map_marker_cluster` **`8.2.2`** (il y a 11 mois, BSD-3, 224 likes, 85,4 k téléchargements,
contrainte `flutter_map: ^8.2.2`) — mais c'est le portage de *Leaflet.markercluster*, dont la
documentation de `flutter_map` dit qu'il privilégie l'animation sur la vitesse. **C'est exactement
la question de `F2`, et elle est ouverte.** Repli si `F2` échoue : n'afficher que les marqueurs du
viewport, ce qu'`04-ui.md` prévoit déjà (« chargement limité au viewport plus une marge »).

### Tests

`flutter test` remplace Jest pour `lib/`. Le décompte, sur les **21 suites / 172 tests** verts au
2026-08-24 :

| Suites | Sort |
|---|---|
| **14** — `src/domain/`, `src/data/`, `src/application/`, architecture (10) + `src/features/map/` (4) | **Réécrites en Dart.** La logique est déjà spécifiée par les 14 `BR` et leurs cas limites : c'est de la transcription, pas de la conception |
| **2** — `tests/plugins/` | **Disparaissent** avec les *config plugins* Expo |
| **5** — `tests/tools/percentiles/` | **Restent sous Jest**, inchangées |

**Le test d'architecture est le premier à réécrire**, avant toute ligne de `domain/` — c'est lui qui
rend l'invariant tenable.

---

## 6. Les tracés de cours d'eau — envisagés, puis reportés

**Arbitrage du commanditaire du 2026-08-24 : hors périmètre pour l'instant.** La fonctionnalité —
surligner la rivière consultée comme géométrie plutôt que comme pixels du fond — a été cadrée puis
retirée le jour même. Elle n'entre ni au spike, ni au plan T0, et **`ADR-014` n'est pas écrit**.

Les faits ci-dessous sont **vérifiés par appel réel le 2026-08-24**. Ils sont conservés ici pour
qu'une reprise n'ait pas à les revérifier — pas parce que la fonctionnalité est prévue.

| Vérification | Résultat |
|---|---|
| `data.geopf.fr/wfs` `GetCapabilities` | **HTTP 200**, 5 179 532 octets. `BDTOPO_V3:cours_d_eau` et `BDTOPO_V3:troncon_hydrographique` présents |
| Une entité `BDTOPO_V3:cours_d_eau` en GeoJSON | **HTTP 200**. `MultiLineString`, 120 points. Attributs : `toponyme`, `code_hydrographique`, **`importance` (1→5)** |
| Volumétrie France entière par `importance` | `≤1` : **32** · `≤2` : **387** · `≤3` : **654** · `≤4` : **4 536** · total : **152 621** |
| BD TOPAGE côté SANDRE | `services.sandre.eaufrance.fr/geo/topage` **HTTP 200**, `sa:CoursEau` et ses variantes par territoire. ⚠️ **GML seulement** : `application/json` refusé — *« is not a permitted output format »* |

**Le point dur, s'il faut y revenir : la jointure n'existe pas.**

| Source | Code porté (constaté) |
|---|---|
| Station Hub'Eau, dans `stations.json` | `code_cours_eau = "10--0020"` ; `uri_cours_eau` redirige **HTTP 302** vers `id.eaufrance.fr/CoursEau_`**`Carthage2017`**`/10--0020` |
| IGN BD TOPO | `code_hydrographique = "03C0000002000801315"` |
| SANDRE BD TOPAGE | `CdOH = "07C0000002215822156"` |

Hub'Eau parle **Carthage 2017**, la géométrie parle **TOPAGE** : aucune clé commune n'a été
trouvée. Un rattachement se ferait par proximité géométrique au build, donc par heuristique — et
`BR-007` imposerait de n'afficher **aucun** tracé plutôt qu'un tracé faux.

⚠️ **En attendant, `04-ui.md:259` reste satisfait** : le fond raster `PLANIGNV2` dessine déjà le
linéaire hydrographique dans l'image.
## 7. La porte — rien ne se réécrit avant

C'est le point non négociable de ce design. `ADR-010` a engagé une stack entière sur une lecture de
documentation, et `M4` l'a démentie trois mois plus tard. La section 2 est **la même lecture de
documentation**. Elle ne vaut pas plus.

Spike **jetable**, sur une branche, **hors du code de production** :

| # | À constater | Répond à |
|---|---|---|
| `F1` | Le **fond IGN WMTS raster** s'affiche sur **Windows** *et* sur **Android réel** | `M2` rejoué sur la nouvelle stack, plus la cible nouvelle |
| `F2` | **4 150 marqueurs** clusterisés tenus à l'écran, `jank` **mesuré** sur Android | `M3` + `M5`, et `NV-5` |
| `F3` | `flutter build windows` produit un exécutable qui **démarre** | La cible nouvelle |

**Règle d'arrêt : si `F1` échoue, aucune ligne de `lib/domain/` n'est réécrite.** On revient à
l'arbitrage avec un fait de plus, pas avec une base à moitié portée.

⚠️ **`F2` est le point le plus risqué du spike**, `M4` ayant disparu. Et c'est le seul dont ce
projet n'a **jamais** obtenu de mesure : la tentative du 2026-08-18 a rendu un histogramme vide
(`Total frames rendered: 0`).

---

## 8. Décisions rouvertes par la bascule

`ADR-011` était réservé à la bibliothèque SQLite. La réservation tient, l'objet change.

| Sujet | État | Note |
|---|---|---|
| **Stockage local** | 🔄 à trancher (`ADR-011`) | Ce n'est plus `expo-sqlite` contre `op-sqlite`. **`drift`** (MIT, couvre Windows) est le candidat par défaut ; **`sqflite` seul ne couvre pas Windows**. À confirmer par exécution |
| **Gestion d'état** | 💭 non tranché | Question *nouvelle* — elle n'existait pas en React. La couche CQRS fait l'orchestration, donc un écran n'a qu'à tenir un résultat : `ValueNotifier` + `ListenableBuilder`, **zéro dépendance**, suffit probablement. À trancher au premier écran, en T1 |
| **Graphes (`US-11`)** | 💭 non tranché | Reste ouvert, comme aujourd'hui |

Aucune n'est bloquante pour le spike : `F1`–`F3` ne touchent ni le stockage métier, ni l'état, ni
les graphes.

---

## 9. Documents à produire

### ADR

| ADR | Objet |
|---|---|
| **`ADR-013` — Flutter et retour de la cible Windows** | Remplace `ADR-010`. ⚠️ Doit **reprendre en propre** les conséquences qu'`ADR-009` avait chiffrées pour Windows — lot responsive, clavier/souris, géolocalisation moins fiable sur poste fixe — plutôt que renvoyer à un ADR remplacé. Et porter son niveau de preuve : documentation lue, rien d'exécuté, d'où la porte |
| **`ADR-012`** | **Clôturé sur l'option C** — statut mis à jour, jamais supprimé. C'est lui qui porte la trace des cinq plantages |
| **`ADR-011`** | Reste réservé au stockage local, objet mis à jour |

### Artefacts passés en « reporté » — jamais supprimés

`UC-005 — Consulter la carte hors-ligne` → *Reporté après la v1* · `US-10` et `US-20` dans
`02-specifications.md` · `UC-003` étape 6, retirer l'action « télécharger la zone » · `UC-001 A3`,
réécrire le renvoi mort en décrivant le cache de tuiles par défaut.

### À mettre à jour

`CLAUDE.md` (stack entière, tableau de release) · `project-state.md` · `03-conception.md`
(10 occurrences) · `04-ui.md` — **et le lot responsive y revient** : les wireframes sont écrits pour
un écran étroit et le tactile · `README.md` · `context-map.md` · `guide-release.md` (Expo → Flutter,
plus une procédure Windows) · `guide-test-appareil.md`.

Puis un nouveau plan T0 — **après** le spike, pas avant.

---

## 10. Ce qui n'est pas vérifié

| # | Point | État |
|---|---|---|
| `NV-F1` | Que `flutter_map` consomme un WMTS IGN en gabarit **KVP** | **Non vérifié.** `M2` l'a établi pour MapLibre, pas pour `flutter_map`. C'est `F1` |
| `NV-F2` | Que 4 150 marqueurs clusterisés tiennent en rendu Dart sur Android d'entrée de gamme | **Non vérifié, et jamais mesuré sur aucune stack.** C'est `F2` |
| `NV-F3` | Que `drift` tienne le volume attendu sur les trois cibles | **Non vérifié.** Hors périmètre du spike (`ADR-011`) |
| `NV-F4` | Qu'un hôte macOS soit disponible pour produire un paquet iOS | **Inchangé depuis `ADR-009`** — bloquant pour livrer iOS, pas pour développer |

---

## 11. Alternatives écartées

- **Tout web — TypeScript unique, MapLibre GL JS, empaqueté par Tauri 2 ou Capacitor + Electron.**
  Garde l'intégralité du socle TS et ses 172 tests ; seul `src/features/map/` serait réécrit. C'est
  de loin le moins cher. **Écarté** : réimporte la carte en WebView sur Android d'entrée de gamme —
  le risque qu'`ADR-005` avait chiffré et qu'`ADR-010` s'était félicité de supprimer — et trois
  moteurs de WebView à supporter. La maturité mobile de Tauri 2 n'a par ailleurs **pas pu être
  établie** par la vérification du 2026-08-24.
- **Retour à .NET MAUI Blazor Hybrid** (annuler `ADR-010`). Les trois cibles compilaient vert le
  2026-07-31 et le code est récupérable (`696be3a`, `22e9850`) ; C# est le plus fort des trois sur
  les invariants. **Écarté** : la carte y est la **même** WebView + GL JS que l'alternative
  précédente — aucun gain cartographique, pour le poids de MAUI en plus.
- **React Native + `react-native-windows`.** **Écarté** : `maplibre-react-native` ne couvre pas
  Windows, il faudrait donc une seconde implémentation de carte pour cette seule cible. Et RNW est
  en `0.84` quand le projet est en `0.86.2`.
- **Flutter + `maplibre_gl`** (MapLibre Native sous Flutter), dont l'offline manager a été
  *« rebuilt end-to-end »* en `0.26.0`. **Écarté** : *« Not supported: desktop targets (Windows,
  macOS, Linux) »*. C'eût été la piste si le hors-ligne était resté au périmètre et Windows non.
- **Toute couche vectorielle de cours d'eau** — du surlignage d'une seule rivière (654 tracés en
  asset) jusqu'au réseau complet (152 621 tracés, qui imposerait des tuiles vectorielles). **Retiré
  par arbitrage du commanditaire le 2026-08-24**, le jour même où il avait été cadré. Faits vérifiés
  conservés en section 6.

---

## 12. Si la décision est revue

- **Si Windows ressort du périmètre :** `maplibre_gl` sous Flutter redevient le meilleur choix
  cartographique, avec son offline manager reconstruit. Le socle `lib/domain/`, `lib/data/` et
  `lib/application/` ne bouge pas — seul `lib/features/map/` change.
- **Si le hors-ligne cartographique revient :** il se réécrit sur le `TileProvider` de
  `flutter_map` — point d'extension documenté, tuiles raster PNG sur gabarit `{z}/{x}/{y}`, stockage
  SQLite. C'est l'option **B** d'`ADR-012`, mais à un coût sans rapport avec ce que cet ADR
  redoutait : hors de MapLibre Native, il n'y a ni C++ ni format de base opaque. Le préalable des
  conditions d'usage IGN redevient alors bloquant.
- **Si le spike échoue en `F1` :** l'alternative « tout web » reprend la main, avec son risque
  WebView assumé et documenté.

## Liens

- Remplace : [`ADR-010`](../../adr/ADR-010-react-native.md)
- Clôt : [`ADR-012`](../../adr/ADR-012-hors-ligne-cartographique-bloque.md), option C
- Reprend les conséquences de : [`ADR-009`](../../adr/ADR-009-cible-windows.md)
- Cas d'usage reporté : [`UC-005`](../../use-cases/UC-005-consulter-la-carte-hors-ligne.md)
- Toujours en vigueur : `ADR-001`, `ADR-002`, `ADR-003`, `ADR-004`, `ADR-006`, `ADR-007`

**Sources vérifiées le 2026-08-24 :** `pub.dev` — `flutter_map`, `maplibre_gl`, `maplibre`,
`drift`, `sqflite`, `flutter_map_tile_caching`, `offline_tiles` ·
`docs.flutter.dev/reference/supported-platforms` · `docs.fleaflet.dev/tile-servers/offline-mapping` ·
`microsoft.github.io/react-native-windows` · `data.geopf.fr/wfs` (`GetCapabilities`, `GetFeature`,
`RESULTTYPE=hits`) · `services.sandre.eaufrance.fr/geo/topage` · `id.eaufrance.fr/CEA/10--0020`

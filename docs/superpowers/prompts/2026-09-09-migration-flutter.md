# Prompt — Migrer MartinPêcheur vers Flutter et repartir d'un arbre git frais

> **Usage.** Ouvrir une nouvelle session Claude Code dans `C:\Users\oliver254\dev\MartinPecheur`,
> branche `feat/bascule-flutter-trois-cibles`, et coller la ligne suivante :
>
> ```
> Lis docs/superpowers/prompts/2026-09-09-migration-flutter.md en entier et exécute-le phase par phase, dans l'ordre. Ne saute aucune porte de confirmation.
> ```
>
> Tout ce qui suit est le brief lui-même. Il est écrit le 2026-09-09, à partir de l'état réel du
> dépôt et du poste à cette date.

---

## 1. Mission

Le projet **MartinPêcheur** quitte React Native (Expo) pour **Flutter**, avec trois cibles :
**Android, iOS et Windows**. La décision est prise et validée par le commanditaire le 2026-08-24.
Le design est écrit. **Le spike de validation n'a pas commencé** : aucun dossier `spike/` n'existe.

Tu dois, dans l'ordre :

| Phase | Objet | Sortie |
|---|---|---|
| **0** | Jouer la **porte de spike** `F1`–`F3` sur un projet jetable | Un compte rendu et un verdict |
| **1** | Si le verdict est favorable, **remettre l'historique git à zéro** : une seule racine, plus aucun commit des stacks précédentes | Une branche `dev` à un commit, l'ancien historique archivé sous un tag |
| **2** | Réécrire le **socle applicatif en Dart** sur le nouvel arbre, couche par couche, en TDD | `lib/` vert : `flutter analyze` sans remarque, `flutter test` vert |
| **3** | Mettre la **documentation** au niveau du code, dans les mêmes commits | `ADR-013`, `ADR-012` clôturé, `CLAUDE.md` et `project-state.md` réécrits |

Chaque phase se termine par un point d'étape au commanditaire. **La phase 1 ne démarre jamais sans
un « oui » explicite** : elle est destructive.

## 2. Lecture obligatoire, avant toute action

Dans cet ordre, en entier :

1. `CLAUDE.md` à la racine — invariants, pièges d'API `C-xx`, conventions. ⚠️ Il décrit encore la
   stack React Native : c'est normal, tu le réécriras en phase 3.
2. `docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md` — **le design de la
   bascule**. Section 5 pour l'architecture cible, section 7 pour la porte, section 9 pour les
   documents à produire, section 10 pour ce qui n'est pas vérifié.
3. `docs/superpowers/plans/2026-08-24-porte-spike-flutter.md` — le plan du spike, tâche par tâche.
   ⚠️ **Les Tasks 1 et 2 (Lot 0) sont déjà faites** — voir section 3 ci-dessous. Commence à la Task 3.
4. `docs/adr/ADR-012-hors-ligne-cartographique-bloque.md` — pourquoi le hors-ligne sort de la v1.
5. `docs/project-state.md` — l'état vivant, source de vérité des statuts.
6. `docs/adr/ADR-010-react-native.md` et `docs/adr/ADR-009-cible-windows.md` — ce qu'`ADR-013`
   remplace, et les conséquences Windows qu'il doit reprendre en propre.
7. `docs/glossary.md` — le vocabulaire, dont les **mots bannis** pour qualifier un débit.

Puis, pour chaque couche que tu réécris, **le fichier TypeScript correspondant et son test** dans
`src/` et `tests/` (tant qu'ils existent, c'est-à-dire jusqu'à la phase 1 — après, via le tag
d'archive). Ils sont la spécification exécutable de ce que tu transposes : mêmes cas limites, mêmes
bornes, mêmes noms de concepts.

## 3. Le poste de développement, vérifié le 2026-09-09

| Élément | État |
|---|---|
| **Flutter** | **3.47.1 stable**, Dart 3.13.1, installé dans `C:\Users\oliver254\develop\flutter`. 🚨 **Pas sur le PATH** : appelle `C:\Users\oliver254\develop\flutter\bin\flutter.bat` par chemin absolu, ou préfixe le PATH dans chaque commande. `which flutter` échoue, ce n'est pas une absence |
| **Windows** | ✅ `flutter doctor` vert : Visual Studio Professional 2026 avec le workload « Desktop development with C++ », CMake, SDK Windows 10.0.26100 |
| **Android** | SDK 36 dans `%LOCALAPPDATA%\Android\Sdk`, `cmdline-tools` installés, JDK embarqué d'Android Studio (OpenJDK 25), émulateur 37.1. ⚠️ **Vérifie que les licences sont acceptées** : `flutter doctor` doit montrer *Android toolchain* en vert. Sinon, demande au commanditaire de lancer `flutter doctor --android-licenses` lui-même, c'est un accord de licence |
| **Appareils** | AVD `Pixel_7` (démarre en ~38 s) ; **Galaxy A54 5G** réel (`arm64`, Android 16) disponible pour les constats `F1`/`F2` |
| **iOS** | Aucun hôte macOS. La cible se configure et se documente, elle ne se compile pas ici |
| Chrome | Absent — la cible web est hors périmètre, ignorer l'avertissement |

### Deux contraintes d'exécution

> 🚨 **Tu ne peux pas compiler du natif depuis ton bac à sable** : les sockets `AF_UNIX` sont
> fermées, `Selector.open()` échoue et Gradle ne démarre pas. Tout `flutter run`, `flutter build`,
> `gradlew` se lance **depuis un terminal du commanditaire**, qui te rapporte le résultat. Toi, tu
> écris le code et les tests, et tu lances `flutter analyze`, `flutter test`, `dart format`, et
> `npm test` dans `tools/`. Donne chaque commande à lancer dans un bloc `bash` séparé.

> ⚠️ **Ne touche jamais à Bitdefender**, ni à aucun réglage système ou de sécurité. Lecture seule ;
> si quelque chose est bloqué, dis-le et laisse le commanditaire agir.

Autres règles de poste : chemins **sans espaces** (le link C++ casse sinon) ; `ANDROID_HOME` déjà
positionné ; `pm clear` inutile désormais, il n'y a plus de pack MapLibre.

## 4. Phase 0 — La porte de spike

Exécute `docs/superpowers/plans/2026-08-24-porte-spike-flutter.md` **à partir de la Task 3**, avec
`superpowers:subagent-driven-development` ou `superpowers:executing-plans`. Le projet jetable vit
sous `spike/porte_flutter/`, jamais dans le code de production.

| Épreuve | À constater | Qui constate |
|---|---|---|
| `F1` | Le fond IGN WMTS raster (`PLANIGNV2`, gabarit KVP) s'affiche sur **Windows** et sur **Android réel** | Le commanditaire, à l'écran |
| `F2` | 4 150 marqueurs clusterisés tenus à l'écran, fluidité **mesurée** par `SchedulerBinding.addTimingsCallback` sur Android | Le commanditaire lance, tu lis les chiffres |
| `F3` | `flutter build windows` produit un exécutable qui démarre | Le commanditaire |

**Règle d'arrêt : si `F1` échoue, tu t'arrêtes.** Aucune ligne de `lib/` n'est écrite, la phase 1
n'a pas lieu. Tu écris le compte rendu (Task 11) avec le fait constaté et tu rends la main.

⚠️ Avant d'écrire du Dart contre `flutter_map`, `latlong2` ou `flutter_map_marker_cluster`, **lis
les signatures sur `pub.dev/documentation`** et date ta lecture. Le plan précédent s'est trompé neuf
fois pour avoir décrit une API de mémoire.

Sortie de phase : `spike/porte_flutter/COMPTE-RENDU.md` avec les trois verdicts, les mesures, les
versions exactes des paquets, et une recommandation en une ligne. Point d'étape au commanditaire.

## 5. Phase 1 — L'arbre git frais

**Objectif :** l'historique de `dev` commence à un unique commit racine. Les trois jets
précédents — fichiers de 2022, .NET de juillet 2026, React Native d'août 2026 — n'apparaissent plus
dans `git log`. Ils restent récupérables sous un **tag d'archive**, hors du chemin.

### 5.1 Ce qui survit, ce qui meurt

| Survit | Pourquoi |
|---|---|
| `docs/` en entier, y compris `superpowers/` et ce prompt | Cadrage indépendant de la stack, a déjà survécu à deux bascules |
| `tools/percentiles/` + ses **5 suites** (`tests/tools/percentiles/`) | Générateur d'asset au build, sous Node. Reste en TypeScript. Déménage avec son outillage dans `tools/` |
| `tools/fetch-stations.sh` | Idem |
| `assets/referentiel/stations.json` | 4 150 stations, 6,6 Mo, données figées |
| `assets/*.png` (icônes) | Réutilisées par Flutter |
| `LICENSE.txt`, `README.md`, `CLAUDE.md`, `.gitattributes`, `.claude/commands/etat.md` | Réécrits en phase 3 pour les trois du milieu |
| `spike/porte_flutter/COMPTE-RENDU.md` | La preuve de la porte. Le reste du spike est jetable |

| Meurt | Remplacé par |
|---|---|
| `src/`, `tests/` (sauf `tests/tools/`), `plugins/` | `lib/`, `test/` |
| `package.json`, `package-lock.json`, `tsconfig.json`, `jest.config.js`, `eslint.config.js` à la racine | Les mêmes, **dans `tools/`**, réduits au périmètre percentiles |
| `app.json` | `pubspec.yaml` + `android/`, `ios/`, `windows/` |
| `.github/workflows/release-android.yml` | Réécrit en phase 2 pour Flutter |
| `.expo/`, `android/` généré, `node_modules/` | Rien |

À reporter du `app.json` défunt : le nom **MartinPêcheur**, l'identifiant **`fr.martinpecheur.app`**
(Android `applicationId` et iOS `bundleIdentifier` — ne pas en changer, il servira au Play Store),
`versionCode 1`, orientation portrait, les icônes.

### 5.2 Procédure

Commence par **montrer au commanditaire la liste exacte** des fichiers conservés et supprimés, la
liste des branches distantes qui seront effacées, et **attends un « oui » explicite**. Pas de
`--force` sans lui.

```bash
# 1. Archiver l'historique complet, à sa pointe actuelle
git tag -a archive/pre-flutter-2026-09-09 feat/bascule-flutter-trois-cibles -m "Historique avant la bascule Flutter : fichiers 2022, .NET (696be3a, 22e9850), React Native (T0)"
git push origin archive/pre-flutter-2026-09-09

# 2. Branche orpheline, index vidé, arbre de travail nettoyé
git checkout --orphan flutter-root
git rm -r --cached .
# supprimer du disque tout ce qui meurt (section 5.1), déplacer l'outillage dans tools/

# 3. Nouveau .gitignore (section 5.3), puis un seul commit racine
git add -A
git commit -m "chore: arbre frais pour la bascule Flutter — cadrage, référentiel et outillage percentiles conservés"

# 4. Remplacer dev, pousser, nettoyer
git branch -M flutter-root dev
git push --force-with-lease origin dev
git push origin --delete docs/spec-test-appareil-reel
git push origin --delete dependabot/npm_and_yarn/xmldom/xmldom-0.8.15
git branch -D feat/bascule-flutter-trois-cibles docs/spec-test-appareil-reel
```

Vérifications avant de déclarer la phase finie : `git log --oneline dev` affiche **un** commit ;
`git show archive/pre-flutter-2026-09-09 --stat` fonctionne ; `git status` propre ; la branche
par défaut sur GitHub est toujours `dev`.

⚠️ **Ce que ce tag implique, à dire au commanditaire :** les anciens objets restent dans le dépôt
tant que le tag existe, donc `.git` ne maigrit pas. Un effacement définitif demanderait de
supprimer le tag, puis `git reflog expire --expire=now --all && git gc --prune=now` en local, et
GitHub garderait des objets orphelins jusqu'à son propre nettoyage. **Ne le fais pas de toi-même** :
c'est son arbitrage, et il perdrait `696be3a`, `22e9850` et tout le T0 React Native.

### 5.3 Le nouveau `.gitignore`

Changement de régime : **`android/`, `ios/` et `windows/` sont versionnés** sous Flutter — ils se
modifient à la main et portent la signature de release. Ignorer : `build/`, `.dart_tool/`,
`.flutter-plugins*`, `*.iml`, `.idea/`, `.vs/`, `tools/node_modules/`, `tools/coverage/`,
`android/key.properties`, `*.jks`, `*.keystore`, `.env*.local`, `.claude/settings.local.json`.

### 5.4 Les références d'historique dans la documentation

Les documents citent **22 hachés** de l'ancien historique (`08bf832`, `0954f9e`, `0a76733`,
`0c3596a`, `17d3359`, `18f27b8`, `20842be`, `22e9850`, `2cf3ad2`, `37cd92a`, `42948e8`, `5504b3c`,
`696be3a`, `74afe6d`, `7802669`, `8c6ed61`, `b035424`, `b13a11b`, `b15c01b`, `dbb74d3`, `dc1c7fa`,
`e535e27`). Ils resteront valides via le tag, mais plus dans `git log`. Dans le commit racine, ou
juste après : chaque mention reçoit la forme `` `08bf832` (tag `archive/pre-flutter-2026-09-09`) ``
à sa **première occurrence par fichier**, et `project-state.md` gagne une phrase d'en-tête qui
explique le tag. **On ne supprime pas** ces mentions : l'historique du raisonnement fait partie de
la spec.

## 6. Phase 2 — Le socle Flutter

### 6.1 D'abord un plan, pas du code

Écris `docs/superpowers/plans/<date>-t0-socle-flutter.md` avec `superpowers:writing-plans`, à
partir de la section 5 du design et du compte rendu du spike. Puis exécute-le avec
`superpowers:subagent-driven-development`. Le plan T0 React Native
(`2026-07-31-t0-socle-react-native.md`) est le **modèle de découpage** : mêmes tâches `S`, `D`,
`N`, `M`, `P`, transposées — pas les mêmes contenus.

### 6.2 Disposition du dépôt

```
pubspec.yaml                    ← la racine EST le projet Flutter
analysis_options.yaml
lib/
  domain/                       ← Dart pur : aucun package:flutter, latlong2, http, drift, dart:io
  data/                         ← Hub'Eau, VigiEau (derrière RestrictionSource), stockage local
  application/                  ← Query/Command scellés + registre + CachePolicy
  features/map/                 ← flutter_map, TileLayer IGN, clustering
  main.dart
test/
  architecture/                 ← LE PREMIER TEST À ÉCRIRE
  domain/  data/  application/  features/
android/  ios/  windows/        ← versionnés
assets/
  referentiel/stations.json
  percentiles/                  ← produit par tools/
tools/                          ← TypeScript / Node, inchangé sur le fond
  package.json  tsconfig.json  jest.config.js  eslint.config.js
  percentiles/  test/
docs/
```

Création : `flutter create --project-name martinpecheur --org fr.martinpecheur --platforms
android,ios,windows .` à la racine, **puis** aligner `applicationId` / `bundleIdentifier` sur
`fr.martinpecheur.app`. Vérifie la commande exacte de `flutter create` sur la 3.47 avant de la
donner.

`analysis_options.yaml` : `flutter_lints` + `language: strict-casts, strict-inference,
strict-raw-types` + `avoid_dynamic_calls`, `always_declare_return_types`,
`prefer_final_locals`. `dynamic` implicite interdit, comme `any` l'était.

### 6.3 Ordre d'implémentation, et ce qui change en Dart

`domain/` → `data/` → `application/` → `features/` → écrans. **TDD strict : test rouge d'abord.**
Commence par la conversion d'unités, c'est le bug le plus coûteux du projet (`BR-002`).

| Invariant | En TypeScript | En Dart — c'est ce que tu écris |
|---|---|---|
| Unités typées (`BR-002`) | *branded types*, effacés à l'exécution | **`extension type`** : `LitresPerSecond`, `CubicMetresPerSecond`, `Millimetres`, `Metres`. Un `double` nu ne passe pas |
| Nomenclature close + `Inconnu` (`BR-011`) | union + garde `never` | **`sealed class`** + `switch` exhaustif. Oublier une branche = erreur de compilation |
| `domain/` ne dépend de rien | test d'archi + ESLint | **`test/architecture/domain_isolation_test.dart`** lit les imports de `lib/domain/**` et interdit `package:flutter`, `package:latlong2`, `package:http`, `package:drift`, `package:sqflite`, `dart:io`, `dart:ui`. **Écrit avant la première ligne de `domain/`** |
| CQRS léger | jamais codé | `sealed class Query<T>` / `Command<T>`, `Map<Type, Handler>`, **aucune bibliothèque de médiateur** |
| Cache en un seul point | `cachePolicy.ts` | `CachePolicy` en décorateur de handler, stale-while-revalidate. Jamais recopié dans un dépôt ni un écran |
| Conversion une seule fois | mapper | Mapper unique `data/mappers/`. Aucune valeur brute d'API n'atteint la vue |
| HTTP | `httpStatus.ts`, `retry.ts`, `hubEauClient.ts` | **200 et 206 sont des succès** (`C-06`). Retry sur 429/5xx, **jamais** sur 4xx. Gigue **injectée** pour être testable |
| Fraîcheur (`BR-005`) | `freshness.ts` | Bornes 2 h / 24 h, mêmes cas limites que le test TypeScript |
| Codes station | — | **10 caractères** seulement (`C-05`). Toujours `date_debut_obs_elab` sur `obs_elab` (`C-04`) |
| VigiEau | — | Uniquement derrière `RestrictionSource` (`ADR-004`). `lat`/`lon`, jamais `?commune=` (`C-14`) |

Suites à transposer : les 14 de `src/domain`, `src/data`, `src/application`, architecture, et
`src/features/map` (fond IGN, options, asset des stations — **pas** `offlinePack*`, retiré).
Les 2 suites `tests/plugins/` disparaissent. Les 5 suites percentiles restent sous Jest dans
`tools/`.

Décisions ouvertes, **à trancher au moment où elles bloquent, pas avant**, chacune par un ADR :
stockage local (`ADR-011`, réservé — `drift` candidat par défaut, `sqflite` seul ne couvre pas
Windows), gestion d'état (`ValueNotifier` + `ListenableBuilder`, zéro dépendance, sauf preuve
contraire), graphes (`US-11`). Toute bibliothèque retenue est vérifiée sur `pub.dev` : version,
licence compatible MIT, plateformes **Windows incluse**, date de dernière publication.

### 6.4 Release et CI

- Signature Android : `android/key.properties` (ignoré) + `signingConfigs.release` dans
  `android/app/build.gradle`. La clé reste **à générer par le commanditaire**. Un contrôle refuse
  de publier si `apksigner` lit `CN=Android Debug`.
- `.github/workflows/release-android.yml` réécrit : `subosito/flutter-action` épinglé sur `3.47.1`,
  `flutter build apk --release --split-per-abi` (l'APK Expo embarquait 52 Mo d'`x86` inutiles),
  `gh release create` sur tag `v*` en pré-version. Ajoute un job `windows-latest` avec
  `flutter build windows --release` qui archive le dossier `Release/`.
- `docs/guide-release.md` décrit la nouvelle procédure, Windows compris.

### 6.5 Critère de fin d'étape

À chaque tâche, **avant** de la déclarer faite, montre la sortie de :

```bash
C:\Users\oliver254\develop\flutter\bin\flutter.bat analyze
```

```bash
C:\Users\oliver254\develop\flutter\bin\flutter.bat test
```

```bash
cd tools && npm run verify
```

Zéro remarque, tout vert. Les builds natifs sont lancés par le commanditaire ; tu attends son
retour, tu ne le supposes pas.

## 7. Phase 3 — La documentation, dans les mêmes commits

Code et spec évoluent ensemble : chaque tâche de phase 2 met à jour les documents qu'elle touche.
Le reste se fait en fin de phase 2, jamais « plus tard ».

| Document | Action |
|---|---|
| **`ADR-013` — Flutter et retour de la cible Windows** | Nouveau. Remplace `ADR-010`. 🚨 **La justification est Windows, et Windows seul** — pas `ADR-012`, le hors-ligne étant retiré. Reprend en propre les conséquences chiffrées par `ADR-009` (lot responsive, clavier/souris, géolocalisation sur poste fixe). Porte le niveau de preuve : le compte rendu du spike, daté |
| `ADR-012` | Statut → **Clôturé sur l'option C**. Jamais supprimé, il porte la trace des cinq plantages |
| `ADR-011` | Reste réservé au stockage local, objet mis à jour (`drift` contre `sqflite_common_ffi`) |
| `ADR-010`, `ADR-009` | Statut → `Remplacé par ADR-013` |
| `UC-005` | Statut → *Reporté après la v1*. `US-10` et `US-20` dans `02-specifications.md` idem. `UC-003` étape 6 : retirer « télécharger la zone ». `UC-001 A3` : remplacer le renvoi mort par la description du cache de tuiles par défaut de `flutter_map` |
| **`CLAUDE.md`** | **Réécriture complète** : stack, tableau « Où on en est », invariants dans leur forme Dart, procédure de release, chemin de Flutter sur le poste, contrainte bac à sable. Garde les sections « Sources de données », « Pièges », « La règle qui structure tout », « Anti-hallucination » telles quelles |
| `README.md` | Badges (Flutter, Dart, plateformes Android · iOS · Windows), démarrage rapide, commandes. Retirer la ligne « Le hors-ligne » du tableau produit, ou la reformuler sur le cache de tuiles |
| `docs/README.md` | Index des ADR et des plans ; la ligne « Application mobile iOS et Android » devient trois cibles |
| `docs/project-state.md` | Réécrit : le T0 React Native passe en section historique avec renvoi au tag, le nouveau T0 prend la table |
| `03-conception.md` (10 occurrences), `04-ui.md` (le lot responsive revient), `context-map.md` | Mises à jour ciblées |
| `guide-installation.md` | Flutter : chemin, `flutter doctor`, `cmdline-tools` via Android Studio, workload C++ de Visual Studio — **les trois pièges rencontrés le 2026-09-09** : `winget` n'a pas les `cmdline-tools` ; cocher MSVC seul dans « Composants individuels » n'installe ni CMake ni le SDK Windows, il faut le **workload** ; `flutter` absent du PATH n'est pas une absence |
| `guide-release.md`, `guide-test-appareil.md` | Expo → Flutter, plus la procédure Windows |

Règles : un artefact obsolète reçoit un statut, **jamais une suppression**. Une contrainte d'API
va au tableau `C-xx` de `01-analyse.md`, pas dans `br/`. Mermaid inline uniquement. Domaine en
français, code en anglais.

## 8. Ce qui ne bouge pas, quelle que soit la stack

- **On ne qualifie jamais un débit de « suffisant »** — ni *insuffisant, normal, bon, sûr*
  (`ADR-002`, `BR-003`, glossaire). C'est le produit.
- **Ne jamais inventer un seuil hydrologique.** Faute la plus grave possible.
- **Tout fait relatif à une API publique est vérifié par appel réel, et daté.** Un fait non
  vérifié est signalé comme tel, avec l'URL. La doc Hub'Eau diverge de la production sur au moins
  quatre points.
- **Les trois échelles restent séparées** — écoulement, débit, sécheresse (`BR-008`).
- **Les quatre avertissements ne sont pas une finition** (`BR-012`, `BR-013`).
- **Attribution IGN** : « © IGN Géoplateforme — Licence Ouverte » reste affichée sur la carte.
- Distinguer ✅ implémenté · 🔄 décidé non codé · 💭 spéculatif. Ne jamais compter du 🔄 comme acquis.

## 9. Façon de travailler

- **Lire avant d'écrire.** Ne jamais inventer une API, un paquet, une signature. Incertain → lire
  `pub.dev/documentation`, dater, ou demander.
- Pas de sur-ingénierie. Code explicite plutôt qu'abstraction prématurée.
- Commits **Conventional Commits**, scopes : `domain`, `data`, `ui`, `map`, `hydrometrie`,
  `ecoulement`, `restrictions`, `avertissement`, `docs`, `ci`, `tools`. Petits commits, un par
  tâche du plan. Pas de ligne d'attribution.
- Agents : les spécialistes `.NET` du `CLAUDE.md` global (`harold`, `ada`, `test-runner`) ne
  conviennent pas à Dart. Utilise `voltagent-lang:flutter-expert` ou `general-purpose` pour
  implémenter, `reviewer` pour l'audit après chaque lot, et lance `flutter test` toi-même.
- Rapporte fidèlement : un test rouge est dit rouge, avec sa sortie. Une étape sautée est dite
  sautée. **Rien n'est « terminé » sans la sortie des trois commandes de la section 6.5.**
- Contrat de sortie à chaque point d'étape :

```
## Résultat
[2-5 lignes]

## Fichiers
- chemin — créé|modifié : raison

## Escalations
- agent : raison   (ou : aucune)

## À valider
- question/risque  (ou : rien)
```

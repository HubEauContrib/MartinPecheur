# Ergonomie — une lecture à la fois, des fiches qui ne recouvrent plus la carte — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la carte porte un **bloc de lecture** unique (sélecteur à quatre entrées, en-tête « Légende · <lecture> » avec « ⚠ Avertissement », avis, légende) ; la fiche ne la recouvre plus — **fiche du bas** sous 800 px, **panneau latéral** à partir de 800 px — et garde son **en-tête épinglé** ; les fiches station et ONDE se lisent par ordre d'importance ; le bouton de retour s'annonce « Retour ». Points 49, 51, 60, 61, 63, 64 soldés. Version `0.6.0`, porte franchie sur **Windows et Android**.

**Architecture:** feature-first + MVVM (`ADR-014`), **inchangée** : la tranche ne touche que des vues, `lib/features/shared/` et la composition (`main.dart`). Aucun fichier de `lib/domain/`, `lib/data/` ni des ViewModels ne change, sauf deux fonctions de libellé ajoutées à `lib/features/map/view_model/map_scale.dart` (Dart pur). La carte reste immobile sous une fiche opaque (arbitrage 12). Les surcouches sont posées par **un seul `RenderObject` de mise en page**, qui lit les hauteurs intrinsèques de chaque pièce et répartit la hauteur par **une fonction pure**, `allocateMapLayout`, dans l'ordre de repli de l'arbitrage 11 ; la même fonction sert la porte de faisabilité (`S6`). Une seule dépendance ajoutée, **du SDK** : `flutter_localizations` (arbitrage 8).

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 · `flutter_map` 8.3.2 (`MapCamera.screenOffsetToLatLng` `camera.dart:353`, `focusedZoomCenter` `:420`, `CameraFit.bounds` / `.coordinates` avec `padding` `camera_fit.dart:24-72`, lus dans le paquet installé) · `flutter_localizations` (SDK ; tire `intl` 0.20.3, déjà dans `pubspec.lock`) · cibles **Windows** et **Android** (émulateur `Pixel_7`) ; iOS configuré, jamais compilé.

**Spec:** [`docs/superpowers/specs/2026-10-17-cadrage-ergonomie-design.md`](../specs/2026-10-17-cadrage-ergonomie-design.md) — **approuvé par le commanditaire le 2026-10-17**, douze arbitrages (§ 2), textes d'écran (§ 11.2) et décisions réversibles (§ 11.3) compris. Ce plan l'applique, il ne le rediscute pas. L'exécutant d'une tâche lit le cadrage **et** sa tâche. Relu par un second agent le 2026-10-17 ; ses corrections sont intégrées.

⚠️ **Identifiants de tâche propres à ce plan.** `O1`, `F1`, `P1`… existent aussi dans les plans de T1 à T4. Hors de ce document (`project-state.md`, messages de commit), on écrit **`ERG-O1`** ; dans le titre d'un commit, « (O1 d'Ergonomie) ».

## Contraintes globales

Chaque tâche les porte, même quand elle ne les répète pas.

- **Une seule dépendance nouvelle** : `flutter_localizations` (`sdk: flutter`), tâche `L1`. `pubspec.yaml` ne change sinon que de version (`O1`).
- **Les sept règles de couches** (`test/architecture/layers_test.dart`) restent vertes : aucun fichier de `lib/features/` n'importe `lib/data/` ; une tranche n'importe pas une autre (la fiche ONDE n'importe **pas** `features/map/`) ; le partagé vit dans `lib/features/shared/` et n'importe aucune tranche ; `main.dart` compose.
- **Aucun ViewModel, aucun dépôt, aucune source ne change** (spec § 5.8, R14).
- **Les quatre avertissements** : le contrôle « ⚠ Avertissement » de la carte est **toujours présent**, fiche ouverte ou non (R4) ; chaque fiche porte le sien, **dans son en-tête, dans tous ses états** ; aucun texte d'avertissement ne change ; `warningTextVersion` ne bouge pas ; le modal du premier lancement ne change pas.
- **`BR-008`** : une lecture à la fois ; « Restrictions » est un interrupteur, pas une échelle (arbitrage du 2026-10-03, inchangé). **Aucune comparaison `==` / `!=` sur `MapScaleKind` ne s'ajoute** : la seule permise est celle qui marque l'entrée active, `kind == scale`, **déplacée telle quelle** de `map_scale_chips.dart:87`.
- **`BR-003`** : aucun mot banni (*suffisant, insuffisant, normal, bon, sûr*) ; `vocabulary_test.dart` reste vert. Le critère 15 de la spec est tenu par ce verrou, sans scénario (`PD16`).
- **Textes d'écran : ceux de la spec, § 11.2, mot pour mot.** Un texte qui manque se demande au commanditaire, il ne s'invente pas.
- **La carte ne bouge pas** quand une fiche s'ouvre ou se ferme (arbitrage 12) : aucun `move`, aucun `fitCamera`, aucun rechargement des lieux.
- **Les quatre tailles garanties** (arbitrage 10 ; taille Windows : `PD1`) : **360 × 640** et **390 × 844** (Android), **800 × 740** et **1 280 × 740** (Windows), à **100 % et 200 %**. En deçà (360 × 300, 640 × 360, 844 × 390) : « ⚠ Avertissement » et l'entrée « Restrictions » atteignables, rien de plus.
- **Ordre de repli** (arbitrage 11, spec § 5.6), à toutes les largeurs, seulement là où la place manque : 1. légende · 2. corps de la fiche · 3. avis · 4. sous-titres du sélecteur · 5. indice du bouton · 6. au téléphone, en mode, fiche ouverte : bande du bouton et réticule. **Ne cèdent jamais** aux quatre tailles : titres du sélecteur, en-tête du bloc avec « ⚠ Avertissement », bas de la carte, en-tête de la fiche, et en mode le réticule et sa bande tant que le repli 6 ne joue pas. **Aucun seuil de taille n'est écrit dans `lib/`** pour décider d'un repli : il se décide sur des hauteurs mesurées (« Note d'architecture » ci-dessous).
- **Pièces compatibles avec les dimensions intrinsèques** : tout ce que la mise en page interroge (bloc, bas, bande, réticule, fiches) rend ses hauteurs intrinsèques — **aucun `LayoutBuilder`**, **aucun `ListView` ni autre `Viewport`** dans ces sous-arbres (ils lèvent une erreur sur une demande d'intrinsèques) ; un défilement s'y fait par `SingleChildScrollView`. Une décision qui dépend de la largeur se prend dans un `RenderObject` qui sait calculer ses intrinsèques.
- **Mesures en Roboto**, chargée depuis le SDK (`FLUTTER_ROOT`) et enregistrée aussi sous « Segoe UI » (`test/support/roboto.dart`, `S6`) ; **Segoe UI réelle n'est vue qu'à la porte**.
- **Tout test de widget nomme sa plateforme** : `testWidgetsOnWindows` ou `testWidgetsOnAndroid`, jamais `testWidgets(` nu (verrou `widget_test_platform_test.dart`). Fenêtre de moins de 600 px de large → Android, titre « Android : … ».
- **R15** : un test « CONSTAT » qui décrit l'ancienne disposition est **remplacé** par un invariant, jamais supprimé sans remplaçant ; **le décompte des tests ne baisse pas** ; un écart à l'une des quatre tailles est un **rouge**, pas un nouveau « CONSTAT » : **arrêt et question**.
- **Code et spec dans le même commit** : le `.feature`, `04-ui.md`, `glossary.md`, `tracabilite.md` que touche une tâche s'écrivent dans cette tâche, avec le verrou de `test/project/` qui bouge.
- **Version** `0.6.0+6`, ouverte par `O1`, datée par `P3`.
- **Git** : un commit par tâche, par liste de chemins explicite (`git add -- <chemins>` puis `git commit -- <chemins>`) ; Conventional Commits en français ; **aucune ligne d'attribution** ; rien n'est poussé, fusionné ni tagué sans demande. `windows/flutter/generated_plugin_registrant.h` et `android/.kotlin/` ne se committent jamais.

## Review Focus

Cinq conditions que la spec implique sans qu'un critère les éprouve, les plus probables d'abord. Chacune a son cas de test dans la tâche nommée ; le relecteur de cette tâche vérifie qu'il y est.

| # | Condition | Ce qu'une personne raisonnable attend | Tâche |
|---|---|---|---|
| 1 | La fenêtre passe de part et d'autre de 800 px (redimensionnement Windows, rotation d'une tablette) **pendant qu'une fiche est ouverte et défilée** | la même fiche reste ouverte, son en-tête en place ; la carte ne bouge pas, aucun lieu ne se recharge ; aucune erreur de rendu | `D4` |
| 2 | Un avis paraît (chargement de la vigilance, panne, filtre qui vide la carte) **pendant le mode « Restrictions »** | le réticule ne bouge pas ; le bouton désigne toujours le point sous lui ; l'avis défile dans le bloc | `D1`, `D3` |
| 3 | La taille du texte change en cours d'usage (200 % → 100 % et retour), fiche ouverte | les replis se recalculent (les sous-titres reviennent à 100 %) ; aucune erreur de rendu, aucun va-et-vient d'une trame à l'autre ; la fiche reste ouverte | `D2` |
| 4 | Au téléphone, en mode, une fiche ouverte retire bouton et réticule (repli 6) ; l'usager fait un **appui long** sur la carte, puis ferme la fiche | l'appui long désigne le point sous le doigt ; le bouton retiré n'est **pas** atteignable au clavier ; à la fermeture, bande et réticule reviennent ; « Restrictions » est restée allumée | `D3` |
| 5 | Au clavier, Tab entre dans le corps d'une fiche défilée dont l'en-tête est épinglé | le contrôle qui reçoit le focus est amené en vue, jamais caché sous l'en-tête | `I1` |

---

## Cible et périmètre

| Cible | État dans ce plan |
|---|---|
| **Windows** | construite en release, exécutable lancé hors Flutter (`P1`), à la taille du lancement (1 280 × 740 de zone cliente depuis la PR #24) puis 800 × 740, texte à 100 % puis 200 % (réglage « Taille du texte » de Windows) |
| **Android** | émulateur `Pixel_7`, en débogage (`P2`), police à 100 % puis 200 % ; publication (`A⏸3`, `A⏸5`) et appareil réel (`A⏸4`) restent ⏸ |
| **iOS** | configuré, jamais compilé |

**Ce que la tranche fait :** spec § 3, « Dedans », `D1` à `D11`. **Ce qu'elle ne fait pas :** spec § 3, « Dehors » — en particulier ni passerelles « … autour », ni position statistique dans la fiche station, ni changement de l'écran des restrictions (hors l'annonce « Retour »), ni rien de T5.

---

## Qui lance quoi

| Commande | Lancée par |
|---|---|
| `flutter analyze`, `flutter test`, `dart format`, `flutter pub get` | **Claude**, dans le bac à sable (`flutter` est sur le PATH de Git Bash ; à défaut `/c/Users/oliver254/develop/flutter/bin/flutter.bat`) |
| `flutter run -d windows`, `flutter build windows --release`, lancement de l'exécutable, `flutter emulators --launch Pixel_7`, `flutter run -d emulator-5554`, tout constat à l'écran, tout réglage du système (taille du texte) | **le commanditaire** |

Toute commande du commanditaire est donnée **seule dans son bloc `bash`**, avec le **résultat attendu énoncé**, puis **constatée et recopiée**. Jamais supposée.

## Critère de fin, identique pour chaque tâche — dit ici une seule fois

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

Attendu : `No issues found!` · tous les tests passent · code de sortie **0**. Recopier le **nombre total de tests** (repère relevé par `A0`) : il ne fait que croître. **Un commit par tâche**, par **liste de chemins explicite**. Un fichier régénéré hors de la liste se signale, il ne se committe pas.

⚠️ **Brief de tout sous-agent, en tête :** interdiction de `git stash`, `git checkout`, `git switch`, `git restore`, `git reset`, `git clean`, `git add`, `git commit`, `git push`, et de `python`/`python3` (bloque sur ce poste) ; il rend la **sortie rouge brute** de son étape de test rouge avant d'implémenter. Au retour, la boucle principale relit `git status`, relance elle-même le critère de fin, fait relire par **un** second agent (une re-relecture seulement après une correction de **code** ; les remarques mineures vont au journal), puis committe. Plusieurs sessions peuvent écrire dans le même arbre : `git branch --show-current` (attendu : `feat/ergonomie`) et `git status` avant chaque commit.

**Journal d'exécution :** `.superpowers/sdd/2026-10-17-ergonomie/progress.md` (ignoré par git) — une ligne `Task <ID>: en cours` au lancement, `Task <ID>: complete (<hachage>)` une fois le hachage du commit lu.

**Trois échecs sur le même point : arrêt et question**, pas de quatrième tentative.

---

## Note d'architecture — comment les replis se décident

Le plan fixe ce mécanisme, parce qu'aucune tâche ne pourrait le choisir seule sans défaire les autres :

1. **Chaque pièce dit deux hauteurs intrinsèques** pour une largeur donnée : `getMinIntrinsicHeight` = sa hauteur **repliée**, `getMaxIntrinsicHeight` = sa hauteur **entière**. Partie fixe du bloc : titres seuls / avec sous-titres. Bande du bouton : pilule seule / pilule et indice. Fiche : en-tête seul / fiche entière. Avis, légende, bas, réticule : une seule hauteur (min = max ; l'avis et la légende cèdent en défilant, pas en se repliant).
2. **Une pièce se replie d'elle-même** quand elle est posée avec une hauteur maximale inférieure à sa hauteur entière : les sous-titres et l'indice s'effacent (ni peints ni touchables ; leur texte reste dans l'annonce de l'entrée), la fiche fait défiler son corps. **Une seule variante est montée** : jamais deux sélecteurs, jamais deux jeux de clés ni de nœuds de focus.
3. **Une fonction pure**, `allocateMapLayout` (`S5`), reçoit ces hauteurs et la hauteur disponible et rend la hauteur de chaque pièce, en appliquant les replis 1 à 6 dans l'ordre, chacun seulement s'il le faut. Elle ne connaît aucune taille d'écran ; elle est éprouvée seule, sur des nombres.
4. **Un `RenderObject` de mise en page**, `RenderMapLayout` (`D1`), lit les intrinsèques de ses enfants, appelle `allocateMapLayout`, pose chaque enfant avec la hauteur allouée, et calcule la **carte visible**, la fiche (en bas ou en panneau) et le réticule. Il ne peint ni ne touche ce que le repli 6 retire.
5. **Ce que la vue doit savoir** (réticule visible et son rectangle, carte visible, repli 6 joué ou non) lui est rendu par un `ValueNotifier<MapLayoutReport?>`, mis à jour **après la trame** (`addPostFrameCallback`) et seulement s'il change ; la vue s'en sert pour exclure du focus et des annonces la bande retirée (repli 6), pour désigner sous le réticule et pour zoomer ou cadrer dans la carte visible. Les enfants retirés **restent dans l'arbre**, exclus : leurs intrinsèques restent lisibles, et la décision ne va-et-vient pas d'une trame à l'autre.
6. **`S6` mesure les vraies pièces** (leurs intrinsèques, en Roboto, aux quatre tailles) et passe ces mesures à la même `allocateMapLayout` : si un cas ne tient pas après le repli 6, la tranche s'arrête avant `D1`.

---

## Structure de fichiers

### Tranche `map` — `lib/features/map/`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `view_model/map_scale.dart` (modifié) | `mapScaleEntryTitle`, `mapScaleEntrySubtitle` | `S1` |
| `view/map_reading_selector.dart` (créé) | `MapReadingSelector` : grille de quatre entrées (colonnes selon les titres, repli 4 local, intrinsèques) | `S1` |
| `view/map_scale_chips.dart` (**supprimé**) | remplacé par le sélecteur ; ses deux constantes publiques y passent | `D2` |
| `view/map_legend.dart` (modifié) | `MapLegendHeader`, `mapLegendHeaderText` ; `MapLegend(inBlock:)` | `S2` |
| `view/map_controls.dart`, `view/map_entry_buttons.dart` (modifiés) | paramètre `axis` (rangée au téléphone) | `S4` |
| `view/designate_center_button.dart` (modifié) | `DesignationBand` : pilule et indice, repli 5 local, intrinsèques — remplace `_DesignationPlacement` de `map_view.dart` | `S4` |
| `view/map_layout_allocation.dart` (créé, sans import de Flutter) | `MapLayoutWidth`, `mapLayoutWidthFor`, seuils de largeur nommés, `PieceHeights`, `MapLayoutInput`, `MapLayoutAllocation`, `allocateMapLayout` | `S5` |
| `view/map_reading_block.dart` (créé) | `MapReadingBlockFixed`, `MapReadingBlockNotices`, `MapReadingBlockLegend` | `B1` |
| `view/map_layout.dart` (créé) | `MapLayoutSlot`, `MapLayoutReport`, le widget `MapLayout` et `RenderMapLayout` | `D1` |
| `view/map_overlays_layout.dart` (**supprimé**) | remplacé par `map_layout.dart` | `D2` |
| `view/map_view.dart` (modifié) | `buildMapOverlays` sur `MapLayout` ; désignation et zoom sous le réticule ; recentrage et cadrages dans la carte visible | `D2`, `D3`, `D4` |

### Partagé — `lib/features/shared/`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `sheet_frame.dart` (créé) | `SheetFrame` (en-tête épinglé, corps défilant) et `NoMinIntrinsicHeight` (enveloppe qui annonce 0 de hauteur intrinsèque minimale) | `S3` |

### Fiches

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `station_sheet/view/station_summary_sheet.dart` (modifié) | panneau dans `SheetFrame` ; tuiles débit et hauteur | `F1` |
| `onde_sheet/view/onde_summary_sheet.dart` (modifié) | panneau dans `SheetFrame` ; tuile de catégorie, historique à symboles fournis | `F2` |
| `flood_sheet/view/flood_sheet_panel.dart` (modifié) | panneau dans `SheetFrame`, ordre de T4 sous l'en-tête | `F3` |

### Composition et tests partagés

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/main.dart` (modifié) | contrôleur de défilement passé aux corps de fiche ; symbole d'écoulement fourni ; localisation | `D5`, `L1` |
| `lib/diagnostics/fluidity_probe_panel.dart` (modifié si nécessaire) | le panneau de la sonde posé dans la carte visible, sans recouvrir le bloc | `D2` |
| `test/support/roboto.dart` (créé) | `chargerRoboto()` | `S6` |
| `test/support/layout_sizes.dart` (créé) | les quatre tailles, les tailles en deçà, la marge système de téléphone, les échelles de texte | `S6` |

### Tests remplacés (R15) — par `D2`, dans le même commit que le code qui les rend caducs

| Fichier | Sort |
|---|---|
| `test/features/map/view/map_overlays_phone_test.dart` (5 272 l., 23 « CONSTAT ») | **supprimé**, remplacé par `map_layout_invariants_test.dart` |
| `test/features/map/view/map_sheet_height_test.dart` (matrice de 80 cas) | **supprimé**, remplacé idem (la fiche bornée y est un invariant) |
| `test/features/map/view/map_entry_buttons_overlap_test.dart` (4 « CONSTAT ») | **supprimé**, remplacé idem |
| `test/features/map/view/map_overlays_layout_test.dart` | **supprimé**, remplacé par `map_layout_test.dart` (`D1`) |
| `test/features/map/view/map_scale_chips_test.dart` | **supprimé** avec son fichier, remplacé par `map_reading_selector_test.dart` (`S1`) |
| `test/features/map/view/map_view_test.dart` | groupes de disposition retirés (l. 1104, 1182, 1288, 1432, 1499, 2114, et les cas de recouvrement du groupe de la l. 855 : l. 1023, 1051, 1068) ; les autres groupes restent |

### Partages entre tâches — à exécuter en série

| Tâches | Fichier partagé |
|---|---|
| `S1`, `S2`, `S4`, `B1`, `D2`, `D3`, `D4`, `I1` | `lib/features/map/view/map_view.dart`, `map_legend.dart`, `designate_center_button.dart`, tests de la carte |
| `D2`, `F1`, `F2`, `F3`, `D5`, `L1` | `lib/main.dart`, `test/main_test.dart`, panneaux de fiche |
| `O2`, `S1`, `S2`, `D2`, `F1`, `F2`, `F3`, `D3`, `D4`, `D5`, `L1` | `docs/acceptance/*.feature`, `test/project/acceptance_features_test.dart` |
| `D2`, `F1`, `F2`, `F3`, `D3`, `X1` | `docs/04-ui.md` |
| `O1`, `P3` | `CHANGELOG.md`, `test/project/changelog_test.dart` |
| `D2`, `X1` | `docs/tracabilite.md`, `test/project/tracabilite_test.dart` |

---

## Lot 0 — Préalable, sur demande du commanditaire

### Task A0 : Cadrage committé, `origin/dev` intégré, branche `feat/ergonomie`

**Agent :** aucun — la boucle principale, **après accord explicite du commanditaire** pour chaque opération git.
**État constaté le 2026-10-17 :** `dev` local à `bc7b34f`, **un commit de retard** sur `origin/dev` (`906c9d2`, PR #24 fusionnée en un commit) ; non committés : la spec d'ergonomie, ce plan, `CLAUDE.md`, `docs/README.md`, `docs/project-state.md`. `docs/project-state.md` est modifié **des deux côtés** (point 65 côté `origin/dev`).

- [ ] **Étape 1** — `git branch --show-current` (attendu : `dev`), seul ; `git status --short`.
- [ ] **Étape 2** — sur accord : commit des documents par chemins explicites (`docs/superpowers/specs/2026-10-17-cadrage-ergonomie-design.md`, `docs/superpowers/plans/2026-10-17-ergonomie.md`, `CLAUDE.md`, `docs/README.md`, `docs/project-state.md`) : `docs: cadrage et plan de la tranche d'ergonomie, approuvés`.
- [ ] **Étape 3** — sur accord : `git fetch`, puis `git merge origin/dev` (`git pull` échoue sur ce poste) ; résoudre le conflit attendu de `docs/project-state.md` en gardant **les deux** apports (point 65 et les lignes de l'ergonomie).
- [ ] **Étape 4** — `git switch -c feat/ergonomie` ; critère de fin ; **relever le décompte de tests** (attendu : celui d'`origin/dev`, rapporté à 3 983 par la session de la PR #24, à constater) : c'est le repère de toute la tranche.

---

## Lot 1 — Documents, avant le code

### Task O1 : Ouvrir la version `0.6.0`

**Agent :** mécanique (sonnet, effort léger).
**Files:** modifiés `pubspec.yaml` (`version: 0.6.0+6`), `CHANGELOG.md` (une section `## [0.6.0]` **ouverte, non datée**, sous `## [Non publié]`, sur le modèle de l'ouverture de `0.5.0` par `O1` de T4 : `changelog_test.dart:11-30` exige `## [<version du pubspec>]`), `test/project/changelog_test.dart` (le verrou de la l. 711, « `pubspec.yaml porte version: 0.5.0+5` », passe à `0.6.0+6`, avec ce que T4 avait ajouté pour une section ouverte), `docs/project-state.md` (en-tête « Mis à jour » ; ligne « Ergonomie » : « en cours, plan `docs/superpowers/plans/2026-10-17-ergonomie.md` » ; « Prochaine étape »)

- [ ] **Étape 1** — modifier le verrou de version, test rouge, sortie recopiée ; **Étape 2** — écrire ; **Étape 3** — critère de fin, commit `chore: version 0.6.0 ouverte, tranche d'ergonomie en cours (O1 d'Ergonomie)`.

### Task O2 : `BR-008`, `UC-001`, glossaire, textes d'acceptation qui nomment l'ancienne disposition

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `docs/br/BR-008-une-seule-echelle-a-la-fois.md` (amendement daté : texte de la spec § 11.1, mot pour mot), `docs/use-cases/UC-001-consulter-la-carte-autour-de-moi.md` (amendement daté : le contrôle « ⚠ Avertissement » de la carte est dans l'en-tête de la légende, sous le sélecteur), `docs/glossary.md` (entrées « Sélecteur de lecture », « Bloc de lecture », « Carte visible », « Fiche du bas », « Panneau latéral » ; l'entrée « Filtre » renvoie au sélecteur), `docs/acceptance/avertissements.feature` (l. 41 : « reste présent au-dessus de la légende » → « reste présent dans l'en-tête de la légende »), `docs/acceptance/crues.feature` (l. 11-14 : « la puce » → « l'entrée du sélecteur »), `docs/acceptance/filtres.feature` (l. 83-86 : « les puces d'échelle » → « le sélecteur de lecture »)

- [ ] **Étape 1** — `flutter test test/project` vert avant ; écrire ; **Étape 2** — `flutter test test/project` vert après ; **Étape 3** — critère de fin, commit `docs: BR-008, UC-001 et glossaire disent le sélecteur et le bloc de lecture (O2 d'Ergonomie)`.

---

## Lot 2 — Pièces, allocation et mesure (premier lot de code, arbitrage 11)

> Les pièces se construisent **seules**, avec leurs tests, **sans être branchées** dans `buildMapOverlays` : les brancher dans l'ancienne disposition ferait rougir ses mesures au pixel, qui ne sont remplacées qu'en `D2`. Le lot se clôt par `S6`, porte de faisabilité.

### Task S1 : Le sélecteur de lecture

**Agent :** **raisonnement** (opus, effort moyen) — un `RenderObject` de grille.
**Files:** modifié `lib/features/map/view_model/map_scale.dart` ; créés `lib/features/map/view/map_reading_selector.dart`, `test/features/map/view/map_reading_selector_test.dart` ; modifiés `test/features/map/view_model/map_scale_test.dart`, `docs/acceptance/filtres.feature` (scénario du critère 2 de la spec : chaque entrée porte son titre et son sous-titre, annoncés ensemble), `test/project/acceptance_features_test.dart` (les trois sous-titres et `designationEntrySubtitle` cités par `filtres.feature`)

**Interfaces :**
- `map_scale.dart` (Dart pur, à côté de `mapScaleLabel`, `switch` exhaustif) : `String mapScaleEntryTitle(MapScaleKind kind)` → `'Écoulement'` · `'Débit'` · `'Vigilance crues'` ; `String mapScaleEntrySubtitle(MapScaleKind kind)` → `'observé sur le terrain'` · `"relatif à l'historique"` · `'publiée par $floodSourceName'`.
- `map_reading_selector.dart` :
  - `const String designationEntrySubtitle = 'arrêtés préfectoraux';`
  - `String readingEntrySemanticsLabel(String title, String subtitle) => '$title, $subtitle';`
  - `class MapReadingSelector extends StatelessWidget { const MapReadingSelector({required MapScaleKind scale, required void Function(MapScaleKind kind) onSelect, bool designationMode = false, VoidCallback? onToggleDesignationMode, super.key}); }`
  - **À ce stade**, `mapDesignationChipKey` et `designationChipLabel` restent dans `map_scale_chips.dart`, que le sélecteur importe ; `D2` les déplace ici.
- **Entrée** : `Semantics(key: ValueKey<MapScaleKind>(kind)` ou `mapDesignationChipKey, button: true, selected:` (lectures, `kind == scale`) **ou** `toggled: designationMode` (« Restrictions »), `label: readingEntrySemanticsLabel(title, subtitle)` — **le sous-titre reste dans l'annonce même effacé**, `excludeSemantics: true, onTap:)` › `KeyboardFocusRing(onActivate:)` › cible d'au moins `minimumTapTarget` dans les deux dimensions › pictogramme (`ExcludeSemantics`), titre (14, gras), sous-titre (12). Allumée : fond noir, texte blanc ; éteinte : fond `#F3F4F1`, bord `#C9CFC4`. La lecture affichée et « Restrictions » peuvent être allumées ensemble (R6).
- **Pictogrammes** (`PD4`) : `Icons.water_drop`, `Icons.timeline`, `Icons.waves`, `Icons.gavel` ; jamais `Icons.warning_amber_rounded` (celui de « ⚠ Avertissement »).
- **Grille** (un `RenderObject`, intrinsèques comprises) : **le nombre de colonnes est le plus grand de 4, 2, 1 pour lequel aucun mot de titre n'est coupé** — la largeur d'une colonne est au moins la largeur intrinsèque minimale de chaque entrée **sans son sous-titre** (le plus long mot du titre, pictogramme et marges compris), à l'échelle de texte courante (`PD5`, au lieu d'un seuil de largeur). Rangées de hauteur égale (la plus haute entrée de la rangée).
- **Repli 4, local** : `getMaxIntrinsicHeight(w)` = grille avec sous-titres, `getMinIntrinsicHeight(w)` = titres seuls ; posée avec une hauteur maximale inférieure à la première, la grille efface **tous** les sous-titres (ni peints, ni touchables, ni dans l'arbre de focus ; la cible de chaque entrée reste ≥ `minimumTapTarget`).

**Cas de test** (`testWidgetsOnWindows`, et `testWidgetsOnAndroid` à 344 de large)
- `map_scale_test` : titres et sous-titres exacts des trois lectures ; aucun mot banni (listes de `test/project/vocabulary_lists.dart`).
- Quatre entrées dans l'ordre Écoulement, Débit, Vigilance crues, Restrictions ; sans `onToggleDesignationMode`, trois.
- Annonces exactes : « Écoulement, observé sur le terrain », « Débit, relatif à l'historique », « Vigilance crues, publiée par Vigicrues », « Restrictions, arrêtés préfectoraux » ; sous-titres effacés (hauteur bornée sous `getMaxIntrinsicHeight`) : textes absents de l'écran, **annonces inchangées**.
- La lecture active est `selected`, les autres non ; « Restrictions » est `toggled` selon `designationMode`, jamais `selected` ; en mode, la lecture active reste `selected`.
- Tap, Entrée, Espace et action sémantique appellent `onSelect(kind)` / `onToggleDesignationMode` une fois.
- Colonnes : à 480 de large et 100 %, quatre ; à 344 et 100 %, deux ; à 344 et 200 %, le nombre que la règle donne (calculé dans le test à partir des largeurs intrinsèques des titres), et **aucun mot de titre coupé** (la largeur de chaque ligne de titre ≥ son plus long mot, lue par `TextPainter`) ; chaque entrée ≥ `minimumTapTarget` (44 Windows, 48 Android).
- Intrinsèques : `getMinIntrinsicHeight(w)` < `getMaxIntrinsicHeight(w)` ; posée exactement à `getMinIntrinsicHeight(w)`, aucune erreur de rendu.
- Le pictogramme de « Restrictions » n'est pas `Icons.warning_amber_rounded`.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): le sélecteur de lecture à quatre entrées, titre et sous-titre (S1 d'Ergonomie)`.

### Task S2 : L'en-tête de légende ; la légende dans le bloc

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `lib/features/map/view/map_legend.dart`, `test/features/map/view/map_legend_test.dart`, `test/project/acceptance_features_test.dart`, `docs/acceptance/avertissements.feature` (scénario : « l'en-tête « Légende · Écoulement » porte « ⚠ Avertissement » »)

**Interfaces :**
- `String mapLegendHeaderText(MapScaleKind kind) => 'Légende · ${mapScaleLabel(kind)}';`
- `class MapLegendHeader extends StatelessWidget { const MapLegendHeader({required MapScaleKind scale, required Widget warningLink, super.key}); }` — une rangée : le texte (13, gras, `Semantics(header: true)`), qui se replie à la ligne et n'est jamais coupé, puis `warningLink` à droite ; hauteur au moins `minimumTapTarget`.
- `MapLegend` gagne `bool inBlock = false` (défaut : comportement actuel). `inBlock: true` : **sans titre** (il est dans l'en-tête), **sans** la carte blanche ni le plafond de `legendMaxWidth` (le bloc les porte), et les **rangées courtes** (six d'écoulement, cinq de fraîcheur du débit, cinq de crues) dans un `Wrap` d'éléments de `legendRowWidth = 156` de large (`PD6`) — deux par ligne dès que la largeur le permet, sans `LayoutBuilder` ; les phrases longues (explication `BR-004`, « Comparaison statistique… », couverture et date de la vigilance) restent pleine largeur.

**Cas de test** (`testWidgetsOnWindows`)
- `mapLegendHeaderText` pour les trois lectures : « Légende · Écoulement », « Légende · Débit relatif à l'historique », « Légende · Vigilance crues ».
- `MapLegendHeader` : le texte puis le lien, le lien à droite ; à 200 % et 344 de large, « Légende · Débit relatif à l'historique » passe à la ligne, le lien reste entier ; intrinsèques lisibles sans erreur.
- `inBlock: true` à 344 : aucun `mapScaleLabel(scale)` seul ; les six rangées d'écoulement sur trois lignes de deux ; `inBlock: false` : les tests existants passent sans changement.
- `acceptance_features_test` : `mapLegendHeaderText(MapScaleKind.ecoulement)` cité par `avertissements.feature`.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): en-tête « Légende · <lecture> » portant l'avertissement ; légende du bloc en colonnes (S2 d'Ergonomie)`.

### Task S3 : Le cadre commun des fiches

**Agent :** mécanique (sonnet, effort moyen).
**Files:** créés `lib/features/shared/sheet_frame.dart`, `test/features/shared/sheet_frame_test.dart`

**Interfaces :**
- `const Key sheetFrameHeaderKey = Key('sheet-frame-header');` · `const Key sheetFrameBodyKey = Key('sheet-frame-body');` · `const String sheetCloseLabel = 'Fermer la fiche';`
- `class NoMinIntrinsicHeight extends SingleChildRenderObjectWidget` — une enveloppe qui annonce 0 de hauteur intrinsèque minimale et transmet le reste (largeurs, hauteur maximale, mise en page).
- `class SheetFrame extends StatelessWidget { const SheetFrame({required String nature, required Key closeButtonKey, required VoidCallback onClose, required Widget body, String? warningExtraText, FavoriteStar? favoriteStar, VoidCallback? onToggleFavorite, ScrollController? bodyScrollController, super.key}) : assert(favoriteStar == null || onToggleFavorite != null); }`
- Rendu : `Material(color: Colors.white, elevation: 4)` › `Column(mainAxisSize: min)` :
  - **en-tête** (`sheetFrameHeaderKey`, ne défile pas) : `Row` [ `Expanded(Text(nature))` (12, gras, `#3A4148`, se replie) · `FavoriteStarButton` si `favoriteStar` · fermeture ] ; dessous `WarningLink(extraText: warningExtraText)` ; dessous, si `favoriteStar?.writeFailed`, `FavoriteWriteFailedNotice` (textes existants) ;
  - **corps** : `NoMinIntrinsicHeight(SingleChildScrollView(key: sheetFrameBodyKey, controller: bodyScrollController, primary: false, child: body))`, sans barre de défilement de bureau (`ScrollConfiguration` à `scrollbars: false`), en `Flexible` **seulement si la hauteur reçue est bornée** ; sous une hauteur non bornée (la zone des fiches actuelle, qui défile elle-même), le corps est posé à sa hauteur, sans `Flexible`.
  - Intrinsèques : min = en-tête, max = en-tête + corps.
- Fermeture : reprend `_CloseButton` des fiches (cible `minimumTapTarget`, `Semantics(label: sheetCloseLabel)`, `GestureDetector(key: closeButtonKey)`), **pas un arrêt de tabulation** (`Échap` ferme) ; l'étoile **est** un arrêt de tabulation (inchangé).

**Cas de test** (`testWidgetsOnWindows`, un `testWidgetsOnAndroid` à 360 × 640 et 200 %)
- Ordre : nature, étoile, fermeture sur la même rangée ; « ⚠ Avertissement » dessous ; corps ensuite. Sans étoile : nature et fermeture.
- **En-tête épinglé** : corps de 2 000 px dans un cadre borné à 400 → faire défiler le corps de 600 : `sheetFrameHeaderKey` ne bouge pas.
- **Hauteur non bornée** (dans un `SingleChildScrollView`) : aucune erreur de rendu, la fiche a la hauteur de son contenu.
- Intrinsèques : `getMinIntrinsicHeight` = hauteur de l'en-tête (à 0,5 px près) ; `getMaxIntrinsicHeight` = en-tête + corps.
- `bodyScrollController.jumpTo(0)` ramène le corps en haut ; `writeFailed` : la phrase sous l'en-tête, `liveRegion`.
- Tap sur la fermeture → `onClose` une fois ; la fermeture hors de l'ordre de tabulation, l'étoile dedans.
- À 360 × 640 et 200 %, « Station hydrométrique · K447001001 » se replie sans chevaucher l'étoile ni la fermeture.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(ui): cadre commun des fiches, en-tête épinglé (S3 d'Ergonomie)`.

### Task S4 : Le bas en rangée ; la bande du bouton en pièce

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `lib/features/map/view/map_controls.dart`, `lib/features/map/view/map_entry_buttons.dart`, `lib/features/map/view/designate_center_button.dart`, `test/features/map/view/map_controls_test.dart`, `test/features/map/view/map_entry_buttons_test.dart`, `test/features/map/view/designate_center_button_test.dart`

**Interfaces :**
- `MapControls({…, Axis axis = Axis.vertical})` : vertical, ordre actuel (`+`, `−`, recentrer) ; **horizontal, ordre de l'écran `−`, `+`, recentrer**, écart `mapControlsSpacing`.
- `MapEntryButtons({…, Axis axis = Axis.vertical})` : horizontal, « Favoris » puis « Filtres » ; formes de « Filtres » inchangées.
- `class DesignationBand extends StatelessWidget { const DesignationBand({required VoidCallback onDesignate, super.key}); }` — la pilule (`DesignateCenterButton`) puis l'indice (`DesignateCenterHint`), centrés ; seule la pilule est dans un `SingleChildScrollView` (pas de `ListView` : intrinsèques), `primary: false` ; l'indice, frère du défilement, reste monté (amendé à la relecture de `S4` : sous un défilement, l'indice ne recevrait plus la hauteur et ne pourrait se replier) ; gestes rendus à la carte hors de la pilule et de l'indice (`deferToChild`, sans barre de bureau) — le comportement de `_DesignationPlacement` (`map_view.dart:1566-1621`), sans ses marges, que la mise en page posera. **Repli 5, local** : min intrinsèque = pilule, max = pilule + écart + indice ; posée sous sa hauteur entière, l'indice s'efface (ni peint ni touchable).
- Clés, libellés, annonces inchangés.

**Cas de test** (`testWidgetsOnWindows`, `testWidgetsOnAndroid`)
- `axis: Axis.horizontal` : centres x croissants dans l'ordre `−`, `+`, recentrer (resp. « Favoris », « Filtres ») ; centres y égaux ; écart `mapControlsSpacing` ; chaque bouton de `minimumTapTarget`. Par défaut : tests existants inchangés.
- Ordre de tabulation dans un `FocusTraversalGroup(policy: OrderedTraversalPolicy())` où les trois partagent un `NumericFocusOrder` : `−`, `+`, recentrer.
- `DesignationBand` : tap sur la pilule → `onDesignate` ; hauteur bornée à la pilule : l'indice (`mapDesignateCenterHintKey`) ni peint ni touchable — à vérifier par `.hitTestable()` et par la peinture, jamais par `find.byKey(mapDesignateCenterHintKey)` seul suivi de `findsNothing` (l'indice reste monté), et sans prendre son `getRect` pour une position —, pilule entière ; un tap à côté de la pilule atteint un `GestureDetector` témoin dessous (Windows et Android, comme les verrous de la bande, `map_designation_test.dart:951-1001`).

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): zoom et entrées en rangée ; la bande du bouton en pièce, repli 5 (S4 d'Ergonomie)`.

### Task S5 : La répartition de la hauteur, fonction pure

**Agent :** **raisonnement** (opus, effort moyen).
**Files:** créés `lib/features/map/view/map_layout_allocation.dart` (**aucun import** de Flutter), `test/features/map/view/map_layout_allocation_test.dart`

**Interfaces :**
- `const double mapWideLayoutMinWidth = 600;` · `const double mapSidePanelMinWidth = 800;` · `const double mapSidePanelWidth = 380;` · `const double mapReadingBlockMaxWidth = 480;` (R2 : constantes nommées, révisables sur constat d'écran — ce sont des **largeurs**, pas des seuils de repli)
- `enum MapLayoutWidth { compact, wide, panel }` · `MapLayoutWidth mapLayoutWidthFor(double width)` — moins de 600 : compact ; moins de 800 : wide ; sinon panel.
- `final class PieceHeights { const PieceHeights({required double min, required double max}); const PieceHeights.fixed(double h); static const PieceHeights none = PieceHeights.fixed(0); }`
- `final class MapLayoutInput { const MapLayoutInput({required double available, required MapLayoutWidth width, required bool blockOverBottom, required bool designation, required bool sheetOpen, required PieceHeights blockFixed, required double notices, required double legend, required double bottom, required PieceHeights band, required double reticleBand, required PieceHeights sheet, required double gap}); }` — `available` : hauteur de la surface moins la zone sûre ; `blockOverBottom` : le bloc et le bas se superposent en largeur (toujours en compact ; au-delà, quand la largeur du bloc atteint la colonne) ; `sheet` : en panel, **non compté** (la fiche est à côté).
- `final class MapLayoutAllocation { final double blockFixed, notices, legend, sheet, band, reticleBand; final bool subtitlesFolded, hintFolded, bandWithdrawn, overflows; final List<int> folds; }` (`folds` : les replis joués, dans l'ordre, sous-ensemble de 1 à 6)
- `MapLayoutAllocation allocateMapLayout(MapLayoutInput input)`

**L'algorithme** — empile, du haut vers le bas, partie fixe, avis, légende, bande du réticule, puis la **zone du bas** — en compact, bande **au-dessus** de la rangée (`band + bottom`) ; au-delà, bande **à côté** de la colonne (`max(band, blockOverBottom ? bottom : 0)`) —, puis la fiche hors panel ; un `gap` entre deux pièces non nulles ; `available` est déjà diminué des deux marges de surcouche (haut et bas) ; tout au plus haut (max) d'abord ; puis, tant que la somme dépasse `available`, et **chaque repli seulement de ce qu'il faut** :
1. la **légende** décroît jusqu'à 0 ;
2. la **fiche** décroît jusqu'à `sheet.min` ;
3. les **avis** décroissent jusqu'à 0 ;
4. la **partie fixe** passe à `blockFixed.min` (`subtitlesFolded`) ;
5. la **bande** passe à `band.min` (`hintFolded`) ;
6. compact, en mode, fiche ouverte : bande et bande du réticule à 0 (`bandWithdrawn`).
Si cela ne suffit toujours pas : `overflows` vrai, la partie fixe reçoit ce qui reste (elle défilera : en deçà). Hors mode : `band` et `reticleBand` sont nuls à l'entrée.

**Amendé à l'exécution de `S5` (2026-10-18, relectures) :** les écarts se comptent **par groupe** — [bloc = partie fixe + avis + légende, sans écart interne (`B1`)] · [bande du réticule, qui porte ses marges : aucun écart de part et d'autre] · [zone du bas, un `gap` entre bande et rangée en compact] · [fiche hors panel] ; un `gap` entre deux groupes consécutifs non nuls ; un groupe à 0 n'en a plus. Le surplus d'un repli tout ou rien (4, 5, 6) revient aux avis, puis à la fiche, puis à la légende ; `folds` = les replis en vigueur à la fin (p. ex. `[1, 2, 4]`). En wide, bloc étroit (`blockOverBottom` faux), fiche du bas ouverte, la colonne, qui ne cède jamais, **plafonne la fiche** à `available − bas − gap` (repli 2), `overflows` si l'en-tête n'y tient pas ; en panel ou sans fiche, `bas > available` → `overflows` (spec § 6.5). Toutes les comparaisons à `1e-6` près.

**Cas de test** (`test`, nombres seuls)
- Tout tient : aucun repli, chaque pièce à son max.
- Il manque 30 px, légende de 100 : `folds == [1]`, légende 70.
- Légende déjà à 0, fiche de max 300 / min 80, il manque 100 : `folds == [1, 2]`, fiche 200.
- Ordre : un cas qui exige les six replis les joue dans l'ordre 1 à 6, et `bandWithdrawn` seulement en compact, en mode, fiche ouverte (le même cas en wide → `overflows`, pas de repli 6).
- Panel, fiche ouverte : la fiche n'entre pas dans la somme.
- `blockOverBottom` faux (wide, bloc étroit) : le bas n'entre pas dans la somme.
- Rien de négatif ; `available` = 0 → `overflows`, partie fixe 0, aucune exception.
- `mapLayoutWidthFor` : 599 → compact, 600 → wide, 799 → wide, 800 → panel.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): répartition pure de la hauteur dans l'ordre de repli (S5 d'Ergonomie)`.

### Task S6 : Mesurer les pièces ; l'ordre de repli suffit-il aux quatre tailles ?

**Agent :** **raisonnement** (opus, effort élevé) — porte de faisabilité de l'arbitrage 11.
**Prérequis :** `S1` à `S5`.
**Files:** créés `test/support/roboto.dart`, `test/support/layout_sizes.dart`, `test/support/ergonomie_mesures.dart`, `test/features/map/view/ergonomie_budget_test.dart`

**Interfaces :**
- `test/support/roboto.dart` : `Future<void> chargerRoboto()` — la fonction `_chargerRoboto` de `map_overlays_phone_test.dart:212-264`, déplacée telle quelle (lit `FLUTTER_ROOT`, `bin/cache/artifacts/material_fonts/roboto-*.ttf`, `fail(...)` si absent, enregistre « Roboto » puis « Segoe UI ») ; les trois copies existantes ne sont pas touchées ici (`D2` supprime leurs fichiers).
- `test/support/layout_sizes.dart` : `const List<({String nom, Size taille, TargetPlatform plateforme})> taillesGaranties` (`360 × 640`, `390 × 844` Android ; `800 × 740`, `1280 × 740` Windows) · `const List<Size> taillesEnDeca = <Size>[Size(360, 300), Size(640, 360), Size(844, 390)];` · `const EdgeInsets margeSystemeTelephone = EdgeInsets.only(top: 24, bottom: 48);` (`PD10`) · `const List<double> echellesDeTexte = <double>[1, 2];` · `const double margeDeSurcouche = 8;`

**Ce que le test mesure** — chaque vraie pièce, montée seule en Roboto, ses intrinsèques à sa largeur réelle (spec § 5.1 : bloc = largeur − 2 × 8 en compact ; `min(480, carte visible − 2 × 8)` sinon, la carte visible valant `largeur − 380` fiche ouverte en panel) : `MapReadingSelector` (min, max) et `MapLegendHeader` pour **chacune des trois lectures** (l'en-tête « Débit relatif à l'historique » passe à la ligne à 200 %) ; l'avis d'absence (`NoDataInArea`, le plus haut des avis d'écoulement, `map_empty_states.dart`) ; `MapLegend(inBlock: true)` des trois lectures ; le bas (rangée + `IgnAttributionBadge` en compact, colonne + badge sinon) ; `DesignationBand` (min, max) à la largeur de la bande ; la bande du réticule (`mapCenterReticleSize + 2 × 8`) ; l'en-tête de `SheetFrame` d'une **station** (nature « Station hydrométrique · K447001001 », étoile, « ⚠ Avertissement ») et d'un **tronçon** (« Tronçon Vigicrues », sans étoile), à la largeur de la fiche (toute la largeur en compact, 380 en panel).

**Mesure partagée** — `test/support/ergonomie_mesures.dart` : `Future<MapLayoutInput> mesurerPieces(WidgetTester tester, {required Size taille, required double echelle, required MapScaleKind lecture, required bool enMode, required ({String nature, bool etoile})? fiche, required bool avecAvis, required EdgeInsets marge})` — monte chaque pièce seule, lit ses intrinsèques et rend l'entrée de `allocateMapLayout` ; `D2` (I-g) et `D3` s'en servent pour savoir quels replis jouent à une configuration.

**Ce que le test affirme** — pour chaque taille garantie × échelle de texte × lecture × {hors mode, en mode} × {sans fiche, fiche station, fiche tronçon} × {sans avis, avis d'absence} × {sans marge, `margeSystemeTelephone`} (la marge au téléphone seulement) : `allocateMapLayout(...)` sur ces mesures rend `overflows == false`. Le titre de chaque cas nomme les replis joués : « 360 × 640, 200 %, débit, en mode, fiche station, avis, marge : replis 1, 2, 3, 4, 5, 6 — tient ».

**Règle d'arrêt** : un cas qui rend `overflows == true` est **rouge** et ne s'assouplit pas : **arrêt et question fermée au commanditaire**, avec le tableau des hauteurs. Le tableau mesuré se recopie dans le message de commit et dans le journal.

- [ ] **Étape 1** — écrire le test, le lancer, recopier le tableau ; **Étape 2** — vert : critère de fin, commit `test(map): hauteurs des pièces mesurées, l'ordre de repli tient aux quatre tailles (S6 d'Ergonomie)` ; rouge : arrêt et question.

---

## Lot 3 — Le bloc de lecture

### Task B1 : Bloc de lecture en trois pièces

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `S1`, `S2`, `S6`.
**Files:** créés `lib/features/map/view/map_reading_block.dart`, `test/features/map/view/map_reading_block_test.dart`

**Interfaces** — trois pièces, une par enfant de la mise en page, qui dessinent ensemble une seule carte blanche (bord `#C9CFC4`, rayon 14, ombre de la maquette) :
- `MapReadingBlockFixed({required MapReadingSelector selector, required MapLegendHeader header, super.key})` — le haut de la carte (rayon en haut), le sélecteur puis l'en-tête ; intrinsèques = celles du sélecteur (min, max) + en-tête. Posée sous sa hauteur repliée (en deçà), elle **défile** (`SingleChildScrollView`, `primary: false`, sans barre, gestes rendus à la carte hors des pièces).
- `MapReadingBlockNotices({required List<Widget> notices, super.key})` — les avis, défilants dans la hauteur reçue ; aucun avis → hauteur 0, rien de peint.
- `MapReadingBlockLegend({required MapLegend legend, super.key})` — le bas de la carte (rayon en bas), la légende défilante dans la hauteur reçue ; hauteur 0 → seul le rebord bas de la carte (rayon) est peint.
- `FocusTraversalOrder(NumericFocusOrder(mapTraversalOrderChips))` enveloppe le sélecteur, `mapTraversalOrderNotices` les avis — posés par `buildMapOverlays` (`D2`), pas ici.

**Cas de test** (`testWidgetsOnWindows` à 480 ; `testWidgetsOnAndroid` à 344 ; Roboto par `chargerRoboto`)
- Les trois pièces empilées sans écart forment une carte continue (bords alignés, un seul rayon en haut, un en bas).
- Fixe posée à sa hauteur repliée : titres et en-tête entiers, sous-titres absents ; posée à 120 : elle défile ; « ⚠ Avertissement » s'amène en vue par un glisser sur le bloc et par `Scrollable.ensureVisible` (focus).
- Avis posés sous leur hauteur : l'action « Élargir la recherche » s'atteint en faisant défiler.
- Un tap, un glisser et un cran de molette posés dans la boîte d'une pièce, **hors de ses éléments**, atteignent un `GestureDetector` témoin dessous.
- Intrinsèques lisibles sans erreur pour les trois.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): bloc de lecture en trois pièces, une seule carte (B1 d'Ergonomie)`.

---

## Lot 4 — La disposition

### Task D1 : `MapLayout`, le `RenderObject` de la carte visible

**Agent :** **raisonnement** (opus, effort élevé).
**Prérequis :** `S5`, `S6`.
**Files:** créés `lib/features/map/view/map_layout.dart`, `test/features/map/view/map_layout_test.dart`

**Interfaces :**
- `enum MapLayoutSlot { blockFixed, blockNotices, blockLegend, bottom, band, reticle, sheet }`
- `final class MapLayoutReport { const MapLayoutReport({required Rect visible, required Rect? reticle, required MapLayoutAllocation allocation}); }` (égalité par valeur)
- `class MapLayout extends MultiChildRenderObjectWidget` — enfants enveloppés de `MapLayoutChild(slot:, child:)` (`ParentDataWidget`) ; paramètres `double padding`, `EdgeInsets safeInsets`, `double reticleBandHeight`, `ValueNotifier<MapLayoutReport?> report`.
- `class RenderMapLayout extends RenderBox` (`ContainerRenderObjectMixin`) :
  1. largeur : `mapLayoutWidthFor(size.width)` ;
  2. **fiche ouverte** si l'enfant `sheet` a une hauteur intrinsèque maximale non nulle (les panneaux fermés valent `SizedBox.shrink`) — aucun paramètre ne la dit ;
  3. panel, fiche ouverte : fiche posée en `tight(mapSidePanelWidth, hauteur)` à droite ; carte visible à sa gauche ; panel fermé ou autres largeurs : carte visible = toute la surface (moins la zone sûre) ;
  4. lit les intrinsèques des enfants aux largeurs de la carte visible, appelle `allocateMapLayout`, pose chaque enfant avec la hauteur allouée (la partie fixe, la bande et la fiche se replient d'elles-mêmes, note d'architecture) ;
  5. positions : partie fixe en haut (compact : pleine largeur moins 2 × `padding` ; sinon en haut à gauche, `min(480, carte visible − 2 × padding)`), avis puis légende dessous, même largeur ; bas : compact, rangée au bas de la carte visible, pleine largeur ; sinon colonne au bas à droite ; bande : compact, au-dessus de la rangée ; sinon au bas de la carte visible, à gauche de la colonne ; fiche du bas (compact, wide) : toute la largeur, au bas, bas et bande **au-dessus** d'elle ;
  6. réticule : centre horizontal de la carte visible ; vertical au milieu de [bas de la partie fixe ; haut de la bande] — **il ne dépend ni des avis ni de la légende** ;
  7. `bandWithdrawn` : bande et réticule posés à taille nulle, **ni peints ni touchables** ;
  8. après la trame, publie `MapLayoutReport` dans `report` s'il a changé (`addPostFrameCallback`).
- Hit-test : chaque enfant ne prend un geste que sur ses éléments (les pièces le font déjà) ; ailleurs, la carte dessous le reçoit.

**Cas de test** (`testWidgetsOnWindows` ; enfants de test à intrinsèques connues — un `_Stub(min, max)` ; sur le modèle de `map_overlays_layout_test.dart`)
- Compact, sans fiche, hors mode : partie fixe en haut à 8 px des bords ; rangée collée en bas ; avis puis légende entre les deux.
- Panel, fiche ouverte : fiche de 380 à droite, pleine hauteur ; tout le reste dans les `largeur − 380` de gauche, sans recouper la fiche ; panel, fiches fermées : rien n'est réservé à droite.
- Compact, fiche ouverte, en mode : partie fixe, bande du réticule, bande et rangée au-dessus de la fiche ; réticule entre la partie fixe et la bande.
- **Le réticule ne bouge pas** quand seule la hauteur des avis ou de la légende change (Review Focus 2, côté mise en page).
- `bandWithdrawn` : un tap sur l'emplacement de la bande atteint la carte témoin ; le rapport dit `reticle == null`.
- Le rapport est publié une fois par changement, jamais pendant la mise en page (aucune erreur « setState during layout »).
- `safeInsets = margeSystemeTelephone` : rien ne se pose dans les marges.
- `taillesEnDeca` : aucune taille négative, aucune erreur ; `overflows` vrai → la partie fixe reçoit le reste.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): mise en page de la carte visible, trois largeurs, replis répartis (D1 d'Ergonomie)`.

### Task D2 : La nouvelle disposition branchée ; les mesures de l'ancienne remplacées

**Agent :** **raisonnement** (opus, effort élevé) — `map_view.dart` (2 668 lignes) et le remplacement de quatre fichiers de mesure.
**Prérequis :** `B1`, `D1`, `S4`.
**Files:** modifiés `lib/features/map/view/map_view.dart`, `lib/features/map/view/map_reading_selector.dart` (reçoit `mapDesignationChipKey` et `designationChipLabel`), `lib/diagnostics/fluidity_probe_panel.dart` (si son panneau, posé en bas à gauche, `fluidity_probe_panel.dart:133-141`, recoupe le bloc ou la rangée : posé au-dessus du bas de la carte visible), `test/features/map/view/map_view_test.dart` (groupes de disposition retirés, « Tests remplacés »), `test/features/map/view/map_designation_test.dart`, `test/features/map/view/map_keyboard_test.dart`, `test/features/map/view/map_view_flood_test.dart`, `test/diagnostics/fluidity_probe_panel_test.dart`, `test/main_test.dart` (import de `map_scale_chips.dart`, l. 71, vers le sélecteur), `test/project/acceptance_features_test.dart` (imports), `docs/tracabilite.md` (lignes `US-02`, `US-07`, `US-21`, `BR-008` : les fichiers supprimés remplacés par `map_reading_selector_test.dart` et `map_layout_invariants_test.dart`), `test/project/tracabilite_test.dart` (constantes `_puceRestrictions`, `_surcouchesTelephone`, l. 124-127, et leurs usages, l. 231, 289-291) ; **supprimés** `lib/features/map/view/map_scale_chips.dart`, `lib/features/map/view/map_overlays_layout.dart`, `test/features/map/view/map_scale_chips_test.dart`, `test/features/map/view/map_overlays_phone_test.dart`, `test/features/map/view/map_sheet_height_test.dart`, `test/features/map/view/map_entry_buttons_overlap_test.dart`, `test/features/map/view/map_overlays_layout_test.dart` ; créé `test/features/map/view/map_layout_invariants_test.dart` ; `docs/04-ui.md` (§ 1 : croquis neuf de la carte aux trois largeurs, « fait foi » ; les amendements de mesures de l'ancienne disposition « remplacés, gardés pour mémoire », R17 ; § 4 et § 5 : place du contrôle « ⚠ Avertissement » de la carte) ; `docs/acceptance/avertissements.feature`, `filtres.feature`, `restrictions.feature` (scénarios des critères 1, 3, 4, 7, 8 de la spec)

**Interfaces :**
- `buildMapOverlays` garde **tous** ses paramètres (dont `sheetScrollController`, que `D5` déplacera) et gagne `ValueNotifier<MapLayoutReport?> layoutReport` ; elle rend une liste à poser dans le `Stack` de la carte, dont **un** `MapLayout(padding: 8, safeInsets: MediaQuery.paddingOf(context), reticleBandHeight: mapCenterReticleSize + 2 × 8, report: layoutReport)` portant :
  - `blockFixed` : `MapReadingBlockFixed(selector: MapReadingSelector(…), header: MapLegendHeader(warningLink: <le WarningLink de la carte, sous FocusTraversalOrder(mapTraversalOrderWarningLink), extraText inchangé>))` ;
  - `blockNotices` : `MapReadingBlockNotices(notices: <mapNoticesFor(...) bâtis par buildMapNotice>)` ;
  - `blockLegend` : `MapReadingBlockLegend(legend: MapLegend(inBlock: true, …))` ;
  - `bottom` : compact, `Row[MapEntryButtons(axis: horizontal), Spacer, MapControls(axis: horizontal)]` puis `IgnAttributionBadge` ; sinon la colonne actuelle ; ordres de tabulation inchangés ;
  - `band` (en mode) : `DesignationBand`, sous `FocusTraversalOrder(mapTraversalOrderDesignate)` ;
  - `reticle` (en mode) : `MapCenterReticle` ;
  - `sheet` : **provisoirement**, la zone actuelle — les panneaux empilés dans `NoMinIntrinsicHeight(SingleChildScrollView(controller: sheetScrollController, …))`, fond blanc pleine largeur (fiche du bas, contenu centré dans `readingColumnWidth` au plus, R18) ou panneau de 380 (filet `#C9CFC4` à gauche, toute la hauteur) ; `D5` remplace ce défilement de zone par celui de chaque cadre.
- `_MapViewState` tient le `ValueNotifier<MapLayoutReport?>` (champ, disposé avec l'état).
- **Carte immobile** : aucun `move` ni `fitCamera` à l'ouverture ou à la fermeture d'une fiche.

**Tests remplacés (R15)** — `map_layout_invariants_test.dart`, en Roboto (`chargerRoboto`), sur la vraie `buildMapOverlays` dans un `Stack` avec une carte témoin (et sur la vraie `MapView` pour les gestes), matrice `taillesGaranties × echellesDeTexte × {écoulement, débit, crues} × {hors mode, en mode} × {sans fiche, fiche station de Blois, fiche tronçon} × {sans avis, avis d'absence} × {sans marge, margeSystemeTelephone au téléphone}` :
- **I-a** le sélecteur entier dans l'écran, le centre de chaque entrée atteignable (hit-test) ;
- **I-b** le « ⚠ Avertissement » de la carte entier et atteignable ;
- **I-c** en mode, le réticule entier, rien de peint par-dessus ; le bouton atteignable — sauf quand le rapport dit `bandWithdrawn` : bande et réticule ni peints ni touchables ;
- **I-d** l'entrée « Restrictions » atteignable ;
- **I-e** la fiche ne recoupe ni le bloc ni le bas (l'en-tête épinglé s'ajoute en `D5`) ;
- **I-f** aucune erreur de rendu ;
- **I-g** les replis joués (`MapLayoutReport.allocation.folds`) sont ceux que `allocateMapLayout(await mesurerPieces(...))` rend pour cette configuration (`test/support/ergonomie_mesures.dart`, `S6`) ;
- **I-h** (avec avis) l'action de l'avis atteignable, au besoin après défilement des avis ;
- **I-i** gestes : un tap, un glisser, un cran de molette posés sur la carte visible hors des pièces atteignent la carte (vraie `MapView`, sur le modèle de `map_designation_test.dart:951-1130`, rejoués sur la nouvelle disposition) ;
- **Review Focus 3** : à 360 × 640, fiche station ouverte, échelle de texte 2 → 1 → 2 : pas d'erreur, la fiche reste ouverte, les sous-titres reviennent puis repartent selon `allocateMapLayout`, le rapport ne change qu'une fois par changement d'échelle (aucun va-et-vient).
- **Forme des tests** : un test par configuration, qui affirme I-a à I-h ; I-i dans des tests à part. **Décompte** : recopier le nombre de tests avant et après ; s'il baisse, découper les cas par invariant jusqu'à ce qu'il ne baisse plus — avant le commit.

**Cas de test conservés et adaptés** : `map_view_test` (groupes non listés), `map_designation_test` (gestes, coordonnées, caméra, redimensionnement, épingle), `map_keyboard_test` (raccourcis, Échap), `map_view_flood_test`, `fluidity_probe_panel_test` (aucune paire de surcouches ne se recoupe), `main_test` — adaptés aux nouvelles positions, **aucune assertion de comportement retirée**.

- [ ] **Étape 1** — tests d'invariants rouges sur l'ancienne disposition, sortie recopiée (nombre de rouges par invariant) ; **Étape 2** — brancher, supprimer, adapter ; **Étape 3** — critère de fin, décompte avant / après recopié, commit `feat(map): bloc de lecture, fiche du bas et panneau latéral ; mesures de l'ancienne disposition remplacées par des invariants (D2 d'Ergonomie)`.

---

## Lot 5 — Les fiches dans le cadre commun

> Après `D2` : la zone des fiches est encore celle d'avant (elle défile elle-même), les cadres y sont posés sous une hauteur non bornée (`S3` le permet) ; les invariants de `D2` restent verts quelle que soit la hauteur des fiches. L'en-tête épinglé ne se voit sur la carte qu'après `D5`.

### Task F1 : Fiche station hiérarchisée

**Agent :** **raisonnement** (opus, effort moyen) — deux tuiles qui décident côte à côte ou l'une sous l'autre, intrinsèques comprises.
**Prérequis :** `S3`, `D2`.
**Files:** modifiés `lib/features/station_sheet/view/station_summary_sheet.dart`, `test/features/station_sheet/view/station_summary_sheet_test.dart`, `docs/acceptance/fiche-station.feature`, `test/project/acceptance_features_test.dart`, `docs/04-ui.md` (section « Fiche station hydrométrique » : croquis neuf « fait foi », l'ancien « remplacé, gardé pour mémoire », R17)

**Interfaces :**
- `String stationSheetNature(StationCode code) => 'Station hydrométrique · ${code.value}';` · `const String stationStatusLabel = "Statut (Hub'Eau)";` · `const String stationQualificationLabel = "Qualification (Hub'Eau)";` · `const Key stationDischargeTileKey = Key('station-discharge-tile');` · `const Key stationLevelTileKey = Key('station-level-tile');`
- `StationSheetPanel` (constructeur inchangé, plus `ScrollController? bodyScrollController`) : chaque état visible — `EnCours`, `Prete`, `EnEchec`, `Introuvable` — dans `SheetFrame(nature: stationSheetNature(code), closeButtonKey: stationSheetCloseButtonKey, onClose:, favoriteStar:, onToggleFavorite:, bodyScrollController:, warningExtraText:, body:)` ; `warningExtraText` : la phrase datée existante en `Prete`, `null` sinon — **« ⚠ Avertissement » est désormais présent aussi en chargement, en échec et introuvable** (`PD7`) ; textes des états inchangés, dans le corps. `_frame` et `_CloseButton` locaux disparaissent.
- Corps de `Prete`, dans l'ordre : titre (`data.station.label`, 20, gras) ; « `<riverLabel ?? coursDEauNonRenseigne>` · Département `<code>` » ; **tuiles** Débit (`stationDischargeTileKey`) puis Hauteur (`stationLevelTileKey`) — chacune : libellé (12, gras), valeur (Débit 26, Hauteur 20, gras, chiffres tabulaires), « mesuré(e) le JJ/MM/AAAA à HH:MM », `hydrometrieSourceName` ; valeur absente : libellé puis `valeurNonTransmise` ; **chaque tuile est un seul nœud d'annonce** (`MergeSemantics`) qui dit libellé, valeur, date et source — c'est ce qui remplace le verrou « valeur, date et source dans un seul `Text` » (`station_summary_sheet.dart:270`, tests l. 222, 243, 289 ; `BR-001`, point 32 clos) ; **côte à côte** quand chacune tient dans la moitié de la largeur sans couper un mot (largeur intrinsèque minimale), l'une sous l'autre sinon (`PD13`, au lieu d'un seuil) ; puis `stationStatusLabel` / valeur et `stationQualificationLabel` / valeur (valeurs et replis existants) ; puis l'avis de fraîcheur (inchangé).

**Cas de test** (`testWidgetsOnWindows` ; `testWidgetsOnAndroid` à 344 et 200 %)
- Ordre : nature < « ⚠ Avertissement » < titre < ligne cours d'eau · département < tuile Débit < tuile Hauteur < statut < qualification < avis de fraîcheur.
- Nature exacte « Station hydrométrique · <code de la donnée de test> » dans les **quatre** états visibles ; « ⚠ Avertissement » présent dans les quatre (phrase datée en `Prete` seulement).
- Tuile Débit : la valeur, la date et la source de la donnée de test existante (`station_summary_sheet_test.dart:35`, affichée selon `utcOffsetOf`) — l'annonce de la tuile les contient toutes trois ; Hauteur absente → « Hauteur » puis `valeurNonTransmise`.
- Disposition des tuiles : à 760, côte à côte ; à 344 et 200 %, l'une sous l'autre ; à 356 (panneau de 380 moins ses marges) et 100 %, celle que la règle donne, calculée dans le test par les largeurs intrinsèques ; aucun mot coupé.
- « Statut (Hub'Eau) » au-dessus de « Pré-validée ».
- Les tests existants sur l'étoile, la fermeture, `Échap`, l'avis d'écriture restent verts, adaptés.
- `acceptance_features_test` : `stationStatusLabel`, `stationQualificationLabel` cités par `fiche-station.feature` (scénario du critère 11).

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(ui): fiche station dans le cadre commun, débit puis hauteur en tuiles (F1 d'Ergonomie)`.

### Task F2 : Fiche ONDE hiérarchisée, symbole fourni

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `S3`, `D2`.
**Files:** modifiés `lib/features/onde_sheet/view/onde_summary_sheet.dart`, `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `docs/acceptance/ecoulement-onde.feature`, `test/project/acceptance_features_test.dart`, `docs/04-ui.md` (section « Fiche point ONDE », R17)

**Interfaces :**
- `const String ondeSheetNature = 'Point ONDE';`
- `typedef OndeCategorySymbol = Widget Function(FlowCategory category, {required bool compact});` — la fiche ne dessine aucun symbole : il lui est **fourni** (`PD8`, R13 ; la règle `feature-vers-feature` interdit d'importer `onde_marker.dart`).
- `OndeSheetPanel` gagne `OndeCategorySymbol? categorySymbol` et `ScrollController? bodyScrollController` ; chaque état visible — `OndeSheetEnCours`, `OndeSheetPrete`, `OndeSheetEnEchec` — dans `SheetFrame(nature: ondeSheetNature, closeButtonKey: ondeSheetCloseButtonKey, …)` ; « ⚠ Avertissement » dans les trois (phrase datée en `Prete` seulement).
- Corps de `Prete`, dans l'ordre : titre ; « `<waterCourseLabel ?? ondeCoursDEauNonRenseigne>` · `<'Département ' + code | ondeDepartementNonRenseigne>` » (la logique actuelle, `onde_summary_sheet.dart:179-183`) ; **tuile** : `categorySymbol?.call(category, compact: false)` puis la catégorie (22, gras), la phrase de `NonObserve`, la modalité, la ligne de campagne (textes existants) — sans campagne, `officialModalityText` seul ; « Campagnes précédentes » : par campagne, `categorySymbol?.call(category, compact: true)`, la date, la catégorie (contenu inchangé, la dernière en tête, cinq au plus) ; le rappel de rythme.
- Sans `categorySymbol` : aucun symbole, aucune erreur.

**Cas de test** (`testWidgetsOnWindows` ; un `testWidgetsOnAndroid` à 344 et 200 %)
- Avec un symbole de test (`SizedBox(key: ValueKey('symbole-${category.runtimeType}-$compact'))`) : un non compact avant la catégorie dans la tuile ; un compact par ligne d'historique, sur la ligne de sa date. Sans : mêmes textes, même ordre.
- Ordre : nature < « ⚠ Avertissement » < titre < ligne cours d'eau · département < catégorie < modalité < campagne < « Campagnes précédentes » < rappel.
- Nature « Point ONDE » dans les trois états visibles ; aucun code affiché (arbitrage 5).
- `acceptance_features_test` : `ondeSheetNature` cité par `ecoulement-onde.feature` (scénario du critère 12).

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(ui): fiche ONDE dans le cadre commun, catégorie et historique à symboles (F2 d'Ergonomie)`.

### Task F3 : Fiche tronçon dans le cadre commun

**Agent :** mécanique (sonnet, effort léger).
**Prérequis :** `S3`, `D2`.
**Files:** modifiés `lib/features/flood_sheet/view/flood_sheet_panel.dart`, `test/features/flood_sheet/view/flood_sheet_panel_test.dart`, `docs/04-ui.md` (section « Fiche tronçon Vigicrues », R17), `docs/acceptance/crues.feature` (scénario du critère 13), `test/project/acceptance_features_test.dart` (`floodSheetNature`)

**Interfaces :**
- `const String floodSheetNature = 'Tronçon $floodSourceName';` (le texte existant, `flood_sheet_panel.dart:97`, nommé)
- `FloodSheetPanel` gagne `ScrollController? bodyScrollController` ; `FicheTronconOuverte` dans `SheetFrame(nature: floodSheetNature, closeButtonKey: floodSheetCloseButtonKey, warningExtraText: floodWarningWindowText, onClose:, bodyScrollController:, body:)`, **sans étoile** (T5). Corps : nom publié, encart de crue, niveau, citations, date, bulletin, adresse, avis de lien — **ordre de T4 inchangé**.

**Cas de test** (`testWidgetsOnWindows`)
- Ordre : nature < « ⚠ Avertissement » < nom < encart < niveau < citation < date < bouton (le test existant « nom < encart < … » reste vrai ; « ⚠ Avertissement » passe avant le nom, R12).
- Aucune étoile ; fermeture par `floodSheetCloseButtonKey`.
- `crues.feature:59` reste vrai, inchangé.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(ui): fiche tronçon dans le cadre commun (F3 d'Ergonomie)`.

---

## Lot 6 — Le mode, la caméra, la composition

### Task D3 : Le mode « Restrictions » : réticule, désignation, zoom, repli 6

**Agent :** **raisonnement** (opus, effort élevé).
**Prérequis :** `D2`.
**Files:** modifiés `lib/features/map/view/map_view.dart`, `test/features/map/view/map_designation_test.dart`, `test/features/map/view/map_layout_invariants_test.dart`, `docs/04-ui.md` (§ 3, ligne « Désignation d'un point » : réticule au centre de la carte visible, zoom autour de lui, replis 5 et 6), `docs/acceptance/restrictions.feature` (scénarios des critères 5 et 6)

**Interfaces :**
- `_handleDesignateCenter` : `_designate(_mapController.camera.screenOffsetToLatLng(report.reticle!.center))` — **le point sous le réticule**, plus `camera.center` ; le rectangle vient de `MapLayoutReport.reticle`, dans le repère du `Stack`, qui est celui du widget `FlutterMap`.
- En mode, réticule présent : `_handleZoomIn` / `_handleZoomOut` → `move(camera.focusedZoomCenter(report.reticle!.center, z), z)` avec `z = camera.zoom ± zoomStep` ; réticule retiré ou hors mode : la règle de `D4`.
- **Repli 6** : quand le rapport dit `bandWithdrawn`, `buildMapOverlays` enveloppe la bande de `ExcludeFocus` et `ExcludeSemantics` (elle reste dans l'arbre, `D1` ne la peint ni ne la touche) ; la puce « Restrictions » reste allumée ; `onLongPress` et `onSecondaryTap` désignent comme aujourd'hui.

**Cas de test** (`map_designation_test`, `testWidgetsOnWindows` et `testWidgetsOnAndroid`)
- Fiche du bas ouverte, en mode, à une configuration où le repli 6 ne joue pas (d'après `allocateMapLayout` sur les mesures de `S6`) : le bouton désigne `screenOffsetToLatLng(centre du réticule)`, **différent** de `camera.center` ; panneau ouvert à 800 × 740 : idem.
- En mode, `+` puis `−` : le point sous le réticule est le même avant et après (à 1e-6 près).
- **Review Focus 2** : en mode, faire paraître l'avis d'absence puis `FloodLoading` → `report.reticle` inchangé ; désigner donne le même point.
- **Review Focus 4** : à une configuration où le repli 6 joue (attendue : 360 × 640, 200 %, fiche station) : ni bande ni réticule à l'écran ; Tab ne s'arrête pas sur le bouton ; appui long → `onPointDesignated` au point sous le doigt ; fermer la fiche → bande et réticule reviennent ; « Restrictions » toujours `toggled`.
- La bande ne monte jamais sur la partie fixe du bloc, à 360 × 300 et 200 % compris (point 63).

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): le réticule au centre de la carte visible, désignation et zoom autour de lui (D3 d'Ergonomie)`.

### Task D4 : La caméra et la partie cachée

**Agent :** **raisonnement** (opus, effort moyen).
**Prérequis :** `D3`.
**Files:** modifiés `lib/features/map/view/map_view.dart`, `test/features/map/view/map_view_test.dart` (groupes « boutons de zoom (K1) », « sélection d'une pastille »), `test/features/map/view/map_designation_test.dart` (groupe « redimensionner la fenêtre »), `docs/acceptance/fiche-station.feature` (scénario du critère 9)

**Interfaces :**
- `EdgeInsets _hiddenInsets()` : la part de la carte que la fiche couvre, lue sur `MapLayoutReport.visible` — `EdgeInsets.fromLTRB(visible.left, visible.top, largeur − visible.right, hauteur − visible.bottom)` ; sans fiche, `EdgeInsets.zero` (la zone sûre n'y entre pas : la carte va jusqu'aux bords).
- `_handleRecenter` : `fitCamera(CameraFit.coordinates(coordinates: <LatLng(initialMapCenterLatitude, initialMapCenterLongitude)>, padding: _hiddenInsets(), minZoom: initialMapZoom, maxZoom: initialMapZoom))` — sans fiche, même résultat qu'aujourd'hui.
- `_handleClusterSelect` : `CoverBounds` → `CameraFit.bounds(…, padding: _hiddenInsets())` ; `CentreOn` → le centre visé posé au centre de la carte visible (comme le recentrage).
- Zoom **hors mode** (ou réticule retiré) : `move(camera.focusedZoomCenter(visible.center, z), z)` — sans fiche, `visible.center` est le centre de la carte : même résultat qu'aujourd'hui (arbitrage 12 : « zoomer tient compte de la partie cachée »).

**Cas de test**
- Recentrer et zoomer sans fiche : centre et zoom identiques à aujourd'hui (tests existants de `K1`).
- Recentrer avec le panneau ouvert à 1 280 × 740 : `(46.6, 2.2)` au centre de la carte visible (à 1e-3 près), zoom 5 ; `+` avec la fiche du bas ouverte : le point au centre de la carte visible est le même avant et après.
- Pastille sélectionnée avec la fiche du bas ouverte : l'emprise des membres est dans la carte visible.
- **Critère 9** : ouvrir, faire défiler et fermer une fiche → aucun appel de plus aux dépôts à compteur et aucun `MapEventMove`.
- **Review Focus 1** : à 1 280 × 740, fiche station ouverte et défilée, réduire la fenêtre à 760 de large puis la rétablir : la fiche reste ouverte (panneau → fiche du bas → panneau), aucun appel de plus aux dépôts, aucune erreur de rendu.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(map): recentrer, zoomer et cadrer dans la carte visible ; la carte ne bouge pas sous une fiche (D4 d'Ergonomie)`.

### Task D5 : La composition ; les corps de fiche défilent, l'en-tête s'épingle

**Agent :** **raisonnement** (opus, effort moyen).
**Prérequis :** `D4`, `F1`, `F2`, `F3`.
**Files:** modifiés `lib/main.dart`, `lib/features/map/view/map_view.dart`, `test/main_test.dart`, `test/features/map/view/map_view_flood_test.dart` (l. 215, 239, 626-636 : le test de l'identité du contrôleur de la zone **remplacé** par celui du contrôleur du corps, R15), `test/features/map/view/map_layout_invariants_test.dart` (I-e : l'en-tête de la fiche entier dans l'écran, à toutes les configurations), `docs/acceptance/fiche-station.feature` (scénario du critère 10)

**Interfaces :**
- `MapView.sheetScrollController` et le paramètre de même nom de `buildMapOverlays` **retirés** ; l'emplacement `sheet` porte les panneaux sans défilement de zone ni `NoMinIntrinsicHeight` (chaque cadre défile son corps et annonce son en-tête en hauteur minimale).
- `_sheetScrollController` (`main.dart:322`) passe aux **trois panneaux** (`bodyScrollController:`) ; sa remise à zéro à chaque ouverture (`_showSheetFromTop`, `main.dart:470-474`, `K4` de T3) vise désormais le corps.
- `OndeSheetPanel(categorySymbol: (FlowCategory category, {required bool compact}) => ExcludeSemantics(child: OndeMarkerShape(category: category, age: CampaignAge.recente, observedAt: null, compact: compact)))` — en grand le symbole de la carte, en petit celui de la légende (`PD8`).

**Cas de test** (`test/main_test.dart`, composition réelle)
- Groupe « une fiche s'ouvre par le haut (K4 de T3) » (l. 538) : les huit tests passent, la position mesurée étant celle du **corps** (`sheetFrameBodyKey`, au lieu de `ancestor(of: StationSheetPanel, matching: Scrollable)`, l. 588) ; l'en-tête reste en place quand le corps défile.
- Fiche ONDE ouverte : un `OndeMarkerShape` dans la tuile, un par ligne d'historique.
- Les groupes `F4 de T4` (exclusivité, lecture Crues), « Favoris », « écran des restrictions (E3) » passent, adaptés.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit `feat(ui): composition — les corps de fiche défilent sous leur en-tête, symbole d'écoulement fourni (D5 d'Ergonomie)`.

---

## Lot 7 — Clavier et tailles en deçà

### Task I1 : Ordre de tabulation, focus amené en vue, tailles en deçà

**Agent :** **raisonnement** (opus, effort moyen).
**Prérequis :** `D5`.
**Files:** modifiés `test/features/map/view/map_keyboard_test.dart`, `test/features/map/view/map_layout_invariants_test.dart` ; le code de `lib/features/map/view/` ou de `lib/features/shared/sheet_frame.dart` **seulement si** un test le montre nécessaire

**Cas de test**
- **Ordre `K1` de T3 gardé** (R9), aux trois largeurs : entrées du sélecteur (quatre) → action de l'avis s'il en porte une → « Favoris » → « Filtres » → zoom et recentrer (rangée : `−`, `+`, recentrer ; colonne : `+`, `−`, recentrer) → bouton de désignation (en mode, non retiré) → carte → fiche ouverte → « ⚠ Avertissement » de la carte, en dernier. Constantes `mapTraversalOrder*` (`map_view.dart:273-317`) inchangées.
- **Review Focus 5** : fiche station défilée au bout, Tab jusqu'à l'étoile puis dans le corps : chaque contrôle focalisé est entier dans la fenêtre du corps, pas sous l'en-tête.
- **En deçà** (`taillesEnDeca`, 200 %, hors mode et en mode) : « ⚠ Avertissement » et l'entrée « Restrictions » atteignables — par un glisser sur le bloc, et au clavier (le focus les amène en vue) ; aucune erreur de rendu ; 844 × 390 passe en panneau latéral (R20).
- `Échap` ferme la fiche ouverte, aux trois largeurs.

**Règle** : un écart **nouveau** est un constat remonté au commanditaire, avec la mesure ; il ne se corrige pas par une disposition inventée.

- [ ] **Étape 1** — tests rouges éventuels, sortie recopiée ; **Étape 2** — corriger ce qui relève de la tâche, remonter le reste ; **Étape 3** — critère de fin, commit `test(map): clavier, focus amené en vue et tailles en deçà sur la nouvelle disposition (I1 d'Ergonomie)`.

---

## Lot 8 — Le bouton « Retour » (point 51)

### Task L1 : `flutter_localizations`, locale française

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `D5` (`main.dart` et `main_test.dart` partagés).
**Files:** modifiés `pubspec.yaml` (`flutter_localizations: sdk: flutter` sous `dependencies`), `pubspec.lock` (régénéré par `flutter pub get`, committé tel que 3.47.7 le résout), `lib/main.dart` (`MaterialApp` : `localizationsDelegates: GlobalMaterialLocalizations.delegates` — Material, Widgets, Cupertino —, `supportedLocales: const <Locale>[Locale('fr')]`, `locale: const Locale('fr')`), `test/main_test.dart`, `test/features/shared/screen_layout_test.dart`, `docs/acceptance/restrictions.feature` (scénario du critère 14 : « le bouton de retour s'annonce « Retour » »), `test/project/acceptance_features_test.dart` (si la phrase est liée à une constante), `CLAUDE.md` (stack : ligne « Localisation » — `flutter_localizations`, locale `fr`, SDK)

**Cas de test**
- `main_test` : « Favoris » ouvert depuis la carte → le `BackButton` de `ScreenTitleBar` a l'info-bulle **« Retour »** ; l'écran des restrictions de même.
- `screen_layout_test` : `ScreenTitleBar` dans un `MaterialApp(locale: fr, delegates)` → « Retour » ; sans délégués → « Back » (caractérise la cause).
- Relever par `grep` dans `test/` les textes intégrés de Material cherchés en anglais (`'Back'`, `'Close'`, `'Copy'`, `'Select all'`, `'Dismiss'`…) : aucun « Back » le 2026-10-17 ; tout autre trouvé est adapté et nommé dans le message de commit.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — `flutter pub get`, implémenter ; **Étape 3** — critère de fin, commit `feat(ui): textes intégrés de Material en français, « Retour » (L1 d'Ergonomie)`.

---

## Lot 9 — Documents

### Task X1 : Documents de la tranche remis d'accord avec le code

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `I1`, `L1`.
**Files:** modifiés `docs/04-ui.md` (relecture d'ensemble : ce qu'`I1` a changé), `docs/03-conception.md` (arbre des écrans : sélecteur, bloc, fiche du bas, panneau latéral), `CLAUDE.md` (« Disposition du dépôt » : `map_reading_selector.dart`, `map_reading_block.dart`, `map_layout.dart`, `map_layout_allocation.dart`, plus de `map_overlays_layout.dart` ni de `map_scale_chips.dart` ; invariant « Un widget partagé… » : `sheet_frame.dart` (`SheetFrame`, `NoMinIntrinsicHeight`) ajouté à la liste ; stack, ligne « Tests » : les fichiers qui mesurent en Roboto deviennent `ergonomie_budget_test.dart`, `map_layout_invariants_test.dart`, `map_reading_block_test.dart`, `restrictions_scale_text_test.dart`, par `test/support/roboto.dart`), `docs/project-state.md` (décompte des tests, seul endroit où il s'écrit ; « Réserve durable sur les polices de mesure » : la nouvelle liste), `docs/tracabilite.md` et `test/project/tracabilite_test.dart` (si `I1` ou `L1` ont ajouté un fichier de test à citer), `docs/README.md` (le plan), `CHANGELOG.md` (« Modifié » de `0.6.0`, écrit en une fois d'après le code livré)

- [ ] **Étape 1** — `flutter test test/project` vert avant ; écrire ; **Étape 2** — vert après ; **Étape 3** — critère de fin, commit `docs: documents de la tranche d'ergonomie remis d'accord avec le code (X1 d'Ergonomie)`.

---

## Lot 10 — La porte, sur Windows **et** Android

### Task P1 : L'exécutable Windows de `0.6.0`, lancé hors Flutter (commanditaire)

**Prérequis :** `X1`.

```bash
flutter build windows --release
```

Attendu : `Built build\windows\x64\runner\Release\martinpecheur.exe`. Puis lancer cet exécutable **hors Flutter** (double-clic). La boucle principale relève poids et nombre de fichiers du dossier (`NFR-06`).

**Constats** (spec § 10), dictés par identifiant et recopiés mot pour mot : `a` à `j` côté Windows — à la taille du lancement puis réduite à 800 × 740, texte à 100 % puis 200 % (Paramètres › Accessibilité › Taille du texte, **réglage fait par le commanditaire**) ; `h` : relever la zone cliente au lancement (attendue 1 280 × 740 à 100 %, PR #24) ; `i` : Narrateur sur le bouton de retour (« Retour »).

### Task P2 : Android, émulateur `Pixel_7` (commanditaire)

**Prérequis :** `P1`.

```bash
flutter emulators --launch Pixel_7
```

```bash
flutter run -d emulator-5554
```

Attendu : construction et lancement sur l'émulateur. **Constats** `a` à `g` et `j` côté Android, police à 100 % puis 200 % ; `g` en écran divisé ; relever la marge système réelle (barre d'état, barre de navigation) et la comparer à `margeSystemeTelephone` (`PD10`).

### Task P3 : Clore la version `0.6.0`

**Agent :** mécanique (sonnet, effort léger).
**Prérequis :** `P1`, `P2`.
**Files:** `CHANGELOG.md` (`## [0.6.0] — <date>`, « Constaté à l'exécution » d'après les constats recopiés, « Non vérifié » d'après ce qui n'a pas été dit), `test/project/changelog_test.dart`, `docs/project-state.md` (ligne « Ergonomie » ; points 49, 51, 60, 61, 63, 64 clos ou restés, selon les constats ; constats rendus sans objet, R16, listés un à un ; « Prochaine étape » : le plan de T5), `CLAUDE.md` (ligne « Ergonomie » du tableau « Où on en est » seulement)

- [ ] Tests du `CHANGELOG` rouges, sortie recopiée ; écrire ; critère de fin ; commit. **Aucun tag, aucune poussée, aucune fusion sans demande.**

---

## Décisions à valider avec le plan

### Au commanditaire — arbitrées le 2026-10-17

Les douze arbitrages de la spec (§ 2), ses textes d'écran (§ 11.2) et ses décisions réversibles (§ 11.3), approuvés avec elle.

### Prises par la boucle principale pour ce plan, réversibles

| # | Décision | Tâche |
|---|---|---|
| PD1 | ⚠️ **Écart à un texte arbitré** (arbitrage 10) : la taille Windows de test est **1 280 × 740**, non 1 280 × 720 — depuis la PR #24 (fusionnée le 2026-10-17), la fenêtre se lance à 1 280 × 740 de zone cliente et ne descend plus sous 740 px de haut : 1 280 × 720 ne peut plus se produire sous Windows | `S6`, `D2`, `P1` |
| PD2 | `map_reading_selector.dart` remplace `map_scale_chips.dart`, supprimé en `D2` ; `mapDesignationChipKey` et `designationChipLabel` gardent leur nom | `S1`, `D2` |
| PD3 | Titres et sous-titres des lectures à côté de `mapScaleLabel`, dans `map_scale.dart` ; « publiée par » interpole `floodSourceName` | `S1` |
| PD4 | Pictogrammes : `Icons.water_drop`, `Icons.timeline`, `Icons.waves`, `Icons.gavel` | `S1` |
| PD5 | Nombre de colonnes du sélecteur : le plus grand de 4, 2, 1 qui ne coupe aucun mot de titre (mesuré, sans seuil de largeur) | `S1` |
| PD6 | Rangées courtes de la légende dans un `Wrap` d'éléments de 156 px ; phrases longues pleine largeur | `S2` |
| PD7 | « ⚠ Avertissement » dans l'en-tête de chaque fiche **dans tous ses états** (aujourd'hui absent en chargement, en échec et « introuvable ») ; phrase datée seulement quand une date existe | `F1`, `F2` |
| PD8 | Le symbole d'écoulement est **fourni** à la fiche ONDE par `main.dart` (`OndeCategorySymbol`), en âge « récent » — en grand le symbole de la carte, en petit celui de la légende —, plutôt que déplacé sous `shared/` avec ses six emprunts à `station_marker.dart` | `F2`, `D5` |
| PD9 | Le contrôleur de défilement passe de `MapView` aux corps des fiches en `D5` ; jusque-là, la zone actuelle défile, enveloppée de `NoMinIntrinsicHeight` | `D2`, `D5` |
| PD10 | Marge système de téléphone mesurée : 24 en haut, 48 en bas ; constatée à la porte Android | `S6`, `P2` |
| PD11 | L'aide de chargement de Roboto, recopiée trois fois, passe dans `test/support/roboto.dart` | `S6` |
| PD12 | `S6` est une porte de faisabilité : un cas qui déborde après le repli 6 arrête la tranche avant `D1` | `S6` |
| PD13 | Tuiles de la fiche station côte à côte quand chacune tient dans la moitié de la largeur sans couper un mot (mesuré) ; chaque tuile, un seul nœud d'annonce, remplace le verrou « un seul `Text` » | `F1` |
| PD14 | Le bloc est posé en trois enfants (partie fixe, avis, légende), pour que la répartition distingue les replis 1 et 3 et connaisse la partie fixe avant de borner la fiche | `B1`, `D1` |
| PD15 | Les replis se décident sur des hauteurs intrinsèques mesurées, par `allocateMapLayout` ; aucun seuil de taille dans `lib/` ; la vue apprend le résultat par un rapport publié après la trame (note d'architecture) | `S5`, `D1`, `D3` |
| PD16 | Le critère 15 de la spec (aucun texte ne qualifie un débit) est tenu par `vocabulary_test.dart`, sans scénario Gherkin | — |
| PD17 | La largeur du bloc au téléphone est la largeur moins 2 × 8 (la marge des surcouches, `_overlayPadding`), non 2 × 12 comme la maquette : 344 à 360, 374 à 390 | `S1`, `S6`, `D1` |

## Récapitulatif

| Lot | Tâches | Agents |
|---|---|---|
| 0 — Préalable | `A0` | boucle principale, sur accord |
| 1 — Documents | `O1`, `O2` | sonnet |
| 2 — Pièces, allocation, mesure | `S1` (opus), `S2`, `S3`, `S4`, `S5` (opus), `S6` (opus) | — |
| 3 — Bloc de lecture | `B1` | sonnet |
| 4 — Disposition | `D1`, `D2` | opus |
| 5 — Fiches | `F1` (opus), `F2`, `F3` | — |
| 6 — Mode, caméra, composition | `D3`, `D4`, `D5` | opus |
| 7 — Clavier, en deçà | `I1` | opus |
| 8 — « Retour » | `L1` | sonnet |
| 9 — Documents | `X1` | sonnet |
| 10 — Porte | `P1`, `P2` (commanditaire), `P3` | — |

**24 tâches**, dont **2** lancées par le commanditaire (`P1`, `P2`, et les constats qu'elles portent) et **1** à faire sur son accord (`A0`).

## Ordre d'exécution

```
A0 → O1 → O2
S1 → S2          (map_legend.dart, tests de la carte) ; S3, S4, S5 en parallèle de S1–S2
S6               (après S1 à S5) — porte de faisabilité
B1               (après S1, S2, S6) ; D1 (après S5, S6)
D2               (après B1, D1, S4)
F1, F2, F3       (après S3, D2 ; en série : 04-ui.md, acceptance_features_test.dart)
D3 (après D2) → D4 → D5 (après D4, F1, F2, F3)
I1 (après D5) ; L1 (après D5)
X1 (après I1, L1) → P1 → P2 → P3
```

Parallélisme permis : `S3`, `S4`, `S5` avec `S1`–`S2` ; `B1` avec `D1` ; `F1`, `F2`, `F3` sur leurs fichiers (le `.feature`, `04-ui.md` et `acceptance_features_test.dart` en série) et avec `D3` (fichiers disjoints, sauf `04-ui.md` : en série). **Jamais** deux tâches qui touchent `map_view.dart`, `main.dart`, `main_test.dart`, `acceptance_features_test.dart` ou `04-ui.md` en même temps (tableau « Partages entre tâches »).

## Les choses à ne jamais faire dans ce plan

- Peindre une fiche par-dessus le bloc de lecture ou le bas de la carte ; déplacer la caméra à l'ouverture d'une fiche (arbitrage 12).
- Ôter le « ⚠ Avertissement » de la carte quand une fiche est ouverte (R4) ; changer un texte d'avertissement ou le modal du premier lancement.
- Supprimer un test « CONSTAT » sans son invariant de remplacement ; laisser baisser le décompte ; transformer un rouge des quatre tailles en nouveau « CONSTAT » (R15).
- Écrire un seuil de taille dans `lib/` pour décider d'un repli ; monter deux variantes d'une pièce pour la mesurer ; publier le rapport de mise en page pendant la mise en page ; inventer une disposition pour un écart nouveau au lieu de le remonter.
- Poser un `LayoutBuilder` ou un `ListView` dans ce que la mise en page interroge.
- Faire importer `features/map/` par la fiche ONDE ; recopier le symbole d'écoulement (R13).
- Ajouter une comparaison `==` sur `MapScaleKind` ; écrire `testWidgets(` nu ; ajouter une bibliothèque autre que `flutter_localizations`.
- Construire passerelles « … autour », position statistique dans la fiche station, ou quoi que ce soit de T5 (spec § 3, « Dehors »).
- Pousser, fusionner, taguer sans demande ; committer `windows/flutter/generated_plugin_registrant.h`.

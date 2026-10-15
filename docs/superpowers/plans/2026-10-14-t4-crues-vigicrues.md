# T4 — Crues : lire la vigilance publiée par Vigicrues — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** l'usager **lit, là où il regarde, la vigilance crues que l'État publie** — une quatrième lecture « Vigilance crues » qui trace les tronçons Vigicrues avec leur niveau écrit, et une fiche tronçon qui cite ce niveau tel que publié, daté, attribué, avec le lien du bulletin (`US-21`). Une panne, un chargement ou un niveau inconnu ne se lisent jamais comme du vert. Version `0.5.0`, porte franchie sur **Windows et Android**.

**Architecture:** feature-first + MVVM (`ADR-014`), amendée par l'arbitrage 7 : **deux ViewModels pour l'écran carte**. Un dossier de domaine nouveau, Dart pur, `lib/domain/floods/` (niveaux clos, tronçon, carte de vigilance datée, port `FloodVigilanceSource` et ses trois échecs, règles d'étiquette). Une implémentation sous `lib/data/floods/` (GeoJSON national, mapper seul point de conversion, cache de session de 30 min par `withCachePolicy`). Dans la tranche `map` : `MapScaleKind.crues` et un `FloodLayerViewModel`. Une tranche nouvelle, `lib/features/flood_sheet/{view,view_model}/`. Le partagé (style et jauge des niveaux, avis « lien non ouvert ») dans `lib/features/shared/`. `main.dart` reste la seule racine de composition. Aucune bibliothèque d'état, **aucune bibliothèque nouvelle**.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 · `flutter_map` 8.3.2 (`PolylineLayer`, `hitNotifier`, `StrokePattern`) · `package:http` (`JsonHttpClient` partagé) · cibles **Windows** et **Android** (émulateur `Pixel_7`) à la porte ; iOS configuré, jamais compilé.

**Spec:** [`docs/superpowers/specs/2026-10-14-cadrage-t4-design.md`](../specs/2026-10-14-cadrage-t4-design.md) — **approuvé par le commanditaire le 2026-10-14** (« oui tu écris le plan »), avec la retouche du texte de l'écran des sources (§ 12.2), puis complété le même jour par les arbitrages 11 (emprise et ancre par les segments) et 12 (rafraîchissement au geste suivant), rendus à la relecture de ce plan, et par la correction `D1` de `R15`. Ce plan l'applique, il ne le rediscute pas : périmètre (§ 3), treize arbitrages (§ 2), conception (§ 5 à § 8), critères (§ 10), constats (§ 11), textes (§ 12), décisions réversibles (§ 12.3), documents (§ 13). Faits de la source : [`docs/sources/vigicrues.md`](../../sources/vigicrues.md) (`VC-01` à `VC-13`). L'exécutant d'une tâche lit le cadrage **et** sa tâche.

⚠️ **Identifiants de tâche propres à ce plan.** `O1`, `K1`, `P1`… existent aussi dans les plans de T1 à T3. Hors de ce document (`project-state.md`, messages de commit), on écrit **`T4-O1`** ; dans le titre d'un commit, « (O1 de T4) ».

## Contraintes globales

Chaque tâche les porte, même quand elle ne les répète pas.

- **Aucune bibliothèque nouvelle.** `pubspec.yaml` ne change que de version (`O1`).
- **Les sept règles de couches** (`test/architecture/layers_test.dart`) et l'isolement du domaine (`domain_isolation_test.dart`) restent verts : `lib/domain/` Dart pur ; aucun fichier de `lib/features/` n'importe `lib/data/` ; une tranche n'importe pas une autre tranche ; un ViewModel n'importe aucun widget ; le partagé vit dans `lib/features/shared/` et n'importe aucune tranche ; `main.dart` compose.
- **L'application relaie, elle ne calcule rien** (`BR-015`) : aucun niveau, seuil, prévision ni risque de crue n'est déduit ; aucun texte, aucun enchaînement ne rapproche un débit, une hauteur ou un écoulement d'une crue.
- **Aucun seuil nouveau.** Le zoom 9 se lit par `MapViewModel.level == null` (niveau individuel, `individualMarkersFromZoom`, `lib/features/map/view_model/map_view_model.dart:87`), jamais recopié dans le domaine. 30 minutes et 20 secondes sont **une constante chacune**, sous `lib/data/floods/`, arbitrées (§ 2, arbitrage 6 ; R3) — un test écrit ses instants à partir d'elles, jamais « 30 min » en dur.
- **Vocabulaire de l'API confiné** (`ADR-016`, sur le modèle d'AR-1 d'`ADR-004`) : `InfoVigiCru`, `NivInfViCr`, `CdEntCru`, `DtHrInfoVigiCru`, `RefInfoVigiCru`, `lbentcru`, `cdensup_1`, le chemin `/services/` n'apparaissent, **commentaires compris**, que sous `lib/data/floods/` et dans `lib/main.dart`. Le nom affichable « Vigicrues », le site public et le gabarit du bulletin vivent dans `lib/domain/sources/source_names.dart` ; les textes les interpolent.
- **Textes d'écran : ceux du cadrage, § 12.2, mot pour mot**, vouvoiement, aucun verbe d'instruction sur un usage de l'eau, aucun mot de garantie (`BR-014`). **Citations de Vigicrues** (légendes, explications) : au caractère près, d'après la fixture `test/fixtures/vigicrues/accueil_legende_2026-10-14.html` (`VC-13`), apostrophe courbe d'« d’avoir » comprise. Un texte qui manque se demande, il ne s'invente pas.
- **On ne qualifie jamais un débit** (`BR-003`).
- **Nomenclatures closes** : `sealed class` + `switch` exhaustif sans `default`, une branche pour l'inconnu (`BR-011`). **Une comparaison `==` / `!=` sur `MapScaleKind` ne s'ajoute pas** : le compilateur ne la signale pas quand une valeur arrive ; écrire un `switch`.
- **Fixtures** : seules des réponses constatées vivent sous `test/fixtures/`. Les niveaux 2 à 4, jamais publiés le 2026-10-14 (`VC-04`), s'éprouvent par **des cas construits dans le fichier de test**, nommés tels (« cas construit, niveau jamais observé en production — `VC-04` »).
- **Tout test de widget nomme sa plateforme** : `testWidgetsOnWindows` ou `testWidgetsOnAndroid` (`test/support/`), jamais `testWidgets(` nu (verrou `test/project/widget_test_platform_test.dart`). Fenêtre de moins de 600 px de large → `testWidgetsOnAndroid`, titre « Android : … ».
- **Code et spec dans le même commit** : la règle, le Gherkin, `domain-model.md`, `glossary.md` que touche une tâche s'écrivent dans cette tâche, avec le verrou de `test/project/` qui bouge.
- **Version** `0.5.0+5`, ouverte par `O1`, datée par `P3`.
- **Git** : un commit par tâche, par liste de chemins explicite (`git add -- <chemins>` puis `git commit -- <chemins>`) ; Conventional Commits en français ; **aucune ligne d'attribution** ; rien n'est poussé, fusionné ni tagué sans demande. `windows/flutter/generated_plugin_registrant.h` et `android/.kotlin/` ne se committent jamais.

## Review Focus

Cinq conditions que le cadrage implique sans les éprouver, les plus probables d'abord. Chacune a son cas de test dans la tâche nommée ; le relecteur de cette tâche vérifie qu'il y est.

| # | Condition | Ce qu'une personne raisonnable attend | Tâche |
|---|---|---|---|
| 1 | La carte se reconstruit à chaque notification d'un des deux ViewModels (geste, préchargement, fiche) : `flutter_map` vide ses caches de projection dans **chaque** `didUpdateWidget` (`layer_projection_simplification/state.dart:52-58` du paquet installé) | les 56 110 points ne sont projetés qu'une fois par carte de vigilance ; la carte reste fluide (`NFR-01`) | `M5` (même **instance** de calque d'un build à l'autre, vérifiée par test ; la fabrique du calque est écrite par `M2`) |
| 2 | L'usager active « Vigilance crues », la quitte et y revient, ou déplace la carte, pendant le premier chargement (jusqu'à 87 s) | un seul téléchargement de 2,2 Mo ; aucune relance tant qu'il court ; la vigilance s'affiche dès qu'il aboutit | `L2` (compte des appels à la source) |
| 3 | `DtHrInfoVigiCru` arrive sans décalage horaire (`"2026-10-14T13:55:31"`) : `DateTime.parse` le lirait en heure **locale** | aucune date inventée : une date sans fuseau explicite est illisible, la carte de vigilance ne s'affiche pas (`BR-001`) | `W1` |
| 4 | Le réseau tombe **après** un premier chargement réussi : le rafraîchissement de la 31e minute échoue | l'ancienne vigilance reste tracée avec **sa** date, sans avis ; avant tout chargement réussi, l'échec dit « Réessayer » et un geste ne relance rien | `W3`, `L2` |
| 5 | Une fiche tronçon est ouverte quand l'usager quitte la lecture Crues, touche une station (sur une autre lecture), ouvre « Favoris » ou désigne un point | la fiche tronçon se ferme ; jamais deux fiches ensemble | `F4` (test de la racine) |

---

## Cible et périmètre

| Cible | État dans ce plan |
|---|---|
| **Windows** | construite en release, exécutable lancé hors Flutter (`P1`) ; `NFR-01` mesuré en `--profile` (`H1`) |
| **Android** | émulateur `Pixel_7`, en débogage (`P2`) — construction constatée le 2026-10-14 (T3). Publication (`A⏸3`, `A⏸5`) et appareil réel (`A⏸4`) restent ⏸ |
| **iOS** | configuré, jamais compilé |

**Ce que T4 fait :** (a) lecture « Vigilance crues » dans les puces d'échelle · (b) tronçons tracés par niveau, un seul calque · (c) étiquettes selon le zoom, focalisables · (d) légende citée, datée, « © VIGICRUES » · (e) avis : lecture en cours, injoignable, illisible, entités écartées, secteur sans tronçon ; « Réessayer » · (f) fiche tronçon : encart de crue, niveau, définition citée, date, bulletin · (g) source derrière `FloodVigilanceSource`, cache de 30 min · (h) section Vigicrues de « D'où vient cette donnée ? ».

**Ce que T4 ne fait pas :** aucun niveau calculé, aucun rapprochement débit ↔ crue · rien de T5 (avis, « Me prévenir », favori d'un tronçon) · aucune vigilance dans la fiche station · aucun nom de territoire · aucune prévision ni observation Vigicrues · aucun outre-mer · aucun filtre sur la lecture Crues · aucun avis d'ancienneté de la date · rien au-delà de la session · le modal du premier lancement ne change pas.

---

## Qui lance quoi

| Commande | Lancée par |
|---|---|
| `flutter analyze`, `flutter test`, `dart format`, `flutter pub get` | **Claude**, dans le bac à sable (Flutter hors PATH sur ce poste : `/c/Users/oliver254/develop/flutter/bin/flutter.bat`) |
| `flutter run -d windows`, `flutter run -d windows --profile …`, `flutter build windows --release`, lancement de l'exécutable, `flutter emulators --launch Pixel_7`, `flutter run -d emulator-5554`, tout constat à l'écran | **le commanditaire** |

Toute commande du commanditaire est donnée **seule dans son bloc `bash`**, avec le **résultat attendu énoncé**, puis **constatée et recopiée**. Jamais supposée.

## Critère de fin, identique pour chaque tâche — dit ici une seule fois

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

Attendu : `No issues found!` · tous les tests passent · code de sortie **0**. Recopier le **nombre total de tests** (repère de départ : **3 313**, `dev` à `801b125`, constaté le 2026-10-14) : il ne fait que croître, sauf suppression justifiée dans le message de commit. **Un commit par tâche**, par **liste de chemins explicite**. Un fichier régénéré hors de la liste se signale, il ne se committe pas.

⚠️ **Brief de tout sous-agent, en tête :** interdiction de `git stash`, `git checkout`, `git switch`, `git restore`, `git reset`, `git clean`, `git add`, `git commit`, `git push`, et de `python`/`python3` (bloque sur ce poste) ; il rend la **sortie rouge brute** de son étape de test rouge avant d'implémenter. Au retour, la boucle principale relit `git status`, relance elle-même le critère de fin, fait relire par **un** second agent (régime rapide du commanditaire : une re-relecture seulement après une correction de **code** ; les remarques mineures vont au journal, sans tour de correction), puis committe. Plusieurs sessions peuvent écrire dans le même arbre : `git branch --show-current` (attendu : `feat/t4-crues`) et `git status` avant chaque commit.

**Journal d'exécution :** `.superpowers/sdd/2026-10-14-t4-crues-vigicrues/progress.md` (ignoré par git) — une ligne `Task <ID>: en cours` au lancement, `Task <ID>: complete (<hachage>)` une fois le hachage du commit lu.

---

## Structure de fichiers

### Domaine — `lib/domain/floods/` (Dart pur)

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `flood_vigilance_level.dart` | `FloodVigilanceLevel` (`sealed`, cinq branches), libellés d'étiquette et de fiche, rang de dessin | `V1` |
| `published_flood_definitions.dart` | légendes et explications publiées par Vigicrues, recopiées (`VC-13`) | `V1` |
| `flood_section.dart` | `FloodSectionCode`, `FloodSection` | `V2` |
| `flood_vigilance_map.dart` | `FloodVigilanceMap` (date obligatoire, tronçons, entités écartées) | `V2` |
| `flood_vigilance_source.dart` | port `FloodVigilanceSource`, `FloodVigilanceFailure` et ses trois branches | `V2` |
| `flood_section_rules.dart` | étiquette ou non, ancre, emprise, ordre de dessin, ordre des étiquettes | `V3` |
| `lib/domain/sources/source_names.dart` (modifié) | `floodSourceName`, `floodAttribution`, `floodPublicSiteLabel`, `floodPublicSiteUrl`, `floodBulletinUri` | `W2` |
| `lib/domain/warnings/warning_texts.dart` (modifié) | textes de l'avertissement de crue | `M5` |

### Données — `lib/data/floods/`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `flood_vigilance_mapper.dart` | `mapFloodVigilance(Object? json)` : seul point de conversion, tout ou rien à la racine, écartée et comptée par entité | `W1` |
| `vigicrues_endpoint.dart` | adresse appelée, délai de 20 s, `vigicruesJsonClient` | `W2` |
| `vigicrues_flood_vigilance_source.dart` | `VigicruesFloodVigilanceSource` : transport → mapper, correspondance des échecs | `W2` |
| `cached_flood_vigilance_source.dart` | `CachedFloodVigilanceSource`, TTL 30 min | `W3` |

### Tranche `map`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `view_model/map_scale.dart` (modifié) | `MapScaleKind.crues` | `L1` |
| `view_model/flood_layer_view_model.dart` | `FloodLayerViewModel`, `FloodLayerState`, `FloodLabel` | `L2` |
| `view/flood_sections_layer.dart` | calque des traits (instance stable), toucher | `M2` |
| `view/flood_section_label.dart` | étiquette d'un tronçon | `M2` |
| `view/map_legend.dart` (modifié) | légende « Vigilance crues » | `M3` |
| `view/map_empty_states.dart` (modifié) | avis de la lecture Crues, « Réessayer » | `M4` |
| `view/map_view.dart` (modifié) | branchement des deux ViewModels, de la fiche tronçon | `M5` |

### Partagé — `lib/features/shared/`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `flood_level_style.dart` | teinte, épaisseur, motif, barres de jauge par niveau | `M1` |
| `flood_level_gauge.dart` | la jauge (carré et barres) | `M1` |
| `unopened_link_notice.dart` | l'avis « lien non ouvert », sorti de la vue des restrictions | `F2` |

### Tranche `flood_sheet`

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `view_model/flood_sheet_view_model.dart` | `FloodSheetViewModel`, `FloodSheetState` | `F1` |
| `view/flood_sheet_panel.dart` | le panneau de la fiche | `F3` |
| `view/flood_warning_card.dart` | l'encart de crue (`BR-015`) | `F3` |

### Partages entre tâches — à exécuter en série

| Tâches | Fichier partagé |
|---|---|
| `V1`, `V2`, `V3` | `docs/domain-model.md`, `test/project/domain_model_doc_test.dart` (`typesDuDomaine`) |
| `O2`, `O4`, `X1` | `test/project/tracabilite_test.dart`, `docs/tracabilite.md` |
| `O4`, `L1`, `M3`, `M4`, `M5`, `F3` | `docs/acceptance/crues.feature`, `test/project/acceptance_features_test.dart` |
| `M5`, `F3` | `docs/04-ui.md` |
| `L1`, `M2`, `M3`, `M4`, `M5` | `lib/features/map/view/map_view.dart`, `map_legend.dart`, `map_empty_states.dart` |
| `W2`, `F5` | `lib/domain/sources/source_names.dart`, `test/domain/sources/source_names_test.dart` |
| `F4` | `lib/main.dart`, `test/main_test.dart` |

---

## Lot 1 — Documents, avant le code

> Textes approuvés le 2026-10-14 (cadrage § 12.1 et § 12.2) : **recopiés mot pour mot**. Aucune ligne de `lib/` ne change dans ce lot, sauf `pubspec.yaml` (version).

### Task O1 : Ouvrir la version `0.5.0` ; T4 en cours dans les documents d'état

**Agent :** mécanique (sonnet, effort léger).
**Files:** modifiés `pubspec.yaml` (`version: 0.5.0+5`), `CHANGELOG.md`, `test/project/changelog_test.dart`, `docs/project-state.md` (en-tête « Mis à jour », ligne T4, « Prochaine étape »)

- [ ] **Étape 1** — `test/project/changelog_test.dart` **rougira** : la l. 475 fige `0.4.0+4`, et les l. 11-30 exigent la section de la version en cours. La forme **ouverte** de `0.4.0` n'est plus lisible dans git : T3 a été fusionnée en un seul commit (`801b125`), sa branche supprimée, et `git log --oneline --grep "O1 de T3"` ne trouve plus rien ; l'étape 2 donne le texte d'ouverture. `git show 801b125 -- test/project/changelog_test.dart` montre les attentes, sous leur forme datée, à réécrire pour `0.5.0+5` et `## [0.5.0]` ouverte — réécrire ces attentes pour `0.5.0+5` et `## [0.5.0]` **avant** de toucher `pubspec.yaml` ; `flutter test test/project/changelog_test.dart` → rouge, **sortie recopiée**.
- [ ] **Étape 2** — `pubspec.yaml` : `version: 0.5.0+5`. `CHANGELOG.md` : ouvrir `## [0.5.0]` sous la forme qu'avait `0.4.0` ouverte (« Cinquième tranche (T4) : la vigilance crues publiée par Vigicrues, en quatrième lecture de la carte. Version ouverte, non publiée. »), sans « Ajouté » (écrit en une fois par `X1`).
- [ ] **Étape 3** — seul `docs/project-state.md` se met à jour : en-tête « Mis à jour », ligne T4 du tableau — « version `0.5.0` ouverte » —, et « Prochaine étape », qui nomme `T4-O1` et passe à `T4-O2` ; ce que git sait (branche, commits, PR, tags) ne s'y recopie pas. `CLAUDE.md` ne change que si le statut grossier de T4 change (il reste « 🔄 en cours ») ; `docs/README.md` porte déjà le cadrage et le plan de T4.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- pubspec.yaml CHANGELOG.md test/project/changelog_test.dart docs/project-state.md && git commit -m "docs: version 0.5.0 ouverte, T4 en cours (O1 de T4)" -m "Version ouverte, non publiée ; ligne T4 de docs/project-state.md." -- pubspec.yaml CHANGELOG.md test/project/changelog_test.dart docs/project-state.md
```

### Task O2 : Règles métier — `BR-001`, `BR-007`, `BR-008`, `BR-011`, `BR-014` amendées, `BR-015` écrite

**Agent :** mécanique (sonnet, effort léger) — recopie de textes approuvés.
**Files:** modifiés `docs/br/BR-001-date-de-mesure-obligatoire.md`, `docs/br/BR-007-absence-de-donnee-jamais-neutre.md`, `docs/br/BR-008-une-seule-echelle-a-la-fois.md`, `docs/br/BR-011-nomenclature-tolerante-a-l-inconnu.md`, `docs/br/BR-014-aucun-verbe-d-instruction.md`, `test/project/tracabilite_test.dart` (`_brAttendues` + `'BR-015'`), `docs/tracabilite.md`, `docs/glossary.md`, `docs/context-map.md`, `CLAUDE.md` (invariant « Les quatre avertissements ») · créé `docs/br/BR-015-relayer-la-vigilance-crues-ne-rien-predire.md`

- [ ] **Étape 1** — `test/project/tracabilite_test.dart` : ajouter `'BR-015'` à `_brAttendues` (l. 37-52) ; lancer `flutter test test/project/tracabilite_test.dart` → **rouge** (le fichier n'existe pas, et la matrice ne le cite pas : l. 360-371), sortie recopiée. Dans `docs/tracabilite.md`, une ligne `BR-015` marquée 🔄 (T4), **sans chemin de test futur** : un fichier cité qui n'existe pas encore fait rougir « Chaque fichier de test cité existe » (l. 529-556) ; ses tests y entrent avec `X1`.
- [ ] **Étape 2** — chaque amendement du cadrage § 12.1, **mot pour mot**, dans « Invariants & cas limites » (ou la règle elle-même pour `BR-008`), et l'en-tête « Statut » complété de « · **amendé le 2026-10-14 (T4, vigilance crues)** ». `BR-008` : règle (« Les **quatre** échelles d'état — **écoulement**, **niveau de débit**, **sévérité sécheresse**, **vigilance crues** — … »), ligne du tableau de justification, phrase des familles de formes. `BR-011` : ligne du tableau, précision de la règle, invariant. Sous « Liens » de chacune : `UC-009`, `ADR-016`.
- [ ] **Étape 3** — `BR-015`, sur le gabarit `docs/br/BR-template.md` (commentaires retirés) : **Statut** Accepté · **Date** 2026-10-14 · **Contexte borné** Crues · Avertissement · **Règle** et **Invariants** : le texte du cadrage § 12.1, recopié · **Justification** : l'application n'a ni serveur ni engagement de délai ; une vigilance relayée peut avoir changé depuis sa date ; une déduction tirée d'un débit (une statistique, `ADR-002`) mêlerait deux natures (`BR-008`) · **Vérifiable par** : test de contenu des textes de crue (`test/domain/warnings/warning_texts_test.dart`), test d'écran de l'encart en tête de fiche, non repliable, région annoncée (`F3`) · **Liens** : `UC-009`, `ADR-016`, `BR-013`, `BR-014`, `BR-008`.
- [ ] **Étape 4** — `docs/glossary.md`, tableau « Termes métier » : six lignes — « Vigilance crues », « Tronçon de vigilance crues », « Territoire de vigilance crues », « Niveau de vigilance crues » (vert, jaune, orange, rouge, d'après la nomenclature Sandre 837 ; « Niveau non reconnu » pour toute autre valeur), « Information de vigilance » (la carte de vigilance publiée, datée par Vigicrues), « Vigicrues » (le service de l'État qui la publie — SCHAPI et réseau Vigicrues). Tableau des contextes bornés : ligne `Crues`. Chaque définition dit ce que l'application en fait : elle relaie, elle ne calcule pas.
- [ ] **Étape 5** — `docs/context-map.md` : contexte `Crues` (dans le schéma et la liste) ; relation `Crues → Carte`, fournisseur, « Échelle 4 (vigilance crues) — un calque de traits et des étiquettes ; `FloodLayerViewModel` dans la tranche carte (`ADR-014` amendé) » ; `Avertissement → tous` : l'encart de crue de `BR-015` compte parmi les emplacements ; couche anticorruption : ligne « Vigicrues | `FloodVigilanceSource`, une implémentation (`VigicruesFloodVigilanceSource`, `lib/data/floods/`) ; vocabulaire de l'API confiné | formats susceptibles d'évoluer sans préavis (`VC-09`) ; `ADR-016` ». `CLAUDE.md`, invariant « Les quatre avertissements ne sont pas une finition » : ajouter la règle, **sans date ni état** (`CLAUDE.md` ne porte aucun statut, arbitrage du 2026-10-15) — « L'avertissement de crue (`BR-015`) s'y ajoute : encart en tête de la fiche tronçon et texte de la fenêtre « ⚠ Avertissement » sur la lecture Crues. »
- [ ] **Étape 6** — critère de fin, commit.

```bash
git add -- docs/br/BR-001-date-de-mesure-obligatoire.md docs/br/BR-007-absence-de-donnee-jamais-neutre.md docs/br/BR-008-une-seule-echelle-a-la-fois.md docs/br/BR-011-nomenclature-tolerante-a-l-inconnu.md docs/br/BR-014-aucun-verbe-d-instruction.md docs/br/BR-015-relayer-la-vigilance-crues-ne-rien-predire.md test/project/tracabilite_test.dart docs/tracabilite.md docs/glossary.md docs/context-map.md CLAUDE.md && git commit -m "docs: BR-015 « relayer la vigilance crues, ne rien prédire » ; BR-001, 007, 008, 011, 014 amendées (O2 de T4)" -m "Textes approuvés par le commanditaire le 2026-10-14 (cadrage de T4, § 12.1). Quatre échelles, la quatrième étant une vigilance publiée par l'État ; aucun trait vert par défaut ; NivInfViCr inconnu nommé « Niveau non reconnu » ; citations de Vigicrues telles quelles. Glossaire et carte des contextes : le contexte Crues." -- docs/br/BR-001-date-de-mesure-obligatoire.md docs/br/BR-007-absence-de-donnee-jamais-neutre.md docs/br/BR-008-une-seule-echelle-a-la-fois.md docs/br/BR-011-nomenclature-tolerante-a-l-inconnu.md docs/br/BR-014-aucun-verbe-d-instruction.md docs/br/BR-015-relayer-la-vigilance-crues-ne-rien-predire.md test/project/tracabilite_test.dart docs/tracabilite.md docs/glossary.md docs/context-map.md CLAUDE.md
```

### Task O3 : `ADR-016` ; amendements d'`ADR-014` et de `NFR-07`

**Agent :** mécanique (sonnet, effort moyen).
**Files:** créé `docs/adr/ADR-016-integration-vigicrues.md` · modifiés `docs/adr/ADR-014-feature-first-mvvm.md`, `docs/nfr.md` (ligne `NFR-07`), `docs/sources/vigicrues.md` (en-tête : « Décision liée : `ADR-016` »), `test/project/nfr_doc_test.dart` (seulement si un verrou porte sur le texte de `NFR-07` — le lire d'abord)

- [ ] **Étape 1** — lire `test/project/nfr_doc_test.dart` : si la ligne `NFR-07` y est verrouillée, écrire d'abord le cas qui attend « sauf Vigicrues », le voir **rouge**, sortie recopiée.
- [ ] **Étape 2** — `ADR-016`, sur le gabarit `docs/adr/ADR-template.md` (commentaires retirés), contenu du cadrage § 12.1 développé : **Statut** Accepté — arbitrages 1, 6, 10 et 12 du commanditaire du 2026-10-14 (le 12 : un rafraîchissement en fond qui échoue est retenté au geste suivant, un à la fois) ; choix d'architecture (R1 à R5) tranchés par défaut, révisables · **Contexte** : `VC-01` à `VC-13` résumés, avec la fiche en lien ; « la seule source qui porte tracés, niveaux et date est un appel national de 2,2 Mo » · **Décision** : les points du cadrage, avec un `flowchart` mermaid (celui du cadrage § 6) · **Conséquences** ➕ / ➖ · **Alternatives écartées** (trois, motifs du cadrage) · **Si la décision est revue** (deux déclencheurs). Section « Arbitrages » : les deux réponses du 2026-10-14 sur la source, la seconde **après correction d'un fait faux**, dites telles.
- [ ] **Étape 3** — `ADR-014`, section « Amendement du 2026-10-14 (T4) » : le texte du cadrage § 12.1, plus « Précédent : les fiches injectées, chacune avec son ViewModel, depuis T1. » `docs/nfr.md`, ligne `NFR-07` : cible amendée (texte du cadrage § 12.1), date de reprise dans l'en-tête du document, colonne de vérification : « tests de `CachedFloodVigilanceSource` (`W3`), de `FloodLayerViewModel` (`L2`) et de `vigicruesJsonClient` (`W2`) ».
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- docs/adr/ADR-016-integration-vigicrues.md docs/adr/ADR-014-feature-first-mvvm.md docs/nfr.md docs/sources/vigicrues.md && git commit -m "docs: ADR-016 — intégrer Vigicrues derrière une abstraction ; ADR-014 et NFR-07 amendés (O3 de T4)" -m "GeoJSON national mis en cache 30 min, 20 s par tentative, nouvel essai sur « Réessayer » : exception nommée à NFR-07. Deux ViewModels pour l'écran carte quand une lecture a son propre cycle de chargement. Alternatives écartées : flux RSS et tracés embarqués, lien seul, fiche station seule." -- docs/adr/ADR-016-integration-vigicrues.md docs/adr/ADR-014-feature-first-mvvm.md docs/nfr.md docs/sources/vigicrues.md
```

(Ajouter `test/project/nfr_doc_test.dart` aux deux listes s'il a changé.)

### Task O4 : `US-21`, `UC-009`, `crues.feature`

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `docs/02-specifications.md` (`US-21` sous « Should » ; § 4, messages par source : les textes Vigicrues), `docs/README.md` (tableau des cas d'usage : `UC-009`), `test/project/tracabilite_test.dart` (`_ucAttendus` + `'UC-009'`), `docs/tracabilite.md`, `test/project/acceptance_features_test.dart` · créés `docs/use-cases/UC-009-consulter-la-vigilance-crues.md`, `docs/acceptance/crues.feature`

- [ ] **Étape 1** — tests d'abord : `_ucAttendus` + `'UC-009'` — « UC-009 est cité dans la matrice » (`tracabilite_test.dart:374-384`) rougit : la ligne `UC-009` de `docs/tracabilite.md` s'écrit dans cette tâche, 🔄, **sans chemin de test futur** (même raison qu'`O2`) ; dans `acceptance_features_test.dart`, `_featureFiles` + `'crues.feature'` (le commentaire « Les sept fichiers » devient « huit »), et deux constantes sur le modèle de `_filtresRules` / `_filtresStory` : `_cruesRules = <String>['BR-001', 'BR-007', 'BR-008', 'BR-011', 'BR-014', 'BR-015']` (chacune citée par au moins un **scénario**) et `_cruesStory = 'US-21'`, avec les deux tests qui les lisent (recopier la forme des tests de `filtres.feature`). `flutter test test/project` → **rouge**, sortie recopiée.
- [ ] **Étape 2** — `02-specifications.md`, tableau « Should », après `US-16` (le dernier Should ; `US-20` est en « Could », l. 120) : `| US-21 | Tous | Je lis sur la carte et dans la fiche d'un tronçon le **niveau de vigilance crues** publié par Vigicrues, daté et attribué · 🔄 **T4** ([UC-009](use-cases/UC-009-consulter-la-vigilance-crues.md), [crues.feature](acceptance/crues.feature)). L'application relaie, elle ne calcule aucun niveau ([BR-015](br/BR-015-relayer-la-vigilance-crues-ne-rien-predire.md)) |`. § 4 (messages par source) : les cinq avis de la lecture Crues (cadrage § 12.2), recopiés.
- [ ] **Étape 3** — `UC-009`, sur le gabarit : **Statut** Accepté · **Date** 2026-10-14 · **Contexte borné** Crues · **Acteur principal** tous les personas · **Objectif** : lire la vigilance crues publiée là où l'on regarde, sans qu'une panne ou une absence se lise comme une absence de risque · **Préconditions** : la carte est affichée (`UC-001`) · **Déclencheur** : la puce « Vigilance crues » · **Flux nominal** : cadrage § 7 et § 8, en étapes numérotées (lecture en cours → tronçons tracés → étiquettes → toucher → fiche → bulletin) · **Alternatifs** : A1 injoignable · A2 refusée ou illisible · A3 « Réessayer » · A4 entités écartées · A5 secteur sans tronçon · A6 niveau inconnu · A7 lien non ouvert · A8 quitter la lecture ferme la fiche · A9 rafraîchissement après 30 min, l'ancienne vigilance reste affichée avec sa date — chacun avec son texte du cadrage § 12.2 · **Postconditions** : rien n'est conservé au-delà de la session · **Règles** : `BR-001`, `BR-007`, `BR-008`, `BR-011`, `BR-014`, `BR-015` · **Liens** : `ADR-016`, `ADR-014`, `04-ui.md`. Un `stateDiagram` mermaid **à côté de A3** : `NonDemandee → EnCours → Prete | EnEchec`, `EnEchec → EnCours` sur « Réessayer » seulement.
- [ ] **Étape 4** — `docs/acceptance/crues.feature` : en-tête sur le modèle de `filtres.feature` (« Critères d'acceptation en Gherkin — spécification lisible, jamais exécutée. Vérifié par test/project/acceptance_features_test.dart. Source : cadrage de T4 (2026-10-14), § 10 ; UC-009 ; BR-001, BR-007, BR-008, BR-011, BR-014, BR-015. ») ; un **scénario par critère** du cadrage § 10 (dix-neuf), chacun citant la règle qu'il éprouve entre parenthèses, les textes d'écran **entre guillemets français, mot pour mot**. Aucun mot de `_forbiddenFlowWords`, aucun verbe de `_instructionVerbs`.
- [ ] **Étape 5** — `docs/README.md` : ligne `UC-009` du tableau des cas d'usage. Critère de fin, commit.

```bash
git add -- docs/02-specifications.md docs/README.md test/project/tracabilite_test.dart docs/tracabilite.md test/project/acceptance_features_test.dart docs/use-cases/UC-009-consulter-la-vigilance-crues.md docs/acceptance/crues.feature && git commit -m "docs: US-21, UC-009 « Consulter la vigilance crues » et crues.feature (O4 de T4)" -m "Dix-neuf scénarios, un par critère du cadrage de T4 (§ 10), textes d'écran cités mot pour mot. Chaque règle touchée par T4 est citée par au moins un scénario, verrouillé par acceptance_features_test." -- docs/02-specifications.md docs/README.md test/project/tracabilite_test.dart docs/tracabilite.md test/project/acceptance_features_test.dart docs/use-cases/UC-009-consulter-la-vigilance-crues.md docs/acceptance/crues.feature
```

---

## Lot 2 — Domaine, `lib/domain/floods/`

> **Dart pur** : aucun `package:flutter`, aucun import de `lib/features/` ni de `lib/data/`. **Aucun nom de champ de l'API**, pas même en commentaire (confinement, `W2`) : on écrit « le code publié du tronçon », jamais le nom du champ. `docs/domain-model.md` et `typesDuDomaine` (`test/project/domain_model_doc_test.dart:21-68`) s'allongent **dans le commit qui écrit chaque type**. `V1` → `V2` → `V3` en série.

### Task V1 : `FloodVigilanceLevel`, ses libellés, et les définitions publiées

**Agent :** mécanique (sonnet, effort moyen).
**Files:** créés `lib/domain/floods/flood_vigilance_level.dart`, `lib/domain/floods/published_flood_definitions.dart`, `test/domain/floods/flood_vigilance_level_test.dart`, `test/domain/floods/published_flood_definitions_test.dart` · modifiés `docs/domain-model.md` (section « Contexte Crues », nomenclature close), `test/project/domain_model_doc_test.dart` (`typesDuDomaine` + `'FloodVigilanceLevel'`, `'NiveauCruesInconnu'`)

**Signatures** — aucun import :
- `sealed class FloodVigilanceLevel { const FloodVigilanceLevel(); }` ; `final class Vert`, `Jaune`, `Orange`, `Rouge` (constructeurs `const`, sans champ, `==` par type) ; `final class NiveauCruesInconnu extends FloodVigilanceLevel { const NiveauCruesInconnu(this.raw); final Object? raw; }` avec `==` et `hashCode` sur `raw`, `toString`.
- `String floodLevelLabel(FloodVigilanceLevel level)` → `'Vert'`, `'Jaune'`, `'Orange'`, `'Rouge'`, `'Niveau non reconnu'`.
- `String floodVigilanceTitle(FloodVigilanceLevel level)` → `'Vigilance verte'`, `'Vigilance jaune'`, `'Vigilance orange'`, `'Vigilance rouge'`, `'Niveau de vigilance non reconnu'`.
- `int floodDrawingRank(FloodVigilanceLevel level)` → `0`, `1`, `2`, `3`, `4` (vert, jaune, orange, rouge, inconnu : le plus grave au-dessus, l'inconnu par-dessus tout — cadrage § 5).
- `String? publishedFloodLegend(FloodVigilanceLevel level)` et `String? publishedFloodExplanation(FloodVigilanceLevel level)` — `null` pour `NiveauCruesInconnu` ; explication `null` pour `Vert`. Textes **au caractère près** de `VC-13` (cadrage § 12.2) :
  - Vert : légende `'Pas de vigilance particulière requise'` ;
  - Jaune : `'Risque de crue génératrice de débordements'` / `"Risque de crue génératrice de débordements et de dommages localisés ou de montée rapide et dangereuse des eaux, nécessitant une vigilance particulière notamment dans le cas d'activités exposées et/ou saisonnières."` (apostrophe **droite**) ;
  - Orange : `'Risque de crue génératrice de débordements importants'` / `'Risque de crue génératrice de débordements importants susceptibles d’avoir un impact significatif sur la vie collective et la sécurité des biens et des personnes.'` (apostrophe **courbe** U+2019) ;
  - Rouge : `'Risque de crue majeure'` / `'Risque de crue majeure. Menace directe et généralisée de la sécurité des personnes et des biens.'`
- En tête de `published_flood_definitions.dart` : provenance (« page d'accueil de Vigicrues, relevée le 2026-10-14, `docs/sources/vigicrues.md`, `VC-13` ; fixture `test/fixtures/vigicrues/accueil_legende_2026-10-14.html` ; arbitrage 5 du cadrage de T4 : le texte du site, pas celui du Sandre »).

**Invariants :** quatre `switch` exhaustifs sans `default` ; aucune lecture de valeur brute ici (la traduction du code publié vit dans le mapper, `W1`).

**Cas de test**
- Chaque libellé, chaque titre, chaque rang, pour les cinq branches ; `NiveauCruesInconnu(7) == NiveauCruesInconnu(7)`, `!= NiveauCruesInconnu('7')`, `!= NiveauCruesInconnu(null)`.
- `published_flood_definitions_test.dart` : **lit la fixture** `accueil_legende_2026-10-14.html` (`dart:io`, test autorisé), décode `&#039;` en `'`, et vérifie que chaque légende et chaque explication non nulles y figurent **telles quelles** (sous-chaîne exacte) ; `publishedFloodExplanation(const Vert())` est `null` ; les deux fonctions rendent `null` pour l'inconnu.
- Une fonction de test à `switch` sans `default` sur `FloodVigilanceLevel` compile (`BR-011`).

- [ ] **Étape 1** — tests rouges, `flutter test test/domain/floods` → échec, **sortie rouge recopiée**.
- [ ] **Étape 2** — implémenter ; `domain-model.md` : section « Contexte Crues — la vigilance publiée par tronçon (T4) » ouverte (une phrase : ce que le contexte relaie, et qu'il ne calcule rien, `BR-015`), `FloodVigilanceLevel` sous « Nomenclatures closes » (cinq branches, l'inconnu garde sa valeur brute) ; `typesDuDomaine`.
- [ ] **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/floods/flood_vigilance_level.dart lib/domain/floods/published_flood_definitions.dart test/domain/floods/flood_vigilance_level_test.dart test/domain/floods/published_flood_definitions_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart && git commit -m "feat(domain): niveaux de vigilance crues et définitions publiées par Vigicrues (V1 de T4)" -m "Nomenclature close à cinq branches, l'inconnu garde sa valeur brute (BR-011). Légendes et explications recopiées au caractère près de la page d'accueil de Vigicrues (VC-13, arbitrage 5), vérifiées contre la fixture datée." -- lib/domain/floods/flood_vigilance_level.dart lib/domain/floods/published_flood_definitions.dart test/domain/floods/flood_vigilance_level_test.dart test/domain/floods/published_flood_definitions_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart
```

### Task V2 : Le tronçon, la carte de vigilance, le port et ses échecs

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `V1`.
**Files:** créés `lib/domain/floods/flood_section.dart`, `lib/domain/floods/flood_vigilance_map.dart`, `lib/domain/floods/flood_vigilance_source.dart`, `test/domain/floods/flood_section_test.dart`, `test/domain/floods/flood_vigilance_map_test.dart`, `test/domain/floods/flood_vigilance_source_test.dart` · modifiés `docs/domain-model.md`, `test/project/domain_model_doc_test.dart` (+ `'FloodSectionCode'`, `'FloodSection'`, `'FloodVigilanceMap'`, `'FloodVigilanceSource'`, `'FloodVigilanceFailure'`, `'VigilanceInjoignable'`, `'VigilanceRefusee'`, `'VigilanceIllisible'`)

**Signatures** — imports permis : `lib/domain/geo/geo_point.dart`, `lib/domain/floods/flood_vigilance_level.dart` :
- `final class FloodSectionCode { factory FloodSectionCode(String raw); final String value; }` — lève `ArgumentError` sur une chaîne vide ; **tel quel**, sans `trim` ; `==`, `hashCode`, `toString` (modèle : `StationCode`, `lib/domain/station/station.dart:20-24`).
- `final class FloodSection { factory FloodSection({required FloodSectionCode code, required String name, required String territoryCode, required FloodVigilanceLevel level, required List<List<GeoPoint>> lines}); … }` — lève `ArgumentError` si `name` ou `territoryCode` est vide, si `lines` est vide, ou si une ligne a moins de deux points ; copies non modifiables (`List.unmodifiable`) ; `==` sur `code` seul (identité publiée) ; `toString` sans les tracés.
- `final class FloodVigilanceMap { factory FloodVigilanceMap({required DateTime informationDate, required List<FloodSection> sections, required int skippedEntities}); }` — lève `ArgumentError` si `informationDate` n'est pas UTC (`isUtc` faux) ou si `skippedEntities < 0` ; `sections` non modifiable ; `FloodSection? sectionByCode(FloodSectionCode code)`.
- `abstract interface class FloodVigilanceSource { Future<FloodVigilanceMap> current(); }` — doc : **lève** un `FloodVigilanceFailure`, ne le rend jamais (le cache n'écrit que ce qui est rendu — même raisonnement que `lib/domain/restrictions/restriction_source.dart:14-19`).
- `sealed class FloodVigilanceFailure implements Exception { const FloodVigilanceFailure(this.diagnostic); final String diagnostic; }` ; `final class VigilanceInjoignable`, `final class VigilanceRefusee` (`{required int statusCode, required String diagnostic}`), `final class VigilanceIllisible` — `==`, `hashCode`, `toString`, comme les trois branches de `RestrictionLookupFailure` (l. 61-110), **sans en partager les types** (R2).

**Cas de test**
- Code : `FloodSectionCode('BT5').value == 'BT5'` ; `FloodSectionCode('')` lève ; `FloodSectionCode(' BT5') != FloodSectionCode('BT5')`.
- Tronçon : construction valide ; chaque refus (nom vide, territoire vide, aucune ligne, une ligne d'un point) lève `ArgumentError` ; `lines` et chaque ligne non modifiables (`.add` → `UnsupportedError`) ; deux tronçons de même code et de niveaux différents sont égaux.
- Carte : `informationDate: DateTime(2026, 10, 14, 15, 55)` (locale) lève ; `DateTime.utc(2026, 10, 14, 13, 55, 31)` passe ; `skippedEntities: -1` lève ; `sectionByCode` trouve, ou rend `null`.
- Échecs : égalité structurelle par branche ; un `switch` sans `default` sur `FloodVigilanceFailure` compile.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter, `domain-model.md` (tronçon et carte sous « Entités », le port et ses échecs dans la section « Contexte Crues »), `typesDuDomaine` ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/floods/flood_section.dart lib/domain/floods/flood_vigilance_map.dart lib/domain/floods/flood_vigilance_source.dart test/domain/floods/flood_section_test.dart test/domain/floods/flood_vigilance_map_test.dart test/domain/floods/flood_vigilance_source_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart && git commit -m "feat(domain): tronçon, carte de vigilance datée, port FloodVigilanceSource (V2 de T4)" -m "La date de l'information est obligatoire et en UTC (BR-001). Le port lève trois échecs fermés, jamais rendus : le cache n'écrit que ce qui est rendu. Types propres aux crues, sans partage avec les restrictions." -- lib/domain/floods/flood_section.dart lib/domain/floods/flood_vigilance_map.dart lib/domain/floods/flood_vigilance_source.dart test/domain/floods/flood_section_test.dart test/domain/floods/flood_vigilance_map_test.dart test/domain/floods/flood_vigilance_source_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart
```

### Task V3 : Règles pures — étiquette, ancre, emprise, ordres

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `V2`.
**Files:** créés `lib/domain/floods/flood_section_rules.dart`, `test/domain/floods/flood_section_rules_test.dart` · modifié `docs/domain-model.md` (les règles, une phrase chacune)

**Signatures** — imports permis : `geo_point.dart`, `bounds.dart`, `flood_section.dart`, `flood_vigilance_level.dart` :
- `bool floodSectionLabelled(FloodSection section, {required bool individualLevel})` — `switch` sur le niveau : `Vert` → `individualLevel` ; `Jaune`, `Orange`, `Rouge`, `NiveauCruesInconnu` → `true`. Le seuil de zoom n'est **pas** ici (`individualLevel` vient de `MapViewModel.level == null`).
- **Arbitrage 11 — par les segments.** Un segment est la paire de deux points consécutifs d'une ligne. Le découpage d'un segment par l'emprise (bornes **incluses**, `west <= lon <= east`, `south <= lat <= north`) se fait dans le plan (longitude, latitude), par l'algorithme de Liang–Barsky, écrit ici (une fonction privée, testée à travers les deux suivantes) ; aucune bibliothèque.
- `bool floodSectionTouches(FloodSection section, Bounds bounds)` — vrai si **un segment** du tracé coupe l'emprise (un point dans l'emprise en est le cas particulier).
- `GeoPoint? floodLabelAnchor(FloodSection section, Bounds bounds)` — pour chaque segment découpé à l'emprise, le point de ce morceau **le plus proche du centre** de l'emprise (projection orthogonale du centre, ramenée aux extrémités du morceau) ; parmi eux, celui de distance au carré la plus petite (en degrés, comme `MapViewModel._squaredDegreesTo`, `map_view_model.dart:1343`) ; égalité : le premier rencontré dans l'ordre des lignes puis des segments ; aucun segment dans l'emprise → `null`.
- `List<FloodSection> floodSectionsInDrawingOrder(Iterable<FloodSection> sections)` — tri **stable** par `floodDrawingRank` croissant (dessiné en premier = le moins grave) ; liste non modifiable.
- `List<(FloodSection, GeoPoint)> floodLabelsFor(Iterable<FloodSection> sections, Bounds bounds, {required bool individualLevel})` — les tronçons étiquetés (`floodSectionLabelled`) qui ont une ancre, dans l'ordre de tabulation : distance de l'ancre au centre croissante, puis `code.value` croissant ; liste non modifiable.

**Cas de test** (tronçons construits ; niveaux 2 à 4 : « cas construit, jamais observé en production — `VC-04` »)
- `floodSectionLabelled` : vert + `individualLevel: false` → faux ; vert + `true` → vrai ; jaune, orange, rouge, inconnu → vrais quel que soit `individualLevel`.
- `floodSectionTouches` : un point sur le bord ouest exact → vrai ; **un segment qui traverse l'emprise de part en part, sans aucun sommet dedans → vrai** (arbitrage 11 : sommets à 2 km l'un de l'autre, emprise de 500 m) ; un segment qui passe à côté (coin frôlé de l'extérieur) → faux ; un segment le long d'un bord, dessus → vrai ; un tronçon entièrement hors emprise → faux.
- `floodLabelAnchor` : un segment qui traverse l'emprise horizontalement par son centre → l'ancre est le **centre** de l'emprise (projection) ; un segment qui la traverse au-dessus du centre → le point du segment à la longitude du centre ; un segment qui entre et s'arrête avant le centre → son extrémité intérieure ; aucun segment dans l'emprise → `null` ; deux segments à égale distance → le premier ; un tronçon à deux lignes, la plus proche du centre dans la seconde → le point de la seconde ; l'ancre est **toujours dans l'emprise** (propriété vérifiée sur une grille de 20 emprises construites dans le test, autour d'un tronçon à segments longs ; `V3` précède le mapper, la fixture n'est pas lue ici).
- `floodSectionsInDrawingOrder([rouge A, vert B, inconnu C, jaune D, vert E])` → `[B, E, D, A, C]` (stabilité : `B` avant `E`).
- `floodLabelsFor` : sous le niveau individuel, un vert et un orange dans l'emprise → seul l'orange ; au niveau individuel → les deux, le plus proche du centre en premier ; égalité de distance → par code ; un orange hors emprise → absent.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter, `domain-model.md` ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/floods/flood_section_rules.dart test/domain/floods/flood_section_rules_test.dart docs/domain-model.md && git commit -m "feat(domain): règles d'étiquette, d'ancre et d'ordre des tronçons (V3 de T4)" -m "Un tronçon non vert ou inconnu est toujours étiqueté, un vert au niveau individuel seulement (arbitrage 3) ; le seuil de zoom n'est pas recopié dans le domaine. Un tronçon est dans le secteur si l'un de ses segments coupe l'emprise, et son étiquette se pose sur le point du trait visible le plus proche du centre (arbitrage 11) ; le plus grave est dessiné au-dessus." -- lib/domain/floods/flood_section_rules.dart test/domain/floods/flood_section_rules_test.dart docs/domain-model.md
```

---

## Lot 3 — Données, `lib/data/floods/`

### Task W1 : Le mapper — seul point de conversion

**Agent :** **raisonnement** (opus, effort élevé) — règles de lecture fines, Review Focus 3.
**Prérequis :** `V2`.
**Files:** créés `lib/data/floods/flood_vigilance_mapper.dart`, `test/data/floods/flood_vigilance_mapper_test.dart` · modifié `test/fixtures/fixtures_test.dart` (groupe Vigicrues)

**Signatures** :
- `FloodVigilanceMap mapFloodVigilance(Object? json)` — lève `VigilanceIllisible` (diagnostic : ce qui manque), jamais autre chose (aucune `TypeError`, aucune `FormatException` ne s'échappe).
- `FloodVigilanceLevel floodLevelFromWire(Object? raw)` — `1` → `Vert`, `2` → `Jaune`, `3` → `Orange`, `4` → `Rouge` (`int` seulement ; un `double` `2.0`, une chaîne `'2'`, `null`, toute autre valeur → `NiveauCruesInconnu(raw)`).

**Règles (cadrage § 6, R4)**
- **Illisible pour toute la réponse** : racine non `Map`, `type` différent de `'FeatureCollection'`, `features` absent ou non `List`, `DtHrInfoVigiCru` absent, non chaîne, ou non lisible. **Lisible** = `DateTime.tryParse` réussit **et** la chaîne porte un fuseau explicite — se termine par `Z` ou par un décalage `±HH:MM` (expression `RegExp(r'(Z|[+-]\d{2}:\d{2})$')`) ; la date rendue est `parsed.toUtc()`. Sans fuseau explicite → illisible (Review Focus 3).
- **Écartée et comptée, entité par entité** : entité non `Map` ; `properties` non `Map` ; code (`CdEntCru`) absent, non chaîne ou vide ; nom (`lbentcru`) absent, non chaîne ou vide ; territoire (`cdensup_1`) absent, non chaîne ou vide ; `geometry` non `Map`, `type` différent de `'MultiLineString'` (un `LineString` est **écarté**, cadrage § 6 : jamais observé, `VC-03`), `coordinates` non liste.
- **Par ligne** : une ligne dont un point n'est pas une liste de deux nombres au moins, ou dont la coordonnée n'est pas un `GeoPoint` valide (`GeoPoint` lève `ArgumentError`), ou qui a moins de deux points, est **retirée** ; l'entité est écartée s'il ne lui reste aucune ligne.
- `[lon, lat]` → `GeoPoint(latitude: lat, longitude: lon)` : la seule inversion d'ordre du projet pour cette source, **commentée** ; `num.toDouble()`.
- Champs inconnus ignorés ; `bbox` **non lu** (fausse, `VC-03`) ; `RefInfoVigiCru` non lu.

**Cas de test**
- **Fixture** `infovigicru_extrait_territoire_8_2026-10-14.geojson` : 15 tronçons, aucun écarté ; `informationDate == DateTime.utc(2026, 10, 14, 13, 55, 31)` ; tous `Vert` ; le tronçon `BT5` s'appelle `'Blavet'`, territoire `'8'` ; son premier point a pour latitude la **seconde** coordonnée de la fixture (inversion vérifiée sur une valeur lue dans la fixture, jamais recopiée de mémoire).
- `floodLevelFromWire` : `1`…`4` ; `0`, `5`, `2.0`, `'2'`, `null`, `true` → `NiveauCruesInconnu` avec la valeur brute.
- Racine : `null`, `[]`, `'x'`, `{'type': 'Feature'}`, `features` absent, `features: {}` → `VigilanceIllisible`.
- Date : absente, `42`, `'pas une date'`, **`'2026-10-14T13:55:31'` (sans fuseau)** → illisible ; `'2026-10-14T13:55:31Z'` et `'2026-10-14T15:55:31+02:00'` → même instant UTC.
- Entités (construites à partir d'une entité de la fixture, un champ retiré ou altéré à la fois) : sans code, code vide, code nombre, sans nom, sans territoire, `geometry` `Point`, `LineString`, `coordinates` absent → **écartée, comptée**, les autres gardées ; deux entités cassées → `skippedEntities == 2`.
- Lignes : une ligne d'un seul point retirée, l'autre gardée (entité gardée) ; toutes les lignes invalides → entité écartée ; latitude `95` → ligne retirée.
- Niveau `NivInfViCr: 3` (cas construit, `VC-04`) → `Orange` ; `NivInfViCr` absent → `NiveauCruesInconnu(null)`, l'entité **n'est pas** écartée.
- Champ inconnu ajouté à la racine et à une entité → aucun effet.
- `test/fixtures/fixtures_test.dart`, groupe « Vigicrues — InfoVigiCru (VC-03 à VC-05) » : la fixture a les six clés de premier niveau ; `DtHrInfoVigiCru` porte un décalage ; `NivInfViCr` est un `int` ; toutes les géométries sont des `MultiLineString` ; `rss_code_inconnu_repli_national_2026-10-14.xml` contient « Pas de vigilance particulière requise » (le piège `VC-12`, consigné). « Un échec ici est un fait nouveau sur l'API » (en-tête du fichier).

- [ ] **Étape 1** — tests rouges, `flutter test test/data/floods test/fixtures` → échec, **sortie recopiée** ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/data/floods/flood_vigilance_mapper.dart test/data/floods/flood_vigilance_mapper_test.dart test/fixtures/fixtures_test.dart && git commit -m "feat(data): lecture du GeoJSON Vigicrues, seul point de conversion (W1 de T4)" -m "Tout ou rien à la racine, à features et à la date : une date sans fuseau explicite est illisible, jamais lue en heure locale (BR-001). Une entité sans code, nom, territoire ou tracé est écartée et comptée ; une ligne invalide est retirée. Niveau 1 à 4 lu en entier, tout le reste nommé inconnu (BR-011)." -- lib/data/floods/flood_vigilance_mapper.dart test/data/floods/flood_vigilance_mapper_test.dart test/fixtures/fixtures_test.dart
```

### Task W2 : La source, son adresse, son délai ; les noms affichables ; le confinement

**Agent :** mécanique (sonnet, effort élevé).
**Prérequis :** `W1`.
**Files:** créés `lib/data/floods/vigicrues_endpoint.dart`, `lib/data/floods/vigicrues_flood_vigilance_source.dart`, `test/data/floods/vigicrues_flood_vigilance_source_test.dart`, `test/data/floods/flood_vocabulary_confinement_test.dart` · modifiés `lib/domain/sources/source_names.dart`, `test/domain/sources/source_names_test.dart`

**Signatures**
- `vigicrues_endpoint.dart` : `final Uri vigicruesInformationUri = Uri.parse('https://www.vigicrues.gouv.fr/services/InfoVigiCru.geojson');` (l'adresse **finale**, `VC-01`) · `const Duration vigicruesRequestTimeout = Duration(seconds: 20);` (R3, commentaire : 2,2 Mo non compressés) · `JsonHttpClient vigicruesJsonClient(http.Client httpClient) => JsonHttpClient(httpClient: httpClient, requestTimeout: vigicruesRequestTimeout);`
- `final class VigicruesFloodVigilanceSource implements FloodVigilanceSource { VigicruesFloodVigilanceSource({required JsonHttpClient client}); }` — `current()` : `getJson(vigicruesInformationUri)` puis `mapFloodVigilance` ; correspondance des échecs, **la même que** `VigieauRestrictionSource.zonesAt` (`lib/data/restrictions/vigieau_restriction_source.dart:60-76`) : statut rejouable → `VigilanceInjoignable` ; autre statut → `VigilanceRefusee(statusCode)` ; `JsonHttpNetworkFailure` → `VigilanceInjoignable` ; `JsonHttpUnreadableBody` → `VigilanceIllisible` ; `VigilanceIllisible` du mapper propagée.
- `source_names.dart` (en-tête complété : le cinquième nom, son confinement) : `const String floodSourceName = 'Vigicrues';` · `const String floodAttribution = '© VIGICRUES';` (licence, `VC-09`) · `const String floodPublicSiteLabel = 'www.vigicrues.gouv.fr';` (l'intitulé de lien exigé par les mentions légales) · `const String floodPublicSiteUrl = 'https://www.vigicrues.gouv.fr';` · `Uri floodBulletinUri(String territoryCode) => Uri.https('www.vigicrues.gouv.fr', '/bulletin_local/$territoryCode');` (`VC-08` ; le site public, pas l'API).

**Confinement** — `flood_vocabulary_confinement_test.dart`, sur le modèle de `test/data/restrictions/restriction_source_test.dart` (règle pure sur contenus synthétiques, puis balayage de `lib/` réel, **fichiers lus en entier, commentaires compris**) : les jetons `InfoVigiCru`, `NivInfViCr`, `CdEntCru`, `DtHrInfoVigiCru`, `RefInfoVigiCru`, `lbentcru`, `cdensup_1` et la chaîne `/services/` (avec l'hôte `vigicrues.gouv.fr`) ne sont admis que sous `lib/data/floods/` et dans `lib/main.dart`. Le nom « Vigicrues » est **libre** (textes d'écran, `source_names.dart`).

**Cas de test**
- Source, avec `MockClient` (`package:http/testing.dart`, comme `test/data/http/hub_eau_client_test.dart:16`) et un `JsonHttpClient` à `sleep` qui n'attend pas : `200` + corps de la fixture → 15 tronçons, et la requête est un `GET` sur `vigicruesInformationUri` exactement ; `200` + corps HTML (`'<html>'`) → `VigilanceIllisible` ; `404` → `VigilanceRefusee(statusCode: 404)` ; `500` à chaque tentative → `VigilanceInjoignable` ; `ClientException` → `VigilanceInjoignable` ; `200` + `{"type":"FeatureCollection","features":[]}` sans date → `VigilanceIllisible`.
- `vigicruesJsonClient(MockClient(...)).requestTimeout == vigicruesRequestTimeout` ; `vigicruesRequestTimeout == const Duration(seconds: 20)` (le seul chiffre écrit en dur dans un test, comme `hub_eau_client_test.dart`).
- `source_names_test.dart` : les **cinq** noms distincts (`hasLength(5)`, + `floodSourceName`) ; `floodBulletinUri('8').toString() == 'https://www.vigicrues.gouv.fr/bulletin_local/8'` ; `floodAttribution` contient `floodSourceName.toUpperCase()`.
- Confinement : un jeton de l'API dans une vue → violation ; dans `lib/data/floods/` → admis ; dans `lib/main.dart` → admis ; dans un **commentaire** du domaine → violation ; « Vigicrues » dans une vue → admis ; balayage de `lib/` réel → aucune violation.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/data/floods/vigicrues_endpoint.dart lib/data/floods/vigicrues_flood_vigilance_source.dart test/data/floods/vigicrues_flood_vigilance_source_test.dart test/data/floods/flood_vocabulary_confinement_test.dart lib/domain/sources/source_names.dart test/domain/sources/source_names_test.dart && git commit -m "feat(data): source Vigicrues, 20 s par tentative, vocabulaire de l'API confiné (W2 de T4)" -m "VigicruesFloodVigilanceSource appelle l'adresse finale du GeoJSON par le transport partagé ; ses échecs suivent la correspondance de la source des restrictions. Le nom, l'attribution « © VIGICRUES », le site et le gabarit du bulletin vivent dans source_names.dart ; les noms de champs de l'API ne sortent pas de lib/data/floods/ (ADR-016)." -- lib/data/floods/vigicrues_endpoint.dart lib/data/floods/vigicrues_flood_vigilance_source.dart test/data/floods/vigicrues_flood_vigilance_source_test.dart test/data/floods/flood_vocabulary_confinement_test.dart lib/domain/sources/source_names.dart test/domain/sources/source_names_test.dart
```

### Task W3 : Le cache de 30 minutes

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `W2` (le port, `V2`).
**Files:** créés `lib/data/floods/cached_flood_vigilance_source.dart`, `test/data/floods/cached_flood_vigilance_source_test.dart`

**Signatures** : `const Duration floodVigilanceCacheTtl = Duration(minutes: 30);` (arbitrage 6 ; écrit ici et nulle part ailleurs) · `final class CachedFloodVigilanceSource implements FloodVigilanceSource { CachedFloodVigilanceSource({required FloodVigilanceSource inner, DateTime Function()? now}); }` — **une seule** fermeture `withCachePolicy<FloodVigilanceMap>` gardée dans un champ (piège d'usage, `lib/data/cache/cache_policy.dart:60-67`), une seule entrée `CachedValue<FloodVigilanceMap>?` ; modèle : `CachedRestrictionSource` (`lib/data/restrictions/cached_restriction_source.dart:68-108`), en-tête qui dit la même chose pour une entrée unique.

**Cas de test** (double de `FloodVigilanceSource` qui compte ses appels ; horloge simulée `test/support/simulated_clock.dart` ou fermeture d'instant mutable ; instants écrits **à partir de `floodVigilanceCacheTtl`**)
- Premier appel : attend la source (1 appel) et rend sa carte.
- Second appel à `ttl - 1 s` : même carte, **aucun** nouvel appel.
- À `ttl` pile : rend **immédiatement** la carte en cache, et **un** rafraîchissement part ; l'appel suivant rend la nouvelle carte.
- Rafraîchissement en échec (`VigilanceInjoignable`) : la carte en cache reste rendue, aucune exception ne remonte (Review Focus 4) ; **l'appel suivant relance un rafraîchissement** (arbitrage 12 : retenté au geste suivant), et un seul tant qu'il court.
- Premier appel en échec : l'échec **remonte** ; l'appel suivant rappelle la source (rien n'a été mis en cache).
- Deux appels simultanés sur une entrée périmée : **un seul** rafraîchissement.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/data/floods/cached_flood_vigilance_source.dart test/data/floods/cached_flood_vigilance_source_test.dart && git commit -m "feat(data): cache de session de 30 min pour la vigilance crues (W3 de T4)" -m "Une entrée, une fermeture withCachePolicy : au-delà de 30 min la carte en cache est rendue avec sa date pendant qu'une nouvelle se charge ; un rafraîchissement en échec garde l'ancienne ; un premier échec n'est jamais mis en cache (arbitrage 6, NFR-07 amendé)." -- lib/data/floods/cached_flood_vigilance_source.dart test/data/floods/cached_flood_vigilance_source_test.dart
```

---

## Lot 4 — La lecture et son ViewModel

### Task L1 : `MapScaleKind.crues` et ses branches, sans calque

**Agent :** **raisonnement** (opus, effort élevé) — 12 `switch`, 4 comparaisons, des tests qui figent les valeurs.
**Prérequis :** `O4`.
**Files:** modifiés `lib/features/map/view_model/map_scale.dart`, `lib/features/map/view_model/map_filter_scale.dart`, `lib/features/map/view_model/map_view_model.dart`, `lib/features/map/view/area_cluster_marker.dart`, `lib/features/map/view/map_empty_states.dart`, `lib/features/map/view/map_filter_sheet.dart`, `lib/features/map/view/map_legend.dart`, `lib/features/map/view/map_view.dart`, et les tests qui figent les échelles : `test/features/map/view_model/map_scale_test.dart`, `test/features/map/view/map_scale_chips_test.dart`, `test/features/map/view/map_empty_states_test.dart`, `test/features/map/view/map_legend_test.dart`, `test/features/map/view/map_filter_sheet_test.dart`, `test/features/map/view/map_overlays_phone_test.dart`, `test/features/map/view/map_entry_buttons_overlap_test.dart`, `test/project/acceptance_features_test.dart` (libellé de la puce) — et tout autre test que la suite fait rougir, lu avant d'être touché

**Ce qui change, branche par branche** (lignes au 2026-10-14, cadrage § 4.2)
- `map_scale.dart` : `crues` ajoutée **en dernier** (doc : « Vigilance publiée par l'État — `BR-008`, quatrième échelle ; aucune pastille, aucun marqueur : un calque de traits, `FloodLayerViewModel` ») ; `mapScaleLabel` → `'Vigilance crues'` ; `shouldPreloadOn` → `false`. L'en-tête du fichier (« trois échelles », « Deux valeurs seulement en T1 ») est **mis à jour**, daté.
- `map_filter_scale.dart:13` : `crues => false` (R9).
- `map_view_model.dart` : `clusters` (l. 337) `crues => const <MapAreaCluster>[]` ; `filterHidesEverything` (l. 625) `case MapScaleKind.crues: return false;`. **Les quatre comparaisons** (l. 854, 946, 1017, 1021) **ne changent pas** : leur effet sur `crues` est le bon (aucun asset entier, aucun appel ONDE, aucun rechargement) — chacune reçoit un commentaire daté qui le dit, et un test (« sur la lecture Crues, aucun appel ONDE ni lecture de l'asset entier ; les stations de l'emprise sont lues » — R15 corrigé par `O1`).
- `area_cluster_marker.dart:63`, `:89` : `MapScaleKind.crues => throw StateError('aucune pastille sur la lecture Crues (BR-008)')` — une `Error`, branche inatteignable dite telle ; le test de `clusters` ci-dessus garantit qu'elle ne l'est pas.
- `map_empty_states.dart:275` (`mapNoticesFor`) : **la lecture Crues passe avant la règle 1** — `mapNoticesFor` gagne `List<MapNotice> floodNotices = const <MapNotice>[]`, et commence par `switch (scale) { case MapScaleKind.crues: return floodNotices; case MapScaleKind.ecoulement: case MapScaleKind.debit: break; }` : une panne du référentiel ou de l'ONDE ne parle pas sur la lecture Crues (R15). Le contenu de `floodNotices` arrive en `M4`.
- `map_filter_sheet.dart:169` : `crues` → aucun critère, ni « Appliquer » ni « Effacer » ; la phrase `const String mapFilterFloodNoCriterionText = "Aucun filtre ne s'applique à la lecture Vigilance crues.";` (cadrage § 12.2 ; guillemets doubles : la chaîne porte une apostrophe) ; la feuille se ferme comme aujourd'hui.
- `map_legend.dart:202` : `crues => const <Widget>[]` **provisoire** — commentaire « lignes de la légende Crues : `M3` ».
- `map_view.dart:473` (`buildMapLayers`) : `crues => const <Marker>[]` ; `:2153` (`carteADuContenuFocalisable`) : `crues => false` **provisoire** (« étiquettes focalisables : `M5` »).
- Tests : `map_scale_test` attend `[ecoulement, debit, crues]` ; « une seule échelle précharge » reste vrai ; `map_scale_chips_test.dart:211` parcourt `MapScaleKind.values` et reste vert : seul son titre (« exactement deux puces ») devient faux, il est réécrit (« une puce par échelle »).
- ⚠️ **La troisième puce élargit le sélecteur sur toutes les échelles.** Un test de recouvrement aux tailles de téléphone qui rougit pour **Écoulement ou Débit** n'est ni restreint ni réécrit : la règle de `K1` s'applique dès ici — **arrêt, mesure recopiée, question au commanditaire**. Les boucles sur `MapScaleKind.values` qui mesurent un contenu propre à une échelle (légende, recouvrements, feuille) sont **restreintes explicitement** à `const <MapScaleKind>[MapScaleKind.ecoulement, MapScaleKind.debit]`, avec un commentaire daté qui nomme la tâche qui les étend (`M3` pour la légende, `K1` pour les recouvrements) ; celles dont le sens vaut pour toute échelle gardent `values`. `acceptance_features_test` : la table des libellés de `crues.feature` gagne `'lecture Crues': mapScaleLabel(MapScaleKind.crues)` et `'feuille de filtres, lecture Crues': mapFilterFloodNoCriterionText`.

**Cas de test nouveaux**
- `mapScaleLabel(MapScaleKind.crues) == 'Vigilance crues'` ; `shouldPreloadOn(crues)` faux ; `mapFilterActiveFor(MapFilter.none.withDepartement('41'), crues)` faux.
- `MapViewModel` : `selectScale(crues)` → `clusters` vide à tout niveau, `filterHidesEverything` faux même avec un filtre actif ; `loadFor` sur `crues` lit les stations de l'emprise et n'appelle pas l'ONDE ; revenir sur `ecoulement` recharge l'ONDE de l'emprise (comportement existant, éprouvé pour `crues → ecoulement`).
- `mapNoticesFor(scale: crues, error: Exception('x'), errorSource: MapErrorSource.referentiel, …, floodNotices: const <MapNotice>[])` → vide ; avec `floodNotices: const <MapNotice>[NoStationInArea()]` → cette liste telle quelle.
- Feuille de filtres sur `crues` (Windows) : la phrase, aucune case, aucun « Appliquer », aucun « Effacer ».

- [ ] **Étape 1** — ajouter la valeur seule : `flutter analyze` → les `switch` non exhaustifs, **sortie recopiée** ; écrire les tests nouveaux → rouges, sortie recopiée.
- [ ] **Étape 2** — chaque branche ; `flutter test` → lire chaque test qui rougit **comme un constat** (un test qui rougit n'est pas une attente à réécrire) ; restreindre ou étendre selon la règle ci-dessus ; trois échecs sur un même test : arrêt et question.
- [ ] **Étape 3** — critère de fin, commit (chemins : tous les fichiers touchés, listés un par un dans `task-L1-paths.txt`).

```bash
git commit -m "feat(map): quatrième échelle « Vigilance crues », sans calque encore (L1 de T4)" -m "MapScaleKind.crues et ses douze branches : aucune pastille, aucun préchargement, aucun filtre ; une panne du référentiel ou de l'ONDE ne parle pas sur cette lecture. Les quatre comparaisons d'échelle de MapViewModel gardent leur effet, dit et testé. Légende et calque : M2, M3." -- <chemins de task-L1-paths.txt>
```

### Task L2 : `FloodLayerViewModel`

**Agent :** **raisonnement** (opus, effort élevé) — concurrence, Review Focus 2 et 4.
**Prérequis :** `V3`, `W3`, `L1`.
**Files:** créés `lib/features/map/view_model/flood_layer_view_model.dart`, `test/features/map/view_model/flood_layer_view_model_test.dart`

**Signatures** — imports permis : `package:flutter/foundation.dart` (`ChangeNotifier`), `lib/domain/` ; **aucun widget**, aucun `lib/data/` :
- `sealed class FloodLayerState { const FloodLayerState(); }` · `final class LectureCruesNonDemandee` · `final class LectureCruesEnCours` · `final class LectureCruesPrete { const LectureCruesPrete(this.map); final FloodVigilanceMap map; }` · `final class LectureCruesEnEchec { const LectureCruesEnEchec(this.cause); final Object cause; }` — noms préfixés : `EnCours`, `Prete`, `EnEchec` existent déjà dans la tranche fiche station.
- `final class FloodLabel { const FloodLabel({required this.section, required this.anchor}); final FloodSection section; final GeoPoint anchor; }`
- `final class FloodLayerViewModel extends ChangeNotifier { FloodLayerViewModel({required FloodVigilanceSource source}); FloodLayerState get state; List<FloodLabel> get labels; bool? get anySectionInBounds; Future<void> activate(); Future<void> onViewportChanged(Bounds bounds, {required bool individualLevel}); Future<void> retry(); FloodSection? sectionByCode(FloodSectionCode code); }` — `anySectionInBounds` vaut `null` tant qu'aucune emprise n'est connue **ou** hors `Prete` : l'absence ne se dit que sur `false` (`BR-007`).

**Comportement (cadrage § 7.1, arbitrages 9 et 10)**
- `activate()` : depuis `NonDemandee` → `EnCours` (notifie), puis lecture de la source ; depuis `Prete` → relecture **sans repasser par `EnCours`** (le décorateur rend la carte en cache ou rafraîchit) ; depuis `EnCours` ou `EnEchec` → **rien** (aucun second téléchargement ; seul « Réessayer » relance).
- Lecture réussie → `Prete(map)` ; **à chaque entrée en `Prete` et à chaque nouvelle carte, `labels` et `anySectionInBounds` sont recalculés sur la dernière emprise retenue** (celle qu'a donnée `onViewportChanged` pendant `EnCours`, s'il y en a eu une) — sans cela l'avis « secteur sans tronçon » s'afficherait à tort jusqu'au geste suivant ; la carte n'est remplacée (et la vue notifiée) que si elle n'est pas **identique** (`identical`) à la précédente. Échec (`on Object`) → `EnEchec(cause)` si aucune carte n'était lue ; si une carte était lue, elle reste (le décorateur absorbe déjà ce cas — ceinture et bretelles, dites telles).
- `onViewportChanged(bounds, individualLevel:)` : retient l'emprise et le niveau ; recalcule `labels` (`floodLabelsFor`) et `anySectionInBounds` (`floodSectionTouches`) si `Prete` ; notifie si l'un change ; **relit la source si `Prete`** (même chemin qu'`activate`) ; **ne relit rien** en `EnEchec`, `EnCours`, `NonDemandee`.
- `retry()` : seulement depuis `EnEchec` → `EnCours`, puis lecture.
- Génération : une lecture terminée après un `dispose` ou dépassée par une plus récente n'écrit rien. `labels` et `anySectionInBounds` valent `const []` et `null` hors `Prete`.
- **Rafraîchissement en fond (arbitrage 12)** : en `Prete`, chaque `onViewportChanged` relit la source ; le décorateur (`W3`) rend la carte en cache et, périmée, lance **un** rafraîchissement — retenté au geste suivant s'il a échoué. Le ViewModel n'a aucune règle de temps.

**Cas de test** (double de `FloodVigilanceSource` piloté par `Completer`, qui compte ses appels ; cartes construites ; aucun widget)
- État initial `NonDemandee`, `labels` vide.
- `activate()` → `EnCours` puis `Prete` ; `labels` après `onViewportChanged` : ceux de `floodLabelsFor` (vert caché sous le niveau individuel).
- **Bloquant de la relecture** : une emprise donnée **pendant `EnCours`**, puis l'aboutissement → `labels` non vide et `anySectionInBounds == true`, **sans nouveau geste** ; aucune emprise jamais donnée, puis `Prete` → `anySectionInBounds == null`.
- Hors de l'emprise, `Prete` → `anySectionInBounds == false`.
- **Review Focus 2** : `activate()` trois fois et `onViewportChanged` deux fois pendant le chargement → **un seul** appel à la source ; l'aboutissement passe en `Prete`.
- Échec au premier chargement → `EnEchec` ; `onViewportChanged` puis `activate()` → **aucun** appel de plus ; `retry()` → `EnCours`, un appel, `Prete`.
- **Review Focus 4** : `Prete`, puis une relecture qui lève → l'état reste `Prete` avec l'ancienne carte.
- Relecture qui rend la **même** instance → aucune notification ; une nouvelle instance → notification et nouvelle carte.
- Lecture qui aboutit après `dispose` → rien n'est écrit, aucune exception.
- `sectionByCode` : trouve en `Prete`, `null` ailleurs.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view_model/flood_layer_view_model.dart test/features/map/view_model/flood_layer_view_model_test.dart && git commit -m "feat(map): FloodLayerViewModel, l'état de la lecture Crues (L2 de T4)" -m "Un chargement à la première activation, jamais deux en même temps ; après un échec seul « Réessayer » relance (arbitrage 10) ; une carte lue n'est jamais remplacée par un échec. Étiquettes et emprise lues dans les règles du domaine. Second ViewModel de l'écran carte (arbitrage 7, ADR-014 amendé)." -- lib/features/map/view_model/flood_layer_view_model.dart test/features/map/view_model/flood_layer_view_model_test.dart
```

---

## Lot 5 — La carte

### Task M1 : Style et jauge des niveaux (partagés)

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `V1`.
**Files:** créés `lib/features/shared/flood_level_style.dart`, `lib/features/shared/flood_level_gauge.dart`, `test/features/shared/flood_level_style_test.dart`, `test/features/shared/flood_level_gauge_test.dart`

**Signatures**
- `final class FloodLevelStyle { const FloodLevelStyle({required this.tint, required this.strokeWidth, required this.dotted, required this.bars}); final Color tint; final double strokeWidth; final bool dotted; final int bars; }` · `FloodLevelStyle floodLevelStyle(FloodVigilanceLevel level)` — `switch` exhaustif, valeurs du cadrage § 7.3 et § 7.4 : Vert `0xFF009E73`, 3, plein, 0 barre ; Jaune `0xFFF0E442`, 5, plein, 1 ; Orange `0xFFE69F00`, 6, plein, 2 ; Rouge `0xFF7B241C`, 7, plein, 3 ; inconnu `0xFF767676`, 4, **pointillé**, 0. `const Color floodContourColor = Color(0xFF000000);` · `const double floodContourWidth = 2;` — largeur **visible de chaque côté** du trait et du contour de la jauge (halo de `04-ui.md` § 3) ; ⚠️ `Polyline.borderStrokeWidth` s'ajoute à la largeur du trait et se partage entre les deux côtés (`polyline_layer/painter.dart:185-191`) : le calque passe donc `borderStrokeWidth: 2 * floodContourWidth` (`M2`) · `const Color floodRedBarsColor = Color(0xFFFFFFFF);` (barres blanches sur le rouge), barres noires ailleurs.
- `class FloodLevelGauge extends StatelessWidget { const FloodLevelGauge({required this.level, this.size = 20, super.key}); }` — carré à coins arrondis (rayon 3 sur 20), teinte du niveau, contour noir 2 px, `bars` barres horizontales ; inconnu : contour en **pointillé** gris, sans barre, fond blanc. **Aucune sémantique** (`ExcludeSemantics`) : le libellé voisin l'annonce (précédent : `drought_severity_badge.dart:12-16`).

**Cas de test**
- La table des cinq styles (teinte, épaisseur strictement croissante de vert à rouge, pointillé seulement pour l'inconnu, barres 0-1-2-3-0).
- Contraste : `#F0E442` et `#E69F00` sous 3:1 contre le blanc → c'est le contour noir qui les porte (même calcul de luminance que `test/features/restrictions/view/drought_severity_badge_test.dart`, réemployé) ; le blanc sur `#7B241C` au-dessus de 4,5:1.
- Jauge (Windows) : se rend aux cinq niveaux à 20 et à 26 px ; aucun nœud sémantique ; le peintre dessine `bars` barres (compte relevé par un `CustomPainter` testable, ou un `Key` par barre).

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/shared/flood_level_style.dart lib/features/shared/flood_level_gauge.dart test/features/shared/flood_level_style_test.dart test/features/shared/flood_level_gauge_test.dart && git commit -m "feat(ui): style et jauge des niveaux de vigilance crues, partagés (M1 de T4)" -m "Teintes du canvas du 2026-10-03, épaisseur qui monte avec le niveau, inconnu gris pointillé, contour noir ; jauge à 0, 1, 2 ou 3 barres, sans sémantique propre. Partagés entre la carte et la fiche tronçon." -- lib/features/shared/flood_level_style.dart lib/features/shared/flood_level_gauge.dart test/features/shared/flood_level_style_test.dart test/features/shared/flood_level_gauge_test.dart
```

### Task M2 : Le calque des traits (instance stable, toucher) et les étiquettes

**Agent :** **raisonnement** (opus, effort élevé) — `flutter_map`, Review Focus 1.
**Prérequis :** `L2`, `M1`.
**Files:** créés `lib/features/map/view/flood_sections_layer.dart`, `lib/features/map/view/flood_section_label.dart`, `test/features/map/view/flood_sections_layer_test.dart`, `test/features/map/view/flood_section_label_test.dart` · modifié `lib/features/map/view/map_view.dart` (`buildMapLayers` : paramètres et ordre des couches ; `carteADuContenuFocalisable`, branche `crues`)

**Lire d'abord** dans le paquet installé (`C:\Users\oliver254\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_map-8.3.2\`) : `lib/src/layer/polyline_layer/polyline_layer.dart:24-71`, `polyline.dart:52-65`, `lib/src/layer/shared/layer_interactivity/` (hit notifier, ordre de parcours l. 63), `lib/src/layer/shared/layer_projection_simplification/state.dart:52-58` (`didUpdateWidget` vide les caches), et l'exemple `example/lib/pages/polyline.dart:183-230` (toucher par `GestureDetector` qui lit le notifier). Aucune signature écrite de mémoire.

**Signatures**
- `Widget buildFloodSectionsLayer({required FloodVigilanceMap map, required LayerHitNotifier<FloodSectionCode> hitNotifier, required void Function(FloodSectionCode code) onTap})` — **un seul** `PolylineLayer<FloodSectionCode>`, enveloppé d'un `GestureDetector` (`behavior: HitTestBehavior.deferToChild`) dont `onTap` lit `hitNotifier.value` **en tolérant `null`** et **copie** `hitValues` avant d'en prendre **le premier** (le plus haut dessiné) : `flutter_map` réemploie et vide sa liste de résultats à chaque test de toucher, survol compris sous Windows (`layer_interactivity/internal_hit_detectable.dart:55-58`, `:77-80`) ; une `Polyline` par ligne de chaque tronçon, dans `floodSectionsInDrawingOrder` ; `hitValue: section.code` ; `color`, `strokeWidth`, `pattern` (`StrokePattern.dotted()` pour l'inconnu, `solid` sinon) de `floodLevelStyle` ; `borderColor: floodContourColor`, `borderStrokeWidth: 2 * floodContourWidth` (2 px visibles de chaque côté, `M1`) ; `minimumHitbox: minimumTapTarget / 2` (un **rayon** : 22 Windows, 24 Android, R7 ; `painter.dart:63-66`) ; `simplificationTolerance` **par défaut** (R5). `onTap` est appelé tel quel : `M5` y passe une **méthode** de l'état, jamais une fermeture qui capture `widget` (le widget rendu est mis en cache).
- **Instance stable** (Review Focus 1) : la fabrique ne garde rien ; c'est `M5` qui met en cache le widget qu'elle rend, dans `_MapViewState`. La doc de `buildFloodSectionsLayer` le dit, en citant `state.dart:52-58`.
- `buildMapLayers` gagne `Widget? floodLayer` et `List<FloodLabel> floodLabels = const <FloodLabel>[]`, `void Function(FloodSectionCode code)? onFloodSectionTap` ; ordre : tuiles → **calque de traits** → `MarkerLayer` (étiquettes sur `crues`, sinon pastilles et marqueurs) → épingle. Branche `crues` du `switch` des marqueurs individuels : les étiquettes.
- `class FloodSectionLabel extends StatelessWidget { const FloodSectionLabel({required this.section, required this.onActivate, super.key}); }` — rangée : `FloodLevelGauge(level: section.level)`, puis `floodLevelLabel(section.level)` ; fond blanc, contour noir 2 px, rayon 16 ; hauteur `minimumTapTarget` ; `FittedBox(fit: BoxFit.scaleDown)` autour du contenu (le nom n'est jamais coupé) ; `KeyboardFocusRing(onActivate:)` ; `Semantics(button: true, label: floodLabelAnnouncement(section))`.
- `String floodLabelAnnouncement(FloodSection section)` — `switch` : `Vert` → `'crues : vigilance verte, ${section.name}'` · `Jaune` → `'crues : vigilance jaune, …'` · `Orange` → `'crues : vigilance orange, …'` · `Rouge` → `'crues : vigilance rouge, …'` · `NiveauCruesInconnu` → `'crues : niveau non reconnu, ${section.name}'` (cadrage § 7.2).
- Marqueur d'étiquette : `Marker(point: LatLng(anchor.latitude, anchor.longitude), width: 168, height: minimumTapTarget, child: …)` ; ordre de focus : celui de `labels` (`NumericFocusOrder` entier, comme `_carteFocusOrder`).
- `carteADuContenuFocalisable` (dans `_MapViewState.build`, `map_view.dart:2152-2158`) n'a pas accès aux étiquettes avant le branchement : sa branche `crues` s'écrit en `M5`.

**Cas de test** (`testWidgetsOnWindows`, et `testWidgetsOnAndroid` pour la tolérance de 24) — le calque monté dans un `FlutterMap` de test (caméra fixe, centre et zoom donnés), sans `MapView` :
- Ordre des `Polyline` dans le calque : vert, jaune, orange, rouge, inconnu (niveaux 2 à 4 : cas construits, `VC-04`).
- Toucher au milieu d'un trait → `onFloodSectionTap` reçoit son code ; toucher à 20 px du trait (Windows) → reçu ; à 40 px → rien ; deux traits superposés (rouge sur vert) → le code du rouge.
- Android : toucher à 23 px → reçu (tolérance 24).
- Étiquette : texte « Orange » et jauge à deux barres ; sémantique « crues : vigilance orange, Blavet » ; Tab l'atteint, Entrée appelle `onActivate` ; hauteur `minimumTapTarget` (44 Windows, 48 Android) ; inconnu → « Niveau non reconnu » et « crues : niveau non reconnu, … ».
- Sous le niveau individuel, un tronçon vert dans l'emprise → aucune étiquette ; au niveau individuel → une.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view/flood_sections_layer.dart lib/features/map/view/flood_section_label.dart lib/features/map/view/map_view.dart test/features/map/view/flood_sections_layer_test.dart test/features/map/view/flood_section_label_test.dart && git commit -m "feat(map): tronçons tracés par niveau et étiquettes selon le zoom (M2 de T4)" -m "Un seul PolylineLayer par carte de vigilance, contour noir de 2 px de chaque côté. Le toucher prend le trait le plus haut dessiné, à une demi-cible près, et copie les résultats que flutter_map réemploie. Étiquettes à jauge et nom, focalisables, annoncées « crues : vigilance <niveau>, <tronçon> »." -- lib/features/map/view/flood_sections_layer.dart lib/features/map/view/flood_section_label.dart lib/features/map/view/map_view.dart test/features/map/view/flood_sections_layer_test.dart test/features/map/view/flood_section_label_test.dart
```

### Task M3 : La légende « Vigilance crues »

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `M1`, `L1`.
**Files:** modifiés `lib/features/map/view/map_legend.dart`, `test/features/map/view/map_legend_test.dart`, `test/project/acceptance_features_test.dart`, `docs/acceptance/crues.feature` (si une phrase y manque)

**Signatures** : `MapLegend({required MapScaleKind scale, DateTime? floodInformationDate, UtcOffsetOf utcOffsetOf = systemUtcOffsetOf, super.key})` — `floodInformationDate` non nul **seulement** quand la lecture Crues est `Prete` ; c'est `M5` qui le passe depuis `LectureCruesPrete.map.informationDate` (ici, la légende seule est éprouvée) ; `utcOffsetOf` rend le décalage injectable par un test (précédent : `station_summary_sheet.dart:128` ; `lib/domain/formatting/display_date.dart:39-51`).

**Contenu de la branche `crues`** (cadrage § 7.6, arbitrage 9)
- Cinq rangées : un **échantillon de trait** (24 × 8 px, teinte, épaisseur ramenée à l'échelle de la rangée, pointillé pour l'inconnu, contour noir — `floodLevelStyle`) et la `FloodLevelGauge` (18 px), puis, pour les quatre niveaux, `'${floodLevelLabel(level)} — ${publishedFloodLegend(level)}'`, et `'Niveau non reconnu'` (cadrage § 7.6 : « glyphe de jauge et trait »).
- Seulement si `floodInformationDate != null` : `const String floodCoverageText = "Un cours d'eau sans trait de couleur n'est pas suivi par $floodSourceName.";` (guillemets doubles), puis `'Information de vigilance du ${formatLocalDateTime(floodInformationDate, offsetOf: utcOffsetOf)} — $floodAttribution'`.
- Les restrictions de `L1` sur les boucles de `map_legend_test` sont **levées** : la légende de chaque échelle, `crues` comprise.

**Cas de test** (`testWidgetsOnWindows`)
- Titre « Vigilance crues » ; les cinq rangées, textes exacts ; aucun symbole d'une autre famille (`BR-008`, test existant étendu).
- Sans date : ni phrase de couverture, ni ligne de date. Avec `DateTime.utc(2026, 10, 14, 13, 55, 31)` et `utcOffsetOf: (_) => const Duration(hours: 2)` → « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES ».
- Chaque rangée porte son échantillon de trait et sa jauge ; l'inconnu, un trait pointillé.
- `acceptance_features_test` : la table de `crues.feature` gagne la phrase de couverture et la légende de chaque niveau.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view/map_legend.dart test/features/map/view/map_legend_test.dart test/project/acceptance_features_test.dart && git commit -m "feat(map): légende « Vigilance crues », citée et datée (M3 de T4)" -m "Les quatre légendes publiées par Vigicrues, citées, et « Niveau non reconnu ». La phrase de couverture et « Information de vigilance du … — © VIGICRUES » n'apparaissent qu'une fois la vigilance lue (arbitrage 9, BR-001, licence VC-09)." -- lib/features/map/view/map_legend.dart test/features/map/view/map_legend_test.dart test/project/acceptance_features_test.dart
```

(Ajouter `docs/acceptance/crues.feature` aux deux listes s'il a changé.)

### Task M4 : Les avis de la lecture Crues, et « Réessayer »

**Agent :** mécanique (sonnet, effort élevé).
**Prérequis :** `L1`, `L2`.
**Files:** modifiés `lib/features/map/view/map_empty_states.dart`, `test/features/map/view/map_empty_states_test.dart`, `test/project/acceptance_features_test.dart`, `test/project/vocabulary_lists.dart` (seulement si un texte l'exige — aucun ne devrait)

**Signatures**
- Branches de `MapNotice` : `final class FloodLoading`, `final class FloodUnavailable`, `final class FloodUnreadable`, `final class FloodUnreadableSections { const FloodUnreadableSections(this.count); final int count; }`, `final class NoFloodSectionInArea`.
- Textes (cadrage § 12.2, avec `floodSourceName` interpolé) : `floodLoadingText` = « Lecture de la vigilance publiée par Vigicrues… Aucun tronçon n'est affiché tant qu'elle n'est pas lue. » · `floodUnavailableText` = « Vigicrues n'a pas répondu. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. » · `floodUnreadableText` = « La vigilance publiée par Vigicrues n'a pas pu être lue. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. » · `String floodUnreadableSectionsText(int count)` = « 1 tronçon de vigilance non lisible. » / « N tronçons de vigilance non lisibles. » (singulier à 0 et 1, comme `unreadableRowsText`) · `noFloodSectionInAreaText` = « Aucun cours d'eau suivi par Vigicrues dans le secteur affiché. Cela ne dit rien du risque de crue : sur cette carte, Vigicrues ne suit que certains cours d'eau de métropole et de Corse. » · `floodRetryLabel = 'Réessayer'`, `const Key floodRetryKey = ValueKey<String>('map-reessayer-crues');`.
- `List<MapNotice> floodNoticesFor({required FloodLayerState state, required bool? anySectionInBounds})` — **pure** : `NonDemandee` → `[]` ; `EnCours` → `[FloodLoading()]` ; `EnEchec(cause)` → `cause is VigilanceRefusee || cause is VigilanceIllisible` ? `[FloodUnreadable()]` : `[FloodUnavailable()]` (une `Error` ou un échec réseau : injoignable) ; `Prete(map)` → `map.skippedEntities > 0` ? `[FloodUnreadableSections(map.skippedEntities)]` (**remplace** l'avis d'absence) : `anySectionInBounds == false` ? `[NoFloodSectionInArea()]` : `[]` — **`null` (emprise inconnue) ne dit aucune absence** (`BR-007`). ⚠️ `is` sur des types du domaine n'est pas une comparaison d'échelle : permis.
- `buildMapNotice` gagne `VoidCallback? onRetryFlood` ; `FloodUnavailable` et `FloodUnreadable` portent l'action « Réessayer » (cible `minimumTapTarget`, `KeyboardFocusRing`, comme « Élargir la recherche ») ; les autres, aucune action ; `FloodLoading` est une région annoncée (`liveRegion`).

**Cas de test**
- `floodNoticesFor`, une ligne par cas ci-dessus, dont : `Prete`, 0 écartée, `anySectionInBounds: null` → `[]` ; `EnEchec(VigilanceInjoignable('x'))` → injoignable ; `EnEchec(StateError('x'))` → injoignable ; `Prete` avec `skippedEntities: 3` et `anySectionInBounds: false` → **seulement** le compte (`BR-007` : l'absence ne s'affirme pas) ; `Prete`, 0 écartée, rien dans l'emprise → l'avis du secteur.
- Widgets (Windows) : chaque texte exact ; « Réessayer » appelle `onRetryFlood` ; au clavier, Entrée aussi ; aucun avis de crue ne contient « vert ».
- Vocabulaire : le balayage de `vocabulary_test.dart` passe sans exception nouvelle.
- `acceptance_features_test` : la table de `crues.feature` gagne les cinq textes et « Réessayer ».

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view/map_empty_states.dart test/features/map/view/map_empty_states_test.dart test/project/acceptance_features_test.dart && git commit -m "feat(map): avis de la lecture Crues et « Réessayer » (M4 de T4)" -m "Lecture en cours, injoignable, illisible, tronçons écartés, secteur sans tronçon : jamais un trait vert par défaut (BR-007). Le compte des tronçons illisibles remplace l'avis d'absence. « Réessayer » est le seul geste qui relance après un échec (arbitrage 10)." -- lib/features/map/view/map_empty_states.dart test/features/map/view/map_empty_states_test.dart test/project/acceptance_features_test.dart
```

### Task M5 : Brancher la lecture Crues dans `MapView` ; le texte de crue de la fenêtre « ⚠ Avertissement »

**Agent :** **raisonnement** (opus, effort élevé) — fichier de 2 332 lignes, deux `Listenable`.
**Prérequis :** `M2`, `M3`, `M4`.
**Files:** modifiés `lib/features/map/view/map_view.dart`, `lib/domain/warnings/warning_texts.dart`, `test/domain/warnings/warning_texts_test.dart`, `test/features/map/view/map_view_flood_test.dart` (créé), `test/project/acceptance_features_test.dart`, `docs/04-ui.md` (§ 1 : la puce ; § 2 : la quatrième échelle — teintes, épaisseurs, motifs, étiquettes ; § 4 : la couche des traits dans la hiérarchie de la carte ; croquis de la carte en lecture Crues — code et spec dans le même commit, cadrage § 13)

**Signatures**
- `warning_texts.dart`, section « T4 — avertissement de crue (`BR-015`) », provenance : cadrage de T4, arbitrage 2 — `const String floodWarningHeadline = "CE N'EST PAS UN SYSTÈME D'ALERTE";` · `const String floodWarningBody = 'Cette application reprend la vigilance publiée par Vigicrues, à la date indiquée ; elle ne remplace ni le bulletin de Vigicrues, ni les consignes des autorités et des secours.';` · `const String floodWarningWindowText = "Ce n'est pas un système d'alerte. $floodWarningBody";` — hors verrou de version du modal (`warningTextVersion` inchangé, arbitrage 8). Le nom « Vigicrues » est écrit en clair : c'est un texte arbitré, et `floodSourceName` le porte aussi — le test vérifie que `floodWarningBody` contient `floodSourceName`.
- `MapView` gagne : `FloodLayerViewModel? floodLayer`, `void Function(FloodSection section, DateTime informationDate)? onFloodSectionTap`, `Widget? floodSheet` — **les trois vont ensemble** (`assert`, comme `onStationTap` / `stationSheet`, l. 1589-1609).
- `_MapViewState` :
  - écoute `Listenable.merge(<Listenable>[widget.viewModel, if (floodLayer != null) floodLayer])` là où il écoute aujourd'hui le seul `viewModel` ;
  - **puce** : une méthode **nouvelle** `_handleScaleSelected(MapScaleKind kind)` (le nom ne survit aujourd'hui que dans un commentaire, `map_view_model.dart:1006`) remplace `onSelect: widget.viewModel.selectScale` (`map_view.dart:2291`) : `viewModel.selectScale(kind)`, puis `switch (kind)` — `crues` → `floodLayer.activate()` puis `floodLayer.onViewportChanged(<emprise de la caméra>, individualLevel: viewModel.level == null)` ; les deux autres → rien de plus ;
  - **gestes** : dans le chemin qui appelle `viewModel.onGestureEnded` (geste de la carte et `_afterCameraMove`), si l'échelle est `crues` (par `switch`), `floodLayer.onViewportChanged(bounds, individualLevel: viewModel.level == null)` après lui ;
  - **toucher** : `onFloodSectionTap` du calque et `onActivate` des étiquettes → `floodLayer.sectionByCode(code)` ; si trouvé et l'état `Prete`, `widget.onFloodSectionTap?.call(section, map.informationDate)` ;
  - **calque, instance stable** (Review Focus 1) : le widget rendu par `buildFloodSectionsLayer` (`M2`) est **mis en cache** avec la carte dont il vient (`FloodVigilanceMap? _floodLayerMap; Widget? _floodLayerWidget;`) et **réemployé tel quel** (même objet) à chaque `build` tant que `identical(map, _floodLayerMap)` ; le `LayerHitNotifier<FloodSectionCode>` est un champ de l'état, disposé avec lui ; commentaire qui cite `state.dart:52-58`. `buildMapLayers(floodLayer: <ce widget, sur la lecture Crues à l'état Prete ; null sinon>, floodLabels: floodLayer.labels, …)` ;
  - **avis et légende** : `buildMapOverlays` (qui construit la légende et les avis, `map_view.dart:949`, `:958`) gagne des paramètres **optionnels** — `List<MapNotice> floodNotices = const <MapNotice>[]`, `VoidCallback? onRetryFlood`, `DateTime? floodInformationDate` — pour que les six fichiers de test qui l'appellent compilent sans changer ; il passe `floodNotices` à `mapNoticesFor`, `onRetryFlood` à `buildMapNotice`, `floodInformationDate` à `MapLegend`. `_MapViewState` lui donne `floodNoticesFor(state: floodLayer.state, anySectionInBounds: floodLayer.anySectionInBounds)`, `floodLayer.retry` et la date de l'état `Prete` ;
  - **focus** : `carteADuContenuFocalisable` (`map_view.dart:2152-2158`), branche `crues` → `floodLayer.labels.isNotEmpty` ;
  - **fenêtre « ⚠ Avertissement » de la carte** : `WarningLink(extraText: switch (scale) { MapScaleKind.crues => floodWarningWindowText, MapScaleKind.ecoulement => null, MapScaleKind.debit => null })` — les trois branches, sans joker (la règle des comparaisons) ;
  - **fiche** : `floodSheet` rendu dans la zone des fiches, comme `stationSheet` et `ondeSheet` (même défilement, `sheetScrollController`).

**Cas de test** — `map_view_flood_test.dart`, `testWidgetsOnWindows` (et deux `testWidgetsOnAndroid` à 360 × 640 : l'avis de lecture s'affiche et s'atteint ; une étiquette fait 48 de haut et son toucher ouvre la fiche), avec un `FloodLayerViewModel` sur un double de source piloté par `Completer` :
- Sur la lecture Crues, **aucun** marqueur de station ni de point ONDE, aucune pastille (critère 1).
- Gestes sur **Écoulement** ou **Débit** : **aucun** appel à la source Vigicrues (critère 16).
- **Review Focus 1** : carte de vigilance lue (trois tronçons), puis un changement sans rapport (geste, notification de `MapViewModel`) → `identical(tester.widget<PolylineLayer<FloodSectionCode>>(…) avant, … après)` vrai ; une **nouvelle** carte de vigilance → instance différente.
- La puce « Vigilance crues » : l'avis de lecture s'affiche, aucun trait, la légende sans date ; la source aboutit → traits, légende datée, plus d'avis.
- Un geste pendant le chargement → un seul appel à la source (Review Focus 2, de bout en bout).
- Échec → avis injoignable avec « Réessayer » ; un geste → aucun appel ; « Réessayer » → un appel, puis les traits.
- Toucher d'un trait → `onFloodSectionTap` avec le tronçon et la date de la carte.
- Fenêtre « ⚠ Avertissement » : sur `crues`, elle contient `floodWarningWindowText` ; sur `ecoulement`, non.
- Revenir sur `ecoulement` : aucun trait, aucune étiquette, les marqueurs ONDE reviennent.
- `warning_texts_test` : les trois textes exacts ; aucun mot de garantie ni verbe d'instruction (listes de `test/project/vocabulary_lists.dart`).
- `acceptance_features_test` : `floodWarningHeadline` et le corps cités par `crues.feature`.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view/map_view.dart lib/domain/warnings/warning_texts.dart test/domain/warnings/warning_texts_test.dart test/features/map/view/map_view_flood_test.dart test/project/acceptance_features_test.dart docs/04-ui.md && git commit -m "feat(map): la lecture Crues branchée dans la carte ; texte de crue de la fenêtre d'avertissement (M5 de T4)" -m "La vue relie ses deux ViewModels : la puce active la lecture, un geste relit l'emprise, « Réessayer » relance ; le calque des traits est réemployé comme même instance tant que la carte de vigilance ne change pas (flutter_map vide ses caches de projection à chaque mise à jour du widget). Sur la lecture Crues, la fenêtre « ⚠ Avertissement » porte le texte arbitré (BR-015) ; le modal du premier lancement ne change pas." -- lib/features/map/view/map_view.dart lib/domain/warnings/warning_texts.dart test/domain/warnings/warning_texts_test.dart test/features/map/view/map_view_flood_test.dart test/project/acceptance_features_test.dart docs/04-ui.md
```

---

## Lot 6 — La fiche tronçon, la composition, l'écran des sources

### Task F1 : `FloodSheetViewModel`

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `V2`, `W2` (gabarit du bulletin).
**Files:** créés `lib/features/flood_sheet/view_model/flood_sheet_view_model.dart`, `test/features/flood_sheet/view_model/flood_sheet_view_model_test.dart`

**Signatures** — imports permis : `package:flutter/foundation.dart` (`ChangeNotifier`), `lib/domain/` :
- `sealed class FloodSheetState { const FloodSheetState(); }` · `final class FicheTronconFermee` · `final class FicheTronconOuverte { const FicheTronconOuverte({required this.section, required this.informationDate, this.unopenedBulletinCount = 0}); final FloodSection section; final DateTime informationDate; final int unopenedBulletinCount; Uri get bulletinUri => floodBulletinUri(section.territoryCode); }`
- `final class FloodSheetViewModel extends ChangeNotifier { FloodSheetViewModel({required ExternalLinkOpener links}); FloodSheetState get state; void open(FloodSection section, DateTime informationDate); void close(); Future<void> openBulletin(); }`
- `openBulletin()` : en `Ouverte`, `links.open(bulletinUri)` ; `false` → `unopenedBulletinCount + 1` (l'avis est recréé à chaque échec, il se réannonce — précédent : `UnopenedLink.failureNumber`, `restrictions_view_model.dart:119-140`) ; en `Fermee` → rien. Une réponse qui arrive après `close()` ou après l'ouverture d'un autre tronçon n'écrit rien.

**Cas de test** (double d'`ExternalLinkOpener` qui note les adresses et rend un booléen piloté)
- `open` → `Ouverte` avec le tronçon et la date ; `close` → `Fermee` ; `close` sur `Fermee` → sans effet observable.
- `openBulletin` : l'adresse ouverte est `https://www.vigicrues.gouv.fr/bulletin_local/8` pour un tronçon du territoire `8` ; `false` deux fois → compte 2 ; `true` → compte inchangé.
- Ouvrir un second tronçon pendant qu'un lien du premier est en vol, puis le lien rend `false` → le compte du second reste 0.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/flood_sheet/view_model/flood_sheet_view_model.dart test/features/flood_sheet/view_model/flood_sheet_view_model_test.dart && git commit -m "feat(flood_sheet): FloodSheetViewModel, la fiche tronçon sans appel réseau (F1 de T4)" -m "La fiche s'ouvre avec le tronçon et la date de la carte lue ; le bulletin du territoire s'ouvre par ExternalLinkOpener, et chaque échec se compte pour se réannoncer. Une réponse tardive n'écrit rien." -- lib/features/flood_sheet/view_model/flood_sheet_view_model.dart test/features/flood_sheet/view_model/flood_sheet_view_model_test.dart
```

### Task F2 : L'avis « lien non ouvert » passe dans `lib/features/shared/`

**Agent :** mécanique (sonnet, effort moyen) — déplacement **sans changement de comportement**.
**Files:** créé `lib/features/shared/unopened_link_notice.dart`, `test/features/shared/unopened_link_notice_test.dart` · modifié `lib/features/restrictions/view/restrictions_screen.dart` (`_UnopenedLinkNotice`, l. 1335-1397, retiré ; ses deux usages, l. 211-218 et 1203-1206, sur le widget partagé)

**Signatures** : `class UnopenedLinkNotice extends StatefulWidget { const UnopenedLinkNotice({super.key}); }` — corps **identique** à `_UnopenedLinkNotice` (amène l'avis dans le champ au premier rendu, région annoncée, texte « Ce lien n'a pas pu être ouvert depuis l'application. Son adresse reste affichée ci-dessus. ») ; `const String unopenedLinkText = …;` publique, lue par le test. `UnopenedLink` et `LinkTarget` **restent** dans la tranche restrictions (R10).

**Cas de test** : le widget partagé (texte, région annoncée, amené dans le champ d'un défilement) ; **la suite des restrictions est le filet : inchangée et verte**, aucun de ses tests ne change.

- [ ] **Étape 1** — test du widget partagé, rouge, sortie recopiée ; **Étape 2** — déplacer ; `flutter test test/features/restrictions` → vert, sortie recopiée ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/shared/unopened_link_notice.dart test/features/shared/unopened_link_notice_test.dart lib/features/restrictions/view/restrictions_screen.dart && git commit -m "refactor(ui): l'avis « lien non ouvert » partagé entre les restrictions et la fiche tronçon (F2 de T4)" -m "Le widget sort de la vue des restrictions vers features/shared, sans changement de comportement ; ses types de lien restent dans la tranche restrictions (R10). La suite des restrictions est inchangée." -- lib/features/shared/unopened_link_notice.dart test/features/shared/unopened_link_notice_test.dart lib/features/restrictions/view/restrictions_screen.dart
```

### Task F3 : Le panneau de la fiche tronçon et l'encart de crue

**Agent :** mécanique (sonnet, effort élevé).
**Prérequis :** `F1`, `F2`, `M1`, `M5` (textes de crue).
**Files:** créés `lib/features/flood_sheet/view/flood_sheet_panel.dart`, `lib/features/flood_sheet/view/flood_warning_card.dart`, `test/features/flood_sheet/view/flood_sheet_panel_test.dart`, `test/features/flood_sheet/view/flood_warning_card_test.dart` · modifiés `test/project/acceptance_features_test.dart`, `docs/04-ui.md` (§ 5 : l'encart de crue parmi les emplacements de l'avertissement ; croquis de la fiche tronçon), `docs/03-conception.md` (tranche `flood_sheet`, `FloodLayerViewModel` dans la tranche carte) — code et spec dans le même commit (cadrage § 13)

**Signatures**
- `class FloodWarningCard extends StatelessWidget { const FloodWarningCard({super.key}); }` — titre `floodWarningHeadline`, corps `floodWarningBody` ; **non repliable** (aucun contrôle) ; `Semantics(container: true, liveRegion: true)` ; style de l'encart renforcé des restrictions (`lib/features/restrictions/view/reinforced_warning_card.dart`), **sans** son action (pas d'arrêtés ici).
- `class FloodSheetPanel extends StatelessWidget { const FloodSheetPanel({required this.state, required this.onClose, required this.onOpenBulletin, this.utcOffsetOf = systemUtcOffsetOf, super.key}); }` — `utcOffsetOf` rend le décalage injectable (précédent : `station_summary_sheet.dart:128`) ; `switch` sur `FloodSheetState` : `Fermee` → `SizedBox.shrink()` ; `Ouverte` → le cadre des fiches (`Material`, élévation 4, blanc, padding 12, bouton « Fermer la fiche » à droite, clé `floodSheetCloseButtonKey`, `minimumTapTarget` — modèle : `onde_summary_sheet.dart:263-404`), **sans étoile**, contenant **dans l'ordre** (cadrage § 8) :
  1. « Tronçon Vigicrues » (texte de 12, gras, couleur de texte par défaut — aucune fiche n'a de style « petites capitales »), le nom publié en gras, `WarningLink(extraText: floodWarningWindowText)` ;
  2. `FloodWarningCard()` ;
  3. `FloodLevelGauge(level, size: 26)` et `floodVigilanceTitle(level)` — pour l'inconnu, la jauge est le carré gris pointillé sans barre de `M1` : **aucune teinte de niveau** (cadrage § 8, « ni jauge colorée ») ;
  4. si `publishedFloodLegend(level)` n'est pas nul : « « <légende> » » puis, s'il y en a une, « « <explication> » », puis « — $floodSourceName » ; si le niveau est inconnu : `const String floodUnknownLevelText = "$floodSourceName a publié un niveau que cette application ne sait pas lire. Le bulletin sur $floodPublicSiteLabel fait foi.";` (guillemets doubles), ni citation ;
  5. `'Information de vigilance du ${formatLocalDateTime(informationDate, offsetOf: utcOffsetOf)} — $floodAttribution'` ;
  6. bouton `'Lire le bulletin sur $floodPublicSiteLabel'` → `onOpenBulletin` ; dessous, `SelectableText(bulletinUri.toString())` ; si `unopenedBulletinCount > 0`, `UnopenedLinkNotice(key: ValueKey<int>(unopenedBulletinCount))`.

**Cas de test** (`testWidgetsOnWindows` ; `testWidgetsOnAndroid` à 360 × 640 pour le défilement et les cibles)
- Ordre vertical : nom < encart < niveau < citation < date < bouton (positions `getTopLeft`).
- Orange (cas construit, `VC-04`) : « Vigilance orange », jauge à deux barres, les deux citations exactes (apostrophe courbe), « — Vigicrues » ; vert : légende seule, aucune explication.
- Inconnu : « Niveau de vigilance non reconnu », la phrase, **aucune** citation.
- Date : `DateTime.utc(2026, 10, 14, 13, 55, 31)`, `utcOffsetOf: (_) => const Duration(hours: 2)` → « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES ».
- Bouton → `onOpenBulletin` ; adresse sélectionnable affichée ; compte 1 → l'avis partagé ; compte 2 → un **nouvel** avis (clé différente).
- Encart : aucun contrôle de repli, région annoncée, au-dessus du niveau (`BR-015`).
- Fenêtre « ⚠ Avertissement » de la fiche → contient `floodWarningWindowText`.
- Android : bouton de fermeture et bouton du bulletin à 48 au moins ; la fiche défile dans la zone des fiches.
- `acceptance_features_test` : `floodUnknownLevelText`, le libellé du bouton, les titres de niveau cités par `crues.feature`.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/flood_sheet/view/flood_sheet_panel.dart lib/features/flood_sheet/view/flood_warning_card.dart test/features/flood_sheet/view/flood_sheet_panel_test.dart test/features/flood_sheet/view/flood_warning_card_test.dart test/project/acceptance_features_test.dart docs/04-ui.md docs/03-conception.md && git commit -m "feat(flood_sheet): la fiche tronçon — encart de crue, niveau, définition citée, date, bulletin (F3 de T4)" -m "Dans l'ordre du cadrage : nom publié, encart « CE N'EST PAS UN SYSTÈME D'ALERTE » non repliable (BR-015), niveau et jauge, définition de Vigicrues citée et attribuée, date et « © VIGICRUES », lien du bulletin du territoire ; un niveau inconnu est dit sans citation (BR-011)." -- lib/features/flood_sheet/view/flood_sheet_panel.dart lib/features/flood_sheet/view/flood_warning_card.dart test/features/flood_sheet/view/flood_sheet_panel_test.dart test/features/flood_sheet/view/flood_warning_card_test.dart test/project/acceptance_features_test.dart docs/04-ui.md docs/03-conception.md
```

### Task F4 : La composition dans `main.dart`, l'exclusivité des fiches, le test de la racine

**Agent :** **raisonnement** (opus, effort élevé) — racine que rien d'autre n'éprouve, Review Focus 5.
**Prérequis :** `W3`, `M5`, `F3`.
**Files:** modifiés `lib/main.dart`, `test/main_test.dart`

**Ce qui change**
- Composition (l. 119-175) : `final FloodVigilanceSource floodVigilanceSource = CachedFloodVigilanceSource(inner: VigicruesFloodVigilanceSource(client: vigicruesJsonClient(http.Client())));` — commentaire : la source n'est nommée qu'ici, hors de `lib/data/floods/` (confinement) ; `MartinPecheurApp` reçoit `floodLayerViewModel: FloodLayerViewModel(source: floodVigilanceSource)` et `floodSheetViewModel: FloodSheetViewModel(links: const UrlLauncherExternalLinkOpener())`.
- `MapView` (l. 370-530) reçoit `floodLayer`, `onFloodSectionTap: (FloodSection section, DateTime date) { stationSheetViewModel.close(); ondeSheetViewModel.close(); floodSheetViewModel.open(section, date); }`, `floodSheet: ListenableBuilder(listenable: floodSheetViewModel, builder: … FloodSheetPanel(state:, onClose: floodSheetViewModel.close, onOpenBulletin: () => unawaited(floodSheetViewModel.openBulletin())))`.
- **Exclusivité dans les deux sens** (cadrage § 8) : `floodSheetViewModel.close()` ajouté à `onStationTap`, `onOndeTap`, `onCloseSheets` (Échap), `onPointDesignated`, `onOpenFavorites`, et au chemin d'ouverture d'un favori.
- **Quitter la lecture Crues ferme la fiche** : dans `initState` de l'état de la racine, là où `K4` de T3 pose déjà ses deux écouteurs (`main.dart:240-256`), un écouteur sur `mapViewModel` qui réagit au **changement** d'échelle — dernière échelle mémorisée dans un champ, comparée par `switch` — et ferme la fiche tronçon quand on **quitte** `crues` (pas à chaque notification de `MapViewModel`) ; il suit `didUpdateWidget` et `dispose` comme les deux écouteurs existants (`main.dart:300-306`). La racine ne dispose aucun ViewModel aujourd'hui : rien ne change à ce sujet.
- Remise à zéro du défilement des fiches à l'ouverture de la fiche tronçon, comme pour les deux autres (`K4` de T3).

**Cas de test** — `test/main_test.dart`, en reprenant ses doubles et sa construction de `MartinPecheurApp` :
- **Review Focus 5** : fiche tronçon ouverte, puis tap d'une station (sur l'échelle débit), puis un point ONDE, Échap, désignation, « Favoris », ouverture d'un favori → à chaque fois la fiche tronçon est `Fermee` ; et l'inverse : fiche station ouverte, toucher d'un tronçon → fiche station fermée, fiche tronçon ouverte.
- Fiche tronçon ouverte, puce « Écoulement » → `Fermee`.
- Le panneau de la fiche tronçon apparaît dans la zone des fiches et revient en haut à chaque ouverture.
- La composition réelle : une lecture du **texte** de `lib/main.dart` dans `test/main_test.dart`, sur le modèle des l. 328-360 de ce fichier, vérifie que `CachedFloodVigilanceSource(` enveloppe `VigicruesFloodVigilanceSource(` construite sur `vigicruesJsonClient(` (et non sur un `JsonHttpClient` nu, qui perdrait les 20 s) ; l'état initial de `FloodLayerViewModel` est `NonDemandee` : aucun appel réseau au lancement.
- Une notification de `MapViewModel` **sans** changement d'échelle (geste) laisse la fiche tronçon ouverte.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/main.dart test/main_test.dart && git commit -m "feat: la lecture Crues et la fiche tronçon composées dans la racine (F4 de T4)" -m "La source Vigicrues, décorée par son cache de 30 min, n'est nommée qu'ici. Jamais deux fiches ensemble : ouvrir une fiche station ou ONDE, un favori, désigner un point, Échap ou quitter la lecture Crues ferment la fiche tronçon, et l'inverse. Aucun appel au lancement." -- lib/main.dart test/main_test.dart
```

### Task F5 : « D'où vient cette donnée ? » nomme Vigicrues

**Agent :** mécanique (sonnet, effort léger).
**Prérequis :** `W2`.
**Files:** modifiés `lib/features/shared/data_sources_view.dart`, `test/features/shared/data_sources_view_test.dart`

**Ce qui change** : une section titrée `floodSourceName`, après VigiEau et avant IGN : `const String dataSourcesFloodText = 'Niveaux de vigilance crues publiés par $floodSourceName, qui annonce une production au moins deux fois par jour. $floodAttribution — Licence Ouverte.';` (cadrage § 12.2, **retouche approuvée avec le cadrage**), puis `SelectableText(floodPublicSiteUrl)`.

**Cas de test** : le test des sources (l. 118-145) en attend **cinq** ; l'ordre des sections (l. 249-281) : hydrométrie, ONDE, VigiEau, **Vigicrues**, IGN ; le texte exact ; l'adresse sélectionnable.

- [ ] **Étape 1** — tests rouges, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/shared/data_sources_view.dart test/features/shared/data_sources_view_test.dart && git commit -m "feat(ui): « D'où vient cette donnée ? » nomme Vigicrues (F5 de T4)" -m "Une section après VigiEau : ce que Vigicrues publie, son rythme annoncé (et seulement annoncé, VC-05), « © VIGICRUES — Licence Ouverte » et l'adresse du site (VC-09)." -- lib/features/shared/data_sources_view.dart test/features/shared/data_sources_view_test.dart
```

---

## Lot 7 — Finitions

### Task K1 : Clavier, cibles, recouvrements à la taille du téléphone

**Agent :** **raisonnement** (opus, effort élevé).
**Prérequis :** `F4`.
**Files:** modifiés `test/features/map/view/map_overlays_phone_test.dart`, `test/features/map/view/map_entry_buttons_overlap_test.dart`, `test/features/map/view/map_filter_sheet_test.dart` (restrictions de `L1` levées), et le code de `lib/features/map/view/` ou `lib/features/flood_sheet/view/` **seulement si** une mesure le montre nécessaire

**Mesures** (les mêmes que T3, `K3`, étendues à `crues`) : à 800 × 740 (Windows) et 360 × 640 (Android), à 100 % et 200 % : la légende « Vigilance crues » (la plus longue des quatre) ne passe sous aucun bouton de la colonne du bas à droite ; l'avis de lecture et l'avis d'échec avec « Réessayer » s'atteignent (au besoin en faisant défiler la colonne, comme l'avis de carte vidée par le filtre de T3 — **même écart, déjà arbitré le 2026-10-14**, à constater) ; la fiche tronçon tient dans la zone des fiches et défile. Clavier (Windows) : Tab parcourt les étiquettes dans l'ordre de `labels`, puis la fiche, puis « ⚠ Avertissement » ; Entrée ouvre ; Échap ferme.

**Règle :** un recouvrement **nouveau** (que T3 n'avait pas) sur la légende ou un avis est **un constat remonté au commanditaire, avec la mesure** ; il ne se corrige pas par une disposition inventée.

- [ ] **Étape 1** — étendre les boucles à `MapScaleKind.values` ; tests rouges éventuels, sortie recopiée ; **Étape 2** — corriger ce qui relève de la tâche, remonter le reste ; **Étape 3** — critère de fin, commit.

```bash
git commit -m "test(map): la lecture Crues mesurée au clavier, aux cibles et aux tailles de téléphone (K1 de T4)" -m "<mesures relevées, avant et après, et constats remontés>" -- <chemins de task-K1-paths.txt>
```

### Task X1 : Documents de T4 ; « Ajouté » de `0.5.0`

**Agent :** mécanique (sonnet, effort moyen).
**Prérequis :** `K1`.
**Files:** modifiés `docs/04-ui.md` et `docs/03-conception.md` **seulement** pour ce que `K1` a changé (`M5` et `F3` les ont écrits avec leur code), `docs/tracabilite.md` (section `Should` : `US-21`, `BR-015`, `UC-009`, avec les fichiers de test qui les éprouvent), `test/project/tracabilite_test.dart` (si la section `Should` y est verrouillée), `docs/project-state.md` (décompte des tests, seul endroit où il s'écrit), `CLAUDE.md` (disposition du dépôt : `domain/floods/`, `data/floods/`, `features/flood_sheet/` ; invariant « Un widget partagé… » : la liste de `features/shared/`, trois fichiers de plus ; stack : ligne « Carte » — `PolylineLayer` employé ; aucun décompte ni état daté), `docs/README.md`, `CHANGELOG.md` (« Ajouté » de `0.5.0`, écrit en une fois d'après le code livré)

- [ ] **Étape 1** — tests du verrou de traçabilité rouges si la section `Should` s'allonge, sortie recopiée ; **Étape 2** — écrire ; **Étape 3** — critère de fin, commit.

```bash
git commit -m "docs: documents de T4 remis d'accord avec le code ; « Ajouté » de 0.5.0 (X1 de T4)" -- <chemins de task-X1-paths.txt>
```

---

## Lot 8 — La porte de T4, sur Windows **et** Android

### Task H1 : `NFR-01` sur la lecture Crues (commanditaire)

**Prérequis :** `X1`.

Commande, au commanditaire :

```bash
flutter run -d windows --profile --dart-define=FLUIDITY_PROBE=true
```

Attendu : l'application s'ouvre ; le commanditaire active « Vigilance crues », attend les traits, puis fait les gestes `G1`, `G2`, `G3` de `docs/nfr.md` (`NFR-01`) et recopie les percentiles que la sonde affiche. **Seuils :** rastérisation p90 ≤ 16,7 ms, trames en retard < 5 %. Relever aussi la **durée du premier chargement** (de l'appui sur la puce aux traits), décodage compris (constat h).

**Règle :** seuil tenu → consigné dans `docs/nfr.md`, ligne `NFR-01` (ligne « Crues », datée), et retiré de la section « Non vérifié » de `docs/sources/vigicrues.md`, avec la durée du premier chargement. Seuil dépassé → **arrêt et question fermée au commanditaire** : simplification des tracés à la lecture (R5, ~111 m : 35 661 points, `VC-06`) ou autre ; aucune optimisation lancée sans réponse.

### Task P1 : L'exécutable Windows de `0.5.0`, lancé hors Flutter (commanditaire)

**Prérequis :** `H1`.

```bash
flutter build windows --release
```

Attendu : `Built build\windows\x64\runner\Release\martinpecheur.exe`. Puis lancer cet exécutable **hors Flutter** (double-clic). La boucle principale relève poids et nombre de fichiers du dossier (`NFR-06`).

**Constats** (cadrage § 11), dictés par identifiant et recopiés mot pour mot : `P1-a` à `P1-g`, et `P1-j` si un épisode de vigilance est en cours. `P1-f` : couper le réseau **avant** d'activer la lecture, puis le rétablir et « Réessayer ».

### Task P2 : Android, émulateur `Pixel_7` (commanditaire)

**Prérequis :** `P1`.

```bash
flutter emulators --launch Pixel_7
```

```bash
flutter run -d emulator-5554
```

Attendu : construction et lancement sur l'émulateur. **Constats** : `P2-a` à `P2-g` et `P2-i` (cibles de 48 au toucher, étiquettes lisibles à la taille du téléphone), `P2-j` si un épisode est en cours.

### Task P3 : Clore la version `0.5.0`

**Agent :** mécanique (sonnet, effort léger).
**Prérequis :** `P1`, `P2`.
**Files:** `CHANGELOG.md` (`## [0.5.0] — <date>`, « Constaté à l'exécution » d'après les constats recopiés, « Non vérifié » d'après ce qui n'a pas été dit — dont les niveaux 2 à 4 si aucun épisode n'a eu lieu), `test/project/changelog_test.dart`, `docs/project-state.md` (statut de T4, constats et non-constats), `CLAUDE.md` (ligne T4 du tableau « Où on en est » seulement : son statut grossier, « ✅ close — `0.5.0` » si la porte est franchie), `docs/nfr.md`, `docs/sources/vigicrues.md` (section « Non vérifié » tenue à jour : Android, rythme, niveaux 2 à 4)

- [ ] Tests du `CHANGELOG` rouges, sortie recopiée ; écrire ; critère de fin ; commit. **Aucun tag, aucune poussée, aucune fusion sans demande.**

---

## Décisions à valider avec le plan

### Au commanditaire — arbitrées le 2026-10-14

Les treize arbitrages du cadrage (§ 2), dont le texte de l'écran des sources retouché (approuvé avec le cadrage), et les arbitrages 11 (emprise et ancre par les segments) et 12 (rafraîchissement au geste suivant), rendus à la relecture de ce plan.

### Prises par la boucle principale, réversibles

| # | Décision | Tâche |
|---|---|---|
| D1 | ⚠️ **Change un texte approuvé** (cadrage § 7.1 et R15, corrigés dans le commit de ce plan) : sur la lecture Crues, `loadFor` lit toujours l'asset local au lieu de « ne rien lire » — sinon un retour sur une autre échelle trouvait une emprise « déjà demandée » jamais lue (`selectScale(ecoulement)` relit l'ONDE sur `_lastRequestedBounds`, `map_view_model.dart:1016-1019`) ; aucun appel réseau de plus, rien n'en est dessiné | `L1` |
| D10 | `anySectionInBounds` vaut `null` tant qu'aucune emprise n'est connue : l'absence ne se dit que sur `false` | `L2`, `M4` |
| D11 | Contour de 2 px **de chaque côté** : `borderStrokeWidth: 4` (la bordure se partage entre les deux côtés du trait) | `M1`, `M2` |
| D12 | Une fiche tronçon ouverte garde la date et le niveau de la carte avec laquelle elle s'est ouverte, quand une nouvelle carte arrive (R12) : elle est datée, ce n'est pas une contradiction ; risque accepté, dit au commanditaire | `F1` |
| D2 | Une date sans fuseau explicite est illisible (`Z` ou `±HH:MM` exigés) | `W1` |
| D3 | `NivInfViCr` : seul un `int` de 1 à 4 est reconnu ; `2.0` ou `'2'` sont inconnus | `W1` |
| D4 | `vigicruesJsonClient` porte le délai de 20 s, testé, plutôt que `main.dart` | `W2` |
| D5 | Noms d'état préfixés `LectureCrues…` et `FicheTroncon…` (les noms nus existent dans la tranche fiche station) | `L2`, `F1` |
| D6 | Une branche `crues` inatteignable lève une `StateError` dite telle (pastilles) | `L1` |
| D7 | Largeur d'étiquette 168, contenu réduit au besoin (`FittedBox`), jamais coupé | `M2` |
| D8 | La fermeture de la fiche en quittant la lecture Crues vit dans un écouteur de la racine, testé par `test/main_test.dart` | `F4` |
| D9 | Ordre de tabulation des étiquettes : distance au centre, puis code | `V3` |

## Récapitulatif

| Lot | Tâches | Agents |
|---|---|---|
| 1 — Documents | `O1`, `O2`, `O3`, `O4` | sonnet |
| 2 — Domaine | `V1`, `V2`, `V3` | sonnet |
| 3 — Données | `W1` (opus), `W2`, `W3` | — |
| 4 — Lecture | `L1` (opus), `L2` (opus) | — |
| 5 — Carte | `M1`, `M2` (opus), `M3`, `M4`, `M5` (opus) | — |
| 6 — Fiche, composition | `F1`, `F2`, `F3`, `F4` (opus), `F5` | — |
| 7 — Finitions | `K1` (opus), `X1` | — |
| 8 — Porte | `H1`, `P1`, `P2` (commanditaire), `P3` | — |

**28 tâches**, dont **3** lancées par le commanditaire (`H1`, `P1`, `P2`, et les constats qu'elles portent).

## Ordre d'exécution

```
O1 → O2 → O3 → O4
V1 → V2 → V3            (après O2 : domain-model.md)
W1 → W2 → W3            (après V2)
L1 (après O4) ; L2 (après V3, W3, L1)
M1 (après V1, peut courir avec W*) ; M2 (après L2, M1) → M3 → M4 → M5
F1 (après V2, W2) ; F2 (indépendante) ; F3 (après F1, F2, M1, M5) ; F4 (après W3, M5, F3) ; F5 (après W2)
K1 (après F4) → X1 → H1 → P1 → P2 → P3
```

Parallélisme permis : `M1`, `F1`, `F2`, `F5` sur des fichiers disjoints des tâches en cours ; **jamais** deux tâches qui touchent `map_view.dart`, `domain-model.md`, `acceptance_features_test.dart` ou `main.dart` en même temps (tableau « Partages entre tâches »).

## Les choses à ne jamais faire dans ce plan

- Calculer, déduire ou prévoir un niveau, un seuil, un risque de crue ; rapprocher un débit d'une crue (`BR-015`).
- Tracer un trait vert par défaut : pendant un chargement, après un échec, pour une entité illisible (`BR-007`).
- Reconstruire le `PolylineLayer` à chaque `build` (Review Focus 1).
- Relancer un téléchargement de 2,2 Mo sans geste de l'usager après un échec (arbitrage 10).
- Écrire un nom de champ de l'API hors de `lib/data/floods/` et `lib/main.dart`, même en commentaire.
- Ranger un cas construit (niveaux 2 à 4) sous `test/fixtures/`.
- Reformuler une citation de Vigicrues, ou un texte du cadrage § 12.2.
- Ajouter une bibliothèque ; toucher au modal du premier lancement ; écrire `testWidgets(` nu ; comparer `MapScaleKind` par `==`.
- Pousser, fusionner, taguer sans demande ; committer `windows/flutter/generated_plugin_registrant.h`.

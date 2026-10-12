# T3 — Favoris, filtres, fraîcheur : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** l'usager **retrouve les lieux qu'il suit** — une étoile sur la fiche station et la fiche ONDE, un écran « Favoris » qui survit au relancement (`US-14`) — et **réduit la carte à ce qu'il cherche** — une feuille « Filtres » par état d'écoulement, département et fraîcheur du débit, toujours visible quand elle agit (`US-13`). Les trois dettes de T2 sont soldées. Version `0.4.0`, porte franchie sur **Windows et Android** (arbitrage 7).

**Architecture:** feature-first + MVVM (`ADR-014`), inchangée. Deux dossiers de domaine nouveaux, Dart pur : `lib/domain/filters/` (valeur `MapFilter` et prédicats) et `lib/domain/favorites/` (`Favorite` clos, contrat `FavoriteRepository`). Une implémentation sous `lib/data/preferences/` (`shared_preferences`, une clé, JSON versionné). Une tranche nouvelle, `lib/features/favorites/{view,view_model}/` ; les filtres restent dans la tranche `map`. `main.dart` reste la seule racine de composition. Aucune bibliothèque d'état, aucune bibliothèque nouvelle.

**Tech Stack:** Flutter 3.47.4 / Dart 3.13.3 · `flutter_map` 8.3.2 · `package:http` · `shared_preferences` ^2.5.5 (déjà liée) · cibles **Windows** et **Android** (émulateur `Pixel_7`) à la porte ; iOS configuré, jamais compilé.

**Spec:** [`docs/superpowers/specs/2026-10-12-cadrage-t3-design.md`](../specs/2026-10-12-cadrage-t3-design.md) — **approuvé par le commanditaire le 2026-10-12, textes de § 10.1 compris**. Ce plan l'applique, il ne le rediscute pas : périmètre (§ 3), huit arbitrages (§ 2), conception (§ 5 à § 7), critères d'acceptation (§ 8), constats d'écran (§ 9), textes (§ 10.1), décisions réversibles (§ 10.2), documents (§ 11). L'exécutant d'une tâche lit le cadrage **et** sa tâche.

⚠️ **Identifiants de tâche propres à ce plan.** `B1`, `K1`, `X1`, `P1`… existent aussi dans les plans de T1 et de T2. Hors de ce document (`project-state.md`, messages de commit), on écrit **`T3-B1`**.

## Contraintes globales

Chaque tâche les porte, même quand elle ne les répète pas.

- **Aucune bibliothèque nouvelle** (arbitrage 2). `pubspec.yaml` ne change que de version.
- **Les sept règles de couches** de `test/architecture/layers_test.dart` et l'isolement du domaine (`domain_isolation_test.dart`) restent verts : `lib/domain/` Dart pur ; aucun fichier de `lib/features/` n'importe `lib/data/` ; une tranche n'importe pas une autre tranche ; un ViewModel n'importe aucun widget ; le partagé vit dans `lib/features/shared/` ; `main.dart` compose.
- **Aucun seuil nouveau.** 2 h et 24 h se lisent dans `lib/domain/observation/freshness.dart` (`ancienneApres`, `perimeeApres`), 60 jours dans `lib/domain/onde/campaign_age.dart` (`campagneAncienneApres`). Un prédicat ne recopie jamais une borne. Un test écrit ses instants à partir des constantes (`now.subtract(ancienneApres)`, `now.subtract(perimeeApres - const Duration(seconds: 1))`). Seules exceptions : les textes exacts de § 10.1 du cadrage et les libellés (« Moins de 2 h »), comparés au mot.
- **On ne qualifie jamais un débit** (`BR-003`) : aucun des mots *suffisant, insuffisant, normal, bon, sûr* dans un texte, un identifiant ou un commentaire rendu à l'usager.
- **Textes d'écran : ceux de § 10.1 du cadrage, mot pour mot**, vouvoiement, aucun verbe portant sur un usage de l'eau (`BR-014`). Un texte qui manque se demande, il ne s'invente pas.
- **Nomenclatures closes** : `sealed class` + `switch` exhaustif sans `default`, une branche pour l'inconnu (`BR-011`).
- **Tout test de widget nomme sa plateforme** : `testWidgetsOnWindows` ou `testWidgetsOnAndroid` (`test/support/`), jamais `testWidgets(` nu, même en commentaire de fin de ligne — verrouillé à partir de `N1`. **Un test dont la fenêtre fait moins de 600 px de large est un test de téléphone : `testWidgetsOnAndroid`**, titre « Android : … ».
- **Code et spec dans le même commit** : le document que touche une tâche (règle métier, cas d'usage, Gherkin, `domain-model.md`, `glossary.md`) est écrit par cette tâche, avec le verrou de `test/project/` qui bouge.
- **Version** `0.4.0+4`, ouverte par `O1`, datée par `P3`.
- **Git** : un commit par tâche, par liste de chemins explicite ; Conventional Commits en français ; **aucune ligne d'attribution** ; rien n'est poussé, fusionné ni tagué sans demande du commanditaire. `windows/flutter/generated_plugin_registrant.h` et `android/.kotlin/` sont des artefacts de poste : jamais committés.

## Review Focus

Cinq conditions que le cadrage implique sans les dire, les plus probables d'abord. Chacune a son cas de test dans la tâche nommée ; le relecteur de cette tâche vérifie qu'il y est.

| # | Condition | Ce qu'une personne raisonnable attend | Tâche |
|---|---|---|---|
| 1 | Une écriture de favori échoue alors que `shared_preferences` a déjà mis la valeur en mémoire (`shared_preferences_legacy.dart`, `_setValue` écrit le cache avant le magasin) | ce que l'écran montre est ce qui sera retrouvé au relancement | `S3` (écriture compensatoire) |
| 2 | Filtre département sur le débit, sous le zoom 9, carte posée sur un autre secteur : la pastille du département existe, hors écran | l'avis « Les filtres masquent tous les lieux du secteur affiché », pas une carte vide et muette | `F7` |
| 3 | Deux appuis rapprochés, ou Entrée répétée, sur « Favoris » | une seule route, un seul retour | `S11` (garde) |
| 4 | La colonne à cinq boutons recouvre la légende, la fiche ou l'attribution | aucun recouvrement à 800 × 740 (Windows) ni à 360 × 640 (Android), les deux tailles du constat f ; sinon **arrêt et question au commanditaire**, l'emplacement étant son arbitrage 8. En paysage court (640 × 360) un recouvrement est un constat remonté, il ne bloque pas | `F10c` (rectangle réservé), `S10` (rendu réel), `K3` |
| 5 | Un test de téléphone au titre muet devient un test Windows pendant la migration : plus aucun test ne voit un débordement à cibles de 48 | tout test de moins de 600 px de large reste nommé Android | `N9` (relecture listée) |

---

## Cible et périmètre

| Cible | État dans ce plan |
|---|---|
| **Windows** | construite en release, exécutable lancé hors Flutter (`P1`) ; constat anticipé sur l'écoulement dès la fin du lot 4 (`C1`) |
| **Android** | **jamais construite à ce jour** (`A1` de T2, toujours due). La porte de T3 l'exige (`P2`) : T3 ne se clôt pas tant qu'Android n'est pas construit et vu. Publication (`A⏸3`, `A⏸5`) et appareil réel (`A⏸4`) restent ⏸ |
| **iOS** | configuré, jamais compilé |

**Ce que T3 fait :** (a) étoile sur les deux fiches, ajouter et retirer · (b) écran « Favoris », identité seule, aucune mesure · (c) favoris persistés en `shared_preferences`, tolérants à l'illisible · (d) feuille « Filtres » : six états d'écoulement, département sur les deux échelles, fraîcheur sur le débit seul (2 h, 24 h) · (e) bouton « Filtres » qui montre le filtre actif, avis de carte vidée par le filtre · (f) dette 1 : chaque test de widget nomme sa plateforme · (g) dette 2 : décisions métier sorties de la vue des restrictions · (h) dette 3 : une seule barre de titre d'écran plein.

**Ce que T3 ne fait pas :** aucune courbe (`US-11`), aucune recherche (`US-16`), aucun `integration_test/` (arbitrage 1) · aucun recentrage de la carte sur un favori (arbitrage 6) · aucun critère de fraîcheur sur l'écoulement, aucun balayage ONDE au-delà de 60 jours (arbitrage 5) · aucun favori sur un point désigné, aucun seuil par lieu (T5) · aucun moteur de stockage structuré (arbitrage 2) · aucun filtre persisté · aucune tranche `settings`.

⚠️ **Échéance.** La carte d'écoulement ne montre que 60 jours et les campagnes ONDE s'arrêtent en septembre : passé fin novembre, plus aucun point ONDE à l'écran avant mai (💭 date de la dernière campagne 2026 non vérifiée par appel réel). **Les lots 2 à 4 passent donc avant les favoris**, et `C1` se fait dès que la feuille est branchée.

---

## Qui lance quoi

| Commande | Lancée par |
|---|---|
| `flutter analyze`, `flutter test`, `dart format`, `flutter pub get` | **Claude**, dans le bac à sable |
| `flutter run -d windows`, `flutter build windows --release`, lancement de l'exécutable, `flutter emulators --launch Pixel_7`, `flutter run -d emulator-5554`, tout constat à l'écran | **le commanditaire** |

Toute commande du commanditaire est donnée **seule dans son bloc `bash`**, avec le **résultat attendu énoncé**, puis **constatée et recopiée**. Jamais supposée.

## Critère de fin, identique pour chaque tâche — dit ici une seule fois

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

Attendu : `No issues found!` · tous les tests passent · code de sortie **0**. Recopier le **nombre total de tests** (repère de départ : **2 330**, `dev` à `1247de3`, constaté le 2026-10-12) : il ne fait que croître, sauf suppression justifiée dans le message de commit. **Un commit par tâche** (par fichier pour les migrations `N2` et suivantes), par **liste de chemins explicite** (`git add -- <chemins>` puis `git commit -- <chemins>`). Un fichier régénéré hors de la liste se signale, il ne se committe pas.

⚠️ **Brief de tout sous-agent, en tête :** interdiction de `git stash`, `git checkout`, `git restore`, `git reset`, `git clean`, `git add`, `git commit`, `git push` ; il rend la **sortie rouge brute** de son étape 1 avant d'implémenter. Au retour, la boucle principale relit `git status`, relance elle-même le critère de fin, fait relire par un second agent, puis committe : un rapport d'agent n'est pas une preuve. Plusieurs sessions peuvent écrire dans le même arbre : `git branch --show-current` et `git status` avant chaque commit.

**Niveau d'agent** (indiqué par tâche) : **mécanique** = `general-purpose` sonnet, effort léger ou moyen, signatures et cas dictés ; **raisonnement** = opus, effort élevé, conception, verrou d'architecture ou refonte à comportement verrouillé. Une relance au plus deux fois : l'effort d'abord, le modèle ensuite. **Trois échecs sur le même point : arrêt et question.**

---

## Structure de fichiers

### lots 0, 1, 8, 9, 10 (socle, dettes, finitions, porte)

```
pubspec.yaml                                   version 0.4.0+4 (O1)
CHANGELOG.md                                   [0.4.0] ouverte (O1), « Ajouté » écrit en une fois (X3), datée (P3) ;
                                               aucun autre lot n'y touche

lib/features/shared/
  screen_layout.dart                           + ScreenTitleBar ; importe tap_target.dart (B1)
  data_sources_view.dart                       _TitleBar supprimée, emploie ScreenTitleBar (B1)
lib/features/restrictions/view/
  restrictions_screen.dart                     _TitleBar supprimée (B1) ; _DecreeEntry, _decreeEntries,
                                               _isSameZonesAsDecree supprimés, _validityLine réduit à la
                                               mise en phrase, lit le domaine (R3)
lib/features/restrictions/view_model/
  restrictions_view_model.dart                 NON MODIFIÉ (R3 : la vue lit le domaine)
lib/domain/restrictions/
  decree_documents.dart                        DecreeDocument, decreeDocumentsOf,
                                               coversSameZonesAsSoleRestrictionDecree (R1)
  zones_at_point.dart                          + lacksSurfaceWaterZone, canStateSurfaceWaterAbsence (R2)
lib/features/{map,station_sheet,onde_sheet,favorites}/view/
                                               corrections au plus court, seulement si K1 ou K2 rougit

test/support/
  android_platform.dart                        testWidgetsOnAndroid (N1)
  windows_platform.dart                        commentaire de convention réécrit, code inchangé (N1)
  platform_helpers_test.dart                   les deux assistants posent et rendent la plateforme (N1)
test/project/
  changelog_test.dart                          groupe « version 0.4.0 » (O1), « Ajouté » (X3), datée (P3)
  screen_title_bar_test.dart                   un seul fichier de lib porte BackButton (B1)
  widget_test_platform_test.dart               verrou : aucun testWidgets nu hors test/support ;
                                               29 exceptions (N1) → 0 (N9)
  domain_model_doc_test.dart                   typesDuDomaine + DecreeDocument (R1)
  tracabilite_test.dart                        UC-007, UC-008, US-13, US-14 ; commentaire corrigé (X2)
test/features/shared/
  screen_layout_test.dart                      ScreenTitleBar (B1 ; cas à 360 × 640 sous Android), retour de 48 (K2)
test/domain/restrictions/
  decree_documents_test.dart                   les trois décisions, sans rendu (R1)
  zones_at_point_test.dart                     + absence d'eaux superficielles (R2)

test/  les 29 fichiers migrés, un commit chacun :
  main_test.dart  diagnostics/fluidity_probe_panel_test.dart                              (N2)
  features/goldens/{onde_marker,station_marker}_golden_test.dart   images inchangées        (N3)
  features/shared/{data_sources_view,keyboard_focus_ring,tap_target,warning_link}_test.dart
  features/warnings/view/initial_warning_view_test.dart                                    (N4)
  features/station_sheet/view/station_summary_sheet_test.dart
  features/onde_sheet/view/onde_summary_sheet_test.dart                                    (N5)
  features/restrictions/view/{drought_severity_badge_size,drought_severity_badge,
    reinforced_warning_card,restrictions_scale_text,restrictions_screen}_test.dart         (N6)
  features/map/view/{area_cluster_marker,designate_center_button,ign_attribution_badge,
    map_controls,map_empty_states,map_legend,map_scale_chips,onde_marker,
    station_marker}_test.dart                                                              (N7)
  features/map/view/{map_view,map_keyboard,map_designation}_test.dart                      (N8)
  features/map/view/map_overlays_phone_test.dart                                           (N9)
test/features/map/view/
  map_keyboard_test.dart  map_overlays_phone_test.dart   + ordre de tabulation avec les deux boutons (K1)
  map_view_test.dart  map_overlays_phone_test.dart       + hauteur de la colonne à cinq boutons,
                                                         390 × 844, tailles intermédiaires, 200 % (K3) ;
                                                         800 × 740 et 360 × 640 sont de F10c et S10,
                                                         640 × 360 de S10 (cité, non remesuré)
  map_entry_buttons_test.dart  map_filter_sheet_test.dart  map_empty_states_test.dart     cas manquants (K1, K2)
test/features/shared/favorite_star_button_test.dart
test/features/{station_sheet,onde_sheet}/view/*_summary_sheet_test.dart
test/features/favorites/view/favorites_screen_test.dart                    cas manquants (K1, K2)

docs/
  superpowers/specs/2026-10-12-cadrage-t3-design.md           statut « approuvé » (O1)
  superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md  l. 91 corrigée, phrase d'origine barrée (O1)
  project-state.md                             en-tête, arbitrages du 2026-10-12, lignes T2, T3, T5 (O1) ;
                                               point 59 : (5) barre (B1), (4) (N9), (5) décisions (R3) ;
                                               mesures (K3) ; état d'ensemble (X3) ; constats (P1, P2, P3)
  README.md                                    cadrage et plan de T3 indexés (O1) ; UC, .feature (X3)
  plan-de-tests.md                             plateforme nommée, integration_test : tranche ultérieure (N1)
  domain-model.md                              DecreeDocument (R1), deux membres de ZonesAtPoint (R2)
  tracabilite.md                               l. 74-79 (N9) ; section Should, UC-007, UC-008 (X2)
  02-specifications.md  03-conception.md       US-11, US-16, US-13 ; stockage, tranches, clé du favori (X1)
  04-ui.md                                     mesures de la colonne (K3) ; croquis manquants (X1)
  nfr.md                                       NFR-06 : poids de l'exécutable 0.4.0 (P1)
CLAUDE.md                                      lignes T2, T3, T5 (O1) ; shared/ (B1) ; tests (N9) ;
                                               disposition (R3) ; ensemble (X3) ; porte (P3)
```

**Verrous qui bougent avec chaque document**

| Document ou fichier | Verrou | Tâches |
|---|---|---|
| `pubspec.yaml`, `CHANGELOG.md` | `test/project/changelog_test.dart` | `O1`, `X3`, `P3` |
| `docs/domain-model.md` | `test/project/domain_model_doc_test.dart` (`typesDuDomaine` ; `ZoneRestriction` reste interdit dans le document) | `R1` |
| `docs/tracabilite.md` | `test/project/tracabilite_test.dart` (tout chemin `.dart` cité doit exister) | `N9`, `X2` |
| `docs/nfr.md` | `test/project/nfr_doc_test.dart` (une ligne `NFR-` cochée nomme ce qui l'a constatée) | `P1` |
| `lib/features/**`, `lib/domain/**` (textes) | `test/project/vocabulary_test.dart` — aucun texte d'écran nouveau dans ces lots | `B1`, `R1`-`R3` |
| `lib/features/shared/screen_layout.dart` | `test/architecture/layers_test.dart`, règle `shared-sans-tranche` | `B1` |
| `lib/domain/restrictions/decree_documents.dart` | `layers_test.dart` règle `domaine-ferme` ; `test/architecture/domain_isolation_test.dart` | `R1` |
| `lib/features/restrictions/view/restrictions_screen.dart` | `layers_test.dart` règles `features-vers-data`, `feature-vers-feature` (inchangées) | `B1`, `R3` |
| tout fichier sous `test/` | `test/project/widget_test_platform_test.dart` (nouveau) | `N1` à `N9`, puis tous les lots |
| `docs/acceptance/*.feature`, `docs/br/`, `docs/use-cases/` | `acceptance_features_test.dart` — lots 2 à 7 ; `X1` ne fait que vérifier | — |
| `project-state.md`, `README.md`, `CLAUDE.md`, `plan-de-tests.md`, `02`, `03`, `04`, cadrages | **aucun test ne les lit** (recherche du 2026-10-12 dans `test/project/` et `test/architecture/`) : relecture par un second agent | `O1`, `N1`, `X1`, `X3` |

### lots 2, 3 et 4 (filtres de la carte, `US-13`)

```
lib/domain/
  filters/map_filter.dart                MapFilter, DischargeFreshnessCriterion, dischargeFreshnessAdmits,
                                         dischargeFreshnessCriterionLabel, filterableFlowCategories (F1)
  filters/map_filter_predicates.dart     filterKeepsDepartement, filterKeepsOndeObservation,
                                         filterKeepsStationPoint, filterKeepsStation, departementsOf (F2)
lib/features/map/
  view_model/map_filter_scale.dart       mapFilterActiveFor(MapFilter, MapScaleKind) — le seul endroit
                                         ou le filtre rencontre l echelle (F4)
  view_model/map_view_model.dart         + filter, filterActive, applyFilter, clearFilter ; marqueurs
                                         individuels retenus (F4) · sources de regroupement filtrees (F5) ·
                                         prechargement borne au departement, departements() (F6) ·
                                         filterHidesEverything (F7) — constructeur INCHANGE
  view/map_empty_states.dart             + FilterHidesEverything, FilterHidesEverythingNotice, textes,
                                         mapNoticesFor(filterHidesEverything:), buildMapNotice(onClearFilters:) (F8)
  view/map_filter_sheet.dart             MapFilterSheet, brouillon dans l etat de la feuille, textes de § 10.1 ;
                                         cles mapFilterClearKey, mapFilterCategoryKey, mapFilterDepartementKey,
                                         mapFilterFreshnessKey, mapFilterCloseKey (« Fermer »), mapFilterApplyKey (F9)
  view/map_round_button.dart             MapRoundButton, extrait de _MapControlButton (F10a)
  view/map_entry_buttons.dart            MapEntryButtons, bouton « Filtres » et sa forme active (F10a) ;
                                         le lot 7 y ajoute « Favoris », au-dessus
  view/map_controls.dart                 emploie MapRoundButton, comportement inchange (F10a)
  view/map_view.dart                     buildMapOverlays : + filterHidesEverything, onClearFilters (F8),
                                         + filterActive, onOpenFilters, mapTraversalOrderEntryButtons (F10b) ;
                                         _MapViewState : + _handleOpenFilters (F10b)
lib/main.dart                            NON TOUCHE par ces trois lots

test/
  domain/filters/map_filter_test.dart                        (F1)
  domain/filters/map_filter_predicates_test.dart             (F2)
  features/map/view_model/map_filter_scale_test.dart         (F4)
  features/map/view_model/map_view_model_filter_test.dart    (F4, F5, F6, F7) — doubles recopies de
                                                             map_view_model_test.dart, qui reste INCHANGE
  features/map/view/map_empty_states_test.dart               + cas de l avis du filtre (F8)
  features/map/view/map_filter_sheet_test.dart               (F9)
  features/map/view/map_entry_buttons_test.dart              (F10a)
  features/map/view/map_filter_wiring_test.dart              MapView + feuille + MapViewModel (F10b)
  features/map/view/map_view_test.dart                       appels de buildMapOverlays (F8, F10b) ;
                                                             groupe « 800 × 740 », l. 1202-1662, + MapEntryButtons
                                                             (F10b) ; place du cinquieme bouton (F10c)
  features/map/view/map_overlays_phone_test.dart             idem, 360 × 640 (F8, F10b) ; place du cinquieme
                                                             bouton a 360 × 640 et 640 × 360 (F10c)
  features/map/view/map_keyboard_test.dart                   ordre de tabulation + « Filtres » (F10b)
  features/map/view/map_controls_test.dart                   INCHANGE : filet de l extraction (F10a)
  diagnostics/fluidity_probe_panel_test.dart                 appel de buildMapOverlays (F8, F10b)
  project/domain_model_doc_test.dart                         typesDuDomaine + MapFilter,
                                                             DischargeFreshnessCriterion (F1)
  project/acceptance_features_test.dart                      + filtres.feature, sa section US-13, ses BR,
                                                             ses libelles lies au code (F7, F8, F9, F10b)
  support/android_platform.dart                              CONSOMME (cree au lot 1, tache N1)

docs/
  br/BR-007-…md  br/BR-008-…md  br/BR-009-…md                amendements de § 10.1 (a) (F3)
  use-cases/UC-007-filtrer-la-carte.md                       cree (F3)
  use-cases/UC-001-consulter-la-carte-autour-de-moi.md       + A7, renvoi a UC-007 (F3)
  acceptance/filtres.feature                                 cree (F7 : 11 scenarios) ; + 2 (F8), + 6 (F9),
                                                             + 2 (F10b) — 21 scenarios, dont un plan a 4 exemples
  domain-model.md                                            MapFilter, critere de fraicheur (F1) ; regle
                                                             « l inconnu reste affiche » (F2)
  glossary.md                                                ligne « Filtre » (F1)
  04-ui.md                                                   l. 633 (F3) ; croquis de l avis (F8) ; croquis
                                                             « Filtres » corrige, l. 534-573 (F9) ; colonne
                                                             du bas a droite (F10b)
  README.md                                                  ligne UC-007 (F3) ; ligne acceptance/ : filtres.feature (F7)
  project-state.md  ·  CLAUDE.md                             constat anticipe, ligne T3, arborescence (C1)
```

**Ce que ces lots ne touchent pas, dit pour l'assembleur :** `docs/tracabilite.md` et `test/project/tracabilite_test.dart` (`UC-007`, `US-13` : lot 9) ; `docs/02-specifications.md`, `docs/03-conception.md` (lot 9) ; `lib/main.dart` ; `CHANGELOG.md`.

### lots 5, 6, 7 (favoris, `US-14`)

```
lib/domain/
  favorites/favorite.dart                Favorite (sealed), StationFavorite, OndePointFavorite, UnreadableFavorite,
                                         sameFavoritePlace, stationFavoriteIn, ondePointFavoriteIn (S1)
  favorites/favorite_repository.dart     FavoriteRepository + FavoriteStorageFailure (ListeDeFavorisIllisible,
                                         EcritureDeFavorisEnEchec) (S1)
  formatting/display_date.dart           + formatLocalDate, « JJ/MM/AAAA » en heure locale (S1)
lib/data/
  preferences/favorites_codec.dart       decodeFavorites / encodeFavorites, forme stockée JSON v1 (S2)
  preferences/shared_preferences_favorite_repository.dart   SharedPreferencesFavoriteRepository (S3)
lib/features/
  shared/favorite_star.dart              FavoriteStar, état d'affichage de l'étoile, Dart pur, aucun import (S4 ;
                                         décision 4 du commanditaire, recommandée : A)
  shared/favorite_star_button.dart       FavoriteStarButton, FavoriteWriteFailedNotice, libellés de l'étoile (S4)
  shared/screen_layout.dart              ScreenTitleBar : CRÉÉ PAR B1 (lot 1), consommé par S9 — non modifié ici
  station_sheet/view_model/station_sheet_view_model.dart   + _favorites, favoriteStar, toggleFavorite (S5)
  onde_sheet/view_model/onde_sheet_view_model.dart         + _favorites, favoriteStar, toggleFavorite (S6)
  station_sheet/view/station_summary_sheet.dart            StationSheetPanel : + favoriteStar, onToggleFavorite (S7a)
  onde_sheet/view/onde_summary_sheet.dart                  OndeSheetPanel : + favoriteStar, onToggleFavorite (S7a)
  favorites/view_model/favorites_view_model.dart           FavoritesViewModel, FavoritesState (sealed, cinq états) (S8)
  favorites/view/favorites_screen.dart                     FavoritesScreen, textes de § 10.1 (S9)
  map/view/map_entry_buttons.dart        MapEntryButtons : CRÉÉ AU LOT 4 ; + onOpenFavorites, bouton « Favoris » (S10)
  map/view/map_view.dart                 MapView et buildMapOverlays : + onOpenFavorites ; commentaire des
                                         l. 1424-1426 corrigé (S10)
lib/main.dart                            dépôt concret câblé aux deux fiches (S5, S6) ; étoile et bascule passées
                                         aux panneaux (S7a) ; FavoritesViewModel, route « Favoris », ouverture d'un
                                         favori (S11)

test/
  support/in_memory_favorite_repository.dart               double programmable du contrat (S1)
  support/fake_shared_preferences.dart                     double de SharedPreferences qui reproduit le cache du
                                                           paquet, écritures programmables (S3)
  domain/favorites/favorite_test.dart  favorite_repository_test.dart         (S1)
  features/shared/favorite_star_test.dart                  égalité, et verrou « aucun import » (S4)
  domain/formatting/display_date_test.dart                 + formatLocalDate (S1)
  data/preferences/favorites_codec_test.dart                                 (S2)
  data/preferences/shared_preferences_favorite_repository_test.dart          (S3)
  features/shared/favorite_star_button_test.dart                             (S4)
  features/station_sheet/view_model/station_sheet_view_model_test.dart       + groupe « favori » (S5)
  features/onde_sheet/view_model/onde_sheet_view_model_test.dart             + groupe « favori » (S6)
  features/station_sheet/view/station_summary_sheet_test.dart                + groupe « étoile » (S7a)
  features/onde_sheet/view/onde_summary_sheet_test.dart                      + groupe « étoile » (S7a)
  features/favorites/view_model/favorites_view_model_test.dart               (S8)
  features/favorites/view/favorites_screen_test.dart                         (S9)
  features/map/view/map_entry_buttons_test.dart            + bouton « Favoris » (S10 ; fichier du lot 4)
  features/map/view/map_entry_buttons_overlap_test.dart    recouvrements de la colonne à cinq boutons (S10)
  main_test.dart                         _app accepte les ViewModels (S5) ; étoile dans la composition réelle
                                         (S7a) ; groupe « ecran des favoris (S11) »
  project/domain_model_doc_test.dart     typesDuDomaine + 8 (S1) ; FavoriteStar n'y entre pas
  project/acceptance_features_test.dart  _featureFiles + favoris.feature, test US-14, table des libellés (S7b) ;
                                         table allongée (S9, S11), 14 scénarios exigés (S11)

docs/
  domain-model.md                        section « Contexte Favoris » (S1)
  glossary.md                            entrée « Favori » (S1)
  adr/ADR-014-feature-first-mvvm.md      une phrase à l'amendement sur shared/ : un état d'affichage en Dart pur (S4)
  adr/ADR-011-stockage-local.md          « Amendement du <date> — favoris » : faits du paquet relus, forme
                                         stockée, limites (S3)
  acceptance/favoris.feature             créé avec sept scénarios (S7b), + quatre (S9), + trois (S11) : quatorze
  use-cases/UC-008-suivre-un-lieu-en-favori.md   créé (S7b), marques 🔄 levées (S11)
  use-cases/UC-003-…md  UC-004-…md       l'étoile de la fiche (S7b)
  04-ui.md                               note sous les deux croquis de fiche (S7b) ; croquis de l'écran
                                         « Favoris » et de ses états (S9) ; bouton « Favoris » du groupe (S10)
  README.md                              ligne acceptance/ : un fichier de plus (S7b) ; UC-008 (S7b)
  CLAUDE.md, project-state.md            arborescence, fichiers de shared/, ViewModels, ligne T3 (S4, S11)
```

**Conventions propres à ces lots :** les noms de champs JSON sont en français (`favoris`, `ajoute_le`, `libelle`), la clé
`shared_preferences` et les identifiants Dart en anglais. Aucun fichier sous `lib/features/` n'importe `lib/data/` :
seul `lib/main.dart` nomme `SharedPreferencesFavoriteRepository`. La tranche `favorites` n'importe ni `map`, ni
`station_sheet`, ni `onde_sheet` : elle rend des rappels, `main.dart` les branche.

---

## Lot 0 — Ouverture de `0.4.0`, documents remis d'accord avec le 2026-10-12

### Task O1 : Ouvrir la version `0.4.0` et consigner les faits du 2026-10-12

**Agent :** mécanique, relu par un second agent.
**Files:** modifiés `CHANGELOG.md`, `pubspec.yaml`, `test/project/changelog_test.dart`, `docs/project-state.md`, `CLAUDE.md`, `docs/README.md`, `docs/superpowers/specs/2026-10-12-cadrage-t3-design.md` (ligne « Statut » seulement), `docs/superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md` (l. 91 seulement)

> Aucun fichier sous `lib/`. Seul verrou qui bouge : `test/project/changelog_test.dart` (il lit `pubspec.yaml` et `CHANGELOG.md`, l. 13, 25, 152). Aucun test ne lit `project-state.md`, `README.md`, `CLAUDE.md` ni les cadrages. `android/local.properties` (`flutter.versionName=0.2.0`) et `windows/flutter/ephemeral/` sont des artefacts de poste, ignorés : ne pas y toucher.

**Faits à relire avant d'écrire — recopier ce qui est LU, pas ce qui est attendu** (lecture seule) :

```bash
git branch --show-current
git tag --list
git rev-list -n 1 v0.3.0
git ls-remote --tags origin
gh pr view 21 --json state,mergedAt,mergeCommit,mergedBy,baseRefName
```
Attendu, d'après la lecture du 2026-10-12 par l'auteur du plan (`git tag --list` : `v0.1.0`, `v0.2.0`, `v0.3.0` ; `dev` à `1247de3`) et d'après le fichier de poste (non vérifié par l'auteur pour `gh`) : branche `feat/t3-favoris-filtres` ; `v0.3.0` sur `1247de3`, présent sur `origin` ; PR #21 `MERGED` vers `dev`, le 2026-10-12 à 10:19:57 UTC, commit `1247de3`. **Si une sortie diffère, écrire ce qui est lu et le signaler dans « À valider ».**

**État de départ, lu** — `pubspec.yaml:19` : `version: 0.3.0+3` · `CHANGELOG.md:12-14` : `## [Non publié]`, ligne vide, `## [0.3.0] — 2026-10-09` · `changelog_test.dart:151-163` : cas « pubspec.yaml porte version: 0.3.0+3 » (devient faux) · `changelog_test.dart:11-30` : la version du pubspec doit avoir sa section `## [X.Y.Z]`, et `## [Non publié]` doit exister.

**Cas de test** — nouveau groupe `version 0.4.0 (Tasks O1 et P3 du plan T3)` dans `changelog_test.dart`, avec ses aides `section040()` et `sousSection(String titre)` écrites comme `section030()` (l. 126-146) :
1. « pubspec.yaml porte version: 0.4.0+4 » : `RegExp(r'^version:\s*0\.4\.0\+4\s*$', multiLine: true)` trouve une ligne. **Le cas « pubspec.yaml porte version: 0.3.0+3 » (l. 151-163) est supprimé** : c'est la seule suppression, à dire dans le message de commit.
2. « la version 0.4.0 est ouverte » : la ligne qui commence par `## [0.4.0]`, `trimRight()` fait, vaut exactement `## [0.4.0] — à publier`.
3. « une section ## [0.4.0], une seule, sous [Non publié] et au-dessus de [0.3.0] » : `RegExp(r'^## \[0\.4\.0\]', multiLine: true)` → 1 occurrence ; `indexOf('## [Non publié]') < indexOf('## [0.4.0]') < indexOf('## [0.3.0]')`.
4. « le chapeau de 0.4.0 dit qu'elle est ouverte et pas publiée, et que la porte de T2 reste due » : chapeau = texte entre la ligne de titre et le premier `\n### `, espaces normalisés (`replaceAll(RegExp(r'\s+'), ' ')`) ; il contient `Version ouverte`, `pas publiée`, `la porte de T2 reste due`.
5. « le Non vérifié de 0.4.0 n'est pas vide » : au moins une puce (`- `) ; le texte contient `Android`, `porte de T3` et `écran de T3` (sans majuscule initiale exigée : la puce peut commencer par « Aucun »).
6. Les cas de `0.3.0` (l. 167-432, hors le cas supprimé) et de `0.2.0` restent **inchangés et verts** : `0.3.0` reste datée du 2026-10-09.

**Ce qui s'écrit**
- `pubspec.yaml` : `version: 0.4.0+4` (R17 du cadrage).
- `CHANGELOG.md`, entre `## [Non publié]` et `## [0.3.0]` : `## [0.4.0] — à publier` ; chapeau : quatrième tranche (T3) — favoris, filtres de la carte, critère de fraîcheur ; « **Version ouverte**, pas publiée : rien n'en est encore livré, ce que la tranche ajoute s'écrit à sa fin ; la porte de T2 reste due (`A1`, `E4`, `P1`, `P2`) » ; puis `### Non vérifié` : aucun écran de T3 n'existe ni n'est constaté ; la porte de T3 est sur Windows **et** Android (arbitrage 7) et dépend d'une construction Android jamais constatée ; aucun exécutable de release de `0.3.0` ni de `0.4.0`. **Pas de `### Ajouté` à ce stade, et aucun lot ne touche `CHANGELOG.md` après `O1`** : `X3` écrit « Ajouté » en une fois, d'après les lots livrés, avant « Non vérifié » ; `P3` date.
- `docs/project-state.md` : (a) en-tête « Mis à jour » — une phrase de tête datée du 2026-10-12 : cadrage de T3 approuvé par le commanditaire, textes de § 10.1 compris, huit arbitrages, branche `feat/t3-favoris-filtres` partie de `dev` à `1247de3`, `0.4.0` ouverte ; l'état précédent reste, marqué « état d'alors » ; (b) « Arbitrages récents » — une ligne `2026-10-12` qui recopie les huit arbitrages de § 2 du cadrage, un par un, et dit « PR #21 fusionnée sur `dev` » et « tag `v0.3.0` posé et poussé sur `1247de3`, sans la porte de T2 » **avec les sorties relues ci-dessus** ; (c) ligne **T2** — « tag à poser », « `git tag --list` fait foi » et « `gh pr list --head feat/t2-p3 --state all` fait foi » barrés (`~~…~~`) et suivis du fait constaté ; (d) ligne **T3** — `🔄 **en cours depuis le 2026-10-12**`, lien vers le cadrage et vers le plan `docs/superpowers/plans/2026-10-12-t3-favoris-filtres-fraicheur.md`, périmètre « le titre seul », `US-11`, `US-16` et `integration_test/` renvoyés à une tranche ultérieure, porte Windows et Android, aucune tâche close hors `O1` ; (e) ligne **T5** — après « du moteur structuré laissé ouvert par `ADR-011` », ajouter : « **qui ne se tranche pas avec T3** (arbitrage 2 du 2026-10-12 : favoris en `shared_preferences`, moteur structuré ouvert jusqu'au hors-ligne, `US-10`) » ; (f) « Prochaine étape » — un paragraphe daté en tête : lot 1 de T3.
- `CLAUDE.md` : ligne **T2** du tableau « Où on en est » (même correction que (c), en une phrase) ; ligne **T3** (même contenu que (d), en deux phrases) ; ligne **T5** (« dépend des favoris de T3 et d'un moteur de stockage structuré » → ajouter « que T3 ne tranche pas (arbitrage 2 du 2026-10-12) »).
- `docs/README.md` : table « Plans d'implémentation » — une ligne pour `docs/superpowers/plans/2026-10-12-t3-favoris-filtres-fraicheur.md` (T3, 🔄 en cours) ; table des specs — une ligne `2026-10-12-cadrage-t3-design.md` (« **T3** — cadrage : favoris, filtres, fraîcheur ; huit arbitrages du 2026-10-12 »).
- Cadrage de T3, l. 3 : « proposé, soumis à la relecture du commanditaire » → « ✅ **approuvé par le commanditaire le 2026-10-12, textes de § 10.1 compris** » ; rien d'autre.
- Cadrage de T4-T5, l. 91 : `~~Il se tranche donc avec T3 ; T5 s'appuie dessus.~~` suivi de « **Corrigé le 2026-10-12 (arbitrage 2 du cadrage de T3) :** les favoris de T3 sont en `shared_preferences` ; le moteur structuré reste ouvert jusqu'au hors-ligne (`US-10`). T5 ne peut pas compter qu'il soit tranché avant elle. » On ne supprime pas la phrase d'origine.

- [ ] **Étape 1** — relire les cinq faits ; écrire les cas 1 à 5, supprimer le cas `0.3.0+3` ; `flutter test test/project/changelog_test.dart` → **rouge**, recopier la sortie.
- [ ] **Étape 2** — écrire `pubspec.yaml`, `CHANGELOG.md`, puis les six documents.
- [ ] **Étape 3** — critère de fin (cinq cas ajoutés, un supprimé : repère + 4 attendu, **à recopier, non à supposer**), commit.

```bash
git add -- CHANGELOG.md pubspec.yaml test/project/changelog_test.dart docs/project-state.md CLAUDE.md docs/README.md docs/superpowers/specs/2026-10-12-cadrage-t3-design.md docs/superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md && git commit -m "docs : ouvrir la version 0.4.0 ; cadrage de T3 approuvé, tag v0.3.0 et PR #21 consignés (O1 de T3)" -m "pubspec en 0.4.0+4, section 0.4.0 à publier, sans Ajouté : il s écrit en une fois à la fin de la tranche (X3). Le cas de test « pubspec porte 0.3.0+3 » est supprimé, remplacé par celui de 0.4.0+4 ; cinq cas ajoutés au total. Faits relus : <recopier git tag --list, git rev-list v0.3.0, gh pr view 21>. Le moteur de stockage structuré ne se tranche pas avec T3 (arbitrage 2) : cadrage de T4-T5 et ligne T5 corrigés, phrase d origine barrée. Aucun fichier sous lib." -- CHANGELOG.md pubspec.yaml test/project/changelog_test.dart docs/project-state.md CLAUDE.md docs/README.md docs/superpowers/specs/2026-10-12-cadrage-t3-design.md docs/superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md
```

---

## Lot 1 — Dettes de T2 : barre de titre partagée (dette 3), plateforme des tests de widget (dette 1)

> **Ordre du lot : `N1`, puis `B1`, puis `N2` à `N9` en série.** `B1` a un cas de téléphone : il lui faut l'assistant Android de `N1`.
>
> **Règle générale, pour ce lot et pour tout le plan :** tout cas de test dont la fenêtre fait **moins de 600 px de large** est en `testWidgetsOnAndroid`, titre « Android : … » ; tout autre test de widget est en `testWidgetsOnWindows`.
>
> **Procédure de migration d'UN fichier de test — dite ici une fois, appliquée par `N2` à `N9`.** Un commit par fichier.
>
> 1. **Compter** : `grep -c -E '^\s*testWidgets\(' <fichier>` doit rendre le décompte écrit dans la tâche (relevé le 2026-10-12). S'il diffère, s'arrêter et le dire.
> 2. **Classer d'abord par le sujet.** Un test dont le titre, le groupe ou le commentaire dit qu'il porte sur Android — « Android », « téléphone », cible de 48, mesure à 360 × 640, 390 × 844 ou toute largeur sous 600 px, ou appel passé par une aide `_surAndroid` — passe **directement** à `testWidgetsOnAndroid(`, et son titre contient le mot « Android » (l'y ajouter s'il manque). Un appel qui porte `variant: TargetPlatformVariant.only(TargetPlatform.android)` devient `testWidgetsOnAndroid(` et perd `variant` ; `.only(TargetPlatform.windows)` devient `testWidgetsOnWindows(`, de même.
> 3. **Tous les autres** `testWidgets(` passent à `testWidgetsOnWindows(`. Imports : `'<relatif>/support/windows_platform.dart'`, et `android_platform.dart` s'il sert. Un test qui pose lui-même `debugDefaultTargetPlatformOverride` dans son corps le garde : l'assistant le remet à `null` après lui.
> 4. **Lancer le fichier seul** : `flutter test <fichier>`. Pour chaque test rouge, le classer, **un par un** :
>    - **(i) il porte sur Android** sans que son titre le dise → `testWidgetsOnAndroid(`, « Android » ajouté au titre ;
>    - **(ii) son attente était calibrée sur la plateforme par défaut sans porter sur Android** (un 48 écrit en dur là où la règle est `minimumTapTarget`, une position décalée de 4 px par cible, une barre de défilement du bureau en plus) → lire le test et le code, comprendre, corriger **l'attente**, et écrire dans le message de commit le titre du test, l'ancienne et la nouvelle valeur. Jamais de correction sous `lib/` ;
>    - **(iii) il révèle un défaut réel sous Windows** (un geste qui n'atteint plus sa cible, un débordement, un contrôle recouvert) → **arrêt** : rien n'est corrigé dans le commit de migration, le fichier reste dans la liste d'exceptions du verrou, la sortie rouge est remontée telle quelle.
>    Un test qui rougit est un constat à lire, pas une attente à réécrire. **Trois échecs sur un même fichier : arrêt et question.**
> 5. **Commentaires** : une ligne de code qui porte encore le mot `testWidgets` dans un commentaire de fin de ligne fait rougir le verrou — reformuler (« le test tourne sous Android »). Les lignes entières de commentaire (`//`, `///`) sont ignorées par le verrou.
> 6. **Retirer le fichier de `filesNotYetMigrated`** (`test/project/widget_test_platform_test.dart`) dans le même commit : le verrou exige qu'un fichier listé porte encore un appel nu.
> 7. **Vérifier** : `grep -c -E '\btestWidgets\b' <fichier>` hors lignes de commentaire → 0 ; `flutter test <fichier>` vert, **même nombre de tests qu'avant** (recopier les deux totaux) ; puis le critère de fin.
> 8. **Message de commit** : `test(<scope>) : plateforme nommée dans <nom du fichier> (<Nx> de T3)` ; corps : n tests sous Windows, m sous Android (lesquels), attentes corrigées en (ii) avec ancienne et nouvelle valeur, ou « aucune attente modifiée ».

### Task N1 : `testWidgetsOnAndroid`, la convention réécrite, et le verrou de plateforme

**Agent :** **raisonnement** (le verrou doit laisser la suite verte à chaque commit de la migration).
**Files:** créés `test/support/android_platform.dart`, `test/support/platform_helpers_test.dart`, `test/project/widget_test_platform_test.dart` · modifiés `test/support/windows_platform.dart` (commentaire l. 1-13 seulement), `docs/plan-de-tests.md`

**État de départ, lu** — `test/support/windows_platform.dart:19-42` : `void testWidgetsOnWindows(String description, Future<void> Function(WidgetTester tester) callback, {bool? skip, Timeout? timeout, bool semanticsEnabled = true, Object? tags})`, qui pose `debugDefaultTargetPlatformOverride = TargetPlatform.windows` dans un `try`, le remet à `null` dans le `finally` (un `tearDown` passe trop tard : « The value of a foundation debug variable was changed by the test. » — c'est ce qui a fait échouer l'essai d'un `flutter_test_config.dart` global, 22 sur 22 dans `warning_link_test.dart`, `project-state.md` point 59, (4)). Son commentaire l. 11-13 dit l'inverse de la règle de T3 (« les autres restent en `testWidgets` »). 29 fichiers portent encore `testWidgets(` nu (524 appels en début de ligne, recherche du 2026-10-12).

**Signatures**
- `test/support/android_platform.dart` — même forme, mêmes imports que `windows_platform.dart` :

```dart
void testWidgetsOnAndroid(
  String description,
  Future<void> Function(WidgetTester tester) callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  Object? tags,
})
```
  Il pose **explicitement** `TargetPlatform.android` (il ne se repose pas sur le défaut de `flutter test`), même `try/finally`.
- `test/project/widget_test_platform_test.dart` :

```dart
/// Chemin de ce fichier : ses cas synthétiques écrivent le mot interdit.
const String lockFilePath = 'test/project/widget_test_platform_test.dart';

/// Les fichiers pas encore migrés. Ne fait que décroître ; vide à la fin de N9.
const Set<String> filesNotYetMigrated = <String>{ /* les 29 chemins */ };

/// « chemin:ligne » de chaque ligne de CODE (hors ligne entière de
/// commentaire) qui porte le mot `testWidgets` seul, dans un fichier sous
/// `test/`, hors `test/support/`, hors [lockFilePath], hors [notYetMigrated].
List<String> bareTestWidgetsLines(
  Map<String, String> contentByPath, {
  Set<String> notYetMigrated = const <String>{},
});

/// Les chemins de [notYetMigrated] qui n'ont plus rien à y faire : fichier
/// absent de [contentByPath], ou qui ne porte plus aucun appel nu.
List<String> staleExceptions(
  Map<String, String> contentByPath,
  Set<String> notYetMigrated,
);
```
  Motif : `RegExp(r'\btestWidgets\b')` — il attrape l'appel, l'appel en fin de flèche (`=>\n    testWidgets(d, corps);`), la référence sans parenthèse et `ft.testWidgets(` ; il n'attrape ni `testWidgetsOnWindows` ni `testWidgetsOnAndroid` (pas de frontière de mot avant `On`). Une ligne est « de commentaire » si son `trimLeft()` commence par `//`. Chemins comparés avec des `/`.

**Les 29 chemins de `filesNotYetMigrated`** : `test/main_test.dart`, `test/diagnostics/fluidity_probe_panel_test.dart`, `test/features/goldens/{onde_marker_golden_test,station_marker_golden_test}.dart`, `test/features/shared/{data_sources_view_test,keyboard_focus_ring_test,tap_target_test,warning_link_test}.dart`, `test/features/warnings/view/initial_warning_view_test.dart`, `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/restrictions/view/{drought_severity_badge_size_test,drought_severity_badge_test,reinforced_warning_card_test,restrictions_scale_text_test,restrictions_screen_test}.dart`, `test/features/map/view/{area_cluster_marker_test,designate_center_button_test,ign_attribution_badge_test,map_controls_test,map_designation_test,map_empty_states_test,map_keyboard_test,map_legend_test,map_overlays_phone_test,map_scale_chips_test,map_view_test,onde_marker_test,station_marker_test}.dart`. **Avant d'écrire, refaire la recherche** (`grep -rlE '^\s*testWidgets\(' test`) : la liste écrite est celle qui est lue ; un écart avec ces 29 se signale.

**Cas de test**
`test/support/platform_helpers_test.dart` :
1. `testWidgetsOnAndroid` : dans le corps, `defaultTargetPlatform == TargetPlatform.android` et `minimumTapTarget == 48`.
2. `testWidgetsOnWindows` : `TargetPlatform.windows` et `minimumTapTarget == 44`.
3. Un `test(` ordinaire placé après eux : `debugDefaultTargetPlatformOverride` est `null`.

`test/project/widget_test_platform_test.dart`, synthétiques :
4. `'test/features/x/a_test.dart'` de contenu `"void main() {\n  testWidgets('a', (WidgetTester t) async {});\n}"` → `['test/features/x/a_test.dart:2']`.
5. Contenu qui n'emploie que `testWidgetsOnWindows(` et `testWidgetsOnAndroid(` → vide.
6. `"void _sur(String d, C c) =>\n    testWidgets(d, c);"` → ligne 2 ; `"final Object f = testWidgets;"` → ligne 1 ; `"ft.testWidgets('a', b);"` → ligne 1.
7. `"// testWidgets tourne sous Android"` et `"  /// Un \`testWidgets\` posé sur une plateforme"` → vide ; `"foo(); // comme testWidgets"` → ligne 1 (un commentaire de fin de ligne compte : il se reformule).
8. `'test/support/windows_platform.dart'` contenant `ft.testWidgets(` → vide ; `'test/support_bis/x.dart'` avec le même contenu → une ligne ; `'lib/x.dart'` → vide ; `lockFilePath` → vide.
9. Un chemin en faute mais listé dans `notYetMigrated` → vide.
10. `staleExceptions` : listé et absent des contenus → rendu ; listé sans appel nu → rendu ; listé avec appel nu → non rendu.
Réels (tous les `.dart` sous `test/`, lus par `Directory('test').listSync(recursive: true)`, séparateurs ramenés à `/`) :
11. `bareTestWidgetsLines(reel, notYetMigrated: filesNotYetMigrated)` → vide.
12. `staleExceptions(reel, filesNotYetMigrated)` → vide : un fichier migré doit quitter la liste dans son commit.

**Documents** — `windows_platform.dart`, l. 1-13, réécrit : « Tout test de widget nomme sa plateforme. `testWidgetsOnWindows` par défaut (Windows est la première cible) ; `testWidgetsOnAndroid` pour un test qui porte sur Android (cible de 48, mesures de téléphone), ce que son titre dit. `testWidgets` nu est interdit hors de `test/support/` : verrou `test/project/widget_test_platform_test.dart`. Pas de paramètre `variant`. » — le paragraphe sur `try/finally` reste. `docs/plan-de-tests.md` : en-tête « Portée » étendue à T3 ; § 1, ligne `test/features/` : la plateforme est nommée par test, verrou cité ; ligne `integration_test/` : `🔄 T3` → « tranche ultérieure, non nommée (arbitrage 1 du 2026-10-12) » ; § 2 (l. 54), titré « Les quatre règles qui décident de l'étage » : une cinquième règle s'ajoute — « Un test de widget nomme sa plateforme. » — et **le titre change avec elle** (« Les cinq règles… ») ; vérifier qu'aucun autre document ne cite l'ancien titre (`grep -rn "quatre règles qui décident" docs CLAUDE.md`).

- [ ] **Étape 1** — tests rouges (`flutter test test/support test/project/widget_test_platform_test.dart`), recopier.
- [ ] **Étape 2** — écrire l'assistant, le verrou avec ses 29 exceptions, le commentaire, `plan-de-tests.md`.
- [ ] **Étape 3 — contre-épreuve**, trois mutations, chacune défaite ensuite : (a) un fichier temporaire `test/features/shared/zz_contre_epreuve_test.dart` avec un `testWidgets(` nu → cas 11 rouge ; (b) retirer `test/main_test.dart` de la liste sans le migrer → cas 11 rouge ; (c) ajouter à la liste `test/features/goldens/area_cluster_marker_golden_test.dart`, déjà sans appel nu → cas 12 rouge. **Recopier les trois rouges.**
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- test/support/android_platform.dart test/support/platform_helpers_test.dart test/support/windows_platform.dart test/project/widget_test_platform_test.dart docs/plan-de-tests.md && git commit -m "test : testWidgetsOnAndroid et verrou de plateforme des tests de widget (N1 de T3)" -m "Dette 1 de T2 : chaque test de widget nomme sa plateforme, Windows par défaut, Android pour ce qui porte sur Android. Le verrou refuse testWidgets nu hors de test/support ; les 29 fichiers pas encore migrés sont une liste d exceptions qui ne fait que décroître — un fichier migré qui y reste rougit. Convention de windows_platform.dart réécrite ; plan de tests : integration_test renvoyé à une tranche ultérieure (arbitrage 1). Contre-épreuves : <recopier les trois rouges>." -- test/support/android_platform.dart test/support/platform_helpers_test.dart test/support/windows_platform.dart test/project/widget_test_platform_test.dart docs/plan-de-tests.md
```

### Task B1 : `ScreenTitleBar`, la barre de titre des écrans pleins — une seule dans `lib/`

**Agent :** **raisonnement** (extraction à rendu verrouillé).
**Prérequis :** `N1` (`testWidgetsOnAndroid`, verrou de plateforme).
**Files:** modifiés `lib/features/shared/screen_layout.dart`, `lib/features/restrictions/view/restrictions_screen.dart`, `lib/features/shared/data_sources_view.dart`, `docs/project-state.md` (point 59, (5) : « barre de titre » soldée ; arborescence), `CLAUDE.md` (invariant `lib/features/shared/` : `screen_layout.dart` porte aussi `ScreenTitleBar`) · créés `test/features/shared/screen_layout_test.dart`, `test/project/screen_title_bar_test.dart` · **non modifiés, c'est le filet :** `test/features/restrictions/**`, `test/features/shared/data_sources_view_test.dart`, `test/main_test.dart`

**État de départ, lu le 2026-10-12** — deux classes privées `_TitleBar` : `restrictions_screen.dart:644-680` (employée l. 183) et `data_sources_view.dart:327-359` (employée l. 205). Structure commune : `Material(elevation: 1)` › `Padding(EdgeInsets.symmetric(horizontal: 4, vertical: 4))` › `Row` [ `BackButton(style: IconButton.styleFrom(minimumSize: Size.square(minimumTapTarget), visualDensity: VisualDensity.standard))`, `SizedBox(width: 8)`, `Expanded(Semantics(header: true, child: Text(titre, style: Theme.of(context).textTheme.titleLarge…)))` ]. **Trois différences, pas une de plus :** le titre (`restrictionsScreenTitle` / `dataSourcesTitle`) ; `Material.color` (`droughtScreenBackground` / absent) ; la couleur du titre (`?.copyWith(color: droughtLevelLabelColor)` / aucune). Les deux couleurs vivent dans `lib/features/restrictions/view/drought_severity_badge.dart:138`, `:142` : **`shared/` ne peut pas les importer** (`shared-sans-tranche`), l'écran les passe.

**Signature** — dans `lib/features/shared/screen_layout.dart`, qui importe en plus `package:martinpecheur/features/shared/tap_target.dart` :

```dart
/// La barre de titre d'un écran plein : retour et titre. Pas d'`AppBar` — sa
/// hauteur est fixe, et son titre serait tronqué à 200 % de police sur un
/// téléphone ; cette barre grandit avec le texte.
class ScreenTitleBar extends StatelessWidget {
  const ScreenTitleBar({
    required this.title,
    this.backgroundColor,
    this.titleColor,
    super.key,
  });

  /// Le titre, annoncé comme en-tête.
  final String title;

  /// Fond de la barre ; `null` : celui du thème (défaut de [Material]).
  final Color? backgroundColor;

  /// Couleur du titre ; `null` : celle de `textTheme.titleLarge`.
  final Color? titleColor;
}
```

Rendu : `Material(color: backgroundColor, elevation: 1, …)` et `Theme.of(context).textTheme.titleLarge?.copyWith(color: titleColor)` — `Material(color: null)` et `copyWith(color: null)` rendent ce que rendait l'absence du paramètre. Appelants : `const ScreenTitleBar(title: restrictionsScreenTitle, backgroundColor: droughtScreenBackground, titleColor: droughtLevelLabelColor)` et `const ScreenTitleBar(title: dataSourcesTitle)`.

**Invariants :** aucun changement de rendu ni de sémantique ; `screen_layout.dart` n'importe aucune tranche ; les deux `_TitleBar` sont **supprimées** ; l'en-tête de `screen_layout.dart` (l. 1-7) nomme la barre ; aucun texte d'écran nouveau (`vocabulary_test.dart` lit `lib/features`). Le troisième utilisateur, l'écran « Favoris », arrive au lot 7.

**Cas de test** — `test/features/shared/screen_layout_test.dart`, en `testWidgetsOnWindows` (import `'../../support/windows_platform.dart'`) sauf le cas 6, de téléphone, en `testWidgetsOnAndroid` (import `'../../support/android_platform.dart'`) ; banc : `MaterialApp(home: Scaffold(body: Column(children: <Widget>[ScreenTitleBar(…)])))`.
1. `ScreenTitleBar(title: 'Titre de test')` : `find.text('Titre de test')` → un widget ; son nœud sémantique a `flagsCollection.isHeader` vrai (même lecture que `data_sources_view_test.dart:104-110`) ; `find.byType(BackButton)` → un widget.
2. Sans couleur : le `Material` ancêtre du titre a `color == null` et `elevation == 1` ; le style du `Text` est égal à `Theme.of(context).textTheme.titleLarge`.
3. `backgroundColor: Color(0xFF112233)`, `titleColor: Color(0xFF445566)` : `Material.color` vaut la première, `Text.style!.color` la seconde.
4. Le retour mesure au moins `minimumTapTarget` (44 sous Windows) en largeur et en hauteur.
5. Route poussée (`Navigator.push` d'une page qui porte la barre) : un tap sur `BackButton` retire la route ; le titre n'est plus trouvé.
6. **`testWidgetsOnAndroid`, titre « Android : … »** — fenêtre de 360 × 640, `MediaQuery` à `TextScaler.linear(2)`, titre « Sécheresse et restrictions » : `tester.takeException()` nul, la barre est plus haute qu'à 100 % (elle grandit, elle ne tronque pas), et son retour mesure au moins 48.

`test/project/screen_title_bar_test.dart` — fonction pure du fichier de test `List<String> backButtonOwners(Map<String, String> contentByPath)` : les chemins sous `lib/` dont le contenu contient `BackButton(` ou `AppBar(`, triés.
7. Synthétique : `{'lib/a.dart': 'BackButton(', 'lib/b.dart': 'x', 'test/c.dart': 'BackButton('}` → `['lib/a.dart']` ; un contenu avec `AppBar(` → listé.
8. Réel, `lib/` lu en entier : exactement `['lib/features/shared/screen_layout.dart']`.

- [ ] **Étape 1** — tests rouges : `flutter test test/features/shared/screen_layout_test.dart test/project/screen_title_bar_test.dart` → échec (classe absente ; le cas 8 rend deux chemins). Recopier.
- [ ] **Étape 2** — écrire `ScreenTitleBar`, brancher les deux écrans, supprimer les deux `_TitleBar` ; retirer un import devenu inutile si `flutter analyze` le dit.
- [ ] **Étape 3 — filet** : `flutter test test/features/restrictions test/features/shared test/main_test.dart` vert ; `git diff --stat -- test/features/restrictions test/features/shared/data_sources_view_test.dart test/main_test.dart` → **vide**.
- [ ] **Étape 4 — contre-épreuve** : remettre un `BackButton()` dans `data_sources_view.dart` → le cas 8 rougit ; retirer → vert. Recopier le rouge.
- [ ] **Étape 5** — documents, critère de fin, commit. Constat `k` de la porte (« inchangée à l'œil ») : dû, non fait ici.

```bash
git add -- lib/features/shared/screen_layout.dart lib/features/restrictions/view/restrictions_screen.dart lib/features/shared/data_sources_view.dart test/features/shared/screen_layout_test.dart test/project/screen_title_bar_test.dart docs/project-state.md CLAUDE.md && git commit -m "refactor(ui) : ScreenTitleBar, une seule barre de titre d écran plein (B1 de T3)" -m "Dette 3 de T2 soldée : les deux _TitleBar, qui ne différaient que par le titre, le fond et la couleur du titre, deviennent un widget de features/shared, sans changement de rendu ni de sémantique ; les couleurs de la tranche restrictions lui sont passées, shared n importe aucune tranche. Tests d écran des restrictions et des sources inchangés. Verrou : un seul fichier de lib porte BackButton. Contre-épreuve : <recopier le rouge>. Vérifié par test, non constaté à l écran." -- lib/features/shared/screen_layout.dart lib/features/restrictions/view/restrictions_screen.dart lib/features/shared/data_sources_view.dart test/features/shared/screen_layout_test.dart test/project/screen_title_bar_test.dart docs/project-state.md CLAUDE.md
```

### Task N2 : Migrer la racine et la sonde — 2 fichiers

**Agent :** mécanique. **Procédure :** celle de la tête du lot, un commit par fichier (chemins du commit : le fichier et `test/project/widget_test_platform_test.dart`).

| Fichier | `testWidgets(` nus | Déjà `OnWindows` | À savoir |
|---|---|---|---|
| `test/main_test.dart` | 23 | 6 | composition réelle de `main.dart` ; scope de commit `ui` |
| `test/diagnostics/fluidity_probe_panel_test.dart` | 3 | 2 | scope `ci` |

- [ ] `main_test.dart` migré, commit · [ ] `fluidity_probe_panel_test.dart` migré, commit.

### Task N3 : Migrer les deux goldens — consigne propre

**Agent :** mécanique, **sans jamais `--update-goldens`**.

| Fichier | Nus | À savoir |
|---|---|---|
| `test/features/goldens/onde_marker_golden_test.dart` | 2 (l. 68, dans une boucle ; l. 85) | 13 images `onde_marker_*.png` |
| `test/features/goldens/station_marker_golden_test.dart` | 3 (l. 61, boucle ; l. 75 ; l. 95) | 7 images `station_marker_*.png` |

**Consigne des goldens** (lue dans `golden_harness.dart:66-79` et `plan-de-tests.md` § 1) : les 23 images sont **produites sur Windows** et dépendent de l'hôte, pas de `defaultTargetPlatform` ; les marqueurs sont peints à taille fixe (`stationMarkerSize`, 26 px) et aucun ne lit `minimumTapTarget`. Le troisième fichier, `area_cluster_marker_golden_test.dart`, est déjà en `testWidgetsOnWindows`. Donc : tous les appels passent à `testWidgetsOnWindows(` (import `'../../support/windows_platform.dart'`), et **les images existantes doivent rester vertes telles quelles**. Si une image rougit : classe (iii), **arrêt** — ne rien régénérer, ne rien committer ; lister ce que `flutter test` a déposé sous `test/features/goldens/failures/` et remonter. Après la migration : `git status --short test/features/goldens` ne montre **aucun `.png`** modifié ni ajouté.

- [ ] `onde_marker_golden_test.dart` migré, commit · [ ] `station_marker_golden_test.dart` migré, commit (scope `map`).

### Task N4 : Migrer `shared/` et `warnings/` — 5 fichiers

**Agent :** mécanique.

| Fichier | Nus | Déjà `OnWindows` | À savoir |
|---|---|---|---|
| `test/features/shared/data_sources_view_test.dart` | 18 | 5 | l. 472 « Android : le retour mesure 48 » et l. 621 « Android : la cible mesure 48 » → `testWidgetsOnAndroid` d'emblée (étape 2 de la procédure) |
| `test/features/shared/keyboard_focus_ring_test.dart` | 2 | 0 | — |
| `test/features/shared/tap_target_test.dart` | 2 | 0 | l. 55-59 et l. 61-65 portent `variant: TargetPlatformVariant.only(…)` : android → `testWidgetsOnAndroid`, windows → `testWidgetsOnWindows`, `variant` retiré ; l'import de `TargetPlatformVariant` devient peut-être inutile |
| `test/features/shared/warning_link_test.dart` | 22 | 0 | l. 297 mesure `minimumTapTarget` : indépendant de la plateforme |
| `test/features/warnings/view/initial_warning_view_test.dart` | 22 | 0 | scope `avertissement` |

- [ ] cinq fichiers, cinq commits (scope `ui`, sauf le dernier).

### Task N5 : Migrer les deux fiches — 2 fichiers

**Agent :** mécanique.

| Fichier | Nus | À savoir |
|---|---|---|
| `test/features/station_sheet/view/station_summary_sheet_test.dart` | 30 | l. 712 mesure `minimumTapTarget` ; scope `hydrometrie` |
| `test/features/onde_sheet/view/onde_summary_sheet_test.dart` | 32 | l. 700 de même ; scope `ecoulement` |

- [ ] deux fichiers, deux commits.

### Task N6 : Migrer `restrictions/view/` — 5 fichiers

**Agent :** mécanique pour les quatre premiers, **raisonnement** pour `restrictions_screen_test.dart` (92 appels, des mesures de disposition).

| Fichier | Nus | Déjà `OnWindows` | À savoir |
|---|---|---|---|
| `drought_severity_badge_size_test.dart` | 2 | 0 | tailles de badge 22, 28, 48 : des tailles de dessin, pas des cibles |
| `drought_severity_badge_test.dart` | 1 | 0 | — |
| `reinforced_warning_card_test.dart` | 8 | 1 | — |
| `restrictions_scale_text_test.dart` | 6 | 0 | charge Roboto depuis `FLUTTER_ROOT`, `markTestSkipped` si elle manque ; lire les largeurs mesurées : les cas à largeur de téléphone (sous 600 px) sont Android par le sujet |
| `restrictions_screen_test.dart` | 92 | 3 | l. 1535 `greaterThanOrEqualTo(48)` et l. 1909 `Size.square(48)` : lire avant de classer (hauteur de bouton, taille de badge) ; l. 771, 2275 mesurent `minimumTapTarget` ; groupe « typographie dynamique : 200 % » (l. 2683) : lire les tailles de fenêtre passées à `check` — celles de moins de 600 px de large sont Android par le sujet |

Tous sous `test/features/restrictions/view/`, scope `restrictions`. `restrictions_scroll_test.dart` (35 `OnWindows`, aucun nu) n'est pas concerné.

- [ ] cinq fichiers, cinq commits.

### Task N7 : Migrer les petits fichiers de `map/view/` — 9 fichiers

**Agent :** mécanique.

| Fichier | Nus | Déjà `OnWindows` | À savoir |
|---|---|---|---|
| `area_cluster_marker_test.dart` | 4 | 0 | — |
| `designate_center_button_test.dart` | 8 | 0 | l. 160-205 : une boucle pose elle-même `debugDefaultTargetPlatformOverride` par plateforme et le remet à `null` — garder le corps tel quel ; l. 77 mesure `minimumTapTarget` |
| `ign_attribution_badge_test.dart` | 2 | 0 | — |
| `map_controls_test.dart` | 9 | 0 | l. 54 mesure `minimumTapTarget` |
| `map_empty_states_test.dart` | 13 | 0 | — |
| `map_legend_test.dart` | 17 | 0 | — |
| `map_scale_chips_test.dart` | 14 | 0 | — |
| `onde_marker_test.dart` | 10 | 1 | — |
| `station_marker_test.dart` | 15 | 0 | l. 77-103, et un autre l. 184 : des `test(` purs, non concernés |

Tous sous `test/features/map/view/`, scope `map`.

- [ ] neuf fichiers, neuf commits.

### Task N8 : Migrer les trois grands fichiers de la carte — 3 fichiers

**Agent :** **raisonnement** (dispositions mesurées, gestes, ordre de tabulation).

| Fichier | Nus | Déjà `OnWindows` | À savoir |
|---|---|---|---|
| `test/features/map/view/map_view_test.dart` | 64 | 4 | le groupe « à la taille minimale de fenêtre Windows (800 × 740…) » (l. 1202 à 1662) est déjà en `OnWindows` ; l. 296-308 : un `test(` pur |
| `test/features/map/view/map_keyboard_test.dart` | 20 | 0 | ordre de tabulation à 800 × 600 (l. 426) |
| `test/features/map/view/map_designation_test.dart` | 52 | 2 | l. 145-155 : aides `_surAndroid` (l. 151-152, un des 52 appels nus) et `_surWindows` — `_surAndroid` appelle désormais `testWidgetsOnAndroid(d, corps)`, et **chaque titre passé par elle dit « Android »** ; l. 1244, commentaire « `testWidgets` tourne en Android : c'est la plateforme concernée » : ce test est Android par le sujet, le commentaire se reformule |

- [ ] trois fichiers, trois commits (scope `map`).

### Task N9 : Migrer `map_overlays_phone_test.dart`, fermer le verrou, solder la dette 1

**Agent :** **raisonnement**.
**Files:** modifiés `test/features/map/view/map_overlays_phone_test.dart`, `test/project/widget_test_platform_test.dart`, puis `docs/project-state.md`, `CLAUDE.md`, `docs/tracabilite.md` (paragraphe « rejoués en plateforme Windows », l. 75-80)

`map_overlays_phone_test.dart` : **28 appels nus, 11 déjà en `OnWindows`**, 2 406 lignes, police Roboto chargée depuis le SDK. C'est le fichier des **mesures de téléphone** : son en-tête (l. 1-80) dit ce qu'il prouve.
- Aides `_surAndroid` (l. 546-547, un des 28) et `_surWindows` (l. 549-550) : `_surAndroid` appelle `testWidgetsOnAndroid(d, corps)`.
- **Android par le sujet, sans passer par Windows** : tout test à `_petit` (360 × 640), `_grand` (390 × 844), 360 × 300, 360 × 568, 360 × 540, 360 × 330, et le premier (« la police de ce fichier est ROBOTO », l. 606, mesuré à `_petit`). Titre : « Android » ajouté par l'aide `_nom(…)` ou en tête du titre, **une seule fois par test**.
- **À classer par l'exécution** : les cas à 599 × 900 et 600 × 900 (bascule de disposition, l. 1234, 1247), la matrice de la disposition large (600 × 360, 640 × 360, 800 × 740, 700 × 740, 800 × 640, 900 × 640 ; l. 1276-1340), les cas à 800 × 740 et 800 × 700 des boucles mixtes (l. 719-720, 1793-1795, 1976-1983). Une boucle qui mêle tailles de téléphone et tailles de bureau choisit l'assistant **par cas** (`cas.$1.width < 600 ? testWidgetsOnAndroid : testWidgetsOnWindows`, par une variable locale de type `_Test`). Un « CONSTAT » dont la valeur change sous Windows est la classe (ii) : ancienne et nouvelle valeur dans le message de commit ; le groupe « Windows, 800 × 740 (Roboto pour Segoe UI) » (l. 2139) porte déjà la bande « de 60 à 740 (cible de 44) quand Android (48) la donne de 64 à 736 ».

**Fermeture du verrou**, dans un second commit : `filesNotYetMigrated` vaut `<String>{}` ; **cas ajouté** « la liste d'exceptions est vide : la migration est finie » (`expect(filesNotYetMigrated, isEmpty)`) ; le commentaire de la constante dit qu'elle ne se remplit plus. Contre-épreuve : y remettre un chemin → rouge ; recopier.

**Documents**, même second commit : `project-state.md` point 59, (4) — soldé, avec le compte des tests sous chaque plateforme (`grep -rcE '^\s*testWidgetsOnAndroid\('` et `…OnWindows\(` sommés, à recopier) et la liste des attentes corrigées en (ii) au fil de `N2`-`N9` ; `CLAUDE.md`, ligne « Tests » du tableau « Stack » et section « Conventions » (« un test de widget nomme sa plateforme ») ; `tracabilite.md` l. 75-80 : les verrous de gestes ne sont plus « rejoués » en plateforme Windows, ils y tournent par défaut.

- [ ] **Étape 1** — migrer le fichier selon la procédure ; commit 1.
- [ ] **Étape 1 bis — relecture de toute la migration, avant de fermer le verrou** : dans les **29 fichiers**, relever chaque test de widget dont la fenêtre fait **moins de 600 px de large** (`tester.view.physicalSize`, `Size(…)` passé à une aide de montage, constantes `_petit` et `_grand`, boucles de tailles) — `grep -rnE "Size\((3|4|5)[0-9]{2}, |_petit|_grand" test --include=*_test.dart` donne les candidats, à lire un par un. **Chacun doit finir en `testWidgetsOnAndroid`** : un test vert sous les deux plateformes passerait sinon sous Windows sans bruit. Ceux qui sont restés en `testWidgetsOnWindows` sont corrigés ici (un commit par fichier touché, même message que la procédure). **La liste complète de ces tests — fichier, titre, taille — est donnée dans le message du commit de fermeture** ; une exception voulue (une largeur sous 600 px qui porte bien sur Windows) y est nommée et justifiée.
- [ ] **Étape 2** — fermer le verrou, contre-épreuve, documents ; critère de fin ; commit 2.

```bash
git add -- test/project/widget_test_platform_test.dart docs/project-state.md CLAUDE.md docs/tracabilite.md && git commit -m "test : verrou de plateforme fermé, plus aucun testWidgets nu (N9 de T3)" -m "Dette 1 de T2 soldée : les 29 fichiers nomment leur plateforme, la liste d exceptions est vide et un cas le verrouille. <n> appels sous Windows, <m> sous Android. Attentes corrigées pendant la migration : <liste, ancienne et nouvelle valeur, ou aucune>. Tests à fenêtre de moins de 600 px de large, tous sous Android : <liste, fichier, titre, taille ; exceptions justifiées>. Contre-épreuve : <recopier le rouge>." -- test/project/widget_test_platform_test.dart docs/project-state.md CLAUDE.md docs/tracabilite.md
```

---

## Lot 2 — Filtres : domaine

> `lib/domain/filters/` est du **Dart pur** : aucun `package:flutter`, et **aucun import de `lib/features/`** — `MapScaleKind` vit dans la tranche carte (`lib/features/map/view_model/map_scale.dart:21`), l'importer casserait `domaine-ferme` (`test/architecture/layers_test.dart`). D'où deux membres nommés, sans paramètre d'échelle. `docs/domain-model.md` et `typesDuDomaine` (`test/project/domain_model_doc_test.dart:21`) s'allongent **dans le commit qui écrit chaque type**.

### Task F1 : `MapFilter`, la valeur du filtre, et le critère de fraîcheur du débit

**Agent :** mécanique (sonnet, effort moyen).
**Files:** créés `lib/domain/filters/map_filter.dart`, `test/domain/filters/map_filter_test.dart` · modifiés `docs/domain-model.md` (objets-valeur, nomenclatures closes), `test/project/domain_model_doc_test.dart` (`typesDuDomaine` + `'MapFilter'`, `'DischargeFreshnessCriterion'`), `docs/glossary.md` (ligne « Filtre »)

**Signatures** — imports permis : `lib/domain/nomenclature/flow_category.dart`, `lib/domain/observation/freshness.dart`, rien d'autre.
- `enum DischargeFreshnessCriterion { toutes, moinsDe2h, moinsDe24h }`
- `bool dischargeFreshnessAdmits(DischargeFreshnessCriterion criterion, Freshness freshness)` — deux `switch` exhaustifs, sans `default`.
- `String dischargeFreshnessCriterionLabel(DischargeFreshnessCriterion criterion)` — `'Toutes'`, `'Moins de ${ancienneApres.inHours} h'`, `'Moins de ${perimeeApres.inHours} h'` : les bornes sont **lues** dans `freshness.dart` (`ancienneApres` l. 28, `perimeeApres` l. 33), jamais recopiées.
- `const List<FlowCategory> filterableFlowCategories = <FlowCategory>[Ecoulement(), EcoulementFaible(), EcoulementNonVisible(), Assec(), NonObserve(), Inconnu(null)];` — l'ordre de la légende (`lib/features/map/view/map_legend.dart:155-162`).
- `final class MapFilter { const MapFilter({this.ecoulement = true, this.ecoulementFaible = true, this.ecoulementNonVisible = true, this.assec = true, this.nonObserve = true, this.inconnu = true, this.departementCode, this.dischargeFreshness = DischargeFreshnessCriterion.toutes}); static const MapFilter none = MapFilter(); final bool ecoulement, ecoulementFaible, ecoulementNonVisible, assec, nonObserve, inconnu; final String? departementCode; final DischargeFreshnessCriterion dischargeFreshness; bool get isActiveForFlow; bool get isActiveForDischarge; bool shows(FlowCategory category); MapFilter withCategory(FlowCategory category, {required bool shown}); MapFilter withDepartement(String? code); MapFilter withDischargeFreshness(DischargeFreshnessCriterion criterion); }` avec `==`, `hashCode`, `toString`.

**Invariants :** immuable ; `shows` et `withCategory` décident par **`switch` sur le type** de `FlowCategory`, jamais par `==` ni par appartenance à un ensemble (`Inconnu('9') != Inconnu(null)`, `flow_category.dart:84-89`) ; `isActiveForFlow` = une case à faux **ou** un département ; `isActiveForDischarge` = un département **ou** une fraîcheur autre que `toutes` ; aucun critère actif au départ ; aucun paramètre d'échelle.

**Cas de test**
- `const MapFilter() == MapFilter.none` ; sur `none` : `isActiveForFlow` et `isActiveForDischarge` faux, `shows` vrai pour les six éléments de `filterableFlowCategories` **et** pour `Inconnu('9')`, `Inconnu('')`.
- `none.withCategory(const Assec(), shown: false)` : `shows(const Assec())` faux, les cinq autres vrais ; `isActiveForFlow` vrai, `isActiveForDischarge` **faux**.
- `none.withCategory(const Inconnu('9'), shown: false)` : `shows(const Inconnu(null))`, `shows(const Inconnu('9'))`, `shows(const Inconnu('x'))` tous **faux** ; `shows(const NonObserve())` **vrai** (`BR-007` : un fait de terrain n'est pas notre ignorance).
- `none.withCategory(const NonObserve(), shown: false).shows(const Inconnu(null))` vrai.
- Aller-retour : décocher puis recocher chacune des six catégories rend `MapFilter.none` (égalité).
- `none.withDepartement('24')` : `departementCode == '24'`, actif pour les **deux** échelles ; `.withDepartement(null)` rend `none`.
- `none.withDischargeFreshness(DischargeFreshnessCriterion.moinsDe2h)` : `isActiveForDischarge` vrai, `isActiveForFlow` **faux**.
- Les six cases à faux : valeur valide, aucune exception, `isActiveForFlow` vrai.
- Égalité et `hashCode` structurels : deux filtres construits par deux chemins sont égaux ; huit cas, un par champ, où un seul champ diffère → inégaux.
- `dischargeFreshnessAdmits`, table 3 × 3 : `toutes` → vrai, vrai, vrai ; `moinsDe2h` → `fraiche` vrai, `ancienne` faux, `perimee` faux ; `moinsDe24h` → vrai, vrai, faux.
- Libellés exacts : « Toutes », « Moins de 2 h », « Moins de 24 h » ; et `dischargeFreshnessCriterionLabel(moinsDe2h) == 'Moins de ${ancienneApres.inHours} h'`.
- `filterableFlowCategories.map(flowCategoryLabel)` = « Eau qui coule », « Écoulement faible », « Eau stagnante », « À sec », « Non observé », « Non renseigné », dans cet ordre.
- Une fonction de test à `switch` **sans `default`** sur `DischargeFreshnessCriterion` compile (`BR-011`).

- [ ] **Étape 1** — test rouge ; `flutter test test/domain/filters` → échec, **sortie rouge recopiée**.
- [ ] **Étape 2** — implémenter ; `domain-model.md` : `MapFilter` sous « Objets-valeur », `DischargeFreshnessCriterion` sous « Nomenclatures closes » ; `typesDuDomaine` ; `glossary.md`, tableau « Termes métier », ligne : `| **Filtre** | \`MapFilter\` (T3) | Ce qui masque des lieux à l'intérieur de l'échelle affichée : des états (écoulement), un département, la fraîcheur d'une mesure (débit). Il ne choisit pas l'échelle — ce sont les puces d'échelle. Un lieu masqué n'est pas une absence de donnée. Gardé le temps de la session, jamais enregistré. |`
- [ ] **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/filters/map_filter.dart test/domain/filters/map_filter_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart docs/glossary.md && git commit -m "feat(domain): MapFilter, la valeur du filtre de la carte (F1 de T3)" -m "Six booléens, un par branche de FlowCategory, un code de département ou aucun, un critère de fraîcheur du débit aux seuils de BR-005 lus dans freshness.dart. La décision se prend par switch sur le type : Inconnu est égal par code brut, un ensemble laisserait passer Inconnu('9'). Deux membres « actif pour l'écoulement » et « actif pour le débit », sans paramètre d'échelle : MapScaleKind vit dans la tranche carte." -- lib/domain/filters/map_filter.dart test/domain/filters/map_filter_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart docs/glossary.md
```

### Task F2 : Les prédicats du filtre et la liste des départements

**Agent :** mécanique (sonnet, effort moyen).
**Files:** créés `lib/domain/filters/map_filter_predicates.dart`, `test/domain/filters/map_filter_predicates_test.dart` · modifié `docs/domain-model.md` (une phrase sous `MapFilter` : la règle « l'inconnu reste affiché »)
**Prérequis :** `F1`.

**Signatures** — fonctions pures, de premier niveau :
- `bool filterKeepsDepartement(MapFilter filter, AdministrativeArea? departement)`
- `bool filterKeepsOndeObservation(MapFilter filter, OndeObservation observation)` — département de `observation.point.departement` (`onde_point.dart:48`) **et** `filter.shows(observation.category)`.
- `bool filterKeepsStationPoint(MapFilter filter, StationPoint station)` — **département seul** (`station_point.dart:55`) : c'est la règle des pastilles et du préchargement sur le débit.
- `bool filterKeepsStation(MapFilter filter, StationPoint station, StationMapState state)` — département **puis** fraîcheur, par `switch` exhaustif sur `StationMapState` (`station_map_state.dart:15-73`).
- `List<AdministrativeArea> departementsOf(Iterable<StationPoint> stations)` — départements distincts **par code**, triés par `code` croissant (`String.compareTo`), libellé du **premier** rencontré, liste non modifiable ; les stations sans département sont ignorées.

**Invariants (cadrage § 6.3) :** un filtre ne masque que ce qui est **connu** comme hors critère. Sans rattachement (`null`) → gardé. Le département se compare par **code exact** (aucune normalisation : les libellés de l'asset et de l'API n'ont pas la même casse, `administrative_area.dart:17-20`). `NonChargee`, `EnEchec`, `SansDonnee` → gardés quel que soit le critère de fraîcheur ; `Chargee(f)` → `dischargeFreshnessAdmits(filter.dischargeFreshness, f)`.

**Cas de test**
- Département, filtre `none` : vrai pour `null` et pour tout code. Filtre `'41'` : `const AdministrativeArea(code: '41', label: 'Loir-et-Cher')` vrai ; `AdministrativeArea(code: '41', label: 'LOIR-ET-CHER')` vrai ; `AdministrativeArea(code: '37', label: 'Indre-et-Loire')` faux ; `null` **vrai** ; `AdministrativeArea(code: ' 41', label: 'Loir-et-Cher')` faux (constructeur : `lib/domain/geo/administrative_area.dart:20`).
- ONDE (observation de département `41`, catégorie `Assec`) : `none` vrai ; `assec: false` faux ; filtre département `'37'` faux même catégorie cochée ; point **sans** département et catégorie cochée → vrai ; sans département et catégorie décochée → faux.
- ONDE, `inconnu: false` : `Inconnu('9')` faux, `Inconnu(null)` faux, `NonObserve()` vrai.
- `filterKeepsStationPoint` avec `dischargeFreshness: moinsDe2h` seul → **vrai** (la fraîcheur n'y entre pas).
- `filterKeepsStation`, critère `moinsDe2h` : `Chargee(Freshness.fraiche)` vrai ; `Chargee(ancienne)` faux ; `Chargee(perimee)` faux ; `NonChargee()` vrai ; `EnEchec(Exception('x'))` vrai ; `SansDonnee()` vrai. Critère `moinsDe24h` : `ancienne` vrai, `perimee` faux. Critère `toutes` : tout vrai.
- Département connu et autre, état `NonChargee` → **faux** (le département, lui, est connu) ; sans département, `Chargee(perimee)` sous `moinsDe24h` → faux.
- **Bornes de `BR-005`**, avec `now = DateTime.utc(2026, 9, 13, 10)` et l'état `Chargee(freshnessOf(measuredAt: m, now: now))`. **Les instants s'écrivent à partir des constantes de `freshness.dart`, jamais « 2 h » ni « 24 h » en dur** : sous `moinsDe2h`, `m = now.subtract(ancienneApres)` (la borne pile) → **faux** ; `m = now.subtract(ancienneApres - const Duration(seconds: 1))` → vrai ; sous `moinsDe24h`, `m = now.subtract(perimeeApres)` (la borne pile) → **faux** ; `m = now.subtract(perimeeApres - const Duration(seconds: 1))` → vrai ; `m = now.add(const Duration(minutes: 5))` (mesure dans le futur) → vrai sous `moinsDe2h`.
- `departementsOf` sur des stations dont le `departement` vaut, dans cet ordre, `AdministrativeArea(code: '41', label: 'LOIR-ET-CHER')`, `AdministrativeArea(code: '01', label: 'AIN')`, `AdministrativeArea(code: '41', label: 'Loir-et-Cher')`, `null`, `AdministrativeArea(code: '2A', label: 'CORSE-DU-SUD')`, `AdministrativeArea(code: '29', label: 'FINISTERE')`, `AdministrativeArea(code: '971', label: 'GUADELOUPE')` → codes `['01', '29', '2A', '41', '971']`, libellé de `41` = `'LOIR-ET-CHER'` ; entrée vide → liste vide ; `.add(…)` sur le résultat → `UnsupportedError`.

- [ ] **Étape 1** — tests rouges, `flutter test test/domain/filters` → échec recopié ; **Étape 2** — implémenter, `domain-model.md` ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/filters/map_filter_predicates.dart test/domain/filters/map_filter_predicates_test.dart docs/domain-model.md && git commit -m "feat(domain): prédicats du filtre — l'inconnu reste affiché (F2 de T3)" -m "Un filtre ne masque que ce qui est connu comme hors critère : un lieu sans département, une station non chargée, en échec ou sans donnée restent affichés. Le département se compare par code. Deux prédicats pour une station : département seul (pastilles, préchargement), département puis fraîcheur (marqueurs). Bornes de BR-005 éprouvées à 2 h 00 et 24 h 00 pile." -- lib/domain/filters/map_filter_predicates.dart test/domain/filters/map_filter_predicates_test.dart docs/domain-model.md
```

### Task F3 : Amender `BR-007`, `BR-008`, `BR-009` ; écrire `UC-007` « Filtrer la carte »

**Agent :** mécanique (sonnet, effort léger) — recopie de textes approuvés.
**Files:** modifiés `docs/br/BR-007-absence-de-donnee-jamais-neutre.md`, `docs/br/BR-008-une-seule-echelle-a-la-fois.md`, `docs/br/BR-009-cluster-porte-l-etat-le-plus-severe.md`, `docs/04-ui.md` (l. 633), `docs/use-cases/UC-001-consulter-la-carte-autour-de-moi.md`, `docs/README.md` (tableau des cas d'usage, l. 125-129 : ligne `UC-007`) · créé `docs/use-cases/UC-007-filtrer-la-carte.md`

> Textes approuvés par le commanditaire le 2026-10-12 (cadrage § 10.1 (a)) : **recopiés mot pour mot**, jamais reformulés. Aucun verrou de `test/` ne lit ces phrases ; `test/project/tracabilite_test.dart` ne connaît que `UC-001` à `UC-006` (`_ucAttendus`, l. 49) et **ne bouge pas ici** : `UC-007` entre dans la matrice et dans cette liste au lot 9.

- [ ] **Étape 1 — `BR-007`** : en-tête « Statut », ajouter « · **amendé le 2026-10-12 (T3, filtre de l'usager)** ». Sous « Invariants & cas limites », ajouter la puce : « **Filtre de l'usager (T3).** Un lieu masqué par un filtre n'est pas une absence de donnée. Tant qu'un critère est actif, la carte le montre en permanence, à tous les zooms. Une carte que le filtre a vidée l'écrit — *« Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau. »* — et propose de les effacer ; elle n'emploie aucun des avis d'absence ci-dessus, qui affirmeraient qu'aucun lieu n'existe. Un lieu dont l'état n'est pas connu — non chargé, en échec, sans donnée, sans département — n'est jamais masqué par un critère qui porte sur cet état. » Sous « Liens », ajouter `UC-007`.
- [ ] **Étape 2 — `BR-008`** : dans la règle (l. 11), « choisie par le filtre » devient « choisie par **les puces d'échelle** » ; l'invariant de la l. 31 devient « Le changement d'échelle est explicite, via **les puces d'échelle**. Il n'y a pas d'échelle « automatique » selon le zoom. » ; ajouter l'invariant : « Un filtre (T3) masque des lieux à l'intérieur de l'échelle active ; il ne choisit pas l'échelle et n'en superpose aucune. » Statut : « · **amendé le 2026-10-12 (T3)** ». Dans `docs/04-ui.md` l. 633, même remplacement (« choisie par le filtre » → « choisie par les puces d'échelle »).
- [ ] **Étape 3 — `BR-009`** : après l'invariant « Le compte affiché sur le cluster est le nombre **total** de points… » (l. 29), ajouter : « Sous un filtre (T3), un cluster ne regroupe que les points retenus : son compte et son état le plus sévère portent sur eux, et un cluster sans point retenu n'est pas dessiné. Exception, sur l'échelle débit : le critère de fraîcheur ne s'applique pas aux clusters — leur compte inclut des stations dont la mesure chargée est hors critère —, et la feuille de filtres le dit. » Statut : « · **amendé le 2026-10-12 (T3)** ».
- [ ] **Étape 4 — `UC-007`**, sur le gabarit `docs/use-cases/UC-template.md` (commentaires retirés) : **Statut** Accepté · **Date** 2026-10-12 · **Contexte borné** Carte · **Acteur principal** Pêcheur (P3), P5 · acteurs secondaires : aucun (le filtre n'appelle aucune source). **Objectif** : réduire la carte aux lieux cherchés sans qu'un lieu masqué se lise comme une absence. **Préconditions** : la carte est affichée (`UC-001`). **Déclencheur** : l'usager active le bouton « Filtres », en bas à droite de la carte. **Flux nominal** : (1) la feuille « Filtres » s'ouvre sur les critères de l'échelle affichée — écoulement : « États » (six cases, toutes cochées au départ) et « Département » ; débit : « Département » et « Fraîcheur » (« Toutes », « Moins de 2 h », « Moins de 24 h ») ; (2) l'usager règle un brouillon ; (3) « Appliquer » ferme la feuille : marqueurs et pastilles ne montrent plus que les lieux retenus (`BR-009`) ; (4) le bouton « Filtres » change de forme tant qu'un critère est actif pour l'échelle affichée (`BR-007`). **Alternatifs** : A1 fermer sans appliquer : rien ne change ; A2 « Effacer » : tous les critères, des deux échelles, sont retirés ; A3 la carte est vidée par le filtre : avis « Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau. » et action « Effacer les filtres » (`BR-007`) ; A4 état non connu (station non chargée, en échec, sans donnée ; lieu sans département) : le lieu reste affiché ; A5 sous le zoom 9 sur le débit : le critère de fraîcheur ne change aucune pastille, la feuille le dit (`BR-009`) ; A6 liste des départements illisible : le critère n'est pas proposé, « La liste des départements n'a pas pu être lue. » ; A7 l'usager change d'échelle : le filtre est gardé, seuls les critères de la nouvelle échelle jouent (`BR-008`). **Postconditions** : le filtre vit le temps de la session ; après relancement, aucun filtre n'est actif. **Règles** : `BR-003`, `BR-005`, `BR-007`, `BR-008`, `BR-009`, `BR-011`. **Liens** : `ADR-014`, `ADR-015` · `04-ui.md`. Un `flowchart` mermaid **à côté du flux alternatif A4** : celui du cadrage § 6.3, recopié.
- [ ] **Étape 5 — `docs/README.md`** : dans le tableau des cas d'usage, après la ligne `UC-006` (l. 129), ajouter `| [UC-007](use-cases/UC-007-filtrer-la-carte.md) | Filtrer la carte | Pêcheur |`. **Puis `UC-001`** : sous « Flux alternatifs / erreurs », ajouter « - **A7 — L'usager filtre la carte :** voir `UC-007` ; un lieu masqué par un filtre n'est pas une absence de donnée (`BR-007`). »
- [ ] **Étape 6** — critère de fin (la suite ne change pas de total), commit.

```bash
git add -- docs/br/BR-007-absence-de-donnee-jamais-neutre.md docs/br/BR-008-une-seule-echelle-a-la-fois.md docs/br/BR-009-cluster-porte-l-etat-le-plus-severe.md docs/04-ui.md docs/use-cases/UC-001-consulter-la-carte-autour-de-moi.md docs/README.md docs/use-cases/UC-007-filtrer-la-carte.md && git commit -m "docs: BR-007, BR-008 et BR-009 amendées pour le filtre de l'usager ; UC-007 « Filtrer la carte » (F3 de T3)" -m "Textes approuvés par le commanditaire le 2026-10-12 (cadrage de T3, § 10.1). Un lieu masqué n'est pas une absence ; l'échelle se choisit par les puces, le filtre masque à l'intérieur d'elle ; un cluster ne regroupe que les points retenus, sauf le critère de fraîcheur sur le débit, dit dans la feuille." -- docs/br/BR-007-absence-de-donnee-jamais-neutre.md docs/br/BR-008-une-seule-echelle-a-la-fois.md docs/br/BR-009-cluster-porte-l-etat-le-plus-severe.md docs/04-ui.md docs/use-cases/UC-001-consulter-la-carte-autour-de-moi.md docs/README.md docs/use-cases/UC-007-filtrer-la-carte.md
```

---

## Lot 3 — Filtres : `MapViewModel`

> `lib/features/map/view_model/map_view_model.dart` (1 291 lignes) ne reçoit **aucune règle** : un champ, des getters et des appels aux prédicats de `lib/domain/filters/`. **`stations` (l. 263) et `ondeObservations` (l. 565) restent les faits lus, non filtrés** : les avis d'absence se décident sur eux. Le constructeur (l. 228-235) **ne change pas**. Les tests nouveaux vivent dans `test/features/map/view_model/map_view_model_filter_test.dart` ; la suite existante `map_view_model_test.dart` (2 434 lignes) est le filet : **inchangée et verte**. Doubles de dépôt : recopier `_StationPointRepositoryDouble`, `_HydroObservationRepositoryDouble`, `_OndeObservationRepositoryDouble` et l'assistant `build` de `map_view_model_test.dart` l. 241-375 (classes privées, non importables). Horloge de référence : `DateTime.utc(2026, 9, 13, 10)`.
>
> **Jeux de données des quatre tâches** (à écrire dans le fichier de test) — ONDE, par `_obs(code, {category, departement, region, latitude, longitude})`, `observedAt: DateTime.utc(2026, 8, 25)` : `A` `K4520001` `Ecoulement` dép. `41` · `B` `K4520002` `Assec` dép. `41` · `C` `K4520003` `Inconnu('9')` dép. `41` · `D` `K4520004` `Inconnu(null)` dép. `37` · `E` `K4520005` `NonObserve` **sans département**. Stations : `S1` `K447000001` dép. `41`, mesure à `now.subtract(ancienneApres ~/ 2)` (fraîche) · `S2` `K447000002` dép. `41`, `now.subtract(ancienneApres + const Duration(hours: 1))` (ancienne) · `S3` `K447000003` dép. `37`, `now.subtract(perimeeApres + const Duration(hours: 1))` (périmée) — **instants écrits à partir de `ancienneApres` et `perimeeApres` (`freshness.dart:28`, `:33`), jamais « 2 h » ni « 24 h » en dur** · `S4` `K447000004` **sans département**, dont `findLatest` lève.

### Task F4 : Le filtre appliqué, et les marqueurs individuels qu'il retient

**Agent :** **raisonnement** (opus, effort élevé) — ajout dans un fichier à comportement verrouillé.
**Files:** créés `lib/features/map/view_model/map_filter_scale.dart`, `test/features/map/view_model/map_filter_scale_test.dart`, `test/features/map/view_model/map_view_model_filter_test.dart` · modifié `lib/features/map/view_model/map_view_model.dart`
**Prérequis :** `F1`, `F2`.

**Signatures**
- `map_filter_scale.dart` (Dart pur, aucun widget) : `bool mapFilterActiveFor(MapFilter filter, MapScaleKind scale)` — `switch` exhaustif : `ecoulement` → `filter.isActiveForFlow`, `debit` → `filter.isActiveForDischarge`.
- Dans `MapViewModel` : `MapFilter get filter;` (champ `_filter`, `MapFilter.none` au départ) · `bool get filterActive;` (= `mapFilterActiveFor(_filter, _scale)`) · `void applyFilter(MapFilter filter);` · `void clearFilter();` (= `applyFilter(MapFilter.none)`).
- `individualStations` (l. 350-358) : les stations de l'emprise que retient `filterKeepsStation(_filter, point, stateOf(point.code))`, **dans ses deux branches** (niveau individuel ; sous le zoom 9, les stations sans zone). `individualOndeObservations` (l. 362-368), **branche du niveau individuel seulement** : `filterKeepsOndeObservation`. (La branche sous le zoom 9 et `clusters` : `F5`.)

**Invariants :** `applyFilter` d'un filtre **égal** au courant ne fait rien, pas même notifier ; sinon il pose le filtre et notifie **une** fois ; il n'appelle **aucun dépôt** dans cette tâche (le préchargement : `F6`). `selectScale` (l. 880) ne touche pas le filtre. Quand `filterActive` est faux, `individualStations` au niveau individuel rend **la même instance** que `stations` (aucune copie de 4 150 points, `NFR-01`). Rien n'est persisté : aucun dépôt ne s'ajoute au constructeur.

**Cas de test**
- `mapFilterActiveFor` : `none` → faux, faux ; `assec: false` → vrai sur `ecoulement`, faux sur `debit` ; `moinsDe2h` → faux, vrai ; département → vrai, vrai.
- Au départ : `filter == MapFilter.none`, `filterActive` faux. Un `MapViewModel` **neuf** porte `MapFilter.none` (critère 16 : rien n'est relu d'un stockage).
- `applyFilter(none.withCategory(const Assec(), shown: false))` : **1** notification, `filterActive` vrai ; `selectScale(MapScaleKind.debit)` → `filterActive` **faux**, `filter` inchangé ; retour à `ecoulement` → vrai, `filter` inchangé (session, `R13`).
- `applyFilter` du même filtre une seconde fois : **0** notification. `clearFilter()` sur un filtre « `assec: false`, département `41`, `moinsDe2h` » : `filter == MapFilter.none`, 1 notification (critère 13) ; `clearFilter()` sur `none` : 0 notification.
- **Écoulement, niveau individuel** (`loadFor` sur l'emprise Loire, ONDE = `[A, B, C, D, E]`) — codes de `individualOndeObservations`, dans l'ordre : `none` → `A, B, C, D, E` ; `assec: false` → `A, C, D, E` ; `inconnu: false` → `A, B, E` (les deux `Inconnu`, quelle que soit leur valeur brute — critère 2) ; département `'41'` → `A, B, C, E` (`E`, sans département, reste — critère 5) ; département `'41'` + `assec: false` → `A, C, E` ; six cases à faux → vide. **Dans les six cas `ondeObservations.length == 5`.** `orderedIndividualOndeObservations` porte le même ensemble.
- **Débit, niveau individuel** (`selectScale(debit)`, `loadFor`, `preloadVisibleStations()`, stations `[S1, S2, S3, S4]`) — codes de `individualStations` : `none` → les quatre ; `moinsDe2h` → `S1, S4` (critère 6 ; `S4` en échec reste, critère 7) ; `moinsDe24h` → `S1, S2, S4` ; département `'41'` → `S1, S2, S4` ; département `'41'` + `moinsDe2h` → `S1, S4`. **`stations.length == 4` partout.**
- Avant tout préchargement (quatre `NonChargee`), `moinsDe2h` → les quatre restent (critère 7). Une station dont `findLatest` rend `null` (`SansDonnee`) reste sous `moinsDe2h`.
- **Vieillissement sans requête** (`BR-005`) : horloge injectée réglable, instants écrits à partir des constantes ; `S1` mesurée à `m`, chargée quand l'horloge vaut `m.add(ancienneApres - const Duration(seconds: 1))` (`fraiche`) : présente sous `moinsDe2h` ; horloge portée à `m.add(ancienneApres)` (**la borne pile**) : `individualStations` ne la contient plus, **sans aucun appel** de plus à `findLatest`, sans notification. De même sous `moinsDe24h` : présente à `m.add(perimeeApres - const Duration(seconds: 1))`, absente à `m.add(perimeeApres)`.
- `filterActive` faux, niveau individuel : `identical(viewModel.individualStations, viewModel.stations)` vrai.
- `layers_test.dart` vert (`view-model-sans-widget`).

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/map/view_model` → échec recopié.
- [ ] **Étape 2** — implémenter. Mettre à jour le commentaire de `individualStations` et de `stations` (« non filtrés, les avis s'y décident »).
- [ ] **Étape 3 — contre-épreuve** : remplacer provisoirement `filterKeepsStation` par `filterKeepsStationPoint` dans `individualStations` → le cas `moinsDe2h` rougit ; rétablir → vert. Recopier le rouge dans le message de commit.
- [ ] **Étape 4** — critère de fin (`map_view_model_test.dart` **non modifié**), commit.

```bash
git add -- lib/features/map/view_model/map_filter_scale.dart test/features/map/view_model/map_filter_scale_test.dart test/features/map/view_model/map_view_model_filter_test.dart lib/features/map/view_model/map_view_model.dart && git commit -m "feat(map): filtre appliqué par MapViewModel, marqueurs individuels retenus (F4 de T3)" -m "Un champ, appliquer, effacer, et les prédicats du domaine sur les marqueurs à dessiner. stations et ondeObservations restent les faits lus : les avis d'absence s'y décident. Filtre de session, non persisté, conservé au changement d'échelle. Une mesure qui passe la borne sort du filtre à la lecture suivante, sans requête. Contre-épreuve : <recopier le rouge>." -- lib/features/map/view_model/map_filter_scale.dart test/features/map/view_model/map_filter_scale_test.dart test/features/map/view_model/map_view_model_filter_test.dart lib/features/map/view_model/map_view_model.dart
```

### Task F5 : Les pastilles sous filtre

**Agent :** mécanique (sonnet, effort moyen) — deux sources de regroupement à filtrer, cas dictés.
**Files:** modifiés `lib/features/map/view_model/map_view_model.dart`, `test/features/map/view_model/map_view_model_filter_test.dart`
**Prérequis :** `F4`. Règle : `BR-009` amendée (`F3`), cadrage § 6.3 et `R10`.

**Changement** — deux points d'entrée, et eux seuls :
- `_ondeClustering` (l. 394-406) reçoit `_ondeObservations.values.where((OndeObservation o) => filterKeepsOndeObservation(_filter, o))` au lieu de `_ondeObservations.values` : le filtre s'applique **avant** `clusterByArea` (`lib/domain/geo/area_cluster.dart:84`). Compte, barycentre, emprise, `severest` et `severestAge` portent alors sur les seuls retenus ; une zone sans membre retenu ne produit **aucun** agrégat ; `individualOndeObservations` sous le zoom 9 (`unassigned`) suit.
- `_stationClustering` (l. 378-390) reçoit `all.where((StationPoint p) => filterKeepsStationPoint(_filter, p))` : **département seul**. Le critère de fraîcheur **ne s'applique pas** aux pastilles du débit (exception assumée, dite dans la feuille, `F9`).
- Corriger le commentaire de `MapAreaCluster.count` (l. 124-127) : « sous un filtre, le compte des membres **retenus** ».

**Cas de test** (horloge 2026-09-13T10:00Z ; régions `24 'Centre-Val de Loire'` et `84 'Auvergne-Rhône-Alpes'`)
- **Écoulement, zoom 6** (`onGestureEnded(bounds, zoom: 6)`), ONDE : `R1` (`Ecoulement`, région 24, dép. 41, 47,0 N 1,0 E), `R2` (`Ecoulement`, 24, dép. 37, 47,4 N 1,4 E), `R3` (`Assec`, 24, dép. 41, 47,8 N 1,8 E), `R4` et `R5` (`Assec`, région 84, dép. 01, 45,0 N 5,0 E et 45,5 N 5,5 E), `R6` (`Ecoulement`, sans région, dép. 41).
  - `none` : `clusters` = `24` (count 3, `severest` `Assec`), `84` (count 2, `Assec`) ; `individualOndeObservations` = `[R6]`.
  - `assec: false` : `clusters` = **un seul**, `24`, count **2**, `severest` `Ecoulement`, barycentre 47,2 N 1,2 E ; **aucun agrégat `84`** (critère 9) ; individuels `[R6]`.
  - `ecoulement: false` : `24` count 1, `severest` `Assec`, `bounds == null`, latitude 47,8 et longitude 1,8 ; `84` count 2 ; individuels **vides**.
  - département `'41'` : `24` count 2 (`R1`, `R3`) ; pas de `84` ; individuels `[R6]`.
  - `orderedClusters` porte les mêmes agrégats.
- **Écoulement, zoom 8** (niveau département), `assec: false` : agrégats `37` (count 1 : `R2`) et `41` (count **2** : `R1` et `R6`, qui a un département) ; aucun `01` ; individuels vides.
- **Débit, zoom 6** (`selectScale(debit)` puis `onGestureEnded(bounds, zoom: 6)`), asset entier (`allAnswer`) : `T1`, `T2` (région 24, dép. 41), `T3` (24, dép. 37), `T4`, `T5` (région 84, dép. 01), `T6` (région 24, **sans** département), `T7` (sans région ni département) ; `withinBounds` rend les mêmes sept.
  - `none` : `24` count 4, `84` count 2 ; `individualStations` = `[T7]`.
  - département `'41'` : `24` count **3** (`T1`, `T2`, et `T6` sans département, qui reste — `R9`) ; **aucun `84`** ; `individualStations` = `[T7]`.
  - `moinsDe2h` seul, les sept étant `NonChargee` : mêmes agrégats que `none`.
  - **Critère 10** : démarrer au zoom 9 sur le débit, précharger `T1` avec une mesure de `now.subtract(perimeeApres + const Duration(hours: 1))` (`Chargee(perimee)`), puis `onGestureEnded(bounds, zoom: 6)` ; sous `moinsDe2h` : `24` garde count **4** — identique à `none`.
  - Un individuel sans zone **chargé hors critère** est masqué : `T7` préchargé à `now.subtract(perimeeApres + const Duration(hours: 1))`, zoom 6, `moinsDe2h` → `individualStations` vide (la fraîcheur vaut pour les marqueurs, pas pour les pastilles).
- La suite `map_view_model_test.dart` reste inchangée et verte.

- [ ] **Étape 1** — tests rouges, `flutter test test/features/map/view_model/map_view_model_filter_test.dart` → échec recopié ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart && git commit -m "feat(map): pastilles sous filtre — regroupement des seuls points retenus (F5 de T3)" -m "Sur l'écoulement le filtre passe avant le regroupement : compte, barycentre et état le plus sévère portent sur les points retenus, une pastille vidée n'est pas dessinée (BR-009 amendée). Sur le débit seul le département passe avant ; le critère de fraîcheur ne change aucune pastille, exception dite dans la feuille." -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart
```

### Task F6 : Préchargement borné au département ; liste des départements

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `lib/features/map/view_model/map_view_model.dart`, `test/features/map/view_model/map_view_model_filter_test.dart`
**Prérequis :** `F4`.

**Signatures et changements**
- `_closestToCentre` (l. 1168-1198) : le filtre de la l. 1183 devient `_needsPreload(point.code) && filterKeepsStationPoint(_filter, point)` — département **seul** ; le critère de fraîcheur n'y entre **jamais** (circulaire : il faut charger pour connaître la fraîcheur).
- `applyFilter` : après la notification, **si** `shouldPreloadOn(_scale) && _level == null` (`map_scale.dart:65`), `cancelPreload()` puis `unawaited(preloadVisibleStations())` — la même condition que `selectScale` (l. 897).
- `Future<List<AdministrativeArea>?> departements()` : lit `StationPointRepository.all()` (`repositories.dart:64`), rend `departementsOf(...)` ; **`null` si la lecture lève**. Mémo propre (un champ `List<AdministrativeArea>? _departements`), posé au premier succès seulement ; **ne touche ni `_allStations`, ni `error`, ni `errorSource`, et ne notifie pas** ; après `dispose`, `departements()` rend le mémo s'il existe, sinon `null`, sans lever.

**Cas de test**
- 30 stations en ligne, longitude `i / 100` pour `i = 0..29`, latitude 46, emprise centrée sur (46, 0) ; `i = 0..4` de département `37`, `i = 5..29` de département `41`. Échelle débit, niveau individuel, filtre département `'41'`, `preloadVisibleStations(limit: 20)` : les 20 codes demandés sont ceux de `i = 5..24`, dans cet ordre ; **aucun** de `i = 0..4` (critère 8).
- Une station **sans** département est préchargée sous le filtre département `'41'` (elle est affichée).
- Filtre `moinsDe2h` seul, trois stations : **trois** requêtes. Puis l'une, `Chargee(perimee)`, est masquée ; horloge avancée de `stationStateRefreshAfter` (constante lue, `map_view_model.dart:74`) ; nouveau préchargement → **une** requête pour elle : une station masquée par la fraîcheur reste rechargée.
- `applyFilter(département '41')` sur le débit au niveau individuel, stations `[S1, S2, S3, S4]` déjà préchargées une fois sans filtre, horloge avancée de `stationStateRefreshAfter` : de nouvelles requêtes partent, **aucune** pour `S3` (dép. 37).
- `applyFilter` sur l'**écoulement** : zéro `findLatest`. Sur le débit **sous le zoom 9** : zéro. Avec un filtre **égal** : zéro.
- Annulation : `findLatest` suspendu par un `Completer` pendant un préchargement ; `applyFilter(…)` ; compléter → l'état de cette station n'est **pas** écrit par l'ancienne boucle.
- `departements()` : asset de trois stations — `AdministrativeArea(code: '41', label: 'LOIR-ET-CHER')`, `AdministrativeArea(code: '01', label: 'AIN')`, une sans département → ces deux zones, `01` puis `41` ; deux appels → **un** seul appel de plus à `all()` ; `all()` qui lève → `null`, `viewModel.error` reste `null`, **0** notification ; `all()` rétabli → l'appel suivant rend la liste (l'échec n'est pas mémorisé) ; appel après `dispose` : mémo déjà posé → la liste mémorisée ; aucun mémo → `null` ; aucune exception dans les deux cas.

- [ ] **Étape 1** — tests rouges recopiés ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart && git commit -m "feat(map): préchargement borné au département du filtre ; liste des départements (F6 de T3)" -m "Le préchargement ne porte que sur les stations que le critère département retient, jamais sur le critère de fraîcheur, qui exige d'avoir chargé. Appliquer un filtre annule et relance le préchargement. La liste des départements vient du référentiel embarqué, triée par code ; illisible, elle se rend nulle sans poser d'erreur sur la carte." -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart
```

### Task F7 : « Le filtre a vidé la carte » ; premiers scénarios de `filtres.feature`

**Agent :** **raisonnement** (opus, effort élevé) — la règle décide d'un avis de `BR-007`, et un verrou de `test/project/` s'ouvre.
**Files:** modifiés `lib/features/map/view_model/map_view_model.dart`, `test/features/map/view_model/map_view_model_filter_test.dart`, `test/project/acceptance_features_test.dart`, `docs/README.md` (ligne `acceptance/`, l. 23 : `filtres.feature` y est nommé) · créé `docs/acceptance/filtres.feature`
**Prérequis :** `F5`, `F6`.

**Signature** — `bool get filterHidesEverything;` sur `MapViewModel`.

**Règle** — **affinement du cadrage § 6.5** (« lu non vide sur l'emprise ET rien de dessiné après filtre, ni marqueur ni pastille »), arbitré par la boucle principale le 2026-10-12 : la règle porte sur **les stations lues sur l'emprise**, pas sur `clusters.isEmpty`. Vrai **si et seulement si** les trois sont vrais :
1. `filterActive` ;
2. le fait lu de l'échelle est non vide — `ondeObservations` sur l'écoulement, `stations` sur le débit ;
3. **aucun lieu lu sur l'emprise n'est retenu** : écoulement → aucune observation ne passe `filterKeepsOndeObservation` ; débit au niveau individuel → aucune station ne passe `filterKeepsStation` ; débit sous le zoom 9 → pour chaque station de `stations`, `filterKeepsStationPoint` si elle a une zone au niveau courant (elle est membre d'une pastille, que la fraîcheur ne touche pas), `filterKeepsStation` sinon.

> ⚠️ Sur le débit sous le zoom 9, `clusters` porte sur l'**asset entier** (`map_view_model.dart:378-390`) : une pastille retenue peut exister à l'autre bout du pays. La règle regarde donc les stations **de l'emprise**, pas `clusters.isEmpty` — et ne dépend pas de ce que l'asset entier soit déjà lu.

**Cas de test**
- Sans filtre : faux, emprise vide comme pleine.
- Écoulement, `[B (Assec, 41), R3 (Assec, 41)]`, `assec: false` : **vrai** au zoom 9 **et** au zoom 6. Même filtre, ONDE vide : **faux** (lu vide : l'avis d'absence habituel). Même données, filtre `moinsDe2h` seul : faux (pas actif pour l'écoulement).
- Écoulement, `[A, B]`, `assec: false` : faux (`A` reste).
- Débit, niveau individuel, deux stations de dép. `37`, filtre département `'41'` : **vrai** ; avec `S4` (sans département) en plus : faux.
- Débit, niveau individuel, deux stations `Chargee(perimee)`, `moinsDe24h` : **vrai** ; avant leur préchargement (`NonChargee`) : faux.
- Débit, **zoom 6**, emprise ne lisant que `T3` (région 24, dép. 37), filtre département `'41'`, asset entier portant `T1`, `T2` (dép. 41) ailleurs : `clusters` **non vide** et pourtant `filterHidesEverything` **vrai**.
- Débit, zoom 6, stations de l'emprise toutes rattachées et `Chargee(perimee)`, `moinsDe2h` : **faux** (la pastille reste, la fraîcheur ne la touche pas).
- Débit, zoom 6, `all()` jamais abouti, emprise portant une station de dép. `41`, filtre département `'41'` : faux.
- Après `clearFilter()` : faux.

**`docs/acceptance/filtres.feature`** — créé ici avec les scénarios que le ViewModel réalise ; `F8`, `F9`, `F10b` y ajoutent les leurs. Chaque scénario porte « Étant donné », « Quand », « Alors » et cite une `BR-` existante ; **aucun** des mots « suffisant, insuffisant, normal, bon, sûr » ni verbe d'instruction (`acceptance_features_test.dart:84-107`).

```gherkin
Fonctionnalité: Filtrer la carte
  # Critères d'acceptation en Gherkin — spécification lisible, jamais exécutée.
  # Vérifié par test/project/acceptance_features_test.dart.
  # Source : cadrage de T3 (2026-10-12), § 8 ; UC-007 ; BR-007, BR-008, BR-009.
  En tant qu'usager de la carte
  Je veux masquer les lieux qui ne m'intéressent pas
  Afin de ne lire que ce que je cherche, sans prendre un lieu masqué pour une absence

  # ── US-13 — Je filtre par type de donnée, état, département et fraîcheur

  Scénario: Décocher une catégorie d'écoulement retire ses marqueurs
    Étant donné l'échelle « Écoulement » et des points « À sec » et « Eau qui coule » à l'écran
    Quand le filtre appliqué a la case « À sec » décochée
    Alors seuls les marqueurs « Eau qui coule » restent, et le lieu masqué n'est pas une absence de donnée (BR-007)

  Scénario: Un code d'écoulement non reconnu suit la case « Non renseigné »
    Étant donné deux points dont le code d'écoulement n'est pas reconnu, l'un de valeur brute « 9 », l'autre sans valeur
    Quand le filtre appliqué a la case « Non renseigné » décochée
    Alors les deux marqueurs sont masqués, et un point « Non observé » reste affiché (BR-011)

  Scénario: Choisir un département ne laisse que ses lieux, sur les deux échelles
    Étant donné des lieux de deux départements à l'écran
    Quand le filtre appliqué porte l'un des deux départements
    Alors seuls les lieux de ce département restent, sur « Écoulement » comme sur « Débit relatif à l'historique » (BR-008)

  Scénario: Un lieu sans département reste affiché sous un critère de département
    Étant donné une station du référentiel sans département
    Quand le filtre appliqué porte un département
    Alors cette station reste affichée : son département n'est pas connu (BR-007)

  Plan du scénario: Le critère de fraîcheur masque une station chargée dont la mesure a atteint la borne
    Étant donné l'échelle « Débit relatif à l'historique » et une station chargée dont la mesure a <âge>
    Quand le critère de fraîcheur appliqué est <critère>
    Alors le marqueur de cette station est <rendu> (BR-005)

    Exemples:
      | âge     | critère       | rendu   |
      | 1 h 59  | Moins de 2 h  | affiché |
      | 2 h 00  | Moins de 2 h  | masqué  |
      | 23 h 59 | Moins de 24 h | affiché |
      | 24 h 00 | Moins de 24 h | masqué  |

  Scénario: Une station dont l'état n'est pas connu reste affichée sous le critère de fraîcheur
    Étant donné l'échelle « Débit relatif à l'historique » et trois stations : non chargée, en échec, sans donnée
    Quand le critère « Moins de 2 h » est appliqué
    Alors les trois marqueurs restent affichés, sous leur rendu habituel (BR-007)

  Scénario: Le préchargement ne porte que sur les stations du département choisi
    Étant donné l'échelle « Débit relatif à l'historique » et des stations de deux départements à l'écran
    Quand le filtre appliqué porte l'un des deux départements
    Alors aucune mesure n'est demandée pour les stations de l'autre, qui sont masquées et non absentes (BR-007)

  Scénario: Sous le zoom 9, une pastille d'écoulement ne compte que les points retenus
    Étant donné l'échelle « Écoulement », sous le zoom 9, une pastille de trois points dont un « À sec »
    Quand le filtre appliqué a la case « À sec » décochée
    Alors la pastille compte deux points et porte l'état le plus sévère de ces deux-là ; une pastille sans point retenu n'est pas dessinée (BR-009)

  Scénario: Sous le zoom 9, le critère de fraîcheur ne change aucune pastille de débit
    Étant donné l'échelle « Débit relatif à l'historique », sous le zoom 9, une pastille dont une station a une mesure chargée de plus de 24 h
    Quand le critère « Moins de 24 h » est appliqué
    Alors le compte de la pastille est le même qu'avant le filtre (BR-009)

  Scénario: Effacer retire tous les critères, des deux échelles
    Étant donné un filtre portant une case décochée, un département et le critère « Moins de 2 h »
    Quand l'usager efface les filtres
    Alors aucun critère n'est actif, ni sur « Écoulement » ni sur « Débit relatif à l'historique » (BR-007)

  Scénario: Après relancement, aucun filtre n'est actif
    Étant donné un filtre appliqué pendant une session
    Quand l'application est relancée
    Alors la carte montre tous les lieux : aucun n'est masqué sans un geste de l'usager ce jour-là (BR-007)
```

**Verrou `test/project/acceptance_features_test.dart`** — `_featureFiles` (l. 33-39) gagne `'filtres.feature'` (les intitulés « cinq fichiers » deviennent « six ») ; ajouter : (a) `filtres.feature` range au moins un scénario sous la section `US-13` (`_scenariosByStory`) ; (b) chacune de `BR-005`, `BR-007`, `BR-008`, `BR-009`, `BR-011` est citée par au moins un **scénario** ; (c) les libellés portés par le code y figurent entre guillemets français (`_containsQuoted`) : `mapScaleLabel(MapScaleKind.ecoulement)`, `mapScaleLabel(MapScaleKind.debit)`, `flowCategoryLabel(const Inconnu(null))`, `flowCategoryLabel(const Assec())`, `dischargeFreshnessCriterionLabel(DischargeFreshnessCriterion.moinsDe2h)` ; (d) les quatre bornes « 1 h 59 », « 2 h 00 », « 23 h 59 », « 24 h 00 » y figurent.

- [ ] **Étape 1** — tests rouges (ViewModel et verrou) recopiés ; **Étape 2** — implémenter le getter, écrire le `.feature`, nommer `filtres.feature` dans la ligne `acceptance/` de `docs/README.md`.
- [ ] **Étape 3 — contre-épreuve** : dans `filtres.feature`, remplacer « Non renseigné » par « Non renseignée » → le verrou rougit ; rétablir → vert. Recopier le rouge.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart test/project/acceptance_features_test.dart docs/README.md docs/acceptance/filtres.feature && git commit -m "feat(map): MapViewModel dit quand le filtre a vidé la carte ; filtres.feature (F7 de T3)" -m "Vrai quand un critère est actif pour l'échelle, que la lecture de l'emprise n'est pas vide et qu'aucun lieu lu n'est retenu. Sur le débit sous le zoom 9 la règle regarde les stations de l'emprise, pas les pastilles, calculées sur le référentiel entier. Premiers scénarios de US-13, liés aux libellés du code. Contre-épreuve : <recopier le rouge>." -- lib/features/map/view_model/map_view_model.dart test/features/map/view_model/map_view_model_filter_test.dart test/project/acceptance_features_test.dart docs/README.md docs/acceptance/filtres.feature
```

---

## Lot 4 — Filtres : vue

> Tout test de widget nouveau **nomme sa plateforme** : `testWidgetsOnWindows` (`test/support/windows_platform.dart:19`) ou `testWidgetsOnAndroid` (`test/support/android_platform.dart`, tâche `N1` du lot 1, même signature). **Jamais de `testWidgets(` nu** — le verrou de `N1` cherche ce mot sur **toute ligne de code, commentaire de fin de ligne compris** : dans un fichier de test nouveau, il n'apparaît que sous les formes `testWidgetsOnWindows` et `testWidgetsOnAndroid`, jamais seul, pas même dans un commentaire. `lib/features/map/view/map_view.dart` (2 050 lignes) ne reçoit que des branchements : chaque pièce vit dans son fichier. Aucun fichier de la vue n'importe `lib/data/` ni une autre tranche (`layers_test.dart`). Les textes d'écran sont ceux du cadrage § 10.1 (b), **mot pour mot**, portés par des constantes.

### Task F8 : L'avis de carte vidée par le filtre

**Agent :** mécanique (sonnet, effort moyen).
**Files:** modifiés `lib/features/map/view/map_empty_states.dart`, `test/features/map/view/map_empty_states_test.dart`, `lib/features/map/view/map_view.dart`, `test/features/map/view/map_view_test.dart`, `test/features/map/view/map_overlays_phone_test.dart`, `test/diagnostics/fluidity_probe_panel_test.dart`, `docs/acceptance/filtres.feature`, `test/project/acceptance_features_test.dart`, `docs/04-ui.md`
**Prérequis :** `F7`.

**Signatures** (existant recopié de `map_empty_states.dart`)
- `const String filterHidesEverythingText = "Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau.";` · `const String clearFiltersLabel = 'Effacer les filtres';` · `const Key clearFiltersKey = ValueKey<String>('map-effacer-les-filtres');`
- `final class FilterHidesEverything extends MapNotice { const FilterHidesEverything(); }` — nouvelle branche de la `sealed class MapNotice` (l. 132).
- `mapNoticesFor` (l. 222-229, six paramètres `required` : `scale`, `hasStations`, `hasOndeObservations`, `error`, `errorSource`, `ondeUnreadableRows`) gagne **`required bool filterHidesEverything`**.
- `buildMapNotice(MapNotice notice, {required VoidCallback onWiden})` (l. 252) gagne **`required VoidCallback onClearFilters`**.
- `class FilterHidesEverythingNotice extends StatelessWidget { const FilterHidesEverythingNotice({required this.onClearFilters, super.key}); final VoidCallback onClearFilters; }` — même habillage que `_AbsenceNotice` (l. 298) : `_NoticeCard`, le texte, puis l'action. `_WidenSearchAction` (l. 320) devient une action privée paramétrée (clé, libellé, rappel), réutilisée par les deux avis ; rendu et sémantique d'« Élargir la recherche » **inchangés**.
- `buildMapOverlays` (`map_view.dart:830-850`) gagne **`required bool filterHidesEverything`** et **`required VoidCallback onClearFilters`** ; il les passe à `mapNoticesFor` (l. 863) et à `buildMapNotice` (l. 893). `_MapViewState.build` (`map_view.dart:1834`) passe, dans l'appel `...buildMapOverlays(` de la l. 2014, `widget.viewModel.filterHidesEverything` et `widget.viewModel.clearFilter`.

**Règle de `mapNoticesFor`**, dans cet ordre : (1) une panne parle seule, inchangé ; (2) si `filterHidesEverything` **et** que le fait lu de l'échelle est non vide (`hasStations` sur le débit, `hasOndeObservations` sur l'écoulement) → `FilterHidesEverything`, précédé de `UnreadableRows(n)` sur l'écoulement quand `ondeUnreadableRows > 0` (**les deux avis**, arbitrage de la boucle principale du 2026-10-12 : ils ne se contredisent pas) ; **aucun** avis d'absence avec lui ; (3) sinon, la décision actuelle, inchangée.

**Cas de test**
- `error` non nul et `filterHidesEverything: true` → `[SourceUnavailable]` seul, sur les deux échelles.
- Écoulement, `hasOndeObservations: true`, `filterHidesEverything: true`, 0 ligne illisible → `[FilterHidesEverything]` ; avec 3 lignes illisibles → `[UnreadableRows(3), FilterHidesEverything]`.
- Écoulement, `hasOndeObservations: false`, `filterHidesEverything: true` : `hasStations: true` → `[OutsideOndeCoverage]` ; `hasStations: false` → `[NoDataInArea]` (lu vide : l'avis habituel, critère 12).
- Débit, `hasStations: true`, `filterHidesEverything: true` → `[FilterHidesEverything]` ; `hasStations: false` → `[NoStationInArea]`.
- Tous les cas existants de `map_empty_states_test.dart`, avec `filterHidesEverything: false` : résultats **inchangés**.
- Widget (`testWidgetsOnWindows`) : le texte exact ; une action de libellé sémantique « Effacer les filtres », `button: true` ; un tap appelle `onClearFilters` **une** fois ; ni `NoDataInAreaNotice`, ni `NoStationInAreaNotice`, ni `OutsideOndeCoverageNotice` ; ni « Élargir la recherche ».
- Cible de l'action : hauteur ≥ `minimumTapTargetFor(TargetPlatform.windows)` (`testWidgetsOnWindows`), ≥ `minimumTapTargetFor(TargetPlatform.android)` (`testWidgetsOnAndroid`, titre « Android : … »).
- `buildMapOverlays` à 800 × 740 (`testWidgetsOnWindows`) et à 360 × 640 (`testWidgetsOnAndroid`, titre « Android : … » — toute fenêtre de moins de 600 px de large est un cas Android), échelle écoulement, `filterHidesEverything: true` : le rectangle de `clearFiltersKey` est **dans l'écran** et ne recoupe ni `MapLegend`, ni `MapControls`.
- `MapView` montée (`testWidgetsOnWindows`), ONDE = deux `Assec`, puis `viewModel.applyFilter(none.withCategory(const Assec(), shown: false))` : `find.text(filterHidesEverythingText)` → un ; tap sur « Effacer les filtres » : l'avis disparaît, `viewModel.filter == MapFilter.none`, deux marqueurs ONDE redessinés.
- `MapView`, panne ONDE (`latestWithinBounds` lève) après un balayage dont le filtre masque tout : seul `SourceUnavailableNotice` est affiché.
- Les neuf appels de `buildMapOverlays` dans `test/` (`map_view_test.dart` × 7, `map_overlays_phone_test.dart`, `fluidity_probe_panel_test.dart`) reçoivent `filterHidesEverything: false, onClearFilters: () {}` — vérifier par `grep -rn "buildMapOverlays(" lib test`.
- `test/project/vocabulary_test.dart` vert.

**Documents** — `filtres.feature`, sous `US-13` :

```gherkin
  Scénario: Une carte vidée par le filtre le dit et propose de l'effacer
    Étant donné une emprise où des lieux ont été lus et un filtre qui les masque tous
    Quand la carte s'affiche
    Alors elle écrit « Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau. », propose « Effacer les filtres », et n'affiche aucun avis d'absence (BR-007)

  Scénario: Une emprise sans lieu garde son avis d'absence, filtre actif ou non
    Étant donné une emprise où aucun lieu n'a été lu et un filtre actif
    Quand la carte s'affiche
    Alors l'avis d'absence habituel s'affiche, et l'avis des filtres ne s'affiche pas (BR-007)
```
`acceptance_features_test.dart` : `filterHidesEverythingText` et `clearFiltersLabel` figurent entre guillemets français dans `filtres.feature`. `docs/04-ui.md`, sous « Filtres · Avertissement initial » : un croquis de l'avis (texte, puis bouton « Effacer les filtres »), daté « Ajout du 2026-10-12, T3 ».

- [ ] **Étape 1** — tests rouges recopiés ; **Étape 2** — implémenter, mettre à jour les appelants ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/map/view/map_empty_states.dart test/features/map/view/map_empty_states_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart test/diagnostics/fluidity_probe_panel_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md && git commit -m "feat(map): avis de carte vidée par le filtre, avec « Effacer les filtres » (F8 de T3)" -m "Après la panne, qui parle seule ; exclusif des avis d'absence, qui restent décidés sur les faits lus : un filtre qui vide les observations ne fait pas dire que le réseau ONDE ne suit pas ce secteur. Les lignes illisibles gardent leur avis à côté." -- lib/features/map/view/map_empty_states.dart test/features/map/view/map_empty_states_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart test/diagnostics/fluidity_probe_panel_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md
```

### Task F9 : La feuille « Filtres »

**Agent :** **raisonnement** (opus, effort élevé) — le plus gros widget du lot, textes approuvés, deux plateformes.
**Files:** créés `lib/features/map/view/map_filter_sheet.dart`, `test/features/map/view/map_filter_sheet_test.dart` · modifiés `docs/acceptance/filtres.feature`, `test/project/acceptance_features_test.dart`, `docs/04-ui.md` (l. 534-573)
**Prérequis :** `F1`, `F2`, `N1` pour le widget et son test ; **`F8` pour les documents** (`filtres.feature` est créé par `F7`, complété par `F8`). Le widget et `map_filter_sheet_test.dart` peuvent s'écrire pendant le lot 3 ; les documents (`filtres.feature`, `acceptance_features_test.dart`, `04-ui.md`) s'écrivent et se committent **après `F8`**.

**Signatures**
- `class MapFilterSheet extends StatefulWidget { const MapFilterSheet({required this.scale, required this.initialFilter, required this.departements, required this.onApply, super.key}); final MapScaleKind scale; final MapFilter initialFilter; final List<AdministrativeArea>? departements; final void Function(MapFilter filter) onApply; }` — `departements` **nul** = liste illisible.
- Textes (cadrage § 10.1 (b), mot pour mot) : `mapFilterSheetTitle = 'Filtres'` · `mapFilterApplyLabel = 'Appliquer'` · `mapFilterClearLabel = 'Effacer'` · `mapFilterAllDepartementsLabel = 'Tous les départements'` · `mapFilterDepartementsUnreadableText = "La liste des départements n'a pas pu être lue."` · `mapFilterFreshnessLoadedOnlyText = "Ce critère ne porte que sur les mesures déjà chargées : une station dont la mesure n'est pas encore chargée reste affichée."` · `mapFilterFreshnessClustersText = "Il ne s'applique pas aux regroupements par région ou par département : leur compte n'en tient pas compte."` · `final String mapFilterFlowWindowText = "La carte ne montre que les campagnes d'observation des ${campagneAncienneApres.inDays} derniers jours. Un point observé plus tôt n'y figure pas.";` (`lib/domain/onde/campaign_age.dart:32`, 60 jours : lue, non recopiée).
- Titres de section, repris du croquis `04-ui.md` l. 545, 552, 555 : `'États'`, `'Département'`, `'Fraîcheur'`.
- Clés : `mapFilterSheetKey`, `mapFilterClearKey` (« Effacer »), `Key mapFilterCategoryKey(FlowCategory category)` (clé = `flowCategoryLabel`), `mapFilterDepartementKey`, `Key mapFilterFreshnessKey(DischargeFreshnessCriterion criterion)`, **`mapFilterCloseKey`** (« Fermer »), `mapFilterApplyKey` (« Appliquer »).
- **Ordre de tabulation, le seul, celui de la construction :** `mapFilterClearKey` → six `mapFilterCategoryKey` (écoulement) → `mapFilterDepartementKey` → trois `mapFilterFreshnessKey` (débit) → `mapFilterCloseKey` → `mapFilterApplyKey`.
- Libellé de fermeture : la constante **existante** `warningReviewCloseLabel` (`lib/domain/warnings/warning_texts.dart:110`, « Fermer ») — celle de la fenêtre d'avertissement ; aucune constante nouvelle.

**Construction** — précédents à **lire avant d'écrire** : `Dialog` › `SafeArea` › `SingleChildScrollView` (`lib/features/shared/warning_link.dart:162-203`) ; `RadioGroup<T>(groupValue:, onChanged:, child:)` et `RadioListTile<T>(key:, value:, title:)` (`lib/features/restrictions/view/restrictions_screen.dart:374-389`). Cases : `CheckboxListTile` ; département : `DropdownButton<String>` à valeur sentinelle `''` pour « Tous les départements » — **signatures lues dans le SDK installé**, non écrites de mémoire. Le **brouillon** est un `MapFilter` tenu par l'état de la feuille (`R14`), initialisé à `initialFilter` ; toute règle reste dans `MapFilter`.
- Écoulement, dans cet ordre : titre et « Effacer » (`mapFilterClearKey`) ; « États » : une case par élément de `filterableFlowCategories`, libellé `flowCategoryLabel` ; « Département » ; **à la place de la fraîcheur**, `mapFilterFlowWindowText` ; puis, sur la dernière ligne, « Fermer » (`mapFilterCloseKey`) puis « Appliquer » (`mapFilterApplyKey`).
- Débit, dans cet ordre : titre et « Effacer » (`mapFilterClearKey`) ; **aucune** section « États » ; « Département » ; « Fraîcheur » : trois choix, libellés `dischargeFreshnessCriterionLabel`, puis les deux phrases dans l'ordre (1), (2) ; puis « Fermer » (`mapFilterCloseKey`) puis « Appliquer » (`mapFilterApplyKey`).
- Option d'un département : `'${area.label} (${area.code})'`, libellé tel que reçu. `departements == null` : la phrase d'illisibilité, **aucun** sélecteur ; les autres critères restent.
- « Appliquer » : `onApply(brouillon)` puis `Navigator.maybePop`. « Effacer » est **immédiat** (arbitrage de la boucle principale du 2026-10-12) : `onApply(MapFilter.none)` puis `Navigator.maybePop` (tous les critères, des deux échelles). **« Fermer », bouton visible** (arbitrage de la boucle principale du 2026-10-12), sur le modèle exact de `_CloseAction` de la fenêtre d'avertissement (`warning_link.dart:193-198` pour l'emplacement, `:216-258` pour la forme — classe privée, donc **reconstruite à l'identique** dans ce fichier) : `Semantics(key: mapFilterCloseKey, button: true, label: warningReviewCloseLabel, excludeSemantics: true, onTap:)` › `KeyboardFocusRing(onActivate:)` › `Material(type: MaterialType.transparency)` › `InkWell(canRequestFocus: false)` › `ConstrainedBox(minWidth/minHeight: minimumTapTarget)` › `Center(Text(warningReviewCloseLabel))` ; son rappel est `Navigator.of(context).maybePop()`. Il ferme **sans appliquer**. Fermer par « Fermer », Échap, retour Android ou tap hors de la feuille : **aucun** appel à `onApply`.
- Aucun groupe « Échelle affichée », aucun compteur sur « Appliquer » (`R11`).

**Cas de test** (`testWidgetsOnWindows` sauf mention ; **tout cas dont la fenêtre fait moins de 600 px de large est en `testWidgetsOnAndroid`, titre « Android : … »** ; la feuille est ouverte par `showDialog` depuis un bouton de test)
- Écoulement, `MapFilter.none` : titre « Filtres » ; six cases dans l'ordre « Eau qui coule », « Écoulement faible », « Eau stagnante », « À sec », « Non observé », « Non renseigné », **toutes cochées** ; « Tous les départements » sélectionné ; `mapFilterFlowWindowText` présent une fois et **égal, au mot, au texte de § 10.1** — « La carte ne montre que les campagnes d'observation des 60 derniers jours. Un point observé plus tôt n'y figure pas. » : ici le « 60 » s'écrit en dur dans le test, c'est l'exception admise (un texte approuvé se compare au mot ; les libellés « Moins de 2 h » et « Moins de 24 h » de même) ; aucun `RadioListTile`, aucun texte « Fraîcheur », aucune des deux phrases du débit (critère 3).
- Aucune échelle n'est proposée : ni « Échelle affichée », ni `mapScaleLabel(MapScaleKind.ecoulement)`, ni `mapScaleLabel(MapScaleKind.debit)` dans la feuille, sur les deux échelles (critère 1).
- Débit, `none` : aucun `CheckboxListTile`, aucun texte « États » (critère 4) ; trois choix « Toutes », « Moins de 2 h », « Moins de 24 h », « Toutes » sélectionné ; les deux phrases présentes, (1) au-dessus de (2) (critères 7 et 10) ; `mapFilterFlowWindowText` absent.
- `initialFilter` reflété : `assec: false` → case « À sec » décochée ; département `'41'` avec `departements: const <AdministrativeArea>[AdministrativeArea(code: '41', label: 'LOIR-ET-CHER')]` → option affichée « LOIR-ET-CHER (41) » ; `moinsDe2h` → ce choix sélectionné.
- Décocher « À sec », « Appliquer » → `onApply` appelé **une** fois avec `MapFilter.none.withCategory(const Assec(), shown: false)`, feuille fermée. Décocher « Non renseigné » → `inconnu: false`. Choisir « LOIR-ET-CHER (41) » → `departementCode == '41'` ; revenir à « Tous les départements » → `null`. Choisir « Moins de 24 h » → `moinsDe24h`.
- Les critères de l'autre échelle survivent : `initialFilter` = `assec: false` + `moinsDe2h`, feuille du **débit**, choisir un département, « Appliquer » → le filtre rendu a toujours `assec == false`.
- Fermer sans appliquer, **quatre façons**, un cas chacune, après avoir décoché une case : tap sur « Fermer » (`mapFilterCloseKey`) ; touche Échap ; tap hors de la feuille ; `testWidgetsOnAndroid` : `tester.binding.handlePopRoute()` — dans les quatre, la feuille n'est plus dans l'arbre et `onApply` n'est **jamais** appelé (critère 14).
- « Fermer » : nœud `mapFilterCloseKey` de libellé sémantique exactement `warningReviewCloseLabel`, `button: true` ; Entrée puis Espace, bouton focalisé, ferment de même sans appeler `onApply` ; **un** seul arrêt de tabulation.
- « Effacer », depuis `assec: false` + département `'41'` + `moinsDe2h` : `onApply(MapFilter.none)` **une** fois, feuille fermée (critère 13).
- `departements: null` : la phrase d'illisibilité présente, aucun `DropdownButton`, « Tous les départements » absent ; décocher une case et appliquer fonctionne, `departementCode` rendu = celui d'`initialFilter`.
- `departements: []` : le sélecteur n'offre que « Tous les départements ». Code d'`initialFilter` absent de la liste (`'99'`) : aucune exception, une option de secours au libellé `'99'` est sélectionnée.
- Aucun texte de la feuille, sur les deux échelles, ne contient un mot de `forbiddenFlowWords` (`test/project/vocabulary_lists.dart:31`), en mot entier (critère 15).
- Chaque case, chaque choix, le sélecteur, « Appliquer », « Effacer » et « Fermer » : hauteur ≥ 44 sur Windows, ≥ 48 sur Android (`testWidgetsOnAndroid`).
- Clavier, écoulement — Tab parcourt exactement : `mapFilterClearKey` → six `mapFilterCategoryKey` → `mapFilterDepartementKey` → `mapFilterCloseKey` → `mapFilterApplyKey` ; débit : `mapFilterClearKey` → `mapFilterDepartementKey` → trois `mapFilterFreshnessKey` → `mapFilterCloseKey` → `mapFilterApplyKey`. Espace bascule une case ; Entrée sur « Appliquer » appelle `onApply`.
- Sémantique : chaque case annonce coché ou non ; les trois choix forment un groupe exclusif ; « Appliquer », « Effacer » et « Fermer » sont des boutons.
- `testWidgetsOnAndroid`, titre « Android : … », 360 × 640, texte à 200 % : aucune exception de débordement (`tester.takeException()` nul), « Appliquer » atteint par défilement, les six libellés entiers.

**Documents** — `filtres.feature`, sous `US-13` :

```gherkin
  Scénario: Le type de donnée se choisit par les puces d'échelle, pas dans la feuille
    Étant donné la carte et ses puces d'échelle
    Quand la feuille « Filtres » s'ouvre
    Alors elle ne propose aucune échelle : l'échelle active reste celle des puces (BR-008)

  Scénario: Sur l'écoulement, la feuille ne propose pas de fraîcheur et dit la borne des 60 jours
    Étant donné l'échelle « Écoulement »
    Quand la feuille « Filtres » s'ouvre
    Alors elle écrit « La carte ne montre que les campagnes d'observation des 60 derniers jours. Un point observé plus tôt n'y figure pas. » à la place du critère de fraîcheur (BR-010)

  Scénario: Sur le débit, la feuille ne propose aucun critère d'état
    Étant donné l'échelle « Débit relatif à l'historique »
    Quand la feuille « Filtres » s'ouvre
    Alors elle propose le département et la fraîcheur, et aucune case d'état : un débit ne se qualifie pas (BR-003)

  Scénario: La feuille dit ce que le critère de fraîcheur ne masque pas
    Étant donné l'échelle « Débit relatif à l'historique »
    Quand la feuille « Filtres » s'ouvre
    Alors elle écrit « Ce critère ne porte que sur les mesures déjà chargées : une station dont la mesure n'est pas encore chargée reste affichée. » puis « Il ne s'applique pas aux regroupements par région ou par département : leur compte n'en tient pas compte. » (BR-007, BR-009)

  Scénario: Fermer la feuille sans appliquer ne change rien à la carte
    Étant donné la feuille « Filtres » ouverte et une case décochée dans le brouillon
    Quand l'usager ferme la feuille sans activer « Appliquer » — par « Fermer », par la touche Échap, par le retour du téléphone ou en touchant hors de la feuille
    Alors la carte montre les mêmes lieux qu'avant, et aucun lieu n'est masqué (BR-007)

  Scénario: Aucun texte de la feuille ne qualifie un débit
    Étant donné la feuille « Filtres » sur l'échelle « Débit relatif à l'historique »
    Quand l'usager lit ses critères et ses phrases
    Alors la fraîcheur y est dite en heures — « Toutes », « Moins de 2 h », « Moins de 24 h » — et aucun mot ne juge le débit (BR-003)
```
`acceptance_features_test.dart` : `mapFilterSheetTitle`, `mapFilterApplyLabel`, `warningReviewCloseLabel`, `mapFilterFlowWindowText`, `mapFilterFreshnessLoadedOnlyText`, `mapFilterFreshnessClustersText`, et les trois `dischargeFreshnessCriterionLabel`, entre guillemets français ; `BR-003` et `BR-010` citées par un scénario. `docs/04-ui.md` l. 534-573 : la colonne « Filtres » du croquis est **remplacée** par deux croquis (écoulement ; débit) conformes à la construction ci-dessus — six cases toutes cochées, « Fermer » à côté d'« Appliquer », « Appliquer » sans compteur, pas de groupe « Échelle affichée », pas de « Moins de 7 jours » (`R11`) —, datés « Corrigé le 2026-10-12, T3 » ; la colonne « Avertissement initial » n'est pas touchée.

- [ ] **Étape 1** — tests rouges recopiés ; **Étape 2** — implémenter le widget ; **Étape 3** — **après `F8`** : scénarios, verrou d'acceptation, croquis ; **Étape 4** — critère de fin (`layers_test.dart` et `vocabulary_test.dart` verts), **un** commit, widget et documents ensemble.

```bash
git add -- lib/features/map/view/map_filter_sheet.dart test/features/map/view/map_filter_sheet_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md && git commit -m "feat(map): la feuille « Filtres » (F9 de T3)" -m "États sur l'écoulement seulement, département sur les deux échelles, fraîcheur sur le débit seulement, aux seuils de BR-005 ; sur l'écoulement la feuille dit la borne des 60 jours. Elle dit ce que le critère de fraîcheur ne masque pas : les mesures non chargées et les regroupements. Brouillon tenu par l'état de la feuille ; fermer sans appliquer ne change rien. Aucun critère d'état sur le débit, aucun compteur." -- lib/features/map/view/map_filter_sheet.dart test/features/map/view/map_filter_sheet_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md
```

### Task F10a : Le bouton rond partagé et le groupe `MapEntryButtons`

**Agent :** mécanique (sonnet, effort moyen) — une extraction à comportement verrouillé, un widget de contenu.
**Files:** créés `lib/features/map/view/map_round_button.dart`, `lib/features/map/view/map_entry_buttons.dart`, `test/features/map/view/map_entry_buttons_test.dart` · modifié `lib/features/map/view/map_controls.dart`
**Prérequis :** lot 1 (`N1`). Aucun autre : la tâche peut s'écrire pendant le lot 3.

**Signatures**
- `map_round_button.dart` — `_MapControlButton` (`lib/features/map/view/map_controls.dart:107-191`) **extrait tel quel**, rendu public : `class MapRoundButton extends StatelessWidget { const MapRoundButton({required this.semanticsKey, required this.icon, required this.label, required this.onTap, this.filled = false, super.key}); final Key semanticsKey; final IconData icon; final String label; final VoidCallback? onTap; final bool filled; }`. `filled: true` : fond noir, icône blanche. `MapControls` (`map_controls.dart:50-101`) l'emploie à la place de sa classe privée, supprimée.
- `map_entry_buttons.dart` — `const Key mapFiltersButtonKey = Key('map-filters');` · `const Key mapFiltersActiveMarkKey = Key('map-filters-active-mark');` · `const String mapFiltersLabel = 'Filtres';` · `const String mapFiltersActiveLabel = 'Filtres — un filtre est actif';` (textes du cadrage § 10.1 (b), mot pour mot) · `class MapEntryButtons extends StatelessWidget { const MapEntryButtons({required this.onOpenFilters, required this.filterActive, super.key}); final VoidCallback onOpenFilters; final bool filterActive; }` — une `Column` (`mainAxisSize: min`, `crossAxisAlignment: end`), espacement `mapControlsSpacing` (`map_controls.dart:35`). Elle ne porte ici **que** « Filtres ». **Ordre arbitré** (boucle principale, 2026-10-12), de haut en bas **et** pour la tabulation : « Favoris » (ajouté au lot 7) puis « Filtres ».
- Forme du bouton « Filtres » — inactif : `MapRoundButton(semanticsKey: mapFiltersButtonKey, icon: Icons.filter_list, label: mapFiltersLabel, onTap: onOpenFilters)` ; **actif** : `icon: Icons.filter_alt`, `filled: true`, `label: mapFiltersActiveLabel`, **plus** une marque — un disque de 12 px, noir à liseré blanc de 2 px, au coin haut droit (`mapFiltersActiveMarkKey`), inerte au pointeur et exclue de la sémantique. Trois différences de forme, aucune ne tient à la seule teinte (`04-ui.md § 3`) — forme retenue par la boucle principale le 2026-10-12 ; le constat (c) de la porte en jugera. Les deux icônes existent dans le SDK installé (`material/icons.dart`, relevé le 2026-10-12).

**Invariants :** widgets de contenu purs — ni `MapViewModel`, ni caméra ; `test/features/map/view/map_controls_test.dart` reste **inchangé et vert** (filet de l'extraction) ; aucun fichier n'importe une autre tranche (`layers_test.dart`).

**Cas de test** (`map_entry_buttons_test.dart` ; aucune fenêtre de moins de 600 px de large dans cette tâche)
- `MapRoundButton`, `filled: true` (`testWidgetsOnWindows`) : `BoxDecoration.color == Colors.black` et icône blanche ; `filled` omis : fond blanc, icône noire ; `onTap: null` : `Semantics.enabled` faux, hors de la tabulation.
- `MapEntryButtons`, `filterActive: false` (`testWidgetsOnWindows`) : nœud `mapFiltersButtonKey` de libellé « Filtres », `button: true` ; `find.byIcon(Icons.filter_list)` un, `Icons.filter_alt` zéro ; aucune marque.
- `filterActive: true` : libellé sémantique exactement « Filtres — un filtre est actif » ; `Icons.filter_alt` un, `Icons.filter_list` zéro ; marque présente ; fond noir.
- Tap → `onOpenFilters` une fois ; Entrée, puis Espace, bouton focalisé → une fois chacune.
- Taille du bouton : `minimumTapTargetFor(TargetPlatform.windows)` de côté (`testWidgetsOnWindows`), `minimumTapTargetFor(TargetPlatform.android)` de côté (`testWidgetsOnAndroid`, titre « Android : … ») ; un tap sur la marque atteint le bouton.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/map/view/map_entry_buttons_test.dart` → échec recopié ; **Étape 2** — extraire, écrire ; **Étape 3** — critère de fin (`map_controls_test.dart` non modifié), commit.

```bash
git add -- lib/features/map/view/map_round_button.dart lib/features/map/view/map_entry_buttons.dart test/features/map/view/map_entry_buttons_test.dart lib/features/map/view/map_controls.dart && git commit -m "feat(map): bouton rond partagé et groupe MapEntryButtons, bouton « Filtres » (F10a de T3)" -m "Le bouton rond de MapControls est extrait pour être partagé, sans changement de comportement. Le bouton « Filtres » change de forme — icône, fond, marque — quand un filtre est actif, et l'annonce. Le groupe attend « Favoris », au-dessus, au lot 7." -- lib/features/map/view/map_round_button.dart lib/features/map/view/map_entry_buttons.dart test/features/map/view/map_entry_buttons_test.dart lib/features/map/view/map_controls.dart
```

### Task F10b : Brancher le groupe et la feuille sur la carte

**Agent :** **raisonnement** (opus, effort élevé) — disposition verrouillée à 800 × 740, ordre de tabulation, branchement dans `map_view.dart`.
**Files:** créé `test/features/map/view/map_filter_wiring_test.dart` · modifiés `lib/features/map/view/map_view.dart`, `test/features/map/view/map_view_test.dart` (groupe « 800 × 740 », l. 1202-1662, et appels de `buildMapOverlays`), `test/features/map/view/map_overlays_phone_test.dart`, `test/features/map/view/map_keyboard_test.dart`, `test/diagnostics/fluidity_probe_panel_test.dart`, `docs/acceptance/filtres.feature`, `test/project/acceptance_features_test.dart`, `docs/04-ui.md`
**Prérequis :** `F6`, `F8`, `F9` (widget **et** documents), `F10a`.

**Ce que la tâche consomme, déjà écrit** — `MapEntryButtons({required VoidCallback onOpenFilters, required bool filterActive})`, clés `mapFiltersButtonKey` et `mapFiltersActiveMarkKey`, libellés `mapFiltersLabel` (« Filtres ») et `mapFiltersActiveLabel` (« Filtres — un filtre est actif ») (`lib/features/map/view/map_entry_buttons.dart`) ; `MapFilterSheet({required MapScaleKind scale, required MapFilter initialFilter, required List<AdministrativeArea>? departements, required void Function(MapFilter) onApply})` et ses clés (`lib/features/map/view/map_filter_sheet.dart`) ; sur `MapViewModel` : `filter`, `filterActive`, `applyFilter`, `departements()`.

**Signatures**
- `buildMapOverlays` (`lib/features/map/view/map_view.dart:830`) gagne **`required bool filterActive`** et **`required VoidCallback onOpenFilters`** ; dans la colonne du bas à droite (l. 1099-1113), **au-dessus** de `MapControls` : `FocusTraversalOrder(order: NumericFocusOrder(mapTraversalOrderEntryButtons), child: MapEntryButtons(…))`, puis `SizedBox(height: mapControlsSpacing)`. Nouvelle constante `const double mapTraversalOrderEntryButtons = 1.5;` (entre les puces, 1, et les contrôles, 2 — `map_view.dart:259-262`) : **une** valeur pour tout le groupe ; à l'intérieur, Tab suit l'ordre de la colonne, « Favoris » (lot 7) puis « Filtres ».
- `_MapViewState` : un gestionnaire `void _handleOpenFilters()` qui attend `widget.viewModel.departements()`, vérifie `mounted`, puis `showDialog<void>` de `MapFilterSheet(scale: widget.viewModel.scale, initialFilter: widget.viewModel.filter, departements: …, onApply: widget.viewModel.applyFilter)`. `_MapViewState.build` (`map_view.dart:1834`) passe, dans l'appel `...buildMapOverlays(` de la l. 2014, `filterActive: widget.viewModel.filterActive, onOpenFilters: _handleOpenFilters`. **Rien d'autre** n'entre dans `map_view.dart` ; `MapView` ne gagne aucun paramètre, `lib/main.dart` n'est pas touché.

**Cas de test** (`testWidgetsOnWindows` sauf mention ; **tout cas dont la fenêtre fait moins de 600 px de large est en `testWidgetsOnAndroid`, titre « Android : … »**)
- Disposition (`buildMapOverlays`, 800 × 740) : `bottom` de « Filtres » + `mapControlsSpacing` == `top` de `+` (`mapZoomInButtonKey`) ; bords droits alignés ; l'attribution reste sous `MapControls`.
- **Le haut de la carte ne bouge pas** : rectangles de `WarningLink`, de `MapScaleChips` et de `MapLegend` à 800 × 740, **relevés avant le changement (étape 0)**, identiques après, sur les deux échelles.
- Groupe « 800 × 740 » de `map_view_test.dart` (l. 1202-1662) : `MapEntryButtons` s'ajoute aux pièces mesurées — sur les deux échelles, avec et sans fiche, avec et sans bouton de désignation, son rectangle est dans l'écran et ne recoupe ni la légende, ni la fiche, ni `DesignateCenterControl`, ni `IgnAttributionBadge`. Même vérification dans `map_overlays_phone_test.dart` à 360 × 640 (`testWidgetsOnAndroid`, « Android : … », 100 % puis 200 %). **Un recouvrement mesuré est un constat : recopier les rectangles, s'arrêter, poser la question — ne rien réagencer en silence** (constat f du cadrage § 9).
- Tabulation (`map_keyboard_test.dart`, test de l'ordre déclaré) : puces d'échelle → « Filtres » → `+` → `−` → recentrer → (désignation) → carte → fiche → « ⚠ Avertissement ».
- `MapView` montée (`map_filter_wiring_test.dart`), ONDE = une observation `Ecoulement` et une `Assec`, zoom individuel : tap sur « Filtres » → la feuille (`mapFilterSheetTitle`) ; décocher « À sec », « Appliquer » → **un** marqueur ONDE dessiné au lieu de deux, le bouton passe à la forme active.
- Critère 11 : filtre `assec: false` appliqué ; forme active sur l'écoulement aux zooms 5, 8 et 10 ; tap sur la puce du débit → forme **inactive** (le critère ne joue pas sur le débit) ; retour à l'écoulement → active.
- Ouvrir la feuille, décocher une case, Échap : `viewModel.filter == MapFilter.none`, deux marqueurs, forme inactive ; le focus revient sur « Filtres ». Même constat en fermant par « Fermer » (`mapFilterCloseKey`).
- Critère 14 : `stationSheet` et `ondeSheet` fournis (widgets à clé de test) ; appliquer un filtre qui masque tous les lieux → les deux widgets sont **toujours** dans l'arbre.
- Feuille ouverte sur le débit : elle porte « Fraîcheur » et aucune case ; sur l'écoulement : six cases.
- Référentiel illisible (`all()` lève) : tap sur « Filtres » → la feuille s'ouvre avec `mapFilterDepartementsUnreadableText` ; **aucun** `SourceUnavailableNotice` sur la carte.
- `MapView` retirée de l'arbre pendant que `departements()` est en attente : aucune exception, aucune feuille.
- Les appels de `buildMapOverlays` dans `test/` reçoivent `filterActive: false, onOpenFilters: () {}` — vérifier par `grep -rn "buildMapOverlays(" lib test`.

**Documents** — `filtres.feature`, sous `US-13` :

```gherkin
  Scénario: Le bouton « Filtres » montre qu'un critère est actif, à tous les zooms
    Étant donné un filtre dont un critère est actif pour l'échelle affichée
    Quand la carte s'affiche, au niveau des marqueurs comme à celui des pastilles de région
    Alors le bouton « Filtres » a changé de forme et s'annonce « Filtres — un filtre est actif » (BR-007)

  Scénario: Une fiche ouverte reste ouverte quand le filtre masque son lieu
    Étant donné la fiche d'un lieu ouverte sur la carte
    Quand un filtre appliqué masque ce lieu
    Alors la fiche reste ouverte : un lieu masqué n'est pas une absence de donnée (BR-007)
```
`acceptance_features_test.dart` : `mapFiltersLabel` et `mapFiltersActiveLabel` entre guillemets français. `docs/04-ui.md` : sous le croquis de la carte (§ 1), un croquis de la colonne du bas à droite — « Filtres », puis `+`, `−`, recentrer, puis l'attribution —, les deux formes du bouton, daté « Ajout du 2026-10-12, T3, arbitrage 8 » ; il dit que « Favoris » s'y ajoute au lot 7, **au-dessus** de « Filtres ».

- [ ] **Étape 0** — relever et noter les trois rectangles du haut de la carte à 800 × 740, avant tout changement.
- [ ] **Étape 1** — tests rouges recopiés ; **Étape 2** — brancher.
- [ ] **Étape 3 — contre-épreuve** : passer provisoirement `filterActive: false` en dur dans `_MapViewState.build` → le cas du critère 11 rougit ; rétablir → vert. Recopier le rouge.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- test/features/map/view/map_filter_wiring_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart test/features/map/view/map_keyboard_test.dart test/diagnostics/fluidity_probe_panel_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md && git commit -m "feat(map): bouton « Filtres » en bas à droite, feuille branchée sur MapViewModel (F10b de T3)" -m "Un groupe à part au-dessus de + / − / recentrer (arbitrage 8), le haut de la carte ne bouge pas. Le bouton montre le filtre actif pour l'échelle affichée, à tous les zooms. La feuille s'ouvre sur le filtre appliqué et la liste des départements du référentiel ; fermer sans appliquer ne change rien. Contre-épreuve : <recopier le rouge>." -- test/features/map/view/map_filter_wiring_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart test/features/map/view/map_keyboard_test.dart test/diagnostics/fluidity_probe_panel_test.dart docs/acceptance/filtres.feature test/project/acceptance_features_test.dart docs/04-ui.md
```

### Task F10c : Mesure anticipée de la place du cinquième bouton

**Agent :** mécanique (sonnet, effort moyen) — une mesure, aucun code d'application.
**Files:** modifiés `test/features/map/view/map_view_test.dart`, `test/features/map/view/map_overlays_phone_test.dart` — **aucun fichier de `lib/`**
**Prérequis :** `F10b`. **Cette tâche ne bloque pas `C1`.**

> « Favoris » n'arrive qu'au lot 7, mais son emplacement est arbitré : au-dessus de « Filtres », dans `MapEntryButtons` (`lib/features/map/view/map_entry_buttons.dart`). Il faut savoir **dès le lot 4** s'il tient. Calcul fait à l'écriture du plan, **non mesuré** : à 800 × 740 sur l'échelle débit, le cinquième bouton couperait la légende d'une quarantaine de pixels.

**Mesure** — un groupe de cas à part, dans chacun des deux fichiers. Monter `buildMapOverlays` (signature : `map_view.dart:830`, avec `filterActive: false, onOpenFilters: () {}`), prendre le rectangle de `find.byType(MapEntryButtons)` et l'**étendre vers le haut** de `minimumTapTarget + mapControlsSpacing` (`lib/features/shared/tap_target.dart:33`, `lib/features/map/view/map_controls.dart:35` — **lus, jamais recopiés en nombres**). Ce rectangle étendu doit rester dans l'écran et ne couper ni `MapLegend`, ni `DesignateCenterControl` (mode de désignation allumé : `onDesignateCenter` et `onToggleDesignationMode` fournis), ni `IgnAttributionBadge`, ni un panneau de fiche (hauteur réaliste de 320, comme le groupe « 800 × 740 » de `map_view_test.dart`, l. 1202-1662).

**Cas de test**
- **800 × 740**, échelle écoulement puis échelle débit, sans fiche puis avec fiche (`testWidgetsOnWindows`, dans `map_view_test.dart`) : aucun recoupement. **Taille d'arrêt.**
- **360 × 640**, les deux échelles, sans puis avec fiche (`testWidgetsOnAndroid`, titre « Android : … », dans `map_overlays_phone_test.dart`) : aucun recoupement. **Taille d'arrêt.**
- **640 × 360**, les deux échelles (`testWidgetsOnAndroid`, titre « Android : … », `map_overlays_phone_test.dart`) : **mesurer et recopier** les rectangles dans le rapport et dans le message de commit. Un recoupement y est un **constat** remonté au commanditaire : il **ne bloque pas** la tâche ; le cas l'écrit en caractérisation (il affirme ce qui est mesuré, sous un titre qui commence par « CONSTAT — »), jamais en `skip`.

⚠️ **Consigne d'arrêt — à 800 × 740 (Windows) et à 360 × 640 (Android), les deux tailles du constat f : si un cas rougit, l'agent s'arrête. Il ne corrige rien, ne déplace rien, ne relâche aucune attente et ne marque aucun cas `skip` : il rend, pour chaque cas rouge, les rectangles mesurés (groupe étendu, pièce coupée, taille d'écran, échelle, plateforme), ne committe pas, et la tâche reste ouverte.** La question va au commanditaire **avant le lot 7**.

- [ ] **Étape 1** — écrire les cas, `flutter test test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart`, recopier la sortie et les rectangles.
- [ ] **Étape 2** — rouge à une taille d'arrêt : **arrêt** (consigne ci-dessus). Sinon : critère de fin, commit.

```bash
git add -- test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart && git commit -m "test(map): la place du cinquième bouton du bas à droite est mesurée avant le lot 7 (F10c de T3)" -m "Rectangle du groupe étendu d'un bouton et d'un espacement vers le haut : il ne coupe ni la légende, ni le bouton de désignation, ni l'attribution, ni une fiche, à 800 × 740 (Windows) et à 360 × 640 (Android). À 640 × 360 : <recopier les rectangles mesurés et le constat>." -- test/features/map/view/map_view_test.dart test/features/map/view/map_overlays_phone_test.dart
```

### Task C1 : Constat d'écran anticipé, a et b, sur l'écoulement (commanditaire)

**Agent :** aucun pour l'épreuve ; consignation **mécanique** (sonnet, effort léger).
**Files:** modifiés `docs/project-state.md`, `CLAUDE.md` (ligne T3 ; arborescence : `lib/domain/filters/`, les fichiers nouveaux de `features/map/view/`)
**Prérequis :** `F10b` (`F10c` ne bloque pas ce constat).

> **Pourquoi maintenant** (cadrage § 9) : la carte d'écoulement ne montre que 60 jours et les campagnes ONDE s'arrêtent en septembre. **Passé fin novembre, plus aucun point ONDE à l'écran**, donc plus de constat possible du filtre « États » ni des pastilles filtrées avant mai. 💭 La date de la dernière campagne de 2026 n'est pas vérifiée par appel réel. Ce constat ne remplace pas la porte : c, d, e, f s'y feront, sur les deux cibles.

- [ ] **Étape 1 — Claude** : critère de fin sur le sommet de la branche, total de tests recopié.
- [ ] **Étape 2 — commanditaire** :

```bash
flutter run -d windows
```
Attendu, **à constater et à recopier tel que vu** :
- **(a)** Échelle « Écoulement », zoomer jusqu'aux marqueurs individuels (zoom 9 ou plus) sur un secteur montrant **au moins deux catégories** (noter le secteur et les catégories vues). Bouton « Filtres », en bas à droite, au-dessus de `+` : la feuille s'ouvre, six cases cochées. Décocher l'une des catégories présentes, « Appliquer » : **ses marqueurs disparaissent, les autres restent**, et le bouton « Filtres » a changé de forme.
- **(b)** Sans effacer le filtre, dézoomer sous le zoom 9 (pastilles de département), puis sous le zoom 7 (pastilles de région). Pour **une pastille nommée**, noter son compte et son symbole **avec** le filtre, rouvrir la feuille, « Effacer », noter son compte et son symbole **sans** filtre : le compte avec filtre est **inférieur ou égal**, et le symbole est celui de l'état le plus sévère parmi les catégories encore cochées. Puis ne cocher qu'**une** catégorie rare : **au moins une pastille disparaît**.
- Si aucun point ONDE ne s'affiche (campagnes de plus de 60 jours) : l'écrire tel quel. Le constat est alors **impossible avant mai** et reste dû, dit tel.
- [ ] **Étape 3** — en cas d'écart : recopier ce qui est vu, **aucun correctif dans cette tâche** ; trois échecs sur le même point → arrêt et question.
- [ ] **Étape 4** — consigner dans `docs/project-state.md` (date, cible Windows, débogage, sommet de la branche, secteur, comptes relevés, ce qui n'a pas été vu) ; ligne T3 et arborescence de `CLAUDE.md` ; commit.

```bash
git add -- docs/project-state.md CLAUDE.md && git commit -m "docs: constat d'écran anticipé des filtres sur l'écoulement (C1 de T3)" -m "<recopier : date, secteur, catégories vues, constat a, comptes et symboles d'une pastille avec et sans filtre, pastille disparue, ou ce qui n'a pas pu être vu>. Windows, débogage. Les constats c à f restent dus à la porte, sur les deux cibles." -- docs/project-state.md CLAUDE.md
```

---

## Lot 5 — Favoris : domaine, forme stockée, dépôt

> Cadrage § 5.1 et § 5.2, décisions R1 à R6. `docs/domain-model.md` et `typesDuDomaine` (`test/project/domain_model_doc_test.dart`) s'allongent **dans le commit qui écrit chaque type**. ⚠️ `docs/domain-model.md` ne doit jamais contenir la chaîne `PointOnde` (liste `typesHorsPerimetre` du même test) : écrire « point ONDE » ou `OndePoint`.
> Valeurs de test de ce lot, reprises des tests existants (ce ne sont pas des fixtures d'API) : station `K447001001` « La Loire à Blois » ; point ONDE `K4640001` « LA BONNEURE A MILLANCAY », latitude `47.444182169`, longitude `1.78116675`, cours d'eau « la Bonne Heure », département `AdministrativeArea(code: '41', label: '41')`, région absente ; code ONDE à espaces `' O968 5312 '` (forme relevée dans `lib/domain/onde/onde_station_code.dart:5`).

### Task S1 : Le favori, type clos, et le contrat du dépôt

**Agent :** mécanique.
**Files:** créés `lib/domain/favorites/favorite.dart`, `lib/domain/favorites/favorite_repository.dart`, `test/domain/favorites/favorite_test.dart`, `test/domain/favorites/favorite_repository_test.dart`, `test/support/in_memory_favorite_repository.dart` · modifiés `lib/domain/formatting/display_date.dart`, `test/domain/formatting/display_date_test.dart`, `docs/domain-model.md`, `test/project/domain_model_doc_test.dart`, `docs/glossary.md`

**Signatures** — `favorite.dart` (imports : `domain/onde/onde_point.dart`, `domain/onde/onde_station_code.dart`, `domain/station/station.dart`, rien d'autre) :
- `sealed class Favorite { const Favorite(); }`
- `final class StationFavorite extends Favorite { StationFavorite({required StationCode code, required String label, required DateTime addedAt}); final StationCode code; final String label; final DateTime addedAt; }` — **sans coordonnées** (arbitrage 6).
- `final class OndePointFavorite extends Favorite { OndePointFavorite({required OndePoint point, required DateTime addedAt}); final OndePoint point; final DateTime addedAt; }` — le point **entier** : `OndeSheetViewModel.open(OndePoint point)` l'exige (`onde_sheet_view_model.dart:204`).
- `final class UnreadableFavorite extends Favorite { const UnreadableFavorite({required String raw, String? label}); final String raw; final String? label; }`
- `bool sameFavoritePlace(Favorite a, Favorite b)` — `switch` exhaustif sur le couple, sans `default` : deux `StationFavorite` de même `code` ; deux `OndePointFavorite` de même `point.code` ; deux `UnreadableFavorite` de même `raw` ; **tout couple de types différents → `false`**.
- `StationFavorite? stationFavoriteIn(Iterable<Favorite> favorites, StationCode code)` · `OndePointFavorite? ondePointFavoriteIn(Iterable<Favorite> favorites, OndeStationCode code)`

`favorite_repository.dart` :
- `abstract interface class FavoriteRepository { Future<List<Favorite>> readAll(); Future<void> add(Favorite favorite); Future<void> remove(Favorite favorite); Future<void> clear(); }`
- `sealed class FavoriteStorageFailure implements Exception { const FavoriteStorageFailure(this.diagnostic); final String diagnostic; }` · `final class ListeDeFavorisIllisible extends FavoriteStorageFailure` · `final class EcritureDeFavorisEnEchec extends FavoriteStorageFailure` (constructeurs `const X(super.diagnostic)`).

`display_date.dart` : `String formatLocalDate(DateTime instant, {UtcOffsetOf offsetOf = systemUtcOffsetOf})` → `'JJ/MM/AAAA'` en heure locale, même calcul que `formatLocalDateTime` (l. 51-59), sans l'heure.

`test/support/in_memory_favorite_repository.dart` : `final class InMemoryFavoriteRepository implements FavoriteRepository { InMemoryFavoriteRepository([List<Favorite> initial = const <Favorite>[]]); Object? readError; Object? writeError; Completer<void>? writeGate; int readCalls = 0; int writeCalls = 0; List<Favorite> get stored; }` — `readAll`, `add`, `remove` lèvent `readError` s'il est posé ; `add`, `remove`, `clear` attendent `writeGate?.future`, puis lèvent `writeError` s'il est posé, sinon écrivent ; `clear` **ne lève jamais** `readError`.

**Invariants (documentés sur l'interface, mot pour mot dans les `///`)**
- `readAll` : liste **non modifiable**, dans l'ordre d'affichage, **dernier ajouté en tête** (R6) ; rien de stocké → liste vide ; valeur illisible → lève `ListeDeFavorisIllisible`, **jamais une liste vide**.
- `add` : insère **en tête** ; un favori de même lieu (`sameFavoritePlace`) déjà présent → **aucun changement, aucune erreur** (la date d'origine reste) ; `add(UnreadableFavorite)` → `ArgumentError`. Valeur illisible → `ListeDeFavorisIllisible` ; écriture refusée → `EcritureDeFavorisEnEchec`.
- `remove` : retire **toute** entrée de même lieu ; absente → aucun changement, aucune erreur ; mêmes échecs.
- `clear` : remplace ce qui est stocké par une liste vide **sans le lire** ; seul échec possible : `EcritureDeFavorisEnEchec`.
- L'échec est **levé, jamais rendu**. `addedAt` est **en UTC** : un `DateTime` local → `ArgumentError`. `StationFavorite.label` blanc → `ArgumentError`. Égalité **structurelle** des trois branches (pour `OndePointFavorite` : les sept champs du point comparés un à un dans `favorite.dart` — `OndePoint` n'a pas d'`==` et **n'en reçoit pas**).

**Cas de test**
- `StationFavorite(code: StationCode('K447001001'), label: 'La Loire à Blois', addedAt: DateTime.utc(2026, 10, 11, 17, 5))` construit ; `addedAt: DateTime(2026, 10, 11)` → `ArgumentError` ; `label: '  '` → `ArgumentError` ; idem `addedAt` local sur `OndePointFavorite`.
- **Même code, deux lieux** : `sameFavoritePlace(StationFavorite(code K447001001…), OndePointFavorite(point de code 'K447001001'…))` → `false` ; `stationFavoriteIn` sur une liste qui ne contient que ce point ONDE → `null`.
- `sameFavoritePlace` : deux stations de même code, libellés et dates différents → `true` ; deux points ONDE `'A721 3011'` et `'A7213011'` → `false` (l'espace est significatif) ; deux `UnreadableFavorite` de `raw` égaux → `true`, de `raw` différents et de même `label` → `false` ; `UnreadableFavorite` contre une station → `false`.
- Une fonction de test à `switch` **sans `default`** sur `Favorite`, puis sur `FavoriteStorageFailure`, compile (`BR-011`).
- Égalité : deux `OndePointFavorite` construits séparément sur les mêmes valeurs sont égaux, `hashCode` compris ; un seul champ du point changé (région `null` contre `AdministrativeArea(code: '24', label: 'Centre-Val de Loire')`) → inégaux.
- Contrat, sur `InMemoryFavoriteRepository` : `add` de A puis B → `readAll` rend `[B, A]` ; `add` de A une seconde fois, avec une autre date → `[B, A]`, date d'origine gardée ; `remove(A)` → `[B]` ; `remove(A)` de nouveau → `[B]`, sans erreur ; `clear` → `[]` ; `readAll().add(…)` → `UnsupportedError` ; `add(const UnreadableFavorite(raw: '{}'))` → `ArgumentError` ; `readError = const ListeDeFavorisIllisible('x')` → `readAll`, `add`, `remove` lèvent, `clear` aboutit.
- `formatLocalDate(DateTime.utc(2026, 10, 12, 22, 30), offsetOf: (_) => const Duration(hours: 2))` → `'13/10/2026'` ; décalage nul → `'12/10/2026'` ; `DateTime.utc(2026, 1, 5)` → `'05/01/2026'`.
- `test/architecture/domain_isolation_test.dart` vert.

- [ ] **Étape 1** — tests rouges ; `flutter test test/domain/favorites test/domain/formatting` → échec, **sortie rouge recopiée dans le rapport**.
- [ ] **Étape 2** — implémenter ; `docs/domain-model.md` : section « Contexte Favoris — une identité copiée à l'ajout (T3, S1) » avec un `classDiagram` des trois branches et du contrat ; `typesDuDomaine` + `'Favorite'`, `'StationFavorite'`, `'OndePointFavorite'`, `'UnreadableFavorite'`, `'FavoriteRepository'`, `'FavoriteStorageFailure'`, `'ListeDeFavorisIllisible'`, `'EcritureDeFavorisEnEchec'` ; `docs/glossary.md` : ligne « **Favori** | `Favorite` (T3) | Un lieu que l'usager choisit de retrouver — une station hydrométrique ou un point ONDE. L'application en garde l'identité (nom, code, date d'ajout), jamais une mesure. ».
- [ ] **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/favorites/favorite.dart lib/domain/favorites/favorite_repository.dart test/domain/favorites/favorite_test.dart test/domain/favorites/favorite_repository_test.dart test/support/in_memory_favorite_repository.dart lib/domain/formatting/display_date.dart test/domain/formatting/display_date_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart docs/glossary.md && git commit -m "feat(domain): le favori, type clos à trois branches, et le contrat de son dépôt (S1 de T3)" -m "Un favori est une identité copiée à l'ajout, jamais une mesure : code et libellé pour une station, le point entier pour un point ONDE (la fiche s'ouvre avec lui), sans coordonnée de station (arbitrage 6). La clé est le couple type et code : un code ONDE est une chaîne libre, rien n'interdit qu'il égale un code station. Une entrée que cette version ne sait pas lire reste un favori, affiché et retirable par son texte brut (BR-011). L'échec du dépôt est levé, à deux branches : liste illisible, écriture en échec." -- lib/domain/favorites/favorite.dart lib/domain/favorites/favorite_repository.dart test/domain/favorites/favorite_test.dart test/domain/favorites/favorite_repository_test.dart test/support/in_memory_favorite_repository.dart lib/domain/formatting/display_date.dart test/domain/formatting/display_date_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart docs/glossary.md
```

### Task S2 : La forme stockée — JSON versionné, tolérant entrée par entrée

**Agent :** **raisonnement** (forme stockée : ce qui s'écrit ici se relira chez les usagers).
**Files:** créés `lib/data/preferences/favorites_codec.dart`, `test/data/preferences/favorites_codec_test.dart`
**Prérequis :** `S1`.

**Signatures** — fonctions pures, `dart:convert` seulement :
- `const int favoritesFormatVersion = 1;`
- `List<Favorite> decodeFavorites(String? stored)` — lève `ListeDeFavorisIllisible`, ne rend jamais de liste vide pour une valeur illisible.
- `String encodeFavorites(List<Favorite> favorites)`

**Forme, en entier** (une ligne par entrée ici pour la lecture ; `jsonEncode` n'écrit ni retour ni espace) :

```json
{"version":1,"favoris":[
 {"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":{"code":" O968 5312 ","libelle":"LA BONNEURE A MILLANCAY","latitude":47.444182169,"longitude":1.78116675,"cours_d_eau":"la Bonne Heure","departement":{"code":"41","libelle":"41"},"region":null}},
 {"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001","libelle":"La Loire à Blois"},
 {"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z","libelle":"Chez moi","latitude":46.2,"longitude":5.2}
]}
```

**Règles**
- **Écriture.** Ordre des clés : celui de l'exemple. `ajoute_le` = `addedAt.toIso8601String()` (UTC, suffixe `Z`). Point ONDE : **les sept champs toujours écrits**, `null` pour une absence (`cours_d_eau`, `departement`, `region`). `code` ONDE = `point.code.value` **verbatim**, espaces compris, jamais `trim`. Un `UnreadableFavorite` s'écrit `jsonDecode(raw)` **à sa place dans la liste** : ni déplacé, ni corrigé, ni rabattu sur un type connu.
- **Lecture, échelle de la valeur → `ListeDeFavorisIllisible`** : `stored` n'est pas du JSON ; racine qui n'est pas un objet ; `version` absente, non entière, `< 1` ou `> favoritesFormatVersion` ; `favoris` absent ou qui n'est pas une liste. `stored == null` → liste vide (rien n'a jamais été écrit).
- **Lecture, échelle de l'entrée → `UnreadableFavorite(raw: jsonEncode(entrée), label: …)`**, entrée par entrée, les autres sont lues : entrée qui n'est pas un objet ; `type` absent ou inconnu ; `ajoute_le` absent, non analysable ou **sans** fuseau UTC ; station dont `code` est refusé par `StationCode` ou dont `libelle` est absent ou blanc ; point ONDE dont `code` est blanc, dont `libelle`, `latitude` ou `longitude` manque ou n'a pas le bon type (`latitude` et `longitude` : `num`, converti par `toDouble()`, fini), dont `cours_d_eau` n'est ni chaîne ni `null`, dont `departement` ou `region` n'est ni `null` ni un objet à `code` et `libelle` chaînes. `label` = le `libelle` de premier niveau s'il est une chaîne non blanche, sinon `point.libelle` s'il l'est, sinon `null`.
- Une clé inconnue **dans une entrée de type connu et lisible** est ignorée à la lecture (elle ne se réécrit pas) ; une clé inconnue à la racine aussi.
- Deux entrées lisibles de même lieu (`sameFavoritePlace`) : **les deux sont rendues**, le codec ne dédoublonne pas.

**Cas de test**
- Aller-retour de chaque branche : `decodeFavorites(encodeFavorites([onde, station]))` égale `[onde, station]`, dans cet ordre.
- **Texte exact** : `encodeFavorites([StationFavorite(code: StationCode('K447001001'), label: 'La Loire à Blois', addedAt: DateTime.utc(2026, 10, 11, 17, 5))])` vaut `{"version":1,"favoris":[{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001","libelle":"La Loire à Blois"}]}` ; `encodeFavorites(const <Favorite>[])` vaut `{"version":1,"favoris":[]}`.
- Code ONDE `' O968 5312 '` : après aller-retour, `point.code.value == ' O968 5312 '` (longueur 11) ; `'A721 3011'` ne revient pas `'A7213011'`.
- Station `K447001001` et point ONDE de code `'K447001001'` dans la même valeur → deux favoris, de deux types.
- Point ONDE dont cours d'eau, département et région sont `null` : aller-retour égal ; le texte contient `"cours_d_eau":null`.
- **Type inconnu** (troisième entrée de l'exemple) : rendue `UnreadableFavorite`, `label == 'Chez moi'`, `raw == '{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z","libelle":"Chez moi","latitude":46.2,"longitude":5.2}'` ; les deux autres entrées de l'exemple sont lues, ordre gardé.
- **Réécrit tel quel** : `encodeFavorites(decodeFavorites(exemple))`, redécodé, rend la même liste ; la troisième entrée y garde ses cinq clés et sa position.
- **Malformée d'un type connu** : `{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z","code":"k447","libelle":"La Loire à Blois"}` → `UnreadableFavorite(label: 'La Loire à Blois')` ; `{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":{"code":"K4640001","libelle":"LA BONNEURE A MILLANCAY","longitude":1.78}}` (latitude absente) → `UnreadableFavorite(label: 'LA BONNEURE A MILLANCAY')` ; `ajoute_le` valant `"hier"`, puis `"2026-10-11T17:05:00.000"` (sans `Z`) → illisible ; entrée `42`, `"x"`, `null` → illisible, `label == null`, `raw` valant `'42'`, `'"x"'`, `'null'`.
- Une valeur à trois entrées dont celle du milieu est illisible → trois favoris, le deuxième `UnreadableFavorite` : jamais tout ou rien.
- **Valeur** : `'pas du json'`, `''`, `'[]'`, `'"x"'`, `'{"favoris":[]}'`, `'{"version":"1","favoris":[]}'`, `'{"version":0,"favoris":[]}'`, `'{"version":2,"favoris":[]}'`, `'{"version":1}'`, `'{"version":1,"favoris":{}}'` → chacun lève `ListeDeFavorisIllisible` ; `decodeFavorites(null)` → `[]`.
- `latitude` écrite `47` (entier JSON) → lue `47.0` ; `"latitude":"47.4"` → entrée illisible.
- Deux entrées station de même code dans la valeur → deux `StationFavorite` rendus.
- Clé inconnue : `'{"version":1,"favoris":[],"autre":1}'` → `[]`, sans lever ; une entrée station lisible portant en plus `"seuil":3` → `StationFavorite`, et `"seuil"` absent du texte réencodé.
- Aucun `package:flutter`, aucun `shared_preferences` importé par `favorites_codec.dart` (assertion sur le texte du fichier).

- [ ] **Étape 1** — tests rouges ; `flutter test test/data/preferences/favorites_codec_test.dart` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter.
- [ ] **Étape 3 — contre-épreuve** : dans `decodeFavorites`, faire rendre `<Favorite>[]` au lieu de lever sur `version` 2 → rouge ; rétablir → vert. **Recopier le rouge** dans le message de commit.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/data/preferences/favorites_codec.dart test/data/preferences/favorites_codec_test.dart && git commit -m "feat(data): forme stockée des favoris, JSON versionné et tolérant entrée par entrée (S2 de T3)" -m "Une chaîne, { version, favoris }, chaque entrée portant son type. Deux niveaux d'illisible, une seule règle : ce qui ne se lit pas à l'échelle de l'entrée devient UnreadableFavorite, gardé à sa place et réécrit tel quel ; ce qui ne se lit pas à l'échelle de la valeur (pas du JSON, racine inattendue, version supérieure) lève, et ne rend jamais une liste vide (BR-011, BR-007). Le code ONDE est écrit verbatim, espaces compris : le rogner changerait la station interrogée. Contre-épreuve : <recopier le rouge>." -- lib/data/preferences/favorites_codec.dart test/data/preferences/favorites_codec_test.dart
```

### Task S3 : `SharedPreferencesFavoriteRepository`, et l'amendement d'`ADR-011`

**Agent :** **raisonnement** (écriture en échec, sérialisation, faits du paquet).
**Files:** créés `lib/data/preferences/shared_preferences_favorite_repository.dart`, `test/data/preferences/shared_preferences_favorite_repository_test.dart`, `test/support/fake_shared_preferences.dart` · modifié `docs/adr/ADR-011-stockage-local.md`
**Prérequis :** `S1`, `S2`.

> **Faits relevés le 2026-10-12 dans le paquet installé — à RELIRE et dater à l'étape 0, pas à recopier d'ici.** `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart` : `String? getString(String key) => _preferenceCache[key] as String?;` (l. 129 — lecture **synchrone du cache mémoire** chargé par `getInstance()`, `TypeError` si la valeur n'est pas une chaîne) ; `Future<bool> setString(String key, String value)` (l. 163-164) → `_setValue` (l. 177-187), qui **écrit le cache AVANT d'appeler le magasin** ; le paquet le dit l. 105-110 (« It is NOT guaranteed that this cache and the device prefs will remain in sync since the setter method might fail »). Note l. 156-162 : sur Android une valeur ne peut pas commencer par trois préfixes réservés — la nôtre commence par `{`. `shared_preferences_windows-2.4.1/lib/shared_preferences_windows.dart` : `setValue` (l. 129-138) modifie sa propre copie mémoire puis `_writePreferences` (l. 374-399) réécrit **tout le fichier JSON** par `writeAsStringSync`, toute exception → `debugPrint` et **`false`** ; aucun fichier temporaire ni renommage n'y est visible ; `_readFromFile` (l. 348-369) fait `json.decode` sans `try`. `shared_preferences_android-2.4.28/android/src/main/kotlin/…/LegacySharedPreferencesPlugin.kt:66` : `preferences.edit().putString(key, value).commit()`.
> ⚠️ **Conséquence, absente du cadrage :** après un `setString` qui rend `false` ou lève, `getString` rend **la valeur non écrite** jusqu'à la fin de la session. « Dépôt sans mémo » (R2) ne suffit donc pas à ce que l'étoile « ne change pas d'état » (critère 13) à l'ouverture suivante de la fiche. **Décision de la boucle principale du 2026-10-12, réversible (elle a relu `_setValue` dans `shared_preferences_legacy.dart`) : écriture compensatoire** — sur une écriture en échec, le dépôt rappelle `setString(clé, valeur d'avant)` (ou `encodeFavorites(const [])` s'il n'y avait aucune valeur), résultat et levée ignorés, puis lève `EcritureDeFavorisEnEchec`. Seules `getString` et `setString` restent employées (R2). **La sérialisation des opérations par instance est gardée : même décision, réversible.** Écartée : la limite documentée, sans compensation.

**Signatures**
- `final class SharedPreferencesFavoriteRepository implements FavoriteRepository { SharedPreferencesFavoriteRepository({Future<SharedPreferences> Function() preferences = SharedPreferences.getInstance}); }` — clé privée `const String _favoritesKey = 'favorites';`, nommée une seule fois.
- `test/support/fake_shared_preferences.dart` : `final class FakeSharedPreferences implements SharedPreferences { FakeSharedPreferences([Map<String, Object> initial = const <String, Object>{}]); final Map<String, Object> cache; final Map<String, Object> disk; final List<Object> writeOutcomes; final List<String> writtenValues; Completer<void>? writeGate; }` — **un seul paramètre positionnel** : `initial` remplit `cache` **et** `disk` ; `writeOutcomes` part vide et se programme par `fake.writeOutcomes.add(…)`, `writeGate` par affectation — `getString(key)` = `cache[key] as String?` ; `setString(key, value)` : ajoute `value` à `writtenValues`, **écrit `cache[key]` d'abord** (comme le paquet), attend `writeGate?.future`, puis consomme le premier élément de `writeOutcomes` (liste vide → `true`) : `true` → `disk[key] = value` et rend `true` ; `false` → rend `false` ; tout autre objet → le lève. Tout autre membre : `noSuchMethod` → `super.noSuchMethod`.

**Invariants**
- **Sans mémo** : chaque opération lit `getString(_favoritesKey)`, décode (`S2`), transforme, encode, écrit. Aucun champ ne garde une liste.
- **Sérialisé par instance** : une opération n'en commence une autre qu'une fois la précédente terminée, quelle que soit son issue — sans cela deux lire-puis-écrire croisés (l'étoile d'une fiche et un retrait dans la liste) perdent un favori. Ce n'est pas un mémo : rien n'est gardé entre deux opérations.
- `readAll` : `preferences()` qui lève, `getString` qui lève (`TypeError`), valeur illisible → `ListeDeFavorisIllisible` ; `add` et `remove` de même, **sans aucun appel à `setString`**. `clear` : `setString(_favoritesKey, encodeFavorites(const <Favorite>[]))`, **sans lire**.
- `add` d'un favori déjà présent, `remove` d'un favori absent : **aucun appel à `setString`**.
- `setString` qui rend `false` **ou** qui lève → `EcritureDeFavorisEnEchec` ; `preferences()` qui lève pendant une écriture → `EcritureDeFavorisEnEchec` pour `clear`, `ListeDeFavorisIllisible` pour `add` et `remove` (la lecture a échoué la première).
- Seul fichier de ce lot à importer `package:shared_preferences`.

**Cas de test** (`preferences: () async => fake`, sauf mention)
- Rien de stocké → `readAll()` rend `[]`, `fake.writtenValues` vide.
- `add(station)` → `fake.disk['favorites']` vaut exactement `{"version":1,"favoris":[{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001","libelle":"La Loire à Blois"}]}` ; `add(onde)` ensuite → `readAll()` rend `[onde, station]`.
- **Pas un cache mémoire** : sur le magasin réel du paquet (`SharedPreferences.setMockInitialValues(<String, Object>{})` en `setUp`, constructeur sans argument), une instance ajoute, **une seconde instance** relit `[station]` (critère 6).
- Station et point ONDE de même code `K447001001` → `readAll()` rend deux favoris ; `remove(station)` laisse le point ONDE.
- Code ONDE `' O968 5312 '` : ajouté, relu identique, puis `remove` d'un `OndePointFavorite` de code `'O968 5312'` (sans espaces de bord) → **rien n'est retiré**.
- **Type inconnu conservé après un ajout** : `FakeSharedPreferences(<String, Object>{'favorites': <exemple complet de S2, trois entrées>})` ; `add(autreStation)` → la valeur écrite, décodée par `jsonDecode`, porte quatre entrées, la quatrième égale (`Map`) à `{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z","libelle":"Chez moi","latitude":46.2,"longitude":5.2}` (critère 11).
- **Retrait d'un `UnreadableFavorite` par son texte brut** : `remove(readAll().whereType<UnreadableFavorite>().single)` → deux entrées restent, plus aucune de type `point_designe` ; un `UnreadableFavorite` de `raw` différent → aucun `setString`.
- **Valeur qui n'est pas du JSON** (`'pas du json'`), puis **`version` 2** (`'{"version":2,"favoris":[]}'`), puis valeur non chaîne (`FakeSharedPreferences(<String, Object>{'favorites': 42})`) : `readAll`, `add`, `remove` lèvent `ListeDeFavorisIllisible`, `fake.writtenValues` reste vide, `fake.cache['favorites']` inchangé (critère 12).
- **« Tout effacer » sur une valeur illisible** : `clear()` aboutit, `fake.disk['favorites'] == '{"version":1,"favoris":[]}'`, `readAll()` rend `[]`, puis `add(station)` aboutit.
- **`setString` qui rend `false`** (`fake.writeOutcomes.add(false)`) : `add(station)` lève `EcritureDeFavorisEnEchec` ; `fake.disk` ne porte pas la clé. **Compensation :** `readAll()` rend ensuite `[]` et `fake.writtenValues` compte deux valeurs, la seconde `'{"version":1,"favoris":[]}'`.
- **`setString` qui lève** (`fake.writeOutcomes.add(StateError('disque'))`) : `add(station)` lève `EcritureDeFavorisEnEchec`, pas `StateError` ; même issue pour `remove` et `clear`.
- Compensation qui échoue elle aussi (`fake.writeOutcomes.addAll(<Object>[false, false])`) : `add` lève `EcritureDeFavorisEnEchec`, une seule fois, sans autre exception.
- `preferences: () async => throw StateError('prefs')` : `readAll`, `add`, `remove` → `ListeDeFavorisIllisible` ; `clear` → `EcritureDeFavorisEnEchec`.
- **Sérialisation** : `writeGate` posé ; `add(station)` et `add(onde)` lancés sans attendre ; avant l'ouverture de la porte `fake.writtenValues` compte **une** valeur ; porte ouverte, les deux futurs aboutissent et `readAll()` rend `[onde, station]`. Variante : la première écriture échoue (`fake.writeOutcomes.add(false)`), la seconde opération s'exécute quand même et aboutit.
- `add(station)` deux fois → un seul `setString` ; `remove` d'un absent → aucun.
- Valeur stockée portant **deux** entrées station de même code (écrite par une autre version) : `remove(station)` retire **les deux** ; `add(station)` sur cette valeur → aucun `setString`.
- Le fichier ne déclare aucun champ de type `List<Favorite>` (assertion sur le texte du fichier).

- [ ] **Étape 0 — relire le paquet installé** (chemins par `.dart_tool/package_config.json`) et recopier dans le rapport, avec fichier et ligne : les signatures de `getString` et `setString`, `_setValue`, le commentaire du cache, `_writePreferences` et `_readFromFile` de l'implémentation Windows, la ligne `commit()` de l'implémentation Android. Chercher dans les trois paquets (`README.md`, `CHANGELOG.md`, sources) **une taille maximale de valeur** et **ce que devient une écriture interrompue** : recopier ce qui est écrit, ou « rien trouvé dans <fichiers consultés> ». Ce qui n'est pas trouvé reste 💭 dans l'amendement. Aucun arrêt : l'écriture compensatoire est décidée (encadré ci-dessus) ; si la relecture **contredit** le fait du cache écrit avant le magasin, arrêt et question.
- [ ] **Étape 1** — tests rouges ; `flutter test test/data/preferences` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter.
- [ ] **Étape 3** — `ADR-011` : en-tête (« Portée ») renvoyant à une section ajoutée **avant « Conséquences »**, `### Amendement du <date du commit> — les favoris en shared_preferences (T3, arbitrage 2 du 2026-10-12)` : la décision (une clé `favorites`, une chaîne JSON, `version` 1, derrière `FavoriteRepository`) ; le tableau des faits de l'étape 0, datés, fichier et ligne ; ce qui en découle (cache écrit avant le magasin, écriture compensatoire, décision de la boucle principale du 2026-10-12, réversible ; fichier Windows réécrit en entier, partagé avec la clé d'acquittement ; dépôt sérialisé) ; **ce qui reste 💭** (taille maximale, écriture interrompue, tout ce que l'étape 0 n'a pas trouvé) ; « le moteur structuré reste ouvert jusqu'au hors-ligne (`US-10`) » ; « Si l'amendement est revu : une classe, `lib/data/preferences/`, et une migration de la valeur déjà écrite ». Le premier paragraphe de « Portée », qui range les favoris dans le moteur structuré, est **barré, pas supprimé**. Aucun verrou de `test/project/` ne lit ce fichier.
- [ ] **Étape 4 — contre-épreuve** : retirer la sérialisation → le cas « Sérialisation » rougit ; rétablir → vert. Recopier le rouge.
- [ ] **Étape 5** — critère de fin, commit.

```bash
git add -- lib/data/preferences/shared_preferences_favorite_repository.dart test/data/preferences/shared_preferences_favorite_repository_test.dart test/support/fake_shared_preferences.dart docs/adr/ADR-011-stockage-local.md && git commit -m "feat(data): dépôt des favoris sur shared_preferences ; ADR-011 amendé (S3 de T3)" -m "Une clé, une chaîne JSON versionnée, getString et setString seulement, aucun mémo : chaque opération relit puis écrit, et les opérations d'une instance se suivent sans se croiser. Une valeur illisible n'est jamais remplacée sans geste : lire, ajouter et retirer lèvent, seul tout effacer l'écrase. Une écriture refusée ou qui lève sort en échec typé. Faits du paquet relus le <date> (cache écrit avant le magasin, fichier Windows réécrit en entier) : une écriture en échec est suivie d'une écriture compensatoire de la valeur d'avant, décision de la boucle principale, réversible. Reste non vérifié : <liste>. Contre-épreuve : <recopier le rouge>." -- lib/data/preferences/shared_preferences_favorite_repository.dart test/data/preferences/shared_preferences_favorite_repository_test.dart test/support/fake_shared_preferences.dart docs/adr/ADR-011-stockage-local.md
```

---

## Lot 6 — Favoris : l'étoile des deux fiches, et le dépôt câblé

> Cadrage § 5.3, décision R7. Tout nouveau test de widget s'écrit `testWidgetsOnWindows` (`test/support/windows_platform.dart`) ou `testWidgetsOnAndroid` (`test/support/android_platform.dart`, lot 1), jamais la fonction nue de Flutter, même citée en commentaire (verrou de `N1`). **Tout cas dont la fenêtre fait moins de 600 px de large est en `testWidgetsOnAndroid`, titre « Android : … ».**

### Task S4 : L'étoile partagée — `FavoriteStar` et `FavoriteStarButton`

> **Soumis à la décision 4 du commanditaire (recommandée : A, `features/shared/`).** `FavoriteStar` est un état d'affichage, pas du métier : il vit dans `lib/features/shared/`, en Dart pur, à côté du widget, et n'entre **ni** dans `docs/domain-model.md` **ni** dans `typesDuDomaine`. Alternative B : `lib/domain/favorites/favorite_star.dart`.
> **Règles de couches, lues le 2026-10-12 dans `test/architecture/layers_test.dart` :** un ViewModel qui importe `package:martinpecheur/features/shared/favorite_star.dart` passe les sept règles — `view-model-sans-widget` (l. 258-265) ne refuse que les trois bibliothèques de `widgetLibraries` (l. 90-94), par égalité exacte de l'URI importée ; `feature-vers-feature` (l. 272-290) laisse passer toute cible sous `shared/` (l. 285-287) ; `features-vers-data` (l. 294-298) et `features-sans-fichier-a-plat` (l. 277-279, l. 304-306) ne sont pas concernées. Le fichier lui-même, sans import, ne peut violer `shared-sans-tranche`.

**Agent :** mécanique.
**Files:** créés `lib/features/shared/favorite_star.dart`, `test/features/shared/favorite_star_test.dart`, `lib/features/shared/favorite_star_button.dart`, `test/features/shared/favorite_star_button_test.dart` · modifiés `docs/adr/ADR-014-feature-first-mvvm.md`, `CLAUDE.md` (invariant `shared/` : deux fichiers de plus)
**Prérequis :** `N1` (`testWidgetsOnAndroid`).

**Signatures**
- `lib/features/shared/favorite_star.dart`, **aucun import** : `final class FavoriteStar { const FavoriteStar({required this.filled, required this.enabled, this.writeFailed = false}); final bool filled; final bool enabled; final bool writeFailed; }` avec `==`, `hashCode`, `toString`.
- `lib/features/shared/favorite_star_button.dart` : `const Key favoriteStarButtonKey = Key('favorite-star');` · `const String addFavoriteLabel = 'Ajouter aux favoris';` · `const String removeFavoriteLabel = 'Retirer des favoris';` · `const String favoriteWriteFailedText = "Le favori n'a pas pu être enregistré.";` (ajout en échec, § 10.1) · `const String favoriteRemoveFailedText = "Le favori n'a pas pu être retiré.";` (retrait en échec — **texte soumis à l'approbation du commanditaire avec ce plan (décision 1)**)
- `class FavoriteStarButton extends StatelessWidget { const FavoriteStarButton({required this.star, required this.onToggle, super.key}); final FavoriteStar star; final VoidCallback onToggle; }`
- `class FavoriteWriteFailedNotice extends StatelessWidget { const FavoriteWriteFailedNotice(this.text, {super.key}); final String text; }` — `Text(text)` sous `Semantics(liveRegion: true)` ; l'appelant choisit le texte.

**Invariants :** même construction que `DataSourcesLink` (`lib/features/shared/data_sources_view.dart:125-175`, à lire) : `Semantics(button: true, label: …, enabled: star.enabled, excludeSemantics: true, onTap: star.enabled ? onToggle : null)` en racine, puis `KeyboardFocusRing(onActivate: star.enabled ? onToggle : null, canRequestFocus: star.enabled)`, puis `InkWell(canRequestFocus: false, onTap: …)` sur un `SizedBox` carré de `minimumTapTarget`. **Forme, pas couleur** : `Icons.star` quand `filled`, `Icons.star_border` sinon, **même couleur** dans les deux cas ; inactive : opacité réduite, forme gardée. Aucun des deux fichiers n'importe une tranche (`shared-sans-tranche`) ; `favorite_star.dart` n'importe **rien**, pour qu'un ViewModel puisse l'importer.

**Cas de test** (`testWidgetsOnWindows`, sauf mention)
- `FavoriteStar(filled: false, enabled: true)` : icône `Icons.star_border`, libellé sémantique « Ajouter aux favoris », `isButton`, `isEnabled` ; un tap appelle `onToggle` **une** fois.
- `filled: true` : `Icons.star`, libellé « Retirer des favoris ».
- **Sans la couleur** (critère 14) : la couleur de l'icône est la même pour `filled` vrai et faux ; les deux libellés diffèrent.
- `enabled: false` : tap, `Entrée` et `Espace` n'appellent pas `onToggle` ; la sémantique porte `hasEnabledState` sans `isEnabled` ; le bouton est **hors** de l'ordre de tabulation (`Tab` ne s'y arrête pas).
- `enabled: true` : `Tab` l'atteint, le contour de focus de `KeyboardFocusRing` apparaît (`focusRingColor`), `Entrée` puis `Espace` appellent chacun `onToggle`.
- Taille : `tester.getSize(find.byKey(favoriteStarButtonKey))` vaut `Size(44, 44)` ; **`testWidgetsOnAndroid`**, titre « Android : … » : `Size(48, 48)`.
- `FavoriteWriteFailedNotice(favoriteWriteFailedText)` : le texte exact « Le favori n'a pas pu être enregistré. », dans une région vivante ; `FavoriteWriteFailedNotice(favoriteRemoveFailedText)` : « Le favori n'a pas pu être retiré. ».
- `FavoriteStar` (`favorite_star_test.dart`, sans rendu) : égalité structurelle sur les trois champs ; `writeFailed` vaut `false` par défaut.
- **Verrou** (`favorite_star_test.dart`, `dart:io`) : le texte de `lib/features/shared/favorite_star.dart` ne contient **aucune directive `import`**, donc aucun `package:flutter` ; un ViewModel peut l'importer.
- `test/architecture/layers_test.dart` et `test/project/vocabulary_test.dart` verts.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/shared/favorite_star_test.dart test/features/shared/favorite_star_button_test.dart` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter ; `ADR-014`, § « Amendement du 2026-09-18 — le dossier partagé `lib/features/shared/` » : une phrase datée — « Depuis T3 (`S4`), `shared/` porte aussi un **état d'affichage en Dart pur**, `FavoriteStar` (`favorite_star.dart`, aucun import), que deux ViewModels de fiche produisent et qu'un widget partagé consomme : un ViewModel l'importe sans violer `view-model-sans-widget`. » ; `CLAUDE.md` : la liste des fichiers de `shared/` gagne `favorite_star.dart` et `favorite_star_button.dart`.
- [ ] **Étape 3 — contre-épreuve** : ajouter `import 'package:flutter/foundation.dart';` en tête de `favorite_star.dart` → le verrou rougit ; retirer → vert. Recopier le rouge.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/features/shared/favorite_star.dart test/features/shared/favorite_star_test.dart lib/features/shared/favorite_star_button.dart test/features/shared/favorite_star_button_test.dart docs/adr/ADR-014-feature-first-mvvm.md CLAUDE.md && git commit -m "feat(ui): l'étoile de favori partagée, lisible sans la couleur (S4 de T3)" -m "Un seul widget pour les deux fiches, dans shared : forme pleine ou vide, même teinte, libellé annoncé (Ajouter aux favoris, Retirer des favoris), cible de 44 ou de 48 sur Android, atteinte par Tab et basculée par Entrée ou Espace. Inactive, elle garde sa forme et sort de l'ordre de tabulation. Son état, FavoriteStar, est un état d'affichage en Dart pur posé à côté du widget, sans aucun import : deux ViewModels de fiche le produisent sans importer de widget (ADR-014 amendé). Contre-épreuve : <recopier le rouge>." -- lib/features/shared/favorite_star.dart test/features/shared/favorite_star_test.dart lib/features/shared/favorite_star_button.dart test/features/shared/favorite_star_button_test.dart docs/adr/ADR-014-feature-first-mvvm.md CLAUDE.md
```

### Task S5 : `StationSheetViewModel` connaît le favori — et `main.dart` câble le dépôt

**Agent :** **raisonnement** (racine de composition ; course entre lecture des favoris et chargement).
**Files:** modifiés `lib/features/station_sheet/view_model/station_sheet_view_model.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart`, `lib/main.dart`, `test/main_test.dart`
**Prérequis :** `S1`, `S3`, `S4`.

**Existant, lu** — constructeur `StationSheetViewModel({required this._observations, required this._stations, DateTime Function()? now, UtcOffsetOf? utcOffsetOf})` (`station_sheet_view_model.dart:145-151`) ; `Future<void> open(StationCode code)` (l. 181) ; `void close()` (l. 252) ; états `Fermee()`, `EnCours(code)`, `Prete(data)`, `Introuvable(code)`, `EnEchec(code, cause)` (l. 43-94) ; `_emit(generation, next)` (l. 259-265). Racine : `StationSheetViewModel(observations: observations, stations: AssetStationRepository(stationsRead.stations))` (`lib/main.dart:141-144`) ; `test/main_test.dart:192-195` le construit de même dans `_app`.

**Signatures**
- Constructeur : `StationSheetViewModel({required this._observations, required this._stations, required this._favorites, DateTime Function()? now, UtcOffsetOf? utcOffsetOf})`, champ `final FavoriteRepository _favorites;`.
- `FavoriteStar? get favoriteStar;` (`FavoriteStar` importé de `package:martinpecheur/features/shared/favorite_star.dart`, Dart pur : permis à un ViewModel, voir `S4`) — `null` : aucune étoile à dessiner. · `Future<void> toggleFavorite();`
- `lib/main.dart` : `final FavoriteRepository favorites = SharedPreferencesFavoriteRepository();` **une seule instance**, déclarée avant `runApp`, passée ici (`favorites: favorites`) — elle le sera aussi à `OndeSheetViewModel` (`S6`) et à `FavoritesViewModel` (`S11`).
- `test/main_test.dart` : `_app` devient `MartinPecheurApp _app(WarningsViewModel warningsViewModel, [RestrictionsViewModel? restrictionsViewModel, StationSheetViewModel? stationSheetViewModel, OndeSheetViewModel? ondeSheetViewModel])`, et construit par défaut la fiche station avec `favorites: InMemoryFavoriteRepository()` (`test/support/in_memory_favorite_repository.dart`).

**Table de l'étoile** (la seule règle ; « en favori » = `stationFavoriteIn(liste lue, code) != null`)

| État de la fiche | Favoris non encore lus | Liste illisible | Pas en favori | En favori |
|---|---|---|---|---|
| `Fermee` | `null` | `null` | `null` | `null` |
| `EnCours`, `EnEchec`, `Introuvable` | `null` | vide, inactive | **`null`** (aucun libellé à copier) | pleine, active |
| `Prete` | `null` | vide, inactive | vide, active | pleine, active |

Pendant une écriture : même forme, **inactive**. Après une écriture en échec : forme **d'avant**, active, `writeFailed: true` jusqu'à la bascule, à l'`open` ou au `close` suivants.

**Invariants**
- `open` lance `_favorites.readAll()` **en même temps** que le chargement existant, sans l'attendre pour émettre `EnCours`, `Prete`, `EnEchec`, `Introuvable` ; le futur rendu par `open` ne se complète qu'après les deux. Toute levée de `readAll` (les deux branches de `FavoriteStorageFailure`, ou autre) → « liste illisible ». Chaque `open` **relit** ; même garde de génération que `_emit` : une lecture ou une écriture d'un `open` abandonné n'écrit rien.
- `toggleFavorite` : étoile `null` ou inactive → **aucun appel au dépôt**. Ajout (état `Prete` seulement) : `_favorites.add(StationFavorite(code: data.station.code, label: data.station.label, addedAt: _now().toUtc()))`. Retrait : `_favorites.remove(<le favori lu à l'open>)` — le code suffit, aucun libellé n'est exigé.
- Les états de la fiche, leurs textes et l'ordre de leurs émissions **ne changent pas** : les tests existants du fichier restent verts sans autre retouche que l'argument `favorites:` ajouté à chaque construction.
- Le fichier n'importe toujours aucun widget ni `lib/data/` (`view-model-sans-widget`, `features-vers-data`).

**Cas de test** — groupe « favori », doubles `InMemoryFavoriteRepository` et ceux du fichier
- Fiche `Prete`, liste vide → `favoriteStar == const FavoriteStar(filled: false, enabled: true)` ; `toggleFavorite()` → le dépôt porte `[StationFavorite(code K447001001, label 'La Loire à Blois', addedAt = horloge injectée, en UTC)]` et l'étoile est pleine, active (critère 1).
- **Étoile inactive pendant une écriture** : `writeGate` posé ; après l'appel, avant la porte, `favoriteStar == const FavoriteStar(filled: false, enabled: false)` ; un second `toggleFavorite()` pendant l'attente → `writeCalls` reste 1 ; porte ouverte → pleine, active (critère 13).
- **Écriture en échec** : `writeError = const EcritureDeFavorisEnEchec('x')` → étoile `FavoriteStar(filled: false, enabled: true, writeFailed: true)` ; l'état de la fiche est toujours `Prete` ; une nouvelle bascule réussie efface `writeFailed`.
- **Station déjà en favori sur une fiche `EnEchec`** (dépôt d'observations qui lève) : étoile pleine, active ; `toggleFavorite()` → dépôt vide, étoile `null`, état toujours `EnEchec` (critère 3). Même chose en `EnCours` (observations tenues par un `Completer`) : l'étoile est pleine **avant** la fin du chargement.
- **Station `Introuvable`, sans ajout** (`findByCode` rend `null`) : `favoriteStar == null` ; `toggleFavorite()` → `writeCalls == 0` (critère 4). `Introuvable` et déjà en favori → pleine, active, retirable.
- `EnEchec` et `EnCours`, pas en favori → `null`.
- Un point ONDE de code `'K447001001'` seul dans le dépôt → la fiche de la station `K447001001` a une étoile **vide** (critère 5).
- Liste illisible (`readError = const ListeDeFavorisIllisible('x')`) : étoile `FavoriteStar(filled: false, enabled: false)` en `Prete` comme en `EnEchec` ; `toggleFavorite()` → `writeCalls == 0`.
- Relecture : `open` → ajout par un **autre** client du dépôt → `close` → `open` : étoile pleine ; `readCalls == 2`.
- Courses : `close()` pendant la lecture des favoris → étoile `null`, aucune notification tardive ; `open(A)` puis `open(B)` avant la fin de la lecture de A → l'étoile est celle de B ; `dispose()` pendant une écriture → aucune exception, aucune notification.
- Notifications : une lecture de favoris qui change l'étoile notifie ; `Fermee` → `favoriteStar == null`.
- Racine (`test/main_test.dart`) : la suite existante reste verte avec le nouveau `_app`.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/station_sheet/view_model` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter le ViewModel, câbler `main.dart`, adapter `_app` et les constructions du fichier de test.
- [ ] **Étape 3** — critère de fin (`layers_test.dart` et `restriction_source_test.dart` compris), commit.

```bash
git add -- lib/features/station_sheet/view_model/station_sheet_view_model.dart test/features/station_sheet/view_model/station_sheet_view_model_test.dart lib/main.dart test/main_test.dart && git commit -m "feat(ui): la fiche station sait si sa station est en favori ; dépôt câblé dans la racine (S5 de T3)" -m "Ajouter exige le libellé, donc l'état Prete ; retirer n'exige que le code : une station déjà en favori garde son étoile pleine et retirable en chargement, en échec et hors référentiel, sinon un favori ouvert hors réseau ne se retirerait que par la liste. Les 37 stations absentes du référentiel n'offrent pas d'ajout. L'étoile est inactive tant qu'une écriture court et tant que la liste est illisible ; une écriture en échec la laisse dans son état et le dit. Chaque ouverture relit le dépôt, qui n'a pas de mémo. main.dart nomme SharedPreferencesFavoriteRepository, une seule instance." -- lib/features/station_sheet/view_model/station_sheet_view_model.dart test/features/station_sheet/view_model/station_sheet_view_model_test.dart lib/main.dart test/main_test.dart
```

### Task S6 : `OndeSheetViewModel` connaît le favori

**Agent :** mécanique (la table et les cas sont ceux de `S5`, réduits : le point est toujours connu).
**Files:** modifiés `lib/features/onde_sheet/view_model/onde_sheet_view_model.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart`, `lib/main.dart`, `test/main_test.dart`
**Prérequis :** `S5`.

**Existant, lu** — constructeur `OndeSheetViewModel({required this._onde, DateTime Function()? now})` (`onde_sheet_view_model.dart:172-173`) ; `Future<void> open(OndePoint point)` (l. 204) ; `void close()` (l. 255) ; états `OndeSheetFermee()`, `OndeSheetEnCours(point)`, `OndeSheetPrete(data)`, `OndeSheetEnEchec(point, cause)` (l. 77-112). Racine : `OndeSheetViewModel(onde: onde)` (`lib/main.dart:148`), et `test/main_test.dart:196-198`.

**Signatures** — `OndeSheetViewModel({required this._onde, required this._favorites, DateTime Function()? now})` · `FavoriteStar? get favoriteStar;` · `Future<void> toggleFavorite();` · `lib/main.dart` : `OndeSheetViewModel(onde: onde, favorites: favorites)`, **la même instance** que la fiche station · `_app` de `test/main_test.dart` : un seul `InMemoryFavoriteRepository` partagé par les deux fiches par défaut.

**Table de l'étoile** — `OndeSheetFermee` → `null` ; dans les trois états visibles : favoris non encore lus → `null` ; liste illisible → vide, inactive ; pas en favori → **vide, active** ; en favori (`ondePointFavoriteIn(liste, point.code) != null`) → pleine, active. Écriture en cours, écriture en échec : comme la fiche station.

**Invariants :** `open` lit les favoris en même temps que l'historique, sans retarder `OndeSheetEnCours` ; relecture à chaque `open` ; garde de génération. Ajout : `_favorites.add(OndePointFavorite(point: <le point passé à open>, addedAt: _now().toUtc()))` — le point **tel que reçu**, code verbatim. Retrait : le favori lu à l'`open`. États, textes et tests existants inchangés, hors l'argument `favorites:`.

**Cas de test** — groupe « favori »
- **Dans chacun des trois états visibles** (`OndeSheetEnCours` tenu par un `Completer`, `OndeSheetPrete`, `OndeSheetEnEchec`) : étoile vide et active ; `toggleFavorite()` → le dépôt porte `[OndePointFavorite(point, addedAt = horloge, UTC)]`, étoile pleine (critère 2).
- Le point stocké est celui reçu : code `' O968 5312 '` ajouté → `stored.single` a `point.code.value == ' O968 5312 '` ; une fiche ouverte sur le code `'O968 5312'` a une étoile **vide**.
- En favori, fiche `OndeSheetEnEchec` → pleine ; bascule → dépôt vide, étoile **vide, active** (le point reste connu) (critère 3).
- **Même code, autre type** : une `StationFavorite` de code `K447001001` seule au dépôt, fiche ouverte sur un point ONDE de code `'K447001001'` → étoile **vide** ; après la bascule le dépôt porte **deux** favoris (critère 5).
- Étoile inactive pendant une écriture ; second appel ignoré (`writeCalls == 1`) ; écriture en échec → `writeFailed: true`, forme d'avant, état de la fiche inchangé (critère 13).
- Liste illisible → vide, inactive, `toggleFavorite()` sans appel au dépôt.
- `close()` pendant la lecture → `null` ; `open(A)` puis `open(B)` → étoile de B ; `OndeSheetFermee` → `null`.
- Racine : la suite de `test/main_test.dart` reste verte.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/onde_sheet/view_model` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter, câbler, adapter les constructions du test.
- [ ] **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/onde_sheet/view_model/onde_sheet_view_model.dart test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart lib/main.dart test/main_test.dart && git commit -m "feat(ui): la fiche ONDE sait si son point est en favori (S6 de T3)" -m "Le point est connu dans les trois états visibles de la fiche : l'étoile y est toujours offerte. Le favori copie le point entier, tel que reçu, code verbatim — c'est ce que la fiche exige pour se rouvrir depuis la liste, sans référentiel ONDE embarqué. Même dépôt, même instance que la fiche station." -- lib/features/onde_sheet/view_model/onde_sheet_view_model.dart test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart lib/main.dart test/main_test.dart
```

### Task S7a : L'étoile dans le cadre des deux panneaux, branchée dans la racine

**Agent :** mécanique pour les vues ; la boucle principale relit le câblage de `main.dart`.
**Files:** modifiés `lib/features/station_sheet/view/station_summary_sheet.dart`, `test/features/station_sheet/view/station_summary_sheet_test.dart`, `lib/features/onde_sheet/view/onde_summary_sheet.dart`, `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `lib/main.dart`, `test/main_test.dart`
**Prérequis :** `S4`, `S5`, `S6`.

**Existant, lu** — `StationSheetPanel({required this.state, required this.onClose, this.utcOffsetOf = systemUtcOffsetOf, super.key})` (`station_summary_sheet.dart:288-293`), cadre `_frame` l. 343-360 : `Row[Flexible(content), SizedBox(width: 8), _CloseButton]` ; `OndeSheetPanel({required this.state, required this.onClose, super.key})` (`onde_summary_sheet.dart:262`), cadre l. 296-313. Racine : les deux `ListenableBuilder` de `lib/main.dart:260-267` et `:277-283`.

**Signatures**
- `StationSheetPanel({required this.state, required this.onClose, this.favoriteStar, this.onToggleFavorite, this.utcOffsetOf = systemUtcOffsetOf, super.key})` · `OndeSheetPanel({required this.state, required this.onClose, this.favoriteStar, this.onToggleFavorite, super.key})` — `final FavoriteStar? favoriteStar;` `final VoidCallback? onToggleFavorite;`, avec `assert(favoriteStar == null || onToggleFavorite != null)`.
- Cadre : `Column[Row[Flexible(content), SizedBox(width: 8), if (favoriteStar != null) ...[FavoriteStarButton(star, onToggle), SizedBox(width: 8)], _CloseButton], if (favoriteStar?.writeFailed ?? false) FavoriteWriteFailedNotice(favoriteStar.filled ? favoriteRemoveFailedText : favoriteWriteFailedText)]` — l'étoile garde sa forme d'avant : pleine, c'est un retrait qui a échoué ; vide, un ajout. Étoile inactive parce que la liste est illisible : **aucune phrase sur la fiche** (l'écran « Favoris » l'explique ; décision de la boucle principale, réversible).
- `lib/main.dart` : `StationSheetPanel(state: stationSheetViewModel.state, onClose: stationSheetViewModel.close, favoriteStar: stationSheetViewModel.favoriteStar, onToggleFavorite: () => unawaited(stationSheetViewModel.toggleFavorite()))`, et de même pour `OndeSheetPanel`.

**Invariants :** `favoriteStar == null` → le cadre est **celui d'aujourd'hui**, au pixel : les tests existants des deux vues passent sans retouche. L'étoile est à gauche du bouton de fermeture, 8 px entre les deux cibles (`04-ui.md § 3`). Aucune tranche n'importe l'autre.

**Cas de test** (`testWidgetsOnWindows`, sauf mention)
- Panneau station `Prete`, `favoriteStar: const FavoriteStar(filled: false, enabled: true)` : une étoile (`favoriteStarButtonKey`), à gauche du bouton de fermeture, écart de 8 ; un tap appelle `onToggleFavorite` une fois ; le bouton de fermeture appelle toujours `onClose`.
- `favoriteStar: null` dans chacun des états visibles : aucune étoile ; `Fermee` avec une étoile non nulle : rien n'est rendu.
- `EnEchec` avec étoile pleine : l'étoile **et** le texte « Hub'Eau n'a pas répondu pour la station K447001001. » sont là.
- `FavoriteStar(filled: false, enabled: true, writeFailed: true)` : « Le favori n'a pas pu être enregistré. » est rendu **sous** la rangée, étoile vide ; `FavoriteStar(filled: true, enabled: true, writeFailed: true)` : « Le favori n'a pas pu être retiré. », étoile pleine, et l'autre phrase absente ; `writeFailed: false` : aucune des deux ; liste illisible (`FavoriteStar(filled: false, enabled: false)`) : aucune phrase.
- Mêmes cas sur `OndeSheetPanel`, dans ses trois états visibles.
- **`testWidgetsOnAndroid`, titre « Android : à 360 px et 200 % de police, étoile et fermeture restent entières »** : fenêtre de 360 × 640, `textScaler` 2,0 — étoile et fermeture de 48 × 48, côte à côte, écart de 8, aucun débordement (`tester.takeException()` nul) ; un cas par panneau.
- **Racine, composition réelle** : une fiche station `Prete` (dépôt de stations qui rend la station `K447001001`) ouverte par `stationSheetViewModel.open` → l'étoile est trouvée ; un tap → `InMemoryFavoriteRepository.stored` porte une `StationFavorite` et l'étoile annonce « Retirer des favoris ». De même pour la fiche ONDE.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/station_sheet/view test/features/onde_sheet/view test/main_test.dart` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter, câbler.
- [ ] **Étape 3 — contre-épreuve** : retirer `favoriteStar:` du `StationSheetPanel` de `lib/main.dart` → le cas « Racine, composition réelle » rougit ; rétablir → vert. Recopier le rouge.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/features/station_sheet/view/station_summary_sheet.dart test/features/station_sheet/view/station_summary_sheet_test.dart lib/features/onde_sheet/view/onde_summary_sheet.dart test/features/onde_sheet/view/onde_summary_sheet_test.dart lib/main.dart test/main_test.dart && git commit -m "feat(ui): l'étoile dans le cadre des deux fiches (S7a de T3)" -m "À côté du bouton de fermeture, dans le cadre commun à tous les états visibles : une fiche en échec garde son étoile si le lieu est déjà en favori. Sans étoile à montrer, le cadre est celui d'avant. Une écriture en échec se lit sous la rangée : ajout ou retrait, selon la forme que l'étoile a gardée. Le câblage de la racine est tenu par un test de la composition réelle. Contre-épreuve : <recopier le rouge>." -- lib/features/station_sheet/view/station_summary_sheet.dart test/features/station_sheet/view/station_summary_sheet_test.dart lib/features/onde_sheet/view/onde_summary_sheet.dart test/features/onde_sheet/view/onde_summary_sheet_test.dart lib/main.dart test/main_test.dart
```

### Task S7b : `favoris.feature`, `UC-008`, et les documents de l'étoile

**Agent :** mécanique.
**Files:** créés `docs/acceptance/favoris.feature`, `docs/use-cases/UC-008-suivre-un-lieu-en-favori.md` · modifiés `test/project/acceptance_features_test.dart`, `docs/use-cases/UC-003-consulter-une-station-hydrometrique.md`, `docs/use-cases/UC-004-consulter-un-point-onde.md`, `docs/04-ui.md`, `docs/README.md`
**Prérequis :** `S7a`.

**Le verrou, lu** (`test/project/acceptance_features_test.dart`) — `_featureFiles` (l. 34-40) liste les fichiers ; chaque scénario porte `Étant donné`, `Quand`, `Alors` et **cite une `BR-` qui existe sur le disque** ; aucun mot de `_forbiddenFlowWords` (« suffisant », « insuffisant », « normal », « bon », « sûr ») ni de `_instructionVerbs` (« autorise », « interdit », « déconseillé » et leurs formes), en mot entier ; `_scenariosByStory` compte les scénarios rangés sous un marqueur `# ── US-NN` ; `_containsQuoted` (l. 185) exige le libellé entier entre guillemets français.

**`docs/acceptance/favoris.feature`, à écrire tel quel** (sept scénarios ; `S9` et `S11` ajoutent les sept autres à la suite) :

```gherkin
Fonctionnalité: Suivre un lieu en favori
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD : ces scénarios ne sont jamais exécutés. Vérifié par
  # test/project/acceptance_features_test.dart.
  #
  # Sources : US-14 (cadrage de T3, § 8) ; BR-001 (aucune valeur sans sa date),
  # BR-007 (l'absence n'est jamais un état neutre), BR-011 (nomenclature
  # tolérante à l'inconnu), BR-014 (aucun verbe d'instruction).
  En tant qu'usager qui suit quelques lieux
  Je veux les enregistrer en favoris et les retrouver en liste
  Afin de rouvrir leur fiche sans les chercher sur la carte

  # ── US-14 — l'étoile des fiches ──────────────────────────────────────────

  Scénario: L'étoile d'une fiche station prête ajoute la station
    Étant donné une fiche station dont les valeurs sont affichées, pour une station qui n'est pas en favori
    Quand l'usager active l'étoile « Ajouter aux favoris »
    Alors l'étoile devient pleine et s'annonce « Retirer des favoris »
    Et le favori garde le libellé de la station et sa date d'ajout, jamais une mesure (BR-001)

  Scénario: L'étoile d'une fiche de point ONDE ajoute le point, quel que soit l'état de la fiche
    Étant donné une fiche de point ONDE en chargement, prête ou en échec, pour un point qui n'est pas en favori
    Quand l'usager active l'étoile « Ajouter aux favoris »
    Alors le point est ajouté aux favoris avec son libellé, son cours d'eau et son département
    Et aucune observation n'est copiée dans le favori (BR-001)

  Scénario: L'étoile retire un favori, même quand la fiche est en échec
    Étant donné une station en favori dont la fiche n'a pas pu charger ses valeurs
    Quand l'usager active l'étoile « Retirer des favoris »
    Alors la station n'est plus en favori
    Et la fiche garde son message d'échec, jamais un état neutre (BR-007)

  Scénario: Une station absente du référentiel embarqué n'offre pas d'ajout
    Étant donné une station présente sur la carte et absente du référentiel embarqué
    Quand sa fiche s'affiche
    Alors la fiche dit que la station n'est pas dans le référentiel (BR-007)
    Et aucune étoile n'est proposée : il n'y a aucun libellé à copier

  Scénario: Une station et un point ONDE de même code sont deux favoris
    Étant donné une station en favori et un point ONDE qui porte le même code
    Quand l'usager ajoute ce point ONDE aux favoris
    Alors la liste compte deux favoris distincts
    Et un code ONDE à espaces revient identique, espaces compris (BR-011)

  Scénario: Une écriture en échec laisse l'étoile dans son état et le dit
    Étant donné une fiche station prête dont la station n'est pas en favori
    Quand l'usager active l'étoile et que l'enregistrement échoue
    Alors l'étoile reste vide et la fiche affiche « Le favori n'a pas pu être enregistré. » (BR-007)
    Et l'étoile est inactive tant qu'une écriture court

  Scénario: L'état de l'étoile se lit sans la couleur
    Étant donné une fiche dont le lieu est en favori, puis une fiche dont le lieu ne l'est pas
    Quand un lecteur d'écran atteint l'étoile
    Alors il annonce « Retirer des favoris » pour la première et « Ajouter aux favoris » pour la seconde
    Et la forme de l'étoile, pleine ou vide, suffit à les distinguer ; aucun libellé ne porte sur un usage de l'eau (BR-014)
```

Critères de § 8 couverts : 1, 2, 3, 4, 5, 13, 14, dans cet ordre.

**`test/project/acceptance_features_test.dart`** — `_featureFiles` + `'favoris.feature'` ; le titre « les cinq fichiers couvrent ensemble… » suit le compte réel (le lot 4 y ajoute `filtres.feature`) ; import de `package:martinpecheur/features/shared/favorite_star_button.dart` ; ajouts :
- `test('favoris.feature met en scénarios US-14', …)` : `_scenariosByStory(favoris)['US-14']` vaut au moins 1 (ici 7).
- `group('les libellés portés par une constante du code figurent dans favoris.feature', …)` avec une table `libellesFavoris` — `addFavoriteLabel`, `removeFavoriteLabel`, `favoriteWriteFailedText` — et un test par entrée : `_containsQuoted(favoris, valeur)` vrai. `S9` et `S11` allongent cette table.

**Autres documents**
- `UC-008` d'après `docs/use-cases/UC-template.md` : statut « Accepté », contexte borné « Favoris », acteur principal P3, secondaire P1 ; déclencheur « l'usager active l'étoile d'une fiche » ; flux nominal de l'étoile (ajouter, retirer), flux de la liste marqués « 🔄 livré par `T3-S11` » ; alternatifs : A1 station hors référentiel, A2 liste illisible, A3 écriture en échec, A4 entrée non lisible ; règles `BR-001`, `BR-007`, `BR-011` ; un `sequenceDiagram` fiche → ViewModel → `FavoriteRepository` → `shared_preferences`, placé dans le flux nominal.
- `UC-003` étape 6 et `UC-004` (étape 6 ajoutée) : amendement daté renvoyant à `UC-008` — l'étoile est dans le cadre de la fiche ; télécharger et partager, cités par `UC-003`, ne sont pas livrés.
- `docs/04-ui.md` : note datée sous chacun des deux croquis de fiche — l'étoile est dans le cadre, à gauche de la fermeture ; pleine ou vide ; absente quand rien ne peut être ajouté ; le bouton « ★ Favori » du bas du croquis n'est pas repris.
- `docs/README.md` : ligne `acceptance/` (un fichier de plus) et tableau des cas d'usage (`UC-008`).
- `docs/tracabilite.md` et son test ne sont **pas** touchés ici (lot 9).

- [ ] **Étape 1** — ajouter au test la liste, le test `US-14` et le groupe des libellés ; `flutter test test/project/acceptance_features_test.dart` → échec (fichier absent), sortie recopiée.
- [ ] **Étape 2** — écrire `favoris.feature` et les documents.
- [ ] **Étape 3 — contre-épreuve** : dans `favoris.feature`, remplacer « Ajouter aux favoris » par « Mettre en favori » → le groupe des libellés rougit ; remplacer un `BR-007` par `BR-099` → le test des règles citées rougit ; rétablir → vert. Recopier les deux rouges.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- docs/acceptance/favoris.feature docs/use-cases/UC-008-suivre-un-lieu-en-favori.md test/project/acceptance_features_test.dart docs/use-cases/UC-003-consulter-une-station-hydrometrique.md docs/use-cases/UC-004-consulter-un-point-onde.md docs/04-ui.md docs/README.md && git commit -m "docs: favoris.feature et UC-008 ouverts avec les scénarios de l'étoile (S7b de T3)" -m "Sept scénarios de US-14, chacun citant une règle qui existe ; les libellés de l'étoile et le texte d'écriture en échec y figurent tels que les constantes du code, et un test les lie. UC-008, Suivre un lieu en favori : les flux de la liste restent marqués à livrer. UC-003, UC-004 et les deux croquis de fiche amendés : l'étoile est dans le cadre. Contre-épreuves : <recopier les deux rouges>." -- docs/acceptance/favoris.feature docs/use-cases/UC-008-suivre-un-lieu-en-favori.md test/project/acceptance_features_test.dart docs/use-cases/UC-003-consulter-une-station-hydrometrique.md docs/use-cases/UC-004-consulter-un-point-onde.md docs/04-ui.md docs/README.md
```

---

## Lot 7 — Favoris : l'écran, son entrée sur la carte, la route

> Cadrage § 5.4, décisions R5, R6, R8, arbitrages 6 et 8. Dépend du lot 1 (`ScreenTitleBar`, `testWidgetsOnAndroid`) et du lot 4 (`MapEntryButtons`, `MapRoundButton`). Le verrou de plateforme (`N1`) cherche le mot nu sur toute ligne de code, commentaire de fin de ligne compris : dans un test nouveau, n'écrire que `testWidgetsOnWindows` ou `testWidgetsOnAndroid`, jamais le nom de la fonction de Flutter, même en commentaire.

### Task S8 : `FavoritesViewModel`

**Agent :** mécanique.
**Files:** créés `lib/features/favorites/view_model/favorites_view_model.dart`, `test/features/favorites/view_model/favorites_view_model_test.dart`
**Prérequis :** `S1`.

**Signatures**
- `sealed class FavoritesState { const FavoritesState(); }` · `final class FavorisFermes extends FavoritesState` (l'écran n'est pas ouvert) · `final class FavorisEnLecture extends FavoritesState` · `final class AucunFavori extends FavoritesState` · `final class FavorisLus extends FavoritesState { const FavorisLus(this.favorites); final List<Favorite> favorites; }` (jamais vide) · `final class FavorisIllisibles extends FavoritesState`
- `final class FavoritesViewModel extends ChangeNotifier { FavoritesViewModel({required this._favorites}); FavoritesState get state; bool get busy; bool get writeFailed; Future<void> load(); Future<void> remove(Favorite favorite); Future<void> startOver(); void close(); }` — état initial `FavorisFermes`. `load` **ouvre** (appelé à chaque poussée de la route), `close` ferme (appelé à son retrait) : `state is! FavorisFermes` est la garde de `S11` contre deux routes empilées, sur le précédent de `RestrictionsFermees` (`lib/main.dart:308-313`).

**Invariants :** `load()` émet `FavorisEnLecture` **avant son premier `await`** (la garde de `S11` contre deux routes en dépend : au second appel de la même trame, l'état n'est déjà plus `FavorisFermes`), efface `writeFailed`, puis lit : liste vide → `AucunFavori` ; sinon `FavorisLus` **dans l'ordre du dépôt**, sans tri ; toute levée → `FavorisIllisibles`. `remove` : `busy` vrai pendant l'écriture, puis **relecture** sans repasser par `FavorisEnLecture` ; en échec : `writeFailed` vrai, état inchangé. `startOver` : `clear()` puis relecture ; en échec : `writeFailed` vrai, état `FavorisIllisibles` gardé. `remove` et `startOver` pendant `busy` → ignorés. `close` : émet `FavorisFermes`, efface `writeFailed`, change la génération — une lecture ou une écriture en cours n'écrit plus rien dans l'état ; `remove` et `startOver` sur `FavorisFermes` → aucun appel au dépôt. Garde de génération et `_disposed`, comme les ViewModels de fiche. Aucun widget importé, aucun `lib/data/`.

**Cas de test**
- Dépôt `[onde, station]` → `load()` : `FavorisEnLecture` puis `FavorisLus([onde, station])`, ordre gardé ; dépôt vide → `AucunFavori`.
- `readError = const ListeDeFavorisIllisible('x')` → `FavorisIllisibles` ; une levée quelconque (`StateError`) aussi ; **jamais** `AucunFavori`.
- `remove(station)` → dépôt `[onde]`, état `FavorisLus([onde])`, jamais repassé par `FavorisEnLecture` (liste des états notifiés) ; retirer le dernier → `AucunFavori`.
- `remove` d'un `UnreadableFavorite` → il disparaît de l'état, les autres restent.
- `writeGate` posé : `busy` vrai avant la porte, un second `remove` ignoré (`writeCalls == 1`), `busy` faux après.
- `writeError = const EcritureDeFavorisEnEchec('x')` → `writeFailed` vrai, état inchangé ; un `load()` l'efface.
- `startOver()` depuis `FavorisIllisibles` (double : `readError` remis à `null` par `clear`) → `AucunFavori` ; en échec → `FavorisIllisibles`, `writeFailed` vrai, **`readCalls` inchangé**.
- Relecture à chaque ouverture : `load()` deux fois → `readCalls == 2`.
- `dispose()` pendant une lecture → aucune notification, aucune exception ; deux `load()` croisés → l'état est celui du second.
- **Synchrone** : `unawaited(viewModel.load())`, sans attendre ni pomper : `viewModel.state is FavorisEnLecture`.
- État initial `FavorisFermes` ; `load()` puis `close()` → `FavorisFermes` ; `close()` pendant une lecture tenue par un `Completer` → l'état reste `FavorisFermes` quand elle aboutit ; `close()` pendant un retrait → le dépôt est bien modifié, l'état reste `FavorisFermes` ; `remove` après `close()` → `writeCalls` inchangé ; `load()` après `close()` → relit (`readCalls` + 1).

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/favorites/view_model` → échec, sortie recopiée ; **Étape 2** — implémenter ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/favorites/view_model/favorites_view_model.dart test/features/favorites/view_model/favorites_view_model_test.dart && git commit -m "feat(ui): FavoritesViewModel, cinq états et quatre actions (S8 de T3)" -m "Fermé, lecture en cours, liste, vide, illisible : une liste illisible n'est jamais montrée vide (BR-007), et rien ne l'écrase avant l'action explicite. load ouvre et passe en lecture avant son premier await, close ferme : c'est ce qui permettra à la racine de ne pousser qu'une route. Le ViewModel relit le dépôt à chaque ouverture et après chaque retrait ; il ne trie rien, l'ordre est celui du dépôt, dernier ajouté en tête. Une écriture en échec laisse l'état tel quel et le dit." -- lib/features/favorites/view_model/favorites_view_model.dart test/features/favorites/view_model/favorites_view_model_test.dart
```

### Task S9 : L'écran « Favoris »

**Agent :** **raisonnement** (écran neuf, cinq états dont quatre visibles, textes approuvés au mot).
**Files:** créés `lib/features/favorites/view/favorites_screen.dart`, `test/features/favorites/view/favorites_screen_test.dart` · modifiés `docs/04-ui.md`, `docs/acceptance/favoris.feature`, `test/project/acceptance_features_test.dart`
**Prérequis :** `S4`, `S7b` (`favoris.feature` et son verrou existent), `S8`, `B1` (`ScreenTitleBar`), `N1`.

**Signatures**
- `class FavoritesScreen extends StatelessWidget { const FavoritesScreen({required this.state, required this.busy, required this.writeFailed, required this.onOpen, required this.onRemove, required this.onStartOver, this.utcOffsetOf = systemUtcOffsetOf, super.key}); final FavoritesState state; final bool busy; final bool writeFailed; final void Function(Favorite favorite) onOpen; final void Function(Favorite favorite) onRemove; final VoidCallback onStartOver; final UtcOffsetOf utcOffsetOf; }`
- Constantes, **mot pour mot § 10.1 du cadrage** : `favoritesScreenTitle = 'Favoris'` · `favoritesNoMeasureNotice = "Cette liste ne montre aucune mesure. La fiche d'un lieu donne sa dernière mesure connue, avec sa date."` · `favoritesEmptyText = "Aucun favori enregistré. L'étoile d'une fiche — station de mesure ou point d'observation — ajoute ce lieu à cette liste."` · `favoritesUnreadableText = "Les favoris enregistrés sur cet appareil n'ont pas pu être lus. Ils sont conservés tels quels : aucun favori ne peut être ajouté ni retiré tant que la liste n'est pas remplacée."` · `favoritesStartOverLabel = "Repartir d'une liste vide"` · `favoritesStartOverHint = 'Les favoris enregistrés sur cet appareil seront effacés.'` · `unreadableFavoriteText = "Favori non lisible par cette version de l'application"` · `stationFavoriteKind = 'Station hydrométrique'` · `ondeFavoriteKind = 'Point ONDE'` · préfixe `'Ajouté le '` · `favoritesReplaceFailedText = "La liste n'a pas pu être remplacée."` (**texte soumis à l'approbation du commanditaire avec ce plan (décision 1)**).
- Clés : `favoritesStartOverButtonKey = Key('favorites-start-over')` ; ligne `ValueKey<String>('favorite-row-<i>')` ; bouton de retrait `ValueKey<String>('favorite-remove-<i>')`, `<i>` rang dans la liste.

**Invariants**
- Écran plein bâti comme `DataSourcesView` (`lib/features/shared/data_sources_view.dart:178-235`, à lire) : `CallbackShortcuts` (`Échap` → `Navigator.maybePop`), `Focus(autofocus: true, skipTraversal: true)`, `Scaffold`, `SafeArea`, `WheelScrollsScreen`, puis, **première ligne de la `Column`**, **`ScreenTitleBar(title: favoritesScreenTitle)`** — signature de `B1` : `const ScreenTitleBar({required this.title, this.backgroundColor, this.titleColor, super.key})`, son `BackButton` fait le retour, **`Échap` reste à la charge de cet écran** (le `CallbackShortcuts` ci-dessus, comme `restrictions_screen.dart:159-164`) —, une `Scrollbar` toujours visible sur un défilement `primary: true`, colonne de `readingColumnWidth` et `readingColumnGutter`. **Aucune barre de titre écrite ici** (dette 3) : le fichier ne contient ni `BackButton(` ni `AppBar(` — `test/project/screen_title_bar_test.dart` les refuse hors de `lib/features/shared/screen_layout.dart`.
- **Aucune valeur mesurée, aucun appel réseau** : l'écran ne reçoit que des `Favorite`. Ligne d'une station : libellé, « Station hydrométrique », « Ajouté le JJ/MM/AAAA » (`formatLocalDate(addedAt, offsetOf: utcOffsetOf)`). Ligne d'un point ONDE : `point.label`, « Point ONDE », le cours d'eau s'il n'est pas `null`, `'Département ${departement.code}'` s'il n'est pas `null`, la date. Ligne non lisible : son `label` s'il existe, puis « Favori non lisible par cette version de l'application » ; **ni date, ni action d'ouverture**.
- Une ligne lisible est un bouton (tap, `Entrée`, `Espace`, `KeyboardFocusRing`) qui appelle `onOpen` ; chaque ligne, lisible ou non, porte un bouton de retrait de `minimumTapTarget`, libellé `removeFavoriteLabel`, inactif quand `busy`. `onOpen` n'est **jamais** appelé avec un `UnreadableFavorite`.
- `FavorisLus` : `favoritesNoMeasureNotice` **en tête**, avant la première ligne. `AucunFavori` : `favoritesEmptyText` seul. `FavorisIllisibles` : `favoritesUnreadableText`, puis le bouton `favoritesStartOverLabel` et, sous lui, `favoritesStartOverHint` ; aucune ligne. `FavorisFermes` : aucun contenu d'état (l'écran n'est pas censé être affiché ; `S11` garde l'état montré pendant la sortie de la route). `FavorisEnLecture` : un indicateur de progression, **aucun texte** (décision de la boucle principale). `writeFailed` : en tête du contenu, `FavoriteWriteFailedNotice(favoritesReplaceFailedText)` quand l'état est `FavorisIllisibles` (c'est « Repartir d'une liste vide » qui a échoué), `FavoriteWriteFailedNotice(favoriteRemoveFailedText)` dans tout autre état (un retrait a échoué).
- `switch` exhaustif sur `FavoritesState` et sur `Favorite`, sans `default`. La tranche n'importe ni `map`, ni `station_sheet`, ni `onde_sheet`.

**Cas de test** (`testWidgetsOnWindows`, sauf mention)
- `FavorisLus([onde, station])`, décalage injecté nul : les textes « LA BONNEURE A MILLANCAY », « Point ONDE », « la Bonne Heure », « Département 41 », « Ajouté le 12/10/2026 », puis « La Loire à Blois », « Station hydrométrique », « Ajouté le 11/10/2026 » ; l'ordre vertical est celui de la liste ; `favoritesNoMeasureNotice` est **au-dessus** de la première ligne (critères 1 et 7).
- **Aucune mesure** : aucun texte de l'écran ne contient « m³/s », « l/s », « mesuré », « Débit », « Hauteur », ni aucun libellé de `flowCategoryLabel`.
- Date locale : `addedAt: DateTime.utc(2026, 10, 12, 22, 30)`, décalage `+2 h` → « Ajouté le 13/10/2026 ».
- Point ONDE sans cours d'eau ni département : ni « Département », ni ligne vide.
- Tap sur la ligne de la station → `onOpen` reçoit **ce** `StationFavorite` ; `Tab` jusqu'à la ligne puis `Entrée` → idem ; tap sur son bouton de retrait → `onRemove` le reçoit, `onOpen` n'est pas appelé.
- `UnreadableFavorite(raw: '{"type":"point_designe"}', label: 'Chez moi')` : « Chez moi » et « Favori non lisible par cette version de l'application » ; tap sur la ligne → `onOpen` **jamais** appelé ; son bouton de retrait appelle `onRemove` ; sans `label` : la phrase seule (critère 11).
- `AucunFavori` : `favoritesEmptyText` exact, aucune ligne, aucun `favoritesNoMeasureNotice`, et aucun des mots de `forbiddenNeutralityPhrases` (critère 10).
- `FavorisIllisibles` : le texte exact, le bouton « Repartir d'une liste vide » ≥ `minimumTapTarget` de haut, son sous-titre ; tap → `onStartOver` ; aucune ligne, **aucun** `favoritesEmptyText` (critère 12).
- `FavorisEnLecture` : un `CircularProgressIndicator`, aucun des textes d'état ; `FavorisFermes` : la barre de titre seule, ni ligne, ni texte d'état, ni indicateur.
- `busy: true` : les boutons de retrait et « Repartir d'une liste vide » n'appellent rien ; `FavorisLus` et `writeFailed: true` : « Le favori n'a pas pu être retiré. » est rendu ; `FavorisIllisibles` et `writeFailed: true` : « La liste n'a pas pu être remplacée. », et pas l'autre phrase ; « Le favori n'a pas pu être enregistré. » n'apparaît jamais sur cet écran.
- Le texte de `favorites_screen.dart` ne contient ni `BackButton(` ni `AppBar(` ; `test/project/screen_title_bar_test.dart` vert.
- Barre de titre : un seul `ScreenTitleBar`, titre « Favoris » en en-tête sémantique ; `Échap` puis `tester.pageBack()` retirent chacun la route (écran poussé dans un `MaterialApp` de banc).
- 30 favoris : la liste défile à la molette posée sur la barre de titre.
- **`testWidgetsOnAndroid`, titre « Android : à 360 × 640 et 200 % de police, rien ne déborde »** : `FavorisLus` (trois lignes dont une non lisible), puis `AucunFavori`, puis `FavorisIllisibles` — `tester.takeException()` nul dans les trois, le bouton « Repartir d'une liste vide » et son sous-titre entiers.
- **`testWidgetsOnAndroid`, titre « Android : … »** : le bouton de retrait mesure 48 × 48.
- `vocabulary_test.dart` et `layers_test.dart` verts.

**Documents (même commit)**
- `docs/04-ui.md` : croquis de l'écran « Favoris » et de ses trois états (liste, vide, illisible), à côté de la section des fiches.
- `docs/acceptance/favoris.feature`, **ajoutés tels quels à la suite** des scénarios de `S7b` (critères 7, 10, 11, 12) :

```gherkin
  # ── US-14 — la liste des favoris ─────────────────────────────────────────

  Scénario: La liste n'affiche aucune valeur mesurée, et le dit
    Étant donné deux favoris enregistrés, une station et un point ONDE
    Quand l'écran des favoris s'affiche
    Alors chaque ligne porte le libellé du lieu, sa nature et sa date d'ajout
    Et la liste s'ouvre sur « Cette liste ne montre aucune mesure. La fiche d'un lieu donne sa dernière mesure connue, avec sa date. » (BR-001)

  Scénario: Une liste vide dit comment un favori s'ajoute
    Étant donné aucun favori enregistré
    Quand l'écran des favoris s'affiche
    Alors il affiche « Aucun favori enregistré. L'étoile d'une fiche — station de mesure ou point d'observation — ajoute ce lieu à cette liste. »
    Et rien ne suggère un état des cours d'eau (BR-007)

  Scénario: Une entrée que cette version ne sait pas lire reste affichée et retirable
    Étant donné une liste enregistrée dont une entrée est d'un type inconnu
    Quand l'écran des favoris s'affiche
    Alors cette entrée porte la mention « Favori non lisible par cette version de l'application »
    Et elle se retire, ne s'ouvre pas, et reste enregistrée après l'ajout d'un autre favori (BR-011)

  Scénario: Une liste illisible est dite telle et n'est remplacée que sur demande
    Étant donné une valeur enregistrée que l'application ne sait pas lire
    Quand l'écran des favoris s'affiche
    Alors il dit que les favoris n'ont pas pu être lus, jamais que la liste est vide (BR-007)
    Et rien n'est effacé avant l'action « Repartir d'une liste vide »
```

- `test/project/acceptance_features_test.dart` : import de `package:martinpecheur/features/favorites/view/favorites_screen.dart` ; la table `libellesFavoris` (posée par `S7b`) gagne `favoritesNoMeasureNotice`, `favoritesEmptyText`, `unreadableFavoriteText`, `favoritesStartOverLabel`, chacun vérifié par `_containsQuoted`.

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/favorites/view test/project/acceptance_features_test.dart` → échec, sortie recopiée ; **Étape 2** — implémenter, documents ; **Étape 3** — critère de fin, commit.

```bash
git add -- lib/features/favorites/view/favorites_screen.dart test/features/favorites/view/favorites_screen_test.dart docs/04-ui.md docs/acceptance/favoris.feature test/project/acceptance_features_test.dart && git commit -m "feat(ui): l'écran Favoris, identité seule et états dits (S9 de T3)" -m "La liste n'affiche aucune mesure, et le dit : sinon chaque ligne devrait porter date, source et fraîcheur, et coûter un appel par favori (BR-001, C-15). Vide, elle dit comment un favori s'ajoute, rien de l'état des cours d'eau (BR-007). Illisible, elle le dit et n'offre qu'une action explicite. Une entrée non lisible est montrée et retirable, jamais ouvrable (BR-011). Barre de titre partagée : aucune troisième copie. Quatre scénarios de plus dans favoris.feature, liés aux textes du code." -- lib/features/favorites/view/favorites_screen.dart test/features/favorites/view/favorites_screen_test.dart docs/04-ui.md docs/acceptance/favoris.feature test/project/acceptance_features_test.dart
```

### Task S10 : Le bouton « Favoris » du groupe d'entrée, le rappel de `MapView`, et la colonne à cinq boutons

**Agent :** mécanique ; **arrêt sans correction** si un recouvrement rougit à 800 × 740 (Windows) ou à 360 × 640 (Android).
**Files:** modifiés `lib/features/map/view/map_entry_buttons.dart`, `test/features/map/view/map_entry_buttons_test.dart`, `lib/features/map/view/map_view.dart` (`MapView`, `buildMapOverlays`, commentaire), `test/features/map/view/map_view_test.dart`, `docs/04-ui.md` · créé `test/features/map/view/map_entry_buttons_overlap_test.dart`
**Prérequis :** lot 4 (`F10a` : `MapRoundButton`, `MapEntryButtons` ; `F10b` : leur branchement dans `buildMapOverlays`), `N1`.

**Existant, à relire avant d'écrire** (signatures accordées le 2026-10-12 ; `MapRoundButton` et `MapEntryButtons` sont écrits par `F10a`, le branchement dans `buildMapOverlays` par `F10b`) — `const MapEntryButtons({required this.onOpenFilters, required this.filterActive, super.key})` dans `lib/features/map/view/map_entry_buttons.dart`, clé `mapFiltersButtonKey`, libellé `mapFiltersLabel` ; il emploie `MapRoundButton({required semanticsKey, required icon, required label, required onTap, filled = false, key})` de `lib/features/map/view/map_round_button.dart`, dans le groupe d'ordre de tabulation `mapTraversalOrderEntryButtons`. `buildMapOverlays` porte, depuis `F10b`, quatre paramètres `required` de plus (`filterHidesEverything`, `onClearFilters`, `filterActive`, `onOpenFilters`) ; **`MapView` n'a gagné aucun paramètre pour les filtres** : `MapView({required this.viewModel, this.onStationTap, this.onOndeTap, this.stationSheet, this.ondeSheet, this.onCloseSheets, this.onPointDesignated, …})` (`map_view.dart:1374-1381` au 2026-10-12).

**Signatures**
- `MapEntryButtons({required this.onOpenFilters, required this.filterActive, this.onOpenFavorites, super.key})` — `final VoidCallback? onOpenFavorites;` · `const Key mapFavoritesButtonKey = Key('map-open-favorites');` · `const String mapFavoritesLabel = 'Favoris';` · le bouton est un `MapRoundButton(semanticsKey: mapFavoritesButtonKey, icon: Icons.star, label: mapFavoritesLabel, onTap: onOpenFavorites)`, jamais `filled`.
- `buildMapOverlays` gagne `VoidCallback? onOpenFavorites` (optionnel), transmis à `MapEntryButtons`.
- `MapView` gagne `this.onOpenFavorites` (`final VoidCallback? onOpenFavorites;`), transmis à `buildMapOverlays`.

**Invariants :** ordre, de haut en bas **et** à la tabulation : « Favoris » puis « Filtres », dans `mapTraversalOrderEntryButtons` ; même taille (`minimumTapTarget`), même espacement que le reste de la colonne ; `onOpenFavorites == null` → **bouton absent**, le groupe est celui du lot 4. La tranche `map` ne nomme pas la tranche `favorites` (`feature-vers-feature`). Le commentaire de `map_view.dart:1424-1426` (« ils dépendent d'échelles différentes, et un seul jeu de marqueurs est tapable à la fois ») est remplacé par : « Les deux panneaux ne sont jamais ouverts en même temps : `main.dart` ferme l'un avant d'ouvrir l'autre. Depuis T3 une fiche s'ouvre aussi depuis l'écran « Favoris » : une fiche ONDE peut donc être ouverte alors que l'échelle affichée est le débit, et inversement. »

**Cas de test** (`testWidgetsOnWindows`, sauf mention)
- `onOpenFavorites` posé : bouton trouvé par `mapFavoritesButtonKey`, libellé sémantique « Favoris », `isButton` ; un tap l'appelle une fois ; `Tab` l'atteint **juste avant** « Filtres » ; `Entrée` et `Espace` l'appellent.
- Il est au-dessus de « Filtres », même abscisse, écart vertical égal à celui qui sépare « Filtres » du bouton suivant ; taille 44 × 44 ; **`testWidgetsOnAndroid`** : 48 × 48.
- `onOpenFavorites: null` : aucun bouton « Favoris » ; « Filtres » à la position qu'il avait au lot 4.
- `MapView(onOpenFavorites: rappel)` : le tap sur le bouton de la carte appelle `rappel` ; sans rappel, bouton absent.
- **Recouvrement, rendu réel de la colonne à cinq boutons** (`map_entry_buttons_overlap_test.dart` ; `F10b` n'a vérifié au lot 4 qu'un rectangle réservé) — `MapView` complet, `onOpenFavorites` posé, rectangles lus par `tester.getRect` : le rectangle qui englobe les cinq boutons (« Favoris », « Filtres », `+`, `−`, recentrer) n'a **aucune intersection** avec (1) la légende, (2) le bouton de désignation et son indice, mode « Restrictions » allumé, (3) l'attribution IGN, (4) un panneau de fiche injecté (`stationSheet`, puis `ondeSheet`, de la hauteur d'une fiche `Prete`). Configurations **bloquantes** : **Windows 800 × 740, échelle écoulement puis échelle débit** (`testWidgetsOnWindows`) ; **360 × 640, sur les deux échelles** (`testWidgetsOnAndroid`, titre « Android : … »). Chaque assertion porte les deux rectangles dans son `reason`.
- **640 × 360 (téléphone couché, `testWidgetsOnAndroid`, titre « Android : 640 × 360, mesure »)** : mêmes rectangles **mesurés et imprimés** (`printOnFailure` et recopie dans le rapport) ; le cas n'affirme que l'absence d'exception de rendu. Un recouvrement y est un **constat remonté à la boucle principale**, il ne bloque pas la tâche.
- Les tests existants de `map_entry_buttons_test.dart` et de la carte restent verts ; `layers_test.dart` vert.

**Document** — `docs/04-ui.md` : le croquis du groupe du bas à droite (posé au lot 4) reçoit le bouton « Favoris », au-dessus de « Filtres ».

- [ ] **Étape 1** — tests rouges ; `flutter test test/features/map/view/map_entry_buttons_test.dart test/features/map/view/map_view_test.dart test/features/map/view/map_entry_buttons_overlap_test.dart` → échec, sortie recopiée.
- [ ] **Étape 2** — implémenter le bouton et les trois passages de rappel.
- [ ] **Étape 3 — mesure de recouvrement.** ⚠️ **Si un cas reste rouge à 800 × 740 (Windows) ou à 360 × 640 (Android) une fois le bouton en place : ARRÊT.** Rien n'est corrigé — ni marge, ni taille, ni disposition, ni attente du test. L'agent rend, pour chaque cas rouge, la configuration et les deux rectangles mesurés ; la boucle principale décide (constat (f) de § 9 du cadrage). **À 640 × 360** : recopier les rectangles mesurés dans le rapport et dans le message de commit, recouvrement ou non — c'est un constat, pas un arrêt.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/features/map/view/map_entry_buttons.dart test/features/map/view/map_entry_buttons_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_entry_buttons_overlap_test.dart docs/04-ui.md && git commit -m "feat(map): bouton Favoris dans le groupe d'entrée de la carte (S10 de T3)" -m "Second bouton du groupe du bas à droite, au-dessus de Filtres (arbitrage 8), avant lui à la tabulation. La carte rend un rappel injecté et ignore qui l'écoute. La colonne compte désormais cinq boutons : son rendu réel est mesuré contre la légende, le bouton de désignation, l'attribution et un panneau de fiche — aucun recouvrement à 800 x 740 sous Windows ni à 360 x 640 sous Android ; à 640 x 360, constat : <recopier les rectangles mesurés>. Commentaire de MapView corrigé : une fiche ONDE peut désormais s'ouvrir sur l'échelle débit, depuis un favori." -- lib/features/map/view/map_entry_buttons.dart test/features/map/view/map_entry_buttons_test.dart lib/features/map/view/map_view.dart test/features/map/view/map_view_test.dart test/features/map/view/map_entry_buttons_overlap_test.dart docs/04-ui.md
```

### Task S11 : La route « Favoris » dans la racine, et son test

**Agent :** **raisonnement** (racine de composition : un écran, trois injections, une règle d'exclusivité).
**Files:** modifiés `lib/main.dart`, `test/main_test.dart`, `docs/acceptance/favoris.feature`, `test/project/acceptance_features_test.dart`, `docs/use-cases/UC-008-suivre-un-lieu-en-favori.md`, `CLAUDE.md`, `docs/project-state.md`
**Prérequis :** `S7a`, `S7b`, `S9`, `S10` (donc les lots 3 et 4 : `MapViewModel.applyFilter`, `MapViewModel.filter`, bouton « Filtres »).

**Existant, lu** — `MartinPecheurApp({required this.warningsViewModel, required this.mapViewModel, required this.stationSheetViewModel, required this.ondeSheetViewModel, required this.restrictionsViewModel, this.fluidityProbe, this.fluidityStationPoints, super.key})` (`lib/main.dart:174-183`) ; tap d'un marqueur : `onStationTap` ferme la fiche ONDE puis `unawaited(stationSheetViewModel.open(code))` (l. 253-256), `onOndeTap` symétrique (l. 273-276) ; désignation : ferme les deux fiches (l. 300-302), **garde contre une seconde route** (`screenOpen`, l. 308-313), état montré retenu pendant la sortie de la route (`shownState`, `leaving`, l. 324-327 et l. 364-367), puis `Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: … ListenableBuilder(listenable: restrictionsViewModel, …)))` (l. 328-363).

**Câblage**
- `MartinPecheurApp` gagne `required this.favoritesViewModel` (`final FavoritesViewModel favoritesViewModel;`) ; `main()` : `favoritesViewModel: FavoritesViewModel(favorites: favorites)`, **la même instance de dépôt** que les deux fiches.
- `MapView(onOpenFavorites: …)` : ferme les deux fiches (`stationSheetViewModel.close(); ondeSheetViewModel.close();`) ; **garde** : `final bool screenOpen = favoritesViewModel.state is! FavorisFermes;` lu **avant** `unawaited(favoritesViewModel.load());`, puis `if (screenOpen) return;` — une seule route « Favoris » à la fois (décision de la boucle principale du 2026-10-12, précédent `main.dart:308-313`) ; puis pousse `MaterialPageRoute<void>` dont le constructeur rend `ListenableBuilder(listenable: favoritesViewModel, builder: … FavoritesScreen(state: favoritesViewModel.state, busy: favoritesViewModel.busy, writeFailed: favoritesViewModel.writeFailed, onRemove: (Favorite f) => unawaited(favoritesViewModel.remove(f)), onStartOver: () => unawaited(favoritesViewModel.startOver()), onOpen: …))`. Au retrait de la route (`.then`) : `leaving = true; favoritesViewModel.close();`, et la route garde ce qu'elle montrait (`shownState`, `busy`, `writeFailed` retenus tant que `leaving` est faux) — même construction que la route des restrictions, pour qu'elle ne se vide pas pendant son animation de sortie.
- `onOpen` : retire la route (`Navigator.of(<contexte de la route>).pop()`), puis, par `switch` exhaustif : `StationFavorite(:final StationCode code)` → `ondeSheetViewModel.close(); unawaited(stationSheetViewModel.open(code));` ; `OndePointFavorite(:final OndePoint point)` → `stationSheetViewModel.close(); unawaited(ondeSheetViewModel.open(point));` ; `UnreadableFavorite()` → rien. **Aucun appel à `mapViewModel`** : ni caméra, ni échelle (arbitrage 6).
- `test/main_test.dart` : `_app` accepte aussi `FavoritesViewModel? favoritesViewModel` et `MapViewModel? mapViewModel` ; par défaut les trois ViewModels de favoris partagent **un** `InMemoryFavoriteRepository`.

**Cas de test** — groupe `'ecran des favoris (S11)'`, usager acquitté, `testWidgetsOnWindows`
- Au lancement : le bouton `mapFavoritesButtonKey` est là, `FavoritesScreen` absent.
- **Ouvrir « Favoris » ferme les fiches** : fiche station ouverte (`stationSheetViewModel.open`, état `Introuvable` avec les dépôts vides) → tap sur le bouton → `FavoritesScreen` trouvé, `stationSheetViewModel.state is Fermee` ; même cas avec la fiche ONDE → `OndeSheetFermee` (critère 9, R8).
- L'ouverture relit : `InMemoryFavoriteRepository.readCalls` augmente de 1 à chaque ouverture ; un favori ajouté entre deux ouvertures apparaît à la seconde.
- **Deux appels de `onOpenFavorites` dans la même trame** (`tester.widget<MapView>(find.byType(MapView)).onOpenFavorites!()` deux fois, puis `pumpAndSettle`) → `find.byType(FavoritesScreen)` rend **un seul** widget, et **un seul** `tester.pageBack()` revient à la carte (`FavoritesScreen` absent, `MapView` visible).
- Retrait de la route : `favoritesViewModel.state is FavorisFermes` ; pendant l'animation de sortie (un `pump` de 50 ms après `pageBack`) la liste est encore à l'écran, non vidée ; rouvrir ensuite → une route, liste relue.
- Dépôt vide → `favoritesEmptyText` à l'écran ; `tester.pageBack()` puis, de nouveau, `Échap` → route retirée, `MapView` visible.
- **Ouvrir un favori station** : tap sur sa ligne → `FavoritesScreen` absent après `pumpAndSettle`, `stationSheetViewModel.state` porte le code `K447001001`, la fiche ONDE est `OndeSheetFermee` (critère 8).
- **Ouvrir un favori ONDE alors que l'échelle est le débit** : `mapViewModel.selectScale(MapScaleKind.debit)` avant l'ouverture ; tap sur la ligne du point → `ondeSheetViewModel.state` porte **ce** point (code verbatim), `mapViewModel.scale == MapScaleKind.debit`, `mapViewModel.zoom` égal à sa valeur d'avant, la fiche station est `Fermee`.
- Une fiche ONDE ouverte, puis « Favoris », puis un favori **station** : seule la fiche station est ouverte.
- Retirer un favori depuis la liste : la ligne disparaît, le dépôt ne le porte plus, la route reste ; retrait en échec (`writeError`) → « Le favori n'a pas pu être retiré. », la ligne reste.
- Liste illisible (`readError`) : `favoritesUnreadableText` ; « Repartir d'une liste vide » → `favoritesEmptyText` ; en échec (`writeError`) → « La liste n'a pas pu être remplacée. », l'avis de liste illisible reste.
- Bout en bout : étoile d'une fiche station `Prete` → fermer la fiche → « Favoris » → la ligne « La Loire à Blois » est là (critères 1 et 6, à la persistance près : `S3`).
- **Le filtre survit à l'aller-retour** (cadrage § 6.6) : filtre `assec: false` appliqué par `mapViewModel.applyFilter`, ouvrir « Favoris », `tester.pageBack()` puis `pumpAndSettle` → `mapViewModel.filter` égal au filtre appliqué, et le bouton « Filtres » (`mapFiltersButtonKey`) toujours en forme active (signatures de `MapFilter`, `applyFilter` et de la forme active : à relire dans le code des lots 2 à 4).
- L'acquittement garde toujours tout : usager non acquitté → ni `MapView`, ni bouton « Favoris ».
- `restriction_source_test.dart` et `layers_test.dart` verts : `main.dart` reste le seul fichier hors `lib/data/` à nommer `SharedPreferencesFavoriteRepository`.

**Documents (même commit)**
- `docs/acceptance/favoris.feature`, **ajoutés tels quels à la suite** des scénarios de `S9` (critères 6, 8, 9 ; le fichier porte alors ses **quatorze** scénarios) :

```gherkin
  # ── US-14 — retrouver et ouvrir un favori ────────────────────────────────

  Scénario: Après relancement, la liste est celle d'avant
    Étant donné deux favoris enregistrés et une entrée non lisible
    Quand l'usager ferme l'application, la relance et active le bouton « Favoris » de la carte
    Alors la liste montre les mêmes lieux, dans le même ordre, entrée non lisible comprise (BR-011)

  Scénario: Ouvrir un favori ouvre sa fiche sans déplacer la carte
    Étant donné un point ONDE en favori et la carte sur l'échelle débit
    Quand l'usager choisit ce favori dans la liste
    Alors la fiche du point s'ouvre, avec la date et la source de son observation (BR-001)
    Et la carte n'a pas bougé et l'échelle affichée reste le débit

  Scénario: Ouvrir l'écran des favoris ferme la fiche ouverte
    Étant donné une fiche station ouverte sur la carte
    Quand l'usager active le bouton « Favoris » de la carte
    Alors la fiche est fermée et l'écran des favoris s'affiche
    Et aucune valeur mesurée n'y apparaît : elle ne se lit que sur une fiche, avec sa date (BR-001)
```

- `test/project/acceptance_features_test.dart` : import de `package:martinpecheur/features/map/view/map_entry_buttons.dart` ; la table `libellesFavoris` gagne `mapFavoritesLabel` (`_containsQuoted`) ; le test « favoris.feature met en scénarios US-14 » exige désormais **14** scénarios sous `US-14`.
- `UC-008` : marques 🔄 levées, déclencheur « ou ouvre un favori depuis la liste ».
- `CLAUDE.md` : arborescence (`domain/favorites/`, `data/preferences/`, `features/favorites/{view,view_model}/`), ligne « Stockage local » (favoris en `shared_preferences`, `ADR-011` amendé), ligne « Gestion d'état » (`FavoritesViewModel`). `docs/project-state.md` : ligne T3. **`CHANGELOG.md` n'est touché par aucune tâche `S`** (c'est `X3`, au lot 9, qui écrit « Ajouté »).
- Le commentaire de `lib/main.dart:246-252` (« Cette garantie n'est, elle, pas verrouillée par un test ») est corrigé : elle l'est désormais pour l'ouverture d'un favori.

- [ ] **Étape 1** — tests rouges ; `flutter test test/main_test.dart test/project/acceptance_features_test.dart` → échec, sortie recopiée.
- [ ] **Étape 2** — câbler, écrire les documents.
- [ ] **Étape 3 — contre-épreuves** : retirer les deux `close()` de fiche de `onOpenFavorites` → le cas « Ouvrir « Favoris » ferme les fiches » rougit ; retirer la garde `screenOpen` → le cas « Deux appels dans la même trame » rougit ; rétablir → vert. Recopier les deux rouges.
- [ ] **Étape 4** — critère de fin, commit.

```bash
git add -- lib/main.dart test/main_test.dart docs/acceptance/favoris.feature test/project/acceptance_features_test.dart docs/use-cases/UC-008-suivre-un-lieu-en-favori.md CLAUDE.md docs/project-state.md && git commit -m "feat(ui): la route Favoris dans la racine, et ouvrir un favori (S11 de T3)" -m "L'écran est une route poussée par main.dart, comme les restrictions. L'ouvrir ferme les deux fiches et relit le dépôt ; une garde empêche d'en empiler deux, et son retrait ferme le ViewModel. Ouvrir un favori retire la route, ferme l'autre fiche et ouvre la bonne, par le chemin d'un tap de marqueur : la carte ne bouge pas, l'échelle et le filtre ne changent pas (arbitrage 6), une fiche ONDE peut donc s'ouvrir sur l'échelle débit. Ces règles vivent dans la racine : un test de la racine les verrouille. favoris.feature porte ses quatorze scénarios. Contre-épreuves : <recopier les deux rouges>." -- lib/main.dart test/main_test.dart docs/acceptance/favoris.feature test/project/acceptance_features_test.dart docs/use-cases/UC-008-suivre-un-lieu-en-favori.md CLAUDE.md docs/project-state.md
```

---

## Lot 8 — Dette 2 : les décisions métier sortent de la vue des restrictions

> **Aucun changement de comportement.** Les tests d'écran sous `test/features/restrictions/` sont le filet : ce lot ne les modifie pas (`git diff --stat -- test/features/restrictions` reste vide d'un bout à l'autre). Il suit le lot 1, qui les a migrés de plateforme.
>
> **Place dans l'exécution : `R1 → R2 → R3` en série, entre `F10c` et `S1`.** Ce lot n'est **pas** indépendant : il ne tourne **jamais en même temps** que `F1`, `F2`, `S1` (même `typesDuDomaine`, même `docs/domain-model.md`) ni que `C1`, `S11` (`CLAUDE.md`, `docs/project-state.md`).
>
> **Qui appelle quoi — tranché.** La vue lit le domaine ; `RestrictionsViewModel` ne change pas. Motifs : (1) les quatre décisions sont des fonctions pures de la réponse (`ZonesAtPoint`), pas de l'état de l'écran — ni le profil, ni le lien non ouvert n'y entrent ; (2) le précédent est celui-là : la partition `surfaceWaterZones` / `otherZones` vit sur `ZonesAtPoint` « et non dans un ViewModel » (`zones_at_point.dart:6-10`), et le ViewModel écrit « ce ViewModel ne filtre pas, la vue appelle `AlertZone.usagesFor` » (`restrictions_view_model.dart:69-70`) ; (3) `RestrictionsScreen` reçoit un `RestrictionsState` (`restrictions_screen.dart:113-126`), que les tests d'écran construisent à la main (`ZonesTrouvees(zones)`) : faire porter les résultats par l'état obligerait à les modifier. `ADR-014` est tenu : la vue affiche ce que le domaine a décidé, elle ne décide plus.

### Task R1 : `DecreeDocument` — dédoublonnage des arrêtés, « mêmes zones », dates communes

**Agent :** **raisonnement** (transcription à conditions exactes).
**Files:** créés `lib/domain/restrictions/decree_documents.dart`, `test/domain/restrictions/decree_documents_test.dart` · modifiés `docs/domain-model.md` (contexte Restrictions), `test/project/domain_model_doc_test.dart` (`typesDuDomaine` + `'DecreeDocument'`)

**Code d'origine, lu le 2026-10-12, à transcrire sans écart** (`lib/features/restrictions/view/restrictions_screen.dart`, **non modifié par cette tâche**) :
- `_decreeEntries(List<AlertZone> zones)`, l. 1060-1086 : deux `Map<String, _DecreeEntry>` (`decrees`, `frameworks`) ; pour chaque zone, dans l'ordre : si `zone.decree.document != null`, `decrees.putIfAbsent(document.raw, () => entrée(isFramework: false, link: document)).zones.add(zone)` ; si `zone.decree.frameworkDocument != null`, de même dans `frameworks` avec `isFramework: true` ; rendu `[...decrees.values, ...frameworks.values]`. Clé : `DocumentLink.raw` **exact**, aucune normalisation.
- `_isSameZonesAsDecree(entry, all)`, l. 1094-1109 : `false` si `!entry.isFramework` ; `restrictions = all.where((o) => !o.isFramework)` ; `false` si `restrictions.length != 1` ; sinon `only.zones.length == entry.zones.length && entry.zones.every((zone) => only.zones.any((o) => identical(o, zone)))`.
- `_validityLine(zones)`, l. 1114-1129, partie décision : `first = zones.first.decree` ; `shared = zones.every((z) => z.decree.validFrom == first.validFrom && z.decree.validUntil == first.validUntil)` ; non partagées → `null`. La mise en phrase (« Depuis le … », « Du … au … ») **reste dans la vue**.

**Signatures** — `lib/domain/restrictions/decree_documents.dart`, Dart pur, seul import `alert_zone.dart` :

```dart
/// Un document distinct cité par les zones d'un point : son rôle, son
/// adresse telle que reçue, et les zones qui le citent.
final class DecreeDocument {
  DecreeDocument._({
    required this.isFramework,
    required this.link,
    required List<AlertZone> zones,
  }) : zones = List<AlertZone>.unmodifiable(zones);

  /// Vrai pour un arrêté-cadre, faux pour un arrêté de restriction.
  final bool isFramework;
  final DocumentLink link;

  /// Les zones qui citent ce document, dans l'ordre reçu. Jamais vide.
  final List<AlertZone> zones;

  /// Les dates de validité si TOUTES les zones les partagent, sinon `null` :
  /// rien n'est choisi à la place d'un désaccord de la source.
  ({DateTime validFrom, DateTime? validUntil})? get sharedValidity;
}

/// Arrêtés de restriction puis arrêtés-cadres, chacun une fois par adresse
/// EXACTE et par rôle, dans l'ordre de première citation.
List<DecreeDocument> decreeDocumentsOf(List<AlertZone> zones);

/// Vrai si [document] est un arrêté-cadre dont les zones sont exactement
/// celles de l'UNIQUE arrêté de restriction de [all].
bool coversSameZonesAsSoleRestrictionDecree(
  DecreeDocument document,
  List<DecreeDocument> all,
);
```
Constructeur privé : un `DecreeDocument` ne naît que de `decreeDocumentsOf`, donc `zones` n'est jamais vide et `sharedValidity` n'a pas de cas « liste vide ». `identical` est gardé tel quel. Liste rendue non modifiable. Pas d'`==` (rien ne compare deux documents : YAGNI).

**Cas de test** — `test/domain/restrictions/decree_documents_test.dart`, des `test(` purs ; zones construites à la main (`AlertZone(name:, kind: const EauxSuperficielles(), severity: const Alerte(), decree: RestrictionDecree(validFrom: DateTime.utc(2026, 8, 20), …), usages: const <RestrictedUsage>[])`) ; `D`, `E` adresses d'arrêté, `F`, `G` adresses de cadre.
1. `decreeDocumentsOf(<AlertZone>[])` → vide.
2. Une zone `z` (document `D`, cadre `F`) → deux documents : `(isFramework: false, link.raw: D, zones: [z])` puis `(true, F, [z])`.
3. Trois zones de même `D` et même `F` → deux documents, chacun avec les trois zones **dans l'ordre passé** (cas de l'Ain, `test/features/restrictions/zones_samples.dart` : `ainSou`, `ainSup`, `ainAep`).
4. `z1(doc E, cadre F)`, `z2(doc D, cadre G)`, `z3(doc E, cadre G)` → `[E{z1,z3}, D{z2}, F{z1}, G{z2,z3}]` : restrictions d'abord, ordre de première citation.
5. Adresses qui ne diffèrent que d'un caractère (`…/a.pdf` et `…/A.pdf` ; `…/a.pdf` et `…/a.pdf ` avec une espace finale) → deux documents distincts.
6. Zone sans `document` mais avec cadre `F` → un seul document, le cadre ; zone sans aucun des deux → aucun document.
7. La même adresse `D` citée comme arrêté par `z1` et comme cadre par `z2` (et par la même zone pour les deux rôles) → deux documents de rôles différents, même `link.raw`.
8. `zones` du document : `add` lève `UnsupportedError` ; la liste rendue par `decreeDocumentsOf` de même.
9. `sharedValidity` — une zone (du 2026-08-20 au 2026-10-31) → ce couple ; `validUntil` nul → `(validFrom, null)` ; deux zones aux mêmes dates → le couple ; `validFrom` différents → `null` ; `validUntil` l'un nul, l'autre non → `null` ; deux `validUntil` nuls et même `validFrom` → `(validFrom, null)`.
10. `coversSame…` — document de restriction → `false` ; cas 2 → `true` pour le cadre ; cas 3 (trois zones) → `true` ; cas 4 (deux arrêtés de restriction) → `false` pour `F` et pour `G` ; aucun arrêté de restriction (cas 6) → `false`.
11. `coversSame…`, un seul arrêté de restriction mais zones différentes — `z1(doc D, cadre F)`, `z2(doc D, sans cadre)` : `F{z1}` contre `D{z1,z2}` → `false` (moins de zones) ; `z1(doc D, cadre F)`, `z2(sans doc, cadre F)` : `F{z1,z2}` contre `D{z1}` → `false` (plus de zones) ; `z1(doc D, sans cadre)`, `z2(sans doc, cadre F)` : même nombre, zones différentes → `false`.
12. Deux zones **structurellement égales** (`==` vrai, instances distinctes), toutes deux `(doc D, cadre F)` → `D{a,b}`, `F{a,b}`, `coversSame…` vrai.

- [ ] **Étape 1** — tests rouges : `flutter test test/domain/restrictions/decree_documents_test.dart` → échec ; recopier.
- [ ] **Étape 2** — implémenter ; `domain-model.md` (une ligne : « `DecreeDocument` — un document distinct cité par les zones d'un point ; dédoublonnage par adresse exacte et par rôle, dates partagées ») et `typesDuDomaine`.
- [ ] **Étape 3** — `flutter test test/architecture` vert (`domaine-ferme`) ; critère de fin, commit.

```bash
git add -- lib/domain/restrictions/decree_documents.dart test/domain/restrictions/decree_documents_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart && git commit -m "feat(restrictions) : DecreeDocument, les documents distincts d un point décidés dans le domaine (R1 de T3)" -m "Dette 2 de T2, trois décisions sur quatre : dédoublonnage des arrêtés par adresse exacte et par rôle, arrêté-cadre aux mêmes zones que l unique arrêté de restriction, dates de validité partagées par toutes les zones. Conditions transcrites de restrictions_screen.dart sans écart ; la vue n est pas encore branchée (R3)." -- lib/domain/restrictions/decree_documents.dart test/domain/restrictions/decree_documents_test.dart docs/domain-model.md test/project/domain_model_doc_test.dart
```

### Task R2 : Le droit d'affirmer l'absence d'eaux superficielles, sur `ZonesAtPoint`

**Agent :** mécanique.
**Files:** modifiés `lib/domain/restrictions/zones_at_point.dart`, `test/domain/restrictions/zones_at_point_test.dart`, `docs/domain-model.md`

**Code d'origine, lu** (`restrictions_screen.dart:303-323`, non modifié ici) : `surface = zones.surfaceWaterZones` ; `others = zones.otherZones` ; `noSurfaceZone = surface.isEmpty && others.isNotEmpty` ; `surfaceAbsenceStated = noSurfaceZone && !others.any((AlertZone zone) => zone.kind is TypeZoneInconnu)`. Sens (arbitrages du 2026-10-06, `BR-011`) : d'une zone de type non reconnu, l'application ne sait pas ce qu'elle est ; elle n'affirme donc pas qu'aucune n'est d'eaux superficielles.

**Signatures** — deux membres de `ZonesAtPoint`, après `otherZones` (`zones_at_point.dart:74`) :

```dart
/// Vrai si le point porte des zones, dont aucune d'eaux superficielles.
bool get lacksSurfaceWaterZone;

/// Vrai si l'absence de zone d'eaux superficielles peut s'écrire : il y a
/// des zones, aucune n'est d'eaux superficielles, et aucune n'est de type
/// non reconnu (`BR-011`).
bool get canStateSurfaceWaterAbsence;
```

**Cas de test** — ajoutés à `zones_at_point_test.dart`, groupe « absence d'eaux superficielles » ; `SUP`, `SOU`, `AEP`, `X` = zones de type `EauxSuperficielles`, `EauxSouterraines`, `EauPotable`, `TypeZoneInconnu('X')`.

| `zones` | `lacksSurfaceWaterZone` | `canStateSurfaceWaterAbsence` |
|---|---|---|
| `[]` | faux | faux |
| `[SUP]` | faux | faux |
| `[SOU]` | vrai | vrai |
| `[AEP, SOU]` | vrai | vrai |
| `[SOU, X]` | vrai | **faux** |
| `[X]` | vrai | **faux** |
| `[TypeZoneInconnu(null)]` | vrai | **faux** |
| `[SUP, X]` | faux | faux |
| `[SOU, SUP]` | faux | faux |

- [ ] **Étape 1** — tests rouges, recopier · **Étape 2** — implémenter, une phrase dans `domain-model.md` · **Étape 3** — critère de fin, commit.

```bash
git add -- lib/domain/restrictions/zones_at_point.dart test/domain/restrictions/zones_at_point_test.dart docs/domain-model.md && git commit -m "feat(restrictions) : ZonesAtPoint dit si l absence d eaux superficielles peut s écrire (R2 de T3)" -m "Dette 2 de T2, quatrième décision : des zones, aucune d eaux superficielles, aucune de type non reconnu (BR-011). Conditions transcrites de restrictions_screen.dart ; la vue n est pas encore branchée (R3)." -- lib/domain/restrictions/zones_at_point.dart test/domain/restrictions/zones_at_point_test.dart docs/domain-model.md
```

### Task R3 : Brancher la vue sur le domaine, retirer ses quatre décisions

**Agent :** **raisonnement** (refonte à comportement verrouillé).
**Files:** modifiés `lib/features/restrictions/view/restrictions_screen.dart`, `docs/project-state.md` (point 59, (5) : « décisions métier dans la vue » soldée ; point 57 s'il y renvoie), `CLAUDE.md` (disposition : `domain/restrictions/` porte `decree_documents.dart`) · **non modifiés :** tout `test/features/restrictions/**`, `lib/features/restrictions/view_model/restrictions_view_model.dart`

**Ce qui change dans `restrictions_screen.dart`** (lignes lues le 2026-10-12 ; `B1` a retiré environ 37 lignes plus haut : retrouver par nom) :
- import ajouté : `package:martinpecheur/domain/restrictions/decree_documents.dart`.
- `_zonesContent` (l. 302-323) : `final List<DecreeDocument> decrees = decreeDocumentsOf(ordered);` · `final bool noSurfaceZone = zones.lacksSurfaceWaterZone;` · `final bool surfaceAbsenceStated = zones.canStateSurfaceWaterAbsence;` — les commentaires d'arbitrage (l. 309-320) restent, sans la condition.
- l. 365-371 : `for (final DecreeDocument entry in decrees)` · `sameZonesAsDecree: coversSameZonesAsSoleRestrictionDecree(entry, decrees)`.
- **supprimés** : `_DecreeEntry` (l. 1050-1056), `_decreeEntries` (l. 1060-1086), `_isSameZonesAsDecree` (l. 1094-1109).
- `_validityLine` (l. 1114-1129) devient `String? _validityLine(DecreeDocument document)` : `final validity = document.sharedValidity; if (validity == null) return null;` puis les deux phrases d'origine, inchangées. Son appel (l. 1167) : `framework ? null : _validityLine(entry)`.
- `_DecreeBlock.entry` (l. 1155) : type `DecreeDocument`.
- en-tête, l. 28-33 : « La vue dedoublonne l'AFFICHAGE… ecart connu… point 57 » remplacé par : le domaine décide (`decreeDocumentsOf`, `coversSameZonesAsSoleRestrictionDecree`, `DecreeDocument.sharedValidity`, `ZonesAtPoint.canStateSurfaceWaterAbsence`), la vue met en phrases.

**Vérifications**
- `grep -n -E "_DecreeEntry|_decreeEntries|_isSameZonesAsDecree|TypeZoneInconnu|identical\(" lib/features/restrictions/view/restrictions_screen.dart` → **vide**.
- `git diff --stat -- test/features/restrictions lib/features/restrictions/view_model` → **vide**.
- `flutter test test/features/restrictions test/main_test.dart` : **même total qu'avant la tâche**, à recopier avant et après.

- [ ] **Étape 1** — relever le total de `flutter test test/features/restrictions test/main_test.dart` ; brancher, supprimer.
- [ ] **Étape 2 — contre-épreuve du filet**, quatre mutations dans le domaine, une à la fois, chacune défaite : (a) `decreeDocumentsOf` indexe par `raw.toLowerCase()` ; (b) `restrictions.length != 1` devient `restrictions.isEmpty` ; (c) `sharedValidity` ne compare plus `validUntil` ; (d) `canStateSurfaceWaterAbsence` rend `lacksSurfaceWaterZone`. Pour chacune, lancer `flutter test test/domain/restrictions test/features/restrictions` et **recopier quels tests rougissent, domaine et écran**. Une mutation qu'aucun test d'écran n'attrape est un trou du filet : le dire dans le message de commit et dans « À valider », sans écrire de test d'écran dans cette tâche.
- [ ] **Étape 3** — documents, critère de fin, commit.

```bash
git add -- lib/features/restrictions/view/restrictions_screen.dart docs/project-state.md CLAUDE.md && git commit -m "refactor(restrictions) : la vue lit les décisions du domaine, elle n en prend plus (R3 de T3)" -m "Dette 2 de T2 soldée, sans changement de comportement : dédoublonnage des arrêtés, mêmes zones, dates communes et droit d affirmer l absence d eaux superficielles viennent de lib/domain/restrictions ; la vue ne garde que la mise en phrases. Tests d écran et ViewModel inchangés (git diff vide). Contre-épreuve, quatre mutations : <recopier, pour chacune, les tests rouges du domaine et de l écran>." -- lib/features/restrictions/view/restrictions_screen.dart docs/project-state.md CLAUDE.md
```

---

## Lot 9 — Finitions : clavier, cibles, recouvrements, documents

> Ce lot suit les lots 4, 7 et 8. Tâches citées : `F9` (feuille), `F10a` (`MapRoundButton`, `MapEntryButtons`), `F10b` (branchement, tabulation), `F10c` (mesure anticipée du rectangle réservé), `S4` (étoile), `S7a` (étoile dans les panneaux, câblage), `S9` (écran), `S10` (bouton « Favoris », rendu à cinq boutons). **Noms livrés par les lots 4, 6 et 7, à relire dans le code avant d'écrire** (un écart avec cette liste se signale, il ne se devine pas) :
>
> | Pièce | Type, fichier | Clés et libellés |
> |---|---|---|
> | Groupe du bas à droite | `MapEntryButtons` (`lib/features/map/view/map_entry_buttons.dart`), bâti sur `MapRoundButton` (`map_round_button.dart`) ; ordre de tabulation `mapTraversalOrderEntryButtons` (`map_view.dart`) | `mapFavoritesButtonKey` (« Favoris »), `mapFiltersButtonKey` (`mapFiltersLabel` « Filtres », `mapFiltersActiveLabel` « Filtres — un filtre est actif »), `mapFiltersActiveMarkKey` |
> | Feuille « Filtres » | `MapFilterSheet` (`lib/features/map/view/map_filter_sheet.dart`), un `Dialog` | `mapFilterSheetKey`, `mapFilterCategoryKey(FlowCategory)`, `mapFilterDepartementKey`, `mapFilterFreshnessKey(DischargeFreshnessCriterion)`, `mapFilterClearKey` (« Effacer »), `mapFilterCloseKey` (« Fermer », bouton visible, modèle : `lib/features/shared/warning_link.dart:193-198`), `mapFilterApplyKey` (« Appliquer ») |
> | Avis de carte vidée | `FilterHidesEverythingNotice` (`lib/features/map/view/map_empty_states.dart`) | `clearFiltersKey` (« Effacer les filtres ») |
> | Étoile | `FavoriteStarButton` (`lib/features/shared/favorite_star_button.dart`), état `FavoriteStar` (`filled`, `enabled` ; `lib/features/shared/favorite_star.dart`, Dart pur) | `favoriteStarButtonKey`, `addFavoriteLabel` « Ajouter aux favoris », `removeFavoriteLabel` « Retirer des favoris » |
> | Écran « Favoris » | `FavoritesScreen` (`lib/features/favorites/view/favorites_screen.dart`), sous `ScreenTitleBar` | ligne `ValueKey<String>('favorite-row-<i>')`, retrait `ValueKey<String>('favorite-remove-<i>')`, `favoritesStartOverButtonKey` (« Repartir d'une liste vide ») |
>
> Tout test nouveau est en `testWidgetsOnWindows` ou `testWidgetsOnAndroid` ; **tout cas dont la fenêtre fait moins de 600 px de large est en `testWidgetsOnAndroid`**, titre « Android : … ». Chaque tâche **ajoute les cas qui manquent** : un cas déjà écrit par les lots 4 à 7 se cite (`fichier:ligne`), il ne se recopie pas. Un comportement absent se corrige dans la vue de sa tranche, au plus court (`KeyboardFocusRing` de `lib/features/shared/keyboard_focus_ring.dart`, `minimumTapTarget` de `lib/features/shared/tap_target.dart`) ; ce qui demanderait de changer une disposition ou un ordre arbitré : **arrêt et question**.

### Task K1 : Clavier — Tab atteint, Entrée et Espace activent

**Agent :** **raisonnement**.
**Files:** modifiés `test/features/map/view/map_keyboard_test.dart`, `test/features/map/view/map_overlays_phone_test.dart`, `test/features/map/view/map_entry_buttons_test.dart`, `test/features/map/view/map_filter_sheet_test.dart`, `test/features/map/view/map_empty_states_test.dart`, `test/features/shared/favorite_star_button_test.dart`, `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/favorites/view/favorites_screen_test.dart` ; au besoin les vues correspondantes sous `lib/features/`

**Précédents, lus** — `map_keyboard_test.dart:426-470` : l'ordre de tabulation de `MapView` à 800 × 600 est une liste de `Finder` parcourue par `tester.sendKeyEvent(LogicalKeyboardKey.tab)`, avec un Tab de plus qui **reboucle** sur le premier arrêt ; `map_overlays_phone_test.dart:953-992` : la même épreuve sous 600 px. **Déjà écrit par les lots 4, 6 et 7, à citer et non à refaire** : `F10a` — Entrée et Espace sur « Filtres » ; `F10b` — « Filtres » dans l'ordre déclaré (puces → « Filtres » → `+` → `−` → recentrer → (désignation) → carte → fiche → « ⚠ Avertissement »), Échap qui ferme la feuille et rend le focus à « Filtres » ; `S10` — Tab atteint « Favoris » **avant** « Filtres », Entrée et Espace l'appellent ; `S4` — étoile `enabled: false` : ni tap, ni Entrée, ni Espace, **hors de l'ordre de tabulation** ; `S7a` — l'étoile dans les deux panneaux ; `F9` — fermer la feuille sans appliquer, **quatre** façons (`mapFilterCloseKey`, Échap, tap hors de la feuille, retour Android).

**Ordre confirmé par la boucle principale** : dans le groupe (`mapTraversalOrderEntryButtons`), « Favoris » puis « Filtres ».

**Cas de test** — n'écrire que ceux que la lecture des fichiers ci-dessus montre absents :
1. **Carte, les deux boutons ensemble** (`MapView` avec `onOpenFavorites` posé), disposition large (800 × 600, `testWidgetsOnWindows`) et compacte (360 × 640 et 390 × 844, `testWidgetsOnAndroid`), hors mode et en mode : ordre complet — puces (trois) → `mapFavoritesButtonKey` → `mapFiltersButtonKey` → `mapZoomInButtonKey` → `mapZoomOutButtonKey` → `mapRecenterButtonKey` → (`mapDesignateCenterButtonKey` en mode) → carte (large seulement) → `warningLinkKey`, puis le Tab de rebouclage revient à la première puce.
2. Un filtre actif : `mapFiltersButtonKey` garde son arrêt de tabulation ; son libellé sémantique vaut `mapFiltersActiveLabel`.
3. **Fiche station prête et fiche ONDE** (`StationSheetPanel`, `OndeSheetPanel`, étoile `enabled: true`) : Tab atteint `favoriteStarButtonKey` ; Entrée puis Espace appellent chacune `onToggleFavorite` une fois ; l'étoile et le bouton de fermeture du panneau sont deux arrêts distincts — écrire l'ordre qui est constaté entre eux.
4. **Étoile inactive dans une fiche** (`FavoriteStar(filled: …, enabled: false)`) : Tab passe de l'arrêt qui précède l'étoile à celui qui la suit, sans s'y arrêter.
5. **`MapFilterSheet` — un seul ordre de tabulation, celui de sa construction** : `mapFilterClearKey` → les six `mapFilterCategoryKey(…)` → `mapFilterDepartementKey` → les trois `mapFilterFreshnessKey(…)` → `mapFilterCloseKey` → `mapFilterApplyKey`. Sur l'échelle écoulement les trois arrêts de fraîcheur n'existent pas ; sur le débit, les six cases n'existent pas ; `departements: null` : aucun arrêt pour le département — l'ordre des arrêts restants ne change pas. Espace sur une case la décoche ; Entrée sur `mapFilterApplyKey` appelle `onApply` une fois ; Entrée sur `mapFilterCloseKey` ferme **sans** appeler `onApply` (critère 14 de `US-13`).
6. **Avis de carte vidée** : Tab atteint `clearFiltersKey`, Entrée appelle `onClearFilters` une fois ; sa place dans l'ordre de la carte est celle de l'action « Élargir la recherche » des autres avis.
7. **`FavoritesScreen`**, deux favoris : Tab atteint le retour (`BackButton` de `ScreenTitleBar`), puis `favorite-row-0`, `favorite-remove-0`, `favorite-row-1`, `favorite-remove-1` ; Entrée sur une ligne appelle `onOpen` avec ce favori, sur un retrait `onRemove` ; Échap retire la route ; le nœud de focus de l'écran n'est pas un arrêt (`skipTraversal`). Ligne `UnreadableFavorite` : pas d'arrêt d'ouverture, son retrait en est un. État illisible : Tab atteint `favoritesStartOverButtonKey`. `busy: true` : Entrée sur un retrait n'appelle rien.

- [ ] **Étape 1 — inventaire, sans rien écrire** : pour chacun des sept cas, ce qui est déjà couvert (`fichier:ligne`) et ce qui manque. **L'inventaire est rendu à la boucle principale et validé par elle avant l'étape 2.**
- [ ] **Étape 2** — écrire les cas manquants, recopier la sortie, rouge ou verte ; corriger au plus court ce qui est rouge ; arrêt si un ordre arbitré est en cause.
- [ ] **Étape 3** — critère de fin, **un commit par tranche**, par liste de chemins : (a) `map` — `test(map) : clavier de la carte, de la feuille Filtres et de l avis (K1 de T3)` ; (b) fiches et `shared` — `test(ui) : clavier de l étoile dans les deux fiches (K1 de T3)` ; (c) `favorites` — `test(ui) : clavier de l écran Favoris (K1 de T3)`. Corps de chacun : cas ajoutés, cas déjà couverts cités, corrections sous `lib/` une par une. Constat `i` de la porte : dû.

### Task K2 : Cibles — 44 sous Windows, 48 sous Android

**Agent :** mécanique.
**Files:** modifiés `test/features/shared/screen_layout_test.dart`, `test/features/shared/favorite_star_button_test.dart`, `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/map/view/map_entry_buttons_test.dart`, `test/features/map/view/map_filter_sheet_test.dart`, `test/features/map/view/map_empty_states_test.dart`, `test/features/favorites/view/favorites_screen_test.dart` ; au besoin les vues

**Règle, lue** — `lib/features/shared/tap_target.dart:29-33` : `minimumTapTargetFor(TargetPlatform.android)` vaut 48, toute autre plateforme 44 ; `minimumTapTarget` lit `defaultTargetPlatform`. **Déjà mesuré, à citer** : `mapFiltersButtonKey` 44 × 44 et 48 × 48 (`F10a`), `mapFavoritesButtonKey` de même (`S10`), dans `map_entry_buttons_test.dart`.

**Cas de test** — chaque contrôle est mesuré **deux fois** : `testWidgetsOnWindows`, largeur et hauteur `≥ 44` ; `testWidgetsOnAndroid`, `≥ 48`, titre « Android : … ». N'écrire que ce qui manque.
1. `ScreenTitleBar` : son `BackButton` sous Android (`screen_layout_test.dart` ; le cas Windows est de `B1`).
2. `FavoriteStarButton` seul, `filled` vrai et faux, `enabled` vrai et faux ; puis `favoriteStarButtonKey` **dans** `StationSheetPanel` et `OndeSheetPanel` (`S7a` ; le cadre du panneau ne l'écrase pas).
3. `mapFiltersButtonKey` dans sa forme active (`filterActive: true`) : même taille qu'inactive ; un tap sur `mapFiltersActiveMarkKey` atteint le bouton.
4. `MapFilterSheet` : chaque `mapFilterCategoryKey(…)`, `mapFilterDepartementKey`, chaque `mapFilterFreshnessKey(…)`, `mapFilterClearKey`, `mapFilterCloseKey`, `mapFilterApplyKey`.
5. `FilterHidesEverythingNotice` : `clearFiltersKey`.
6. `FavoritesScreen` : `favorite-row-0` (hauteur), `favorite-remove-0`, `favoritesStartOverButtonKey`.
7. Recherche d'un 44 ou d'un 48 écrit en dur, dans `lib/features/favorites/view/favorites_screen.dart`, `lib/features/shared/favorite_star_button.dart`, `lib/features/map/view/map_filter_sheet.dart`, `map_entry_buttons.dart` et `map_round_button.dart` (motif `[^0-9.]4[48][^0-9]`) : aucun qui serait une cible — recopier la sortie, justifier chaque ligne restante.

- [ ] Rouge ou vert constaté, corriger, critère de fin, commit : `test(ui) : cibles de 44 et de 48 sur les contrôles de T3 (K2 de T3)`.

### Task K3 : La colonne à cinq boutons — ce que `F10c` et `S10` n'ont pas mesuré

**Agent :** **raisonnement** (mesures, et tri entre invariant et constat).
**Files:** modifiés `test/features/map/view/map_view_test.dart`, `test/features/map/view/map_overlays_phone_test.dart`, `docs/04-ui.md` (colonne du bas à droite : mesures), `docs/project-state.md`

**Ce qui est mesuré** — la colonne du bas à droite : `MapEntryButtons` (« Favoris » au-dessus de « Filtres », `mapControlsSpacing` entre eux) au-dessus de `MapControls` (`+`, `−`, recentrer), `mapControlsSpacing` entre les deux groupes (`F10b` : `bottom` de « Filtres » + 8 == `top` de `+`). Hauteur attendue, **calculée dans le test, jamais en dur** : `5 × minimumTapTarget + 4 × mapControlsSpacing` (`mapControlsSpacing = 8`, `map_controls.dart:35`) — 252 sous Windows, 272 sous Android.

**La règle de la colonne, la même dans `F10c`, `S10` et `K3`** : un recouvrement à **800 × 740 (Windows)** ou à **360 × 640 (Android)** est un **arrêt** — recopier, s'arrêter, poser la question, ne rien réagencer. À **640 × 360** et **600 × 360** (paysage court), et à toute autre taille, un recouvrement est un **« CONSTAT »** : mesuré, écrit dans le test, **remonté au commanditaire, non bloquant**.

**Ce que `K3` ne refait pas** — déjà vérifié, à citer (`fichier:ligne`) dans le message de commit :
- `F10c` (lot 4) : `MapEntryButtons` ajouté aux pièces du groupe « 800 × 740 » de `map_view_test.dart` (l. 1202 à 1662) — dans l'écran, sans recouper légende, fiche, `DesignateCenterControl` ni `IgnAttributionBadge`, sur les deux échelles, avec et sans fiche, avec et sans désignation ; même vérification à 360 × 640 sous Android, 100 % puis 200 %. `F10c` a mesuré, par anticipation, un **rectangle réservé pour cinq boutons** alors que le groupe n'en portait qu'un ; `F10b` a vérifié que le haut de la carte (`WarningLink`, `MapScaleChips`, `MapLegend`) n'a pas bougé.
- `S10` (lot 7) : le **rendu réel à cinq boutons** — « Favoris » au-dessus de « Filtres », écart de 8, même abscisse — aux deux tailles d'arrêt, **et la mesure du paysage court (640 × 360, 600 × 360)**, consignée en « CONSTAT ». `K3` **ne remesure pas 640 × 360** : il cite la mesure de `S10` (`fichier:ligne`, valeur) dans `04-ui.md` et `project-state.md`.

`K3` commence par relancer ces deux séries et en recopier le résultat ; il n'en réécrit aucune.

**Cas de test ajoutés** — ce que ni `F10c` ni `S10` ne mesurent :
1. **Hauteur réelle de la colonne à cinq boutons** : du haut de `mapFavoritesButtonKey` au bas de `mapRecenterButtonKey`, égale à la formule à 0,5 px — `testWidgetsOnWindows` à 800 × 740, `testWidgetsOnAndroid` à 360 × 640.
2. **`testWidgetsOnAndroid`, 390 × 844**, 100 % et 200 %, hors mode et en mode, fiche de 320 px ouverte (`_ficheKey`, `map_overlays_phone_test.dart:112-113`) : la colonne recoupe-t-elle la fiche, `DesignateCenterControl`, `IgnAttributionBadge` ? `colonne.top ≥ 0` ? Invariant si rien ne se recoupe, « CONSTAT » sinon.
3. **Tailles intermédiaires de bureau** (`testWidgetsOnWindows`) : 800 × 700, 800 × 640, 700 × 740, 900 × 640 (celles de `map_overlays_phone_test.dart:1301-1305` et `map_view_test.dart:1529`), 100 % et 200 %, en mode, fiche ouverte : même mesure, même tri.
4. **200 %, 800 × 740, Windows** : la colonne garde sa hauteur (des icônes, pas du texte) ; `FilterHidesEverythingNotice` et `clearFiltersKey` sont entiers, dans l'écran et hors de la colonne (constat `d`). Taille d'arrêt : un recouvrement ici arrête la tâche.
5. **Les « CONSTAT » existants** de `map_overlays_phone_test.dart` (l. 1488, 1597, 1756, 1985, 2087) : si `F10c` ou `S10` en ont changé une valeur, vérifier que l'ancienne et la nouvelle sont dans leur message de commit ; sinon, les remesurer avec les cinq boutons et le dire ici.

- [ ] **Étape 1** — relancer les séries de `F10c` et de `S10`, recopier ; écrire les cas 1 à 5, lancer les deux fichiers, recopier la sortie brute.
- [ ] **Étape 2** — trier chaque rouge d'après la règle de la colonne : arrêt aux deux tailles d'arrêt, « CONSTAT » remonté ailleurs.
- [ ] **Étape 3** — `04-ui.md` et `project-state.md` : hauteurs mesurées, police de mesure (Roboto ; Segoe UI non mesurée), la mesure du paysage court citée de `S10`, ce qui reste dû à l'écran (constat `f`). Critère de fin, commit : `test(map) : la colonne à cinq boutons mesurée à 390 × 844, à 200 % et aux tailles intermédiaires (K3 de T3)`.

### Task X1 : Complétude des documents de T3 ; `02`, `03`, `04`

**Agent :** mécanique, relu par un second agent.
**Files:** modifiés `docs/02-specifications.md`, `docs/03-conception.md`, `docs/04-ui.md` — **aucun des documents écrits par les lots 2 à 7 n'est réécrit ici**

**Étape 1 — vérifier, par recherche, que les lots 2 à 7 ont écrit leur part** (cadrage § 11). Recopier chaque sortie ; un manque **se remonte au lot qui le doit**, il ne se comble pas ici :

| Attendu | Commande | Vert si |
|---|---|---|
| `BR-007`, `BR-008`, `BR-009` amendées, textes de § 10.1 (a) mot pour mot | `grep -c "Filtre de l'usager (T3)" docs/br/BR-007-*.md` ; `grep -c "puces d'échelle" docs/br/BR-008-*.md` ; `grep -c "Sous un filtre (T3)" docs/br/BR-009-*.md` | ≥ 1, ≥ 2, ≥ 1 |
| deux cas d'usage nouveaux | `ls docs/use-cases/UC-007-*.md docs/use-cases/UC-008-*.md` | deux fichiers |
| `UC-001`, `UC-003`, `UC-004` amendés | `grep -l -i "filtre" docs/use-cases/UC-001-*.md` ; `grep -l -i "favori" docs/use-cases/UC-003-*.md docs/use-cases/UC-004-*.md` | trois fichiers |
| Gherkin | `ls docs/acceptance/filtres.feature docs/acceptance/favoris.feature` ; `grep -n "filtres.feature\|favoris.feature" test/project/acceptance_features_test.dart` | présents et listés |
| `ADR-011` amendé | `grep -n "2026-10" docs/adr/ADR-011-stockage-local.md` | un amendement daté qui nomme les favoris |
| domaine documenté | `grep -n "domain/filters\|domain/favorites\|MapFilter\|FavoriteRepository" docs/domain-model.md` ; `grep -n "\*\*Favori\*\*\|\*\*Filtre\*\*" docs/glossary.md` (forme des entrées : `| **Profil d'usager** | …`, `glossary.md:25`) | les deux dossiers, les deux entrées |
| croquis | `grep -n "Moins de 7 jours" docs/04-ui.md` | **vide** (arbitrage 4) |

**Étape 2 — ce qui reste de § 11**
- `02-specifications.md` (tableau `Should`, l. 104-111) : `US-11` et `US-16` — « tranche ultérieure, non nommée (arbitrage 1 du 2026-10-12) » ; `US-13` — note : « type de donnée » = l'échelle, choisie par les puces ; états sur l'écoulement seul ; fraîcheur sur le débit seul (2 h, 24 h, `BR-005`) ; `US-13` et `US-14` ✅ T3.
- `03-conception.md` : l. 33 (stockage : favoris en `shared_preferences`, une clé, JSON versionné ; moteur structuré ouvert jusqu'au hors-ligne) ; la ligne des tranches présentes (l. 51) : `favorites` ✅, `settings` hors T3 ; l. 100 (`Favori` : clé = couple (type, code), pas `CodeEntite` seul) ; § 5, arborescence (l. 169 « Filtres (feuille) : ~~type ·~~ état · département · fraîcheur », « Recherche » et « Courbe » : tranche ultérieure, « Favoris » ✅ T3). Ancien texte barré et daté, jamais effacé.
- `04-ui.md` : **seulement ce qui manque** après les lots 4 et 7 parmi — croquis « Filtres » corrigé (six cases cochées, « Appliquer » sans compteur, pas de groupe « Échelle affichée »), écran « Favoris » et ses états, groupe des deux boutons, avis de carte vidée, étoile des fiches (l. 277, 308, 323).

- [ ] Étape 1, étape 2, `flutter test test/project` vert, critère de fin, commit : `docs : spécifications, conception et croquis alignés sur T3 (X1 de T3)`.

### Task X2 : La matrice de traçabilité gagne une section `Should`

**Agent :** mécanique.
**Files:** modifiés `docs/tracabilite.md`, `test/project/tracabilite_test.dart`

**État de départ, lu** — `tracabilite_test.dart` : `_ucAttendus` (l. 49-56, six `UC`), `_usMustAttendues` (l. 60-71), groupe « Chaque UC-001 à UC-006 apparaît » (l. 280), `_lignesDuTableau` (l. 179-202, saute les lignes dont la première cellule vaut `US`), `_ligneDe` (l. 207), `_celluleFichier` (l. 219 : quatrième colonne pour un `US-`), « Chaque fichier de test cité existe » (l. 404, sur tous les tableaux). `tracabilite.md:20` ne suit que les `Must`.

**Cas de test** (rouges d'abord)
1. `_ucAttendus` gagne `UC-007` et `UC-008` ; le groupe est renommé « Chaque UC-001 à UC-008 apparaît au moins une fois ».
2. Nouvelle constante `_usShouldLivreesEnT3 = <String>['US-13', 'US-14']` et groupe « Les user stories Should livrées par T3 » : pour chacune, une ligne dont la première cellule est l'identifiant ; sa cellule « État » contient `✅ T3` et pas `🔄` ; sa cellule « Fichier de test » cite au moins un chemin `.dart`.
3. `_citationsExigees` gagne, chemins relevés dans les lots 2 à 7 :
   - `US-13` → `test/domain/filters/map_filter_test.dart`, `test/domain/filters/map_filter_predicates_test.dart`, `test/features/map/view_model/map_filter_scale_test.dart`, `test/features/map/view_model/map_view_model_filter_test.dart`, `test/features/map/view/map_filter_sheet_test.dart`, `test/features/map/view/map_entry_buttons_test.dart`, `test/features/map/view/map_filter_wiring_test.dart`, `test/features/map/view/map_empty_states_test.dart` ;
   - `US-14` → `test/domain/favorites/favorite_test.dart`, `test/domain/favorites/favorite_repository_test.dart`, `test/features/shared/favorite_star_test.dart` (`FavoriteStar` vit dans `lib/features/shared/favorite_star.dart`, Dart pur — chemin du test à confirmer par `ls`), `test/data/preferences/favorites_codec_test.dart`, `test/data/preferences/shared_preferences_favorite_repository_test.dart`, `test/features/shared/favorite_star_button_test.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart`, `test/features/favorites/view_model/favorites_view_model_test.dart`, `test/features/favorites/view/favorites_screen_test.dart`, `test/main_test.dart` (route « Favoris », critère 9) ;
   - `UC-007` → `test/domain/filters/map_filter_predicates_test.dart`, `test/features/map/view_model/map_view_model_filter_test.dart`, `test/features/map/view/map_filter_sheet_test.dart`, `test/features/map/view/map_filter_wiring_test.dart` ;
   - `UC-008` → `test/data/preferences/shared_preferences_favorite_repository_test.dart`, `test/features/favorites/view_model/favorites_view_model_test.dart`, `test/features/favorites/view/favorites_screen_test.dart`, `test/main_test.dart` ;
   - `BR-007` → `test/features/map/view/map_empty_states_test.dart` (avis de carte vidée) et `test/features/favorites/view/favorites_screen_test.dart` (liste vide, liste illisible) ; `BR-008` → `test/features/map/view_model/map_filter_scale_test.dart` ; `BR-009` → `test/features/map/view_model/map_view_model_filter_test.dart` (pastilles sous filtre) ; `BR-011` → `test/data/preferences/favorites_codec_test.dart` (entrée non lisible gardée) et `test/domain/filters/map_filter_predicates_test.dart` (`Inconnu` suit « Non renseigné »).

   Les lignes `US-04`, `US-05`, `UC-003` et `UC-004` citent déjà les tests des deux fiches : l'étoile y est dite dans la cellule, sans chemin nouveau. Avant d'écrire, `ls` de chacun de ces chemins : un fichier absent ou renommé se signale (le test « chaque fichier cité existe » le refuserait).
4. Le commentaire l. 110-119 (« le moteur de stockage structuré qu'`ADR-011` laisse ouvert (T3) ») est corrigé : ouvert jusqu'au hors-ligne (arbitrage 2). `US-10` et `UC-005` **restent 🔄** (`_lignesPartielles` inchangée).

**Document** — `tracabilite.md` : en-tête (tâche `X2` du plan T3) ; nouvelle section `## User stories Should livrées (US-13, US-14)`, mêmes six colonnes ; lignes `UC-007` et `UC-008` dans le tableau des cas d'usage ; lignes `BR-007`, `BR-008`, `BR-009`, `BR-011` complétées ; « Ce que cette matrice ne prétend pas » : `US-11`, `US-12`, `US-15`, `US-16` non suivies ; constats d'écran de T3 dus à la porte.

- [ ] Rouge, écrire, critère de fin, commit : `docs : traçabilité de T3, section Should (X2 de T3)`.

### Task X3 : État du projet, `CLAUDE.md`, `README`, et « Ajouté » de `0.4.0` écrit en une fois

**Agent :** mécanique, relu par un second agent.
**Files:** modifiés `docs/project-state.md`, `CLAUDE.md`, `docs/README.md`, `CHANGELOG.md`, `test/project/changelog_test.dart`

> **Aucun lot n'a touché `CHANGELOG.md` depuis `O1`** (décision de la boucle principale) : la section `[0.4.0]` ne porte que son chapeau et « Non vérifié ». Cette tâche écrit « Ajouté » **en une fois, d'après ce qui est livré** — relu dans le code et dans `git log --oneline dev..HEAD`, pas d'après le cadrage : une ligne par changement visible pour l'usager, rien de ce qu'un lot n'a pas livré.

- **Cas de test** (`changelog_test.dart`, groupe `version 0.4.0`, rouges d'abord) — (1) « la sous-section Ajouté nomme ce que T3 livre » : `sousSection('Ajouté')` a des puces et contient `Favoris`, `Filtres`, `étoile`, `Effacer les filtres`, `Moins de 2 h`, `Moins de 24 h`, `Repartir d'une liste vide` ; (2) « Ajouté précède Non vérifié » : dans la section, `indexOf('### Ajouté') < indexOf('### Non vérifié')` ; (3) le chapeau ne contient plus `rien n'en est encore livré` ; il garde `Version ouverte`, `pas publiée`, `la porte de T2 reste due` (cas 4 de `O1`, inchangé).
- `CHANGELOG.md` `[0.4.0]` : `### Ajouté`, **avant** `### Non vérifié` — l'étoile des deux fiches (ajouter, retirer, ce qui ne peut pas l'être) ; l'écran « Favoris » (liste sans mesure, liste vide, liste illisible et « Repartir d'une liste vide », favori non lisible) ; les favoris retrouvés après relancement ; la feuille « Filtres » (états sur l'écoulement, département, fraîcheur du débit « Moins de 2 h » / « Moins de 24 h », ce que le filtre ne masque pas) ; le bouton « Filtres » qui montre un filtre actif ; l'avis de carte vidée et « Effacer les filtres » ; les deux boutons en bas à droite. **Les dettes 1, 2 et 3 n'y entrent pas** : un remaniement sans effet observable ne figure pas au journal (`CHANGELOG.md:8-10`). « Non vérifié » mis à jour, **et garde les mots `Android`, `porte de T3`, `écran de T3`** (cas 5 de `O1`, toujours exigé jusqu'à `P3`) : constats `c` à `l` dus à la porte, `a` et `b` datés d'après `C1`, les `💭` du cadrage (taille maximale d'une valeur `shared_preferences`, départements ONDE sans station de l'asset), lecteur d'écran, Segoe UI non mesurée, ce que `K3` a constaté en paysage court.
- `project-state.md` : ligne T3 (tâches closes sur total, lots clos, total de tests **recopié**), lien vers `docs/superpowers/plans/2026-10-12-t3-favoris-filtres-fraicheur.md` ; point 59 soldé pour (4) et (5) ; arborescence « telle qu'elle est sur cette branche » (`domain/filters`, `domain/favorites`, `data/preferences`, `features/favorites`, fichiers ajoutés à `features/map/view/` et à `features/shared/`) ; « Prochaine étape » : la porte.
- `CLAUDE.md` : ligne T3 ; invariants (`lib/features/shared/` : `favorite_star.dart`, `favorite_star_button.dart` et `ScreenTitleBar` ; règle de plateforme des tests) ; « Disposition du dépôt » ; lignes « Stockage local », « Gestion d'état » (`FavoritesViewModel`) et « Tests » du tableau « Stack ».
- `docs/README.md` : `UC-007`, `UC-008`, `filtres.feature`, `favoris.feature`, statut de `docs/superpowers/plans/2026-10-12-t3-favoris-filtres-fraicheur.md`.

- [ ] Rouge, écrire, critère de fin, commit : `docs : état du projet et journal de 0.4.0 écrits d après le code de T3 (X3 de T3)`.

---

## Lot 10 — La porte de T3, sur Windows **et** Android (arbitrage 7)

> Les constats `a` et `b` (écoulement) ont été faits plus tôt, par `C1` (lot 4) : la porte les **rappelle**, avec leur date, et ne les refait pas si plus aucun point ONDE n'est à l'écran (la carte ne charge que 60 jours, les campagnes s'arrêtent en septembre). Chaque constat se dicte par son identifiant et se **recopie mot pour mot**. Un constat manquant n'est pas un constat fait.

### Task P1 : L'exécutable Windows de `0.4.0`, lancé hors Flutter

**Files:** aucun code ; `docs/nfr.md`, `docs/project-state.md` à l'étape 5.

- [ ] **Étape 1 — Claude** : critère de fin sur le sommet de la branche ; recopier le total de tests.
- [ ] **Étape 2 — commanditaire** (jamais dans un tube) :

```bash
flutter build windows --release
```
Attendu : ligne finale `Built …` nommant le dossier sous `build\windows\`. **Recopier la ligne et la durée.**
- [ ] **Étape 3 — Claude** : `du -sh build/windows/x64/runner/Release && ls -1 build/windows/x64/runner/Release | wc -l` — poids **≤ 60 Mo** (`NFR-06` ; repère `0.2.0` : 33 Mo, 14 fichiers), et date de `martinpecheur.exe` postérieure à l'étape 2 (un exécutable de `0.2.0` daté du 2026-09-27 traîne sur un poste).
- [ ] **Étape 4 — commanditaire**, toute session de développement fermée :

```bash
./build/windows/x64/runner/Release/martinpecheur.exe
```
Attendu, **neuf constats à l'écran (cadrage § 9), ou la porte n'est pas franchie** :
  - `P1-c` — un filtre actif : le bouton « Filtres » se distingue sans la couleur, et reste distinct en dézoomant jusqu'aux pastilles de région.
  - `P1-d` — carte vidée par le filtre : l'avis « Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau. » et « Effacer les filtres » se voient sans défiler.
  - `P1-e` — débit, « Moins de 2 h » : les stations non chargées restent ; des marqueurs disparaissent un à un au fil du préchargement ; cela se comprend-il avec les deux phrases de la feuille ?
  - `P1-f` — à 800 × 740, la colonne de cinq boutons ne recouvre ni une fiche ouverte, ni le bouton de désignation (choix « Restrictions »), ni l'attribution. *(Si `S10` ou `K3` ont consigné un « CONSTAT » de recouvrement à une autre taille, le rappeler ici et demander au commanditaire de le regarder.)*
  - `P1-g` — ajouter une station et un point ONDE aux favoris, **fermer l'application, la relancer** : la liste les montre. *(Un point ONDE suppose qu'il en reste à l'écran : sinon, le dire, et ne constater que la station.)*
  - `P1-h` — ouvrir un favori : la fiche s'ouvre, la carte n'a pas bougé, l'échelle non plus.
  - `P1-i` — l'étoile se distingue, pleine et vide ; Tab l'atteint, Entrée la bascule.
  - `P1-j` — liste vide : « Aucun favori enregistré. L'étoile d'une fiche — station de mesure ou point d'observation — ajoute ce lieu à cette liste. » se lit ; rien ne suggère un état des cours d'eau.
  - `P1-k` — la barre de titre de « Sécheresse et restrictions » et de « D'où vient cette donnée ? » est inchangée à l'œil.
  - `P1-m` — **seulement si la décision 2 du commanditaire est A** (sinon : non demandé, et dit tel dans la consignation) : réseau coupé, la liste « Favoris » s'affiche ; ouvrir un favori station montre l'échec nommé ; l'étoile reste pleine et se retire.
  Rappel, non refait : `a` et `b`, constatés le <date consignée par `C1`>.
- [ ] **Étape 5** — consigner dans `docs/nfr.md` (`NFR-06` : poids et nombre de fichiers ; une ligne marquée d'une coche nomme ce qui l'a constatée, `test/project/nfr_doc_test.dart` l'exige) et dans `project-state.md`, constat par constat, mot pour mot ; commit `docs : constats de la porte de T3 sur Windows (P1 de T3)`.

### Task P2 : Android — première construction constatée, puis les écrans au toucher

**Files:** `docs/project-state.md`

> **Aucune construction Android n'a jamais été constatée sur ce projet sous Flutter** (`A1` de T2 reste due). Elle peut échouer pour des raisons sans rapport avec T3. Le bac à sable ne compile pas de natif : tout est lancé par le commanditaire.

- [ ] **Étape 1 — commanditaire**, un bloc à la fois :

```bash
flutter emulators --launch Pixel_7
```
Attendu : l'émulateur démarre (`adb devices` le voit `emulator-5554 device`).

```bash
flutter run -d emulator-5554
```
Attendu, **inconnu d'avance** : la construction Gradle aboutit (premier passage : téléchargements), l'application se lance en `0.4.0`.
  - `P2-l` — la construction aboutit et l'application s'ouvre : durée, dernière ligne de la construction, premier écran vu (le modal du premier lancement).
  - puis, **au toucher** : `P2-c`, `P2-d`, `P2-e`, `P2-g`, `P2-h`, `P2-j` — mêmes énoncés que `P1` ; `P2-f` — à la taille du téléphone, la colonne de cinq boutons (272 px) ne recouvre ni la fiche, ni le bouton de désignation, ni l'attribution ; `P2-i` — l'étoile se distingue, pleine et vide, et se touche sans viser (cible de 48). Pour `P2-g`, « fermer » veut dire retirer l'application des applications récentes, puis la rouvrir — pas un rechargement à chaud. `P2-m` — **seulement si la décision 2 du commanditaire est A** : mode avion de l'émulateur, mêmes trois points que `P1-m`.
- [ ] **Étape 2** — en cas d'échec de construction : recopier **verbatim** les 30 dernières lignes. **Aucun correctif dans cette tâche** : le diagnostic est une tâche à part ; trois échecs sur le même point → arrêt et question. La porte attend.
- [ ] **Étape 3** — consigner constat par constat, mot pour mot ; dire, sans la clore, ce que `P2-l` apporte à `A1` de T2 (la décision revient au commanditaire) ; commit `docs : constats de la porte de T3 sur Android (P2 de T3)`.

### Task P3 : Clore la version `0.4.0`

**Agent :** mécanique, relu par un second agent.
**Files:** `CHANGELOG.md`, `test/project/changelog_test.dart`, `docs/project-state.md`, `CLAUDE.md`

> **Préalable : `P1` et `P2` consignées.** Si un constat manque ou est négatif, **arrêt et question fermée au commanditaire** (attendre, recommandé ; dater sans la porte, en le disant — le précédent du 2026-10-09). On ne date pas de soi-même.

- [ ] **Étape 1** — tests rouges, groupe `version 0.4.0`. **Les cas 2 et 4 de `O1` sont remplacés** : le cas 2 par « la version 0.4.0 est datée » (`matches(RegExp(r'^## \[0\.4\.0\] — \d{4}-\d{2}-\d{2}$'))`, sans « à publier ») ; le cas 4 par « le chapeau de 0.4.0 ne dit plus qu'elle est ouverte » (ni `Version ouverte` ni `pas publiée` ; il dit si la porte de T3 est franchie, et sur quelles cibles). **Le cas 5 est réduit** à « Non vérifié a au moins une puce ». **Trois cas modifiés, à dire dans le message de commit.** Le cas (3) de `X3` (« le chapeau garde `Version ouverte`… ») tombe avec le cas 4. Cas ajoutés : « Constaté à l'exécution » existe, placée avant « Non vérifié », et porte une puce par constat rapporté, chacune datée et nommant sa cible (Windows, release ; Android, émulateur) ; « Non vérifié » reste non vide.
- [ ] **Étape 2** — dater du jour ; `### Constaté à l'exécution` : les constats de `P1` et `P2` **recopiés mot pour mot**, `a` et `b` avec la date de `C1`, le poids et le nombre de fichiers ; `### Non vérifié` : ce qui n'a pas été vu (lecteur d'écran, Segoe UI contre Roboto, les `💭` du cadrage), la porte de T2 si elle reste due (`E4`, `P1`, `P2` de T2), `A⏸3` à `A⏸5`, iOS jamais compilé. `project-state.md` et `CLAUDE.md` : ligne T3, porte franchie ou non, dite telle.
- [ ] **Étape 3** — critère de fin, commit `docs : version 0.4.0 datée d après les constats de la porte de T3 (P3 de T3)`, dont le corps nomme les trois cas de `O1` modifiés (2 et 4 remplacés, 5 réduit). **Aucun tag, aucune poussée, aucune fusion sans demande du commanditaire.** La mise en production reste sa décision.

---

## Décisions à valider avec le plan

### Au commanditaire

| # | Question | Options | Recommandation |
|---|---|---|---|
| 1 | Deux textes d'échec que § 10.1 du cadrage ne donne pas : retrait en échec, « Repartir d'une liste vide » en échec | **A.** « Le favori n'a pas pu être retiré. » et « La liste n'a pas pu être remplacée. » · B. réemployer « Le favori n'a pas pu être enregistré. » partout | **A** — B est inexact pour un retrait. Les tâches `S4`, `S7a` et `S9` portent A, marqué comme soumis à cette décision |
| 2 | Constat hors réseau à la porte, absent de § 9 du cadrage | **A.** un constat de plus, `P1-m` et `P2-m` : sans réseau, la liste « Favoris » s'affiche ; ouvrir un favori station montre l'échec nommé, l'étoile reste pleine et retirable · B. rien de plus | **A** — un geste de plus, sur ce que T3 a de propre : des favoris locaux. `P1` et `P2` portent le constat, à ne faire que si la réponse est A |
| 3 | Constats encore dus de T2 (`A1`, `E4`, les huit du point 48 de `project-state.md`) | **A.** faits dans les mêmes séances que `C1`, `P1` et `P2`, consignés sous T2, sans tâche dans ce plan · B. séances à part | **A** — l'application est déjà lancée ; `P2` sera de toute façon la première construction Android constatée |
| 4 | Où vit `FavoriteStar`, l'état d'affichage de l'étoile (pleine, active, écriture en échec), que deux ViewModels de fiche produisent | **A.** `lib/features/shared/favorite_star.dart`, Dart pur, sans import Flutter, à côté du widget `FavoriteStarButton` · B. `lib/domain/favorites/`, documenté dans `domain-model.md` · C. aucun type : quatre booléens par ViewModel | **A** — ce n'est pas du métier, donc pas du domaine ; `shared/` porte déjà ce que deux tranches partagent, et la règle `view-model-sans-widget` n'interdit que les imports de widgets. A étend l'amendement d'`ADR-014`, qui parle de « widgets » partagés : une phrase à y ajouter (`S4`) |

### Prises par la boucle principale, réversibles

| # | Décision | Tâche |
|---|---|---|
| a | Après une écriture en échec, le dépôt réécrit la valeur d'avant pour remettre le cache du paquet d'accord ; les opérations d'une instance sont sérialisées | `S3` |
| b | L'étoile est **absente**, et non inactive, quand rien ne peut être ajouté (station en chargement, en échec ou hors référentiel, pas en favori) ; elle est inactive pendant une écriture et sur liste illisible, sans phrase sur la fiche | `S5`, `S7a` |
| c | Date d'ajout stockée en UTC, affichée en date locale ; `add` insère en tête et ne change rien si le lieu y est déjà ; champs JSON en français | `S1`, `S2`, `S3` |
| d | Garde contre deux routes « Favoris » empilées : `FavoritesViewModel` porte un état « fermé », sur le précédent de l'écran des restrictions | `S8`, `S11` |
| e | « Effacer » de la feuille est immédiat : il applique « aucun filtre » et ferme | `F9` |
| f | Avis de carte vidée sur le débit sous le zoom 9 : la règle porte sur les stations lues sur l'emprise, pas sur l'absence de pastille (affinement de § 6.5 du cadrage) | `F7` |
| g | Filtre qui vide la carte et lignes ONDE illisibles : les deux avis s'affichent | `F8` |
| h | La feuille « Filtres » porte un bouton « Fermer » visible, sur le modèle de la fenêtre d'avertissement | `F9` |
| i | Forme active du bouton « Filtres » : icône pleine, fond plein, marque ronde au coin | `F10a` |
| j | Titres de section de la feuille repris du croquis de `04-ui.md` (« États », « Département », « Fraîcheur ») ; une option de département s'écrit avec le libellé tel que reçu de l'asset, en capitales, et son code | `F9` |
| k | Dette 2 : la vue appelle des fonctions pures du domaine ; `RestrictionsViewModel` ne change pas | `R1` à `R3` |
| l | Dette 1 : le verrou cherche le mot `testWidgets` sur toute ligne de code ; les goldens ne sont jamais régénérés | `N1`, `N3` |
| m | Le journal : `O1` ouvre `[0.4.0]`, `X3` écrit « Ajouté » en une fois | `O1`, `X3` |
| n | `UC-007` « Filtrer la carte », `UC-008` « Suivre un lieu en favori » | `F3`, `S7b` |
| o | Colonne à cinq boutons : arrêt sur un recouvrement à 800 × 740 (Windows) et à 360 × 640 (Android) ; à 640 × 360 un recouvrement est un constat remonté, il ne bloque pas | `F10c`, `S10`, `K3` |

**Conséquence connue de la dette 1 :** après la migration, presque tous les tests tournent sous Windows (cibles de 44). Une disposition qui déborderait avec des cibles de 48 à une taille de bureau n'est plus vue par un test ; `K2`, `K3` et le constat `P2` y reviennent, en partie.

---

## Récapitulatif

**48 tâches**, dont 3 lancées par le commanditaire (`C1`, `P1`, `P2`).

| Lot | Tâches | Contenu |
|---|---|---|
| 0 | `O1` | version `0.4.0` ouverte, faits du 2026-10-12 consignés |
| 1 | `N1`, `B1`, `N2` à `N9` | dette 1 (assistants, verrou, 29 fichiers migrés) ; dette 3 (barre de titre partagée) |
| 2 | `F1` à `F3` | filtres — domaine, règles métier amendées, `UC-007` |
| 3 | `F4` à `F7` | filtres — `MapViewModel` : filtre appliqué, pastilles, préchargement, carte vidée |
| 4 | `F8`, `F9`, `F10a`, `F10b`, `F10c`, `C1` | filtres — avis, feuille, bouton, mesure anticipée ; **constat anticipé sur l'écoulement** |
| 5 | `S1` à `S3` | favoris — domaine, forme stockée, dépôt, `ADR-011` amendé |
| 6 | `S4` à `S6`, `S7a`, `S7b` | favoris — étoile des deux fiches, dépôt câblé dans `main.dart`, Gherkin et `UC-008` |
| 7 | `S8` à `S11` | favoris — écran, bouton d'entrée, route et test de la racine |
| 8 | `R1` à `R3` | dette 2 (décisions sorties de la vue des restrictions) |
| 9 | `K1` à `K3`, `X1` à `X3` | clavier, cibles, recouvrements ; documents |
| 10 | `P1` à `P3` | porte sur Windows et Android, version datée |

## Ordre d'exécution

```
O1 → N1 → B1 → N2 → N3 → N4 → N5 → N6 → N7 → N8 → N9
          └→ F1 → F2 → F3 → F4 → F5 → F6 → F7
N9, F7 → F8 → F9 → F10a → F10b → C1 (commanditaire)
                           └→ F10c
F10c → R1 → R2 → R3 → S1 → S2 → S3 → S4 → S5 → S6 → S7a → S7b → S8 → S9 → S10 → S11
S11 → K1 → K2 → K3 → X1 → X2 → X3 → P1 → P2 → P3
```

- **`N2` à `N9` en série** : elles retirent chacune une entrée du même fichier de verrou.
- **`F1` à `F7` peuvent courir pendant les migrations** : domaine et `MapViewModel`, aucun test de widget, aucun fichier commun avec `N2` à `N9`. Un arrêt dans une migration ne gèle pas le chemin de `C1`. `F4` à `F7` en série : même fichier.
- **`F8`, `F9`, `F10a`, `F10b` attendent `N9`** : elles ajoutent des cas à des fichiers de test migrés. Le widget de `F9` et son test peuvent s'écrire pendant le lot 3 ; ses documents (`filtres.feature`, `acceptance_features_test.dart`, `04-ui.md`) se committent après `F8`, en série.
- **`C1` ne dépend que de `F10b`** : la mesure anticipée de `F10c` ne retient pas le constat sur l'écoulement, qui a une échéance.
- **Le lot 8 (`R1` → `R2` → `R3`) se place entre `F10c` et `S1`**, pendant l'attente de `C1` : il écrit `docs/domain-model.md` et `typesDuDomaine` comme `F1`, `F2`, `S1`, et `CLAUDE.md`, `project-state.md` comme `C1`, `S11` — jamais en même temps qu'elles.
- **Les lots 5 à 7 en série.** `S8` ne dépend que de `S1`, mais écrit dans `docs/domain-model.md` ou `project-state.md` selon sa liste de fichiers : la boucle principale ne la lance en parallèle du lot 6 que si ses fichiers sont disjoints de ceux de la tâche en cours.

Deux agents ne courent ensemble que sur des **fichiers disjoints** ; le critère de fin se relance quand les deux sont revenus, jamais sur un arbre où l'autre écrit encore.

## Les choses à ne jamais faire dans ce plan

- Écrire un `testWidgets(` nu, même en commentaire de fin de ligne ; recréer `test/flutter_test_config.dart` (essai du 2026-10-06 : tous les tests de widget en échec).
- Écrire sous Windows un test de téléphone (fenêtre de moins de 600 px de large).
- Lancer `flutter test --update-goldens` : une image qui rougit est un arrêt.
- Corriger l'attente d'un test qui rougit pendant une migration sans l'avoir lu et classé (procédure du lot 1).
- Recopier 2 h, 24 h ou 60 jours dans un prédicat, ou écrire un instant de test autrement qu'à partir des constantes ; inventer un seuil ; qualifier un débit.
- Importer `lib/data/` depuis `lib/features/`, une tranche depuis une autre, un widget depuis un ViewModel ; écrire un `BackButton(` ou un `AppBar(` hors de `lib/features/shared/screen_layout.dart`.
- Inventer un texte d'écran absent de § 10.1 du cadrage ou de la décision 1.
- Écraser une liste de favoris illisible sans le geste « Repartir d'une liste vide ».
- Supposer un constat d'écran ; cocher une tâche de porte sans la phrase du commanditaire recopiée.
- Committer `windows/flutter/generated_plugin_registrant.h` ou `android/.kotlin/` ; employer `git add -A` ; committer sans liste de chemins.
- Pousser, fusionner, poser un tag sans demande du commanditaire.
- Tenter une quatrième fois : trois échecs sur le même point, arrêt et question.

# État du projet

**Mis à jour :** 2026-09-22 — plan T1 révisé en place (`H1`, `H2` insérées, `BR-013` reporté en T2, heure locale arbitrée). Précédemment, 2026-09-18 — **lot 3 de T1 clos** (`U1`→`U6`, les vues), après les lots 1 et 2 et le correctif `T-14`. Session interrompue à la demande du commanditaire (arrêt du poste) : voir § « Prochaine étape ».

> Ce document est l'**état vivant** du projet. En cas de contradiction avec le code, **le code a
> raison** — et ce document se corrige dans le même commit.

## Arbitrages récents

| Date | Arbitrage |
|---|---|
| 2026-09-12 | **Porte de spike Flutter franchie** sur `F1` (fond IGN, Windows) + `F3` (exécutable Windows). `F2` non tranchée ; approche par défaut de la carte : marqueurs du viewport plus marge, sans clustering. Compte rendu : `spike/porte_flutter/COMPTE-RENDU.md` |
| 2026-09-12 | **Android ⏸ différé jusqu'à nouvel ordre.** Windows seule cible construite ; iOS configuré, jamais compilé. Toute tâche Android d'un plan est marquée ⏸, ni supprimée ni comptée faite · ⚠️ **levé le 2026-09-18**, voir la ligne de ce jour |
| 2026-09-12 | **Arbre git frais** : `dev` repart d'un commit racine unique ; spike et outillage précédent sous le tag `archive/pre-flutter-2026-09-09`. **Plus d'outillage Node** : le générateur de percentiles (`ADR-003`) sera un script Dart |
| 2026-09-13 | **Pas de briefs de session dans `docs/`.** La spec s'étoffe de six documents : fiches de sources avec fixtures datées (`docs/sources/`), critères d'acceptation Gherkin (`docs/acceptance/`, T1), `docs/nfr.md`, matrice de traçabilité (T1), `docs/domain-model.md`, `CHANGELOG.md` + `docs/plan-de-tests.md` |
| 2026-09-13 | **Architecture : feature-first + MVVM** (recommandation de l'équipe Flutter) remplace le CQRS léger. `domain/` et `data/` conservés ; bus, `Query`/`Command` et gestionnaires retirés à l'ouverture de T1 ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), plan T0 § « Suite immédiate ») — **fait** le 2026-09-13 sur cette branche (`9043df1`) |
| 2026-09-13 | **Réusinage `R1`-`R6` exécuté sur `feat/t1-mvvm-fiche-station`** — `69ac82e` (`R1`, [`ADR-014`](adr/ADR-014-feature-first-mvvm.md)), `1bb1810` (`R2`), `b6e9aec` (`R3`), `9043df1` (`R4`), `7541928` puis `0a668be` (`R5`), `2681e12` + `7913b1a` + `9911982` + `fe1b92e` (`R6`), plus les correctifs de relecture `ce4f719` et `43a18cd`. **244 tests** à la clôture (`fe1b92e`) |
| 2026-09-13 | **Plan T1 écrit et ouvert** — [`2026-09-13-t1-fiche-station-et-avertissements.md`](superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md), **7 lots**, **31 tâches actives** au récapitulatif, **10 décisions à valider** (`68151f6`, préalable MVVM levé par `6caac28`) |
| 2026-09-14 | **Branche de travail : `feat/t1-mvvm-fiche-station`.** La branche `refactor/feature-first-mvvm` (7 commits, **doublon du même réusinage**) est **abandonnée, non fusionnée** : elle reste dans le clone, rien n'en sera repris. [`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md) y a été **reporté** (seul apport non redondant, avec cette réécriture de `project-state.md`) : commit `docs` du 2026-09-14 sur cette branche |
| 2026-09-14 | **Audit de reprise du lot 1 de T1 par un second agent** : lot 1 (`D1`→`D8`) et `V1` **repris tels quels**, aucun défaut bloquant. Cinq points ouverts remontés au commanditaire (§ « Ce qui bloque », lignes 15 à 19) |
| 2026-09-14 | **Premier bug constaté à l'écran, corrigé le jour même** : carte vide et bandeau rouge au lancement, `T-04` invalidé par appel réel — le code de station ONDE est une **chaîne libre**, pas huit caractères (`T-14`, [`sources/onde.md`](sources/onde.md)). Codes conservés verbatim, **ligne illisible ignorée et comptée** au dépôt. Trois fixtures ajoutées. Ce que ça dit du cadrage : un fait vérifié **sur un échantillon** (la Loire) a été écrit comme s'il valait partout |
| 2026-09-14 | **Purger toute trace de React Native à la fin de T1, docs comprises** (demande du commanditaire) → tâche `X5` du lot 6 du plan T1, avec une question fermée sur les ADR remplacés (recommandation : les garder avec leur statut). Même jour : l'ONDE appelée à chaque geste sans consommateur avant `U3` est **gardée telle quelle** (« ok ») ; `V2` puis `V3` livrées et relues |
| 2026-09-14 | **Lot 3 validé puis livré le jour même** (« je valide le lot 3 ») : `U1`→`U6` en TDD, chaque tâche relue par un second agent avant commit, corrections appliquées. Décisions prises en cours de lot, à confirmer : `Introuvable` ajouté aux états de la fiche station (37 stations sans fiche), vocabulaire d'écoulement aligné sur la colonne « Libellé carte » d'`ADR-006` dans le **domaine**, préchargement des débits limité à l'échelle « débit », phrase de repli de `BR-007` sur l'échelle « débit », halo de marqueur **noir** (plan IGN clair), cause technique jamais affichée à l'usager |
| 2026-09-18 | 🚨 **Android réactivé — le différé du 2026-09-12 est levé** (demande du commanditaire : « active android et lancer l'émulateur »), amendement d'[`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md). **Constaté ce jour :** `flutter doctor` rend « [√] Android toolchain - develop for Android devices (Android SDK version 36.0.0) » ; le NDK `28.2.13676358` exigé par Flutter 3.47.4 (lu dans `FlutterExtension.kt` du SDK Flutter installé) **est présent sur le poste**, donc `ndkVersion = flutter.ndkVersion` est conservé et l'épingle `27.1` du spike n'a plus lieu d'être ; `flutter create --project-name martinpecheur --org fr.martinpecheur --platforms android .` a généré le gabarit ; l'émulateur `Pixel_7` a démarré, vu `emulator-5554 device` puis `sys.boot_completed=1`. **Non constaté :** aucune construction, aucun lancement, aucun écran sur Android — le bac à sable ne compile pas de natif, `flutter run -d emulator-5554` revient au commanditaire. Windows reste la première cible construite ; iOS reste configuré, jamais compilé |
| 2026-09-18 | **Sept points bloquants arbitrés par questions fermées** : (1) **`shared_preferences` 2.5.5** pour la préférence simple → [`ADR-011`](adr/ADR-011-stockage-local.md), moteur structuré toujours ouvert ; (2) **`lib/features/shared/`** pour un widget commun à plusieurs tranches, sixième règle `shared-sans-tranche` → amendement d'[`ADR-014`](adr/ADR-014-feature-first-mvvm.md) ; (3) les **trois amendements du lot 1 entérinés** (retrait d'`OndeClient`, retrait de `findLatestForAll`, `OndeObservation.point`) ; (4) **« Non renseigné » gardé** → amendement d'[`ADR-006`](adr/ADR-006-onde-quatre-categories.md) ; (5) **phrase dédiée à l'échelle débit** retenue parmi trois candidates cadrées par `eva` (« Il n'y a aucune station de mesure dans le secteur affiché. Cela ne dit rien de l'état des cours d'eau : le débit n'est simplement pas mesuré ici. ») ; (6) **tap entre marqueurs superposés accepté pour T1** ; (7) **branche poussée** sur `origin`, PNG Expo **rattachés à `X5`**. Même jour : `Q-01` à `Q-04` mesurés (`T-15`) |
| 2026-09-22 | **Révision du plan T1, après un bilan de conception vérifié sur le code** ([spec](superpowers/specs/2026-09-22-revision-plan-t1-design.md)) : (1) **`BR-013` reporté en T2** — en T1 la fiche station n'est pas un écran de ressource ; l'encart renforcé sera posé sur l'écran des restrictions VigiEau, T1 n'en écrit que le texte (`W5`) ; (2) **heure affichée = heure locale sans suffixe** (« 27/08/2026 à 10:00 »), fuseau injecté — clôt le point 19, réalisé par `H1` ; (3) **approche A** : plan amendé en place, deux tâches insérées juste avant celles qui en ont besoin — `H1` (formateur de date unique, avant `W4`) et `H2` (décisions de la carte rendues à `MapViewModel`, avant `K1`) —, dette traitée seulement quand une tâche la touche. **35 tâches actives** |

> ⚠️ **Le tag `archive/pre-flutter-2026-09-09` n'est pas présent dans ce clone** : `git tag` ne
> liste que `v0.1.0` (constaté le 2026-09-13, reconstaté le 2026-09-14). L'arbitrage du 2026-09-12
> est consigné tel qu'il a été pris ; l'existence du tag, elle, n'est **pas vérifiée**. Le tag
> `v0.1.0` est posé **localement sur `015a245`, non poussé**.

## Où on en est

| Tranche | Prouve | Statut |
|---|---|---|
| **Porte de spike** | Fond IGN affiché (`F1`), exécutable Windows autonome (`F3`) | ✅ franchie sur Windows (exécution 2026-09-09, arbitrage 2026-09-12). `F2` (4 150 marqueurs clusterisés) **non tranchée** |
| **T0 — socle Flutter** | Carte `flutter_map`, socle domaine et données, test d'architecture, exécutable Windows | ✅ **livrée le 2026-09-13** — **31 tâches sur 31**, PR #11 fusionnée sur `dev` (`015a245`), version **`0.1.0`** (tag `v0.1.0` posé **localement, non poussé**), **248 tests** (247 du plan + `changelog_test`) constatés par `flutter test`, exécutable Windows **lancé hors outil** par le commanditaire, **31 Mo** ([`CHANGELOG.md`](../CHANGELOG.md)) |
| **Réusinage `R1`-`R6`** | `lib/application/` retiré, `MapViewModel`, `layers_test.dart` à cinq règles, docs alignées | ✅ **exécuté et relu le 2026-09-13 sur cette branche** — **244 tests** à la clôture (`fe1b92e`). **Non fusionné sur `dev`** : PR et fusion sont pour le commanditaire (`gh` absent du bac à sable) |
| **T1 — fiche station, écoulement ONDE, avertissements** | Carte interactive (tap, fiche), fiches station et ONDE, **modal, bandeau, encart daté** — encart renforcé (`BR-013`) en T2 | 🔄 **en cours.** **Lots 1 (`D1`→`D8`), 2 (`V1`→`V4`) et 3 (`U1`→`U6`) clos** le 2026-09-14 ; restent les **lots 4 à 7** (avertissements, clavier/souris, documentation, porte `0.2.0`). ⚠️ **Rien du lot 3 n'a été vu à l'écran** : `flutter run -d windows` est à relancer par le commanditaire avant `W1` |
| **T2** | Sécheresse et restrictions (VigiEau) | 🔄 |
| **T3** | Favoris, filtres, fraîcheur | 🔄 |

**Le cadrage produit est terminé et vérifié** — il ne dépend d'aucune technologie et n'a été refait
à aucune des deux bascules de stack.

🚨 **Rien de tout cela n'est un produit.** Aucun des quatre avertissements obligatoires n'est posé
(`BR-012`, `BR-013`) : `CLAUDE.md` interdit toute mise en production tant qu'ils manquent. Trois sont
le **lot 4 de T1** (modal, bandeau, encart daté) ; l'encart renforcé de `BR-013` est reporté en **T2**
(arbitrage du 2026-09-22) : aucune mise en production n'a donc lieu avant T2.

## Ce qui est acquis

| Sujet | État |
|---|---|
| Analyse des APIs | ✅ Vérifiée par appels HTTP réels les 2026-07-30 et 07-31, **recapturée le 2026-09-13** (14 faits `V-01` à `V-14` du plan T0, puis `T-01` à `T-14` du plan T1) |
| Question centrale du « débit suffisant » | ✅ Tranchée (`ADR-002`) et documentée avec ses limites |
| Sources retenues et écartées | ✅ 7 APIs évaluées, motifs documentés |
| Règles métier | ✅ **14 règles**, chacune avec son test |
| Cas d'usage | ✅ **6 cas**, flux nominaux et alternatifs |
| Avertissements | ✅ Les 4 emplacements **spécifiés**, textes rédigés — 🔄 **aucun n'est posé dans le code** (lot 4 de T1 : modal, bandeau, encart daté ; l'encart renforcé de `BR-013` est **reporté en T2**, arbitrage du 2026-09-22) |
| Stack | ✅ **Flutter / Dart**, Windows première cible ([`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md), arbitrage du commanditaire du 2026-09-12) |
| Architecture | ✅ **feature-first + MVVM** ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), arbitrage du 2026-09-13) — vue → ViewModel → dépôt → domaine, sans bus ni médiateur, verrouillée par sept règles de couches (`shared-sans-tranche` et `features-sans-fichier-a-plat` ajoutées le 2026-09-18) |
| Socle de domaine | ✅ Unités en `extension type` (`BR-002`), conversion l/s → m³/s et mm → m **à un seul endroit**, fraîcheur aux bornes de `BR-005`, nomenclature close à branche `Inconnu` (`BR-011`), `StationCode` à dix caractères qui refuse un code site (`C-05`) |
| Socle de données hydrométrie | ✅ Client Hub'Eau **v2** (200 **et** 206 en succès, retry 429/5xx jamais 4xx, recul à gigue injectée), mapper unique, référentiel lu depuis l'asset embarqué, `RestrictionSource` **interface seule** |
| Domaine de l'écoulement ONDE (`D2`) | ✅ `OndeStationCode` (**chaîne libre conservée verbatim** depuis `T-14`, plus « 8 caractères »), `OndePoint`, `OndeObservation`, âge de campagne en **jours calendaires** (`BR-010`, `T-08`), `StationMapState` — `Chargee`/`SansDonnee`/`NonChargee`/`EnEchec` |
| Mapper ONDE (`D3`) | ✅ `mapOndeObservation` / `mapOndePoint`, testés sur la **fixture réelle du 2026-09-13** ; `code_ecoulement` lu en texte, jamais par un cast nu ; `flowCategoryFromCode` réutilisé, pas recopié |
| URI ONDE (`D4`) | ✅ `ondeObservationsBboxUri`, `ondeObservationsStationUri` posées **sur le `HubEauClient` existant** — aucun second client (`OndeClient` retiré). `fields` à dix champs, dates formatées en **UTC** |
| Dépôt d'observations hydrométriques (`D5`, `D6`) | ✅ `HttpHydroObservationRepository` dans sa **forme garantie** (un appel par station), décoré par `CachedHydroObservationRepository` — `withCachePolicy`, TTL **20 min**, chiffre unique dans `lib/` |
| Dépôt d'écoulement (`D7`, `D8`) | ✅ `HttpOndeObservationRepository` (emprise et point) + `CachedOndeObservationRepository` — TTL **30 j** de mai à septembre, **90 j** hors saison ; une observation ONDE **porte son point**, lu sur la même ligne d'API ; depuis `T-14`, une ligne illisible est **ignorée et comptée** au lieu de faire tomber la page — le compte est rattaché à l'appel (`OndeSweep.unreadableRows`, rendu par `latestWithinBounds`), traverse le cache avec le balayage qu'il décrit, et `skippedRowCount` est supprimé |
| ViewModel de fiche station (`V1`) | ✅ `StationSheetViewModel` — `Fermee`/`EnCours`/`Prete`/`EnEchec`, horloge injectée, **aucun widget importé** ; libellés balayés en **mots entiers** contre le vocabulaire interdit (`BR-003`) |
| ViewModel de la carte (`V2`) | ✅ `MapViewModel` — `MapScaleKind` (une seule échelle active, `BR-008`), `stateOf` par station (`NonChargee` tant que rien n'est chargé, `BR-007`), préchargement **borné à 20** et annulable (`NFR-07`), ONDE de l'emprise sur 60 jours ; notifie dès les points locaux, avant l'ONDE (`UC-001 § 4`) |
| ViewModel des avertissements (`V4`) | ✅ `WarningsViewModel` — version acquittée persistée et comparée à la version courante du texte (`UC-006 A1`, `A3`), case jamais pré-cochée, `acknowledge()` refuse sans case cochée ; aucune chaîne destinée à l'écran (le texte vivra dans `lib/domain/warnings/warning_texts.dart`, `W2` révisée le 2026-09-22) |
| ViewModel de fiche ONDE (`V3`) | ✅ `OndeSheetViewModel` — états préfixés `OndeSheet…`, dernière observation et cinq campagnes, âge en jours calendaires (`BR-010`), modalité officielle en second niveau (`ADR-006`), « À sec » à l'écran jamais « Assec » ; historique vide → absence honnête, jamais une observation inventée |
| Carte | ✅ Fond IGN Géoplateforme en tuiles raster, attribution affichée, **4 150 stations** en marqueurs du viewport plus une marge, requête au relâcher du geste — constaté à l'écran sur T0 (`dev`) ; les correctifs `ce4f719`/`43a18cd` (**la dernière emprise demandée gagne**, une emprise en erreur reste rechargeable) ne sont couverts que par les tests, `flutter run -d windows` n'ayant pas été relancé sur cette branche |
| Politique de cache | ✅ `withCachePolicy` (stale-while-revalidate, déduplication en vol), **décorateur de dépôt** sous `lib/data/cache/` — désormais **utilisé** par les deux dépôts du lot 1 |
| Hors-ligne cartographique | ⚠️ **Partiel.** Le cache de tuiles intégré à `flutter_map` sert les zones **déjà parcourues** (constaté hors réseau le 2026-09-13, `NV-W2`). **Aucun téléchargement de zone** : le `Must` d'[`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md) reste **non livré** |

## Code

### Disposition, telle qu'elle est sur cette branche

```
lib/
  domain/          station/{station,station_point}.dart · geo/{bounds,viewport_filter}.dart
                   units/ · observation/{freshness,hydro_observation,station_map_state}.dart
                   onde/{onde_station_code,onde_point,onde_observation,campaign_age}.dart
                   nomenclature/flow_category.dart · repositories/repositories.dart
  data/            http/{http_status,hub_eau_client,hub_eau_paging,onde_uris,retry}.dart
                   mappers/ · cache/cache_policy.dart
                   observations/{http,cached}_hydro_observation_repository.dart
                   onde/{http,cached}_onde_observation_repository.dart
                   referentiel/{asset_station_repository,asset_station_point_repository,…}.dart
                   restrictions/restriction_source.dart
  features/        map/{view,view_model}/ — view/{map_view,station_marker,onde_marker,map_legend,map_empty_states,ign_tile_template}.dart, view_model/{map_view_model,map_scale}.dart · station_sheet/{view,view_model}/ · onde_sheet/{view,view_model}/ · warnings/view_model/ (sa view/ arrive en W2)
test/features/goldens/  20 images de référence (5 états de station, 12 marqueurs ONDE, 2 planches en niveaux de gris, 1 comparaison) — plateforme-dépendantes, regardées avant versionnement
  main.dart        racine de composition — à la racine de lib/, seul fichier exempt de la règle « features/ n'importe pas data/ »
```

⚠️ **`StationPoint`, le filtre d'emprise et `Bounds` vivent dans `lib/domain/`** —
`lib/domain/station/station_point.dart`, `lib/domain/geo/viewport_filter.dart`,
`lib/domain/geo/bounds.dart` — et non sous `lib/data/referentiel/` : le filtre est un calcul pur
sur des `double`, et deux couches le consomment (le dépôt de points, la carte). Le dépôt de points
de carte, lui, est `AssetStationPointRepository`
(`lib/data/referentiel/asset_station_point_repository.dart`) ; son contrat
`StationPointRepository` est déclaré dans `lib/domain/repositories/repositories.dart`.

`test/architecture/layers_test.dart` verrouille **sept règles**, nommées dans son en-tête :

1. `domaine-ferme` — un fichier de `domain/` n'importe rien du projet hors `domain/`.
2. `data-vers-features` — un fichier de `data/` n'importe aucune tranche de fonctionnalité.
3. `view-model-sans-widget` — un ViewModel n'importe ni `material.dart`, ni `widgets.dart`, ni
   `cupertino.dart` (`foundation.dart` reste autorisé : c'est de là que vient `ChangeNotifier`).
4. `feature-vers-feature` — une tranche n'importe pas une autre tranche.
5. `features-vers-data` — aucun fichier sous `features/` n'importe `data/`, **`main.dart` excepté**.
6. `shared-sans-tranche` — `features/shared/` est importable par toute tranche et n'importe aucune
   tranche (arbitrage du 2026-09-18, amendement d'`ADR-014`). 🔄 Le dossier n'existe pas encore : le
   verrou précède le code, première occupation prévue en `W4`.
7. `features-sans-fichier-a-plat` — aucun fichier `.dart` directement sous `features/` : un fichier y vit
   dans une tranche ou dans `features/shared/`. Ferme le trou trouvé à la relecture du 2026-09-18 (un
   fichier à plat échappait aux règles 4 et 6).

La moitié « aucune infrastructure sous `lib/domain/` » reste dans `domain_isolation_test.dart`, le
premier test du projet — `layers_test.dart` le **complète**, il ne le recopie pas.

### Tranche T0, plan [`2026-09-13-t0-socle-flutter.md`](superpowers/plans/2026-09-13-t0-socle-flutter.md)

Le commit de chaque tâche est celui inscrit dans le titre de la tâche du plan.

> ⚠️ Les hashes ci-dessous sont ceux des titres du plan T0 (commits de la branche de travail).
> La PR #11 ayant été fusionnée en **squash** (`015a245`), **ils ne sont pas résolvables dans ce
> clone** ; seul `015a245` l'est. Même réserve pour `a0d4279` (ligne « Transverse »).

| Tâche | Livrable | Commit |
|---|---|---|
| `S1` | Projet Flutter à la racine, plateformes `windows` et `ios` générées | ✅ `b538d8c` |
| `S2` | Analyse statique durcie — `strict-casts`, `strict-inference`, `strict-raw-types`, `avoid_dynamic_calls` | ✅ `c90f6de` + `710d191` |
| `S3` | **Le premier test du projet** — la frontière `lib/domain/`, écrite avant la première ligne de domaine | ✅ `f6577ac` |
| `S4` | `CHANGELOG.md` | ✅ `90d7529` |
| `S5` | `docs/plan-de-tests.md` | ✅ `ed37078` |
| `D1` | Les quatre unités en `extension type`, fermées **dans les deux sens** | ✅ `e3087e7` |
| `D2` | `toCubicMetresPerSecond` / `toMetres` — la conversion à un seul endroit (`BR-002`) | ✅ `3eb7a04` |
| `D3` | Fraîcheur d'une observation aux bornes de `BR-005` (2 h / 24 h) | ✅ `f6c3631` |
| `D4` | `Station`, `StationCode` (10 car.), `DepartementCode` | ✅ `b31eae2` + `b5a06c5` |
| `D5` | `HydroObservation`, `Qualification`, `Grandeur` | ✅ `fb08460` |
| `D6` | `FlowCategory` — `sealed`, branche `Inconnu` porteuse du code brut (`BR-011`) | ✅ `6f3798a` |
| `D7` | Interfaces de dépôts, `Bounds` | ✅ `7f0ba0a` |
| `D8` | `docs/domain-model.md` | ✅ `984825f` + `10b30c5` |
| `N1` | **Fixtures réelles datées et fiches de sources d'abord** (`docs/sources/`, `test/fixtures/CAPTURES.md`) | ✅ `24134cf` + `1d7b382` |
| `N2` | `isSuccess` — 200 **et** 206 (`C-06`) | ✅ `4ff3af6` |
| `N3` | `delayForAttempt` — recul exponentiel à **gigue injectée**, donc testable | ✅ `96fc1d0` + `bf83c71` |
| `N4` | Client Hub'Eau hydrométrie v2 — retry 429/5xx, **jamais** 4xx, décodage UTF-8 explicite | ✅ `790d767` |
| `N5` | Mapper `observations_tr` — conversion appliquée **une seule fois** | ✅ `340b8c7` |
| `N6` | Lecture du référentiel depuis l'asset embarqué | ✅ `ae6d125` |
| `N7` | `RestrictionSource` — **interface et rien d'autre** (`ADR-004`) | ✅ `3a1b376` |
| `A1` | `Query<R>` / `Command<R>` en `abstract interface class` | ✅ `1d929f5` — 🗑️ **retiré par `R4`** |
| `A2` | Registre de gestionnaires `Map<Type, Handler>`, sans réflexion ni médiateur | ✅ `0bee6d2` — 🗑️ **retiré par `R4`** |
| `A3` | `withCachePolicy`, l'unique — stale-while-revalidate | ✅ `8afb7eb` + `66820ea` — **conservé**, déplacé sous `lib/data/cache/` par `R4` |
| `M1` | Gabarit de tuiles IGN (WMTS KVP) | ✅ `1c74c9d` |
| `M2` | Filtre de viewport à marge proportionnelle | ✅ `f261408` + `ea497b3` |
| `M3` | Écran carte — fond IGN et attribution affichée | ✅ `d9fa091` |
| `M4` | Les **4 150 stations** en marqueurs du viewport | ✅ `fcc0b0b` + `e5c7e94` + `31b1cfe` |
| `M5` | La molette sur Windows — diagnostic borné | ✅ `809ac40` |
| `M6` | `docs/nfr.md` | ✅ `809ac40` |
| `P1` | **L'exécutable Windows, lancé hors Flutter** | ✅ constaté le 2026-09-13, `f05ed04` |
| `P2` | Clore la version `0.1.0` | ✅ 2026-09-13 |
| `A⏸1`-`A⏸5` | Plateforme Android, outillage natif, signature, appareil réel, préversion | **Différé levé le 2026-09-18.** `A⏸1` ✅ gabarit `android/` généré · `A⏸2` 🔄 NDK `28.2.13676358` constaté présent sur le poste, `ndkVersion = flutter.ndkVersion` conservé — **à constater par une construction réussie**, pas encore faite · `A⏸3`, `A⏸4`, `A⏸5` ⏸ toujours différées (signature, appareil réel, préversion). Hors du décompte « 31 tâches actives » |

Transverse : licence du code **GPL-3.0-or-later** (`a0d4279`).

> **`A1` et `A2` sont retirés par `R4`** : le bus, `Query`/`Command` et les gestionnaires
> disparaissent avec `lib/application/`. Le code reste dans l'historique git, sur `dev` au commit
> `015a245`. **`A3` survit** — c'est le principe « la politique de cache vit dans un seul
> composant » qui est conservé, pas son véhicule ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md)).

### Réusinage `R1`-`R6`, § « Suite immédiate » du plan T0

Ces commits sont **résolvables sur cette branche**.

| Tâche | Livrable | Commit |
|---|---|---|
| `R1` | [`ADR-014`](adr/ADR-014-feature-first-mvvm.md), `CLAUDE.md` aligné | ✅ `69ac82e` |
| `R2` | Tranche carte en `view/` ; `StationPoint` et le filtre d'emprise **rangés dans `lib/domain/`** | ✅ `1bb1810` |
| `R3` | `MapViewModel extends ChangeNotifier` remplace le contrôleur, le bus et les gestionnaires | ✅ `b6e9aec` |
| `R4` | `lib/application/` retiré ; `withCachePolicy` devient décorateur de dépôt sous `lib/data/cache/` | ✅ `9043df1` |
| `R5` | `test/architecture/layers_test.dart` — quatre règles, puis la **cinquième** (`features-vers-data`) | ✅ `7541928`, puis `0a668be` |
| `R6` | Conception, carte de contexte, plan de tests, `CLAUDE.md` et `docs/nfr.md` alignés | ✅ `2681e12`, `7913b1a`, `9911982`, `fe1b92e` |
| — | Correctifs de relecture : la dernière emprise demandée gagne, une emprise en erreur reste rechargeable ; retrait de ce que rien ne lit | ✅ `ce4f719`, `43a18cd` |

> ⚠️ Le tableau `R1`-`R6` du plan T0 et le § « Préalable » du plan T1 citent d'autres hashes
> (`9b4e4c9`, `2a8f507`, `a705789`, `a89e88d`, sommet `c1a5755`) : ils **ne sont résolvables dans
> aucune branche de ce clone**. Les commits ci-dessus sont ceux de `feat/t1-mvvm-fiche-station`,
> lus dans `git log`. Les plans restent à corriger.

### Tranche T1, plan [`2026-09-13-t1-fiche-station-et-avertissements.md`](superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md)

**Lot 1 clos, `V1` fait.** Chaque ligne porte le commit de la tâche, puis ses correctifs de
relecture. Tous sont **résolvables** sur cette branche.

| Tâche | Livrable | Commit |
|---|---|---|
| `D1` | **Faits d'API et fixtures d'abord** — trois fixtures ONDE capturées, `Q-01` à `Q-05` instruites, `docs/sources/onde.md` et `…/hubeau-hydrometrie.md` complétées | ✅ `adb5c0d` + `f6ea10d`, `03e0386`, `0c078b4`, `f70d11a` |
| `D2` | Domaine de l'écoulement — `OndeStationCode`, `OndePoint`, `OndeObservation`, âge de campagne, `StationMapState` | ✅ `375dfa0` + `16d70fb`, `78ee3a3`, `8e93e70`, `235622e` (`BR-010`) |
| `D3` | `mapOndeObservation` — seul point de passage, testé sur la **fixture réelle du 2026-09-13** | ✅ `00e93d9` + `993bdd2`, `f00a3af`, `e200136`, `0a83192` |
| `D4` | URI ONDE (emprise, point, campagnes) sur le `HubEauClient` existant ; `fields` à dix champs, dates en UTC | ✅ `6fe66e0` + `90d5a76`, `c1a8b2c`, `cef1061`, `cabdc39` |
| `D5` | `HttpHydroObservationRepository` — **forme garantie** (`findLatest` seul), `Q-01`/`Q-02` étant restées ouvertes | ✅ `44fd55f` + `271ae9b` |
| `D6` | `CachedHydroObservationRepository` — `withCachePolicy`, TTL **20 min**, chiffre unique dans `lib/` | ✅ `246fd54` + `e161b36` |
| `D7` | `HttpOndeObservationRepository` + `CachedOndeObservationRepository` — TTL **30 j** en saison, **90 j** hors saison | ✅ `d640f56` + `e24b24d`, `5d5cdd0`, `53626cb` |
| `D8` | `OndeObservation` porte son `OndePoint`, lu sur la même ligne d'API (**amendement du 2026-09-13**) | ✅ `0285f58` + `9067933` |
| `V1` | `StationSheetViewModel` — l'état de la fiche station **sans aucun widget** | ✅ `bade919` + `c8d36eb` |
| `V2` | `MapViewModel` — `MapScaleKind`, une seule échelle active (BR-008), `stateOf` par station (BR-007), préchargement borné à 20 et annulable (NFR-07), ONDE de l'emprise sur 60 jours (BR-010) ; relu, `loadFor` notifie dès les points avant l'ONDE (UC-001 § 4) | ✅ `e00b34f` (2026-09-14) |
| `V3` | `OndeSheetViewModel` — fiche d'un point ONDE sans widget, valeurs de la fixture réelle de `K4520001`, balayages `BR-003` et `BR-014` | ✅ `0255df5` (2026-09-14) |
| — | **Correctif `T-14`** (bug vu à l'écran) : codes ONDE verbatim, ligne illisible ignorée et comptée, trois fixtures, `Q-05` amendé | ✅ `69f51b5` (2026-09-14) |
| `V4` | `WarningsViewModel` — acquittement par **version** (jamais un booléen, `BR-012`), échec de lecture rebloque, échec d'écriture exposé ; `AcknowledgementRepository` déclaré dans le domaine (implémentation en `W1`) | ✅ `f801d79` (2026-09-14) |
| `U1` | Feuille de résumé au tap — formateurs sur unités typées (`47,8 m³/s`, `−1,232 m`, `< 0,001` pour une valeur infime), valeur et date dans un seul `Text` (`BR-001`), phrase d'absence recopiée (`BR-007`), zone de tap 44 pt sur le `Marker`, panneau injecté par `main.dart` (règle `feature-vers-feature`) ; relecture : état `Introuvable` (37 stations hors référentiel embarqué), `BR-006` documente les libellés d'API cités verbatim | ✅ `ee46730` |
| `U2` | Marqueur par état de fraîcheur (losange `CustomPaint` sans allocation par trame, `#767676`, motif + libellé annoncé, halo noir 2 px), légende toujours visible (`BR-008`), `buildMapOverlays` pure, préchargement branché au relâcher et borné aux états inconnus | ✅ `c583afd` |
| `U3` | Points ONDE (six teintes/formes/motifs recopiés d'`ADR-006` et `04-ui.md § 2`, gris + date au-delà de 60 jours), bascule par puces, familles de marqueurs exclusives, annonces préfixées par l'échelle ; relecture : un seul vocabulaire (`flowCategoryLabel` = colonne « Libellé carte »), préchargement des débits sur l'échelle « débit » seulement | ✅ `c35fe2e` |
| `U4` | Fiche ONDE — catégorie → modalité officielle → date, cinq campagnes, rappel de rythme dans tous les cas, absence honnête sans campagne ; troisième ViewModel câblé dans `main.dart`, ouvrir une fiche ferme l'autre ; encart d'avertissement reporté à `W4` | ✅ `f4419b6` |
| `U5` | 20 goldens regardés avant versionnement, contre-épreuve rouge constatée ; la planche ONDE confirme que `#56B4E9` et `#E69F00` ont la même luminance — forme et motif seuls les séparent | ✅ `434c3b6` |
| `U6` | Avis d'absence et de panne nommée par source (textes recopiés), décision pure `mapNoticesFor`, `OndeSweep` (compte de lignes illisibles rattaché à l'appel, en cache), « Élargir la recherche » sans déplacement de caméra (→ `K1`) ; relecture : erreur ONDE effacée au succès, cause technique jamais affichée, phrase de repli sur l'échelle « débit » | ✅ `e0081a2` |
| Lots 4 à 7 | Avertissements (`W1`-`W3`, **`H1`** formateur de date en heure locale, `W4`, `W5`), clavier/souris (**`H2`** décisions de la carte rendues au ViewModel, `K1`-`K3`), documentation (`X1`-`X5`, dont la **purge React Native** `X5`), porte `0.2.0` (`P1`, `P2`) — `H1` et `H2` ajoutées le 2026-09-22 | 🔄 à faire |

Documentation du lot : `68151f6` (plan), `6caac28` (préalable levé), `e21b08e` (lot 1 clos),
`9cfcb6c` (`V1` fait), `0ce4ac3` (ADR-013 reporté, état réécrit), `9ab0005` (YAGNI `/campagnes`), `61df8a2` (`V3` cochée, `T-14`, `X5`).

> Décompte du plan T1 : **35 tâches actives** depuis la révision du 2026-09-22 (`H1` et `H2` ajoutées),
> 5 différées. Corrigé une première fois le 2026-09-14 à 33 (le récapitulatif initial disait 31 — il
> oubliait `D8` — et `X5` a été ajoutée).

### Tests — l'état exact sur ce poste

**778 tests, 778 verts sur ce poste** (`flutter test`, 2026-09-18, sortie `+778`, « All tests passed! ») — première suite entièrement verte depuis T0, après l'alignement Android en TDD du 2026-09-18 (retrait de l'affirmation « le dossier android n'existe pas », ajout de `test/project/android_configuration_test.dart`). Repère antérieur : **773 tests, 772 verts sur ce poste** (`flutter test`, 2026-09-18, sortie `+772 -1`) — 764 dont 763 verts en fin de session du 2026-09-14. Jalons du jour : 427 à la reprise, 408 après le retrait YAGNI, 437 après `V2`, 452 après `V3`, 478 après le correctif `T-14`, 493 après `V4`, 540 après `U1`, 577 après `U2`, 651 après `U3`, 691 après `U4`, 711 après `U5`, 764 après `U6`. Le 2026-09-18 : 773 après les arbitrages (règles de couches `shared-sans-tranche` et `features-sans-fichier-a-plat`, phrase dédiée de l'échelle débit). Le seul rouge
était alors `test/project/ios_bundle_identifier_test.dart` : « le dossier android n'existe pas ».
**Ce rouge disparaît avec la levée du différé Android du 2026-09-18** : le dossier `android/` est
désormais généré et versionné, et l'affirmation est retirée du test dans le même mouvement
(alignement en TDD, **fait le jour même**). Pour mémoire : 248 à la fin de T0, **244** à la clôture
du réusinage MVVM (`fe1b92e`), **411** à la clôture du lot 1 (`e21b08e`).

### Écarts constatés à l'exécution de T0

Le plan est une esquisse antérieure ; **le code a raison**. Les écarts qui portent à conséquence :

| Écart | Constat |
|---|---|
| **Unités** (`D1`) | Les `extension type` ferment **les deux sens** — un `double` nu ne devient pas une unité, pas seulement l'inverse. `.value` est la seule sortie explicite |
| **206** (`N2`, `V-01`, `V-08`) | `size=2` répond **HTTP 206**, une page **vide** répond **HTTP 200**. Les deux sont des succès ; un client qui n'accepte que 200 casse dès la première page |
| **`count` du code site** (`N1`) | `C-05` reproduit, mais avec d'autres chiffres que ceux anticipés : **412** pour le code site contre **206** pour le code station (le plan écrivait 430 / 216). Le référentiel bouge — les volumes se recapturent, ils ne se recopient pas |
| **37 stations sans département** (`M4`) | 37 stations **en service** n'ont pas de `code_departement`. L'absence est lue **telle quelle**, jamais remplacée par une valeur sentinelle (`BR-007`) |
| **Requête au relâcher du geste** (`M4`) | L'emprise est demandée à la **fin** du geste, pas à chaque trame — et les erreurs de chargement restent **visibles à l'écran** plutôt qu'avalées |
| **`NV-W1` — la molette** (`M5`) | **Constat inverse du spike** : la molette **zoome** sur Windows à l'exécution de T0, sans qu'aucun réglage ait été posé. Le constat du 2026-09-09 n'est pas reproduit ; **la cause de l'écart n'est pas établie**, seule sa disparition est constatée. Clos par `7913b1a` |
| **`Bounds` sans `==` / `hashCode`** (`D7`/`D8`) | **Traité en T1** : `Bounds` gagne son égalité structurelle en `e24b24d`, le jour où le cache par emprise de `D7` en a eu besoin |
| **Identifiants** | Le plan nommait des identifiants en français (`delaiDeBase`, `taillePageMaximale`) ; ils sont implémentés en **anglais** (`baseDelay`, `maxPageSize`), par convention de `CLAUDE.md` |

## Ce qui bloque, ou reste à trancher

| # | Sujet | Nature |
|---|---|---|
| 1 | **Stockage local** — **préférence simple tranchée** ([`ADR-011`](adr/ADR-011-stockage-local.md), arbitrage du commanditaire du 2026-09-18) ; **moteur structuré non tranché** | `shared_preferences` **2.5.5** (publiée le 2026-03-25, BSD-3-Clause, éditeur `flutter.dev`, Windows couvert — relevé sur pub.dev le 2026-09-18 à 09:00 UTC). 🔄 **Pas encore dans `pubspec.yaml`** : c'est `W1`. Pour la donnée structurée (favoris, dernière vue), `drift` reste candidat par défaut ; `sqflite` seul **ne couvre pas Windows** — à trancher quand un écran en aura besoin |
| 2 | Trois ADR tranchés **sans arbitrage du commanditaire** : `ADR-002`, `ADR-004`, `ADR-006` | Décisions par défaut, réversibles. Chacune porte sa section « Si la décision est revue » |
| 3 | **Réduction de périmètre à valider** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 4 | Le cadrage annonçait **3 modalités ONDE** ; il y en a **6** (`ADR-006`) | Corrigé dans la spec |
| 5 | ~~Poids réel de l'asset de percentiles~~ — **mesuré le 2026-08-15** sur 40 stations réelles : 479 octets/station bruts, 177 gzip. Extrapolé à 4 150 : ≈ 2,0 Mo bruts, ≈ 0,73 Mo gzip. Le poids ne remet pas `ADR-003` en cause | Clos — reste à confirmer sur la passe complète (~2 h) |
| 5 bis | 🚨 **`Indéterminé` concerne près d'une station sur deux.** Sur l'échantillon : **19 stations sur 40 sans aucune quinzaine calculable**, 48,8 % des quinzaines. `ADR-002` fonde le positionnement statistique du débit sur cet asset ; pour la moitié des stations il n'existera **jamais** | **Ouvert.** Le commanditaire a demandé le 2026-08-15 de **confirmer sur la passe complète** avant d'en tirer une conséquence produit. ⚠️ **Or cette passe n'est pas lancée** (~2 h, décision « pas maintenant » le même jour) : le point reste donc en attente, sans échéance. Un échantillon de 200 stations le resserrerait en ~6 minutes |
| 6 | **Script de génération des percentiles** — en **Dart** désormais (`ADR-003`, arbitrage du 2026-09-12). `assets/percentiles/` n'existe pas | Lot d'outillage à chiffrer. **Hors T1** (décision 1 du plan) : conséquence assumée, sur l'échelle « débit » toute station est `Indéterminé` au sens de `BR-004` |
| 7 | **Hôte macOS** pour produire un build iOS — `NV-W4`, sans date | **Matériel.** Bloquant pour livrer iOS, pas pour développer |
| 8 | **`NV-W3` — aucune mesure de fluidité sur Windows.** `NFR-01` (rastérisation p90 ≤ 16,7 ms, trames en retard < 5 %) est **non mesuré** sur la seule cible construite ; le binaire de T0 a été jugé à l'œil | Ouvert, sans date ([`nfr.md`](nfr.md)). Programmé en `X3` de T1 |
| 9 | **Android — différé levé le 2026-09-18** (`NV-W5` amendé). **Ce qui est levé :** l'arbitrage ⏸ du 2026-09-12 ; la chaîne d'outils est vue par `flutter doctor` (« Android SDK version 36.0.0 », SDK du poste, chemin sans espace ni parenthèse) ; le NDK `28.2.13676358` exigé par Flutter 3.47.4 **est présent sur le poste** — la dette « NDK 28.2 absent » tombe, l'épingle `27.1.12297006` du spike n'a plus lieu d'être et `ndkVersion = flutter.ndkVersion` est conservé ; le gabarit `android/` est généré ; l'émulateur `Pixel_7` a démarré (`emulator-5554 device`, `sys.boot_completed=1`) | **Ce qui reste dû.** (a) **Aucune construction Android n'est constatée** : le bac à sable ne compile pas de natif (socket AF_UNIX fermée, Gradle ne démarre pas) — `flutter run -d emulator-5554` est à lancer **par le commanditaire**, et tant qu'il ne l'a pas fait le NDK est « présent », pas « éprouvé » (`A⏸2` reste 🔄). (b) **`adb` ne voit toujours pas le Galaxy A54 réel** — `A⏸4` ⏸. (c) **`NV-5`, tenue sur Android d'entrée de gamme réel, toujours ouvert** : toutes les mesures existantes viennent d'un émulateur. (d) Signature de publication (`A⏸3`) et préversion (`A⏸5`) restent ⏸ |
| 10 | **Hors-ligne de zone** — le `Must` d'[`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md) et d'`US-10` **n'est pas livré**. Le cache de tuiles ne couvre que les zones déjà parcourues | La question d'[`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) est **déplacée, pas résolue** : [`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md) ne tranche aucune de ses options A, B ou C |
| 11 | **Bibliothèque de graphes** pour la courbe de débit (`US-11`) — aucune relevée, aucune version citée | À trancher, par question fermée au commanditaire (`CLAUDE.md`). Hors T1 |
| 12 | **`gh` est absent du bac à sable** : PR, revues et opérations GitHub sont déléguées au commanditaire | Contrainte d'outillage, permanente |
| 13 | **Le lot clavier / souris et responsive** — [`04-ui.md`](04-ui.md) est écrite pour un écran étroit et le tactile, Windows est la seule cible construite | **Chiffré** : lot 5 de T1 (`K1`-`K3`). Premier point instruit : la molette (`NV-W1`, clos sans explication) |
| 14 | **`Q-01` à `Q-04` mesurés le 2026-09-18** (`T-15`, `docs/sources/hubeau-hydrometrie.md`) — l'endpoint répondait de nouveau après la panne du 13 (`T-10`). Codes multiples et `bbox` : **206**, tri global par `date_obs` décroissant sur le pool combiné, **sans garantie d'une mesure par station** (une station en retard peut n'apparaître dans aucune page) ; `sort=desc`/`asc` accepté. `fields` : **206**, filtre bien les champs (un seul 503 isolé rencontré en cours de lot, rejoué avec succès). Latence sur 10 appels : médiane **1,498 s**, min 0,230 s, max 4,069 s — un seul échantillon, un seul jour. Aucun en-tête `X-RateLimit-*` ni de cache | **Partiellement clos** : les quatre questions ont une réponse factuelle, mais sur une mesure unique — pas de campagne répétée. `D5` reste dans sa **forme garantie** (un appel par station) : l'appel groupé fonctionne mais change le contrat de tri (pas de garantie par station), une éventuelle bascule est une décision du commanditaire, pas engagée ici |
| 15 | **YAGNI du lot 1** — `ondeCampagnesUri`, `mapOndeCampaign` et `OndeCampaign` (`/campagnes`) n'avaient **aucun appelant hors tests**, et aucune tâche `V*`/`U*` du plan ne les consommait | **Fait le 2026-09-14** : retirés (`lib/domain/onde/onde_observation.dart`, `lib/data/mappers/onde_observation_mapper.dart`, `lib/data/http/onde_uris.dart`, tests miroirs). La fixture `/campagnes` et `T-07` restent — l'écart de type `code_campagne` reste un fait constaté, `_campaignCode` reste tolérant aux deux formes |
| 16 | **Trois amendements décidés en cours d'exécution, jamais soumis** : retrait d'`OndeClient` (plan l. 270), retrait de `findLatestForAll` (l. 301), `OndeObservation.point` (`D8`, l. 378) | À entériner ou à revoir. Le plan les porte déjà comme faits ; le commanditaire ne les a pas validés · ✅ **Entérinés par le commanditaire le 2026-09-18**, les trois |
| 17 | **Collision de nom public `EnEchec`** entre `lib/domain/observation/station_map_state.dart` et `lib/features/station_sheet/view_model/station_sheet_view_model.dart` | `V3` a **préfixé** ses états (`OndeSheetFermee`…) pour ne pas ajouter un troisième homonyme. Reste `StationSheetState` (`Fermee`/`EnCours`/`Prete`/`EnEchec`/`Introuvable`) contre `station_map_state.dart` : `U1` a évité d'importer les deux dans un même fichier ; à préfixer si `W4` doit le faire |
| 18 | **`open()` de `StationSheetViewModel` fait deux requêtes** (débit **et** hauteur), en parallèle | **Clos par `U1`** : la feuille affiche la hauteur avec sa date, les deux requêtes sont consommées |
| 19 | **Le fuseau affiché est « UTC »** dans `stalenessNotice` (`JJ/MM/AAAA à HH:MM UTC`) | `U1` a **gardé UTC explicite** (`JJ/MM/AAAA à HH:MM UTC`) pour rester déterministe et cohérent avec `V1` ; l'heure locale reste une question fermée au commanditaire, non posée · ✅ **Arbitré le 2026-09-22 : heure locale, sans suffixe** (« 27/08/2026 à 10:00 »), fuseau **injecté** pour des tests déterministes. Réalisé par la tâche `H1` du plan T1 (formateur de date unique, `U1` et `V1` réalignés) — **clos** côté décision, 🔄 côté code jusqu'à `H1` |
| 20 | **Les dix décisions du plan T1** — **engagées par le code** : 2 (état = fraîcheur, sans teinte inventée), 4 (au tap, forme garantie ; préchargement borné à 20 écrit en `V2`, non encore appelé par une vue avant `U2`), 5 (forme garantie), 10 (ordre des lots). **Réversibles sans toucher au code** : 1 (percentiles hors T1), 3 (`shared_preferences`), 6 (aucun framework BDD), 7 (traçabilité à la main), 8 (fenêtre 800 × 600), 9 (version d'avertissement datée) | À valider. Les quatre premières coûtent un réusinage si elles sont revues · ✅ **Décision 3 (`shared_preferences`) validée le 2026-09-18** (point 1) ; les autres restent à valider |
| 21 | **`NV-W6` — chaque cran de molette déclenche un rechargement, sans anti-rebond.** `MapEventScrollWheelZoom` n'a pas de variante `…End` dans `flutter_map` 8.3.2 : un zoom de cinq crans fait cinq allers-retours au dépôt et cinq reconstructions des 4 150 marqueurs | Ouvert le 2026-09-13, **non mesuré**. À instruire avec `NFR-01` et `NV-W3` ([`nfr.md`](nfr.md)) |
| 22 | **Caches résiduels sous `android/` sur le poste** — 2 580 830 523 octets de caches Gradle datés du 2026-08-24, hérités de l'outillage précédent | **Réécrit le 2026-09-18, après la levée du différé.** Le **gabarit Flutter** de `android/` est désormais **versionné** (`A⏸1`) ; seuls les **caches résiduels** restent à supprimer, **par le commanditaire**, et ne se committent jamais. Flutter construit dans `build/` à la racine, pas dans `android/app/build` : ces caches sont **inertes pour Flutter**. Le test rouge « le dossier android n'existe pas » disparaît avec son retrait de `ios_bundle_identifier_test` (alignement Android en TDD, en cours le 2026-09-18) |
| 23 | **Six PNG hérités d'Expo** restent versionnés sous `assets/` sans qu'aucun code ne les référence : `android-icon-background`, `android-icon-foreground`, `android-icon-monochrome`, `favicon`, `icon`, `splash-icon` | À retirer, ou à réaffecter le jour où les icônes Flutter sont posées. Décision du commanditaire · ✅ **Arbitré le 2026-09-18 : retirés dans `X5`**, avec la purge React Native, en un seul commit |
| 24 | **La PR de `feat/t1-mvvm-fiche-station` n'est pas ouverte** ; la branche n'est pas fusionnée sur `dev` | À ouvrir **par le commanditaire** — `gh` est absent du bac à sable (ligne 12) · **Branche poussée sur `origin` le 2026-09-18** à la demande du commanditaire ; la PR reste à ouvrir par lui |
| 25 | **Bug ONDE des codes à espaces** — au lancement, la carte affichait un bandeau rouge et **zéro station** : 507 lignes sur 10 234 portent un code hors `^[A-Z0-9]{8}$` (`A721 3011`, `S224`, `" O968 5312 "`), et l'exception d'une ligne faisait tomber toute la page | **Corrigé le 2026-09-14** (`T-14`, [`sources/onde.md`](sources/onde.md)) : code conservé **verbatim**, ligne illisible **ignorée et comptée**, `RangeError`/`IndexError` relancés ; commit `69f51b5`, relu. **`U6` a remonté le compte jusqu'à l'écran** : `OndeSweep.unreadableRows` est rattaché à l'appel, traverse le décorateur de cache avec le balayage qu'il décrit, et `UnreadableRowsNotice` le dit (« N points d'observation non lisibles sur cette emprise. ») ; le champ mutable `skippedRowCount`, sans lecteur, est **supprimé**. ⚠️ **Non élucidé** : les codes à espaces de bord ne sont retrouvables **sous aucune forme** en requête (`%20O968%205312%20` → 0, `O968%205312` → 0), alors qu'ils apparaissent en réponse par emprise. Ouvert aussi : `A721 3011` et `A7213011` sont-ils deux points, un doublon, ou un recodage ? Aucune fusion tant que ce n'est pas établi |
| 26 | **`Q-05` amendé** — `code_ecoulement` à `null` n'est pas un cas synthétique : **700 lignes sur 10 234** à l'échelle nationale (6,8 %), sur 29 campagnes, 20 dates et 17 départements | Constaté le 2026-09-14 (`T-14 e`). Le mapper les rend déjà en `Inconnu(null)` (`BR-011`) — sans incidence sur le code, mais l'écran verra ce cas souvent, ce que le cadrage ne supposait pas |
| 27 | **L'axe « remplissage » de la pastille de station est déjà pris par la fraîcheur.** `04-ui.md § 2` réserve motif et remplissage au **niveau de percentile** (hachures serrées « Très bas », larges « Bas », plein « Habituel »…) et donne à « Indéterminé » des **hachures croisées** ; `U2` y encode la **fraîcheur** (`BR-005` : plein / atténué / creux) et ne dessine pas les hachures. Sans percentile il n'y a qu'un niveau, donc aucun conflit — avec l'asset d'`ADR-003`, une station « Bas » **et** périmée n'aura plus d'axe libre | **Ouvert, constaté le 2026-09-14** (relecture de `U2`). Rien n'est changé au rendu. ❓ Question fermée : *l'atténuation de fraîcheur passe-t-elle sur le **halo** ou sur l'**opacité globale** de la pastille quand les percentiles arriveront ?* Recommandation : **l'opacité globale**, en vérifiant le halo à ≥ 3:1 (`04-ui.md § 3`) — elle libère motif et teinte pour le percentile |
| 28 | **`Inconnu` → « Non renseigné » dévie d'[`ADR-006`](adr/ADR-006-onde-quatre-categories.md)** — l'ADR range un code d'écoulement inconnu sous « Non observé » ; la **sixième ligne de légende** le nomme autrement, pour que le fait de terrain constaté (« Non observé », code `4`) et notre propre ignorance d'un code ne portent jamais le même mot (`BR-007`). Le rendu visuel, lui, suit l'ADR : même teinte, même forme, même motif | **À acter.** Constaté et retenu à la relecture de `U3` du 2026-09-14, porté par le domaine (`flowCategoryLabel`) depuis le même jour. ❓ Question fermée : *garde-t-on « Non renseigné » comme sixième libellé, au prix d'une déviation d'`ADR-006` ?* Recommandation : **oui** — `BR-007` est une règle métier, la ligne d'`ADR-006` un choix de regroupement visuel, et les deux se tiennent sans se contredire · ✅ **Arbitré le 2026-09-18 : oui**, « Non renseigné » est gardé — amendement daté d'`ADR-006`, commentaire de `flow_category.dart` aligné |
| 29 | **Aucune phrase de spec pour « aucune station sur l'échelle débit ».** `02-specifications.md § 4` et `BR-007` ne donnent que « Il n'y a ni station de mesure ni point d'observation dans le secteur affiché… » — or sur l'échelle **débit** l'ONDE n'est pas interrogée (`BR-008`) : la moitié de cette phrase affirmerait une lecture qui n'a pas eu lieu | **Ouvert, constaté le 2026-09-14** (relecture de `U6`). En attendant, `U6` rend la **formulation de repli** de `BR-007` — « Aucune donnée disponible ici. » — avec « Élargir la recherche ». ❓ Question fermée : *faut-il une phrase de spec dédiée pour « aucune station sur l'échelle débit » ?* Recommandation : **oui**, à écrire dans `02-specifications.md § 4` par `eva` — le repli est correct mais avare, et `glossary.md` fait foi sur toute reformulation · ✅ **Arbitré le 2026-09-18** : phrase dédiée retenue (candidate C d'`eva`), écrite dans `02-specifications.md § 4` et `BR-007`, recopiée à l'écran à la place du repli. La bascule vers l'échelle « Écoulement » depuis l'avis est un besoin distinct, **non retenu** : changement de périmètre d'`UC-001 A2` |
| 30 | **Tap arbitraire entre marqueurs superposés** — au zoom national, 4 150 zones de tap de 44 pt se chevauchent ; `flutter_map` 8.3.2 empile les marqueurs dans l'ordre de la liste et le hit-test rend le plus tardif de l'asset, pas le plus proche du doigt. `04-ui.md § 3` demande un regroupement des zones qui se chevauchent ; `F2` non tranchée, `F2c` sans regroupement retenue par défaut | **Écart assumé pour T1, acté dans le plan (`U1`)** — à confirmer par le commanditaire · ✅ **Confirmé par le commanditaire le 2026-09-18** : écart accepté pour T1, à reprendre avec `X3` et `F2` |
| 31 | **Le nom du département existe dans l'asset** (`libelle_departement`, ex. « LOIR-ET-CHER ») mais `parseStations` ne le remonte pas dans `Station` : les fiches affichent « Département 41 » | Lacune du mapper, pas une contrainte de données — à traiter quand une fiche doit se lire sans connaître les codes INSEE (`harold`) |
| 32 | **`BR-001` « … et sa source, visibles au même endroit »** : aucune fiche ne nomme Hub'Eau à côté d'une valeur ; `W4` (encart de fiche) ne le prévoit pas non plus | Lacune antérieure à T1, à porter dans `W4` ou dans un amendement de `BR-001` (`harold`) · **Porté par `W4`** (révision du 2026-09-22) : l'encart daté et la fiche station nomment la source Hub'Eau à côté de la valeur et de sa date ; se clôt avec `W4` |
| 33 | **Annonce des marqueurs au lecteur d'écran** — `U2`/`U3` posent un nœud sémantique par marqueur (nom, état, échelle, date de campagne), mais rien n'est constaté avec un lecteur d'écran réel (`04-ui.md § 3`, `UC-006 A5`) | Non vérifié, hors périmètre des tests automatisés ; à constater sur Windows (Narrateur) au plus tard en `K2` |
| 34 | **`W4` : un encart d'avertissement partagé par les deux feuilles** ne peut pas être importé par deux tranches (règle `feature-vers-feature` de `layers_test.dart`) | ❓ Question fermée avant `W4` : un emplacement commun hors `features/` (une couche de plus qu'`ADR-014` ne décrit pas — arbitrage) ou une recopie par tranche comme pour les 44 pt (déjà trois occurrences) ? Recommandation : **un dossier `lib/features/shared/`** admis explicitement par une sixième règle de `layers_test.dart` (importable par toute tranche, n'importe aucune tranche) — à acter avec `harold` · ✅ **Arbitré le 2026-09-18 : `lib/features/shared/`**, règle `shared-sans-tranche` écrite dans `layers_test.dart` avant le code, amendement d'`ADR-014`. `lib/ui/core/` et la recopie par tranche sont écartés |
| 35 | **Prérequis T2 : `RestrictionSource` vit sous `lib/data/restrictions/restriction_source.dart`** — un ViewModel de l'écran des restrictions ne pourra pas l'importer (règle `features-vers-data` de `layers_test.dart`), alors que tous les autres contrats de dépôt sont déclarés dans `lib/domain/repositories/repositories.dart` | Constaté le 2026-09-22 (bilan de conception). **Hors T1** : à déplacer vers `lib/domain/` au début de T2, avec un modèle de restriction écrit d'après une **fixture VigiEau réelle et datée** (`CLAUDE.md`, anti-hallucination). C'est aussi en T2 que l'encart renforcé de `BR-013` trouve son écran |
| 36 | **Constat d'écran du lot 3, partiel (2026-09-22, Windows, `flutter run`, deux captures du commanditaire)** — **vu :** fond IGN et attribution, bascule des deux puces (marqueurs et légende changent ensemble), points ONDE sous leurs quatre formes plus le cercle pointillé, légende « débit » avec « ◇ ? Indéterminé » et sa phrase `BR-004`, aucun bandeau rouge. **Vu aussi :** « Non observé » et « Non renseigné » portent le même cercle pointillé (écart assumé, `onde_marker.dart`) ; la quasi-totalité des losanges sont à l'état `NonChargee`, légendé « Chargement en cours » alors que rien ne charge | **Libellé arbitré le 2026-09-22 : « Sélectionnez pour charger »** (verbe neutre souris, clavier, toucher ; conforme à `BR-014`, qui vise un usage de l'eau), appliqué dans `map_legend.dart`. 🔄 **Pas encore vu :** sélection d'une station → fiche, sélection d'un point ONDE → fiche, avis sur emprise déserte — à constater avant `W2` |

## Constats d'API du 2026-07-31

Relevés avant la bascule de stack, et **indépendants d'elle** :

| Constat | Détail |
|---|---|
| `size` | `C-08` dit ≤ 20 000 (code : `maxPageSize = 20000`, constaté sur `observations_tr`) ; le constat du 2026-07-31 sur le référentiel disait `size=20000` → HTTP 400 `ValidatePageSize`, capture faite à `size=10000`. **Contradiction non réconciliée, à vérifier par appel réel** |
| **200 et 206 coexistent** | `size=1` → **206** ; `size=5000` (≥ 4 140 résultats) → **200**. Confirme `C-06` en production, et reconfirmé le 2026-09-13 (`V-01`, `V-08`) |
| Volume | **4 140 stations** en service, **6,57 Mo** en GeoJSON brut, 0 géométrie manquante. ⚠️ **Re-mesuré le 2026-08-15 : 4 150 stations, 6 604 249 octets** — le référentiel bouge |
| Codes station | 4 150 codes distincts, **tous à 10 caractères** — cohérent avec `C-05` |

### Écoulement ONDE — constaté les 2026-09-13 et 2026-09-14, par appel réel (lot 1 de T1, puis correctif `T-14`)

| Constat | Détail |
|---|---|
| `T-01` / `T-03` | `/v1/ecoulement/observations` **accepte `bbox`** (HTTP 206, `count` 1 448 sur l'emprise Loire) **et `date_observation_min`** (`count` 30 au lieu de 1 448). La carte n'a **pas** besoin de passer par le département |
| `T-04` | `?code_station=K4520001&sort=desc` → 206, `count` **96** : le code de station est la clé de l'historique d'un point. ⚠️ ~~à **8 caractères**~~ — **invalidé le 2026-09-14, voir `T-14`** |
| `T-05` / `T-06` | `/campagnes?code_departement=41` → 206, `count` 96, `api_version` `1.2.0` ; `libelle_type_campagne` en **minuscules** (`"usuelle"`) — `C-10` reproduit |
| `T-07` | 🚨 **`code_campagne` change de type selon l'endpoint** : **entier** `109905` dans `/campagnes`, **chaîne** `"109905"` dans `/observations`. Un modèle qui le type en `int` casse sur l'un des deux. Fait **nouveau**, absent du cadrage |
| `T-08` | `date_observation` est **une date sans heure** (`"2026-08-25"`) : `BR-010` se calcule en **jours** |
| `T-09` | Une observation ONDE porte ses coordonnées **deux fois** — `latitude`/`longitude` à plat **et** `geometry` GeoJSON. C'est ce qui rend `D8` possible sans appel supplémentaire |
| `Q-05` | **Répondu : zéro** `code_ecoulement` à `null` sur la fixture d'emprise. Zéro est une réponse. ⚠️ **Amendé le 2026-09-14** : vrai de la Loire seulement — **700 sur 10 234** à l'échelle nationale (`T-14 e`) |
| `T-10` | 🚨 `/v2/hydrometrie/observations_tr` **indisponible ce jour-là** — voir la ligne 14 de « Ce qui bloque » |
| `T-14` | 🚨 **Le code de station ONDE est une chaîne libre** (2026-09-14) : sur 10 234 lignes nationales, **507** hors `^[A-Z0-9]{8}$`, **147 codes distincts** — `A721 3011` (espace), `S224` (4 caractères), `" O968 5312 "` (espaces de bord). **L'espace est significatif** : `A721%203011` → count 40, `A7213011` → count 63. Détail : [`sources/onde.md`](sources/onde.md) § `T-14`, ligne 25 de « Ce qui bloque » |

### Carte — ce qui reste vrai quelle que soit la stack

| Fait | Constat | Source |
|---|---|---|
| WMTS IGN — capacités | **HTTP 200**, `application/xml`, 2,86 Mo (2026-07-31) | `data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetCapabilities&VERSION=1.0.0` |
| WMTS IGN — tuile | **HTTP 200**, `image/png`, **256×256** en `TILEMATRIXSET=PM` — donc adressable en `{z}/{x}/{y}` (2026-07-31) | même hôte, `REQUEST=GetTile&TILEMATRIX=5&TILECOL=16&TILEROW=11` |
| WMTS IGN — tuile, recapture | **HTTP 200**, `image/png`, **31 087 octets** sur `GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2`, `TILEMATRIX=9` (2026-09-13, `V-13`) | `data.geopf.fr/wmts?…` |
| Zoom 19 servi | Le géoplateforme sert **aussi** le zoom 19 (constaté par appel réel). Le zoom natif **18** retenu par `M1` est un **choix de charge**, pas une limite de la source | plan T0, écart `M1` |

> Les vérifications de 2026-07-31 portant sur le SDK de cartographie de la stack précédente
> (chemin de code du téléchargement hors-ligne, versions de paquets npm, signature de `createPack`)
> sont **caduques** et rangées dans l'historique, en fin de document.

## Points non vérifiés, assumés comme tels

Une case vide est une case vide, pas un « probablement ».

- **`NV-W3`** — aucune mesure chiffrée de fluidité sur Windows (`NFR-01`). Ouvert, sans date.
- **`NV-W4`** — iOS n'a **jamais été compilé**, faute d'hôte macOS. Sans date.
- **`NV-W5`** — ~~Android ⏸ différé le 2026-09-12~~ **amendé le 2026-09-18 : le différé est levé.** Ce
  qui reste non vérifié est plus précis qu'avant : **l'application n'a jamais été construite ni
  lancée sur Android sous Flutter** — ni sur l'émulateur `Pixel_7`, pourtant démarré ce jour-là, ni
  sur appareil réel. Sans date : `flutter run -d emulator-5554` revient au commanditaire.
- **`NV-W6`** — le rechargement à chaque cran de molette, **jamais mesuré** : on ne sait pas si son
  coût est visible. Ouvert le 2026-09-13.
- **`Q-01` à `Q-04`** — appel groupé, `bbox`, `fields` et latence de `/v2/hydrometrie` : quatre
  questions posées, **aucune réponse**, l'endpoint ayant rendu 503 puis 500 toute la journée du
  2026-09-13.
- **Une zone de carte jamais chargée, hors réseau** — non constatée. Le cache de tuiles a été
  éprouvé **sur les zones déjà parcourues seulement**, et le bandeau « tuiles manquantes » n'existe
  pas.
- **La contrainte SDK minimale** de `flutter_map`, `latlong2` et `http` — non affichée sur pub.dev,
  non vérifiée.
- Version exacte de la **Licence Ouverte Etalab** pour Hub'Eau (1.0 ou 2.0).
- Fenêtre du `X-RateLimit-Limit: 300` de **VigiEau**.
- Sémantique du paramètre `departement` de VigiEau `/arretes_restrictions`.
- Existence du niveau `vigilance` dans VigiEau — non observé le 2026-07-30.
- Mapping entre `nombre_modalite_ecoulement` (4 ou 5) et les codes ONDE disponibles.
- **Tenue sur Android d'entrée de gamme réel** (`NV-5`) — jamais mesurée. « Attendu meilleur »
  n'est pas « mesuré », et l'arbitrage ⏸ ne rend pas le besoin caduc.

## Prochaine étape

**Lot 4 — les avertissements** (`W1`→`W3`, `H1`, `W4`, `W5`) : **plus aucune question ne le bloque** depuis le 2026-09-18 (`ADR-011` écrit, `lib/features/shared/` arbitré et verrouillé). Avant tout : **`flutter run -d windows` par le commanditaire** — rien du lot 3 n'a été vu à l'écran (feuille au tap, bascule d'échelle, points ONDE, fiche ONDE, avis d'absence). **Et, depuis la levée du différé Android du 2026-09-18, un second constat d'écran est dû : `flutter run -d emulator-5554`** — l'émulateur `Pixel_7` tourne, mais l'app n'a jamais été construite ni lancée sur Android sous Flutter ; c'est ce lancement qui fera passer `A⏸2` de 🔄 à ✅. Puis lots 5 à 7, dont `X5`, la purge React Native (ADR remplacés gardés, arbitré le 2026-09-18). Le fichier de poste `CLAUDE.local.md` porte le brief de reprise de cette session ; il est ignoré par git et à réécrire une fois la reprise faite.

⚠️ **Points encore à trancher par le commanditaire** : 27 (axe de remplissage quand les percentiles arriveront), 22 (caches résiduels sous `android/` du poste, à supprimer **par lui** — le gabarit, lui, est versionné depuis le 2026-09-18), 24 (ouvrir la PR), 14 (garder la forme garantie de `D5` — recommandé, l'appel groupé ne garantit pas une mesure par station), 3 et 5 bis (périmètre). **Arbitrés le 2026-09-18** : 1, 16, 20-3, 23, 28, 29, 30, 34. **Arbitrés le 2026-09-22** : 19 (heure locale sans suffixe, via `H1`) et le report de `BR-013` en T2.

---

<details>
<summary><strong>Historique — React Native (2026-07-31 → 2026-09-12) et .NET (2026-07-30 → 07-31)</strong></summary>

> ⚠️ Les hashes cités dans cet historique sont ceux de l'arbre git antérieur au 2026-09-12 (`archive/pre-flutter-2026-09-09`, absent de ce clone) : **aucun n'est résolvable ici**.

**Deux socles applicatifs abandonnés en six semaines.** Le cadrage produit n'a été refait ni l'une
ni l'autre fois — c'est ce qui a rendu ces bascules soutenables, et il ne faut pas en conclure
qu'elles étaient bon marché. Ce qui suit est **du passé** : aucune ligne n'y décrit l'état actuel.

### .NET MAUI Blazor Hybrid — 2026-07-30 → 2026-07-31

Retiré du *working tree* le 2026-07-31 sur arbitrage du commanditaire (`74afe6d`), après
[`ADR-005`](adr/ADR-005-stack-maui-blazor-hybrid.md). Étaient livrés : `src/MartinPecheur.App`
(3 cibles vertes, `696be3a`), les projets `Domain` / `Application` / `Data` / `tests` (`22e9850`),
et `MeasurementUnits.cs` avec 8 tests verts. Motif de l'abandon : le hors-ligne cartographique était
un **lot de développement à chiffrer** en .NET.

### React Native + Expo — 2026-07-31 → 2026-09-12

Plan suivi : `T0 — Socle React Native` (`docs/superpowers/plans/2026-07-31-t0-socle-react-native.md`,
**retiré du dépôt** depuis). Vérification verte au 2026-08-15 : `tsc --noEmit` sans erreur, ESLint
propre, **149 tests** sur 18 suites.

| Tâche | Livrable | Commit |
|---|---|---|
| `S1`, `S2` | Projet Expo `57.0.9`, TypeScript `6.0.3`, `tsconfig` durci | `08bf832` |
| `S3` | Jest projet `unit` + ESLint + test d'architecture | `8c6ed61` |
| `S4` | Référentiel figé — 4 150 stations, 6 604 249 octets | `0a76733` |
| `D1`-`D4` | Conversion d'unités par types *branded*, nomenclature ONDE close, fraîcheur, entités et dépôts | `17d3359`, `37cd92a`, `20842be`, `42948e8` |
| `N1`-`N5` | `isSuccess` 200/206, recul à gigue, mapper, client Hub'Eau, décorateur `CachePolicy` | `5504b3c`, `b13a11b`, `dbb74d3`, `2cf3ad2` |
| `M1`-`M3` | MapLibre 11.3.6 compile, fond IGN raster affiché, clustering des 4 150 stations | `b035424`, `0c3596a` |
| `P1`-`P4` | Outillage percentiles — aspiration `obs_elab`, quinzaines, poids mesuré, procédure | `e535e27`, `0954f9e` |

**Ce qui a tué la stack — `M4`, le pack hors-ligne.** Exécuté le **2026-08-15**,
`OfflineManager.createPack` **tue le processus** : `SIGABRT` sur une `std::regex_error` non
rattrapée dans le fil `DatabaseFileSource`, ~0,7 s après la création du pack, **4 essais sur 4**,
base vierge comprise, avec le style vectoriel de démonstration — donc ni l'IGN ni le raster en
cause. **Zéro requête HTTP** avant la mort. Reproduit le **2026-08-18** sur `arm64` réel (Galaxy
A54 5G, Android 16) — ⚠️ par observation seule, la signature n'y a pas été relevée.

**Option E, 2026-08-24 — épuisée, pas démontrée épuisée.** Le SDK natif est épinglable par
propriété Gradle : `13.0.0`, `13.1.0`, `13.2.0` et `13.5.1` plantent **à l'identique** ; `12.0.0` ne
compile pas (`ColorReliefLayer` absent), ce qui bornait l'espace de recherche à
`[13.0.0 … 13.5.1]`. Huit versions intercalaires n'ont jamais été essayées.
Arbitrage : [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md), puis bascule Flutter
([`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md)).

**Le `createPack` n'a jamais été départagé.** « Que `createPack` télécharge les tuiles d'un WMTS
IGN » est resté **ni confirmé ni infirmé** : l'appel plantait avant qu'une tuile soit téléchargée.
Idem pour `tileset.tiles[0]` (`NV-3`), le volume d'un pack départemental (`NV-4`, **aucun octet
mesuré**) et l'absence de test amont du chemin raster hors-ligne (`NV-6`).

### La leçon qui resservira si Android revient

**Installer le SDK Android sur un chemin sans espace ni parenthèse.** Le NDK ne les supporte pas :
sous un chemin du type `Program Files (x86)`, Windows réduit le chemin en notation 8.3, `clang++.exe` devient
`CLANG_~1.EXE`, et **clang choisit son mode C ou C++ d'après son propre nom d'exécutable**. Privé de
ses `++`, il compile en C et ne lie pas la bibliothèque standard C++ — le symptôme, des symboles
C++ manquants au link, **ne désigne jamais le chemin**. Deux diagnostics faux (« NDK trop ancien »,
« NDK incomplet ») ont été écrits avant celui-là.

Basculer `ANDROID_HOME` vers le SDK utilisateur (`%LOCALAPPDATA%\Android\Sdk`) — sans espace,
**inscriptible sans élévation** — a levé les trois obstacles d'un coup le 2026-08-15, et `M1` a
compilé (`app-debug.apk`, 58 Mo). Deux autres pièges relevés ce jour-là :

- **`sdkmanager` en ligne de commande échoue en silence** : il n'affiche que
  `Failed to read or create install properties file`, ne renvoie aucun code d'erreur et n'écrit
  rien. Ne pas le re-tenter.
- **Sonder le registre (`HKCU\Environment`), pas l'environnement du processus** : un inventaire
  publié plus tôt le 2026-08-15 déclarait l'outillage Android absent — **il était faux sur les cinq
  lignes**.

</details>

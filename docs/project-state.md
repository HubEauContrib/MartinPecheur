# État du projet

**Mis à jour :** 2026-09-14 — reprise de `feat/t1-mvvm-fiche-station` (audit du **lot 1 de T1**).

> Ce document est l'**état vivant** du projet. En cas de contradiction avec le code, **le code a
> raison** — et ce document se corrige dans le même commit.

## Arbitrages récents

| Date | Arbitrage |
|---|---|
| 2026-09-12 | **Porte de spike Flutter franchie** sur `F1` (fond IGN, Windows) + `F3` (exécutable Windows). `F2` non tranchée ; approche par défaut de la carte : marqueurs du viewport plus marge, sans clustering. Compte rendu : `spike/porte_flutter/COMPTE-RENDU.md` |
| 2026-09-12 | **Android ⏸ différé jusqu'à nouvel ordre.** Windows seule cible construite ; iOS configuré, jamais compilé. Toute tâche Android d'un plan est marquée ⏸, ni supprimée ni comptée faite |
| 2026-09-12 | **Arbre git frais** : `dev` repart d'un commit racine unique ; spike et outillage précédent sous le tag `archive/pre-flutter-2026-09-09`. **Plus d'outillage Node** : le générateur de percentiles (`ADR-003`) sera un script Dart |
| 2026-09-13 | **Pas de briefs de session dans `docs/`.** La spec s'étoffe de six documents : fiches de sources avec fixtures datées (`docs/sources/`), critères d'acceptation Gherkin (`docs/acceptance/`, T1), `docs/nfr.md`, matrice de traçabilité (T1), `docs/domain-model.md`, `CHANGELOG.md` + `docs/plan-de-tests.md` |
| 2026-09-13 | **Architecture : feature-first + MVVM** (recommandation de l'équipe Flutter) remplace le CQRS léger. `domain/` et `data/` conservés ; bus, `Query`/`Command` et gestionnaires retirés à l'ouverture de T1 ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), plan T0 § « Suite immédiate ») — **fait** le 2026-09-13 sur cette branche (`9043df1`) |
| 2026-09-13 | **Réusinage `R1`-`R6` exécuté sur `feat/t1-mvvm-fiche-station`** — `69ac82e` (`R1`, [`ADR-014`](adr/ADR-014-feature-first-mvvm.md)), `1bb1810` (`R2`), `b6e9aec` (`R3`), `9043df1` (`R4`), `7541928` puis `0a668be` (`R5`), `2681e12` + `7913b1a` + `9911982` + `fe1b92e` (`R6`), plus les correctifs de relecture `ce4f719` et `43a18cd`. **244 tests** à la clôture (`fe1b92e`) |
| 2026-09-13 | **Plan T1 écrit et ouvert** — [`2026-09-13-t1-fiche-station-et-avertissements.md`](superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md), **7 lots**, **31 tâches actives** au récapitulatif, **10 décisions à valider** (`68151f6`, préalable MVVM levé par `6caac28`) |
| 2026-09-14 | **Branche de travail : `feat/t1-mvvm-fiche-station`.** La branche `refactor/feature-first-mvvm` (7 commits, **doublon du même réusinage**) est **abandonnée, non fusionnée** : elle reste dans le clone, rien n'en sera repris. [`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md) y a été **reporté** (seul apport non redondant, avec cette réécriture de `project-state.md`) : commit `docs` du 2026-09-14 sur cette branche |
| 2026-09-14 | **Audit de reprise du lot 1 de T1 par un second agent** : lot 1 (`D1`→`D8`) et `V1` **repris tels quels**, aucun défaut bloquant. Cinq points ouverts remontés au commanditaire (§ « Ce qui bloque », lignes 15 à 19) |

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
| **T1 — fiche station, écoulement ONDE, avertissements** | Carte interactive (tap, fiche), fiches station et ONDE, **les quatre avertissements** | 🔄 **en cours.** **Lot 1 (`D1`→`D8`) clos**, **`V1` fait** ; restent `V2`→`V4` puis les **lots 3 à 7** (vues, avertissements, clavier/souris, documentation, porte `0.2.0`) |
| **T2** | Sécheresse et restrictions (VigiEau) | 🔄 |
| **T3** | Favoris, filtres, fraîcheur | 🔄 |

**Le cadrage produit est terminé et vérifié** — il ne dépend d'aucune technologie et n'a été refait
à aucune des deux bascules de stack.

🚨 **Rien de tout cela n'est un produit.** Aucun des quatre avertissements obligatoires n'est posé
(`BR-012`, `BR-013`) : `CLAUDE.md` interdit toute mise en production tant qu'ils manquent. Ils sont
le **lot 4 de T1** (`W1`→`W5`), et rien n'est livrable avant eux.

## Ce qui est acquis

| Sujet | État |
|---|---|
| Analyse des APIs | ✅ Vérifiée par appels HTTP réels les 2026-07-30 et 07-31, **recapturée le 2026-09-13** (14 faits `V-01` à `V-14` du plan T0, puis `T-01` à `T-13` du plan T1) |
| Question centrale du « débit suffisant » | ✅ Tranchée (`ADR-002`) et documentée avec ses limites |
| Sources retenues et écartées | ✅ 7 APIs évaluées, motifs documentés |
| Règles métier | ✅ **14 règles**, chacune avec son test |
| Cas d'usage | ✅ **6 cas**, flux nominaux et alternatifs |
| Avertissements | ✅ Les 4 emplacements **spécifiés**, textes rédigés — 🔄 **aucun n'est posé dans le code** (lot 4 de T1) |
| Stack | ✅ **Flutter / Dart**, Windows première cible ([`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md), arbitrage du commanditaire du 2026-09-12) |
| Architecture | ✅ **feature-first + MVVM** ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), arbitrage du 2026-09-13) — vue → ViewModel → dépôt → domaine, sans bus ni médiateur, verrouillée par cinq règles de couches |
| Socle de domaine | ✅ Unités en `extension type` (`BR-002`), conversion l/s → m³/s et mm → m **à un seul endroit**, fraîcheur aux bornes de `BR-005`, nomenclature close à branche `Inconnu` (`BR-011`), `StationCode` à dix caractères qui refuse un code site (`C-05`) |
| Socle de données hydrométrie | ✅ Client Hub'Eau **v2** (200 **et** 206 en succès, retry 429/5xx jamais 4xx, recul à gigue injectée), mapper unique, référentiel lu depuis l'asset embarqué, `RestrictionSource` **interface seule** |
| Domaine de l'écoulement ONDE (`D2`) | ✅ `OndeStationCode` (8 car.), `OndePoint`, `OndeObservation`, âge de campagne en **jours calendaires** (`BR-010`, `T-08`), `StationMapState` — `Chargee`/`SansDonnee`/`NonChargee`/`EnEchec` |
| Mapper ONDE (`D3`) | ✅ `mapOndeObservation` / `mapOndePoint`, testés sur la **fixture réelle du 2026-09-13** ; `code_ecoulement` lu en texte, jamais par un cast nu ; `flowCategoryFromCode` réutilisé, pas recopié |
| URI ONDE (`D4`) | ✅ `ondeObservationsBboxUri`, `ondeObservationsStationUri` posées **sur le `HubEauClient` existant** — aucun second client (`OndeClient` retiré). `fields` à dix champs, dates formatées en **UTC** |
| Dépôt d'observations hydrométriques (`D5`, `D6`) | ✅ `HttpHydroObservationRepository` dans sa **forme garantie** (un appel par station), décoré par `CachedHydroObservationRepository` — `withCachePolicy`, TTL **20 min**, chiffre unique dans `lib/` |
| Dépôt d'écoulement (`D7`, `D8`) | ✅ `HttpOndeObservationRepository` (emprise et point) + `CachedOndeObservationRepository` — TTL **30 j** de mai à septembre, **90 j** hors saison ; une observation ONDE **porte son point**, lu sur la même ligne d'API |
| ViewModel de fiche station (`V1`) | ✅ `StationSheetViewModel` — `Fermee`/`EnCours`/`Prete`/`EnEchec`, horloge injectée, **aucun widget importé** ; libellés balayés en **mots entiers** contre le vocabulaire interdit (`BR-003`) |
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
  features/        map/{view,view_model}/ · station_sheet/view_model/
  main.dart        racine de composition — à la racine de lib/, seul fichier exempt de la règle « features/ n'importe pas data/ »
```

⚠️ **`StationPoint`, le filtre d'emprise et `Bounds` vivent dans `lib/domain/`** —
`lib/domain/station/station_point.dart`, `lib/domain/geo/viewport_filter.dart`,
`lib/domain/geo/bounds.dart` — et non sous `lib/data/referentiel/` : le filtre est un calcul pur
sur des `double`, et deux couches le consomment (le dépôt de points, la carte). Le dépôt de points
de carte, lui, est `AssetStationPointRepository`
(`lib/data/referentiel/asset_station_point_repository.dart`) ; son contrat
`StationPointRepository` est déclaré dans `lib/domain/repositories/repositories.dart`.

`test/architecture/layers_test.dart` verrouille **cinq règles**, nommées dans son en-tête :

1. `domaine-ferme` — un fichier de `domain/` n'importe rien du projet hors `domain/`.
2. `data-vers-features` — un fichier de `data/` n'importe aucune tranche de fonctionnalité.
3. `view-model-sans-widget` — un ViewModel n'importe ni `material.dart`, ni `widgets.dart`, ni
   `cupertino.dart` (`foundation.dart` reste autorisé : c'est de là que vient `ChangeNotifier`).
4. `feature-vers-feature` — une tranche n'importe pas une autre tranche.
5. `features-vers-data` — aucun fichier sous `features/` n'importe `data/`, **`main.dart` excepté**.

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
| `A⏸1`-`A⏸5` | Plateforme Android, outillage natif, signature, appareil réel, préversion | ⏸ **différées le 2026-09-12** — listées, jamais comptées faites |

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
| `V2`-`V4` | `MapViewModel` enrichi, `OndeSheetViewModel`, `WarningsViewModel` | 🔄 à faire |
| Lots 3 à 7 | Vues (`U1`-`U6`), avertissements (`W1`-`W5`), clavier/souris (`K1`-`K3`), documentation (`X1`-`X4`), porte `0.2.0` (`P1`, `P2`) | 🔄 à faire |

Documentation du lot : `68151f6` (plan), `6caac28` (préalable levé), `e21b08e` (lot 1 clos),
`9cfcb6c` (`V1` fait).

> ⚠️ **Le récapitulatif du plan T1 annonce 31 tâches actives et compte le lot 1 comme `D1`→`D7`
> (7).** Le corps du plan porte un **`D8`**, ajouté par amendement le 2026-09-13 : le décompte réel
> est de **32 tâches actives**. Écart non corrigé dans le plan.

### Tests — l'état exact sur ce poste

**427 tests, 426 verts sur ce poste** (`flutter test`, 2026-09-14, sortie `+426 -1`). Le seul rouge
est `test/project/ios_bundle_identifier_test.dart` : « le dossier android n'existe pas ». Il est
rouge **tant qu'un dossier `android/` traîne hors dépôt** — ce dossier n'est pas versionné, le test
dit vrai sur le dépôt et faux sur le poste. Pour mémoire : 248 à la fin de T0, **244** à la clôture
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
| 1 | **Stockage local** — `ADR-011` **réservé**, aucun moteur choisi. `drift` candidat par défaut ; `sqflite` seul **ne couvre pas Windows** | À trancher **au moment où un écran en aura besoin**. Le plan T1 `W1` propose `shared_preferences` **2.5.5** (BSD-3-Clause, Windows, relevé le 2026-09-13) pour l'acquittement seul, `ADR-011` laissant le moteur structuré ouvert |
| 2 | Trois ADR tranchés **sans arbitrage du commanditaire** : `ADR-002`, `ADR-004`, `ADR-006` | Décisions par défaut, réversibles. Chacune porte sa section « Si la décision est revue » |
| 3 | **Réduction de périmètre à valider** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 4 | Le cadrage annonçait **3 modalités ONDE** ; il y en a **6** (`ADR-006`) | Corrigé dans la spec |
| 5 | ~~Poids réel de l'asset de percentiles~~ — **mesuré le 2026-08-15** sur 40 stations réelles : 479 octets/station bruts, 177 gzip. Extrapolé à 4 150 : ≈ 2,0 Mo bruts, ≈ 0,73 Mo gzip. Le poids ne remet pas `ADR-003` en cause | Clos — reste à confirmer sur la passe complète (~2 h) |
| 5 bis | 🚨 **`Indéterminé` concerne près d'une station sur deux.** Sur l'échantillon : **19 stations sur 40 sans aucune quinzaine calculable**, 48,8 % des quinzaines. `ADR-002` fonde le positionnement statistique du débit sur cet asset ; pour la moitié des stations il n'existera **jamais** | **Ouvert.** Le commanditaire a demandé le 2026-08-15 de **confirmer sur la passe complète** avant d'en tirer une conséquence produit. ⚠️ **Or cette passe n'est pas lancée** (~2 h, décision « pas maintenant » le même jour) : le point reste donc en attente, sans échéance. Un échantillon de 200 stations le resserrerait en ~6 minutes |
| 6 | **Script de génération des percentiles** — en **Dart** désormais (`ADR-003`, arbitrage du 2026-09-12). `assets/percentiles/` n'existe pas | Lot d'outillage à chiffrer. **Hors T1** (décision 1 du plan) : conséquence assumée, sur l'échelle « débit » toute station est `Indéterminé` au sens de `BR-004` |
| 7 | **Hôte macOS** pour produire un build iOS — `NV-W4`, sans date | **Matériel.** Bloquant pour livrer iOS, pas pour développer |
| 8 | **`NV-W3` — aucune mesure de fluidité sur Windows.** `NFR-01` (rastérisation p90 ≤ 16,7 ms, trames en retard < 5 %) est **non mesuré** sur la seule cible construite ; le binaire de T0 a été jugé à l'œil | Ouvert, sans date ([`nfr.md`](nfr.md)). Programmé en `X3` de T1 |
| 9 | **Android ⏸ différé** (`NV-W5`, arbitrage du 2026-09-12). Dettes héritées du spike, toujours dues : NDK **28.2** absent (épingle `27.1.12297006`), `adb` ne voyant pas le Galaxy A54, `NV-5` (tenue sur Android réel) ouvert | Arbitrage à lever avant toute reprise |
| 10 | **Hors-ligne de zone** — le `Must` d'[`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md) et d'`US-10` **n'est pas livré**. Le cache de tuiles ne couvre que les zones déjà parcourues | La question d'[`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) est **déplacée, pas résolue** : [`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md) ne tranche aucune de ses options A, B ou C |
| 11 | **Bibliothèque de graphes** pour la courbe de débit (`US-11`) — aucune relevée, aucune version citée | À trancher, par question fermée au commanditaire (`CLAUDE.md`). Hors T1 |
| 12 | **`gh` est absent du bac à sable** : PR, revues et opérations GitHub sont déléguées au commanditaire | Contrainte d'outillage, permanente |
| 13 | **Le lot clavier / souris et responsive** — [`04-ui.md`](04-ui.md) est écrite pour un écran étroit et le tactile, Windows est la seule cible construite | **Chiffré** : lot 5 de T1 (`K1`-`K3`). Premier point instruit : la molette (`NV-W1`, clos sans explication) |
| 14 | 🚨 **`Q-01` à `Q-04` restent ouverts** — `/v2/hydrometrie/observations_tr` a répondu **503 sur 19 tentatives** le matin du 2026-09-13 (plus un 502 après 67 s et un timeout sec), puis **500 sur sept appels** l'après-midi (13:34:49 → 13:35:26 UTC), `T-10`. Appel groupé, `bbox`, `fields` et latence médiane sont donc **non mesurés** | `D5` est implémenté dans sa **forme garantie** — un appel par station — et l'interface du dépôt ne changera pas si la réponse arrive. `C-15` n'est pas rédactionnel : c'est le régime observé |
| 15 | **YAGNI du lot 1** — `ondeCampagnesUri`, `mapOndeCampaign` et `OndeCampaign` (`/campagnes`) n'avaient **aucun appelant hors tests**, et aucune tâche `V*`/`U*` du plan ne les consommait | **Fait le 2026-09-14** : retirés (`lib/domain/onde/onde_observation.dart`, `lib/data/mappers/onde_observation_mapper.dart`, `lib/data/http/onde_uris.dart`, tests miroirs). La fixture `/campagnes` et `T-07` restent — l'écart de type `code_campagne` reste un fait constaté, `_campaignCode` reste tolérant aux deux formes |
| 16 | **Trois amendements décidés en cours d'exécution, jamais soumis** : retrait d'`OndeClient` (plan l. 270), retrait de `findLatestForAll` (l. 301), `OndeObservation.point` (`D8`, l. 378) | À entériner ou à revoir. Le plan les porte déjà comme faits ; le commanditaire ne les a pas validés |
| 17 | **Collision de nom public `EnEchec`** entre `lib/domain/observation/station_map_state.dart` et `lib/features/station_sheet/view_model/station_sheet_view_model.dart` | Sans conséquence aujourd'hui — à préfixer **au premier fichier qui importe les deux**, ce qui arrivera en `U1` ou `V2` |
| 18 | **`open()` de `StationSheetViewModel` fait deux requêtes** (débit **et** hauteur), en parallèle | Conforme **si `U1` affiche la hauteur**. À confirmer en `U1` : sinon c'est un appel réseau pour rien, sur une API sans quota documenté (`C-12`, `NFR-07`) |
| 19 | **Le fuseau affiché est « UTC »** dans `stalenessNotice` (`JJ/MM/AAAA à HH:MM UTC`) | À trancher en `U1` : UTC est exact et vérifiable, l'heure locale est lisible par l'usager. Les deux se défendent ; le choix n'a pas été porté au commanditaire |
| 20 | **Les dix décisions du plan T1** — **engagées par le code** : 2 (état = fraîcheur, sans teinte inventée), 4 (au tap, forme garantie — le préchargement borné à 20 reste à écrire en `V2`), 5 (forme garantie), 10 (ordre des lots). **Réversibles sans toucher au code** : 1 (percentiles hors T1), 3 (`shared_preferences`), 6 (aucun framework BDD), 7 (traçabilité à la main), 8 (fenêtre 800 × 600), 9 (version d'avertissement datée) | À valider. Les quatre premières coûtent un réusinage si elles sont revues |
| 21 | **`NV-W6` — chaque cran de molette déclenche un rechargement, sans anti-rebond.** `MapEventScrollWheelZoom` n'a pas de variante `…End` dans `flutter_map` 8.3.2 : un zoom de cinq crans fait cinq allers-retours au dépôt et cinq reconstructions des 4 150 marqueurs | Ouvert le 2026-09-13, **non mesuré**. À instruire avec `NFR-01` et `NV-W3` ([`nfr.md`](nfr.md)) |
| 22 | **Un dossier `android/` non versionné traîne sur le poste** — 989 fichiers, **2 580 830 523 octets**, caches Gradle datés du 2026-08-24, hérités de l'outillage précédent | **À supprimer, jamais à commiter.** C'est lui qui rend `ios_bundle_identifier_test` rouge. Le dépôt, lui, n'a pas de dossier `android/` : c'est l'arbitrage ⏸ du 2026-09-12 |
| 23 | **Six PNG hérités d'Expo** restent versionnés sous `assets/` sans qu'aucun code ne les référence : `android-icon-background`, `android-icon-foreground`, `android-icon-monochrome`, `favicon`, `icon`, `splash-icon` | À retirer, ou à réaffecter le jour où les icônes Flutter sont posées. Décision du commanditaire |
| 24 | **La PR de `feat/t1-mvvm-fiche-station` n'est pas ouverte** ; la branche n'est pas fusionnée sur `dev` | À ouvrir **par le commanditaire** — `gh` est absent du bac à sable (ligne 12) |

## Constats d'API du 2026-07-31

Relevés avant la bascule de stack, et **indépendants d'elle** :

| Constat | Détail |
|---|---|
| `size` | `C-08` dit ≤ 20 000 (code : `maxPageSize = 20000`, constaté sur `observations_tr`) ; le constat du 2026-07-31 sur le référentiel disait `size=20000` → HTTP 400 `ValidatePageSize`, capture faite à `size=10000`. **Contradiction non réconciliée, à vérifier par appel réel** |
| **200 et 206 coexistent** | `size=1` → **206** ; `size=5000` (≥ 4 140 résultats) → **200**. Confirme `C-06` en production, et reconfirmé le 2026-09-13 (`V-01`, `V-08`) |
| Volume | **4 140 stations** en service, **6,57 Mo** en GeoJSON brut, 0 géométrie manquante. ⚠️ **Re-mesuré le 2026-08-15 : 4 150 stations, 6 604 249 octets** — le référentiel bouge |
| Codes station | 4 150 codes distincts, **tous à 10 caractères** — cohérent avec `C-05` |

### Écoulement ONDE — constaté le 2026-09-13, par appel réel (lot 1 de T1)

| Constat | Détail |
|---|---|
| `T-01` / `T-03` | `/v1/ecoulement/observations` **accepte `bbox`** (HTTP 206, `count` 1 448 sur l'emprise Loire) **et `date_observation_min`** (`count` 30 au lieu de 1 448). La carte n'a **pas** besoin de passer par le département |
| `T-04` | `?code_station=K4520001&sort=desc` → 206, `count` **96** : le code à **8 caractères** est la clé de l'historique d'un point |
| `T-05` / `T-06` | `/campagnes?code_departement=41` → 206, `count` 96, `api_version` `1.2.0` ; `libelle_type_campagne` en **minuscules** (`"usuelle"`) — `C-10` reproduit |
| `T-07` | 🚨 **`code_campagne` change de type selon l'endpoint** : **entier** `109905` dans `/campagnes`, **chaîne** `"109905"` dans `/observations`. Un modèle qui le type en `int` casse sur l'un des deux. Fait **nouveau**, absent du cadrage |
| `T-08` | `date_observation` est **une date sans heure** (`"2026-08-25"`) : `BR-010` se calcule en **jours** |
| `T-09` | Une observation ONDE porte ses coordonnées **deux fois** — `latitude`/`longitude` à plat **et** `geometry` GeoJSON. C'est ce qui rend `D8` possible sans appel supplémentaire |
| `Q-05` | **Répondu : zéro** `code_ecoulement` à `null` sur la fixture d'emprise. Zéro est une réponse |
| `T-10` | 🚨 `/v2/hydrometrie/observations_tr` **indisponible ce jour-là** — voir la ligne 14 de « Ce qui bloque » |

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
- **`NV-W5`** — Android ⏸ différé le 2026-09-12. Sans date.
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

**`V2` — `MapViewModel` : un état par station, une seule échelle, un préchargement borné.**
Concrètement : `MapScaleKind { ecoulement, debit }` avec **une seule échelle active à la fois**
(`BR-008`), `stateOf(StationCode)` rendant `NonChargee` tant que rien n'est chargé (`BR-007`,
jamais un état par défaut), et `preloadVisibleStations(limit: 20)` **borné et annulable** — jamais
national (`NFR-07`, décision 4).

⚠️ **À faire d'abord : trancher les points 15 à 20 de « Ce qui bloque ».** Les décisions 2, 4, 5
et 10 sont déjà engagées par le code du lot 1 ; les revoir après `V2` coûterait un réusinage. Les
points 17 (`EnEchec`) et 19 (fuseau UTC) se règlent au plus tard en `U1`.

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

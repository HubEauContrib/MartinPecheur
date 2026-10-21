# Documentation MartinPêcheur

Spec vivante du projet. Tout vit dans **ce dépôt** : code et spec évoluent dans le même commit.

MartinPêcheur informe les usagers d'une rivière française sur son état — écoulement, débit,
sécheresse — à partir des APIs publiques Hub'Eau et VigiEau, et de la vigilance crues publiée par Vigicrues. Application **Flutter — Windows en première cible**, iOS configuré (jamais compilé), Android actif en débogage, sa publication différée (amendement d'`ADR-013`) —
**sans backend, sans compte utilisateur**.

> 📍 **Où commencer** — [`project-state.md`](project-state.md) est la **source de vérité des
> statuts**. Si un autre document le contredit, c'est lui qui a raison ; et si le code contredit
> les deux, c'est le code.

## Organisation

| Dossier | Contenu | Convention de nom |
|---|---|---|
| [`br/`](br/) | **Business Rules** — règles métier invariantes, indépendantes de l'implémentation | `BR-NNN-slug.md` |
| [`use-cases/`](use-cases/) | **Use Cases** — scénarios acteur↔système, avec diagrammes mermaid | `UC-NNN-slug.md` |
| [`adr/`](adr/) | **Architecture Decision Records** — décisions tranchées, avec alternatives écartées | `ADR-NNN-slug.md` |
| [`superpowers/plans/`](superpowers/plans/) | Plans d'implémentation par tranche | `YYYY-MM-DD-slug.md` |
| [`superpowers/specs/`](superpowers/specs/) | **Cadrages et conceptions** par tranche : ce qui est décidé avant le plan, avec ses arbitrages (index plus bas) | `YYYY-MM-DD-slug-design.md` |
| [`sources/`](sources/) | **Fiches de sources de données** — faits vérifiés et datés, fixtures associées | `<source>.md` |
| [`acceptance/`](acceptance/) | **Critères d'acceptation Gherkin** — spécification lisible, chaque `Scénario` cite une `BR-` qui existe sur le disque (`test/project/acceptance_features_test.dart`) ; aucun framework BDD : jamais exécutés. Un fichier par sujet, dont [`restrictions.feature`](acceptance/restrictions.feature) (T2), [`filtres.feature`](acceptance/filtres.feature) (`US-13`) et [`favoris.feature`](acceptance/favoris.feature) (`US-14`) | `slug.feature` |
| [`glossary.md`](glossary.md) | **Langage omniprésent** — termes métier, ce qui est dit à l'usager, vocabulaire proscrit | — |
| [`context-map.md`](context-map.md) | **Carte des contextes** — les contextes bornés et leurs sources externes | — |
| [`domain-model.md`](domain-model.md) | **Modèle de domaine** — objets-valeur, entités, agrégats, ce que le domaine ne contient pas | — |
| [`nfr.md`](nfr.md) | **Exigences non fonctionnelles** — seuils chiffrés, et constats ouverts | — |
| [`project-state.md`](project-state.md) | **État vivant** — où on en est, ce qui bloque | — |
| [`guide-installation.md`](guide-installation.md) | Installation du poste de développement, et ses pièges | — |
| [`plan-de-tests.md`](plan-de-tests.md) | **Plan de tests** — la pyramide, à quel étage une règle se vérifie | — |
| [`tracabilite.md`](tracabilite.md) | **Matrice de traçabilité** — US, BR, UC et leur fichier de test, maintenue à la main et vérifiée par `test/project/tracabilite_test.dart` (`Task X2`) | — |

## Cadrage produit

Les quatre livrables de cadrage, en tête de dossier :

| Document | Contenu |
|---|---|
| [`01-analyse.md`](01-analyse.md) | Personas, parcours, sources retenues et écartées, **17 contraintes d'API vérifiées** |
| [`02-specifications.md`](02-specifications.md) | Arbitrage du « débit suffisant », user stories MoSCoW, cas limites |
| [`03-conception.md`](03-conception.md) | Architecture, modèle de données, cache, arborescence des écrans |
| [`04-ui.md`](04-ui.md) | Wireframes, code couleur des états, accessibilité |

## Plans d'implémentation

Statuts : [`project-state.md`](project-state.md).

| Plan | Tranche |
|---|---|
| [`2026-08-24-porte-spike-flutter.md`](superpowers/plans/2026-08-24-porte-spike-flutter.md) | Porte de spike `F1`–`F3` — compte rendu : `spike/porte_flutter/COMPTE-RENDU.md` |
| [`2026-09-13-t0-socle-flutter.md`](superpowers/plans/2026-09-13-t0-socle-flutter.md) | **T0** — socle Flutter, domaine, données, carte, porte Windows · § « Suite immédiate » : réusinage MVVM `R1`–`R6` · 31 tâches, plus 5 tâches Android hors décompte (`A⏸1` à `A⏸5`) |
| [`2026-09-13-t1-fiche-station-et-avertissements.md`](superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md) | **T1** — fiche station, écoulement ONDE, les quatre avertissements, clavier/souris, porte `0.2.0` ; 42 tâches |
| [`2026-09-27-t2-secheresse-et-restrictions.md`](superpowers/plans/2026-09-27-t2-secheresse-et-restrictions.md) | **T2** — sécheresse et restrictions (VigiEau) : domaine, données, ViewModel, écran des restrictions, encart renforcé, écran des sources, choix « Restrictions » du sélecteur, documentation, porte Windows **et** Android ; 29 tâches |
| [`2026-10-12-t3-favoris-filtres-fraicheur.md`](superpowers/plans/2026-10-12-t3-favoris-filtres-fraicheur.md) | **T3** — favoris, filtres de la carte, critère de fraîcheur ; 50 tâches sur 11 lots, filtres avant favoris ; porte Windows **et** Android |
| [`2026-10-14-t4-crues-vigicrues.md`](superpowers/plans/2026-10-14-t4-crues-vigicrues.md) | **T4** — crues : vigilance Vigicrues en quatrième lecture, fiche tronçon ; 28 tâches sur 8 lots |
| [`2026-10-17-ergonomie.md`](superpowers/plans/2026-10-17-ergonomie.md) | **Ergonomie** — sélecteur et bloc de lecture, bas de la carte, fiche du bas et panneau latéral, fiches hiérarchisées, bouton « Retour » ; en lots, les tâches ajoutées en cours de route étant portées par le plan lui-même ; porte Windows **et** Android |
| [`2026-10-21-t5-suivi-des-lieux.md`](superpowers/plans/2026-10-21-t5-suivi-des-lieux.md) | **T5** — être prévenu : favori tronçon, « Me prévenir », vérification à l'ouverture (`FollowUpCheck`), écran « Avis reçus », annonce sur la carte, essais de tâche de fond `E-A` et `E-W` ; 33 tâches sur 10 lots ; version `1.1.0` ; porte Windows **et** Android |

## Cadrages et conceptions par tranche

Les documents de [`superpowers/specs/`](superpowers/specs/), dans l'ordre. Un cadrage dit **quoi** et
arbitre ; une conception dit **comment** et arbitre aussi. Chacun porte, en tête, son statut et la date
de ses arbitrages ; le plan correspondant est ci-dessus.

| Document | Contenu |
|---|---|
| *(retirés le 2026-10-21)* | Le design de la bascule du 2026-08-24 et celui du test sur appareil réel du 2026-08-18, antérieurs à la porte de spike, retirés avec les ADR des stacks antérieures ; ils restent dans l'historique git |
| [`2026-09-22-revision-plan-t1-design.md`](superpowers/specs/2026-09-22-revision-plan-t1-design.md) | Révision du plan de T1 (`BR-013` reporté en T2, `H1`, `H2`) |
| [`2026-09-27-cadrage-t2-design.md`](superpowers/specs/2026-09-27-cadrage-t2-design.md) | **T2** — cadrage produit (`eva`) : Q1 à Q10, arbitrés le 2026-09-27 |
| [`2026-09-27-modele-restrictions-t2-design.md`](superpowers/specs/2026-09-27-modele-restrictions-t2-design.md) | **T2** — modèle du domaine « restrictions », contrat `RestrictionSource`, emplacement des fichiers (`harold`) |
| [`2026-09-27-ecran-restrictions-t2-design.md`](superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md) | **T2** — écran des restrictions, désignation d'un point, écran « D'où vient cette donnée ? » (`C1`, arbitrages Q-1 à Q-8) |
| [`2026-10-03-cadrage-t4-t5-crues-design.md`](superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md) | **T4** (crues, vigilance Vigicrues) et **T5** (être prévenu) : les deux tranches, leur ordre et ce que chacune doit prouver ; arbitré le 2026-10-03 |
| [`2026-10-12-cadrage-t3-design.md`](superpowers/specs/2026-10-12-cadrage-t3-design.md) | **T3** — cadrage : favoris, filtres, fraîcheur ; huit arbitrages du 2026-10-12 |
| [`2026-10-14-cadrage-t4-design.md`](superpowers/specs/2026-10-14-cadrage-t4-design.md) | **T4** — cadrage détaillé : treize arbitrages, approuvé le 2026-10-14 ; faits de la source : [`sources/vigicrues.md`](sources/vigicrues.md) |
| [`2026-10-17-cadrage-t5-design.md`](superpowers/specs/2026-10-17-cadrage-t5-design.md) | **T5** — cadrage détaillé : avis sur les lieux suivis, vérification à l'ouverture, essais de tâche de fond sur Windows et Android ; dix-sept arbitrages, approuvé le 2026-10-17 ; plan écrit le 2026-10-21 sur les écrans refaits, après la tranche d'ergonomie |
| [`2026-10-17-cadrage-ergonomie-design.md`](superpowers/specs/2026-10-17-cadrage-ergonomie-design.md) | **Ergonomie** — cadrage, avant T5 : bloc de lecture unique, fiche du bas et panneau latéral, fiches hiérarchisées, points d'interface 49, 51, 60, 61, 63, 64 ; douze arbitrages à l'approbation du 2026-10-17, les suivants pris en cours de tranche (§ 2 du document) ; version `0.6.0` |

## Index des décisions

| # | Décision | Statut |
|---|---|---|
| [ADR-001](adr/ADR-001-api-hydrometrie-v2.md) | Cibler l'API hydrométrie **v2** — la v1 est arrêtée | Accepté |
| [ADR-002](adr/ADR-002-qualification-du-debit.md) | Ne jamais qualifier un débit de « suffisant » | Accepté ⚠️ |
| [ADR-003](adr/ADR-003-reference-percentiles-en-asset.md) | Percentiles pré-calculés dans un asset embarqué | Accepté |
| [ADR-004](adr/ADR-004-integration-vigieau.md) | VigiEau derrière une abstraction, repli data.gouv **différé** (amendé le 2026-09-27) | Accepté ⚠️ — **en partie arbitré le 2026-09-27** (chemin nominal, `SUP` d'abord, appel unique, confinement) ; ses autres choix restent tranchés par défaut |
| [ADR-006](adr/ADR-006-onde-quatre-categories.md) | ONDE en 4 catégories d'affichage | Accepté ⚠️ |
| [ADR-007](adr/ADR-007-ecarter-qualite-eau.md) | Écarter la qualité de l'eau de la v1 | Accepté |
| [ADR-011](adr/ADR-011-stockage-local.md) | **Stockage local : `shared_preferences`** pour la préférence simple | Accepté — arbitrage du commanditaire du 2026-09-18, **portée limitée** ; **amendé le 2026-10-12** (T3, arbitrage 2) : les favoris y entrent, une clé, une chaîne JSON ; moteur structuré toujours ouvert |
| [ADR-013](adr/ADR-013-bascule-flutter-cible-windows.md) | **Flutter, Windows première cible** construite | Accepté — arbitrage du 2026-09-12, écrit a posteriori le 2026-09-13 |
| [ADR-014](adr/ADR-014-feature-first-mvvm.md) | **Feature-first + MVVM** (`ChangeNotifier`), à la place du CQRS léger | Accepté — arbitrage du commanditaire du 2026-09-13 |
| [ADR-015](adr/ADR-015-regroupement-par-zone-administrative.md) | **Regroupement par zone administrative** sous le zoom 9 (région, puis département), `F2c` au-delà | Accepté — arbitrage du commanditaire du 2026-09-22 |
| [ADR-016](adr/ADR-016-integration-vigicrues.md) | **Intégrer Vigicrues derrière une abstraction** (`FloodVigilanceSource`), GeoJSON national mis en cache | Accepté ⚠️ — **en partie arbitré le 2026-10-14** (1, 6, 10, 12) ; les choix d'architecture `R1` à `R5` sont tranchés par défaut |
| [ADR-018](adr/ADR-018-empaquetage-msix-microsoft-store.md) | **Empaquetage MSIX pour le Microsoft Store** par le paquet `msix`, en dépendance de développement (`ADR-017` est réservé par le cadrage de T5) | Accepté — arbitrages du commanditaire du 2026-10-21 (version `1.0.0`, outil `msix`) |

⚠️ = tranché par défaut, **sans arbitrage du commanditaire**. Réversible : chaque ADR porte une
section « Si la décision est revue ».

Les numéros `005`, `008`, `009`, `010` et `012` portaient les ADR écrits pour les stacks antérieures
à Flutter : retirés le 2026-10-21 sur arbitrage du commanditaire, ils ne sont jamais réutilisés.

> ✅ **`ADR-011` n'est plus réservé** — il est **tranché le 2026-09-18**, par arbitrage du
> commanditaire, et **seulement sur la préférence simple** : `shared_preferences` pour une clé et
> une chaîne, la version d'avertissement acquittée. Le **moteur de donnée structurée**
> (dernière vue, cache d'observations persistant) **reste à trancher quand un écran en aura
> besoin** — `drift` candidat par défaut, `sqflite` seul **ne couvrant pas Windows**.
> **Amendé le 2026-10-12** (arbitrage 2 de T3) : les **favoris** entrent dans la préférence
> simple — une clé, une chaîne JSON versionnée, derrière `FavoriteRepository` (`S3` de T3).
> ✅ La dépendance est dans `pubspec.yaml` et utilisée par `SharedPreferencesAcknowledgementRepository`
> depuis la tâche `W1` de T1 (2026-09-22) ; son câblage dans `main.dart` vient avec `W2`.

## Index des règles métier

| # | Règle | Contexte |
|---|---|---|
| [BR-001](br/BR-001-date-de-mesure-obligatoire.md) | Aucune valeur sans sa date de mesure | Transverse |
| [BR-002](br/BR-002-debit-en-metres-cubes-par-seconde.md) | Le débit est affiché en m³/s | Hydrometrie |
| [BR-003](br/BR-003-jamais-qualifier-un-debit-de-suffisant.md) | Un débit n'est jamais « suffisant » | Hydrometrie |
| [BR-004](br/BR-004-historique-insuffisant-indetermine.md) | Historique < 10 ans : « Indéterminé » | Hydrometrie |
| [BR-005](br/BR-005-donnee-perimee-signalee.md) | Donnée périmée signalée et atténuée | Hydrometrie · Carte |
| [BR-006](br/BR-006-statut-de-qualification-toujours-affiche.md) | Statut de qualification toujours affiché | Hydrometrie |
| [BR-007](br/BR-007-absence-de-donnee-jamais-neutre.md) | L'absence n'est jamais un état neutre | Carte |
| [BR-008](br/BR-008-une-seule-echelle-a-la-fois.md) | Une seule échelle d'état à la fois | Carte |
| [BR-009](br/BR-009-cluster-porte-l-etat-le-plus-severe.md) | Le cluster porte l'état le plus sévère | Carte |
| [BR-010](br/BR-010-age-de-campagne-onde-affiche.md) | L'âge de la campagne ONDE est affiché | Ecoulement |
| [BR-011](br/BR-011-nomenclature-tolerante-a-l-inconnu.md) | Toute nomenclature tolère l'inconnu | Transverse |
| [BR-012](br/BR-012-acquittement-au-premier-lancement.md) | Acquittement explicite au 1er lancement | Avertissement |
| [BR-013](br/BR-013-avertissement-renforce-sur-ecrans-ressource.md) | Avertissement renforcé sur les écrans ressource | Avertissement |
| [BR-014](br/BR-014-aucun-verbe-d-instruction.md) | Aucun verbe d'instruction sur un usage de l'eau | Transverse |

## Index des cas d'usage

| # | Cas d'usage | Acteur principal |
|---|---|---|
| [UC-001](use-cases/UC-001-consulter-la-carte-autour-de-moi.md) | Consulter l'état de la rivière autour de moi | Citoyen riverain |
| [UC-002](use-cases/UC-002-consulter-les-restrictions.md) | Consulter les restrictions applicables à mon usage | Agriculteur / irrigant |
| [UC-003](use-cases/UC-003-consulter-une-station-hydrometrique.md) | Consulter le détail d'une station | Usager de loisir |
| [UC-004](use-cases/UC-004-consulter-un-point-onde.md) | Consulter un point d'observation ONDE | Pêcheur |
| [UC-005](use-cases/UC-005-consulter-la-carte-hors-ligne.md) | Consulter la dernière carte hors ligne | Pêcheur |
| [UC-006](use-cases/UC-006-acquitter-l-avertissement-initial.md) | Acquitter l'avertissement initial | Tout usager |
| [UC-007](use-cases/UC-007-filtrer-la-carte.md) | Filtrer la carte | Pêcheur |
| [UC-008](use-cases/UC-008-suivre-un-lieu-en-favori.md) | Suivre un lieu en favori | Pêcheur |
| [UC-009](use-cases/UC-009-consulter-la-vigilance-crues.md) | Consulter la vigilance crues | Tout usager |

## Règles d'écriture

- **`NNN`** = numéro sur 3 chiffres, séquentiel, jamais réutilisé.
- **`slug`** = kebab-case court, en français, cohérent avec le titre.
- Un artefact = un fichier. On **ne supprime pas** un BR/UC/ADR obsolète : on passe son statut à
  `Remplacé par …`. Seule exception : les ADR des stacks antérieures à Flutter et les deux specs
  qui les accompagnaient, retirés le 2026-10-21 sur arbitrage du commanditaire (voir l'index des
  décisions et la table des cadrages).
- Les **diagrammes** sont **dispersés à côté de la sous-partie qu'ils illustrent** — séquence sous le
  flux nominal, cycle de vie sous l'invariant, composants sous la décision. Pas de section dédiée.
  Optionnels : seulement s'ils complètent le propos.
- Tous les diagrammes sont en **mermaid inline** — pas d'images binaires.

### La règle propre à ce projet

> **Tout fait relatif à une API publique est vérifié par appel réel, et daté.**
> Un fait non vérifié est signalé comme tel, avec l'URL consultée.
> On ne spécifie jamais d'après une documentation seule.

Ce n'est pas de la prudence rédactionnelle. Cette règle a déjà évité quatre erreurs bloquantes :
l'API v1 arrêtée, le débit en l/s et non en m³/s, les 6 modalités ONDE au lieu de 3, et l'absence
totale de seuils réglementaires en API. Elle continue de payer — le référentiel est passé de 4 140 à
**4 150 stations** entre le 2026-07-31 et le 2026-08-15, constaté en réexécutant l'appel.

## Quand créer quoi

- Une **règle métier** invariante (« aucune valeur sans sa date ») → **BR**.
- Un **scénario** d'usage avec acteurs, déclencheur, flux nominal et alternatifs → **UC**.
- Une **décision technique** structurante avec alternatives écartées → **ADR**.
- Une **contrainte d'API subie** (pagination, quota, unité) → tableau `C-xx` de
  [`01-analyse.md § 4`](01-analyse.md), pas un BR. Une contrainte n'est pas une règle métier.

> Templates : [`br/BR-template.md`](br/BR-template.md) ·
> [`use-cases/UC-template.md`](use-cases/UC-template.md) ·
> [`adr/ADR-template.md`](adr/ADR-template.md)

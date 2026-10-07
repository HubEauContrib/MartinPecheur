# Documentation MartinPêcheur

Spec vivante du projet. Tout vit dans **ce dépôt** : code et spec évoluent dans le même commit.

MartinPêcheur informe les usagers d'une rivière française sur son état — écoulement, débit,
sécheresse — à partir des APIs publiques Hub'Eau et VigiEau. Application **Flutter — Windows en première cible**, iOS configuré (jamais compilé), Android **réactivé le 2026-09-18** (différé levé, amendement d'`ADR-013`) — gabarit généré et émulateur démarré, **jamais construit ni lancé** —
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
| [`acceptance/`](acceptance/) | **Critères d'acceptation Gherkin** — spécification lisible, chaque `Scénario` cite une `BR-` qui existe sur le disque (`test/project/acceptance_features_test.dart`, `Task X1`) ; aucun framework BDD en T1 ni en T2. Cinq fichiers : les quatre de T1 et [`restrictions.feature`](acceptance/restrictions.feature) (T2, `X1`, 2026-10-04) | `slug.feature` |
| [`glossary.md`](glossary.md) | **Langage omniprésent** — termes métier, ce qui est dit à l'usager, vocabulaire proscrit | — |
| [`context-map.md`](context-map.md) | **Carte des contextes** — 6 contextes bornés et leurs sources externes | — |
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

| Plan | Tranche | Statut |
|---|---|---|
| [`2026-09-13-t0-socle-flutter.md`](superpowers/plans/2026-09-13-t0-socle-flutter.md) | **T0** — socle Flutter, domaine, données, carte, porte Windows · § « Suite immédiate » : réusinage MVVM `R1`–`R6` | ✅ clos le 2026-09-13, **31 tâches sur 31**, `v0.1.0`, 248 tests verts · les 5 tâches Android (hors décompte) ne sont plus toutes ⏸ depuis la levée du 2026-09-18 : `A⏸1` ✅, `A⏸2` 🔄, `A⏸3`→`A⏸5` ⏸ |
| [`2026-09-13-t1-fiche-station-et-avertissements.md`](superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md) | **T1** — fiche station, écoulement ONDE, les quatre avertissements, clavier/souris, porte `0.2.0` | ~~🔄 en cours sur `feat/t1-mvvm-fiche-station` — lots 1 à 3 clos (2026-09-14, 18 tâches sur 33), lot 4 débloqué par les arbitrages du 2026-09-18~~ ✅ **clos le 2026-09-27** — **42 tâches sur 42**, `v0.2.0` (tag sur `a664783`, PR #14 fusionnée sur `dev`) ; statuts à jour dans [`project-state.md`](project-state.md) |
| [`2026-09-27-t2-secheresse-et-restrictions.md`](superpowers/plans/2026-09-27-t2-secheresse-et-restrictions.md) | **T2** — sécheresse et restrictions (VigiEau) : domaine, données, ViewModel, écran des restrictions, encart renforcé, écran des sources, choix « Restrictions » du sélecteur, documentation, porte Windows **et** Android | 🔄 **en cours** — ~~sur `feat/t2-domaine` (poussée sur `origin`, non fusionnée sur `dev`, PR #17 en brouillon)~~ ✅ **PR #17 fusionnée sur `dev` le 2026-10-06 à 16:34** (`ff3d108`, squash ; la porte n'est pas franchie) ; ~~**travail en cours sur `fix/suites-relecture-pr17`** (depuis `dev` à `ff3d108`, seconde relecture de la PR #17, point 59 de [`project-state.md`](project-state.md) ; **PR #18 ouverte en brouillon** le 2026-10-06 au soir, six commits relus par trois seconds agents — fusionnables, aucun défaut de code —, trois commits de retouche non relus par un second agent)~~ ✅ **PR #18 fusionnée sur `dev` le 2026-10-06 à 18:00, heure de Paris** (`0a1fb6f`, squash, `gh pr view 18` ; fusion faite sous le compte `oliver254` ; `fix/suites-relecture-pr17` n'est plus sur `origin`) ; ~~**travail en cours sur `feat/t2-porte`**~~ ✅ **PR #19 fusionnée sur `dev` le 2026-10-06 à 20:16, heure de Paris** (`b95f1eb`, squash, sept commits, `gh pr view 19` ; fusion lancée par la boucle principale, à la demande du commanditaire, sous le compte `oliver254` ; l'arbre de `b95f1eb` est identique à celui de `feat/t2-porte` à son sommet `4c5a91a` ; `feat/t2-porte` existe encore, en local et sur `origin`, la supprimer revient au commanditaire ; aucun tag n'est posé, `v0.3.0` se posera à `P3` : réponse du commanditaire « Après la porte »), **la porte de T2 n'étant pas franchie** ; **branche de travail depuis le 2026-10-07 : `feat/t2-cloture`** (créée depuis `dev` à `b95f1eb`, ~~locale, non poussée, sans PR~~ **poussée sur `origin` le 2026-10-07, PR #20 ouverte vers `dev` le même jour** (15:35:24 UTC, soit 17:35 heure de Paris ; prête à relire, non en brouillon : choix du commanditaire ; `gh pr view 20` fait foi pour son état et ses commits) ; elle sert à clore `0.3.0` à `P3`) ; avant la fusion, `feat/t2-porte` (créée depuis `dev` à `0a1fb6f` le 2026-10-06 au soir, ~~locale, non poussée, sans PR ; quatre commits locaux~~ **poussée sur `origin` le même soir, PR #19 ouverte en brouillon vers `dev` (sommet `9cecb8a` à l'ouverture) ; cinq commits à l'ouverture** : `e27a6ac`, `6dbe8b2`, `39b462e`, `8730475`, `9cecb8a` — des commits de documents ont suivi sur la même PR (un document ne peut pas citer le commit qui le porte) : `61a80e8`, relu par un second agent, puis `4c5a91a`, **non relu par un second agent** ; `gh pr view 19` fait foi) ; la seconde relecture de la PR #17 (point 59 de [`project-state.md`](project-state.md)) portait six commits relus par trois seconds agents — fusionnables, aucun défaut de code —, puis trois commits de retouche, **relus le soir même par un second agent, fusionnables** (`8730475` corrige leurs commentaires) ; sur `feat/t2-porte`, le soir (puis entrés dans `dev` par la fusion de la PR #19) : « S'applique à la même zone » codé (`e27a6ac`), test de la phrase de `BR-007` écrite deux fois (`6dbe8b2`), **délai de 20 s pour Hub'Eau, 10 s pour VigiEau** (`39b462e`) ; trois sujets laissés en dette pour T3 (décision du commanditaire du 2026-10-06 au soir) — **24 tâches closes sur 29** au 2026-10-04, après `X4` ; `E4` est codée (`bbdfdc1`) mais son constat d'écran n'est fait que pour quatre points sur six, le deuxième avec une réserve (par le commanditaire, le 2026-10-04, en débogage sur Windows), elle reste ouverte et n'est pas comptée ; restent `A1`, les deux constats manquants de `E4`, la réserve de son point 2 et la porte `P1` à `P3` ; la version `0.3.0` est **ouverte** (`X4`), non publiée. ✅ codé et vérifié par test (~~2 318~~ **2 328 tests au 2026-10-06 au soir**, sur `feat/t2-porte` après `39b462e` ; 2 318 au sommet `81a0b78` de `fix/suites-relecture-pr17`, puis de même au sommet `0a1fb6f` de `dev` ; 2 315 plus tôt le même soir, au sommet `6b06f6f` ; 2 292 plus tôt le même jour, après la contrainte de caméra de la carte ; 2 274, après le traitement de la revue de la PR #17 ; 2 132 le 2026-10-04 avec `X4`, 2 126 avec `X3`, 2 125 au sommet), **la revue de la PR #17 (postée le 2026-10-04) est traitée en grande partie, ses sept commits poussés sur `origin` le 2026-10-06 (six à 12:41, un à 13:28) (`origin/feat/t2-domaine` au sommet `454935e`), la caméra de la carte étant contrainte au monde l'après-midi, `acb83f3`, poussé le 2026-10-06 à 14:20** (`project-state.md`, point 57), **les écrans de T2 ne sont constatés qu'en partie** — par le commanditaire, en débogage, sur Windows, le 2026-10-04 ; rien en release ni sur Android ; statuts à jour dans [`project-state.md`](project-state.md) |
| [`2026-08-24-porte-spike-flutter.md`](superpowers/plans/2026-08-24-porte-spike-flutter.md) | Porte de spike `F1`–`F3` | ✅ franchie le 2026-09-12 sur Windows — `spike/porte_flutter/COMPTE-RENDU.md` |

## Cadrages et conceptions par tranche

Les documents de [`superpowers/specs/`](superpowers/specs/), dans l'ordre. Un cadrage dit **quoi** et
arbitre ; une conception dit **comment** et arbitre aussi. Chacun porte, en tête, son statut et la date
de ses arbitrages ; le plan correspondant est ci-dessus.

| Document | Contenu |
|---|---|
| [`2026-08-18-test-appareil-reel-m4-m5-design.md`](superpowers/specs/2026-08-18-test-appareil-reel-m4-m5-design.md) | Usage d'un Android personnel pour trancher `M4` et `M5` de T0 |
| [`2026-08-24-bascule-flutter-trois-cibles-design.md`](superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md) | Bascule Flutter, Android, iOS et Windows, conditionnée à la porte de spike |
| [`2026-09-22-revision-plan-t1-design.md`](superpowers/specs/2026-09-22-revision-plan-t1-design.md) | Révision du plan de T1 (`BR-013` reporté en T2, `H1`, `H2`) |
| [`2026-09-27-cadrage-t2-design.md`](superpowers/specs/2026-09-27-cadrage-t2-design.md) | **T2** — cadrage produit (`eva`) : Q1 à Q10, arbitrés le 2026-09-27 |
| [`2026-09-27-modele-restrictions-t2-design.md`](superpowers/specs/2026-09-27-modele-restrictions-t2-design.md) | **T2** — modèle du domaine « restrictions », contrat `RestrictionSource`, emplacement des fichiers (`harold`) |
| [`2026-09-27-ecran-restrictions-t2-design.md`](superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md) | **T2** — écran des restrictions, désignation d'un point, écran « D'où vient cette donnée ? » (`C1`, arbitrages Q-1 à Q-8) |
| [`2026-10-03-cadrage-t4-t5-crues-design.md`](superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md) | **T4** (crues, vigilance Vigicrues) et **T5** (être prévenu), prévues après T3 — non cadrées en détail |

## Index des décisions

| # | Décision | Statut |
|---|---|---|
| [ADR-001](adr/ADR-001-api-hydrometrie-v2.md) | Cibler l'API hydrométrie **v2** — la v1 est arrêtée | Accepté |
| [ADR-002](adr/ADR-002-qualification-du-debit.md) | Ne jamais qualifier un débit de « suffisant » | Accepté ⚠️ |
| [ADR-003](adr/ADR-003-reference-percentiles-en-asset.md) | Percentiles pré-calculés dans un asset embarqué | Accepté |
| [ADR-004](adr/ADR-004-integration-vigieau.md) | VigiEau derrière une abstraction, ~~avec repli~~ repli data.gouv **différé** (amendé le 2026-09-27) | Accepté ⚠️ — **en partie arbitré le 2026-09-27** (chemin nominal, `SUP` d'abord, appel unique, confinement) ; ses autres choix restent tranchés par défaut |
| [ADR-005](adr/ADR-005-stack-maui-blazor-hybrid.md) | ~~.NET MAUI Blazor Hybrid + MapLibre GL JS~~ | **Remplacé par ADR-010** |
| [ADR-006](adr/ADR-006-onde-quatre-categories.md) | ONDE en 4 catégories d'affichage | Accepté ⚠️ |
| [ADR-007](adr/ADR-007-ecarter-qualite-eau.md) | Écarter la qualité de l'eau de la v1 | Accepté |
| [ADR-008](adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md) | ~~CQRS léger, cache par décorateur de gestionnaire~~ | **Remplacé par ADR-014** — *seul survivant : le cache en un point unique* |
| [ADR-009](adr/ADR-009-cible-windows.md) | ~~Ajouter **Windows** aux cibles de la v1~~ | **Remplacé par ADR-010** — intention rétablie par ADR-013, sans réactivation |
| [ADR-010](adr/ADR-010-react-native.md) | ~~**React Native**, abandon de MAUI et de Windows~~ | **Remplacé par ADR-013** (stack, 2026-09-12) · volet architecture remplacé par ADR-014 |
| [ADR-011](adr/ADR-011-stockage-local.md) | **Stockage local : `shared_preferences`** pour la préférence simple | Accepté — arbitrage du commanditaire du 2026-09-18, **portée limitée** · ✅ réalisé par `W1` (`6b9e9ed`, 2026-09-22) — `shared_preferences` 2.5.5 dans `pubspec.yaml`, `SharedPreferencesAcknowledgementRepository` ; moteur structuré toujours ouvert |
| [ADR-012](adr/ADR-012-hors-ligne-cartographique-bloque.md) | 🚨 **Le hors-ligne cartographique est bloqué** — le téléchargement de packs plante en natif | **D exécutée** (le plantage se reproduit sur `arm64` réel), **E épuisée** ; question déplacée, non tranchée (`ADR-013`) ; le `Must` hors-ligne de `UC-005` reste non livré |
| [ADR-013](adr/ADR-013-bascule-flutter-cible-windows.md) | **Bascule Flutter, Windows première cible** construite | Accepté — arbitrage du 2026-09-12, écrit a posteriori le 2026-09-13 |
| [ADR-014](adr/ADR-014-feature-first-mvvm.md) | **Feature-first + MVVM** (`ChangeNotifier`), à la place du CQRS léger | Accepté — arbitrage du commanditaire du 2026-09-13 |
| [ADR-015](adr/ADR-015-regroupement-par-zone-administrative.md) | **Regroupement par zone administrative** sous le zoom 9 (région, puis département), `F2c` au-delà | Accepté — arbitrage du commanditaire du 2026-09-22 · ~~🔄 pas encore codé (lot 4 bis de T1, `Z2`→`Z4`)~~ ✅ codé (`Z2`→`Z4`) et constaté à l'écran sur Windows le 2026-09-23 |

⚠️ = tranché par défaut, **sans arbitrage du commanditaire**. Réversible : chaque ADR porte une
section « Si la décision est revue ».

> ✅ **`ADR-011` n'est plus réservé** — il est **tranché le 2026-09-18**, par arbitrage du
> commanditaire, et **seulement sur la préférence simple** : `shared_preferences` pour une clé et
> une chaîne, la version d'avertissement acquittée. Le **moteur de donnée structurée** (favoris,
> dernière vue, cache d'observations persistant) **reste à trancher quand un écran en aura
> besoin** — `drift` candidat par défaut, `sqflite` seul **ne couvrant pas Windows**.
> ✅ La dépendance est dans `pubspec.yaml` et utilisée par `SharedPreferencesAcknowledgementRepository`
> depuis la tâche `W1` de T1 (`6b9e9ed`, 2026-09-22) ; son câblage dans `main.dart` vient avec `W2`. Son numéro sort dans le désordre : `ADR-012` a été écrit avant lui, le
> 2026-08-15, parce que l'exécution de `M4` l'a imposé.

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

## Règles d'écriture

- **`NNN`** = numéro sur 3 chiffres, séquentiel, jamais réutilisé.
- **`slug`** = kebab-case court, en français, cohérent avec le titre.
- Un artefact = un fichier. On **ne supprime pas** un BR/UC/ADR obsolète : on passe son statut à
  `Remplacé par …`.
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

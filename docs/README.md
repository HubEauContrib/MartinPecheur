# Documentation MartinPêcheur

Spec vivante du projet. Tout vit dans **ce dépôt** : code et spec évoluent dans le même commit.

MartinPêcheur informe les usagers d'une rivière française sur son état — écoulement, débit,
sécheresse — à partir des APIs publiques Hub'Eau et VigiEau. Application mobile iOS et Android,
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
| [`glossary.md`](glossary.md) | **Langage omniprésent** — termes métier, ce qui est dit à l'usager, vocabulaire proscrit | — |
| [`context-map.md`](context-map.md) | **Carte des contextes** — 6 contextes bornés et leurs sources externes | — |
| [`project-state.md`](project-state.md) | **État vivant** — où on en est, ce qui bloque | — |
| [`guide-installation.md`](guide-installation.md) | Installation du poste de développement, et ses pièges | — |
| [`guide-release.md`](guide-release.md) | **Livrer un APK à un testeur distant** — commandes, signature, verrou produit | — |

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
| [`2026-07-31-t0-socle-react-native.md`](superpowers/plans/2026-07-31-t0-socle-react-native.md) | **T0** — socle Expo, domaine, données, carte, outillage percentiles | 🔄 **21 tâches sur 23** au 2026-08-15 — restent `S5` et `M5`, tous deux en attente d'un **appareil Android réel** |
| [`2026-07-30-t0-spike-carte-et-socle.md`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md) | T0 en .NET MAUI | 🚫 **caduc** — conservé pour l'historique, **ne pas exécuter** |

## Index des décisions

| # | Décision | Statut |
|---|---|---|
| [ADR-001](adr/ADR-001-api-hydrometrie-v2.md) | Cibler l'API hydrométrie **v2** — la v1 est arrêtée | Accepté |
| [ADR-002](adr/ADR-002-qualification-du-debit.md) | Ne jamais qualifier un débit de « suffisant » | Accepté ⚠️ |
| [ADR-003](adr/ADR-003-reference-percentiles-en-asset.md) | Percentiles pré-calculés dans un asset embarqué | Accepté |
| [ADR-004](adr/ADR-004-integration-vigieau.md) | VigiEau derrière une abstraction, avec repli | Accepté ⚠️ |
| [ADR-005](adr/ADR-005-stack-maui-blazor-hybrid.md) | ~~.NET MAUI Blazor Hybrid + MapLibre GL JS~~ | **Remplacé par ADR-010** |
| [ADR-006](adr/ADR-006-onde-quatre-categories.md) | ONDE en 4 catégories d'affichage | Accepté ⚠️ |
| [ADR-007](adr/ADR-007-ecarter-qualite-eau.md) | Écarter la qualité de l'eau de la v1 | Accepté |
| [ADR-008](adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md) | CQRS léger, cache par décorateur de handler | **Remplacé par ADR-010** — *le principe survit* |
| [ADR-009](adr/ADR-009-cible-windows.md) | ~~Ajouter **Windows** aux cibles de la v1~~ | **Remplacé par ADR-010** |
| [ADR-010](adr/ADR-010-react-native.md) | **React Native**, abandon de MAUI et de Windows | Accepté — arbitrage du commanditaire |
| [ADR-012](adr/ADR-012-hors-ligne-cartographique-bloque.md) | 🚨 **Le hors-ligne cartographique est bloqué** — `createPack` plante en natif | **Proposé — arbitrage du commanditaire requis** |

⚠️ = tranché par défaut, **sans arbitrage du commanditaire**. Réversible : chaque ADR porte une
section « Si la décision est revue ».

> 🔄 **`ADR-011` reste à écrire** — le choix entre `expo-sqlite` et `op-sqlite` (tâche `S5`).
> Son numéro lui est **réservé** : `ADR-012` a été écrit avant lui, le 2026-08-15, parce que
> l'exécution de `M4` l'a imposé.

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

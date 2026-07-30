# MartinPêcheur — Claude AI Guidelines

> Application mobile qui informe les usagers d'une rivière française sur son état — **écoulement**, **débit**, **sécheresse** — à partir des APIs publiques **Hub'Eau** et **VigiEau**.
> Carte de la doc : `docs/README.md` · **État vivant (source de vérité des statuts) : `docs/project-state.md`**

> ⚠️ **Ce fichier distingue** ✅ implémenté · 🔄 cible décidée, pas encore codée · 💭 spéculatif. Si ce fichier contredit le code, **le code a raison** : corriger ce fichier dans le même commit.

> ⚠️ **Aucun code métier n'existe à ce jour.** `MartinPecheur.slnx` contient un seul projet,
> `src/MartinPecheur.App` — la **coquille du gabarit MAUI Blazor** (tâche `A1`, faite le
> 2026-07-31). Ni Domain, ni Data, ni mapper, ni test.

---

## Où on en est

| Tranche | Prouve | Statut |
|---|---|---|
| **T0** | Spike carte (lève le seul risque bloquant) + socle Domain/Data + outillage percentiles | 🔄 **en cours** — `A1` ✅ faite, `A2`…`A6`, `B0`…`B8`, `C1`…`C4` à faire. Plan : `docs/superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md` |
| **T1** | Carte, fiches, les 4 avertissements | 🔄 après arbitrage d'`ADR-005` |
| **T2** | Sécheresse et restrictions (VigiEau) | 🔄 |
| **T3** | Hors-ligne complet, favoris, filtres | 🔄 |

Le cadrage produit est terminé et vérifié. L'implémentation vient de démarrer.

---

## Architecture — Clean Architecture en couches + MVVM + CQRS léger

Décision : `docs/adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md`.

⚠️ **CQRS « léger » = `IQuery`/`ICommand` + handlers + un pipeline. Rien de plus.** Pas de CQRS complet (il n'y a pas deux modèles), **pas d'event sourcing**, aucun événement de domaine, aucune projection — voir `docs/context-map.md`. Ne pas importer le vocabulaire de Kairior au-delà de ça.

⚠️ **Pas de backend.** L'app appelle directement les APIs publiques. La seule donnée pré-calculée est un **asset généré au build** (`ADR-003`), pas un service.

```
UI (Razor / XAML)  →  ViewModel  →  Application  →  Domain
                                    IQuery/ICommand      ↓
                                    + CachePolicy      Data
                                                        ├─ RemoteDataSource (Hub'Eau, VigiEau)
                                                        ├─ LocalDataSource  (SQLite, tuiles)
                                                        └─ Asset percentiles (lecture seule)
```

### Invariants à ne jamais casser

- **Le Domain ne dépend de rien.** Ni MAUI, ni HTTP, ni SQLite. C'est ce qui rend le socle indépendant du résultat du spike carte. Toute référence d'infrastructure depuis le Domain est une erreur d'architecture, pas un détail.
- **Le ViewModel n'appelle jamais un dépôt.** Il envoie une requête ou une commande. Les handlers orchestrent, les dépôts restent bêtes.
- **La politique de cache vit dans un seul composant du pipeline.** Le stale-while-revalidate n'est jamais recopié dans un dépôt ni dans un ViewModel — c'est la raison d'être d'`ADR-008`.
- **Aucune valeur brute d'API n'atteint la vue.** La conversion l/s → m³/s et mm → m se fait dans le mapper, une seule fois (`BR-002`).
- **Les trois échelles d'état restent séparées** — écoulement (fait observé), débit (statistique), sécheresse (décision préfectorale). Les fondre dans un champ unique mélangerait trois natures (`BR-008`).
- **Toute nomenclature a une branche par défaut.** Une énumération sans valeur `Inconnu` est un défaut de conception (`BR-011`).
- **VigiEau ne s'appelle que derrière `IRestrictionSource`.** L'API est en version `0.1` : le risque de rupture reste confiné à une classe (`ADR-004`).
- **Les quatre avertissements ne sont pas une finition.** Rien ne part en production sans eux (`BR-012`, `BR-013`).

---

## Stack (état réel par ligne)

| Composant | Techno | État |
|---|---|---|
| Runtime | **.NET 10** — imposé par `BrilliantMediator` 3.0.0 qui cible `net10.0` | ✅ SDK 10.0.302, projet en `net10.0-*` |
| Cible | **MAUI — Android, iOS et Windows** (`ADR-009`) ; macOS/Mac Catalyst hors périmètre v1 | ✅ les 3 cibles buildent en Release, 0 warning ⚠️ **iOS compilé seulement — pas de bundle `.app` sans hôte macOS** |
| Médiateur (CQRS) | **BrilliantMediator 3** + `BrilliantMediator.SourceGenerator` — ⚠️ PAS MediatR (réflexion au runtime, mauvais candidat sur mobile trimmé) | 🔄 ⚠️ **le support des *pipeline behaviors* n'est pas confirmé** — à lever au spike T0. Repli : `IQueryHandler<,>` maison résolu par DI (`ADR-008`) |
| UI | **MAUI Blazor Hybrid** (`BlazorWebView`) — `docs/adr/ADR-005-stack-maui-blazor-hybrid.md` | 🔄 gabarit en place, **aucun écran du produit**. ⚠️ **`ADR-005` reste `Proposé`, pas `Accepté`** — conditionné au spike T0. Repli : MAUI natif + Mapsui |
| Carte | **MapLibre GL JS** dans le WebView, fond **IGN Géoplateforme** (WMTS) | 🔄 ⚠️ `Microsoft.Maui.Controls.Maps` est **éliminé** : ni clustering, ni tuiles custom, ni hors-ligne |
| MVVM | **CommunityToolkit.Mvvm** (`ObservableObject`, `RelayCommand`) | 🔄 |
| Navigation | **Shell**, routes paramétrées | 🔄 |
| HTTP | **`IHttpClientFactory` + Polly** (retry, backoff exponentiel avec gigue) | 🔄 |
| Stockage | **`sqlite-net-pcl`** ; tuiles en fichiers dans `FileSystem.CacheDirectory` | 🔄 |
| Graphes | **LiveChartsCore** (option A) ou Chart.js (option B) | 💭 selon l'arbitrage d'`ADR-005` |
| Tests | **xUnit** | 🔄 |

---

## Sources de données — ce qui est vérifié

Toutes vérifiées **par appels HTTP réels le 2026-07-30**. Détail : `docs/01-analyse.md`.

| Source | Base URL | Rôle |
|---|---|---|
| Hydrométrie **v2** | `https://hubeau.eaufrance.fr/api/v2/hydrometrie` | Débit, hauteur, historique |
| Écoulement ONDE v1 | `https://hubeau.eaufrance.fr/api/v1/ecoulement` | Assecs, écoulement observé |
| VigiEau | `https://api.vigieau.beta.gouv.fr/api` | Restrictions, arrêtés |

### Les pièges qui coûtent une journée

| # | Piège |
|---|---|
| `C-01` | **L'API hydrométrie v1 est arrêtée** depuis le 05/05/2025 → HTTP 403. Seule la **v2** répond |
| `C-02` | **Le débit arrive en l/s, la hauteur en mm.** `53000.0` = 53 m³/s. Diviser par 1000 |
| `C-04` | `obs_elab` **n'a pas de `sort`** — il est ignoré silencieusement et renvoie 1900. Toujours passer `date_debut_obs_elab` |
| `C-05` | Interroger un **code site** (8 car.) renvoie chaque mesure **en double**. N'utiliser que des codes station (10 car.) |
| `C-06` | **HTTP 206 est un succès.** Un client qui n'accepte que 200 casse dès la première pagination |
| `C-10` | Les codes ONDE sont des **chaînes** (`"1a"`, `"1f"`), les libellés de campagne en **minuscules** |
| `C-14` | VigiEau `?commune=` → **HTTP 409**. Toujours `lat`/`lon` |
| `C-15` | **Aucun SLA**, aucun quota chiffré. Mode dégradé obligatoire, throttle client |

---

## La règle qui structure tout le produit

> **On ne qualifie jamais un débit de « suffisant ».**

Aucune API n'expose de seuil réglementaire par station — vérifié sur Hub'Eau, HydroPortail et SANDRE. Le produit sépare donc deux questions et ne les mélange jamais (`ADR-002`) :

| Question | Réponse | Nature |
|---|---|---|
| Ce débit est-il **inhabituel pour la saison** ? | Percentile face à 30 ans d'historique | **Statistique** |
| Qu'est-ce qui est **interdit chez moi** ? | Niveau de gravité, usages restreints, PDF de l'arrêté | **Réglementaire** |

**Mots bannis** pour qualifier un débit : *suffisant, insuffisant, normal, bon, sûr*. Vocabulaire complet : `docs/glossary.md`.

---

## Documentation & Spec

Tout vit dans **ce dépôt** (`docs/`) — code et spec évoluent dans le même commit. Carte complète : `docs/README.md`.

| Artefact | Dossier | Nom | Quand |
|---|---|---|---|
| **Business Rule** | `docs/br/` | `BR-NNN-slug.md` | règle métier invariante |
| **Use Case** | `docs/use-cases/` | `UC-NNN-slug.md` | scénario acteur↔système (mermaid inline) |
| **ADR** | `docs/adr/` | `ADR-NNN-slug.md` | décision technique tranchée + alternatives écartées |

Docs transverses : `docs/glossary.md` · `docs/context-map.md` · `docs/project-state.md`.
Cadrage produit : `docs/01-analyse.md` → `docs/04-ui.md`.

- `NNN` = 3 chiffres séquentiels, jamais réutilisés. `slug` = kebab-case français.
- On **ne supprime pas** un artefact obsolète → statut `Remplacé par …`.
- **Une contrainte d'API subie n'est pas une règle métier** : elle va au tableau `C-xx` de `01-analyse.md`, pas dans `br/`.
- **Diagrammes** : dispersés **à côté** de la sous-partie qu'ils illustrent, jamais en section dédiée. **Mermaid inline** uniquement.
- Templates : `docs/{br,use-cases,adr}/*-template.md`.
- **Quatre ADR sont tranchés sans arbitrage du commanditaire** (`ADR-002`, `004`, `005`, `006`). Chacun porte une section « Si la décision est revue ». Ne pas les traiter comme définitifs.

---

## Conventions

- **Code :** anglais · **Domaine et documentation :** français
- **Commits :** Conventional Commits — scopes : `domain`, `data`, `ui`, `map`, `hydrometrie`, `ecoulement`, `restrictions`, `avertissement`, `docs`, `ci`
- **Ordre d'implémentation :** Domain → Data → ViewModel → UI
- **TDD** : test rouge avant implémentation. Commencer par la conversion d'unités — c'est le bug le plus coûteux du projet
- **Critère de fin d'étape :** build Release **0 warning** + tests verts

---

## Anti-hallucination

Lire avant d'écrire. Ne jamais inventer une API, un endpoint, un champ ou une volumétrie.

**Sur ce projet, la règle est plus stricte que d'habitude :**

> **Tout fait relatif à une API publique est vérifié par appel réel, et daté.**
> Un fait non vérifié est signalé comme tel, avec l'URL consultée.
> On ne spécifie jamais d'après une documentation seule.

Ce n'est pas de la prudence rédactionnelle : la documentation Hub'Eau est **en écart avec la production** sur au moins quatre points (v1 annoncée vivante mais arrêtée, unités, `code_methode_obs = 8` non documenté, casse des libellés). Le cadrage a déjà évité quatre erreurs bloquantes de cette façon.

Distinguer **implémenté** ✅ / **décidé mais pas codé** 🔄 / **spéculatif** 💭 — ne jamais compter du 🔄 comme un acquis. Toujours exposer les alternatives avant de recommander. **Ce fichier inclus** : s'il diverge du code, le corriger dans le même commit.

**Ne jamais inventer un seuil hydrologique.** C'est la faute la plus grave possible sur ce produit.

# MartinPêcheur — Claude AI Guidelines

> Application mobile qui informe les usagers d'une rivière française sur son état — **écoulement**, **débit**, **sécheresse** — à partir des APIs publiques **Hub'Eau** et **VigiEau**.
> Carte de la doc : `docs/README.md` · **État vivant (source de vérité des statuts) : `docs/project-state.md`**

> ⚠️ **Ce fichier distingue** ✅ implémenté · 🔄 cible décidée, pas encore codée · 💭 spéculatif. Si ce fichier contredit le code, **le code a raison** : corriger ce fichier dans le même commit.

> 🚨 **Bascule de stack le 2026-07-31 — `ADR-010`.** Le projet passe de **.NET MAUI à React Native**
> et **abandonne Windows**. Tout le code .NET écrit (`A1`, `B1`, `B3a`) est **caduc** : il reste dans
> l'historique git (`696be3a`, `22e9850`) mais ne sera pas repris.
> **`ADR-005`, `ADR-008` et `ADR-009` sont remplacés par `ADR-010`.**

> ✅ **Le code .NET a été retiré du dépôt le 2026-07-31** (`src/`, `tests/`, `MartinPecheur.slnx`).
> Il n'existe plus que dans l'historique git — `git show 22e9850` pour le socle, `696be3a` pour le
> projet MAUI. Le cadrage produit, lui, est **intact et valide** : il ne dépendait pas de la stack.

---

## Où on en est

| Tranche | Prouve | Statut |
|---|---|---|
| **T0** | Socle React Native + carte MapLibre + socle domaine + outillage percentiles | 🔄 **12 tâches sur 23 au 2026-08-15** — `docs/superpowers/plans/2026-07-31-t0-socle-react-native.md`. Lots 0 (hors `S5`), 1 et 2 ✅ · lot 4 à faire · lot 3 (carte) **prêt à démarrer** : outillage Android complet, `ANDROID_HOME` posé, AVD API 36 disponible |
| **T1** | Carte, fiches, les 4 avertissements | 🔄 |
| **T2** | Sécheresse et restrictions (VigiEau) | 🔄 |
| **T3** | Hors-ligne complet, favoris, filtres | 🔄 |

Le cadrage produit est terminé et vérifié. **L'implémentation repart de zéro** sur la nouvelle stack.

---

## Architecture — Clean Architecture en couches + CQRS léger

Décision : `docs/adr/ADR-010-react-native.md`. Le principe CQRS vient d'`ADR-008`, dont **seul le véhicule .NET est caduc**.

⚠️ **CQRS « léger » = `Query`/`Command` typés + handlers + un décorateur de cache. Rien de plus.** Pas de CQRS complet (il n'y a pas deux modèles), **pas d'event sourcing**, aucun événement de domaine, aucune projection — voir `docs/context-map.md`. **Aucune bibliothèque de médiateur** : un registre explicite de handlers suffit.

⚠️ **Pas de backend.** L'app appelle directement les APIs publiques. La seule donnée pré-calculée est un **asset généré au build** (`ADR-003`), pas un service.

```
UI (écrans React)  →  application/       →  domain/
                      Query/Command           ↓
                      + CachePolicy         data/
                                             ├─ RemoteDataSource (Hub'Eau, VigiEau)
                                             ├─ LocalDataSource  (SQLite, packs MapLibre)
                                             └─ Asset percentiles (lecture seule)
```

### Invariants à ne jamais casser

- **`domain/` ne dépend de rien.** Aucun import de React, de React Native, de `fetch` ni de SQLite. TypeScript pur. Toute dépendance d'infrastructure depuis `domain/` est une erreur d'architecture, pas un détail.
- **Un composant d'écran n'appelle jamais un dépôt.** Il envoie une requête ou une commande. Les handlers orchestrent, les dépôts restent bêtes.
- **La politique de cache vit dans un seul composant** — le décorateur `CachePolicy`. Le stale-while-revalidate n'est jamais recopié dans un dépôt ni dans un écran : c'est la raison d'être d'`ADR-008`, reprise par `ADR-010`.
- **Les unités sont typées, pas conventionnelles.** TypeScript laisse passer un `number` en l/s là où on attend des m³/s. Utiliser des types *branded* — c'est le bug le plus coûteux du projet (`BR-002`).
- **Aucune valeur brute d'API n'atteint la vue.** La conversion l/s → m³/s et mm → m se fait dans le mapper, une seule fois (`BR-002`).
- **Les trois échelles d'état restent séparées** — écoulement (fait observé), débit (statistique), sécheresse (décision préfectorale). Les fondre dans un champ unique mélangerait trois natures (`BR-008`).
- **Toute nomenclature a une branche par défaut.** Une union sans valeur `Inconnu` est un défaut de conception (`BR-011`). Garantir l'exhaustivité par un `switch` gardé par `never`.
- **VigiEau ne s'appelle que derrière `RestrictionSource`.** L'API est en version `0.1` : le risque de rupture reste confiné à un module (`ADR-004`).
- **Les quatre avertissements ne sont pas une finition.** Rien ne part en production sans eux (`BR-012`, `BR-013`).

---

## Stack (état réel par ligne)

| Composant | Techno | État |
|---|---|---|
| Langage | **TypeScript**, mode `strict` | ✅ **posé le 2026-07-31** — `6.0.3`, durci au-delà de `strict` (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`) |
| Runtime | **React Native**, empaqueté par **Expo** (*development builds* — Expo Go ne suffit pas, code natif) | ✅ **amorcé le 2026-07-31** — `expo@57.0.9`, `react-native@0.86.2`, `react@19.2.3`. ⚠️ Expo Go marche encore *tant que* MapLibre n'est pas installé |
| Cible | **Android et iOS** (`ADR-010`). ⚠️ **Windows abandonné le 2026-07-31**, un jour après son ajout | 🔄 |
| Carte | **`@maplibre/maplibre-react-native` v11+** — MapLibre **Native**, rendu GPU. Fond **IGN Géoplateforme** (WMTS) | 🔄 ✅ *v11.3.6 courante, vérifiée le 2026-07-31.* ⚠️ **v11 a changé l'API hors-ligne** : id auto-généré, `addListener`/`removeListener` |
| Hors-ligne carto | **`OfflineManager.createPack`** — région + niveaux de zoom | 🔄 ✅ *le chemin raster existe* : `SourceType::Raster` traité comme `Vector` dans `offline_download.cpp`, et la tuile IGN répond en 256×256 `TILEMATRIXSET=PM` — les deux vérifiés le 2026-07-31. ⚠️ **Rien n'a été exécuté** : tâche `M4` du plan T0 |
| CQRS | `Query`/`Command` typés + handlers + décorateur `CachePolicy`. **Aucune bibliothèque de médiateur** | 🔄 ✅ *le décorateur existe* — `src/application/cachePolicy.ts` (`N5`, 6 tests). ⚠️ **`bus.ts` et les `Query`/`Command` typés n'existent pas encore** : ils arrivent avec les premiers écrans, en T1 |
| HTTP | `fetch` + retry, backoff exponentiel à gigue. **Normaliser 200 et 206** (`C-06`) | ✅ **2026-08-15** — `httpStatus.ts`, `retry.ts` (gigue injectée, donc testable), `hubEauClient.ts` : retry sur 429/5xx, jamais sur 4xx |
| Stockage | SQLite — `expo-sqlite` **ou** `op-sqlite` | 💭 à trancher |
| Graphes | pour la courbe de débit (`US-11`) | 💭 à trancher |
| Tests | **Jest** + `ts-jest`, projet `unit` en environnement **node**, **sans** préréglage `jest-expo` | ✅ **tranché le 2026-07-31.** Le choix n'est pas esthétique : sans transformation React Native, un import de framework depuis `domain/` **casse le test** au lieu de passer inaperçu. `jest-expo` arrivera en T1, en second projet, pour les composants |
| Frontière `domain/` | Test d'architecture (`tests/architecture/`) **+** `no-restricted-imports` ESLint | ✅ 2026-07-31 — deux verrous : l'un lit les imports en texte, l'autre les comprend |

> ✅ **Plus aucun C# dans le working tree** depuis le 2026-07-31. Si tu cherches un précédent
> d'implémentation, il n'y en a pas : le seul code écrit sur ce projet était en .NET et il est
> retiré. Ne pas le ressortir de l'historique pour s'en inspirer — les invariants sont dans ce
> fichier et dans `docs/`, pas dans ces commits.

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
- **Trois ADR sont tranchés sans arbitrage du commanditaire** (`ADR-002`, `004`, `006`). Chacun porte une section « Si la décision est revue ». Ne pas les traiter comme définitifs. *(`ADR-005` l'était aussi — il est remplacé par `ADR-010`, qui, lui, est un arbitrage explicite du commanditaire.)*

---

## Conventions

- **Code :** anglais · **Domaine et documentation :** français
- **Commits :** Conventional Commits — scopes : `domain`, `data`, `ui`, `map`, `hydrometrie`, `ecoulement`, `restrictions`, `avertissement`, `docs`, `ci`
- **Ordre d'implémentation :** `domain/` → `data/` → `application/` → écrans
- **TDD** : test rouge avant implémentation. Commencer par la conversion d'unités — c'est le bug le plus coûteux du projet
- **Critère de fin d'étape :** `tsc --noEmit` **sans erreur**, lint propre, tests verts
- **TypeScript `strict` non négociable.** `any` implicite interdit. Les unités passent par des types *branded*, les nomenclatures par des unions closes avec `Inconnu`

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

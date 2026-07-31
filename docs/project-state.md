# État du projet

**Mis à jour :** 2026-07-31

## Où on en est

🚨 **Bascule de stack le 2026-07-31.** Le commanditaire a révisé son arbitrage .NET : le projet
passe à **React Native** et **abandonne Windows** ([`ADR-010`](adr/ADR-010-react-native.md)).

**L'implémentation repart de zéro.** Le cadrage produit, lui, est intact — il ne dépendait pas
de la stack.

## Ce qui est acquis

| Sujet | État |
|---|---|
| Analyse des APIs | ✅ Vérifiée par appels HTTP réels les 2026-07-30 et 07-31 |
| Question centrale du « débit suffisant » | ✅ Tranchée (`ADR-002`) et documentée avec ses limites |
| Sources retenues et écartées | ✅ 7 APIs évaluées, motifs documentés |
| Règles métier | ✅ 14 règles, chacune avec son test |
| Cas d'usage | ✅ 6 cas, flux nominaux et alternatifs |
| Avertissements | ✅ Les 4 emplacements spécifiés, textes rédigés |
| Stack | ✅ **Tranchée le 2026-07-31** — React Native (`ADR-010`), arbitrage du commanditaire |
| Hors-ligne cartographique | ✅ **N'est plus un risque** — `OfflineManager.createPack` vérifié le 2026-07-31 |

## Code

**Aucun code React Native n'existe.** Rien n'est commencé sur la nouvelle stack.

Le **code .NET a été retiré du working tree le 2026-07-31** sur arbitrage du commanditaire. Il
reste intégralement dans l'historique git et n'est repris nulle part :

| Tâche | Livrable .NET | Sort |
|---|---|---|
| `A1` | `src/MartinPecheur.App` (MAUI Blazor Hybrid, 3 cibles vertes) | 🗑️ caduc — `696be3a` |
| `B0` | Vérification `BrilliantMediator` (aucun *behavior*) | 🗑️ sans objet |
| `B1` | `Domain`, `Application`, `Data`, `tests/` | 🗑️ caduc — `22e9850` |
| `B3a` | `MeasurementUnits.cs`, 8 tests verts | 🗑️ caduc — **à réécrire en TypeScript** |

> `B3a` mérite d'être refait **en premier** sur la nouvelle stack : la conversion d'unités reste
> le bug le plus coûteux du projet, et TypeScript la protège moins bien que C#.

## Constats d'API du 2026-07-31 — à reporter dans `01-analyse.md`

Relevés pendant `A2`, avant la bascule. Indépendants de la stack :

| Constat | Détail |
|---|---|
| `size` plafonne à **10000** | Le plan T0 écrivait `size=20000` → **HTTP 400** `ValidatePageSize` |
| **200 et 206 coexistent** | `size=1` → **206** ; `size=5000` (≥ 4 140 résultats) → **200**. Confirme `C-06` en production |
| Volume | **4 140 stations** en service, **6,28 Mo** en GeoJSON brut, 0 géométrie manquante |
| Codes station | 4 140 codes distincts, **tous à 10 caractères** — cohérent avec `C-05` |

## Ce qui bloque, ou reste à trancher

| # | Sujet | Nature |
|---|---|---|
| 1 | **Le plan T0 est écrit pour .NET.** `A1`, `A3`…`A6`, `B0`, `B1`, `B4` n'ont plus de sens tels quels | **À réécrire avant de coder.** Seuls `A2` et la voie C sont indépendants de la stack |
| 2 | Trois ADR tranchés **sans arbitrage du commanditaire** : `ADR-002`, `ADR-004`, `ADR-006` | Décisions par défaut, réversibles. Chacune porte sa section « Si la décision est revue » |
| 3 | **Réduction de périmètre à valider** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 4 | Le cadrage annonçait **3 modalités ONDE** ; il y en a **6** (`ADR-006`) | Corrigé dans la spec |
| 5 | Poids réel de l'asset de percentiles | À mesurer, pas à estimer |
| 6 | Script de build des percentiles | Lot d'outillage à chiffrer (`ADR-003`) |
| 7 | **Hôte macOS** pour produire un build iOS | **Matériel.** Bloquant pour livrer iOS, pas pour développer |
| 8 | Bibliothèque SQLite, bibliothèque de graphes, outil de test | À trancher (`ADR-010` § « Points à vérifier ») |
| 9 | ~~Téléchargement de tuiles hors-ligne~~ — **levé le 2026-07-31** : `OfflineManager.createPack` le fournit | Clos par `ADR-010` |
| 10 | ~~Behaviors BrilliantMediator~~, ~~AOT et trimming~~, ~~portage Windows~~ | Sans objet depuis `ADR-010` |

## Points non vérifiés, assumés comme tels

- **Que `createPack` accepte une source raster WMTS** (IGN) et pas seulement des tuiles vectorielles. C'est l'hypothèse qui porte tout le hors-ligne — à constater tôt.
- Comportement de `maplibre-react-native` v11+ **en volume réel** (~4 140 points, clustering) sur Android d'entrée de gamme. Attendu bien meilleur qu'un WebView, mais **non mesuré**.
- Version exacte de la Licence Ouverte Etalab pour Hub'Eau (1.0 ou 2.0).
- Fenêtre du `X-RateLimit-Limit: 300` de VigiEau.
- Sémantique du paramètre `departement` de VigiEau `/arretes_restrictions`.
- Existence du niveau `vigilance` dans VigiEau — non observé le 2026-07-30.
- Mapping entre `nombre_modalite_ecoulement` (4 ou 5) et les codes ONDE disponibles.

## Prochaine étape

**Réécrire le plan T0 pour la nouvelle stack**, puis amorcer le projet Expo.

L'ancien plan ([`T0 — Spike carte & socle données`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md))
reste au dépôt pour l'historique, mais **ne doit plus être exécuté** : sa voie A est un spike
`BlazorWebView` sans objet, et sa voie B est en C#.

Ce qui change dans la logique du plan : **le spike carte perd son caractère bloquant.** Il
existait pour lever un doute sur le WebView ; MapLibre Native le rend sans objet. La séquence
redevient linéaire — socle, domaine, carte — au lieu de trois voies dont une conditionnait tout.

⚠️ **Ce qui reste vrai malgré la bascule :** la mesure sur un **Android d'entrée de gamme réel**
garde son intérêt. Le rendu natif est attendu bien meilleur, mais « attendu » n'est pas « mesuré ».

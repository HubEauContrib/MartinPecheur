# État du projet

**Mis à jour :** 2026-07-31

## Où on en est

Cadrage terminé. **L'implémentation a démarré : la tâche `A1` du plan T0 est faite.**

Le dépôt contient `MartinPecheur.slnx` et un seul projet, `src/MartinPecheur.App` — la **coquille
du gabarit MAUI Blazor Hybrid**, sans code métier. Le reste de T0 est intact.

## Ce qui est acquis

| Sujet | État |
|---|---|
| Analyse des APIs | ✅ Vérifiée par appels HTTP réels le 2026-07-30, pas d'après la documentation |
| Question centrale du « débit suffisant » | ✅ Tranchée (`ADR-002`) et documentée avec ses limites |
| Stack | ⚠️ **Proposée**, conditionnée à un spike (`ADR-005`) |
| Sources retenues et écartées | ✅ 7 APIs évaluées, motifs documentés |
| Règles métier | ✅ 14 règles, chacune avec son test |
| Cas d'usage | ✅ 6 cas, flux nominaux et alternatifs |
| Avertissements | ✅ Les 4 emplacements spécifiés, textes rédigés |
| **Solution et projet d'application** (`A1`) | ✅ **2026-07-31** — `.slnx`, .NET 10, build Release **0 avertissement** |

## Code produit

| Tâche | Livrable | Vérification |
|---|---|---|
| `A1` | `src/MartinPecheur.App`, gabarit MAUI Blazor Hybrid, cibles Android + iOS + Windows (`ADR-009`) | Build Release **0 avertissement** sur les 3 cibles. APK signé et `.exe` produits ; **iOS compilé sans bundle `.app`** — exige un hôte macOS |
| `B0` | Vérification du médiateur | **BrilliantMediator 3.x n'a pas de behaviors** (dépôt source consulté). Repli retenu : décorateur de `IQueryHandler<,>`. `ADR-008` mis à jour |
| `B1` | `src/MartinPecheur.Domain`, `.Application`, `.Data` + `tests/MartinPecheur.UnitTests` | Projets `net10.0` créés, références câblées, ajoutés au `.slnx` |
| `B3a` | `Domain/Hydrometry/MeasurementUnits.cs` — conversion l/s → m³/s et mm → m (`BR-002`) | **8 tests verts** en Release sur les valeurs réelles du 2026-07-30 : `53000.0 → 53.0`, `350571.0 → 350.571`, absence propagée, double conversion interdite |

**Le métier reste embryonnaire.** Une seule classe de domaine. Ni mapper, ni dépôt, ni client
HTTP, ni écran du produit : la page d'accueil est encore celle de Microsoft.

## Ce qui bloque, ou reste à trancher

| # | Sujet | Nature |
|---|---|---|
| 1 | **Spike carte** (2-3 j) : fluidité du clustering et mémoire du `BlazorWebView` sur Android d'entrée de gamme | Bloque `ADR-005`. À faire **avant** toute autre implémentation |
| 2 | Quatre ADR tranchés **sans arbitrage du commanditaire** : `ADR-002`, `ADR-004`, `ADR-005`, `ADR-006` | Décisions par défaut, réversibles. Chacune porte sa section « Si la décision est revue » |
| 3 | **Réduction de périmètre à valider** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 4 | Le cadrage annonçait **3 modalités ONDE** ; il y en a **6** (`ADR-006`) | Corrigé dans la spec |
| 5 | Poids réel de l'asset de percentiles | À mesurer, pas à estimer |
| 6 | Script de build des percentiles | Lot d'outillage à chiffrer (`ADR-003`) |
| 7 | Téléchargement de tuiles hors-ligne | Lot de développement à chiffrer, pas un réglage (`ADR-005`) |
| 8 | ~~Behaviors BrilliantMediator~~ — **levé le 2026-07-31** : il n'y en a pas. Repli appliqué (décorateur de `IQueryHandler<,>`), `ADR-008` à jour | Clos |
| 9 | **Compatibilité AOT et trimming** du médiateur | Non annoncée. À constater par un build Release trimmé sur Android, au spike |

## Points non vérifiés, assumés comme tels

- **Production d'un paquet iOS installable.** La compilation passe sur Windows, mais l'AOT, l'édition de liens native et la signature exigent un hôte macOS — non disponible au 2026-07-31.
- **Portage Windows de l'UI.** Les wireframes de `04-ui.md` sont écrits pour le mobile. Le lot responsive et clavier/souris n'est ni spécifié ni chiffré (`ADR-009`).
- Version exacte de la Licence Ouverte Etalab pour Hub'Eau (1.0 ou 2.0).
- Fenêtre du `X-RateLimit-Limit: 300` de VigiEau.
- Sémantique du paramètre `departement` de VigiEau `/arretes_restrictions`.
- Existence du niveau `vigilance` dans VigiEau — non observé le 2026-07-30.
- Mapping entre `nombre_modalite_ecoulement` (4 ou 5) et les codes ONDE disponibles.

## Prochaine étape

**Le spike carte, suite.** `A1` est faite ; `A2` (figer le jeu de stations) et `A3` (MapLibre dans
le `BlazorWebView`) suivent. Le spike conditionne `ADR-005`, donc l'architecture de l'UI.

L'ajout de Windows (`ADR-009`) rend `A3` nettement plus rapide à itérer — WebView2 se débogue sur
le poste. **Mais `A4` reste mesurée sur un Android d'entrée de gamme réel** : un vert sur WebView2
ne dit rien du moteur le plus contraint.

Tout le reste — couches Domain et Data, mappers, règles métier — est indépendant du spike par
construction et peut démarrer en parallèle.

Plan : [`T0 — Spike carte & socle données`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md),
en trois voies dont une seule est bloquante.

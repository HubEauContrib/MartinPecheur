# État du projet

**Mis à jour :** 2026-07-30

## Où on en est

**Phase de cadrage terminée. Aucune ligne de code produit** — c'était le périmètre demandé.

Le dépôt contient `MartinPecheur.sln`, **vide** (aucun projet). La documentation est complète et vérifiée.

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

## Points non vérifiés, assumés comme tels

- Version exacte de la Licence Ouverte Etalab pour Hub'Eau (1.0 ou 2.0).
- Fenêtre du `X-RateLimit-Limit: 300` de VigiEau.
- Sémantique du paramètre `departement` de VigiEau `/arretes_restrictions`.
- Existence du niveau `vigilance` dans VigiEau — non observé le 2026-07-30.
- Mapping entre `nombre_modalite_ecoulement` (4 ou 5) et les codes ONDE disponibles.

## Prochaine étape

**Le spike carte.** Il conditionne `ADR-005`, donc l'architecture de l'UI. Tout le reste — couches Domain et Data, mappers, règles métier — en est indépendant par construction et peut démarrer en parallèle.

Plan prêt : [`T0 — Spike carte & socle données`](superpowers/plans/2026-07-30-t0-spike-carte-et-socle.md),
en trois voies dont une seule est bloquante.

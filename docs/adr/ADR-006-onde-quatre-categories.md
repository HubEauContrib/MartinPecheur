# ADR-006 — Afficher l'écoulement ONDE en 4 catégories

- **Statut :** Accepté · *tranché par défaut, sans arbitrage du commanditaire*
- **Date :** 2026-07-30

## Contexte

Le cadrage annonçait **3 modalités** ONDE. La lecture du référentiel et le comptage des observations réelles depuis le 2026-01-01 en montrent **six** :

| `code_ecoulement` | `libelle_ecoulement` | Occurrences depuis 2025-01-01 |
|---|---|---|
| `1` | Écoulement visible | 2 740 |
| `1a` | Écoulement visible acceptable | 17 523 |
| `1f` | Écoulement visible faible | 7 879 |
| `2` | Écoulement non visible | 2 176 |
| `3` | Assec | 4 815 |
| `4` | Observation impossible | 27 |

Les codes sont des **chaînes** (`"1a"`, `"1f"`), pas des entiers.

Six états à distinguer sur une carte, en extérieur, sans coder l'information par la seule couleur, est difficilement lisible. Les fondre en trois ferait disparaître **« écoulement visible faible »** — soit **7 879 observations, environ un quart du total**, et le principal signal précurseur d'assèchement.

Le champ `nombre_modalite_ecoulement` des campagnes vaut 4 ou 5 selon le protocole. Le mapping exact protocole ↔ modalités disponibles **n'est pas documenté** — non vérifié.

## Décision

**Quatre catégories d'affichage**, plus un état d'absence :

| Catégorie affichée | Codes source | Libellé carte |
|---|---|---|
| Écoulement | `1`, `1a` | Eau qui coule |
| Écoulement faible | `1f` | Écoulement faible |
| Non visible | `2` | Eau stagnante |
| À sec | `3` | À sec |
| *(absence)* Non observé | `4` | Non observé |

**La modalité officielle exacte reste affichée sur la fiche** (« code 3 — Assec »). Le regroupement sert la lisibilité de la carte ; il ne se substitue jamais à la source.

```mermaid
flowchart LR
    C1["code 1<br/>Écoulement visible"] --> N[Écoulement]
    C1a["code 1a<br/>visible acceptable"] --> N
    C1f["code 1f<br/>visible faible"] --> F[Écoulement faible]
    C2["code 2<br/>non visible"] --> NV[Eau stagnante]
    C3["code 3<br/>Assec"] --> A[À sec]
    C4["code 4<br/>Observation impossible"] --> NO[Non observé]
    CX["code inconnu"] --> NO
```

## Conséquences

- ➕ Le signal précurseur d'assèchement (`1f`) reste visible, distinct de l'écoulement franc.
- ➕ Quatre états restent distinguables par forme et motif, y compris en niveaux de gris.
- ➖ C'est une **interprétation de notre part**, pas une classification officielle de l'OFB. Elle doit être documentée dans « D'où vient cette donnée ? ».
- ➖ Un code futur ajouté au référentiel tombera en « Non observé » tant que le mapping n'est pas mis à jour (`BR-011`).

## Alternatives écartées

- **Les 6 modalités officielles** : fidélité totale, aucune interprétation. Mais six états à distinguer visuellement sur une carte, en plein soleil, au détriment de la lisibilité — qui est l'exigence première de l'écran principal.
- **3 catégories, comme au cadrage** : le plus simple à lire, mais fait disparaître `1f`, soit un quart des observations et le principal signal d'alerte précoce. Écarté comme une perte d'information métier.

## Si la décision est revue

Le mapping est une seule fonction de projection, dans la couche Domain. Passer à 3 ou 6 catégories n'impacte que cette fonction, la palette de `04-ui.md § 2` et les libellés de filtre. Le modèle de données conserve `CodeEcoulement` brut : **aucune information n'est perdue au stockage**, la projection est réversible.

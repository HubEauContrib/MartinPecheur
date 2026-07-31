---
description: Tableau de bord d'avancement — fait, en cours, à faire
---

Produis un **tableau de bord d'avancement** de MartinPêcheur. Ne code rien, ne modifie aucun fichier.

## Sources de vérité, dans cet ordre

1. **Le code** — ce qui compile et passe les tests prime sur toute documentation.
2. `docs/superpowers/plans/*.md` — les cases `- [ ]` / `- [x]` des étapes.
3. `docs/project-state.md` — les points bloquants.
4. Les statuts en tête des `docs/adr/ADR-*.md` (`Proposé` ≠ `Accepté`).
5. `git log --oneline -15` et `git status --short`.

Si une source en contredit une autre, **signale la contradiction** — c'est un défaut à corriger, pas un détail à lisser.

## Format de sortie

### 1. Une ligne d'état

`T0 · voie B — 3/9 étapes · dernier commit : <sha> <sujet>`

### 2. Les trois colonnes

Un tableau par tranche active, avec **une ligne par étape du plan** :

| # | Étape | État | Preuve |
|---|---|---|---|

- **État** : ✅ fait · 🔄 en cours · ⬜ à faire · 🚫 bloqué
- **Preuve** : le fichier, le test ou le commit qui l'atteste. **Une étape sans preuve n'est pas ✅.**

### 3. Ce qui bloque

Une ligne par blocage : quoi, sur qui, et ce que ça empêche de démarrer.
Distingue **bloqué sur une décision du commanditaire** et **bloqué sur du matériel ou un accès**.

### 4. Décisions non figées

Les ADR en statut `Proposé`, et ceux marqués « tranché sans arbitrage du commanditaire ». Rappelle en une ligne ce qui bascule si chacun est revu.

### 5. La prochaine action

**Une seule.** La plus petite qui débloque le plus. Dis pourquoi c'est celle-là.

## Contraintes

- **Concis** : tableaux et listes, pas de prose. Une page maximum.
- Ne compte jamais du 🔄 comme un acquis.
- Si un lot est annoncé fait mais que rien ne l'atteste, écris-le franchement.

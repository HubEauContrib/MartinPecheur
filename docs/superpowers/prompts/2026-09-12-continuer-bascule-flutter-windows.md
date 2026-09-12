# Prompt — Continuer la bascule Flutter, cible Windows d'abord

Écrit le 2026-09-12. Il **prolonge** le brief `docs/superpowers/prompts/2026-09-09-migration-flutter.md`,
qui reste la référence pour tout détail non repris ici. En cas de contradiction, ce document l'emporte.

> **Arbitrages rendus en séance le 2026-09-12**, qui l'emportent sur les deux briefs :
> - Verdict de porte **favorable sur `F1` + `F3`** ; `F2` non tranchée ; `F2c` (viewport, sans clustering) par défaut.
> - **Option A** : `tools/` et tout l'outillage Node sont supprimés. Le générateur de percentiles sera un script **Dart** quand T1 en aura besoin.
> - **Aucune référence à l'ancienne stack** (.NET, React Native, Node) dans les points d'entrée du dépôt (`README.md`, `CLAUDE.md`). Les autres documents sont réécrits en Phase 3.
> - La section 5.4 du brief du 09-09 (suffixer les hachés) est **abandonnée** : les hachés .NET / React Native n'existent dans aucune ref du dépôt.

## 1. Où on en est

| Phase | État au 2026-09-12 |
|---|---|
| 0 — Porte de spike | `F1` ✅ Windows · `F3` ✅ · `F2` ⚠️ rouge sur émulateur Android (jank 8,9 %), variantes `F2b`/`F2c` codées, **jamais mesurées** |
| 1 — Arbre git frais | ✅ **fait le 2026-09-12** — `dev` = un commit racine ; spike et outillage sous le tag `archive/pre-flutter-2026-09-09` |
| 2 — Socle Dart (T0), puis T1 | ❌ `lib/` n'existe pas |
| 3 — Documentation | 🔄 `README.md` et `CLAUDE.md` réécrits ; `project-state.md`, ADR et guides restent à faire |

Compte rendu : `spike/porte_flutter/COMPTE-RENDU.md`.

## 2. Trois contraintes nouvelles

1. **Android est ignoré jusqu'à nouvel ordre.** Aucun émulateur, APK, NDK, `adb`, remesure `F2`
   ni réécriture de `release-android.yml`. Chaque tâche Android d'un plan est marquée
   `⏸ différée (arbitrage 2026-09-12)`, jamais supprimée ni comptée faite. Windows est la seule
   cible construite ; iOS se configure sans se compiler.
2. **Concision.** Comptes rendus, ADR, plans et messages vont à l'essentiel. Pas de préambule, pas
   de redite d'un document existant : on le cite.
3. **Orchestration par sous-agents**, section 4.

## 3. Le poste

Flutter **3.47.4** (relevé le 2026-09-13 ; le spike a tourné en 3.47.1) :
`D:\Users\Oliver254\develop\flutter\bin\flutter.bat`, hors PATH. Dépôt sur `D:`. Bac à sable sans
build natif : `flutter run -d windows` et `flutter build windows` sont lancés **par le commanditaire**,
chaque commande dans un bloc `bash` séparé, résultat attendu et jamais supposé. Ne rien toucher à
Bitdefender ni au système. Node n'est pas installé et ne le sera pas.

## 4. Orchestration

Chef d'orchestre : **délègue** l'exécution, **vérifie** chaque retour, **relance** ce qui est faux,
**arbitre** entre agents, **synthétise sous sa responsabilité**.

| Nature de la tâche | Agent | Modèle |
|---|---|---|
| Lecture, inventaire, recherche dans le dépôt ou sur `pub.dev` | `Explore` | haiku |
| Implémentation TDD d'une tâche de plan, docs ciblées | `general-purpose` | sonnet |
| Plan, ADR, design, revue de code, arbitrage technique | `general-purpose` ou `Plan` | opus |

Règles :
- **Un agent, une tâche, un prompt autonome** : fichiers, invariants, critère de fin, interdictions.
  Chaque implémentation est relue par un second agent avant commit.
- **Vérifier soi-même** `flutter analyze`, `flutter test` après chaque retour. Un agent qui déclare
  « vert » sans sortie est relancé.
- **Trois échecs sur une même tâche** : arrêt, remise en cause de l'approche, question au commanditaire.
- **Solliciter le commanditaire** quand le choix dépasse : opération git destructive, décision
  d'ADR, choix de bibliothèque, réduction de périmètre, verdict de porte, tout constat à l'écran.
  Question fermée avec recommandation.
- Agents parallèles seulement sur des tâches sans fichier commun.

## 5. Phases

### Phase 0 — Clore la porte ✅ 2026-09-12

### Phase 1 — Arbre git frais ✅ 2026-09-12

### Phase 2 — T0 puis T1, Windows

1. Écrire `docs/superpowers/plans/2026-09-xx-t0-socle-flutter.md` (agent opus,
   `superpowers:writing-plans`) à partir de la section 6 du brief du 09-09 et du compte rendu.
   Tâches Android marquées ⏸. Le commanditaire valide le plan avant exécution.
2. Exécuter avec `superpowers:subagent-driven-development`. Ordre : test d'architecture →
   `domain/` (unités d'abord, `BR-002`) → `data/` → `application/` → `features/map` → `main.dart`
   qui affiche la carte sur Windows.
3. Porte T0 : `flutter analyze` zéro remarque, `flutter test` vert, `flutter build windows
   --release` produit un exécutable que le commanditaire lance. Version `0.1.0`.
4. T1 — carte colorée par état, fiches station et ONDE, les quatre avertissements (`BR-012`,
   `BR-013`), lot clavier/souris dont le zoom à la molette. Même mécanique : plan validé, puis
   exécution. Version `0.2.0`.

### Phase 3 — Documentation

Section 7 du brief du 09-09, dans les mêmes commits que le code. Priorité : `ADR-013`, clôture
d'`ADR-012`, `project-state.md`, guides. Chemins du poste corrigés (`D:`). Aucune référence à
l'ancienne stack.

## 6. Invariants

Section 8 du brief du 09-09, inchangée : jamais « suffisant », jamais de seuil inventé, tout fait
d'API vérifié par appel réel et daté, trois échelles séparées, quatre avertissements, attribution
IGN, ✅ / 🔄 / 💭 jamais confondus.

## 7. Contrat de sortie à chaque point d'étape

Cinq lignes au plus : ce qui est fait avec les commits, ce qui est rouge avec la sortie, ce qui est
différé, la question ouverte s'il y en a une, la commande à lancer s'il y en a une.

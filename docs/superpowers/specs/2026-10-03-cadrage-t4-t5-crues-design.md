# Cadrage de T4 et T5 — Crues : lire la vigilance, puis être prévenu

**Date :** 2026-10-03 · **Statut :** **tranches prévues**, arbitrées le 2026-10-03 par le commanditaire sur trois questions fermées (§ 6) — **non cadrées en détail** : ni user story numérotée, ni règle métier, ni ADR, ni plan · **État vivant :** [`project-state.md`](../../project-state.md)

> Ce document décide **qu'il y aura deux tranches**, dans quel ordre, et ce que chacune doit prouver. Il ne conçoit ni l'architecture, ni les écrans, ni les tâches. Le cadrage détaillé de chaque tranche se fera à son ouverture, comme celui de T2 ([`2026-09-27-cadrage-t2-design.md`](2026-09-27-cadrage-t2-design.md)).

## 1. Objectif

Le produit dit aujourd'hui l'état d'une rivière quand l'eau manque : écoulement, débit, sécheresse. Le commanditaire demande le cas inverse, hors saison au jour de la demande : **savoir qu'une crue est annoncée, et en être prévenu**.

Deux besoins distincts en sortent, et ils ne se livrent pas ensemble :

| Tranche | Besoin | Ce qu'elle prouve |
|---|---|---|
| **T4** | **Lire** la vigilance crues là où je regarde | La vigilance publiée par Vigicrues pour un tronçon se lit sur la carte et dans une fiche, **citée telle que publiée, datée et attribuée**. Une panne de la source est dite ; elle n'est jamais rendue comme le niveau le plus bas |
| **T5** | **Être prévenu** quand un niveau change sur un lieu que je suis | Un changement de niveau sur un lieu suivi — vigilance crues ou gravité sécheresse — produit un avis daté et attribué. Une vérification impossible est dite, elle aussi |

**Ordre arbitré :** T2 → T3 → **T4** → **T5**. T2 reste la condition de la première mise en production ; T4 et T5 n'y changent rien.

## 2. Point de départ — constaté le 2026-10-03

| Élément | État |
|---|---|
| Source Vigicrues dans le code, les fiches de sources, les fixtures | ❌ aucune (recherche de « vigicrues » sans casse : rien sous `docs/` avant ce document, rien sous `lib/` ni `test/`). Le mot n'apparaît que dans `assets/referentiel/stations.json`, 33 fois, dans le texte libre `commentaire_station` de Hub'Eau (« Station de référence vigicrues… ») : **aucun lien structuré** entre une station et un tronçon |
| « Notifications push », « alertes personnalisées », « prévision ou modélisation hydrologique » | `Won't (v1)` dans [`02-specifications.md § 3`](../../02-specifications.md) — amendé ce jour : « alertes personnalisées » en sort pour T5, en avis et notifications **locales** ; « notifications push » au sens d'un envoi par serveur y reste, comme la prévision (§ 5) |
| Échelles de la carte | deux dans le code (`MapScaleKind` : `ecoulement`, `debit`) ; la troisième, sécheresse, se lit par désignation d'un point (T2) |
| Favoris (`US-14`) | 🔄 T3, non livrés — T5 en dépend |
| Moteur de stockage structuré | ouvert ([`ADR-011`](../../adr/ADR-011-stockage-local.md) ne tranche que la préférence simple) — T5 en dépend |
| Backend, compte utilisateur | exclus, et le restent |
| Maquettes | canvas de design « MartinPêcheur — ergonomie échelles, restrictions et fiches », rangée « Crues » (quatre écrans téléphone), publié le 2026-10-03 : <https://claude.ai/artifact/L7wJpLzh1n9rK62bAdyTrU> — artefact privé du commanditaire. **Proposition**, pas une spécification |

### Ce qui a été relevé sur Vigicrues, et ce que ça vaut

Deux adresses ont été lues le 2026-10-03 par un outil qui **résume** la page : aucun corps de réponse n'a été conservé, aucune fixture n'existe. Au sens de la règle du projet, **ce ne sont pas des faits vérifiés** — ce sont des pistes à confirmer par appel réel au lot 0 de T4.

| Adresse | Relevé (résumé, non conservé) |
|---|---|
| `https://www.vigicrues.gouv.fr/services/1/InfoVigiCru.geojson` | A répondu. Collection GeoJSON, tronçons en `MultiLineString`, propriétés lues : `CdEntCru`, `lbentcru` (libellé, par exemple « Eure moyenne et aval »), `NivInfViCr` (niveau), `dhmentcru` (date). Seule valeur de niveau lue : `1`. Le résumé annonce 20 entités, **chiffre non concluant** (lecture peut-être partielle) |
| `https://www.vigicrues.gouv.fr/` | Quatre niveaux nommés vert, jaune, orange, rouge, chacun avec une définition ; production annoncée « au moins deux fois par jour, à 10h et 16h » ; le site propose ses propres abonnements à des avertissements par territoire |

**Non relevé :** le codage des niveaux autres que `1` (seule valeur lue ; une suite de 1 à 4 est une supposition), la portée de l'appel (nationale ou filtrable), le poids des tracés, les conditions de réutilisation des données, le comportement en panne, l'existence d'un lien structuré entre station hydrométrique et tronçon du côté de Vigicrues.

## 3. T4 — Crues : lire la vigilance (Vigicrues)

**Forme arbitrée :** une **quatrième lecture sur la carte**. Les deux formes écartées : la vigilance affichée dans la seule fiche station (suppose un lien station–tronçon non vérifié, et ne montre rien là où il n'y a pas de station) ; un simple lien vers le site Vigicrues (l'usager quitte l'application pour savoir).

### Dedans

| # | Élément | Motif |
|---|---|---|
| D1 | **Lecture « Crues »** dans le sélecteur de la carte, une seule lecture active à la fois | [`BR-008`](../../br/BR-008-une-seule-echelle-a-la-fois.md) — passe de trois à quatre échelles, à amender au cadrage détaillé |
| D2 | **Tronçons colorés** par niveau, le **nom du niveau toujours écrit**, une famille de formes propre à cette échelle | `04-ui.md § 2` : aucune information portée par la seule couleur |
| D3 | **Fiche tronçon** : niveau, définition du niveau **citée telle que publiée**, date de la carte de vigilance, source, lien vers le bulletin | [`BR-001`](../../br/BR-001-date-de-mesure-obligatoire.md), [`BR-014`](../../br/BR-014-aucun-verbe-d-instruction.md) : on cite l'autorité, on ne reformule pas — la règle ne prévoit aujourd'hui cette citation que pour VigiEau, elle est à étendre (§ 5) |
| D4 | **États d'absence et d'échec** : cours d'eau non suivi par Vigicrues, source injoignable, réponse illisible, niveau non reconnu | [`BR-007`](../../br/BR-007-absence-de-donnee-jamais-neutre.md), [`BR-011`](../../br/BR-011-nomenclature-tolerante-a-l-inconnu.md) — une panne ne se lit jamais « vert » |
| D5 | **Avertissement de sécurité** sur les écrans de crue, texte à arbitrer | même esprit que [`BR-013`](../../br/BR-013-avertissement-renforce-sur-ecrans-ressource.md) : l'application n'est pas un système d'alerte |
| D6 | **Source derrière une interface**, comme VigiEau derrière `RestrictionSource` | [`ADR-004`](../../adr/ADR-004-integration-vigieau.md) fait jurisprudence ; un **nouvel ADR** est à écrire |
| D7 | **Fiche de source** `docs/sources/vigicrues.md` et **fixtures datées** | règle du projet : tout fait d'API est vérifié par appel réel, et daté |

### Dehors

| Élément | Motif |
|---|---|
| Toute prévision, tout seuil, tout niveau **calculé par l'application** | « Prévision ou modélisation hydrologique » reste en `Won't (v1)`. T4 **relaie** une vigilance publiée par l'État ; elle ne déduit rien d'un débit ni d'une hauteur |
| Rapprocher un débit « Très haut » (échelle 2) d'un risque de crue | deux natures différentes — une statistique et une vigilance — qui ne se fondent pas (`BR-008`, [`ADR-002`](../../adr/ADR-002-qualification-du-debit.md)) |
| Zones inondables, hauteurs prévues, cartes de submersion | hors du besoin exprimé ; aucune source relevée |
| Avis et notifications | T5 |

### Préalable — lot 0, avant toute ligne de code

Appels réels, datés, conservés en fixtures, sur : la structure de la réponse, le **codage des niveaux**, la **portée de l'appel** — la seule adresse relevée est une collection entière, alors que `NFR-07` exige « aucun appel national en bloc » ([`nfr.md`](../../nfr.md)) —, le **poids des tracés** et son effet sur la fluidité de la carte (`NFR-01`), le rythme de publication, le **comportement en panne**, et les **conditions de réutilisation** des données. Si l'un de ces points contredit la forme arbitrée — appel national sans filtre, tracés trop lourds, réutilisation restreinte — **arrêt et question au commanditaire**, pas de contournement.

## 4. T5 — Être prévenu (avis sur les lieux suivis)

### Dedans

| # | Élément | Motif |
|---|---|---|
| D1 | **Lieux suivis** et, par lieu, le **seuil de vigilance crues** à partir duquel être prévenu (jaune, orange ou rouge, si le lot 0 de T4 confirme ces niveaux) | le seuil porte sur un niveau **publié**, choisi par l'usager — pas un seuil hydrologique |
| D2 | **Avis sur la sécheresse aussi** : quand le niveau de gravité change au lieu suivi | demande du commanditaire : « être prévenue aussi » |
| D3 | **Liste « Avis reçus »**, chaque avis daté et attribué à sa source | `BR-001` |
| D4 | **Avis « Vérification impossible »** quand la source ne répond pas | `BR-007` : un silence ne doit pas se lire comme une absence de crue |
| D5 | **Avertissement « Ce n'est pas un système d'alerte »**, texte à arbitrer, et renvoi vers Vigicrues et vers les consignes des autorités | l'application n'a ni serveur ni engagement de délai |

### Deux étapes

1. **Vérification à l'ouverture de l'application** : les niveaux des lieux suivis sont relus, les changements depuis la dernière ouverture sont listés. Aucune tâche de fond.
2. **Notifications en tâche de fond**, seulement **après un essai technique par cible** (Windows, Android, iOS) qui prouve qu'une vérification part sans que l'application soit ouverte. Sans cette preuve sur une cible, l'étape 2 n'y est pas livrée.

### Dépendances

- **T3** : les favoris (`US-14`) sont le socle des lieux suivis.
- **Stockage structuré** : `ADR-011` laisse le moteur ouvert et lie ce choix aux favoris. Il se tranche donc avec T3 ; T5 s'appuie dessus.
- **Bibliothèque de notifications** : aucune relevée. À vérifier sur `pub.dev` avant ajout — version, licence compatible GPL-3.0, plateformes dont Windows, date de dernière publication.
- **T4** pour les avis de crue ; les avis de sécheresse ne dépendent que de T2 et T3.

### Dehors

Backend, compte utilisateur, envoi par courriel ou SMS, tout engagement de délai.

## 5. Ce que ces tranches changent dans la spec existante

| Document | Changement | Quand |
|---|---|---|
| [`02-specifications.md § 3`](../../02-specifications.md) | « Alertes personnalisées » quitte `Won't (v1)` pour T5, en avis et notifications **locales, sans serveur ni compte** ; « notifications push » (envoi par serveur), « prévision ou modélisation hydrologique », « backend » et « compte utilisateur » y restent | ✅ amendé le 2026-10-03 |
| `BR-014` | la citation « telle quelle » ne vise aujourd'hui que les libellés de VigiEau : à étendre à ceux de Vigicrues | cadrage détaillé de T4 |
| [`project-state.md`](../../project-state.md), `CLAUDE.md` | lignes T4 et T5 dans le tableau des tranches | ✅ le 2026-10-03 |
| `BR-008`, `04-ui.md § 2` | quatrième échelle : teintes, formes, libellés | cadrage détaillé de T4 |
| `glossary.md`, `context-map.md`, `domain-model.md` | vocabulaire de la vigilance, nouveau contexte borné | cadrage détaillé de T4 |
| User stories, cas d'usage, règles métier, ADR | numéros attribués à ce moment-là — `NNN` séquentiel, jamais réservé d'avance | cadrage détaillé de chaque tranche |

## 6. Arbitrages du 2026-10-03

| # | Question | Réponse du commanditaire | Écarté |
|---|---|---|---|
| Q1 | Comment découper le scénario crues ? | **Deux tranches** : T4 lecture, T5 avis | une seule tranche (elle ne se clôt qu'une fois les avis prouvés sur chaque cible) ; lecture seule, avis non planifiés |
| Q2 | Où placer T4 par rapport à T3 ? | **Après T3** | avant T3 (favoris et filtres reculent d'une tranche) |
| Q3 | Quelle forme pour T4 ? | **Quatrième lecture sur la carte** | vigilance dans la seule fiche station ; lien vers Vigicrues seulement |

## 7. Questions ouvertes, pour le cadrage détaillé

**T4**
- Les conditions de réutilisation des données Vigicrues permettent-elles de les afficher dans une application tierce, et sous quelle attribution ?
- Le poids des tracés tient-il `NFR-01` sur Windows, et sur téléphone ?
- Le texte de l'avertissement de sécurité (proposition du canvas : « Ce n'est pas un système d'alerte »).
- Les teintes et formes de la quatrième échelle (proposition du canvas : teintes de la palette existante, jauge à barres).
- La porte de T4 : Windows seul, ou Windows et Android comme T2.

**T5**
- À quelle fréquence vérifier ? Hub'Eau n'a aucun quota documenté (`C-12`), VigiEau annonce `X-RateLimit-Limit: 300` sans fenêtre connue (`C-13`), aucune des deux n'a de SLA (`C-15`), et rien n'est relevé pour Vigicrues.
- Que peut une tâche de fond sur chaque cible, sans serveur ?
- L'étape 1 seule permet-elle de clore la tranche si l'essai de l'étape 2 échoue sur toutes les cibles ?

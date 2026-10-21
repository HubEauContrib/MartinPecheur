# 03 — Conception

**Cible** : **Flutter / Dart**, **Windows en première cible construite** ([`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md)) ; Android réactivé le 2026-09-18 (jamais construit ni lancé), iOS configuré (jamais compilé).

## 1. Stack

### 1.1 Le choix — [`ADR-013`](adr/ADR-013-bascule-flutter-cible-windows.md), [`ADR-014`](adr/ADR-014-feature-first-mvvm.md)

**`flutter_map`**, fond de tuiles raster IGN Géoplateforme (WMTS KVP).

| Besoin | Couverture |
|---|---|
| Regroupement de ~4 150 points | Regroupement par zone administrative sous le zoom 9, sans bibliothèque ([`ADR-015`](adr/ADR-015-regroupement-par-zone-administrative.md)) |
| Tuiles WMTS personnalisées | `TileLayer(urlTemplate: …)`, gabarit KVP passé tel quel |
| **Hors-ligne** | Cache de tuiles **intégré à `flutter_map` depuis 8.2** pour les zones déjà parcourues ; aucun téléchargement de zone à la demande, sorti de la v1 (`US-20`, arbitrage du 2026-08-24, confirmé le 2026-10-21) — le `Must` d'[`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md) reste livré en partie |
| Rendu | Widgets Flutter, compilés nativement sur chaque cible |

**Fond de carte** : IGN Géoplateforme WMTS (Licence Ouverte, cohérent avec des données françaises), OSM en repli (ODbL).
**Stockage local** : `shared_preferences` pour la préférence simple ([`ADR-011`](adr/ADR-011-stockage-local.md)) ; ~~moteur structuré (favoris, cache persistant) encore à trancher.~~ **Depuis T3 (arbitrage 2 du 2026-10-12, `ADR-011` amendé), les favoris y sont aussi** : une clé, une chaîne JSON versionnée (`{ "version": 1, "favoris": [ … ] }`), derrière l'interface `FavoriteRepository` du domaine ; ✅ codé, vérifié par test, non constaté à l'écran. Le **moteur structuré** (cache persistant, hors-ligne) reste **à trancher, ouvert jusqu'au hors-ligne** ([`US-10`](02-specifications.md), [`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md)) : T3 ne le tranche pas.

## 2. Architecture

**Feature-first + MVVM**, l'architecture recommandée par l'équipe Flutter (guide lu le 2026-09-13). Deux couches, et une **tranche par écran** :

| Élément | Où | Rôle |
|---|---|---|
| **View** | `lib/features/<feature>/view/` | widgets. Elle branche et affiche ; elle ne décide pas, et **n'appelle jamais un dépôt** |
| **ViewModel** | `lib/features/<feature>/view_model/` | un `ChangeNotifier` par écran : il expose l'état et les actions, et appelle les dépôts par des **appels typés**. Il **n'importe aucun widget** — c'est ce qui le rend testable sans rendu |
| **Repository** | `lib/data/` | source de vérité d'une donnée, décorée par `CachePolicy`. Produit des objets de domaine, jamais des valeurs brutes d'API |
| **Service / DataSource** | `lib/data/` | enveloppe une source : Hub'Eau v2, ONDE v1, VigiEau derrière `RestrictionSource`, asset des percentiles, stockage local |
| **`domain/`** | `lib/domain/` | Dart pur, **transverse** : entités, unités typées, nomenclatures, interfaces de dépôt. Ne dépend de rien |

**Zéro bibliothèque de gestion d'état** : `ChangeNotifier` et `ListenableBuilder` sont dans Flutter. **Aucune couche de cas d'usage** non plus — le guide l'annonce optionnelle~~, et aucun des six cas d'usage n'orchestre encore deux dépôts~~ ; elle se réintroduirait **entre** ViewModel et dépôt, sans rien défaire. *Barré le 2026-10-14 (revue finale de T3), faux depuis T1 :* les cas d'usage sont huit (`UC-001` à `UC-008`), et des ViewModels lisent plusieurs dépôts, chacun par son appel typé, sans couche de cas d'usage — `MapViewModel` trois (points de stations, observations hydrométriques, observations ONDE) et `StationSheetViewModel` deux (stations, observations) depuis T1 ; depuis T3, les deux fiches lisent aussi les favoris (`StationSheetViewModel` trois dépôts, `OndeSheetViewModel` deux : observations ONDE, favoris).

Tranches **présentes dans le code** (✅, 2026-10-04 ; **`favorites` ajoutée le 2026-10-14**) : `features/{map,station_sheet,onde_sheet,warnings,restrictions,favorites}` — `restrictions` livrée par T2 (`RestrictionsViewModel`, l'écran plein, l'encart renforcé, le badge de gravité ; vérifiée par test ; ~~jamais constatée à l'écran~~ constatée en partie le 2026-10-04, par le commanditaire, en débogage sur Windows (`project-state.md`, point 48), rien en release ni sur Android) —, plus `features/shared/` — widgets communs à plusieurs tranches, n'important aucune tranche (règle `shared-sans-tranche`, amendement d'[`ADR-014`](adr/ADR-014-feature-first-mvvm.md) du 2026-09-18), qui porte aussi, depuis T2, l'écran « D'où vient cette donnée ? » (`data_sources_view.dart`, deux consommateurs : le modal et la fenêtre « ⚠ Avertissement »). `favorites`, livrée par T3 : `FavoritesViewModel` et l'écran « Favoris », route poussée par `main.dart` ; l'étoile des deux fiches vit dans `features/shared/` (`favorite_star.dart`, `favorite_star_button.dart`) ; vérifiée par test, **jamais constatée à l'écran** (porte de T3 due). Tranches **prévues** : ~~🔄 `features/restrictions` (T2),~~ ~~🔄 `features/{favorites,settings}` (T3).~~ (barré le 2026-10-14 : `favorites` est présente, ci-dessus) 🔄 `features/settings` est **hors T3** (cadrage de T3, § 3 : hors « le titre seul »), **tranche ultérieure, non nommée**. Les filtres de T3 ne forment pas de tranche : ils vivent dans `features/map/` (feuille, groupe de boutons, avis) et dans `lib/domain/filters/`. `data/` et `domain/` restent partagés.

**T4 — `flood_sheet` et la lecture Crues (2026-10-15, `F3`).** La tranche `features/flood_sheet/` porte la **fiche tronçon** : `FloodSheetViewModel` (état `FicheTronconFermee` / `FicheTronconOuverte`, ouverture du bulletin par `ExternalLinkOpener`, aucun appel réseau), `FloodSheetPanel` (le cadre et le contenu dans l'ordre du cadrage § 8) et `FloodWarningCard` (l'encart de crue, `BR-015`, non repliable). Elle n'importe aucune autre tranche : seulement `lib/domain/` et `lib/features/shared/` (jauge `flood_level_gauge.dart`, avis `unopened_link_notice.dart`, `warning_link.dart`). L'état de la **lecture Crues** de la carte (chargement, rafraîchissement, avis, « Réessayer ») vit dans la tranche carte : `FloodLayerViewModel` (`features/map/view_model/`), qui lit la carte de vigilance par une interface du domaine (`FloodVigilanceSource`) ; la fiche reçoit le tronçon et la date de la carte déjà lue, jamais un dépôt. Panneau et encart ✅ vérifiés par leurs tests (F3) ; ✅ injection dans la zone des fiches et ouverture, comme les deux autres fiches, composées par `main.dart` (F4), vérifiées par `test/main_test.dart`, non constatées à l'écran. **Jamais constaté à l'écran**.

```mermaid
flowchart LR
  subgraph FEAT["features/&lt;feature&gt;/ — une tranche par écran"]
    V["view/<br/>widgets"]
    VM["view_model/<br/>ChangeNotifier :<br/>état + actions"]
  end
  subgraph DATA["data/ — partagé"]
    REPO["Repository + mappers<br/>décoré par CachePolicy"]
    REM["RemoteDataSource<br/>retry, backoff à gigue"]
    LOC["LocalDataSource<br/>base locale + cache de tuiles"]
    ASSET["Asset embarqué<br/>référence percentiles"]
  end
  DOM["domain/ — Dart pur, transverse<br/>entités, unités, nomenclatures,<br/>interfaces de dépôt"]

  V -->|écoute, déclenche une action| VM
  VM -->|appel typé| REPO
  REPO --> REM
  REPO --> LOC
  REPO --> ASSET
  REM -.-> HE[("Hub'Eau v2 hydrométrie<br/>Hub'Eau v1 écoulement")]
  REM -.-> VE[("VigiEau — derrière RestrictionSource")]
  VM -.-> DOM
  REPO -.-> DOM
  style DOM fill:#27ae60,color:#fff
```

**Le sens des dépendances est verrouillé par un test**, pas seulement écrit : `data/` n'importe jamais `features/`, `domain/` n'importe aucune infrastructure, et un `view_model` n'importe ni `material.dart` ni `widgets.dart`.

**Isolation du risque VigiEau** : une seule interface `RestrictionSource`, déclarée dans le domaine (`lib/domain/restrictions/`), et ~~deux implémentations (API, puis export data.gouv en repli)~~ **une implémentation en T2** : `VigieauRestrictionSource` (`lib/data/restrictions/`), décorée par `CachedRestrictionSource` (cache de session, 6 h) et posée sur le transport HTTP partagé `JsonHttpClient`, extrait de `HubEauClient`. Le repli sur l'export data.gouv est **différé** (Q3-B, arbitré le 2026-09-27, `ADR-004` amendé) : il ne s'écrira que sur une rupture constatée. Une rupture de l'API `0.1` n'impacte qu'un module, `lib/data/restrictions/`.

## 3. Modèle de données local

> Les trois échelles d'état sont **séparées**. Les fondre dans un champ unique (`normal/alerte/assec/crise`) mélangerait un fait observé, une statistique et une décision préfectorale — trois natures différentes, trois responsabilités différentes.

| Entité | Champs | Relations |
|---|---|---|
| `Departement` | `Code` (PK), `Nom`, `CodeRegion` | Asset embarqué, jamais rafraîchi |
| `Station` | `CodeStation` (PK, 10 car.), `LibelleStation`, `Latitude`, `Longitude`, `CodeDepartement` (idx), `LibelleCoursEau`, `EnService`, `DateMajReferentiel` | → `Departement` |
| `ObservationHydro` | `Id` (PK), `CodeStation` (idx), `DateObs`, `GrandeurHydro` (`H`\|`Q`), `ValeurM3S`, `ValeurM`, `CodeStatut`, `LibelleStatut`, `CodeQualification`, `LibelleQualification` | → `Station` |
| `SerieDebitJournaliere` | `Id` (PK), `CodeStation` (idx), `DateObs`, `ValeurM3S` | → `Station` — issue d'`obs_elab/QmnJ` |
| `NiveauDebitCalcule` | `CodeStation` (PK), `Classe` (`TresBas`…`TresHaut`\|`Indetermine`), `Percentile`, `DateCalcul`, `NbAnneesReference` | → `Station` — **échelle 2** |
| `ReferencePercentile` | `CodeStation` + `Quinzaine` (PK composite), `P10`, `P25`, `P50`, `P75`, `P90`, `NbAnnees` | **Asset embarqué en lecture seule**, `DateGeneration` en métadonnée |
| `PointOnde` | `CodeStation` (PK), `LibelleStation`, `Latitude`, `Longitude`, `CodeDepartement` (idx), `LibelleCoursEau` | → `Departement` |
| `CampagneOnde` | `CodeCampagne` (PK), `DateCampagne`, `TypeCampagne` (minuscules) | — |
| `ObservationOnde` | `Id` (PK), `CodeStation` (idx), `CodeCampagne` (idx), `CodeEcoulement` (**string**), `LibelleEcoulement`, `Categorie` (`Normal`\|`Faible`\|`NonVisible`\|`Assec`\|`NonObserve`), `DateObservation` | → `PointOnde`, `CampagneOnde` — **échelle 1** |
| 💭 `ZoneRestriction` | `IdZone` (PK), `CodeDepartement` (idx), `Nom`, `TypeZone` (`SUP`\|`SOU`\|`AEP`), `NiveauGravite`, `DateDebut`, `DateFin`, `UrlArrete`, `UrlArreteCadre` | **échelle 3** — ~~filtrée sur `SUP` pour l'usage rivière~~ schéma de stockage **non retenu en T2** : aucune persistance, voir la note sous ce tableau |
| 💭 `UsageRestreint` | `Id` (PK), `IdZone` (idx), `Nom`, `Thematique`, `Description`, `ConcerneParticulier`, `ConcerneExploitation`, `ConcerneCollectivite`, `ConcerneEntreprise` | → `ZoneRestriction` — idem |
| `Favori` | ~~`CodeEntite` (PK), `TypeEntite`, `DateAjout`~~ **Clé : le couple (`TypeEntite`, code)** — jamais `CodeEntite` seul ; `DateAjout` ; un libellé copié à l'ajout. Voir la note sous ce tableau | ~~Polymorphe~~ **Stations hydrométriques et points ONDE**, type clos : ni jointure ni table, la forme stockée est une chaîne JSON (note du 2026-10-14 ci-dessous) |
| `CacheMeta` | `CleCache` (PK), `TypeDonnee`, `DateRecuperation`, `TtlSecondes`, `TailleOctets` | Pilote la purge |
| `DerniereVueCarte` | `Id` (PK, unique), `BboxMinLat/Lon`, `BboxMaxLat/Lon`, `Zoom`, `DateSnapshot` | Ancre du hors-ligne |
| `TuilePack` | `Id` (PK), `BboxRef`, `ZoomMin`, `ZoomMax`, `CheminFichier`, `DateTelechargement` | Fichiers hors base |

> **Note du 2026-10-04 (`X3` de T2) — les deux lignes 💭 ci-dessus ne sont pas celles du code.** T2 ne persiste rien : la réponse de VigiEau est un instantané daté tenu **en mémoire** (cache de session, perdu au relancement), jamais une table. Le modèle réellement écrit est celui de `lib/domain/restrictions/` — `ZonesAtPoint` (le point, la date de récupération, **toutes** les zones, sans filtre sur `SUP`), `AlertZone`, `RestrictionDecree`, `DocumentLink`, `RestrictedUsage`, `DroughtSeverity`, `ZoneKind`, `UserProfile` — décrit par [`domain-model.md`](domain-model.md). Il n'a **ni `IdZone` ni `CodeDepartement`** (`code` vaut `null` sur une zone et se partage entre types : il n'aurait rien identifié), et la partition « eaux superficielles d'abord, autres zones ensuite » vit dans le domaine (`ZonesAtPoint.surfaceWaterZones` / `otherZones`). Le schéma de stockage ci-dessus ne servira que si un moteur structuré est tranché ([`ADR-011`](adr/ADR-011-stockage-local.md)).

> **Note du 2026-10-14 (`X1` de T3) — la ligne `Favori` ci-dessus n'est pas celle du code.** Le modèle réellement écrit est celui de `lib/domain/favorites/`, décrit par [`domain-model.md`](domain-model.md) : `Favorite`, une `sealed class` à trois branches (`BR-011`) — `StationFavorite` (le `StationCode`, le libellé copié à l'ajout, la date d'ajout en UTC ; **sans coordonnées**), `OndePointFavorite` (le `OndePoint` entier, parce que l'ouverture de la fiche l'exige, et la date d'ajout) et `UnreadableFavorite` (le texte brut tel que stocké et son libellé s'il se lit : affiché, retirable, non ouvrable, réécrit tel quel à chaque écriture). **La clé d'un lieu est le couple (type, code), jamais `CodeEntite` seul** : un code ONDE est une chaîne libre, un code station compte dix caractères, et rien n'interdit la même valeur dans les deux ; un favori illisible s'identifie par son texte brut. Un favori est une **identité copiée à l'ajout, jamais une mesure**. Rien n'est une table : `FavoriteRepository` (contrat dans `lib/domain/favorites/` : lire tout, ajouter, retirer, tout effacer ; réalisation `SharedPreferencesFavoriteRepository` sous `lib/data/preferences/`) lit et écrit **une chaîne JSON sous la clé `favorites`**, `{ "version": 1, "favoris": [ … ] }`, chaque entrée portant son `type`. Le dernier ajouté est en tête. Le filtre de la carte (`MapFilter`, `lib/domain/filters/`) n'est, lui, **jamais enregistré** : gardé le temps de la session.

## 4. Cache et rafraîchissement

### 4.1 Politique par type de donnée

| Donnée | TTL | Stratégie | Purge |
|---|---|---|---|
| Référentiel stations (6 454 lignes) | 30 j | Préchargement au 1er lancement, puis SWR | Remplacement en bloc |
| Référentiel points ONDE (3 548) | 30 j | Idem | Remplacement en bloc |
| `observations_tr` | **20 min** | Cache affiché immédiatement, rafraîchissement en tâche de fond si TTL dépassé **et** réseau disponible | Dernière valeur toujours conservée |
| `obs_elab` (courbe) | 12 h | À la demande à l'ouverture de la fiche | LRU par (station, fenêtre) |
| Campagnes ONDE | **30 j en saison (mai-sept), 90 j hors saison** | Vérification d'une nouvelle campagne au lancement | 2 dernières campagnes conservées |
| Zones de restriction | **6 h** | SWR + ~~badge horodaté~~ date de récupération rappelée sur l'écran (« Réponse de VigiEau obtenue le … ») — **cache de session en mémoire, perdu au relancement** (T2, `CachedRestrictionSource`) | Remplacement en bloc |
| `ReferencePercentile` | ∞ | Asset embarqué, jamais d'appel réseau | Remplacé à chaque release |
| Départements | ∞ | Asset embarqué | — |
| Tuiles | LRU, plafond **150 Mo** configurable | Pack local pour la bbox visitée | Auto au-delà du plafond, ou manuelle |

**Règle générale** : lecture du cache → rendu immédiat → si TTL dépassé et réseau disponible, rafraîchissement en tâche de fond → sinon, badge « données du JJ/MM à HH:MM ».

> ⚠️ **Deux âges distincts, à ne pas confondre** — corrigé le 2026-08-01, ce paragraphe les mélangeait.
>
> | Âge | Mesuré sur | Seuils | Effet |
> |---|---|---|---|
> | **Fraîcheur du cache** | date de récupération | le TTL du tableau ci-dessus | déclenche le rafraîchissement en tâche de fond |
> | **Âge de la mesure** (`BR-005`) | **`date_obs`** | **2 h** puis **24 h**, absolus | mention « il y a N h », puis marqueur atténué |
>
> Une observation peut être **fraîchement téléchargée et vieille de neuf jours** : c'est le cas en production (`BR-001`). Appliquer « 2 × TTL » à l'âge de la mesure déclarerait périmée une observation de 40 minutes, à qui `BR-005` laisse 24 heures.

> Cette règle est portée par **un composant unique** — le décorateur de dépôt `CachePolicy`, sous `lib/data/` ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md)) — jamais recopiée dans un dépôt nu, un ViewModel ou un widget.

### 4.2 Implémentation — client HTTP

- Client `package:http` par source, avec **retry et backoff exponentiel à gigue** sur 429, 5xx et erreurs réseau transitoires ([`CLAUDE.md`](../CLAUDE.md) § HTTP) — ✅ livré en T0 (`N4`) ; **depuis le 2026-10-06 chaque tentative est bornée** — ~~à 10 s~~ à **20 s pour Hub'Eau**, **10 s pour VigiEau** (arbitrage du commanditaire, revue de la PR #17, puis le soir pour les 20 s de Hub'Eau, mesure `T-17` de [`sources/onde.md`](sources/onde.md)) — et rejouée comme une panne réseau ([`nfr.md`](nfr.md), `NFR-07`).
- **206 doit être traité comme un succès** (`C-06`) : normaliser 200 et 206 au même endroit, jamais un test `status == 200` seul qui casse dès la première pagination.
- Throttle client global : Hub'Eau n'annonce aucun quota, et l'app n'a pas de proxy pour mutualiser la charge de sa base installée (`C-15`).
- Conversion l/s → m³/s **et** mm → m dans le mapper uniquement, couverte par test unitaire (`BR-002`). **`extension type`** (`LitresPerSecond`, `CubicMetresPerSecond`, `Millimetres`, `Metres`) pour empêcher qu'un `double` nu en l/s soit passé là où on attend des m³/s — Dart les ferme dans les deux sens.
- Toute nomenclature porte une branche `Inconnu`, garantie par un `sealed class` + `switch` exhaustif — oublier une branche est une erreur de compilation (`BR-011`).

### 4.3 Hors-ligne « dernière carte consultée » — 💭 non livré, mécanisme à trancher

Cette section décrit un **besoin**, pas un mécanisme retenu. Sur `flutter_map`, seul le cache de
tuiles déjà parcourues sert hors réseau (constaté le 2026-09-13, `NV-W2`). Le **pré-téléchargement
de zone est sorti de la v1** (`US-20`, arbitrage du commanditaire du 2026-08-24, confirmé le
2026-10-21) : aucun mécanisme de téléchargement n'est à concevoir. Le besoin fonctionnel reste :

1. À chaque stabilisation de la carte, retenir la dernière bbox + zoom consultés.
2. Les stations et points ONDE de cette bbox, avec leur dernière observation connue, doivent être
   disponibles hors réseau — sans duplication avec le cache déjà en mémoire.
3. Au lancement sans réseau : centrage sur la dernière vue → marqueurs au dernier état connu →
   bandeau persistant « Mode hors-ligne — données du JJ/MM/AAAA à HH:MM ».

Le `Must` d'[`UC-005`](use-cases/UC-005-consulter-la-carte-hors-ligne.md) reste **livré en partie** :
seul le cache de tuiles l'est.

## 5. Arborescence des écrans

```
Navigateur racine
├── Avertissement initial (modal bloquant, hors navigation, acquittement requis)
├── Carte ......................... écran d'accueil — ✅ mise en page de la tranche d'ergonomie (`map_layout.dart`), sur trois largeurs : moins de 600 px, 600 à 799 px, 800 px et plus (`mapLayoutWidthFor`) ; vérifiée par test, non constatée à l'écran (porte de la tranche due)
│   ├── Bloc de lecture (en haut ; toute la largeur sous 600 px, 480 px au plus en haut à gauche au-delà) ...... trois pièces posées sans écart, une seule carte blanche (`map_reading_block.dart`)
│   │   ├── Partie fixe (titres du sélecteur et en-tête toujours entiers ; les sous-titres s'effacent, puis elle défile en dernier recours — arbitrages 13, 18 et 19) : sélecteur de lecture (`map_reading_selector.dart`) puis en-tête « Légende · <lecture> » qui porte le contrôle « ⚠ Avertissement » → fenêtre (W3c, présent dans tous les états)
│   │   │   └── Sélecteur : trois lectures exclusives (écoulement, débit, vigilance crues) et l'interrupteur « Restrictions » (pas une lecture : il s'allume en plus de la lecture affichée) ; sous-titres effacés quand la hauteur manque
│   │   ├── Avis (absence, hors couverture, filtre qui cache tout, panne, lignes illisibles, états de la lecture Crues) ...... défile dans le bloc
│   │   └── Légende de la lecture active ...... défile dans le bloc
│   ├── Recherche (station / cours d'eau) ...... 🔄 tranche ultérieure, non nommée (arbitrage 1 du 2026-10-12, `US-16`)
│   ├── Bas de la carte (`MapBottom`, `map_bottom.dart`) ...... sous 600 px une rangée (« Favoris », « Filtres » à gauche ; −, +, recentrer à droite ; attribution IGN dessous), dès 600 px une colonne au bas à droite
│   │   ├── Favoris (bouton) ...... ✅ T3 : pousse l'écran « Favoris » ci-dessous
│   │   └── Filtres (feuille) ✅ T3 : ~~type ·~~ état · département · fraîcheur  ←  « type » = l'échelle, choisie par le sélecteur de lecture, non par la feuille ; états sur l'écoulement seul, fraîcheur (2 h, 24 h) sur le débit seul ; ouverte par le bouton « Filtres » du même groupe
│   ├── En mode « Restrictions » : bande du bouton de désignation (au bas de la carte visible) et réticule (au centre) ...... retirés, fiche ouverte, au téléphone quand la hauteur manque et à toute largeur quand la bande ne tient pas à côté de la colonne du bas (repli 6, arbitrages 14 et 20)
│   └── Fiche ouverte au tap sur un marqueur, un trait ou une étiquette de vigilance, ou depuis « Favoris », une à la fois (`map_sheet_area.dart`) ...... fiche du bas sous 800 px, panneau latéral de 380 px à droite dès 800 px ; la carte visible est l'écran moins la fiche, et la carte ne bouge pas
├── Fiche station hydrométrique .... panneau de la zone des fiches (`map_sheet_area.dart`), paramétré par CodeStation
│   ├── Débit (m³/s) + date + statut de qualification
│   ├── Niveau relatif à l'historique + limites
│   ├── Courbe 7 / 30 / 90 j ...... 🔄 tranche ultérieure, non nommée (arbitrage 1 du 2026-10-12, `US-11`)
│   └── Actions : favori ✅ T3 (étoile, dans le cadre de la fiche), télécharger la zone, partager
├── Fiche tronçon Vigicrues ........ ✅ panneau et encart (T4, `F3`, `lib/features/flood_sheet/`) · ✅ injection et ouverture depuis un trait ou une étiquette composées par `main.dart` (F4), vérifiées par `test/main_test.dart`, non constatées à l'écran ; nom publié, encart de crue non repliable, niveau, définition citée, date, bulletin
├── Fiche point ONDE ............... panneau de la zone des fiches (`map_sheet_area.dart`), paramétré par CodeStation
│   ├── Catégorie + modalité officielle + date de campagne
│   ├── Historique des campagnes
│   ├── Action : favori ✅ T3 (étoile, dans le cadre de la fiche)
│   └── Avertissement renforcé
├── Sécheresse et restrictions ..... écran plein poussé par la désignation d'un point sur la carte (choix « Restrictions » puis bouton, appui long ou clic droit) ; avertissement renforcé en tête
│   ├── Point désigné, date de récupération, **toutes** les zones du point (eaux superficielles d'abord) et leur niveau de gravité
│   ├── Arrêtés : PDF de l'arrêté et de l'arrêté-cadre, dédoublonnés
│   └── Choix du profil, puis usages restreints groupés par zone
├── Favoris ........................ ✅ écran plein livré par T3 (`lib/features/favorites/`, `S9`), route poussée par `main.dart` depuis le bouton « Favoris » de la carte, qui ferme les fiches ouvertes ; vérifié par test, non constaté à l'écran
│   ├── Liste : l'identité de chaque lieu (libellé, nature, date d'ajout), **aucune mesure** ; retrait depuis la ligne
│   ├── Ouvrir un favori : la fiche seule, la carte ne bouge pas (arbitrage 6 du 2026-10-12)
│   └── États : lecture en cours · liste · vide · illisible (avis et « Repartir d'une liste vide »)
├── D'où vient cette donnée ? ...... ✅ écran plein livré par T2 (`S1`, `lib/features/shared/data_sources_view.dart`), réduit aux sources livrées : quatre sources, licences, `L-06`, limites propres aux restrictions ; ~~limites L-01 à L-06, glossaire~~ `L-01` à `L-05` n'y figurent pas tant qu'aucun percentile n'est affiché (Q8-A, `C1` de T2), et le glossaire n'y figure pas
└── Réglages ...................... 🔄 hors T3, tranche `settings` ultérieure, non nommée (comme au § 2)
    ├── Cache et zones hors-ligne
    └── À propos — sources, licences, date de génération de l'asset
```

> **Les trois fiches (station, point ONDE, tronçon) partagent un cadre** (`SheetFrame`, `lib/features/shared/sheet_frame.dart`) : un en-tête épinglé (nature, étoile, fermeture, « ⚠ Avertissement ») qui ne cède jamais, et un corps qui défile dessous. Fiche du bas ouverte, le corps ne cède que jusqu'à sa mesure mise en avant (la tuile **Débit**, la tuile de la **catégorie**, le **niveau**) : là où les six replis ne la lui laissent pas, la partie fixe du bloc de lecture défile, jusqu'à une cible tactile ; plus bas seulement, le corps cède sous sa mesure, jusqu'à l'en-tête (arbitrages 18 et 19). L'ordre de repli complet est dans `map_layout_allocation.dart` et dans le cadrage d'ergonomie (§ 5.6). L'ordre de tabulation est déclaré par les constantes `mapTraversalOrder*` (`map_traversal_order.dart`).

## 6. Points de vigilance

| Sujet | Vigilance |
|---|---|
| Pagination | Curseur sur `observations_tr` et `obs_elab` ; `page`+`size` ailleurs, avec `page × size ≤ 20 000`. Segmenter par département, jamais de dump national |
| `obs_elab` | Aucun `sort` : toujours passer `date_debut_obs_elab`, sinon la réponse commence en 1900 |
| Codes station | Interroger des codes à 10 caractères, jamais des codes site — sinon doublons |
| Volume de marqueurs | Clustering obligatoire dès le zoom départemental ; chargement par viewport avec anti-rebond de 300–500 ms |
| Batterie et GPS | Géolocalisation ponctuelle uniquement, précision approximative, aucun suivi continu ni tâche de fond |
| Référentiel | Filtrer `EnService = false` et les coordonnées absentes avant affichage |
| Asset percentiles | Le script de build est un livrable versionné, avec sa procédure de régénération documentée |

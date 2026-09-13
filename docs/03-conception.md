# 03 — Conception

**Cible** : **React Native + TypeScript**, **Android et iOS** en v1 ([`ADR-010`](adr/ADR-010-react-native.md)). Windows, macOS et Mac Catalyst sont hors périmètre.

> ⚠️ **Réécrit le 2026-07-31.** Ce document décrivait une stack .NET MAUI jusqu'à cette date. Le commanditaire a révisé son arbitrage : [`ADR-005`](adr/ADR-005-stack-maui-blazor-hybrid.md), [`ADR-008`](adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md) et [`ADR-009`](adr/ADR-009-cible-windows.md) sont remplacés par [`ADR-010`](adr/ADR-010-react-native.md).

## 1. Stack

### 1.1 Ce qui a été éliminé

`react-native-maps` (Google/Apple Maps) est écarté : incompatible avec des **tuiles personnalisées** et avec le **hors-ligne**, qui sont deux exigences du produit. Le même motif avait éliminé `Microsoft.Maui.Controls.Maps` dans la conception précédente — la contrainte vient du produit, pas de la technologie.

### 1.2 Le choix — [`ADR-010`](adr/ADR-010-react-native.md)

**`@maplibre/maplibre-react-native` (v11+), adossé à MapLibre Native.**

| Besoin | Couverture |
|---|---|
| Clustering sur ~4 140 points | Configuration de couche, cas d'usage courant |
| Tuiles WMTS/XYZ personnalisées | Sources natives |
| **Hors-ligne** | **`OfflineManager.createPack`** — région + niveaux de zoom, téléchargement suivi par callbacks |
| Rendu | **Natif, accéléré GPU** — pas de WebView à nourrir |

C'est le hors-ligne qui a fait basculer la décision : il était un **lot de développement à chiffrer** en .NET, il est une **API fournie** ici.

⚠️ **v11 a changé son API hors-ligne** : packs identifiés par id auto-généré, `addListener`/`removeListener` au lieu de `subscribe`/`unsubscribe`. Cibler la v11+ dès le départ.

**Fond de carte** : IGN Géoplateforme WMTS (Licence Ouverte, cohérent avec des données françaises), OSM en repli (ODbL). *Inchangé — ce choix ne dépendait pas de la stack.*
**Stockage** : SQLite (`expo-sqlite` ou `op-sqlite`, **à trancher**) ; les packs de tuiles sont gérés par MapLibre, pas par nous.
**Empaquetage** : **Expo avec *development builds*** — `maplibre-react-native` embarque du code natif, Expo Go ne suffit pas.

## 2. Architecture

> ⚠️ **Cette section est réécrite le 2026-09-13** ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), arbitrage du commanditaire). Elle décrivait une architecture en couches avec un contrat `Query`/`Command` et un registre de gestionnaires, repris d'[`ADR-008`](adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md) : ce volet est abandonné.

**Feature-first + MVVM**, l'architecture recommandée par l'équipe Flutter (guide lu le 2026-09-13). Deux couches, et une **tranche par écran** :

| Élément | Où | Rôle |
|---|---|---|
| **View** | `lib/features/<feature>/view/` | widgets. Elle branche et affiche ; elle ne décide pas, et **n'appelle jamais un dépôt** |
| **ViewModel** | `lib/features/<feature>/view_model/` | un `ChangeNotifier` par écran : il expose l'état et les actions, et appelle les dépôts par des **appels typés**. Il **n'importe aucun widget** — c'est ce qui le rend testable sans rendu |
| **Repository** | `lib/data/` | source de vérité d'une donnée, décorée par `CachePolicy`. Produit des objets de domaine, jamais des valeurs brutes d'API |
| **Service / DataSource** | `lib/data/` | enveloppe une source : Hub'Eau v2, ONDE v1, VigiEau derrière `RestrictionSource`, asset des percentiles, stockage local |
| **`domain/`** | `lib/domain/` | Dart pur, **transverse** : entités, unités typées, nomenclatures, interfaces de dépôt. Ne dépend de rien |

**Zéro bibliothèque de gestion d'état** : `ChangeNotifier` et `ListenableBuilder` sont dans Flutter. **Aucune couche de cas d'usage** non plus — le guide l'annonce optionnelle, et aucun des six cas d'usage n'orchestre encore deux dépôts ; elle se réintroduirait **entre** ViewModel et dépôt, sans rien défaire.

Tranches prévues : `features/{map,station_detail,onde,restrictions,favorites,settings}`, plus `data/` et `domain/` partagés.

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

**Isolation du risque VigiEau** : une seule interface `RestrictionSource`, deux implémentations (API, puis export data.gouv en repli). Une rupture de l'API `0.1` n'impacte qu'une classe.

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
| `ZoneRestriction` | `IdZone` (PK), `CodeDepartement` (idx), `Nom`, `TypeZone` (`SUP`\|`SOU`\|`AEP`), `NiveauGravite`, `DateDebut`, `DateFin`, `UrlArrete`, `UrlArreteCadre` | **échelle 3** — filtrée sur `SUP` pour l'usage rivière |
| `UsageRestreint` | `Id` (PK), `IdZone` (idx), `Nom`, `Thematique`, `Description`, `ConcerneParticulier`, `ConcerneExploitation`, `ConcerneCollectivite`, `ConcerneEntreprise` | → `ZoneRestriction` |
| `Favori` | `CodeEntite` (PK), `TypeEntite`, `DateAjout` | Polymorphe |
| `CacheMeta` | `CleCache` (PK), `TypeDonnee`, `DateRecuperation`, `TtlSecondes`, `TailleOctets` | Pilote la purge |
| `DerniereVueCarte` | `Id` (PK, unique), `BboxMinLat/Lon`, `BboxMaxLat/Lon`, `Zoom`, `DateSnapshot` | Ancre du hors-ligne |
| `TuilePack` | `Id` (PK), `BboxRef`, `ZoomMin`, `ZoomMax`, `CheminFichier`, `DateTelechargement` | Fichiers hors base |

## 4. Cache et rafraîchissement

### 4.1 Politique par type de donnée

| Donnée | TTL | Stratégie | Purge |
|---|---|---|---|
| Référentiel stations (6 454 lignes) | 30 j | Préchargement au 1er lancement, puis SWR | Remplacement en bloc |
| Référentiel points ONDE (3 548) | 30 j | Idem | Remplacement en bloc |
| `observations_tr` | **20 min** | Cache affiché immédiatement, rafraîchissement en tâche de fond si TTL dépassé **et** réseau disponible | Dernière valeur toujours conservée |
| `obs_elab` (courbe) | 12 h | À la demande à l'ouverture de la fiche | LRU par (station, fenêtre) |
| Campagnes ONDE | **30 j en saison (mai-sept), 90 j hors saison** | Vérification d'une nouvelle campagne au lancement | 2 dernières campagnes conservées |
| Zones de restriction | **6 h** | SWR + badge horodaté | Remplacement en bloc |
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

> Cette règle est portée par **un composant unique** — le décorateur de dépôt `CachePolicy`, sous `lib/data/` ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md) ; le principe « un seul endroit » vient d'[`ADR-008`](adr/ADR-008-cqrs-leger-et-cache-en-pipeline.md), son véhicule a changé) — jamais recopiée dans un dépôt nu, un ViewModel ou un widget.

### 4.2 Implémentation React Native

- Client `fetch` par source, avec **retry et backoff exponentiel à gigue** sur 429, 5xx et erreurs réseau transitoires.
- **206 doit être traité comme un succès** : `fetch` ne lève pas, mais tout test `status === 200` casse dès la première pagination (`C-06`). Normaliser 200 et 206 au même endroit.
- État du réseau vérifié avant toute tentative (`@react-native-community/netinfo`, **à confirmer**).
- Throttle client global : Hub'Eau n'annonce aucun quota, et l'app n'a pas de proxy pour mutualiser la charge de sa base installée (`C-15`).
- Conversion l/s → m³/s dans le mapper uniquement, couverte par test unitaire (`BR-002`). **Types *branded*** pour empêcher qu'un `number` en l/s soit passé là où on attend des m³/s — TypeScript ne l'interdit pas seul.
- Toute nomenclature porte une branche `Inconnu`, garantie par un `switch` exhaustif gardé par `never` (`BR-011`).

### 4.3 Hors-ligne « dernière carte consultée »

1. À chaque stabilisation de la carte, `DerniereVueCarte` est mise à jour (bbox + zoom).
2. Les `Station` et `PointOnde` de cette bbox, avec leur dernière observation connue, sont déjà en base : aucune duplication.
3. Un **pack MapLibre** est créé pour la bbox ± marge, sur le zoom courant ± 2 niveaux, via `OfflineManager.createPack`.
4. Au lancement sans réseau : lecture de `DerniereVueCarte` → centrage → **le pack local sert les tuiles nativement** → marqueurs au dernier état connu → bandeau persistant « Mode hors-ligne — données du JJ/MM/AAAA à HH:MM ».

> **Ce point faible a disparu.** La conception précédente devait développer spécifiquement l'énumération, le téléchargement et le stockage des tuiles XYZ, faute d'équivalent côté .NET. `OfflineManager.createPack` couvre le besoin ([`ADR-010`](adr/ADR-010-react-native.md), vérifié le 2026-07-31). ⚠️ **Reste à constater** que `createPack` accepte bien une source **raster WMTS** (IGN) et pas seulement des tuiles vectorielles — non vérifié.

## 5. Arborescence des écrans

```
Navigateur racine
├── Avertissement initial (modal bloquant, hors navigation, acquittement requis)
├── Carte ......................... écran d'accueil
│   ├── Recherche (station / cours d'eau)
│   ├── Filtres (feuille) : type · état · département · fraîcheur
│   ├── Légende de l'échelle active
│   ├── Bandeau d'avertissement permanent
│   └── Résumé au tap (feuille) → fiche
├── Fiche station hydrométrique .... route paramétrée par CodeStation
│   ├── Débit (m³/s) + date + statut de qualification
│   ├── Niveau relatif à l'historique + limites
│   ├── Courbe 7 / 30 / 90 j
│   └── Actions : favori, télécharger la zone, partager
├── Fiche point ONDE ............... route paramétrée par CodeStation
│   ├── Catégorie + modalité officielle + date de campagne
│   ├── Historique des campagnes
│   └── Avertissement renforcé
├── Sécheresse et restrictions ..... avertissement renforcé en tête
│   ├── Zone géolocalisée + niveau de gravité
│   ├── Usages restreints (filtrables par profil)
│   └── PDF de l'arrêté + arrêté-cadre
├── Favoris
├── D'où vient cette donnée ? ...... limites L-01 à L-06, glossaire
└── Réglages
    ├── Cache et zones hors-ligne
    └── À propos — sources, licences, date de génération de l'asset
```

## 6. Points de vigilance

| Sujet | Vigilance |
|---|---|
| Pagination | Curseur sur `observations_tr` et `obs_elab` ; `page`+`size` ailleurs, avec `page × size ≤ 20 000`. Segmenter par département, jamais de dump national |
| `obs_elab` | Aucun `sort` : toujours passer `date_debut_obs_elab`, sinon la réponse commence en 1900 |
| Codes station | Interroger des codes à 10 caractères, jamais des codes site — sinon doublons |
| Volume de marqueurs | Clustering obligatoire dès le zoom départemental ; chargement par viewport avec anti-rebond de 300–500 ms |
| Batterie et GPS | Géolocalisation ponctuelle uniquement, précision approximative, aucun suivi continu ni tâche de fond |
| WebView | Mémoire et temps de démarrage à mesurer sur Android d'entrée de gamme, dans le spike |
| Référentiel | Filtrer `EnService = false` et les coordonnées absentes avant affichage |
| Asset percentiles | Le script de build est un livrable versionné, avec sa procédure de régénération documentée |

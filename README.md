<div align="center">

# MartinPêcheur

**L'état de votre rivière, sans promesse qu'on ne peut pas tenir.**

Application mobile qui informe les usagers d'une rivière française sur son état —
**écoulement**, **débit**, **sécheresse** — à partir des données publiques ouvertes
**Hub'Eau** et **VigiEau**.

[![Licence](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE.txt)
[![TypeScript](https://img.shields.io/badge/TypeScript-strict-3178c6.svg)](tsconfig.json)
[![React Native](https://img.shields.io/badge/React%20Native-0.86-61dafb.svg)](package.json)
[![Expo](https://img.shields.io/badge/Expo-SDK%2057-000020.svg)](app.json)
[![Plateformes](https://img.shields.io/badge/plateformes-Android%20%7C%20iOS-3ddc84.svg)](docs/adr/ADR-010-react-native.md)

[Documentation](docs/README.md) · [État du projet](docs/project-state.md) ·
[Installation](docs/guide-installation.md) · [Décisions](docs/README.md#index-des-décisions)

</div>

---

> *Le martin-pêcheur ne pêche que dans une eau claire et vive. Sa présence dit l'état de la
> rivière — c'est un indicateur, pas une garantie.*

## Sommaire

- [Le produit](#le-produit) · [Ce qu'il refuse de faire](#ce-quil-refuse-de-faire)
- [Démarrage rapide](#démarrage-rapide) · [Commandes](#commandes)
- [Architecture](#architecture) · [Contribuer](#contribuer) · [Licences](#licences)

## Le produit

MartinPêcheur s'adresse aux riverains, aux agriculteurs et irrigants, aux pêcheurs, aux usagers de
loisir et aux collectivités.

| | |
|---|---|
| 🗺️ **Une carte** | Stations hydrométriques et points d'observation ONDE, colorés par état, avec clustering et filtres |
| 💧 **Le débit** | En m³/s, avec sa date, son statut de qualification et sa courbe d'évolution |
| 🏞️ **L'écoulement observé** | L'eau coule-t-elle encore, ou le lit est-il à sec ? |
| ⚠️ **Les restrictions sécheresse** | Celles de votre zone, par profil d'usager, avec l'arrêté préfectoral |
| 📴 **Le hors-ligne** | La dernière carte consultée reste disponible sans réseau |

**Périmètre v1** — pas de backend · pas de compte utilisateur · pas de notifications · pas de
prévision hydrologique.

## Ce qu'il refuse de faire

Le produit repose sur un principe simple : **ne jamais laisser croire à ce qu'il ne sait pas.**

- Il ne répond **jamais** à « le débit est-il suffisant ? ». Aucune API publique n'expose de seuil
  réglementaire par station — le vérifier a fait partie du cadrage. Le produit situe un débit par
  rapport à l'historique de sa propre station, et nomme cela pour ce que c'est : une statistique.
- Il ne remplace **ni** un arrêté préfectoral, **ni** une décision d'irrigation, **ni** une
  évaluation de sécurité avant de se baigner, naviguer ou traverser.
- Il n'affiche **aucune** donnée de qualité de l'eau : le seul jeu disponible décrit l'eau du robinet
  après traitement, et l'afficher sur une fiche de rivière serait lu comme une autorisation de
  baignade.
- Aucune de ses données ne reflète les **lâchers ou manœuvres de barrages**.

Un avertissement explicite apparaît à **quatre endroits** : au premier lancement avec acquittement
obligatoire, en bandeau permanent sur la carte, sur chaque fiche avec la date de la mesure, et
renforcé sur tout écran de sécheresse. Ce ne sont pas des finitions —
[`BR-012`](docs/br/BR-012-acquittement-au-premier-lancement.md) et
[`BR-013`](docs/br/BR-013-avertissement-renforce-sur-ecrans-ressource.md) en font une condition de
mise en production.

## Démarrage rapide

```bash
npm install && npm run verify
```

C'est tout ce qu'il faut pour travailler sur les couches `domain/`, `data/` et `application/` —
elles sont du TypeScript pur testé sous Node, sans émulateur ni téléphone.

Pour **voir l'application à l'écran**, il faut en plus Android Studio et un JDK 17 :
👉 **[Guide d'installation](docs/guide-installation.md)**.

> ⚠️ Ce guide contient un piège qui coûte une nuit entière : **le SDK Android doit être installé sur
> un chemin sans espace ni parenthèse.** Le NDK ne les supporte pas, et le message d'erreur ne
> désigne jamais la cause.

## Commandes

| Commande | Rôle |
|---|---|
| **`npm run verify`** | **Typecheck + lint + tests.** Le critère de fin d'étape du projet |
| `npm run typecheck` | `tsc --noEmit` — TypeScript `strict`, sans concession |
| `npm test` | Tests unitaires (Jest, environnement Node) |
| `npm run lint` | ESLint, dont les règles de frontière entre couches |
| `npm start` | Serveur de développement Metro |
| `npm run android` | Compile et lance sur appareil ou émulateur Android |
| `npm run ios` | Idem sur iOS — **macOS requis** |

Aucune tâche n'est considérée terminée si `npm run verify` ne passe pas.

## Architecture

**Clean Architecture en couches + CQRS léger** — `Query`/`Command` typés avec handlers, et une
politique de cache portée par un **décorateur unique**. Pas d'event sourcing, pas de bibliothèque
de médiateur, et **pas de backend** : l'application appelle directement les APIs publiques.

```
src/
├── domain/        entités et règles — TypeScript pur, ZÉRO import de framework
├── data/          dépôts, clients HTTP, mappers
├── application/   Query/Command + le décorateur de cache, unique
└── features/      écrans React
tests/             calque src/, plus tests/architecture/
tools/             scripts hors application (asset de percentiles)
docs/              spécification, ADR, règles métier, plans
```

Deux invariants ne sont **pas** des conventions de revue : `domain/` ne dépend de rien — vérifié par
un test d'architecture **et** par ESLint — et un écran n'appelle jamais un dépôt. Les unités sont
des types *branded*, pas des `number` : confondre des l/s avec des m³/s est le bug le plus coûteux
du projet ([`BR-002`](docs/br/BR-002-debit-en-metres-cubes-par-seconde.md)).

Détail : [`docs/03-conception.md`](docs/03-conception.md) ·
[`ADR-010`](docs/adr/ADR-010-react-native.md).

### Stack

**React Native** + **TypeScript** (`strict`), empaqueté par **Expo** · carte
**`@maplibre/maplibre-react-native`** (MapLibre Native, rendu GPU) sur fond **IGN Géoplateforme** ·
SQLite · Android et iOS.

> 🚨 **Bascule du 2026-07-31** — le projet était en .NET MAUI Blazor Hybrid et ciblait aussi
> Windows. Le commanditaire a révisé son arbitrage :
> [`ADR-010`](docs/adr/ADR-010-react-native.md) remplace `ADR-005`, `ADR-008` et `ADR-009`. Le code
> .NET a été retiré du dépôt le même jour ; il reste dans l'historique git (`696be3a`, `22e9850`).

## Contribuer

- **Code en anglais, domaine et documentation en français.**
- **Conventional Commits**, scopes : `domain`, `data`, `ui`, `map`, `hydrometrie`, `ecoulement`,
  `restrictions`, `avertissement`, `docs`, `ci`.
- **TDD** : test rouge avant l'implémentation, sans exception.
- **Tout fait relatif à une API publique se vérifie par appel réel, et se date.** La documentation
  Hub'Eau est en écart avec la production sur au moins quatre points — on ne spécifie jamais
  d'après elle seule.
- **Ne jamais inventer un seuil hydrologique.** C'est la faute la plus grave possible sur ce
  produit.

Règles complètes : [`CLAUDE.md`](CLAUDE.md) · Conventions de documentation :
[`docs/README.md`](docs/README.md).

## Licences

### Le code — MIT

Distribué sous [licence MIT](LICENSE.txt) : réutilisation libre, y compris commerciale et en source
fermée, sous réserve de conserver la notice de copyright.

### Les données — Licence Ouverte, attribution obligatoire

**La licence MIT du code ne couvre pas les données.** Les jeux consommés, et l'asset dérivé
redistribué dans ce dépôt, restent sous leur propre licence.

| Source | Licence | Obligation |
|---|---|---|
| **Hub'Eau** — Office français de la biodiversité · [hubeau.eaufrance.fr](https://hubeau.eaufrance.fr/page/apis) | Licence Ouverte Etalab — version non précisée sur les CGU *(non vérifié)* | Citation de la source et de la date de mise à jour |
| **VigiEau** — Ministère de la Transition écologique · [vigieau.gouv.fr](https://vigieau.gouv.fr) | Licence Ouverte 2.0 | idem |
| **IGN Géoplateforme** — fond de carte WMTS | Licence Ouverte | idem |
| **OpenStreetMap** — fond de carte en repli | **ODbL** | Attribution + *share-alike* sur toute base dérivée |

La **Licence Ouverte 2.0** n'impose **aucun partage à l'identique** : elle autorise explicitement de
créer des « Informations dérivées » et de les exploiter à titre commercial, contre la seule mention
de la paternité et de la date de dernière mise à jour. Elle se déclare compatible avec OGL, CC-BY et
ODC-BY. *Vérifié le 2026-07-30 sur
[etalab/licence-ouverte](https://raw.githubusercontent.com/etalab/licence-ouverte/master/LO.md).*

**Conséquence** : l'asset de percentiles généré au build
([`ADR-003`](docs/adr/ADR-003-reference-percentiles-en-asset.md)) est une œuvre dérivée de
l'historique Hub'Eau. Il **peut** être diffusé dans un dépôt MIT, mais l'obligation d'attribution le
suit et n'est pas éteinte par le `LICENSE.txt`.

**Sur l'ODbL** : l'application met en cache des **tuiles** (*Produced Work*), pas de la donnée OSM —
le code n'est donc pas contaminé. Cela changerait si des géométries OSM étaient extraites et
stockées en base (*Derivative Database*). ⚠️ Lecture **non confirmée** par relecture du texte ODbL —
à vérifier si OSM devient un repli réellement servi en production.

### Les dépendances

Aucune dépendance sous licence copyleft. BSD-3-Clause et Apache-2.0 ne sont **pas** relicenciées en
MIT : leurs notices doivent être conservées et présentées dans l'écran « À propos ».

| Dépendance | Licence |
|---|---|
| React Native · Expo | MIT |
| `@maplibre/maplibre-react-native` | *à confirmer* |
| MapLibre Native | BSD-3-Clause |
| SQLite (`expo-sqlite` ou `op-sqlite`) | *à confirmer* |

⚠️ **Ce tableau est à refaire intégralement à la source, et à dater.** Il descend de la liste des
dépendances .NET, devenues caduques avec [`ADR-010`](docs/adr/ADR-010-react-native.md).

### Disponibilité

Les services publics consommés sont mis à disposition **sans garantie de disponibilité ni de
performance**, et sans quota chiffré. L'application prévoit un mode dégradé et un throttle client en
conséquence.

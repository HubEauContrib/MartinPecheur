# MartinPêcheur

> L'état de votre rivière, sans promesse qu'on ne peut pas tenir.

**MartinPêcheur** est une application mobile qui informe les usagers d'une rivière française sur son état — **écoulement**, **débit**, **sécheresse** — à partir des données publiques ouvertes **Hub'Eau** (Office français de la biodiversité) et **VigiEau** (Ministère de la Transition écologique).

Elle s'adresse aux riverains, aux agriculteurs et irrigants, aux pêcheurs, aux usagers de loisir et aux collectivités.

> *Le martin-pêcheur ne pêche que dans une eau claire et vive. Sa présence dit l'état de la rivière — c'est un indicateur, pas une garantie.*

## Statut

🚧 **Cadrage terminé, implémentation non commencée.** La solution est vide.
Documentation complète : [`docs/README.md`](docs/README.md) · État vivant : [`docs/project-state.md`](docs/project-state.md).

## Ce que l'application fait

- **Une carte** — stations hydrométriques et points d'observation ONDE, colorés par état, avec clustering et filtres.
- **Le débit**, en m³/s, avec sa date, son statut de qualification et sa courbe d'évolution.
- **L'écoulement observé** — l'eau coule-t-elle encore, ou le lit est-il à sec ?
- **Les restrictions sécheresse** de votre zone, par profil d'usager, avec l'arrêté préfectoral.
- **Le hors-ligne** — la dernière carte consultée reste disponible sans réseau.

## Ce qu'elle ne fait pas, et le dit

Le produit repose sur un principe simple : **ne jamais laisser croire à ce qu'il ne sait pas.**

- Il ne répond **jamais** à « le débit est-il suffisant ? ». Aucune API publique n'expose de seuil réglementaire par station — le vérifier a fait partie du cadrage. Le produit situe un débit par rapport à l'historique de sa propre station, et nomme cela pour ce que c'est : une statistique.
- Il ne remplace **ni** un arrêté préfectoral, **ni** une décision d'irrigation, **ni** une évaluation de sécurité avant de se baigner, naviguer ou traverser.
- Il n'affiche **aucune** donnée de qualité de l'eau : le seul jeu disponible décrit l'eau du robinet après traitement, et l'afficher sur une fiche de rivière serait lu comme une autorisation de baignade.
- Aucune de ses données ne reflète les **lâchers ou manœuvres de barrages**.

Un avertissement explicite apparaît à **quatre endroits** : au premier lancement avec acquittement obligatoire, en bandeau permanent sur la carte, sur chaque fiche avec la date de la mesure, et renforcé sur tout écran de sécheresse.

## Périmètre v1

Pas de backend · pas de compte utilisateur · pas de notifications · pas de prévision hydrologique.

## Stack

**React Native** + **TypeScript** (`strict`), empaqueté par **Expo** · carte **`@maplibre/maplibre-react-native`** (MapLibre Native) sur fond **IGN Géoplateforme** · SQLite · Android et iOS.
**Clean Architecture en couches + CQRS léger** — `Query`/`Command` typés avec handlers et une politique de cache portée par un décorateur unique. Pas d'event sourcing : l'application ne produit aucun événement de domaine.

> 🚨 **Bascule du 2026-07-31** : le projet était en .NET MAUI Blazor Hybrid et ciblait aussi Windows.
> Le commanditaire a révisé son arbitrage — voir [`docs/adr/ADR-010-react-native.md`](docs/adr/ADR-010-react-native.md),
> qui remplace `ADR-005`, `ADR-008` et `ADR-009`. Le code .NET a été **retiré du dépôt** le même
> jour ; il reste consultable dans l'historique git (`696be3a`, `22e9850`).

## Licences

### Le code — MIT

Ce dépôt est distribué sous [licence MIT](LICENSE.txt) : réutilisation libre, y compris commerciale et en source fermée, sous réserve de conserver la notice de copyright.

### Les données — Licence Ouverte, attribution obligatoire

**La licence MIT du code ne couvre pas les données.** Les jeux consommés, et l'asset dérivé redistribué dans ce dépôt, restent sous leur propre licence.

| Source | Licence | Obligation |
|---|---|---|
| **Hub'Eau** — Office français de la biodiversité · [hubeau.eaufrance.fr](https://hubeau.eaufrance.fr/page/apis) | Licence Ouverte Etalab — version non précisée sur les CGU (*non vérifié*) | Citation de la source et de la date de mise à jour |
| **VigiEau** — Ministère de la Transition écologique · [vigieau.gouv.fr](https://vigieau.gouv.fr) | Licence Ouverte 2.0 | idem |
| **IGN Géoplateforme** — fond de carte WMTS | Licence Ouverte | idem |
| **OpenStreetMap** — fond de carte en repli | **ODbL** | Attribution + *share-alike* sur toute base dérivée |

La **Licence Ouverte 2.0** n'impose **aucun partage à l'identique** : elle autorise explicitement de « créer des "Informations dérivées" » et de « l'exploiter à titre commercial », contre la seule mention de la paternité — « sa source (a minima le nom du « Concédant ») et la date de la dernière mise à jour ». Elle se déclare compatible avec OGL (Royaume-Uni), CC-BY et ODC-BY.
*Vérifié le 2026-07-30 sur [etalab/licence-ouverte](https://raw.githubusercontent.com/etalab/licence-ouverte/master/LO.md).*

**Conséquence pour ce dépôt** : l'asset de percentiles généré au build ([`ADR-003`](docs/adr/ADR-003-reference-percentiles-en-asset.md)) est une œuvre dérivée de l'historique Hub'Eau. Il **peut** être diffusé dans un dépôt MIT — mais l'obligation d'attribution le suit, et n'est pas éteinte par le `LICENSE.txt`.

**Sur l'ODbL** : l'application met en cache des **tuiles** (*Produced Work*), pas de la donnée OSM. Le code n'est donc pas contaminé. Cela changerait si des géométries OSM étaient un jour extraites et stockées en base (*Derivative Database*).
⚠️ Cette lecture n'a **pas** été confirmée par relecture du texte ODbL — à vérifier si OSM devient un repli réellement servi en production.

### Les dépendances — toutes permissives

Aucune dépendance sous licence copyleft. BSD-3-Clause et Apache-2.0 ne sont **pas** relicenciées en MIT : leurs notices doivent être conservées et présentées dans l'écran « À propos ».

| Dépendance | Licence |
|---|---|
| React Native | MIT |
| Expo | MIT |
| `@maplibre/maplibre-react-native` | à confirmer |
| MapLibre Native | BSD-3-Clause |
| SQLite (`expo-sqlite` ou `op-sqlite`) | à confirmer |

⚠️ **Ce tableau est à refaire intégralement.** Il listait les dépendances .NET, devenues caduques
avec [`ADR-010`](docs/adr/ADR-010-react-native.md). **Aucune ligne ci-dessus n'a été vérifiée à la
source** — à faire à l'ajout effectif de chaque paquet, et à dater.

### Disponibilité

Les services publics consommés sont mis à disposition **sans garantie de disponibilité ni de performance**, et sans quota chiffré (`C-15`). L'application prévoit un mode dégradé en conséquence.

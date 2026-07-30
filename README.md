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

.NET 10 · **MAUI** (iOS + Android) · MAUI Blazor Hybrid + **MapLibre GL JS** sur fond **IGN Géoplateforme** · CommunityToolkit.Mvvm · BrilliantMediator · `IHttpClientFactory` + Polly · `sqlite-net-pcl` · xUnit.
**Clean Architecture en couches + MVVM + CQRS léger** — `IQuery`/`ICommand` avec handlers et une politique de cache en pipeline. Pas d'event sourcing : l'application ne produit aucun événement de domaine.

> Le choix d'UI est en statut **`Proposé`**, conditionné à un spike de validation :
> [`docs/adr/ADR-005-stack-maui-blazor-hybrid.md`](docs/adr/ADR-005-stack-maui-blazor-hybrid.md).

## Données et licences

- **Hub'Eau** — Licence Ouverte Etalab · [hubeau.eaufrance.fr](https://hubeau.eaufrance.fr/page/apis)
- **VigiEau** — Licence Ouverte 2.0 · [vigieau.gouv.fr](https://vigieau.gouv.fr)
- **IGN Géoplateforme** — Licence Ouverte · OpenStreetMap en repli (ODbL)

Ces services sont mis à disposition **sans garantie de disponibilité ni de performance**. L'application prévoit un mode dégradé en conséquence.

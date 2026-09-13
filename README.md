<div align="center">

# MartinPêcheur

**L'état de votre rivière, sans promesse qu'on ne peut pas tenir.**

Application **Android, iOS et Windows** qui informe les usagers d'une rivière française sur son
état — **écoulement**, **débit**, **sécheresse** — à partir des données publiques ouvertes
**Hub'Eau** et **VigiEau**.

[![Licence](https://img.shields.io/badge/licence-GPL--3.0-blue.svg)](LICENSE.txt)
[![Flutter](https://img.shields.io/badge/Flutter-3.47%20stable-02569B.svg?logo=flutter)](docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2.svg?logo=dart)](docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md)
[![Plateformes](https://img.shields.io/badge/plateformes-Android%20%7C%20iOS%20%7C%20Windows-3ddc84.svg)](docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md)
[![Données](https://img.shields.io/badge/donn%C3%A9es-Hub'Eau%20%C2%B7%20VigiEau%20%C2%B7%20IGN-0b6e4f.svg)](docs/01-analyse.md)

[Documentation](docs/README.md) · [État du projet](docs/project-state.md) ·
[Installation](docs/guide-installation.md) · [Décisions](docs/README.md#index-des-décisions)

</div>

---

> *Le martin-pêcheur ne pêche que dans une eau claire et vive. Sa présence dit l'état de la
> rivière — c'est un indicateur, pas une garantie.*

## Sommaire

- [Le produit](#le-produit) · [Ce qu'il refuse de faire](#ce-quil-refuse-de-faire)
- [Où en est le projet](#où-en-est-le-projet) · [Démarrage rapide](#démarrage-rapide) · [Commandes](#commandes)
- [Architecture](#architecture) · [Contribuer](#contribuer) · [Remerciements](#remerciements) ·
  [Licences](#licences)

## Le produit

MartinPêcheur s'adresse aux riverains, aux agriculteurs et irrigants, aux pêcheurs, aux usagers de
loisir et aux collectivités — sur leur téléphone comme sur leur PC.

| | |
|---|---|
| 🗺️ **Une carte** | Stations hydrométriques et points d'observation ONDE, colorés par état, avec clustering et filtres |
| 💧 **Le débit** | En m³/s, avec sa date, son statut de qualification et sa courbe d'évolution |
| 🏞️ **L'écoulement observé** | L'eau coule-t-elle encore, ou le lit est-il à sec ? |
| ⚠️ **Les restrictions sécheresse** | Celles de votre zone, par profil d'usager, avec l'arrêté préfectoral |
| 📶 **Sans réseau** | La dernière réponse connue reste affichée, **avec sa date et un bandeau** — jamais comme si elle était fraîche. Les tuiles de carte déjà parcourues restent visibles |

**Périmètre v1** — pas de backend · pas de compte utilisateur · pas de notifications · pas de
prévision hydrologique · **pas de pré-téléchargement de zone cartographique** (retiré le 2026-08-24,
[`ADR-012`](docs/adr/ADR-012-hors-ligne-cartographique-bloque.md) option C).

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

## Où en est le projet

> Légende : ✅ fait et vérifié · 🔄 décidé, pas encore codé · 💭 spéculatif. La source de vérité des
> statuts est [`docs/project-state.md`](docs/project-state.md).

| | État |
|---|---|
| **Cadrage produit** — analyse, spécifications, 14 règles métier, 6 cas d'usage, 17 contraintes d'API vérifiées par appel réel | ✅ terminé, indépendant de la stack |
| **Référentiel des stations** — 4 150 stations Hub'Eau figées dans [`assets/referentiel/stations.json`](assets/referentiel/stations.json) | ✅ |
| **Stack** — **Flutter**, trois cibles | ✅ décidée le 2026-08-24, porte franchie le 2026-09-12 · 🔄 `ADR-013` à écrire |
| **Porte de spike `F1`–`F3`** — fond IGN, exécutable Windows, clustering | ✅ franchie le 2026-09-12 sur Windows (`F1`, `F3`) · `F2` non tranchée · Android ⏸ — [compte rendu](spike/porte_flutter/COMPTE-RENDU.md) |
| **Socle applicatif Dart** (`lib/`) | 🔄 T0 à venir, Windows d'abord |
| **Cibles** | Windows construite · Android ⏸ différé (2026-09-12) · iOS configuré, non compilé |

## Démarrage rapide

Il faut le SDK Flutter `3.47` stable, et — pour Windows — Visual Studio avec le workload *Desktop
development with C++* : 👉 **[Guide d'installation](docs/guide-installation.md)**.

```bash
flutter doctor -v
```

> Sur le poste de référence, si `flutter` n'est pas dans le `PATH`, l'appeler par son chemin absolu.

> ⚠️ Trois pièges rencontrés sur ce poste : le SDK Android et le SDK Flutter doivent vivre sur un
> **chemin sans espace ni parenthèse** ; `winget` n'installe pas les `cmdline-tools` Android ;
> cocher MSVC seul dans Visual Studio ne suffit pas, il faut le **workload** entier, sinon CMake et
> le SDK Windows manquent. Android Studio et les `cmdline-tools` ne sont nécessaires que pour la
> cible Android, différée.

## Commandes

| Commande | Rôle | État |
|---|---|---|
| `flutter analyze` · `flutter test` | Analyse statique Dart et tests du socle, test d'architecture en premier | 🔄 avec `lib/` |
| `flutter run -d windows` | Lancer l'application | 🔄 |
| `flutter build windows --release` | Livrable Windows | ✅ éprouvé par le spike (`F3`) |
| `flutter build apk` | Livrable Android | ⏸ Android différé |

Aucune tâche n'est considérée terminée si la chaîne de vérification ne passe pas.

## Architecture

**Clean Architecture en couches + CQRS léger** — `Query`/`Command` typés avec handlers, et une
politique de cache portée par un **décorateur unique**. Pas d'event sourcing, pas de bibliothèque
de médiateur, et **pas de backend** : l'application appelle directement les APIs publiques.

Disposition cible du dépôt (🔄) :

```
lib/
├── domain/        entités et règles — Dart pur, ZÉRO import de flutter, latlong2, http, dart:io
├── data/          Hub'Eau, VigiEau (derrière RestrictionSource), stockage local, mappers
├── application/   Query/Command scellés + registre + le décorateur de cache, unique
└── features/map/  flutter_map, fond IGN, marqueurs du viewport
test/              calque lib/, plus test/architecture/ — écrit avant la première ligne de domain/
android/ ios/ windows/   projets natifs, versionnés
assets/            référentiel des stations, asset de percentiles, généré par un script Dart (🔄)
docs/              spécification, ADR, règles métier, plans
```

Trois invariants ne sont **pas** des conventions de revue, et Dart en renforce deux :

- **`domain/` ne dépend de rien** — vérifié par un test d'architecture qui lit les imports.
- **Les unités sont typées** — `extension type` distinct au compilateur pour les l/s, m³/s, mm et m.
  Confondre des l/s avec des m³/s est le bug le plus coûteux du projet
  ([`BR-002`](docs/br/BR-002-debit-en-metres-cubes-par-seconde.md)).
- **Toute nomenclature est close, avec une branche `Inconnu`** — `sealed class` et `switch`
  exhaustif : oublier une branche est une erreur de compilation
  ([`BR-011`](docs/br/BR-011-nomenclature-tolerante-a-l-inconnu.md)).

Détail : [`docs/03-conception.md`](docs/03-conception.md) ·
[design de la bascule](docs/superpowers/specs/2026-08-24-bascule-flutter-trois-cibles-design.md).

### Stack

| Composant | Choix | État |
|---|---|---|
| Langage, runtime | **Dart 3.13** · **Flutter 3.47** stable | ✅ installés, `flutter doctor` vert sur Windows |
| Cibles | **Android**, **iOS**, **Windows** | Windows ✅ construite · Android ⏸ différé (2026-09-12) · iOS 🔄 configuré, non compilé |
| Carte | **`flutter_map`** 8.x, rendu Dart natif, fond **IGN Géoplateforme** (WMTS `PLANIGNV2`) | ✅ `F1` franchie sur Windows |
| Clustering | `flutter_map_marker_cluster` 8.2.x | ⏸ `F2` non tranchée — par défaut, marqueurs du viewport sans clustering |
| Stockage local | `drift` candidat — `sqflite` seul ne couvre pas Windows | 💭 `ADR-011` réservé |
| Gestion d'état | `ValueNotifier` + `ListenableBuilder`, zéro dépendance, sauf preuve contraire | 💭 tranché au premier écran |

## Contribuer

- **Code en anglais, domaine et documentation en français.**
- **Conventional Commits**, scopes : `domain`, `data`, `ui`, `map`, `hydrometrie`, `ecoulement`,
  `restrictions`, `avertissement`, `docs`, `ci`.
- **TDD** : test rouge avant l'implémentation, sans exception.
- **Lire avant d'écrire.** Toute signature de paquet se lit sur `pub.dev/documentation` et se date.
- **Tout fait relatif à une API publique se vérifie par appel réel, et se date.** La documentation
  Hub'Eau est en écart avec la production sur au moins quatre points — on ne spécifie jamais
  d'après elle seule.
- **Ne jamais inventer un seuil hydrologique.** C'est la faute la plus grave possible sur ce
  produit.

Règles complètes : [`CLAUDE.md`](CLAUDE.md) · Conventions de documentation :
[`docs/README.md`](docs/README.md).

## Remerciements

Rien de ce que montre MartinPêcheur n'est produit par lui. Merci aux équipes qui conçoivent et
font vivre **Hub'Eau** — l'Office français de la biodiversité, avec le BRGM et les partenaires
du système d'information sur l'eau — pour des APIs publiques, ouvertes, accessibles sans clé ni
quota annoncé, sur lesquelles cette application repose entièrement.

Merci aux **hydromètres** des services de l'État et de leurs partenaires, qui entretiennent les
stations, jaugent les cours d'eau et valident les mesures : chaque débit affiché ici est le
résultat de leur travail sur le terrain, souvent par crue ou par étiage, rarement par beau temps.

Merci aux **observateurs de l'ONDE**, le réseau animé par l'OFB, qui chaque été vont regarder à
pied si l'eau coule encore sur leur tronçon — une observation visuelle, humaine, que rien ne
remplace.

Merci à l'**IGN** pour le fond de carte de la Géoplateforme, mis à disposition sous Licence
Ouverte, et aux équipes de **VigiEau** pour les données de restriction et les arrêtés qu'elles
publient.

Merci enfin aux mainteneurs des bibliothèques libres sur lesquelles ce projet s'appuie, à
commencer par Flutter et `flutter_map`.

MartinPêcheur ne fait que rendre lisible ce que ces personnes mesurent, observent et publient —
aucune de ces données ne lui appartient.

## Licences

### Le code — GPL-3.0-or-later

Distribué sous [licence GPL-3.0-or-later](LICENSE.txt) : réutilisation libre, y compris
commerciale, sous réserve de redistribuer les sources et les modifications sous la même licence.
Aucune fermeture possible.

### Les données — Licence Ouverte, attribution obligatoire

**La licence GPL-3.0 du code ne couvre pas les données.** Les jeux consommés, et l'asset dérivé
redistribué dans ce dépôt, restent sous leur propre licence.

| Source | Licence | Obligation |
|---|---|---|
| **Hub'Eau** — Office français de la biodiversité · [hubeau.eaufrance.fr](https://hubeau.eaufrance.fr/page/apis) | Licence Ouverte Etalab — version non précisée sur les CGU *(non vérifié)* | Citation de la source et de la date de mise à jour |
| **VigiEau** — Ministère de la Transition écologique · [vigieau.gouv.fr](https://vigieau.gouv.fr) | Licence Ouverte 2.0 | idem |
| **IGN Géoplateforme** — fond de carte WMTS | Licence Ouverte | **« © IGN Géoplateforme — Licence Ouverte » reste affiché sur la carte** |
| **OpenStreetMap** — fond de carte en repli | **ODbL** | Attribution + *share-alike* sur toute base dérivée |

La **Licence Ouverte 2.0** n'impose **aucun partage à l'identique** : elle autorise explicitement de
créer des « Informations dérivées » et de les exploiter à titre commercial, contre la seule mention
de la paternité et de la date de dernière mise à jour. Elle se déclare compatible avec OGL, CC-BY et
ODC-BY. *Vérifié le 2026-07-30 sur
[etalab/licence-ouverte](https://raw.githubusercontent.com/etalab/licence-ouverte/master/LO.md).*

**Conséquence** : l'asset de percentiles généré au build
([`ADR-003`](docs/adr/ADR-003-reference-percentiles-en-asset.md)) est une œuvre dérivée de
l'historique Hub'Eau. Il **peut** être diffusé dans un dépôt GPL-3.0, mais l'obligation
d'attribution le suit et n'est pas éteinte par le `LICENSE.txt`.

**Sur l'ODbL** : l'application met en cache des **tuiles** (*Produced Work*), pas de la donnée OSM —
le code n'est donc pas contaminé. Cela changerait si des géométries OSM étaient extraites et
stockées en base (*Derivative Database*). ⚠️ Lecture **non confirmée** par relecture du texte ODbL —
à vérifier si OSM devient un repli réellement servi en production.

### Les dépendances

BSD-3-Clause et Apache-2.0 restent compatibles avec la GPL-3.0 : leurs notices doivent être
conservées et présentées dans l'écran « À propos ».

| Dépendance | Version | Licence | Vérifié |
|---|---|---|---|
| Flutter SDK | 3.47.4 | BSD-3-Clause | `flutter --version`, 2026-09-13 |
| `flutter_map` | 8.3.2 | BSD-3-Clause | pub.dev, 2026-09-09 |
| `latlong2` | 0.10.1 | Apache-2.0 | pub.dev, 2026-09-09 |
| `flutter_map_marker_cluster` | 8.2.2 | BSD-3-Clause | pub.dev, 2026-09-09 |
| `drift` *(candidat, non retenu)* | 2.34.x | MIT | pub.dev, 2026-08-24 |

La bibliothèque `flutter_map_tile_caching` est en **GPL-3.0** : elle est désormais compatible avec
ce dépôt, mais la question est sans objet — le pré-téléchargement cartographique a été retiré.

### Disponibilité

Les services publics consommés sont mis à disposition **sans garantie de disponibilité ni de
performance**, et sans quota chiffré. L'application prévoit un mode dégradé et un throttle client en
conséquence.

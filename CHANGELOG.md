# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et ce
projet adhère au [Versionnage Sémantique](https://semver.org/lang/fr/).

Chaque ligne décrit un changement visible **pour un usager ou un
intégrateur** — jamais un détail interne. Un remaniement sans effet
observable n'y figure pas.

## [Non publié]

## [0.1.0] — 2026-09-13

Première tranche technique, **rien de tout cela n'est un produit** : aucun
des quatre avertissements obligatoires n'est encore posé (`BR-012`,
`BR-013`), et `CLAUDE.md` interdit toute mise en production tant qu'ils
manquent.

### Ajouté

- Cible Windows construite et lancée hors Flutter ; cible iOS déclarée,
  jamais compilée (aucun hôte macOS).
- Écran carte, fond IGN Géoplateforme en tuiles raster, attribution
  « © IGN Géoplateforme — Licence Ouverte » affichée.
- 4 150 stations en marqueurs, limités à l'emprise visible de la carte plus
  une marge.
- Socle de domaine : unités typées (m³/s, m), fraîcheur des données
  (`BR-005`), nomenclature d'écoulement tolérante à l'inconnu (`BR-011`),
  code station à dix caractères.
- Socle de données : client hydrométrie v2 avec nouvelle tentative à gigue,
  réponses `200` et `206` traitées comme des succès, conversion d'unités en
  un seul point.
- Politique de cache unique, partagée par tous les dépôts.
- Documentation de spécification : fiches de sources datées, modèle de
  domaine, exigences non fonctionnelles, plan de tests.

### Modifié

- Licence du code : MIT → GPL-3.0-or-later (2026-09-13). Les données
  restent sous Licence Ouverte.

### Différé

- Android en entier (arbitrage du 2026-09-12) : aucune plateforme générée,
  aucune signature, aucune publication.
- Stockage local, `ADR-011` réservé.
- Volet sécheresse : `RestrictionSource` n'est encore qu'une interface
  (prévu en T2).

### Constaté à l'exécution

- Exécutable Windows (`flutter build windows --release`) produit et lancé **sans
  outil de développement** par le commanditaire le 2026-09-13 : la carte IGN
  s'affiche, les 4 150 pastilles sont là, l'attribution est lisible, le glisser
  déplace la carte, la molette zoome.
- Dossier de publication : **31 Mo** (budget 60 Mo), dont `flutter_windows.dll`
  21 Mo et le référentiel 6,4 Mo.
- Hors réseau, carte réseau désactivée : la carte s'ouvre, les pastilles et le
  fond de carte s'affichent depuis le cache de tuiles sur les zones déjà
  parcourues, aucun message d'erreur. Une zone jamais chargée n'a pas été
  constatée.

### Non vérifié

- Aucune mesure chiffrée de fluidité sur Windows (`NFR-01`).
- Une zone de carte jamais chargée, hors réseau.
- iOS n'a jamais été compilé, faute d'hôte.
- Android ⏸ différé le 2026-09-12.

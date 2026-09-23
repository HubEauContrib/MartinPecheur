// Les bornes de zoom de la carte — Dart pur, aucun `package:flutter`, aucun
// `package:flutter_map`. **Extrait** de `map_view_model.dart` et de
// `ign_tile_template.dart` par la relecture du coordinateur du 2026-09-23
// (`K1`) : `MapViewModel` doit décider si `+`/`−` restent actifs
// (`canZoomIn`/`canZoomOut`) sans importer un fichier du dossier de la VUE
// carte — même un fichier Dart pur, la règle voulait un dossier, pas
// seulement une absence de widget. `ign_tile_template.dart`
// garde tout ce qui touche au gabarit de tuiles proprement dit (URL, taille,
// attribution, agent) ; ce fichier-ci porte tout ce qui touche au ZOOM, y
// compris [ignMaxNativeZoom] — qui n'est donc plus dans
// `ign_tile_template.dart`, pour cette raison précise. UNE seule source de
// vérité pour chacune des trois constantes, jamais un ré-export.

/// Niveau de zoom natif maximal du plan IGN ; au-delà, la couche agrandit le
/// niveau 18 plutôt que d'interroger un niveau inexistant.
///
/// Vérifié le 2026-09-13 par appel réel sur Paris (lat 48.85, lon 2.35,
/// Pseudo-Mercator) : `z18` (`TILECOL=132783&TILEROW=90192`) → HTTP 200,
/// `image/png`, 34 147 octets ; `z19` (`TILECOL=265566&TILEROW=180384`) →
/// HTTP 200, `image/png`, 32 250 octets. **Le niveau 19 existe aussi** côté
/// serveur : `18` reste un choix de charge (moins de tuiles demandées), pas
/// une limite constatée du service — à revoir en T1 si le rendu au zoom rue
/// justifie d'aller plus loin.
const int ignMaxNativeZoom = 18;

/// Zoom minimal de la carte — en dessous, la France n'emplit plus l'écran.
/// Lu par `MapOptions.minZoom` (`map_view.dart`, la SEULE consommatrice côté
/// caméra) et par `MapViewModel.canZoomOut` (`K1`) : les bornes de zoom
/// restent celles de `MapOptions`, cette constante n'en crée pas une
/// seconde, elle change seulement d'adresse.
const double minimumMapZoom = 4;

/// Zoom maximal de la carte — aligné sur [ignMaxNativeZoom] : au-delà, le
/// serveur n'a rien à offrir de plus fin. Même remarque que
/// [minimumMapZoom] pour `MapOptions.maxZoom` et `MapViewModel.canZoomIn`.
const double maximumMapZoom = ignMaxNativeZoom * 1.0;

// Les boutons `+`, `−` et de recentrage (`K1`, 2026-09-23) : la molette
// zoome déjà sur Windows (`NV-W1`, constaté le 2026-09-13), mais rien ne sert
// qui n'a pas de molette — un pavé tactile, un lecteur d'écran, un clavier
// sans raccourci (`K2` les ajoute ensuite). Ces boutons ne remplacent donc
// pas la molette, ils la complètent.
//
// Ce widget est un widget de CONTENU pur, comme le sélecteur de lecture et
// [IgnAttributionBadge] : il ne pilote aucune caméra `flutter_map` et ne
// connaît pas `MapViewModel`. C'est `_MapViewState`
// (`lib/features/map/view/map_view.dart`) qui construit les trois rappels —
// avec, pour `+`/`−`, `null` quand `MapViewModel.canZoomIn`/`canZoomOut` le
// disent — et qui, après un déplacement de caméra réussi, signale le geste
// terminé au ViewModel par [MapViewModel.onGestureEnded]
// (`_MapViewState._afterCameraMove`), exactement comme le fait déjà la
// sélection d'une pastille de zone (`_handleClusterSelect`, `Z4`) : AUCUN
// enchaînement n'est recopié ici, la vue réutilise le même mécanisme pour
// les deux origines de geste.
//
// Un bouton `onTap` nul se rend **désactivé** — pas de ripple, pas
// d'annonce activable — plutôt que de disparaître : un contrôle qui
// s'efface change la disposition des deux autres à chaque geste, ce
// qu'aucune spécification ne demande.
//
// Le groupe se pose en colonne (défaut) ou en rangée ([MapControls.axis],
// `S4` d'Ergonomie : le bas de la carte au téléphone). Il ne compte qu'une
// hauteur intrinsèque, que la mise en page de la carte (`D1`) interroge.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view/map_round_button.dart';

/// Le nombre de crans de zoom qu'un tap sur `+` ou `−` applique. `1,0` :
/// aligné sur le pas d'un cran de molette (`MapEventScrollWheelZoom`,
/// `map_view.dart`), pour que bouton et molette avancent d'un même cran.
const double zoomStep = 1.0;

/// Espacement entre deux boutons, en pixels logiques : ≥ 8 dp (`04-ui.md`
/// § 3), comme entre deux entrées du sélecteur de lecture.
const double mapControlsSpacing = 8;

/// Clé du bouton `+`.
const Key mapZoomInButtonKey = Key('map-zoom-in');

/// Clé du bouton `−`.
const Key mapZoomOutButtonKey = Key('map-zoom-out');

/// Clé du bouton de recentrage.
const Key mapRecenterButtonKey = Key('map-recenter');

/// Les boutons de pilotage de la caméra à la souris/au tactile : `+`, `−` et
/// recentrage — chacun une cible tactile ≥ 44 × 44 pt, espacés d'au moins
/// 8 dp (`04-ui.md` § 3). Le bouton « Restrictions au centre de la carte » en
/// est sorti le 2026-09-29 (`designate_center_button.dart`).
///
/// En colonne ([Axis.vertical], le défaut) : `+`, `−`, recentrage, de haut en
/// bas. En rangée ([Axis.horizontal], le bas de la carte au téléphone, `S4`
/// d'Ergonomie) : `−`, `+`, recentrage, de gauche à droite — l'ordre de
/// l'écran, que la tabulation suit. Dans les deux cas, [mapControlsSpacing]
/// sépare deux boutons.
class MapControls extends StatelessWidget {
  const MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    this.axis = Axis.vertical,
    super.key,
  });

  /// Le sens du groupe : une colonne (défaut) ou une rangée.
  final Axis axis;

  /// Appelé par un tap sur `+`. `null` quand `MapViewModel.canZoomIn` est
  /// faux (zoom déjà maximal) : le bouton se rend alors désactivé plutôt que
  /// d'appeler un zoom sans effet.
  final VoidCallback? onZoomIn;

  /// Appelé par un tap sur `−`. `null` quand `MapViewModel.canZoomOut` est
  /// faux (zoom déjà minimal).
  final VoidCallback? onZoomOut;

  /// Appelé par un tap sur le bouton de recentrage. Toujours actif : revenir
  /// à l'emprise de démarrage a toujours un effet, quel que soit le zoom
  /// courant.
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final Widget zoomIn = MapRoundButton(
      semanticsKey: mapZoomInButtonKey,
      icon: Icons.add,
      label: 'Zoomer',
      onTap: onZoomIn,
    );
    final Widget zoomOut = MapRoundButton(
      semanticsKey: mapZoomOutButtonKey,
      icon: Icons.remove,
      label: 'Dézoomer',
      onTap: onZoomOut,
    );
    final Widget recenter = MapRoundButton(
      semanticsKey: mapRecenterButtonKey,
      icon: Icons.my_location,
      label: 'Recentrer la carte',
      onTap: onRecenter,
    );
    // Un `Flex` et non `Column`/`Row` : un seul widget pour les deux sens.
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: mapControlsSpacing,
      children: <Widget>[
        ...switch (axis) {
          Axis.vertical => <Widget>[zoomIn, zoomOut],
          Axis.horizontal => <Widget>[zoomOut, zoomIn],
        },
        recenter,
      ],
    );
  }
}

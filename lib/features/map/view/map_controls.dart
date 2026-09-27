// Les boutons `+`, `−` et de recentrage (`K1`, 2026-09-23) : la molette
// zoome déjà sur Windows (`NV-W1`, constaté le 2026-09-13), mais rien ne sert
// qui n'a pas de molette — un pavé tactile, un lecteur d'écran, un clavier
// sans raccourci (`K2` les ajoute ensuite). Ces boutons ne remplacent donc
// pas la molette, ils la complètent.
//
// Ce widget est un widget de CONTENU pur, comme [MapScaleChips] et
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

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Le nombre de crans de zoom qu'un tap sur `+` ou `−` applique. `1,0` :
/// aligné sur le pas d'un cran de molette (`MapEventScrollWheelZoom`,
/// `map_view.dart`), pour que bouton et molette avancent d'un même cran.
const double zoomStep = 1.0;

/// Espacement entre deux boutons, en pixels logiques : ≥ 8 dp (`04-ui.md`
/// § 3), comme entre deux puces d'échelle ([MapScaleChips]).
const double mapControlsSpacing = 8;

/// Clé du bouton `+`.
const Key mapZoomInButtonKey = Key('map-zoom-in');

/// Clé du bouton `−`.
const Key mapZoomOutButtonKey = Key('map-zoom-out');

/// Clé du bouton de recentrage.
const Key mapRecenterButtonKey = Key('map-recenter');

/// Les trois boutons de pilotage de la caméra à la souris/au tactile : `+`,
/// `−`, recentrage — chacun une cible tactile ≥ 44 × 44 pt, espacés d'au
/// moins 8 dp (`04-ui.md` § 3).
class MapControls extends StatelessWidget {
  const MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    super.key,
  });

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _MapControlButton(
          semanticsKey: mapZoomInButtonKey,
          icon: Icons.add,
          label: 'Zoomer',
          onTap: onZoomIn,
        ),
        const SizedBox(height: mapControlsSpacing),
        _MapControlButton(
          semanticsKey: mapZoomOutButtonKey,
          icon: Icons.remove,
          label: 'Dézoomer',
          onTap: onZoomOut,
        ),
        const SizedBox(height: mapControlsSpacing),
        _MapControlButton(
          semanticsKey: mapRecenterButtonKey,
          icon: Icons.my_location,
          label: 'Recentrer la carte',
          onTap: onRecenter,
        ),
      ],
    );
  }
}

/// Un bouton rond, construit à la main pour la même raison que
/// [_MapScaleChip] de `map_scale_chips.dart` : la cible tactile de 44 pt est
/// ici une contrainte explicite, et l'état désactivé est porté par
/// `Semantics(enabled:)` en plus du rendu.
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.semanticsKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Posée sur le `Semantics` ci-dessous, PAS sur ce widget — comme pour
  /// `_MapScaleChip` (`map_scale_chips.dart`) : c'est le nœud sémantique que
  /// les tests trouvent, tapent et interrogent (`Semantics.enabled`).
  final Key semanticsKey;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handleTap = onTap;
    final bool enabled = handleTap != null;

    // `KeyboardFocusRing` (`K2`) : Entrée/Espace font ce que le tap fait
    // déjà, et le contour de focus est visible dès l'arrivée dessus.
    // `canRequestFocus: enabled` retire un bouton désactivé — zoom déjà à sa
    // borne — de l'ordre de tabulation : rien à activer, rien à atteindre.
    // Posé SOUS `Semantics`, comme `WarningLink` : la clé reste la racine du
    // sous-arbre où le focus se trouve.
    return Semantics(
      key: semanticsKey,
      button: true,
      enabled: enabled,
      label: label,
      // Le libellé est déjà annoncé ici ; sans cette exclusion l'`Icon`
      // intérieur ne porterait rien de plus, mais `InkWell` ferait tout de
      // même remonter sa propre action de tap en double (même relecture
      // que `WarningLink` et `_MapScaleChip`).
      excludeSemantics: true,
      onTap: handleTap,
      child: KeyboardFocusRing(
        onActivate: handleTap,
        canRequestFocus: enabled,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: handleTap,
            // `KeyboardFocusRing` porte déjà le focus : un second `FocusNode`
            // ferait de ce bouton deux arrêts de tabulation.
            canRequestFocus: false,
            customBorder: const CircleBorder(),
            // `SizedBox` de taille EXACTE, et non `ConstrainedBox(minWidth:)` +
            // `Center` : `Center` (un `Align` sans `widthFactor`/`heightFactor`)
            // REMPLIT les contraintes bornées qu'on lui donne plutôt que de se
            // réduire à son enfant — dans la colonne de [MapControls]
            // (`crossAxisAlignment.end`, contraintes lâches 0..largeur
            // disponible), cela grossissait le bouton jusqu'à la largeur de
            // tout l'écran (relecture du coordinateur du 2026-09-23, constaté
            // par un test à 400 × 800). Une taille EXACTE ferme la question :
            // ni trop petit (44 pt, `04-ui.md` § 3), ni plus grand que
            // nécessaire.
            child: SizedBox(
              width: minimumTapTarget,
              height: minimumTapTarget,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: enabled ? Colors.black : const Color(0xFFBDBDBD),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: enabled ? Colors.black : const Color(0xFFBDBDBD),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

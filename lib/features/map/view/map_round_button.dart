// Le bouton rond des contrôles de la carte, extrait de `map_controls.dart`
// (`F10a` de T3) pour être partagé : les trois boutons de caméra
// ([MapControls]) et les boutons d'entrée vers une feuille ([MapEntryButtons],
// « Filtres ») ont le même montage — cible tactile exacte, focus clavier
// visible, état désactivé porté par `Semantics`. Le rendu des trois boutons
// de caméra n'a pas changé : `map_controls_test.dart` en est le filet.
//
// Widget de CONTENU pur, comme [MapControls] : ni caméra ni `MapViewModel`.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Un bouton rond, construit à la main pour la même raison que
/// `_MapScaleChip` de `map_scale_chips.dart` : la cible tactile de 44 pt est
/// ici une contrainte explicite, et l'état désactivé est porté par
/// `Semantics(enabled:)` en plus du rendu.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    required this.semanticsKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    super.key,
  });

  /// Posée sur le `Semantics` ci-dessous, PAS sur ce widget — comme pour
  /// `_MapScaleChip` (`map_scale_chips.dart`) : c'est le nœud sémantique que
  /// les tests trouvent, tapent et interrogent (`Semantics.enabled`).
  final Key semanticsKey;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Fond plein : disque noir, icône blanche. Sert à dire qu'un état est
  /// actif (bouton « Filtres ») ; l'icône et une marque changent aussi, la
  /// teinte seule ne porte rien (`04-ui.md § 3`).
  ///
  /// Le disque plein reçoit un liséré blanc de 2 px, posé juste en dessous
  /// de la bande que couvre l'anneau de focus ([focusRingWidth], peint par
  /// `KeyboardFocusRing` par-dessus le bord) : l'anneau bleu ne se confond
  /// pas avec le fond plein, comme sur `DesignateCenterButton`.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handleTap = onTap;
    final bool enabled = handleTap != null;
    final Color tint = filled
        ? Colors.white
        : (enabled ? Colors.black : const Color(0xFFBDBDBD));

    final Widget iconWidget = Center(child: Icon(icon, color: tint));

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
                  color: filled ? Colors.black : Colors.white,
                  border: Border.all(
                    color: filled || enabled
                        ? Colors.black
                        : const Color(0xFFBDBDBD),
                  ),
                ),
                child: filled
                    ? Padding(
                        padding: const EdgeInsets.all(focusRingWidth),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: iconWidget,
                        ),
                      )
                    : iconWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

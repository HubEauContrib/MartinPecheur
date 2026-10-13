// La mise en page des surcouches de la carte : le délégué et ses
// emplacements, extraits de `map_view.dart` (`F10b` de T3) — ce fichier-là ne
// reçoit que des branchements. Aucune pièce d'écran ici : `buildMapOverlays`
// (`map_view.dart`) construit les colonnes et les donne à ce délégué.
import 'package:flutter/widgets.dart';

/// Les emplacements de [MapOverlaysLayout].
enum MapOverlaySlot {
  /// La colonne du haut à droite : avertissement et légende en disposition
  /// large ; avertissement, puces, avis et légende en disposition compacte.
  top,

  /// Disposition large seulement : la colonne des puces et des avis, en haut à
  /// gauche. Elle prend toute la surface et se place elle-même.
  left,

  /// La zone des fiches et du bouton de désignation, si elle existe. Elle
  /// prend toute la surface et se place elle-même.
  middle,

  /// La colonne du bas à droite : boutons d'entrée, contrôles de caméra,
  /// attribution.
  bottom,
}

/// La mise en page des surcouches de la carte (arbitrage du commanditaire du
/// 2026-10-12, « La légende défile », `F10b` de T3).
///
/// Le bord droit porte deux colonnes défilantes, l'une sous l'autre :
/// [MapOverlaySlot.top] et [MapOverlaySlot.bottom]. La colonne du bas est mise
/// en page D'ABORD ; celle du haut reçoit pour hauteur maximale ce qui reste
/// au-dessus d'elle, moins [padding]. La fenêtre du haut s'arrête donc
/// au-dessus des boutons du bas PAR CONSTRUCTION, sans hauteur mesurée ni
/// constante recopiée : la partie visible de la légende ne passe plus sous un
/// bouton ni sous l'attribution, elle défile.
///
/// Sur une surface trop courte pour les deux, c'est la colonne du bas qui
/// cède (décision de la boucle principale du 2026-10-12, réversible) : celle
/// du haut garde [topMinHeight] — la hauteur du contrôle « ⚠ Avertissement »,
/// premier de sa colonne, qui est une cible tactile (`BR-012` : il reste
/// visible). ⚠️ Elle ne garde alors QUE lui : sur une fenêtre compacte courte
/// (mesuré à 360 × 300, en Roboto, le 2026-10-13), les puces d'échelle, l'avis
/// et la légende sont sous le bord de la fenêtre du haut au repos et ne se
/// lisent qu'en la faisant défiler — `docs/04-ui.md` § 1, amendement du
/// 2026-10-12.
///
/// Ce délégué ne décide pas de l'ordre de peinture : c'est l'ordre dans lequel
/// son appelant lui donne ses enfants. Cette boîte ne capte aucun geste
/// elle-même.
class MapOverlaysLayout extends MultiChildLayoutDelegate {
  MapOverlaysLayout({required this.padding, required this.topMinHeight});

  /// Marge au bord de la carte, et écart entre les deux colonnes de droite.
  final double padding;

  /// Hauteur que la colonne du haut garde quoi qu'il arrive.
  final double topMinHeight;

  @override
  void performLayout(Size size) {
    for (final MapOverlaySlot slot in <MapOverlaySlot>[
      MapOverlaySlot.left,
      MapOverlaySlot.middle,
    ]) {
      if (hasChild(slot)) {
        layoutChild(slot, BoxConstraints.tight(size));
        positionChild(slot, Offset.zero);
      }
    }

    final double width = _atLeastZero(size.width - 2 * padding);
    final double height = _atLeastZero(size.height - 2 * padding);
    final Size bottom = layoutChild(
      MapOverlaySlot.bottom,
      BoxConstraints(
        maxWidth: width,
        maxHeight: _atLeastZero(height - topMinHeight - padding),
      ),
    );
    final Size top = layoutChild(
      MapOverlaySlot.top,
      BoxConstraints(
        maxWidth: width,
        maxHeight: _atLeastZero(height - bottom.height - padding),
      ),
    );
    positionChild(
      MapOverlaySlot.top,
      Offset(size.width - padding - top.width, padding),
    );
    positionChild(
      MapOverlaySlot.bottom,
      Offset(
        size.width - padding - bottom.width,
        size.height - padding - bottom.height,
      ),
    );
  }

  static double _atLeastZero(double value) => value < 0 ? 0 : value;

  @override
  bool shouldRelayout(MapOverlaysLayout oldDelegate) =>
      padding != oldDelegate.padding ||
      topMinHeight != oldDelegate.topMinHeight;
}

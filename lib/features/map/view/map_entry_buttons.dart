// Les boutons d'entrée de la carte (`F10a` de T3) : ceux qui ouvrent une
// feuille plutôt que de piloter la caméra. « Favoris » (`S10` de T3, arbitrage
// 8 du cadrage) est AU-DESSUS de « Filtres », par un paramètre
// `onOpenFavorites` ; nul, le bouton est absent et le groupe est « Filtres »
// seul. La colonne s'empile de haut en bas, dans l'ordre de la tabulation ; en
// rangée (`S4` d'Ergonomie, [MapEntryButtons.axis]), « Favoris » est à gauche
// de « Filtres », dans le même ordre.
//
// Widget de CONTENU pur, comme [MapControls] : ni `MapViewModel` ni caméra.
// `_MapViewState` construira le rappel et dira si un filtre est actif
// (`F10b`).
//
// Le bouton « Filtres » change de FORME quand un filtre est actif — icône
// pleine, fond plein, marque ronde au coin —, jamais de teinte seule
// (`04-ui.md § 3`).

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart'
    show mapControlsSpacing;
import 'package:martinpecheur/features/map/view/map_round_button.dart';

/// Clé du bouton « Favoris » (`S10` de T3).
const Key mapFavoritesButtonKey = Key('map-open-favorites');

/// Libellé annoncé du bouton « Favoris ».
const String mapFavoritesLabel = 'Favoris';

/// Clé du bouton « Filtres ».
const Key mapFiltersButtonKey = Key('map-filters');

/// Clé de la marque ronde posée au coin du bouton « Filtres » actif.
const Key mapFiltersActiveMarkKey = Key('map-filters-active-mark');

/// Libellé annoncé du bouton « Filtres » quand aucun filtre n'est actif
/// (`cadrage-t3-design.md`, § 10.1).
const String mapFiltersLabel = 'Filtres';

/// Libellé annoncé quand un filtre est actif (§ 10.1).
const String mapFiltersActiveLabel = 'Filtres — un filtre est actif';

/// Diamètre de la marque, liséré compris.
const double _activeMarkSize = 12;

/// Le groupe des boutons d'entrée : « Favoris », puis « Filtres ».
///
/// En colonne ([Axis.vertical], le défaut), empilés de haut en bas et alignés
/// à droite. En rangée ([Axis.horizontal], le bas de la carte au téléphone,
/// `S4` d'Ergonomie), de gauche à droite : « Favoris » puis « Filtres », dans
/// le même ordre, que la tabulation suit. [mapControlsSpacing] sépare les
/// deux ; les formes de « Filtres » ne changent pas.
class MapEntryButtons extends StatelessWidget {
  const MapEntryButtons({
    required this.onOpenFilters,
    required this.filterActive,
    this.onOpenFavorites,
    this.axis = Axis.vertical,
    super.key,
  });

  /// Le sens du groupe : une colonne (défaut) ou une rangée.
  final Axis axis;

  /// Appelé par un tap, Entrée ou Espace sur « Filtres » : ouvre la feuille.
  final VoidCallback onOpenFilters;

  /// Appelé par un tap, Entrée ou Espace sur « Favoris » : ouvre l'écran des
  /// favoris. Injecté : la carte ignore qui l'écoute (`feature-vers-feature`).
  /// `null` : le bouton est absent, le groupe est celui du lot 4.
  final VoidCallback? onOpenFavorites;

  /// Au moins un filtre est actif : le bouton prend sa forme active.
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onOpenFavorites = this.onOpenFavorites;
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: mapControlsSpacing,
      children: <Widget>[
        if (onOpenFavorites != null)
          MapRoundButton(
            semanticsKey: mapFavoritesButtonKey,
            icon: Icons.star,
            label: mapFavoritesLabel,
            onTap: onOpenFavorites,
          ),
        Stack(
          children: <Widget>[
            MapRoundButton(
              semanticsKey: mapFiltersButtonKey,
              icon: filterActive ? Icons.filter_alt : Icons.filter_list,
              label: filterActive ? mapFiltersActiveLabel : mapFiltersLabel,
              onTap: onOpenFilters,
              filled: filterActive,
            ),
            if (filterActive)
              const Positioned(
                top: 0,
                right: 0,
                // Inerte au pointeur (un tap dessus atteint le bouton) et
                // hors de la sémantique (le libellé du bouton dit déjà
                // « un filtre est actif »).
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      key: mapFiltersActiveMarkKey,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: SizedBox(
                        width: _activeMarkSize,
                        height: _activeMarkSize,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

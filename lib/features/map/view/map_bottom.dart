// Le bas de la carte (`S4` et `D2` d'Ergonomie, spec § 5.4 et § 5.8,
// arbitrage 2) : une pièce de la mise en page de la carte (`map_layout.dart`),
// découpée hors de `map_view.dart` par responsabilité.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_traversal_order.dart';

/// Le bas de la carte (`S4` d'Ergonomie, spec § 5.4, arbitrage 2) : les
/// boutons d'entrée ([MapEntryButtons]), les contrôles de caméra
/// ([MapControls]) et l'attribution IGN, chacun sous son rang de tabulation.
///
/// [compact] (moins de 600 px de large) : une **rangée** — « Favoris »,
/// « Filtres » à gauche ; −, +, recentrer à droite — puis l'attribution
/// dessous ; l'écart entre les deux groupes est de la carte (une `Row` ne
/// prend aucun geste hors de ses enfants). Sinon, la **colonne** : boutons
/// d'entrée, contrôles, attribution, alignés à droite. Les boutons ne changent
/// ni de libellé, ni d'annonce, ni de comportement.
///
/// Public pour que la mesure des pièces (`test/support/ergonomie_mesures.dart`)
/// monte CE bas-là, et non une recopie qui dériverait.
class MapBottom extends StatelessWidget {
  const MapBottom({
    required this.compact,
    required this.onOpenFilters,
    required this.filterActive,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    this.onOpenFavorites,
    super.key,
  });

  final bool compact;
  final VoidCallback onOpenFilters;
  final VoidCallback? onOpenFavorites;
  final bool filterActive;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final Axis axis = compact ? Axis.horizontal : Axis.vertical;
    final Widget entries = FocusTraversalOrder(
      order: const NumericFocusOrder(mapTraversalOrderEntryButtons),
      child: MapEntryButtons(
        axis: axis,
        onOpenFilters: onOpenFilters,
        onOpenFavorites: onOpenFavorites,
        filterActive: filterActive,
      ),
    );
    final Widget controls = FocusTraversalOrder(
      order: const NumericFocusOrder(mapTraversalOrderControls),
      child: MapControls(
        axis: axis,
        onZoomIn: onZoomIn,
        onZoomOut: onZoomOut,
        onRecenter: onRecenter,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (compact)
          Row(children: <Widget>[entries, const Spacer(), controls])
        else ...<Widget>[
          entries,
          const SizedBox(height: mapControlsSpacing),
          controls,
        ],
        const SizedBox(height: _attributionGap),
        const IgnAttributionBadge(),
      ],
    );
  }
}

/// L'écart entre les boutons et l'attribution : la marge des surcouches.
const double _attributionGap = 8;

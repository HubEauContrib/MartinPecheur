// Le bas de la carte (`S4` et `D2` d'Ergonomie, spec § 5.4 et § 5.8,
// arbitrage 2) : une pièce de la mise en page de la carte (`map_layout.dart`),
// découpée hors de `map_view.dart` par responsabilité.
//
// Depuis `D8` (arbitrages 22 et 24 du commanditaire, 2026-10-18), la COLONNE
// dit deux hauteurs intrinsèques (note d'architecture, 1) : repliée,
// l'attribution IGN et son écart ; entière, ses cinq boutons compris. En deçà
// des quatre tailles, posée plus bas que sa hauteur entière, elle fait
// DÉFILER ses boutons — ancrés en bas, « recentrer » et le zoom en vue au
// repos — au-dessus de l'attribution, qui reste entière et affichée. Un
// défilement par `SingleChildScrollView`, qui répond aux intrinsèques : ni
// `LayoutBuilder` ni autre `Viewport`. La RANGÉE du téléphone ne cède jamais :
// une seule hauteur.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_traversal_order.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show NoMinIntrinsicHeight;

/// Le bas de la carte (`S4` d'Ergonomie, spec § 5.4, arbitrage 2) : les
/// boutons d'entrée ([MapEntryButtons]), les contrôles de caméra
/// ([MapControls]) et l'attribution IGN, chacun sous son rang de tabulation.
///
/// [compact] (moins de 600 px de large) : une **rangée** — « Favoris »,
/// « Filtres » à gauche ; −, +, recentrer à droite — puis l'attribution
/// dessous ; l'écart entre les deux groupes est de la carte (une `Row` ne
/// prend aucun geste hors de ses enfants). Sinon, la **colonne** : boutons
/// d'entrée, contrôles, attribution, alignés à droite ; posée plus bas que sa
/// hauteur entière (en deçà des quatre tailles, `D8`), ses boutons défilent
/// au-dessus de l'attribution, et son défilement ne prend que les gestes
/// posés sur un bouton. Les boutons ne changent ni de libellé, ni d'annonce,
/// ni de comportement.
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
        else
          // Les boutons cèdent, l'attribution non : sa hauteur et son écart
          // sont la hauteur repliée de la colonne (`NoMinIntrinsicHeight`).
          // `Flexible` lâche : sous une hauteur bornée, les boutons reçoivent
          // ce que l'attribution laisse ; sous une hauteur non bornée (la
          // mesure des pièces), leur hauteur entière.
          Flexible(
            child: NoMinIntrinsicHeight(
              child: _ColumnScroll(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    entries,
                    const SizedBox(height: mapControlsSpacing),
                    controls,
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: _attributionGap),
        const IgnAttributionBadge(),
      ],
    );
  }
}

/// Le défilement des boutons de la colonne (`D8`) : ancré en bas (`reverse`)
/// — « recentrer » et le zoom en vue au repos, « Favoris » et « Filtres »
/// amenés en glissant ou par le focus —, `primary: false`, sans la barre de
/// bureau, et ne prenant que les gestes posés sur un bouton
/// (`HitTestBehavior.deferToChild`) : ailleurs, ils vont à la carte, comme
/// avant. Même retrait que les défilements du bloc de lecture
/// (`map_reading_block.dart`).
class _ColumnScroll extends StatelessWidget {
  const _ColumnScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        primary: false,
        reverse: true,
        hitTestBehavior: HitTestBehavior.deferToChild,
        child: child,
      ),
    );
  }
}

/// L'écart entre les boutons et l'attribution : la marge des surcouches.
const double _attributionGap = 8;

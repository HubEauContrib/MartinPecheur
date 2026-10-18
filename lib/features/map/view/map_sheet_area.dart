// La zone des fiches de la carte (`D2` d'Ergonomie, spec § 5.8 et § 6.5) : la
// pièce `sheet` de la mise en page de la carte (`map_layout.dart`), découpée
// hors de `map_view.dart` par responsabilité. `D5` la reprend : chaque cadre de
// fiche défilera alors son corps sous son en-tête, et la zone ne défilera plus
// elle-même.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart'
    show readingColumnWidth;
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show NoMinIntrinsicHeight;

/// La clé de la zone des fiches : la fiche du bas ou le panneau latéral.
const Key mapSheetAreaKey = Key('map-sheet-area');

/// La couleur du filet à gauche du panneau latéral : celle des filets du bloc
/// et des entrées éteintes.
const Color mapSidePanelRuleColor = Color(0xFFC9CFC4);

/// L'épaisseur du filet du panneau latéral, en pixels logiques.
const double mapSidePanelRuleWidth = 1;

/// La zone des fiches (spec § 6.5) : les panneaux de fiche empilés — station,
/// point ONDE, tronçon, dans cet ordre, sans écart (un panneau fermé vaut
/// `SizedBox.shrink`, et la mise en page ne tient la fiche pour ouverte que si
/// la zone a une hauteur) —, sur un fond blanc prolongé de [extend] sous les
/// marges système qui la bordent.
///
/// - Fiche du bas ([sidePanel] faux) : le contenu est centré dans la largeur de
///   lecture ([readingColumnWidth], R18).
/// - Panneau latéral ([sidePanel] vrai) : toute la largeur du panneau, et un
///   filet [mapSidePanelRuleColor] à gauche, sur toute la hauteur, peint
///   PAR-DESSUS la fiche — un panneau de fiche porte son propre fond blanc, qui
///   cacherait un filet peint dessous.
///
/// La forme de l'arbre ne dépend pas de [sidePanel] : franchir 800 px de large,
/// fiche ouverte, ne recrée pas la fiche (position de défilement, focus et
/// état gardés).
///
/// **Provisoirement** (jusqu'à `D5`), la zone défile elle-même, par
/// [scrollController] (`K4` de T3 : la racine de composition la ramène en haut
/// à chaque ouverture), et annonce une hauteur repliée nulle
/// ([NoMinIntrinsicHeight]) : c'est elle qui cède au repli 2. Aucune hauteur
/// propre : celles des panneaux, que la mise en page de la carte interroge.
class MapSheetArea extends StatelessWidget {
  const MapSheetArea({
    required this.sidePanel,
    required this.extend,
    required this.panels,
    this.scrollController,
    super.key,
  });

  final bool sidePanel;

  /// Ce que le fond déborde de la zone, sous les marges système.
  final EdgeInsets extend;

  /// Les panneaux de fiche fournis, dans l'ordre d'empilement.
  final List<Widget> panels;

  /// Le contrôleur du défilement de la zone, tenu par la racine de
  /// composition. `null` : le défilement garde son contrôleur interne.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SheetBackgroundPainter(extend: extend),
      foregroundPainter: sidePanel
          ? _SidePanelRulePainter(extend: extend)
          : null,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: sidePanel ? double.infinity : readingColumnWidth,
          ),
          child: NoMinIntrinsicHeight(
            child: ScrollConfiguration(
              // Sans la `Scrollbar` automatique du bureau, dont le
              // `MouseRegion` est opaque sur toute la boîte : même retrait que
              // les pièces du bloc (`map_reading_block.dart`).
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: scrollController,
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: panels,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le fond de [MapSheetArea] : un `CustomPainter` peint hors de sa boîte sans
/// rognage, ce qui prolonge le fond sous la marge système sans que la boîte —
/// donc le toucher et la mise en page — n'y entre.
class _SheetBackgroundPainter extends CustomPainter {
  const _SheetBackgroundPainter({required this.extend});

  final EdgeInsets extend;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Rect.fromLTRB(
        -extend.left,
        -extend.top,
        size.width + extend.right,
        size.height + extend.bottom,
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SheetBackgroundPainter oldDelegate) =>
      oldDelegate.extend != extend;
}

/// Le filet à gauche du panneau latéral, peint au premier plan, sur toute la
/// hauteur de la zone et des marges système qui la prolongent.
class _SidePanelRulePainter extends CustomPainter {
  const _SidePanelRulePainter({required this.extend});

  final EdgeInsets extend;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        -extend.top,
        mapSidePanelRuleWidth,
        size.height + extend.bottom,
      ),
      Paint()..color = mapSidePanelRuleColor,
    );
  }

  @override
  bool shouldRepaint(_SidePanelRulePainter oldDelegate) =>
      oldDelegate.extend != extend;
}

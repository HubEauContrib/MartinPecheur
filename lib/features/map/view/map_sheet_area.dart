// La zone des fiches de la carte (`D2` d'Ergonomie, spec § 5.8 et § 6.5) : la
// pièce `sheet` de la mise en page de la carte (`map_layout.dart`), découpée
// hors de `map_view.dart` par responsabilité. Depuis `D5`, elle ne défile plus
// elle-même : chaque panneau de fiche — un `SheetFrame` — défile son CORPS
// sous son EN-TÊTE épinglé, et la zone transmet à la mise en page les hauteurs
// du cadre (repliée : l'en-tête seul ; entière : la fiche entière ; depuis
// `D7`, mise en avant : l'en-tête et la mesure mise en avant, arbitrage 18).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart'
    show readingColumnWidth;
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show RenderSheetFeaturedHeight, sheetFeaturedHeightOf;

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
/// **Aucun défilement de zone** (`D5`, arbitrage 3) : chaque panneau reçoit
/// pour hauteur maximale ce que les panneaux du dessus lui laissent, et c'est
/// son cadre qui fait défiler son corps sous l'en-tête. La position du corps
/// est tenue par la racine de composition (`bodyScrollController` des
/// panneaux, `K4` de T3). Les hauteurs intrinsèques de la zone, et sa hauteur
/// mise en avant (`D7`), sont la somme de celles des panneaux, lues à la
/// largeur où leur contenu est posé — la
/// largeur de lecture au plus pour la fiche du bas : au-delà de 760 px, la
/// hauteur n'est plus lue plus large qu'elle n'est posée.
class MapSheetArea extends StatelessWidget {
  const MapSheetArea({
    required this.sidePanel,
    required this.extend,
    required this.panels,
    super.key,
  });

  final bool sidePanel;

  /// Ce que le fond déborde de la zone, sous les marges système.
  final EdgeInsets extend;

  /// Les panneaux de fiche fournis, dans l'ordre d'empilement.
  final List<Widget> panels;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SheetBackgroundPainter(extend: extend),
      foregroundPainter: sidePanel
          ? _SidePanelRulePainter(extend: extend)
          : null,
      child: _SheetPanels(
        maxContentWidth: sidePanel ? double.infinity : readingColumnWidth,
        children: panels,
      ),
    );
  }
}

/// Les panneaux empilés de haut en bas, sans écart, chacun dans la largeur de
/// contenu ([maxContentWidth] au plus, centré) et borné en hauteur par ce que
/// les précédents laissent.
///
/// Ni `Column` — elle donnerait aux panneaux une hauteur non bornée, et le
/// corps d'un cadre ne défilerait plus —, ni `Flexible` dans une `Column` —
/// `RenderFlex` partagerait la place à parts égales entre les panneaux,
/// fermés compris.
class _SheetPanels extends MultiChildRenderObjectWidget {
  const _SheetPanels({required this.maxContentWidth, super.children});

  final double maxContentWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSheetPanels(maxContentWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetPanels renderObject,
  ) {
    renderObject.maxContentWidth = maxContentWidth;
  }
}

class _SheetPanelsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSheetPanels extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SheetPanelsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SheetPanelsParentData>
    implements RenderSheetFeaturedHeight {
  _RenderSheetPanels(this._maxContentWidth);

  double _maxContentWidth;

  set maxContentWidth(double value) {
    if (value == _maxContentWidth) return;
    _maxContentWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SheetPanelsParentData) {
      child.parentData = _SheetPanelsParentData();
    }
  }

  /// La largeur où le contenu est posé, pour une largeur de zone [width].
  double _contentWidth(double width) => math.min(width, _maxContentWidth);

  double _sum(double Function(RenderBox child) of) {
    double total = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      total += of(child);
      child = childAfter(child);
    }
    return total;
  }

  double _widest(double Function(RenderBox child) of) {
    double widest = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      widest = math.max(widest, of(child));
      child = childAfter(child);
    }
    return math.min(widest, _maxContentWidth);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widest((RenderBox c) => c.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widest((RenderBox c) => c.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sum((RenderBox c) => c.getMinIntrinsicHeight(_contentWidth(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sum((RenderBox c) => c.getMaxIntrinsicHeight(_contentWidth(width)));

  /// La hauteur mise en avant de la zone (arbitrage 18) : celle des panneaux,
  /// lue comme leurs autres hauteurs, à la largeur de leur contenu.
  @override
  double featuredHeight(double width) =>
      _sum((RenderBox c) => sheetFeaturedHeightOf(c, _contentWidth(width)));

  /// Pose — ou mesure à sec, si [dry] — chaque panneau, et rend la taille de
  /// la zone : sa largeur entière, la somme des hauteurs des panneaux, dans
  /// ses contraintes.
  ///
  /// Un panneau n'est jamais posé plus bas que sa hauteur repliée (l'en-tête
  /// du cadre, qui ne cède jamais) : aux tailles garanties, la mise en page
  /// de la carte la lui donne toujours ; en deçà, là où même l'en-tête ne
  /// tient pas, la zone ROGNE ce qui dépasse (ni peint ni touchable), au lieu
  /// d'écraser l'en-tête dans une colonne qui déborde.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final double width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _widest((RenderBox c) => c.getMaxIntrinsicWidth(double.infinity));
    final double contentWidth = _contentWidth(width);
    final double left = (width - contentWidth) / 2;
    double used = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final BoxConstraints panel = BoxConstraints(
        minWidth: contentWidth,
        maxWidth: contentWidth,
        maxHeight: math.max(
          math.max(0, constraints.maxHeight - used),
          child.getMinIntrinsicHeight(contentWidth),
        ),
      );
      final Size size;
      if (dry) {
        size = child.getDryLayout(panel);
      } else {
        child.layout(panel, parentUsesSize: true);
        size = child.size;
        (child.parentData! as _SheetPanelsParentData).offset = Offset(
          left,
          used,
        );
      }
      used += size.height;
      child = childAfter(child);
    }
    final Size area = constraints.constrain(Size(width, used));
    if (!dry) {
      _clipped = used > area.height;
    }
    return area;
  }

  /// Vrai quand les panneaux dépassent la zone (en deçà des tailles
  /// garanties) : la peinture est alors rognée à la zone.
  bool _clipped = false;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_clipped) {
      _clipLayer.layer = null;
      defaultPaint(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  // `RenderBox.hitTest` ne descend que si le point est dans la zone : ce qui
  // est rogné n'est pas touchable.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
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

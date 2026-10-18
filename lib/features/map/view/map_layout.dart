// La mise en page de la carte visible (`D1` d'Ergonomie, spec § 5.1 à § 5.6
// et § 6.5) : un `RenderObject` qui pose, sur la carte, le bloc de lecture en
// trois pièces (`B1`), le bas (`S4`), la bande du bouton de désignation
// (`S4`), le réticule et la fiche (`S3`), sur trois largeurs, en répartissant
// la hauteur par `allocateMapLayout` (`S5`).
//
// Branché par `D2` : `buildMapOverlays` (`map_view.dart`) le pose dans le
// `Stack` de la carte.
//
// ## L'ordre de la mise en page
//
// 1. la largeur ([mapLayoutWidthFor]) et la zone sûre ;
// 2. la fiche est OUVERTE si son enfant a une hauteur intrinsèque maximale
//    non nulle (une fiche fermée vaut `SizedBox.shrink`) ; le mode
//    « Restrictions », si la bande du bouton en a une ;
// 3. les largeurs : [mapLayoutWidths], la même fonction que la porte de
//    faisabilité (`S6`, `mesurerPieces`) ;
// 4. les intrinsèques des enfants, lues à ces largeurs AVANT toute pose — et,
//    pour la fiche, sa hauteur mise en avant (`sheetFeaturedHeightOf`,
//    arbitrage 18) et sa première rangée (`sheetFirstRowHeightOf`, arbitrage
//    24) —, le plancher de la partie fixe (la cible tactile de la plateforme,
//    arbitrages 19 et 21), puis [allocateMapLayout] ;
// 5. chaque enfant posé avec la hauteur allouée : la partie fixe, la bande, la
//    fiche et la colonne du bas se replient d'elles-mêmes (note
//    d'architecture) ; les trois pièces du bloc sont posées À CHAQUE mise en
//    page, même à 0 ;
// 6. les positions, puis le réticule ;
// 7. le rapport ([MapLayoutReport]), publié après la trame s'il a changé.
//
// ## Ce qui se peint et se touche
//
// Ordre de peinture, à la largeur de la colonne : le bas d'abord, puis la
// fiche — l'en-tête de la fiche passe devant la colonne (arbitrage 22, `D8`) :
// là où, en deçà des tailles garanties, même la colonne repliée descendrait
// sur elle, c'est la fiche qui se voit et se touche —, puis le bloc (la fiche
// ne le recouvre jamais), la bande, le réticule en dernier (rien ne se peint
// sur lui). Au téléphone, comme avant `D8` : la fiche d'abord, puis le bloc,
// la rangée — devant la fiche, l'attribution entière (l'arbitrage 22 ne vaut
// qu'à la colonne) —, la bande, le réticule. Aux tailles garanties, rien ne
// se recoupe : l'ordre n'y change rien. Le toucher suit l'ordre inverse.
// Cette boîte ne prend aucun geste elle-même : hors des pièces, la carte
// dessous le reçoit. Les pièces du bloc absorbent sur leur surface (`B1`), la
// bande et le bas ne prennent un geste que sur leurs éléments (`S4`) :
// chacune en décide. Repli 6 — faute de hauteur, faute de
// largeur (une bande qui ne recevrait que 0 px, arbitrages 14 et 23) ou pour
// le plancher de la partie fixe (arbitrage 21) : la bande et le réticule sont
// posés à taille nulle et ne sont ni peints, ni touchables, ni annoncés ; ils
// restent dans l'arbre (leurs intrinsèques restent lisibles). La bande
// retirée garde son nœud de focus : un `RenderObject` ne peut pas en retirer
// un ; la composition (`D2`) l'exclut par `ExcludeFocus`, à l'écoute du
// rapport. Elle l'enveloppe aussi d'un `ExcludeSemantics` (`D3`) : une
// redondance voulue, puisque [RenderMapLayout.visitChildrenForSemantics]
// exclut déjà des annonces ce qui est retiré ; aucun test ne distingue les
// deux.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart'
    show mapCenterReticleSize;
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show sheetFeaturedHeightOf, sheetFirstRowHeightOf;
import 'package:martinpecheur/features/shared/tap_target.dart'
    show minimumTapTarget;

/// La marge d'une surcouche au bord de la carte visible, et l'écart entre deux
/// groupes de pièces (`allocateMapLayout`, `gap`), en pixels logiques : ce que
/// la composition (`buildMapOverlays`) passe à [MapLayout.padding]. Publique
/// pour que la mesure de la porte (`S6`) la lise ici, sans la recopier.
const double mapOverlayPadding = 8;

/// La bande du réticule : le réticule et sa marge, au-dessus et au-dessous
/// (spec § 5.6). Ce que la composition passe à [MapLayout.reticleBandHeight] ;
/// publique pour la même raison que [mapOverlayPadding].
const double mapReticleBandHeight =
    mapCenterReticleSize + 2 * mapOverlayPadding;

/// Les emplacements de [MapLayout]. Chacun est facultatif : absent, il vaut
/// une pièce nulle.
enum MapLayoutSlot {
  /// La partie fixe du bloc de lecture (`MapReadingBlockFixed`).
  blockFixed,

  /// Les avis du bloc (`MapReadingBlockNotices`).
  blockNotices,

  /// La légende du bloc (`MapReadingBlockLegend`).
  blockLegend,

  /// Le bas de la carte : la rangée (compact) ou la colonne, attribution
  /// comprise.
  bottom,

  /// La bande du bouton de désignation (`DesignationBand`). Hors mode :
  /// `SizedBox.shrink`.
  band,

  /// Le réticule (`MapCenterReticle`). Hors mode : `SizedBox.shrink`.
  reticle,

  /// La fiche ouverte (fiche du bas ou panneau latéral). Aucune fiche :
  /// `SizedBox.shrink`.
  sheet,
}

/// Ce que la vue doit savoir de la dernière mise en page (note
/// d'architecture, 5) : la carte visible, le réticule, la répartition, et la
/// part de la surface que la fiche couvre (`D4`). Égalité par valeur.
final class MapLayoutReport {
  const MapLayoutReport({
    required this.visible,
    required this.reticle,
    required this.allocation,
    required this.covered,
  });

  /// La carte visible, dans le repère de [MapLayout] : la surface moins la
  /// zone sûre et moins la fiche.
  final Rect visible;

  /// Le réticule posé, ou `null` : hors mode, ou retiré (repli 6).
  final Rect? reticle;

  /// La répartition de la hauteur ([allocateMapLayout]).
  final MapLayoutAllocation allocation;

  /// La part de la surface que la fiche couvre, en écarts aux bords de
  /// [MapLayout] (`D4` d'Ergonomie, arbitrage 12) : ce que la caméra doit
  /// éviter. Panneau : `right`, du bord gauche du panneau au bord de la
  /// surface ; fiche du bas : `bottom`, du haut de la fiche au bas de la
  /// surface. Seule compte la part que la fiche couvre, jusqu'au bord de la
  /// surface : la marge système de son côté y entre — la marge du bas sous
  /// une fiche du bas, celle de droite sous le panneau, où leur fond se
  /// prolonge —, aucune autre marge de la zone sûre (spec § 5.2 : « la carte,
  /// elle, va jusqu'aux bords »), et aucune sans fiche. [EdgeInsets.zero] sans
  /// fiche ouverte, et pour une fiche du bas posée à 0 px — en deçà des
  /// tailles garanties seulement : depuis `D5`, la fiche garde au moins son
  /// en-tête épinglé, et depuis `D8` la première rangée de cet en-tête
  /// (arbitrage 24).
  final EdgeInsets covered;

  @override
  bool operator ==(Object other) =>
      other is MapLayoutReport &&
      other.visible == visible &&
      other.reticle == reticle &&
      other.allocation == allocation &&
      other.covered == covered;

  @override
  int get hashCode => Object.hash(visible, reticle, allocation, covered);

  @override
  String toString() =>
      'MapLayoutReport(visible: $visible, reticle: $reticle, '
      'allocation: $allocation, covered: $covered)';
}

/// L'emplacement d'un enfant de [MapLayout].
class MapLayoutParentData extends ContainerBoxParentData<RenderBox> {
  MapLayoutSlot? slot;
}

/// Désigne l'emplacement de [child] dans [MapLayout].
///
/// Sa clé est son emplacement (`ValueKey(slot)`), comme celle d'un `LayoutId`
/// est son identifiant : la bande et le réticule n'existent qu'en mode, et
/// sans clé, allumer ou éteindre « Restrictions » ferait passer l'élément de la
/// fiche, posée après eux, au widget de la bande — une fiche neuve, son corps
/// revenu en haut, son focus perdu (I1 de la relecture finale de la branche).
/// Aucune autre clé ne se passe : elle romprait cet appariement.
class MapLayoutChild extends ParentDataWidget<MapLayoutParentData> {
  MapLayoutChild({required this.slot, required super.child})
    : super(key: ValueKey<MapLayoutSlot>(slot));

  final MapLayoutSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final MapLayoutParentData data =
        renderObject.parentData! as MapLayoutParentData;
    if (data.slot != slot) {
      data.slot = slot;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => MapLayout;
}

/// La mise en page de la carte visible : chaque enfant enveloppé d'un
/// [MapLayoutChild]. Elle prend toute la surface qu'on lui donne.
class MapLayout extends MultiChildRenderObjectWidget {
  const MapLayout({
    required this.padding,
    required this.safeInsets,
    required this.reticleBandHeight,
    required this.report,
    super.children,
    super.key,
  });

  /// La marge au bord de la carte visible, et l'écart entre deux groupes de
  /// pièces (`allocateMapLayout`, `gap`).
  final double padding;

  /// La zone sûre de l'appareil : rien ne s'y pose.
  final EdgeInsets safeInsets;

  /// La bande du réticule : le réticule et sa marge (spec § 5.6).
  final double reticleBandHeight;

  /// Où le rapport de la dernière mise en page est publié, après la trame et
  /// seulement s'il a changé.
  final ValueNotifier<MapLayoutReport?> report;

  @override
  RenderMapLayout createRenderObject(BuildContext context) => RenderMapLayout(
    padding: padding,
    safeInsets: safeInsets,
    reticleBandHeight: reticleBandHeight,
    report: report,
    blockFixedFloor: minimumTapTarget,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMapLayout renderObject,
  ) {
    renderObject
      ..padding = padding
      ..safeInsets = safeInsets
      ..reticleBandHeight = reticleBandHeight
      ..report = report
      ..blockFixedFloor = minimumTapTarget;
  }
}

/// Le `RenderObject` de [MapLayout] (voir l'en-tête du fichier).
class RenderMapLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MapLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MapLayoutParentData> {
  RenderMapLayout({
    required this._padding,
    required this._safeInsets,
    required this._reticleBandHeight,
    required this._report,
    required this._blockFixedFloor,
  });

  double _padding;
  EdgeInsets _safeInsets;
  double _reticleBandHeight;
  ValueNotifier<MapLayoutReport?> _report;

  /// Le plancher de la partie fixe quand elle défile pour la fiche du bas
  /// (arbitrage 19) : la cible tactile de la plateforme, que [MapLayout] lit
  /// (`minimumTapTarget`) et passe à `allocateMapLayout`.
  double _blockFixedFloor;

  /// Le dernier rapport calculé, en attente de publication.
  MapLayoutReport? _latest;
  bool _publishScheduled = false;

  /// Le repli 6 de la dernière mise en page : bande et réticule ni peints, ni
  /// touchables, ni annoncés.
  bool _bandWithdrawn = false;

  /// Le bas de la dernière mise en page est la rangée du téléphone (compact) :
  /// elle se peint devant la fiche ; la colonne, derrière (arbitrage 22).
  bool _row = false;

  /// Les enfants par emplacement, relevés à la dernière mise en page : la
  /// peinture et le toucher les relisent sans reparcourir la liste (un ajout
  /// ou un retrait d'enfant remet en page).
  Map<MapLayoutSlot, RenderBox> _laidOut = const <MapLayoutSlot, RenderBox>{};

  set padding(double value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  set safeInsets(EdgeInsets value) {
    if (value == _safeInsets) return;
    _safeInsets = value;
    markNeedsLayout();
  }

  set reticleBandHeight(double value) {
    if (value == _reticleBandHeight) return;
    _reticleBandHeight = value;
    markNeedsLayout();
  }

  set report(ValueNotifier<MapLayoutReport?> value) {
    if (identical(value, _report)) return;
    _report = value;
    markNeedsLayout();
  }

  set blockFixedFloor(double value) {
    if (value == _blockFixedFloor) return;
    _blockFixedFloor = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MapLayoutParentData) {
      child.parentData = MapLayoutParentData();
    }
  }

  /// Les enfants par emplacement. Un emplacement en double est une erreur de
  /// l'appelant.
  Map<MapLayoutSlot, RenderBox> _children() {
    final Map<MapLayoutSlot, RenderBox> bySlot = <MapLayoutSlot, RenderBox>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final MapLayoutParentData data = child.parentData! as MapLayoutParentData;
      final MapLayoutSlot? slot = data.slot;
      assert(slot != null, 'Chaque enfant de MapLayout est un MapLayoutChild.');
      assert(
        slot == null || !bySlot.containsKey(slot),
        'Emplacement $slot donné deux fois à MapLayout.',
      );
      if (slot != null) bySlot[slot] = child;
      child = data.nextSibling;
    }
    return bySlot;
  }

  // --- Les intrinsèques de la boîte elle-même ---------------------------------
  //
  // Elle prend toute la surface qu'on lui donne : aucune taille propre.

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.hasBoundedWidth && constraints.hasBoundedHeight
      ? constraints.biggest
      : constraints.smallest;

  // --- La mise en page --------------------------------------------------------

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    final Map<MapLayoutSlot, RenderBox> children = _laidOut = _children();
    final double padding = math.max(0, _padding);

    double maxHeight(MapLayoutSlot slot, double width) =>
        children[slot]?.getMaxIntrinsicHeight(width) ?? 0;
    double minHeight(MapLayoutSlot slot, double width) =>
        children[slot]?.getMinIntrinsicHeight(width) ?? 0;
    PieceHeights heights(MapLayoutSlot slot, double width) =>
        PieceHeights(min: minHeight(slot, width), max: maxHeight(slot, width));

    // 1. La zone sûre.
    final Rect safe = Rect.fromLTRB(
      math.min(_safeInsets.left, size.width),
      math.min(_safeInsets.top, size.height),
      math.max(_safeInsets.left, size.width - _safeInsets.right),
      math.max(_safeInsets.top, size.height - _safeInsets.bottom),
    );
    final MapLayoutWidth layout = mapLayoutWidthFor(size.width);
    final bool compact = switch (layout) {
      MapLayoutWidth.compact => true,
      MapLayoutWidth.wide || MapLayoutWidth.panel => false,
    };
    final bool panel = switch (layout) {
      MapLayoutWidth.panel => true,
      MapLayoutWidth.compact || MapLayoutWidth.wide => false,
    };

    // 2. La fiche ouverte, le mode : dits par les enfants eux-mêmes.
    final double sheetWidth = panel ? mapSidePanelWidth : safe.width;
    final bool sheetOpen = maxHeight(MapLayoutSlot.sheet, sheetWidth) > 0;
    final bool designation = maxHeight(MapLayoutSlot.band, double.infinity) > 0;

    // 3. Les largeurs : la seule source, partagée avec `S6`.
    final MapLayoutWidths widths = mapLayoutWidths(
      width: size.width,
      safeWidth: safe.width,
      sheetOpen: sheetOpen,
      bottomMaxIntrinsicWidth:
          children[MapLayoutSlot.bottom]?.getMaxIntrinsicWidth(
            double.infinity,
          ) ??
          0,
      bandMinIntrinsicWidth:
          children[MapLayoutSlot.band]?.getMinIntrinsicWidth(double.infinity) ??
          0,
      padding: padding,
      reticleWidth: mapCenterReticleSize,
    );

    // 4. Les intrinsèques aux largeurs, puis la répartition.
    final MapLayoutAllocation allocation = allocateMapLayout(
      MapLayoutInput(
        available: mapLayoutAvailableHeight(
          safeHeight: safe.height,
          width: layout,
          sheetOpen: sheetOpen,
          padding: padding,
        ),
        width: layout,
        blockOverBottom: widths.blockOverBottom,
        bandFits: widths.bandFits,
        reticleUnderBlock: widths.reticleUnderBlock,
        designation: designation,
        sheetOpen: sheetOpen,
        blockFixed: heights(MapLayoutSlot.blockFixed, widths.block),
        notices: maxHeight(MapLayoutSlot.blockNotices, widths.block),
        legend: maxHeight(MapLayoutSlot.blockLegend, widths.block),
        bottom: heights(MapLayoutSlot.bottom, widths.bottom),
        // Une bande qui ne tient pas n'a pas de hauteur à dire :
        // `allocateMapLayout` la retire, fiche ouverte ou non (repli 6
        // étendu, arbitrages 14 et 23).
        band: designation && widths.bandFits
            ? heights(MapLayoutSlot.band, widths.band)
            : PieceHeights.none,
        reticleBand: designation ? _reticleBandHeight : 0,
        sheet: sheetOpen
            ? heights(MapLayoutSlot.sheet, widths.sheet)
            : PieceHeights.none,
        blockFixedFloor: _blockFixedFloor,
        // La troisième hauteur de la fiche (arbitrage 18), dite par la zone des
        // fiches et ses cadres (`sheetFeaturedHeightOf`, `shared`).
        sheetFeatured: sheetOpen
            ? sheetFeaturedHeightOf(
                children[MapLayoutSlot.sheet]!,
                widths.sheet,
              )
            : 0,
        sheetFirstRow: sheetOpen
            ? sheetFirstRowHeightOf(
                children[MapLayoutSlot.sheet]!,
                widths.sheet,
              )
            : 0,
        gap: padding,
      ),
    );
    _bandWithdrawn = allocation.bandWithdrawn;
    _row = compact;

    // 5. La pose. Une pièce absente vaut zéro.
    Size layoutChild(MapLayoutSlot slot, BoxConstraints constraints) {
      final RenderBox? child = children[slot];
      if (child == null) return Size.zero;
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    }

    void place(MapLayoutSlot slot, Offset offset) {
      final RenderBox? child = children[slot];
      if (child == null) return;
      (child.parentData! as MapLayoutParentData).offset = offset;
    }

    BoxConstraints widthAndMaxHeight(double width, double height) =>
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: math.max(0, height),
        );

    // La fiche d'abord : elle borne la carte visible, dont la largeur est
    // celle de `mapLayoutWidths` (la fiche du bas, ou aucune : la zone sûre ;
    // le panneau : la zone sûre moins lui).
    final double visibleRight = safe.left + widths.visible;
    final Rect visible;
    // La part que la fiche couvre, jusqu'au bord de la surface (`D4`, voir
    // [MapLayoutReport.covered]).
    EdgeInsets covered = EdgeInsets.zero;
    if (!sheetOpen) {
      layoutChild(MapLayoutSlot.sheet, BoxConstraints.tight(Size.zero));
      place(MapLayoutSlot.sheet, safe.bottomRight);
      visible = Rect.fromLTRB(safe.left, safe.top, visibleRight, safe.bottom);
    } else if (panel) {
      layoutChild(
        MapLayoutSlot.sheet,
        BoxConstraints.tight(Size(widths.sheet, safe.height)),
      );
      place(MapLayoutSlot.sheet, Offset(visibleRight, safe.top));
      covered = EdgeInsets.only(right: size.width - visibleRight);
      visible = Rect.fromLTRB(safe.left, safe.top, visibleRight, safe.bottom);
    } else {
      // Jamais plus haute que la zone sûre : la carte visible n'est jamais
      // négative, même en deçà.
      final Size sheet = layoutChild(
        MapLayoutSlot.sheet,
        widthAndMaxHeight(
          widths.sheet,
          math.min(allocation.sheet, safe.height),
        ),
      );
      final double top = safe.bottom - sheet.height;
      place(MapLayoutSlot.sheet, Offset(safe.left, top));
      // Posée à 0 px (en deçà des tailles garanties), elle ne couvre rien.
      if (sheet.height > 0) {
        covered = EdgeInsets.only(bottom: size.height - top);
      }
      visible = Rect.fromLTRB(safe.left, safe.top, visibleRight, top);
    }

    // Le bloc : les trois pièces, toujours posées, empilées sans écart.
    final double blockLeft = visible.left + padding;
    double blockBottom = visible.top + padding;
    double stackPiece(MapLayoutSlot slot, double height) {
      final Size piece = layoutChild(
        slot,
        widthAndMaxHeight(widths.block, height),
      );
      place(slot, Offset(blockLeft, blockBottom));
      return blockBottom += piece.height;
    }

    final double fixedBottom = stackPiece(
      MapLayoutSlot.blockFixed,
      allocation.blockFixed,
    );
    stackPiece(MapLayoutSlot.blockNotices, allocation.notices);
    stackPiece(MapLayoutSlot.blockLegend, allocation.legend);

    // Le bas : au bas de la carte visible, à la hauteur que la répartition
    // lui rend — entière, sauf la colonne en deçà des tailles garanties, qui
    // fait alors défiler ses boutons au-dessus de son attribution, pour la
    // partie fixe et sous l'en-tête de la fiche (arbitrages 22 et 24) ;
    // jamais au-dessus du haut de la carte visible. Là où même sa hauteur
    // repliée ne tient pas (garde-fou c de `D8`), la fiche passe devant la
    // colonne, la rangée du téléphone devant la fiche (ordre de peinture et
    // de toucher).
    final Size bottom = layoutChild(
      MapLayoutSlot.bottom,
      widthAndMaxHeight(widths.bottom, allocation.bottom),
    );
    final double bottomTop = math.max(
      visible.bottom - padding - bottom.height,
      visible.top + padding,
    );
    place(
      MapLayoutSlot.bottom,
      Offset(
        compact
            ? visible.left + padding
            : visible.right - padding - bottom.width,
        bottomTop,
      ),
    );

    // La bande : au-dessus de la rangée (compact), au bas de la carte visible
    // à gauche de la colonne (au-delà). Repli 6 : taille nulle.
    final Size band = layoutChild(
      MapLayoutSlot.band,
      _bandWithdrawn
          ? BoxConstraints.tight(Size.zero)
          : widthAndMaxHeight(widths.band, allocation.band),
    );
    final double bandBottom = compact && bottom.height > 0
        ? bottomTop - padding
        : visible.bottom - padding;
    final double bandTop = bandBottom - band.height;
    place(MapLayoutSlot.band, Offset(visible.left + padding, bandTop));

    // 6. Le réticule : centre horizontal de la carte visible ; milieu
    // vertical de [bas de la partie fixe ; haut de la bande]. Ni les avis ni
    // la légende n'y entrent.
    final bool reticleShown = designation && !_bandWithdrawn;
    final Size reticle = layoutChild(
      MapLayoutSlot.reticle,
      reticleShown
          ? BoxConstraints.loose(visible.size)
          : BoxConstraints.tight(Size.zero),
    );
    final Offset center = Offset(
      visible.center.dx,
      (fixedBottom + bandTop) / 2,
    );
    final Offset reticleOffset =
        center - Offset(reticle.width / 2, reticle.height / 2);
    place(MapLayoutSlot.reticle, reticleOffset);

    // 7. Le rapport.
    _schedulePublish(
      MapLayoutReport(
        visible: visible,
        reticle: reticleShown ? reticleOffset & reticle : null,
        allocation: allocation,
        covered: covered,
      ),
    );
  }

  /// Publie [next] après la trame, s'il diffère de ce que [_report] porte —
  /// jamais pendant la mise en page.
  void _schedulePublish(MapLayoutReport next) {
    _latest = next;
    if (_publishScheduled || _report.value == next) return;
    _publishScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _publishScheduled = false;
      final MapLayoutReport? latest = _latest;
      if (!attached || latest == null) return;
      _report.value = latest;
    }, debugLabel: 'MapLayout.report');
  }

  // --- Peinture, toucher, annonces --------------------------------------------

  /// Les emplacements dans l'ordre de peinture (voir l'en-tête du fichier),
  /// à la largeur de la colonne : la fiche devant le bas (arbitrage 22).
  static const List<MapLayoutSlot> _columnPaintOrder = <MapLayoutSlot>[
    MapLayoutSlot.bottom,
    MapLayoutSlot.sheet,
    MapLayoutSlot.blockFixed,
    MapLayoutSlot.blockNotices,
    MapLayoutSlot.blockLegend,
    MapLayoutSlot.band,
    MapLayoutSlot.reticle,
  ];

  /// Au téléphone : la rangée devant la fiche, comme avant `D8` —
  /// l'arbitrage 22 ne vaut qu'à la colonne, et l'attribution reste entière.
  static const List<MapLayoutSlot> _rowPaintOrder = <MapLayoutSlot>[
    MapLayoutSlot.sheet,
    MapLayoutSlot.blockFixed,
    MapLayoutSlot.blockNotices,
    MapLayoutSlot.blockLegend,
    MapLayoutSlot.bottom,
    MapLayoutSlot.band,
    MapLayoutSlot.reticle,
  ];

  /// L'ordre de peinture de la dernière mise en page.
  List<MapLayoutSlot> get _paintOrder =>
      _row ? _rowPaintOrder : _columnPaintOrder;

  /// Retirés par le repli 6 : ni peints, ni touchables, ni annoncés.
  bool _withdrawn(MapLayoutSlot slot) =>
      _bandWithdrawn &&
      switch (slot) {
        MapLayoutSlot.band || MapLayoutSlot.reticle => true,
        MapLayoutSlot.blockFixed ||
        MapLayoutSlot.blockNotices ||
        MapLayoutSlot.blockLegend ||
        MapLayoutSlot.bottom ||
        MapLayoutSlot.sheet => false,
      };

  @override
  bool paintsChild(RenderBox child) {
    final MapLayoutSlot? slot = (child.parentData! as MapLayoutParentData).slot;
    return slot == null || !_withdrawn(slot);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Map<MapLayoutSlot, RenderBox> children = _laidOut;
    for (final MapLayoutSlot slot in _paintOrder) {
      final RenderBox? child = children[slot];
      if (child == null || _withdrawn(slot)) continue;
      context.paintChild(
        child,
        offset + (child.parentData! as MapLayoutParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final Map<MapLayoutSlot, RenderBox> children = _laidOut;
    for (final MapLayoutSlot slot in _paintOrder.reversed) {
      final RenderBox? child = children[slot];
      if (child == null || _withdrawn(slot)) continue;
      final bool hit = result.addWithPaintOffset(
        offset: (child.parentData! as MapLayoutParentData).offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      final MapLayoutParentData data = child.parentData! as MapLayoutParentData;
      final MapLayoutSlot? slot = data.slot;
      if (slot == null || !_withdrawn(slot)) visitor(child);
      child = data.nextSibling;
    }
  }
}

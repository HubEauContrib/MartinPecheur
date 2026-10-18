// Le bloc de lecture de la carte, en TROIS PIÈCES (`B1` d'Ergonomie, cadrage
// du 2026-10-17, § 5.3) : la partie fixe (le sélecteur de lecture, puis
// l'en-tête `Légende · <lecture>` qui porte « ⚠ Avertissement »), les avis,
// la légende. Trois enfants de la mise en page de la carte (`D1`), posés l'un
// sous l'autre SANS ÉCART, qui dessinent ensemble UNE SEULE carte blanche :
// bord `#C9CFC4` (1 px), rayon 8, l'ombre de la pilule du bouton de
// désignation (`designate_center_button.dart`, la seule du code).
//
// Branché par `D2` : `buildMapOverlays` (`map_view.dart`) pose les trois
// pièces dans la mise en page de la carte (`map_layout.dart`).
//
// ## Les hauteurs que la mise en page interroge (note d'architecture)
//
// Chaque pièce dit deux hauteurs intrinsèques pour une largeur donnée, celles
// que la porte de faisabilité (`S6`) a mesurées sur les pièces SEULES — aucune
// marge interne n'est ajoutée :
// - [MapReadingBlockFixed] : `min` = le sélecteur replié (titres seuls) plus
//   l'en-tête, `max` = le sélecteur entier plus l'en-tête ;
// - [MapReadingBlockNotices] : `min` 0, `max` = les avis empilés nus ;
// - [MapReadingBlockLegend] : `min` 0, `max` = la légende.
// Aucun `LayoutBuilder`, aucun viewport de slivers (`ListView`,
// `CustomScrollView`) : ils lèvent une erreur sur une demande d'intrinsèques.
// Un défilement se fait par [SingleChildScrollView].
//
// ## Le défilement
//
// Les trois pièces défilent dans la hauteur qu'on leur donne, avec l'enveloppe
// des défilements de surcouche de la carte : `primary: false`, sans la barre
// que `MaterialScrollBehavior` pose sur un défilement vertical du bureau. La
// carte blanche ABSORBE les gestes posés sur sa surface (décision de la
// boucle principale, comme les cartes de légende et d'avis d'aujourd'hui) : le
// défilement, `HitTestBehavior.opaque` par défaut, couvre toute la boîte de la
// pièce, donc un tap ou un appui long dessus n'atteint pas la carte dessous
// (verrou : un défilement `deferToChild` ferait rougir le test des gestes).
//
// La partie fixe se replie D'ELLE-MÊME (repli 4) : posée avec une hauteur
// maximale inférieure à sa hauteur entière, elle efface les sous-titres du
// sélecteur ; posée sous sa hauteur repliée, elle défile. La grille du
// sélecteur décide du repli sur la hauteur MAXIMALE qu'elle reçoit — or un
// défilement la lui donne illimitée. La pièce transmet donc la hauteur qu'elle
// a reçue à la colonne qui est dans son défilement ([_FoldSignal]), qui la
// retranche de l'en-tête et pose le sélecteur sous la hauteur qui reste.
//
// ## La peinture sans couture
//
// Une seule règle, pour l'ombre, le fond et le bord : chaque pièce peint la
// carte ENTIÈRE — `card`, prolongée de `_openExtent` aux extrémités qu'elle ne
// ferme pas, de sorte qu'aucun bord ni aucune ombre n'apparaît à la jonction —
// et ne garde que SES rangées : la couche est rognée, SANS anticrénelage, à la
// boîte de la pièce. Deux rognages sans anticrénelage qui partagent un bord se
// répartissent les pixels sans trou ni recouvrement, à toute densité, à toute
// position (un bord entre deux pixels physiques, une hauteur fractionnaire) et
// dans l'ordre de peinture qu'on voudra : aucune des deux ne repeint un pixel
// de l'autre. (Des tranches anticrénelées qui se touchent laissent voir la
// carte, ou un trait plus clair, sur la rangée de la jonction.)
//
// ## Qui ferme le bas de la carte
//
// Le rayon et le bord du bas sont ceux de la DERNIÈRE pièce visible : la
// légende quand elle a une hauteur ; sinon les avis, sinon la partie fixe. La
// légende à hauteur 0 — le cas courant d'un téléphone fiche ouverte — ne peint
// rien et laisse à la pièce du dessus le soin de fermer la carte : c'est le
// rebord bas (bord, rayon, ombre) qui reste peint, sans pointe d'angle droit —
// un rayon ne se peint que dans la boîte de la pièce qui ferme, jamais par-
// dessus la pièce du dessus. Chaque pièce repère ses voisines : les autres
// pièces posées par la même mise en page (on monte tant que le parent n'a que
// cet enfant, un `SizedBox` ou un `Semantics` autour d'une pièce ne la cache
// donc pas). Une pièce qui n'en trouve aucune de plus basse reste ouverte,
// sauf la légende, qui ferme dès qu'elle a une hauteur. Les pièces ne sont pas
// des `RepaintBoundary` : ce que l'une repeint, les autres le repeignent avec
// elle.
//
// Le contenu est rogné par le rayon aux extrémités fermées : le bloc ne pose
// aucune marge, le sélecteur et la légende touchent le bord de la carte, et
// le rayon (8) est celui des entrées, dont le coin coïncide avec le sien.
//
// ## Ce que la mise en page (`D1`) doit à ces pièces
//
// - poser les TROIS pièces à chaque mise en page, y compris à hauteur 0 : une
//   pièce non posée garde un `size` périmé, et ses voisines la croiraient
//   visible ;
// - ni `RepaintBoundary` ni enveloppe à plusieurs enfants autour d'une pièce :
//   les voisines se cherchent parmi les pièces posées par la même mise en
//   page, au travers d'enveloppes à enfant unique seulement ;
// - les poser sans écart, à la largeur du bloc (la pièce prend toute la largeur
//   bornée qu'on lui donne).
//
// L'ordre de peinture est indifférent : la carte est la même, dans un sens
// comme dans l'autre.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart'
    show MapLegend, MapLegendHeader;
import 'package:martinpecheur/features/map/view/map_reading_selector.dart'
    show MapReadingSelector;
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show NoMinIntrinsicHeight;

/// Rayon des angles de la carte, en pixels logiques : 8, celui des entrées du
/// sélecteur (`_entryRadius`, `map_reading_selector.dart`). Le sélecteur touche
/// le bord de la carte, sans marge interne : avec un rayon de 8 le coin de
/// l'entrée du haut coïncide avec celui de la carte, plus rien n'est rogné et
/// aucune hauteur ne change. Un rayon de 14 rognait le coin de l'entrée. La marge
/// interne et le rayon de la maquette se constateront à la porte.
const double _cardRadius = 8;

/// Couleur du bord de la carte : celle des filets et des entrées éteintes.
const Color _cardBorderColor = Color(0xFFC9CFC4);

/// Épaisseur du bord de la carte, en pixels logiques.
const double _cardBorderWidth = 1;

/// L'ombre de la carte : celle de la pilule du bouton de désignation
/// (`designate_center_button.dart`), la seule du code.
const BoxShadow _cardShadow = BoxShadow(
  color: Color(0x40000000),
  blurRadius: 6,
  offset: Offset(0, 2),
);

/// Dépassement d'une extrémité OUVERTE : assez loin pour que ni son bord ni
/// son ombre n'apparaissent dans la boîte de la pièce.
const double _openExtent = 64;

/// Marge autour de la boîte où se peint l'ombre : le flou (jusqu'à 3 écarts
/// types) et le décalage.
const double _shadowMargin = 16;

/// Tolérance des comparaisons de hauteurs (même tolérance que
/// `allocateMapLayout`).
const double _heightEpsilon = 1e-6;

/// La partie fixe du bloc : le haut de la carte (rayon en haut), le sélecteur
/// de lecture puis l'en-tête de légende.
///
/// Intrinsèques : `min` = [selector] replié (titres seuls) plus [header],
/// `max` = [selector] entier plus [header], sans marge ajoutée. Posée avec une
/// hauteur maximale inférieure à `max`, elle efface les sous-titres du
/// sélecteur ; posée sous `min`, elle défile, « ⚠ Avertissement » atteignable
/// au glisser, à la molette et au clavier (le focus l'amène en vue).
///
/// L'ordre de tabulation (`mapTraversalOrderChips`) est posé par l'appelant
/// (`buildMapOverlays`, `D2`) : `selector` est typé, il ne peut pas être
/// enveloppé — c'est la pièce entière qui l'est, et le contrôle « ⚠
/// Avertissement », plus profond, y garde son propre ordre.
class MapReadingBlockFixed extends StatefulWidget {
  const MapReadingBlockFixed({
    required this.selector,
    required this.header,
    super.key,
  });

  /// Le sélecteur de lecture, tel que `D2` le construit.
  final MapReadingSelector selector;

  /// L'en-tête `Légende · <lecture>`, son « ⚠ Avertissement » compris.
  final MapLegendHeader header;

  @override
  State<MapReadingBlockFixed> createState() => _MapReadingBlockFixedState();
}

class _MapReadingBlockFixedState extends State<MapReadingBlockFixed> {
  final _FoldSignal _fold = _FoldSignal();

  @override
  void dispose() {
    _fold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BlockPiece(
      role: _PieceRole.fixed,
      fold: _fold,
      child: _BlockScroll(
        child: _FoldingColumn(
          signal: _fold,
          children: <Widget>[widget.selector, widget.header],
        ),
      ),
    );
  }
}

/// Les avis du bloc, entre l'en-tête et la légende : empilés nus, sans marge ni
/// écart, défilants dans la hauteur reçue (leur action, « Élargir la
/// recherche », s'atteint en faisant défiler).
///
/// Intrinsèques : `min` 0, `max` = les [notices] empilées. Aucun avis : hauteur
/// 0, rien n'est peint ni touchable.
///
/// L'ordre de tabulation de l'action (`mapTraversalOrderNotices`) est posé par
/// l'appelant sur les avis reçus.
class MapReadingBlockNotices extends StatelessWidget {
  const MapReadingBlockNotices({required this.notices, super.key});

  /// Les avis, déjà construits (`buildMapNotice`), dans l'ordre d'affichage.
  final List<Widget> notices;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return const _BlockPiece(
        role: _PieceRole.notices,
        child: SizedBox.shrink(),
      );
    }
    return _BlockPiece(
      role: _PieceRole.notices,
      child: NoMinIntrinsicHeight(
        child: _BlockScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: notices,
          ),
        ),
      ),
    );
  }
}

/// Le bas du bloc : la légende (rayon en bas), défilante dans la hauteur
/// reçue.
///
/// Intrinsèques : `min` 0, `max` = [legend]. À hauteur 0, la légende ne peint
/// rien ; le rebord bas de la carte (bord, rayon, ombre) reste peint — par la
/// dernière pièce visible (voir « Qui ferme le bas de la carte »).
class MapReadingBlockLegend extends StatelessWidget {
  const MapReadingBlockLegend({required this.legend, super.key});

  /// La légende « dans le bloc » (`MapLegend(inBlock: true)`).
  final MapLegend legend;

  @override
  Widget build(BuildContext context) {
    return _BlockPiece(
      role: _PieceRole.legend,
      child: NoMinIntrinsicHeight(child: _BlockScroll(child: legend)),
    );
  }
}

/// Un défilement de surcouche : `primary: false` et sans la `Scrollbar`
/// automatique du bureau, dont le `MouseRegion` est opaque sur toute la boîte.
/// Même retrait que `designate_center_button.dart` et `sheet_frame.dart`.
class _BlockScroll extends StatelessWidget {
  const _BlockScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(primary: false, child: child),
    );
  }
}

// --- Le repli de la partie fixe ----------------------------------------------

/// La hauteur que la pièce a reçue, transmise à la colonne qui est DANS son
/// défilement. Un défilement donne à son enfant une hauteur illimitée : la
/// colonne ne saurait pas, sans cela, qu'elle est posée sous sa hauteur
/// entière.
///
/// Mis à jour par la pièce pendant SA mise en page (dans
/// `invokeLayoutCallback`, qui autorise à marquer sale un descendant) ; la
/// colonne écoute et se remet en page. Illimitée (`double.infinity`) tant que
/// la pièce n'a pas de borne : rien ne se replie.
class _FoldSignal extends ChangeNotifier {
  double _available = double.infinity;

  double get available => _available;

  void update(double available) {
    if (available == _available) {
      return;
    }
    _available = available;
    notifyListeners();
  }
}

class _FoldingParentData extends ContainerBoxParentData<RenderBox> {}

/// Deux enfants, dans cet ordre : le sélecteur, puis l'en-tête.
class _FoldingColumn extends MultiChildRenderObjectWidget {
  const _FoldingColumn({required this.signal, required super.children});

  final _FoldSignal signal;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFoldingColumn(signal);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderFoldingColumn renderObject,
  ) {
    renderObject.signal = signal;
  }
}

/// Le sélecteur, puis l'en-tête dessous, sur toute la largeur. Quand la hauteur
/// que la pièce a reçue ([_FoldSignal.available]), moins l'en-tête, est
/// inférieure à la hauteur entière du sélecteur, celui-ci est posé sous sa
/// hauteur REPLIÉE : sa grille efface alors d'elle-même ses sous-titres (repli
/// 4, `map_reading_selector.dart`). L'en-tête, lui, reste entier.
///
/// Ses hauteurs intrinsèques ne dépendent pas de la hauteur reçue : `min` = le
/// sélecteur replié plus l'en-tête, `max` = le sélecteur entier plus l'en-tête.
class _RenderFoldingColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FoldingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FoldingParentData> {
  _RenderFoldingColumn(this._signal);

  _FoldSignal _signal;

  set signal(_FoldSignal value) {
    if (identical(value, _signal)) {
      return;
    }
    if (attached) {
      _signal.removeListener(markNeedsLayout);
    }
    _signal = value;
    if (attached) {
      _signal.addListener(markNeedsLayout);
    }
    markNeedsLayout();
  }

  RenderBox get _selector => firstChild!;
  RenderBox get _header => lastChild!;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _signal.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _signal.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FoldingParentData) {
      child.parentData = _FoldingParentData();
    }
  }

  /// Les contraintes du sélecteur à [width] de large, sous un en-tête de
  /// [headerHeight] : sa hauteur repliée en maximum quand la place manque pour
  /// l'entier, aucune borne de hauteur sinon.
  BoxConstraints _selectorConstraints(double width, double headerHeight) {
    final double room = _signal.available - headerHeight;
    final bool folds =
        room < _selector.getMaxIntrinsicHeight(width) - _heightEpsilon;
    return folds
        ? BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: _selector.getMinIntrinsicHeight(width),
          )
        : BoxConstraints.tightFor(width: width);
  }

  double _resolvedWidth(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : computeMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _selector.getMinIntrinsicWidth(height),
    _header.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _selector.getMaxIntrinsicWidth(height),
    _header.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _selector.getMinIntrinsicHeight(width) +
      _header.getMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _selector.getMaxIntrinsicHeight(width) +
      _header.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double width = _resolvedWidth(constraints);
    final Size header = _header.getDryLayout(
      BoxConstraints.tightFor(width: width),
    );
    final Size selector = _selector.getDryLayout(
      _selectorConstraints(width, header.height),
    );
    return constraints.constrain(Size(width, selector.height + header.height));
  }

  @override
  void performLayout() {
    final double width = _resolvedWidth(constraints);
    _header.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final double headerHeight = _header.size.height;
    _selector.layout(
      _selectorConstraints(width, headerHeight),
      parentUsesSize: true,
    );
    (_selector.parentData! as _FoldingParentData).offset = Offset.zero;
    (_header.parentData! as _FoldingParentData).offset = Offset(
      0,
      _selector.size.height,
    );
    size = constraints.constrain(
      Size(width, _selector.size.height + headerHeight),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// --- La carte blanche --------------------------------------------------------

/// La place d'une pièce dans la carte, de haut en bas. L'ordre de déclaration
/// EST l'ordre vertical : [_RenderBlockPiece] compare les index.
enum _PieceRole { fixed, notices, legend }

/// Une pièce : sa tranche de la carte blanche (ombre, fond, bord), son contenu
/// rogné par le rayon.
class _BlockPiece extends SingleChildRenderObjectWidget {
  const _BlockPiece({required this.role, required super.child, this.fold});

  final _PieceRole role;

  /// Le canal vers la colonne de repli, pour la seule partie fixe.
  final _FoldSignal? fold;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlockPiece(role: role, fold: fold);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBlockPiece renderObject,
  ) {
    renderObject
      ..role = role
      ..fold = fold;
  }
}

/// Les extrémités que la pièce ferme : le haut (rayon et bord du haut), le bas
/// (rayon, bord et ombre du bas).
class _CardEnds {
  const _CardEnds({required this.top, required this.bottom});

  final bool top;
  final bool bottom;
}

class _RenderBlockPiece extends RenderProxyBox {
  _RenderBlockPiece({required this._role, this._fold});

  _PieceRole _role;
  _FoldSignal? _fold;
  final LayerHandle<ClipRRectLayer> _contentClip =
      LayerHandle<ClipRRectLayer>();

  set role(_PieceRole value) {
    if (value == _role) {
      return;
    }
    _role = value;
    markNeedsPaint();
  }

  set fold(_FoldSignal? value) {
    if (identical(value, _fold)) {
      return;
    }
    _fold = value;
    markNeedsLayout();
  }

  /// La pièce prend toute la largeur reçue : c'est une tranche de carte, qui
  /// s'aligne sur ses voisines même posée sous des contraintes lâches.
  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? constraints.tighten(width: constraints.maxWidth)
      : constraints;

  /// La mise en page à vide, qui ne dépend pas de la dernière vraie : sous un
  /// repli ([_fold] non nul), la hauteur est celle que `performLayout` donnera
  /// sous ces contraintes — la hauteur entière du contenu si la hauteur
  /// maximale la contient, sa hauteur repliée sinon. Elle se lit sur les
  /// intrinsèques de l'enfant : le sélecteur replié vaut son `min` intrinsèque.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    final BoxConstraints inner = _childConstraints(constraints);
    final Size dry = child.getDryLayout(inner);
    if (_fold == null) {
      return constraints.constrain(dry);
    }
    final double full = child.getMaxIntrinsicHeight(dry.width);
    final double folded = child.getMinIntrinsicHeight(dry.width);
    return constraints.constrain(
      Size(
        dry.width,
        constraints.maxHeight >= full - _heightEpsilon ? full : folded,
      ),
    );
  }

  @override
  void performLayout() {
    final BoxConstraints own = constraints;
    final _FoldSignal? fold = _fold;
    if (fold != null && fold.available != own.maxHeight) {
      invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
        fold.update(own.maxHeight);
      });
    }
    final RenderBox? child = this.child;
    if (child == null) {
      size = own.smallest;
      return;
    }
    child.layout(_childConstraints(own), parentUsesSize: true);
    size = own.constrain(child.size);
  }

  // --- Les voisines ----------------------------------------------------------

  /// Les autres pièces du bloc : celles qui sont posées par la même mise en
  /// page. On monte de parent en parent tant que le parent n'a que cet enfant
  /// (un `SizedBox`, un `Padding`, un `Semantics` autour de la pièce ne la
  /// cachent pas), jusqu'à la mise en page qui en a plusieurs ; on y cherche
  /// les pièces, chacune en descendant par ses enveloppes à enfant unique.
  List<_RenderBlockPiece> _siblings() {
    RenderObject? layout = parent;
    while (layout != null && _children(layout).length <= 1) {
      layout = layout.parent;
    }
    if (layout == null) {
      return const <_RenderBlockPiece>[];
    }
    return <_RenderBlockPiece>[
      for (final RenderObject child in _children(layout))
        if (_pieceWithin(child) case final _RenderBlockPiece piece
            when !identical(piece, this))
          piece,
    ];
  }

  static List<RenderObject> _children(RenderObject node) {
    final List<RenderObject> children = <RenderObject>[];
    node.visitChildren(children.add);
    return children;
  }

  /// La pièce que [node] enveloppe, ou `null` : [node] lui-même, ou ce que sa
  /// chaîne d'enfants uniques contient.
  static _RenderBlockPiece? _pieceWithin(RenderObject node) {
    RenderObject current = node;
    while (true) {
      if (current is _RenderBlockPiece) {
        return current;
      }
      final List<RenderObject> children = _children(current);
      if (children.length != 1) {
        return null;
      }
      current = children.single;
    }
  }

  bool get _visible => hasSize && size.height > 0;

  /// Les extrémités de la carte que cette pièce ferme.
  _CardEnds _ends() {
    final List<_RenderBlockPiece> siblings = _siblings();
    final List<_RenderBlockPiece> below = <_RenderBlockPiece>[
      for (final _RenderBlockPiece other in siblings)
        if (other._role.index > _role.index) other,
    ];
    // Ferme le bas : visible, et SÛRE que toutes les pièces plus basses sont
    // là et vides — une pièce qui n'en voit aucune reste ouverte.
    final bool lowest =
        _visible &&
        below.isNotEmpty &&
        below.every((_RenderBlockPiece other) => !other._visible);
    return switch (_role) {
      _PieceRole.fixed => _CardEnds(top: true, bottom: lowest),
      _PieceRole.notices => _CardEnds(top: false, bottom: lowest),
      _PieceRole.legend => _CardEnds(top: false, bottom: _visible),
    };
  }

  // --- La peinture -----------------------------------------------------------

  static RRect _shape(
    Rect rect, {
    required double topRadius,
    required double bottomRadius,
  }) => RRect.fromRectAndCorners(
    rect,
    topLeft: Radius.circular(topRadius),
    topRight: Radius.circular(topRadius),
    bottomLeft: Radius.circular(bottomRadius),
    bottomRight: Radius.circular(bottomRadius),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      _contentClip.layer = null;
      return;
    }
    final _CardEnds ends = _ends();
    final Rect box = offset & size;
    final double topRadius = ends.top
        ? math.min(_cardRadius, size.height / (ends.bottom ? 2 : 1))
        : 0;
    final double bottomRadius = ends.bottom
        ? math.min(_cardRadius, size.height / (ends.top ? 2 : 1))
        : 0;
    // La carte ENTIÈRE, prolongée au-delà des extrémités ouvertes : aucun bord
    // ni aucune ombre ne s'y montre aux jonctions. Chaque couche ne garde que
    // les rangées de la pièce (« La peinture sans couture »).
    final RRect card = _shape(
      Rect.fromLTRB(
        box.left,
        box.top - (ends.top ? 0 : _openExtent),
        box.right,
        box.bottom + (ends.bottom ? 0 : _openExtent),
      ),
      topRadius: topRadius,
      bottomRadius: bottomRadius,
    );

    _paintShadow(context.canvas, box, card, ends);
    _paintFill(context.canvas, box, card, ends);
    _paintContent(context, offset, ends, topRadius, bottomRadius);
    // Le canevas est relu : pousser le rognage du contenu a changé de couche.
    _paintBorder(context.canvas, box, card, ends);
  }

  /// Les rangées de la pièce : sa boîte, élargie de [side] sur les côtés et de
  /// [end] aux seules extrémités FERMÉES — jamais aux ouvertes, où commence la
  /// pièce voisine.
  static Rect _rows(
    Rect box,
    _CardEnds ends, {
    double side = 0,
    double end = 0,
  }) => Rect.fromLTRB(
    box.left - side,
    box.top - (ends.top ? end : 0),
    box.right + side,
    box.bottom + (ends.bottom ? end : 0),
  );

  /// Peint [draw] rogné à [rows], sans anticrénelage : la pièce voisine, qui
  /// rogne de même à son bord, se répartit avec elle les pixels de la
  /// jonction.
  static void _clipped(Canvas canvas, Rect rows, VoidCallback draw) {
    canvas
      ..save()
      ..clipRect(rows, doAntiAlias: false);
    draw();
    canvas.restore();
  }

  /// L'ombre de la carte, dans les rangées de la pièce élargies du flou sur
  /// les côtés et sur les extrémités fermées. Sous le fond, qui la recouvre
  /// dans l'intérieur de la carte.
  void _paintShadow(Canvas canvas, Rect box, RRect card, _CardEnds ends) {
    _clipped(
      canvas,
      _rows(box, ends, side: _shadowMargin, end: _shadowMargin),
      () => canvas.drawRRect(
        card.shift(_cardShadow.offset),
        _cardShadow.toPaint(),
      ),
    );
  }

  void _paintFill(Canvas canvas, Rect box, RRect card, _CardEnds ends) {
    _clipped(
      canvas,
      _rows(box, ends, side: _cardBorderWidth, end: _cardBorderWidth * 2),
      () => canvas.drawRRect(card, Paint()..color = Colors.white),
    );
  }

  /// Le contenu, rogné par le rayon aux extrémités fermées.
  void _paintContent(
    PaintingContext context,
    Offset offset,
    _CardEnds ends,
    double topRadius,
    double bottomRadius,
  ) {
    if (!ends.top && !ends.bottom) {
      _contentClip.layer = null;
      super.paint(context, offset);
      return;
    }
    final Rect local = Offset.zero & size;
    _contentClip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      local,
      _shape(local, topRadius: topRadius, bottomRadius: bottomRadius),
      super.paint,
      oldLayer: _contentClip.layer,
    );
  }

  /// Le bord, peint PAR-DESSUS le contenu : un contenu qui touche le bord ne le
  /// cache pas.
  void _paintBorder(Canvas canvas, Rect box, RRect card, _CardEnds ends) {
    _clipped(
      canvas,
      _rows(box, ends, side: _cardBorderWidth, end: _cardBorderWidth * 2),
      () => canvas.drawDRRect(
        card,
        card.deflate(_cardBorderWidth),
        Paint()..color = _cardBorderColor,
      ),
    );
  }

  @override
  void dispose() {
    _contentClip.layer = null;
    super.dispose();
  }
}

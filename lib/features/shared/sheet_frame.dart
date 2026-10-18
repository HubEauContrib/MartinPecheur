// Le cadre commun des trois fiches — station, point ONDE, tronçon de
// vigilance (`S3` d'Ergonomie, arbitrage 3, spec § 6.1) : un EN-TÊTE ÉPINGLÉ
// qui ne défile pas, et un CORPS qui défile dessous.
//
// L'en-tête porte, de haut en bas : la rangée « nature · étoile · fermeture »
// (la nature se replie sur la largeur, jamais d'ellipse), le contrôle
// « ⚠ Avertissement » (`W3c`, présent dans tous les états d'une fiche), puis
// l'avis d'échec d'écriture du favori quand il y en a un. Il ne cède jamais à
// un repli (spec § 5.6) : c'est le corps qui défile quand la place manque.
//
// ⚠️ Ce que la mise en page de la carte (`D1`) interroge, sans `LayoutBuilder`
// (note d'architecture du plan, point 1, amendé par `D7`) — TROIS hauteurs :
// - `getMinIntrinsicHeight` = l'en-tête SEUL : le corps n'y compte pas ;
// - la hauteur MISE EN AVANT (arbitrage 18, [RenderSheetFeaturedHeight], lue
//   par [sheetFeaturedHeightOf]) = l'en-tête, la marge haute du corps et la
//   hauteur intrinsèque minimale du corps. Dans un corps, le `min` intrinsèque
//   EST la mesure mise en avant et ce qui la précède : la fiche enveloppe ce
//   qui la suit dans [NoMinIntrinsicHeight]. Un corps qui ne marque rien (un
//   état « en cours », « en échec ») est entier ; la marge basse n'y entre pas ;
// - `getMaxIntrinsicHeight` = l'en-tête et le corps ENTIER.
// Rien, dans le cadre, ne lève d'erreur sur une demande d'intrinsèques : un
// défilement s'y fait par `SingleChildScrollView`, jamais par un `ListView` ni
// un autre `Viewport`. Le CONTRAT vaut aussi pour le `body` que la fiche
// fournit (voir [SheetFrame.body]) : le cadre ne peut pas le garantir pour lui.
//
// Un filet (`#C9CFC4`, § 6.1) sépare l'en-tête du corps, peint dans la boîte de
// l'en-tête sans en changer la hauteur. Entre l'étoile et la fermeture, 8 px :
// l'écart de l'amendement `S7b`, qui était VERTICAL (l'étoile sous la
// fermeture), transposé sur la rangée — un choix de la boucle principale sur le
// croquis du § 6.1.
//
// L'en-tête et le corps sont posés par [_RenderSheetFrameColumn], qui dit les
// trois hauteurs et pose comme la `Column` de taille minimale d'avant `D7` (un
// en-tête fixe, puis un `Flexible`) : sous une hauteur BORNÉE (la fiche du bas,
// le panneau latéral), le corps prend ce que l'en-tête laisse et défile ; sous
// une hauteur NON bornée (un parent qui défile), il se pose à sa hauteur
// entière — un test de ce fichier le verrouille. L'en-tête est toujours posé
// entier : sous lui, rien (en deçà des tailles garanties, la zone des fiches
// rogne).
//
// Aucune tranche importée (`shared-sans-tranche`) : le cadre reçoit tout par
// paramètre, jusqu'à la clé du bouton de fermeture, que chaque fiche garde
// dans son propre fichier (`stationSheetCloseButtonKey`, …).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Clé de l'en-tête épinglé : nature, étoile, fermeture, « ⚠ Avertissement »
/// et l'avis d'échec d'écriture. C'est elle que les tests mesurent.
const Key sheetFrameHeaderKey = Key('sheet-frame-header');

/// Clé du défilement du corps.
const Key sheetFrameBodyKey = Key('sheet-frame-body');

/// Libellé annoncé du bouton de fermeture, le même sur les trois fiches.
const String sheetCloseLabel = 'Fermer la fiche';

/// La nature de la fiche : 12, gras, `#3A4148` (spec § 6.1).
const TextStyle _natureStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  color: Color(0xFF3A4148),
);

/// Couleur du filet sous l'en-tête : celle des filets déjà en usage
/// (`flood_warning_card.dart`, `reinforced_warning_card.dart`).
const Color _ruleColor = Color(0xFFC9CFC4);

/// Marges de l'en-tête : celles de l'ancien cadre (12), sans bas — le contrôle
/// « ⚠ Avertissement » a déjà sa cible de [minimumTapTarget] (44, 48 sous
/// Android).
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(12, 12, 12, 0);

/// Marges du corps : 12 de chaque côté et en bas, un peu d'air sous l'en-tête.
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

/// Une boîte qui dit, à une largeur, la hauteur d'une fiche « mise en avant »
/// (arbitrage 18) : son en-tête et la mesure mise en avant de son corps, avec
/// ce qui la précède. La troisième hauteur d'une fiche, entre la hauteur
/// repliée (`getMinIntrinsicHeight`, l'en-tête seul) et la hauteur entière
/// (`getMaxIntrinsicHeight`). [SheetFrame] la dit ; la zone des fiches de la
/// carte la dit pour ses panneaux. Elle se lit par [sheetFeaturedHeightOf].
abstract interface class RenderSheetFeaturedHeight {
  /// La hauteur mise en avant à [width] de large.
  double featuredHeight(double width);
}

/// La hauteur mise en avant de [box] à [width] de large (arbitrage 18) :
/// - celle que [box] dit, s'il est une [RenderSheetFeaturedHeight] ;
/// - celle de son enfant, si [box] est une enveloppe à enfant unique
///   ([RenderProxyBox]) qui garde les deux hauteurs intrinsèques de cet
///   enfant — le fond de `Material`, un `CustomPaint`, un `SizedBox` sans
///   taille ;
/// - sinon, sa hauteur intrinsèque minimale : rien n'est mis en avant au-delà
///   de sa hauteur repliée (une fiche fermée, une pièce de test, une
///   enveloppe qui change les hauteurs de ce qu'elle porte).
double sheetFeaturedHeightOf(RenderBox box, double width) {
  RenderBox current = box;
  while (true) {
    if (current is RenderSheetFeaturedHeight) {
      return (current as RenderSheetFeaturedHeight).featuredHeight(width);
    }
    final RenderBox? child = current is RenderProxyBox ? current.child : null;
    if (child == null || !_keepsHeights(current, child, width)) {
      return box.getMinIntrinsicHeight(width);
    }
    current = child;
  }
}

/// [wrapper] dit, à [width], les deux hauteurs intrinsèques de [child].
bool _keepsHeights(RenderBox wrapper, RenderBox child, double width) =>
    (wrapper.getMinIntrinsicHeight(width) - child.getMinIntrinsicHeight(width))
            .abs() <=
        _heightEpsilon &&
    (wrapper.getMaxIntrinsicHeight(width) - child.getMaxIntrinsicHeight(width))
            .abs() <=
        _heightEpsilon;

/// L'écart que la comparaison des hauteurs ignore : celui de
/// `allocateMapLayout`.
const double _heightEpsilon = 1e-6;

/// Une enveloppe qui annonce 0 de hauteur intrinsèque MINIMALE et transmet le
/// reste à son enfant : largeurs intrinsèques, hauteur intrinsèque maximale,
/// mise en page, peinture et touchers.
///
/// C'est ce qui fait d'un contenu une pièce qui PEUT céder : sa hauteur
/// « repliée » est nulle, sa hauteur « entière » est celle de son contenu. Le
/// bloc de lecture de la carte en enveloppe ses avis et sa légende ; une fiche,
/// depuis `D7`, ce qui suit sa mesure mise en avant dans son corps (arbitrage
/// 18) — la hauteur mise en avant de [SheetFrame] s'arrête là.
class NoMinIntrinsicHeight extends SingleChildRenderObjectWidget {
  const NoMinIntrinsicHeight({required Widget child, super.key})
    : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoMinIntrinsicHeight();
}

class _RenderNoMinIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;
}

/// Le cadre commun d'une fiche : en-tête épinglé ([nature], étoile,
/// fermeture, « ⚠ Avertissement », avis d'échec d'écriture) et [body]
/// défilant dessous.
///
/// - [closeButtonKey] : la clé que la fiche pose sur son bouton de fermeture
///   (`stationSheetCloseButtonKey`, …) — le cadre ne la connaît pas.
/// - [warningExtraText] : la phrase propre à la fiche, sous le texte général
///   de la fenêtre d'avertissement ; `null` sans date à donner.
/// - [favoriteStar] et [onToggleFavorite] : l'étoile, ensemble ou pas du tout.
///   `null`, aucun emplacement vide (la fiche tronçon, avant T5).
/// - [bodyScrollController] : la position du corps, que l'appelant remet à
///   zéro à chaque ouverture (`K4` de T3).
///
/// Ordre de tabulation : l'étoile est un arrêt ; la fermeture n'en est pas un
/// (`Échap` ferme).
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    required this.nature,
    required this.closeButtonKey,
    required this.onClose,
    required this.body,
    this.warningExtraText,
    this.favoriteStar,
    this.onToggleFavorite,
    this.bodyScrollController,
    super.key,
  }) : assert(
         favoriteStar == null || onToggleFavorite != null,
         "Une étoile sans onToggleFavorite n'a rien à basculer.",
       );

  /// La ligne de nature : « Station hydrométrique · K447001001 »,
  /// « Point ONDE », « Tronçon Vigicrues ». Elle se replie sur la largeur.
  final String nature;

  /// La clé du bouton de fermeture, fournie par la fiche.
  final Key closeButtonKey;

  /// Appelée par le bouton de fermeture.
  final VoidCallback onClose;

  /// Le contenu défilant, sous l'en-tête.
  ///
  /// Il doit LUI-MÊME répondre aux demandes de dimensions intrinsèques, que la
  /// mise en page de la carte adresse au cadre entier : ni `LayoutBuilder`, ni
  /// `ListView`, ni aucun autre `Viewport` dans ce sous-arbre (ils lèvent une
  /// erreur sur une telle demande). Une décision qui dépend de la largeur se
  /// prend dans un `RenderObject` qui sait calculer ses intrinsèques ; un
  /// défilement interne, par `SingleChildScrollView`.
  ///
  /// Sa hauteur intrinsèque MINIMALE est sa mesure mise en avant, avec ce qui
  /// la précède (arbitrage 18) : ce qui la suit s'enveloppe dans
  /// [NoMinIntrinsicHeight]. Un corps qui n'enveloppe rien est mis en avant
  /// tout entier — c'est le cas des états sans mesure, courts.
  final Widget body;

  /// La phrase datée de la fenêtre « ⚠ Avertissement », ou `null`.
  final String? warningExtraText;

  /// L'étoile de favori telle qu'elle s'affiche, ou `null` : pas d'étoile.
  final FavoriteStar? favoriteStar;

  /// Ce que fait un tap sur l'étoile ; requis dès que [favoriteStar] est là.
  final VoidCallback? onToggleFavorite;

  /// Le contrôleur de défilement du corps, ou `null`.
  final ScrollController? bodyScrollController;

  @override
  Widget build(BuildContext context) {
    final FavoriteStar? star = favoriteStar;
    final VoidCallback? toggle = onToggleFavorite;
    return Material(
      elevation: 4,
      color: Colors.white,
      child: _SheetFrameColumn(
        children: <Widget>[
          // Le filet du § 6.1 : une bordure basse, pleine largeur, peinte DANS
          // la boîte de l'en-tête. Un `DecoratedBox` et non un `Container`, qui
          // ajouterait l'épaisseur de la bordure en marge de son enfant :
          // aucune hauteur ne change, ni celle de l'en-tête ni les intrinsèques.
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _ruleColor)),
            ),
            child: Padding(
              key: sheetFrameHeaderKey,
              padding: _headerPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(nature, style: _natureStyle)),
                      if (star != null && toggle != null) ...<Widget>[
                        FavoriteStarButton(star: star, onToggle: toggle),
                        // 8 px entre l'étoile et la fermeture : deux actions
                        // opposées dont les cibles ne se touchent pas. C'est
                        // l'écart de l'amendement `S7b` (`docs/04-ui.md`,
                        // vertical : l'étoile sous la fermeture), transposé
                        // sur la rangée — choix de la boucle principale sur
                        // le croquis du § 6.1. Sans étoile, pas de boîte vide.
                        const SizedBox(width: 8),
                      ],
                      _CloseButton(buttonKey: closeButtonKey, onClose: onClose),
                    ],
                  ),
                  WarningLink(extraText: warningExtraText),
                  // `FavoriteStar` ne dit que `writeFailed` : la forme de
                  // l'étoile reste celle d'avant l'échec — pleine, c'est un
                  // retrait qui a échoué, vide un ajout. Une liste illisible
                  // (étoile inactive, sans `writeFailed`) ne laisse aucune
                  // phrase ici : l'écran « Favoris » l'explique.
                  if (star != null && star.writeFailed)
                    FavoriteWriteFailedNotice(
                      star.filled
                          ? favoriteRemoveFailedText
                          : favoriteWriteFailedText,
                    ),
                ],
              ),
            ),
          ),
          // Sans la barre de défilement que `MaterialScrollBehavior` pose sur
          // un défilement vertical des cibles de bureau : sa `MouseRegion` est
          // opaque sur toute la boîte, et le corps d'une fiche n'a pas à en
          // porter une. Même retrait que `data_sources_view.dart`.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: SingleChildScrollView(
              key: sheetFrameBodyKey,
              controller: bodyScrollController,
              // Un contrôleur propre ou, à défaut, aucun : jamais le
              // contrôleur primaire de l'écran, que ce corps n'a pas à capter
              // sur le bureau.
              primary: false,
              padding: _bodyPadding,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// L'en-tête puis le corps défilant d'un [SheetFrame] : deux enfants, dans cet
/// ordre.
class _SheetFrameColumn extends MultiChildRenderObjectWidget {
  const _SheetFrameColumn({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSheetFrameColumn();
}

class _SheetFrameParentData extends ContainerBoxParentData<RenderBox> {}

/// Pose l'en-tête entier, puis le corps sous lui dans ce qui reste, sur toute
/// la largeur — la pose de la `Column` de taille minimale d'avant `D7`, un
/// en-tête fixe puis un `Flexible` lâche. Dit les trois hauteurs d'une fiche
/// (voir l'en-tête du fichier) : `min` = l'en-tête, mise en avant = l'en-tête
/// et la mesure mise en avant du corps, `max` = l'en-tête et le corps entier.
class _RenderSheetFrameColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SheetFrameParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SheetFrameParentData>
    implements RenderSheetFeaturedHeight {
  RenderBox get _header => firstChild!;
  RenderBox get _body => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SheetFrameParentData) {
      child.parentData = _SheetFrameParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _header.getMinIntrinsicWidth(double.infinity),
    _body.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _header.getMaxIntrinsicWidth(double.infinity),
    _body.getMaxIntrinsicWidth(double.infinity),
  );

  /// L'en-tête seul : le corps cède tout entier.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _header.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _header.getMaxIntrinsicHeight(width) + _body.getMaxIntrinsicHeight(width);

  /// L'en-tête, puis, si le corps met quelque chose en avant, sa marge haute
  /// et sa hauteur minimale — sa mesure mise en avant et ce qui la précède. La
  /// marge basse n'y entre pas : la mesure finit au bas de la fiche.
  @override
  double featuredHeight(double width) {
    final double featured =
        _body.getMinIntrinsicHeight(width) - _bodyPadding.vertical;
    return _header.getMinIntrinsicHeight(width) +
        (featured > 0 ? _bodyPadding.top + featured : 0);
  }

  /// Les contraintes d'un enfant : toute la largeur bornée, au plus
  /// [maxHeight] de haut.
  static BoxConstraints _childConstraints(
    BoxConstraints constraints,
    double maxHeight,
  ) => constraints.hasBoundedWidth
      ? BoxConstraints(
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
          maxHeight: maxHeight,
        )
      : BoxConstraints(maxHeight: maxHeight);

  /// Pose — ou mesure à sec, si [dry] — l'en-tête puis le corps, et rend la
  /// taille du cadre.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    Size place(RenderBox child, BoxConstraints inner) {
      if (dry) return child.getDryLayout(inner);
      child.layout(inner, parentUsesSize: true);
      return child.size;
    }

    final Size header = place(
      _header,
      _childConstraints(constraints, double.infinity),
    );
    final Size body = place(
      _body,
      _childConstraints(
        constraints,
        constraints.hasBoundedHeight
            ? math.max(0, constraints.maxHeight - header.height)
            : double.infinity,
      ),
    );
    if (!dry) {
      (_header.parentData! as _SheetFrameParentData).offset = Offset.zero;
      (_body.parentData! as _SheetFrameParentData).offset = Offset(
        0,
        header.height,
      );
    }
    return constraints.constrain(
      Size(math.max(header.width, body.width), header.height + body.height),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Le bouton de fermeture, dimensionné à [minimumTapTarget] par un
/// `SizedBox` explicite et non par les valeurs par défaut d'un bouton
/// Material : la taille est alors une propriété du code, mesurable par test
/// (`04-ui.md` § 3), pas un effet de thème. Repris tel quel des fiches, où il
/// existait en trois copies (station, ONDE, tronçon).
///
/// Pas un arrêt de tabulation : un `GestureDetector` ne prend pas le focus, et
/// `Échap` ferme déjà la fiche.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.buttonKey, required this.onClose});

  final Key buttonKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: sheetCloseLabel,
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SizedBox(
          width: minimumTapTarget,
          height: minimumTapTarget,
          child: const Center(child: Icon(Icons.close)),
        ),
      ),
    );
  }
}

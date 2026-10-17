// Le bouton « Restrictions au centre de la carte » (`E1` de T2), refait selon
// le canvas de design validé par le commanditaire le 2026-09-29 : il sort de
// la colonne des contrôles (`MapControls`) — une quatrième icône ronde,
// identique aux autres, ne disait pas ce qu'elle faisait — pour devenir un
// bouton large et libellé, en bas au centre de la carte, avec dessous
// l'indice du geste équivalent (appui long au toucher, clic droit à la
// souris).
//
// Il n'existe que dans le MODE de désignation (`E5`, 2026-10-03) : le choix
// « Restrictions » du sélecteur (`map_scale_chips.dart`) le fait apparaître,
// avec son indice et le réticule, et le retire. Il n'est plus permanent.
//
// Comme [MapControls], c'est un widget de CONTENU pur : il ne connaît ni la
// caméra ni le ViewModel. `_MapViewState` construit le rappel.
//
// [DesignationBand] (`S4` d'Ergonomie) est la bande du bouton refaite en pièce
// autonome pour la mise en page de la carte (`D1`, `D2`) : la pilule et
// l'indice, le défilement et le repli de l'indice dedans. Construite SEULE à ce
// stade — `map_view.dart` pose encore [DesignateCenterControl] dans
// `_DesignationPlacement` —, `D2` la branche à leur place.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Clé du bouton « Restrictions au centre de la carte » (`E1` de T2).
const Key mapDesignateCenterButtonKey = Key('map-designate-center');

/// Clé de l'indice de geste posé sous le bouton.
const Key mapDesignateCenterHintKey = Key('map-designate-center-hint');

/// Libellé visible ET annoncé du bouton.
const String designateCenterLabel = 'Restrictions au centre de la carte';

/// Hauteur minimale du bouton : au-delà de [minimumTapTarget], quelle que
/// soit la plateforme (canvas de design du 2026-09-29).
const double designateCenterButtonHeight = 52;

/// Écart entre le bouton et son indice.
const double designateCenterGap = 6;

/// Le bouton et son indice, empilés et centrés. Un seul widget pour que les
/// deux ne soient jamais posés l'un sans l'autre (l'indice sans le bouton
/// décrirait une alternative à rien).
class DesignateCenterControl extends StatelessWidget {
  const DesignateCenterControl({required this.onDesignate, super.key});

  /// Appelé par un tap, Entrée ou Espace : la désignation du centre de la
  /// carte. Non nul : sans désignation branchée, l'appelant n'affiche pas ce
  /// widget (un bouton mort serait pire qu'aucun bouton).
  final VoidCallback onDesignate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        DesignateCenterButton(onTap: onDesignate),
        const SizedBox(height: designateCenterGap),
        const DesignateCenterHint(),
      ],
    );
  }
}

/// La bande du bouton de désignation (`S4` d'Ergonomie) : la pilule
/// ([DesignateCenterButton]) puis l'indice ([DesignateCenterHint]), centrés
/// sur la largeur qu'on leur donne. Une pièce autonome, que la mise en page de
/// la carte (`D1`) posera : elle n'a pas de marge, c'est la mise en page qui
/// dégage l'attribution IGN et les colonnes.
///
/// Elle reprend le comportement de la bande de `_DesignationPlacement`
/// (`map_view.dart`) : la pilule est dans un [SingleChildScrollView] qui
/// défile quand la hauteur manque, `primary: false` (aucun contrôleur
/// hérité), `HitTestBehavior.deferToChild` et sans la barre de défilement
/// automatique du bureau — dont le `MouseRegion` est opaque sur toute la
/// boîte —, de sorte qu'un tap, un appui long, un clic droit, un glisser ou
/// un cran de molette posés dans la bande, à côté de la pilule et de
/// l'indice, atteignent la carte dessous.
///
/// Repli 5 (note d'architecture du plan d'Ergonomie), LOCAL : elle dit deux
/// hauteurs intrinsèques, pour la largeur donnée.
/// - `getMaxIntrinsicHeight` : sa hauteur ENTIÈRE, la pilule, [designateCenterGap]
///   et l'indice ;
/// - `getMinIntrinsicHeight` : sa hauteur REPLIÉE, la pilule seule.
/// Posée avec une hauteur maximale inférieure à la première, elle efface
/// l'indice d'elle-même — ni peint, ni touchable. Le bouton, lui, reste entier
/// et actif ; seul disparaît le rappel du geste équivalent, que le lecteur
/// d'écran n'a jamais reçu ([DesignateCenterHint] est hors sémantique). Une
/// seule variante est montée : l'indice reste dans l'arbre, ses intrinsèques
/// restent lisibles et la décision ne va-et-vient pas d'une trame à l'autre.
///
/// L'indice est un frère du défilement et non son enfant : il n'est jamais
/// affiché qu'avec assez de place pour tout, donc il n'a rien à y défiler ;
/// c'est la pilule, la seule pièce qui reste quand la place manque, qui
/// défile (aucun [LayoutBuilder] ni [ListView] : ils refuseraient de rendre
/// leurs hauteurs intrinsèques).
class DesignationBand extends StatelessWidget {
  const DesignationBand({required this.onDesignate, super.key});

  /// Appelé par un tap, Entrée ou Espace sur la pilule : la désignation du
  /// centre de la carte.
  final VoidCallback onDesignate;

  @override
  Widget build(BuildContext context) {
    return _DesignationBandLayout(
      children: <Widget>[
        // Sans la `Scrollbar` automatique du bureau : voir la documentation
        // de la classe. Même retrait que les surcouches de `map_view.dart`.
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            primary: false,
            hitTestBehavior: HitTestBehavior.deferToChild,
            child: Center(child: DesignateCenterButton(onTap: onDesignate)),
          ),
        ),
        const DesignateCenterHint(),
      ],
    );
  }
}

/// Deux enfants, dans cet ordre : la zone de la pilule (le défilement), puis
/// l'indice.
class _DesignationBandLayout extends MultiChildRenderObjectWidget {
  const _DesignationBandLayout({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDesignationBand();
}

class _DesignationBandParentData extends ContainerBoxParentData<RenderBox> {}

/// La pilule, puis l'indice dessous, centrés ; l'indice s'efface quand la
/// hauteur maximale reçue est inférieure à la hauteur entière (repli 5).
/// Modèle : `_RenderEntryBody` (`map_reading_selector.dart`, repli 4).
class _RenderDesignationBand extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DesignationBandParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DesignationBandParentData> {
  bool _hintShown = true;

  RenderBox get _pillZone => firstChild!;
  RenderBox get _hint => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DesignationBandParentData) {
      child.parentData = _DesignationBandParentData();
    }
  }

  /// La hauteur de la pilule à [width] : celle que le défilement porte.
  double _pillHeight(double width) => _pillZone.getMaxIntrinsicHeight(width);

  /// La hauteur ENTIÈRE à [width] : la pilule, l'écart et l'indice.
  double _fullHeight(double width) =>
      _pillHeight(width) +
      designateCenterGap +
      _hint.getMaxIntrinsicHeight(width);

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _pillZone.getMinIntrinsicWidth(double.infinity),
    _hint.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _pillZone.getMaxIntrinsicWidth(double.infinity),
    _hint.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _pillHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _fullHeight(width);

  /// Toute la largeur donnée, comme la bande qu'elle remplace : la pilule et
  /// l'indice y sont centrés, le reste est de la carte.
  double _resolvedWidth(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : computeMaxIntrinsicWidth(double.infinity);

  bool _showsHint(BoxConstraints constraints, double width) =>
      constraints.maxHeight >= _fullHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double width = _resolvedWidth(constraints);
    return constraints.constrain(
      Size(
        width,
        _showsHint(constraints, width)
            ? _fullHeight(width)
            : _pillHeight(width),
      ),
    );
  }

  @override
  void performLayout() {
    final double width = _resolvedWidth(constraints);
    final double pillHeight = _pillHeight(width);
    _hintShown = _showsHint(constraints, width);
    // Le défilement a exactement la hauteur de la pilule quand l'indice est
    // là ; sinon il n'a que ce qui reste, et la pilule y défile.
    final double zoneHeight = _hintShown
        ? pillHeight
        : math.min(pillHeight, constraints.maxHeight);
    _pillZone.layout(
      BoxConstraints.tightFor(width: width, height: zoneHeight),
      parentUsesSize: true,
    );
    _hint.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    (_pillZone.parentData! as _DesignationBandParentData).offset = Offset.zero;
    (_hint.parentData! as _DesignationBandParentData).offset = _hintShown
        ? Offset(
            (width - _hint.size.width) / 2,
            zoneHeight + designateCenterGap,
          )
        : Offset.zero;
    size = constraints.constrain(
      Size(
        width,
        _hintShown
            ? zoneHeight + designateCenterGap + _hint.size.height
            : zoneHeight,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(
      _pillZone,
      offset + (_pillZone.parentData! as _DesignationBandParentData).offset,
    );
    if (_hintShown) {
      context.paintChild(
        _hint,
        offset + (_hint.parentData! as _DesignationBandParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in <RenderBox>[
      if (_hintShown) _hint,
      _pillZone,
    ]) {
      final Offset childOffset =
          (child.parentData! as _DesignationBandParentData).offset;
      final bool hit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_pillZone);
    if (_hintShown) {
      visitor(_hint);
    }
  }
}

/// Le bouton en pilule. Le libellé passe à la ligne plutôt que d'être tronqué
/// (petit écran, police à 200 %) ; la pilule (`StadiumBorder`) suit alors la
/// hauteur.
class DesignateCenterButton extends StatelessWidget {
  const DesignateCenterButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Même montage que `_MapControlButton` (`map_controls.dart`) : la clé et
    // le libellé sur le `Semantics`, `KeyboardFocusRing` SOUS lui, le
    // `InkWell` sans focus propre (un second nœud ferait deux arrêts de
    // tabulation).
    return Semantics(
      key: mapDesignateCenterButtonKey,
      button: true,
      enabled: true,
      label: designateCenterLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: KeyboardFocusRing(
        onActivate: onTap,
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: primaryActionColor,
            shape: StadiumBorder(
              side: BorderSide(color: Colors.white, width: 2),
            ),
            shadows: <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              canRequestFocus: false,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: designateCenterButtonHeight,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Icon(
                          Icons.gps_fixed,
                          size: 22,
                          color: onPrimaryActionColor,
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          designateCenterLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: onPrimaryActionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'indice du geste équivalent. Exclu de la sémantique : il décrit un geste
/// de pointeur, inutile au lecteur d'écran, qui a le bouton.
class DesignateCenterHint extends StatelessWidget {
  const DesignateCenterHint({super.key});

  @override
  Widget build(BuildContext context) {
    final bool touch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return ExcludeSemantics(
      child: DecoratedBox(
        key: mapDesignateCenterHintKey,
        decoration: BoxDecoration(
          color: const Color(0xF0FFFFFF),
          border: Border.all(color: const Color(0xFFC9CFC4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            touch
                ? 'ou appui long sur n\'importe quel point'
                : 'ou clic droit sur n\'importe quel point de la carte',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF141A1F)),
          ),
        ),
      ),
    );
  }
}

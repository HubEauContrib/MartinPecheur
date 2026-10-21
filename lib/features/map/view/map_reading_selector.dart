// Le sélecteur de lecture (`S1` d'Ergonomie, cadrage du 2026-10-17,
// arbitrage 1 « Carte unique ») : quatre entrées — les trois lectures de
// [MapScaleKind], puis l'interrupteur « Restrictions » —, chacune un
// pictogramme, un titre et un sous-titre (§ 11.2), annoncés ensemble.
//
// Branché par `D2` dans la partie fixe du bloc de lecture, à la place des
// puces d'échelle (`map_scale_chips.dart`, supprimé) ; [mapDesignationChipKey]
// et [designationChipLabel] y ont été déplacés, noms gardés (`PD2`).
//
// `BR-008` : une lecture à la fois. « Restrictions » n'est PAS une lecture
// (arbitrage du 2026-10-03) : un interrupteur indépendant, `toggled`, jamais
// `selected` ; la lecture affichée reste allumée quand il s'allume. Ce widget
// ne décide rien : il appelle [MapReadingSelector.onSelect] ou
// [MapReadingSelector.onToggleDesignationMode], le ViewModel bascule.
//
// La grille est un `RenderObject` ([_RenderReadingGrid]) et non un
// `LayoutBuilder` : la mise en page de la carte (`RenderMapLayout`, `D1`)
// interrogera ses hauteurs intrinsèques, qu'un `LayoutBuilder` refuse de
// rendre (note d'architecture du plan d'Ergonomie). Ses deux hauteurs :
// - `getMaxIntrinsicHeight(w)` : la grille entière, sous-titres compris ;
// - `getMinIntrinsicHeight(w)` : les titres seuls (repli 4).
// Posée avec une hauteur maximale inférieure à la première, elle efface
// TOUS ses sous-titres d'elle-même — ni peints, ni touchables ; leur texte
// reste dans l'annonce de chaque entrée. Une seule variante est montée.
//
// Le nombre de colonnes ne dépend d'aucun seuil de largeur (`PD5`) : c'est le
// plus grand de 4, 2, 1 pour lequel la colonne est au moins aussi large que
// chaque entrée privée de son sous-titre — son plus long mot de titre,
// pictogramme et marges compris —, à l'échelle de texte courante.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// La clé de l'entrée « Restrictions » (`E5` de T2, nom gardé par `PD2`) :
/// posée sur son nœud sémantique, donc sur la boîte entière — celle que les
/// tests tapent et mesurent, comme `ValueKey<MapScaleKind>` pour chaque
/// lecture. Déplacée de `map_scale_chips.dart` (supprimé par `D2`).
const Key mapDesignationChipKey = Key('map-designation-chip');

/// Le titre de l'entrée « Restrictions » — celui de l'écran des restrictions
/// et du bouton qu'elle fait apparaître. Déplacé de `map_scale_chips.dart`.
const String designationChipLabel = 'Restrictions';

/// Sous-titre de l'entrée « Restrictions » (§ 11.2), mot pour mot.
const String designationEntrySubtitle = 'arrêtés préfectoraux';

/// L'annonce d'une entrée : son titre et son sous-titre, séparés par une
/// virgule (§ 11.2 : « Débit, relatif à l'historique »). Le sous-titre y
/// reste même quand le repli 4 l'efface de l'écran.
String readingEntrySemanticsLabel(String title, String subtitle) =>
    '$title, $subtitle';

/// Le sélecteur de lecture, en tête du bloc de la carte : une entrée par
/// valeur de [MapScaleKind], celle de [scale] allumée et `selected`, puis —
/// si [onToggleDesignationMode] est fourni — l'interrupteur « Restrictions ».
class MapReadingSelector extends StatelessWidget {
  const MapReadingSelector({
    required this.scale,
    required this.onSelect,
    this.designationMode = false,
    this.onToggleDesignationMode,
    super.key,
  });

  /// La lecture affichée, lue sur `MapViewModel.scale`.
  final MapScaleKind scale;

  /// Appelé avec la lecture demandée. En production,
  /// `MapViewModel.selectScale`.
  final void Function(MapScaleKind kind) onSelect;

  /// Le mode de désignation est-il actif ? Sans effet quand
  /// [onToggleDesignationMode] est nul : l'entrée est alors absente.
  final bool designationMode;

  /// Appelé par l'entrée « Restrictions ». En production,
  /// `MapViewModel.toggleDesignationMode`. `null` : aucune désignation n'est
  /// câblée, l'entrée est **absente** — jamais une entrée morte.
  final VoidCallback? onToggleDesignationMode;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? toggleDesignation = onToggleDesignationMode;
    return _ReadingGrid(
      children: <Widget>[
        for (final MapScaleKind kind in MapScaleKind.values)
          _ReadingEntry(
            semanticsKey: ValueKey<MapScaleKind>(kind),
            icon: _readingIcon(kind),
            title: mapScaleEntryTitle(kind),
            subtitle: mapScaleEntrySubtitle(kind),
            // La seule comparaison sur `MapScaleKind` du sélecteur, déplacée
            // telle quelle des anciennes puces d'échelle : elle marque l'entrée
            // active.
            selected: kind == scale,
            onActivate: () => onSelect(kind),
          ),
        if (toggleDesignation != null)
          _ReadingEntry(
            semanticsKey: mapDesignationChipKey,
            icon: Icons.gavel,
            title: designationChipLabel,
            subtitle: designationEntrySubtitle,
            toggled: designationMode,
            onActivate: toggleDesignation,
          ),
      ],
    );
  }
}

/// Le pictogramme d'une lecture (`PD4`). Jamais `Icons.warning_amber_rounded`,
/// celui de « ⚠ Avertissement ». `switch` exhaustif (`BR-011`).
IconData _readingIcon(MapScaleKind kind) => switch (kind) {
  MapScaleKind.ecoulement => Icons.water_drop,
  MapScaleKind.debit => Icons.timeline,
  MapScaleKind.crues => Icons.waves,
};

/// Une entrée. Une lecture porte `selected` ; « Restrictions » porte
/// `toggled` — l'un ou l'autre, jamais les deux. L'état allumé est porté par
/// `Semantics` en plus du rendu (`04-ui.md` § 3 : aucune information par la
/// seule couleur). Le noir et le blanc ne codent aucun état de l'eau.
class _ReadingEntry extends StatelessWidget {
  const _ReadingEntry({
    required this.semanticsKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onActivate,
    this.selected,
    this.toggled,
  });

  final Key semanticsKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onActivate;

  /// `Semantics(selected:)` d'une lecture ; `null` pour « Restrictions ».
  final bool? selected;

  /// `Semantics(toggled:)` de « Restrictions » ; `null` pour une lecture.
  final bool? toggled;

  bool get _lit => (selected ?? false) || (toggled ?? false);

  @override
  Widget build(BuildContext context) {
    final bool lit = _lit;
    final Color foreground = lit ? Colors.white : Colors.black;
    return Semantics(
      // Sur le nœud sémantique, donc sur la boîte entière : celle que les
      // tests tapent et mesurent.
      key: semanticsKey,
      button: true,
      selected: selected,
      toggled: toggled,
      label: readingEntrySemanticsLabel(title, subtitle),
      // Titre et sous-titre sont annoncés ici, ensemble ; sans cette
      // exclusion, chaque `Text` ferait un second nœud.
      excludeSemantics: true,
      // `excludeSemantics` masque l'action du geste : elle est rendue ici.
      onTap: onActivate,
      child: KeyboardFocusRing(
        onActivate: onActivate,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onActivate,
          child: ConstrainedBox(
            // La cible de la plateforme (48 Android, 44 ailleurs), dans les
            // deux dimensions : un plancher, jamais un plafond.
            constraints: BoxConstraints(
              minWidth: minimumTapTarget,
              minHeight: minimumTapTarget,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: lit ? Colors.black : _offBackground,
                border: Border.all(color: lit ? Colors.black : _offBorder),
                borderRadius: const BorderRadius.all(
                  Radius.circular(_entryRadius),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _entryHorizontalPadding,
                  vertical: _entryVerticalPadding,
                ),
                child: _EntryBody(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ExcludeSemantics(
                          child: Icon(icon, size: _iconSize, color: foreground),
                        ),
                        const SizedBox(width: _iconGap),
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: _titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: _subtitleFontSize,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- La grille ---------------------------------------------------------------

class _ReadingGrid extends MultiChildRenderObjectWidget {
  const _ReadingGrid({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReadingGrid();
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

/// La grille des entrées. Elle choisit son nombre de colonnes sur les
/// largeurs intrinsèques minimales des entrées (privées de leur sous-titre,
/// [_RenderEntryBody]) et pose des rangées de hauteur égale.
///
/// Repli 4 : posée avec une hauteur maximale inférieure à sa hauteur entière
/// ([computeMaxIntrinsicHeight]), elle pose chaque entrée à une hauteur
/// **imposée** (contrainte serrée) — celle des titres seuls de sa rangée. Une
/// hauteur imposée est, pour [_RenderEntryBody], l'ordre d'effacer son
/// sous-titre : toutes les entrées l'effacent, même celle dont le sous-titre
/// tiendrait dans la hauteur de sa rangée. Hors repli, la hauteur de rangée
/// n'est qu'un plancher : la contrainte n'est jamais serrée en hauteur.
class _RenderReadingGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) {
      child.parentData = _GridParentData();
    }
  }

  List<RenderBox> get _entries {
    final List<RenderBox> entries = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      entries.add(child);
      child = childAfter(child);
    }
    return entries;
  }

  /// La largeur la plus étroite où une entrée ne coupe aucun mot de son
  /// titre.
  double _widestTitleNeed(List<RenderBox> entries) => entries.fold(
    0,
    (double widest, RenderBox entry) =>
        math.max(widest, entry.getMinIntrinsicWidth(double.infinity)),
  );

  double _widestNaturalWidth(List<RenderBox> entries) => entries.fold(
    0,
    (double widest, RenderBox entry) =>
        math.max(widest, entry.getMaxIntrinsicWidth(double.infinity)),
  );

  /// Le plus grand de 4, 2, 1 (borné au nombre d'entrées) pour lequel aucune
  /// colonne n'est plus étroite que [_widestTitleNeed]. Une seule colonne si
  /// même elle ne suffit pas.
  int _columnsFor(double width, List<RenderBox> entries) {
    if (!width.isFinite) {
      return math.min(_columnCandidates.first, entries.length);
    }
    final double need = _widestTitleNeed(entries);
    for (final int candidate in _columnCandidates) {
      final int columns = math.min(candidate, entries.length);
      if (_columnWidth(width, columns, entries) >= need) {
        return columns;
      }
    }
    return 1;
  }

  double _columnWidth(double width, int columns, List<RenderBox> entries) =>
      width.isFinite
      ? (width - (columns - 1) * _gridSpacing) / columns
      : _widestNaturalWidth(entries);

  double _rowHeight(
    List<RenderBox> row,
    double columnWidth, {
    required bool withSubtitles,
  }) => row.fold(
    0,
    (double tallest, RenderBox entry) => math.max(
      tallest,
      withSubtitles
          ? entry.getMaxIntrinsicHeight(columnWidth)
          : entry.getMinIntrinsicHeight(columnWidth),
    ),
  );

  /// Les rangées de [entries] pour [columns] colonnes.
  Iterable<List<RenderBox>> _rows(List<RenderBox> entries, int columns) sync* {
    for (int start = 0; start < entries.length; start += columns) {
      yield entries.sublist(start, math.min(start + columns, entries.length));
    }
  }

  double _gridHeight(double width, {required bool withSubtitles}) {
    final List<RenderBox> entries = _entries;
    if (entries.isEmpty) {
      return 0;
    }
    final int columns = _columnsFor(width, entries);
    final double columnWidth = _columnWidth(width, columns, entries);
    final List<List<RenderBox>> rows = _rows(entries, columns).toList();
    double height = (rows.length - 1) * _gridSpacing;
    for (final List<RenderBox> row in rows) {
      height += _rowHeight(row, columnWidth, withSubtitles: withSubtitles);
    }
    return height;
  }

  double _resolvedWidth(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth) {
      return constraints.maxWidth;
    }
    return constraints.constrainWidth(
      computeMaxIntrinsicWidth(double.infinity),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _widestTitleNeed(_entries);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final List<RenderBox> entries = _entries;
    if (entries.isEmpty) {
      return 0;
    }
    final int columns = math.min(_columnCandidates.first, entries.length);
    return columns * _widestNaturalWidth(entries) +
        (columns - 1) * _gridSpacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _gridHeight(width, withSubtitles: false);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _gridHeight(width, withSubtitles: true);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double width = _resolvedWidth(constraints);
    final double full = _gridHeight(width, withSubtitles: true);
    final double height = constraints.maxHeight < full
        ? _gridHeight(width, withSubtitles: false)
        : full;
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final List<RenderBox> entries = _entries;
    final double width = _resolvedWidth(constraints);
    if (entries.isEmpty) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    final bool withSubtitles =
        constraints.maxHeight >= _gridHeight(width, withSubtitles: true);
    final int columns = _columnsFor(width, entries);
    final double columnWidth = _columnWidth(width, columns, entries);
    double y = 0;
    bool firstRow = true;
    for (final List<RenderBox> row in _rows(entries, columns)) {
      if (!firstRow) {
        y += _gridSpacing;
      }
      firstRow = false;
      final double rowHeight = _rowHeight(
        row,
        columnWidth,
        withSubtitles: withSubtitles,
      );
      double tallest = rowHeight;
      for (int i = 0; i < row.length; i++) {
        final RenderBox entry = row[i];
        entry.layout(
          withSubtitles
              ? BoxConstraints(
                  minWidth: columnWidth,
                  maxWidth: columnWidth,
                  minHeight: rowHeight,
                )
              : BoxConstraints.tightFor(width: columnWidth, height: rowHeight),
          parentUsesSize: true,
        );
        (entry.parentData! as _GridParentData).offset = Offset(
          i * (columnWidth + _gridSpacing),
          y,
        );
        tallest = math.max(tallest, entry.size.height);
      }
      y += tallest;
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// --- Le corps d'une entrée -----------------------------------------------------

/// Deux enfants, dans cet ordre : la ligne du titre (pictogramme et titre),
/// puis le sous-titre.
class _EntryBody extends MultiChildRenderObjectWidget {
  const _EntryBody({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEntryBody();
}

class _EntryBodyParentData extends ContainerBoxParentData<RenderBox> {}

/// Le titre, puis le sous-titre dessous. Sa largeur intrinsèque minimale est
/// celle de la ligne du titre SEULE : c'est la règle des colonnes (`PD5`), un
/// sous-titre peut se replier sur plus de lignes, un mot de titre jamais.
///
/// Posé avec une hauteur imposée (contrainte serrée, repli 4 décidé par
/// [_RenderReadingGrid]), il efface son sous-titre : ni peint, ni touchable,
/// ni visité pour l'annonce. Le sous-titre reste monté et posé — ses
/// intrinsèques restent lisibles et la décision ne va-et-vient pas d'une
/// trame à l'autre ; son texte reste dans le libellé de l'entrée.
class _RenderEntryBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EntryBodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EntryBodyParentData> {
  bool _subtitleShown = true;

  RenderBox get _titleLine => firstChild!;
  RenderBox get _subtitle => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EntryBodyParentData) {
      child.parentData = _EntryBodyParentData();
    }
  }

  double _titleHeight(double width) => _titleLine.getMaxIntrinsicHeight(width);

  double _fullHeight(double width) =>
      _titleHeight(width) +
      _subtitleGap +
      _subtitle.getMaxIntrinsicHeight(width);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _titleLine.getMinIntrinsicWidth(double.infinity);

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _titleLine.getMaxIntrinsicWidth(double.infinity),
    _subtitle.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _titleHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _fullHeight(width);

  double _resolvedWidth(BoxConstraints constraints) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : computeMaxIntrinsicWidth(double.infinity);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double width = _resolvedWidth(constraints);
    return constraints.constrain(
      Size(
        width,
        constraints.hasTightHeight ? _titleHeight(width) : _fullHeight(width),
      ),
    );
  }

  @override
  void performLayout() {
    final double width = _resolvedWidth(constraints);
    _subtitleShown = !constraints.hasTightHeight;
    final BoxConstraints childConstraints = BoxConstraints(maxWidth: width);
    _titleLine.layout(childConstraints, parentUsesSize: true);
    _subtitle.layout(childConstraints, parentUsesSize: true);
    final double titleHeight = _titleLine.size.height;
    (_titleLine.parentData! as _EntryBodyParentData).offset = Offset.zero;
    (_subtitle.parentData! as _EntryBodyParentData).offset = _subtitleShown
        ? Offset(0, titleHeight + _subtitleGap)
        : Offset.zero;
    size = constraints.constrain(
      Size(
        width,
        _subtitleShown
            ? titleHeight + _subtitleGap + _subtitle.size.height
            : titleHeight,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(
      _titleLine,
      offset + (_titleLine.parentData! as _EntryBodyParentData).offset,
    );
    if (_subtitleShown) {
      context.paintChild(
        _subtitle,
        offset + (_subtitle.parentData! as _EntryBodyParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final RenderBox child in <RenderBox>[
      if (_subtitleShown) _subtitle,
      _titleLine,
    ]) {
      final Offset childOffset =
          (child.parentData! as _EntryBodyParentData).offset;
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
    visitor(_titleLine);
    if (_subtitleShown) {
      visitor(_subtitle);
    }
  }
}

/// Colonnes essayées, de la plus large rangée à la plus étroite (`PD5`).
const List<int> _columnCandidates = <int>[4, 2, 1];

/// Espacement entre deux entrées, en colonnes comme en rangées.
const double _gridSpacing = 8;

/// Fond d'une entrée éteinte.
const Color _offBackground = Color(0xFFF3F4F1);

/// Bord d'une entrée éteinte.
const Color _offBorder = Color(0xFFC9CFC4);

const double _entryRadius = 8;
const double _entryHorizontalPadding = 6;
const double _entryVerticalPadding = 8;
const double _iconSize = 16;
const double _iconGap = 4;
const double _subtitleGap = 2;
const double _titleFontSize = 14;
const double _subtitleFontSize = 12;

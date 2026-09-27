// Le marqueur d'un point ONDE sur l'échelle « écoulement » (T1-U3), et le
// vocabulaire visuel de cette échelle : une teinte, une forme, un motif et un
// libellé carte par catégorie.
//
// ⚠️ **Rien n'est choisi ici.** Les six lignes ci-dessous sont RECOPIÉES de
// `04-ui.md` § 2 (« Échelle 1 — Écoulement ONDE (formes pleines) »), la
// sixième — « Non renseigné » — du **tableau `U3` du plan T1** et du domaine
// (`flowCategoryLabel`). Elle **dévie d'`ADR-006`**, qui range un code
// inconnu sous « Non observé » : le rendu visuel est bien celui de l'ADR,
// mais le mot en est distinct, parce qu'un fait de terrain constaté n'est
// pas notre propre ignorance d'un code (`BR-007`). La déviation est
// consignée dans `docs/project-state.md` et **reste à acter par le
// commanditaire** :
//
// | Catégorie | Hex | Forme | Motif | Libellé carte |
// |---|---|---|---|---|
// | `Ecoulement` | `#0072B2` | ● cercle | plein | Eau qui coule |
// | `EcoulementFaible` | `#56B4E9` | ◐ cercle mi-plein | demi-plein | Écoulement faible |
// | `EcoulementNonVisible` | `#E69F00` | ▲ triangle | hachures obliques | Eau stagnante |
// | `Assec` | `#D55E00` | ■ carré | plein, contour noir 2 px | À sec |
// | `NonObserve` | `#767676` | ◌ cercle vide | contour pointillé | Non observé |
// | `Inconnu` | `#767676` | ◌ cercle vide | contour pointillé | Non renseigné |
//
// La palette est **Okabe-Ito** (`04-ui.md` § 3) : le couple critique
// `#E69F00` / `#56B4E9` reste séparable en deutéranopie comme en
// protanopie. Mais la couleur ne porte **jamais** l'information à elle
// seule : chaque état combine teinte + forme + motif + libellé, et les cinq
// rendus visuels restent distincts en niveaux de gris — c'est ce que le
// test miroir de ce fichier vérifie, couple (forme, motif) par couple.
//
// ## Deux écarts assumés, documentés plutôt que corrigés en douce
//
// 1. **`NonObserve` et `Inconnu` ont le MÊME rendu** — même teinte, même
//    forme, même motif — et ne se séparent que par le libellé. C'est la
//    recopie fidèle d'`ADR-006` (« code inconnu → Non observé ») : un fait
//    de terrain constaté et notre propre ignorance d'un code partagent
//    l'aveu « rien à montrer ici », mais jamais le mot (`BR-007`).
// 2. **La ligne « plein, contour noir 2 px » d'À sec** est exactement le
//    halo que `04-ui.md` § 3 pose sur TOUS les marqueurs (« contour de 2 px
//    systématique, [...] noir sur fond clair » — le seul fond du projet est
//    le plan IGN, un fond clair). Rien de plus n'est dessiné pour elle : ce
//    qui sépare ■ de ● est la **forme**, pas le motif.
//
// Le troisième écart — « le libellé carte diffère de `flowCategoryLabel` » —
// **a été supprimé, pas documenté** (relecture du 2026-09-14) : un point
// annoncé « Eau qui coule » sur la carte aurait ouvert une fiche disant
// « Écoulement visible », ce que `docs/glossary.md` interdit (un concept, un
// mot). Le domaine rend désormais la colonne « Libellé carte », une seule
// fois, et [ondeCategoryMapLabel] y **délègue**.
//
// ## BR-010 : la date toujours, et passé 60 jours le gris
//
// ONDE n'est pas une mesure continue : ce sont des campagnes de terrain, une
// par mois de mai à septembre. D'octobre à avril, un point affiché « eau qui
// coule » porte couramment une observation de septembre. `BR-010` ouvre donc
// sur « **tout** point ONDE affiche la date de sa dernière campagne » :
// l'annonce la porte quel que soit l'âge — « campagne du 25/08/2026 » —
// comme `04-ui.md` § 3 l'écrit pour le lecteur d'écran. Au-delà de
// [campagneAncienneApres] s'ajoutent la teinte grise, **quelle que soit la
// catégorie**, et la mention « dernière observation le … » que la règle
// nomme. La forme et le motif, eux, ne changent pas : c'est ce qui laisse
// l'usager lire « à sec, mais c'était il y a trois mois » plutôt que « on ne
// sait pas ».
//
// ## Rien n'est alloué par trame
//
// Même contrainte et même technique que `station_marker.dart` : au zoom
// national tous les marqueurs du viewport élargi sont peints à chaque trame
// d'un déplacement (`F2c`, aucun clustering ; `NFR-01`). Les `Paint` sont
// mis en cache par teinte, les tracés par couple (forme, motif) et par
// taille — en pratique une taille unique, [stationMarkerSize]. `paint()`
// n'alloue rien et ne fait **que deux appels de dessin au plus**.
//
// Les constantes d'accessibilité — 12 px de forme, 44 pt de cible tactile,
// 2 px de halo — sont celles de `station_marker.dart`, importées et non
// recopiées : les deux fichiers sont de la MÊME tranche (`features/map/`),
// et ce sont les mêmes lignes de `04-ui.md` § 3. La règle
// `feature-vers-feature` de `test/architecture/layers_test.dart` n'interdit
// qu'une tranche de citer une AUTRE tranche.

import 'dart:math' as math;
// `PathMetric` n'est pas réexporté par `material.dart` — il vient de
// `dart:ui`, comme `Path` lui-même. Importé nommément pour ne rien ramener
// d'autre.
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';

/// Forme d'un marqueur de l'échelle 1, telle que `04-ui.md` § 2 la nomme.
/// `enum` fermé : une forme ajoutée sans branche dans les `switch` de ce
/// fichier est une erreur de compilation (`BR-011`).
enum OndeMarkerShapeKind {
  /// ● — le cercle d'« Eau qui coule ».
  cercle,

  /// ◐ — le cercle mi-plein d'« Écoulement faible ».
  cercleMiPlein,

  /// ▲ — le triangle d'« Eau stagnante ».
  triangle,

  /// ■ — le carré d'« À sec ».
  carre,

  /// ◌ — le cercle vide de « Non observé » et « Non renseigné ».
  cercleVide,
}

/// Motif de remplissage d'un marqueur de l'échelle 1, tel que `04-ui.md`
/// § 2 le nomme. C'est lui, avec la forme, qui porte l'information en
/// niveaux de gris (`04-ui.md` § 3).
enum OndeMarkerPattern {
  /// Remplissage plein.
  plein,

  /// Une moitié remplie, l'autre vide.
  demiPlein,

  /// Des traits obliques, séparés par des vides.
  hachuresObliques,

  /// Plein, plus le contour noir de 2 px — qui est déjà le halo commun à
  /// tous les marqueurs (voir l'en-tête, écart 2).
  pleinContourNoir,

  /// Aucun remplissage ; le contour est découpé en tirets.
  contourPointille,
}

/// Gris de « Non observé » et « Non renseigné », recopié de `04-ui.md` § 2
/// (échelle 1). C'est aussi la teinte que `BR-010` impose passé 60 jours,
/// quelle que soit la catégorie.
///
/// Privé : ce fichier est son seul appelant, et le test miroir retape le
/// littéral — sur ce projet le test **est** la recopie vérifiée de
/// `04-ui.md`, jamais un renvoi vers la constante qu'il contrôle.
const Color _ondeGrey = Color(0xFF767676);

/// Couleur du halo. `04-ui.md` § 3 : « contour de 2 px systématique, blanc
/// sur fond sombre, **noir sur fond clair** ». Le seul fond de carte du
/// projet est le plan IGN Géoplateforme, un fond clair.
const Color _ondeMarkerHalo = Color(0xFF000000);

/// Largeur d'un trait de hachure, en pixels logiques. **Paramètre choisi
/// ici** : `04-ui.md` § 2 dit « hachures obliques » sans en donner le pas.
/// Ce qui est spécifié — la lisibilité de la forme — est tenu par le halo
/// de 2 px, à opacité pleine.
const double _hatchWidth = 1.5;

/// Pas entre deux hachures, en pixels logiques. Supérieur à [_hatchWidth] :
/// sans vide entre les traits, le motif redeviendrait un aplat.
const double _hatchSpacing = 3.5;

/// Longueur d'un tiret du contour pointillé, en pixels logiques.
const double _dashLength = 2;

/// Longueur d'un vide entre deux tirets, en pixels logiques.
const double _dashGap = 2;

/// Teinte de [category] sur l'échelle 1, recopiée de `04-ui.md` § 2 —
/// **avant** la règle d'âge. Pour la teinte réellement peinte, voir
/// [ondeEffectiveColor].
///
/// `switch` exhaustif sur une `sealed class` (`BR-011`) : une catégorie
/// ajoutée au domaine sans branche ici ne compile pas.
Color ondeCategoryColor(FlowCategory category) => switch (category) {
  Ecoulement() => const Color(0xFF0072B2),
  EcoulementFaible() => const Color(0xFF56B4E9),
  EcoulementNonVisible() => const Color(0xFFE69F00),
  Assec() => const Color(0xFFD55E00),
  NonObserve() => _ondeGrey,
  Inconnu() => _ondeGrey,
};

/// Forme de [category], recopiée de `04-ui.md` § 2.
OndeMarkerShapeKind ondeCategoryShape(FlowCategory category) =>
    switch (category) {
      Ecoulement() => OndeMarkerShapeKind.cercle,
      EcoulementFaible() => OndeMarkerShapeKind.cercleMiPlein,
      EcoulementNonVisible() => OndeMarkerShapeKind.triangle,
      Assec() => OndeMarkerShapeKind.carre,
      NonObserve() => OndeMarkerShapeKind.cercleVide,
      Inconnu() => OndeMarkerShapeKind.cercleVide,
    };

/// Motif de [category], recopié de `04-ui.md` § 2.
OndeMarkerPattern ondeCategoryPattern(FlowCategory category) =>
    switch (category) {
      Ecoulement() => OndeMarkerPattern.plein,
      EcoulementFaible() => OndeMarkerPattern.demiPlein,
      EcoulementNonVisible() => OndeMarkerPattern.hachuresObliques,
      Assec() => OndeMarkerPattern.pleinContourNoir,
      NonObserve() => OndeMarkerPattern.contourPointille,
      Inconnu() => OndeMarkerPattern.contourPointille,
    };

/// Libellé **carte** de [category] : exactement celui du domaine,
/// `flowCategoryLabel`, qui porte la colonne « Libellé carte » d'`ADR-006`
/// et de `04-ui.md` § 2 — « Non renseigné » compris, une déviation de
/// l'`ADR` retenue pour `BR-007` et à acter par le commanditaire.
///
/// ⚠️ **Aucune seconde liste ici** (relecture du 2026-09-14) : deux `switch`
/// sur la même nomenclature auraient vieilli séparément, et la carte aurait
/// fini par nommer autrement ce que la fiche nomme. « À sec » et jamais
/// « Assec » ni « asséché » — un concept, un mot (`glossary.md`).
///
/// La fonction reste **publique et nommée** : le plan `U3` la cite dans ses
/// signatures, la légende et [ondeMarkerLabel] l'appellent, et c'est elle
/// qui dit « le libellé d'un marqueur de l'échelle 1 » — le jour où la carte
/// devrait s'écarter du domaine, c'est ici, et nulle part ailleurs.
String ondeCategoryMapLabel(FlowCategory category) =>
    flowCategoryLabel(category);

/// La teinte réellement peinte : celle de [category], sauf passé
/// [campagneAncienneApres] où toute catégorie vire au gris (`BR-010`).
///
/// La forme et le motif, eux, sont inchangés : une observation vieille de
/// trois mois reste une observation, pas une absence.
Color ondeEffectiveColor({
  required FlowCategory category,
  required CampaignAge age,
}) => switch (age) {
  CampaignAge.recente => ondeCategoryColor(category),
  CampaignAge.ancienne => _ondeGrey,
};

/// L'annonce d'un marqueur ONDE au lecteur d'écran, assemblée **en un seul
/// endroit** — la forme seule en légende, le point nommé sur la carte, et la
/// date de campagne dès qu'il y en a une :
///
/// - `À sec`
/// - `À sec — Le Trey à Vilcey-sur-Trey`
/// - `À sec — Ruisseau des Fées, campagne du 25/08/2026, observation
///   visuelle ponctuelle`
/// - `À sec — Le Trey à Vilcey-sur-Trey, dernière observation le 26/09/2025,
///   observation visuelle ponctuelle`
///
/// [pointLabel] est nul en légende : il n'y a alors aucun point à nommer.
///
/// ⚠️ La date est annoncée **quel que soit l'âge** (relecture du
/// 2026-09-14) : `BR-010` s'ouvre sur « tout point ONDE affiche la date de
/// sa dernière campagne », et `04-ui.md` § 3 donne l'annonce attendue —
/// « Point ONDE, Ruisseau des Fées, à sec, campagne du 25 juillet 2026,
/// observation visuelle ponctuelle ». Ce n'est qu'au-delà de
/// [campagneAncienneApres] que la mention devient « dernière observation
/// le … », la formulation que la règle réserve à un état périmé. La
/// qualification « observation visuelle ponctuelle » est recopiée de
/// `04-ui.md` § 3 : ONDE n'est pas une mesure continue, et c'est ce qui
/// empêche de lire une campagne comme un relevé d'aujourd'hui.
///
/// [observedAt] reste nullable pour la **légende seule**, qui ne parle
/// d'aucune observation particulière. Sans date, rien n'est inventé
/// (`BR-007`).
///
/// ⚠️ L'échelle active ne figure PAS ici : `BR-008` demande que l'annonce
/// d'un marqueur de carte la préfixe, mais la légende, elle, la nomme déjà
/// en tête. C'est donc `buildMapLayers` (`map_view.dart`) qui préfixe, avec
/// `mapScaleLabel` — jamais une recopie locale du nom de l'échelle.
String ondeMarkerLabel({
  required FlowCategory category,
  required CampaignAge age,
  DateTime? observedAt,
  String? pointLabel,
}) {
  final StringBuffer buffer = StringBuffer(ondeCategoryMapLabel(category));

  final String? point = pointLabel;
  if (point != null) {
    buffer
      ..write(' — ')
      ..write(point);
  }

  final DateTime? observed = observedAt;
  if (observed != null) {
    // `switch` exhaustif sur un `enum` fermé (`BR-011`) : la formulation
    // dépend de l'âge, l'annonce de la date, non.
    final String mention = switch (age) {
      CampaignAge.recente => 'campagne du ',
      CampaignAge.ancienne => 'dernière observation le ',
    };
    buffer
      ..write(', ')
      ..write(mention)
      ..write(formatCalendarDate(observed))
      ..write(', ')
      ..write(_observationVisuellePonctuelle);
  }

  return buffer.toString();
}

/// La nature de la donnée ONDE, recopiée de l'annonce que `04-ui.md` § 3
/// donne pour le lecteur d'écran (« …, campagne du 25 juillet 2026,
/// **observation visuelle ponctuelle**. ») et de la justification de
/// `BR-010`. Elle suit la date : sans elle, une date se lit comme celle d'un
/// relevé continu.
const String _observationVisuellePonctuelle =
    'observation visuelle '
    'ponctuelle';

/// Le halo des six catégories : même couleur, même épaisseur, même style. Un
/// unique objet de niveau bibliothèque, construit au premier marqueur peint
/// et jamais par trame.
final Paint _haloPaint = Paint()
  ..color = _ondeMarkerHalo
  ..style = PaintingStyle.stroke
  ..strokeWidth = stationMarkerBorderWidth;

/// Les `Paint` de remplissage déjà construits, par teinte. Cinq entrées au
/// plus — les quatre teintes de catégorie plus le gris de `BR-010`.
final Map<Color, Paint> _fillPaints = <Color, Paint>{};

Paint _fillPaintFor(Color color) => _fillPaints.putIfAbsent(
  color,
  () => Paint()
    ..color = color
    ..style = PaintingStyle.fill,
);

/// Les tracés d'un marqueur : ce que le halo suit, et ce que le remplissage
/// couvre. Ne dépendent NI de la teinte NI de l'âge — seulement de la forme,
/// du motif et de la taille.
///
/// Les deux champs sont `final` et ne sont jamais modifiés après
/// construction — pas d'`@immutable` pour autant : un `Path` reste mutable
/// en droit, et l'annotation promettrait plus que la classe ne peut tenir.
class _OndeGeometry {
  _OndeGeometry(OndeMarkerShapeKind shape, OndeMarkerPattern pattern, Size size)
    : halo = pattern == OndeMarkerPattern.contourPointille
          ? _dashed(_outlinePath(shape, size))
          : _outlinePath(shape, size),
      fill = _fillPath(shape, pattern, size);

  /// Le tracé que suit le halo de 2 px : le contour, continu ou en tirets.
  final Path halo;

  /// Le tracé rempli, ou `null` quand le motif n'en a pas.
  final Path? fill;

  /// Le contour de [shape], rentré d'un demi-halo : le trait est centré sur
  /// le tracé, la moitié déborderait hors de la boîte sans cette marge.
  static Path _outlinePath(OndeMarkerShapeKind shape, Size size) {
    const double inset = stationMarkerBorderWidth / 2;
    final Rect box = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );

    // `switch` exhaustif sur un `enum` fermé (`BR-011`).
    return switch (shape) {
      OndeMarkerShapeKind.cercle ||
      OndeMarkerShapeKind.cercleMiPlein ||
      OndeMarkerShapeKind.cercleVide => Path()..addOval(box),
      OndeMarkerShapeKind.carre => Path()..addRect(box),
      OndeMarkerShapeKind.triangle =>
        Path()..addPolygon(<Offset>[
          Offset(box.center.dx, box.top),
          Offset(box.right, box.bottom),
          Offset(box.left, box.bottom),
        ], true),
    };
  }

  static Path? _fillPath(
    OndeMarkerShapeKind shape,
    OndeMarkerPattern pattern,
    Size size,
  ) => switch (pattern) {
    OndeMarkerPattern.plein ||
    OndeMarkerPattern.pleinContourNoir => _outlinePath(shape, size),
    OndeMarkerPattern.demiPlein => _halfDiscPath(size),
    OndeMarkerPattern.hachuresObliques => Path.combine(
      PathOperation.intersect,
      _hatchBarsPath(size),
      _outlinePath(shape, size),
    ),
    OndeMarkerPattern.contourPointille => null,
  };

  /// La moitié **droite** du disque : l'arc part du haut et balaie un
  /// demi-tour, `close` referme par la corde verticale. Le côté choisi n'a
  /// pas d'importance de spécification — ce qui compte est qu'une moitié
  /// seulement soit remplie (`04-ui.md` § 2, motif « demi-plein »).
  static Path _halfDiscPath(Size size) {
    const double inset = stationMarkerBorderWidth / 2;
    final Rect box = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    return Path()
      ..addArc(box, -math.pi / 2, math.pi)
      ..close();
  }

  /// Des barres obliques à 45°, couvrant largement la boîte : c'est
  /// l'intersection avec le contour qui les taille à la forme. Construites
  /// comme des parallélogrammes **remplis** et non comme des traits : un
  /// tracé rempli s'intersecte avec un autre (`Path.combine`), un tracé
  /// seulement destiné à être tracé, non.
  static Path _hatchBarsPath(Size size) {
    final Path bars = Path();
    final double height = size.height;

    for (double left = -height; left < size.width; left += _hatchSpacing) {
      bars.addPolygon(<Offset>[
        Offset(left, 0),
        Offset(left + _hatchWidth, 0),
        Offset(left + _hatchWidth + height, height),
        Offset(left + height, height),
      ], true);
    }

    return bars;
  }

  /// Découpe [source] en tirets de [_dashLength] séparés de [_dashGap].
  /// `computeMetrics` plutôt qu'une interpolation à la main : les contours
  /// de ce fichier sont courbes, et le résultat est calculé UNE fois par
  /// couple (forme, motif) et par taille.
  static Path _dashed(Path source) {
    final Path dashes = Path();

    for (final PathMetric metric in source.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = math.min(start + _dashLength, metric.length);
        dashes.addPath(metric.extractPath(start, end), Offset.zero);
        start = end + _dashGap;
      }
    }

    return dashes;
  }
}

/// Les géométries déjà calculées. En pratique **cinq entrées** : un couple
/// (forme, motif) par rendu visuel, tous à [stationMarkerSize].
final Map<(OndeMarkerShapeKind, OndeMarkerPattern, Size), _OndeGeometry>
_geometries = <(OndeMarkerShapeKind, OndeMarkerPattern, Size), _OndeGeometry>{};

_OndeGeometry _geometryFor(
  OndeMarkerShapeKind shape,
  OndeMarkerPattern pattern,
  Size size,
) => _geometries.putIfAbsent((
  shape,
  pattern,
  size,
), () => _OndeGeometry(shape, pattern, size));

/// Peint un marqueur ONDE : la [shape] de `04-ui.md` § 2, son [pattern], et
/// le halo noir de [stationMarkerBorderWidth] px que la même spécification
/// pose sur tous les marqueurs.
///
/// La forme est **dessinée**, jamais un glyphe de police : au zoom national
/// tous les marqueurs du viewport élargi sont peints à chaque trame, et un
/// glyphe coûterait une passe de mise en page de texte par marqueur
/// (`NFR-01`).
@immutable
class OndeMarkerPainter extends CustomPainter {
  const OndeMarkerPainter({
    required this.fillColor,
    required this.shape,
    required this.pattern,
  });

  /// Le peintre de [category] vue à l'âge [age] : teinte de la catégorie,
  /// ou gris passé 60 jours (`BR-010`). Forme et motif, eux, ne dépendent
  /// jamais de l'âge.
  factory OndeMarkerPainter.forCategory({
    required FlowCategory category,
    required CampaignAge age,
  }) => OndeMarkerPainter(
    fillColor: ondeEffectiveColor(category: category, age: age),
    shape: ondeCategoryShape(category),
    pattern: ondeCategoryPattern(category),
  );

  /// La teinte réellement peinte — déjà passée par [ondeEffectiveColor].
  final Color fillColor;

  /// La forme du marqueur.
  final OndeMarkerShapeKind shape;

  /// Le motif de remplissage.
  final OndeMarkerPattern pattern;

  /// Deux appels de dessin au plus, et **aucune allocation** : géométrie et
  /// `Paint` sont mis en cache hors de cette méthode.
  @override
  void paint(Canvas canvas, Size size) {
    final _OndeGeometry geometry = _geometryFor(shape, pattern, size);

    final Path? fill = geometry.fill;
    if (fill != null) {
      canvas.drawPath(fill, _fillPaintFor(fillColor));
    }

    canvas.drawPath(geometry.halo, _haloPaint);
  }

  @override
  bool shouldRepaint(OndeMarkerPainter oldDelegate) => oldDelegate != this;

  @override
  bool operator ==(Object other) =>
      other is OndeMarkerPainter &&
      other.fillColor == fillColor &&
      other.shape == shape &&
      other.pattern == pattern;

  @override
  int get hashCode => Object.hash(fillColor, shape, pattern);
}

/// Le marqueur d'un point ONDE, à l'échelle « écoulement ».
///
/// Une forme **dessinée** ([OndeMarkerPainter]) de [stationMarkerSize] px,
/// et un libellé porté par `Semantics` plutôt que peint dedans — à 12 px,
/// aucun texte n'atteindrait les seuils de lisibilité de `04-ui.md` § 3. La
/// cible tactile, elle, vaut `minimumTapTarget`
/// (`lib/features/shared/tap_target.dart`) : c'est l'appelant qui la pose
/// autour (voir `buildMapLayers`, `map_view.dart`).
///
/// Le `Semantics` est porté **ici** pour que la forme soit annonçable telle
/// quelle en légende, où elle n'a aucun point à nommer. Sur la carte, le
/// marqueur reprend l'annonce pour y joindre l'échelle et le nom du point,
/// et masque celle-ci (`excludeSemantics`) : un marqueur, un seul nœud
/// sémantique.
class OndeMarkerShape extends StatelessWidget {
  /// [observedAt] est la date de la dernière campagne. Le paramètre est
  /// **requis**, et nullable : `BR-010` ouvre sur « tout point ONDE affiche
  /// la date de sa dernière campagne », donc un appelant qui pose un
  /// marqueur de carte doit la fournir — l'oublier ferait perdre la date
  /// **silencieusement**, y compris pour une campagne récente. Le compilateur
  /// le refuse maintenant ; l'`assert` de `U3`, lui, ne couvrait que le cas
  /// gris (relecture du 2026-09-14).
  ///
  /// Le seul appelant légitime à passer `null` est la **légende**, qui parle
  /// d'une catégorie et d'aucune observation en particulier : elle l'écrit
  /// alors explicitement, et rien n'est inventé (`BR-007`).
  const OndeMarkerShape({
    required this.category,
    required this.age,
    required this.observedAt,
    super.key,
  });

  /// La catégorie d'écoulement observée.
  final FlowCategory category;

  /// L'âge de la campagne, calculé par `campaignAgeOf` (`BR-010`).
  final CampaignAge age;

  /// La date de la dernière campagne, sans heure (`T-08`). Nulle en légende
  /// seulement.
  final DateTime? observedAt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ondeMarkerLabel(
        category: category,
        age: age,
        observedAt: observedAt,
      ),
      child: CustomPaint(
        // Taille explicite : sans elle, `CustomPaint` peint dans la boîte
        // que son parent lui accorde — `Size.zero` là où ce parent lui
        // laisse des contraintes lâches, donc un marqueur invisible.
        size: const Size.square(stationMarkerSize),
        painter: OndeMarkerPainter.forCategory(category: category, age: age),
      ),
    );
  }
}

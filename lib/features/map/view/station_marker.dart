// La pastille d'une station sur l'échelle « débit » (T1-U2), et ses mesures.
//
// ⚠️ **En T1, toute station est « Indéterminé »** au sens de `BR-004` : le
// percentile vient d'un asset généré hors exécution (`ADR-003`), et cet
// asset n'est pas produit avant T1+. Aucune station ne peut donc être
// qualifiée « Très bas » ou « Habituel pour la saison », et rien ici
// n'invente de seuil. La teinte est celle que `04-ui.md` § 2 (échelle 2,
// ligne « Indéterminé ») donne déjà à cet état : `#767676`, recopiée, jamais
// choisie ici.
//
// Ce qui distingue les états les uns des autres est donc **le motif et le
// libellé**, jamais la couleur — `04-ui.md` § 3 : « Aucune information n'est
// portée par la seule couleur », et la pastille doit rester lisible en
// niveaux de gris comme en achromatopsie.
//
// | État | Remplissage | Contour | Libellé annoncé |
// |---|---|---|---|
// | `Chargee(fraiche)` | plein | continu | aucun |
// | `Chargee(ancienne)` | plein | continu | « … il y a plus de 2 h » |
// | `Chargee(perimee)` | **atténué** | continu | « … il y a plus de 24 h » |
// | `SansDonnee` | creux | **pointillé** | « Aucune donnée disponible ici. » |
// | `NonChargee` | creux | continu | **aucun** |
// | `EnEchec` | creux | pointillé | « Donnée indisponible pour le moment. » |
//
// Le libellé n'est **pas dessiné** dans les 12 px de la pastille : il est
// porté par `Semantics`, pour le lecteur d'écran (`04-ui.md` § 3). La forme
// et le motif portent l'information visuelle.
//
// ⚠️ **`EnEchec` et `SansDonnee` partagent leur rendu visuel** — creux,
// contour pointillé — et ne se séparent que par le libellé annoncé. C'est un
// écart assumé : `04-ui.md` § 2 ne donne qu'un seul motif « rien à
// montrer » pour l'échelle 2, et en inventer un second serait inventer de la
// spécification. Ce qui distingue une panne d'une absence constatée reste
// donc le libellé **plus** l'avis de panne par source
// (`SourceUnavailableNotice`, `map_empty_states.dart`), que `BR-007` exige au
// niveau de l'écran.
//
// ⚠️ **Le « ? » de la forme ◇ + « ? » de `04-ui.md` § 2 n'est pas dessiné
// ici**, et c'est délibéré. Deux raisons, dans cet ordre :
// 1. au zoom national les 4 150 stations sont TOUTES peintes (`F2c`, aucun
//    clustering) ; un glyphe coûterait une passe de mise en page de texte
//    par marqueur, là où une forme dessinée coûte quatre segments (`NFR-01`) ;
// 2. à 12 px de côté, un « ? » n'atteindrait aucun des seuils de lisibilité
//    de `04-ui.md` § 3 — il serait un pâté, pas une information.
// Le « ? » reste écrit **dans la légende** (`map_legend.dart`), rendue une
// seule fois par écran : c'est là que la forme de `04-ui.md` est montrée en
// entier, et c'est la légende que l'usager lit pour interpréter un marqueur
// (`BR-008`).
//
// L'atténuation de `Chargee(perimee)` ne porte que sur le **remplissage** :
// le contour de 2 px garde son opacité pleine. `BR-005` l'exige mot pour
// mot — « elle réduit la saturation, pas la lisibilité » — et un `Opacity`
// posé sur toute la pastille délaverait aussi le halo.
//
// ## Rien n'est alloué par trame (relecture du 2026-09-14)
//
// Au zoom national les 4 150 marqueurs sont TOUS peints, à chaque trame d'un
// déplacement (`F2c`, aucun clustering ; `NFR-01`, jank déjà mesuré à 8,9 %
// sur la porte `F2`). Une version antérieure de `paint()` allouait, par
// marqueur et par trame, une `List<Offset>`, un `Path` et un à deux
// `Paint` : à soixante trames par seconde, cela fait plus d'un million
// d'objets par seconde à charge du ramasse-miettes, pour un dessin qui ne
// change jamais.
//
// Tout ce qui ne dépend pas de l'état est donc construit **une fois** et
// réutilisé :
// - le halo est identique pour les six états → un unique `_haloPaint` de
//   niveau bibliothèque ;
// - le remplissage ne prend que deux opacités (1 et
//   `_attenuatedFillOpacity`) → deux `Paint` pré-construits, plus un repli
//   qui alloue pour une valeur intermédiaire — le constructeur est public,
//   mais la fabrique par état n'en produit jamais ;
// - les sommets ne dépendent que de `size`, constante à `stationMarkerSize`
//   → une géométrie (`_MarkerGeometry`) mise en cache **par taille**, avec
//   le losange plein et son découpage en tirets déjà calculés. Le cache
//   tient une seule entrée en pratique.
//
// Aucun test ne peut prouver l'absence d'allocation à ce niveau — rien
// n'expose de compteur d'allocations depuis `flutter test`. Le choix est
// donc **documenté ici**, et les tests de rendu vérifient seulement qu'il
// n'a rien changé à ce qui se voit.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';

/// Gris de l'état « Indéterminé », recopié de `04-ui.md` § 2 (échelle 2 —
/// débit relatif à l'historique). Sur blanc, `#767676` tient 4,54:1
/// (`04-ui.md` § 3) : c'est la teinte que la spécification réserve à
/// « pas assez d'historique pour situer cette valeur » (`BR-004`).
const Color indetermineGrey = Color(0xFF767676);

/// Couleur du halo de marqueur. `04-ui.md` § 3 : « Contour de 2 px
/// systématique, blanc sur fond sombre, **noir sur fond clair** ». Le seul
/// fond de carte du projet est le plan IGN Géoplateforme, un fond clair —
/// le halo est donc noir. Le jour où un fond sombre est proposé, cette
/// constante devient une fonction du fond, pas un choix de cette tâche.
///
/// Privée : ce fichier est son seul appelant, et les tests de teinte
/// retapent le littéral — sur ce projet le test **est** la recopie vérifiée
/// de `04-ui.md`, jamais un renvoi vers la constante qu'il contrôle.
const Color _stationMarkerHalo = Color(0xFF000000);

/// Épaisseur du halo, en pixels logiques : 2 px, recopiés de `04-ui.md`
/// § 3. Jamais atténuée, quel que soit l'état.
const double stationMarkerBorderWidth = 2;

/// Taille d'une pastille de station, en pixels logiques. Volontairement
/// petite : ce n'est **pas** la cible tactile — celle-ci vaut
/// [stationMarkerTapTarget], et la pastille est centrée dedans. Quatre mille
/// cent cinquante pastilles de 44 px couvriraient la France d'un aplat ;
/// c'est la zone de tap, invisible, qui porte l'exigence d'accessibilité.
const double stationMarkerSize = 12;

/// Côté de la zone de tap d'un marqueur, en pixels logiques : 44 × 44 pt,
/// recopié de `04-ui.md` § 3 (cibles tactiles ≥ 44 × 44 pt iOS).
///
/// ⚠️ La fiche station porte la même exigence, avec sa PROPRE constante
/// (`minimumTapTarget`,
/// `lib/features/station_sheet/view/station_summary_sheet.dart`) : une
/// tranche n'importe pas une autre tranche
/// (`test/architecture/layers_test.dart`, règle `feature-vers-feature`). Les
/// deux constantes recopient la même ligne de `04-ui.md`, jamais l'une
/// l'autre — le jour où une troisième tranche en a besoin, c'est le signe
/// qu'il faut un endroit commun, et cela se tranche avec le commanditaire.
const double stationMarkerTapTarget = 44;

/// Opacité du remplissage d'une observation périmée (`BR-005`). Le contour,
/// lui, reste à opacité pleine : l'atténuation doit réduire la saturation,
/// pas la lisibilité.
///
/// ⚠️ **C'est un paramètre choisi ici**, pas un chiffre repris d'une règle :
/// ni `BR-005` ni `04-ui.md` § 3 n'en donnent la valeur — la règle dit
/// « atténué », la spécification exige « ≥ 3:1 pour les formes de
/// marqueur ». Sur un gris ([indetermineGrey]), réduire l'alpha ne réduit
/// d'ailleurs pas la *saturation*, qui est nulle : il réduit le contraste du
/// remplissage contre le fond de carte. Ce qui tient les 3:1 quoi qu'il
/// arrive est le **halo de 2 px**, à opacité pleine sur les six états — lui,
/// et non le remplissage, porte la lisibilité de la forme.
///
/// Privée : la fabrique par état de ce fichier est son seul appelant.
const double _attenuatedFillOpacity = 0.4;

/// Longueur d'un tiret du contour pointillé, en pixels logiques.
const double _dashLength = 2;

/// Longueur d'un vide entre deux tirets, en pixels logiques.
const double _dashGap = 2;

/// Le halo des six états : même couleur, même épaisseur, même style. Un
/// unique objet de niveau bibliothèque, construit au premier marqueur peint
/// et jamais par trame (voir l'en-tête de ce fichier).
final Paint _haloPaint = Paint()
  ..color = _stationMarkerHalo
  ..style = PaintingStyle.stroke
  ..strokeWidth = stationMarkerBorderWidth;

/// Le remplissage plein, celui d'une observation fraîche ou ancienne.
final Paint _opaqueFillPaint = Paint()
  ..color = indetermineGrey
  ..style = PaintingStyle.fill;

/// Le remplissage atténué d'une observation périmée (`BR-005`).
final Paint _attenuatedFillPaint = Paint()
  ..color = indetermineGrey.withValues(alpha: _attenuatedFillOpacity)
  ..style = PaintingStyle.fill;

/// Le `Paint` de remplissage pour [opacity], sans allocation pour les deux
/// seules valeurs que produit [StationMarkerPainter.forState].
///
/// Le repli, lui, alloue : le constructeur de [StationMarkerPainter] est
/// public et accepte n'importe quelle opacité. Aucun appelant du projet n'en
/// produit une troisième ; le jour où l'un le ferait, il paierait une
/// allocation par trame — pas une pastille fausse.
Paint _fillPaintFor(double opacity) {
  if (opacity >= 1) {
    return _opaqueFillPaint;
  }
  if (opacity == _attenuatedFillOpacity) {
    return _attenuatedFillPaint;
  }
  return Paint()
    ..color = indetermineGrey.withValues(alpha: opacity)
    ..style = PaintingStyle.fill;
}

/// Le tracé d'une pastille pour une taille donnée : le losange fermé, et sa
/// version découpée en tirets. Ne dépend NI de l'état NI de l'opacité —
/// seulement de `size`, qui vaut [stationMarkerSize] partout dans le projet.
///
/// Les deux champs sont `final` et **ne sont jamais modifiés après
/// construction** — pas d'`@immutable` pour autant : un `Path` reste
/// mutable en droit, et l'annotation promettrait plus que la classe ne peut
/// tenir. C'est la discipline de ce fichier qui garantit l'invariant, et lui
/// seul lit ces tracés.
class _MarkerGeometry {
  _MarkerGeometry(Size size)
    : diamond = _diamondPath(size),
      dashes = _dashedPath(size);

  /// Le losange fermé : rempli, ou tracé d'un trait continu.
  final Path diamond;

  /// Les mêmes quatre côtés, découpés en tirets de [_dashLength] séparés de
  /// [_dashGap] — un seul `Path`, donc **un** appel de dessin au lieu d'un
  /// par tiret.
  final Path dashes;

  /// Les quatre sommets, dans le sens horaire depuis le haut. Le halo est
  /// centré sur le tracé : la moitié déborderait hors de la boîte sans cette
  /// marge, et le losange serait rogné.
  static List<Offset> _vertices(Size size) {
    const double inset = stationMarkerBorderWidth / 2;
    final double middleX = size.width / 2;
    final double middleY = size.height / 2;
    return <Offset>[
      Offset(middleX, inset),
      Offset(size.width - inset, middleY),
      Offset(middleX, size.height - inset),
      Offset(inset, middleY),
    ];
  }

  static Path _diamondPath(Size size) =>
      Path()..addPolygon(_vertices(size), true);

  /// Découpe les quatre côtés en tirets. Écrit à la main plutôt qu'avec
  /// `Path.computeMetrics` : sur quatre segments droits, l'interpolation
  /// linéaire suffit — et le résultat est calculé UNE fois par taille.
  static Path _dashedPath(Size size) {
    final List<Offset> vertices = _vertices(size);
    final Path path = Path();

    for (int index = 0; index < vertices.length; index++) {
      final Offset from = vertices[index];
      final Offset to = vertices[(index + 1) % vertices.length];
      final double length = (to - from).distance;
      if (length <= 0) {
        continue;
      }

      final Offset direction = (to - from) / length;
      double start = 0;
      while (start < length) {
        final double end = start + _dashLength > length
            ? length
            : start + _dashLength;
        final Offset dashStart = from + direction * start;
        final Offset dashEnd = from + direction * end;
        path
          ..moveTo(dashStart.dx, dashStart.dy)
          ..lineTo(dashEnd.dx, dashEnd.dy);
        start = end + _dashGap;
      }
    }

    return path;
  }
}

/// Les géométries déjà calculées, par taille. En pratique **une seule
/// entrée** : toutes les pastilles du projet mesurent [stationMarkerSize].
/// Une `Map` plutôt qu'un champ unique pour qu'une pastille d'une autre
/// taille — un test, une légende un jour plus grande — ne fasse pas
/// recalculer la géométrie de toutes les autres à chaque trame.
final Map<Size, _MarkerGeometry> _geometries = <Size, _MarkerGeometry>{};

/// La géométrie de [size], calculée au premier besoin puis réutilisée.
_MarkerGeometry _geometryFor(Size size) =>
    _geometries.putIfAbsent(size, () => _MarkerGeometry(size));

/// Style du contour d'une pastille. Deux valeurs, et elles suffisent : le
/// pointillé dit « rien à montrer ici », le continu dit « une forme pleine
/// ou un chargement en cours ».
enum StationMarkerOutline {
  /// Trait plein.
  continu,

  /// Trait discontinu — le motif que `04-ui.md` § 2 associe à l'absence
  /// d'observation.
  pointille,
}

/// Peint le losange d'une station : un remplissage [indetermineGrey] à
/// [fillOpacity], et un halo de [stationMarkerBorderWidth] px en
/// [stationMarkerHalo], continu ou pointillé selon [outline].
///
/// Le losange (◇) est la forme de l'état « Indéterminé » de l'échelle 2
/// (`04-ui.md` § 2). Il est **dessiné**, quatre segments et un remplissage,
/// jamais un glyphe : voir l'en-tête de ce fichier.
@immutable
class StationMarkerPainter extends CustomPainter {
  const StationMarkerPainter({
    required this.fillOpacity,
    required this.outline,
  });

  /// Le rendu de [state]. `switch` exhaustif sur une `sealed class`
  /// (`BR-011`) : un état ajouté au domaine sans branche ici est une erreur
  /// de compilation, jamais un marqueur muet à l'écran.
  factory StationMarkerPainter.forState(StationMapState state) =>
      switch (state) {
        Chargee(freshness: Freshness.fraiche) => const StationMarkerPainter(
          fillOpacity: 1,
          outline: StationMarkerOutline.continu,
        ),
        // Même rendu visuel que `fraiche` : ce qui distingue une observation
        // ancienne est son libellé « il y a N h » (`BR-005`), pas sa forme.
        Chargee(freshness: Freshness.ancienne) => const StationMarkerPainter(
          fillOpacity: 1,
          outline: StationMarkerOutline.continu,
        ),
        Chargee(freshness: Freshness.perimee) => const StationMarkerPainter(
          fillOpacity: _attenuatedFillOpacity,
          outline: StationMarkerOutline.continu,
        ),
        SansDonnee() => const StationMarkerPainter(
          fillOpacity: 0,
          outline: StationMarkerOutline.pointille,
        ),
        NonChargee() => const StationMarkerPainter(
          fillOpacity: 0,
          outline: StationMarkerOutline.continu,
        ),
        EnEchec() => const StationMarkerPainter(
          fillOpacity: 0,
          outline: StationMarkerOutline.pointille,
        ),
      };

  /// Opacité du remplissage, de `0` (creux) à `1` (plein).
  final double fillOpacity;

  /// Style du halo.
  final StationMarkerOutline outline;

  /// Deux appels de dessin au plus, et **aucune allocation** : géométrie et
  /// `Paint` sont mis en cache hors de cette méthode (voir l'en-tête de ce
  /// fichier). C'est ce qui rend tenable de peindre 4 150 pastilles à chaque
  /// trame d'un déplacement (`NFR-01`).
  @override
  void paint(Canvas canvas, Size size) {
    final _MarkerGeometry geometry = _geometryFor(size);

    if (fillOpacity > 0) {
      canvas.drawPath(geometry.diamond, _fillPaintFor(fillOpacity));
    }

    // `switch` exhaustif sur un `enum` fermé (`BR-011`) : un style de
    // contour ajouté sans branche ici ne compile pas.
    canvas.drawPath(switch (outline) {
      StationMarkerOutline.continu => geometry.diamond,
      StationMarkerOutline.pointille => geometry.dashes,
    }, _haloPaint);
  }

  @override
  bool shouldRepaint(StationMarkerPainter oldDelegate) => oldDelegate != this;

  @override
  bool operator ==(Object other) =>
      other is StationMarkerPainter &&
      other.fillOpacity == fillOpacity &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(fillOpacity, outline);
}

/// Pastille d'une station sur la carte, à l'échelle « débit ».
///
/// Une forme **dessinée** ([StationMarkerPainter]), jamais un glyphe de
/// police, et un libellé porté par `Semantics` plutôt que peint dans les
/// 12 px du losange. Le détail des choix est en tête de ce fichier.
class StationMarkerDot extends StatelessWidget {
  const StationMarkerDot({required this.state, super.key});

  /// L'état d'affichage de la station, tel que le ViewModel le rend
  /// (`MapViewModel.stateOf`).
  final StationMapState state;

  @override
  Widget build(BuildContext context) {
    // Le libellé vient du domaine (`stationMapStateLabel`), jamais d'une
    // recopie locale : une révision des seuils de `BR-005` doit se voir ici
    // sans qu'on y touche. Il est vide pour `NonChargee` — un chargement en
    // cours n'annonce aucun état (`BR-007`).
    return Semantics(
      label: stationMapStateLabel(state),
      // Taille explicite : sans elle, `CustomPaint` peint dans la boîte que
      // son parent lui accorde — `Size.zero` là où ce parent lui laisse des
      // contraintes lâches, donc une pastille invisible. Les appelants du
      // projet posent tous un `SizedBox` de [stationMarkerSize] autour ; la
      // taille est répétée ici pour que la pastille soit juste TOUTE SEULE,
      // et non par la grâce de son parent.
      child: CustomPaint(
        size: const Size.square(stationMarkerSize),
        painter: StationMarkerPainter.forState(state),
      ),
    );
  }
}

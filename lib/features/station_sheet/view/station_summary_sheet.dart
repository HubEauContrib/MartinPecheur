// La vue de la tranche fiche station (MVVM, ADR-014) : le SEUL endroit du
// projet où un nombre devient du texte. Les formateurs reçoivent des unités
// typées ([CubicMetresPerSecond], [Metres]), jamais un `double` nu — c'est
// `BR-002`, le bug le plus coûteux du projet : un `double` nu passe en l/s
// là où on attend des m³/s, et rien ne le voit.
//
// Aucun paquet de formatage (`intl`) n'est ajouté pour deux formateurs :
// virgule décimale et signe moins typographique tiennent en vingt
// lignes vérifiables, là où `intl` apporterait un catalogue de locales, une
// initialisation asynchrone et une dépendance de plus à surveiller (YAGNI).
// La date, elle, vit dans `lib/domain/formatting/display_date.dart` (`H1`).
//
// Trois règles d'écriture tenues ici, et testées :
// - une valeur ne s'affiche JAMAIS sans sa date ni sa source (`BR-001`,
//   point 32) : depuis `F1` d'Ergonomie, la valeur, sa date de mesure et sa
//   source sont dans la MÊME tuile, un seul nœud d'annonce (`MergeSemantics`)
//   — plus dans un seul `Text` ;
// - une valeur absente affiche la phrase d'absence de `UC-003 A3`, jamais un
//   `0` ni un tiret seul (`BR-007`) — un zéro mesuré est un assec, pas une
//   absence, et les deux ne doivent pas se ressembler ;
// - aucun des cinq mots bannis (`BR-003`) ni aucun mot de garantie
//   (`BR-014`) dans la copie du produit. Les libellés de statut et de
//   qualification, eux, viennent de l'API et sont rendus VERBATIM
//   (`BR-006`) : « Bonne » est le mot de Hub'Eau sur la qualité de la
//   mesure, pas un jugement du produit sur le débit. `BR-014` pose déjà ce
//   principe pour les libellés d'une autorité, cités tels quels et
//   attribués — ce n'est pas l'application qui parle.
//
// ⚠️ `stalenessNotice` n'est pas recalculé ici : il est déjà mis en forme
// par [StationSheetViewModel] (V1), qui seul connaît l'instant de référence.
// La vue le rend tel quel, ou ne rend rien.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show SheetWarningKind, sheetWarningText;
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

// Le ré-export de `minimumTapTarget` posé par `K1` est retiré (YAGNI,
// relecture du coordinateur du 2026-09-23) : cette fiche a longtemps déclaré
// SA PROPRE constante (dette actée en `U1`) ; ses appelants, y compris ses
// propres tests, importent désormais directement
// `features/shared/tap_target.dart`.

/// Clé du bouton de fermeture de la fiche, que le cadre commun
/// ([SheetFrame]) pose sur sa fermeture — le seul chemin qui ferme la
/// feuille. Nommée pour que le test puisse en mesurer la taille sans dépendre
/// d'une icône ou d'un libellé.
const Key stationSheetCloseButtonKey = Key('station-sheet-close');

/// La ligne de nature de l'en-tête de la fiche (spec § 11.2) : la station est
/// la seule fiche qui affiche son code.
String stationSheetNature(StationCode code) =>
    'Station hydrométrique · ${code.value}';

/// Le libellé du statut, attribué à Hub'Eau (spec § 11.2), au-dessus de sa
/// valeur.
const String stationStatusLabel = "Statut (Hub'Eau)";

/// Le libellé de la qualification, attribué à Hub'Eau (spec § 11.2), au-dessus
/// de sa valeur.
const String stationQualificationLabel = "Qualification (Hub'Eau)";

/// Clé de la tuile Débit : un seul nœud d'annonce (libellé, valeur, date,
/// source).
const Key stationDischargeTileKey = Key('station-discharge-tile');

/// Clé de la tuile Hauteur : un seul nœud d'annonce.
const Key stationLevelTileKey = Key('station-level-tile');

/// L'écart entre les deux tuiles, côte à côte comme l'une sous l'autre.
const double stationTileGap = 8;

/// Phrase d'absence d'une valeur, recopiée de `UC-003 A3` et de
/// `docs/02-specifications.md` (tableau des cas d'absence). Jamais un `0`,
/// jamais un tiret seul (`BR-007`).
const String valeurNonTransmise =
    "La station n'a pas transmis de valeur pour ce paramètre. Cela arrive "
    'lors des pannes, de la maintenance ou du gel.';

/// Absence de cours d'eau au référentiel : `Station.riverLabel` vaut `null`.
/// Une absence se dit, elle ne se masque pas par une ligne vide (`BR-007`).
const String coursDEauNonRenseigne = "Cours d'eau non renseigné";

/// L'espace entre un nombre et son unité : INSÉCABLE (U+00A0), comme le veut
/// la typographie française — la valeur ne se sépare pas de son unité, à 100 %
/// et 200 % (à 300 %, une tuile étroite peut encore couper l'unité). C'est
/// aussi ce qui fait voir « 47,8 m³/s » comme un seul segment à la règle des
/// tuiles (`PD13`, passe 1 de `F1` d'Ergonomie).
const String _unitSpace = '\u{00A0}';

/// Le débit [value] en texte affichable : `'47,8 m³/s'`, espace insécable
/// avant l'unité ([_unitSpace]). Reçoit une unité
/// typée, jamais un `double` nu (`BR-002`).
String formatDischarge(CubicMetresPerSecond value) =>
    '${_decimal(value.value)}${_unitSpace}m³/s';

/// La hauteur [value] en texte affichable : `'−1,232 m'`, espace insécable
/// avant l'unité ([_unitSpace]). Le signe est
/// conservé — une hauteur d'eau se lit sous un zéro d'échelle, la négative
/// n'est pas une anomalie à masquer.
String formatLevel(Metres value) => '${_decimal(value.value)}${_unitSpace}m';

/// Rend [value] avec une virgule décimale, arrondi à trois décimales puis
/// zéros de fin retirés (`47.0` → `'47'`, `0.05` → `'0,05'`), et le signe
/// moins TYPOGRAPHIQUE `−` (U+2212) — pas le trait d'union `-`, qui se
/// confond avec un tiret de séparation à l'écran.
///
/// Trois décimales : c'est la précision utile après conversion depuis les
/// unités brutes de l'API (l/s → m³/s, mm → m, `C-02`) — le millimètre pour
/// une hauteur, le litre par seconde pour un débit. Pas de séparateur de
/// milliers : sur `47800` il inviterait à lire une virgule.
///
/// ⚠️ Une valeur NON NULLE qui s'arrondirait à zéro rend une **borne** —
/// `'< 0,001'`, ou `'> −0,001'` sous zéro — jamais `'0'` : un zéro mesuré
/// est un assec, un débit infime n'en est pas un, et les afficher pareil
/// inventerait l'information qui les sépare (`BR-007`). La borne garde le
/// sens de lecture : au-dessous de 0,001, au-dessus de −0,001. Un zéro
/// exact reste `'0'`, sans signe : `'−0'` ne veut rien dire à l'écran.
String _decimal(double value) {
  String text = value.abs().toStringAsFixed(3);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '');
    text = text.replaceAll(RegExp(r'\.$'), '');
  }
  text = text.replaceAll('.', ',');

  if (text == '0') {
    // `value != 0` est faux pour `-0.0` comme pour `0.0` : les deux zéros
    // restent un zéro mesuré, aucune borne.
    if (value != 0) {
      return value.isNegative ? '> −0,001' : '< 0,001';
    }
    return text;
  }

  if (value.isNegative) {
    return '−$text';
  }
  return text;
}

/// Le libellé d'une tuile, du statut et de la qualification : 12, gras,
/// `#3A4148` — la couleur de la nature du cadre commun (spec § 6.1).
const TextStyle _labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  color: Color(0xFF3A4148),
);

/// Le filet d'une tuile : celui des filets déjà en usage (`sheet_frame.dart`).
const Color _tileRuleColor = Color(0xFFC9CFC4);

/// La phrase datée de la fenêtre « ⚠ Avertissement » d'une fiche prête : la
/// date de la mesure la plus significative — le débit d'abord, la hauteur
/// seule sinon, un ORDRE choisi par `W4`, pas prescrit par `UC-003 § 1`, qui ne
/// connaît qu'« la mesure ». Sans aucune des deux, aucune mesure n'existe : la
/// fenêtre s'ouvre alors sans phrase propre, jamais une phrase inventée (« sans
/// date, aucun encart », arbitrage du commanditaire du 2026-09-23).
String? _warningExtraText(StationSheetData data, UtcOffsetOf utcOffsetOf) {
  final DateTime? warningDate =
      data.discharge?.measuredAt ?? data.level?.measuredAt;
  return warningDate == null
      ? null
      : sheetWarningText(
          SheetWarningKind.station,
          warningDate,
          offsetOf: utcOffsetOf,
        );
}

/// Le corps de la fiche d'une station prête, dans l'ordre de la spec
/// d'Ergonomie (§ 6.2, critère 11) : le titre ; « cours d'eau · Département
/// NN » ; deux tuiles, Débit mis en avant puis Hauteur ; « Statut
/// (Hub'Eau) » et « Qualification (Hub'Eau) », chacun au-dessus de sa valeur ;
/// l'avis de fraîcheur s'il y en a un.
///
/// Le contrôle « ⚠ Avertissement » n'est plus ici : il est dans l'en-tête
/// épinglé du cadre commun ([SheetFrame]), que pose [StationSheetPanel].
///
/// Ne connaît aucun dépôt et aucun ViewModel : elle reçoit un
/// [StationSheetData] déjà prêt et l'affiche. C'est ce qui la rend testable
/// sans réseau, sans asset et sans carte. Elle répond aux demandes de
/// dimensions intrinsèques (contrat de [SheetFrame.body]) : ni
/// `LayoutBuilder` ni `ListView` ; la disposition des tuiles se décide dans un
/// `RenderObject` qui sait calculer ses intrinsèques.
class StationSummarySheet extends StatelessWidget {
  const StationSummarySheet({
    required this.data,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// Les données à afficher, produites par [StationSheetViewModel].
  final StationSheetData data;

  /// Le décalage UTC → heure locale, demandé pour l'instant affiché (`H1`) —
  /// par défaut celui de la machine, injectable par un test.
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    final String? stalenessNotice = data.stalenessNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          data.station.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(
          '${data.station.riverLabel ?? coursDEauNonRenseigne} · '
          'Département ${data.station.departement.value}',
        ),
        const SizedBox(height: 12),
        _MeasurementTiles(
          children: <Widget>[
            _MeasurementTile(
              key: stationDischargeTileKey,
              label: 'Débit',
              // Accord au masculin pour le débit, au féminin pour la
              // hauteur : le participe s'accorde avec la grandeur, pas avec
              // la mesure.
              measuredWord: 'mesuré',
              // Le débit est MIS EN AVANT (spec § 6.2) : sa valeur en 26.
              valueFontSize: 26,
              measurement: _dischargeMeasurement(data),
              utcOffsetOf: utcOffsetOf,
            ),
            _MeasurementTile(
              key: stationLevelTileKey,
              label: 'Hauteur',
              measuredWord: 'mesurée',
              valueFontSize: 20,
              measurement: _levelMeasurement(data),
              utcOffsetOf: utcOffsetOf,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(stationStatusLabel, style: _labelStyle),
        Text(data.statusLabel),
        const SizedBox(height: 8),
        const Text(stationQualificationLabel, style: _labelStyle),
        Text(data.qualificationLabel),
        if (stalenessNotice != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            stalenessNotice,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

/// Une valeur affichable et l'instant où elle a été mesurée. Les deux
/// voyagent ENSEMBLE, dans un seul objet nullable : `BR-001` interdit
/// d'afficher une valeur sans sa date, et deux paramètres nullables
/// distincts laisseraient un appelant en fournir un seul.
typedef _Measurement = ({String value, DateTime measuredAt});

/// Le débit affichable et sa date, ou `null` si la station n'a transmis
/// aucune valeur de débit (`BR-007`). `discharge` peut être non nul alors
/// que sa valeur de débit l'est : l'observation existe, la grandeur manque —
/// et `measuredAt` daterait alors une mesure qui n'a pas eu lieu.
_Measurement? _dischargeMeasurement(StationSheetData data) {
  final HydroObservation? observation = data.discharge;
  final CubicMetresPerSecond? value = observation?.discharge;
  if (observation == null || value == null) {
    return null;
  }
  return (value: formatDischarge(value), measuredAt: observation.measuredAt);
}

/// La hauteur affichable et sa date, ou `null` si la station n'a transmis
/// aucune valeur de hauteur (`BR-007`).
_Measurement? _levelMeasurement(StationSheetData data) {
  final HydroObservation? observation = data.level;
  final Metres? value = observation?.level;
  if (observation == null || value == null) {
    return null;
  }
  return (value: formatLevel(value), measuredAt: observation.measuredAt);
}

/// Une tuile : le libellé de la grandeur, sa valeur, « mesuré(e) le
/// JJ/MM/AAAA à HH:MM » et la source — ou, sans valeur, le libellé puis la
/// phrase d'absence de `UC-003 A3`, jamais un `0`, un tiret ou une tuile vide
/// (`BR-007`).
///
/// La tuile est UN SEUL nœud d'annonce ([MergeSemantics]) qui dit libellé,
/// valeur, date et source : c'est ce qui tient `BR-001` (point 32) — aucune
/// valeur ne s'annonce sans sa date ni sa source —, là où la fiche d'avant
/// les mettait dans un seul `Text`. Les quatre textes restent dans le même
/// widget, qu'aucun remaniement de mise en page ne sépare.
class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({
    required this.label,
    required this.measuredWord,
    required this.valueFontSize,
    required this.measurement,
    required this.utcOffsetOf,
    super.key,
  });

  /// Nom de la grandeur : « Débit », « Hauteur ».
  final String label;

  /// Le participe accordé à la grandeur : « mesuré », « mesurée ».
  final String measuredWord;

  /// La taille de la valeur : 26 pour le débit, mis en avant ; 20 pour la
  /// hauteur.
  final double valueFontSize;

  /// La valeur déjà formatée AVEC sa date, ou `null` si la station n'a rien
  /// transmis. Un seul paramètre nullable pour les deux : il n'existe pas
  /// d'état « une valeur sans date » à représenter (`BR-001`).
  final _Measurement? measurement;

  /// Le décalage UTC → heure locale, demandé pour l'instant de [measurement]
  /// (`H1`).
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    final _Measurement? measurement = this.measurement;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: _tileRuleColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: _labelStyle),
              if (measurement == null)
                const Text(valeurNonTransmise)
              else ...<Widget>[
                Text(
                  measurement.value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    // Chiffres tabulaires : une valeur qui change ne fait pas
                    // danser ses chiffres.
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                Text(
                  '$measuredWord le '
                  '${formatLocalDateTime(measurement.measuredAt, offsetOf: utcOffsetOf)}',
                ),
                const Text(hydrometrieSourceName),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Les deux tuiles : CÔTE À CÔTE quand chacune tient dans la moitié de la
/// largeur sans couper un mot — sa largeur intrinsèque minimale, celle de son
/// mot le plus long —, L'UNE SOUS L'AUTRE sinon (`PD13`, au lieu d'un seuil de
/// largeur écrit dans `lib/`). Débit d'abord, à gauche ou en haut.
///
/// La décision se prend dans un `RenderObject` ([_RenderMeasurementTiles]) et
/// non dans un `LayoutBuilder` : la mise en page de la carte demande au cadre
/// de la fiche ses hauteurs intrinsèques, et un `LayoutBuilder` lèverait une
/// erreur (note d'architecture du plan d'Ergonomie). Les intrinsèques
/// appliquent la même règle que la mise en page.
class _MeasurementTiles extends MultiChildRenderObjectWidget {
  const _MeasurementTiles({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasurementTiles();
}

class _TileParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMeasurementTiles extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TileParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TileParentData) {
      child.parentData = _TileParentData();
    }
  }

  List<RenderBox> get _tiles {
    final List<RenderBox> tiles = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      tiles.add(child);
      child = childAfter(child);
    }
    return tiles;
  }

  double get _gaps => stationTileGap * (childCount > 1 ? childCount - 1 : 0);

  /// La largeur d'une tuile côte à côte, dans [width].
  double _columnWidth(double width) => (width - _gaps) / childCount;

  /// La règle : côte à côte si chaque tuile tient dans sa colonne sans couper
  /// un mot. Une largeur non bornée laisse toute la place : côte à côte.
  bool _sideBySide(double width) {
    if (!width.isFinite) return true;
    final double column = _columnWidth(width);
    return _tiles.every(
      (RenderBox tile) => tile.getMinIntrinsicWidth(double.infinity) <= column,
    );
  }

  /// La plus large des largeurs ENTIÈRES des tuiles : la colonne commune
  /// quand rien ne borne la largeur.
  double get _widestMaxWidth {
    double widest = 0;
    for (final RenderBox tile in _tiles) {
      final double w = tile.getMaxIntrinsicWidth(double.infinity);
      if (w > widest) widest = w;
    }
    return widest;
  }

  /// La largeur d'une tuile posée côte à côte dans [width] : sa colonne, ou,
  /// sans borne, la colonne commune [_widestMaxWidth] — des colonnes égales
  /// dans les deux cas.
  double _sideTileWidth(double width) =>
      width.isFinite ? _columnWidth(width) : _widestMaxWidth;

  /// La hauteur de la paire à [width], par la mesure [height] de chaque
  /// tuile — l'intrinsèque minimale, maximale, ou la mise en page sèche.
  double _heightAt(
    double width,
    double Function(RenderBox tile, double tileWidth) height,
  ) {
    final List<RenderBox> tiles = _tiles;
    if (tiles.isEmpty) return 0;
    if (_sideBySide(width)) {
      double tallest = 0;
      for (final RenderBox tile in tiles) {
        final double h = height(tile, _sideTileWidth(width));
        if (h > tallest) tallest = h;
      }
      return tallest;
    }
    double total = _gaps;
    for (final RenderBox tile in tiles) {
      total += height(tile, width);
    }
    return total;
  }

  /// La largeur occupée : celle des contraintes, ou, non bornée, celle des
  /// tuiles côte à côte à leur largeur entière.
  double _laidOutWidth(double width) =>
      width.isFinite ? width : computeMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicWidth(double height) {
    // L'une sous l'autre, la paire n'est pas plus étroite que la plus large
    // de ses tuiles.
    double widest = 0;
    for (final RenderBox tile in _tiles) {
      final double w = tile.getMinIntrinsicWidth(double.infinity);
      if (w > widest) widest = w;
    }
    return widest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    // Côte à côte, en colonnes égales : chacune à la largeur entière de la
    // plus large tuile, pour qu'aucune ne se replie à cette largeur.
    return childCount * _widestMaxWidth + _gaps;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightAt(
    width,
    (RenderBox tile, double tileWidth) => tile.getMinIntrinsicHeight(tileWidth),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _heightAt(
    width,
    (RenderBox tile, double tileWidth) => tile.getMaxIntrinsicHeight(tileWidth),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final double height = _heightAt(
      width,
      (RenderBox tile, double tileWidth) =>
          tile.getDryLayout(BoxConstraints.tightFor(width: tileWidth)).height,
    );
    return constraints.constrain(Size(_laidOutWidth(width), height));
  }

  @override
  void performLayout() {
    final double width = constraints.maxWidth;
    final List<RenderBox> tiles = _tiles;
    if (_sideBySide(width)) {
      // Côte à côte : chaque tuile à la largeur de sa colonne, puis toutes à
      // la hauteur de la plus haute — deux tuiles de même hauteur.
      double tallest = 0;
      for (final RenderBox tile in tiles) {
        tile.layout(
          BoxConstraints.tightFor(width: _sideTileWidth(width)),
          parentUsesSize: true,
        );
        if (tile.size.height > tallest) tallest = tile.size.height;
      }
      double x = 0;
      for (final RenderBox tile in tiles) {
        tile.layout(
          BoxConstraints.tight(Size(tile.size.width, tallest)),
          parentUsesSize: true,
        );
        (tile.parentData! as _TileParentData).offset = Offset(x, 0);
        x += tile.size.width + stationTileGap;
      }
      size = constraints.constrain(Size(_laidOutWidth(width), tallest));
      return;
    }
    // L'une sous l'autre : chaque tuile sur toute la largeur.
    double y = 0;
    for (final RenderBox tile in tiles) {
      tile.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      (tile.parentData! as _TileParentData).offset = Offset(0, y);
      y += tile.size.height + stationTileGap;
    }
    size = constraints.constrain(
      Size(width, tiles.isEmpty ? 0 : y - stationTileGap),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Le panneau de la fiche station : rend l'état porté par
/// [StationSheetViewModel], quel qu'il soit. `switch` exhaustif sur un
/// `sealed` (`BR-011`) — une branche oubliée est une erreur de compilation,
/// pas un écran muet.
///
/// Chaque état visible se dit dans le cadre commun des fiches ([SheetFrame],
/// `F1` d'Ergonomie, spec § 6.1) : en-tête épinglé — « Station hydrométrique
/// · code », l'étoile, la fermeture, puis « ⚠ Avertissement », présent
/// désormais en chargement, en échec et introuvable aussi (`PD7`) — et corps
/// qui défile. La phrase datée de la fenêtre d'avertissement n'existe qu'en
/// [Prete] : ailleurs, aucune mesure n'est connue.
///
/// La fiche ne se ferme que par [onClose] : un tap sur la carte hors
/// marqueur ne la ferme pas. Une fermeture par un geste que rien ne teste
/// serait une magie invisible, et ferait disparaître la fiche sans que
/// l'usager l'ait demandé.
class StationSheetPanel extends StatelessWidget {
  const StationSheetPanel({
    required this.state,
    required this.onClose,
    this.favoriteStar,
    this.onToggleFavorite,
    this.utcOffsetOf = systemUtcOffsetOf,
    this.bodyScrollController,
    super.key,
  }) : assert(
         favoriteStar == null || onToggleFavorite != null,
         'une étoile à montrer exige son rappel de bascule',
       );

  /// L'état courant de la fiche.
  final StationSheetState state;

  /// Appelé par le bouton de fermeture — branché sur
  /// `StationSheetViewModel.close`.
  final VoidCallback onClose;

  /// L'étoile de favori à montrer, telle que `StationSheetViewModel` la
  /// produit (`S7a` de T3). `null` : aucune étoile et aucun emplacement vide.
  final FavoriteStar? favoriteStar;

  /// Appelé par l'étoile — branché sur `StationSheetViewModel.toggleFavorite`.
  /// Obligatoire dès que [favoriteStar] est non nul.
  final VoidCallback? onToggleFavorite;

  /// Le décalage UTC → heure locale, transmis tel quel à
  /// [StationSummarySheet] et à la phrase datée de l'avertissement (`H1`) —
  /// par défaut celui de la machine, injectable par un test.
  final UtcOffsetOf utcOffsetOf;

  /// La position du corps du cadre, que l'appelant remet à zéro à chaque
  /// ouverture (`K4` de T3), ou `null`.
  final ScrollController? bodyScrollController;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      Fermee() => const SizedBox.shrink(),
      EnCours(:final StationCode code) => _frame(
        code,
        Text('Chargement de la station ${code.value}…'),
      ),
      Prete(:final StationSheetData data) => _frame(
        data.station.code,
        StationSummarySheet(data: data, utcOffsetOf: utcOffsetOf),
        warningExtraText: _warningExtraText(data, utcOffsetOf),
      ),
      // La cause technique (`EnEchec.cause`) n'est PAS affichée : c'est une
      // donnée de diagnostic, pas un texte pour l'usager. Le message nomme
      // la source défaillante et la station (`UC-001 A4`), et la feuille
      // n'est jamais vide.
      EnEchec(:final StationCode code) => _frame(
        code,
        Text(
          "Hub'Eau n'a pas répondu pour la station ${code.value}. Aucune "
          "valeur n'est disponible pour l'instant.",
        ),
      ),
      // Ici, AUCUNE source distante n'est en cause : la station est sur la
      // carte (4 150 points) et absente du référentiel embarqué (4 113
      // entités). Nommer Hub'Eau serait faux, et un écran muet serait pire
      // (`BR-007`). Le texte dit ce qui s'est passé, sans verbe
      // d'instruction (`BR-014`).
      Introuvable(:final StationCode code) => _frame(
        code,
        Text(
          'Aucune fiche pour la station ${code.value} : elle figure sur la '
          "carte mais pas dans le référentiel embarqué de l'application.",
        ),
      ),
    };
  }

  /// Le cadre commun d'un état visible de la station [code] : la nature, la
  /// fermeture (sa clé [stationSheetCloseButtonKey]), l'étoile, et
  /// [warningExtraText] — `null` hors [Prete].
  Widget _frame(StationCode code, Widget body, {String? warningExtraText}) {
    return SheetFrame(
      nature: stationSheetNature(code),
      closeButtonKey: stationSheetCloseButtonKey,
      onClose: onClose,
      favoriteStar: favoriteStar,
      onToggleFavorite: onToggleFavorite,
      bodyScrollController: bodyScrollController,
      warningExtraText: warningExtraText,
      body: body,
    );
  }
}

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
// - une valeur ne s'affiche JAMAIS sans sa date (`BR-001`) : la valeur et sa
//   date de mesure sont dans le MÊME `Text`, pas dans deux lignes qu'un
//   remaniement pourrait séparer ;
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
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

/// Côté minimal d'une cible tactile, en pixels logiques : 44 × 44 pt (iOS)
/// selon `04-ui.md` § 3. Recopié de la spécification, jamais choisi ici.
///
/// ⚠️ La carte tient la même exigence pour la zone de tap d'un marqueur,
/// avec sa PROPRE constante (`stationMarkerTapTarget`,
/// `lib/features/map/view/map_view.dart`) : une tranche n'importe pas une
/// autre tranche (`test/architecture/layers_test.dart`, règle
/// `feature-vers-feature`). Les deux constantes recopient la même ligne de
/// `04-ui.md`, elles ne se recopient pas l'une l'autre.
const double minimumTapTarget = 44.0;

/// Clé du bouton de fermeture de la fiche — le seul contrôle du panneau, et
/// le seul chemin qui ferme la feuille. Nommée pour que le test puisse en
/// mesurer la taille sans dépendre d'une icône ou d'un libellé.
const Key stationSheetCloseButtonKey = Key('station-sheet-close');

/// Phrase d'absence d'une valeur, recopiée de `UC-003 A3` et de
/// `docs/02-specifications.md` (tableau des cas d'absence). Jamais un `0`,
/// jamais un tiret seul (`BR-007`).
const String valeurNonTransmise =
    "La station n'a pas transmis de valeur pour ce paramètre. Cela arrive "
    'lors des pannes, de la maintenance ou du gel.';

/// Absence de cours d'eau au référentiel : `Station.riverLabel` vaut `null`.
/// Une absence se dit, elle ne se masque pas par une ligne vide (`BR-007`).
const String coursDEauNonRenseigne = "Cours d'eau non renseigné";

/// Le débit [value] en texte affichable : `'47,8 m³/s'`. Reçoit une unité
/// typée, jamais un `double` nu (`BR-002`).
String formatDischarge(CubicMetresPerSecond value) =>
    '${_decimal(value.value)} m³/s';

/// La hauteur [value] en texte affichable : `'−1,232 m'`. Le signe est
/// conservé — une hauteur d'eau se lit sous un zéro d'échelle, la négative
/// n'est pas une anomalie à masquer.
String formatLevel(Metres value) => '${_decimal(value.value)} m';

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

/// La feuille de résumé d'une station hydrométrique, dans l'ordre de
/// `04-ui.md` § « Fiche station hydrométrique » : identité (libellé, cours
/// d'eau, département), puis les deux grandeurs avec leur date, puis statut
/// et qualification, puis l'avis de fraîcheur s'il y en a un.
///
/// Ne connaît aucun dépôt et aucun ViewModel : elle reçoit un
/// [StationSheetData] déjà prêt et l'affiche. C'est ce qui la rend testable
/// sans réseau, sans asset et sans carte.
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(data.station.riverLabel ?? coursDEauNonRenseigne),
        Text('Département ${data.station.departement.value}'),
        const SizedBox(height: 8),
        _MeasurementLine(
          label: 'Débit',
          // Accord au masculin pour le débit, au féminin pour la hauteur :
          // le participe s'accorde avec la grandeur, pas avec la mesure.
          measuredWord: 'mesuré',
          measurement: _dischargeMeasurement(data),
          utcOffsetOf: utcOffsetOf,
        ),
        _MeasurementLine(
          label: 'Hauteur',
          measuredWord: 'mesurée',
          measurement: _levelMeasurement(data),
          utcOffsetOf: utcOffsetOf,
        ),
        const SizedBox(height: 8),
        Text('Statut : ${data.statusLabel}'),
        Text('Qualification : ${data.qualificationLabel}'),
        if (stalenessNotice != null) ...<Widget>[
          const SizedBox(height: 8),
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

/// Une grandeur et sa date de mesure, dans un SEUL `Text` : `BR-001` exige
/// qu'aucune valeur ne s'affiche sans sa date, et deux lignes séparées se
/// laisseraient dissocier par un remaniement de mise en page.
///
/// [measurement] nul rend la phrase d'absence de `UC-003 A3` — jamais un
/// `0`, un tiret, ou une ligne vide (`BR-007`).
class _MeasurementLine extends StatelessWidget {
  const _MeasurementLine({
    required this.label,
    required this.measuredWord,
    required this.measurement,
    required this.utcOffsetOf,
  });

  /// Nom de la grandeur : « Débit », « Hauteur ».
  final String label;

  /// Le participe accordé à la grandeur : « mesuré », « mesurée ».
  final String measuredWord;

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

    if (measurement == null) {
      return Text('$label : $valeurNonTransmise');
    }
    return Text(
      '$label : ${measurement.value} — $measuredWord le '
      '${formatLocalDateTime(measurement.measuredAt, offsetOf: utcOffsetOf)}',
    );
  }
}

/// Le panneau de la fiche station : rend l'état porté par
/// [StationSheetViewModel], quel qu'il soit. `switch` exhaustif sur un
/// `sealed` (`BR-011`) — une branche oubliée est une erreur de compilation,
/// pas un écran muet.
///
/// La fiche ne se ferme que par [onClose] : un tap sur la carte hors
/// marqueur ne la ferme pas. Une fermeture par un geste que rien ne teste
/// serait une magie invisible, et ferait disparaître la fiche sans que
/// l'usager l'ait demandé.
class StationSheetPanel extends StatelessWidget {
  const StationSheetPanel({
    required this.state,
    required this.onClose,
    super.key,
  });

  /// L'état courant de la fiche.
  final StationSheetState state;

  /// Appelé par le bouton de fermeture — branché sur
  /// `StationSheetViewModel.close`.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      Fermee() => const SizedBox.shrink(),
      EnCours(:final StationCode code) => _frame(
        Text('Chargement de la station ${code.value}…'),
      ),
      Prete(:final StationSheetData data) => _frame(
        StationSummarySheet(data: data),
      ),
      // La cause technique (`EnEchec.cause`) n'est PAS affichée : c'est une
      // donnée de diagnostic, pas un texte pour l'usager. Le message nomme
      // la source défaillante et la station (`UC-001 A4`), et la feuille
      // n'est jamais vide.
      EnEchec(:final StationCode code) => _frame(
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
        Text(
          'Aucune fiche pour la station ${code.value} : elle figure sur la '
          "carte mais pas dans le référentiel embarqué de l'application.",
        ),
      ),
    };
  }

  /// Le cadre commun aux quatre états visibles : le contenu, et le bouton de
  /// fermeture à sa droite.
  Widget _frame(Widget content) {
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: content),
            const SizedBox(width: 8),
            _CloseButton(onClose: onClose),
          ],
        ),
      ),
    );
  }
}

/// Le bouton de fermeture, dimensionné à [minimumTapTarget] par un
/// `SizedBox` explicite et non par les valeurs par défaut d'un bouton
/// Material : la taille est alors une propriété du code, mesurable par test
/// (`04-ui.md` § 3), pas un effet de thème.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fermer la fiche',
      child: GestureDetector(
        key: stationSheetCloseButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: const SizedBox(
          width: minimumTapTarget,
          height: minimumTapTarget,
          child: Center(child: Icon(Icons.close)),
        ),
      ),
    );
  }
}

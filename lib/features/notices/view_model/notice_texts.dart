// Les textes des avis reçus (N1 de T5, BR-016) : titre, corps et ligne
// « Reçu le » de chaque avis, recopiés du cadrage de T5 (§ 11.2) et de la
// décision PD12 du plan. Dart pur : aucun widget.
//
// Les noms de source viennent de `lib/domain/sources/source_names.dart`. Les
// niveaux et gravités se disent par les libellés existants du domaine. Un
// `switch` exhaustif sans branche par défaut (BR-011) : un avis ajouté sans
// texte est une erreur de compilation.

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';

/// Titre de l'écran des avis.
const String noticesScreenTitle = 'Avis reçus';

/// Marque d'un avis non lu.
const String noticeNewMark = 'Nouveau';

/// Texte d'un avis enregistré que cette version ne sait pas lire (Q3),
/// calqué sur celui d'un favori illisible.
const String unreadableNoticeText =
    "Avis non lisible par cette version de l'application";

/// Titre d'un avis de première lecture, crues comme sécheresse.
const String noticeFollowUpStartedTitle = 'Suivi commencé';

/// Titre d'un avis de lecture impossible.
const String noticeCheckImpossibleTitle = 'Vérification impossible';

/// Titre d'un avis de lieu qui ne peut pas être relu.
const String noticePlaceNotVerifiableTitle = 'Lieu non vérifiable';

/// Titre d'un avis de zone que la source ne cite plus.
const String noticeZoneNoLongerCitedTitle =
    'Restrictions sécheresse : zone plus citée';

/// Phrase d'un point sans zone d'alerte citée : un silence qui ne dit pas
/// l'absence (BR-007).
const String noticeNoZoneText =
    "$restrictionsSourceName ne cite aucune zone d'alerte à cet endroit. Cela "
    "ne dit pas qu'aucune restriction ne s'y applique.";

const String _decreeFaitFoi = "L'arrêté fait foi.";

/// L'adjectif d'un niveau publié (« verte », « jaune », « orange », « rouge »),
/// ou `null` pour un niveau non reconnu.
String? floodLevelAdjective(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'verte',
  Jaune() => 'jaune',
  Orange() => 'orange',
  Rouge() => 'rouge',
  NiveauCruesInconnu() => null,
};

/// Joint des libellés de lieux : « A », « A et B », « A, B et C ».
String joinPlaceLabels(List<String> labels) => switch (labels.length) {
  0 => '',
  1 => labels.first,
  _ => '${labels.sublist(0, labels.length - 1).join(', ')} et ${labels.last}',
};

/// Le titre d'un avis.
String noticeTitle(ReceivedNotice notice) => switch (notice) {
  UnreadableNotice() => unreadableNoticeText,
  FloodFollowUpStarted() ||
  DroughtFollowUpStarted() => noticeFollowUpStartedTitle,
  FloodLevelChanged(:final after) => switch (floodLevelAdjective(after)) {
    final String adjective => 'Vigilance crues $adjective',
    null => floodVigilanceTitle(after),
  },
  DroughtZoneChanged(:final after) =>
    after == null
        ? noticeZoneNoLongerCitedTitle
        : 'Restrictions sécheresse : ${droughtSeverityLabel(after)}',
  CheckImpossible() => noticeCheckImpossibleTitle,
  PlaceNotVerifiable() => noticePlaceNotVerifiableTitle,
};

/// Le corps d'un avis : le lieu en première ligne quand le texte ne le nomme
/// pas lui-même, puis les phrases. Un avis illisible n'a pas de corps.
List<String> noticeBody(
  ReceivedNotice notice, {
  UtcOffsetOf offsetOf = systemUtcOffsetOf,
}) {
  String dateTime(DateTime instant) =>
      formatLocalDateTime(instant, offsetOf: offsetOf);

  return switch (notice) {
    UnreadableNotice() => const <String>[],
    FloodFollowUpStarted() => <String>[
      notice.placeLabel,
      '${floodVigilanceTitle(notice.level)} — information de vigilance du '
          '${dateTime(notice.informationDate)} — $floodAttribution.',
      floodFollowUpReminder(notice.threshold),
    ],
    DroughtFollowUpStarted() => <String>[
      notice.placeLabel,
      if (notice.zones.isEmpty)
        noticeNoZoneText
      else
        for (final KnownZone zone in notice.zones)
          _zoneLine(
            name: zone.name,
            kind: zone.kind,
            severity: zone.severity,
            decreeValidFrom: zone.decreeValidFrom,
          ),
    ],
    FloodLevelChanged() => <String>[
      notice.placeLabel,
      if (floodLevelAdjective(notice.after) == null) floodUnknownLevelText,
      'Information de vigilance du ${dateTime(notice.informationDate)} — '
          '$floodAttribution. Avant : ${_floodBefore(notice.before)}',
    ],
    DroughtZoneChanged() => <String>[
      notice.placeLabel,
      _zoneChangeLine(notice),
    ],
    CheckImpossible() => <String>[_impossibleLine(notice)],
    PlaceNotVerifiable() => <String>[_notVerifiableLine(notice, dateTime)],
  };
}

/// La ligne « Reçu le JJ/MM/AAAA à HH:MM » d'un avis lisible.
String? noticeReceivedLine(
  ReadableNotice notice, {
  UtcOffsetOf offsetOf = systemUtcOffsetOf,
}) => 'Reçu le ${formatLocalDateTime(notice.receivedAt, offsetOf: offsetOf)}';

String _floodBefore(FloodVigilanceLevel before) =>
    switch (floodLevelAdjective(before)) {
      final String adjective => 'vigilance $adjective.',
      null => 'niveau de vigilance non reconnu.',
    };

String _zoneLine({
  required String name,
  required ZoneKind kind,
  required DroughtSeverity severity,
  required DateTime decreeValidFrom,
}) =>
    'Zone « $name » (${zoneKindLabel(kind)}) : '
    "${droughtSeverityLabel(severity)} d'après $restrictionsSourceName, "
    'arrêté en vigueur depuis le ${formatCalendarDate(decreeValidFrom)}.';

String _zoneChangeLine(DroughtZoneChanged notice) {
  final DroughtSeverity? after = notice.after;
  final DroughtSeverity? before = notice.before;
  final String beforeText = before == null
      ? "Avant : cette zone n'était pas citée à cet endroit."
      : 'Avant : ${droughtSeverityLabel(before)}.';
  final DateTime? decreeValidFrom = notice.decreeValidFrom;
  if (after == null || decreeValidFrom == null) {
    return '$restrictionsSourceName ne cite plus la zone « ${notice.zoneName} » '
        '(${zoneKindLabel(notice.zoneKind)}) à cet endroit. $beforeText Cela '
        "ne dit pas que les restrictions sont levées : l'arrêté fait foi.";
  }
  return '${_zoneLine(name: notice.zoneName, kind: notice.zoneKind, severity: after, decreeValidFrom: decreeValidFrom)} '
      '$beforeText $_decreeFaitFoi';
}

String _impossibleLine(CheckImpossible notice) {
  final String places = joinPlaceLabels(notice.placeLabels);
  return switch ((notice.source, notice.cause)) {
    (FollowUpSource.floods, CheckFailureCause.unreachable) =>
      "$floodSourceName n'a pas répondu : aucun avis de crue n'a pu être "
          'donné pour $places. Cela ne dit rien du risque de crue.',
    (FollowUpSource.floods, CheckFailureCause.refused) =>
      "$floodSourceName a refusé la demande : aucun avis de crue n'a pu être "
          'donné pour $places. Cela ne dit rien du risque de crue.',
    (FollowUpSource.floods, CheckFailureCause.unreadable) =>
      "La vigilance publiée par $floodSourceName n'a pas pu être lue : aucun "
          "avis de crue n'a pu être donné pour $places. Cela ne dit rien du "
          'risque de crue.',
    (FollowUpSource.drought, CheckFailureCause.unreachable) =>
      "$restrictionsSourceName n'a pas répondu : aucun avis de restrictions "
          "n'a pu être donné pour $places. Cela ne dit rien des restrictions "
          'en vigueur.',
    (FollowUpSource.drought, CheckFailureCause.refused) =>
      '$restrictionsSourceName a refusé la demande pour $places : aucun avis '
          "de restrictions n'a pu être donné. Cela ne dit rien des "
          'restrictions en vigueur.',
    (FollowUpSource.drought, CheckFailureCause.unreadable) =>
      "La réponse de $restrictionsSourceName n'a pas pu être lue pour "
          "$places : aucun avis de restrictions n'a pu être donné. Cela ne "
          'dit rien des restrictions en vigueur.',
  };
}

String _notVerifiableLine(
  PlaceNotVerifiable notice,
  String Function(DateTime) dateTime,
) => switch (notice.reason) {
  SectionAbsent(:final informationDate) =>
    "${notice.placeLabel} : ce tronçon n'est pas dans la vigilance publiée "
        'par $floodSourceName le ${dateTime(informationDate)}. Aucun avis de '
        'crue ne peut être donné pour lui.',
  SectionMaybeUnreadable(:final informationDate) =>
    "${notice.placeLabel} : ce tronçon n'a pas pu être lu dans la vigilance "
        'publiée par $floodSourceName le ${dateTime(informationDate)}. Aucun '
        'avis de crue ne peut être donné pour lui.',
  StationAbsent() =>
    "${notice.placeLabel} : cette station n'est pas dans le référentiel "
        'embarqué. Aucun avis de restrictions ne peut être donné pour elle.',
};

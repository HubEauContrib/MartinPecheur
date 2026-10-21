// Les avis reçus (M3 de T5, BR-016, PD3) : ce qu'une vérification a relevé
// d'un changement PUBLIÉ, d'un échec de lecture ou d'un lieu qui ne peut pas
// être relu. L'application relaie, elle ne calcule aucun niveau.
//
// Deux branches closes (BR-011) : un avis lisible, à six branches, chacune
// d'une seule échelle (BR-008) ; une entrée stockée que cette version ne sait
// pas lire, gardée telle quelle, sans date de réception connue.
//
// Les dates sont en UTC. Dart pur.

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_rules.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/value_equality.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// La source dont un avis relève : la vigilance crues ou les restrictions
/// sécheresse.
enum FollowUpSource { floods, drought }

/// Pourquoi une source n'a pas pu être lue : les trois échecs des ports.
enum CheckFailureCause { unreachable, refused, unreadable }

/// Pourquoi un lieu ne peut pas être relu. Trois branches, closes.
sealed class NotVerifiableReason {
  const NotVerifiableReason();
}

/// Le tronçon est absent de la vigilance publiée à [informationDate].
final class SectionAbsent extends NotVerifiableReason {
  const SectionAbsent(this.informationDate);

  /// Date de l'information de vigilance, en UTC.
  final DateTime informationDate;

  @override
  bool operator ==(Object other) =>
      other is SectionAbsent && other.informationDate == informationDate;

  @override
  int get hashCode => Object.hash(SectionAbsent, informationDate);
}

/// Le tronçon est peut-être parmi les entités illisibles de la vigilance
/// publiée à [informationDate].
final class SectionMaybeUnreadable extends NotVerifiableReason {
  const SectionMaybeUnreadable(this.informationDate);

  /// Date de l'information de vigilance, en UTC.
  final DateTime informationDate;

  @override
  bool operator ==(Object other) =>
      other is SectionMaybeUnreadable &&
      other.informationDate == informationDate;

  @override
  int get hashCode => Object.hash(SectionMaybeUnreadable, informationDate);
}

/// La station est absente du référentiel embarqué.
final class StationAbsent extends NotVerifiableReason {
  const StationAbsent();

  @override
  bool operator ==(Object other) => other is StationAbsent;

  @override
  int get hashCode => (StationAbsent).hashCode;
}

/// Un avis reçu. Deux branches, closes.
sealed class ReceivedNotice {
  const ReceivedNotice();
}

/// Une entrée stockée que cette version ne sait pas lire : gardée à sa place
/// et telle quelle ([raw]). Elle n'a pas de date de réception connue.
final class UnreadableNotice extends ReceivedNotice {
  const UnreadableNotice({required this.raw});

  /// Le texte brut stocké.
  final String raw;

  @override
  bool operator ==(Object other) =>
      other is UnreadableNotice && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

/// Un avis lisible. Six branches, closes.
sealed class ReadableNotice extends ReceivedNotice {
  const ReadableNotice();

  /// Instant de réception, en UTC.
  DateTime get receivedAt;

  /// Vrai une fois l'écran « Avis reçus » ouvert après la réception.
  bool get read;

  /// Le même avis, lu.
  ReadableNotice asRead();
}

/// Première lecture d'un tronçon suivi : le niveau publié lu, la date de
/// l'information de vigilance et le seuil réglé.
final class FloodFollowUpStarted extends ReadableNotice {
  const FloodFollowUpStarted({
    required this.placeLabel,
    required this.level,
    required this.informationDate,
    required this.threshold,
    required this.receivedAt,
    this.read = false,
  });

  final String placeLabel;
  final FloodVigilanceLevel level;

  /// Date de l'information de vigilance, en UTC.
  final DateTime informationDate;
  final FloodThreshold threshold;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  FloodFollowUpStarted asRead() => FloodFollowUpStarted(
    placeLabel: placeLabel,
    level: level,
    informationDate: informationDate,
    threshold: threshold,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is FloodFollowUpStarted &&
      other.placeLabel == placeLabel &&
      sameFloodLevel(other.level, level) &&
      other.informationDate == informationDate &&
      other.threshold == threshold &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(
    FloodFollowUpStarted,
    placeLabel,
    level.runtimeType,
    informationDate,
    threshold,
    receivedAt,
    read,
  );
}

/// Première lecture d'une station ou d'un point ONDE suivi : les zones
/// citées ([zones] vide : aucune zone citée) et l'instant de la lecture.
final class DroughtFollowUpStarted extends ReadableNotice {
  DroughtFollowUpStarted({
    required this.placeLabel,
    required List<KnownZone> zones,
    required this.readAt,
    required this.receivedAt,
    this.read = false,
  }) : zones = List<KnownZone>.unmodifiable(zones);

  final String placeLabel;

  /// Les zones citées, dans l'ordre de l'écran des restrictions. Non
  /// modifiable.
  final List<KnownZone> zones;

  /// Instant de la lecture des zones, en UTC. Stocké, jamais affiché.
  final DateTime readAt;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  DroughtFollowUpStarted asRead() => DroughtFollowUpStarted(
    placeLabel: placeLabel,
    zones: zones,
    readAt: readAt,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is DroughtFollowUpStarted &&
      other.placeLabel == placeLabel &&
      listEquals(other.zones, zones) &&
      other.readAt == readAt &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(
    DroughtFollowUpStarted,
    placeLabel,
    Object.hashAll(zones),
    readAt,
    receivedAt,
    read,
  );
}

/// Le niveau publié d'un tronçon suivi a changé entre deux lectures.
final class FloodLevelChanged extends ReadableNotice {
  const FloodLevelChanged({
    required this.placeLabel,
    required this.before,
    required this.after,
    required this.informationDate,
    required this.receivedAt,
    this.read = false,
  });

  final String placeLabel;
  final FloodVigilanceLevel before;
  final FloodVigilanceLevel after;

  /// Date de l'information de vigilance du niveau [after], en UTC.
  final DateTime informationDate;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  FloodLevelChanged asRead() => FloodLevelChanged(
    placeLabel: placeLabel,
    before: before,
    after: after,
    informationDate: informationDate,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is FloodLevelChanged &&
      other.placeLabel == placeLabel &&
      sameFloodLevel(other.before, before) &&
      sameFloodLevel(other.after, after) &&
      other.informationDate == informationDate &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(
    FloodLevelChanged,
    placeLabel,
    before.runtimeType,
    after.runtimeType,
    informationDate,
    receivedAt,
    read,
  );
}

/// Une zone d'alerte du point a changé de gravité, est apparue ([before]
/// `null`) ou n'est plus citée ([after] et [decreeValidFrom] `null`).
final class DroughtZoneChanged extends ReadableNotice {
  const DroughtZoneChanged({
    required this.placeLabel,
    required this.zoneName,
    required this.zoneKind,
    required this.before,
    required this.after,
    required this.decreeValidFrom,
    required this.receivedAt,
    this.read = false,
  });

  final String placeLabel;
  final String zoneName;
  final ZoneKind zoneKind;

  /// `null` : la zone n'était pas citée.
  final DroughtSeverity? before;

  /// `null` : la zone n'est plus citée.
  final DroughtSeverity? after;

  /// Début de validité de l'arrêté de [after], en UTC ; `null` pour une zone
  /// plus citée.
  final DateTime? decreeValidFrom;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  DroughtZoneChanged asRead() => DroughtZoneChanged(
    placeLabel: placeLabel,
    zoneName: zoneName,
    zoneKind: zoneKind,
    before: before,
    after: after,
    decreeValidFrom: decreeValidFrom,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is DroughtZoneChanged &&
      other.placeLabel == placeLabel &&
      other.zoneName == zoneName &&
      sameZoneKind(other.zoneKind, zoneKind) &&
      sameOptionalDroughtSeverity(other.before, before) &&
      sameOptionalDroughtSeverity(other.after, after) &&
      other.decreeValidFrom == decreeValidFrom &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(
    DroughtZoneChanged,
    placeLabel,
    zoneName,
    zoneKind.runtimeType,
    before?.runtimeType,
    after?.runtimeType,
    decreeValidFrom,
    receivedAt,
    read,
  );
}

/// Une source n'a pas pu être lue pour [placeLabels] : un avis par source et
/// par cause dans une même vérification (PD4).
final class CheckImpossible extends ReadableNotice {
  CheckImpossible({
    required this.source,
    required this.cause,
    required List<String> placeLabels,
    required this.receivedAt,
    this.read = false,
  }) : placeLabels = List<String>.unmodifiable(placeLabels);

  final FollowUpSource source;
  final CheckFailureCause cause;

  /// Les lieux dont la série d'échecs s'ouvre. Non modifiable.
  final List<String> placeLabels;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  CheckImpossible asRead() => CheckImpossible(
    source: source,
    cause: cause,
    placeLabels: placeLabels,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is CheckImpossible &&
      other.source == source &&
      other.cause == cause &&
      listEquals(other.placeLabels, placeLabels) &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(
    CheckImpossible,
    source,
    cause,
    Object.hashAll(placeLabels),
    receivedAt,
    read,
  );
}

/// Un lieu suivi ne peut pas être relu, pour [reason].
final class PlaceNotVerifiable extends ReadableNotice {
  const PlaceNotVerifiable({
    required this.placeLabel,
    required this.reason,
    required this.receivedAt,
    this.read = false,
  });

  final String placeLabel;
  final NotVerifiableReason reason;

  @override
  final DateTime receivedAt;

  @override
  final bool read;

  @override
  PlaceNotVerifiable asRead() => PlaceNotVerifiable(
    placeLabel: placeLabel,
    reason: reason,
    receivedAt: receivedAt,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaceNotVerifiable &&
      other.placeLabel == placeLabel &&
      other.reason == reason &&
      other.receivedAt == receivedAt &&
      other.read == read;

  @override
  int get hashCode =>
      Object.hash(PlaceNotVerifiable, placeLabel, reason, receivedAt, read);
}

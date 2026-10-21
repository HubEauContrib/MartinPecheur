// Les règles de changement du suivi (M3 de T5, BR-016). Elles comparent deux
// niveaux PUBLIÉS, ou deux lectures des zones citées : aucune n'en calcule un
// (BR-015). Un rang ne sert qu'à ordonner deux niveaux publiés, ou à le
// rapprocher du seuil que l'usager a choisi parmi ces mêmes niveaux.
//
// Dart pur.

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// Le rang d'un niveau publié : vert 0, jaune 1, orange 2, rouge 3 ; `null`
/// pour un niveau non reconnu, qui n'a pas de place sur l'échelle.
int? publishedFloodRank(FloodVigilanceLevel level) => switch (level) {
  Vert() => 0,
  Jaune() => 1,
  Orange() => 2,
  Rouge() => 3,
  NiveauCruesInconnu() => null,
};

/// Le rang du niveau publié que nomme [threshold] : jaune 1, orange 2,
/// rouge 3.
int floodThresholdRank(FloodThreshold threshold) => switch (threshold) {
  FloodThreshold.jaune => 1,
  FloodThreshold.orange => 2,
  FloodThreshold.rouge => 3,
};

/// Vrai si le passage de [before] à [after] fait un avis pour un tronçon
/// suivi à partir de [threshold] : les niveaux diffèrent, et l'un des deux
/// atteint le seuil, à la montée comme à la descente (critère 11). Un niveau
/// non reconnu, avant ou après, fait toujours un avis (critère 12, BR-011).
bool floodNoticeDue({
  required FloodVigilanceLevel before,
  required FloodVigilanceLevel after,
  required FloodThreshold threshold,
}) {
  if (sameFloodLevel(before, after)) {
    return false;
  }
  final int? from = publishedFloodRank(before);
  final int? to = publishedFloodRank(after);
  if (from == null || to == null) {
    return true;
  }
  final int highest = from > to ? from : to;
  return highest >= floodThresholdRank(threshold);
}

/// Le rang d'un type de zone, dans l'ordre de l'écran des restrictions :
/// eaux superficielles 0, eaux souterraines 1, eau potable 2, type non
/// reconnu 3 (`ZonesAtPoint.surfaceWaterZones` puis `otherZones`).
int zoneKindRank(ZoneKind kind) => switch (kind) {
  EauxSuperficielles() => 0,
  EauxSouterraines() => 1,
  EauPotable() => 2,
  TypeZoneInconnu() => 3,
};

/// Ce que l'on garde d'une lecture des zones : chacune réduite à son nom, son
/// type, sa gravité et le début de validité de son arrêté, dans l'ordre de
/// l'écran des restrictions ; l'instant de la lecture.
LastKnownZones lastKnownZonesOf(ZonesAtPoint zones) => LastKnownZones(
  readAt: zones.retrievedAt,
  zones: <KnownZone>[
    for (final AlertZone zone in <AlertZone>[
      ...zones.surfaceWaterZones,
      ...zones.otherZones,
    ])
      KnownZone(
        name: zone.name,
        kind: zone.kind,
        severity: zone.severity,
        decreeValidFrom: zone.decree.validFrom,
      ),
  ],
);

/// Vrai si [a] et [b] sont tous deux absents, ou la même gravité
/// ([sameDroughtSeverity]).
bool sameOptionalDroughtSeverity(DroughtSeverity? a, DroughtSeverity? b) {
  if (a == null || b == null) {
    return a == null && b == null;
  }
  return sameDroughtSeverity(a, b);
}

/// Un changement d'une zone entre deux lectures : une gravité différente, une
/// zone nouvelle ([before] `null`) ou une zone plus citée ([after] et
/// [decreeValidFrom] `null`).
final class DroughtZoneChange {
  const DroughtZoneChange({
    required this.name,
    required this.kind,
    required this.before,
    required this.after,
    required this.decreeValidFrom,
  });

  final String name;
  final ZoneKind kind;
  final DroughtSeverity? before;
  final DroughtSeverity? after;

  /// Début de validité de l'arrêté de la lecture nouvelle, en UTC ; `null`
  /// pour une zone plus citée.
  final DateTime? decreeValidFrom;

  @override
  bool operator ==(Object other) =>
      other is DroughtZoneChange &&
      other.name == name &&
      sameZoneKind(other.kind, kind) &&
      sameOptionalDroughtSeverity(other.before, before) &&
      sameOptionalDroughtSeverity(other.after, after) &&
      other.decreeValidFrom == decreeValidFrom;

  @override
  int get hashCode => Object.hash(
    name,
    kind.runtimeType,
    before?.runtimeType,
    after?.runtimeType,
    decreeValidFrom,
  );

  @override
  String toString() =>
      'DroughtZoneChange($name, $kind, $before → $after, $decreeValidFrom)';
}

/// Les changements des zones citées entre [before] et [after].
///
/// Faute d'identifiant, les zones s'apparient par type ([sameZoneKind]) et
/// par nom ; à clé égale, dans l'ordre d'apparition. Un renommage se lit donc
/// comme une zone plus citée puis une zone nouvelle (R5). Une date d'arrêté
/// changée, gravité égale, ne donne rien (R5).
///
/// Ordre : par [zoneKindRank] ; à rang égal, les zones plus citées dans
/// l'ordre de [before], puis les autres changements dans l'ordre de [after].
List<DroughtZoneChange> droughtZoneChanges({
  required LastKnownZones before,
  required LastKnownZones after,
}) {
  final List<KnownZone> unpaired = List<KnownZone>.of(before.zones);
  final List<DroughtZoneChange> fromAfter = <DroughtZoneChange>[];
  for (final KnownZone zone in after.zones) {
    final int index = unpaired.indexWhere(
      (KnownZone old) =>
          old.name == zone.name && sameZoneKind(old.kind, zone.kind),
    );
    final KnownZone? old = index < 0 ? null : unpaired.removeAt(index);
    if (old != null && sameDroughtSeverity(old.severity, zone.severity)) {
      continue;
    }
    fromAfter.add(
      DroughtZoneChange(
        name: zone.name,
        kind: zone.kind,
        before: old?.severity,
        after: zone.severity,
        decreeValidFrom: zone.decreeValidFrom,
      ),
    );
  }
  final List<DroughtZoneChange> gone = <DroughtZoneChange>[
    for (final KnownZone zone in unpaired)
      DroughtZoneChange(
        name: zone.name,
        kind: zone.kind,
        before: zone.severity,
        after: null,
        decreeValidFrom: null,
      ),
  ];

  // Un tri à clé totale, sans borne de rang : `List.sort` ne garantit pas de
  // garder l'ordre de deux éléments égaux, d'où la position d'origine en
  // dernier départage. Les disparitions précèdent le reste : leur index est
  // donc pris avant celui des changements venus de `after`.
  final List<DroughtZoneChange> ordered = <DroughtZoneChange>[
    ...gone,
    ...fromAfter,
  ];
  final List<int> indices = List<int>.generate(ordered.length, (int i) => i)
    ..sort((int a, int b) {
      final int byRank = zoneKindRank(ordered[a].kind)
          .compareTo(zoneKindRank(ordered[b].kind));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  return <DroughtZoneChange>[for (final int i in indices) ordered[i]];
}

// La reponse datee de la source au point designe — conception T2 § 2.3 et
// § 5. `retrievedAt` voyage AVEC la reponse, pas dans le cache : un ecran
// servi par le cache connait sa date de recuperation aussi bien qu'un
// ecran servi par le reseau (US-07, AR-3).
//
// La partition surfaceWaterZones / otherZones vit ICI, dans le domaine, et
// non dans un ViewModel (§ 5) : l'invariant « aucune zone perdue » a un
// poids juridique (BR-007) et se teste sur un objet-valeur pur. Aucun tri
// par severite : chaque zone regit ses propres usages, rien ne fonde une
// zone « principale ».

import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/value_equality.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// L'ensemble des zones d'alerte au point interroge, a l'instant ou la
/// source a repondu.
final class ZonesAtPoint {
  ZonesAtPoint({
    required this.point,
    required DateTime retrievedAt,
    required List<AlertZone> zones,
  }) : retrievedAt = requireUtc(retrievedAt, 'retrievedAt'),
       zones = List<AlertZone>.unmodifiable(zones);

  /// Le point interroge — celui de la requete, pas de la reponse. Rappele
  /// a l'ecran (US-07).
  final GeoPoint point;

  /// Instant ou la source a repondu, en UTC. Injecte par le depot HTTP, il
  /// ne vient jamais de l'horloge de la source elle-meme (aucun champ de
  /// fraicheur sur une zone).
  final DateTime retrievedAt;

  /// Toutes les zones du point, dans l'ordre de la source. Vide :
  /// « aucune zone » (`BR-007`), un resultat valide, pas un echec. Non
  /// modifiable.
  final List<AlertZone> zones;

  /// Les zones `EauxSuperficielles`, dans l'ordre de la source. Non
  /// modifiable.
  List<AlertZone> get surfaceWaterZones => List<AlertZone>.unmodifiable(
    zones.where((AlertZone zone) => zone.kind is EauxSuperficielles),
  );

  /// Toutes les autres zones, dans un ordre fixe par type —
  /// `EauxSouterraines`, puis `EauPotable`, puis `TypeZoneInconnu` — et
  /// dans l'ordre de la source a l'interieur d'un meme type. Une zone de
  /// type inconnu est gardee et signalee, jamais ecartee. Non modifiable.
  List<AlertZone> get otherZones {
    final List<AlertZone> souterraines = <AlertZone>[];
    final List<AlertZone> potable = <AlertZone>[];
    final List<AlertZone> inconnues = <AlertZone>[];

    for (final AlertZone zone in zones) {
      switch (zone.kind) {
        case EauxSuperficielles():
          break; // deja dans surfaceWaterZones
        case EauxSouterraines():
          souterraines.add(zone);
        case EauPotable():
          potable.add(zone);
        case TypeZoneInconnu():
          inconnues.add(zone);
      }
    }

    return List<AlertZone>.unmodifiable(<AlertZone>[
      ...souterraines,
      ...potable,
      ...inconnues,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is ZonesAtPoint &&
      other.point == point &&
      other.retrievedAt == retrievedAt &&
      listEquals(other.zones, zones);

  @override
  int get hashCode => Object.hash(point, retrievedAt, Object.hashAll(zones));

  @override
  String toString() =>
      'ZonesAtPoint(point: $point, retrievedAt: $retrievedAt, '
      'zones: ${zones.length})';
}

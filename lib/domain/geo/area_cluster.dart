// Le regroupement des marqueurs par zone administrative sous le zoom 9
// (ADR-015) : une pastille par région sous le zoom 7, par département de 7
// à 9. `clusterByArea` est une PARTITION (BR-007) — chaque élément est dans
// un agrégat ou dans `unassigned`, jamais deux fois, jamais perdu — et non
// une approche par proximité comme `flutter_map_marker_cluster` (écarté par
// ADR-015 : dépendance, et c'est l'approche mesurée au rouge au spike).
// Dart pur (CLAUDE.md, invariants d'architecture ; ADR-014).

import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';

/// Le niveau administratif d'un regroupement (ADR-015) : région sous le
/// zoom 7, département de 7 à 9.
enum AreaLevel { region, departement }

/// Un agrégat d'éléments de type [T] rattachés à la même [area], au niveau
/// [level].
final class AreaCluster<T> {
  const AreaCluster({
    required this.level,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.members,
    required this.bounds,
  });

  /// Le niveau de ce regroupement.
  final AreaLevel level;

  /// La zone administrative de cet agrégat — code et libellé du PREMIER
  /// membre rencontré, jamais recalculé ni recopié d'une autre source.
  final AdministrativeArea area;

  /// Latitude du barycentre : moyenne arithmétique des latitudes des
  /// [members], en degrés — aucun centroïde administratif, aucune
  /// pondération.
  final double latitude;

  /// Longitude du barycentre, même règle que [latitude].
  final double longitude;

  /// Les membres de l'agrégat, dans l'ordre d'entrée. Liste non modifiable :
  /// un appelant qui tenterait de la modifier en place lèverait
  /// [UnsupportedError].
  final List<T> members;

  /// L'emprise exacte des [members] — `null` quand elle est PLATE (un seul
  /// membre, ou des membres de même latitude ou de même longitude :
  /// [Bounds] la refuse). Jamais élargie d'une marge inventée.
  final Bounds? bounds;

  /// Le nombre de [members].
  int get count => members.length;
}

/// Le résultat d'un [clusterByArea] : les agrégats formés, et les éléments
/// sans zone au niveau demandé.
final class AreaClustering<T> {
  const AreaClustering({required this.clusters, required this.unassigned});

  /// Les agrégats, rendus par code de zone croissant, quel que soit l'ordre
  /// d'entrée des éléments.
  final List<AreaCluster<T>> clusters;

  /// Les éléments sans zone au niveau demandé, dans l'ordre d'entrée —
  /// jamais rattachés à une zone voisine (BR-007).
  final List<T> unassigned;
}

/// Regroupe [items] par zone administrative, au niveau [level].
///
/// [areaOf] rend la zone de l'élément au niveau demandé, ou `null` en
/// l'absence de rattachement — l'élément va alors dans `unassigned`, dans
/// l'ordre d'entrée. [positionOf] rend la position de l'élément, utilisée
/// pour le barycentre et l'emprise de son agrégat.
///
/// C'est une PARTITION (BR-007) : chaque élément de [items] se retrouve
/// dans exactement un agrégat ou dans `unassigned`, jamais deux fois,
/// jamais perdu. Le regroupement se fait par `area.code` ; le libellé
/// retenu pour l'agrégat est celui du PREMIER membre rencontré, même si un
/// membre ultérieur porte un libellé différent pour le même code. Les
/// agrégats sont rendus par code croissant.
AreaClustering<T> clusterByArea<T>(
  Iterable<T> items, {
  required AreaLevel level,
  required AdministrativeArea? Function(T item) areaOf,
  required ({double latitude, double longitude}) Function(T item) positionOf,
}) {
  final Map<String, String> labelByCode = <String, String>{};
  final Map<String, List<T>> membersByCode = <String, List<T>>{};
  final List<T> unassigned = <T>[];

  for (final T item in items) {
    final AdministrativeArea? area = areaOf(item);
    if (area == null) {
      unassigned.add(item);
      continue;
    }
    labelByCode.putIfAbsent(area.code, () => area.label);
    membersByCode.putIfAbsent(area.code, () => <T>[]).add(item);
  }

  final List<String> codesCroissants = membersByCode.keys.toList()..sort();

  final List<AreaCluster<T>> clusters = <AreaCluster<T>>[
    for (final String code in codesCroissants)
      _buildCluster<T>(
        level: level,
        area: AdministrativeArea(code: code, label: labelByCode[code]!),
        members: membersByCode[code]!,
        positionOf: positionOf,
      ),
  ];

  return AreaClustering<T>(clusters: clusters, unassigned: unassigned);
}

/// Construit l'agrégat d'une zone : barycentre en moyenne arithmétique,
/// emprise exacte (`null` si plate — un seul membre, ou des membres alignés
/// en latitude ou en longitude, que [Bounds] refuse à la construction).
AreaCluster<T> _buildCluster<T>({
  required AreaLevel level,
  required AdministrativeArea area,
  required List<T> members,
  required ({double latitude, double longitude}) Function(T item) positionOf,
}) {
  double sommeLatitudes = 0;
  double sommeLongitudes = 0;
  double latitudeMin = double.infinity;
  double latitudeMax = double.negativeInfinity;
  double longitudeMin = double.infinity;
  double longitudeMax = double.negativeInfinity;

  for (final T membre in members) {
    final ({double latitude, double longitude}) position = positionOf(membre);
    sommeLatitudes += position.latitude;
    sommeLongitudes += position.longitude;
    if (position.latitude < latitudeMin) {
      latitudeMin = position.latitude;
    }
    if (position.latitude > latitudeMax) {
      latitudeMax = position.latitude;
    }
    if (position.longitude < longitudeMin) {
      longitudeMin = position.longitude;
    }
    if (position.longitude > longitudeMax) {
      longitudeMax = position.longitude;
    }
  }

  Bounds? bounds;
  try {
    bounds = Bounds(
      west: longitudeMin,
      south: latitudeMin,
      east: longitudeMax,
      north: latitudeMax,
    );
  } on ArgumentError {
    // Emprise plate — un seul membre, ou des membres de même latitude ou de
    // même longitude : jamais une marge inventée pour la rendre valide.
    bounds = null;
  }

  return AreaCluster<T>(
    level: level,
    area: area,
    latitude: sommeLatitudes / members.length,
    longitude: sommeLongitudes / members.length,
    members: List<T>.unmodifiable(members),
    bounds: bounds,
  );
}

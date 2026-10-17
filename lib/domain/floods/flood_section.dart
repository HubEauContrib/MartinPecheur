// Un troncon de cours d'eau et le niveau de vigilance crues publie pour lui
// (T4, BR-015 : l'application relaie, elle ne calcule rien).
//
// Dart pur. Le code du troncon est celui que la source publie, pris tel quel.

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// Code publie d'un troncon, chaine non vide, jamais normalisee (ni `trim`,
/// ni changement de casse).
final class FloodSectionCode {
  /// Leve une [ArgumentError] si [raw] est vide.
  factory FloodSectionCode(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'ne doit pas etre vide');
    }

    return FloodSectionCode._(raw);
  }

  const FloodSectionCode._(this.value);

  /// Le code, tel que publie.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is FloodSectionCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FloodSectionCode($value)';
}

/// Un troncon : son identite publiee, son nom, son territoire, son niveau et
/// son trace.
///
/// L'egalite ne porte que sur [code] : c'est l'identite publiee, le niveau
/// change d'une carte a l'autre.
final class FloodSection {
  /// Leve une [ArgumentError] si [name] ou [territoryCode] est vide, si
  /// [lines] est vide, ou si une ligne a moins de deux points. Les listes sont
  /// copiees et non modifiables.
  factory FloodSection({
    required FloodSectionCode code,
    required String name,
    required String territoryCode,
    required FloodVigilanceLevel level,
    required List<List<GeoPoint>> lines,
  }) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'ne doit pas etre vide');
    }
    if (territoryCode.isEmpty) {
      throw ArgumentError.value(
        territoryCode,
        'territoryCode',
        'ne doit pas etre vide',
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'au moins une ligne');
    }
    for (final List<GeoPoint> line in lines) {
      if (line.length < 2) {
        throw ArgumentError.value(
          lines,
          'lines',
          'chaque ligne compte au moins deux points',
        );
      }
    }

    return FloodSection._(
      code: code,
      name: name,
      territoryCode: territoryCode,
      level: level,
      lines: List<List<GeoPoint>>.unmodifiable(
        lines.map<List<GeoPoint>>(List<GeoPoint>.unmodifiable),
      ),
    );
  }

  const FloodSection._({
    required this.code,
    required this.name,
    required this.territoryCode,
    required this.level,
    required this.lines,
  });

  /// Identite publiee du troncon.
  final FloodSectionCode code;

  /// Nom publie, tel quel.
  final String name;

  /// Code du territoire publie, tel quel.
  final String territoryCode;

  /// Niveau de vigilance publie.
  final FloodVigilanceLevel level;

  /// Trace : au moins une ligne, chacune d'au moins deux points.
  final List<List<GeoPoint>> lines;

  @override
  bool operator ==(Object other) => other is FloodSection && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() =>
      'FloodSection(code: ${code.value}, name: $name, '
      'territoryCode: $territoryCode, level: $level)';
}

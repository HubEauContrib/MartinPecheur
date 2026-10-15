// La carte de vigilance crues : tous les troncons publies a un instant donne
// (T4, BR-001 : jamais de valeur sans sa date).

import 'package:martinpecheur/domain/floods/flood_section.dart';

/// Carte de vigilance, avec la date de l'information.
final class FloodVigilanceMap {
  /// Leve une [ArgumentError] si [informationDate] n'est pas en UTC ou si
  /// [skippedEntities] est negatif. [sections] est copiee, non modifiable.
  factory FloodVigilanceMap({
    required DateTime informationDate,
    required List<FloodSection> sections,
    required int skippedEntities,
  }) {
    if (!informationDate.isUtc) {
      throw ArgumentError.value(
        informationDate,
        'informationDate',
        'doit etre un instant UTC',
      );
    }
    if (skippedEntities < 0) {
      throw ArgumentError.value(
        skippedEntities,
        'skippedEntities',
        'ne doit pas etre negatif',
      );
    }

    return FloodVigilanceMap._(
      informationDate: informationDate,
      sections: List<FloodSection>.unmodifiable(sections),
      skippedEntities: skippedEntities,
    );
  }

  const FloodVigilanceMap._({
    required this.informationDate,
    required this.sections,
    required this.skippedEntities,
  });

  /// Date de l'information publiee, en UTC.
  final DateTime informationDate;

  /// Les troncons de la carte.
  final List<FloodSection> sections;

  /// Nombre d'entites ecartees faute d'etre exploitables.
  final int skippedEntities;

  /// Le troncon de code [code], ou `null` s'il n'est pas sur la carte.
  FloodSection? sectionByCode(FloodSectionCode code) {
    for (final FloodSection section in sections) {
      if (section.code == code) {
        return section;
      }
    }

    return null;
  }
}

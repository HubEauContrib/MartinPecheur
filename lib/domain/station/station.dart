// Le code station à dix caractères et le code département en chaîne (C-05).
// C-05 reproduit le 2026-09-13 : le code SITE K4470010 (8 car.) renvoie
// chaque mesure en double, dont une ligne à code_station null — count 430
// contre 216 pour le code station. Une valeur de bonne longueur mais de
// mauvaise forme partirait vers l'API et reviendrait vide, affichée en
// « pas de donnée » (BR-007) : un faux négatif silencieux. On refuse à la
// construction plutôt que de laisser passer.

/// Forme exacte des codes station en service, mesurée sur les 4 150
/// stations du référentiel le 2026-09-13 : 3 974 en `A999999999` (une
/// lettre puis neuf chiffres), 176 en `9999999999` (dix chiffres, DOM).
/// Restreindre à la seule forme majoritaire rejetterait ces 176 stations.
final RegExp _stationCodePattern = RegExp(r'^[A-Z0-9]{10}$');

/// Code station Hub'Eau, toujours à dix caractères. Une classe et non un
/// `extension type` : à la différence des unités de
/// `lib/domain/units/quantities.dart`, ce type **valide** — c'est le seul
/// verrou mécanique contre `C-05`. La casse n'est jamais normalisée : un
/// `k` minuscule est refusé, il ne correspond à aucune forme mesurée.
final class StationCode {
  /// Valide [raw] contre [_stationCodePattern]. Lève une [ArgumentError] si
  /// [raw] n'a pas exactement dix caractères, ou contient un caractère hors
  /// `A-Z0-9` (minuscule comprise).
  factory StationCode(String raw) {
    if (!_stationCodePattern.hasMatch(raw)) {
      throw ArgumentError.value(
        raw,
        'raw',
        'doit comporter dix caractères A-Z0-9 (code station, jamais le '
            'code site à huit caractères — C-05)',
      );
    }

    return StationCode._(raw);
  }

  const StationCode._(this.value);

  /// Le code, tel que validé — jamais transformé.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is StationCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Forme du code département : deux chiffres, `2A`/`2B` pour la Corse, ou
/// trois chiffres pour les DOM.
final RegExp _departementCodePattern = RegExp(r'^(\d{2}|2[AB]|\d{3})$');

/// Code département, en chaîne et non en entier : `"01"` interprété comme un
/// nombre deviendrait `1`, et la Corse (`2A`/`2B`) rendrait la conversion de
/// toute façon impossible.
final class DepartementCode {
  /// Normalise [raw] (`trim` puis majuscules), puis le valide contre
  /// [_departementCodePattern]. Lève une [ArgumentError] sinon.
  factory DepartementCode(String raw) {
    final String normalized = raw.trim().toUpperCase();
    if (!_departementCodePattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        raw,
        'raw',
        'doit être un code département valide : deux chiffres, 2A/2B, ou '
            'trois chiffres pour les DOM',
      );
    }

    return DepartementCode._(normalized);
  }

  const DepartementCode._(this.value);

  /// Le code, normalisé en majuscules.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is DepartementCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Une station du référentiel Hub'Eau hydrométrie.
///
/// Les coordonnées s'appellent `latitude_station`/`longitude_station` au
/// référentiel et `latitude`/`longitude` en temps réel : le domaine n'en
/// connaît qu'un couple, c'est au mapper d'absorber cet écart de
/// nomenclature de l'API.
final class Station {
  const Station({
    required this.code,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.departement,
    required this.riverLabel,
    required this.inService,
  });

  /// Code de la station, à dix caractères.
  final StationCode code;

  /// Libellé de la station.
  final String label;

  final double latitude;

  final double longitude;

  /// Département où se situe la station.
  final DepartementCode departement;

  /// Cours d'eau de la station. `null` signifie une absence — jamais une
  /// chaîne vide (`BR-007`).
  final String? riverLabel;

  /// `true` si la station est en service.
  final bool inService;
}

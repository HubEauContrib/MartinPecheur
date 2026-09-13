// Le code station ONDE, à huit caractères — et non dix (T-04). ONDE
// (écoulement) et Hub'Eau hydrométrie sont deux référentiels distincts : un
// code de l'un ne doit jamais passer la validation de l'autre, sans quoi une
// station d'écoulement s'afficherait avec les mesures d'une station de débit
// portant le même préfixe.

/// Forme exacte du code station ONDE : huit caractères A-Z0-9, jamais dix
/// (c'est la forme de `StationCode`, `lib/domain/station/station.dart`).
final RegExp _ondeStationCodePattern = RegExp(r'^[A-Z0-9]{8}$');

/// Code station ONDE (écoulement), toujours à huit caractères. Une classe et
/// non un `extension type` : comme `StationCode`, elle **valide** — c'est le
/// seul verrou mécanique qui empêche un code du référentiel hydrométrie
/// (dix caractères) de se substituer à un code ONDE (T-04). La casse n'est
/// jamais normalisée.
final class OndeStationCode {
  /// Valide [raw] contre [_ondeStationCodePattern]. Lève une [ArgumentError]
  /// si [raw] n'a pas exactement huit caractères, ou contient un caractère
  /// hors `A-Z0-9` (minuscule comprise).
  factory OndeStationCode(String raw) {
    if (!_ondeStationCodePattern.hasMatch(raw)) {
      throw ArgumentError.value(
        raw,
        'raw',
        'doit comporter huit caractères A-Z0-9 (code station ONDE, jamais '
            'le code station hydrométrie à dix caractères — T-04)',
      );
    }

    return OndeStationCode._(raw);
  }

  const OndeStationCode._(this.value);

  /// Le code, tel que validé — jamais transformé.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is OndeStationCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

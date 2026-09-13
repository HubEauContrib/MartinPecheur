// Le code station ONDE, a huit caracteres — et non dix (T-04). ONDE
// (ecoulement) et Hub'Eau hydrometrie sont deux referentiels distincts : un
// code de l'un ne doit jamais passer la validation de l'autre, sans quoi une
// station d'ecoulement s'afficherait avec les mesures d'une station de debit
// portant le meme prefixe.

/// Forme exacte du code station ONDE : huit caracteres A-Z0-9, jamais dix
/// (c'est la forme de `StationCode`, `lib/domain/station/station.dart`).
final RegExp _ondeStationCodePattern = RegExp(r'^[A-Z0-9]{8}$');

/// Code station ONDE (ecoulement), toujours a huit caracteres. Une classe et
/// non un `extension type` : comme `StationCode`, elle **valide** — c'est le
/// seul verrou mecanique qui empeche un code du referentiel hydrometrie
/// (dix caracteres) de se substituer a un code ONDE (T-04). La casse n'est
/// jamais normalisee.
final class OndeStationCode {
  /// Valide [raw] contre [_ondeStationCodePattern]. Leve une [ArgumentError]
  /// si [raw] n'a pas exactement huit caracteres, ou contient un caractere
  /// hors `A-Z0-9` (minuscule comprise).
  factory OndeStationCode(String raw) {
    if (!_ondeStationCodePattern.hasMatch(raw)) {
      throw ArgumentError.value(
        raw,
        'raw',
        'doit comporter huit caracteres A-Z0-9 (code station ONDE, jamais '
            'le code station hydrometrie a dix caracteres — T-04)',
      );
    }

    return OndeStationCode._(raw);
  }

  const OndeStationCode._(this.value);

  /// Le code, tel que valide — jamais transforme.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is OndeStationCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

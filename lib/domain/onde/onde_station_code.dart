// Le code station ONDE est une **chaîne libre**, conservée verbatim. `T-04`
// (« le code fait huit caractères ») n'était vrai que de l'échantillon
// Loire : sur la page nationale du 2026-09-14, 147 codes distincts sortent
// de `^[A-Z0-9]{8}$` — `A721 3011` (espace intérieur), `S224` (quatre
// caractères), `" O968 5312 "` (espaces de bord). Une validation de forme
// rejetait 507 lignes sur 10 234 et faisait tomber tout le chargement de la
// carte : le bandeau rouge vu à l'écran le 2026-09-14 (`T-14`).
//
// **L'espace est significatif pour l'API** (`T-14`, appels réels du
// 2026-09-14) : `?code_station=A721%203011` rend `count` 40, et
// `?code_station=A7213011` rend `count` 63 — deux historiques distincts. Le
// code n'est donc **ni `trim`é, ni débarrassé de ses espaces, ni normalisé
// en casse** : le transformer changerait la station interrogée.
//
// Ce qui sépare ONDE (écoulement) d'Hub'Eau hydrométrie n'est donc plus la
// forme, mais le **type** : `OndeStationCode` et `StationCode`
// (`lib/domain/station/station.dart`) sont deux classes distinctes, jamais
// convertibles l'une en l'autre. Le compilateur refuse de passer l'une là où
// l'autre est attendue — c'est désormais le seul verrou, et il est plus sûr
// que le motif qu'il remplace, qui laissait de toute façon passer un code
// hydrométrie de huit caractères.

/// Code station ONDE (écoulement), conservé **verbatim**. Une classe et non
/// un `extension type` : elle **valide** — et surtout elle **type**, seul
/// verrou restant contre la substitution d'un code hydrométrie
/// ([StationCode], `lib/domain/station/station.dart`) à un code ONDE.
///
/// La seule validation est l'absence de contenu : un code blanc n'identifie
/// rien et n'est jamais interrogeable (`BR-007` — une absence se nomme, elle
/// ne se déguise pas en code vide). Tout le reste passe tel quel : espaces
/// intérieurs, espaces de bord, longueur quelconque, casse quelconque.
final class OndeStationCode {
  /// Accepte toute chaîne non vide et non blanche, conservée telle quelle.
  /// Lève une [ArgumentError] si [raw] est vide ou entièrement composée de
  /// blancs, et dans ce cas seulement.
  factory OndeStationCode(String raw) {
    if (raw.trim().isEmpty) {
      throw ArgumentError.value(
        raw,
        'raw',
        'code station ONDE vide ou entièrement blanc — un code blanc '
            "n'identifie aucune station (BR-007). Toute autre chaîne est "
            'acceptée et conservée verbatim, espaces compris (T-14)',
      );
    }

    return OndeStationCode._(raw);
  }

  const OndeStationCode._(this.value);

  /// Le code, exactement tel que rendu par l'API — jamais `trim`é, jamais
  /// recasé, jamais débarrassé de ses espaces (`T-14`).
  final String value;

  @override
  bool operator ==(Object other) =>
      other is OndeStationCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

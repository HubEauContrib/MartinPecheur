// Décore `OndeObservationRepository` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique de
// cache (stale-while-revalidate) reste dans son seul décorateur ; ce
// fichier se contente de l'APPELER (CLAUDE.md § Architecture). Le
// regroupement d'une observation par station, lui, ne vit pas ici — il est
// fait par `HttpOndeObservationRepository.latestWithinBounds` (D7) : ce
// décorateur ne voit jamais qu'une seule ligne par station, il n'a rien à
// regrouper.
//
// TTL saisonnier (`docs/03-conception.md § 4.1`, « Campagnes ONDE : 30 j en
// saison (mai-sept), 90 j hors saison ») : [ondeTtlFor] ne lit que le mois
// de la date passée — aucune granularité au jour n'est nécessaire, les
// bornes mai/septembre tombent exactement sur un changement de mois. Pas de
// `ttl` injectable au constructeur : contrairement à `observationsTrTtl`
// (un seul chiffre, D6), le TTL d'ONDE dépend de `now()` et se recalcule à
// chaque lecture — un seul chiffre par saison, jamais un troisième.
//
// Stockage en mémoire, deux `Map` de valeurs — une par méthode, les deux
// clés étant de formes différentes ((Bounds, DateTime) pour
// `latestWithinBounds`, (OndeStationCode, int) pour `historyFor`) — sans
// purge : aucun stockage local n'existe encore (ADR-011 réservé).
//
// Piège d'usage de `withCachePolicy` (documenté dans `cache_policy.dart`) :
// une fermeture par clé, conservée dans un champ, jamais reconstruite à
// chaque lecture — sinon la déduplication des rafraîchissements en vol
// (C-12) serait perdue. Ici la fermeture dépend aussi du TTL, calculé une
// fois par `ondeTtlFor(now())` AU MOMENT de sa création : les fermetures
// sont donc indexées par (clé, ttl), pas par clé seule. Un changement de
// saison entre deux lectures crée une nouvelle fermeture avec le nouveau
// TTL, mais les deux fermetures partagent la même entrée des `Map` de
// valeurs ci-dessus (indexées par clé seule) : aucune donnée n'est perdue
// au basculement, la valeur écrite par l'une reste lue par l'autre.
//
// Une liste vide (BR-007) est mise en cache comme une valeur ordinaire —
// même choix que `CachedHydroObservationRepository` pour `null` (D6) :
// c'est ce qui évite de réinterroger une absence déjà constatée avant le
// TTL.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show OndeObservationRepository;

/// TTL des observations ONDE en saison (mai à septembre inclus),
/// `docs/03-conception.md § 4.1`.
const Duration ondeTtlInSeason = Duration(days: 30);

/// TTL des observations ONDE hors saison (octobre à avril inclus),
/// `docs/03-conception.md § 4.1`.
const Duration ondeTtlOffSeason = Duration(days: 90);

/// TTL applicable pour une lecture faite au mois de [date] : [ondeTtlInSeason]
/// de mai à septembre inclus, [ondeTtlOffSeason] le reste de l'année. Aucune
/// granularité au jour : les campagnes ONDE se décident par mois, jamais par
/// date précise.
Duration ondeTtlFor(DateTime date) {
  final int month = date.month;
  if (month >= DateTime.may && month <= DateTime.september) {
    return ondeTtlInSeason;
  }
  return ondeTtlOffSeason;
}

typedef _BoundsKey = (Bounds, DateTime);
typedef _StationKey = (OndeStationCode, int);

/// Décore un [OndeObservationRepository] par la politique de cache
/// stale-while-revalidate, avec un TTL qui dépend du mois de lecture.
final class CachedOndeObservationRepository
    implements OndeObservationRepository {
  CachedOndeObservationRepository({
    required this._inner,
    this._now,
    this._networkAvailable,
  });

  final OndeObservationRepository _inner;
  final DateTime Function()? _now;
  final bool Function()? _networkAvailable;

  DateTime _clock() => (_now ?? DateTime.now)();

  final Map<_BoundsKey, CachedValue<List<OndeObservation>>> _boundsCache =
      <_BoundsKey, CachedValue<List<OndeObservation>>>{};
  final Map<_StationKey, CachedValue<List<OndeObservation>>> _stationCache =
      <_StationKey, CachedValue<List<OndeObservation>>>{};

  /// Une fermeture par (clé, ttl) : voir le commentaire d'en-tête sur le
  /// piège d'usage de `withCachePolicy` et le partage d'entrée au
  /// changement de saison.
  final Map<(_BoundsKey, Duration), Future<List<OndeObservation>> Function()>
  _boundsReads =
      <(_BoundsKey, Duration), Future<List<OndeObservation>> Function()>{};
  final Map<(_StationKey, Duration), Future<List<OndeObservation>> Function()>
  _stationReads =
      <(_StationKey, Duration), Future<List<OndeObservation>> Function()>{};

  @override
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) {
    final _BoundsKey key = (bounds, since);
    final Duration ttl = ondeTtlFor(_clock());
    final Future<List<OndeObservation>> Function() read = _boundsReads
        .putIfAbsent(
          (key, ttl),
          () => withCachePolicy<List<OndeObservation>>(
            load: () => _inner.latestWithinBounds(bounds, since: since),
            readCache: () async => _boundsCache[key],
            writeCache: (List<OndeObservation> value) async {
              _boundsCache[key] = CachedValue<List<OndeObservation>>(
                value: value,
                storedAt: _clock(),
              );
            },
            ttl: ttl,
            now: _now,
            networkAvailable: _networkAvailable,
          ),
        );
    return read();
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) {
    final _StationKey key = (station, limit);
    final Duration ttl = ondeTtlFor(_clock());
    final Future<List<OndeObservation>> Function() read = _stationReads
        .putIfAbsent(
          (key, ttl),
          () => withCachePolicy<List<OndeObservation>>(
            load: () => _inner.historyFor(station, limit: limit),
            readCache: () async => _stationCache[key],
            writeCache: (List<OndeObservation> value) async {
              _stationCache[key] = CachedValue<List<OndeObservation>>(
                value: value,
                storedAt: _clock(),
              );
            },
            ttl: ttl,
            now: _now,
            networkAvailable: _networkAvailable,
          ),
        );
    return read();
  }
}

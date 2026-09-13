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
// Stockage en mémoire, sans purge : aucun stockage local n'existe encore
// (ADR-011 réservé). La clé `(OndeStationCode, int)` de `historyFor` reste
// bornée par le référentiel, comme `CachedHydroObservationRepository`
// (D6) ; la clé `(Bounds, since)` de `latestWithinBounds`, elle, ne l'EST
// PAS — la vue construit une emprise neuve à chaque relâchement de geste, et
// une entrée s'accumule par emprise visitée, pour toute la durée de la
// session, jamais purgée. Acceptable tant que la carte reste la seule
// appelante ; la conception (`docs/03-conception.md § 4.1`, « 2 dernières
// campagnes conservées ») n'est pas implémentée ici — à reprendre avec
// ADR-011, pas avant.
//
// `_TtlCache` factorise le couplage clé/TTL commun aux deux méthodes
// (piège d'usage de `withCachePolicy`, documenté dans `cache_policy.dart`) :
// une fermeture par (clé, ttl), jamais reconstruite à chaque lecture, sinon
// la déduplication des rafraîchissements en vol (C-12) serait perdue. Le
// TTL est calculé par `ondeTtlFor(now())` AU MOMENT de la création de la
// fermeture ; un changement de saison entre deux lectures en crée donc une
// nouvelle, mais les deux partagent la même entrée de la `Map` de valeurs
// (indexée par clé seule) : aucune donnée n'est perdue au basculement. Cas
// limite accepté : si un rafraîchissement de l'ancienne fermeture est
// encore en vol au moment de la bascule, il ne se déduplique pas avec celui
// que lance la fermeture nouvellement créée pour la même clé — au plus une
// fois par an et par clé, sans conséquence (les deux écrivent dans la même
// entrée, la dernière écriture gagne).
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
///
/// [date] n'est jamais convertie en UTC : le mois est lu dans le fuseau de
/// la date passée, parce que le calendrier des campagnes de terrain est
/// local, jamais UTC — avec un `.toUtc()`, le 1er mai à 0 h 30 heure locale
/// (été, UTC+2) retomberait au 30 avril en UTC et tomberait à tort hors
/// saison.
Duration ondeTtlFor(DateTime date) {
  final int month = date.month;
  if (month >= DateTime.may && month <= DateTime.september) {
    return ondeTtlInSeason;
  }
  return ondeTtlOffSeason;
}

typedef _BoundsKey = (Bounds, DateTime);
typedef _StationKey = (OndeStationCode, int);

/// Cache stale-while-revalidate générique pour UNE forme de clé [K] et de
/// valeur [V] : une `Map<K, CachedValue<V>>` de valeurs, une fermeture par
/// (clé, ttl) — voir le commentaire d'en-tête sur le piège d'usage de
/// `withCachePolicy` et le partage d'entrée au changement de saison. Seul
/// endroit qui connaît ce couplage clé/TTL ; `CachedOndeObservationRepository`
/// en instancie un par méthode, sans le recopier.
final class _TtlCache<K, V> {
  _TtlCache({this.now, this.networkAvailable});

  final DateTime Function()? now;
  final bool Function()? networkAvailable;

  final Map<K, CachedValue<V>> _values = <K, CachedValue<V>>{};
  final Map<(K, Duration), Future<V> Function()> _reads =
      <(K, Duration), Future<V> Function()>{};

  Future<V> read(
    K key, {
    required Duration ttl,
    required Future<V> Function() load,
  }) {
    final Future<V> Function() cachedRead = _reads.putIfAbsent(
      (key, ttl),
      () => withCachePolicy<V>(
        load: load,
        readCache: () async => _values[key],
        writeCache: (V value) async {
          _values[key] = CachedValue<V>(
            value: value,
            storedAt: (now ?? DateTime.now)(),
          );
        },
        ttl: ttl,
        now: now,
        networkAvailable: networkAvailable,
      ),
    );
    return cachedRead();
  }
}

/// Décore un [OndeObservationRepository] par la politique de cache
/// stale-while-revalidate, avec un TTL qui dépend du mois de lecture.
final class CachedOndeObservationRepository
    implements OndeObservationRepository {
  /// [networkAvailable] n'est retenu que le temps de construire les deux
  /// caches ci-dessous : chacun garde sa propre référence, ce champ ne
  /// serait plus jamais lu ensuite (contrairement à [_now], réutilisé par
  /// [_clock] à chaque lecture).
  CachedOndeObservationRepository({
    required this._inner,
    this._now,
    bool Function()? networkAvailable,
  }) : _boundsCache = _TtlCache<_BoundsKey, List<OndeObservation>>(
         now: _now,
         networkAvailable: networkAvailable,
       ),
       _stationCache = _TtlCache<_StationKey, List<OndeObservation>>(
         now: _now,
         networkAvailable: networkAvailable,
       );

  final OndeObservationRepository _inner;
  final DateTime Function()? _now;

  final _TtlCache<_BoundsKey, List<OndeObservation>> _boundsCache;
  final _TtlCache<_StationKey, List<OndeObservation>> _stationCache;

  DateTime _clock() => (_now ?? DateTime.now)();

  @override
  Future<List<OndeObservation>> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    // Normalisée à son jour calendaire — mêmes composantes que celles lues
    // par `formatDateUtc` sur la requête — pour que deux horaires du même
    // jour ne ratent jamais le cache l'un de l'autre.
    final DateTime sinceKey = DateTime.utc(since.year, since.month, since.day);

    final List<OndeObservation> value = await _boundsCache.read(
      (bounds, sinceKey),
      ttl: ondeTtlFor(_clock()),
      load: () => _inner.latestWithinBounds(bounds, since: since),
    );
    return List<OndeObservation>.unmodifiable(value);
  }

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final List<OndeObservation> value = await _stationCache.read(
      (station, limit),
      ttl: ondeTtlFor(_clock()),
      load: () => _inner.historyFor(station, limit: limit),
    );
    return List<OndeObservation>.unmodifiable(value);
  }
}

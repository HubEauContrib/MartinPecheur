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
// (D6) ; la clé `(Bounds, String)` de `latestWithinBounds`, elle, ne l'EST
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
//
// C'est l'`OndeSweep` ENTIER qui est mis en cache depuis `U6`, son compte de
// lignes illisibles compris : ce compte est une propriété de la PAGE lue, il
// vieillit avec elle. Un écran servi par le cache doit pouvoir dire « N
// points d'observation non lisibles sur cette emprise » aussi bien qu'un
// écran servi par le réseau — sans quoi l'explication de l'absence
// disparaîtrait au premier TTL (BR-007, `T-14`).
//
// Une seule résolution d'horloge dans ce fichier : `CachedOndeObservationRepository`
// calcule `now ?? DateTime.now` une fois, dans son constructeur, et
// transmet cette fonction déjà résolue aux deux `_TtlCache` (leur champ
// `clock` n'est plus nullable) — `withCachePolicy`, dans
// `cache_policy.dart`, fait sa propre résolution par ailleurs, mais c'est
// un fichier distinct.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/data/http/hub_eau_paging.dart' show formatDateUtc;
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show OndeObservationRepository, OndeSweep;

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

/// Clé de `latestWithinBounds` : la CHAÎNE envoyée à l'API pour
/// `date_observation_min` (voir [formatDateUtc]), pas une [DateTime]
/// reconstruite ici — il n'y aurait alors plus deux fonctions à garder
/// d'accord sur ce qu'est « le même jour ». `since.year`/`.month`/`.day` lus
/// sans `toUtc()` auraient pu faire partager une entrée à deux requêtes
/// dont l'API reçoit deux `date_observation_min` différents (N1).
typedef _BoundsKey = (Bounds, String);
typedef _StationKey = (OndeStationCode, int);

/// Cache stale-while-revalidate générique pour UNE forme de clé [K] et de
/// valeur [V] : une `Map<K, CachedValue<V>>` de valeurs, une fermeture par
/// (clé, ttl) — voir le commentaire d'en-tête sur le piège d'usage de
/// `withCachePolicy` et le partage d'entrée au changement de saison. Seul
/// endroit qui connaît ce couplage clé/TTL ; `CachedOndeObservationRepository`
/// en instancie un par méthode, sans le recopier. [clock] est déjà résolue
/// par l'appelant (jamais nullable ici) : voir le commentaire d'en-tête sur
/// la résolution unique de l'horloge.
final class _TtlCache<K, V> {
  _TtlCache({required this.clock, this.networkAvailable});

  final DateTime Function() clock;
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
          _values[key] = CachedValue<V>(value: value, storedAt: clock());
        },
        ttl: ttl,
        now: clock,
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
  /// [now] est résolu une seule fois ici (`now ?? DateTime.now`), puis
  /// transmis déjà résolu aux deux caches ci-dessous : c'est la seule
  /// résolution d'horloge de ce fichier (N3). [networkAvailable] n'est
  /// retenu, lui, que le temps de construire les deux caches : chacun garde
  /// sa propre référence, un champ ici ne serait plus jamais lu ensuite.
  CachedOndeObservationRepository({
    required this._inner,
    DateTime Function()? now,
    bool Function()? networkAvailable,
  }) : _clock = now ?? DateTime.now {
    _boundsCache = _TtlCache<_BoundsKey, OndeSweep>(
      clock: _clock,
      networkAvailable: networkAvailable,
    );
    _stationCache = _TtlCache<_StationKey, List<OndeObservation>>(
      clock: _clock,
      networkAvailable: networkAvailable,
    );
  }

  final OndeObservationRepository _inner;
  final DateTime Function() _clock;

  late final _TtlCache<_BoundsKey, OndeSweep> _boundsCache;
  late final _TtlCache<_StationKey, List<OndeObservation>> _stationCache;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async {
    // La fermeture `load` capturée par `putIfAbsent` garde le `since` du
    // premier appelant à créer l'entrée ; comme la clé est maintenant la
    // chaîne UTC envoyée à l'API, deux appelants dont la clé coïncide
    // demandent forcément la même chose — capturer l'un ou l'autre `since`
    // interroge la même URI.
    final OndeSweep value = await _boundsCache.read(
      (bounds, formatDateUtc(since)),
      ttl: ondeTtlFor(_clock()),
      load: () => _inner.latestWithinBounds(bounds, since: since),
    );
    // Un balayage neuf, dont seule la liste est rendue non modifiable : le
    // compte le suit tel quel, il n'y a rien à protéger sur un `int`.
    return OndeSweep(
      observations: List<OndeObservation>.unmodifiable(value.observations),
      unreadableRows: value.unreadableRows,
    );
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

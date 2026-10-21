// Décore `RestrictionSource` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique de
// cache (stale-while-revalidate) reste dans son seul décorateur ; ce
// fichier se contente de l'APPELER (CLAUDE.md § Architecture, D4 de T2).
//
// Cache de SESSION, en mémoire, sans purge, perdu au relancement (Q7-A) :
// aucun moteur de donnée structurée n'existe encore (`ADR-011` ne tranche
// que la préférence simple).
//
// Clé = `formatPointParameters(point)` (`vigieau_uris.dart`) — la MÊME
// chaîne que celle envoyée à l'URI, jamais les composantes brutes du
// `GeoPoint` : c'est ce qui fait qu'un point voisin arrondi à la même
// septième décimale partage l'entrée de son voisin (leçon N1 d'ONDE,
// `cached_onde_observation_repository.dart`).
//
// TTL fixe, une seule constante : contrairement au TTL saisonnier d'ONDE,
// les restrictions n'ont qu'un seul chiffre (Q7, six heures) — pas de
// `_TtlCache` générique ici, un seul `withCachePolicyReads`, gardé par point
// dans une `Map` (piège d'usage documenté dans `cache_policy.dart` : la
// déduplication des rafraîchissements en vol vit dans les fermetures
// elles-mêmes, jamais reconstruites à chaque lecture). Ses deux lectures
// servent `zonesAt` et la vue fraîche `fresh` (D1 de T5), sur la même
// entrée du point : jamais deux téléchargements à la fois pour un point.
//
// Un échec n'est jamais mis en cache (conception T2 § 3, rappelé dans
// `restriction_source.dart`) : `RestrictionSource.zonesAt` LÈVE, jamais ne
// rend, un `RestrictionLookupFailure` — `withCachePolicy` n'écrit en cache
// que ce que `load` REND, jamais ce qu'il lève. Rien à faire ici pour
// garantir cela : c'est une propriété de `withCachePolicy`, pas de ce
// fichier.
//
// AR-3 : une entrée de plus de six heures est servie immédiatement, datée
// de son `retrievedAt` d'origine — `retrievedAt` voyage AVEC la réponse
// (`ZonesAtPoint`), pas dans le cache : rien à recalculer ici, la valeur
// mise en cache porte déjà sa propre date. Un rafraîchissement part en
// tâche de fond ; la lecture suivante rend la réponse rafraîchie.
//
// La fermeture `load` capturée par `_reads.putIfAbsent` garde le `point`
// du PREMIER appelant à créer l'entrée (piège documenté dans
// `cached_onde_observation_repository.dart`, l. 181-185) : comme la clé
// est la chaîne formatée à sept décimales, deux points dont la clé
// coïncide (écart inférieur à 1e-7°) demandent forcément la même chose —
// capturer l'un ou l'autre `point` interroge le même point pour VigiEau.
//
// `_values` et `_reads` grossissent sans borne pendant la session (Q7,
// « sans purge ») : chaque point interrogé une fois y laisse une entrée
// jusqu'à la fermeture de l'application. Acceptable tant que l'entrée
// géographique reste un point désigné à la main (Q1-A), jamais un
// balayage — à reprendre avec `ADR-011` si un moteur structuré remplace un
// jour ce cache de session.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/data/restrictions/vigieau_uris.dart'
    show formatPointParameters;
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// TTL du cache des restrictions, `docs/superpowers/plans/…` (Q7-A) : six
/// heures, un seul chiffre, écrit ici et nulle part ailleurs.
const Duration restrictionsCacheTtl = Duration(hours: 6);

/// Clé de cache : la chaîne `(lat, lon)` formatée à sept décimales, la
/// même que celle envoyée à l'URI (`formatPointParameters`).
typedef _PointKey = ({String lat, String lon});

/// Décore un [RestrictionSource] par la politique de cache
/// stale-while-revalidate, TTL fixe de six heures, cache de session en
/// mémoire.
final class CachedRestrictionSource implements RestrictionSource {
  /// [now] est résolu une seule fois ici (`now ?? DateTime.now`), comme
  /// `CachedOndeObservationRepository` : seule résolution d'horloge de ce
  /// fichier.
  ///
  /// Pas de signal « réseau disponible » ici : rien ne le fournit (aucune
  /// bibliothèque de connectivité, `main.dart` ne câble rien). Une entrée
  /// périmée lance donc toujours son rafraîchissement ; hors réseau il
  /// échoue, et la dernière valeur connue reste servie (`withCachePolicy`).
  CachedRestrictionSource({required this._inner, DateTime Function()? now})
    : _clock = now ?? DateTime.now;

  final RestrictionSource _inner;
  final DateTime Function() _clock;

  final Map<_PointKey, CachedValue<ZonesAtPoint>> _values =
      <_PointKey, CachedValue<ZonesAtPoint>>{};
  final Map<_PointKey, CachedReads<ZonesAtPoint>> _reads =
      <_PointKey, CachedReads<ZonesAtPoint>>{};

  /// La vue fraîche (D1 de T5) : son `zonesAt(point)` appelle la lecture
  /// fraîche de **l'entrée du point**, la même que celle de [zonesAt]. Une
  /// réponse de moins de [restrictionsCacheTtl] est rendue telle quelle ;
  /// sinon la vue attend la source et laisse remonter son échec.
  late final RestrictionSource fresh = _FreshRestrictionSource(
    (GeoPoint point) => _readsAt(point).readFresh(),
  );

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) => _readsAt(point).read();

  CachedReads<ZonesAtPoint> _readsAt(GeoPoint point) {
    final _PointKey key = formatPointParameters(point);
    return _reads.putIfAbsent(
      key,
      () => withCachePolicyReads<ZonesAtPoint>(
        load: () => _inner.zonesAt(point),
        readCache: () async => _values[key],
        writeCache: (ZonesAtPoint value) async {
          _values[key] = CachedValue<ZonesAtPoint>(
            value: value,
            storedAt: _clock(),
          );
        },
        ttl: restrictionsCacheTtl,
        now: _clock,
      ),
    );
  }
}

/// La vue fraîche de [CachedRestrictionSource] : une lecture, rien d'autre.
final class _FreshRestrictionSource implements RestrictionSource {
  const _FreshRestrictionSource(this._readFresh);

  final Future<ZonesAtPoint> Function(GeoPoint point) _readFresh;

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) => _readFresh(point);
}

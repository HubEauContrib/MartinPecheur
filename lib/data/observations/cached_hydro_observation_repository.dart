// Decore `HydroObservationRepository` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique de
// cache (stale-while-revalidate) reste dans son seul decorateur ; ce fichier
// se contente de l'APPELER (CLAUDE.md § Architecture).
//
// TTL de `observations_tr` (`docs/03-conception.md § 4.1`) : vingt minutes.
// C'est la seule occurrence de ce chiffre sous `lib/` — une seconde serait
// une divergence future.
//
// Stockage en memoire seulement (une `Map`) : aucun stockage local n'existe
// encore (ADR-011 reserve). Une absence (`null`, BR-007) est mise en cache
// comme une valeur ordinaire : une `CachedValue<HydroObservation?>` dont la
// `value` est `null` reste une entree presente, distincte d'une cle absente
// de la `Map` (cache vide) — c'est ce qui evite de reinterroger une absence
// deja constatee avant le TTL.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';

/// TTL de `observations_tr` (`docs/03-conception.md § 4.1`).
const Duration observationsTrTtl = Duration(minutes: 20);

/// Cle d'une entree de cache : un `record` convient, `StationCode` porte
/// `==`/`hashCode` structurels (`lib/domain/station/station.dart`) et
/// `Grandeur` est un `enum` (egalite d'identite) — deux cles egales
/// composant par composant sont donc bien la meme entree de `Map`.
typedef _ObservationKey = (StationCode, Grandeur);

/// Decore un [HydroObservationRepository] par la politique de cache
/// stale-while-revalidate : rendu immediat depuis le cache, rafraichissement
/// en tache de fond si perime et le reseau disponible, dedupliction des
/// rafraichissements en vol (C-12).
final class CachedHydroObservationRepository
    implements HydroObservationRepository {
  CachedHydroObservationRepository({
    required HydroObservationRepository inner,
    Duration ttl = observationsTrTtl,
    DateTime Function()? now,
    bool Function()? networkAvailable,
  }) : _inner = inner, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _ttl = ttl,
       // ignore: prefer_initializing_formals
       _now = now,
       // ignore: prefer_initializing_formals
       _networkAvailable = networkAvailable {
    // `withCachePolicy` refuse deja un TTL non strictement positif, mais
    // seulement a la creation de la fermeture d'une cle — laquelle n'a lieu
    // qu'a sa premiere lecture (une fermeture par cle, jamais reconstruite,
    // cf. le piege d'usage documente dans `cache_policy.dart`). La tache
    // exige un echec des la construction du depot : ce seul `if` duplique
    // ce controle pour l'anticiper, plutot que de fabriquer une fermeture
    // factice au seul usage de declencher la verification — plus simple a
    // lire pour un controle aussi elementaire.
    if (_ttl <= Duration.zero) {
      throw ArgumentError.value(_ttl, 'ttl', 'doit etre strictement positif');
    }
  }

  final HydroObservationRepository _inner;
  final Duration _ttl;
  final DateTime Function()? _now;
  final bool Function()? _networkAvailable;

  final Map<_ObservationKey, CachedValue<HydroObservation?>> _cache =
      <_ObservationKey, CachedValue<HydroObservation?>>{};

  /// Une fermeture par cle (piege d'usage de [withCachePolicy]) : la
  /// deduplication des rafraichissements en vol vit dans la fermeture
  /// elle-meme ; la reconstruire a chaque lecture l'annulerait (C-12).
  final Map<_ObservationKey, Future<HydroObservation?> Function()> _reads =
      <_ObservationKey, Future<HydroObservation?> Function()>{};

  @override
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur) {
    final _ObservationKey key = (station, grandeur);
    final Future<HydroObservation?> Function() read = _reads.putIfAbsent(
      key,
      () => withCachePolicy<HydroObservation?>(
        load: () => _inner.findLatest(station, grandeur),
        readCache: () async => _cache[key],
        writeCache: (HydroObservation? value) async {
          _cache[key] = CachedValue<HydroObservation?>(
            value: value,
            storedAt: (_now ?? DateTime.now)(),
          );
        },
        ttl: _ttl,
        now: _now,
        networkAvailable: _networkAvailable,
      ),
    );
    return read();
  }
}

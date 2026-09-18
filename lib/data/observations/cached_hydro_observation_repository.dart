// Décore `HydroObservationRepository` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique de
// cache (stale-while-revalidate) reste dans son seul décorateur ; ce fichier
// se contente de l'APPELER (CLAUDE.md § Architecture).
//
// TTL de `observations_tr` (`docs/03-conception.md § 4.1`) : vingt minutes.
// C'est la seule occurrence de ce chiffre sous `lib/` — une seconde serait
// une divergence future.
//
// Stockage en mémoire seulement, dans deux `Map` sans purge : aucun
// stockage local structuré n'existe encore (ADR-011 ne tranche que la
// préférence simple). Chacune ne porte
// qu'une entrée par couple (station, grandeur) effectivement lu — borné en
// pratique par le référentiel (4 150 stations × 2 grandeurs), jamais par
// davantage. Une éviction viendra avec ADR-011, pas avant.
//
// Une absence (`null`, BR-007) est mise en cache comme une valeur
// ordinaire : une `CachedValue<HydroObservation?>` dont la `value` est
// `null` reste une entrée présente, distincte d'une clé absente de la
// `Map` (cache vide) — c'est ce qui évite de réinterroger une absence déjà
// constatée avant le TTL.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show HydroObservationRepository;
import 'package:martinpecheur/domain/station/station.dart';

/// TTL de `observations_tr` (`docs/03-conception.md § 4.1`).
const Duration observationsTrTtl = Duration(minutes: 20);

/// Clé d'une entrée de cache : un `record` convient, `StationCode` porte
/// `==`/`hashCode` structurels (`lib/domain/station/station.dart`) et
/// `Grandeur` est un `enum` (égalité d'identité) — deux clés égales
/// composant par composant sont donc bien la même entrée de `Map`.
typedef _ObservationKey = (StationCode, Grandeur);

/// Décore un [HydroObservationRepository] par la politique de cache
/// stale-while-revalidate : rendu immédiat depuis le cache, rafraîchissement
/// en tâche de fond si périmé et le réseau disponible, déduplication des
/// rafraîchissements en vol (C-12).
final class CachedHydroObservationRepository
    implements HydroObservationRepository {
  /// Lève [ArgumentError] si [ttl] n'est pas strictement positif.
  CachedHydroObservationRepository({
    required this._inner,
    this._ttl = observationsTrTtl,
    this._now,
    this._networkAvailable,
  }) {
    // `withCachePolicy` refuse déjà un TTL non strictement positif, mais
    // seulement à la création de la fermeture d'une clé — laquelle n'a lieu
    // qu'à sa première lecture (une fermeture par clé, jamais reconstruite,
    // cf. le piège d'usage documenté dans `cache_policy.dart`). La tâche
    // exige un échec dès la construction du dépôt : ce seul `if` duplique
    // ce contrôle pour l'anticiper, plutôt que de fabriquer une fermeture
    // factice au seul usage de déclencher la vérification — plus simple à
    // lire pour un contrôle aussi élémentaire.
    if (_ttl <= Duration.zero) {
      throw ArgumentError.value(_ttl, 'ttl', 'doit être strictement positif');
    }
  }

  final HydroObservationRepository _inner;
  final Duration _ttl;
  final DateTime Function()? _now;
  final bool Function()? _networkAvailable;

  final Map<_ObservationKey, CachedValue<HydroObservation?>> _cache =
      <_ObservationKey, CachedValue<HydroObservation?>>{};

  /// Une fermeture par clé (piège d'usage de [withCachePolicy]) : la
  /// déduplication des rafraîchissements en vol vit dans la fermeture
  /// elle-même ; la reconstruire à chaque lecture l'annulerait (C-12).
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

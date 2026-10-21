// Decore `FloodVigilanceSource` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique
// stale-while-revalidate reste dans son seul decorateur, ce fichier l'APPELLE
// (W3 de T4, cadrage § 6).
//
// Cache de SESSION, en memoire, **une seule entree** : la carte de vigilance
// est nationale, il n'y a pas de cle. Un seul `withCachePolicyReads`, garde
// dans un champ (piege d'usage de `cache_policy.dart` : le dedoublonnage des
// rafraichissements en vol vit dans les fermetures). Ses deux lectures
// servent `current()` et la vue fraiche `fresh` (D1 de T5), sur la meme
// entree : jamais deux telechargements a la fois.
//
// Perimee, la carte est rendue avec sa date (elle la porte, BR-001) pendant
// qu'une nouvelle se charge en fond. Un rafraichissement en echec est absorbe
// et ne met rien a jour : l'entree reste perimee, l'appel suivant relance un
// rafraichissement (arbitrage 12), un seul tant qu'il court. Un echec du
// premier appel remonte et n'est jamais ecrit.

import 'package:martinpecheur/data/cache/cache_policy.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';

/// Duree de conservation de la carte de vigilance (arbitrage 6) : trente
/// minutes, un seul chiffre, ecrit ici et nulle part ailleurs.
const Duration floodVigilanceCacheTtl = Duration(minutes: 30);

/// Decore un [FloodVigilanceSource] par la politique de cache, une entree.
final class CachedFloodVigilanceSource implements FloodVigilanceSource {
  CachedFloodVigilanceSource({
    required FloodVigilanceSource inner,
    DateTime Function()? now,
  }) : _clock = now ?? DateTime.now {
    _reads = withCachePolicyReads<FloodVigilanceMap>(
      load: inner.current,
      readCache: () async => _entry,
      writeCache: (FloodVigilanceMap value) async {
        _entry = CachedValue<FloodVigilanceMap>(
          value: value,
          storedAt: _clock(),
        );
      },
      ttl: floodVigilanceCacheTtl,
      now: _clock,
    );
  }

  final DateTime Function() _clock;
  CachedValue<FloodVigilanceMap>? _entry;
  late final CachedReads<FloodVigilanceMap> _reads;

  /// La vue fraiche (D1 de T5), sur **la meme** entree : son `current()`
  /// rend la carte en cache si elle a moins de [floodVigilanceCacheTtl],
  /// sinon attend la source, et laisse remonter son echec. La carte perimee
  /// reste alors rendue, avec sa date, par [current].
  late final FloodVigilanceSource fresh = _FreshFloodVigilanceSource(
    _reads.readFresh,
  );

  @override
  Future<FloodVigilanceMap> current() => _reads.read();
}

/// La vue fraiche de [CachedFloodVigilanceSource] : une lecture, rien d'autre.
final class _FreshFloodVigilanceSource implements FloodVigilanceSource {
  const _FreshFloodVigilanceSource(this._readFresh);

  final Future<FloodVigilanceMap> Function() _readFresh;

  @override
  Future<FloodVigilanceMap> current() => _readFresh();
}

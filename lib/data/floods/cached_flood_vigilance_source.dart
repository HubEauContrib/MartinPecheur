// Decore `FloodVigilanceSource` par la politique de cache
// (`lib/data/cache/cache_policy.dart`), et rien d'autre : la politique
// stale-while-revalidate reste dans son seul decorateur, ce fichier l'APPELLE
// (W3 de T4, cadrage § 6).
//
// Cache de SESSION, en memoire, **une seule entree** : la carte de vigilance
// est nationale, il n'y a pas de cle. Une seule fermeture `withCachePolicy`,
// gardee dans un champ (piege d'usage de `cache_policy.dart` : le
// dedoublonnage des rafraichissements en vol vit dans la fermeture).
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
    _read = withCachePolicy<FloodVigilanceMap>(
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
  late final Future<FloodVigilanceMap> Function() _read;

  @override
  Future<FloodVigilanceMap> current() => _read();
}

// La politique de cache vit ici, et nulle part ailleurs (cf. CLAUDE.md §
// Architecture) : jamais recopiee dans un depot ni dans un ecran. Rendu
// immediat depuis le cache, rafraichissement en tache de fond
// (stale-while-revalidate) si l'entree est perimee et le reseau disponible.
// L'affichage n'attend jamais le reseau.

import 'dart:async';

/// Une valeur mise en cache, avec l'instant de son ecriture. [storedAt] est
/// la date de RECUPERATION par le cache — sans rapport avec la fraicheur
/// metier d'une observation (BR-005, qui date l'observation elle-meme, pas
/// le cache qui la contient). La borne de peremption appartient a l'etat
/// perime : c'est [withCachePolicy] qui la lit, jamais un depot ni un ecran.
final class CachedValue<T> {
  const CachedValue({required this.value, required this.storedAt});

  /// La valeur mise en cache.
  final T value;

  /// L'instant ou [value] a ete ecrite en cache.
  final DateTime storedAt;
}

bool _toujoursDisponible() => true;

/// Construit une fonction de lecture stale-while-revalidate.
///
/// Rend immediatement la valeur en cache si [readCache] en renvoie une, sans
/// jamais attendre [load] pour l'affichage. Si cette valeur est perimee
/// (`now() - storedAt >= ttl`) et que [networkAvailable] repond `true`, lance
/// [load] en tache de fond pour rafraichir le cache via [writeCache].
///
/// Deduplique les rafraichissements en vol (`C-12`) : plusieurs lectures
/// simultanees sur une entree perimee ne declenchent qu'un seul appel a
/// [load]. Un rafraichissement en echec laisse la derniere valeur connue,
/// n'ecrit rien, et ne bloque pas les rafraichissements suivants — la mise
/// en vol est liberee dans un `finally` (BR-007).
///
/// Un cache vide (`readCache` rend `null`) attend [load], le rend et
/// l'ecrit : rien n'est encore perime, il n'y a rien de perime a afficher en
/// attendant.
///
/// Leve un [ArgumentError] si [ttl] n'est pas strictement positif — a la
/// construction de la fonction, avant tout appel.
Future<T> Function() withCachePolicy<T>({
  required Future<T> Function() load,
  required Future<CachedValue<T>?> Function() readCache,
  required Future<void> Function(T value) writeCache,
  required Duration ttl,
  DateTime Function()? now,
  bool Function()? networkAvailable,
}) {
  if (ttl <= Duration.zero) {
    throw ArgumentError.value(ttl, 'ttl', 'doit etre strictement positif');
  }

  final DateTime Function() horloge = now ?? DateTime.now;
  final bool Function() reseauDisponible =
      networkAvailable ?? _toujoursDisponible;

  Future<T>? rafraichissementEnVol;

  Future<T> rafraichir() {
    final Future<T>? existant = rafraichissementEnVol;
    if (existant != null) {
      return existant;
    }

    Future<T> lancer() async {
      try {
        final T valeur = await load();
        await writeCache(valeur);
        return valeur;
      } finally {
        rafraichissementEnVol = null;
      }
    }

    final Future<T> lance = lancer();
    rafraichissementEnVol = lance;
    return lance;
  }

  return () async {
    final CachedValue<T>? enCache = await readCache();
    if (enCache == null) {
      return rafraichir();
    }

    final bool perime = horloge().difference(enCache.storedAt) >= ttl;
    if (perime && reseauDisponible()) {
      unawaited(
        rafraichir().then<void>(
          (T _) {},
          onError: (Object _) {
            // La derniere valeur connue reste en cache (BR-007) : l'echec
            // est deja absorbe ici, il ne doit pas ressortir comme erreur
            // non geree.
          },
        ),
      );
    }

    return enCache.value;
  };
}

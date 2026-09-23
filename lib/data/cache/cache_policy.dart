// La politique de cache vit ici, et nulle part ailleurs (cf. CLAUDE.md §
// Architecture) : jamais recopiee dans un depot, un ViewModel ni un widget.
// Rendu immediat depuis le cache, rafraichissement en tache de fond
// (stale-while-revalidate) si l'entree est perimee et le reseau disponible.
// L'affichage n'attend jamais le reseau.
//
// C'est un **decorateur de depot** (R4, arbitrage 2026-09-13 — ADR-014) : un
// depot enveloppe sa propre lecture dans [withCachePolicy] et garde la
// fermeture obtenue dans un champ. Le principe « un seul endroit » survit ;
// seul le vehicule a change — il vivait sous `lib/application/`, au temps ou
// un registre de messages l'inserait dans un pipeline. Le corps de ce fichier
// n'a pas bouge d'un caractere avec ce deplacement.

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

bool _alwaysAvailable() => true;

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
/// attendant. **Y compris quand [networkAvailable] repond `false`** : la
/// fonction ne consulte [networkAvailable] que sur une entree perimee, jamais
/// sur un cache vide. [load] est donc tente malgre tout ; s'il echoue,
/// l'echec remonte tel quel a l'appelant (BR-007), a qui revient d'afficher
/// une absence explicite plutot qu'une valeur inventee.
///
/// Un echec de [writeCache] n'est jamais qu'un confort perdu, jamais une
/// condition de lecture : que le cache soit vide ou perime, une valeur
/// fraichement chargee par [load] est rendue meme si son ecriture en cache
/// echoue. Seul un echec de [load] peut faire echouer la lecture.
///
/// Leve un [ArgumentError] si [ttl] n'est pas strictement positif — a la
/// construction de la fonction, avant tout appel.
///
/// ⚠️ **Piege d'usage** : la deduplication des rafraichissements en vol vit
/// dans la fermeture rendue par cet appel, pas dans [withCachePolicy]
/// lui-meme. L'appelant doit donc **conserver une seule fermeture par entree
/// de cache** (par exemple dans un champ de depot) et l'invoquer a chaque
/// lecture. Appeler `withCachePolicy(...)()` a chaque lecture reconstruit une
/// fermeture neuve — donc un nouveau verrou toujours `null` — et annule la
/// deduplication : chaque lecture simultanee relancerait son propre [load].
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

  final DateTime Function() clock = now ?? DateTime.now;
  final bool Function() isNetworkAvailable =
      networkAvailable ?? _alwaysAvailable;

  Future<T>? refreshInFlight;

  Future<T> refresh() {
    final Future<T>? existing = refreshInFlight;
    if (existing != null) {
      return existing;
    }

    Future<T> run() async {
      try {
        // Future.sync garantit que meme un load() synchrone (fonction non
        // async qui leve immediatement) echoue de facon ASYNCHRONE : sans
        // cela, l'exception remonterait pendant la partie synchrone de
        // run(), le `finally` liberait le verrou avant que l'affectation
        // `refreshInFlight = launched` ci-dessous n'ait eu lieu, et cette
        // affectation ecraserait ensuite le verrou libere avec un future
        // deja en echec — bloque a vie (relecture du 2026-09-13).
        final T value = await Future<T>.sync(load);
        try {
          await writeCache(value);
        } catch (_) {
          // Le cache est un confort, pas une condition de lecture : la
          // valeur fraiche vient d'etre chargee avec succes, un echec
          // d'ecriture ne doit pas la faire perdre.
        }
        return value;
      } finally {
        refreshInFlight = null;
      }
    }

    final Future<T> launched = run();
    refreshInFlight = launched;
    return launched;
  }

  return () async {
    final CachedValue<T>? cached = await readCache();
    if (cached == null) {
      return refresh();
    }

    final bool isStale = clock().difference(cached.storedAt) >= ttl;
    if (isStale && isNetworkAvailable()) {
      unawaited(
        refresh().then<void>(
          (T _) {},
          onError: (Object _) {
            // La derniere valeur connue reste en cache (BR-007) : l'echec
            // est deja absorbe ici, il ne doit pas ressortir comme erreur
            // non geree.
          },
        ),
      );
    }

    return cached.value;
  };
}

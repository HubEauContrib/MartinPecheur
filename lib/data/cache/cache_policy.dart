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
// un registre de messages l'inserait dans un pipeline.
//
// La lecture fraiche (D1 de T5) s'ajoute ici, a cote de la lecture
// ordinaire, et nulle part ailleurs : [withCachePolicyReads] rend les deux
// lectures d'une meme entree, qui partagent le meme rafraichissement en vol.
// La verification des lieux suivis lit la vue fraiche ; les ecrans gardent la
// lecture ordinaire, qui n'attend jamais le reseau sur une entree en cache.

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

/// Les deux lectures d'une meme entree de cache, rendues par
/// [withCachePolicyReads]. Elles partagent le meme rafraichissement en vol :
/// jamais deux appels a `load` a la fois pour une entree.
final class CachedReads<T> {
  const CachedReads({required this.read, required this.readFresh});

  /// La lecture ordinaire, stale-while-revalidate : n'attend `load` que sur
  /// un cache vide (voir [withCachePolicy]).
  final Future<T> Function() read;

  /// La lecture fraiche : rend la valeur en cache si elle est encore valide
  /// (age strictement inferieur au `ttl`), sinon attend `load`, partage avec
  /// un rafraichissement deja en vol. Un echec remonte tel quel.
  final Future<T> Function() readFresh;
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
/// C'est la lecture ordinaire de [withCachePolicyReads], seule : les
/// appelants qui n'ont pas besoin d'une lecture fraiche (hydrometrie, ONDE)
/// gardent cette signature et ce comportement.
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
}) => withCachePolicyReads<T>(
  load: load,
  readCache: readCache,
  writeCache: writeCache,
  ttl: ttl,
  now: now,
  networkAvailable: networkAvailable,
).read;

/// Construit les deux lectures d'une entree de cache, avec les memes
/// parametres que [withCachePolicy].
///
/// - [CachedReads.read] : la lecture stale-while-revalidate de
///   [withCachePolicy], inchangee.
/// - [CachedReads.readFresh] : [readCache] d'abord. Une valeur **valide**
///   (`now() - storedAt < ttl`) est rendue telle quelle, sans appel a [load].
///   Une valeur **perimee** (`>= ttl`, borne incluse, la meme que la lecture
///   ordinaire) ou **absente** se relit : la lecture attend [load], partage
///   avec un rafraichissement deja en vol. [networkAvailable] n'est pas
///   consulte. Un echec de [load] remonte tel quel et n'ecrit rien :
///   l'ancienne valeur reste en cache pour [CachedReads.read].
///
/// Les deux lectures partagent **le meme** rafraichissement en vol : une
/// lecture ordinaire perimee et une lecture fraiche lancees ensemble ne font
/// qu'un appel a [load]. Le piege d'usage de [withCachePolicy] vaut ici
/// aussi : un seul [CachedReads] par entree de cache.
///
/// Leve un [ArgumentError] si [ttl] n'est pas strictement positif.
CachedReads<T> withCachePolicyReads<T>({
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

  bool isStale(CachedValue<T> cached) =>
      clock().difference(cached.storedAt) >= ttl;

  Future<T> read() async {
    final CachedValue<T>? cached = await readCache();
    if (cached == null) {
      return refresh();
    }

    if (isStale(cached) && isNetworkAvailable()) {
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
  }

  Future<T> readFresh() async {
    final CachedValue<T>? cached = await readCache();
    if (cached != null && !isStale(cached)) {
      return cached.value;
    }
    // Perimee ou absente : on attend le rafraichissement, partage avec celui
    // qui serait deja en vol. Son echec remonte ; rien n'est ecrit, et
    // l'ancienne valeur reste servie par la lecture ordinaire.
    return refresh();
  }

  return CachedReads<T>(read: read, readFresh: readFresh);
}

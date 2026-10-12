// Double en mémoire du contrat `FavoriteRepository` (S1 de T3) : mêmes
// invariants que le dépôt réel, plus de quoi provoquer chaque échec.
import 'dart:async';

import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';

final class InMemoryFavoriteRepository implements FavoriteRepository {
  InMemoryFavoriteRepository([List<Favorite> initial = const <Favorite>[]])
    : _stored = List<Favorite>.of(initial);

  List<Favorite> _stored;

  /// Posée : `readAll`, `add` et `remove` la lèvent. `clear` jamais.
  Object? readError;

  /// Posée : `add`, `remove` et `clear` la lèvent, après `writeGate`.
  Object? writeError;

  /// Posée : `add`, `remove` et `clear` attendent qu'elle aboutisse.
  Completer<void>? writeGate;

  /// Posée : `readAll` attend qu'elle aboutisse, avant de lever [readError] ou
  /// de rendre la liste. Chaque lecture compte dans [readCalls] dès son appel.
  Completer<void>? readGate;

  int readCalls = 0;
  int writeCalls = 0;

  List<Favorite> get stored => List<Favorite>.unmodifiable(_stored);

  @override
  Future<List<Favorite>> readAll() async {
    readCalls++;
    await readGate?.future;
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return List<Favorite>.unmodifiable(_stored);
  }

  @override
  Future<void> add(Favorite favorite) async {
    writeCalls++;
    if (favorite is UnreadableFavorite) {
      throw ArgumentError.value(
        favorite,
        'favorite',
        "une entrée illisible ne s'ajoute pas",
      );
    }
    final Object? read = readError;
    if (read != null) {
      throw read;
    }
    await writeGate?.future;
    final Object? write = writeError;
    if (write != null) {
      throw write;
    }
    if (_stored.any((Favorite f) => sameFavoritePlace(f, favorite))) {
      return;
    }
    _stored = <Favorite>[favorite, ..._stored];
  }

  @override
  Future<void> remove(Favorite favorite) async {
    writeCalls++;
    final Object? read = readError;
    if (read != null) {
      throw read;
    }
    await writeGate?.future;
    final Object? write = writeError;
    if (write != null) {
      throw write;
    }
    _stored = <Favorite>[
      for (final Favorite f in _stored)
        if (!sameFavoritePlace(f, favorite)) f,
    ];
  }

  @override
  Future<void> clear() async {
    writeCalls++;
    await writeGate?.future;
    final Object? write = writeError;
    if (write != null) {
      throw write;
    }
    _stored = <Favorite>[];
  }
}

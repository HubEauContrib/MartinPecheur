// Le ViewModel de l'écran « Favoris » (S8 de T3, MVVM, ADR-014) : il lit la
// liste, retire un favori, repart d'une liste vide. Même style que
// `StationSheetViewModel` — jeton de génération contre une réponse tardive,
// `_disposed` contre une notification après `dispose()`.
//
// Une liste illisible n'est jamais montrée vide (BR-007) et rien ne
// l'écrase avant l'action explicite [FavoritesViewModel.startOver]. Le
// ViewModel ne trie rien : l'ordre est celui du dépôt, dernier ajouté en tête.
//
// [FavoritesViewModel.load] ouvre l'écran et passe en lecture AVANT son
// premier `await` ; [FavoritesViewModel.close] le ferme. La racine de
// composition s'en sert pour ne pousser qu'une route : `state is! FavorisFermes`
// est sa garde.
//
// ⚠️ Un ViewModel ne connaît aucun widget : ce fichier n'importe que
// `foundation.dart`, pour [ChangeNotifier]. Aucun texte d'écran ici : ils
// sont à la vue. Le verrou est `test/architecture/layers_test.dart`.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';

/// État de l'écran « Favoris ». `sealed` + `switch` exhaustif (BR-011).
sealed class FavoritesState {
  const FavoritesState();
}

/// L'écran n'est pas ouvert.
final class FavorisFermes extends FavoritesState {
  const FavorisFermes();
}

/// La liste est en cours de lecture.
final class FavorisEnLecture extends FavoritesState {
  const FavorisEnLecture();
}

/// La liste a été lue : elle est vide.
final class AucunFavori extends FavoritesState {
  const AucunFavori();
}

/// La liste a été lue, dans l'ordre du dépôt. Jamais vide.
final class FavorisLus extends FavoritesState {
  const FavorisLus(this.favorites);

  final List<Favorite> favorites;
}

/// La liste stockée n'a pas pu être lue.
final class FavorisIllisibles extends FavoritesState {
  const FavorisIllisibles();
}

/// ViewModel de l'écran « Favoris ».
final class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel({required this._favorites});

  final FavoriteRepository _favorites;

  FavoritesState _state = const FavorisFermes();

  /// État courant de l'écran.
  FavoritesState get state => _state;

  bool _busy = false;

  /// Une écriture (retrait ou remise à zéro) court.
  bool get busy => _busy;

  bool _writeFailed = false;

  /// La dernière écriture a échoué ; l'état est resté tel quel.
  bool get writeFailed => _writeFailed;

  bool _disposed = false;

  /// Numéro de la dernière ouverture ou fermeture. Une lecture ou une écriture
  /// d'un numéro dépassé n'écrit plus rien dans l'état.
  int _generation = 0;

  /// Ouvre l'écran : passe en lecture avant tout `await`, efface l'échec
  /// d'écriture, puis lit le dépôt (relu à chaque ouverture).
  Future<void> load() async {
    if (_disposed) {
      return;
    }
    final int generation = ++_generation;
    _busy = false;
    _writeFailed = false;
    _emit(generation, const FavorisEnLecture());
    final FavoritesState read = await _read();
    _emit(generation, read);
  }

  /// Retire [favorite] puis relit le dépôt, sans repasser par la lecture.
  /// Ignoré pendant une écriture, sur un écran fermé ou en lecture. L'échec ne
  /// se lève pas : [writeFailed], état inchangé.
  Future<void> remove(Favorite favorite) =>
      _write(() => _favorites.remove(favorite));

  /// Repart d'une liste vide : `clear()` puis relecture. Mêmes garde et échec
  /// que [remove] ; en échec, l'état (typiquement [FavorisIllisibles]) reste.
  Future<void> startOver() => _write(_favorites.clear);

  /// Ferme l'écran : une lecture ou une écriture en cours n'écrit plus rien
  /// dans l'état.
  void close() {
    if (_disposed) {
      return;
    }
    final int generation = ++_generation;
    _busy = false;
    _writeFailed = false;
    _emit(generation, const FavorisFermes());
  }

  Future<void> _write(Future<void> Function() action) async {
    if (_disposed || _busy) {
      return;
    }
    switch (_state) {
      case FavorisFermes() || FavorisEnLecture():
        return;
      case AucunFavori() || FavorisLus() || FavorisIllisibles():
        break;
    }
    final int generation = _generation;
    _busy = true;
    _writeFailed = false;
    notifyListeners();

    try {
      await action();
    } on Object {
      if (_disposed || generation != _generation) {
        return;
      }
      _busy = false;
      _writeFailed = true;
      notifyListeners();
      return;
    }
    if (_disposed || generation != _generation) {
      return;
    }
    final FavoritesState read = await _read();
    if (_disposed || generation != _generation) {
      return;
    }
    _busy = false;
    _state = read;
    notifyListeners();
  }

  /// Lit le dépôt. Toute levée vaut « liste illisible ». Ne lève jamais.
  Future<FavoritesState> _read() async {
    try {
      final List<Favorite> all = await _favorites.readAll();
      if (all.isEmpty) {
        return const AucunFavori();
      }
      return FavorisLus(List<Favorite>.unmodifiable(all));
    } on Object {
      return const FavorisIllisibles();
    }
  }

  void _emit(int generation, FavoritesState next) {
    if (_disposed || generation != _generation) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

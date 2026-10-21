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
// `foundation.dart`, pour [ChangeNotifier]. Les seuls textes rendus ici sont
// les rappels de « Me prévenir », tirés du domaine ; les autres sont à la
// vue. Le verrou est `test/architecture/layers_test.dart`.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';

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
  FavoritesViewModel({
    required this._favorites,
    required this._followUps,
    required this._notices,
  });

  final FavoriteRepository _favorites;
  final FollowUpRepository _followUps;
  final NoticeRepository _notices;

  // Le suivi lu avec la liste (T5, V3) ; `null` s'il est illisible ou pas
  // encore lu : aucun rappel, les favoris restent lus.
  FollowUpBook? _book;

  // Le nombre d'avis non lus ; `null` si les avis sont illisibles ou pas encore
  // lus.
  int? _unreadNotices;

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
    final (FavoritesState read, FollowUpBook? book, int? unread) = await (
      _read(),
      _readBook(),
      _readUnread(),
    ).wait;
    if (_disposed || generation != _generation) {
      return;
    }
    _book = book;
    _unreadNotices = unread;
    _emit(generation, read);
  }

  /// Le rappel du réglage « Me prévenir » de [favorite], ou `null` : lieu non
  /// suivi, entrée illisible, ou suivi illisible.
  String? reminderOf(Favorite favorite) {
    final FollowedPlace? place = followedPlaceOf(favorite);
    final FollowUpBook? book = _book;
    if (place == null || book == null) {
      return null;
    }
    return switch (followUpOf(book.followUps, place)) {
      FloodFollowUp(:final FloodThreshold threshold) => floodFollowUpReminder(
        threshold,
      ),
      DroughtFollowUp() => droughtFollowUpReminder,
      UnreadableFollowUp() || null => null,
    };
  }

  /// Le nombre d'avis lisibles non lus ; `null` si les avis sont illisibles ou
  /// pas encore lus.
  int? get unreadNotices => _unreadNotices;

  /// Relit seulement les avis, sans repasser par [FavorisEnLecture]. Une
  /// lecture tardive (écran rouvert ou fermé entre-temps) n'écrit rien.
  Future<void> refreshUnreadNotices() async {
    if (_disposed) {
      return;
    }
    final int generation = _generation;
    final int? unread = await _readUnread();
    if (_disposed || generation != _generation) {
      return;
    }
    _unreadNotices = unread;
    notifyListeners();
  }

  /// Retire [favorite] puis éteint le suivi de son lieu (un échec de
  /// `unfollow` est ignoré : l'orphelin tombe à la vérification suivante), puis
  /// relit le dépôt, sans repasser par la lecture.
  /// Ignoré pendant une écriture, sur un écran fermé ou en lecture. L'échec ne
  /// se lève pas : [writeFailed], état inchangé.
  Future<void> remove(Favorite favorite) => _write(() async {
    await _favorites.remove(favorite);
    final FollowedPlace? place = followedPlaceOf(favorite);
    if (place == null) {
      return;
    }
    try {
      await _followUps.unfollow(place);
    } on Object {
      // Ignoré : le suivi orphelin sera retiré à la vérification suivante.
    }
  });

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
    final (FavoritesState read, FollowUpBook? book) = await (
      _read(),
      _readBook(),
    ).wait;
    if (_disposed || generation != _generation) {
      return;
    }
    _busy = false;
    _book = book;
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

  /// Lit le suivi. Toute levée vaut « suivi illisible » (`null`). Ne lève
  /// jamais.
  Future<FollowUpBook?> _readBook() async {
    try {
      return await _followUps.read();
    } on Object {
      return null;
    }
  }

  /// Compte les avis lisibles non lus ; `null` si illisibles. Ne lève jamais.
  Future<int?> _readUnread() async {
    try {
      final List<ReceivedNotice> all = await _notices.readAll();
      return all
          .whereType<ReadableNotice>()
          .where((ReadableNotice n) => !n.read)
          .length;
    } on Object {
      return null;
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

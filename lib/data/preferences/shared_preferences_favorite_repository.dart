// Le dépôt des favoris (S3 de T3), adossé à `shared_preferences` (ADR-011,
// amendement de T3) : UNE clé, UNE chaîne JSON versionnée
// (`favorites_codec.dart`), `getString` et `setString` seulement.
//
// - SANS MÉMO : chaque opération relit la valeur, la décode, la transforme,
//   l'encode et l'écrit. Rien n'est gardé entre deux opérations.
// - SÉRIALISÉ PAR INSTANCE : une opération ne commence qu'une fois la
//   précédente terminée, quelle que soit son issue. Deux lire-puis-écrire
//   croisés perdraient un favori.
// - Une valeur ILLISIBLE n'est jamais remplacée sans geste : lire, ajouter et
//   retirer lèvent ; seul `clear` l'écrase, sans la décoder.
// - ÉCRITURE COMPENSATOIRE : le paquet écrit son cache mémoire AVANT
//   d'appeler le magasin (`shared_preferences` 2.5.5,
//   `lib/src/shared_preferences_legacy.dart`, `_setValue` ; inchangé en 2.5.6,
//   relu dans le paquet installé le 2026-10-14). Après un
//   `setString` refusé, `getString` rendrait donc la valeur non écrite jusqu'à
//   la fin de la session. Sur une écriture en échec, le dépôt réécrit la
//   valeur d'avant — ce qui remet le cache —, puis lève.
import 'package:martinpecheur/data/preferences/favorites_codec.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé de stockage de la liste des favoris — nommée une seule fois ici.
const String _favoritesKey = 'favorites';

/// Dépôt des favoris adossé à `shared_preferences` (ADR-011).
final class SharedPreferencesFavoriteRepository implements FavoriteRepository {
  SharedPreferencesFavoriteRepository({
    this._preferences = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() _preferences;

  /// La fin de la dernière opération lancée, issue ignorée : ce n'est pas un
  /// mémo, elle ne porte aucune valeur.
  Future<void> _previous = Future<void>.value();

  @override
  Future<List<Favorite>> readAll() => _inTurn(
    () async => List<Favorite>.unmodifiable((await _read()).favorites),
  );

  @override
  Future<void> add(Favorite favorite) async {
    // Erreur de programmation, pas de stockage : levée avant toute lecture.
    if (favorite is UnreadableFavorite) {
      throw ArgumentError.value(
        favorite,
        'favorite',
        "une entrée illisible ne s'ajoute pas",
      );
    }

    return _inTurn(() async {
      final _Stored stored = await _read();
      if (stored.favorites.any(
        (Favorite f) => sameFavoritePlace(f, favorite),
      )) {
        return;
      }
      await _write(
        stored.preferences,
        _encode(<Favorite>[favorite, ...stored.favorites]),
        compensation: stored.raw ?? _encode(const <Favorite>[]),
      );
    });
  }

  @override
  Future<void> remove(Favorite favorite) => _inTurn(() async {
    final _Stored stored = await _read();
    if (!stored.favorites.any((Favorite f) => sameFavoritePlace(f, favorite))) {
      return;
    }
    await _write(
      stored.preferences,
      _encode(<Favorite>[
        for (final Favorite f in stored.favorites)
          if (!sameFavoritePlace(f, favorite)) f,
      ]),
      compensation: stored.raw ?? _encode(const <Favorite>[]),
    );
  });

  @override
  Future<void> clear() => _inTurn(() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw EcritureDeFavorisEnEchec('préférences inaccessibles : $error');
    }
    await _write(
      preferences,
      _encode(const <Favorite>[]),
      compensation: _rawOrNull(preferences),
    );
  });

  /// Lance [operation] une fois la précédente terminée, quelle que soit son
  /// issue.
  Future<T> _inTurn<T>(Future<T> Function() operation) {
    final Future<T> result = _previous.then((_) => operation());
    _previous = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Lit et décode la valeur stockée. Tout échec — préférences inaccessibles,
  /// valeur qui n'est pas une chaîne, valeur illisible — sort en
  /// [ListeDeFavorisIllisible].
  Future<_Stored> _read() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw ListeDeFavorisIllisible('préférences inaccessibles : $error');
    }

    final String? raw;
    try {
      raw = preferences.getString(_favoritesKey);
    } catch (error) {
      // `getString` fait un `as String?` : une valeur d'un autre type lève.
      throw ListeDeFavorisIllisible(
        "la valeur stockée n'est pas une chaîne : $error",
      );
    }

    return (
      preferences: preferences,
      raw: raw,
      favorites: decodeFavorites(raw),
    );
  }

  /// Écrit [value]. Sur un `setString` qui rend `false` ou qui lève, réécrit
  /// [compensation] si elle est connue (issue ignorée), puis lève
  /// [EcritureDeFavorisEnEchec].
  Future<void> _write(
    SharedPreferences preferences,
    String value, {
    required String? compensation,
  }) async {
    final String? failure = await _trySet(preferences, value);
    if (failure == null) {
      return;
    }
    if (compensation != null) {
      await _trySet(preferences, compensation);
    }
    throw EcritureDeFavorisEnEchec(failure);
  }
}

/// Ce qu'une lecture rend : les préférences, le texte stocké (`null` si rien
/// ne l'a jamais été) et les favoris qu'il porte.
typedef _Stored = ({
  SharedPreferences preferences,
  String? raw,
  List<Favorite> favorites,
});

/// Encode [favorites]. Un échec d'encodage (un point ONDE à coordonnée non
/// finie, que JSON ne sait pas écrire) sort en [EcritureDeFavorisEnEchec],
/// avant tout `setString`.
String _encode(List<Favorite> favorites) {
  try {
    return encodeFavorites(favorites);
  } catch (error) {
    throw EcritureDeFavorisEnEchec(
      'la liste ne peut pas être encodée : $error',
    );
  }
}

/// Le texte stocké, sans le décoder ; `null` s'il n'y en a pas ou s'il ne se
/// lit pas comme une chaîne.
String? _rawOrNull(SharedPreferences preferences) {
  try {
    return preferences.getString(_favoritesKey);
  } catch (_) {
    return null;
  }
}

/// Appelle `setString` ; rend `null` si l'écriture aboutit, sinon le
/// diagnostic de l'échec (`false` rendu, ou levée).
Future<String?> _trySet(SharedPreferences preferences, String value) async {
  try {
    return await preferences.setString(_favoritesKey, value)
        ? null
        : 'setString a rendu false';
  } catch (error) {
    return 'setString a levé : $error';
  }
}

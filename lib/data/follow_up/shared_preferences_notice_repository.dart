// Le dépôt des avis reçus (D3 de T5), adossé à `shared_preferences` (ADR-011,
// ADR-017) : UNE clé, UNE chaîne JSON versionnée (`notices_codec.dart`),
// `getString` et `setString` seulement. Même construction que le dépôt des
// suivis :
//
// - SANS MÉMO : chaque opération relit la valeur, la décode, la transforme,
//   l'encode et l'écrit. Rien n'est gardé entre deux opérations.
// - SÉRIALISÉ PAR INSTANCE : une opération ne commence qu'une fois la
//   précédente terminée, quelle que soit son issue. Deux lire-puis-écrire
//   croisés perdraient un avis.
// - Une valeur ILLISIBLE n'est jamais remplacée sans geste : lire et chaque
//   écriture lèvent ; seul `clear` l'écrase, sans la décoder.
// - ÉCRITURE COMPENSATOIRE : le paquet écrit son cache mémoire AVANT d'appeler
//   le magasin. Après un `setString` refusé, `getString` rendrait donc la
//   valeur non écrite jusqu'à la fin de la session. Sur une écriture en échec,
//   le dépôt réécrit la valeur d'avant — ce qui remet le cache —, puis lève.
// - Au plus [maxStoredNotices] avis gardés, illisibles compris.
import 'package:martinpecheur/data/follow_up/notices_codec.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé de stockage des avis — nommée une seule fois ici.
const String _noticesKey = 'notices';

/// Dépôt des avis reçus adossé à `shared_preferences`.
final class SharedPreferencesNoticeRepository implements NoticeRepository {
  SharedPreferencesNoticeRepository({
    this._preferences = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() _preferences;

  /// La fin de la dernière opération lancée, issue ignorée : ce n'est pas un
  /// mémo, elle ne porte aucune valeur.
  Future<void> _previous = Future<void>.value();

  @override
  Future<List<ReceivedNotice>> readAll() =>
      _inTurn(() async => (await _read()).notices);

  @override
  Future<void> addAll(List<ReadableNotice> notices) {
    if (notices.isEmpty) {
      return Future<void>.value();
    }

    return _inTurn(() async {
      final _Stored stored = await _read();
      final List<ReceivedNotice> next = <ReceivedNotice>[
        ...notices,
        ...stored.notices,
      ];
      await _write(
        stored,
        next.length > maxStoredNotices
            ? next.sublist(0, maxStoredNotices)
            : next,
      );
    });
  }

  @override
  Future<void> markAllRead() => _inTurn(() async {
    final _Stored stored = await _read();
    await _write(stored, <ReceivedNotice>[
      for (final ReceivedNotice notice in stored.notices)
        switch (notice) {
          ReadableNotice() => notice.asRead(),
          UnreadableNotice() => notice,
        },
    ]);
  });

  @override
  Future<void> clear() => _inTurn(() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw EcritureDAvisEnEchec('préférences inaccessibles : $error');
    }
    await _writeValue(
      preferences,
      _encode(const <ReceivedNotice>[]),
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
  /// [ListeDAvisIllisible].
  Future<_Stored> _read() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw ListeDAvisIllisible('préférences inaccessibles : $error');
    }

    final String? raw;
    try {
      raw = preferences.getString(_noticesKey);
    } catch (error) {
      // `getString` fait un `as String?` : une valeur d'un autre type lève.
      throw ListeDAvisIllisible(
        "la valeur stockée n'est pas une chaîne : $error",
      );
    }

    return (preferences: preferences, raw: raw, notices: decodeNotices(raw));
  }

  Future<void> _write(_Stored stored, List<ReceivedNotice> notices) =>
      _writeValue(
        stored.preferences,
        _encode(notices),
        compensation: stored.raw ?? _encode(const <ReceivedNotice>[]),
      );

  /// Écrit [value]. Sur un `setString` qui rend `false` ou qui lève, réécrit
  /// [compensation] si elle est connue (issue ignorée), puis lève [EcritureDAvisEnEchec].
  Future<void> _writeValue(
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
    throw EcritureDAvisEnEchec(failure);
  }
}

/// Ce qu'une lecture rend : les préférences, le texte stocké (`null` si rien
/// ne l'a jamais été) et les avis qu'il porte.
typedef _Stored = ({
  SharedPreferences preferences,
  String? raw,
  List<ReceivedNotice> notices,
});

/// Encode [notices]. Un échec d'encodage (un brut que JSON ne sait pas écrire)
/// sort en [EcritureDAvisEnEchec], avant tout `setString`.
String _encode(List<ReceivedNotice> notices) {
  try {
    return encodeNotices(notices);
  } catch (error) {
    throw EcritureDAvisEnEchec('les avis ne peuvent pas être encodés : $error');
  }
}

/// Le texte stocké, sans le décoder ; `null` s'il n'y en a pas ou s'il ne se
/// lit pas comme une chaîne.
String? _rawOrNull(SharedPreferences preferences) {
  try {
    return preferences.getString(_noticesKey);
  } catch (_) {
    return null;
  }
}

/// Appelle `setString` ; rend `null` si l'écriture aboutit, sinon le
/// diagnostic de l'échec (`false` rendu, ou levée).
Future<String?> _trySet(SharedPreferences preferences, String value) async {
  try {
    return await preferences.setString(_noticesKey, value)
        ? null
        : 'setString a rendu false';
  } catch (error) {
    return 'setString a levé : $error';
  }
}

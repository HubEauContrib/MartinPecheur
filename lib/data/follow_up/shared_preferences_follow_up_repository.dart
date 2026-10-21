// Le dépôt des suivis (D2 de T5), adossé à `shared_preferences` (ADR-011,
// ADR-017) : UNE clé, UNE chaîne JSON versionnée (`follow_up_codec.dart`),
// `getString` et `setString` seulement. Même construction que le dépôt des
// favoris :
//
// - SANS MÉMO : chaque opération relit la valeur, la décode, la transforme,
//   l'encode et l'écrit. Rien n'est gardé entre deux opérations.
// - SÉRIALISÉ PAR INSTANCE : une opération ne commence qu'une fois la
//   précédente terminée, quelle que soit son issue. Deux lire-puis-écrire
//   croisés perdraient un réglage.
// - Une valeur ILLISIBLE n'est jamais remplacée sans geste : lire et chaque
//   écriture lèvent ; seul `clear` l'écrase, sans la décoder.
// - ÉCRITURE COMPENSATOIRE : le paquet écrit son cache mémoire AVANT d'appeler
//   le magasin. Après un `setString` refusé, `getString` rendrait donc la
//   valeur non écrite jusqu'à la fin de la session. Sur une écriture en échec,
//   le dépôt réécrit la valeur d'avant — ce qui remet le cache —, puis lève.
//
// `recordCheck` REPORTE sur l'état stocké AU MOMENT DE L'ÉCRITURE : le seuil
// stocké est gardé, un lieu éteint entre-temps est ignoré, un orphelin n'est
// retiré que s'il est encore égal à sa lecture.
import 'package:martinpecheur/data/follow_up/follow_up_codec.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé de stockage des suivis — nommée une seule fois ici.
const String _followUpsKey = 'follow_ups';

/// Dépôt des suivis adossé à `shared_preferences`.
final class SharedPreferencesFollowUpRepository implements FollowUpRepository {
  SharedPreferencesFollowUpRepository({
    this._preferences = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() _preferences;

  /// La fin de la dernière opération lancée, issue ignorée : ce n'est pas un
  /// mémo, elle ne porte aucune valeur.
  Future<void> _previous = Future<void>.value();

  @override
  Future<FollowUpBook> read() => _inTurn(() async => (await _read()).book);

  @override
  Future<void> followFlood(FloodSectionPlace place, FloodThreshold threshold) =>
      _inTurn(() async {
        final _Stored stored = await _read();
        final FollowUp? existing = followUpOf(stored.book.followUps, place);
        final List<FollowUp> next;
        if (existing is FloodFollowUp) {
          next = <FollowUp>[
            for (final FollowUp f in stored.book.followUps)
              if (identical(f, existing))
                FloodFollowUp(
                  place: place,
                  threshold: threshold,
                  lastKnown: existing.lastKnown,
                  series: existing.series,
                )
              else
                f,
          ];
        } else {
          next = <FollowUp>[
            ...stored.book.followUps,
            FloodFollowUp(place: place, threshold: threshold),
          ];
        }
        await _write(stored, next, stored.book.lastCheckAt);
      });

  @override
  Future<void> followDrought(DroughtPlace place) => _inTurn(() async {
    final _Stored stored = await _read();
    if (followUpOf(stored.book.followUps, place) != null) {
      return;
    }
    await _write(stored, <FollowUp>[
      ...stored.book.followUps,
      DroughtFollowUp(place: place),
    ], stored.book.lastCheckAt);
  });

  @override
  Future<void> unfollow(FollowedPlace place) => _inTurn(() async {
    final _Stored stored = await _read();
    if (followUpOf(stored.book.followUps, place) == null) {
      return;
    }
    await _write(stored, <FollowUp>[
      for (final FollowUp f in stored.book.followUps)
        if (placeOfFollowUp(f) != place) f,
    ], stored.book.lastCheckAt);
  });

  @override
  Future<void> recordCheck(CheckRecord record) => _inTurn(() async {
    final _Stored stored = await _read();
    final List<FollowUp> next = <FollowUp>[];
    for (final FollowUp current in stored.book.followUps) {
      if (record.orphans.contains(current)) {
        continue;
      }
      final FollowedPlace? place = placeOfFollowUp(current);
      final FollowUp? update = place == null
          ? null
          : followUpOf(record.updated, place);
      next.add(switch ((current, update)) {
        (final FloodFollowUp s, final FloodFollowUp u) => FloodFollowUp(
          place: s.place,
          threshold: s.threshold,
          lastKnown: u.lastKnown,
          series: u.series,
        ),
        (final DroughtFollowUp s, final DroughtFollowUp u) => DroughtFollowUp(
          place: s.place,
          lastKnown: u.lastKnown,
          series: u.series,
        ),
        _ => current,
      });
    }
    await _write(stored, next, record.checkedAt);
  });

  @override
  Future<void> clear() => _inTurn(() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw EcritureDuSuiviEnEchec('préférences inaccessibles : $error');
    }
    await _writeValue(
      preferences,
      _encode(FollowUpBook(followUps: <FollowUp>[])),
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
  /// [SuiviIllisible].
  Future<_Stored> _read() async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (error) {
      throw SuiviIllisible('préférences inaccessibles : $error');
    }

    final String? raw;
    try {
      raw = preferences.getString(_followUpsKey);
    } catch (error) {
      // `getString` fait un `as String?` : une valeur d'un autre type lève.
      throw SuiviIllisible("la valeur stockée n'est pas une chaîne : $error");
    }

    return (preferences: preferences, raw: raw, book: decodeFollowUps(raw));
  }

  Future<void> _write(
    _Stored stored,
    List<FollowUp> followUps,
    DateTime? lastCheckAt,
  ) => _writeValue(
    stored.preferences,
    _encode(FollowUpBook(followUps: followUps, lastCheckAt: lastCheckAt)),
    compensation: stored.raw ?? _encode(FollowUpBook(followUps: <FollowUp>[])),
  );

  /// Écrit [value]. Sur un `setString` qui rend `false` ou qui lève, réécrit
  /// [compensation] si elle est connue (issue ignorée), puis lève
  /// [EcritureDuSuiviEnEchec].
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
    throw EcritureDuSuiviEnEchec(failure);
  }
}

/// Ce qu'une lecture rend : les préférences, le texte stocké (`null` si rien
/// ne l'a jamais été) et le livre qu'il porte.
typedef _Stored = ({
  SharedPreferences preferences,
  String? raw,
  FollowUpBook book,
});

/// Encode [book]. Un échec d'encodage (un brut que JSON ne sait pas écrire)
/// sort en [EcritureDuSuiviEnEchec], avant tout `setString`.
String _encode(FollowUpBook book) {
  try {
    return encodeFollowUps(book);
  } catch (error) {
    throw EcritureDuSuiviEnEchec('le suivi ne peut pas être encodé : $error');
  }
}

/// Le texte stocké, sans le décoder ; `null` s'il n'y en a pas ou s'il ne se
/// lit pas comme une chaîne.
String? _rawOrNull(SharedPreferences preferences) {
  try {
    return preferences.getString(_followUpsKey);
  } catch (_) {
    return null;
  }
}

/// Appelle `setString` ; rend `null` si l'écriture aboutit, sinon le
/// diagnostic de l'échec (`false` rendu, ou levée).
Future<String?> _trySet(SharedPreferences preferences, String value) async {
  try {
    return await preferences.setString(_followUpsKey, value)
        ? null
        : 'setString a rendu false';
  } catch (error) {
    return 'setString a levé : $error';
  }
}

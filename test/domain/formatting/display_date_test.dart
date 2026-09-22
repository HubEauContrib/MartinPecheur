// Verrouille le seul formateur de date du projet (Task H1) : un INSTANT se
// convertit par un décalage UTC injecté pour lui-même — l'heure d'été dépend
// de la date affichée, pas du jour où l'on regarde — une DATE CALENDAIRE, sans
// heure, ne se convertit JAMAIS. Le format retenu est celui de la décision 12
// (arbitrage du 2026-09-22) : « JJ/MM/AAAA à HH:MM », sans suffixe de fuseau.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';

void main() {
  group('formatLocalDateTime — instant + décalage injecté', () {
    test("l'exemple de D5 : 2026-08-27T08:00Z, +2 h (Paris en été) → "
        "27/08/2026 à 10:00", () {
      expect(
        formatLocalDateTime(
          DateTime.utc(2026, 8, 27, 8),
          offsetOf: (DateTime _) => const Duration(hours: 2),
        ),
        '27/08/2026 à 10:00',
      );
    });

    test('hiver : 2026-01-15T08:00Z, +1 h → 15/01/2026 à 09:00', () {
      expect(
        formatLocalDateTime(
          DateTime.utc(2026, 1, 15, 8),
          offsetOf: (DateTime _) => const Duration(hours: 1),
        ),
        '15/01/2026 à 09:00',
      );
    });

    test(
      'passage de minuit : 2026-08-27T23:30Z, +2 h → 28/08/2026 à 01:30',
      () {
        expect(
          formatLocalDateTime(
            DateTime.utc(2026, 8, 27, 23, 30),
            offsetOf: (DateTime _) => const Duration(hours: 2),
          ),
          '28/08/2026 à 01:30',
        );
      },
    );

    test('décalage négatif : 2026-08-27T03:00Z, −5 h → 26/08/2026 à 22:00', () {
      expect(
        formatLocalDateTime(
          DateTime.utc(2026, 8, 27, 3),
          offsetOf: (DateTime _) => const Duration(hours: -5),
        ),
        '26/08/2026 à 22:00',
      );
    });

    test("offsetOf reçoit l'instant EN UTC, même si l'appelant passe un "
        'DateTime local', () {
      DateTime? received;
      final DateTime local = DateTime.utc(2026, 8, 27, 8).toLocal();

      formatLocalDateTime(
        local,
        offsetOf: (DateTime utcInstant) {
          received = utcInstant;
          return const Duration(hours: 2);
        },
      );

      expect(received, isNotNull);
      expect(received!.isUtc, isTrue);
      expect(received, DateTime.utc(2026, 8, 27, 8));
    });

    test("aucun résultat ne contient 'UTC', ni 'h' comme séparateur d'heure — "
        'un seul format, celui de la décision 12', () {
      final String result = formatLocalDateTime(
        DateTime.utc(2026, 8, 27, 8),
        offsetOf: (DateTime _) => const Duration(hours: 2),
      );

      expect(result, isNot(contains('UTC')));
      expect(RegExp(r'\dh\d').hasMatch(result), isFalse);
      expect(result, contains(':'));
    });
  });

  group('systemUtcOffsetOf — la seule lecture du fuseau de la machine', () {
    test('rend une Duration, utilisée par défaut en production', () {
      expect(systemUtcOffsetOf(DateTime.utc(2026, 8, 27, 8)), isA<Duration>());
    });
  });

  group('formatCalendarDate — date calendaire, jamais convertie', () {
    test('2026-08-25 (UTC) → 25/08/2026', () {
      expect(formatCalendarDate(DateTime.utc(2026, 8, 25)), '25/08/2026');
    });

    // Ne détecte une lecture en composantes locales que sur un poste à
    // l'ouest de Greenwich : en UTC+2, une implémentation fautive passerait.
    test('la même date passée en local reste 25/08/2026 (lecture des '
        'composantes UTC, T-08)', () {
      final DateTime local = DateTime.utc(2026, 8, 25).toLocal();
      expect(formatCalendarDate(local), '25/08/2026');
    });
  });
}

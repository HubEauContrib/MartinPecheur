// Verrouille l'encart daté (Task W4, emplacement 3 de `04-ui.md § 5`),
// premier occupant de `lib/features/shared/` (arbitrage du commanditaire du
// 2026-09-18) : la seule tranche que `station_sheet` et `onde_sheet`
// peuvent toutes deux importer (`test/architecture/layers_test.dart`, règle
// `shared-sans-tranche`).
//
// Les phrases sont recopiées mot pour mot de `docs/use-cases/UC-003-…md § 1`
// (station) et `docs/use-cases/UC-004-…md § 1` plus `docs/04-ui.md § 1`,
// wireframe « Fiche point ONDE » (ONDE, titre « OBSERVATION VISUELLE
// PONCTUELLE ») : aucune phrase n'est inventée ici.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/sheet_warning_card.dart';

/// L'instant de mesure de l'exemple de `H1`/`D5` : `2026-08-27T08:00:00Z`,
/// `+2 h` injecté (été, Paris) → `27/08/2026 à 10:00`.
final DateTime _instant = DateTime.utc(2026, 8, 27, 8);

/// La date de campagne ONDE de l'exemple de `UC-004 § 1` :
/// `2026-08-25`, sans heure (`T-08`).
final DateTime _campagne = DateTime.utc(2026, 8, 25);

Duration _plusDeuxHeures(DateTime _) => const Duration(hours: 2);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  group('sheetWarningText — le texte FIGÉ, phrase entière', () {
    test('version station, mot pour mot (UC-003 § 1, +2 h injecté)', () {
      expect(
        sheetWarningText(
          SheetWarningKind.station,
          _instant,
          offsetOf: _plusDeuxHeures,
        ),
        'Mesure brute du 27/08/2026 à 10:00, non validée. La station ne '
        'voit pas les lâchers de barrage.',
      );
    });

    test('version ONDE, mot pour mot (UC-004 § 1, 04-ui.md § 1)', () {
      expect(
        sheetWarningText(SheetWarningKind.onde, _campagne),
        'OBSERVATION VISUELLE PONCTUELLE\n'
        "Observation du 25/08/2026, lors d'une campagne ponctuelle. Ce "
        "n'est pas une mesure de débit, et la situation a pu changer "
        'depuis.',
      );
    });
  });

  group('sheetWarningText — station (UC-003 § 1)', () {
    test('contient la date en heure locale, « brute », « non validée » et '
        '« lâchers de barrage », mot pour mot', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        _instant,
        offsetOf: _plusDeuxHeures,
      );

      expect(text, contains('27/08/2026 à 10:00'));
      expect(text, contains('brute'));
      expect(text, contains('non validée'));
      expect(text, contains('lâchers de barrage'));
    });

    test('ne contient ni « UTC » ni « 08h00 » (décision 12, H1)', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        _instant,
        offsetOf: _plusDeuxHeures,
      );

      expect(text, isNot(contains('UTC')));
      expect(text, isNot(contains('08h00')));
    });

    test("ne contient PAS « observation visuelle ponctuelle » — c'est la "
        'version ONDE qui est plus insistante', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        _instant,
        offsetOf: _plusDeuxHeures,
      );

      expect(
        text.toLowerCase(),
        isNot(contains('observation visuelle ponctuelle')),
      );
    });
  });

  group('sheetWarningText — ONDE (UC-004 § 1, 04-ui.md § 1)', () {
    test('contient la date calendaire (sans heure, H1), « campagne '
        'ponctuelle », « Ce n\'est pas une mesure de débit » et « la '
        'situation a pu changer depuis », mot pour mot', () {
      final String text = sheetWarningText(SheetWarningKind.onde, _campagne);

      expect(text, contains('25/08/2026'));
      expect(text, contains('campagne ponctuelle'));
      expect(text, contains("Ce n'est pas une mesure de débit"));
      expect(text, contains('la situation a pu changer depuis'));
    });

    test('est PLUS insistante que la version station : porte '
        '« observation visuelle ponctuelle », la station non', () {
      final String onde = sheetWarningText(SheetWarningKind.onde, _campagne);
      final String station = sheetWarningText(
        SheetWarningKind.station,
        _instant,
        offsetOf: _plusDeuxHeures,
      );

      expect(onde.toLowerCase(), contains('observation visuelle ponctuelle'));
      expect(
        station.toLowerCase(),
        isNot(contains('observation visuelle ponctuelle')),
      );
    });

    test('ne porte aucune heure : la campagne ONDE est une date calendaire '
        '(T-08)', () {
      final String text = sheetWarningText(SheetWarningKind.onde, _campagne);
      final RegExp heure = RegExp(r'\d{1,2}\s?[:h]\s?\d{2}');

      expect(heure.hasMatch(text), isFalse);
    });
  });

  group('SheetWarningCard — le rendu', () {
    testWidgets('rend le texte de la station avec sa date', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SheetWarningCard(
          kind: SheetWarningKind.station,
          dataDate: _instant,
          utcOffsetOf: _plusDeuxHeures,
        ),
      );

      expect(find.textContaining('27/08/2026 à 10:00'), findsOneWidget);
      expect(find.textContaining('lâchers de barrage'), findsOneWidget);
    });

    testWidgets('rend le texte ONDE avec sa date de campagne', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SheetWarningCard(kind: SheetWarningKind.onde, dataDate: _campagne),
      );

      expect(find.textContaining('25/08/2026'), findsOneWidget);
      expect(
        find.textContaining("Ce n'est pas une mesure de débit"),
        findsOneWidget,
      );
    });
  });
}

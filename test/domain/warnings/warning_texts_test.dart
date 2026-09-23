// Test miroir de `lib/domain/warnings/warning_texts.dart` : balaie les
// constantes sans monter aucun widget (Dart pur). Le VERROU de version, lui,
// est `test/project/warning_texts_version_test.dart` — ce fichier-ci vérifie
// le contenu (mots requis, mots bannis, absence de verbe d'instruction),
// pas la valeur figée caractère pour caractère.
//
// Le groupe `sheetWarningText` (`W4`) vivait dans le fichier de test de
// l'ancien encart daté de tête de fiche, aux côtés de son widget. `W3c`
// (arbitrage du commanditaire du 2026-09-23) retire ce widget — le TEXTE,
// lui, ne change pas — et ce fichier reprend donc ses tests de la fonction
// PURE, mot pour mot.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

/// Les cinq mots bannis pour qualifier un débit (`CLAUDE.md`, `BR-003`) —
/// recherchés avec des frontières de MOT LINGUISTIQUE (`(?<!\p{L})…(?!\p{L})`,
/// `unicode: true`) pour ne pas confondre « bon » et « abandon », ou « sûr »
/// et « sûreté ». `\b` (ASCII) laisserait passer une lettre accentuée
/// adjacente sans la traiter comme une frontière de mot.
final RegExp _bannedWords = RegExp(
  r'(?<!\p{L})(suffisant|insuffisant|normal|bon|sûr)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

/// Quelques verbes d'instruction sur un usage de l'eau, proscrits par
/// `BR-014` (« vous pouvez arroser », « baignade possible », etc.). Liste
/// non exhaustive, assez large pour attraper une régression évidente. Même
/// frontière de mot linguistique que [_bannedWords].
final RegExp _instructionVerbs = RegExp(
  r'(?<!\p{L})(arrosez|arroser|baignez|baignade possible|naviguez|'
  r'traversez|pouvez arroser|pouvez naviguer|pouvez vous baigner)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

void main() {
  group('warningTextVersion', () {
    test('n\'est pas vide', () {
      expect(warningTextVersion, isNotEmpty);
    });
  });

  group('initialWarningTitle', () {
    test('vaut exactement "Des informations, pas une autorisation" '
        '(04-ui.md, lignes 164-165)', () {
      expect(initialWarningTitle, 'Des informations, pas une autorisation');
    });

    test('ne contient aucun mot banni (BR-003)', () {
      expect(_bannedWords.hasMatch(initialWarningTitle), isFalse);
    });
  });

  group('initialWarningBody', () {
    const List<String> requiredWords = <String>[
      'indicatives',
      'partielles',
      'anciennes',
      'non validées',
      'lâchers de barrage',
      'arrêté préfectoral',
    ];

    for (final String word in requiredWords) {
      test('contient "$word" (UC-006 § 2)', () {
        expect(initialWarningBody, contains(word));
      });
    }

    test('ne contient aucun mot banni (BR-003)', () {
      expect(_bannedWords.hasMatch(initialWarningBody), isFalse);
    });

    test('ne contient aucun verbe d\'instruction sur un usage de l\'eau '
        '(BR-014)', () {
      expect(_instructionVerbs.hasMatch(initialWarningBody), isFalse);
    });

    test('n\'est pas tronqué : une phrase complète, terminée par un point', () {
      expect(initialWarningBody.trim().endsWith('.'), isTrue);
    });
  });

  group('initialWarningCheckboxLabel', () {
    test('recopie exactement le texte de UC-006 § 2, étape 4', () {
      expect(
        initialWarningCheckboxLabel,
        "J'ai lu et compris que ces données ne valent ni autorisation ni "
        'consigne de sécurité.',
      );
    });

    test('ne contient aucun mot banni (BR-003)', () {
      expect(_bannedWords.hasMatch(initialWarningCheckboxLabel), isFalse);
    });
  });

  group('initialWarningButtonLabel', () {
    test('vaut exactement "J\'ai compris ces limites" (BR-012)', () {
      expect(initialWarningButtonLabel, "J'ai compris ces limites");
    });

    test('n\'est ni "OK", ni "Continuer", ni "Fermer" (BR-012)', () {
      expect(initialWarningButtonLabel, isNot('OK'));
      expect(initialWarningButtonLabel, isNot('Continuer'));
      expect(initialWarningButtonLabel, isNot('Fermer'));
    });
  });

  group(
    'initialWarningWriteFailedText (UC-006 A6, arbitrage du 2026-09-22)',
    () {
      test('vaut exactement "Votre choix n\'a pas pu être enregistré. Vous '
          'pouvez réessayer."', () {
        expect(
          initialWarningWriteFailedText,
          "Votre choix n'a pas pu être enregistré. Vous pouvez réessayer.",
        );
      });

      test('ne contient aucun mot banni (BR-003)', () {
        expect(_bannedWords.hasMatch(initialWarningWriteFailedText), isFalse);
      });

      test('ne contient aucun verbe d\'instruction sur un usage de l\'eau '
          '(BR-014)', () {
        expect(
          _instructionVerbs.hasMatch(initialWarningWriteFailedText),
          isFalse,
        );
      });
    },
  );

  group('encart renforce (W5, BR-013, texte seul — le widget part en T2)', () {
    test('reinforcedWarningHeadline vaut exactement "NE FONDEZ AUCUNE '
        'DECISION SUR CET ECRAN" (04-ui.md § 1, l. 116-117)', () {
      expect(
        reinforcedWarningHeadline,
        'NE FONDEZ AUCUNE DÉCISION SUR CET ÉCRAN',
      );
    });

    test('reinforcedWarningActionLabel vaut exactement "Consulter les '
        'arretes en vigueur" (04-ui.md § 1, l. 129)', () {
      expect(reinforcedWarningActionLabel, 'Consulter les arrêtés en vigueur');
    });

    const List<String> requiredPhrases = <String>[
      'arrêtés préfectoraux',
      'évaluation de sécurité',
      'irrigation',
    ];

    for (final String phrase in requiredPhrases) {
      test(
        'reinforcedWarningBody contient "$phrase" (BR-013, 04-ui.md § 1)',
        () {
          expect(reinforcedWarningBody, contains(phrase));
        },
      );
    }

    test('ne contient aucun mot banni (BR-003)', () {
      expect(_bannedWords.hasMatch(reinforcedWarningHeadline), isFalse);
      expect(_bannedWords.hasMatch(reinforcedWarningBody), isFalse);
      expect(_bannedWords.hasMatch(reinforcedWarningActionLabel), isFalse);
    });

    test('ne contient aucun verbe d\'instruction sur un usage de l\'eau '
        '(BR-014)', () {
      expect(_instructionVerbs.hasMatch(reinforcedWarningBody), isFalse);
    });

    test("n'est pas tronque : une phrase complete, terminee par un point", () {
      expect(reinforcedWarningBody.trim().endsWith('.'), isTrue);
    });
  });

  group('sheetWarningText — le texte FIGÉ, phrase entière (W4)', () {
    final DateTime instant = DateTime.utc(2026, 8, 27, 8);
    final DateTime campagne = DateTime.utc(2026, 8, 25);
    Duration plusDeuxHeures(DateTime _) => const Duration(hours: 2);

    test('version station, mot pour mot (UC-003 § 1, +2 h injecté)', () {
      expect(
        sheetWarningText(
          SheetWarningKind.station,
          instant,
          offsetOf: plusDeuxHeures,
        ),
        'Mesure brute du 27/08/2026 à 10:00, non validée. La station ne '
        'voit pas les lâchers de barrage.',
      );
    });

    test('version ONDE, mot pour mot (UC-004 § 1, 04-ui.md § 1)', () {
      expect(
        sheetWarningText(SheetWarningKind.onde, campagne),
        'OBSERVATION VISUELLE PONCTUELLE\n'
        "Observation du 25/08/2026, lors d'une campagne ponctuelle. Ce "
        "n'est pas une mesure de débit, et la situation a pu changer "
        'depuis.',
      );
    });
  });

  group('sheetWarningText — station (UC-003 § 1)', () {
    final DateTime instant = DateTime.utc(2026, 8, 27, 8);
    Duration plusDeuxHeures(DateTime _) => const Duration(hours: 2);

    test('contient la date en heure locale, « brute », « non validée » et '
        '« lâchers de barrage », mot pour mot', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        instant,
        offsetOf: plusDeuxHeures,
      );

      expect(text, contains('27/08/2026 à 10:00'));
      expect(text, contains('brute'));
      expect(text, contains('non validée'));
      expect(text, contains('lâchers de barrage'));
    });

    test('ne contient ni « UTC » ni « 08h00 » (décision 12, H1)', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        instant,
        offsetOf: plusDeuxHeures,
      );

      expect(text, isNot(contains('UTC')));
      expect(text, isNot(contains('08h00')));
    });

    test("ne contient PAS « observation visuelle ponctuelle » — c'est la "
        'version ONDE qui est plus insistante', () {
      final String text = sheetWarningText(
        SheetWarningKind.station,
        instant,
        offsetOf: plusDeuxHeures,
      );

      expect(
        text.toLowerCase(),
        isNot(contains('observation visuelle ponctuelle')),
      );
    });
  });

  group('sheetWarningText — ONDE (UC-004 § 1, 04-ui.md § 1)', () {
    final DateTime instant = DateTime.utc(2026, 8, 27, 8);
    final DateTime campagne = DateTime.utc(2026, 8, 25);
    Duration plusDeuxHeures(DateTime _) => const Duration(hours: 2);

    test('contient la date calendaire (sans heure, H1), « campagne '
        'ponctuelle », « Ce n\'est pas une mesure de débit » et « la '
        'situation a pu changer depuis », mot pour mot', () {
      final String text = sheetWarningText(SheetWarningKind.onde, campagne);

      expect(text, contains('25/08/2026'));
      expect(text, contains('campagne ponctuelle'));
      expect(text, contains("Ce n'est pas une mesure de débit"));
      expect(text, contains('la situation a pu changer depuis'));
    });

    test('est PLUS insistante que la version station : porte '
        '« observation visuelle ponctuelle », la station non', () {
      final String onde = sheetWarningText(SheetWarningKind.onde, campagne);
      final String station = sheetWarningText(
        SheetWarningKind.station,
        instant,
        offsetOf: plusDeuxHeures,
      );

      expect(onde.toLowerCase(), contains('observation visuelle ponctuelle'));
      expect(
        station.toLowerCase(),
        isNot(contains('observation visuelle ponctuelle')),
      );
    });

    test('ne porte aucune heure : la campagne ONDE est une date calendaire '
        '(T-08)', () {
      final String text = sheetWarningText(SheetWarningKind.onde, campagne);
      final RegExp heure = RegExp(r'\d{1,2}\s?[:h]\s?\d{2}');

      expect(heure.hasMatch(text), isFalse);
    });
  });
}

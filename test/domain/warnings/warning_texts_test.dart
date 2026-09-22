// Test miroir de `lib/domain/warnings/warning_texts.dart` : balaie les
// constantes sans monter aucun widget (Dart pur). Le VERROU de version, lui,
// est `test/project/warning_texts_version_test.dart` — ce fichier-ci vérifie
// le contenu (mots requis, mots bannis, absence de verbe d'instruction),
// pas la valeur figée caractère pour caractère.
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
}

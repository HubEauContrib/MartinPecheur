// Test de non-régression sur la fiche F-Droid (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Les limites et les motifs sont ceux de F-Droid, relevés le 2026-11-01 :
// https://f-droid.org/docs/All_About_Descriptions_Graphics_and_Screenshots/ et
// `REGEX_CHECKS` de fdroidserver/lint.py. Le nom du dossier de langue est repris
// tel quel par fdroidserver/update.py ; `en-US` est la langue de repli, et les
// images n'y vivent qu'une fois, comme chez NewPipe.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

import 'vocabulary_lists.dart';

const String racine = 'fastlane/metadata/android';
const List<String> langues = <String>['fr', 'en-US'];

/// Le pendant anglais du vocabulaire proscrit (`BR-003`, `BR-014`) : le texte de
/// repli ne dit pas ce que la fiche française s'interdit.
const List<String> vocabulaireProscritAnglais = <String>[
  'sufficient',
  'insufficient',
  'normal',
  'good',
  'safe',
  'reliable',
  'verified',
  'official',
  'real-time',
  'real time',
  'guarantee',
  'guaranteed',
];

/// Lit un texte de la fiche, sans les fins de ligne que `core.autocrlf` ajoute
/// à l'extraction : F-Droid construit depuis le dépôt, en LF.
String lire(String langue, String fichier) =>
    File('$racine/$langue/$fichier')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

RegExp motEntier(String mot) => RegExp(
  '(?<!\\p{L})${RegExp.escape(mot)}(?!\\p{L})',
  caseSensitive: false,
  unicode: true,
);

int entierPng(List<int> b, int debut) =>
    (b[debut] << 24) |
    (b[debut + 1] << 16) |
    (b[debut + 2] << 8) |
    b[debut + 3];

bool estPng(List<int> b) =>
    b.length > 24 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;

void main() {
  for (final String langue in langues) {
    group('Fiche F-Droid, $langue', () {
      test('le titre est MartinPêcheur', () {
        expect(lire(langue, 'title.txt').trim(), 'MartinPêcheur');
      });

      test('le résumé tient en 80 caractères et passe le lint de F-Droid', () {
        final String resume = lire(langue, 'short_description.txt').trim();

        expect(resume, isNotEmpty);
        expect(resume.runes.length, lessThanOrEqualTo(80));
        expect(resume.toLowerCase(), isNot('martinpêcheur'));
        for (final RegExp motif in <RegExp>[
          RegExp(r'\b(free software|open source)\b', caseSensitive: false),
          RegExp(
            r'((your|for).*android|android.*(app|device|client|port|version))',
            caseSensitive: false,
          ),
          RegExp(r'[a-z0-9][.!?]( |$)'),
        ]) {
          expect(motif.hasMatch(resume), isFalse, reason: motif.pattern);
        }
      });

      test('la description tient en 4000 caractères, sans balise proscrite', () {
        final String description = lire(langue, 'full_description.txt');

        expect(description.trim(), isNotEmpty);
        expect(description.runes.length, lessThanOrEqualTo(4000));
        expect(
          RegExp(
            r'<(applet|base|body|button|embed|form|head|html|iframe|img|input|'
            r'link|object|picture|script|source|style|svg|video)',
            caseSensitive: false,
          ).hasMatch(description),
          isFalse,
        );
      });

      test('la description nomme les sources et le fond de carte', () {
        final String description = lire(langue, 'full_description.txt');

        for (final String source in <String>[
          "Hub'Eau",
          'VigiEau',
          floodSourceName,
          ignAttribution,
          '$floodAttribution — Licence Ouverte',
        ]) {
          expect(description, contains(source));
        }
      });
    });
  }

  test(
    'les dossiers de la fiche sont exactement les langues vérifiées ici',
    () {
      final List<String> dossiers =
          Directory(racine)
              .listSync()
              .whereType<Directory>()
              .map(
                (Directory d) =>
                    d.uri.pathSegments.lastWhere((String s) => s.isNotEmpty),
              )
              .toList()
            ..sort();

      expect(dossiers, <String>[...langues]..sort());
    },
  );

  group('Fiche F-Droid, vocabulaire', () {
    test('les deux fiches disent que la vigilance crues n est pas une alerte '
        '(BR-015)', () {
      expect(
        lire('fr', 'full_description.txt'),
        contains("Ce n'est pas un système d'alerte."),
      );
      expect(
        lire('en-US', 'full_description.txt'),
        contains('It is not an alert system.'),
      );
    });

    test('la fiche française porte l avertissement du premier lancement, '
        'mot pour mot', () {
      final String description = lire('fr', 'full_description.txt');

      expect(description, contains(initialWarningTitle));
      expect(description, contains(initialWarningBody));
    });

    test('la fiche de repli dit la même limite, et que l interface est en '
        'français', () {
      final String description = lire('en-US', 'full_description.txt');

      expect(description, contains('never replace'));
      expect(description, contains('in French'));
    });

    test('la fiche française n emploie aucun mot proscrit', () {
      final String texte =
          '${lire('fr', 'short_description.txt')}\n'
          '${lire('fr', 'full_description.txt')}';

      for (final String mot in <String>[
        ...forbiddenFlowWords,
        ...forbiddenNeutralityPhrases,
        ...forbiddenGuaranteeWords,
      ]) {
        expect(motEntier(mot).hasMatch(texte), isFalse, reason: mot);
      }
    });

    test('la fiche de repli n emploie aucun de leurs pendants anglais', () {
      final String texte =
          '${lire('en-US', 'short_description.txt')}\n'
          '${lire('en-US', 'full_description.txt')}';

      for (final String mot in vocabulaireProscritAnglais) {
        expect(motEntier(mot).hasMatch(texte), isFalse, reason: mot);
      }
    });
  });

  group('Fiche F-Droid, images', () {
    test('l icône est un PNG de 512 × 512', () {
      final List<int> icone = File('$racine/en-US/images/icon.png')
          .readAsBytesSync();

      expect(estPng(icone), isTrue);
      expect(entierPng(icone, 16), 512);
      expect(entierPng(icone, 20), 512);
    });

    test('les captures sont des PNG numérotés à partir de 1', () {
      final List<String> noms =
          Directory('$racine/en-US/images/phoneScreenshots')
              .listSync()
              .whereType<File>()
              .map((File f) => f.uri.pathSegments.last)
              .toList()
            ..sort();

      expect(noms, isNotEmpty);
      expect(noms, <String>[for (int i = 1; i <= noms.length; i++) '$i.png']);
      for (final String nom in noms) {
        expect(
          estPng(
            File('$racine/en-US/images/phoneScreenshots/$nom')
                .readAsBytesSync(),
          ),
          isTrue,
          reason: nom,
        );
      }
    });

    test('aucune image n est dupliquée sous fr : en-US sert de repli', () {
      expect(Directory('$racine/fr/images').existsSync(), isFalse);
    });
  });
}

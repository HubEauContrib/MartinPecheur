// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// Une version annoncée d'un côté (pubspec.yaml) et absente de l'autre
// (CHANGELOG.md), c'est une release dont on ne sait pas ce qu'elle contient.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la version du pubspec est annoncee dans le CHANGELOG, au format Keep a '
      'Changelog', () {
    final String contenuPubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? correspondance = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(contenuPubspec);
    expect(
      correspondance,
      isNotNull,
      reason: 'pubspec.yaml doit declarer une version X.Y.Z',
    );
    final String version = correspondance!.group(1)!;

    final String contenuChangelog = File('CHANGELOG.md').readAsStringSync();

    expect(contenuChangelog, contains('## [$version]'));
    expect(contenuChangelog, contains('## [Non publié]'));
    expect(contenuChangelog, contains('keepachangelog.com'));
  });

  test(
    'la version 0.1.0 est datee : une version sans date n est pas publiee',
    () {
      final String contenuChangelog = File('CHANGELOG.md').readAsStringSync();
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.1.0]'))
          .firstOrNull;
      expect(ligne, isNotNull);
      expect(ligne, matches(RegExp(r'^## \[0\.1\.0\] — \d{4}-\d{2}-\d{2}$')));
      expect(ligne, isNot(contains('à publier')));
    },
  );

  group('version 0.2.0 (Task X4 du plan T1)', () {
    late String contenuChangelog;

    setUpAll(() {
      contenuChangelog = File('CHANGELOG.md').readAsStringSync();
    });

    // Le texte de la section `## [0.2.0]`, jusqu'a la section suivante.
    String section020() {
      final int debut = contenuChangelog.indexOf('## [0.2.0]');
      expect(debut, isNot(-1), reason: 'aucune section ## [0.2.0]');
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      return contenuChangelog.substring(
        debut,
        suivante == -1 ? contenuChangelog.length : suivante,
      );
    }

    test('pubspec.yaml porte version: 0.2.0+2', () {
      final String contenuPubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(
          r'^version:\s*0\.2\.0\+2\s*$',
          multiLine: true,
        ).hasMatch(contenuPubspec),
        isTrue,
        reason:
            'un tag et un journal qui divergent laissent personne savoir ce '
            'que contient le binaire installe',
      );
    });

    // Task P2 du plan T1 : la porte P1 passee, la version se date.
    test('la version 0.2.0 est datee : une version sans date n est pas '
        'publiee', () {
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.2.0]'))
          .firstOrNull;
      expect(ligne, isNotNull);
      expect(ligne, matches(RegExp(r'^## \[0\.2\.0\] — \d{4}-\d{2}-\d{2}$')));
      expect(ligne, isNot(contains('à publier')));
    });

    test('le CHANGELOG porte une section ## [0.2.0], et une seule', () {
      final int occurrences = RegExp(
        r'^## \[0\.2\.0\]',
        multiLine: true,
      ).allMatches(contenuChangelog).length;
      expect(occurrences, 1);
    });

    test('la section 0.2.0 porte une sous-section Non verifie non vide, qui '
        'nomme les Q- ouvertes, iOS, l etat reel d Android et BR-013', () {
      final String section = section020();
      final int debut = section.indexOf('### Non vérifié');
      expect(debut, isNot(-1), reason: 'aucune sous-section ### Non vérifié');
      final int suivante = section.indexOf('\n### ', debut + 1);
      final String nonVerifie = section.substring(
        debut,
        suivante == -1 ? section.length : suivante,
      );

      expect(
        nonVerifie.split('\n').where((String l) => l.startsWith('- ')),
        isNotEmpty,
        reason: 'une section Non verifie vide ferait croire a un produit fini',
      );
      expect(nonVerifie, contains('Q-0'));
      expect(nonVerifie, contains('iOS'));
      expect(nonVerifie, contains('Android'));
      expect(
        nonVerifie,
        contains('2026-09-18'),
        reason: 'l etat d Android se date : reactive le 2026-09-18',
      );
      expect(nonVerifie, contains('BR-013'));
    });
  });
}

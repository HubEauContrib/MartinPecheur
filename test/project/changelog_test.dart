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

  // Task X4 du plan T2 : la version 0.3.0 est OUVERTE, pas publiee. Le test
  // de datation de la tache P3 (« ## [0.3.0] » datee, sans « a publier »)
  // inversera le deuxieme cas de ce groupe, celui qui exige « a publier ».
  group('version 0.3.0 (Task X4 du plan T2)', () {
    late String contenuChangelog;

    setUpAll(() {
      contenuChangelog = File('CHANGELOG.md').readAsStringSync();
    });

    // Le texte de la section `## [0.3.0]`, jusqu'a la section suivante.
    String section030() {
      final int debut = contenuChangelog.indexOf('## [0.3.0]');
      expect(debut, isNot(-1), reason: 'aucune section ## [0.3.0]');
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      return contenuChangelog.substring(
        debut,
        suivante == -1 ? contenuChangelog.length : suivante,
      );
    }

    // Le texte d'une sous-section `### <titre>` de la section 0.3.0.
    String sousSection(String titre) {
      final String section = section030();
      final int debut = section.indexOf('### $titre');
      expect(debut, isNot(-1), reason: 'aucune sous-section ### $titre');
      final int suivante = section.indexOf('\n### ', debut + 1);
      return section.substring(
        debut,
        suivante == -1 ? section.length : suivante,
      );
    }

    Iterable<String> puces(String texte) =>
        texte.split('\n').where((String l) => l.startsWith('- '));

    test('pubspec.yaml porte version: 0.3.0+3', () {
      final String contenuPubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(
          r'^version:\s*0\.3\.0\+3\s*$',
          multiLine: true,
        ).hasMatch(contenuPubspec),
        isTrue,
        reason:
            'un tag et un journal qui divergent laissent personne savoir ce '
            'que contient le binaire installe',
      );
    });

    test('la version 0.3.0 est ouverte, pas datee : la porte de T2 n est pas '
        'passee', () {
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.3.0]'))
          .firstOrNull;
      expect(ligne, isNotNull);
      expect(ligne, equals('## [0.3.0] — à publier'));
    });

    test('le CHANGELOG porte une section ## [0.3.0], une seule, au-dessus de '
        '[0.2.0]', () {
      final int occurrences = RegExp(
        r'^## \[0\.3\.0\]',
        multiLine: true,
      ).allMatches(contenuChangelog).length;
      expect(occurrences, 1);
      expect(
        contenuChangelog.indexOf('## [0.3.0]'),
        lessThan(contenuChangelog.indexOf('## [0.2.0]')),
        reason: 'la plus recente en haut (Keep a Changelog)',
      );
      expect(
        contenuChangelog.indexOf('## [Non publié]'),
        lessThan(contenuChangelog.indexOf('## [0.3.0]')),
      );
    });

    test('la sous-section Ajoute nomme ce que T2 livre : restrictions au point '
        'designe, encart renforce, ecran des sources et son lien, choix '
        'Restrictions, designation, arrete ouvert hors de l application', () {
      final String ajoute = sousSection('Ajouté');
      expect(puces(ajoute), isNotEmpty);
      expect(ajoute, contains('Sécheresse et restrictions'));
      expect(ajoute, contains('BR-013'));
      expect(ajoute, contains("D'où vient cette donnée ?"));
      expect(ajoute, contains('Relire le détail des sources'));
      expect(ajoute, contains('« Restrictions »'));
      expect(ajoute, contains('appui long'));
      expect(ajoute, contains('clic droit'));
      expect(ajoute, contains("hors de l'application"));
    });

    test('le chapeau de 0.3.0 dit qu elle est ouverte, qu aucune construction '
        'Android n est consignee ni constatee et qu aucun ecran de T2 n est '
        'constate', () {
      final String section = section030();
      final String chapeau = section.substring(0, section.indexOf('\n### '));
      expect(chapeau, contains('Version ouverte, pas'));
      expect(
        chapeau.replaceAll(RegExp(r'\s+'), ' '),
        contains("aucune construction Android n'est consignée ni constatée"),
      );
      expect(
        chapeau.replaceAll(RegExp(r'\s+'), ' '),
        contains("aucun écran de T2 n'est constaté"),
      );
    });

    test('la section 0.3.0 porte une sous-section Non verifie non vide, qui '
        'dit ce que personne n a vu, ce qui n a pas ete construit et ce qui '
        'n est pas etabli', () {
      final String nonVerifie = sousSection('Non vérifié');

      expect(
        puces(nonVerifie),
        isNotEmpty,
        reason: 'une section Non verifie vide ferait croire a un produit fini',
      );
      // Aucun ecran de T2 n'est constate, une seule exception, datee. La
      // negation est exigee : une puce « tous les ecrans sont constates »
      // contiendrait encore le mot « constate ».
      expect(nonVerifie, contains("Aucun écran de T2 n'est constaté"));
      expect(nonVerifie, isNot(contains('Tous les écrans')));
      expect(
        nonVerifie,
        contains('2026-09-29'),
        reason: 'le seul constat d ecran de T2 : la molette, le 2026-09-29',
      );
      // Rien n'est construit, et la trace d'Android est dite, pas supposee.
      expect(nonVerifie, contains('Windows'));
      expect(nonVerifie, contains('Android'));
      expect(
        nonVerifie,
        contains("aucune construction n'est consignée ni constatée"),
      );
      expect(nonVerifie, contains('APK de débogage'));
      expect(nonVerifie, contains('2026-09-27'));
      expect(nonVerifie, contains('iOS'));
      // Les mesures aux largeurs de telephone : police de test, pas Segoe UI.
      expect(nonVerifie, contains('Roboto'));
      expect(nonVerifie, contains('Segoe UI'));
      // Lien, lecteur d'ecran, licences, percentiles, echelle sur la carte.
      expect(nonVerifie, contains("lecteur d'écran"));
      expect(nonVerifie, contains('licence'));
      expect(nonVerifie, contains('percentile'));
      expect(nonVerifie, contains('échelle'));
      // La publication Android reste differee.
      expect(nonVerifie, contains('publication'));
    });

    test('les affirmations de 0.2.0 restent : version close, datee, et son '
        'Non verifie n est pas efface par l ouverture de 0.3.0', () {
      final int debut = contenuChangelog.indexOf('## [0.2.0] — 2026-09-27');
      expect(debut, isNot(-1));
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      expect(suivante, isNot(-1), reason: 'la section 0.1.0 suit la 0.2.0');
      expect(
        contenuChangelog.substring(debut, suivante),
        contains('### Non vérifié'),
        reason:
            'borne a la section 0.2.0 : sans cela, le Non verifie de 0.1.0 '
            'suffirait',
      );
    });
  });
}

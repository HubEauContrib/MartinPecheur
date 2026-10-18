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

  // Tasks X4 puis P3 du plan T2. X4 a ouvert la version 0.3.0 ; P3 la date,
  // le 2026-10-09, SANS que la porte de T2 soit franchie (decision du
  // commanditaire du meme jour) : les constats de P1 et de P2 n'existent pas,
  // et le journal doit le dire plutot que le laisser croire.
  group('version 0.3.0 (Tasks X4 et P3 du plan T2)', () {
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

    // Task P3 du plan T2 : la version se date. La date est epinglee : le
    // chapeau la redit, et les deux doivent nommer le meme jour.
    test('la version 0.3.0 est datee du 2026-10-09, sans « a publier »', () {
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.3.0]'))
          .firstOrNull;
      expect(ligne, isNotNull);
      expect(ligne, equals('## [0.3.0] — 2026-10-09'));
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

    test('le chapeau de 0.3.0 dit qu elle est datee sans que la porte de T2 '
        'soit franchie, par decision du commanditaire, qu elle n est pas '
        'publiee, qu aucune construction Android n est consignee ni constatee '
        'et que les ecrans de T2 ne sont constates qu en partie, en debogage '
        'sur Windows', () {
      final String section = section030();
      final String chapeau = section.substring(0, section.indexOf('\n### '));
      final String chapeauNormalise = chapeau.replaceAll(RegExp(r'\s+'), ' ');
      expect(chapeauNormalise, isNot(contains('Version ouverte')));
      // Une date ne vaut pas une porte : le chapeau dit que la version est
      // datee sans elle, qui l'a decide et quand. La phrase est exigee
      // entiere : « decision du commanditaire » et « 2026-10-09 » existent
      // ailleurs dans le chapeau (mise en production, ligne de titre) et ne
      // prouveraient rien, pris seuls.
      expect(
        chapeauNormalise,
        contains(
          'Version datée le 2026-10-09 sans que la porte de T2 soit '
          'franchie**, par décision du commanditaire du même jour',
        ),
      );
      // Datee n'est pas publiee, et la porte reste due.
      expect(chapeauNormalise, contains('pas publiée'));
      expect(chapeauNormalise, contains('reste due'));
      expect(chapeauNormalise, isNot(contains('porte de T2 est franchie')));
      expect(
        chapeauNormalise,
        contains("aucune construction Android n'est consignée ni constatée"),
      );
      expect(chapeauNormalise, contains("ne sont constatés qu'en partie"));
      expect(chapeauNormalise, contains('en débogage sur Windows'));
      expect(chapeauNormalise, contains('2026-10-04'));
      // Un executable de debogage de 0.3.0 existe (constat du 2026-10-04) :
      // c'est l'executable de release qui n'est pas construit.
      expect(chapeauNormalise, contains('aucun exécutable de release'));
      expect(
        chapeauNormalise,
        isNot(
          matches(
            RegExp(
              r"aucun écran de T2 n'(est|a été) constaté",
              caseSensitive: false,
            ),
          ),
        ),
        reason: 'le constat partiel du 2026-10-04 a rendu cette phrase fausse',
      );
    });

    // Task P3 : ce que le commanditaire a VU, et rien d'autre. La porte
    // n'etant pas franchie, la sous-section ne porte que les quatre constats
    // du 2026-10-04 (debogage, Windows) et celui de la molette du 2026-09-29 ;
    // son chapeau dit sur quel code, qu'aucun n'est fait sur l'executable de
    // release ni sur Android, et que ce n'est pas le constat d'une porte.
    // Le nombre de puces et leurs dates sont epingles expres : ce cas se
    // reecrit le jour ou la porte apporte ses constats.
    test('la sous-section Constate a l execution de 0.3.0 ne porte que les '
        'quatre constats du 2026-10-04, en debogage sur Windows, et celui de '
        'la molette du 2026-09-29, et dit qu aucun n est fait sur l '
        'executable de release ni sur Android', () {
      final String section = section030();
      final String constate = sousSection("Constaté à l'exécution");
      final List<String> morceaux = constate
          .split('\n- ')
          .map((String p) => p.replaceAll(RegExp(r'\s+'), ' '))
          .toList();
      final String chapeau = morceaux.first;
      final List<String> constats = morceaux.skip(1).toList();

      expect(
        section.indexOf("### Constaté à l'exécution"),
        lessThan(section.indexOf('### Non vérifié')),
        reason: 'meme ordre que 0.2.0 et 0.1.0',
      );

      // Le chapeau : dans quelles conditions, et sur quel code.
      expect(chapeau, contains('en débogage'));
      expect(chapeau, contains('flutter run -d windows'));
      expect(chapeau, contains('ba5d079'));
      // Le constat de la molette est anterieur : un autre code, et son mode
      // de lancement n'est ecrit nulle part. Il ne se range pas sous les
      // conditions du 2026-10-04.
      expect(chapeau, contains('bc81efe'));
      expect(chapeau, contains('mode de lancement non consigné'));
      expect(
        chapeau,
        contains(
          "Aucun de ces constats n'est fait sur l'exécutable de release ni "
          'sur Android',
        ),
      );
      // Le code a change depuis, et personne n'a rien revu a l'ecran.
      expect(chapeau, contains('le code a changé depuis'));
      expect(chapeau, contains("aucun constat d'écran n'est rapporté depuis"));
      expect(chapeau, contains("Ce n'est pas le constat d'une porte"));

      // Les puces : cinq, chacune datee, aucune qui viendrait d'une
      // construction de release ou d'Android.
      expect(constats, hasLength(5));
      for (final String constat in constats) {
        expect(constat, matches(RegExp(r'^Le 2026-(10-04|09-29)')));
        expect(constat, isNot(contains('release')));
        expect(constat, isNot(contains('Android')));
        expect(constat, isNot(contains('mulateur')));
      }
      expect(
        constats.where((String c) => c.startsWith('Le 2026-09-29')),
        hasLength(1),
        reason: 'le defilement a la molette, constate le 2026-09-29',
      );
      // Les quatre non-constates du 2026-10-04 n'y sont pas ranges parmi ce
      // qui a ete vu. (« profil » attraperait aussi « --profile » : voulu
      // tant qu'aucune mesure de fluidite n'est refaite pour 0.3.0.)
      for (final String constat in constats) {
        expect(constat, isNot(contains('point en mer')));
        expect(constat, isNot(contains('non repliable')));
        expect(constat, isNot(contains('profil')));
        expect(constat, isNot(contains('au retour')));
      }
    });

    test('le Non verifie de 0.3.0 s ouvre sur la porte de T2 non franchie et '
        'nomme ce qui reste du : A1, E4, P1, P2', () {
      final String pucePorte = sousSection('Non vérifié')
          .split('\n- ')
          .skip(1)
          .map((String p) => p.replaceAll(RegExp(r'\s+'), ' '))
          .first;
      expect(
        pucePorte,
        contains("La porte de T2 n'est pas franchie"),
        reason: 'la puce de la porte ouvre la sous-section',
      );
      expect(pucePorte, contains('2026-10-09'));
      expect(pucePorte, contains('`A1`'));
      expect(pucePorte, contains('`E4`'));
      expect(pucePorte, contains('`P1`'));
      expect(pucePorte, contains('`P2`'));
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
      // Les ecrans de T2 ne sont constates qu'en partie : en debogage, sur
      // Windows, le 2026-10-04. Ce qui manque est nomme, et rien n'est
      // constate sur l'executable de release. Les negations sont exigees :
      // une puce « tous les ecrans sont constates » contiendrait encore le
      // mot « constate ».
      // La puce du constat partiel, seule : « --profile », « un point en
      // mer », « au retour » et « 2026-10-04 » existent aussi dans d'autres
      // puces, et ne prouveraient rien sur le texte de celle-ci.
      final String puceConstat = nonVerifie
          .split('\n- ')
          .map((String p) => p.replaceAll(RegExp(r'\s+'), ' '))
          .firstWhere(
            (String p) => p.contains("ne sont constatés qu'en partie"),
            orElse: () => '',
          );
      expect(puceConstat, isNotEmpty);
      final int debutManque = puceConstat.indexOf('**Non constaté**');
      expect(debutManque, isNot(-1));
      final String vu = puceConstat.substring(0, debutManque);
      final String manque = puceConstat.substring(debutManque);
      expect(vu, contains('en débogage'));
      expect(vu, contains('2026-10-04'));
      // Ce qui manque est dit manquant, pas range parmi ce qui a ete vu.
      expect(manque, contains('profil'));
      expect(manque, contains('point en mer'));
      expect(manque, contains('non repliable'));
      expect(manque, contains('au retour'));
      expect(
        manque,
        contains("Rien n'est constaté sur l'exécutable de release"),
      );
      expect(
        nonVerifie.replaceAll(RegExp(r'\s+'), ' '),
        isNot(
          matches(
            RegExp(
              r"aucun écran de T2 n'(est|a été) constaté",
              caseSensitive: false,
            ),
          ),
        ),
      );
      expect(nonVerifie, isNot(contains('Tous les écrans')));
      // Ce qui a ete vu a quitte cette sous-section pour « Constate a
      // l'execution » (Task P3) : elle y renvoie, sans le redire.
      expect(vu, contains("« Constaté à l'exécution »"));
      expect(vu, isNot(contains('trois puces')));
      // Aucune construction de release, et la trace d'Android est dite, pas
      // supposee : un executable de debogage a ete lance le 2026-10-04.
      expect(
        nonVerifie.replaceAll(RegExp(r'\s+'), ' '),
        contains('Aucune construction Windows de release'),
      );
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

  // Task O1 du plan T3 ouvre la version 0.4.0 ; X3 ecrit sa sous-section
  // « Ajoute » en une fois, d'apres le code livre ; P3 la date, le
  // 2026-10-14, la porte de T3 etant constatee EN BLOC par le commanditaire
  // sur les deux cibles (P1 : Windows, release ; P2 : Android, emulateur) :
  // ses constats sont recopies, et ce qu'il n'a pas dit reste ecrit comme non
  // dit. Trois cas d'O1 sont modifies par P3 : le 2 (ouverte -> datee), le 4
  // (le chapeau ne dit plus « Version ouverte ») et le 5 (« Non verifie »
  // reduit a « non vide » : ses affirmations « rien n'est constate » ne sont
  // plus vraies).
  group('version 0.4.0 (Tasks O1, X3 et P3 du plan T3)', () {
    late String contenuChangelog;

    setUpAll(() {
      contenuChangelog = File('CHANGELOG.md').readAsStringSync();
    });

    // Le texte de la section `## [0.4.0]`, jusqu'a la section suivante.
    String section040() {
      final int debut = contenuChangelog.indexOf('## [0.4.0]');
      expect(debut, isNot(-1), reason: 'aucune section ## [0.4.0]');
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      return contenuChangelog.substring(
        debut,
        suivante == -1 ? contenuChangelog.length : suivante,
      );
    }

    // Le texte d'une sous-section `### <titre>` de la section 0.4.0.
    String sousSection(String titre) {
      final String section = section040();
      final int debut = section.indexOf('### $titre');
      expect(debut, isNot(-1), reason: 'aucune sous-section ### $titre');
      final int suivante = section.indexOf('\n### ', debut + 1);
      return section.substring(
        debut,
        suivante == -1 ? section.length : suivante,
      );
    }

    // Task P3 : la porte de T3 constatee, la version se date. Une version
    // sans date n'est pas close ; la date est celle du jour de P3.
    test(
      'la version 0.4.0 est datée : une version sans date n\'est pas close',
      () {
        final String? ligne = contenuChangelog
            .split('\n')
            .map((String l) => l.trimRight())
            .where((String l) => l.startsWith('## [0.4.0]'))
            .firstOrNull;
        expect(ligne, isNotNull);
        expect(ligne, matches(RegExp(r'^## \[0\.4\.0\] — \d{4}-\d{2}-\d{2}$')));
        expect(ligne, isNot(contains('à publier')));
      },
    );

    test('une section ## [0.4.0], une seule, sous [Non publié] et au-dessus '
        'de [0.3.0]', () {
      final int occurrences = RegExp(
        r'^## \[0\.4\.0\]',
        multiLine: true,
      ).allMatches(contenuChangelog).length;
      expect(occurrences, 1);
      final int nonPublie = contenuChangelog.indexOf('## [Non publié]');
      final int v040 = contenuChangelog.indexOf('## [0.4.0]');
      final int v030 = contenuChangelog.indexOf('## [0.3.0]');
      expect(nonPublie, lessThan(v040));
      expect(v040, lessThan(v030));
    });

    // Task P3 : le chapeau ne dit plus que la version est ouverte. Il dit la
    // porte de T3 (franchie, sur quelles cibles, et que c'est en bloc), que
    // la date ne vaut pas mise en production, et que la porte de T2 reste
    // due : les phrases sont exigees entieres, « Windows » et « Android »
    // existant aussi ailleurs dans le chapeau.
    test('le chapeau de 0.4.0 ne dit plus qu\'elle est ouverte ; il dit la '
        'porte de T3 franchie sur Windows et sur Android, en bloc, et que la '
        'porte de T2 reste due', () {
      final String section = section040();
      final int finTitre = section.indexOf('\n');
      final int premiereSousSection = section.indexOf('\n### ');
      expect(premiereSousSection, isNot(-1));
      final String chapeau = section
          .substring(finTitre, premiereSousSection)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(chapeau, isNot(contains('Version ouverte')));
      expect(chapeau, isNot(contains('pas publiée')));
      expect(chapeau, isNot(contains("La porte de T3 n'est pas franchie")));
      expect(
        chapeau,
        contains(
          'La porte de T3 est franchie sur les deux cibles, Windows (exécutable '
          'de release lancé hors Flutter) et Android (émulateur, en débogage), '
          'constats confirmés en bloc par le commanditaire',
        ),
      );
      // Datee n'est pas mise en production, et aucun tag n'est pose.
      expect(chapeau, contains('Aucun tag'));
      expect(chapeau, contains('mise en production'));
      expect(chapeau, contains('la porte de T2 reste due'));
    });

    test('le Non vérifié de 0.4.0 n\'est pas vide', () {
      final String nonVerifie = sousSection('Non vérifié');
      expect(
        nonVerifie.split('\n').where((String l) => l.startsWith('- ')),
        isNotEmpty,
        reason: 'une section Non verifie vide ferait croire a un produit fini',
      );
    });

    // Task P3 : la confirmation du commanditaire etant EN BLOC, ce qu'elle ne
    // couvre pas est nomme, pas passe sous silence. Chaque identifiant est
    // exige dans sa forme de code : un constat « non dit » qui disparait du
    // journal devient un constat fait.
    test('le Non vérifié de 0.4.0 nomme ce que la confirmation en bloc ne '
        'couvre pas : P1-m, P2-g, P2-m, Segoe UI, lecteur d\'écran, porte de '
        'T2', () {
      final String nonVerifie = sousSection('Non vérifié')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(nonVerifie, contains('`P1-m`'));
      expect(nonVerifie, contains('`P2-g`'));
      expect(nonVerifie, contains('`P2-m`'));
      expect(nonVerifie, contains('Segoe UI'));
      expect(nonVerifie, contains("lecteur d'écran"));
      expect(nonVerifie, contains("La porte de T2 n'est pas franchie"));
      expect(nonVerifie, contains('`A1`'));
      expect(nonVerifie, contains('iOS'));
      expect(nonVerifie, contains('`A⏸3`'));
      // Plus aucune phrase qui nierait ce que la porte a constate.
      expect(
        nonVerifie,
        isNot(contains("Aucun écran de T3 n'est constaté")),
        reason: 'la porte de T3 a ete constatee en bloc le 2026-10-14',
      );
    });

    // Task P3 : « Constate a l'execution » existe, avant « Non verifie », et
    // porte une puce par constat RAPPORTE, chacune datee et nommant sa cible.
    // Le nombre de puces est epingle expres : ce cas se reecrit le jour ou un
    // constat s'ajoute.
    test('la sous-section Constaté à l\'exécution précède Non vérifié', () {
      final String section = section040();
      final int constate = section.indexOf("### Constaté à l'exécution");
      expect(constate, isNot(-1), reason: 'aucune sous-section Constaté');
      expect(constate, lessThan(section.indexOf('### Non vérifié')));
      expect(
        constate,
        greaterThan(section.indexOf('### Corrigé')),
        reason: 'meme ordre que 0.2.0 et 0.3.0 : apres Corrigé',
      );
    });

    test('Constaté à l\'exécution porte une puce par constat rapporté, datée '
        'et nommant sa cible : C1, P2, P1 et le poids de l\'exécutable', () {
      final String constate = sousSection("Constaté à l'exécution");
      final List<String> morceaux = constate
          .split('\n- ')
          .map((String p) => p.replaceAll(RegExp(r'\s+'), ' '))
          .toList();
      final String chapeau = morceaux.first;
      final List<String> constats = morceaux.skip(1).toList();

      // Le chapeau de la sous-section : en bloc, et ce que ca veut dire.
      expect(chapeau, contains('en bloc'));
      expect(chapeau, contains('point par point'));

      expect(constats, hasLength(4));
      for (final String constat in constats) {
        expect(constat, startsWith('Le 2026-10-14, '));
        expect(
          constat.contains('Windows') || constat.contains('Android'),
          isTrue,
          reason: 'chaque constat nomme sa cible : $constat',
        );
      }

      final String c1 = constats.singleWhere((String c) => c.contains('`C1`'));
      expect(c1, contains('Windows'));
      expect(c1, contains('en débogage'));
      expect(c1, contains('en bloc'));
      expect(c1, contains("« j'ai testé c'est bon »"));

      final String p2 = constats.singleWhere((String c) => c.contains('`P2`'));
      expect(p2, contains('Android'));
      expect(p2, contains('émulateur'));
      expect(p2, contains('en débogage'));
      expect(p2, contains('en bloc'));
      expect(p2, contains('les écrans de T3 fonctionnent au toucher'));

      final String p1 = constats.singleWhere((String c) => c.contains('`P1`'));
      expect(p1, contains('Windows'));
      expect(p1, contains('release'));
      expect(p1, contains('hors Flutter'));
      expect(p1, contains('en bloc'));
      expect(p1, contains('« c\'est bon »'));

      final String poids = constats.singleWhere(
        (String c) => c.contains('35 Mo'),
      );
      expect(poids, contains('Windows'));
      expect(poids, contains('release'));
      expect(poids, contains('15 fichiers'));
      expect(poids, contains('`NFR-06`'));

      // Rien de release sur Android, ni d'emulateur sur Windows : une cible
      // ne se melange pas a une autre.
      expect(c1, isNot(contains('release')));
      expect(c1, isNot(contains('Android')));
      expect(p2, isNot(contains('release')));
      expect(p2, isNot(contains('Windows')));
    });

    // Task X3 du plan T3 : « Ajoute » s'ecrit en une fois, a la fin de la
    // tranche, d'apres ce qui est livre. Les libelles sont ceux de l'ecran ;
    // les blancs sont normalises, un libelle pouvant passer a la ligne.
    test('la sous-section Ajouté nomme ce que T3 livre', () {
      final String ajoute = sousSection('Ajouté');
      expect(
        ajoute.split('\n').where((String l) => l.startsWith('- ')),
        isNotEmpty,
      );
      final String texte = ajoute.replaceAll(RegExp(r'\s+'), ' ');
      expect(texte, contains('Favoris'));
      expect(texte, contains('Filtres'));
      expect(texte, contains('étoile'));
      expect(texte, contains('Effacer les filtres'));
      expect(texte, contains('Moins de 2 h'));
      expect(texte, contains('Moins de 24 h'));
      expect(texte, contains("Repartir d'une liste vide"));
    });

    test('Ajouté précède Non vérifié dans la section 0.4.0', () {
      final String section = section040();
      final int ajoute = section.indexOf('### Ajouté');
      expect(ajoute, isNot(-1), reason: 'aucune sous-section ### Ajouté');
      expect(ajoute, lessThan(section.indexOf('### Non vérifié')));
    });

    test('le chapeau de 0.4.0 ne dit plus que rien n\'en est livré', () {
      final String section = section040();
      final String chapeau = section
          .substring(section.indexOf('\n'), section.indexOf('\n### '))
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(chapeau, isNot(contains("rien n'en est encore livré")));
    });
  });

  // Task O1 du plan T4 ouvre la version 0.5.0 ; Task P3 la date : la porte de
  // T4 est constatee sur Windows et sur Android, « Constate a l'execution »
  // recopie ces constats et « Non verifie » dit ce qui n'a pas ete dit.
  group('version 0.5.0 (Tasks O1 et P3 du plan T4)', () {
    late String contenuChangelog;

    setUpAll(() {
      contenuChangelog = File('CHANGELOG.md').readAsStringSync();
    });

    String section050() {
      final int debut = contenuChangelog.indexOf('## [0.5.0]');
      expect(debut, isNot(-1), reason: 'aucune section ## [0.5.0]');
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      return contenuChangelog.substring(debut, suivante);
    }

    String sousSection(String titre) {
      final String section = section050();
      final int debut = section.indexOf('### $titre');
      expect(debut, isNot(-1), reason: 'aucune sous-section ### $titre');
      final int suivante = section.indexOf('\n### ', debut + 1);
      return section.substring(
        debut,
        suivante == -1 ? section.length : suivante,
      );
    }

    // Le verrou « pubspec.yaml porte version: 0.5.0+5 » est retiré : le
    // pubspec est passé à 0.6.0+6 (Task O1 du plan d'ergonomie), il ne peut
    // plus être vrai. Le groupe 0.6.0 porte le verrou de version courant.

    test('une section ## [0.5.0], une seule, sous [Non publié] et au-dessus '
        'de [0.4.0]', () {
      final int occurrences = RegExp(
        r'^## \[0\.5\.0\]',
        multiLine: true,
      ).allMatches(contenuChangelog).length;
      expect(occurrences, 1);
      final int nonPublie = contenuChangelog.indexOf('## [Non publié]');
      final int v050 = contenuChangelog.indexOf('## [0.5.0]');
      final int v040 = contenuChangelog.indexOf('## [0.4.0]');
      expect(nonPublie, lessThan(v050));
      expect(v050, lessThan(v040));
    });

    test('la version 0.5.0 est datée du 2026-10-17 : une version sans date '
        'n\'est pas close', () {
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.5.0]'))
          .firstOrNull;
      expect(ligne, '## [0.5.0] — 2026-10-17');
    });

    test('le chapeau de 0.5.0 dit la tranche T4, la porte franchie sur les '
        'deux cibles, et qu\'aucun tag n\'est posé', () {
      final String section = section050();
      final int finTitre = section.indexOf('\n');
      final int premiereSousSection = section.indexOf('\n### ');
      final String chapeau = section
          .substring(finTitre, premiereSousSection)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(
        chapeau,
        contains(
          'Cinquième tranche (T4) : la vigilance crues publiée par Vigicrues, '
          'en quatrième lecture de la carte.',
        ),
      );
      expect(chapeau, isNot(contains('Version ouverte')));
      expect(chapeau, isNot(contains('non publiée')));
      expect(
        chapeau,
        contains(
          'La porte de T4 est franchie sur les deux cibles, Windows '
          '(exécutable de release lancé hors Flutter) et Android (émulateur '
          'Pixel_7, en débogage)',
        ),
      );
      expect(chapeau, contains('Aucun tag'));
      expect(chapeau, contains('mise en production'));
    });

    test('Ajouté précède Constaté à l\'exécution, qui précède Non vérifié', () {
      final String section = section050();
      final int ajoute = section.indexOf('### Ajouté');
      final int constate = section.indexOf('### Constaté à l\'exécution');
      final int nonVerifie = section.indexOf('### Non vérifié');
      expect(ajoute, isNot(-1));
      expect(ajoute, lessThan(constate));
      expect(constate, lessThan(nonVerifie));
    });

    test('Ajouté dit qu\'un geste ou un changement de taille de la carte '
        'relit Vigicrues', () {
      final String ajoute = sousSection('Ajouté')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(
        ajoute,
        contains('un geste ou un changement de taille de la carte'),
      );
    });

    test('Constaté à l\'exécution recopie les constats de la porte, datés, '
        'par cible', () {
      final String constate = sousSection('Constaté à l\'exécution')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(constate, contains('2026-10-17'));
      expect(constate, contains('(`P1-a` à `P1-g`)'));
      expect(constate, contains('`P2-i`'));
      expect(constate, contains('« p1-a ok »'));
      expect(constate, contains('« p2-a: ok »'));
      expect(constate, contains('« G2 impossible »'));
      expect(constate, contains('35 748 882'));
      expect(constate, contains('maximumMapZoom'));
      expect(constate, contains('11 appels'));
      expect(constate, contains('0.5.0'));
      expect(constate, contains('185 trames'));
      expect(constate, contains('81 trames'));
      expect(constate, contains('194 trames'));
      expect(
        constate,
        contains(
          'n'
          "'"
          'est pas retenue',
        ),
      );
    });

    test('Non vérifié nomme le point 64, les niveaux 2 à 4, les lecteurs '
        'd\'écran et Segoe UI', () {
      final String nonVerifie = sousSection('Non vérifié')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(nonVerifie, contains('Point 64'));
      expect(nonVerifie, contains('Niveaux 2 à 4'));
      expect(nonVerifie, contains('Narrateur'));
      expect(nonVerifie, contains('TalkBack'));
      expect(nonVerifie, contains('Segoe UI réelle'));
      expect(nonVerifie, contains('La porte de T2 n\'est pas franchie'));
    });
  });

  // Task O1 du plan d'ergonomie ouvre la version 0.6.0 ; Task P3 la datera,
  // la porte de la tranche étant constatée sur Windows et sur Android. Le cas
  // « ouverte, pas datée » (le 3) est celui que P3 inversera, comme pour 0.3.0 ;
  // P3 réécrira aussi le verrou du chapeau (« le code de la tranche est
  // livré », « la porte reste à passer »).
  group('version 0.6.0 (Tasks O1 et P3 du plan d\'ergonomie)', () {
    late String contenuChangelog;

    setUpAll(() {
      contenuChangelog = File('CHANGELOG.md').readAsStringSync();
    });

    // Le texte de la section `## [0.6.0]`, jusqu'à la section suivante.
    String section060() {
      final int debut = contenuChangelog.indexOf('## [0.6.0]');
      expect(debut, isNot(-1), reason: 'aucune section ## [0.6.0]');
      final int suivante = contenuChangelog.indexOf('\n## [', debut + 1);
      return contenuChangelog.substring(
        debut,
        suivante == -1 ? contenuChangelog.length : suivante,
      );
    }

    test('pubspec.yaml porte version: 0.6.0+6', () {
      final String contenuPubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(
          r'^version:\s*0\.6\.0\+6\s*$',
          multiLine: true,
        ).hasMatch(contenuPubspec),
        isTrue,
        reason:
            'un tag et un journal qui divergent laissent personne savoir ce '
            'que contient le binaire installé',
      );
    });

    test('une section ## [0.6.0], une seule, sous [Non publié] et au-dessus '
        'de [0.5.0]', () {
      final int occurrences = RegExp(
        r'^## \[0\.6\.0\]',
        multiLine: true,
      ).allMatches(contenuChangelog).length;
      expect(occurrences, 1);
      final int nonPublie = contenuChangelog.indexOf('## [Non publié]');
      final int v060 = contenuChangelog.indexOf('## [0.6.0]');
      final int v050 = contenuChangelog.indexOf('## [0.5.0]');
      expect(nonPublie, lessThan(v060));
      expect(v060, lessThan(v050));
    });

    test('la version 0.6.0 est ouverte, pas datée : la porte de la tranche '
        'd\'ergonomie n\'est pas passée', () {
      final String? ligne = contenuChangelog
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.startsWith('## [0.6.0]'))
          .firstOrNull;
      expect(ligne, '## [0.6.0] — à publier');
    });

    test('le chapeau de 0.6.0 dit la tranche d\'ergonomie, avant T5, son code '
        'livré et sa porte restant à passer', () {
      final String section = section060();
      final String chapeau = section
          .substring(section.indexOf('\n'))
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(chapeau, contains('Tranche d\'ergonomie, avant T5'));
      expect(chapeau, contains('Version ouverte, pas publiée'));
      expect(chapeau, contains('le code de la tranche est livré'));
      expect(chapeau, contains('la porte reste à passer'));
    });
  });
}

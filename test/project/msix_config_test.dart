// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// ADR-018 : le paquet MSIX du Microsoft Store se construit avec `msix`, en
// dépendance de développement, et porte l'identité réservée dans Partner
// Center. Une valeur qui diverge fait refuser le paquet au dépôt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le bloc de premier niveau `nom:` de [pubspec], jusqu'à la clé de premier
/// niveau suivante (une ligne qui ne commence ni par une espace ni par `#`).
String blocDePremierNiveau(String pubspec, String nom) {
  final List<String> lignes = pubspec.split('\n');
  final int debut = lignes.indexWhere((String l) => l.trimRight() == '$nom:');
  expect(debut, isNot(-1), reason: 'pubspec.yaml doit porter une clé $nom:');
  final StringBuffer bloc = StringBuffer();
  for (final String ligne in lignes.skip(debut + 1)) {
    final bool premierNiveau =
        ligne.isNotEmpty &&
        !ligne.startsWith(' ') &&
        !ligne.startsWith('#') &&
        ligne.trim().isNotEmpty;
    if (premierNiveau) break;
    bloc.writeln(ligne);
  }
  return bloc.toString();
}

void main() {
  late String pubspec;

  setUpAll(() {
    pubspec = File('pubspec.yaml').readAsStringSync().replaceAll('\r\n', '\n');
  });

  group('msix en dépendance de développement (ADR-018)', () {
    test('msix ^3.18.0 est sous dev_dependencies, et seulement là', () {
      expect(
        blocDePremierNiveau(pubspec, 'dev_dependencies'),
        matches(RegExp(r'^  msix: \^3\.18\.0(\s+#.*)?$', multiLine: true)),
      );
      expect(
        blocDePremierNiveau(pubspec, 'dependencies'),
        isNot(contains('msix')),
        reason: "msix est un outil de construction : rien n'en entre dans lib/",
      );
    });
  });

  group("msix_config porte l'identité de Partner Center (ADR-018)", () {
    late String config;

    setUpAll(() {
      config = blocDePremierNiveau(pubspec, 'msix_config');
    });

    for (final (String cle, String valeur) in <(String, String)>[
      ('display_name', 'MartinPêcheur'),
      ('publisher_display_name', 'Monbsoft'),
      ('identity_name', '46Monbsoft.com.MartinPcheur'),
      ('publisher', 'CN=6D56381B-9EA9-4C93-83CC-28D86DB31617'),
      ('capabilities', 'internetClient'),
      ('languages', 'fr-fr'),
      ('install_certificate', 'false'),
      // Le MSIX emballe l'exécutable de release déjà vérifié, sans le
      // reconstruire (arbitrage du commanditaire du 2026-10-21).
      ('build_windows', 'false'),
    ]) {
      test('$cle vaut $valeur', () {
        expect(
          config,
          matches(
            RegExp('^  $cle: ${RegExp.escape(valeur)}\\s*\$', multiLine: true),
          ),
        );
      });
    }

    test('pas de msix_version : la version vient de pubspec.yaml', () {
      expect(config, isNot(contains('msix_version')));
    });

    // Amendement d'ADR-018 du 2026-10-21 : un paquet construit sans --store
    // a été signé par le certificat de test de msix, qui a remplacé l'éditeur,
    // et Partner Center l'a refusé. store: true rend l'oubli impossible.
    test('store: true : tout paquet construit est un paquet du Store, sans '
        'signature de test', () {
      expect(config, matches(RegExp(r'^  store: true\s*$', multiLine: true)));
    });
  });

  group('logo du paquet (ADR-018)', () {
    test('msix_config porte logo_path: windows/store/logo.png', () {
      expect(
        blocDePremierNiveau(pubspec, 'msix_config'),
        matches(
          RegExp(r'^  logo_path: windows/store/logo\.png\s*$', multiLine: true),
        ),
        reason:
            'sans logo_path, msix met le logo de Flutter dans le paquet, que '
            'la politique 10.1.1 du Store interdit',
      );
    });

    test("windows/store/logo.png est un PNG carré d'au moins 400 px", () {
      final File logo = File('windows/store/logo.png');
      expect(logo.existsSync(), isTrue, reason: 'le logo doit exister');
      final List<int> octets = logo.readAsBytesSync();
      // Signature PNG, puis largeur et hauteur en tête du bloc IHDR.
      expect(octets.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      int entier(int debut) =>
          (octets[debut] << 24) |
          (octets[debut + 1] << 16) |
          (octets[debut + 2] << 8) |
          octets[debut + 3];
      final int largeur = entier(16);
      final int hauteur = entier(20);
      expect(largeur, hauteur, reason: 'le logo du paquet est carré');
      expect(largeur, greaterThanOrEqualTo(400), reason: 'README de msix');
    });
  });

  test('le premier nombre de la version ne vaut pas 0 : le Store le refuse '
      '(ADR-018)', () {
    final RegExpMatch? version = RegExp(
      r'^version:\s*(\d+)\.\d+\.\d+',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(version, isNotNull);
    expect(int.parse(version!.group(1)!), greaterThan(0));
  });
}

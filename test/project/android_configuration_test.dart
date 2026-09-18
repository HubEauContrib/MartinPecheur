// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// Android a été réactivé par arbitrage du commanditaire le 2026-09-18
// (il était différé depuis le 2026-09-12). Ce test verrouille le gabarit
// généré par `flutter create` sur l'identifiant, le réseau et le nom affiché
// — la même exigence que pour iOS (`ios_bundle_identifier_test.dart`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Liste tous les fichiers (récursivement) sous [dossier].
List<File> _fichiersSous(String dossier) {
  final Directory racine = Directory(dossier);
  if (!racine.existsSync()) {
    return <File>[];
  }
  return racine
      .listSync(recursive: true)
      .whereType<File>()
      .toList(growable: false);
}

void main() {
  group('Identifiant applicatif Android', () {
    late String contenuBuildGradle;

    setUpAll(() {
      final File fichierBuildGradle = File('android/app/build.gradle.kts');
      expect(
        fichierBuildGradle.existsSync(),
        isTrue,
        reason: 'android/app/build.gradle.kts doit exister',
      );
      contenuBuildGradle = fichierBuildGradle.readAsStringSync();
    });

    test('applicationId et namespace valent fr.martinpecheur.app', () {
      expect(
        contenuBuildGradle,
        contains('namespace = "fr.martinpecheur.app"'),
      );
      expect(
        contenuBuildGradle,
        contains('applicationId = "fr.martinpecheur.app"'),
      );
    });

    test("l'ancien identifiant fr.martinpecheur.martinpecheur a disparu de "
        'build.gradle.kts et de android/app/src/main', () {
      expect(
        contenuBuildGradle,
        isNot(contains('fr.martinpecheur.martinpecheur')),
      );

      for (final File fichier in _fichiersSous('android/app/src/main')) {
        // Seuls les fichiers texte attendus sont lus : une image ou un futur
        // binaire (.webp, police, .jar) ferait lever une FormatException au
        // lieu d'un echec d'assertion.
        const List<String> extensionsTexte = <String>['.xml', '.kt', '.java'];
        if (!extensionsTexte.any(fichier.path.endsWith)) {
          continue;
        }
        final String contenu = fichier.readAsStringSync();
        expect(
          contenu,
          isNot(contains('fr.martinpecheur.martinpecheur')),
          reason: '${fichier.path} contient encore l ancien identifiant',
        );
      }
    });
  });

  group('Manifeste principal Android', () {
    late String contenuManifeste;

    setUpAll(() {
      final File fichierManifeste = File(
        'android/app/src/main/AndroidManifest.xml',
      );
      expect(
        fichierManifeste.existsSync(),
        isTrue,
        reason: 'android/app/src/main/AndroidManifest.xml doit exister',
      );
      contenuManifeste = fichierManifeste.readAsStringSync();
    });

    test("la permission INTERNET est declaree : sans elle, en version de "
        "publication, aucune tuile IGN ni aucune reponse Hub'Eau n arrive", () {
      expect(contenuManifeste, contains('android.permission.INTERNET'));
      // Enfant direct de <manifest>, donc AVANT <application> : deplacee
      // dedans, la permission serait ignoree sans que rien le signale.
      final int positionPermission = contenuManifeste.indexOf(
        '<uses-permission',
      );
      final int positionApplication = contenuManifeste.indexOf('<application');
      expect(positionPermission, isNonNegative);
      expect(positionPermission, lessThan(positionApplication));
    });

    test('le label affiche est MartinPêcheur', () {
      expect(contenuManifeste, contains('android:label="MartinPêcheur"'));
    });
  });

  group('MainActivity Android', () {
    test('MainActivity.kt vit sous kotlin/fr/martinpecheur/app/ avec le '
        'paquet fr.martinpecheur.app, et l ancien dossier a disparu', () {
      final File nouveauFichier = File(
        'android/app/src/main/kotlin/fr/martinpecheur/app/MainActivity.kt',
      );
      expect(
        nouveauFichier.existsSync(),
        isTrue,
        reason: '${nouveauFichier.path} doit exister',
      );
      expect(
        nouveauFichier.readAsStringSync(),
        contains('package fr.martinpecheur.app'),
      );

      final Directory ancienDossier = Directory(
        'android/app/src/main/kotlin/fr/martinpecheur/martinpecheur',
      );
      expect(
        ancienDossier.existsSync(),
        isFalse,
        reason: '${ancienDossier.path} ne doit plus exister',
      );
    });
  });

  group('Version du NDK Android', () {
    test(
      'ndkVersion reste indexe sur flutter.ndkVersion, sans epingle en dur',
      () {
        final String contenuBuildGradle = File('android/app/build.gradle.kts')
            .readAsStringSync();

        expect(contenuBuildGradle, contains('ndkVersion = flutter.ndkVersion'));
        expect(
          RegExp(r'ndkVersion\s*=\s*"').hasMatch(contenuBuildGradle),
          isFalse,
          reason: 'ndkVersion ne doit pas etre epingle a une chaine litterale',
        );
      },
    );
  });
}

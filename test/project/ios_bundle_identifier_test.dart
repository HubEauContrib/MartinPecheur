// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Identifiant de bundle iOS', () {
    late String contenuProjetXcode;

    setUpAll(() {
      final File fichierProjet = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        fichierProjet.existsSync(),
        isTrue,
        reason: 'ios/Runner.xcodeproj/project.pbxproj doit exister',
      );
      contenuProjetXcode = fichierProjet.readAsStringSync();
    });

    test("l'identifiant fr.martinpecheur.app est present et l'ancien "
        'identifiant fr.martinpecheur.martinpecheur a disparu', () {
      expect(contenuProjetXcode, contains('fr.martinpecheur.app'));
      expect(
        contenuProjetXcode,
        isNot(contains('fr.martinpecheur.martinpecheur')),
      );
    });
  });

  test("le dossier android n'existe pas : le report Android est une decision, "
      'pas un oubli', () {
    expect(Directory('android').existsSync(), isFalse);
  });
}

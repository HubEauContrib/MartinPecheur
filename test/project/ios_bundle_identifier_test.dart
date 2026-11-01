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

    test("les six entrees portent io.github.hubeaucontrib.martinpecheur, dont "
        'trois en .RunnerTests, et les anciens identifiants ont disparu', () {
      // iOS n'est jamais compilé : ce test est son seul garde-fou.
      const String identifiant = 'io.github.hubeaucontrib.martinpecheur';
      final List<String?> entrees = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
      ).allMatches(contenuProjetXcode).map((Match m) => m.group(1)).toList();

      expect(entrees, hasLength(6));
      expect(entrees.where((String? e) => e == identifiant), hasLength(3));
      expect(
        entrees.where((String? e) => e == '$identifiant.RunnerTests'),
        hasLength(3),
      );
      expect(contenuProjetXcode, isNot(contains('fr.martinpecheur')));
    });
  });
}

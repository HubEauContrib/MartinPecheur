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
}

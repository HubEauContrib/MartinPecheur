// Le premier test du projet. lib/domain/ n'existe pas encore : ce test précède
// la première ligne de domaine et pose la frontière avant qu'il y ait quoi que
// ce soit à protéger. Dart n'offre aucun lint de restriction d'import par
// dossier (BR-002) : ce test est le seul verrou mécanique de la frontière.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Motifs d'infrastructure interdits sous lib/domain/. dart:math et
/// dart:convert restent autorisés : ce sont des calculs, pas de
/// l'infrastructure.
const List<String> forbiddenImports = <String>[
  'package:flutter/',
  'package:flutter_test/',
  'package:flutter_map/',
  'package:latlong2/',
  'package:http/',
  'package:drift/',
  'package:sqflite/',
  'dart:io',
  'dart:ui',
];

/// Parcourt [root] et relève chaque ligne d'import/export qui contient un
/// motif de [forbiddenImports]. On lit le texte des directives, pas un arbre
/// syntaxique : un commentaire qui nomme un paquet interdit n'est pas une
/// dépendance. Un [root] absent renvoie une liste vide.
List<String> forbiddenImportsUnder(Directory root) {
  if (!root.existsSync()) {
    return <String>[];
  }

  final List<String> findings = <String>[];
  final List<FileSystemEntity> entities = root.listSync(recursive: true);
  for (final FileSystemEntity entity in entities) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    final List<String> lines = entity.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      if (!line.startsWith('import ') && !line.startsWith('export ')) {
        continue;
      }

      for (final String pattern in forbiddenImports) {
        if (line.contains(pattern)) {
          findings.add('${entity.path}:${i + 1} → $pattern');
        }
      }
    }
  }

  return findings;
}

void main() {
  group('Frontière du domaine (BR-002)', () {
    test("lib/domain/ n'importe aucune infrastructure", () {
      final List<String> findings = forbiddenImportsUnder(
        Directory('lib/domain'),
      );

      expect(
        findings,
        isEmpty,
        reason:
            "Une dépendance d'infrastructure a été trouvée dans "
            'lib/domain/. Déplacer le code fautif vers data/ ou '
            'features/, et y accéder depuis le domaine via une '
            'interface de dépôt (BR-002). Relevés : $findings',
      );
    });

    test(
      'un dossier absent ou un dossier temporaire vide ne relèvent rien',
      () {
        expect(forbiddenImportsUnder(Directory('lib/domain_absent')), isEmpty);

        final Directory emptyTempDir = Directory.systemTemp.createTempSync(
          'domain_isolation_vide_',
        );
        addTearDown(() {
          if (emptyTempDir.existsSync()) {
            emptyTempDir.deleteSync(recursive: true);
          }
        });

        expect(forbiddenImportsUnder(emptyTempDir), isEmpty);
      },
    );

    test("un fichier fautif est relevé, un commentaire citant un paquet "
        "interdit ne l'est pas", () {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'domain_isolation_fautif_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File('${tempDir.path}${Platform.pathSeparator}offender.dart')
          .writeAsStringSync(
            "import 'package:flutter/material.dart';\n"
            '\n'
            'const int offender = 1;\n',
          );
      File('${tempDir.path}${Platform.pathSeparator}innocent.dart')
          .writeAsStringSync(
            "import 'dart:math';\n"
            '\n'
            '// pas une dependance : mention de package:http/ en commentaire\n'
            'const double innocent = pi;\n',
          );

      final List<String> findings = forbiddenImportsUnder(tempDir);

      expect(findings, hasLength(1));
      expect(findings.single, contains('package:flutter/'));
      expect(findings.single, contains('offender.dart:1'));
    });
  });
}

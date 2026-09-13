// Le premier test du projet : il a été écrit avant la première ligne de
// `lib/domain/`, et posait la frontière avant qu'il y ait quoi que ce soit à
// protéger. Dart n'offre aucun lint de restriction d'import par dossier
// (BR-002) : ce test est le seul verrou mécanique de la frontière.
//
// Il relève deux fautes, qui n'en font qu'une : un paquet d'infrastructure
// importé sous `lib/domain/`, et un chemin relatif qui SORT de `lib/domain/`.
// Les règles de couches propres à la disposition feature-first (`domain/`
// fermé, `data/` sans tranche, ViewModel sans widget, tranche sans tranche,
// `features/` sans `data/`) vivent dans `layers_test.dart` — ce fichier ne les
// recopie pas.
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

/// Extrait l'URI d'une ligne `import '…';` ou `export '…';`, ou `null` si la
/// ligne n'est pas une directive. Guillemets simples et doubles acceptés.
String? _uriOf(String line) {
  if (!line.startsWith('import ') && !line.startsWith('export ')) {
    return null;
  }

  final RegExpMatch? match = RegExp('''['"]([^'"]+)['"]''').firstMatch(line);
  return match?.group(1);
}

/// Dit si l'URI **relative** [uri], résolue depuis le dossier de
/// [importerPath] (relatif à la racine parcourue), sort de cette racine.
///
/// ⚠️ `import '../../data/http/x.dart'` depuis `lib/domain/station/` est
/// exactement la même dépendance que `import 'package:martinpecheur/data/…'` :
/// le domaine atteint l'infrastructure. Sans cette résolution, la seconde
/// forme serait relevée et la première passerait — la frontière serait
/// contournable par une notation.
bool _escapesRoot(String importerPath, String uri) {
  if (uri.contains(':')) {
    return false;
  }

  final List<String> segments = importerPath.split('/');
  if (segments.isNotEmpty) {
    segments.removeLast();
  }

  for (final String part in uri.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (segments.isEmpty) {
        return true;
      }
      segments.removeLast();
      continue;
    }
    segments.add(part);
  }

  return false;
}

/// Parcourt [root] et relève chaque ligne d'import/export qui contient un
/// motif de [forbiddenImports], **ou** dont le chemin relatif sort de [root].
/// On lit le texte des directives, pas un arbre syntaxique : un commentaire
/// qui nomme un paquet interdit n'est pas une dépendance. Un [root] absent
/// renvoie une liste vide.
List<String> forbiddenImportsUnder(Directory root) {
  if (!root.existsSync()) {
    return <String>[];
  }

  final String rootPath = root.path.replaceAll(r'\', '/');
  final List<String> findings = <String>[];
  final List<FileSystemEntity> entities = root.listSync(recursive: true);
  for (final FileSystemEntity entity in entities) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    String relative = entity.path.replaceAll(r'\', '/');
    if (relative.startsWith(rootPath)) {
      relative = relative.substring(rootPath.length);
    }
    relative = relative.startsWith('/') ? relative.substring(1) : relative;

    final List<String> lines = entity.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final String? uri = _uriOf(line);
      if (uri == null) {
        continue;
      }

      for (final String pattern in forbiddenImports) {
        if (line.contains(pattern)) {
          findings.add('${entity.path}:${i + 1} → $pattern');
        }
      }

      if (_escapesRoot(relative, uri)) {
        findings.add('${entity.path}:${i + 1} → sort du domaine ($uri)');
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

    test("un import relatif qui SORT du domaine est relevé, un import "
        "relatif interne ne l'est pas", () {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'domain_isolation_relatif_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final Directory station = Directory('${tempDir.path}/station')
        ..createSync(recursive: true);

      File('${station.path}/escapee.dart')
          .writeAsStringSync("import '../../data/http/hub_eau_client.dart';\n");
      File('${station.path}/innocent_relatif.dart').writeAsStringSync(
        "import '../units/quantities.dart';\n"
        "import './station_point.dart';\n",
      );

      final List<String> findings = forbiddenImportsUnder(tempDir);

      expect(
        findings,
        hasLength(1),
        reason:
            'un `package:` interdit et un `../../` qui sort de lib/domain/ '
            'sont la meme faute écrite de deux façons : le domaine dépend '
            "de l'infrastructure. Relevés : $findings",
      );
      expect(findings.single, contains('escapee.dart:1'));
    });
  });
}

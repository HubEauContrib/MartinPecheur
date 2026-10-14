// Test de non-régression sur le code lui-même (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Une seule barre de titre d'écran plein dans `lib/` (`B1` de T3, dette 3 de
// T2) : `ScreenTitleBar`, dans `lib/features/shared/screen_layout.dart`. Un
// écran qui écrit son propre retour, ou qui pose une barre d'application à
// hauteur fixe, fait rougir ce verrou.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les chemins sous `lib/` dont le contenu construit un bouton de retour ou
/// une barre d'application, triés.
List<String> backButtonOwners(Map<String, String> contentByPath) {
  final List<String> owners = <String>[
    for (final MapEntry<String, String> entry in contentByPath.entries)
      if (entry.key.startsWith('lib/') &&
          (entry.value.contains('BackButton(') ||
              entry.value.contains('AppBar(')))
        entry.key,
  ];
  owners.sort();
  return owners;
}

/// Tous les `.dart` sous `lib/`, chemins ramenés à des `/`.
Map<String, String> _realLibFiles() {
  final Map<String, String> contentByPath = <String, String>{};
  for (final FileSystemEntity entity in Directory(
    'lib',
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    contentByPath[entity.path.replaceAll(r'\', '/')] = entity
        .readAsStringSync();
  }
  return contentByPath;
}

void main() {
  group('backButtonOwners — cas synthétiques', () {
    test('seuls les fichiers de lib/ qui portent un retour ou une barre '
        "d'application sont rendus", () {
      expect(
        backButtonOwners(<String, String>{
          'lib/a.dart': 'BackButton(',
          'lib/b.dart': 'x',
          'test/c.dart': 'BackButton(',
        }),
        <String>['lib/a.dart'],
      );
      expect(
        backButtonOwners(<String, String>{
          'lib/z.dart': 'return AppBar(title: t);',
          'lib/a.dart': 'BackButton(',
        }),
        <String>['lib/a.dart', 'lib/z.dart'],
      );
    });
  });

  group('lib/ réel', () {
    test('un seul fichier porte le retour : screen_layout.dart', () {
      final Map<String, String> reel = _realLibFiles();
      expect(reel, isNotEmpty, reason: 'aucun fichier .dart lu sous lib/');
      expect(backButtonOwners(reel), <String>[
        'lib/features/shared/screen_layout.dart',
      ]);
    });
  });
}

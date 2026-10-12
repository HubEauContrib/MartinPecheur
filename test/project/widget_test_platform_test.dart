// Test de non-régression sur la suite elle-même (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Verrou de plateforme des tests de widget (`N1` de T3, dette 1 de T2) : tout
// test de widget nomme sa plateforme par `testWidgetsOnWindows` ou
// `testWidgetsOnAndroid` (`test/support/`). L'appel nu est interdit hors de
// `test/support/` : sous `flutter test` la plateforme par défaut est android,
// et un test de disposition de Windows qui l'oublie mesure autre chose que ce
// qu'il dit (`docs/project-state.md`, point 59).
//
// La migration se fait fichier par fichier (`N2` à `N9`) : les fichiers pas
// encore migrés sont une liste d'exceptions, [filesNotYetMigrated], qui ne
// fait que décroître. Un fichier migré qui y reste fait rougir le verrou.
//
// Ce fichier écrit le mot interdit dans ses cas synthétiques : il s'exclut
// lui-même par [lockFilePath].
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chemin de ce fichier : ses cas synthétiques écrivent le mot interdit.
const String lockFilePath = 'test/project/widget_test_platform_test.dart';

/// Les fichiers pas encore migrés. Ne fait que décroître ; vide à la fin de N9.
const Set<String> filesNotYetMigrated = <String>{
  'test/features/station_sheet/view/station_summary_sheet_test.dart',
  'test/features/onde_sheet/view/onde_summary_sheet_test.dart',
  'test/features/restrictions/view/drought_severity_badge_size_test.dart',
  'test/features/restrictions/view/drought_severity_badge_test.dart',
  'test/features/restrictions/view/reinforced_warning_card_test.dart',
  'test/features/restrictions/view/restrictions_scale_text_test.dart',
  'test/features/restrictions/view/restrictions_screen_test.dart',
  'test/features/map/view/area_cluster_marker_test.dart',
  'test/features/map/view/designate_center_button_test.dart',
  'test/features/map/view/ign_attribution_badge_test.dart',
  'test/features/map/view/map_controls_test.dart',
  'test/features/map/view/map_designation_test.dart',
  'test/features/map/view/map_empty_states_test.dart',
  'test/features/map/view/map_keyboard_test.dart',
  'test/features/map/view/map_legend_test.dart',
  'test/features/map/view/map_overlays_phone_test.dart',
  'test/features/map/view/map_scale_chips_test.dart',
  'test/features/map/view/map_view_test.dart',
  'test/features/map/view/onde_marker_test.dart',
  'test/features/map/view/station_marker_test.dart',
};

/// « chemin:ligne » de chaque ligne de CODE (hors ligne entière de
/// commentaire) qui porte le mot `testWidgets` seul, dans un fichier sous
/// `test/`, hors `test/support/`, hors [lockFilePath], hors [notYetMigrated].
List<String> bareTestWidgetsLines(
  Map<String, String> contentByPath, {
  Set<String> notYetMigrated = const <String>{},
}) {
  final List<String> lines = <String>[];
  for (final MapEntry<String, String> entry in contentByPath.entries) {
    final String path = entry.key;
    if (!_isLocked(path) || notYetMigrated.contains(path)) continue;
    for (final int line in _bareLineNumbers(entry.value)) {
      lines.add('$path:$line');
    }
  }
  return lines;
}

/// Les chemins de [notYetMigrated] qui n'ont plus rien à y faire : fichier
/// absent de [contentByPath], ou qui ne porte plus aucun appel nu.
List<String> staleExceptions(
  Map<String, String> contentByPath,
  Set<String> notYetMigrated,
) {
  final List<String> stale = <String>[];
  for (final String path in notYetMigrated) {
    final String? content = contentByPath[path];
    if (content == null || _bareLineNumbers(content).isEmpty) stale.add(path);
  }
  return stale;
}

/// Le mot seul : ni `testWidgetsOnWindows` ni `testWidgetsOnAndroid` (pas de
/// frontière de mot avant `On`).
final RegExp _bareWord = RegExp(r'\btestWidgets\b');

/// Un fichier que le verrou regarde : sous `test/`, hors `test/support/`,
/// hors ce fichier.
bool _isLocked(String path) =>
    path.startsWith('test/') &&
    !path.startsWith('test/support/') &&
    path != lockFilePath;

/// Numéros (à partir de 1) des lignes de code qui portent le mot seul. Une
/// ligne entière de commentaire n'est pas du code ; un commentaire de fin de
/// ligne en est.
List<int> _bareLineNumbers(String content) {
  final List<String> lines = content.split('\n');
  return <int>[
    for (int i = 0; i < lines.length; i++)
      if (!lines[i].trimLeft().startsWith('//') && _bareWord.hasMatch(lines[i]))
        i + 1,
  ];
}

/// Tous les `.dart` sous `test/`, chemins ramenés à des `/`.
Map<String, String> _realTestFiles() {
  final Map<String, String> contentByPath = <String, String>{};
  for (final FileSystemEntity entity in Directory(
    'test',
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    contentByPath[entity.path.replaceAll(r'\', '/')] = entity
        .readAsStringSync();
  }
  return contentByPath;
}

void main() {
  group('bareTestWidgetsLines — cas synthétiques', () {
    test('un appel nu est rendu avec son chemin et sa ligne', () {
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/a_test.dart': "void main() {\n  testWidgets('a', (WidgetTester t) async {});\n}",
        }),
        <String>['test/features/x/a_test.dart:2'],
      );
    });

    test('les deux assistants de plateforme ne sont pas des appels nus', () {
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/a_test.dart':
              'void main() {\n'
              "  testWidgetsOnWindows('a', (WidgetTester t) async {});\n"
              "  testWidgetsOnAndroid('Android : b', (WidgetTester t) async {});\n"
              '}',
        }),
        isEmpty,
      );
    });

    test('fin de flèche, référence sans parenthèse, appel préfixé', () {
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/a_test.dart':
              'void _sur(String d, C c) =>\n    testWidgets(d, c);',
        }),
        <String>['test/features/x/a_test.dart:2'],
      );
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/b_test.dart': 'final Object f = testWidgets;',
        }),
        <String>['test/features/x/b_test.dart:1'],
      );
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/c_test.dart': "ft.testWidgets('a', b);",
        }),
        <String>['test/features/x/c_test.dart:1'],
      );
    });

    test('une ligne entière de commentaire est ignorée, pas un commentaire '
        'de fin de ligne', () {
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/a_test.dart': '// testWidgets tourne sous Android',
          'test/features/x/b_test.dart':
              '  /// Un `testWidgets` posé sur une plateforme',
        }),
        isEmpty,
      );
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/features/x/c_test.dart': 'foo(); // comme testWidgets',
        }),
        <String>['test/features/x/c_test.dart:1'],
      );
    });

    test('hors de test/, sous test/support/ et dans le verrou lui-même : '
        'rien', () {
      const String contenu = "ft.testWidgets('a', b);";
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/support/windows_platform.dart': contenu,
        }),
        isEmpty,
      );
      expect(
        bareTestWidgetsLines(<String, String>{
          'test/support_bis/x.dart': contenu,
        }),
        <String>['test/support_bis/x.dart:1'],
      );
      expect(
        bareTestWidgetsLines(<String, String>{'lib/x.dart': contenu}),
        isEmpty,
      );
      expect(
        bareTestWidgetsLines(<String, String>{lockFilePath: contenu}),
        isEmpty,
      );
    });

    test('un fichier en faute mais pas encore migré est toléré', () {
      expect(
        bareTestWidgetsLines(
          <String, String>{
            'test/features/x/a_test.dart': "void main() {\n  testWidgets('a', (WidgetTester t) async {});\n}",
          },
          notYetMigrated: <String>{'test/features/x/a_test.dart'},
        ),
        isEmpty,
      );
    });
  });

  group('staleExceptions — cas synthétiques', () {
    test('une exception sans objet est rendue, une exception fondée non', () {
      expect(
        staleExceptions(
          <String, String>{
            'test/features/x/migre_test.dart':
                "testWidgetsOnWindows('a', (WidgetTester t) async {});",
            'test/features/x/nu_test.dart':
                "testWidgets('a', (WidgetTester t) async {});",
          },
          <String>{
            'test/features/x/absent_test.dart',
            'test/features/x/migre_test.dart',
            'test/features/x/nu_test.dart',
          },
        ),
        <String>[
          'test/features/x/absent_test.dart',
          'test/features/x/migre_test.dart',
        ],
      );
    });
  });

  group('La suite réelle', () {
    late Map<String, String> reel;

    setUpAll(() {
      reel = _realTestFiles();
      expect(reel, isNotEmpty, reason: 'aucun fichier .dart lu sous test/');
    });

    test('aucun appel nu hors des fichiers pas encore migrés', () {
      expect(
        bareTestWidgetsLines(reel, notYetMigrated: filesNotYetMigrated),
        isEmpty,
        reason:
            'Un test de widget nomme sa plateforme : testWidgetsOnWindows '
            'ou testWidgetsOnAndroid (test/support/).',
      );
    });

    test('un fichier migré a quitté la liste des exceptions', () {
      expect(
        staleExceptions(reel, filesNotYetMigrated),
        isEmpty,
        reason:
            'Un fichier migré (ou supprimé) se retire de '
            'filesNotYetMigrated dans son commit.',
      );
    });
  });
}

// Confinement du vocabulaire de l'API Vigicrues (W2 de T4, cadrage § 6,
// ADR-016 sur le modele d'AR-1 d'ADR-004) — le fichier est lu EN ENTIER,
// commentaires compris :
// - les noms de champs (`InfoVigiCru`, `NivInfViCr`, `CdEntCru`,
//   `DtHrInfoVigiCru`, `RefInfoVigiCru`, `lbentcru`, `cdensup_1`) et le chemin
//   `/services/` ne sont admis que sous `lib/data/floods/` et dans
//   `lib/main.dart` (racine de composition) ;
// - le nom « Vigicrues », l'hote public et le gabarit `/bulletin_local/`
//   restent libres : le domaine les porte (`source_names.dart`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Confinement du vocabulaire de l API Vigicrues — regle pure, '
      'contenus synthetiques', () {
    test('un jeton de l API dans une vue est une violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/features/map/view/y.dart': "final String s = 'NivInfViCr';",
        }),
        hasLength(1),
      );
    });

    test('un jeton de l API sous lib/data/floods/ est admis', () {
      expect(
        confinementViolations(<String, String>{
          'lib/data/floods/flood_vigilance_mapper.dart':
              '// InfoVigiCru NivInfViCr CdEntCru DtHrInfoVigiCru '
              'RefInfoVigiCru lbentcru cdensup_1 /services/',
        }),
        isEmpty,
      );
    });

    test('un jeton de l API dans lib/main.dart est admis', () {
      expect(
        confinementViolations(<String, String>{
          'lib/main.dart': '// InfoVigiCru /services/',
        }),
        isEmpty,
      );
    });

    test('un jeton de l API dans un COMMENTAIRE du domaine est une '
        'violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/floods/flood_section.dart':
              '// vient de CdEntCru\nclass X {}',
        }),
        hasLength(1),
      );
    });

    test('le nom Vigicrues dans une vue est admis', () {
      expect(
        confinementViolations(<String, String>{
          'lib/features/map/view/y.dart': "final String s = 'Vigicrues';",
        }),
        isEmpty,
      );
    });

    test('l hote public et le gabarit du bulletin dans le domaine sont '
        'admis', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/sources/source_names.dart':
              "const String h = 'www.vigicrues.gouv.fr';\n"
              "final Uri u = Uri.https(h, '/bulletin_local/8');",
        }),
        isEmpty,
      );
    });

    test('le chemin /services/ hors du module est une violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/sources/source_names.dart':
              "const String u = 'https://www.vigicrues.gouv.fr/services/x';",
        }),
        hasLength(1),
      );
    });

    test('chaque jeton est interdit hors du module', () {
      const List<String> jetons = <String>[
        'InfoVigiCru',
        'NivInfViCr',
        'CdEntCru',
        'DtHrInfoVigiCru',
        'RefInfoVigiCru',
        'lbentcru',
        'cdensup_1',
        '/services/',
      ];
      for (final String jeton in jetons) {
        expect(
          confinementViolations(<String, String>{
            'lib/features/x/view/y.dart': '// $jeton',
          }),
          hasLength(1),
          reason: jeton,
        );
      }
    });
  });

  group('Confinement du vocabulaire de l API Vigicrues — lib/ reel', () {
    test('aucune violation', () {
      final Map<String, String> contentByPath = <String, String>{};
      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        contentByPath[entity.path.replaceAll('\\', '/')] = entity
            .readAsStringSync();
      }

      expect(contentByPath, isNotEmpty);
      expect(
        confinementViolations(contentByPath),
        isEmpty,
        reason:
            "ADR-016 : le vocabulaire de l'API Vigicrues reste dans "
            'lib/data/floods/ et lib/main.dart',
      );
    });
  });
}

/// Chemins ou le vocabulaire de l'API est admis (prefixe de dossier termine
/// par `/`, ou chemin de fichier exact).
const List<String> _admittedIn = <String>['lib/data/floods/', 'lib/main.dart'];

final RegExp _apiVocabulary = RegExp(
  r'InfoVigiCru|NivInfViCr|CdEntCru|DtHrInfoVigiCru|RefInfoVigiCru|'
  r'lbentcru|cdensup_1|/services/',
  caseSensitive: false,
);

bool _admits(String path) => _admittedIn.any(
  (String admitted) =>
      admitted.endsWith('/') ? path.startsWith(admitted) : path == admitted,
);

/// Regle pure du confinement. [contentByPath] : chemin relatif a la racine du
/// depot, separateur `/`, vers le contenu ENTIER du fichier. Rend une ligne
/// par fichier en faute ; vide si tout est confine.
List<String> confinementViolations(Map<String, String> contentByPath) {
  final List<String> violations = <String>[];
  for (final MapEntry<String, String> entry in contentByPath.entries) {
    if (_admits(entry.key)) {
      continue;
    }
    final RegExpMatch? match = _apiVocabulary.firstMatch(entry.value);
    if (match != null) {
      violations.add(
        "${entry.key} : vocabulaire de l'API Vigicrues (« ${match[0]} »)",
      );
    }
  }
  return violations;
}

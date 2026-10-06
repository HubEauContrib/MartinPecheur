// Le contrat RestrictionSource (ADR-004) est passe au domaine par M4 de T2
// (`lib/domain/restrictions/restriction_source.dart`,
// `test/domain/restrictions/restriction_source_test.dart`) : ce fichier ne
// garde plus que la regle pure de confinement, qui continue de porter sur
// `lib/` reel independamment de l'emplacement du contrat.
//
// Confinement redefini par l'amendement d'ADR-004 (AR-1, 2026-09-27 ;
// conception T2 § 7, point 1) — le fichier est lu EN ENTIER, commentaires
// compris :
// - le nom de la source (`vigieau`, casse indifferente) n'est admis que dans
//   `lib/data/restrictions/`, `lib/domain/sources/source_names.dart` (nom
//   affiche et adresse du site public) et `lib/main.dart` (racine de
//   composition, meme exemption que la regle features-vers-data) ;
// - le vocabulaire technique de l'API (hote beta.gouv, noms de champs,
//   valeurs filaires) n'est admis que dans `lib/data/restrictions/` et
//   `lib/main.dart` ;
// - le mot « restriction », celui du contexte Restrictions du glossaire, est
//   libere.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Confinement redefini (ADR-004 amende, AR-1) — regle pure, '
      'contenus synthetiques', () {
    test('le nom de la source dans une vue est une violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/features/x/view/y.dart': "const String s = 'VigiEau';",
        }),
        hasLength(1),
      );
    });

    test('le site public dans source_names.dart est admis', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/sources/source_names.dart':
              "const String u = 'https://vigieau.gouv.fr/';",
        }),
        isEmpty,
      );
    });

    test('le mot restriction dans le domaine est libere', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/restrictions/z.dart':
              '// une restriction, des Restrictions\nclass RestrictionX {}',
        }),
        isEmpty,
      );
    });

    test('un nom de champ de l API dans une tranche est une violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/features/restrictions/view/y.dart':
              "final String s = 'niveauGravite';",
        }),
        hasLength(1),
      );
    });

    test('main.dart est exempte : il nomme l implementation concrete', () {
      expect(
        confinementViolations(<String, String>{
          'lib/main.dart':
              'final Object s = VigieauRestrictionSource(); '
              '// https://api.vigieau.beta.gouv.fr niveauGravite',
        }),
        isEmpty,
      );
    });

    test('le nom de la source dans un COMMENTAIRE hors du module est une '
        'violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/data/http/json_http_client.dart':
              '// transport partage, utilise aussi par vigieau\nclass C {}',
        }),
        hasLength(1),
      );
    });

    test('le vocabulaire filaire reste interdit dans source_names.dart', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/sources/source_names.dart':
              "const String u = 'https://api.vigieau.beta.gouv.fr/api';",
        }),
        hasLength(1),
      );
    });

    test('le nom de la source dans le domaine des restrictions est une '
        'violation', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/restrictions/z.dart': '/// Niveau recu de VigiEau.',
        }),
        hasLength(1),
      );
    });

    test('chaque motif filaire est interdit hors du module', () {
      const List<String> motifs = <String>[
        'beta.gouv',
        'niveauGravite',
        'cheminFichier',
        'dateDebutValidite',
        'dateFinValidite',
        'concerneParticulier',
        'concerneExploitation',
        'concerneCollectivite',
        'concerneEntreprise',
        'alerte_renforcee',
      ];
      for (final String motif in motifs) {
        expect(
          confinementViolations(<String, String>{
            'lib/features/x/view/y.dart': '// $motif',
          }),
          hasLength(1),
          reason: motif,
        );
      }
    });

    test('tout est admis sous lib/data/restrictions/', () {
      expect(
        confinementViolations(<String, String>{
          'lib/data/restrictions/zones_mapper.dart':
              '// VigiEau https://api.vigieau.beta.gouv.fr niveauGravite '
              'alerte_renforcee concerneCollectivite cheminFichier',
        }),
        isEmpty,
      );
    });

    test('le vocabulaire filaire est interdit quelle que soit la casse', () {
      for (final String motif in <String>[
        'NiveauGraviteDto',
        'ALERTE_RENFORCEE',
      ]) {
        expect(
          confinementViolations(<String, String>{
            'lib/features/x/view/y.dart': 'class $motif {}',
          }),
          hasLength(1),
          reason: motif,
        );
      }
    });

    test('un libelle affiche « Alerte renforcée » n est pas une valeur '
        'filaire', () {
      expect(
        confinementViolations(<String, String>{
          'lib/domain/restrictions/drought_severity.dart':
              "const String s = 'Alerte renforcée';",
        }),
        isEmpty,
      );
    });
  });

  group('Confinement redefini (ADR-004 amende, AR-1) — lib/ reel', () {
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
            "ADR-004 amende : le risque de rupture d'une API en version 0.1 "
            'reste dans un seul module',
      );
    });

    test('aucun fichier de lib/data/restrictions/ ne contient package:http/ '
        '— le HTTP passe par le transport partage (conception T2 § 4.2)', () {
      final Directory restrictionsDir = Directory('lib/data/restrictions');
      final List<String> fichiersEnFaute = <String>[];

      // Dossier absent entre M4 (qui supprime son dernier fichier) et D2
      // (qui le recree) : aucune violation possible.
      if (restrictionsDir.existsSync()) {
        for (final FileSystemEntity entity in restrictionsDir.listSync(
          recursive: true,
        )) {
          if (entity is! File || !entity.path.endsWith('.dart')) {
            continue;
          }
          if (entity.readAsStringSync().contains('package:http/')) {
            fichiersEnFaute.add(entity.path);
          }
        }
      }

      expect(fichiersEnFaute, isEmpty);
    });
  });
}

/// Une regle de confinement : un motif interdit, et les chemins ou il est
/// admis (prefixe de dossier termine par `/`, ou chemin de fichier exact).
final class _ConfinementRule {
  const _ConfinementRule(this.name, this.pattern, this.admittedIn);

  final String name;
  final RegExp pattern;
  final List<String> admittedIn;

  bool admits(String path) => admittedIn.any(
    (String admitted) =>
        admitted.endsWith('/') ? path.startsWith(admitted) : path == admitted,
  );
}

final List<_ConfinementRule> _confinementRules = <_ConfinementRule>[
  _ConfinementRule(
    'nom de la source',
    RegExp('vigieau', caseSensitive: false),
    const <String>[
      'lib/data/restrictions/',
      'lib/domain/sources/source_names.dart',
      'lib/main.dart',
    ],
  ),
  _ConfinementRule(
    "vocabulaire technique de l'API",
    RegExp(
      r'beta\.gouv|niveauGravite|cheminFichier|dateDebutValidite|'
      r'dateFinValidite|'
      r'concerne(Particulier|Exploitation|Collectivite|Entreprise)|'
      r'alerte_renforcee',
      caseSensitive: false,
    ),
    const <String>['lib/data/restrictions/', 'lib/main.dart'],
  ),
];

/// Regle pure du confinement d'ADR-004 amende (AR-1). [contentByPath] :
/// chemin relatif a la racine du depot, separateur `/`, vers le contenu
/// ENTIER du fichier (commentaires compris). Rend une ligne par couple
/// (fichier, regle) en faute ; vide si tout est confine.
List<String> confinementViolations(Map<String, String> contentByPath) {
  final List<String> violations = <String>[];
  for (final MapEntry<String, String> entry in contentByPath.entries) {
    for (final _ConfinementRule rule in _confinementRules) {
      if (rule.admits(entry.key)) {
        continue;
      }
      final RegExpMatch? match = rule.pattern.firstMatch(entry.value);
      if (match != null) {
        violations.add('${entry.key} : ${rule.name} (« ${match[0]} »)');
      }
    }
  }
  return violations;
}

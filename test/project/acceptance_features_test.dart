// Vérifie la forme des critères d'acceptation Gherkin de `docs/acceptance/`
// (`Task X1` du plan T1, révision du 2026-09-22). Aucun framework BDD n'est
// introduit en T1 (décision 6 du plan) : ces `.feature` sont de la
// SPÉCIFICATION LISIBLE, jamais exécutée — ce test-ci vérifie seulement
// qu'ils sont bien formés et qu'ils citent une règle métier qui EXISTE
// réellement sur le disque. Un `BR-099` inventé doit rendre ce test rouge :
// c'est la contre-épreuve de l'étape 4 du plan.
//
// dart:io est autorisé ici (test/project/), jamais sous lib/domain/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les quatre fichiers attendus sous `docs/acceptance/` (`Task X1`).
const List<String> _featureFiles = <String>[
  'avertissements.feature',
  'fraicheur-d-une-mesure.feature',
  'fiche-station.feature',
  'ecoulement-onde.feature',
];

/// Les règles métier que les quatre fichiers doivent couvrir AU MINIMUM,
/// ensemble (`Task X1` : « la liste est dans le test, pas seulement dans une
/// intention »). `BR-013` en est explicitement absent : l'encart renforcé
/// n'a pas d'écran en T1 (décision 11 de la révision du plan du 2026-09-22).
const List<String> _minimumCoveredRules = <String>[
  'BR-005',
  'BR-006',
  'BR-007',
  'BR-010',
  'BR-012',
];

/// Bornes de `BR-005` (fraîcheur d'une observation hydrométrique) : chacune
/// doit avoir son propre scénario, avec la valeur écrite en toutes lettres
/// dans le Gherkin (`lib/domain/observation/freshness.dart`).
const List<String> _br005Bounds = <String>[
  '1 h 59',
  '2 h 00',
  '23 h 59',
  '24 h 00',
];

/// Bornes de `BR-010` (âge d'une campagne ONDE) : chacune doit avoir son
/// propre scénario (`lib/domain/onde/campaign_age.dart`).
const List<String> _br010Bounds = <String>['59 jours', '60 jours'];

/// Les cinq mots proscrits de `BR-003`, sous leur forme de base — aucun
/// scénario ne qualifie un débit ou un écoulement avec l'un d'eux.
const List<String> _forbiddenFlowWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

/// Verbes d'instruction, d'autorisation ou d'interdiction portant sur un
/// usage de l'eau (`BR-014` : « aucun verbe d'instruction, d'autorisation
/// ni d'interdiction » ; justification de la règle : « Autoriser ou
/// interdire un usage de l'eau relève du préfet »). Recopiés de la lettre
/// de `BR-014`, jamais inventés.
const List<String> _instructionVerbs = <String>[
  'autorise',
  'autorisez',
  'autorisons',
  'interdit',
  'interdite',
  'interdisez',
  'déconseillé',
  'déconseillée',
  'déconseillez',
];

/// Une correspondance en MOT ENTIER, insensible à la casse, comme
/// `vocabulary_test.dart` : `(?<!\p{L})mot(?!\p{L})`, jamais `\b` qui ne
/// connaît que l'ASCII en Dart et couperait « sûr » sur son accent.
bool _containsWholeWord(String text, String word) {
  final RegExp pattern = RegExp(
    '(?<!\\p{L})${RegExp.escape(word)}(?!\\p{L})',
    caseSensitive: false,
    unicode: true,
  );
  return pattern.hasMatch(text);
}

/// Un fichier `docs/br/BR-<code>-*.md` existe-t-il sur le disque pour le
/// [code] cité (par exemple `005`) ? Un `BR-099` inventé n'a pas de fichier
/// : c'est la contre-épreuve de l'étape 4.
bool _brFileExists(String code) {
  final Directory dossierBr = Directory('docs/br');
  if (!dossierBr.existsSync()) {
    return false;
  }
  final RegExp motif = RegExp('^BR-$code-.*\\.md\$');
  return dossierBr.listSync().whereType<File>().any(
    (File f) => motif.hasMatch(f.uri.pathSegments.last),
  );
}

/// Découpe le contenu d'un `.feature` en ses scénarios (chacun commençant
/// par `Scénario:`), le préambule avant le premier `Scénario:` étant
/// ignoré (c'est l'en-tête `Fonctionnalité:`).
List<String> _scenariosOf(String contenu) {
  final List<String> morceaux = contenu.split('Scénario:');
  if (morceaux.length <= 1) {
    return <String>[];
  }
  return morceaux.skip(1).map((String s) => 'Scénario:$s').toList();
}

void main() {
  final Directory dossierAcceptance = Directory('docs/acceptance');

  test('le dossier docs/acceptance existe', () {
    expect(
      dossierAcceptance.existsSync(),
      isTrue,
      reason:
          'docs/acceptance/ doit exister avec les quatre .feature de Task X1',
    );
  });

  final Map<String, String> contenusParFichier = <String, String>{};
  for (final String nom in _featureFiles) {
    final File fichier = File('docs/acceptance/$nom');
    if (fichier.existsSync()) {
      contenusParFichier[nom] = fichier.readAsStringSync();
    }
  }

  group('Chaque .feature est bien formé', () {
    for (final String nom in _featureFiles) {
      test('$nom existe et commence par Fonctionnalité:', () {
        final File fichier = File('docs/acceptance/$nom');
        expect(
          fichier.existsSync(),
          isTrue,
          reason: '$nom est attendu sous docs/acceptance/',
        );
        final String contenu = contenusParFichier[nom] ?? '';
        expect(
          contenu.trimLeft().startsWith('Fonctionnalité:'),
          isTrue,
          reason: '$nom doit commencer par "Fonctionnalité:"',
        );
      });

      test('$nom contient au moins un Scénario:, chacun bien formé', () {
        final String contenu = contenusParFichier[nom] ?? '';
        final List<String> scenarios = _scenariosOf(contenu);
        expect(
          scenarios,
          isNotEmpty,
          reason: '$nom doit contenir au moins un "Scénario:"',
        );
        for (final String scenario in scenarios) {
          expect(
            scenario.contains('Étant donné'),
            isTrue,
            reason: 'un scénario de $nom sans "Étant donné" : $scenario',
          );
          expect(
            scenario.contains('Quand'),
            isTrue,
            reason: 'un scénario de $nom sans "Quand" : $scenario',
          );
          expect(
            scenario.contains('Alors'),
            isTrue,
            reason: 'un scénario de $nom sans "Alors" : $scenario',
          );
        }
      });

      test('chaque Scénario de $nom cite un BR- qui existe sur le disque', () {
        final String contenu = contenusParFichier[nom] ?? '';
        final List<String> scenarios = _scenariosOf(contenu);
        for (final String scenario in scenarios) {
          final Iterable<RegExpMatch> citations = RegExp(r'BR-(\d{3})')
              .allMatches(scenario);
          expect(
            citations,
            isNotEmpty,
            reason: 'un scénario de $nom ne cite aucune BR- : $scenario',
          );
          for (final RegExpMatch m in citations) {
            final String code = m.group(1)!;
            expect(
              _brFileExists(code),
              isTrue,
              reason:
                  'BR-$code citée dans $nom n\'a pas de fichier docs/br/BR-$code-*.md',
            );
          }
        }
      });
    }
  });

  test('les quatre fichiers couvrent ensemble BR-005, BR-006, BR-007, BR-010, BR-012', () {
    final String tout = contenusParFichier.values.join('\n');
    for (final String regle in _minimumCoveredRules) {
      expect(
        tout.contains(regle),
        isTrue,
        reason: '$regle doit être citée par au moins un des quatre .feature',
      );
    }
  });

  test('aucun .feature ne décrit BR-013 (encart renforcé, reporté en T2)', () {
    final String tout = contenusParFichier.values.join('\n');
    expect(
      tout.contains('BR-013'),
      isFalse,
      reason:
          'BR-013 (encart renforcé) est reporté en T2 : aucun écran de T1 n\'est '
          'un écran de ressource (décision 11, révision du plan du 2026-09-22)',
    );
  });

  group('BR-005 — un scénario par borne', () {
    for (final String borne in _br005Bounds) {
      test(
        'la borne "$borne" apparaît dans fraicheur-d-une-mesure.feature',
        () {
          final String contenu =
              contenusParFichier['fraicheur-d-une-mesure.feature'] ?? '';
          expect(
            contenu.contains(borne),
            isTrue,
            reason: 'aucun scénario ne porte la borne BR-005 "$borne"',
          );
        },
      );
    }
  });

  group('BR-010 — un scénario par borne', () {
    for (final String borne in _br010Bounds) {
      test('la borne "$borne" apparaît dans ecoulement-onde.feature', () {
        final String contenu =
            contenusParFichier['ecoulement-onde.feature'] ?? '';
        expect(
          contenu.contains(borne),
          isTrue,
          reason: 'aucun scénario ne porte la borne BR-010 "$borne"',
        );
      });
    }
  });

  test('avertissements.feature porte un scénario par emplacement de 04-ui.md § 5 (W3c)', () {
    final String contenu = contenusParFichier['avertissements.feature'] ?? '';
    // Emplacement 1 : bouton inactif tant que la case n'est pas cochée.
    expect(contenu.contains('inactif'), isTrue);
    // UC-006 A3 : texte modifié, écran réaffiché.
    expect(contenu.contains('UC-006 A3'), isTrue);
    // Emplacement 2 : contrôle présent sur la carte à tous les zooms.
    expect(contenu.contains('zoom'), isTrue);
    expect(contenu.contains('Avertissement'), isTrue);
    // Emplacement 3 : contrôle en tête de fiche, phrase datée, absente sans date.
    expect(
      contenu.contains('phrase datée') || contenu.contains('date'),
      isTrue,
    );
  });

  test('aucun mot banni de BR-003 dans les .feature', () {
    for (final MapEntry<String, String> entree in contenusParFichier.entries) {
      for (final String mot in _forbiddenFlowWords) {
        expect(
          _containsWholeWord(entree.value, mot),
          isFalse,
          reason: '"${entree.key}" contient le mot banni "$mot" (BR-003)',
        );
      }
    }
  });

  test('aucun verbe d\'instruction de BR-014 dans les .feature', () {
    for (final MapEntry<String, String> entree in contenusParFichier.entries) {
      for (final String verbe in _instructionVerbs) {
        expect(
          _containsWholeWord(entree.value, verbe),
          isFalse,
          reason:
              '"${entree.key}" contient le verbe d\'instruction "$verbe" (BR-014)',
        );
      }
    }
  });
}

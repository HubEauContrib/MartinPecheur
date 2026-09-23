// Test de non-régression sur la documentation (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Verrouille `docs/tracabilite.md` (`Task X2` du plan T1, décision 7 :
// matrice maintenue À LA MAIN, vérifiée MÉCANIQUEMENT). Générer la matrice
// supposerait de parser des noms de test pour en déduire une intention — un
// couplage fragile qui produirait une matrice complète et fausse. Ce test-ci
// ne juge jamais la justesse d'une intention (affaire de relecture) : il
// refuse seulement les TROUS — un artefact cité qui n'existe pas, un
// artefact qui existe et n'apparaît nulle part, une ligne vide.
//
// Colonnes attendues dans le tableau markdown : US · BR · UC · Fichier de
// test · Tranche · État.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les BR réellement présentes sous `docs/br/` (hors template), en dur ici :
/// si `docs/br/` gagne une règle sans que ce fichier soit mis à jour, la
/// matrice doit quand même toutes les citer — donc les deux listes divergent
/// et un test le montre.
const List<String> _brAttendues = <String>[
  'BR-001',
  'BR-002',
  'BR-003',
  'BR-004',
  'BR-005',
  'BR-006',
  'BR-007',
  'BR-008',
  'BR-009',
  'BR-010',
  'BR-011',
  'BR-012',
  'BR-013',
  'BR-014',
];

/// Les UC réellement présents sous `docs/use-cases/` (hors template).
const List<String> _ucAttendus = <String>[
  'UC-001',
  'UC-002',
  'UC-003',
  'UC-004',
  'UC-005',
  'UC-006',
];

/// Les user stories **Must** de `docs/02-specifications.md § « Must »`
/// (US-01 à US-10). US-07, US-08 et US-09 sont les trois de sécheresse.
const List<String> _usMustAttendues = <String>[
  'US-01',
  'US-02',
  'US-03',
  'US-04',
  'US-05',
  'US-06',
  'US-07',
  'US-08',
  'US-09',
  'US-10',
];

/// US Must dont l'état attendu est un report explicite (T2, sécheresse) :
/// la matrice les cite avec un état, jamais avec une ligne vide, et le test
/// n'exige pas de fichier de test en face.
const List<String> _usSansFichierDeTestAccepte = <String>[
  'US-07',
  'US-08',
  'US-09',
];

/// `BR-013` (encart renforcé) porte l'état 🔄 T2 (décision 11, révision du
/// 2026-09-22) : accepté dans la matrice sans fichier de test, comme les
/// user stories de sécheresse.
const String _brSansFichierDeTestAccepte = 'BR-013';

/// Repère de ligne de tableau markdown : une cellule non vide entre deux
/// `|`, en excluant les séparateurs `---`.
bool _celluleNonVide(String cellule) {
  final String c = cellule.trim();
  return c.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(c);
}

/// Découpe `docs/tracabilite.md` en ses lignes de tableau (celles qui
/// commencent par `|`), en écartant l'en-tête et la ligne de séparation.
List<List<String>> _lignesDuTableau(String contenu) {
  final List<List<String>> lignes = <List<String>>[];
  for (final String ligne in contenu.split('\n')) {
    final String t = ligne.trim();
    if (!t.startsWith('|')) {
      continue;
    }
    final List<String> cellules = t
        .split('|')
        .sublist(1, t.split('|').length - 1)
        .map((String c) => c.trim())
        .toList();
    if (cellules.isEmpty) {
      continue;
    }
    // Ligne d'en-tête (« US », « BR », …) ou de séparation (`---`).
    if (cellules.first == 'US' ||
        RegExp(r'^:?-+:?$').hasMatch(cellules.first)) {
      continue;
    }
    lignes.add(cellules);
  }
  return lignes;
}

bool _fichierBrExiste(String code) {
  final String numero = code.replaceFirst('BR-', '');
  final Directory dossier = Directory('docs/br');
  if (!dossier.existsSync()) {
    return false;
  }
  final RegExp motif = RegExp('^BR-$numero-.*\\.md\$');
  return dossier.listSync().whereType<File>().any(
    (File f) => motif.hasMatch(f.uri.pathSegments.last),
  );
}

void main() {
  final File fichierMatrice = File('docs/tracabilite.md');

  test('docs/tracabilite.md existe', () {
    expect(
      fichierMatrice.existsSync(),
      isTrue,
      reason: 'docs/tracabilite.md doit exister (Task X2)',
    );
  });

  final String contenu = fichierMatrice.existsSync()
      ? fichierMatrice.readAsStringSync()
      : '';

  test('le tableau porte les six colonnes attendues', () {
    expect(contenu.contains('US'), isTrue);
    expect(contenu.contains('BR'), isTrue);
    expect(contenu.contains('UC'), isTrue);
    expect(contenu.contains('Fichier de test'), isTrue);
    expect(contenu.contains('Tranche'), isTrue);
    expect(contenu.contains('État'), isTrue);
  });

  group('Chaque BR-001 à BR-014 apparaît au moins une fois', () {
    for (final String br in _brAttendues) {
      test('$br est cité dans la matrice', () {
        expect(
          contenu.contains(br),
          isTrue,
          reason:
              '$br doit apparaître dans docs/tracabilite.md — un '
              'artefact orphelin rend la suite rouge',
        );
      });
    }
  });

  group('Chaque UC-001 à UC-006 apparaît au moins une fois', () {
    for (final String uc in _ucAttendus) {
      test('$uc est cité dans la matrice', () {
        expect(
          contenu.contains(uc),
          isTrue,
          reason: '$uc doit apparaître dans docs/tracabilite.md',
        );
      });
    }
  });

  group('Chaque US Must (US-01 à US-10) apparaît avec un état', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String us in _usMustAttendues) {
      test('$us apparaît, jamais avec un état vide', () {
        final Iterable<List<String>> lignesDeUs = lignes.where(
          (List<String> l) => l.isNotEmpty && l.first.contains(us),
        );
        expect(
          lignesDeUs.isNotEmpty,
          isTrue,
          reason: '$us doit apparaître dans docs/tracabilite.md',
        );
        for (final List<String> ligne in lignesDeUs) {
          final String etat = ligne.last;
          expect(
            _celluleNonVide(etat),
            isTrue,
            reason: '$us ne doit jamais porter une colonne État vide',
          );
        }
      });
    }

    test('US-07, US-08 et US-09 (sécheresse) portent un état 🔄 T2, sans '
        'fichier de test exigé', () {
      for (final String us in _usSansFichierDeTestAccepte) {
        final List<String> ligne = lignes.firstWhere(
          (List<String> l) => l.isNotEmpty && l.first.contains(us),
          orElse: () => <String>[],
        );
        expect(
          ligne,
          isNotEmpty,
          reason: '$us doit avoir une ligne dans la matrice',
        );
        final String etat = ligne.last;
        expect(
          etat.contains('T2') && etat.contains('🔄'),
          isTrue,
          reason:
              '$us (sécheresse) doit porter l\'état 🔄 T2 — pas encore '
              'couverte, la matrice ne le prétend pas : "$etat"',
        );
      }
    });
  });

  test('BR-013 porte l\'état 🔄 T2, accepté sans fichier de test '
      '(décision 11, révision du 2026-09-22)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);
    final Iterable<List<String>> lignesDeBr013 = lignes.where(
      (List<String> l) =>
          l.any((String c) => c.contains(_brSansFichierDeTestAccepte)),
    );
    expect(
      lignesDeBr013.isNotEmpty,
      isTrue,
      reason: 'BR-013 doit apparaître dans la matrice',
    );
    for (final List<String> ligne in lignesDeBr013) {
      final String etat = ligne.last;
      expect(
        etat.contains('T2') && etat.contains('🔄'),
        isTrue,
        reason: 'BR-013 doit porter l\'état 🔄 T2 : "$etat"',
      );
    }
  });

  group('Chaque fichier de test cité existe réellement sur le disque', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);
    final int indexColonneFichier = 3; // US, BR, UC, Fichier de test, ...

    final Set<String> cheminsCites = <String>{};
    for (final List<String> ligne in lignes) {
      if (ligne.length <= indexColonneFichier) {
        continue;
      }
      final String cellule = ligne[indexColonneFichier];
      for (final RegExpMatch m in RegExp(
        r'`([^`]+\.dart)`',
      ).allMatches(cellule)) {
        cheminsCites.add(m.group(1)!);
      }
    }

    test('au moins un fichier de test est cité par la matrice', () {
      expect(cheminsCites, isNotEmpty);
    });

    for (final String chemin in cheminsCites) {
      test('$chemin existe', () {
        expect(
          File(chemin).existsSync(),
          isTrue,
          reason:
              '$chemin est cité dans docs/tracabilite.md mais n\'existe pas '
              'sur le disque : aucun chemin ne s\'écrit de mémoire',
        );
      });
    }
  });

  group('Chaque BR citée pointe vers un docs/br/BR-<NNN>-*.md existant', () {
    for (final String br in _brAttendues) {
      test('le fichier de $br existe sous docs/br/', () {
        expect(
          _fichierBrExiste(br),
          isTrue,
          reason: 'docs/br/$br-*.md doit exister',
        );
      });
    }
  });
}

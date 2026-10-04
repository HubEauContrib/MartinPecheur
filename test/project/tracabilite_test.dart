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
//
// `Task X2` du plan T2 (2026-10-04) : T2 livre la couverture de US-07, US-08,
// US-09, UC-002 et BR-013. Les exceptions « sans fichier de test accepté »
// qu'avait la matrice de T1 pour ces lignes DISPARAISSENT : chacune doit
// maintenant porter un état ✅ T2 et citer des fichiers qui existent. Le
// test n'admet plus aucun 🔄 sur ces cinq lignes — une partie non livrée
// s'écrit en toutes lettres dans la cellule, jamais sous la marque d'un
// acquis.

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

/// Les cinq lignes dont T2 livre la couverture (`Task X2` du plan T2) :
/// l'écran des restrictions (US-07, US-08, UC-002) et son encart renforcé
/// (US-09, BR-013). Elles portaient 🔄 T2, sans fichier de test accepté ; elles
/// portent désormais ✅ T2 et citent des fichiers qui existent.
const List<String> _lignesLivreesEnT2 = <String>[
  'US-07',
  'US-08',
  'US-09',
  'UC-002',
  'BR-013',
];

const String _ecranRestrictions =
    'test/features/restrictions/view/restrictions_screen_test.dart';
const String _viewModelRestrictions =
    'test/features/restrictions/view_model/restrictions_view_model_test.dart';
const String _sourceVigieau =
    'test/data/restrictions/vigieau_restriction_source_test.dart';
const String _mapperZones = 'test/data/restrictions/zones_mapper_test.dart';
const String _equivalenceProfil =
    'test/data/restrictions/profile_filter_equivalence_test.dart';
const String _encartRenforce =
    'test/features/restrictions/view/reinforced_warning_card_test.dart';
const String _ouvreurDeLien =
    'test/data/links/url_launcher_external_link_opener_test.dart';
const String _designationCarte =
    'test/features/map/view/map_designation_test.dart';
const String _puceRestrictions =
    'test/features/map/view/map_scale_chips_test.dart';
const String _surcouchesTelephone =
    'test/features/map/view/map_overlays_phone_test.dart';
const String _profilUsager = 'test/domain/restrictions/user_profile_test.dart';
const String _boutonDesignation =
    'test/features/map/view/designate_center_button_test.dart';
const String _echelleEnBande =
    'test/features/restrictions/view/restrictions_scale_text_test.dart';

/// Les deux lignes que T2 ne livre PAS : la carte hors ligne (`US-10`,
/// `UC-005`) n'est couverte qu'en partie (le cache de tuiles de `flutter_map`
/// sur les zones déjà parcourues). Sans ce garde-fou, rien n'interdit de les
/// passer à ✅ : les exceptions de T1 qui les protégeaient ont disparu avec
/// `Task X2`. Elles gardent 🔄 tant que la persistance de `DerniereVueCarte`,
/// le bandeau « Mode hors-ligne » et le téléchargement explicite d'une zone
/// (`UC-005` flux nominal, étapes 1, 4 et 6) ne sont pas livrés ET couverts
/// par un test — ce qui exige le moteur de stockage structuré qu'`ADR-011`
/// laisse ouvert (T3). Le jour où ils le sont, ce test et cette liste se
/// retirent ensemble, dans le commit qui passe les deux lignes à ✅.
const List<String> _lignesPartielles = <String>['US-10', 'UC-005'];

/// Les fichiers qu'une ligne DOIT citer parce que T2 les a écrits pour elle
/// (`Task X2` du plan T2 : « écran, encart, ViewModel, source, mapper,
/// équivalence » ; `BR-011` cite aussi le mapper ; `US-01` cite l'écran des
/// sources) ou parce qu'un ajout de T2 touche la règle (le choix
/// « Restrictions » du sélecteur de la carte, `E5` et `E5b`). Le test ne juge
/// pas la justesse de l'intention : il refuse qu'une ligne en omette un.
const Map<String, List<String>> _citationsExigees = <String, List<String>>{
  'US-01': <String>['test/features/shared/data_sources_view_test.dart'],
  'US-02': <String>[_surcouchesTelephone],
  'US-07': <String>[
    _ecranRestrictions,
    _viewModelRestrictions,
    _sourceVigieau,
    _mapperZones,
    _equivalenceProfil,
    _designationCarte,
    _boutonDesignation,
    _profilUsager,
    _echelleEnBande,
  ],
  'US-08': <String>[_ecranRestrictions, _viewModelRestrictions, _ouvreurDeLien],
  'US-09': <String>[_encartRenforce, _ecranRestrictions],
  'UC-002': <String>[
    _ecranRestrictions,
    _viewModelRestrictions,
    _sourceVigieau,
    _mapperZones,
    _equivalenceProfil,
    _designationCarte,
    _boutonDesignation,
  ],
  'BR-008': <String>[
    _puceRestrictions,
    _designationCarte,
    _surcouchesTelephone,
  ],
  'BR-011': <String>[_mapperZones],
  'BR-012': <String>[
    'test/features/shared/data_sources_view_test.dart',
    'test/main_test.dart',
  ],
  'BR-013': <String>[
    _encartRenforce,
    _ecranRestrictions,
    'test/domain/warnings/warning_texts_test.dart',
  ],
};

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

/// La ligne dont la première cellule est exactement [id] (« US-07 »,
/// « BR-013 », « UC-002 »), ou `null` : l'en-tête d'un tableau de BR ou d'UC
/// n'a pas de première cellule de cette forme.
List<String>? _ligneDe(List<List<String>> lignes, String id) {
  for (final List<String> ligne in lignes) {
    if (ligne.isNotEmpty && ligne.first == id) {
      return ligne;
    }
  }
  return null;
}

/// La cellule « Fichier de test » d'une ligne : quatrième colonne du tableau
/// des US (US · BR · UC · Fichier de test · Tranche · État), deuxième de ceux
/// des BR et des UC (identifiant · Fichier de test · Tranche · État).
String _celluleFichier(String id, List<String> ligne) {
  final int colonne = id.startsWith('US-') ? 3 : 1;
  return ligne.length > colonne ? ligne[colonne] : '';
}

/// Les chemins `….dart` écrits entre accents graves dans [cellule].
Set<String> _cheminsDart(String cellule) => <String>{
  for (final RegExpMatch m in RegExp(r'`([^`]+\.dart)`').allMatches(cellule))
    m.group(1)!,
};

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
  });

  group('Les lignes dont T2 livre la couverture (Task X2 du plan T2)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String id in _lignesLivreesEnT2) {
      test('$id porte l\'état ✅ T2, sans 🔄, et cite au moins un fichier '
          'de test', () {
        final List<String>? ligne = _ligneDe(lignes, id);
        expect(ligne, isNotNull, reason: '$id doit avoir une ligne');
        final String etat = ligne!.last;
        expect(
          etat.contains('✅') && etat.contains('T2'),
          isTrue,
          reason: '$id doit porter l\'état ✅ T2 : "$etat"',
        );
        expect(
          etat.contains('🔄'),
          isFalse,
          reason:
              '$id ne compte aucun 🔄 comme un acquis : une partie non '
              'livrée s\'écrit en toutes lettres : "$etat"',
        );
        expect(
          _cheminsDart(_celluleFichier(id, ligne)),
          isNotEmpty,
          reason:
              '$id doit citer au moins un fichier de test : plus aucune '
              'exception « sans fichier de test accepté »',
        );
      });
    }
  });

  group('Les lignes que T2 ne livre pas gardent 🔄 (US-10, UC-005)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String id in _lignesPartielles) {
      test('$id reste 🔄, jamais ✅, tant que la carte hors ligne n\'est '
          'couverte qu\'en partie', () {
        final List<String>? ligne = _ligneDe(lignes, id);
        expect(ligne, isNotNull, reason: '$id doit avoir une ligne');
        final String etat = ligne!.last;
        expect(
          etat.contains('🔄'),
          isTrue,
          reason:
              '$id est partiel : seul le cache de tuiles est livré. Il '
              'garde 🔄 jusqu\'à la persistance de DerniereVueCarte, au '
              'bandeau hors-ligne et au téléchargement de zone : "$etat"',
        );
        expect(
          etat.contains('✅'),
          isFalse,
          reason: '$id ne compte pas un acquis partiel comme un ✅ : "$etat"',
        );
      });
    }
  });

  group('Les lignes touchées par T2 citent les fichiers qui les éprouvent', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final MapEntry<String, List<String>> exigence
        in _citationsExigees.entries) {
      test(
        '${exigence.key} cite ${exigence.value.length} fichier(s) de T2',
        () {
          final List<String>? ligne = _ligneDe(lignes, exigence.key);
          expect(
            ligne,
            isNotNull,
            reason: '${exigence.key} doit avoir une ligne',
          );
          final Set<String> cites = _cheminsDart(
            _celluleFichier(exigence.key, ligne!),
          );
          for (final String chemin in exigence.value) {
            expect(
              cites,
              contains(chemin),
              reason: '${exigence.key} doit citer $chemin',
            );
          }
        },
      );
    }
  });

  group('Chaque fichier de test cité existe réellement sur le disque', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    // Toute cellule de toute ligne : la colonne « Fichier de test » est la
    // quatrième du tableau des US, mais la deuxième de ceux des BR et des UC.
    // Ne lire que la quatrième laissait ces deux tableaux sans contrôle.
    final Set<String> cheminsCites = <String>{};
    for (final List<String> ligne in lignes) {
      for (final String cellule in ligne) {
        cheminsCites.addAll(_cheminsDart(cellule));
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

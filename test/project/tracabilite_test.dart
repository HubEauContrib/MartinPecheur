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
//
// `Task X2` du plan T3 (2026-10-14) : T3 livre `US-13` (filtres) et `US-14`
// (favoris), deux user stories **Should**, et les cas d'usage `UC-007` et
// `UC-008`. La matrice gagne une section « Should » : chaque story livrée y a
// une ligne ✅ T3 qui cite les fichiers de test qui l'éprouvent. `US-11`,
// `US-12`, `US-15` et `US-16` ne sont pas livrées : la matrice ne les suit
// pas, et le dit en bas de page.

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
  'BR-015',
  'BR-016',
];

/// Les UC réellement présents sous `docs/use-cases/` (hors template).
const List<String> _ucAttendus = <String>[
  'UC-001',
  'UC-002',
  'UC-003',
  'UC-004',
  'UC-005',
  'UC-006',
  'UC-007',
  'UC-008',
  'UC-009',
  'UC-010',
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

/// Les user stories **Should** que T3 livre (`Task X2` du plan T3) : `US-13`
/// (filtres) et `US-14` (favoris). Les quatre autres Should de
/// `docs/02-specifications.md` (`US-11`, `US-12`, `US-15`, `US-16`) ne sont
/// pas livrées : la matrice ne les suit pas.
const List<String> _usShouldLivreesEnT3 = <String>['US-13', 'US-14'];

/// Les trois lignes que T4 livre (`Task X1` du plan T4) : la user story
/// **Should** `US-21`, la règle `BR-015` et le cas d'usage `UC-009`. Elles
/// portaient 🔄 T4, sans fichier de test ; elles portent ✅ T4 et citent des
/// fichiers qui existent. Aucun constat d'écran de T4 n'est consigné : la
/// marque ✅ dit « vérifié par test », jamais « vu à l'écran ».
const List<String> _lignesLivreesEnT4 = <String>['US-21', 'BR-015', 'UC-009'];

/// Les deux lignes que T5 ouvre (`O4` du plan de T5) sans les livrer : la user
/// story **Should** `US-22` et le cas d'usage `UC-010`. Elles portent 🔄 T5,
/// sans chemin de test.
const List<String> _lignesOuvertesEnT5 = <String>['US-22', 'UC-010'];

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
// `D3` d'Ergonomie : la désignation sous le réticule et le zoom autour de lui,
// mesurés en Roboto, dans leur propre fichier.
const String _designationReticule =
    'test/features/map/view/map_designation_reticle_test.dart';
// `D2` d'Ergonomie : le sélecteur de lecture remplace les puces d'échelle, et
// les invariants de disposition remplacent les mesures de l'ancienne (R15).
const String _selecteurLecture =
    'test/features/map/view/map_reading_selector_test.dart';
const String _invariantsDisposition =
    'test/features/map/view/map_layout_invariants_test.dart';
const String _profilUsager = 'test/domain/restrictions/user_profile_test.dart';
const String _boutonDesignation =
    'test/features/map/view/designate_center_button_test.dart';
const String _echelleEnBande =
    'test/features/restrictions/view/restrictions_scale_text_test.dart';

// Fichiers de T3 (`Task X2` du plan T3), chemins relevés dans le dépôt.
const String _filtreDomaine = 'test/domain/filters/map_filter_test.dart';
const String _filtrePredicats =
    'test/domain/filters/map_filter_predicates_test.dart';
const String _filtreEchelle =
    'test/features/map/view_model/map_filter_scale_test.dart';
const String _filtreViewModel =
    'test/features/map/view_model/map_view_model_filter_test.dart';
const String _filtreFeuille =
    'test/features/map/view/map_filter_sheet_test.dart';
const String _filtreBoutons =
    'test/features/map/view/map_entry_buttons_test.dart';
const String _filtreCablage =
    'test/features/map/view/map_filter_wiring_test.dart';
const String _avisCarteVide =
    'test/features/map/view/map_empty_states_test.dart';
const String _favoriDomaine = 'test/domain/favorites/favorite_test.dart';
const String _favoriContrat =
    'test/domain/favorites/favorite_repository_test.dart';
const String _favoriEtoileEtat = 'test/features/shared/favorite_star_test.dart';
const String _favoriCodec = 'test/data/preferences/favorites_codec_test.dart';
const String _favoriStockage =
    'test/data/preferences/shared_preferences_favorite_repository_test.dart';
const String _favoriEtoileBouton =
    'test/features/shared/favorite_star_button_test.dart';
const String _favoriFicheStation =
    'test/features/station_sheet/view_model/station_sheet_view_model_test.dart';
const String _favoriFicheOnde =
    'test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart';
const String _favoriViewModel =
    'test/features/favorites/view_model/favorites_view_model_test.dart';
const String _favoriEcran =
    'test/features/favorites/view/favorites_screen_test.dart';
const String _racine = 'test/main_test.dart';

// Fichiers de T4 (`Task X1` du plan T4), chemins relevés dans le dépôt.
const String _crueNiveauDomaine =
    'test/domain/floods/flood_vigilance_level_test.dart';
const String _crueTronconDomaine = 'test/domain/floods/flood_section_test.dart';
const String _crueCarteDomaine =
    'test/domain/floods/flood_vigilance_map_test.dart';
const String _crueReglesTroncon =
    'test/domain/floods/flood_section_rules_test.dart';
const String _crueDefinitions =
    'test/domain/floods/published_flood_definitions_test.dart';
const String _crueMapper = 'test/data/floods/flood_vigilance_mapper_test.dart';
const String _crueSource =
    'test/data/floods/vigicrues_flood_vigilance_source_test.dart';
const String _crueCache =
    'test/data/floods/cached_flood_vigilance_source_test.dart';
const String _crueConfinement =
    'test/data/floods/flood_vocabulary_confinement_test.dart';
const String _crueViewModelCarte =
    'test/features/map/view_model/flood_layer_view_model_test.dart';
const String _crueCalque =
    'test/features/map/view/flood_sections_layer_test.dart';
const String _crueEtiquette =
    'test/features/map/view/flood_section_label_test.dart';
const String _crueCarte = 'test/features/map/view/map_view_flood_test.dart';
const String _crueLegende = 'test/features/map/view/map_legend_test.dart';
const String _crueFiche =
    'test/features/flood_sheet/view/flood_sheet_panel_test.dart';
const String _crueEncart =
    'test/features/flood_sheet/view/flood_warning_card_test.dart';
const String _crueFicheViewModel =
    'test/features/flood_sheet/view_model/flood_sheet_view_model_test.dart';
const String _crueJauge = 'test/features/shared/flood_level_gauge_test.dart';
const String _crueStyle = 'test/features/shared/flood_level_style_test.dart';
const String _crueTextes = 'test/domain/warnings/warning_texts_test.dart';

/// Les deux lignes que T2 ne livre PAS : la carte hors ligne (`US-10`,
/// `UC-005`) n'est couverte qu'en partie (le cache de tuiles de `flutter_map`
/// sur les zones déjà parcourues). Sans ce garde-fou, rien n'interdit de les
/// passer à ✅ : les exceptions de T1 qui les protégeaient ont disparu avec
/// `Task X2`. Elles gardent 🔄 tant que la persistance de `DerniereVueCarte`,
/// le bandeau « Mode hors-ligne » et la désactivation du rafraîchissement
/// (`UC-005` flux nominal, étapes 1, 4 et 6) ne sont pas livrés ET couverts
/// par un test — ce qui exige le moteur de stockage structuré qu'`ADR-011`
/// laisse ouvert jusqu'au hors-ligne (arbitrage 2 du cadrage de T3 : T3 range
/// les favoris dans `shared_preferences` et ne tranche pas ce moteur). Le jour
/// où ils le sont, ce test et cette liste se retirent ensemble, dans le commit
/// qui passe les deux lignes à ✅.
const List<String> _lignesPartielles = <String>['US-10', 'UC-005'];

/// Les fichiers qu'une ligne DOIT citer parce que T2 les a écrits pour elle
/// (`Task X2` du plan T2 : « écran, encart, ViewModel, source, mapper,
/// équivalence » ; `BR-011` cite aussi le mapper ; `US-01` cite l'écran des
/// sources) ou parce qu'un ajout de T2 touche la règle (le choix
/// « Restrictions » du sélecteur de la carte, `E5` et `E5b`) — ou, depuis la
/// `Task X2` du plan T3, parce que T3 les a écrits pour `US-13`, `US-14`,
/// `UC-007`, `UC-008` ou parce qu'un ajout de T3 touche `BR-007`, `BR-008`,
/// `BR-009` ou `BR-011` (avis de carte vidée, liste de favoris vide ou
/// illisible, échelle du filtre, pastilles sous filtre, entrée non lisible,
/// `Inconnu`). Le test ne juge pas la justesse de l'intention : il refuse
/// qu'une ligne en omette un.
const Map<String, List<String>> _citationsExigees = <String, List<String>>{
  'US-01': <String>['test/features/shared/data_sources_view_test.dart'],
  'US-02': <String>[_invariantsDisposition],
  'US-07': <String>[
    _ecranRestrictions,
    _viewModelRestrictions,
    _sourceVigieau,
    _mapperZones,
    _equivalenceProfil,
    _designationCarte,
    _designationReticule,
    _boutonDesignation,
    _selecteurLecture,
    _invariantsDisposition,
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
  'US-13': <String>[
    _filtreDomaine,
    _filtrePredicats,
    _filtreEchelle,
    _filtreViewModel,
    _filtreFeuille,
    _filtreBoutons,
    _filtreCablage,
    _avisCarteVide,
  ],
  'US-14': <String>[
    _favoriDomaine,
    _favoriContrat,
    _favoriEtoileEtat,
    _favoriCodec,
    _favoriStockage,
    _favoriEtoileBouton,
    _favoriFicheStation,
    _favoriFicheOnde,
    _favoriViewModel,
    _favoriEcran,
    _racine,
  ],
  'UC-007': <String>[
    _filtrePredicats,
    _filtreViewModel,
    _filtreFeuille,
    _filtreCablage,
    _avisCarteVide,
  ],
  'UC-008': <String>[_favoriStockage, _favoriViewModel, _favoriEcran, _racine],
  // `BR-007` : l'avis d'une carte que le filtre a vidée (T3), la liste de
  // favoris vide ou illisible (T3).
  'BR-007': <String>[_avisCarteVide, _favoriEcran],
  'BR-008': <String>[
    _selecteurLecture,
    _designationCarte,
    _invariantsDisposition,
    _filtreEchelle,
  ],
  // `BR-009` : les pastilles sous filtre (T3).
  'BR-009': <String>[_filtreViewModel],
  'BR-011': <String>[
    _mapperZones,
    _favoriCodec,
    _filtrePredicats,
    _crueNiveauDomaine,
    _crueMapper,
  ],
  'BR-012': <String>[
    'test/features/shared/data_sources_view_test.dart',
    'test/main_test.dart',
  ],
  'BR-013': <String>[
    _encartRenforce,
    _ecranRestrictions,
    'test/domain/warnings/warning_texts_test.dart',
  ],
  // T4 : la vigilance crues relayée (`US-21`, `UC-009`, `BR-015`).
  'US-21': <String>[
    _crueNiveauDomaine,
    _crueTronconDomaine,
    _crueReglesTroncon,
    _crueDefinitions,
    _crueConfinement,
    _crueEtiquette,
    _crueJauge,
    _crueStyle,
    _crueCarteDomaine,
    _crueMapper,
    _crueSource,
    _crueCache,
    _crueViewModelCarte,
    _crueCalque,
    _crueCarte,
    _crueLegende,
    _crueFiche,
    _crueEncart,
    _crueFicheViewModel,
    _crueTextes,
    _racine,
  ],
  'UC-009': <String>[
    _crueMapper,
    _crueCache,
    _crueViewModelCarte,
    _crueCarte,
    _crueFiche,
    _crueFicheViewModel,
    _racine,
  ],
  'BR-015': <String>[_crueTextes, _crueEncart, _crueFiche],
  'BR-001': <String>[_crueMapper, _crueLegende],
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

  group('Chaque BR-001 à BR-016 apparaît au moins une fois', () {
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

  group('Chaque UC-001 à UC-010 apparaît au moins une fois', () {
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

  group('Les user stories Should livrées par T3 (Task X2 du plan T3)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String id in _usShouldLivreesEnT3) {
      test('$id porte l\'état ✅ T3, sans 🔄, et cite au moins un fichier '
          'de test', () {
        final List<String>? ligne = _ligneDe(lignes, id);
        expect(ligne, isNotNull, reason: '$id doit avoir une ligne');
        final String etat = ligne!.last;
        expect(
          etat.contains('✅ T3'),
          isTrue,
          reason: '$id doit porter l\'état ✅ T3 : "$etat"',
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
          reason: '$id doit citer au moins un fichier de test',
        );
      });
    }
  });

  group('Les lignes que T4 livre (Task X1 du plan T4)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String id in _lignesLivreesEnT4) {
      test('$id porte l\'état ✅ T4, sans 🔄, et cite au moins un fichier '
          'de test', () {
        final List<String>? ligne = _ligneDe(lignes, id);
        expect(ligne, isNotNull, reason: '$id doit avoir une ligne');
        final String etat = ligne!.last;
        expect(
          etat.contains('✅ T4'),
          isTrue,
          reason: '$id doit porter l\'état ✅ T4 : "$etat"',
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
          reason: '$id doit citer au moins un fichier de test',
        );
      });
    }

    test('US-21 est rangée dans la section des user stories Should', () {
      final int should = contenu.indexOf('## User stories Should suivies');
      final int br = contenu.indexOf('## Règles métier');
      final int us21 = contenu.indexOf('| US-21 |');
      expect(should, isNonNegative);
      expect(us21, greaterThan(should));
      expect(us21, lessThan(br));
    });
  });

  // `O4` de T5 : `US-22` et `UC-010` sont écrites, pas livrées. Elles portent
  // 🔄 T5 et ne citent aucun fichier de test tant qu'il n'existe pas ; `X1` du
  // plan de T5 les passe à ✅ T5 et retire ce groupe avec cette marque.
  group('Les lignes que T5 ouvre, pas encore livrées (O4 du plan de T5)', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final String id in _lignesOuvertesEnT5) {
      test('$id porte l\'état 🔄 T5, jamais ✅, et ne cite aucun fichier de '
          'test', () {
        final List<String>? ligne = _ligneDe(lignes, id);
        expect(ligne, isNotNull, reason: '$id doit avoir une ligne');
        final String etat = ligne!.last;
        expect(
          etat.contains('🔄') && etat.contains('T5'),
          isTrue,
          reason: '$id doit porter l\'état 🔄 T5 : "$etat"',
        );
        expect(
          etat.contains('✅'),
          isFalse,
          reason: '$id n\'est pas livrée : jamais ✅ avant X1 : "$etat"',
        );
        expect(
          _cheminsDart(_celluleFichier(id, ligne)),
          isEmpty,
          reason: '$id ne cite aucun chemin de test tant qu\'il n\'existe pas',
        );
      });
    }

    test('US-22 est rangée dans la section des user stories Should', () {
      final int should = contenu.indexOf('## User stories Should');
      final int br = contenu.indexOf('## Règles métier');
      final int us22 = contenu.indexOf('| US-22 |');
      expect(should, isNonNegative);
      expect(us22, greaterThan(should));
      expect(us22, lessThan(br));
    });
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
              'garde 🔄 jusqu\'à la persistance de DerniereVueCarte et au '
              'bandeau hors-ligne : "$etat"',
        );
        expect(
          etat.contains('✅'),
          isFalse,
          reason: '$id ne compte pas un acquis partiel comme un ✅ : "$etat"',
        );
      });
    }
  });

  group('Les lignes touchées par T2 et T3 citent les fichiers qui les '
      'éprouvent', () {
    final List<List<String>> lignes = _lignesDuTableau(contenu);

    for (final MapEntry<String, List<String>> exigence
        in _citationsExigees.entries) {
      test(
        '${exigence.key} cite ${exigence.value.length} fichier(s) exigé(s)',
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

// Vérifie la forme des critères d'acceptation Gherkin de `docs/acceptance/`
// (`Task X1` du plan T1, révision du 2026-09-22, puis `Task X1` du plan T2,
// 2026-10-04). Aucun framework BDD n'est introduit (décision 6 du plan T1,
// décision 9 du plan T2) : ces `.feature` sont de la SPÉCIFICATION LISIBLE,
// jamais exécutée — ce test-ci vérifie seulement qu'ils sont bien formés,
// qu'ils citent une règle métier qui EXISTE réellement sur le disque, et que
// les libellés d'écran PORTÉS PAR UNE CONSTANTE du code (listés plus bas, par
// leur nom) y figurent tels quels, entre guillemets français. Un `BR-099`
// inventé doit rendre ce test rouge : c'est la contre-épreuve de l'étape 4 du
// plan T1.
//
// ⚠️ Limite : les autres phrases d'écran citées par les `.feature` (la plupart
// des textes de `restrictions_screen.dart`) sont écrites en dur dans les vues,
// sans constante. Elles ont été comparées au code à l'écriture (2026-10-04) ;
// rien ne les verrouille, et un mot changé dans une vue ne rougit pas ce test.
//
// dart:io est autorisé ici (test/project/), jamais sous lib/domain/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';

/// Les cinq fichiers attendus sous `docs/acceptance/` : les quatre de T1
/// (`Task X1` du plan T1) et `restrictions.feature` (`Task X1` du plan T2).
const List<String> _featureFiles = <String>[
  'avertissements.feature',
  'fraicheur-d-une-mesure.feature',
  'fiche-station.feature',
  'ecoulement-onde.feature',
  'restrictions.feature',
];

/// Les règles métier que les cinq fichiers doivent couvrir AU MINIMUM,
/// ensemble (`Task X1` : « la liste est dans le test, pas seulement dans une
/// intention »). `BR-013` (l'encart renforcé) y entre avec l'écran des
/// restrictions de T2 ; l'affirmation inverse, valable en T1 (aucun écran de
/// ressource), est remplacée par [_restrictionsRules].
const List<String> _minimumCoveredRules = <String>[
  'BR-005',
  'BR-006',
  'BR-007',
  'BR-010',
  'BR-012',
  'BR-013',
];

/// Les règles que `restrictions.feature` doit citer, chacune par au moins un
/// SCÉNARIO (jamais seulement par son en-tête) : l'encart renforcé, l'absence
/// de donnée, la nomenclature inconnue, la citation sans verbe d'instruction.
const List<String> _restrictionsRules = <String>[
  'BR-013',
  'BR-007',
  'BR-011',
  'BR-014',
];

/// Les trois user stories de T2 que `restrictions.feature` met en scénarios.
const List<String> _restrictionsStories = <String>['US-09', 'US-07', 'US-08'];

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

/// Le début d'un scénario : `Scénario:` ou `Plan du scénario:`, en début de
/// ligne seulement — un commentaire (`# … Scénario …`) ou une phrase qui
/// contient le mot ne découpe rien.
final RegExp _scenarioStart = RegExp(
  r'^[ \t]*(?:Plan du [Ss]cénario|Scénario)[ \t]*:',
  multiLine: true,
);

/// Découpe le contenu d'un `.feature` en ses scénarios (chacun commençant par
/// `Scénario:` ou `Plan du scénario:`), le préambule avant le premier étant
/// ignoré (c'est l'en-tête `Fonctionnalité:`).
List<String> _scenariosOf(String contenu) {
  final List<RegExpMatch> debuts = _scenarioStart.allMatches(contenu).toList();
  return <String>[
    for (int i = 0; i < debuts.length; i++)
      contenu.substring(
        debuts[i].start,
        i + 1 < debuts.length ? debuts[i + 1].start : contenu.length,
      ),
  ];
}

/// Le marqueur de section d'une user story : `# ── US-07 — …`.
final RegExp _storyMarker = RegExp(
  r'^[ \t]*#[ \t]*─+[ \t]*(US-\d{2})\b',
  multiLine: true,
);

/// Le nombre de SCÉNARIOS que `contenu` range sous chaque marqueur de user
/// story : un marqueur sans scénario sous lui ne compte pas (une section
/// vidée de ses scénarios mais dont le commentaire reste doit rougir).
Map<String, int> _scenariosByStory(String contenu) {
  final List<RegExpMatch> marqueurs = _storyMarker.allMatches(contenu).toList();
  final Map<String, int> parHistoire = <String, int>{};
  for (int i = 0; i < marqueurs.length; i++) {
    final String histoire = marqueurs[i].group(1)!;
    final String section = contenu.substring(
      marqueurs[i].start,
      i + 1 < marqueurs.length ? marqueurs[i + 1].start : contenu.length,
    );
    parHistoire[histoire] =
        (parHistoire[histoire] ?? 0) + _scenariosOf(section).length;
  }
  return parHistoire;
}

/// Vrai si [libelle] figure dans [texte] entre guillemets français, `« … »`
/// — pas seulement comme sous-chaîne : un libellé raccourci dans le code, ou
/// une puce renommée dans le `.feature`, ne doit pas rester vert parce que
/// l'ancien libellé (court) est inclus dans le nouveau (long).
bool _containsQuoted(String texte, String libelle) =>
    texte.contains('« $libelle »');

/// Vrai si [mot] figure dans [texte] délimité des deux côtés : ni lettre ni
/// chiffre ni `/` collés à lui. Pour les libellés qui ne sont jamais cités
/// entre guillemets seuls (le nom de la source, son adresse).
bool _containsDelimited(String texte, String mot) => RegExp(
  '(?<![\\p{L}\\p{N}/])${RegExp.escape(mot)}(?![\\p{L}\\p{N}/])',
  unicode: true,
).hasMatch(texte);

void main() {
  final Directory dossierAcceptance = Directory('docs/acceptance');

  test('le dossier docs/acceptance existe', () {
    expect(
      dossierAcceptance.existsSync(),
      isTrue,
      reason:
          'docs/acceptance/ doit exister avec les cinq .feature de Task X1 '
          '(quatre en T1, restrictions.feature en T2)',
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

  test('les cinq fichiers couvrent ensemble BR-005, BR-006, BR-007, BR-010, BR-012, BR-013', () {
    final String tout = contenusParFichier.values.join('\n');
    for (final String regle in _minimumCoveredRules) {
      expect(
        tout.contains(regle),
        isTrue,
        reason: '$regle doit être citée par au moins un des cinq .feature',
      );
    }
  });

  // Remplace « aucun .feature ne décrit BR-013 », vrai en T1 faute d'écran de
  // ressource (décision 11, révision du plan T1 du 2026-09-22) : l'écran des
  // restrictions de T2 en est un.
  test('restrictions.feature cite BR-013, BR-007, BR-011, BR-014, chacune '
      'par un scénario', () {
    final String contenu = contenusParFichier['restrictions.feature'] ?? '';
    final List<String> scenarios = _scenariosOf(contenu);
    expect(scenarios, isNotEmpty);
    for (final String regle in _restrictionsRules) {
      expect(
        scenarios.any((String scenario) => scenario.contains(regle)),
        isTrue,
        reason: 'aucun scénario de restrictions.feature ne cite $regle',
      );
    }
  });

  // Le comptage se fait par SECTION (`# ── US-xx`) et par scénario : nommer une
  // user story dans l'en-tête, ou laisser le commentaire d'une section dont les
  // scénarios ont été retirés, ne suffit pas.
  test('restrictions.feature met en scénarios US-09, US-07 et US-08', () {
    final String contenu = contenusParFichier['restrictions.feature'] ?? '';
    final Map<String, int> parHistoire = _scenariosByStory(contenu);
    for (final String histoire in _restrictionsStories) {
      expect(
        parHistoire[histoire] ?? 0,
        greaterThan(0),
        reason:
            'aucun scénario de restrictions.feature sous la section $histoire',
      );
    }
  });

  // Un plan du scénario (`Plan du scénario:` + `Exemples:`) est un seul
  // scénario écrit une fois pour plusieurs cas : chaque `<paramètre>` de ses
  // étapes doit être une colonne du tableau, et chaque ligne doit avoir autant
  // de cellules que l'en-tête. Sans cela, un paramètre mal orthographié
  // laisserait un texte à trous dans la spécification.
  group('les plans du scénario sont complets', () {
    for (final String nom in _featureFiles) {
      test('chaque plan de $nom a un tableau d\'exemples qui le remplit', () {
        final List<String> plans = _scenariosOf(contenusParFichier[nom] ?? '')
            .where((String s) => s.trimLeft().startsWith('Plan du'))
            .toList();
        for (final String plan in plans) {
          final int exemples = plan.indexOf('Exemples:');
          expect(
            exemples,
            greaterThan(0),
            reason: 'un plan de $nom sans "Exemples:" : $plan',
          );
          final List<String> lignes = plan
              .substring(exemples)
              .split('\n')
              .map((String l) => l.trim())
              .where((String l) => l.startsWith('|'))
              .toList();
          expect(
            lignes.length,
            greaterThanOrEqualTo(2),
            reason: 'un plan de $nom sans ligne d\'exemple : $plan',
          );
          List<String> cellules(String ligne) =>
              ligne.split('|').map((String c) => c.trim()).skip(1).toList()
                ..removeLast();
          final List<String> colonnes = cellules(lignes.first);
          for (final String ligne in lignes.skip(1)) {
            expect(
              cellules(ligne).length,
              colonnes.length,
              reason:
                  'ligne d\'exemple de $nom sans ses ${colonnes.length} '
                  'cellules : $ligne',
            );
          }
          final Set<String> parametres = RegExp(r'<([^>\n]+)>')
              .allMatches(plan.substring(0, exemples))
              .map((RegExpMatch m) => m.group(1)!)
              .toSet();
          for (final String parametre in parametres) {
            expect(
              colonnes,
              contains(parametre),
              reason:
                  '<$parametre> n\'est pas une colonne des exemples de $nom',
            );
          }
        }
      });
    }

    // Les quatre causes d'échec de la source des restrictions (§ 5.3 de la
    // conception, `Q-5d`) tiennent en UN plan à quatre exemples : retirer une
    // ligne perd une cause sans que rien d'autre ne rougisse.
    test('restrictions.feature : le plan des échecs a une ligne par cause', () {
      final List<String> plans =
          _scenariosOf(contenusParFichier['restrictions.feature'] ?? '')
              .where(
                (String s) =>
                    s.trimLeft().startsWith('Plan du') &&
                    s.contains('Réessayer'),
              )
              .toList();
      expect(plans, hasLength(1), reason: 'un seul plan des échecs attendu');
      final int lignes = plans.single
          .split('\n')
          .where((String l) => l.trim().startsWith('|'))
          .length;
      expect(
        lignes,
        5,
        reason:
            'l\'en-tête plus quatre causes : source injoignable, réponse '
            'illisible, requête refusée, échec que la source n\'a pas levé',
      );
    });
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

  test('avertissements.feature porte un scénario par emplacement de 04-ui.md § 5 (W3c, T2)', () {
    final String contenu = contenusParFichier['avertissements.feature'] ?? '';
    final List<String> scenarios = _scenariosOf(contenu);
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
    // Emplacement 4 (T2) : l'encart renforcé de l'écran des restrictions,
    // affiché d'emblée, non repliable, en tête d'écran (BR-013).
    expect(
      scenarios.any(
        (String s) =>
            s.contains('encart renforcé') &&
            s.contains('non repliable') &&
            s.contains('BR-013'),
      ),
      isTrue,
      reason: 'aucun scénario ne décrit le quatrième emplacement (BR-013)',
    );
  });

  test('avertissements.feature porte les deux scénarios du détail des sources '
      '(US-01, BR-012)', () {
    final String contenu = contenusParFichier['avertissements.feature'] ?? '';
    final List<String> scenarios = _scenariosOf(contenu);
    // Depuis le modal du premier lancement, sans acquitter.
    expect(
      scenarios.any(
        (String s) =>
            _containsQuoted(s, initialWarningSourcesLinkLabel) &&
            s.contains('BR-012'),
      ),
      isTrue,
      reason: 'aucun scénario ne porte « $initialWarningSourcesLinkLabel »',
    );
    // Après l'acquittement, depuis la fenêtre « ⚠ Avertissement » : un AUTRE
    // scénario. Celui du modal cite aussi l'écran « D'où vient cette donnée ? »
    // (il le lit avant de revenir) : sans cette exclusion, supprimer le second
    // scénario laisserait ce test vert.
    expect(
      scenarios.any(
        (String s) =>
            _containsQuoted(s, dataSourcesTitle) &&
            _containsQuoted(s, '⚠ $warningLinkLabel') &&
            !_containsQuoted(s, initialWarningSourcesLinkLabel) &&
            s.contains('BR-012'),
      ),
      isTrue,
      reason:
          'aucun scénario distinct de celui du modal ne porte '
          '« $dataSourcesTitle » depuis « ⚠ $warningLinkLabel »',
    );
  });

  // Les .feature ne sont jamais exécutés : rien ne les lie au code. Ce test
  // est ce lien, pour les SEULS libellés portés par une constante ou une
  // fonction de libellé du code, lus ici et jamais recopiés : si le code en
  // change un, ce test rougit et le critère d'acceptation se met à jour avec
  // lui. Les libellés d'écran écrits en dur dans les vues (« VigiEau n'a pas
  // répondu… », « Ouvrir l'arrêté », « Réessayer »…) n'ont pas de constante :
  // ils ne sont PAS liés ici (voir l'en-tête du fichier).
  //
  // Chaque libellé est cherché entre guillemets français, `« libellé »` :
  // un libellé raccourci dans le code, ou renommé dans le `.feature`, ne reste
  // pas vert parce que l'ancien libellé est inclus dans le nouveau. Le nom de
  // la source et son adresse, jamais cités seuls entre guillemets, sont
  // cherchés délimités ([_containsDelimited]).
  group('les libellés portés par une constante du code figurent dans les .feature de T2', () {
    final String restrictions =
        contenusParFichier['restrictions.feature'] ?? '';
    final String avertissements =
        contenusParFichier['avertissements.feature'] ?? '';

    final Map<String, String> libellesRestrictions = <String, String>{
      'titre de l\'écran': restrictionsScreenTitle,
      'titre de l\'encart renforcé': reinforcedWarningHeadline,
      'action de l\'encart renforcé': reinforcedWarningActionLabel,
      'phrase de BR-007': restrictionsNoDecreeMeaningText,
      'choix « Restrictions » du sélecteur': designationChipLabel,
      'bouton de désignation': designateCenterLabel,
      'échelle écoulement': mapScaleLabel(MapScaleKind.ecoulement),
      'échelle débit': mapScaleLabel(MapScaleKind.debit),
      'niveau Vigilance': droughtSeverityLabel(const Vigilance()),
      'niveau Alerte': droughtSeverityLabel(const Alerte()),
      'niveau Alerte renforcée': droughtSeverityLabel(const AlerteRenforcee()),
      'niveau Crise': droughtSeverityLabel(const Crise()),
      'niveau inconnu': droughtSeverityLabel(const GraviteInconnue(null)),
      'type Eaux superficielles': zoneKindLabel(const EauxSuperficielles()),
      'type Eaux souterraines': zoneKindLabel(const EauxSouterraines()),
      'type Eau potable': zoneKindLabel(const EauPotable()),
      'type inconnu': zoneKindLabel(const TypeZoneInconnu(null)),
      for (final UserProfile profil in UserProfile.values)
        'profil ${profil.name}': userProfileLabel(profil),
    };
    for (final MapEntry<String, String> libelle
        in libellesRestrictions.entries) {
      test('restrictions.feature cite « ${libelle.value} » '
          '(${libelle.key})', () {
        expect(
          _containsQuoted(restrictions, libelle.value),
          isTrue,
          reason:
              'restrictions.feature ne contient pas « ${libelle.value} », '
              'le libellé du code pour ${libelle.key}',
        );
      });
    }

    final Map<String, String> motsDelimites = <String, String>{
      'nom de la source': restrictionsSourceName,
      'adresse du site public': restrictionsPublicSiteUrl,
    };
    for (final MapEntry<String, String> mot in motsDelimites.entries) {
      test('restrictions.feature cite ${mot.value} (${mot.key})', () {
        expect(
          _containsDelimited(restrictions, mot.value),
          isTrue,
          reason:
              'restrictions.feature ne contient pas ${mot.value}, '
              'la valeur du code pour ${mot.key}',
        );
      });
    }

    final Map<String, String> libellesAvertissements = <String, String>{
      'bouton d\'acquittement': initialWarningButtonLabel,
      'lien du modal vers les sources': initialWarningSourcesLinkLabel,
      'titre de l\'écran des sources et lien de la fenêtre': dataSourcesTitle,
      // Le contrôle porte une icône d'avertissement devant son libellé : les
      // `.feature` l'écrivent « ⚠ Avertissement », comme `04-ui.md`.
      'contrôle d\'avertissement': '⚠ $warningLinkLabel',
      'titre de l\'encart renforcé': reinforcedWarningHeadline,
    };
    for (final MapEntry<String, String> libelle
        in libellesAvertissements.entries) {
      test('avertissements.feature cite « ${libelle.value} » '
          '(${libelle.key})', () {
        expect(
          _containsQuoted(avertissements, libelle.value),
          isTrue,
          reason:
              'avertissements.feature ne contient pas « ${libelle.value} », '
              'le libellé du code pour ${libelle.key}',
        );
      });
    }
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

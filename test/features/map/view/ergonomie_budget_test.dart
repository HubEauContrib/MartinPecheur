// La porte de faisabilité de l'arbitrage 11 (`S6` d'Ergonomie, spec § 5.6) :
// avant de construire la mise en page (`D1`, `D2`), chaque vraie pièce livrée
// par `S1` à `S4` est mesurée en ROBOTO (`chargerRoboto`), et ses hauteurs
// passent à la même fonction pure que la carte appellera, `allocateMapLayout`
// (`S5`). Aux quatre tailles garanties, aux deux échelles de texte, sur les
// trois lectures, hors mode et en mode, sans fiche et avec chacune des deux
// fiches, sans avis et avec l'avis d'absence, sans marge et — au téléphone —
// avec la marge système : rien de ce qui ne cède jamais ne déborde
// (`overflows` faux).
//
// Deux arbitrages du commanditaire (2026-10-18), pris sur la première mesure :
// - 13 : à 360 × 640 et 200 %, là où l'ordre de repli ne suffit pas, la partie
//   fixe du bloc DÉFILE, comme en deçà — aucun nouveau repli. Là seulement,
//   `overflows` est accepté ; le cas vérifie alors qu'aucune hauteur allouée
//   n'est négative et que la somme posée, écarts compris, vaut exactement la
//   hauteur disponible (la partie fixe reçoit ce qui reste) ;
// - 14 : le repli 6 s'étend au-delà du téléphone — en mode, fiche ouverte, une
//   bande du bouton qui ne tient pas en largeur à côté de la colonne du bas se
//   retire avec le réticule (`bandFits` faux, 800 × 740 à 200 %, panneau).
// Partout ailleurs, un `overflows` vrai est ROUGE et ne s'assouplit pas : arrêt
// et question au commanditaire, avec le tableau des hauteurs
// (`.superpowers/sdd/2026-10-17-ergonomie/task-S6-mesures.md`).
//
// Le titre de chaque cas nomme les replis joués et dit s'il tient ou si le
// bloc défile, tels que relevés dans le fichier de données
// `ergonomie_replis_releves.dart` : le cas AFFIRME que la répartition rend
// exactement cela. Une pièce qui change de hauteur au point de changer les
// replis d'une configuration fait donc rougir ce fichier, au lieu de laisser
// un titre faux. Le relevé se régénère par
// `--dart-define=RELEVER_REPLIS=true` (commande : en tête du fichier de
// données) et son diff se relit, avec le tableau, dans le commit qui le
// change.
import 'dart:io' show Directory, File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart' show EdgeInsets, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_mesures.dart';
import '../../../support/layout_sizes.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';
import 'ergonomie_replis_releves.dart';

String _nomLecture(MapScaleKind lecture) => switch (lecture) {
  MapScaleKind.ecoulement => 'écoulement',
  MapScaleKind.debit => 'débit',
  MapScaleKind.crues => 'crues',
};

String _nomFiche(({String nature, bool etoile})? fiche) => fiche == null
    ? 'sans fiche'
    : fiche.etoile
    ? 'fiche station'
    : 'fiche tronçon';

String _nomReplis(List<int> replis) =>
    replis.isEmpty ? 'aucun repli' : 'replis ${replis.join(', ')}';

/// L'arbitrage 13 : la seule taille et la seule échelle où la partie fixe du
/// bloc peut défiler.
bool _defileAccepte(Size taille, double echelle) =>
    taille == const Size(360, 640) && echelle == 2;

/// Ce que dit le titre d'un cas : ses replis, puis s'il tient ou si le bloc
/// défile.
String _issue(MapLayoutAllocation repartition) =>
    '${_nomReplis(repartition.folds)} — '
    '${repartition.overflows ? 'le bloc défile (arbitrage 13)' : 'tient'}';

/// La hauteur que la répartition pose, écarts compris — la même règle que
/// `allocateMapLayout` : un écart entre deux groupes consécutifs non nuls,
/// aucun de part et d'autre de la bande du réticule ; en compact, la bande et
/// la rangée séparées d'un écart ; au-delà, la zone du bas est la plus haute
/// de la bande et du bas (s'il passe sous le bloc) ; en panneau, la fiche est
/// à côté.
///
/// Un ORACLE écrit à part de `_Stack.total` (`map_layout_allocation.dart`), sur
/// la même règle : une même erreur dans les deux passerait inaperçue. Le vrai
/// oracle sera la pose de `D1` (`RenderMapLayout`), qui pose les pièces aux
/// hauteurs allouées et dont la somme se mesure à l'écran.
double _hauteurPosee(MapLayoutInput entree, MapLayoutAllocation repartition) {
  final bool compact = switch (entree.width) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  };
  final double bas = compact || entree.blockOverBottom ? entree.bottom : 0;
  final double zoneDuBas = compact
      ? repartition.band +
            bas +
            (repartition.band > 0 && bas > 0 ? entree.gap : 0)
      : math.max(repartition.band, bas);
  final double fiche = switch (entree.width) {
    MapLayoutWidth.compact || MapLayoutWidth.wide => repartition.sheet,
    MapLayoutWidth.panel => 0,
  };
  double somme = 0;
  bool apresUnGroupe = false;
  bool apresLeReticule = false;
  for (final (double hauteur, bool reticule) in <(double, bool)>[
    (repartition.blockFixed + repartition.notices + repartition.legend, false),
    (repartition.reticleBand, true),
    (zoneDuBas, false),
    (fiche, false),
  ]) {
    if (hauteur <= 0) continue;
    if (apresUnGroupe && !apresLeReticule && !reticule) somme += entree.gap;
    somme += hauteur;
    apresUnGroupe = true;
    apresLeReticule = reticule;
  }
  return somme;
}

/// Le chemin de régénération de [replisReleves] : avec
/// `--dart-define=RELEVER_REPLIS=true`, aucun cas n'affirme ses replis ; chacun
/// note ce qu'il rend, et la table complète s'écrit dans [_cheminDuReleve] à la
/// fin du fichier (commande : `ergonomie_replis_releves.dart`).
const bool _relever = bool.fromEnvironment('RELEVER_REPLIS');

/// Où la régénération écrit la table, sous `build/` (ignoré par git).
const String _cheminDuReleve = 'build/ergonomie_replis_releves.dart';

/// Ce que chaque cas a rendu, dans l'ordre de déclaration, en régénération.
final Map<String, String> _nouveauReleve = <String, String>{};

/// L'en-tête du fichier de données, recopié tel quel à chaque régénération.
const String _enteteDuReleve = '''
// Les replis relevés de la porte de faisabilité (`S6` d'Ergonomie) : pour
// chaque configuration de `ergonomie_budget_test.dart`, ce que
// `allocateMapLayout` rend sur les mesures de `mesurerPieces` — les replis en
// vigueur, puis « tient » ou « le bloc défile (arbitrage 13) ». Chaque cas
// AFFIRME sa ligne, et son titre la nomme : une pièce qui change de hauteur au
// point de changer les replis d'une configuration fait rougir le test.
//
// FICHIER GÉNÉRÉ — ne pas éditer à la main. Pour le régénérer, depuis la racine
// du dépôt :
//
//   flutter test --dart-define=RELEVER_REPLIS=true test/features/map/view/ergonomie_budget_test.dart
//   cp build/ergonomie_replis_releves.dart test/features/map/view/
//   dart format test/features/map/view/ergonomie_replis_releves.dart
//
// puis relire le diff dans le commit qui change les hauteurs, avec le tableau
// `.superpowers/sdd/2026-10-17-ergonomie/task-S6-mesures.md`.
''';

/// Le fichier de données [replisReleves], dans sa syntaxe Dart : l'en-tête,
/// puis une entrée par configuration. À passer par `dart format` une fois
/// recopié.
String _fichierDuReleve(Map<String, String> releve) {
  final StringBuffer texte = StringBuffer()
    ..writeln(_enteteDuReleve)
    ..writeln('const Map<String, String> replisReleves = <String, String>{');
  for (final MapEntry<String, String> entree in releve.entries) {
    texte.writeln("  '${entree.key}': '${entree.value}',");
  }
  texte.writeln('};');
  return texte.toString();
}

void main() {
  setUpAll(chargerRoboto);
  if (_relever) {
    tearDownAll(() {
      Directory('build').createSync(recursive: true);
      File(_cheminDuReleve).writeAsStringSync(_fichierDuReleve(_nouveauReleve));
    });
  }

  for (final ({String nom, Size taille, TargetPlatform plateforme}) garantie
      in taillesGaranties) {
    final bool telephone = switch (garantie.plateforme) {
      TargetPlatform.android => true,
      TargetPlatform.windows ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => false,
    };
    final void Function(String, Future<void> Function(WidgetTester))
    testSurLaPlateforme = telephone
        ? testWidgetsOnAndroid
        : testWidgetsOnWindows;
    for (final double echelle in echellesDeTexte) {
      final bool defileAccepte = _defileAccepte(garantie.taille, echelle);
      for (final MapScaleKind lecture in MapScaleKind.values) {
        for (final bool enMode in <bool>[false, true]) {
          for (final ({String nature, bool etoile})? fiche
              in <({String nature, bool etoile})?>[
                null,
                ficheStation,
                ficheTroncon,
              ]) {
            for (final bool avecAvis in <bool>[false, true]) {
              for (final EdgeInsets marge in <EdgeInsets>[
                EdgeInsets.zero,
                if (telephone) margeSystemeTelephone,
              ]) {
                final String configuration =
                    '${garantie.nom}, ${(echelle * 100).round()} %, '
                    '${_nomLecture(lecture)}, '
                    '${enMode ? 'en mode' : 'hors mode'}, '
                    '${_nomFiche(fiche)}, '
                    '${avecAvis ? 'avis' : 'sans avis'}, '
                    '${marge == EdgeInsets.zero ? 'sans marge' : 'marge'}';
                final String? releve = replisReleves[configuration];
                testSurLaPlateforme(
                  '${telephone ? 'Android : ' : ''}$configuration : '
                  '${releve ?? 'non relevé'}',
                  (WidgetTester tester) async {
                    final MapLayoutInput entree = await mesurerPieces(
                      tester,
                      taille: garantie.taille,
                      echelle: echelle,
                      lecture: lecture,
                      enMode: enMode,
                      fiche: fiche,
                      avecAvis: avecAvis,
                      marge: marge,
                    );
                    final MapLayoutAllocation repartition = allocateMapLayout(
                      entree,
                    );
                    if (!defileAccepte) {
                      expect(
                        repartition.overflows,
                        isFalse,
                        reason:
                            '$configuration : ce qui ne cède jamais déborde '
                            '($repartition)',
                      );
                    }
                    if (repartition.overflows) {
                      for (final double hauteur in <double>[
                        repartition.blockFixed,
                        repartition.notices,
                        repartition.legend,
                        repartition.sheet,
                        repartition.band,
                        repartition.reticleBand,
                      ]) {
                        expect(hauteur, greaterThanOrEqualTo(0));
                      }
                      expect(
                        _hauteurPosee(entree, repartition),
                        moreOrLessEquals(entree.available, epsilon: 1e-6),
                        reason:
                            '$configuration : le bloc défile dans exactement '
                            'la hauteur disponible',
                      );
                    }
                    if (_relever) {
                      _nouveauReleve[configuration] = _issue(repartition);
                      return;
                    }
                    if (releve == null) {
                      fail('$configuration : aucun relevé dans replisReleves');
                    }
                    expect(
                      _issue(repartition),
                      releve,
                      reason: '$configuration : replis relevés',
                    );
                  },
                );
              }
            }
          }
        }
      }
    }
  }
}

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
// Deux arbitrages de plus, pris sur la mesure de `D7` (2026-10-18) :
// - 18 : fiche du bas ouverte, la fiche garde son en-tête et sa mesure mise en
//   avant ; là où les six replis ne la lui laissent pas, la partie fixe du
//   bloc défile — `overflows` est accepté, à 200 %, partout où la fiche est au
//   bas de l'écran ;
// - 19 : la partie fixe défile jusqu'à son plancher, une cible tactile ; sous
//   ce plancher, le corps cède sous sa mesure mise en avant. À 100 %, seules
//   les 12 configurations de 360 × 640, fiche station (son avis d'échec
//   d'écriture épinglé), sous la marge système, défilent.
// Le cas l'affirme : jamais la partie fixe sous son plancher ; la fiche sous
// sa mesure mise en avant seulement la partie fixe à son plancher. Depuis
// `D7`, la fiche ONDE entre dans la matrice (décision 3 : à 200 %, son
// en-tête et sa mesure mise en avant dépassent ceux de la station).
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
import 'package:flutter/widgets.dart' show EdgeInsets, Size, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_fiches.dart';
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
    : fiche == ficheStation
    ? 'fiche station'
    : fiche == ficheOnde
    ? 'fiche ONDE'
    : 'fiche tronçon';

/// L'étoile du pire en-tête : vide, en échec d'écriture, son avis épinglé
/// sous elle (spec § 6.1).
const FavoriteStar _etoileEnEchec = FavoriteStar(
  filled: false,
  enabled: true,
  writeFailed: true,
);

String _nomReplis(List<int> replis) =>
    replis.isEmpty ? 'aucun repli' : 'replis ${replis.join(', ')}';

/// La fiche est au bas de l'écran (comptée dans la hauteur), pas en panneau.
bool _ficheDuBas(MapLayoutInput entree) =>
    entree.sheetOpen &&
    switch (entree.width) {
      MapLayoutWidth.compact || MapLayoutWidth.wide => true,
      MapLayoutWidth.panel => false,
    };

/// Où la partie fixe du bloc peut défiler : à 360 × 640 et 200 % (arbitrage
/// 13) ; à 200 %, fiche du bas ouverte (arbitrages 18 et 19) ; à 100 %,
/// seulement à 360 × 640, fiche station au pire en-tête, sous la marge
/// système (arbitrage 19).
bool _defileAccepte(
  Size taille,
  double echelle,
  ({String nature, bool etoile})? fiche,
  EdgeInsets marge,
  MapLayoutInput entree,
) =>
    (taille == const Size(360, 640) && echelle == 2) ||
    (_ficheDuBas(entree) && echelle == 2) ||
    (taille == const Size(360, 640) &&
        echelle == 1 &&
        fiche == ficheStation &&
        marge != EdgeInsets.zero);

/// La fiche du bas est sous sa mesure mise en avant (arbitrage 19).
bool _sousSaMesure(MapLayoutInput entree, MapLayoutAllocation repartition) =>
    _ficheDuBas(entree) && repartition.sheet < entree.sheetFeatured - 1e-6;

/// Ce que dit le titre d'un cas : ses replis, puis s'il tient ou si le bloc
/// défile — et pourquoi.
String _issue(MapLayoutInput entree, MapLayoutAllocation repartition) =>
    '${_nomReplis(repartition.folds)} — '
    '${!repartition.overflows
        ? 'tient'
        : !_ficheDuBas(entree)
        ? 'le bloc défile (arbitrage 13)'
        : _sousSaMesure(entree, repartition)
        ? 'le bloc défile jusqu’à son plancher, la fiche sous sa mesure mise '
              'en avant (arbitrage 19)'
        : 'le bloc défile, la fiche garde sa mesure mise en avant '
              '(arbitrage 18)'}';

/// La hauteur que la répartition pose, écarts compris — la même règle que
/// `allocateMapLayout` : un écart entre deux groupes consécutifs non nuls,
/// aucun de part et d'autre de la bande du réticule ; en compact, la bande et
/// la rangée séparées d'un écart ; au-delà, la zone du bas est la plus haute
/// de la bande et du bas (s'il passe sous le bloc) ; en panneau, la fiche est
/// à côté ; en mode, avec la bande du réticule, la partie variable compte deux
/// fois quand le réticule passe sous le bloc (le réticule au milieu,
/// amendement de `D1`).
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
  final double bas = compact || entree.blockOverBottom ? repartition.bottom : 0;
  final double zoneDuBas = compact
      ? repartition.band +
            bas +
            (repartition.band > 0 && bas > 0 ? entree.gap : 0)
      : math.max(repartition.band, bas);
  final double fiche = switch (entree.width) {
    MapLayoutWidth.compact || MapLayoutWidth.wide => repartition.sheet,
    MapLayoutWidth.panel => 0,
  };
  // En mode, tant que la bande du réticule est là et que le réticule passe
  // sous le bloc en largeur, la partie variable compte
  // deux fois : le réticule est au milieu de [bas de la partie fixe ; haut de
  // la bande], avis et légende au-dessus de sa bande (amendement de `D1`).
  final double poidsVariable =
      entree.designation &&
          entree.reticleUnderBlock &&
          repartition.reticleBand > 0
      ? 2
      : 1;
  double somme = 0;
  bool apresUnGroupe = false;
  bool apresLeReticule = false;
  for (final (double hauteur, bool reticule) in <(double, bool)>[
    (
      repartition.blockFixed +
          poidsVariable * (repartition.notices + repartition.legend),
      false,
    ),
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
// vigueur, puis « tient » ou « le bloc défile » et l'arbitrage qui l'accepte
// (13 ; 18, la fiche garde sa mesure mise en avant ; 19, la partie fixe à son
// plancher, la fiche sous sa mesure). Chaque cas AFFIRME sa ligne, et son
// titre la nomme : une pièce qui change de hauteur au point de changer les
// replis d'une configuration fait rougir le test.
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

  group('la fiche ONDE dans la matrice (décision 3 de D7)', () {
    for (final Size taille in <Size>[
      const Size(360, 640),
      const Size(390, 844),
    ]) {
      testWidgetsOnAndroid('Android : ${taille.width.round()} × '
          '${taille.height.round()}, 200 % — l’en-tête et la mesure mise en '
          'avant de la fiche ONDE dépassent ceux de la station : elle borne la '
          'porte', (WidgetTester tester) async {
        Future<double> vedette(Widget fiche) async => (await poserFiche(
          tester,
          fiche,
          largeur: taille.width,
          echelle: 2,
        )).vedette;

        expect(
          await vedette(ficheOndeChaon(etoile: _etoileEnEchec)),
          greaterThan(await vedette(ficheStationBlois(etoile: _etoileEnEchec))),
        );
      });
    }

    testWidgetsOnAndroid('Android : mesurerPieces honore la nature de la fiche '
        'composée — « Point ONDE » et son corps, pas ceux de la station '
        '(mineur différé de S6)', (WidgetTester tester) async {
      Future<MapLayoutInput> mesure(({String nature, bool etoile}) fiche) =>
          mesurerPieces(
            tester,
            taille: const Size(390, 844),
            echelle: 2,
            lecture: MapScaleKind.ecoulement,
            enMode: false,
            fiche: fiche,
            avecAvis: false,
            marge: EdgeInsets.zero,
          );

      final MapLayoutInput onde = await mesure(ficheOnde);
      expect(find.text(ficheOnde.nature), findsOneWidget);
      expect(find.text(ficheStation.nature), findsNothing);
      final MapLayoutInput station = await mesure(ficheStation);
      expect(find.text(ficheStation.nature), findsOneWidget);
      expect(onde.sheet.max, isNot(moreOrLessEquals(station.sheet.max)));
      expect(
        onde.sheetFeatured,
        isNot(moreOrLessEquals(station.sheetFeatured)),
      );
    });
  });

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
      for (final MapScaleKind lecture in MapScaleKind.values) {
        for (final bool enMode in <bool>[false, true]) {
          for (final ({String nature, bool etoile})? fiche
              in <({String nature, bool etoile})?>[
                null,
                ficheStation,
                ficheTroncon,
                ficheOnde,
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
                      // `D5` : les VRAIES fiches (`F1`, `F3` ; `F2` depuis
                      // `D7`), à l'en-tête le plus haut — l'étoile en échec
                      // d'écriture, son avis épinglé sous elle.
                      ficheReelle: fiche == null
                          ? null
                          : fiche == ficheStation
                          ? ficheStationBlois(etoile: _etoileEnEchec)
                          : fiche == ficheOnde
                          ? ficheOndeChaon(etoile: _etoileEnEchec)
                          : ficheTronconBlavet(),
                      avecAvis: avecAvis,
                      marge: marge,
                    );
                    final MapLayoutAllocation repartition = allocateMapLayout(
                      entree,
                    );
                    if (!_defileAccepte(
                      garantie.taille,
                      echelle,
                      fiche,
                      marge,
                      entree,
                    )) {
                      expect(
                        repartition.overflows,
                        isFalse,
                        reason:
                            '$configuration : ce qui ne cède jamais déborde '
                            '($repartition)',
                      );
                    }
                    // `D8` (relecture, m1) : aux quatre tailles, ni la colonne
                    // ni l'en-tête de la fiche ne cèdent (arbitrages 22 et 24 :
                    // en deçà seulement).
                    expect(
                      repartition.bottom,
                      moreOrLessEquals(entree.bottom.max, epsilon: 1e-6),
                      reason: '$configuration : le bas cède ($repartition)',
                    );
                    if (_ficheDuBas(entree)) {
                      expect(
                        repartition.sheet,
                        greaterThanOrEqualTo(entree.sheet.min - 1e-6),
                        reason:
                            '$configuration : l’en-tête de la fiche cède '
                            '($repartition)',
                      );
                      // Arbitrage 19 : la partie fixe jamais sous son plancher
                      // aux quatre tailles ; la fiche sous sa mesure mise en
                      // avant seulement la partie fixe à son plancher.
                      final double plancher = math.min(
                        entree.blockFixedFloor,
                        entree.blockFixed.min,
                      );
                      expect(
                        repartition.blockFixed,
                        greaterThanOrEqualTo(plancher - 1e-6),
                        reason:
                            '$configuration : la partie fixe sous son '
                            'plancher ($repartition)',
                      );
                      if (_sousSaMesure(entree, repartition)) {
                        expect(
                          repartition.blockFixed,
                          moreOrLessEquals(plancher, epsilon: 1e-6),
                          reason:
                              '$configuration : la fiche sous sa mesure mise '
                              'en avant, la partie fixe au-dessus de son '
                              'plancher ($repartition)',
                        );
                      }
                    }
                    if (repartition.overflows) {
                      // Les hauteurs que `allocateMapLayout` rend, et non des
                      // tailles de boîte : l'assertion n'est pas toujours
                      // vraie (relecture finale de la branche, m5).
                      for (final double hauteur in <double>[
                        repartition.blockFixed,
                        repartition.notices,
                        repartition.legend,
                        repartition.sheet,
                        repartition.band,
                        repartition.reticleBand,
                      ]) {
                        expect(
                          hauteur,
                          greaterThanOrEqualTo(0),
                          reason:
                              '$configuration : une hauteur négative '
                              '($repartition)',
                        );
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
                      _nouveauReleve[configuration] = _issue(
                        entree,
                        repartition,
                      );
                      return;
                    }
                    if (releve == null) {
                      fail('$configuration : aucun relevé dans replisReleves');
                    }
                    expect(
                      _issue(entree, repartition),
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

// Verrouille la legende de la carte (T1-U2). BR-008 en fait une piece
// obligatoire et non une finition : les trois echelles du produit reutilisent
// les memes teintes, et c'est la legende — TOUJOURS visible — qui dit
// laquelle est active. Une legende absente rendrait la carte ambigue.
//
// Trois exigences testees ici :
// - chaque legende NOMME son echelle avec le libelle de `04-ui.md`
//   (`mapScaleLabel`), jamais une reformulation locale ;
// - une legende ne contient JAMAIS un libelle de l'autre echelle (BR-008) ;
// - aucun des cinq mots bannis (BR-003) n'apparait dans un libelle de
//   legende — c'est exactement le texte que l'usager lit pour interpreter un
//   marqueur, donc l'endroit ou « normal » se glisserait.
//
// `S2` d'Ergonomie (cadrage du 2026-10-17) ajoute deux pièces de la nouvelle
// carte, éprouvées seules : l'en-tête « Légende · <lecture> » qui porte
// « ⚠ Avertissement » (`MapLegendHeader`), et la légende du bloc (sans titre,
// sans carte blanche, rangées courtes en colonnes). Ces deux pièces mesurent en
// ROBOTO, chargée depuis le SDK Flutter par `chargerRoboto`
// (`test/support/roboto.dart`) : en police de test, chaque glyphe mesure un
// cadratin et « Avertissement » ne tiendrait jamais à 200 % sur 344 de large.
//
// Depuis la relecture finale de la branche (m1), la légende n'a plus qu'une
// forme, celle du bloc : l'ancienne forme « hors du bloc » (titre, carte
// blanche, 260 de large au plus) n'avait plus d'appelant. Les cas d'avant
// `S2` éprouvent donc la légende du bloc, posée à la largeur du bloc au
// téléphone ; ceux qui lisaient son titre lisent le nom de la lecture là où il
// est désormais, dans l'en-tête, la légende posée dessous.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

/// Largeur du bloc au téléphone : 360 − 2 × 8.
const double _phoneBlockWidth = 344;

/// Les cinq mots proscrits pour qualifier un debit (BR-003, `glossary.md`).
const List<String> bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

/// Les libelles carte de l'echelle 1 — recopies de `04-ui.md` § 2, ligne a
/// ligne, plus « Non renseigne » : sixieme ligne du tableau `U3` du plan T1,
/// portee par le domaine (`flowCategoryLabel`) et DEVIATION d'`ADR-006`, qui
/// range un code inconnu sous « Non observe ». Le test EST la recopie
/// verifiee.
const List<String> libellesEcoulement = <String>[
  'Eau qui coule',
  'Écoulement faible',
  'Eau stagnante',
  'À sec',
  'Non observé',
  'Non renseigné',
];

/// Les libelles propres a la legende « debit » en T1 : le niveau
/// « Indetermine » (BR-004, aucun percentile avant ADR-003) et les cinq
/// rendus de disponibilite que la carte dessine reellement.
const List<String> libellesDebit = <String>[
  'Indéterminé',
  'Pas assez de mesures passées à cette station pour situer la valeur '
      "d'aujourd'hui.",
  'Mesure récente',
  'Dernière mesure il y a plus de 2 h',
  'Dernière mesure il y a plus de 24 h',
  'Aucune donnée disponible ici.',
  'Sélectionnez pour charger',
];

/// Les cinq rangées de la légende Crues, telles que le cadrage § 12.2 les écrit.
const List<String> libellesCrues = <String>[
  'Vert — Pas de vigilance particulière requise',
  'Jaune — Risque de crue génératrice de débordements',
  'Orange — Risque de crue génératrice de débordements importants',
  'Rouge — Risque de crue majeure',
  'Niveau non reconnu',
];

Future<void> _pumpCruesLegend(
  WidgetTester tester, {
  DateTime? date,
  UtcOffsetOf utcOffsetOf = systemUtcOffsetOf,
}) {
  return _pumpAt(
    tester,
    MapLegend(
      scale: MapScaleKind.crues,
      floodInformationDate: date,
      utcOffsetOf: utcOffsetOf,
    ),
  );
}

/// Tous les textes reellement rendus par la legende affichee.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(MapLegend), matching: find.byType(Text)),
    )
    .map((Text text) => text.data ?? '')
    .toList();

/// Pose [child] dans une colonne de [width] de large, à l'échelle de texte
/// [textScale] : la largeur d'un bloc de carte, pas celle de l'écran.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  double width = _phoneBlockWidth,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, 800),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// La légende de [scale], posée à [width] de large — par défaut, la largeur
/// du bloc au téléphone.
Future<void> _pumpLegend(
  WidgetTester tester,
  MapScaleKind scale, {
  double width = _phoneBlockWidth,
  DateTime? date,
}) {
  return _pumpAt(
    tester,
    MapLegend(scale: scale, floodInformationDate: date),
    width: width,
  );
}

/// La légende de [scale] sous son en-tête, comme le bloc les pose : l'en-tête
/// porte le nom de la lecture, la légende vient dessous.
Future<void> _pumpLegendUnderHeader(WidgetTester tester, MapScaleKind scale) {
  return _pumpAt(
    tester,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MapLegendHeader(scale: scale, warningLink: const WarningLink()),
        MapLegend(scale: scale),
      ],
    ),
  );
}

/// L'en-tête de légende de [scale], avec le VRAI contrôle d'avertissement.
Future<void> _pumpHeader(
  WidgetTester tester,
  MapScaleKind scale, {
  double width = _phoneBlockWidth,
  double textScale = 1,
}) {
  return _pumpAt(
    tester,
    MapLegendHeader(scale: scale, warningLink: const WarningLink()),
    width: width,
    textScale: textScale,
  );
}

/// Les lignes posées : les ordonnées distinctes des cases repérées par
/// [finder], dans l'ordre de lecture, et le nombre de cases de chacune.
List<int> _perLine(WidgetTester tester, Finder finder) {
  final int count = finder.evaluate().length;
  final Map<double, int> perTop = <double, int>{};
  for (int i = 0; i < count; i++) {
    final double top = tester.getTopLeft(finder.at(i)).dy;
    perTop[top] = (perTop[top] ?? 0) + 1;
  }
  final List<double> tops = perTop.keys.toList()..sort();
  return <int>[for (final double top in tops) perTop[top]!];
}

/// Le nombre de lignes que le texte [text] occupe une fois posé.
int _lineCount(WidgetTester tester, String text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(text),
  );
  final TextPainter oneLine = TextPainter(
    text: TextSpan(text: 'Légende', style: paragraph.text.style),
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  return (paragraph.size.height / oneLine.height).round();
}

/// La largeur du plus long mot de [text], mesurée par [TextPainter] avec le
/// style et l'échelle du paragraphe posé [paragraph] : la plus petite largeur
/// où le texte se pose sans couper un mot.
double _longestWordWidth(RenderParagraph paragraph, String text) {
  double longest = 0;
  for (final String word in text.split(' ')) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textDirection: TextDirection.ltr,
      textScaler: paragraph.textScaler,
    )..layout();
    if (painter.width > longest) {
      longest = painter.width;
    }
  }
  return longest;
}

void main() {
  setUpAll(chargerRoboto);

  group('symboles compacts (canvas de design du 2026-09-29)', () {
    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgetsOnWindows('legende $scale : symboles a 12 px, sans liseré', (
        WidgetTester tester,
      ) async {
        await _pumpLegend(tester, scale);
        final bool drawsMarkers = switch (scale) {
          MapScaleKind.crues => false,
          MapScaleKind.debit || MapScaleKind.ecoulement => true,
        };
        if (!drawsMarkers) {
          // La légende Crues n'a ni pastille ni marqueur ONDE : ses symboles
          // sont l'échantillon de trait et la jauge de 18 px.
          for (final FloodLevelGauge gauge
              in tester.widgetList<FloodLevelGauge>(
                find.byType(FloodLevelGauge),
              )) {
            expect(gauge.size, 18);
          }
          return;
        }

        final List<CustomPaint> symboles = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(MapLegend),
                matching: find.byWidgetPredicate(
                  (Widget w) =>
                      w is CustomPaint &&
                      (w.painter is StationMarkerPainter ||
                          w.painter is OndeMarkerPainter),
                ),
              ),
            )
            .toList();

        expect(symboles, isNotEmpty);
        for (final CustomPaint symbole in symboles) {
          expect(symbole.size, const Size.square(compactMarkerSize));
          final Object? painter = symbole.painter;
          final bool detached = painter is StationMarkerPainter
              ? painter.detached
              : (painter! as OndeMarkerPainter).detached;
          expect(detached, isFalse);
        }
      });
    }
  });

  group('legende de l echelle « debit »', () {
    testWidgetsOnWindows('nomme son echelle avec le libelle de 04-ui.md, une '
        'fois : dans l en-tete du bloc, la legende dessous ne le repete pas', (
      WidgetTester tester,
    ) async {
      await _pumpLegendUnderHeader(tester, MapScaleKind.debit);

      expect(
        find.text('Légende · ${mapScaleLabel(MapScaleKind.debit)}'),
        findsOneWidget,
      );
      expect(find.text(mapScaleLabel(MapScaleKind.debit)), findsNothing);
    });

    testWidgetsOnWindows(
      'contient « Indéterminé » — en T1 aucun percentile n existe, '
      'donc toute station porte ce niveau (BR-004, ADR-003 hors T1)',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        expect(find.text('Indéterminé'), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'porte le sous-texte permanent de BR-003 / L-01, mot pour '
      'mot',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        expect(
          find.text(
            "Comparaison statistique. Ce n'est pas un seuil réglementaire.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'explique « Indéterminé » avec le libelle long de BR-004, '
      'mot pour mot — c est ce que l usager lit quand la moitie des '
      'stations porte ce niveau',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        expect(
          find.text(
            'Pas assez de mesures passées à cette station pour situer la '
            "valeur d'aujourd'hui.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'le sous-texte de BR-003 est LISIBLE : couleur de texte par '
      'defaut et taille >= 12 — c est le seul garde-fou permanent contre '
      'la lecture « seuil » a l ecran',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        final Text sousTexte = tester.widget<Text>(
          find.text(
            "Comparaison statistique. Ce n'est pas un seuil réglementaire.",
          ),
        );

        expect(sousTexte.style?.fontSize ?? 14, greaterThanOrEqualTo(12));
        expect(
          sousTexte.style?.color,
          isNull,
          reason:
              'aucune teinte ne doit affaiblir cet avertissement : la couleur '
              'de texte par defaut tient les ratios de 04-ui.md § 3',
        );
      },
    );

    testWidgetsOnWindows(
      'liste ses cinq etats, chacun avec la pastille exacte que la '
      'carte dessine',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        expect(find.byType(StationMarkerDot), findsNWidgets(5));
        for (final String label in libellesDebit) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '« $label » manque a la legende',
          );
        }
      },
    );
  });

  group('legende de l echelle « ecoulement »', () {
    testWidgetsOnWindows('nomme son echelle avec le libelle de 04-ui.md, une '
        'fois : dans l en-tete du bloc, la legende dessous ne le repete pas', (
      WidgetTester tester,
    ) async {
      await _pumpLegendUnderHeader(tester, MapScaleKind.ecoulement);

      expect(
        find.text('Légende · ${mapScaleLabel(MapScaleKind.ecoulement)}'),
        findsOneWidget,
      );
      expect(find.text(mapScaleLabel(MapScaleKind.ecoulement)), findsNothing);
    });

    testWidgetsOnWindows(
      'liste les six libelles carte de l echelle 1, mot pour mot',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        for (final String label in libellesEcoulement) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '« $label » manque a la legende',
          );
        }
      },
    );

    testWidgetsOnWindows(
      'chaque ligne montre le marqueur QUE LA CARTE DESSINE, pas '
      'une forme ecrite — six lignes, six marqueurs (T1-U3)',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        expect(find.byType(OndeMarkerShape), findsNWidgets(6));
      },
    );

    testWidgetsOnWindows(
      'les marqueurs de legende sont rendus a l age « recente » : '
      'une legende montre la teinte de la categorie, jamais le gris de '
      'BR-010 qui depend de la date d une observation',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        for (final OndeMarkerShape shape in tester.widgetList<OndeMarkerShape>(
          find.byType(OndeMarkerShape),
        )) {
          expect(shape.age, CampaignAge.recente);
          expect(shape.observedAt, isNull);
        }
      },
    );

    testWidgetsOnWindows(
      '« Non observé » et « Non renseigné » sont DEUX lignes — un '
      'fait de terrain constate n est pas notre ignorance (BR-007)',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        expect(find.text('Non observé'), findsOneWidget);
        expect(find.text('Non renseigné'), findsOneWidget);
      },
    );
  });

  group('legende de l echelle « Vigilance crues » (M3 de T4)', () {
    testWidgetsOnWindows('nomme son echelle dans l en-tete du bloc et cite les '
        'cinq rangees, mot pour mot', (WidgetTester tester) async {
      await _pumpLegendUnderHeader(tester, MapScaleKind.crues);

      expect(find.text('Légende · Vigilance crues'), findsOneWidget);
      expect(
        find.text('Légende · ${mapScaleLabel(MapScaleKind.crues)}'),
        findsOneWidget,
      );
      expect(find.text(mapScaleLabel(MapScaleKind.crues)), findsNothing);
      for (final String label in libellesCrues) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '« $label » manque a la legende',
        );
      }
    });

    testWidgetsOnWindows('les rangees viennent du domaine, jamais recopiees', (
      WidgetTester tester,
    ) async {
      await _pumpCruesLegend(tester);

      for (final FloodVigilanceLevel level in const <FloodVigilanceLevel>[
        Vert(),
        Jaune(),
        Orange(),
        Rouge(),
      ]) {
        expect(
          find.text(
            '${floodLevelLabel(level)} — ${publishedFloodLegend(level)}',
          ),
          findsOneWidget,
        );
      }
      expect(
        find.text(floodLevelLabel(const NiveauCruesInconnu(null))),
        findsOneWidget,
      );
    });

    testWidgetsOnWindows('chaque rangee porte son echantillon de trait et sa '
        'jauge de 18 px ; l inconnu est pointille', (
      WidgetTester tester,
    ) async {
      await _pumpCruesLegend(tester);

      final List<FloodStrokeSample> traits = tester
          .widgetList<FloodStrokeSample>(find.byType(FloodStrokeSample))
          .toList();
      final List<FloodLevelGauge> jauges = tester
          .widgetList<FloodLevelGauge>(find.byType(FloodLevelGauge))
          .toList();

      expect(traits, hasLength(5));
      expect(jauges, hasLength(5));
      expect(
        traits.map((FloodStrokeSample t) => t.level),
        orderedEquals(jauges.map((FloodLevelGauge g) => g.level)),
      );
      for (final FloodLevelGauge jauge in jauges) {
        expect(jauge.size, 18);
      }
      for (final FloodStrokeSample trait in traits) {
        expect(
          floodLevelStyle(trait.level).dotted,
          trait.level is NiveauCruesInconnu,
        );
      }
      expect(
        tester.getSize(find.byType(FloodStrokeSample).first),
        const Size(24, 8),
      );
    });

    testWidgetsOnWindows('sans date : ni phrase de couverture, ni ligne de '
        'date', (WidgetTester tester) async {
      await _pumpCruesLegend(tester);
      final List<String> texts = _texts(tester);

      expect(
        texts,
        isNot(
          contains(
            "Un cours d'eau sans trait de couleur n'est pas suivi par Vigicrues.",
          ),
        ),
      );
      expect(
        texts.where((String t) => t.startsWith('Information de vigilance')),
        isEmpty,
      );
    });

    testWidgetsOnWindows('avec date : phrase de couverture puis date locale '
        'attribuee', (WidgetTester tester) async {
      await _pumpCruesLegend(
        tester,
        date: DateTime.utc(2026, 10, 14, 13, 55, 31),
        utcOffsetOf: (_) => const Duration(hours: 2),
      );

      expect(
        find.text(
          "Un cours d'eau sans trait de couleur n'est pas suivi par "
          'Vigicrues.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES',
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnWindows('la legende Crues ne contient aucun symbole ni '
        'libelle d une autre famille (BR-008)', (WidgetTester tester) async {
      await _pumpCruesLegend(tester);

      expect(find.byType(StationMarkerDot), findsNothing);
      expect(find.byType(OndeMarkerShape), findsNothing);
      final List<String> texts = _texts(tester);
      for (final String label in <String>[
        mapScaleLabel(MapScaleKind.debit),
        mapScaleLabel(MapScaleKind.ecoulement),
        ...libellesDebit,
        ...libellesEcoulement,
      ]) {
        expect(texts, isNot(contains(label)));
      }
    });

    testWidgetsOnWindows('les legendes debit et ecoulement ne montrent ni '
        'trait ni jauge de crues (BR-008)', (WidgetTester tester) async {
      for (final MapScaleKind scale in const <MapScaleKind>[
        MapScaleKind.debit,
        MapScaleKind.ecoulement,
      ]) {
        await _pumpLegend(tester, scale);
        expect(find.byType(FloodStrokeSample), findsNothing);
        expect(find.byType(FloodLevelGauge), findsNothing);
        expect(_texts(tester), isNot(contains('Niveau non reconnu')));
      }
    });
  });

  group('une seule echelle a la fois (BR-008)', () {
    testWidgetsOnWindows('la legende « debit » ne contient aucun libelle de '
        'l echelle ecoulement', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.debit);
      final List<String> texts = _texts(tester);

      for (final String label in <String>[
        mapScaleLabel(MapScaleKind.ecoulement),
        ...libellesEcoulement,
      ]) {
        expect(texts, isNot(contains(label)));
      }
    });

    testWidgetsOnWindows(
      'la legende « ecoulement » ne contient aucun libelle de '
      'l echelle debit',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);
        final List<String> texts = _texts(tester);

        for (final String label in <String>[
          mapScaleLabel(MapScaleKind.debit),
          ...libellesDebit,
        ]) {
          expect(texts, isNot(contains(label)));
        }
      },
    );

    testWidgetsOnWindows(
      'la legende « ecoulement » ne dessine aucune pastille de '
      'l echelle debit',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        expect(find.byType(StationMarkerDot), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'la legende « debit » ne dessine aucun marqueur ONDE',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        expect(find.byType(OndeMarkerShape), findsNothing);
      },
    );
  });

  group('vocabulaire (BR-003)', () {
    testWidgetsOnWindows(
      'aucun texte de legende ne contient un mot banni, sur l une '
      'comme sur l autre echelle',
      (WidgetTester tester) async {
        for (final MapScaleKind scale in MapScaleKind.values) {
          await _pumpLegend(tester, scale);

          for (final String text in _texts(tester)) {
            final Set<String> words = text
                .toLowerCase()
                .split(RegExp(r'[^a-zà-öø-ÿ]+'))
                .toSet();
            for (final String banned in bannedWords) {
              expect(
                words,
                isNot(contains(banned)),
                reason: '"$banned" trouve MOT POUR MOT dans "$text" (BR-003)',
              );
            }
          }
        }
      },
    );
  });

  group('en-tête de légende (S2 d\'Ergonomie, § 11.2)', () {
    testWidgetsOnWindows(
      'mapLegendHeaderText : « Légende · » puis le nom de la lecture, mot '
      'pour mot',
      (WidgetTester tester) async {
        expect(
          mapLegendHeaderText(MapScaleKind.ecoulement),
          'Légende · Écoulement',
        );
        expect(
          mapLegendHeaderText(MapScaleKind.debit),
          "Légende · Débit relatif à l'historique",
        );
        expect(
          mapLegendHeaderText(MapScaleKind.crues),
          'Légende · Vigilance crues',
        );
      },
    );

    testWidgetsOnWindows(
      'le texte puis le lien, le lien à droite ; le texte est un titre pour '
      'le lecteur d\'écran, en 13 gras',
      (WidgetTester tester) async {
        await _pumpHeader(tester, MapScaleKind.ecoulement);

        final Finder text = find.text('Légende · Écoulement');
        final Finder link = find.byKey(warningLinkKey);
        expect(text, findsOneWidget);
        expect(link, findsOneWidget);
        final Rect header = tester.getRect(find.byType(MapLegendHeader));
        expect(
          tester.getRect(text).right,
          lessThanOrEqualTo(tester.getRect(link).left),
        );
        expect(
          tester.getRect(link).right,
          closeTo(header.right, 0.01),
          reason: 'le lien est collé au bord droit de l\'en-tête',
        );
        expect(header.height, greaterThanOrEqualTo(minimumTapTarget));

        final Text widget = tester.widget<Text>(text);
        expect(widget.style?.fontSize, 13);
        expect(widget.style?.fontWeight, FontWeight.bold);
        final SemanticsNode node = tester.getSemantics(text);
        expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
      },
    );

    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgetsOnWindows(
        'à 344 de large et 100 % : "${mapLegendHeaderText(scale)}" et le '
        'lien tiennent, rien ne déborde',
        (WidgetTester tester) async {
          await _pumpHeader(tester, scale);

          expect(tester.takeException(), isNull);
          final Rect header = tester.getRect(find.byType(MapLegendHeader));
          expect(header.width, _phoneBlockWidth);
          expect(
            tester.getRect(find.byKey(warningLinkKey)).right,
            lessThanOrEqualTo(header.right + 0.01),
          );
        },
      );
    }

    testWidgetsOnWindows(
      'à 200 % et 344 de large, en débit : aucun mot du texte n\'est coupé, '
      'le lien entier passe sous le texte, aligné à droite, et la hauteur '
      'intrinsèque est la hauteur posée',
      (WidgetTester tester) async {
        await _pumpHeader(tester, MapScaleKind.debit, textScale: 2);

        expect(tester.takeException(), isNull);
        final String text = mapLegendHeaderText(MapScaleKind.debit);
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.text(text),
        );

        // Aucun mot coupé : la largeur de la ligne est celle du plus long mot,
        // au moins — mesurée par `TextPainter`, avec le style du paragraphe.
        final double longestWord = _longestWordWidth(paragraph, text);
        expect(paragraph.size.width, greaterThanOrEqualTo(longestWord));
        // Et le texte passe à la ligne, sans être tronqué.
        expect(_lineCount(tester, text), greaterThan(1));
        final Text widget = tester.widget<Text>(find.text(text));
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
        expect(paragraph.didExceedMaxLines, isFalse);

        // Le lien : entier, sur une ligne, SOUS le texte, aligné à droite.
        final Rect header = tester.getRect(find.byType(MapLegendHeader));
        final Rect textRect = tester.getRect(find.text(text));
        final Rect link = tester.getRect(find.byKey(warningLinkKey));
        expect(_lineCount(tester, warningLinkLabel), 1);
        expect(link.top, greaterThanOrEqualTo(textRect.bottom));
        expect(link.right, closeTo(header.right, 0.01));
        expect(link.left, greaterThanOrEqualTo(header.left));
        expect(textRect.width, greaterThan(link.width));
        expect(
          header.height,
          closeTo(textRect.height + 2 * 4 + link.height, 0.01),
          reason: 'le texte (avec ses 4 de marge), puis le lien',
        );

        // La hauteur intrinsèque est la hauteur posée.
        final RenderBox box = tester.renderObject<RenderBox>(
          find.byType(MapLegendHeader),
        );
        expect(
          box.getMaxIntrinsicHeight(_phoneBlockWidth),
          closeTo(header.height, 0.01),
        );
        expect(
          box.getMinIntrinsicHeight(_phoneBlockWidth),
          closeTo(header.height, 0.01),
        );
      },
    );

    testWidgetsOnWindows(
      'à 480 de large et 100 % : le lien est à côté du texte, sur la même '
      'rangée, pour les trois lectures',
      (WidgetTester tester) async {
        for (final MapScaleKind scale in MapScaleKind.values) {
          await _pumpHeader(tester, scale, width: 480);

          final Rect text = tester.getRect(
            find.text(mapLegendHeaderText(scale)),
          );
          final Rect link = tester.getRect(find.byKey(warningLinkKey));
          final Rect header = tester.getRect(find.byType(MapLegendHeader));
          expect(text.right, lessThanOrEqualTo(link.left), reason: '$scale');
          expect(link.right, closeTo(header.right, 0.01), reason: '$scale');
          expect(
            tester.getCenter(find.text(mapLegendHeaderText(scale))).dy,
            closeTo(tester.getCenter(find.byKey(warningLinkKey)).dy, 0.01),
            reason: '$scale : même rangée',
          );
          expect(header.height, lessThan(2 * minimumTapTarget));
        }
      },
    );

    testWidgetsOnWindows(
      'la règle, à toutes les largeurs et aux deux échelles de texte : côte à '
      'côte si le mot le plus long, l\'écart et le lien tiennent, sinon sous '
      'le texte ; jamais un mot coupé, hauteur intrinsèque = hauteur posée',
      (WidgetTester tester) async {
        int beside = 0;
        int stacked = 0;
        for (final (double textScale, List<double> widths)
            in <(double, List<double>)>[
              (1, <double>[160, 200, 240, 280, 344, 480]),
              (2, <double>[240, 280, 344, 400, 480]),
            ]) {
          for (final double width in widths) {
            for (final MapScaleKind scale in MapScaleKind.values) {
              await _pumpHeader(
                tester,
                scale,
                width: width,
                textScale: textScale,
              );
              final String reason = '$scale à $width, texte × $textScale';
              expect(tester.takeException(), isNull, reason: reason);

              final String text = mapLegendHeaderText(scale);
              final RenderParagraph paragraph = tester
                  .renderObject<RenderParagraph>(find.text(text));
              final Rect textRect = tester.getRect(find.text(text));
              final Rect link = tester.getRect(find.byKey(warningLinkKey));
              final Rect header = tester.getRect(find.byType(MapLegendHeader));

              // Aucun mot coupé, le lien entier et collé à droite.
              expect(
                paragraph.size.width,
                greaterThanOrEqualTo(_longestWordWidth(paragraph, text)),
                reason: reason,
              );
              expect(_lineCount(tester, warningLinkLabel), 1, reason: reason);
              expect(link.right, closeTo(header.right, 0.01), reason: reason);
              expect(link.left, greaterThanOrEqualTo(header.left));

              // La règle : le mot le plus long, l'écart (8) et le lien.
              final double needed =
                  _longestWordWidth(paragraph, text) + 8 + link.width;
              if ((needed - width).abs() > 1) {
                final bool isBeside = textRect.right <= link.left;
                expect(isBeside, needed <= width, reason: reason);
                if (isBeside) {
                  beside++;
                  expect(link.top, lessThan(textRect.bottom), reason: reason);
                } else {
                  stacked++;
                  expect(
                    link.top,
                    greaterThanOrEqualTo(textRect.bottom),
                    reason: reason,
                  );
                }
              }

              final RenderBox box = tester.renderObject<RenderBox>(
                find.byType(MapLegendHeader),
              );
              // La mise en page à vide suit la même règle que la mise en page.
              expect(box.getDryLayout(box.constraints), box.size);
              expect(
                box.getMaxIntrinsicHeight(width),
                closeTo(header.height, 0.01),
                reason: reason,
              );
              expect(
                box.getMinIntrinsicHeight(width),
                closeTo(header.height, 0.01),
                reason: reason,
              );
            }
          }
        }
        // Le balayage voit les deux dispositions : il n'est pas vide.
        expect(beside, greaterThan(0));
        expect(stacked, greaterThan(0));
      },
    );

    testWidgetsOnWindows(
      'la hauteur est d\'au moins minimumTapTarget, de l\'en-tête lui-même '
      'et non du seul lien reçu',
      (WidgetTester tester) async {
        await _pumpAt(
          tester,
          const MapLegendHeader(
            scale: MapScaleKind.ecoulement,
            warningLink: SizedBox(width: 40, height: 10),
          ),
        );

        final RenderBox box = tester.renderObject<RenderBox>(
          find.byType(MapLegendHeader),
        );
        expect(box.size.height, minimumTapTarget);
        expect(box.getMinIntrinsicHeight(_phoneBlockWidth), minimumTapTarget);
        expect(box.getMaxIntrinsicHeight(_phoneBlockWidth), minimumTapTarget);
      },
    );

    testWidgetsOnWindows(
      'intrinsèques lisibles sans erreur : min = max, au moins la cible '
      'tactile, et égaux à la hauteur posée',
      (WidgetTester tester) async {
        for (final double textScale in <double>[1, 2]) {
          for (final MapScaleKind scale in MapScaleKind.values) {
            await _pumpHeader(tester, scale, textScale: textScale);

            final RenderBox box = tester.renderObject<RenderBox>(
              find.byType(MapLegendHeader),
            );
            final double min = box.getMinIntrinsicHeight(_phoneBlockWidth);
            final double max = box.getMaxIntrinsicHeight(_phoneBlockWidth);
            expect(min, greaterThanOrEqualTo(minimumTapTarget));
            expect(max, min);
            expect(max, closeTo(box.size.height, 0.01));
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  });

  group('légende dans le bloc (S2 d\'Ergonomie, PD6)', () {
    testWidgetsOnWindows('legendRowWidth vaut 156 (PD6)', (
      WidgetTester tester,
    ) async {
      expect(legendRowWidth, 156);
    });

    testWidgetsOnWindows(
      'sans titre — aucun mapScaleLabel(scale) seul, pour les trois lectures : '
      'le nom de la lecture est dans l\'en-tête',
      (WidgetTester tester) async {
        for (final MapScaleKind scale in MapScaleKind.values) {
          await _pumpLegend(tester, scale);
          expect(
            find.text(mapScaleLabel(scale)),
            findsNothing,
            reason: 'le titre est dans l\'en-tête, pas dans la légende',
          );
          expect(find.text(mapLegendHeaderText(scale)), findsNothing);
        }
      },
    );

    testWidgetsOnWindows(
      'ni carte blanche, ni plafond de largeur — le bloc les porte : la légende '
      'prend la largeur du bloc, au téléphone (344) comme au-delà (480)',
      (WidgetTester tester) async {
        for (final MapScaleKind scale in MapScaleKind.values) {
          await _pumpLegend(tester, scale);
          expect(
            find.descendant(
              of: find.byType(MapLegend),
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
        }

        // Aucun plafond : la légende a la largeur que le bloc lui donne — et
        // deux cases de 156 et leur écart de 8 (320) y tiennent côte à côte.
        for (final double width in <double>[_phoneBlockWidth, 480]) {
          await _pumpLegend(tester, MapScaleKind.ecoulement, width: width);
          expect(tester.getSize(find.byType(MapLegend)).width, width);
        }
      },
    );

    testWidgetsOnWindows(
      'écoulement à 344 : les six rangées sur trois lignes de deux, '
      'dans l\'ordre de lecture',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement);

        final Finder markers = find.byType(OndeMarkerShape);
        expect(markers, findsNWidgets(6));
        expect(_perLine(tester, markers), <int>[2, 2, 2]);
        // L'ordre de lecture : de gauche à droite, puis la ligne suivante.
        final List<Offset> corners = <Offset>[
          for (int i = 0; i < 6; i++) tester.getTopLeft(markers.at(i)),
        ];
        for (int i = 1; i < corners.length; i++) {
          final bool nextInLine =
              corners[i].dy == corners[i - 1].dy &&
              corners[i].dx > corners[i - 1].dx;
          expect(
            nextInLine || corners[i].dy > corners[i - 1].dy,
            isTrue,
            reason: 'rangée $i hors de l\'ordre de lecture',
          );
        }
        // Deux cases de 156 séparées de 8 : le second marqueur est à 164 du
        // premier.
        expect(
          corners[1].dx - corners[0].dx,
          legendRowWidth + 8,
          reason: 'cases de legendRowWidth, écart horizontal de 8',
        );
        for (final String label in libellesEcoulement) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'les colonnes suivent la largeur — deux dès 320, une seule en '
      'deçà, sans LayoutBuilder',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement, width: 320);
        expect(_perLine(tester, find.byType(OndeMarkerShape)), <int>[2, 2, 2]);
        await _pumpLegend(tester, MapScaleKind.ecoulement, width: 300);
        expect(_perLine(tester, find.byType(OndeMarkerShape)), <int>[
          1,
          1,
          1,
          1,
          1,
          1,
        ]);
        expect(
          find.descendant(
            of: find.byType(MapLegend),
            matching: find.byType(LayoutBuilder),
          ),
          findsNothing,
        );
      },
    );

    testWidgetsOnWindows(
      'débit à 344 : l\'explication de BR-004 et la comparaison '
      'statistique restent pleine largeur ; les cinq rangées de fraîcheur '
      'sont en colonnes',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.debit);

        for (final String phrase in <String>[
          'Pas assez de mesures passées à cette station pour situer la valeur '
              "d'aujourd'hui.",
          "Comparaison statistique. Ce n'est pas un seuil réglementaire.",
        ]) {
          expect(
            tester.getSize(find.text(phrase)).width,
            greaterThan(legendRowWidth),
            reason: '« $phrase » est tenue dans une case de la grille',
          );
        }
        expect(find.byType(StationMarkerDot), findsNWidgets(5));
        expect(_perLine(tester, find.byType(StationMarkerDot)), <int>[2, 2, 1]);
        for (final String label in libellesDebit) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'crues à 344 : les cinq rangées restent pleine largeur (leurs '
      'libellés publiés sont longs), une par ligne ; la couverture et la date '
      'de la vigilance aussi',
      (WidgetTester tester) async {
        await _pumpLegend(
          tester,
          MapScaleKind.crues,
          date: DateTime.utc(2026, 10, 14, 13, 55, 31),
        );

        final Finder samples = find.byType(FloodStrokeSample);
        expect(samples, findsNWidgets(5));
        expect(_perLine(tester, samples), <int>[1, 1, 1, 1, 1]);
        final Set<double> lefts = <double>{
          for (int i = 0; i < 5; i++) tester.getTopLeft(samples.at(i)).dx,
        };
        expect(lefts, hasLength(1), reason: 'une seule colonne');
        for (final String label in libellesCrues) {
          expect(find.text(label), findsOneWidget);
        }
        // Le libellé le plus long dépasse la place qu'une case de 156 lui
        // laisserait : 156 moins le trait (24), la jauge (18) et ses écarts.
        expect(
          tester.getSize(find.text(libellesCrues[2])).width,
          greaterThan(legendRowWidth - 24 - 4 - 18 - 6),
        );
        expect(
          tester.getSize(find.text(floodCoverageText)).width,
          greaterThan(legendRowWidth),
        );
        final Finder date = find.textContaining('Information de vigilance du');
        expect(date, findsOneWidget);
        expect(tester.getSize(date).width, greaterThan(legendRowWidth));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'intrinsèques lisibles sans erreur — la hauteur entière est '
      'celle qui est posée, et la légende n\'a qu\'une hauteur (min = max)',
      (WidgetTester tester) async {
        for (final MapScaleKind scale in MapScaleKind.values) {
          await _pumpLegend(
            tester,
            scale,
            // Seule la lecture Crues dit une date : `switch` exhaustif, une
            // branche par lecture, sans `_` (BR-011).
            date: switch (scale) {
              MapScaleKind.crues => DateTime.utc(2026, 10, 14, 13, 55, 31),
              MapScaleKind.ecoulement || MapScaleKind.debit => null,
            },
          );

          final RenderBox box = tester.renderObject<RenderBox>(
            find.byType(MapLegend),
          );
          final double min = box.getMinIntrinsicHeight(_phoneBlockWidth);
          final double max = box.getMaxIntrinsicHeight(_phoneBlockWidth);
          expect(max, greaterThan(0), reason: '$scale');
          expect(max, min, reason: '$scale');
          expect(max, closeTo(box.size.height, 0.01), reason: '$scale');
          expect(tester.takeException(), isNull);
        }
      },
    );

    // Relecture finale de la branche (m1), R15 : remplace « inBlock: false (le
    // défaut) garde la carte blanche, son titre et sa colonne unique de 260 au
    // plus » — une forme sans appelant, retirée. À sa place, la disposition de
    // la seule forme à la plus grande largeur du bloc (480, au-delà du
    // téléphone) : trois cases de 156 et deux écarts de 8 font 484 > 480.
    testWidgetsOnWindows(
      'à 480 de large, la plus grande largeur du bloc : jamais trois cases de '
      'front — écoulement et fraîcheur du débit restent en deux colonnes',
      (WidgetTester tester) async {
        await _pumpLegend(tester, MapScaleKind.ecoulement, width: 480);
        expect(_perLine(tester, find.byType(OndeMarkerShape)), <int>[2, 2, 2]);
        await _pumpLegend(tester, MapScaleKind.debit, width: 480);
        expect(_perLine(tester, find.byType(StationMarkerDot)), <int>[2, 2, 1]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';

import '../../../support/windows_platform.dart';

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

Future<void> _pumpLegend(WidgetTester tester, MapScaleKind scale) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MapLegend(scale: scale)),
    ),
  );
}

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
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapLegend(
          scale: MapScaleKind.crues,
          floodInformationDate: date,
          utcOffsetOf: utcOffsetOf,
        ),
      ),
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

void main() {
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
    testWidgetsOnWindows('nomme son echelle avec le libelle de 04-ui.md', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(find.text(mapScaleLabel(MapScaleKind.debit)), findsOneWidget);
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
    testWidgetsOnWindows('nomme son echelle avec le libelle de 04-ui.md', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      expect(find.text(mapScaleLabel(MapScaleKind.ecoulement)), findsOneWidget);
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
    testWidgetsOnWindows('nomme son echelle et cite les cinq rangees, mot pour '
        'mot', (WidgetTester tester) async {
      await _pumpCruesLegend(tester);

      expect(find.text('Vigilance crues'), findsOneWidget);
      expect(find.text(mapScaleLabel(MapScaleKind.crues)), findsOneWidget);
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
}

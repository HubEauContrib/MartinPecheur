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
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

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
  'Chargement en cours',
];

Future<void> _pumpLegend(WidgetTester tester, MapScaleKind scale) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MapLegend(scale: scale)),
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
  group('legende de l echelle « debit »', () {
    testWidgets('nomme son echelle avec le libelle de 04-ui.md', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(find.text(mapScaleLabel(MapScaleKind.debit)), findsOneWidget);
    });

    testWidgets('contient « Indéterminé » — en T1 aucun percentile n existe, '
        'donc toute station porte ce niveau (BR-004, ADR-003 hors T1)', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(find.text('Indéterminé'), findsOneWidget);
    });

    testWidgets('porte le sous-texte permanent de BR-003 / L-01, mot pour '
        'mot', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(
        find.text(
          "Comparaison statistique. Ce n'est pas un seuil réglementaire.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('explique « Indéterminé » avec le libelle long de BR-004, '
        'mot pour mot — c est ce que l usager lit quand la moitie des '
        'stations porte ce niveau', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(
        find.text(
          'Pas assez de mesures passées à cette station pour situer la '
          "valeur d'aujourd'hui.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('le sous-texte de BR-003 est LISIBLE : couleur de texte par '
        'defaut et taille >= 12 — c est le seul garde-fou permanent contre '
        'la lecture « seuil » a l ecran', (WidgetTester tester) async {
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
    });

    testWidgets('liste ses cinq etats, chacun avec la pastille exacte que la '
        'carte dessine', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(find.byType(StationMarkerDot), findsNWidgets(5));
      for (final String label in libellesDebit) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '« $label » manque a la legende',
        );
      }
    });
  });

  group('legende de l echelle « ecoulement »', () {
    testWidgets('nomme son echelle avec le libelle de 04-ui.md', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      expect(find.text(mapScaleLabel(MapScaleKind.ecoulement)), findsOneWidget);
    });

    testWidgets('liste les six libelles carte de l echelle 1, mot pour mot', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      for (final String label in libellesEcoulement) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '« $label » manque a la legende',
        );
      }
    });

    testWidgets('chaque ligne montre le marqueur QUE LA CARTE DESSINE, pas '
        'une forme ecrite — six lignes, six marqueurs (T1-U3)', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      expect(find.byType(OndeMarkerShape), findsNWidgets(6));
    });

    testWidgets('les marqueurs de legende sont rendus a l age « recente » : '
        'une legende montre la teinte de la categorie, jamais le gris de '
        'BR-010 qui depend de la date d une observation', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      for (final OndeMarkerShape shape in tester.widgetList<OndeMarkerShape>(
        find.byType(OndeMarkerShape),
      )) {
        expect(shape.age, CampaignAge.recente);
        expect(shape.observedAt, isNull);
      }
    });

    testWidgets('« Non observé » et « Non renseigné » sont DEUX lignes — un '
        'fait de terrain constate n est pas notre ignorance (BR-007)', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      expect(find.text('Non observé'), findsOneWidget);
      expect(find.text('Non renseigné'), findsOneWidget);
    });
  });

  group('une seule echelle a la fois (BR-008)', () {
    testWidgets('la legende « debit » ne contient aucun libelle de '
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

    testWidgets('la legende « ecoulement » ne contient aucun libelle de '
        'l echelle debit', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);
      final List<String> texts = _texts(tester);

      for (final String label in <String>[
        mapScaleLabel(MapScaleKind.debit),
        ...libellesDebit,
      ]) {
        expect(texts, isNot(contains(label)));
      }
    });

    testWidgets('la legende « ecoulement » ne dessine aucune pastille de '
        'l echelle debit', (WidgetTester tester) async {
      await _pumpLegend(tester, MapScaleKind.ecoulement);

      expect(find.byType(StationMarkerDot), findsNothing);
    });

    testWidgets('la legende « debit » ne dessine aucun marqueur ONDE', (
      WidgetTester tester,
    ) async {
      await _pumpLegend(tester, MapScaleKind.debit);

      expect(find.byType(OndeMarkerShape), findsNothing);
    });
  });

  group('vocabulaire (BR-003)', () {
    testWidgets('aucun texte de legende ne contient un mot banni, sur l une '
        'comme sur l autre echelle', (WidgetTester tester) async {
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
    });
  });
}

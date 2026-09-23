// Verrouille la fiche d'un point ONDE : les deux formateurs, le contenu
// rendu, l'ORDRE catégorie → modalité officielle → date (`UC-004`, `BR-010`,
// `ADR-006`), et les quatre états du panneau.
//
// Les données de test sont les valeurs RÉELLES de la station `K4520001`
// (LA RIVIERE AUX LOCHES A CHAON), lues dans
// `test/fixtures/onde/observations_station_K4520001_2026-09-13.json` :
// cinq campagnes — 2026-08-25 code `3` « Assec », 2026-07-24 code `3`
// « Assec », 2026-06-26 code `2` « Ecoulement non visible », 2026-05-26
// code `1a` « Ecoulement visible acceptable », 2025-09-26 code `1f`
// « Ecoulement visible faible » — cours d'eau « ruisseau la rivière aux
// loches », département « 41 ». Aucune valeur n'est inventée.
//
// ⚠️ Aucun test ne rend `FlutterMap` : la feuille et le panneau sont rendus
// SEULS dans un `MaterialApp`. L'environnement de test refuse les tuiles, et
// un échec de tuile ne dirait rien sur ce code.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

OndeStationCode _code() => OndeStationCode('K4520001');

OndePoint _chaon({
  String? waterCourseLabel = 'ruisseau la rivière aux loches',
  String? departement = '41',
}) => OndePoint(
  code: _code(),
  label: 'LA RIVIERE AUX LOCHES A CHAON',
  latitude: 47.610620493,
  longitude: 2.173858157,
  waterCourseLabel: waterCourseLabel,
  departement: departement == null
      ? null
      : AdministrativeArea(code: departement, label: departement),
);

/// Une observation de la fixture : la date, le code brut et le libellé
/// officiel tels que l'API les rend, la catégorie dérivée du code par le
/// domaine (jamais écrite à la main ici).
OndeObservation _observation({
  required DateTime observedAt,
  required String rawFlowCode,
  required String officialLabel,
  required String campaignCode,
  OndePoint? point,
}) {
  final OndePoint on = point ?? _chaon();
  return OndeObservation(
    station: on.code,
    point: on,
    observedAt: observedAt,
    category: flowCategoryFromCode(rawFlowCode),
    rawFlowCode: rawFlowCode,
    officialLabel: officialLabel,
    campaignCode: campaignCode,
  );
}

/// Les CINQ campagnes de la fixture, la plus récente en tête — l'ordre que
/// le dépôt rend (`sort=desc`), jamais retrié ici.
List<OndeObservation> _history({OndePoint? point}) => <OndeObservation>[
  _observation(
    observedAt: DateTime.utc(2026, 8, 25),
    rawFlowCode: '3',
    officialLabel: 'Assec',
    campaignCode: '109905',
    point: point,
  ),
  _observation(
    observedAt: DateTime.utc(2026, 7, 24),
    rawFlowCode: '3',
    officialLabel: 'Assec',
    campaignCode: '108768',
    point: point,
  ),
  _observation(
    observedAt: DateTime.utc(2026, 6, 26),
    rawFlowCode: '2',
    officialLabel: 'Ecoulement non visible',
    campaignCode: '107808',
    point: point,
  ),
  _observation(
    observedAt: DateTime.utc(2026, 5, 26),
    rawFlowCode: '1a',
    officialLabel: 'Ecoulement visible acceptable',
    campaignCode: '106709',
    point: point,
  ),
  _observation(
    observedAt: DateTime.utc(2025, 9, 26),
    rawFlowCode: '1f',
    officialLabel: 'Ecoulement visible faible',
    campaignCode: '104068',
    point: point,
  ),
];

/// Les données de la fiche, telles que `OndeSheetViewModel` les produirait
/// au 2026-09-13 : la campagne du 25/08/2026 a 19 jours.
OndeSheetData _data({
  OndePoint? point,
  List<OndeObservation>? history,
  CampaignAge? age = CampaignAge.recente,
  int? ageInDays = 19,
  String officialModalityText = 'code 3 — Assec',
  String seasonNotice = ondeSeasonNotice,
}) {
  final OndePoint on = point ?? _chaon();
  final List<OndeObservation> campaigns = history ?? _history(point: on);
  return OndeSheetData(
    point: on,
    latest: campaigns.isEmpty ? null : campaigns.first,
    history: List<OndeObservation>.unmodifiable(campaigns),
    age: campaigns.isEmpty ? null : age,
    ageInDays: campaigns.isEmpty ? null : ageInDays,
    officialModalityText: officialModalityText,
    seasonNotice: seasonNotice,
  );
}

/// Les cinq mots bannis de `BR-003`, par MOT ENTIER — même expression que
/// `test/features/station_sheet/view/station_summary_sheet_test.dart`, pour
/// que les deux fiches soient tenues à la même règle.
final RegExp _bannedWords = RegExp(
  r'\b(insuffisante?s?|suffisante?s?|normale?s?|normaux|bonne?s?|sûre?s?)\b',
  caseSensitive: false,
);

/// Les mots de garantie interdits par `BR-014`.
///
/// ⚠️ « officiel » figure dans la liste de `BR-014` mais **pas ici** :
/// `UC-004 § 3` et `04-ui.md § « Fiche point ONDE »` imposent d'afficher la
/// **modalité officielle ONDE**, qui nomme la nomenclature de la SOURCE et
/// non une qualité de nos données. C'est la même réserve que `BR-014` pose
/// lui-même pour les libellés d'une autorité, cités tels quels et attribués,
/// et que `BR-006` pose pour « Bonne » sur la fiche station. Le test
/// « le mot officiel ne sert qu'à attribuer la nomenclature ONDE » ci-dessous
/// borne cette réserve : aucune autre occurrence n'est tolérée.
final RegExp _guaranteeWords = RegExp(
  r'(temps réel|en direct|fiabl|vérifié|exact|garanti|sécurisé)',
  caseSensitive: false,
);

/// Les QUATRE états du panneau, pour un balayage de vocabulaire qui couvre
/// toute la copie du produit et pas seulement la feuille de résumé.
///
/// Le libellé d'API de l'état [OndeSheetPrete] est volontairement neutralisé
/// — comme en `U1` : `ADR-006` impose de citer `libelle_ecoulement`
/// VERBATIM, et ce mot-là n'est pas de la copie du produit. Le balayage ne
/// doit mesurer que ce que l'application écrit elle-même.
List<OndeSheetState> _panelStates() => <OndeSheetState>[
  const OndeSheetFermee(),
  OndeSheetEnCours(_chaon()),
  OndeSheetEnEchec(_chaon(), StateError('socket')),
  OndeSheetPrete(_data(officialModalityText: 'code 3 — libellé non cité')),
];

/// Tous les textes rendus, à plat — sert aux balayages de vocabulaire.
List<String> _renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? '')
    .where((String data) => data.isNotEmpty)
    .toList();

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  // `formatCampaignDate` a disparu de cette tranche (Task H1) : c'est
  // désormais `formatCalendarDate` de `lib/domain/formatting/display_date.dart`
  // qui formate la date de campagne, verrouillé par
  // `test/domain/formatting/display_date_test.dart` — une copie en moins,
  // aucun changement visible sur cette fiche (elle appelle la même fonction
  // domaine que `onde_marker.dart` et `station_summary_sheet.dart`).

  group("formatCampaignAge — l'âge en jours calendaires (BR-010)", () {
    test('19 jours : contient le nombre et le mot « jour »', () {
      final String text = formatCampaignAge(19);

      expect(text, contains('19'));
      expect(text, contains('jour'));
      expect(text, 'il y a 19 jours');
    });

    test('1 jour : le singulier, jamais « 1 jours »', () {
      expect(formatCampaignAge(1), 'il y a 1 jour');
    });

    test("0 jour : « aujourd'hui », jamais « il y a 0 jour »", () {
      expect(formatCampaignAge(0), "aujourd'hui");
    });

    test("un âge négatif (observation datée du futur) : « aujourd'hui », "
        'jamais « il y a −2 jours »', () {
      expect(formatCampaignAge(-2), "aujourd'hui");
    });

    test('142 jours : contient le nombre', () {
      expect(formatCampaignAge(142), contains('142'));
    });
  });

  group('minimumTapTarget (K1, features/shared/tap_target.dart)', () {
    test('vaut 44 pt (04-ui.md § 3, cibles tactiles)', () {
      expect(minimumTapTarget, 44.0);
    });
  });

  group('OndeSummarySheet — le contenu de la fiche (UC-004 § 3 et § 4)', () {
    testWidgets(
      "rend le libellé du point, son cours d'eau et son département",
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.text('LA RIVIERE AUX LOCHES A CHAON'), findsOneWidget);
        expect(
          find.textContaining('ruisseau la rivière aux loches'),
          findsOneWidget,
        );
        expect(find.textContaining('41'), findsWidgets);
      },
    );

    testWidgets(
      "cours d'eau nul → une absence honnête, jamais une ligne vide (BR-007)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSummarySheet(data: _data(point: _chaon(waterCourseLabel: null))),
        );

        expect(find.text(ondeCoursDEauNonRenseigne), findsOneWidget);
      },
    );

    testWidgets('département nul → une absence honnête (BR-007)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSummarySheet(data: _data(point: _chaon(departement: null))),
      );

      expect(find.text(ondeDepartementNonRenseigne), findsOneWidget);
    });

    testWidgets(
      'rend la catégorie « À sec » — le libellé d INTERFACE, jamais « Assec »',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.text('À sec'), findsOneWidget);
      },
    );

    testWidgets('rend la modalité officielle exacte : « code 3 » et « Assec » '
        '(ADR-006, UC-004 § 3)', (WidgetTester tester) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.textContaining('code 3'), findsOneWidget);
      expect(find.textContaining('Assec'), findsOneWidget);
    });

    testWidgets('rend la date de la campagne, sans heure (T-08)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.textContaining('25/08/2026'), findsWidgets);

      // Aucun texte rendu ne porte d'heure : l'API ONDE n'en donne pas
      // (T-08), en afficher une laisserait croire à une précision qui
      // n'existe pas.
      final RegExp heure = RegExp(r'\d{1,2}\s?[:h]\s?\d{2}');
      for (final String text in _renderedTexts(tester)) {
        expect(
          heure.hasMatch(text),
          isFalse,
          reason: 'aucune heure ne doit être rendue : « $text »',
        );
      }
    });

    testWidgets("rend l'âge de la campagne — le nombre et le mot « jour » "
        '(BR-010)', (WidgetTester tester) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.textContaining('il y a 19 jours'), findsOneWidget);
    });

    // L'invariant de `U4` : les trois informations sont sur la MÊME fiche et
    // dans CET ordre, sans exception (`UC-004`, `BR-010`, `ADR-006`).
    testWidgets('ordre imposé : catégorie, puis modalité officielle, puis '
        'date de campagne', (WidgetTester tester) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      final double category = tester.getTopLeft(find.text('À sec')).dy;
      final double modality = tester
          .getTopLeft(find.textContaining('code 3'))
          .dy;
      final double date = tester
          .getTopLeft(find.textContaining('il y a 19 jours'))
          .dy;

      expect(category, lessThan(modality));
      expect(modality, lessThan(date));
    });

    // L'invariant de `W4`, tenu désormais par le contrôle d'avertissement
    // (`W3c`) : voir le groupe « le contrôle d'avertissement de tête »
    // ci-dessous pour l'assertion d'ordre EN TÊTE, avant la catégorie.

    testWidgets('rend les CINQ campagnes de la fixture, chacune avec sa date '
        'et sa catégorie, la plus récente en tête (UC-004 § 4)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      const List<String> expected = <String>[
        '25/08/2026 — À sec',
        '24/07/2026 — À sec',
        '26/06/2026 — Eau stagnante',
        '26/05/2026 — Eau qui coule',
        '26/09/2025 — Écoulement faible',
      ];

      double previous = -1;
      for (final String line in expected) {
        expect(find.text(line), findsOneWidget, reason: 'ligne manquante');
        final double top = tester.getTopLeft(find.text(line)).dy;
        expect(top, greaterThan(previous), reason: 'ordre rompu sur « $line »');
        previous = top;
      }
    });

    testWidgets('le rappel de rythme est rendu (UC-004 § 5)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.text(ondeSeasonNotice), findsOneWidget);
    });

    testWidgets(
      "$ondeSourceName est rendu avec la date de campagne (BR-001, point 32)",
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(
          find.textContaining(ondeSourceName),
          findsOneWidget,
          reason:
              'la valeur, sa date et sa source sont visibles au même '
              'endroit (BR-001)',
        );
      },
    );
  });

  group("OndeSummarySheet — le contrôle d'avertissement de tête (W3c, "
      'arbitrage du commanditaire du 2026-09-23)', () {
    testWidgets('le contrôle est TOUJOURS rendu, avec ou sans campagne', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.byType(WarningLink), findsOneWidget);
    });

    testWidgets(
      'le contrôle est rendu EN TÊTE, avant la catégorie — assertion sur '
      "l'ORDRE dans l'arbre, pas sur la seule présence",
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        final double linkTop = tester.getTopLeft(find.byType(WarningLink)).dy;
        final double categoryTop = tester
            .getTopLeft(find.text(flowCategoryLabel(_data().latest!.category)))
            .dy;

        expect(linkTop, lessThan(categoryTop));
      },
    );

    testWidgets(
      'avec une campagne, la fenêtre porte la phrase datée, plus insistante '
      'que la version station (UC-004 § 1)',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Observation du 25/08/2026'),
          findsOneWidget,
        );
        expect(find.textContaining('campagne ponctuelle'), findsOneWidget);
        expect(
          find.textContaining("Ce n'est pas une mesure de débit"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sans campagne, le contrôle reste mais la fenêtre n\'a pas de phrase '
      'propre — arbitrage du commanditaire du 2026-09-23 : sans date, '
      'aucun encart',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSummarySheet(
            data: _data(
              history: <OndeObservation>[],
              officialModalityText: 'Aucune campagne connue pour ce point.',
            ),
          ),
        );

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(find.byKey(warningWindowExtraTextKey), findsNothing);
      },
    );
  });

  group('OndeSummarySheet — une campagne ancienne (BR-010, UC-004 A1)', () {
    OndeSheetData ancienne() => _data(
      history: <OndeObservation>[_history().last],
      age: CampaignAge.ancienne,
      ageInDays: 353,
      officialModalityText: 'code 1f — Ecoulement visible faible',
    );

    testWidgets('rend la mention « dernière observation le 26/09/2025 »', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: ancienne()));

      expect(
        find.textContaining('dernière observation le 26/09/2025'),
        findsOneWidget,
      );
    });

    // Relecture du 2026-09-14 : `#767676` (4,54:1) ne tient pas les 7:1
    // qu'exige `04-ui.md` § 3 pour un libellé d'état. `BR-010` reste
    // respecté autrement — la mention datée, vérifiée ici, et le marqueur
    // de la carte (`U3`) — sans recolorer le texte de la catégorie.
    testWidgets(
      "la mention datée est rendue et la catégorie ne porte pas #767676",
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: ancienne()));

        expect(
          find.textContaining('dernière observation le 26/09/2025'),
          findsOneWidget,
        );

        final Text category = tester.widget<Text>(
          find.text('Écoulement faible'),
        );

        expect(category.style?.color, isNot(const Color(0xFF767676)));
      },
    );

    testWidgets('une campagne récente ne porte pas la mention', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.text('À sec'), findsOneWidget);
      expect(find.textContaining('dernière observation'), findsNothing);
    });
  });

  group('OndeSummarySheet — les absences (UC-004 A2 et A4, BR-007)', () {
    testWidgets(
      "aucune campagne → le message d'absence, et la fiche N'EST PAS vidée "
      '(UC-004 A4, BR-007)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSummarySheet(
            data: _data(
              history: <OndeObservation>[],
              officialModalityText: 'Aucune campagne connue pour ce point.',
            ),
          ),
        );

        expect(
          find.text('Aucune campagne connue pour ce point.'),
          findsOneWidget,
        );
        expect(find.text('LA RIVIERE AUX LOCHES A CHAON'), findsOneWidget);
        expect(
          find.textContaining('ruisseau la rivière aux loches'),
          findsOneWidget,
        );
        expect(find.textContaining('41'), findsWidgets);
        expect(find.text(ondeSeasonNotice), findsOneWidget);
      },
    );

    testWidgets(
      'catégorie NonObserve → la phrase de UC-004 A2, jamais un état neutre',
      (WidgetTester tester) async {
        final OndeObservation nonObserve = _observation(
          observedAt: DateTime.utc(2026, 8, 25),
          rawFlowCode: '4',
          officialLabel: 'Observation impossible',
          campaignCode: '109905',
        );

        await _pump(
          tester,
          OndeSummarySheet(
            data: _data(
              history: <OndeObservation>[nonObserve],
              officialModalityText: 'code 4 — Observation impossible',
            ),
          ),
        );

        expect(find.text(ondePointNonObserveText), findsOneWidget);
        expect(find.text('Non observé'), findsOneWidget);
      },
    );

    testWidgets('une catégorie observée ne porte PAS la phrase de UC-004 A2', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.text(ondePointNonObserveText), findsNothing);
    });
  });

  group('vocabulaire — BR-003 et BR-014', () {
    testWidgets('aucun des cinq mots bannis dans AUCUN des quatre états du '
        'panneau — toute la copie du produit est balayée', (
      WidgetTester tester,
    ) async {
      for (final OndeSheetState state in _panelStates()) {
        await _pump(tester, OndeSheetPanel(state: state, onClose: () {}));

        for (final String text in _renderedTexts(tester)) {
          expect(
            _bannedWords.hasMatch(text),
            isFalse,
            reason: 'mot banni dans « $text » (état ${state.runtimeType})',
          );
        }
      }
    });

    testWidgets(
      'aucun mot de garantie dans AUCUN des quatre états du panneau (BR-014)',
      (WidgetTester tester) async {
        for (final OndeSheetState state in _panelStates()) {
          await _pump(tester, OndeSheetPanel(state: state, onClose: () {}));

          for (final String text in _renderedTexts(tester)) {
            expect(
              _guaranteeWords.hasMatch(text),
              isFalse,
              reason:
                  'mot de garantie dans « $text » (état ${state.runtimeType})',
            );
          }
        }
      },
    );

    // La réserve de `BR-014` sur les libellés d'une autorité, bornée : le mot
    // « officiel » ne sert QU'À attribuer la nomenclature ONDE à sa source
    // (`UC-004 § 3`), jamais à qualifier nos propres données.
    testWidgets("le mot « officiel » ne sert qu'à attribuer la nomenclature "
        'ONDE', (WidgetTester tester) async {
      final RegExp officiel = RegExp('officiel', caseSensitive: false);

      for (final OndeSheetState state in _panelStates()) {
        await _pump(tester, OndeSheetPanel(state: state, onClose: () {}));

        for (final String text in _renderedTexts(tester)) {
          if (!officiel.hasMatch(text)) {
            continue;
          }
          expect(
            text.startsWith(ondeModalitePrefix),
            isTrue,
            reason: 'occurrence hors attribution dans « $text »',
          );
        }
      }
    });
  });

  group('OndeSheetPanel — les quatre états de la fiche', () {
    testWidgets('OndeSheetFermee ne rend rien', (WidgetTester tester) async {
      await _pump(
        tester,
        OndeSheetPanel(state: const OndeSheetFermee(), onClose: () {}),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(OndeSummarySheet), findsNothing);
    });

    testWidgets('OndeSheetEnCours nomme le point demandé', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(state: OndeSheetEnCours(_chaon()), onClose: () {}),
      );

      expect(
        find.textContaining('LA RIVIERE AUX LOCHES A CHAON'),
        findsOneWidget,
      );
    });

    testWidgets(
      "OndeSheetEnEchec nomme la source défaillante et le point — jamais une "
      'feuille vide (UC-001 A4)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(
            state: OndeSheetEnEchec(_chaon(), StateError('socket')),
            onClose: () {},
          ),
        );

        expect(find.textContaining("Hub'Eau"), findsOneWidget);
        expect(
          find.textContaining('LA RIVIERE AUX LOCHES A CHAON'),
          findsOneWidget,
        );
      },
    );

    testWidgets('OndeSheetEnEchec ne rend jamais la cause technique brute', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(
          state: OndeSheetEnEchec(_chaon(), StateError('socket')),
          onClose: () {},
        ),
      );

      expect(find.textContaining('socket'), findsNothing);
    });

    testWidgets('OndeSheetPrete rend la feuille de résumé', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
      );

      expect(find.byType(OndeSummarySheet), findsOneWidget);
      expect(find.text('LA RIVIERE AUX LOCHES A CHAON'), findsOneWidget);
    });

    testWidgets(
      'le bouton de fermeture mesure au moins 44 × 44 pt (04-ui.md § 3)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
        );

        final Size size = tester.getSize(find.byKey(ondeSheetCloseButtonKey));

        expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
        expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
      },
    );

    testWidgets('le bouton de fermeture appelle onClose', (
      WidgetTester tester,
    ) async {
      int closed = 0;
      await _pump(
        tester,
        OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () => closed++),
      );

      await tester.tap(find.byKey(ondeSheetCloseButtonKey));
      await tester.pump();

      expect(closed, 1);
    });

    testWidgets('EnCours et EnEchec portent aussi un bouton de fermeture', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(state: OndeSheetEnCours(_chaon()), onClose: () {}),
      );
      expect(find.byKey(ondeSheetCloseButtonKey), findsOneWidget);

      await _pump(
        tester,
        OndeSheetPanel(
          state: OndeSheetEnEchec(_chaon(), StateError('socket')),
          onClose: () {},
        ),
      );
      expect(find.byKey(ondeSheetCloseButtonKey), findsOneWidget);
    });
  });
}

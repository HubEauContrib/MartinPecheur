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
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

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
      expect(minimumTapTargetFor(TargetPlatform.windows), 44.0);
    });
  });

  group('OndeSummarySheet — le contenu de la fiche (UC-004 § 3 et § 4)', () {
    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
      "cours d'eau nul → une absence honnête, jamais une ligne vide (BR-007)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSummarySheet(data: _data(point: _chaon(waterCourseLabel: null))),
        );

        expect(find.text(ondeCoursDEauNonRenseigne), findsOneWidget);
      },
    );

    testWidgetsOnWindows('département nul → une absence honnête (BR-007)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSummarySheet(data: _data(point: _chaon(departement: null))),
      );

      expect(find.text(ondeDepartementNonRenseigne), findsOneWidget);
    });

    testWidgetsOnWindows(
      'rend la catégorie « À sec » — le libellé d INTERFACE, jamais « Assec »',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.text('À sec'), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'rend la modalité officielle exacte : « code 3 » et « Assec » '
      '(ADR-006, UC-004 § 3)',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.textContaining('code 3'), findsOneWidget);
        expect(find.textContaining('Assec'), findsOneWidget);
      },
    );

    testWidgetsOnWindows('rend la date de la campagne, sans heure (T-08)', (
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

    testWidgetsOnWindows(
      "rend l'âge de la campagne — le nombre et le mot « jour » "
      '(BR-010)',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.textContaining('il y a 19 jours'), findsOneWidget);
      },
    );

    // L'invariant de `U4` : les trois informations sont sur la MÊME fiche et
    // dans CET ordre, sans exception (`UC-004`, `BR-010`, `ADR-006`).
    testWidgetsOnWindows(
      'ordre imposé : catégorie, puis modalité officielle, puis '
      'date de campagne',
      (WidgetTester tester) async {
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
      },
    );

    // L'invariant de `W4`, tenu désormais par le contrôle d'avertissement
    // (`W3c`) : voir le groupe « le contrôle d'avertissement de tête »
    // ci-dessous pour l'assertion d'ordre EN TÊTE, avant la catégorie.

    testWidgetsOnWindows(
      'rend les CINQ campagnes de la fixture, chacune avec sa date '
      'et sa catégorie, la plus récente en tête (UC-004 § 4)',
      (WidgetTester tester) async {
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
          expect(
            top,
            greaterThan(previous),
            reason: 'ordre rompu sur « $line »',
          );
          previous = top;
        }
      },
    );

    testWidgetsOnWindows('le rappel de rythme est rendu (UC-004 § 5)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.text(ondeSeasonNotice), findsOneWidget);
    });

    testWidgetsOnWindows(
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
    testWidgetsOnWindows(
      'le contrôle est TOUJOURS rendu, avec ou sans campagne',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.byType(WarningLink), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
      'rend la mention « dernière observation le 26/09/2025 »',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: ancienne()));

        expect(
          find.textContaining('dernière observation le 26/09/2025'),
          findsOneWidget,
        );
      },
    );

    // Relecture du 2026-09-14 : `#767676` (4,54:1) ne tient pas les 7:1
    // qu'exige `04-ui.md` § 3 pour un libellé d'état. `BR-010` reste
    // respecté autrement — la mention datée, vérifiée ici, et le marqueur
    // de la carte (`U3`) — sans recolorer le texte de la catégorie.
    testWidgetsOnWindows(
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

    testWidgetsOnWindows('une campagne récente ne porte pas la mention', (
      WidgetTester tester,
    ) async {
      await _pump(tester, OndeSummarySheet(data: _data()));

      expect(find.text('À sec'), findsOneWidget);
      expect(find.textContaining('dernière observation'), findsNothing);
    });
  });

  group('OndeSummarySheet — les absences (UC-004 A2 et A4, BR-007)', () {
    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
      'une catégorie observée ne porte PAS la phrase de UC-004 A2',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(find.text(ondePointNonObserveText), findsNothing);
      },
    );
  });

  group('vocabulaire — BR-003 et BR-014', () {
    testWidgetsOnWindows(
      'aucun des cinq mots bannis dans AUCUN des quatre états du '
      'panneau — toute la copie du produit est balayée',
      (WidgetTester tester) async {
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
      },
    );

    testWidgetsOnWindows(
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
    testWidgetsOnWindows(
      "le mot « officiel » ne sert qu'à attribuer la nomenclature "
      'ONDE',
      (WidgetTester tester) async {
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
      },
    );
  });

  group('OndeSheetPanel — les quatre états de la fiche', () {
    testWidgetsOnWindows('OndeSheetFermee ne rend rien', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(state: const OndeSheetFermee(), onClose: () {}),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(OndeSummarySheet), findsNothing);
    });

    testWidgetsOnWindows('OndeSheetEnCours nomme le point demandé', (
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

    testWidgetsOnWindows(
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

    testWidgetsOnWindows(
      'OndeSheetEnEchec ne rend jamais la cause technique brute',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(
            state: OndeSheetEnEchec(_chaon(), StateError('socket')),
            onClose: () {},
          ),
        );

        expect(find.textContaining('socket'), findsNothing);
      },
    );

    testWidgetsOnWindows('OndeSheetPrete rend la feuille de résumé', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
      );

      expect(find.byType(OndeSummarySheet), findsOneWidget);
      expect(find.text('LA RIVIERE AUX LOCHES A CHAON'), findsOneWidget);
    });

    testWidgetsOnWindows(
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

    testWidgetsOnWindows('le bouton de fermeture appelle onClose', (
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

    testWidgetsOnWindows(
      'EnCours et EnEchec portent aussi un bouton de fermeture',
      (WidgetTester tester) async {
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
      },
    );
  });

  // `S7a` de T3 : l'étoile de favori entre dans le cadre commun. Sans étoile à
  // montrer (`favoriteStar` nul) le cadre est celui d'avant, au pixel : les
  // groupes précédents n'ont pas bougé.
  group("OndeSheetPanel — l'étoile de favori (S7a de T3)", () {
    const FavoriteStar empty = FavoriteStar(filled: false, enabled: true);
    const FavoriteStar full = FavoriteStar(filled: true, enabled: true);

    Widget panel(
      OndeSheetState state, {
      FavoriteStar? star,
      VoidCallback? onToggle,
      VoidCallback? onClose,
    }) => OndeSheetPanel(
      state: state,
      onClose: onClose ?? () {},
      favoriteStar: star,
      onToggleFavorite: star == null ? null : (onToggle ?? () {}),
    );

    /// Le panneau tel que la carte le pose : largeur bornée (420), hauteur
    /// libre. Sert aux mesures « avec et sans étoile ».
    Future<void> pump420(WidgetTester tester, Widget child) => _pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: child,
      ),
    );

    Future<Size> contentSize(
      WidgetTester tester,
      OndeSheetState state, {
      FavoriteStar? star,
    }) async {
      await pump420(tester, panel(state, star: star));
      return tester.getSize(find.byType(OndeSummarySheet));
    }

    Color? ringColor(WidgetTester tester) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(KeyboardFocusRing),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).border?.top.color;
    }

    testWidgetsOnWindows(
      "Prete : l'étoile ne rétrécit pas le contenu et n'allonge pas la "
      'fiche (même largeur, même hauteur avec et sans étoile)',
      (WidgetTester tester) async {
        // Fenêtre haute : la fiche Prete et son historique de cinq campagnes
        // dépassent les 600 px de la fenêtre de test par défaut (602 px), avec
        // ou sans étoile.
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final Size without = await contentSize(tester, OndeSheetPrete(_data()));
        final Size panelWithout = tester.getSize(find.byType(OndeSheetPanel));
        final Rect closeWithout = tester.getRect(
          find.byKey(ondeSheetCloseButtonKey),
        );
        expect(find.byKey(favoriteStarButtonKey), findsNothing);

        final Size withStar = await contentSize(
          tester,
          OndeSheetPrete(_data()),
          star: empty,
        );
        final Size panelWith = tester.getSize(find.byType(OndeSheetPanel));

        expect(withStar.width, without.width);
        expect(withStar.height, without.height);
        expect(panelWith, panelWithout);
        // Le bouton de fermeture n'a pas bougé.
        expect(
          tester.getRect(find.byKey(ondeSheetCloseButtonKey)),
          closeWithout,
        );
      },
    );

    testWidgetsOnWindows(
      "l'étoile est SOUS le bouton de fermeture, alignée sur lui, à 8 px ; "
      'sans étoile, aucun emplacement vide',
      (WidgetTester tester) async {
        // Libellé court : le texte tient sur une ligne, plus bas que les
        // boutons, pour que la hauteur du cadre soit celle des boutons.
        final OndeSheetState state = OndeSheetEnCours(
          OndePoint(
            code: _code(),
            label: 'Chaon',
            latitude: 47.6,
            longitude: 2.17,
            waterCourseLabel: null,
            departement: null,
          ),
        );
        await pump420(tester, panel(state));
        final Size none = tester.getSize(find.byType(OndeSheetPanel));
        final Rect closeAlone = tester.getRect(
          find.byKey(ondeSheetCloseButtonKey),
        );
        // 12 + fermeture + 12 : rien de réservé pour une étoile absente.
        expect(none.height, 12 + minimumTapTarget + 12);

        await pump420(tester, panel(state, star: full));
        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(find.byKey(ondeSheetCloseButtonKey));
        expect(close, closeAlone);
        expect(star.size, Size(minimumTapTarget, minimumTapTarget));
        expect(star.left, closeTo(close.left, 0.01));
        expect(star.top - close.bottom, closeTo(8, 0.01));
        expect(
          tester.getSize(find.byType(OndeSheetPanel)).height,
          12 + minimumTapTarget + 8 + minimumTapTarget + 12,
        );
      },
    );

    testWidgetsOnWindows(
      "Tab atteint l'étoile (un arrêt de tabulation ; le bouton de fermeture "
      "n'en est pas un)",
      (WidgetTester tester) async {
        await _pump(tester, panel(OndeSheetEnCours(_chaon()), star: full));
        expect(ringColor(tester), Colors.transparent);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(ringColor(tester), focusRingColor);
      },
    );

    testWidgetsOnWindows(
      "le focus clavier de l'étoile survit à une écriture : inactive pendant "
      "l'écriture, puis active avec l'avis d'échec — toujours focalisée",
      (WidgetTester tester) async {
        final OndeSheetState state = OndeSheetEnCours(_chaon());
        await _pump(tester, panel(state, star: empty));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(ringColor(tester), focusRingColor);

        await _pump(
          tester,
          panel(state, star: const FavoriteStar(filled: false, enabled: false)),
        );
        await tester.pump();
        expect(ringColor(tester), focusRingColor);

        await _pump(
          tester,
          panel(
            state,
            star: const FavoriteStar(
              filled: false,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );
        await tester.pump();

        expect(ringColor(tester), focusRingColor);
        expect(
          find.text("Le favori n'a pas pu être enregistré."),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'le tap appelle onToggleFavorite, la fermeture onClose',
      (WidgetTester tester) async {
        int toggled = 0;
        int closed = 0;
        await _pump(
          tester,
          panel(
            OndeSheetPrete(_data()),
            star: empty,
            onToggle: () => toggled++,
            onClose: () => closed++,
          ),
        );

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();
        expect(toggled, 1);
        expect(closed, 0);

        await tester.tap(find.byKey(ondeSheetCloseButtonKey));
        await tester.pump();
        expect(closed, 1);
        expect(toggled, 1);
      },
    );

    testWidgetsOnWindows(
      'favoriteStar nul, dans chacun des états visibles : aucune étoile',
      (WidgetTester tester) async {
        final List<OndeSheetState> visible = <OndeSheetState>[
          OndeSheetEnCours(_chaon()),
          OndeSheetPrete(_data()),
          OndeSheetEnEchec(_chaon(), StateError('socket')),
        ];
        for (final OndeSheetState state in visible) {
          await _pump(tester, panel(state));

          expect(find.byKey(favoriteStarButtonKey), findsNothing);
          expect(find.byType(FavoriteStarButton), findsNothing);
          expect(find.byKey(ondeSheetCloseButtonKey), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows(
      "OndeSheetFermee avec une étoile non nulle : rien n'est rendu",
      (WidgetTester tester) async {
        await _pump(tester, panel(const OndeSheetFermee(), star: full));

        expect(find.byType(FavoriteStarButton), findsNothing);
        expect(find.byType(Text), findsNothing);
        expect(find.byKey(ondeSheetCloseButtonKey), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "OndeSheetEnEchec avec une étoile pleine : l'étoile ET le texte "
      "d'échec",
      (WidgetTester tester) async {
        await _pump(
          tester,
          panel(OndeSheetEnEchec(_chaon(), StateError('socket')), star: full),
        );

        expect(find.byKey(favoriteStarButtonKey), findsOneWidget);
        expect(
          find.textContaining(
            "Hub'Eau n'a pas répondu pour le point "
            'LA RIVIERE AUX LOCHES A CHAON.',
          ),
          findsOneWidget,
        );
        expect(find.byType(FavoriteWriteFailedNotice), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "un ajout en échec (étoile vide) : « enregistré », sous la rangée, "
      "l'étoile reste vide",
      (WidgetTester tester) async {
        await _pump(
          tester,
          panel(
            OndeSheetPrete(_data()),
            star: const FavoriteStar(
              filled: false,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );

        expect(
          find.text("Le favori n'a pas pu être enregistré."),
          findsOneWidget,
        );
        expect(find.text("Le favori n'a pas pu être retiré."), findsNothing);
        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        final double noticeTop = tester
            .getTopLeft(find.byType(FavoriteWriteFailedNotice))
            .dy;
        expect(
          noticeTop,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.byKey(favoriteStarButtonKey)).dy,
          ),
        );
        expect(
          noticeTop,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.byKey(ondeSheetCloseButtonKey)).dy,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      "un retrait en échec (étoile pleine) : « retiré », l'étoile reste "
      "pleine, l'autre phrase est absente",
      (WidgetTester tester) async {
        await _pump(
          tester,
          panel(
            OndeSheetPrete(_data()),
            star: const FavoriteStar(
              filled: true,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );

        expect(find.text("Le favori n'a pas pu être retiré."), findsOneWidget);
        expect(
          find.text("Le favori n'a pas pu être enregistré."),
          findsNothing,
        );
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "sans échec d'écriture, ou liste illisible : aucune des deux phrases",
      (WidgetTester tester) async {
        final List<FavoriteStar> stars = <FavoriteStar>[
          empty,
          full,
          const FavoriteStar(filled: false, enabled: false),
        ];
        for (final FavoriteStar star in stars) {
          await _pump(tester, panel(OndeSheetPrete(_data()), star: star));

          expect(find.byKey(favoriteStarButtonKey), findsOneWidget);
          expect(find.byType(FavoriteWriteFailedNotice), findsNothing);
          expect(find.textContaining('Le favori'), findsNothing);
        }
      },
    );

    testWidgetsOnWindows(
      "étoile inactive : le tap n'appelle pas onToggleFavorite",
      (WidgetTester tester) async {
        int toggled = 0;
        await _pump(
          tester,
          panel(
            OndeSheetPrete(_data()),
            star: const FavoriteStar(filled: false, enabled: false),
            onToggle: () => toggled++,
          ),
        );

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();

        expect(toggled, 0);
      },
    );

    testWidgetsOnAndroid(
      'Android : à 360 px et 200 % de police, le cadre (étoile sous la '
      "fermeture, avis d'échec) reste dans l'écran",
      (WidgetTester tester) async {
        // Ce test mesure LE CADRE, avec un contenu court (OndeSheetEnCours).
        // La fiche `Prete` entière ne tient pas à 200 % sur 360 x 640 (cas de
        // la fiche station, mesuré) : ce débordement est ANTÉRIEUR à T3 — la
        // fiche n'est ni défilante ni bornée en hauteur (`map_view.dart`,
        // colonne des fiches). Point ouvert, hors de `S7a`.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: panel(
                  OndeSheetEnCours(_chaon()),
                  star: const FavoriteStar(
                    filled: false,
                    enabled: true,
                    writeFailed: true,
                  ),
                ),
              ),
            ),
          ),
        );

        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(find.byKey(ondeSheetCloseButtonKey));
        expect(star.size, const Size(48, 48));
        expect(close.size, const Size(48, 48));
        expect(star.left, closeTo(close.left, 0.01));
        expect(star.top - close.bottom, closeTo(8, 0.01));
        expect(close.right, lessThanOrEqualTo(360));
        expect(
          tester.getRect(find.byType(FavoriteWriteFailedNotice)).right,
          lessThanOrEqualTo(360),
        );
        expect(
          tester.getRect(find.byType(FavoriteWriteFailedNotice)).bottom,
          lessThanOrEqualTo(640),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

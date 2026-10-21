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
//
// Depuis `F2` d'Ergonomie, la fiche est dans le cadre commun (`SheetFrame`) et
// son corps porte une TUILE de catégorie puis l'historique à symboles. Le
// symbole de légende n'est pas dessiné par la fiche : il lui est FOURNI
// (`OndeCategorySymbol`), et ces tests lui passent un symbole de test. Les
// tests de disposition mesurent en Roboto, chargée depuis le SDK
// (`test/support/roboto.dart`) pour TOUT ce fichier.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsNode;
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
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_fiches.dart';
import '../../../support/focus.dart';
import '../../../support/roboto.dart';
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

/// Le symbole de test fourni à la fiche (`F2` d'Ergonomie) : une boîte vide
/// dont la clé dit la catégorie et la taille demandée, de 32 pt dans la tuile
/// et de 16 pt dans une ligne d'historique.
Widget _testSymbol(FlowCategory category, {required bool compact}) => SizedBox(
  key: ValueKey<String>('symbole-${category.runtimeType}-$compact'),
  width: compact ? 16 : 32,
  height: compact ? 16 : 32,
);

/// Le symbole de test, qui PORTE un libellé de lecteur d'écran : si la fiche ne
/// l'excluait pas des annonces, ce libellé s'y entendrait (`F2`, passe 1).
Widget _announcingSymbol(FlowCategory category, {required bool compact}) =>
    Semantics(
      label: 'SYMBOLE-${category.runtimeType}-$compact',
      child: _testSymbol(category, compact: compact),
    );

/// Les symboles de test rendus, dans l'ordre de l'arbre : les non compacts
/// (ceux de la tuile) ou, si [compact], les compacts (ceux de l'historique).
Finder _symbols({required bool compact}) => find.byWidgetPredicate(
  (Widget widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('symbole-') &&
      (widget.key! as ValueKey<String>).value.endsWith('-$compact'),
);

/// Pose la fenêtre à la taille d'un téléphone, à l'échelle 1.
void _setPhoneView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pose [child] à 200 % de police, en haut à gauche de la fenêtre.
Future<void> _pumpAt200(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    builder: (BuildContext context, Widget? app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(2)),
      child: app!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

/// Tous les libellés annoncés par l'arbre sémantique, du haut en bas.
List<String> _announcedLabels(WidgetTester tester) {
  final List<String> labels = <String>[];
  void visit(SemanticsNode node) {
    labels.add(node.label);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  // Le nœud qui porte le panneau, ou son plus proche ancêtre : tout le
  // panneau est dessous.
  visit(tester.getSemantics(find.byType(OndeSheetPanel)));
  return labels;
}

/// L'annonce fusionnée de la tuile de catégorie, et le nombre de nœuds
/// sémantiques qu'elle contient (0 : un seul nœud, tout y est fusionné).
({String label, int childNodes}) _tileAnnouncement(WidgetTester tester) {
  final SemanticsNode node = tester.getSemantics(
    find.byKey(ondeCategoryTileKey),
  );
  return (label: node.label, childNodes: node.childrenCount);
}

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Vrai si [a] se lit avant [b] : plus haut, ou sur la même ligne et à gauche.
bool _readsBefore(Rect a, Rect b) =>
    a.top < b.top - 0.01 ||
    ((a.top - b.top).abs() <= 0.01 && a.left < b.left - 0.01);

/// Aucun mot coupé : chaque paragraphe du panneau est posé au moins aussi
/// large que son mot le plus long (sa largeur intrinsèque minimale).
void _expectNoWordCut(WidgetTester tester) {
  final Iterable<RenderParagraph> paragraphs = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(OndeSheetPanel),
          matching: find.byType(RichText),
        ),
      );
  expect(paragraphs, isNotEmpty);
  for (final RenderParagraph paragraph in paragraphs) {
    expect(
      paragraph.size.width + 0.5,
      greaterThanOrEqualTo(paragraph.getMinIntrinsicWidth(double.infinity)),
      reason: 'mot coupé dans « ${paragraph.text.toPlainText()} »',
    );
  }
}

/// La ligne de campagne telle que la fiche l'écrit, pour la campagne du
/// 25/08/2026 de 19 jours (`_data()`).
const String _campagneRecente =
    'Campagne du 25/08/2026 — il y a 19 jours — $ondeSourceName';

void main() {
  setUpAll(chargerRoboto);

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

        // Depuis `F2` d'Ergonomie, « <cours d'eau> · <département> » est UNE
        // ligne (spec § 6.3, § 11.2), comme sur la fiche station.
        expect(
          find.text("$ondeCoursDEauNonRenseigne · Département 41"),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows('département nul → une absence honnête (BR-007)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        OndeSummarySheet(data: _data(point: _chaon(departement: null))),
      );

      expect(
        find.text(
          'ruisseau la rivière aux loches · $ondeDepartementNonRenseigne',
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnWindows(
      'ligne cours d\'eau · département : « <cours d\'eau> · Département '
      '<code> », sur une seule ligne',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        expect(
          find.text('ruisseau la rivière aux loches · Département 41'),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'le titre du point est mis en avant : 20, gras (comme la fiche station)',
      (WidgetTester tester) async {
        await _pump(tester, OndeSummarySheet(data: _data()));

        final TextStyle? titre = tester
            .widget<Text>(find.text('LA RIVIERE AUX LOCHES A CHAON'))
            .style;
        expect(titre?.fontSize, 20);
        expect(titre?.fontWeight, FontWeight.bold);
      },
    );

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

  // Depuis `F2` d'Ergonomie, le contrôle est dans l'EN-TÊTE du cadre commun
  // (`SheetFrame`), plus dans la feuille de résumé : ces tests rendent le
  // panneau.
  group("OndeSheetPanel — le contrôle d'avertissement de tête (W3c, "
      "arbitrage du commanditaire du 2026-09-23 ; F2 d'Ergonomie)", () {
    testWidgetsOnWindows(
      'le contrôle est TOUJOURS rendu, avec ou sans campagne',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
        );
        expect(find.byType(WarningLink), findsOneWidget);

        await _pump(
          tester,
          OndeSheetPanel(
            state: OndeSheetPrete(
              _data(
                history: <OndeObservation>[],
                officialModalityText: 'Aucune campagne connue pour ce point.',
              ),
            ),
            onClose: () {},
          ),
        );
        expect(find.byType(WarningLink), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'le contrôle est rendu EN TÊTE, avant la catégorie — assertion sur '
      "l'ORDRE dans l'arbre, pas sur la seule présence",
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
        );

        final double linkTop = tester.getTopLeft(find.byType(WarningLink)).dy;
        final double categoryTop = tester
            .getTopLeft(find.text(flowCategoryLabel(_data().latest!.category)))
            .dy;

        expect(linkTop, lessThan(categoryTop));
      },
    );

    testWidgetsOnWindows(
      'la feuille de résumé seule ne porte plus le contrôle : il est dans '
      "l'en-tête du cadre, épinglé (F2 d'Ergonomie, spec § 6.1)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
        );

        expect(
          find.descendant(
            of: find.byType(OndeSummarySheet),
            matching: find.byType(WarningLink),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(sheetFrameHeaderKey),
            matching: find.byType(WarningLink),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'avec une campagne, la fenêtre porte la phrase datée, plus insistante '
      'que la version station (UC-004 § 1)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          OndeSheetPanel(state: OndeSheetPrete(_data()), onClose: () {}),
        );

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
          OndeSheetPanel(
            state: OndeSheetPrete(
              _data(
                history: <OndeObservation>[],
                officialModalityText: 'Aucune campagne connue pour ce point.',
              ),
            ),
            onClose: () {},
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

  group("OndeSheetPanel — le cadre commun et l'ordre du corps (F2 "
      "d'Ergonomie, spec § 6.1, § 6.3, critère 12)", () {
    List<OndeSheetState> visibles() => <OndeSheetState>[
      OndeSheetEnCours(_chaon()),
      OndeSheetPrete(_data()),
      OndeSheetEnEchec(_chaon(), StateError('socket')),
    ];

    Widget prete({
      OndeCategorySymbol? symbol,
      OndeSheetData? data,
      ScrollController? controller,
    }) => OndeSheetPanel(
      state: OndeSheetPrete(data ?? _data()),
      onClose: () {},
      categorySymbol: symbol,
      bodyScrollController: controller,
    );

    /// Les neuf éléments de l'ordre de lecture de la fiche prête (critère 12,
    /// spec § 6.3) : nature < « ⚠ Avertissement » < titre < ligne cours d'eau ·
    /// département < catégorie < modalité < campagne < « Campagnes
    /// précédentes » < rappel.
    List<Rect> ordreDeLecture(WidgetTester tester) => <Rect>[
      _rectOf(tester, find.text(ondeSheetNature)),
      _rectOf(tester, find.byKey(warningLinkKey)),
      _rectOf(tester, find.text('LA RIVIERE AUX LOCHES A CHAON')),
      _rectOf(
        tester,
        find.text('ruisseau la rivière aux loches · Département 41'),
      ),
      _rectOf(tester, find.text('À sec')),
      _rectOf(tester, find.textContaining('code 3')),
      _rectOf(tester, find.textContaining(_campagneRecente)),
      _rectOf(tester, find.text(ondeHistoriqueTitre)),
      _rectOf(tester, find.text(ondeSeasonNotice)),
    ];

    void expectOrder(List<Rect> ordre) {
      expect(ordre, hasLength(9));
      for (int i = 0; i + 1 < ordre.length; i++) {
        expect(
          _readsBefore(ordre[i], ordre[i + 1]),
          isTrue,
          reason: 'élément $i (${ordre[i]}) avant ${i + 1} (${ordre[i + 1]})',
        );
      }
    }

    testWidgetsOnWindows(
      'les trois états visibles sont dans un SheetFrame : la nature « Point '
      'ONDE » et « ⚠ Avertissement » dans son en-tête, jamais le code du '
      'point (arbitrage 5)',
      (WidgetTester tester) async {
        for (final OndeSheetState state in visibles()) {
          await _pump(tester, OndeSheetPanel(state: state, onClose: () {}));

          expect(find.byType(SheetFrame), findsOneWidget);
          final Finder entete = find.byKey(sheetFrameHeaderKey);
          expect(
            find.descendant(of: entete, matching: find.text('Point ONDE')),
            findsOneWidget,
            reason: 'nature (${state.runtimeType})',
          );
          expect(
            find.descendant(of: entete, matching: find.byType(WarningLink)),
            findsOneWidget,
            reason: '« ⚠ Avertissement » (${state.runtimeType})',
          );
          expect(
            find.descendant(
              of: entete,
              matching: find.byKey(ondeSheetCloseButtonKey),
            ),
            findsOneWidget,
          );
          for (final String text in _renderedTexts(tester)) {
            expect(
              text.contains(_code().value),
              isFalse,
              reason:
                  'le code du point ne s\'affiche pas : « $text » '
                  '(${state.runtimeType})',
            );
          }
        }
      },
    );

    testWidgetsOnWindows(
      'la phrase datée de la fenêtre en Prete seulement : en chargement et en '
      "échec, la fenêtre s'ouvre sans phrase propre",
      (WidgetTester tester) async {
        for (final OndeSheetState state in visibles()) {
          await _pump(tester, OndeSheetPanel(state: state, onClose: () {}));
          await tester.tap(find.byKey(warningLinkKey));
          await tester.pumpAndSettle();

          expect(
            find.byKey(warningWindowExtraTextKey),
            state is OndeSheetPrete ? findsOneWidget : findsNothing,
            reason: state.runtimeType.toString(),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgetsOnWindows(
      'Prete se lit dans l\'ordre : nature < « ⚠ Avertissement » < titre < '
      "cours d'eau · département < catégorie < modalité < campagne < "
      '« Campagnes précédentes » < rappel — avec un symbole fourni',
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _testSymbol));

        expectOrder(ordreDeLecture(tester));
      },
    );

    testWidgetsOnWindows(
      'sans symbole fourni : mêmes textes, même ordre, aucun symbole, aucune '
      'erreur',
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _testSymbol));
        final List<String> avec = _renderedTexts(tester);

        await _pump(tester, prete());

        expect(tester.takeException(), isNull);
        expect(_symbols(compact: false), findsNothing);
        expect(_symbols(compact: true), findsNothing);
        expect(_renderedTexts(tester), avec);
        expectOrder(ordreDeLecture(tester));
      },
    );

    testWidgetsOnWindows(
      'la tuile porte la catégorie (22, gras), la modalité et la campagne '
      "datée et sourcée — et rien d'autre ; l'historique est dessous",
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _testSymbol));

        final Finder tuile = find.byKey(ondeCategoryTileKey);
        for (final Finder dedans in <Finder>[
          find.text('À sec'),
          find.textContaining('Modalité officielle ONDE : code 3 — Assec'),
          find.textContaining(_campagneRecente),
        ]) {
          expect(
            find.descendant(of: tuile, matching: dedans),
            findsOneWidget,
            reason: 'dans la tuile : $dedans',
          );
        }
        expect(
          find.descendant(of: tuile, matching: find.byType(Text)),
          findsNWidgets(3),
          reason: 'catégorie, modalité, campagne',
        );
        final TextStyle? categorie = tester
            .widget<Text>(find.text('À sec'))
            .style;
        expect(categorie?.fontSize, 22);
        expect(categorie?.fontWeight, FontWeight.bold);
        // L'historique et le rappel sont hors de la tuile, dessous.
        final Rect rectTuile = _rectOf(tester, tuile);
        expect(
          _rectOf(tester, find.text(ondeHistoriqueTitre)).top,
          greaterThanOrEqualTo(rectTuile.bottom),
        );
        expect(
          _rectOf(tester, find.text(ondeSeasonNotice)).top,
          greaterThanOrEqualTo(rectTuile.bottom),
        );
      },
    );

    // `F2`, passe 1 : comme la tuile Débit de la fiche station (`F1`), la
    // tuile ONDE est UN nœud d'annonce. Une catégorie ne s'annonce jamais sans
    // sa modalité, sa date ni sa source (`BR-001`, `BR-010`).
    testWidgetsOnWindows(
      "la tuile est UN SEUL nœud d'annonce : la catégorie, la modalité, puis "
      'la campagne datée et sourcée, dans cet ordre ; le symbole fourni '
      "n'est pas annoncé (BR-001, BR-010)",
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _announcingSymbol));

        final ({String label, int childNodes}) annonce = _tileAnnouncement(
          tester,
        );
        expect(
          annonce.childNodes,
          0,
          reason: 'un seul nœud, tout y est fusionné',
        );
        int depuis = 0;
        for (final String texte in <String>[
          'À sec',
          'Modalité officielle ONDE : code 3 — Assec',
          'Campagne du 25/08/2026 — il y a 19 jours',
          ondeSourceName,
        ]) {
          final int index = annonce.label.indexOf(texte, depuis);
          expect(
            index,
            greaterThanOrEqualTo(0),
            reason: '« $texte » après les précédents dans « ${annonce.label} »',
          );
          depuis = index + texte.length;
        }
        // Rien de ce qui est hors de la tuile, et pas le symbole.
        expect(annonce.label, isNot(contains('LA RIVIERE AUX LOCHES A CHAON')));
        expect(annonce.label, isNot(contains(ondeHistoriqueTitre)));
        expect(annonce.label, isNot(contains('SYMBOLE')));
      },
    );

    testWidgetsOnWindows(
      "code 4 : l'annonce de la tuile porte la phrase de UC-004 A2 entre la "
      'catégorie et la modalité (BR-007)',
      (WidgetTester tester) async {
        final OndeObservation nonObserve = _observation(
          observedAt: DateTime.utc(2026, 8, 25),
          rawFlowCode: '4',
          officialLabel: 'Observation impossible',
          campaignCode: '109905',
        );
        await _pump(
          tester,
          prete(
            symbol: _announcingSymbol,
            data: _data(
              history: <OndeObservation>[nonObserve],
              officialModalityText: 'code 4 — Observation impossible',
            ),
          ),
        );

        final ({String label, int childNodes}) annonce = _tileAnnouncement(
          tester,
        );
        expect(annonce.childNodes, 0);
        int depuis = 0;
        for (final String texte in <String>[
          'Non observé',
          ondePointNonObserveText,
          'Modalité officielle ONDE : code 4 — Observation impossible',
          'Campagne du 25/08/2026 — il y a 19 jours',
          ondeSourceName,
        ]) {
          final int index = annonce.label.indexOf(texte, depuis);
          expect(
            index,
            greaterThanOrEqualTo(0),
            reason: '« $texte » après les précédents dans « ${annonce.label} »',
          );
          depuis = index + texte.length;
        }
        expect(annonce.label, isNot(contains('SYMBOLE')));
      },
    );

    // Le symbole est décoratif (R7 : le texte dit déjà la catégorie). Ce test
    // rend le retrait de l'`ExcludeSemantics` bruyant : si `D5` veut que le
    // symbole s'annonce, il change ce test en le sachant.
    testWidgetsOnWindows(
      "le symbole fourni est décoratif : son libellé n'est annoncé nulle "
      "part, ni dans la tuile ni dans l'historique (R7)",
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _announcingSymbol));

        expect(_symbols(compact: false), findsOneWidget);
        expect(_symbols(compact: true), findsNWidgets(5));
        final List<String> annonces = _announcedLabels(tester);
        expect(
          annonces.where((String libelle) => libelle.contains('SYMBOLE')),
          isEmpty,
          reason: annonces.join(' | '),
        );
        // Les textes de l'historique, eux, sont bien annoncés.
        expect(
          annonces.any((String libelle) => libelle == '25/08/2026 — À sec'),
          isTrue,
          reason: annonces.join(' | '),
        );
      },
    );

    testWidgetsOnWindows(
      'avec un symbole : un non compact AVANT la catégorie, dans la tuile ; '
      "un compact par ligne d'historique, sur la ligne de sa date",
      (WidgetTester tester) async {
        await _pump(tester, prete(symbol: _testSymbol));

        // La tuile : un seul symbole, non compact, celui de la catégorie.
        final Finder tuile = find.byKey(ondeCategoryTileKey);
        expect(_symbols(compact: false), findsOneWidget);
        expect(
          find.descendant(of: tuile, matching: _symbols(compact: false)),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('symbole-Assec-false')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tuile, matching: _symbols(compact: true)),
          findsNothing,
        );
        final Rect symbole = tester.getRect(_symbols(compact: false));
        final Rect categorie = _rectOf(tester, find.text('À sec'));
        expect(symbole.size, const Size(32, 32));
        expect(symbole.right, lessThanOrEqualTo(categorie.left + 0.01));
        expect(
          symbole.center.dy,
          inInclusiveRange(categorie.top, categorie.bottom),
          reason: 'le symbole est sur la ligne de la catégorie',
        );

        // L'historique : un symbole compact par campagne, sur sa ligne.
        const List<String> lignes = <String>[
          '25/08/2026 — À sec',
          '24/07/2026 — À sec',
          '26/06/2026 — Eau stagnante',
          '26/05/2026 — Eau qui coule',
          '26/09/2025 — Écoulement faible',
        ];
        const List<String> attendus = <String>[
          'symbole-Assec-true',
          'symbole-Assec-true',
          'symbole-EcoulementNonVisible-true',
          'symbole-Ecoulement-true',
          'symbole-EcoulementFaible-true',
        ];
        expect(_symbols(compact: true), findsNWidgets(5));
        expect(
          tester
              .widgetList(_symbols(compact: true))
              .map((Widget w) => (w.key! as ValueKey<String>).value),
          attendus,
        );
        for (int i = 0; i < lignes.length; i++) {
          final Rect ligne = _rectOf(tester, find.text(lignes[i]));
          final Rect compact = tester.getRect(_symbols(compact: true).at(i));
          expect(compact.size, const Size(16, 16));
          expect(compact.right, lessThanOrEqualTo(ligne.left + 0.01));
          expect(
            compact.center.dy,
            inInclusiveRange(ligne.top, ligne.bottom),
            reason: 'le symbole compact est sur la ligne « ${lignes[i]} »',
          );
        }
      },
    );

    testWidgetsOnWindows(
      'catégorie NonObserve : la phrase de UC-004 A2 entre la catégorie et la '
      'modalité, dans la tuile ; le symbole fourni est celui de NonObserve',
      (WidgetTester tester) async {
        final OndeObservation nonObserve = _observation(
          observedAt: DateTime.utc(2026, 8, 25),
          rawFlowCode: '4',
          officialLabel: 'Observation impossible',
          campaignCode: '109905',
        );
        await _pump(
          tester,
          prete(
            symbol: _testSymbol,
            data: _data(
              history: <OndeObservation>[nonObserve],
              officialModalityText: 'code 4 — Observation impossible',
            ),
          ),
        );

        final Finder tuile = find.byKey(ondeCategoryTileKey);
        final Rect categorie = _rectOf(tester, find.text('Non observé'));
        final Rect phrase = _rectOf(tester, find.text(ondePointNonObserveText));
        final Rect modalite = _rectOf(
          tester,
          find.textContaining('Modalité officielle ONDE : code 4'),
        );
        final Rect campagne = _rectOf(
          tester,
          find.textContaining(_campagneRecente),
        );
        expect(_readsBefore(categorie, phrase), isTrue);
        expect(_readsBefore(phrase, modalite), isTrue);
        expect(_readsBefore(modalite, campagne), isTrue);
        expect(
          find.descendant(
            of: tuile,
            matching: find.text(ondePointNonObserveText),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('symbole-NonObserve-false')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('symbole-NonObserve-true')),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      "sans campagne : la tuile ne porte que le texte d'absence, aucun "
      "symbole même fourni, pas d'historique ; le rappel de rythme reste",
      (WidgetTester tester) async {
        await _pump(
          tester,
          prete(
            symbol: _testSymbol,
            data: _data(
              history: <OndeObservation>[],
              officialModalityText: 'Aucune campagne connue pour ce point.',
            ),
          ),
        );

        final Finder tuile = find.byKey(ondeCategoryTileKey);
        expect(
          find.descendant(of: tuile, matching: find.byType(Text)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tuile,
            matching: find.text('Aucune campagne connue pour ce point.'),
          ),
          findsOneWidget,
        );
        expect(_symbols(compact: false), findsNothing);
        expect(_symbols(compact: true), findsNothing);
        expect(find.text(ondeHistoriqueTitre), findsNothing);
        expect(find.text(ondeSeasonNotice), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'le contrôleur de défilement fourni pilote le corps du cadre, '
      "l'en-tête reste en place",
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pump(tester, prete(symbol: _testSymbol, controller: controller));

        expect(controller.hasClients, isTrue);
        expect(controller.position.maxScrollExtent, greaterThan(0));
        final Rect entete = _rectOf(tester, find.byKey(sheetFrameHeaderKey));

        controller.jumpTo(60);
        await tester.pump();

        expect(controller.offset, 60);
        expect(_rectOf(tester, find.byKey(sheetFrameHeaderKey)), entete);
      },
    );

    testWidgetsOnWindows(
      'les hauteurs intrinsèques du cadre : min = l\'en-tête seul, max = la '
      'fiche entière, sans erreur, à 380 comme à 260',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final double largeur in <double>[380, 260]) {
          await _pump(
            tester,
            SizedBox(
              width: largeur,
              child: prete(symbol: _testSymbol),
            ),
          );
          final RenderBox cadre = tester.renderObject<RenderBox>(
            find.byType(SheetFrame),
          );
          final double entier = cadre.getMaxIntrinsicHeight(largeur);
          final double replie = cadre.getMinIntrinsicHeight(largeur);

          expect(tester.takeException(), isNull);
          expect(
            replie,
            closeTo(
              tester.getSize(find.byKey(sheetFrameHeaderKey)).height,
              0.5,
            ),
            reason: "à $largeur, replié = l'en-tête seul",
          );
          expect(replie, lessThan(entier));
          expect(
            entier,
            closeTo(cadre.size.height, 0.5),
            reason: 'à $largeur, posée sans limite de hauteur',
          );
        }
      },
    );

    testWidgetsOnAndroid(
      'Android : à 344 et 200 % la fiche prête, avec symboles, tient dans la '
      'largeur, aucun mot coupé, et tout le corps s\'atteint en défilant '
      "sous l'en-tête épinglé",
      (WidgetTester tester) async {
        // 344 de largeur de contenu : le panneau mesure 344 + les 24 de marges
        // du corps, comme les tuiles de la fiche station (`F1`).
        const double panneau = 344 + 24;
        _setPhoneView(tester, const Size(panneau, 640));
        await _pumpAt200(
          tester,
          OndeSheetPanel(
            state: OndeSheetPrete(_data()),
            onClose: () {},
            favoriteStar: const FavoriteStar(filled: false, enabled: true),
            onToggleFavorite: () {},
            categorySymbol: _testSymbol,
          ),
        );

        expect(tester.takeException(), isNull);
        final Rect cadre = _rectOf(tester, find.byType(SheetFrame));
        expect(cadre.right, lessThanOrEqualTo(panneau));
        expect(cadre.bottom, lessThanOrEqualTo(640));
        for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
          final Rect rect = tester.getRect(find.byWidget(text));
          expect(
            rect.right,
            lessThanOrEqualTo(panneau + 0.01),
            reason: '« ${text.data} » déborde de la largeur',
          );
        }
        _expectNoWordCut(tester);

        // La tuile : le symbole avant la catégorie, sans déborder.
        final Rect symbole = tester.getRect(_symbols(compact: false));
        final Rect categorie = _rectOf(tester, find.text('À sec'));
        expect(symbole.right, lessThanOrEqualTo(categorie.left + 0.01));
        expect(
          _rectOf(tester, find.byKey(ondeCategoryTileKey)).right,
          lessThanOrEqualTo(panneau),
        );

        // Le corps défile, l'en-tête reste ; la fin s'atteint.
        final Rect entete = _rectOf(tester, find.byKey(sheetFrameHeaderKey));
        final ScrollPosition position = tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(sheetFrameBodyKey),
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        expect(position.maxScrollExtent, greaterThan(0));
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        expect(_rectOf(tester, find.byKey(sheetFrameHeaderKey)), entete);
        final Rect rappel = _rectOf(tester, find.text(ondeSeasonNotice));
        expect(rappel.bottom, lessThanOrEqualTo(640));
        expect(rappel.top, greaterThanOrEqualTo(entete.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnAndroid(
      'Android : à 344 et 200 %, la tuile de chacune des six catégories tient '
      'à côté de son symbole, sans mot coupé ni débordement',
      (WidgetTester tester) async {
        const double panneau = 344 + 24;
        _setPhoneView(tester, const Size(panneau, 640));
        // Un code par catégorie : `1a` Eau qui coule, `1f` Écoulement faible,
        // `2` Eau stagnante, `3` À sec, `4` Non observé, `zz` Non renseigné.
        for (final String code in <String>['1a', '1f', '2', '3', '4', 'zz']) {
          final OndeObservation campagne = _observation(
            observedAt: DateTime.utc(2026, 8, 25),
            rawFlowCode: code,
            officialLabel: 'libellé de la source',
            campaignCode: '109905',
          );
          await _pumpAt200(
            tester,
            OndeSheetPanel(
              state: OndeSheetPrete(
                _data(
                  history: <OndeObservation>[campagne],
                  officialModalityText: 'code $code — libellé',
                ),
              ),
              onClose: () {},
              categorySymbol: _testSymbol,
            ),
          );

          final String libelle = flowCategoryLabel(campagne.category);
          expect(tester.takeException(), isNull, reason: libelle);
          _expectNoWordCut(tester);
          final Rect tuile = _rectOf(tester, find.byKey(ondeCategoryTileKey));
          expect(tuile.right, lessThanOrEqualTo(panneau), reason: libelle);
          final Rect symbole = tester.getRect(_symbols(compact: false));
          final Rect categorie = _rectOf(tester, find.text(libelle));
          expect(
            symbole.right,
            lessThanOrEqualTo(categorie.left + 0.01),
            reason: libelle,
          );
          expect(
            categorie.right,
            lessThanOrEqualTo(tuile.right),
            reason: libelle,
          );
        }
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

    /// Le bord droit de la ligne de nature de l'en-tête.
    double natureRight(WidgetTester tester) =>
        tester.getRect(find.text(ondeSheetNature)).right;

    // Le cadre commun porte deux anneaux de focus (l'étoile, puis
    // « ⚠ Avertissement ») : on désigne celui de l'étoile.
    Color? ringColor(WidgetTester tester) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.descendant(
            of: find.byType(FavoriteStarButton),
            matching: find.byType(KeyboardFocusRing),
          ),
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
      // `F2` d'Ergonomie : la fiche passe dans le cadre commun, où l'étoile
      // est sur la rangée de l'en-tête, À GAUCHE de la fermeture, à 8 px
      // (`S3`, spec § 6.1) — elle n'est plus sous la fermeture. Remplace le
      // test « l'étoile est SOUS le bouton de fermeture » (`S7b` de T3).
      "l'étoile est à GAUCHE de la fermeture, sur la même rangée de l'en-tête, "
      'à 8 px ; sans étoile, aucun emplacement vide, la fiche garde sa hauteur',
      (WidgetTester tester) async {
        final OndeSheetState state = OndeSheetEnCours(_chaon());
        await pump420(tester, panel(state));
        final Size none = tester.getSize(find.byType(OndeSheetPanel));
        final Rect closeAlone = tester.getRect(
          find.byKey(ondeSheetCloseButtonKey),
        );
        expect(find.byKey(favoriteStarButtonKey), findsNothing);
        // Aucun emplacement vide : la nature va jusqu'à la fermeture.
        expect(closeAlone.left - natureRight(tester), closeTo(0, 0.01));

        await pump420(tester, panel(state, star: full));
        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(find.byKey(ondeSheetCloseButtonKey));
        expect(close, closeAlone);
        expect(star.size, Size(minimumTapTarget, minimumTapTarget));
        expect(star.top, closeTo(close.top, 0.01));
        expect(close.left - star.right, closeTo(8, 0.01));
        expect(tester.getSize(find.byType(OndeSheetPanel)), none);
        // Avec étoile, la nature s'arrête contre elle.
        expect(star.left - natureRight(tester), closeTo(0, 0.01));
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

    // `K1` de T3 : le clavier dans une fiche prête. Deux arrêts, et le bouton
    // de fermeture n'en est pas un (décision antérieure : Échap ferme). Depuis
    // `F2` d'Ergonomie, l'ordre est celui de l'en-tête du cadre commun :
    // l'étoile, sur la rangée du haut, puis « ⚠ Avertissement » dessous
    // (`S3`, spec § 6.1).
    testWidgetsOnWindows(
      "Prete, étoile active : deux arrêts de Tab, l'étoile puis "
      '« ⚠ Avertissement », puis le tour repart ; le bouton de fermeture ne '
      "reçoit jamais le focus (K1 de T3, F2 d'Ergonomie)",
      (WidgetTester tester) async {
        await _pump(tester, panel(OndeSheetPrete(_data()), star: empty));

        final Finder avertissement = find.byType(WarningLink);
        final Finder etoile = find.byType(FavoriteStarButton);
        for (final Finder attendu in <Finder>[etoile, avertissement, etoile]) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, attendu),
            isTrue,
            reason: 'attendu à ce Tab : $attendu',
          );
          expect(
            focusedWithin(tester, find.byKey(ondeSheetCloseButtonKey)),
            isFalse,
          );
        }
      },
    );

    testWidgetsOnWindows(
      'Prete, étoile focalisée : Entrée puis Espace appellent '
      'onToggleFavorite UNE fois chacune, jamais onClose (K1 de T3)',
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
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byType(FavoriteStarButton)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggled, 1, reason: 'Entrée');
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggled, 2, reason: 'Espace');
        expect(closed, 0);
      },
    );

    testWidgetsOnWindows(
      "Prete, étoile DÉJÀ inactive à l'ouverture (liste illisible) : Tab s'y "
      "arrête ; Entrée et Espace n'appellent ni onToggleFavorite ni onClose "
      '(K1 de T3)',
      (WidgetTester tester) async {
        int toggled = 0;
        int closed = 0;
        await _pump(
          tester,
          panel(
            OndeSheetPrete(_data()),
            star: const FavoriteStar(filled: false, enabled: false),
            onToggle: () => toggled++,
            onClose: () => closed++,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byType(FavoriteStarButton)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggled, 0);
        expect(closed, 0);
        expect(
          focusedWithin(tester, find.byType(FavoriteStarButton)),
          isTrue,
          reason: 'le focus reste sur l’étoile inactive',
        );
      },
    );

    testWidgetsOnAndroid(
      'Android : à 360 px et 200 % de police, le cadre (étoile à gauche de '
      "la fermeture, avis d'échec) reste dans l'écran",
      (WidgetTester tester) async {
        // Ce test mesure LE CADRE, avec un contenu court (OndeSheetEnCours).
        // Depuis `F2` d'Ergonomie, le cadre est `SheetFrame` : l'étoile est
        // sur la rangée de l'en-tête, à gauche de la fermeture, à 8 px. La
        // fiche `Prete` entière à 344 et 200 % a son propre test, plus bas.
        _setPhoneView(tester, const Size(360, 640));
        await _pumpAt200(
          tester,
          panel(
            OndeSheetEnCours(_chaon()),
            star: const FavoriteStar(
              filled: false,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );

        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(find.byKey(ondeSheetCloseButtonKey));
        expect(star.size, const Size(48, 48));
        expect(close.size, const Size(48, 48));
        expect(star.top, closeTo(close.top, 0.01));
        expect(close.left - star.right, closeTo(8, 0.01));
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

  group('OndeSheetPanel — la mesure mise en avant (arbitrages 18 et 19)', () {
    Widget prete() => OndeSheetPanel(
      state: OndeSheetPrete(_data()),
      onClose: () {},
      categorySymbol: _testSymbol,
    );

    for (final double echelle in <double>[1, 2]) {
      testWidgetsOnAndroid(
        'Android : 360 de large, à ${(echelle * 100).round()} % — la mesure '
        'mise en avant finit au bas de la tuile de la catégorie ; posée à '
        'cette hauteur, la fiche montre l\'en-tête et la tuile entiers, '
        'l\'historique dessous',
        (WidgetTester tester) async {
          final ({Rect cadre, double vedette}) entiere = await poserFiche(
            tester,
            prete(),
            largeur: 360,
            echelle: echelle,
          );
          expect(
            entiere.vedette,
            closeTo(
              _rectOf(tester, find.byKey(ondeCategoryTileKey)).bottom -
                  entiere.cadre.top,
              0.01,
            ),
          );

          final ({Rect cadre, double vedette}) posee = await poserFiche(
            tester,
            prete(),
            largeur: 360,
            echelle: echelle,
            hauteur: entiere.vedette,
          );
          expect(tester.takeException(), isNull);
          expect(posee.cadre.height, closeTo(entiere.vedette, 0.01));
          expect(
            _rectOf(tester, find.byKey(ondeCategoryTileKey)).bottom,
            closeTo(posee.cadre.bottom, 0.01),
          );
          expect(
            _rectOf(tester, find.byKey(sheetFrameHeaderKey)).top,
            closeTo(posee.cadre.top, 0.01),
          );
          expect(
            _rectOf(tester, find.text(ondeHistoriqueTitre)).top,
            greaterThanOrEqualTo(posee.cadre.bottom - 0.01),
            reason: 'l’historique suit la mesure : il cède avec le reste',
          );
        },
      );
    }

    testWidgetsOnWindows('les états sans mesure — en cours, en échec : la mesure mise en avant est '
        'le corps entier (décision 1 de D7)', (WidgetTester tester) async {
      for (final OndeSheetState etat in <OndeSheetState>[
        OndeSheetEnCours(_chaon()),
        OndeSheetEnEchec(_chaon(), StateError('socket')),
      ]) {
        final ({Rect cadre, double vedette}) r = await poserFiche(
          tester,
          OndeSheetPanel(state: etat, onClose: () {}),
          largeur: 380,
        );
        // Le corps entier, sans sa marge basse de 12.
        expect(r.vedette, closeTo(r.cadre.height - 12, 0.01), reason: '$etat');
      }
    });
  });
}

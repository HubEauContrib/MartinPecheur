// Verrouille la feuille de résumé d'une station : les trois formateurs, le
// contenu rendu, et les cinq états du panneau. Les données de test sont
// les valeurs RÉELLES de la station `K447001001` (La Loire à Blois), lues
// dans `test/fixtures/hubeau/observations_tr_K447001001_Q_2026-09-13.json`
// et `…_H_….json` : `resultat_obs` 47800.0 l/s → 47,8 m³/s, -1232.0 mm →
// -1,232 m, `date_obs` 2026-08-27T08:00:00Z, `libelle_statut`
// « Pré-validée », `libelle_qualification_obs` « Bonne ». Le département
// « 41 » et le cours d'eau « la Loire » viennent de
// `referentiel_stations_K447001001_2026-09-13.json`.
//
// ⚠️ Aucun test ne rend `FlutterMap` : la feuille et le panneau sont rendus
// SEULS dans un `MaterialApp`. L'environnement de test refuse les tuiles, et
// un échec de tuile ne dirait rien sur ce code.
//
// Depuis `F1` d'Ergonomie, la fiche est dans le cadre commun (`SheetFrame`) et
// le corps porte deux TUILES, Débit puis Hauteur. Le verrou « valeur, date et
// source dans un seul `Text` » est remplacé par « chaque tuile est UN nœud
// d'annonce qui dit libellé, valeur, date et source » (`BR-001`, point 32).
// Les tests de disposition des tuiles mesurent en Roboto, chargée depuis le
// SDK (`test/support/roboto.dart`) pour TOUT ce fichier.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

/// Instant de mesure des deux fixtures : `date_obs` 2026-08-27T08:00:00Z.
final DateTime _measuredAt = DateTime.utc(2026, 8, 27, 8);

/// Le code de la station des fixtures.
StationCode _code() => StationCode('K447001001');

Station _blois({String? riverLabel = 'la Loire'}) => Station(
  code: _code(),
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
  departement: DepartementCode('41'),
  riverLabel: riverLabel,
  inService: true,
);

/// La qualification telle que l'API la transporte (BR-006), verbatim.
const Qualification _qualification = Qualification(
  statusCode: 12,
  statusLabel: 'Pré-validée',
  qualificationCode: 20,
  qualificationLabel: 'Bonne',
);

HydroObservation _discharge() => HydroObservation(
  station: _code(),
  measuredAt: _measuredAt,
  grandeur: Grandeur.debit,
  discharge: const CubicMetresPerSecond(47.8),
  level: null,
  qualification: _qualification,
);

HydroObservation _level() => HydroObservation(
  station: _code(),
  measuredAt: _measuredAt,
  grandeur: Grandeur.hauteur,
  discharge: null,
  level: const Metres(-1.232),
  qualification: _qualification,
);

StationSheetData _data({
  HydroObservation? discharge,
  HydroObservation? level,
  String? riverLabel = 'la Loire',
  String? stalenessNotice,
  Freshness? freshness = Freshness.fraiche,
  String statusLabel = 'Pré-validée',
  String qualificationLabel = 'Bonne',
}) => StationSheetData(
  station: _blois(riverLabel: riverLabel),
  discharge: discharge,
  level: level,
  freshness: freshness,
  statusLabel: statusLabel,
  qualificationLabel: qualificationLabel,
  stalenessNotice: stalenessNotice,
);

/// Les cinq mots bannis de `BR-003`, par MOT ENTIER : une recherche par
/// sous-chaîne confondrait « bonne » — le libellé de qualification de
/// Hub'Eau, rendu verbatim (`BR-006`) — avec le mot banni « bon ».
final RegExp _bannedWords = RegExp(
  r'\b(insuffisante?s?|suffisante?s?|normale?s?|normaux|bonne?s?|sûre?s?)\b',
  caseSensitive: false,
);

/// Les mots de garantie interdits par `BR-014`.
final RegExp _guaranteeWords = RegExp(
  r'(temps réel|en direct|fiabl|vérifié|officiel|exact|garanti|sécurisé)',
  caseSensitive: false,
);

/// Les CINQ états du panneau, pour un balayage de vocabulaire qui couvre
/// toute la copie du produit et pas seulement la feuille de résumé.
///
/// Les libellés d'API de l'état [Prete] sont volontairement neutres ici :
/// `BR-006` impose de rendre `libelle_statut` et `libelle_qualification_obs`
/// VERBATIM (« Bonne », « Pré-validée »), et ces mots-là ne sont pas de la
/// copie du produit. Le balayage ne doit mesurer que ce que l'application
/// écrit elle-même.
List<StationSheetState> _panelStates() => <StationSheetState>[
  const Fermee(),
  EnCours(_code()),
  EnEchec(_code(), StateError('socket')),
  Introuvable(_code()),
  Prete(
    _data(
      discharge: _discharge(),
      level: _level(),
      statusLabel: 'non renseigné',
      qualificationLabel: 'non qualifiée',
      stalenessNotice: 'Dernière mesure il y a 3 h',
    ),
  ),
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

/// Les marges latérales du corps d'un `SheetFrame` (12 de chaque côté) : la
/// largeur des tuiles est celle du panneau moins elles.
const double _bodySideMargins = 24;

/// Le panneau `Prete` de Blois, posé à une largeur telle que la paire de
/// tuiles mesure [tilesWidth], à l'échelle de texte [scale]. La fenêtre fait
/// 1 280 px de large (Windows) ; [phone] la réduit à la largeur du panneau
/// (un téléphone, moins de 600 px).
Future<void> _pumpTilesAt(
  WidgetTester tester, {
  required double tilesWidth,
  double scale = 1,
  bool phone = false,
}) async {
  final double panelWidth = tilesWidth + _bodySideMargins;
  tester.view.physicalSize = Size(phone ? panelWidth : 1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: panelWidth,
            child: StationSheetPanel(
              state: Prete(_data(discharge: _discharge(), level: _level())),
              onClose: () {},
              utcOffsetOf: (DateTime _) => const Duration(hours: 2),
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Vrai si [a] se lit avant [b] : plus haut, ou sur la même ligne et à gauche.
bool _readsBefore(Rect a, Rect b) =>
    a.top < b.top - 0.01 ||
    ((a.top - b.top).abs() <= 0.01 && a.left < b.left - 0.01);

/// La règle de `PD13`, recalculée ici par les largeurs intrinsèques : côte à
/// côte quand chaque tuile tient dans la moitié de la largeur sans couper un
/// mot (sa largeur intrinsèque minimale), l'une sous l'autre sinon.
bool _tilesShouldSitSideBySide(WidgetTester tester, double tilesWidth) {
  final double half = (tilesWidth - stationTileGap) / 2;
  return <Key>[stationDischargeTileKey, stationLevelTileKey].every(
    (Key key) =>
        tester
            .renderObject<RenderBox>(find.byKey(key))
            .getMinIntrinsicWidth(double.infinity) <=
        half,
  );
}

/// Vrai si les deux tuiles sont posées côte à côte (même haut, Hauteur à
/// droite de Débit) ; faux si Hauteur est sous Débit.
bool _tilesSideBySide(WidgetTester tester) {
  final Rect debit = _rectOf(tester, find.byKey(stationDischargeTileKey));
  final Rect hauteur = _rectOf(tester, find.byKey(stationLevelTileKey));
  if ((debit.top - hauteur.top).abs() <= 0.01 && hauteur.left >= debit.right) {
    return true;
  }
  expect(
    hauteur.top,
    greaterThanOrEqualTo(debit.bottom),
    reason: 'ni côte à côte ni l\'une sous l\'autre : $debit, $hauteur',
  );
  return false;
}

/// Aucun mot coupé : chaque paragraphe du panneau est posé au moins aussi
/// large que son mot le plus long (sa largeur intrinsèque minimale).
void _expectNoWordCut(WidgetTester tester) {
  final Iterable<RenderParagraph> paragraphs = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(StationSheetPanel),
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

/// La valeur de chaque tuile — « 47,8 m³/s », « −1,232 m » — est posée sur
/// UNE ligne : le nombre ne se sépare pas de son unité.
void _expectValuesOnOneLine(WidgetTester tester) {
  for (final String valeur in <String>[
    formatDischarge(const CubicMetresPerSecond(47.8)),
    formatLevel(const Metres(-1.232)),
  ]) {
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.text(valeur),
    );
    final Set<double> lineTops = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: valeur.length),
        )
        .map((TextBox box) => box.top)
        .toSet();
    expect(lineTops.length, 1, reason: '« $valeur » sur une seule ligne');
  }
}

/// L'annonce fusionnée de la tuile de clé [key].
String _tileAnnouncement(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).label;

void main() {
  setUpAll(chargerRoboto);

  group('formatDischarge — le débit en m³/s, virgule décimale (BR-002)', () {
    test('47,8 m³/s : la valeur réelle de K447001001 (47800.0 l/s)', () {
      expect(
        formatDischarge(const CubicMetresPerSecond(47.8)),
        '47,8\u00A0m³/s',
      );
    });

    test('3,2 m³/s', () {
      expect(formatDischarge(const CubicMetresPerSecond(3.2)), '3,2\u00A0m³/s');
    });

    test('0,05 m³/s — un zéro de tête est conservé', () {
      expect(
        formatDischarge(const CubicMetresPerSecond(0.05)),
        '0,05\u00A0m³/s',
      );
    });

    test('47 m³/s — les zéros de fin sont retirés, pas la valeur', () {
      expect(formatDischarge(const CubicMetresPerSecond(47)), '47\u00A0m³/s');
    });

    // Un zéro MESURÉ (assec) et un débit infime ne portent pas la même
    // information : rendre `0` pour 0,0004 m³/s inventerait un assec
    // (`BR-007`). La borne se dit, la valeur ne se maquille pas.
    test('0,0004 m³/s → « < 0,001 m³/s », jamais « 0 » (BR-007)', () {
      expect(
        formatDischarge(const CubicMetresPerSecond(0.0004)),
        '< 0,001\u00A0m³/s',
      );
    });

    test("0 m³/s — un zéro mesuré reste un zéro, ce n'est pas une borne", () {
      expect(formatDischarge(const CubicMetresPerSecond(0)), '0\u00A0m³/s');
    });
  });

  group('formatLevel — la hauteur en m, signe conservé', () {
    test('−1,232 m : la valeur réelle de K447001001 (-1232.0 mm), au signe '
        'moins typographique U+2212', () {
      expect(formatLevel(const Metres(-1.232)), '−1,232\u00A0m');
    });

    test('0,5 m', () {
      expect(formatLevel(const Metres(0.5)), '0,5\u00A0m');
    });

    test("0 m — un zéro mesuré reste un zéro, ce n'est pas une absence", () {
      expect(formatLevel(const Metres(0)), '0\u00A0m');
    });

    test('0,0004 m → « < 0,001 m » : une hauteur infime au-dessus du zéro '
        "d'échelle n'est pas le zéro (BR-007)", () {
      expect(formatLevel(const Metres(0.0004)), '< 0,001\u00A0m');
    });

    test('−0,0004 m → « > −0,001 m » : la borne garde le sens de lecture, '
        'au-DESSUS de −0,001', () {
      expect(formatLevel(const Metres(-0.0004)), '> −0,001\u00A0m');
    });
  });

  group(
    'StationSummarySheet — date en heure locale, décalage injecté (H1)',
    () {
      testWidgetsOnWindows(
        '2026-08-27T08:00Z, +2 h injecté → 27/08/2026 à 10:00, sans '
        'suffixe de fuseau',
        (WidgetTester tester) async {
          await _pump(
            tester,
            StationSummarySheet(
              data: _data(discharge: _discharge(), level: _level()),
              utcOffsetOf: (DateTime _) => const Duration(hours: 2),
            ),
          );

          expect(find.text('mesuré le 27/08/2026 à 10:00'), findsOneWidget);
          expect(find.text('mesurée le 27/08/2026 à 10:00'), findsOneWidget);
          expect(
            _tileAnnouncement(tester, stationDischargeTileKey),
            contains('mesuré le 27/08/2026 à 10:00'),
          );
        },
      );

      testWidgetsOnWindows(
        "l'instant est converti par un décalage négatif injecté (−3 h)",
        (WidgetTester tester) async {
          await _pump(
            tester,
            StationSummarySheet(
              data: _data(discharge: _discharge(), level: _level()),
              utcOffsetOf: (DateTime _) => const Duration(hours: -3),
            ),
          );

          expect(find.text('mesuré le 27/08/2026 à 05:00'), findsOneWidget);
          expect(
            _tileAnnouncement(tester, stationDischargeTileKey),
            contains('mesuré le 27/08/2026 à 05:00'),
          );
        },
      );
    },
  );

  group('minimumTapTarget', () {
    test('vaut 44 pt (04-ui.md § 3, cibles tactiles)', () {
      expect(minimumTapTargetFor(TargetPlatform.windows), 44.0);
    });
  });

  group('StationSummarySheet — le contenu de la feuille (UC-003 § 2)', () {
    testWidgetsOnWindows("rend libellé, cours d'eau et département", (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSummarySheet(
          data: _data(discharge: _discharge(), level: _level()),
        ),
      );

      expect(find.text('La Loire à Blois'), findsOneWidget);
      expect(find.text('la Loire · Département 41'), findsOneWidget);
      final TextStyle? titre = tester
          .widget<Text>(find.text('La Loire à Blois'))
          .style;
      expect(titre?.fontSize, 20);
      expect(titre?.fontWeight, FontWeight.bold);
    });

    testWidgetsOnWindows(
      "la tuile Débit est UN nœud d'annonce qui dit le libellé, la valeur en "
      'm³/s, sa date en heure locale et sa source (BR-001, BR-002, H1, '
      'point 32)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        final Finder tuile = find.byKey(stationDischargeTileKey);
        for (final String texte in <String>[
          'Débit',
          '47,8\u00A0m³/s',
          'mesuré le 27/08/2026 à 10:00',
          hydrometrieSourceName,
        ]) {
          expect(
            find.descendant(of: tuile, matching: find.text(texte)),
            findsOneWidget,
            reason: '« $texte » dans la tuile Débit',
          );
        }
        final String annonce = _tileAnnouncement(
          tester,
          stationDischargeTileKey,
        );
        expect(annonce, contains('Débit'));
        expect(annonce, contains('47,8\u00A0m³/s'));
        expect(annonce, contains('mesuré le 27/08/2026 à 10:00'));
        expect(annonce, contains(hydrometrieSourceName));
        expect(annonce, isNot(contains('Hauteur')));
        final TextStyle? valeur = tester
            .widget<Text>(find.text('47,8\u00A0m³/s'))
            .style;
        expect(valeur?.fontSize, 26);
        expect(valeur?.fontWeight, FontWeight.bold);
        expect(
          valeur?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      },
    );

    testWidgetsOnWindows(
      "la tuile Hauteur est UN nœud d'annonce : la valeur en m, signe "
      'conservé, sa date en heure locale et sa source (H1, point 32)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        final String annonce = _tileAnnouncement(tester, stationLevelTileKey);
        expect(annonce, contains('Hauteur'));
        expect(annonce, contains('−1,232\u00A0m'));
        expect(annonce, contains('mesurée le 27/08/2026 à 10:00'));
        expect(annonce, contains(hydrometrieSourceName));
        expect(annonce, isNot(contains('Débit')));
        expect(
          tester.widget<Text>(find.text('−1,232\u00A0m')).style?.fontSize,
          20,
        );
      },
    );

    testWidgetsOnWindows('rend statut et qualification, verbatim (BR-006)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSummarySheet(
          data: _data(discharge: _discharge(), level: _level()),
        ),
      );

      expect(find.text('Pré-validée'), findsOneWidget);
      expect(find.text('Bonne'), findsOneWidget);
    });

    testWidgetsOnWindows(
      "« Statut (Hub'Eau) » au-dessus de « Pré-validée », « Qualification "
      "(Hub'Eau) » au-dessus de « Bonne »",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
          ),
        );

        final Rect statut = _rectOf(tester, find.text(stationStatusLabel));
        final Rect statutValeur = _rectOf(tester, find.text('Pré-validée'));
        final Rect qualif = _rectOf(
          tester,
          find.text(stationQualificationLabel),
        );
        final Rect qualifValeur = _rectOf(tester, find.text('Bonne'));
        expect(statutValeur.top, greaterThanOrEqualTo(statut.bottom));
        expect(qualif.top, greaterThanOrEqualTo(statutValeur.bottom));
        expect(qualifValeur.top, greaterThanOrEqualTo(qualif.bottom));
      },
    );

    testWidgetsOnWindows(
      'une observation périmée rend son avis de fraîcheur, avec la date '
      '(BR-005)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(
              discharge: _discharge(),
              level: _level(),
              freshness: Freshness.perimee,
              stalenessNotice: 'Dernière mesure le 27/08/2026 à 10:00',
            ),
          ),
        );

        expect(
          find.text('Dernière mesure le 27/08/2026 à 10:00'),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'une mesure fraîche ne porte aucun avis de fraîcheur (BR-005)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
          ),
        );

        expect(find.textContaining('Dernière mesure'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "débit absent → la phrase d'absence, jamais un zéro ni un tiret seul "
      '(BR-007, UC-003 A3)',
      (WidgetTester tester) async {
        await _pump(tester, StationSummarySheet(data: _data(level: _level())));

        expect(
          find.textContaining(
            "La station n'a pas transmis de valeur pour ce paramètre.",
          ),
          findsOneWidget,
        );

        final List<String> texts = _renderedTexts(tester);
        expect(texts.any((String text) => text.contains('m³/s')), isFalse);
        expect(texts.any((String text) => text.trim() == '0'), isFalse);
        expect(texts.any((String text) => text.trim() == '-'), isFalse);
        expect(texts.any((String text) => text.trim() == '—'), isFalse);
      },
    );

    testWidgetsOnWindows(
      "hauteur absente → la même phrase d'absence (BR-007)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(data: _data(discharge: _discharge())),
        );

        expect(
          find.textContaining(
            "La station n'a pas transmis de valeur pour ce paramètre.",
          ),
          findsOneWidget,
        );
        // Dans la tuile Hauteur : « Hauteur » puis la phrase, rien d'autre.
        final Finder tuile = find.byKey(stationLevelTileKey);
        final Rect libelle = _rectOf(
          tester,
          find.descendant(of: tuile, matching: find.text('Hauteur')),
        );
        final Rect phrase = _rectOf(
          tester,
          find.descendant(of: tuile, matching: find.text(valeurNonTransmise)),
        );
        expect(phrase.top, greaterThanOrEqualTo(libelle.bottom));
        expect(
          find.descendant(of: tuile, matching: find.byType(Text)),
          findsNWidgets(2),
        );
        final String annonce = _tileAnnouncement(tester, stationLevelTileKey);
        expect(annonce, contains('Hauteur'));
        expect(annonce, contains(valeurNonTransmise));
        expect(annonce, isNot(contains(hydrometrieSourceName)));
      },
    );

    testWidgetsOnWindows(
      "cours d'eau nul → une absence honnête, jamais une ligne vide (BR-007)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(
              discharge: _discharge(),
              level: _level(),
              riverLabel: null,
            ),
          ),
        );

        expect(
          find.text("Cours d'eau non renseigné · Département 41"),
          findsOneWidget,
        );
      },
    );
  });

  // Depuis `F1` d'Ergonomie, le contrôle est dans l'EN-TÊTE du cadre commun
  // (`SheetFrame`), plus dans la feuille de résumé : ces tests rendent le
  // panneau.
  group('StationSheetPanel — le contrôle d\'avertissement de tête (W3c, '
      'arbitrage du commanditaire du 2026-09-23 ; F1 d\'Ergonomie)', () {
    testWidgetsOnWindows(
      'le contrôle est TOUJOURS rendu, avec ou sans mesure',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(state: Prete(_data()), onClose: () {}),
        );

        expect(find.byType(WarningLink), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      "le contrôle est rendu EN TÊTE, avant la valeur du débit — assertion "
      "sur l'ORDRE dans l'arbre, pas sur la seule présence",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(_data(discharge: _discharge(), level: _level())),
            onClose: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        final double linkTop = tester.getTopLeft(find.byType(WarningLink)).dy;
        final double debitTop = tester
            .getTopLeft(find.textContaining('47,8\u00A0m³/s'))
            .dy;

        expect(linkTop, lessThan(debitTop));
      },
    );

    testWidgetsOnWindows(
      'avec une mesure de débit, la fenêtre porte la phrase datée '
      '(UC-003 § 1)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(_data(discharge: _discharge(), level: _level())),
            onClose: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Mesure brute du 27/08/2026 à 10:00'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(find.byKey(warningWindowExtraTextKey))
              .data!
              .contains('lâchers de barrage'),
          isTrue,
          reason:
              'la phrase propre à la fiche (sous le corps général) porte '
              'bien la mention des lâchers de barrage',
        );
      },
    );

    testWidgetsOnWindows(
      'sans débit ni hauteur, le contrôle reste mais la fenêtre n\'a pas '
      'de phrase propre — arbitrage du commanditaire du 2026-09-23 : sans '
      'date, aucun encart',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(state: Prete(_data()), onClose: () {}),
        );

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(find.byKey(warningWindowExtraTextKey), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'la feuille de résumé seule ne porte plus le contrôle : il est dans '
      "l'en-tête du cadre, épinglé (F1 d'Ergonomie, spec § 6.1)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(_data(discharge: _discharge(), level: _level())),
            onClose: () {},
          ),
        );

        expect(
          find.descendant(
            of: find.byType(StationSummarySheet),
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
  });

  group("StationSheetPanel — le cadre commun et l'ordre du corps (F1 "
      "d'Ergonomie, spec § 6.1, § 6.2, critère 11)", () {
    List<StationSheetState> visibles() => <StationSheetState>[
      EnCours(_code()),
      Prete(_data(discharge: _discharge(), level: _level())),
      EnEchec(_code(), StateError('socket')),
      Introuvable(_code()),
    ];

    test('stationSheetNature : « Station hydrométrique · <code> »', () {
      expect(stationSheetNature(_code()), 'Station hydrométrique · K447001001');
      expect(stationStatusLabel, "Statut (Hub'Eau)");
      expect(stationQualificationLabel, "Qualification (Hub'Eau)");
    });

    testWidgetsOnWindows(
      'les quatre états visibles sont dans un SheetFrame : la nature exacte '
      'et « ⚠ Avertissement » dans son en-tête (PD7)',
      (WidgetTester tester) async {
        for (final StationSheetState state in visibles()) {
          await _pump(tester, StationSheetPanel(state: state, onClose: () {}));

          expect(find.byType(SheetFrame), findsOneWidget);
          final Finder entete = find.byKey(sheetFrameHeaderKey);
          expect(
            find.descendant(
              of: entete,
              matching: find.text('Station hydrométrique · K447001001'),
            ),
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
              matching: find.byKey(stationSheetCloseButtonKey),
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgetsOnWindows(
      'la phrase datée de la fenêtre en Prete seulement : en chargement, en '
      'échec et introuvable, la fenêtre s\'ouvre sans phrase propre',
      (WidgetTester tester) async {
        for (final StationSheetState state in visibles()) {
          await _pump(
            tester,
            StationSheetPanel(
              state: state,
              onClose: () {},
              utcOffsetOf: (DateTime _) => const Duration(hours: 2),
            ),
          );
          await tester.tap(find.byKey(warningLinkKey));
          await tester.pumpAndSettle();

          expect(
            find.byKey(warningWindowExtraTextKey),
            state is Prete ? findsOneWidget : findsNothing,
            reason: state.runtimeType.toString(),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgetsOnWindows(
      'Prete se lit dans l\'ordre : nature < « ⚠ Avertissement » < titre < '
      "cours d'eau · département < Débit < Hauteur < statut < qualification "
      '< avis de fraîcheur',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(
              _data(
                discharge: _discharge(),
                level: _level(),
                stalenessNotice: 'Dernière mesure le 27/08/2026 à 10:00',
              ),
            ),
            onClose: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        final List<Rect> ordre = <Rect>[
          _rectOf(tester, find.text('Station hydrométrique · K447001001')),
          _rectOf(tester, find.byKey(warningLinkKey)),
          _rectOf(tester, find.text('La Loire à Blois')),
          _rectOf(tester, find.text('la Loire · Département 41')),
          _rectOf(tester, find.byKey(stationDischargeTileKey)),
          _rectOf(tester, find.byKey(stationLevelTileKey)),
          _rectOf(tester, find.text(stationStatusLabel)),
          _rectOf(tester, find.text(stationQualificationLabel)),
          _rectOf(tester, find.text('Dernière mesure le 27/08/2026 à 10:00')),
        ];
        for (int i = 0; i + 1 < ordre.length; i++) {
          expect(
            _readsBefore(ordre[i], ordre[i + 1]),
            isTrue,
            reason: 'élément $i (${ordre[i]}) avant ${i + 1} (${ordre[i + 1]})',
          );
        }
        // Le statut est sous les DEUX tuiles, quelle que soit leur disposition.
        final double basDesTuiles = <double>[
          ordre[4].bottom,
          ordre[5].bottom,
        ].reduce((double a, double b) => a > b ? a : b);
        expect(ordre[6].top, greaterThanOrEqualTo(basDesTuiles));
      },
    );
  });

  group('StationSummarySheet — les tuiles côte à côte ou l\'une sous '
      'l\'autre (PD13, mesuré en Roboto)', () {
    testWidgetsOnWindows('à 760 et 100 % : côte à côte, aucun mot coupé', (
      WidgetTester tester,
    ) async {
      await _pumpTilesAt(tester, tilesWidth: 760);

      expect(tester.takeException(), isNull);
      expect(_tilesShouldSitSideBySide(tester, 760), isTrue);
      expect(_tilesSideBySide(tester), isTrue);
      _expectNoWordCut(tester);
    });

    testWidgetsOnWindows(
      'à 356 (panneau de 380 moins ses marges) et 100 % : la disposition que '
      'la règle donne, calculée par les largeurs intrinsèques ; aucun mot '
      'coupé',
      (WidgetTester tester) async {
        await _pumpTilesAt(tester, tilesWidth: 356);

        expect(tester.takeException(), isNull);
        final RenderBox paire =
            tester
                    .renderObject<RenderBox>(
                      find.byKey(stationDischargeTileKey),
                    )
                    .parent!
                as RenderBox;
        expect(paire.size.width, closeTo(356, 0.01));
        expect(
          _tilesSideBySide(tester),
          _tilesShouldSitSideBySide(tester, 356),
        );
        expect(
          _tilesSideBySide(tester),
          isTrue,
          reason: "à 356 et 100 %, la règle donne côte à côte",
        );
        _expectNoWordCut(tester);
      },
    );

    testWidgetsOnAndroid(
      'Android : à 344 et 200 % : l\'une sous l\'autre, aucun mot coupé',
      (WidgetTester tester) async {
        await _pumpTilesAt(tester, tilesWidth: 344, scale: 2, phone: true);

        expect(tester.takeException(), isNull);
        expect(_tilesShouldSitSideBySide(tester, 344), isFalse);
        expect(_tilesSideBySide(tester), isFalse);
        _expectNoWordCut(tester);
      },
    );

    testWidgetsOnWindows(
      'la largeur intrinsèque maximale de la paire est juste : à cette '
      'largeur, côte à côte en colonnes égales, aucune tuile ne se replie',
      (WidgetTester tester) async {
        await _pumpTilesAt(tester, tilesWidth: 760);
        final RenderBox debit = tester.renderObject<RenderBox>(
          find.byKey(stationDischargeTileKey),
        );
        final RenderBox hauteur = tester.renderObject<RenderBox>(
          find.byKey(stationLevelTileKey),
        );
        final RenderBox paire = debit.parent! as RenderBox;
        final double largeur = paire.getMaxIntrinsicWidth(double.infinity);
        final double colonne = (largeur - stationTileGap) / 2;
        for (final RenderBox tuile in <RenderBox>[debit, hauteur]) {
          expect(
            tuile.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(colonne + 0.01),
          );
        }
        final double haute = <double>[
          debit.getMaxIntrinsicHeight(double.infinity),
          hauteur.getMaxIntrinsicHeight(double.infinity),
        ].reduce((double a, double b) => a > b ? a : b);
        expect(paire.getMaxIntrinsicHeight(largeur), closeTo(haute, 0.01));
      },
    );

    // La valeur ne se sépare jamais de son unité (espace insécable U+00A0,
    // typographie française ; passe 1 de `F1`) : la règle voit « 47,8 m³/s »
    // comme un seul segment, et la tuile ne se pose côte à côte que si la
    // valeur ENTIÈRE tient dans sa colonne.
    testWidgetsOnWindows(
      'à 356 (panneau de 380) et 200 % : chaque valeur tient sur une ligne, '
      "avec son unité ; la règle pose les tuiles l'une sous l'autre",
      (WidgetTester tester) async {
        await _pumpTilesAt(tester, tilesWidth: 356, scale: 2);

        expect(tester.takeException(), isNull);
        expect(
          _tilesSideBySide(tester),
          _tilesShouldSitSideBySide(tester, 356),
        );
        // La valeur entière, insécable, ne tient pas dans une demi-colonne :
        // la règle pose les tuiles l'une sous l'autre.
        expect(_tilesSideBySide(tester), isFalse);
        _expectValuesOnOneLine(tester);
        _expectNoWordCut(tester);
      },
    );

    testWidgetsOnAndroid(
      "Android : à 387 (Pixel 7) et 200 % : l'une sous l'autre, chaque "
      'valeur tient sur une ligne, avec son unité',
      (WidgetTester tester) async {
        await _pumpTilesAt(tester, tilesWidth: 387, scale: 2, phone: true);

        expect(tester.takeException(), isNull);
        expect(
          _tilesSideBySide(tester),
          _tilesShouldSitSideBySide(tester, 387),
        );
        // La valeur entière, insécable, ne tient pas dans une demi-colonne :
        // la règle pose les tuiles l'une sous l'autre.
        expect(_tilesSideBySide(tester), isFalse);
        _expectValuesOnOneLine(tester);
        _expectNoWordCut(tester);
      },
    );

    testWidgetsOnWindows(
      'les hauteurs intrinsèques de la fiche disent la disposition posée : '
      'max = la fiche entière, sans erreur, côte à côte comme l\'une sous '
      'l\'autre',
      (WidgetTester tester) async {
        for (final double largeur in <double>[760, 200]) {
          await _pumpTilesAt(tester, tilesWidth: largeur);
          final RenderBox panneau = tester.renderObject<RenderBox>(
            find.byType(SheetFrame),
          );
          final double entier = panneau.getMaxIntrinsicHeight(
            largeur + _bodySideMargins,
          );
          expect(tester.takeException(), isNull);
          expect(
            _tilesSideBySide(tester),
            largeur == 760,
            reason: "à $largeur, la disposition parcourue",
          );
          expect(
            entier,
            closeTo(panneau.size.height, 0.5),
            reason: 'à $largeur, posée sans limite de hauteur',
          );
        }
      },
    );
  });

  // Le balayage porte sur les mots que l'application ÉCRIT, pas sur les
  // libellés que l'API lui transmet : `libelle_qualification_obs` vaut
  // « Bonne » sur K447001001 et BR-006 exige de le rendre verbatim. Même
  // principe que BR-014 pour les libellés d'une autorité, cités tels quels
  // et attribués. Les
  // deux libellés d'API sont donc neutres ici, pour que le balayage ne
  // mesure que la copie du produit.
  group('vocabulaire — BR-003 et BR-014', () {
    testWidgetsOnWindows(
      'aucun des cinq mots bannis dans AUCUN des cinq états du panneau — '
      'toute la copie du produit est balayée, pas la seule feuille',
      (WidgetTester tester) async {
        for (final StationSheetState state in _panelStates()) {
          await _pump(tester, StationSheetPanel(state: state, onClose: () {}));

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
      'aucun mot de garantie dans AUCUN des cinq états du panneau (BR-014)',
      (WidgetTester tester) async {
        for (final StationSheetState state in _panelStates()) {
          await _pump(tester, StationSheetPanel(state: state, onClose: () {}));

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

    testWidgetsOnWindows(
      'aucun des cinq mots bannis dans les textes du produit',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(
              discharge: _discharge(),
              level: _level(),
              qualificationLabel: 'non qualifiée',
              stalenessNotice: 'Dernière mesure il y a 3 h',
            ),
          ),
        );

        for (final String text in _renderedTexts(tester)) {
          expect(
            _bannedWords.hasMatch(text),
            isFalse,
            reason: 'mot banni dans « $text »',
          );
        }
      },
    );

    testWidgetsOnWindows('aucun mot de garantie (BR-014)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSummarySheet(
          data: _data(
            discharge: _discharge(),
            level: _level(),
            qualificationLabel: 'non qualifiée',
          ),
        ),
      );

      for (final String text in _renderedTexts(tester)) {
        expect(
          _guaranteeWords.hasMatch(text),
          isFalse,
          reason: 'mot de garantie dans « $text »',
        );
      }
    });
  });

  group('StationSheetPanel — les cinq états de la fiche', () {
    testWidgetsOnWindows('Fermee ne rend rien', (WidgetTester tester) async {
      await _pump(
        tester,
        StationSheetPanel(state: const Fermee(), onClose: () {}),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(StationSummarySheet), findsNothing);
    });

    testWidgetsOnWindows('EnCours rend le code de la station demandée', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(state: EnCours(_code()), onClose: () {}),
      );

      expect(find.text('Chargement de la station K447001001…'), findsOneWidget);
    });

    testWidgetsOnWindows(
      'EnEchec nomme la source défaillante et le code — jamais une feuille '
      'vide (UC-001 A4)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: EnEchec(_code(), StateError('socket')),
            onClose: () {},
          ),
        );

        expect(find.textContaining("Hub'Eau"), findsOneWidget);
        expect(
          find.text(
            "Hub'Eau n'a pas répondu pour la station K447001001. Aucune "
            "valeur n'est disponible pour l'instant.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows('EnEchec ne rend jamais la cause technique brute', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(
          state: EnEchec(_code(), StateError('socket')),
          onClose: () {},
        ),
      );

      expect(find.textContaining('socket'), findsNothing);
    });

    // Les 37 stations sans `code_departement` sont sur la carte et tapables,
    // sans entrée dans le référentiel embarqué : aucun appel réseau n'a eu
    // lieu, nommer Hub'Eau serait une accusation fausse (BR-007, UC-001 A4).
    testWidgetsOnWindows(
      "Introuvable dit l'absence du référentiel embarqué et ne nomme PAS "
      "Hub'Eau — aucun réseau n'a été appelé (BR-007)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(state: Introuvable(_code()), onClose: () {}),
        );

        expect(
          find.text(
            'Aucune fiche pour la station K447001001 : elle figure sur la '
            "carte mais pas dans le référentiel embarqué de l'application.",
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('référentiel embarqué'),
          findsOneWidget,
          reason: "la cause réelle est nommée : l'asset, pas une API",
        );
        expect(find.textContaining("Hub'Eau"), findsNothing);
      },
    );

    testWidgetsOnWindows('Introuvable porte aussi un bouton de fermeture', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(state: Introuvable(_code()), onClose: () {}),
      );

      expect(find.byKey(stationSheetCloseButtonKey), findsOneWidget);
    });

    testWidgetsOnWindows('Prete rend la feuille de résumé', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(
          state: Prete(_data(discharge: _discharge(), level: _level())),
          onClose: () {},
        ),
      );

      expect(find.byType(StationSummarySheet), findsOneWidget);
      expect(find.text('La Loire à Blois'), findsOneWidget);
    });

    testWidgetsOnWindows(
      'Prete transmet utcOffsetOf à StationSummarySheet : +2 h injecté '
      'rend « 10:00 » (H1, le panneau transmet le décalage)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(_data(discharge: _discharge(), level: _level())),
            onClose: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        expect(find.textContaining('à 10:00'), findsWidgets);
      },
    );

    testWidgetsOnWindows(
      'le bouton de fermeture mesure au moins 44 × 44 pt (04-ui.md § 3)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(
            state: Prete(_data(discharge: _discharge(), level: _level())),
            onClose: () {},
          ),
        );

        final Size size = tester.getSize(
          find.byKey(stationSheetCloseButtonKey),
        );
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
        StationSheetPanel(
          state: Prete(_data(discharge: _discharge(), level: _level())),
          onClose: () => closed++,
        ),
      );

      await tester.tap(find.byKey(stationSheetCloseButtonKey));
      await tester.pump();

      expect(closed, 1);
    });

    testWidgetsOnWindows(
      'EnCours et EnEchec portent aussi un bouton de fermeture',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSheetPanel(state: EnCours(_code()), onClose: () {}),
        );
        expect(find.byKey(stationSheetCloseButtonKey), findsOneWidget);

        await _pump(
          tester,
          StationSheetPanel(
            state: EnEchec(_code(), StateError('socket')),
            onClose: () {},
          ),
        );
        expect(find.byKey(stationSheetCloseButtonKey), findsOneWidget);
      },
    );
  });

  // `S7a` de T3 : l'étoile de favori entre dans le cadre commun. Sans étoile à
  // montrer (`favoriteStar` nul) le cadre est celui d'avant, au pixel : les
  // groupes précédents n'ont pas bougé.
  group("StationSheetPanel — l'étoile de favori (S7a de T3)", () {
    const FavoriteStar empty = FavoriteStar(filled: false, enabled: true);
    const FavoriteStar full = FavoriteStar(filled: true, enabled: true);

    StationSheetState prete() =>
        Prete(_data(discharge: _discharge(), level: _level()));

    Widget panel(
      StationSheetState state, {
      FavoriteStar? star,
      VoidCallback? onToggle,
      VoidCallback? onClose,
    }) => StationSheetPanel(
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

    /// Ce que le ViewModel produit pour le contenu court (EnCours) : une
    /// étoile de station n'y existe que pleine.
    StationSheetState enCours() => EnCours(_code());

    Future<Size> contentSize(
      WidgetTester tester,
      StationSheetState state, {
      FavoriteStar? star,
    }) async {
      await pump420(tester, panel(state, star: star));
      return tester.getSize(find.byType(StationSummarySheet));
    }

    /// Le bord droit de la ligne de nature de l'en-tête.
    double natureRight(WidgetTester tester) =>
        tester.getRect(find.text('Station hydrométrique · K447001001')).right;

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
      'Prete : l\'étoile ne rétrécit pas le contenu et n\'allonge pas la '
      'fiche (même largeur, même hauteur avec et sans étoile)',
      (WidgetTester tester) async {
        final Size without = await contentSize(tester, prete());
        final Size panelWithout = tester.getSize(
          find.byType(StationSheetPanel),
        );
        final Rect closeWithout = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
        expect(find.byKey(favoriteStarButtonKey), findsNothing);

        final Size withStar = await contentSize(tester, prete(), star: empty);
        final Size panelWith = tester.getSize(find.byType(StationSheetPanel));

        expect(withStar.width, without.width);
        expect(withStar.height, without.height);
        expect(panelWith, panelWithout);
        // Le bouton de fermeture n'a pas bougé.
        expect(
          tester.getRect(find.byKey(stationSheetCloseButtonKey)),
          closeWithout,
        );
      },
    );

    testWidgetsOnWindows(
      // `F1` d'Ergonomie : la fiche passe dans le cadre commun, où l'étoile
      // est sur la rangée de l'en-tête, À GAUCHE de la fermeture, à 8 px
      // (`S3`, spec § 6.1) — elle n'est plus sous la fermeture. Remplace le
      // test « l'étoile est SOUS le bouton de fermeture » (`S7a` de T3).
      "l'étoile est à GAUCHE de la fermeture, sur la même rangée de l'en-tête, "
      'à 8 px ; sans étoile, aucun emplacement vide, la fiche garde sa hauteur',
      (WidgetTester tester) async {
        await pump420(tester, panel(enCours()));
        final Size none = tester.getSize(find.byType(StationSheetPanel));
        final Rect closeAlone = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
        expect(find.byKey(favoriteStarButtonKey), findsNothing);
        // Aucun emplacement vide : la nature va jusqu'à la fermeture.
        expect(closeAlone.left - natureRight(tester), closeTo(0, 0.01));

        await pump420(tester, panel(enCours(), star: full));
        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
        expect(close, closeAlone);
        expect(star.size, Size(minimumTapTarget, minimumTapTarget));
        expect(star.top, closeTo(close.top, 0.01));
        expect(close.left - star.right, closeTo(8, 0.01));
        expect(tester.getSize(find.byType(StationSheetPanel)), none);
        // Avec étoile, la nature s'arrête contre elle.
        expect(star.left - natureRight(tester), closeTo(0, 0.01));
      },
    );

    testWidgetsOnWindows(
      'Tab atteint l\'étoile (un arrêt de tabulation ; le bouton de fermeture '
      'n\'en est pas un)',
      (WidgetTester tester) async {
        await _pump(tester, panel(enCours(), star: full));
        expect(ringColor(tester), Colors.transparent);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(ringColor(tester), focusRingColor);
      },
    );

    testWidgetsOnWindows(
      'le focus clavier de l\'étoile survit à une écriture : inactive pendant '
      'l\'écriture, puis active avec l\'avis d\'échec — toujours focalisée',
      (WidgetTester tester) async {
        await _pump(tester, panel(enCours(), star: full));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(ringColor(tester), focusRingColor);

        await _pump(
          tester,
          panel(
            enCours(),
            star: const FavoriteStar(filled: true, enabled: false),
          ),
        );
        await tester.pump();
        expect(ringColor(tester), focusRingColor);

        await _pump(
          tester,
          panel(
            enCours(),
            star: const FavoriteStar(
              filled: true,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );
        await tester.pump();

        expect(ringColor(tester), focusRingColor);
        expect(find.text("Le favori n'a pas pu être retiré."), findsOneWidget);
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
            prete(),
            star: empty,
            onToggle: () => toggled++,
            onClose: () => closed++,
          ),
        );

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();
        expect(toggled, 1);
        expect(closed, 0);

        await tester.tap(find.byKey(stationSheetCloseButtonKey));
        await tester.pump();
        expect(closed, 1);
        expect(toggled, 1);
      },
    );

    testWidgetsOnWindows(
      'favoriteStar nul, dans chacun des états visibles : aucune étoile',
      (WidgetTester tester) async {
        final List<StationSheetState> visible = <StationSheetState>[
          EnCours(_code()),
          prete(),
          EnEchec(_code(), StateError('socket')),
          Introuvable(_code()),
        ];
        for (final StationSheetState state in visible) {
          await _pump(tester, panel(state));

          expect(find.byKey(favoriteStarButtonKey), findsNothing);
          expect(find.byType(FavoriteStarButton), findsNothing);
          expect(find.byKey(stationSheetCloseButtonKey), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows(
      "Fermee avec une étoile non nulle : rien n'est rendu",
      (WidgetTester tester) async {
        await _pump(tester, panel(const Fermee(), star: full));

        expect(find.byType(FavoriteStarButton), findsNothing);
        expect(find.byType(Text), findsNothing);
        expect(find.byKey(stationSheetCloseButtonKey), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "EnEchec avec une étoile pleine : l'étoile ET le texte d'échec",
      (WidgetTester tester) async {
        await _pump(
          tester,
          panel(EnEchec(_code(), StateError('socket')), star: full),
        );

        expect(find.byKey(favoriteStarButtonKey), findsOneWidget);
        expect(
          find.textContaining(
            "Hub'Eau n'a pas répondu pour la station K447001001.",
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
            prete(),
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
            tester.getBottomLeft(find.byKey(stationSheetCloseButtonKey)).dy,
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
            prete(),
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
          await _pump(tester, panel(prete(), star: star));

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
            prete(),
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
    // `F1` d'Ergonomie, l'ordre est celui de l'en-tête du cadre commun :
    // l'étoile, sur la rangée du haut, puis « ⚠ Avertissement » dessous
    // (`S3`, spec § 6.1).
    testWidgetsOnWindows(
      "Prete, étoile active : deux arrêts de Tab, l'étoile puis "
      '« ⚠ Avertissement », puis le tour repart ; le bouton de fermeture ne '
      'reçoit jamais le focus (K1 de T3, F1 d\'Ergonomie)',
      (WidgetTester tester) async {
        await _pump(tester, panel(prete(), star: empty));

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
            focusedWithin(tester, find.byKey(stationSheetCloseButtonKey)),
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
            prete(),
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
            prete(),
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
      'la fermeture, avis d\'échec) reste dans l\'écran',
      (WidgetTester tester) async {
        // Ce test mesure LE CADRE, avec un contenu court (EnCours) et une
        // étoile que le ViewModel peut produire dans cet état : hors `Prete`,
        // une étoile de station n'existe que pleine. Depuis `F1` d'Ergonomie,
        // le cadre est `SheetFrame` : l'étoile est sur la rangée de l'en-tête,
        // à gauche de la fermeture, à 8 px.
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
                  EnCours(_code()),
                  star: const FavoriteStar(
                    filled: true,
                    enabled: true,
                    writeFailed: true,
                  ),
                ),
              ),
            ),
          ),
        );

        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
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
}

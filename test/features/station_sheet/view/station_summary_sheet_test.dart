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
import 'package:flutter/material.dart';
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
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

import '../../../support/android_platform.dart';
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

void main() {
  group('formatDischarge — le débit en m³/s, virgule décimale (BR-002)', () {
    test('47,8 m³/s : la valeur réelle de K447001001 (47800.0 l/s)', () {
      expect(formatDischarge(const CubicMetresPerSecond(47.8)), '47,8 m³/s');
    });

    test('3,2 m³/s', () {
      expect(formatDischarge(const CubicMetresPerSecond(3.2)), '3,2 m³/s');
    });

    test('0,05 m³/s — un zéro de tête est conservé', () {
      expect(formatDischarge(const CubicMetresPerSecond(0.05)), '0,05 m³/s');
    });

    test('47 m³/s — les zéros de fin sont retirés, pas la valeur', () {
      expect(formatDischarge(const CubicMetresPerSecond(47)), '47 m³/s');
    });

    // Un zéro MESURÉ (assec) et un débit infime ne portent pas la même
    // information : rendre `0` pour 0,0004 m³/s inventerait un assec
    // (`BR-007`). La borne se dit, la valeur ne se maquille pas.
    test('0,0004 m³/s → « < 0,001 m³/s », jamais « 0 » (BR-007)', () {
      expect(
        formatDischarge(const CubicMetresPerSecond(0.0004)),
        '< 0,001 m³/s',
      );
    });

    test("0 m³/s — un zéro mesuré reste un zéro, ce n'est pas une borne", () {
      expect(formatDischarge(const CubicMetresPerSecond(0)), '0 m³/s');
    });
  });

  group('formatLevel — la hauteur en m, signe conservé', () {
    test('−1,232 m : la valeur réelle de K447001001 (-1232.0 mm), au signe '
        'moins typographique U+2212', () {
      expect(formatLevel(const Metres(-1.232)), '−1,232 m');
    });

    test('0,5 m', () {
      expect(formatLevel(const Metres(0.5)), '0,5 m');
    });

    test("0 m — un zéro mesuré reste un zéro, ce n'est pas une absence", () {
      expect(formatLevel(const Metres(0)), '0 m');
    });

    test('0,0004 m → « < 0,001 m » : une hauteur infime au-dessus du zéro '
        "d'échelle n'est pas le zéro (BR-007)", () {
      expect(formatLevel(const Metres(0.0004)), '< 0,001 m');
    });

    test('−0,0004 m → « > −0,001 m » : la borne garde le sens de lecture, '
        'au-DESSUS de −0,001', () {
      expect(formatLevel(const Metres(-0.0004)), '> −0,001 m');
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

          expect(
            find.text(
              'Débit : 47,8 m³/s — mesuré le 27/08/2026 à 10:00 — '
              "$hydrometrieSourceName",
            ),
            findsOneWidget,
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

          expect(
            find.text(
              'Débit : 47,8 m³/s — mesuré le 27/08/2026 à 05:00 — '
              "$hydrometrieSourceName",
            ),
            findsOneWidget,
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
      expect(find.textContaining('la Loire'), findsWidgets);
      expect(find.textContaining('41'), findsWidgets);
    });

    testWidgetsOnWindows(
      'rend le débit en m³/s AVEC sa date, en heure locale, ET sa source, '
      "dans le MÊME Text (BR-001, BR-002, H1, point 32)",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        expect(
          find.text(
            'Débit : 47,8 m³/s — mesuré le 27/08/2026 à 10:00 — '
            "$hydrometrieSourceName",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      'rend la hauteur en m AVEC sa date, signe conservé, en heure locale, '
      'ET sa source, dans le MÊME Text (H1, point 32)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        expect(
          find.text(
            'Hauteur : −1,232 m — mesurée le 27/08/2026 à 10:00 — '
            "$hydrometrieSourceName",
          ),
          findsOneWidget,
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

      expect(find.textContaining('Pré-validée'), findsOneWidget);
      expect(find.textContaining('Bonne'), findsOneWidget);
    });

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
        final List<String> texts = _renderedTexts(tester);
        expect(texts.any((String text) => text.contains(' m —')), isFalse);
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

        expect(find.text("Cours d'eau non renseigné"), findsOneWidget);
      },
    );
  });

  group('StationSummarySheet — le contrôle d\'avertissement de tête (W3c, '
      'arbitrage du commanditaire du 2026-09-23)', () {
    testWidgetsOnWindows(
      'le contrôle est TOUJOURS rendu, avec ou sans mesure',
      (WidgetTester tester) async {
        await _pump(tester, StationSummarySheet(data: _data()));

        expect(find.byType(WarningLink), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      "le contrôle est rendu EN TÊTE, avant la valeur du débit — assertion "
      "sur l'ORDRE dans l'arbre, pas sur la seule présence",
      (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        final double linkTop = tester.getTopLeft(find.byType(WarningLink)).dy;
        final double debitTop = tester
            .getTopLeft(find.textContaining('47,8 m³/s'))
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
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
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
        await _pump(tester, StationSummarySheet(data: _data()));

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(find.byKey(warningWindowExtraTextKey), findsNothing);
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

      expect(find.textContaining('K447001001'), findsOneWidget);
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
        expect(find.textContaining('K447001001'), findsOneWidget);
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

        expect(find.textContaining('K447001001'), findsOneWidget);
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
      'l\'étoile est SOUS le bouton de fermeture, alignée sur lui, à 8 px ; '
      'sans étoile, aucun emplacement vide',
      (WidgetTester tester) async {
        await pump420(tester, panel(enCours()));
        final Size none = tester.getSize(find.byType(StationSheetPanel));
        final Rect closeAlone = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
        // 12 + fermeture + 12 : rien de réservé pour une étoile absente.
        expect(none.height, 12 + minimumTapTarget + 12);

        await pump420(tester, panel(enCours(), star: full));
        final Rect star = tester.getRect(find.byKey(favoriteStarButtonKey));
        final Rect close = tester.getRect(
          find.byKey(stationSheetCloseButtonKey),
        );
        expect(close, closeAlone);
        expect(star.size, Size(minimumTapTarget, minimumTapTarget));
        expect(star.left, closeTo(close.left, 0.01));
        expect(star.top - close.bottom, closeTo(8, 0.01));
        expect(
          tester.getSize(find.byType(StationSheetPanel)).height,
          12 + minimumTapTarget + 8 + minimumTapTarget + 12,
        );
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

    testWidgetsOnAndroid(
      'Android : à 360 px et 200 % de police, le cadre (étoile sous la '
      'fermeture, avis d\'échec) reste dans l\'écran',
      (WidgetTester tester) async {
        // Ce test mesure LE CADRE, avec un contenu court (EnCours) et une
        // étoile que le ViewModel peut produire dans cet état : hors `Prete`,
        // une étoile de station n'existe que pleine. La fiche `Prete` entière
        // ne tient pas à 200 % sur 360 x 640 : ce débordement est ANTÉRIEUR à
        // T3 — la fiche n'est ni défilante ni bornée en hauteur
        // (`map_view.dart`, colonne des fiches). Point ouvert, hors de `S7a`.
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

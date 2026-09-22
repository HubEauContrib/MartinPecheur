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
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

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
      testWidgets('2026-08-27T08:00Z, +2 h injecté → 27/08/2026 à 10:00, sans '
          'suffixe de fuseau', (WidgetTester tester) async {
        await _pump(
          tester,
          StationSummarySheet(
            data: _data(discharge: _discharge(), level: _level()),
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        );

        expect(
          find.text('Débit : 47,8 m³/s — mesuré le 27/08/2026 à 10:00'),
          findsOneWidget,
        );
      });

      testWidgets(
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
            find.text('Débit : 47,8 m³/s — mesuré le 27/08/2026 à 05:00'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('minimumTapTarget', () {
    test('vaut 44 pt (04-ui.md § 3, cibles tactiles)', () {
      expect(minimumTapTarget, 44.0);
    });
  });

  group('StationSummarySheet — le contenu de la feuille (UC-003 § 2)', () {
    testWidgets("rend libellé, cours d'eau et département", (
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

    testWidgets('rend le débit en m³/s AVEC sa date, en heure locale (BR-001, '
        'BR-002, H1)', (WidgetTester tester) async {
      await _pump(
        tester,
        StationSummarySheet(
          data: _data(discharge: _discharge(), level: _level()),
          utcOffsetOf: (DateTime _) => const Duration(hours: 2),
        ),
      );

      expect(
        find.text('Débit : 47,8 m³/s — mesuré le 27/08/2026 à 10:00'),
        findsOneWidget,
      );
    });

    testWidgets('rend la hauteur en m AVEC sa date, signe conservé, en heure '
        'locale (H1)', (WidgetTester tester) async {
      await _pump(
        tester,
        StationSummarySheet(
          data: _data(discharge: _discharge(), level: _level()),
          utcOffsetOf: (DateTime _) => const Duration(hours: 2),
        ),
      );

      expect(
        find.text('Hauteur : −1,232 m — mesurée le 27/08/2026 à 10:00'),
        findsOneWidget,
      );
    });

    testWidgets('rend statut et qualification, verbatim (BR-006)', (
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

    testWidgets(
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

    testWidgets(
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

    testWidgets(
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

    testWidgets("hauteur absente → la même phrase d'absence (BR-007)", (
      WidgetTester tester,
    ) async {
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
    });

    testWidgets(
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

  // Le balayage porte sur les mots que l'application ÉCRIT, pas sur les
  // libellés que l'API lui transmet : `libelle_qualification_obs` vaut
  // « Bonne » sur K447001001 et BR-006 exige de le rendre verbatim. Même
  // principe que BR-014 pour les libellés d'une autorité, cités tels quels
  // et attribués. Les
  // deux libellés d'API sont donc neutres ici, pour que le balayage ne
  // mesure que la copie du produit.
  group('vocabulaire — BR-003 et BR-014', () {
    testWidgets(
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

    testWidgets(
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

    testWidgets('aucun des cinq mots bannis dans les textes du produit', (
      WidgetTester tester,
    ) async {
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
    });

    testWidgets('aucun mot de garantie (BR-014)', (WidgetTester tester) async {
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
    testWidgets('Fermee ne rend rien', (WidgetTester tester) async {
      await _pump(
        tester,
        StationSheetPanel(state: const Fermee(), onClose: () {}),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(StationSummarySheet), findsNothing);
    });

    testWidgets('EnCours rend le code de la station demandée', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(state: EnCours(_code()), onClose: () {}),
      );

      expect(find.textContaining('K447001001'), findsOneWidget);
    });

    testWidgets(
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

    testWidgets('EnEchec ne rend jamais la cause technique brute', (
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
    testWidgets(
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

    testWidgets('Introuvable porte aussi un bouton de fermeture', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        StationSheetPanel(state: Introuvable(_code()), onClose: () {}),
      );

      expect(find.byKey(stationSheetCloseButtonKey), findsOneWidget);
    });

    testWidgets('Prete rend la feuille de résumé', (WidgetTester tester) async {
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

    testWidgets(
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

    testWidgets('le bouton de fermeture appelle onClose', (
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

    testWidgets('EnCours et EnEchec portent aussi un bouton de fermeture', (
      WidgetTester tester,
    ) async {
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
    });
  });
}

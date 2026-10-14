// Verrouille les avis d'absence et de panne de la carte (`U6`) : ce que
// l'écran DIT quand il n'a rien à dessiner, et ce qu'il dit quand une source
// est tombée.
//
// Trois natures de cas, et elles ne se remplacent pas :
//
// 1. **Les textes**, comparés MOT POUR MOT à leur source
//    (`docs/02-specifications.md § 4`, `docs/br/BR-007`, `UC-001 A5`). Un
//    test qui se contenterait de `findsOneWidget` laisserait reformuler
//    « personne ne mesure ici » en « aucune mesure disponible » — or
//    `glossary.md` fait foi sur toute reformulation, et c'est précisément
//    cette phrase qui empêche de lire une carte vide comme « il n'y a pas de
//    problème ici ».
// 2. **La décision**, `mapNoticesFor` : quel avis pour quelle combinaison
//    d'échelle, de vide, de panne et de lignes illisibles — et jamais deux
//    avis qui se contredisent.
// 3. **Le balayage de vocabulaire** sur tous les textes du fichier, doublé
//    de deux verrous : la liste des constantes déclarées dans le fichier
//    source est comparée à celle que ce test balaie, si bien qu'un texte
//    ajouté demain rend la suite rouge tant qu'il n'est pas balayé lui
//    aussi ; et, parce que ce premier verrou ne voit que les `const String`
//    et les fonctions de PREMIER NIVEAU, un second balaie **tous les
//    littéraux de chaîne** du fichier — un texte écrit en clair dans le
//    `build` d'un widget échapperait au premier.
//
// ⚠️ Un piège structurel du balayage : le texte de `BR-007` CONTIENT « tout
// va bien » — « Ce n'est pas un signe que tout va bien ». La tournure
// interdite est l'AFFIRMATION, pas sa négation recopiée de la règle. Le
// balayage l'exprime tel quel : « tout va bien » n'est toléré que dans la
// phrase exacte de `BR-007`, nulle part ailleurs.
//
// Aucun cas ne rend de `FlutterMap` : ces avis sont des surcouches, et
// l'environnement de test refuse le chargement de tuiles.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart'
    show MapErrorSource;
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart'
    show focusRingColor;
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// Le fichier source des avis, lu par le verrou d'exhaustivité ci-dessous.
const String _sourcePath = 'lib/features/map/view/map_empty_states.dart';

/// Tous les textes que ce fichier peut afficher, valeurs de paramètre
/// comprises. Le verrou `aucune constante de texte n'échappe au balayage`
/// garantit que cette liste reste complète.
List<String> _allTexts() => <String>[
  noDataInAreaText,
  widenSearchLabel,
  filterHidesEverythingText,
  clearFiltersLabel,
  outsideOndeCoverageText,
  noDataFallbackText,
  noStationInAreaText,
  sourceUnavailableHint,
  unreadableRowsHint,
  for (final MapErrorSource source in MapErrorSource.values)
    mapSourceName(source),
  mapSourceName(null),
  for (final MapErrorSource source in MapErrorSource.values)
    sourceUnavailableText(mapSourceName(source)),
  unreadableRowsText(0),
  unreadableRowsText(1),
  unreadableRowsText(3),
];

/// Les constantes de texte déclarées dans le fichier source, et que
/// [_allTexts] balaie donc nommément.
const List<String> _sweptConstants = <String>[
  'noDataInAreaText',
  'widenSearchLabel',
  'filterHidesEverythingText',
  'clearFiltersLabel',
  'outsideOndeCoverageText',
  'noDataFallbackText',
  'noStationInAreaText',
  'sourceUnavailableHint',
  'unreadableRowsHint',
];

/// Les fonctions de texte déclarées dans le fichier source, et que
/// [_allTexts] balaie sur des valeurs représentatives.
const List<String> _sweptTextFunctions = <String>[
  'sourceUnavailableText',
  'unreadableRowsText',
  'mapSourceName',
];

/// Les cinq mots bannis pour qualifier un débit (`BR-003`, `glossary.md`,
/// CLAUDE.md). Balayés par MOT ENTIER : un « bon » caché dans « bonne » doit
/// rester détectable, et « abonné » ne doit pas déclencher un faux positif.
const List<String> _bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

/// Les mots que `glossary.md` § « Reformulations » proscrit au profit d'un
/// seul : « assec », « tari » et « asséché » se disent **« à sec »**, partout
/// — un concept, un mot. La règle vaut pour les avis de la carte comme pour
/// la fiche ONDE, qui la balaie déjà (`onde_marker.dart`,
/// `onde_sheet_view_model.dart`).
const List<String> _glossaryWords = <String>['assec', 'tari', 'asséché'];

/// Les mots de garantie de `BR-014` et du `glossary.md` : « "Données
/// fiables", "vérifié", "officiel", "en direct" », « ni temps réel ».
///
/// ⚠️ « officiel » figure ICI, contrairement au balayage de la fiche ONDE
/// (`onde_sheet_view_model_test.dart`) où il nomme la nomenclature
/// officielle de la source (`ADR-006`, `UC-004 § 3`). Ce fichier-ci ne cite
/// aucune nomenclature : le mot n'y aurait d'autre rôle qu'une garantie.
const List<String> _guaranteeWords = <String>[
  'fiable',
  'fiables',
  'vérifié',
  'vérifiée',
  'vérifiées',
  'officiel',
  'officielle',
  'direct',
  'réel',
  'réelle',
];

Set<String> _wordsOf(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-zà-öø-ÿ]+'))
    .where((String word) => word.isNotEmpty)
    .toSet();

/// Un littéral de chaîne Dart, quelle que soit sa forme de guillemets. Deux
/// alternatives et non une : `"Il n'y a ni station…"` porte une apostrophe,
/// `'Élargir la recherche'` porte l'autre.
/// Chacune est écrite dans un littéral brut de l'AUTRE forme de guillemets :
/// c'est la seule façon de les poser sans échappement.
const String _doubleQuoted = r'"(?:[^"\\\n]|\\.)*"';
const String _singleQuoted = r"'(?:[^'\\\n]|\\.)*'";
final RegExp _stringLiteral = RegExp('$_doubleQuoted|$_singleQuoted');

/// TOUS les littéraux de chaîne du fichier source, les commentaires retirés.
///
/// Le verrou de déclarations ne voit que les `const String` et les fonctions
/// de premier niveau ; un texte écrit en clair dans le `build` d'un widget
/// lui échapperait. Celui-ci balaie la matière brute.
///
/// ⚠️ **Seuls les mots** sont vérifiés sur ces littéraux, pas les phrases
/// interdites : un texte long est écrit en morceaux concaténés, et le
/// morceau « …Ce n'est pas un signe que tout va bien : c'est » ne se
/// reconnaîtrait pas dans la phrase entière de `BR-007`. Les phrases restent
/// balayées sur [_allTexts], où elles sont recomposées.
List<String> _sourceLiterals() {
  final String sansCommentaires = File(_sourcePath)
      .readAsLinesSync()
      .where((String ligne) => !ligne.trimLeft().startsWith('//'))
      .join('\n');

  return _stringLiteral
      .allMatches(sansCommentaires)
      .map((RegExpMatch match) => match.group(0)!)
      .toList();
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('NoDataInAreaNotice — ni station ni point (BR-007, UC-001 A2)', () {
    testWidgetsOnWindows(
      'le texte est celui de BR-007 et de 02-specifications § 4, '
      'mot pour mot',
      (WidgetTester tester) async {
        await _pump(tester, NoDataInAreaNotice(onWiden: () {}));

        expect(
          find.text(
            "Il n'y a ni station de mesure ni point d'observation dans le "
            "secteur affiché. Ce n'est pas un signe que tout va bien : c'est "
            'simplement que personne ne mesure ici.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      "l'action « Élargir la recherche » est rendue, appelle "
      'onWiden, et sa cible fait au moins 44 pt (04-ui.md § 3, '
      'UC-001 A2)',
      (WidgetTester tester) async {
        int elargissements = 0;
        await _pump(
          tester,
          NoDataInAreaNotice(onWiden: () => elargissements++),
        );

        final Finder action = find.byKey(widenSearchKey);
        expect(action, findsOneWidget);
        expect(find.text(widenSearchLabel), findsOneWidget);

        final Size taille = tester.getSize(action);
        expect(taille.width, greaterThanOrEqualTo(minimumTapTarget));
        expect(taille.height, greaterThanOrEqualTo(minimumTapTarget));

        await tester.tap(action);
        await tester.pump();

        expect(elargissements, 1);
      },
    );

    testWidgetsOnWindows(
      "« Élargir la recherche » porte une action tap pour le "
      "lecteur d'écran — `excludeSemantics` masque celle du geste "
      '(relecture du 2026-09-23)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        int elargissements = 0;
        await _pump(
          tester,
          NoDataInAreaNotice(onWiden: () => elargissements++),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byKey(widenSearchKey),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(elargissements, 1);

        handle.dispose();
      },
    );
  });

  group('OutsideOndeCoverageNotice — le périmètre réel (UC-001 A5)', () {
    testWidgetsOnWindows(
      'le texte NOMME le périmètre : France hexagonale, Corse, '
      "petits cours d'eau choisis",
      (WidgetTester tester) async {
        await _pump(tester, const OutsideOndeCoverageNotice());

        expect(
          find.text(
            "Le réseau ONDE ne suit que certains petits cours d'eau de France "
            'hexagonale et de Corse.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      "l'absence est nommée, jamais laissée muette (BR-007)",
      (WidgetTester tester) async {
        await _pump(tester, const OutsideOndeCoverageNotice());

        expect(find.text(noDataFallbackText), findsOneWidget);
      },
    );
  });

  group('SourceUnavailableNotice — un message PAR SOURCE (BR-007)', () {
    testWidgetsOnWindows('le texte nomme la source passée', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const SourceUnavailableNotice(sourceName: "Hub'Eau"));

      expect(find.text("Hub'Eau n'a pas répondu."), findsOneWidget);
    });

    testWidgetsOnWindows(
      'deux sources distinctes donnent deux messages distincts : '
      "l'écran ne dit jamais « une erreur est survenue »",
      (WidgetTester tester) async {
        await _pump(
          tester,
          const SourceUnavailableNotice(sourceName: "Hub'Eau hydrométrie"),
        );
        expect(find.textContaining('hydrométrie'), findsOneWidget);

        await _pump(
          tester,
          const SourceUnavailableNotice(sourceName: "Hub'Eau écoulement ONDE"),
        );
        expect(find.textContaining('écoulement ONDE'), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'ne dit ni « rien à signaler », ni « tout va bien », ni '
      '« aucun problème »',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const SourceUnavailableNotice(sourceName: "Hub'Eau"),
        );

        for (final String phrase in <String>[
          'rien à signaler',
          'tout va bien',
          'aucun problème',
        ]) {
          expect(
            find.textContaining(phrase),
            findsNothing,
            reason: '"$phrase" est interdit par BR-007',
          );
        }
      },
    );

    testWidgetsOnWindows(
      "la cause technique n'est JAMAIS rendue : c'est une donnée "
      "de diagnostic, pas un texte pour l'usager — la convention des deux "
      'fiches (`station_summary_sheet.dart`, `onde_summary_sheet.dart`), '
      "et le grief porté contre l'ancien `MapErrorBanner`",
      (WidgetTester tester) async {
        await _pump(
          tester,
          const SourceUnavailableNotice(sourceName: "Hub'Eau"),
        );

        for (final String diagnostic in <String>[
          'HubEauFailure',
          '503',
          'Exception',
          'Bad state',
        ]) {
          expect(
            find.textContaining(diagnostic),
            findsNothing,
            reason: '"$diagnostic" est un texte de diagnostic, pas d interface',
          );
        }
        expect(find.text(sourceUnavailableText("Hub'Eau")), findsOneWidget);
        expect(find.text(sourceUnavailableHint), findsOneWidget);
      },
    );
  });

  group('NoStationInAreaNotice — zone sans station, échelle débit '
      '(U6, arbitrage du commanditaire 2026-09-18)', () {
    testWidgetsOnWindows(
      'dit EXACTEMENT la phrase retenue par le commanditaire, et '
      'ne porte plus la formulation de repli générique de BR-007 : sur '
      "l'échelle débit l'ONDE n'est pas interrogée (BR-008), « ni station "
      "ni point » affirmerait une lecture qui n'a pas eu lieu",
      (WidgetTester tester) async {
        await _pump(tester, NoStationInAreaNotice(onWiden: () {}));

        expect(
          find.text(
            "Il n'y a aucune station de mesure dans le secteur affiché. Cela "
            "ne dit rien de l'état des cours d'eau : le débit n'est "
            'simplement pas mesuré ici.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(noDataFallbackText),
          findsNothing,
          reason:
              'la formulation de repli générique est remplacée par la phrase '
              'dédiée depuis le 2026-09-18',
        );
        expect(
          find.textContaining("point d'observation"),
          findsNothing,
          reason: "on n'affirme que ce qu'on a lu",
        );
        expect(
          find.textContaining('ONDE'),
          findsNothing,
          reason: "l'ONDE n'est pas interrogée sur l'échelle débit (BR-008)",
        );
        expect(find.textContaining('personne ne mesure ici'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "l'action « Élargir la recherche » y est rendue aussi : une "
      'absence sans issue serait un cul-de-sac (UC-001 A2)',
      (WidgetTester tester) async {
        int elargissements = 0;
        await _pump(
          tester,
          NoStationInAreaNotice(onWiden: () => elargissements++),
        );

        expect(find.text(widenSearchLabel), findsOneWidget);

        await tester.tap(find.byKey(widenSearchKey));
        await tester.pump();

        expect(elargissements, 1);
      },
    );
  });

  group('FilterHidesEverythingNotice — une carte vidée par le filtre (F8 de '
      'T3, cadrage § 10.1)', () {
    testWidgetsOnWindows('le texte est celui du cadrage § 10.1, mot pour mot, '
        'et rien ne dit que les cours d\'eau sont dans un état', (
      WidgetTester tester,
    ) async {
      await _pump(tester, FilterHidesEverythingNotice(onClearFilters: () {}));

      expect(
        find.text(
          'Les filtres masquent tous les lieux du secteur affiché. Cela ne '
          "dit rien de l'état des cours d'eau.",
        ),
        findsOneWidget,
      );
      expect(find.text(clearFiltersLabel), findsOneWidget);
      expect(clearFiltersLabel, 'Effacer les filtres');
    });

    testWidgetsOnWindows(
      "l'action « Effacer les filtres » est un bouton sémantique, et un tap "
      'appelle onClearFilters UNE fois',
      (WidgetTester tester) async {
        int effacements = 0;
        await _pump(
          tester,
          FilterHidesEverythingNotice(onClearFilters: () => effacements++),
        );

        expect(
          tester.getSemantics(find.byKey(clearFiltersKey)),
          matchesSemantics(
            label: 'Effacer les filtres',
            isButton: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.byKey(clearFiltersKey));
        await tester.pump();

        expect(effacements, 1);
      },
    );

    testWidgetsOnWindows(
      "l'action porte une action tap pour le lecteur d'écran, qui appelle "
      'onClearFilters',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        int effacements = 0;
        await _pump(
          tester,
          FilterHidesEverythingNotice(onClearFilters: () => effacements++),
        );

        final SemanticsNode node = tester.getSemantics(
          find.byKey(clearFiltersKey),
        );
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();

        expect(effacements, 1);
        handle.dispose();
      },
    );

    testWidgetsOnWindows(
      "aucun avis d'absence, aucune action « Élargir la recherche » avec "
      'lui (BR-007)',
      (WidgetTester tester) async {
        await _pump(tester, FilterHidesEverythingNotice(onClearFilters: () {}));

        expect(find.byType(NoDataInAreaNotice), findsNothing);
        expect(find.byType(NoStationInAreaNotice), findsNothing);
        expect(find.byType(OutsideOndeCoverageNotice), findsNothing);
        expect(find.byKey(widenSearchKey), findsNothing);
        expect(find.text(widenSearchLabel), findsNothing);
        expect(find.textContaining('personne ne mesure'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'la cible de l\'action fait au moins 44 pt (Windows)',
      (WidgetTester tester) async {
        await _pump(tester, FilterHidesEverythingNotice(onClearFilters: () {}));

        final Size taille = tester.getSize(find.byKey(clearFiltersKey));
        expect(
          taille.height,
          greaterThanOrEqualTo(minimumTapTargetFor(TargetPlatform.windows)),
        );
        expect(
          taille.width,
          greaterThanOrEqualTo(minimumTapTargetFor(TargetPlatform.windows)),
        );
      },
    );

    testWidgetsOnAndroid(
      'Android : la cible de l\'action fait au moins 48 dp',
      (WidgetTester tester) async {
        await _pump(tester, FilterHidesEverythingNotice(onClearFilters: () {}));

        final Size taille = tester.getSize(find.byKey(clearFiltersKey));
        expect(
          taille.height,
          greaterThanOrEqualTo(minimumTapTargetFor(TargetPlatform.android)),
        );
        expect(
          taille.width,
          greaterThanOrEqualTo(minimumTapTargetFor(TargetPlatform.android)),
        );
      },
    );

    testWidgetsOnWindows(
      "« Élargir la recherche » est rendu comme avant par l'action "
      'partagée : même clé, même libellé, une seule action',
      (WidgetTester tester) async {
        int elargissements = 0;
        await _pump(
          tester,
          NoDataInAreaNotice(onWiden: () => elargissements++),
        );

        expect(
          tester.getSemantics(find.byKey(widenSearchKey)),
          matchesSemantics(
            label: 'Élargir la recherche',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(find.byKey(clearFiltersKey), findsNothing);
        await tester.tap(find.byKey(widenSearchKey));
        await tester.pump();
        expect(elargissements, 1);
      },
    );
  });

  // Les actions des avis au clavier (`K1` de T3, arbitrage du commanditaire
  // du 2026-10-14) : « Effacer les filtres » et « Élargir la recherche »
  // deviennent des arrêts de Tab, Entrée et Espace font ce que le tap fait.
  // Leur place dans l'ordre de la carte est vérifiée sur la carte
  // (`map_keyboard_test.dart`, `map_overlays_phone_test.dart`).
  group('les actions des avis au clavier (K1 de T3)', () {
    for (final (String, Key, Widget Function(VoidCallback)) avis
        in <(String, Key, Widget Function(VoidCallback))>[
          (
            '« Effacer les filtres » (FilterHidesEverythingNotice)',
            clearFiltersKey,
            (VoidCallback rappel) =>
                FilterHidesEverythingNotice(onClearFilters: rappel),
          ),
          (
            '« Élargir la recherche » (NoDataInAreaNotice)',
            widenSearchKey,
            (VoidCallback rappel) => NoDataInAreaNotice(onWiden: rappel),
          ),
          (
            '« Élargir la recherche » (NoStationInAreaNotice)',
            widenSearchKey,
            (VoidCallback rappel) => NoStationInAreaNotice(onWiden: rappel),
          ),
        ]) {
      testWidgetsOnWindows('${avis.$1} : Tab atteint l’action, et son anneau '
          'de focus est visible', (WidgetTester tester) async {
        await _pump(tester, avis.$3(() {}));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(focusedWithin(tester, find.byKey(avis.$2)), isTrue);
        expect(
          find.descendant(
            of: find.byKey(avis.$2),
            matching: find.byWidgetPredicate((Widget w) {
              if (w is! DecoratedBox) {
                return false;
              }
              final Decoration decoration = w.decoration;
              return decoration is BoxDecoration &&
                  decoration.border?.top.color == focusRingColor;
            }),
          ),
          findsOneWidget,
          reason: 'l’anneau de focus doit se voir sur l’action',
        );
      });

      testWidgetsOnWindows('${avis.$1} : action focalisée, Entrée puis Espace '
          'appellent le rappel UNE fois chacune', (WidgetTester tester) async {
        int appels = 0;
        await _pump(tester, avis.$3(() => appels++));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(appels, 1, reason: 'Entrée');

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(appels, 2, reason: 'Espace');
      });
    }
  });

  group('UnreadableRowsNotice — les lignes ONDE illisibles (T-14)', () {
    testWidgetsOnWindows('1 : singulier', (WidgetTester tester) async {
      await _pump(tester, const UnreadableRowsNotice(count: 1));

      expect(
        find.text("1 point d'observation non lisible sur cette emprise."),
        findsOneWidget,
      );
    });

    testWidgetsOnWindows('3 : pluriel', (WidgetTester tester) async {
      await _pump(tester, const UnreadableRowsNotice(count: 3));

      expect(
        find.text("3 points d'observation non lisibles sur cette emprise."),
        findsOneWidget,
      );
    });
  });

  group('mapNoticesFor — la décision, pure et exhaustive (U6)', () {
    /// Les paramètres d'un écran sain, qu'on dévie un à un.
    List<MapNotice> notices({
      MapScaleKind scale = MapScaleKind.ecoulement,
      bool hasStations = true,
      bool hasOndeObservations = true,
      Object? error,
      MapErrorSource? errorSource,
      int ondeUnreadableRows = 0,
      bool filterHidesEverything = false,
    }) => mapNoticesFor(
      scale: scale,
      hasStations: hasStations,
      hasOndeObservations: hasOndeObservations,
      error: error,
      errorSource: errorSource,
      ondeUnreadableRows: ondeUnreadableRows,
      filterHidesEverything: filterHidesEverything,
    );

    test('un filtre qui masque tout, écoulement, des observations lues : '
        "l'avis des filtres, et aucun avis d'absence", () {
      expect(notices(filterHidesEverything: true), <MapNotice>[
        const FilterHidesEverything(),
      ]);
    });

    test('un filtre qui masque tout, écoulement, avec 3 lignes illisibles : '
        'les DEUX avis, le compte d\'abord — ils ne se contredisent pas', () {
      final List<MapNotice> rendus = notices(
        filterHidesEverything: true,
        ondeUnreadableRows: 3,
      );

      expect(rendus.map((MapNotice avis) => avis.runtimeType).toList(), <Type>[
        UnreadableRows,
        FilterHidesEverything,
      ]);
      expect((rendus.first as UnreadableRows).count, 3);
    });

    test('un filtre qui masque tout, écoulement, aucune observation lue, des '
        "stations : l'avis habituel du périmètre ONDE — un filtre ne vide "
        'pas ce qui n\'a pas été lu', () {
      expect(
        notices(hasOndeObservations: false, filterHidesEverything: true),
        <MapNotice>[const OutsideOndeCoverage()],
      );
    });

    test('un filtre qui masque tout, écoulement, ni station ni observation '
        "lue : l'avis d'absence habituel (BR-007)", () {
      expect(
        notices(
          hasStations: false,
          hasOndeObservations: false,
          filterHidesEverything: true,
        ),
        <MapNotice>[const NoDataInArea()],
      );
    });

    test('un filtre qui masque tout, débit, des stations lues : '
        "l'avis des filtres seul", () {
      expect(
        notices(scale: MapScaleKind.debit, filterHidesEverything: true),
        <MapNotice>[const FilterHidesEverything()],
      );
    });

    test('un filtre qui masque tout, débit, ni station lue : '
        "l'avis d'absence habituel", () {
      expect(
        notices(
          scale: MapScaleKind.debit,
          hasStations: false,
          filterHidesEverything: true,
        ),
        <MapNotice>[const NoStationInArea()],
      );
    });

    test('un filtre qui masque tout, débit, avec des lignes ONDE illisibles '
        "résiduelles : l'avis des filtres seul — elles ne disent rien "
        'sur cette échelle (BR-008)', () {
      expect(
        notices(
          scale: MapScaleKind.debit,
          ondeUnreadableRows: 5,
          filterHidesEverything: true,
        ),
        <MapNotice>[const FilterHidesEverything()],
      );
    });

    test('une panne parle seule, même quand le filtre masque tout, sur les '
        'deux échelles', () {
      for (final MapScaleKind scale in MapScaleKind.values) {
        final List<MapNotice> rendus = notices(
          scale: scale,
          error: StateError('panne'),
          errorSource: MapErrorSource.ecoulement,
          ondeUnreadableRows: 3,
          filterHidesEverything: true,
        );

        expect(rendus, hasLength(1), reason: '$scale');
        expect(rendus.single, isA<SourceUnavailable>(), reason: '$scale');
      }
    });

    test("échelle débit, aucune station, aucune erreur : la phrase dédiée "
        "de l'arbitrage du 2026-09-18, jamais « ni station ni point » — "
        "l'ONDE n'est pas interrogée sur cette échelle (BR-008), la moitié "
        "de la phrase ne serait adossée à aucune lecture", () {
      expect(
        notices(
          scale: MapScaleKind.debit,
          hasStations: false,
          hasOndeObservations: false,
        ),
        <MapNotice>[const NoStationInArea()],
      );
    });

    test("échelle débit, aucune station mais des observations ONDE en "
        'mémoire : toujours la phrase dédiée — ce résidu vient du dernier '
        "passage sur l'échelle écoulement, il ne dit rien de cette "
        'emprise-ci', () {
      expect(
        notices(scale: MapScaleKind.debit, hasStations: false),
        <MapNotice>[const NoStationInArea()],
      );
      expect(
        notices(
          scale: MapScaleKind.debit,
          hasStations: false,
          ondeUnreadableRows: 4,
        ),
        <MapNotice>[const NoStationInArea()],
      );
    });

    test("échelle débit, des stations : aucun avis — la carte parle d'elle "
        'même', () {
      expect(notices(scale: MapScaleKind.debit), isEmpty);
    });

    test('échelle écoulement, ni station ni observation : « ni station ni '
        'point »', () {
      expect(
        notices(hasStations: false, hasOndeObservations: false),
        <MapNotice>[const NoDataInArea()],
      );
    });

    test('échelle écoulement, des STATIONS mais aucune observation ONDE : '
        'hors couverture ONDE, jamais « ni station ni point » — la phrase '
        'de BR-007 serait fausse, il y a des stations', () {
      expect(notices(hasOndeObservations: false), <MapNotice>[
        const OutsideOndeCoverage(),
      ]);
    });

    test('échelle écoulement, des observations : aucun avis', () {
      expect(notices(), isEmpty);
    });

    test('une erreur rend UN SEUL avis, celui qui nomme la source : une '
        "panne explique l'absence, « personne ne mesure ici » serait alors "
        'un mensonge', () {
      final List<MapNotice> rendus = notices(
        hasStations: false,
        hasOndeObservations: false,
        error: StateError('panne'),
        errorSource: MapErrorSource.ecoulement,
        ondeUnreadableRows: 4,
      );

      expect(rendus, hasLength(1));
      expect(rendus.single, isA<SourceUnavailable>());
      expect(
        (rendus.single as SourceUnavailable).sourceName,
        mapSourceName(MapErrorSource.ecoulement),
        reason:
            "l'avis porte le NOM de la source et rien d'autre : la cause "
            "technique reste du diagnostic, elle n'entre pas dans la "
            "décision d'affichage",
      );
    });

    test('des lignes illisibles ET des observations : un avis qui explique '
        "une absence PARTIELLE, sans contredire les marqueurs affichés", () {
      final List<MapNotice> rendus = notices(ondeUnreadableRows: 3);

      expect(rendus, hasLength(1));
      expect(rendus.single, isA<UnreadableRows>());
      expect((rendus.single as UnreadableRows).count, 3);
    });

    test('toutes les lignes illisibles, donc aucune observation : le compte '
        "explique l'absence, et « personne ne mesure ici » N'EST PAS rendu "
        '— les deux avis se contrediraient', () {
      final List<MapNotice> rendus = notices(
        hasOndeObservations: false,
        hasStations: false,
        ondeUnreadableRows: 2,
      );

      expect(rendus, hasLength(1));
      expect(rendus.single, isA<UnreadableRows>());
    });

    test('échelle débit : les lignes ONDE illisibles ne disent rien — aucune '
        "observation d'écoulement n'est dessinée (BR-008)", () {
      expect(
        notices(scale: MapScaleKind.debit, ondeUnreadableRows: 5),
        isEmpty,
      );
    });

    test('sur TOUTES les combinaisons : jamais deux avis d absence, et une '
        'panne parle seule', () {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool stations in <bool>[true, false]) {
          for (final bool observations in <bool>[true, false]) {
            for (final int illisibles in <int>[0, 2]) {
              for (final Object? error in <Object?>[null, StateError('x')]) {
                for (final bool filtre in <bool>[false, true]) {
                  final List<MapNotice> rendus = mapNoticesFor(
                    scale: scale,
                    hasStations: stations,
                    hasOndeObservations: observations,
                    error: error,
                    errorSource: error == null
                        ? null
                        : MapErrorSource.referentiel,
                    ondeUnreadableRows: illisibles,
                    filterHidesEverything: filtre,
                  );

                  expect(
                    rendus.whereType<NoDataInArea>().length +
                        rendus.whereType<NoStationInArea>().length +
                        rendus.whereType<OutsideOndeCoverage>().length,
                    lessThanOrEqualTo(1),
                    reason:
                        'deux avis d absence pour $scale / stations=$stations '
                        '/ observations=$observations / filtre=$filtre',
                  );
                  expect(
                    rendus.whereType<FilterHidesEverything>().length +
                        (rendus.whereType<NoDataInArea>().length +
                            rendus.whereType<NoStationInArea>().length +
                            rendus.whereType<OutsideOndeCoverage>().length),
                    lessThanOrEqualTo(1),
                    reason:
                        "l'avis des filtres et un avis d'absence se "
                        'contrediraient : $scale / stations=$stations / '
                        'observations=$observations / filtre=$filtre',
                  );
                  if (!filtre) {
                    expect(
                      rendus.whereType<FilterHidesEverything>(),
                      isEmpty,
                      reason:
                          "sans filtre qui masque tout, pas l'avis des filtres",
                    );
                  }
                  if (scale == MapScaleKind.debit) {
                    expect(
                      rendus.whereType<NoDataInArea>(),
                      isEmpty,
                      reason:
                          '« ni station ni point » suppose que les DEUX ont '
                          'été cherchés ; sur l échelle débit, l ONDE ne l a '
                          'pas été (BR-008) — on n affirme que ce qu on a lu',
                    );
                  }
                  if (error != null) {
                    expect(
                      rendus.map((MapNotice avis) => avis.runtimeType).toList(),
                      <Type>[SourceUnavailable],
                      reason: 'une panne parle seule',
                    );
                  }
                }
              }
            }
          }
        }
      }
    });
  });

  group('mapSourceName — nommer la source, jamais « une erreur »', () {
    test('chaque source a son nom, et ils sont distincts', () {
      final List<String> noms = MapErrorSource.values
          .map(mapSourceName)
          .toList();

      expect(noms.toSet(), hasLength(MapErrorSource.values.length));
      expect(mapSourceName(MapErrorSource.ecoulement), contains("Hub'Eau"));
      expect(
        mapSourceName(MapErrorSource.referentiel),
        contains('référentiel'),
      );
    });

    test("une source inconnue a tout de même un nom : une nomenclature "
        "tolère toujours l'inconnu (BR-011)", () {
      expect(mapSourceName(null), isNotEmpty);
    });

    test('mapSourceName(ecoulement) est IDENTIQUE à ondeSourceName : un '
        'concept, un mot (glossary.md, W4) — la chaîne est réutilisée, pas '
        'recopiée', () {
      expect(mapSourceName(MapErrorSource.ecoulement), ondeSourceName);
    });
  });

  group('balayage de vocabulaire sur TOUS les textes du fichier', () {
    test("aucune constante de texte n'échappe au balayage : les déclarations "
        'du fichier source sont exactement celles que ce test balaie', () {
      final String source = File(_sourcePath).readAsStringSync();

      final List<String> constantes = RegExp(
        r'^const String (\w+)',
        multiLine: true,
      ).allMatches(source).map((RegExpMatch m) => m.group(1)!).toList();
      final List<String> fonctions = RegExp(
        r'^String (\w+)\(',
        multiLine: true,
      ).allMatches(source).map((RegExpMatch m) => m.group(1)!).toList();

      expect(
        constantes,
        unorderedEquals(_sweptConstants),
        reason:
            'un texte ajouté au fichier doit être ajouté à `_allTexts` — '
            "sans quoi il échapperait aux balayages BR-003 et BR-014",
      );
      expect(fonctions, unorderedEquals(_sweptTextFunctions));
    });

    test('le balayage lit bien des textes — un filtre muet passerait tout', () {
      expect(
        _allTexts().any((String t) => t.contains('personne ne mesure ici')),
        isTrue,
        reason:
            'le texte de BR-007 doit être vu par le balayage, sinon celui-ci '
            'ne prouve rien',
      );
    });

    test('aucun des cinq mots bannis de BR-003', () {
      for (final String texte in _allTexts()) {
        final Set<String> mots = _wordsOf(texte);
        for (final String banni in _bannedWords) {
          expect(
            mots,
            isNot(contains(banni)),
            reason: '"$banni" trouvé MOT POUR MOT dans "$texte" (BR-003)',
          );
        }
      }
    });

    test('aucun mot de garantie de BR-014 ni du glossaire', () {
      for (final String texte in _allTexts()) {
        final Set<String> mots = _wordsOf(texte);
        for (final String garantie in _guaranteeWords) {
          expect(
            mots,
            isNot(contains(garantie)),
            reason: '"$garantie" trouvé dans "$texte" (BR-014, glossary.md)',
          );
        }
      }
    });

    test('aucune des reformulations proscrites par le glossaire : « assec », '
        '« tari », « asséché » se disent « à sec »', () {
      for (final String texte in _allTexts()) {
        final Set<String> mots = _wordsOf(texte);
        for (final String proscrit in _glossaryWords) {
          expect(
            mots,
            isNot(contains(proscrit)),
            reason: '"$proscrit" trouvé dans "$texte" — « à sec » (glossary)',
          );
        }
      }
    });

    test("AUCUN littéral du fichier source n'échappe au vocabulaire : le "
        'verrou de déclarations ne couvre que les `const String` et les '
        'fonctions de PREMIER NIVEAU — un texte écrit en clair dans un '
        'widget lui échapperait, celui-ci le rattrape', () {
      final List<String> litteraux = _sourceLiterals();

      expect(
        litteraux.any((String l) => l.contains('personne ne mesure ici')),
        isTrue,
        reason:
            'le balayage doit voir les textes du fichier, sinon il ne prouve '
            'rien : une extraction muette passerait tout',
      );

      for (final String litteral in litteraux) {
        final Set<String> mots = _wordsOf(litteral);
        for (final String proscrit in <String>[
          ..._bannedWords,
          ..._guaranteeWords,
          ..._glossaryWords,
        ]) {
          expect(
            mots,
            isNot(contains(proscrit)),
            reason: '"$proscrit" trouvé dans le littéral "$litteral"',
          );
        }
      }
    });

    test('« rien à signaler » et « aucun problème » sont absents ; « tout va '
        "bien » n'apparaît QUE dans la négation recopiée de BR-007", () {
      for (final String texte in _allTexts()) {
        final String minuscules = texte.toLowerCase();

        expect(
          minuscules,
          isNot(contains('rien à signaler')),
          reason: 'BR-007 interdit « rien à signaler » — "$texte"',
        );
        expect(
          minuscules,
          isNot(contains('aucun problème')),
          reason: 'BR-007 interdit « aucun problème » — "$texte"',
        );

        if (minuscules.contains('tout va bien')) {
          expect(
            texte,
            noDataInAreaText,
            reason:
                '« tout va bien » nest tolérable que dans la phrase exacte '
                'de BR-007 (« Ce nest pas un signe que tout va bien ») : la '
                'tournure interdite est lAFFIRMATION. Trouvé : "$texte"',
          );
        }
      }
    });
  });
}

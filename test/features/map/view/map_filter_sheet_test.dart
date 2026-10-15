// La feuille « Filtres » de la carte (`F9` de T3) : états sur l'écoulement
// seulement, département sur les deux échelles, fraîcheur sur le débit
// seulement. Le brouillon vit dans la feuille ; rien n'atteint l'appelant
// sans « Appliquer » ou « Effacer ».
//
// Tout cas nomme sa plateforme : Windows par défaut, Android pour la fenêtre
// de téléphone, le retour du téléphone et la cible de 48.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_filter_sheet.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../project/vocabulary_lists.dart';
import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

const Key _openKey = Key('test-open-filter-sheet');

const AdministrativeArea _loirEtCher = AdministrativeArea(
  code: '41',
  label: 'LOIR-ET-CHER',
);
const AdministrativeArea _dordogne = AdministrativeArea(
  code: '24',
  label: 'DORDOGNE',
);
const List<AdministrativeArea> _departements = <AdministrativeArea>[
  _dordogne,
  _loirEtCher,
];

/// Les deux phrases et la phrase des 60 jours, telles qu'approuvées
/// (cadrage de T3, § 10.1 (b)) : comparées au mot.
const String _flowWindowText =
    "La carte ne montre que les campagnes d'observation des 60 derniers "
    "jours. Un point observé plus tôt n'y figure pas.";
const String _loadedOnlyText =
    'Ce critère ne porte que sur les mesures déjà chargées : une station '
    "dont la mesure n'est pas encore chargée reste affichée.";
const String _clustersText =
    "Il ne s'applique pas aux regroupements par région ou par département : "
    "leur compte n'en tient pas compte.";

/// Ouvre la feuille par `showDialog` depuis un bouton de test, et rend la
/// liste des filtres reçus par `onApply`.
Future<List<MapFilter>> _open(
  WidgetTester tester, {
  required MapScaleKind scale,
  MapFilter initialFilter = MapFilter.none,
  List<AdministrativeArea>? departements = _departements,
  double textScale = 1,
}) async {
  final List<MapFilter> applied = <MapFilter>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              key: _openKey,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) => MapFilterSheet(
                  scale: scale,
                  initialFilter: initialFilter,
                  departements: departements,
                  onApply: applied.add,
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
  expect(find.byKey(mapFilterSheetKey), findsOneWidget);
  return applied;
}

/// Fenêtre de téléphone, 360 × 640.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Amène [finder] dans le champ puis le touche.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseDepartement(WidgetTester tester, String option) async {
  await _tap(tester, find.byKey(mapFilterDepartementKey));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

final List<Key> _sheetKeys = <Key>[
  mapFilterClearKey,
  for (final FlowCategory category in filterableFlowCategories)
    mapFilterCategoryKey(category),
  mapFilterDepartementKey,
  for (final DischargeFreshnessCriterion criterion
      in DischargeFreshnessCriterion.values)
    mapFilterFreshnessKey(criterion),
  mapFilterCloseKey,
  mapFilterApplyKey,
];

/// La clé de la feuille qui porte le focus courant, ou `null`.
Key? _focusedKey() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return null;
  }
  final List<Key> candidates = _sheetKeys;
  Key? found;
  context.visitAncestorElements((Element element) {
    final Key? key = element.widget.key;
    if (key != null && candidates.contains(key)) {
      found = key;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _pressTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

/// Tabule jusqu'à [key] (douze appuis au plus).
Future<void> _tabTo(WidgetTester tester, Key key) async {
  for (int i = 0; i < 12 && _focusedKey() != key; i++) {
    await _pressTab(tester);
  }
  expect(_focusedKey(), key);
}

/// Les arrêts de tabulation, depuis l'ouverture, sur [count] appuis.
Future<List<Key?>> _tabStops(WidgetTester tester, int count) async {
  final List<Key?> stops = <Key?>[];
  for (int i = 0; i < count; i++) {
    await _pressTab(tester);
    stops.add(_focusedKey());
  }
  return stops;
}

List<String> _sheetTexts(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(mapFilterSheetKey),
      matching: find.byType(Text, skipOffstage: false),
      skipOffstage: false,
    ),
  ))
    text.data ?? '',
];

bool _checked(WidgetTester tester, FlowCategory category) => tester
    .widget<CheckboxListTile>(find.byKey(mapFilterCategoryKey(category)))
    .value!;

DischargeFreshnessCriterion? _selectedFreshness(WidgetTester tester) => tester
    .widget<RadioGroup<DischargeFreshnessCriterion>>(
      find.byType(RadioGroup<DischargeFreshnessCriterion>),
    )
    .groupValue;

String? _selectedDepartement(WidgetTester tester) => tester
    .widget<DropdownButton<String>>(find.byKey(mapFilterDepartementKey))
    .value;

void main() {
  group('textes approuvés (cadrage de T3, § 10.1 (b))', () {
    test('au mot', () {
      expect(mapFilterSheetTitle, 'Filtres');
      expect(mapFilterApplyLabel, 'Appliquer');
      expect(mapFilterClearLabel, 'Effacer');
      expect(mapFilterAllDepartementsLabel, 'Tous les départements');
      expect(
        mapFilterDepartementsUnreadableText,
        "La liste des départements n'a pas pu être lue.",
      );
      expect(mapFilterFreshnessLoadedOnlyText, _loadedOnlyText);
      expect(mapFilterFreshnessClustersText, _clustersText);
      expect(mapFilterFlowWindowText, _flowWindowText);
      expect(warningReviewCloseLabel, 'Fermer');
    });
  });

  // `L1` de T4 (2026-10-15) : sur la lecture Crues, la feuille n'offre aucun
  // critère — masquer un niveau publié cacherait une vigilance émise
  // (cadrage de T4, § 7.7) — et le dit, par le texte du § 12.2.
  group('MapFilterSheet — vigilance crues (L1 de T4)', () {
    test('le texte du cadrage de T4, § 12.2, au mot', () {
      expect(
        mapFilterFloodNoCriterionText,
        "Aucun filtre ne s'applique à la lecture Vigilance crues.",
      );
    });

    testWidgetsOnWindows(
      'la phrase, aucune case, aucun choix, ni « Appliquer » ni « Effacer »',
      (WidgetTester tester) async {
        await _open(
          tester,
          scale: MapScaleKind.crues,
          initialFilter: const MapFilter(
            assec: false,
            departementCode: '41',
            dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
          ),
        );

        expect(find.text('Filtres'), findsOneWidget);
        expect(
          find.text(mapFilterFloodNoCriterionText, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.byType(CheckboxListTile, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byType(
            RadioListTile<DischargeFreshnessCriterion>,
            skipOffstage: false,
          ),
          findsNothing,
        );
        expect(
          find.byKey(mapFilterDepartementKey, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byKey(mapFilterApplyKey, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.byKey(mapFilterClearKey, skipOffstage: false),
          findsNothing,
        );
        final List<String> texts = _sheetTexts(tester);
        expect(texts, isNot(contains(mapFilterApplyLabel)));
        expect(texts, isNot(contains(mapFilterClearLabel)));
      },
    );

    testWidgetsOnWindows(
      'la feuille se ferme comme aujourd\'hui, sans rien appliquer',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.crues,
        );

        await _tap(tester, find.byKey(mapFilterCloseKey));

        expect(find.byKey(mapFilterSheetKey), findsNothing);
        expect(applied, isEmpty);
      },
    );
  });

  group('MapFilterSheet — écoulement', () {
    testWidgetsOnWindows(
      'sans filtre : titre, six cases cochées dans l\'ordre, tous les '
      'départements, la phrase des 60 jours, aucune fraîcheur',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.ecoulement);

        expect(find.text('Filtres'), findsOneWidget);
        expect(find.text('États'), findsOneWidget);
        expect(find.text('Département'), findsOneWidget);

        final List<CheckboxListTile> tiles = tester
            .widgetList<CheckboxListTile>(
              find.byType(CheckboxListTile, skipOffstage: false),
            )
            .toList();
        expect(
          <String?>[
            for (final CheckboxListTile tile in tiles)
              (tile.title! as Text).data,
          ],
          <String>[
            'Eau qui coule',
            'Écoulement faible',
            'Eau stagnante',
            'À sec',
            'Non observé',
            'Non renseigné',
          ],
        );
        expect(
          tiles.every((CheckboxListTile tile) => tile.value == true),
          isTrue,
        );

        expect(_selectedDepartement(tester), '');
        expect(
          find.text('Tous les départements', skipOffstage: false),
          findsOneWidget,
        );

        expect(find.text(_flowWindowText, skipOffstage: false), findsOneWidget);
        expect(
          find.byType(
            RadioListTile<DischargeFreshnessCriterion>,
            skipOffstage: false,
          ),
          findsNothing,
        );
        expect(find.text('Fraîcheur', skipOffstage: false), findsNothing);
        expect(find.text(_loadedOnlyText, skipOffstage: false), findsNothing);
        expect(find.text(_clustersText, skipOffstage: false), findsNothing);
      },
    );

    testWidgetsOnWindows('le filtre appliqué est reflété : « À sec » décochée, '
        'département 41', (WidgetTester tester) async {
      await _open(
        tester,
        scale: MapScaleKind.ecoulement,
        initialFilter: const MapFilter(assec: false, departementCode: '41'),
        departements: const <AdministrativeArea>[
          AdministrativeArea(code: '41', label: 'LOIR-ET-CHER'),
        ],
      );

      expect(_checked(tester, const Assec()), isFalse);
      expect(_checked(tester, const Ecoulement()), isTrue);
      expect(_selectedDepartement(tester), '41');
      expect(find.text('LOIR-ET-CHER (41)'), findsOneWidget);
    });

    testWidgetsOnWindows(
      'décocher « À sec » puis « Appliquer » : onApply une fois, feuille '
      'fermée',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.ecoulement,
        );

        await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
        expect(_checked(tester, const Assec()), isFalse);
        expect(applied, isEmpty);
        await _tap(tester, find.byKey(mapFilterApplyKey));

        expect(applied, <MapFilter>[
          MapFilter.none.withCategory(const Assec(), shown: false),
        ]);
        expect(find.byKey(mapFilterSheetKey), findsNothing);
      },
    );

    testWidgetsOnWindows('décocher « Non renseigné » rend inconnu: false', (
      WidgetTester tester,
    ) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.ecoulement,
      );

      await _tap(tester, find.byKey(mapFilterCategoryKey(const Inconnu(null))));
      await _tap(tester, find.byKey(mapFilterApplyKey));

      expect(applied, hasLength(1));
      expect(applied.single.inconnu, isFalse);
      expect(applied.single, const MapFilter(inconnu: false));
    });

    testWidgetsOnWindows(
      'choisir « LOIR-ET-CHER (41) » rend le code 41 ; revenir à « Tous les '
      'départements » rend null',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.ecoulement,
        );

        await _chooseDepartement(tester, 'LOIR-ET-CHER (41)');
        expect(_selectedDepartement(tester), '41');
        await _chooseDepartement(tester, 'Tous les départements');
        expect(_selectedDepartement(tester), '');
        await _chooseDepartement(tester, 'LOIR-ET-CHER (41)');
        await _tap(tester, find.byKey(mapFilterApplyKey));
        expect(applied.single.departementCode, '41');

        await tester.tap(find.byKey(_openKey));
        await tester.pumpAndSettle();
        await _chooseDepartement(tester, 'DORDOGNE (24)');
        await _chooseDepartement(tester, 'Tous les départements');
        await _tap(tester, find.byKey(mapFilterApplyKey));
        expect(applied, hasLength(2));
        expect(applied.last.departementCode, isNull);
      },
    );
  });

  group('MapFilterSheet — débit', () {
    testWidgetsOnWindows(
      'sans filtre : aucun état, trois choix de fraîcheur, « Toutes » '
      'sélectionné, les deux phrases dans l\'ordre',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.debit);

        expect(find.text('Filtres'), findsOneWidget);
        expect(
          find.byType(CheckboxListTile, skipOffstage: false),
          findsNothing,
        );
        expect(find.text('États', skipOffstage: false), findsNothing);
        expect(find.text('Département'), findsOneWidget);
        expect(find.text('Fraîcheur'), findsOneWidget);

        final List<RadioListTile<DischargeFreshnessCriterion>> choices = tester
            .widgetList<RadioListTile<DischargeFreshnessCriterion>>(
              find.byType(
                RadioListTile<DischargeFreshnessCriterion>,
                skipOffstage: false,
              ),
            )
            .toList();
        expect(
          <String?>[
            for (final RadioListTile<DischargeFreshnessCriterion> choice
                in choices)
              (choice.title! as Text).data,
          ],
          <String>['Toutes', 'Moins de 2 h', 'Moins de 24 h'],
        );
        expect(_selectedFreshness(tester), DischargeFreshnessCriterion.toutes);

        final Finder first = find.text(_loadedOnlyText, skipOffstage: false);
        final Finder second = find.text(_clustersText, skipOffstage: false);
        expect(first, findsOneWidget);
        expect(second, findsOneWidget);
        final double lastChoiceBottom = tester
            .getBottomLeft(
              find.byKey(
                mapFilterFreshnessKey(DischargeFreshnessCriterion.moinsDe24h),
                skipOffstage: false,
              ),
            )
            .dy;
        expect(tester.getTopLeft(first).dy, greaterThan(lastChoiceBottom - 1));
        expect(
          tester.getTopLeft(second).dy,
          greaterThan(tester.getTopLeft(first).dy),
        );

        expect(find.text(_flowWindowText, skipOffstage: false), findsNothing);
      },
    );

    testWidgetsOnWindows('le filtre appliqué est reflété : « Moins de 2 h » '
        'sélectionné', (WidgetTester tester) async {
      await _open(
        tester,
        scale: MapScaleKind.debit,
        initialFilter: const MapFilter(
          dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
        ),
      );

      expect(_selectedFreshness(tester), DischargeFreshnessCriterion.moinsDe2h);
    });

    testWidgetsOnWindows('choisir « Moins de 24 h » rend moinsDe24h', (
      WidgetTester tester,
    ) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.debit,
      );

      await _tap(
        tester,
        find.byKey(
          mapFilterFreshnessKey(DischargeFreshnessCriterion.moinsDe24h),
        ),
      );
      await _tap(tester, find.byKey(mapFilterApplyKey));

      expect(applied, const <MapFilter>[
        MapFilter(dischargeFreshness: DischargeFreshnessCriterion.moinsDe24h),
      ]);
    });

    testWidgetsOnWindows(
      'les critères de l\'autre échelle survivent : une case décochée reste '
      'décochée après un choix de département sur le débit',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.debit,
          initialFilter: const MapFilter(
            assec: false,
            dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
          ),
        );

        await _chooseDepartement(tester, 'LOIR-ET-CHER (41)');
        await _tap(tester, find.byKey(mapFilterApplyKey));

        expect(applied, const <MapFilter>[
          MapFilter(
            assec: false,
            departementCode: '41',
            dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
          ),
        ]);
        expect(applied.single.assec, isFalse);
      },
    );
  });

  group('MapFilterSheet — toutes les échelles', () {
    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgetsOnWindows(
        '${scale.name} : aucune échelle n\'est proposée dans la feuille',
        (WidgetTester tester) async {
          await _open(tester, scale: scale);

          final List<String> texts = _sheetTexts(tester);
          expect(texts, isNot(contains('Échelle affichée')));
          for (final MapScaleKind kind in MapScaleKind.values) {
            // Égalité, non inclusion : « Écoulement faible » est un état.
            expect(texts, isNot(contains(mapScaleLabel(kind))));
          }
          expect(texts.any((String text) => text.contains('Échelle')), isFalse);
        },
      );
    }
  });

  group('MapFilterSheet — les deux échelles à critères', () {
    // `L1` de T4 (2026-10-15) : restreinte à l'écoulement et au débit — la
    // lecture Crues n'offre ni « Appliquer » ni « Effacer » (groupe
    // « vigilance crues » plus haut) ; `K1` reprend les boucles de la feuille.
    for (final MapScaleKind scale in const <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
    ]) {
      testWidgetsOnWindows(
        '${scale.name} : « Appliquer » sans compteur, aucun mot qui qualifie '
        'un débit',
        (WidgetTester tester) async {
          await _open(
            tester,
            scale: scale,
            initialFilter: const MapFilter(departementCode: '99'),
          );

          final List<String> texts = _sheetTexts(tester);
          expect(texts, contains('Appliquer'));
          expect(texts, isNotEmpty);
          for (final String word in forbiddenFlowWords) {
            final RegExp pattern = RegExp(
              '(?<!\\p{L})${RegExp.escape(word)}(?!\\p{L})',
              caseSensitive: false,
              unicode: true,
            );
            for (final String text in texts) {
              expect(
                pattern.hasMatch(text),
                isFalse,
                reason: '« $text » contient « $word »',
              );
            }
          }
        },
      );

      testWidgetsOnWindows(
        '${scale.name} : « Effacer » applique MapFilter.none une fois et ferme',
        (WidgetTester tester) async {
          final List<MapFilter> applied = await _open(
            tester,
            scale: scale,
            initialFilter: const MapFilter(
              assec: false,
              departementCode: '41',
              dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
            ),
          );

          await _tap(tester, find.byKey(mapFilterClearKey));

          expect(applied, const <MapFilter>[MapFilter.none]);
          expect(find.byKey(mapFilterSheetKey), findsNothing);
        },
      );
    }
  });

  group('MapFilterSheet — fermer sans appliquer', () {
    Future<List<MapFilter>> openAndUncheck(WidgetTester tester) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.ecoulement,
      );
      await _tap(tester, find.byKey(mapFilterCategoryKey(const Ecoulement())));
      expect(_checked(tester, const Ecoulement()), isFalse);
      return applied;
    }

    testWidgetsOnWindows('par « Fermer »', (WidgetTester tester) async {
      final List<MapFilter> applied = await openAndUncheck(tester);

      await _tap(tester, find.byKey(mapFilterCloseKey));

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(applied, isEmpty);
    });

    testWidgetsOnWindows('par la touche Échap', (WidgetTester tester) async {
      final List<MapFilter> applied = await openAndUncheck(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(applied, isEmpty);
    });

    testWidgetsOnWindows('par un tap hors de la feuille', (
      WidgetTester tester,
    ) async {
      final List<MapFilter> applied = await openAndUncheck(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(applied, isEmpty);
    });

    testWidgetsOnAndroid('Android : par le retour du téléphone', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final List<MapFilter> applied = await openAndUncheck(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(applied, isEmpty);
    });

    testWidgetsOnWindows('rouvrir après « Fermer » : le brouillon abandonné '
        'ne revient pas', (WidgetTester tester) async {
      await openAndUncheck(tester);
      await _tap(tester, find.byKey(mapFilterCloseKey));

      await tester.tap(find.byKey(_openKey));
      await tester.pumpAndSettle();

      expect(_checked(tester, const Ecoulement()), isTrue);
    });
  });

  group('MapFilterSheet — « Fermer »', () {
    testWidgetsOnWindows('un bouton, annoncé « Fermer »', (
      WidgetTester tester,
    ) async {
      await _open(tester, scale: MapScaleKind.ecoulement);
      await tester.ensureVisible(find.byKey(mapFilterCloseKey));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(mapFilterCloseKey)),
        matchesSemantics(
          label: warningReviewCloseLabel,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.text(warningReviewCloseLabel), findsOneWidget);
    });

    for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      testWidgetsOnWindows(
        '${key == LogicalKeyboardKey.space ? 'Espace' : 'Entrée'}, bouton '
        'focalisé, ferme sans appliquer',
        (WidgetTester tester) async {
          final List<MapFilter> applied = await _open(
            tester,
            scale: MapScaleKind.ecoulement,
          );
          await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
          await _tabTo(tester, mapFilterCloseKey);

          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();

          expect(find.byKey(mapFilterSheetKey), findsNothing);
          expect(applied, isEmpty);
        },
      );
    }
  });

  group('MapFilterSheet — liste des départements', () {
    testWidgetsOnWindows(
      'illisible : la phrase, aucun sélecteur, les autres critères restent',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.ecoulement,
          initialFilter: const MapFilter(departementCode: '41'),
          departements: null,
        );

        expect(
          find.text(
            "La liste des départements n'a pas pu être lue.",
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(
          find.byType(DropdownButton<String>, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Tous les départements', skipOffstage: false),
          findsNothing,
        );

        await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
        await _tap(tester, find.byKey(mapFilterApplyKey));

        expect(applied, const <MapFilter>[
          MapFilter(assec: false, departementCode: '41'),
        ]);
      },
    );

    testWidgetsOnWindows('vide : le sélecteur n\'offre que « Tous les '
        'départements »', (WidgetTester tester) async {
      await _open(
        tester,
        scale: MapScaleKind.debit,
        departements: const <AdministrativeArea>[],
      );

      final DropdownButton<String> selector = tester
          .widget<DropdownButton<String>>(find.byKey(mapFilterDepartementKey));
      expect(selector.items, hasLength(1));
      expect(selector.items!.single.value, '');
      expect(selector.value, '');
      expect(find.text('Tous les départements'), findsOneWidget);
    });

    testWidgetsOnWindows(
      'code appliqué absent de la liste : une option de secours à son code, '
      'sélectionnée, sans exception',
      (WidgetTester tester) async {
        final List<MapFilter> applied = await _open(
          tester,
          scale: MapScaleKind.debit,
          initialFilter: const MapFilter(departementCode: '99'),
        );

        expect(tester.takeException(), isNull);
        final DropdownButton<String> selector = tester
            .widget<DropdownButton<String>>(
              find.byKey(mapFilterDepartementKey),
            );
        expect(selector.value, '99');
        expect(selector.items, hasLength(_departements.length + 2));
        expect(find.text('99'), findsOneWidget);

        await _tap(tester, find.byKey(mapFilterApplyKey));
        expect(applied.single.departementCode, '99');
      },
    );
  });

  group('MapFilterSheet — cibles', () {
    // `L1` de T4 (2026-10-15) : restreinte à l'écoulement et au débit — les
    // cibles mesurées sont des critères et « Appliquer »/« Effacer », absents
    // de la lecture Crues ; `K1` reprend les boucles de la feuille.
    for (final MapScaleKind scale in const <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
    ]) {
      testWidgetsOnWindows('${scale.name} : chaque contrôle fait au moins 44 '
          'de haut', (WidgetTester tester) async {
        await _open(tester, scale: scale);

        final List<Finder> all = _targets(scale);
        expect(all, hasLength(scale == MapScaleKind.ecoulement ? 10 : 7));
        for (final Finder target in all) {
          expect(target, findsOneWidget);
          expect(
            tester.getSize(target).height,
            greaterThanOrEqualTo(44),
            reason: '$target',
          );
        }
      });

      testWidgetsOnAndroid(
        'Android : ${scale.name}, chaque contrôle fait au moins 48 de haut',
        (WidgetTester tester) async {
          _phone(tester);
          await _open(tester, scale: scale);

          for (final Finder target in _targets(scale)) {
            expect(target, findsOneWidget);
            expect(
              tester.getSize(target).height,
              greaterThanOrEqualTo(48),
              reason: '$target',
            );
          }
        },
      );

      // Mesures de plancher : chaque contrôle est plus large que la cible.
      testWidgetsOnWindows('${scale.name} : chaque contrôle fait au moins 44 '
          'de large', (WidgetTester tester) async {
        await _open(tester, scale: scale);

        for (final Finder target in _targets(scale)) {
          expect(
            tester.getSize(target).width,
            greaterThanOrEqualTo(44),
            reason: '$target',
          );
        }
      });

      testWidgetsOnAndroid(
        'Android : ${scale.name}, chaque contrôle fait au moins 48 de large',
        (WidgetTester tester) async {
          _phone(tester);
          await _open(tester, scale: scale);

          for (final Finder target in _targets(scale)) {
            expect(
              tester.getSize(target).width,
              greaterThanOrEqualTo(48),
              reason: '$target',
            );
          }
        },
      );
    }
  });

  group('MapFilterSheet — largeur et action principale', () {
    testWidgetsOnWindows('fenêtre de 1 920 × 1 032 : la feuille ne dépasse pas '
        '560 de large', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(tester, scale: MapScaleKind.ecoulement);

      expect(tester.getSize(find.byKey(mapFilterSheetKey)).width, 560);
      final Rect sheet = tester.getRect(find.byKey(mapFilterSheetKey));
      expect(sheet.center.dx, 960);
    });

    testWidgetsOnAndroid('Android : à 360 de large, la feuille garde toute la '
        'largeur que la fenêtre lui laisse', (WidgetTester tester) async {
      _phone(tester);
      await _open(tester, scale: MapScaleKind.ecoulement);

      // 360 moins la marge de 40 que `Dialog` garde de chaque côté.
      expect(tester.getSize(find.byKey(mapFilterSheetKey)).width, 280);
    });

    testWidgetsOnWindows('chaque contrôle suit minimumTapTarget', (
      WidgetTester tester,
    ) async {
      await _open(tester, scale: MapScaleKind.debit);

      for (final Finder target in _targets(MapScaleKind.debit)) {
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(minimumTapTarget),
          reason: '$target',
        );
      }
    });

    testWidgetsOnWindows('« Appliquer » porte la couleur des actions '
        'principales, « Effacer » et « Fermer » non', (
      WidgetTester tester,
    ) async {
      await _open(tester, scale: MapScaleKind.debit);

      Finder filled(Key key) => find.descendant(
        of: find.byKey(key),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == primaryActionColor,
        ),
      );
      Color? textColor(Key key) => tester
          .widget<Text>(
            find.descendant(of: find.byKey(key), matching: find.byType(Text)),
          )
          .style
          ?.color;

      expect(filled(mapFilterApplyKey), findsOneWidget);
      expect(textColor(mapFilterApplyKey), onPrimaryActionColor);
      for (final Key secondary in <Key>[mapFilterClearKey, mapFilterCloseKey]) {
        expect(filled(secondary), findsNothing);
        expect(textColor(secondary), isNot(onPrimaryActionColor));
      }
    });
  });

  group('MapFilterSheet — clavier', () {
    testWidgetsOnWindows(
      'écoulement : Tab parcourt Effacer, les six cases, le département, '
      'Fermer, Appliquer — un arrêt chacun',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.ecoulement);

        expect(await _tabStops(tester, 11), <Key>[
          mapFilterClearKey,
          for (final FlowCategory category in filterableFlowCategories)
            mapFilterCategoryKey(category),
          mapFilterDepartementKey,
          mapFilterCloseKey,
          mapFilterApplyKey,
          // Le tour repart du premier contrôle : aucun arrêt de plus.
          mapFilterClearKey,
        ]);
      },
    );

    testWidgetsOnWindows(
      'débit : Tab parcourt Effacer, le département, le choix de fraîcheur '
      'sélectionné, Fermer, Appliquer ; les flèches parcourent les trois '
      'choix',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.debit);

        // `RadioGroup` (SDK) ne laisse à Tab que le choix sélectionné : les
        // deux autres s'atteignent aux flèches, qui les sélectionnent.
        expect(await _tabStops(tester, 6), <Key>[
          mapFilterClearKey,
          mapFilterDepartementKey,
          mapFilterFreshnessKey(DischargeFreshnessCriterion.toutes),
          mapFilterCloseKey,
          mapFilterApplyKey,
          mapFilterClearKey,
        ]);

        await _tabTo(
          tester,
          mapFilterFreshnessKey(DischargeFreshnessCriterion.toutes),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          _focusedKey(),
          mapFilterFreshnessKey(DischargeFreshnessCriterion.moinsDe2h),
        );
        expect(
          _selectedFreshness(tester),
          DischargeFreshnessCriterion.moinsDe2h,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          _focusedKey(),
          mapFilterFreshnessKey(DischargeFreshnessCriterion.moinsDe24h),
        );
        expect(
          _selectedFreshness(tester),
          DischargeFreshnessCriterion.moinsDe24h,
        );

        // Flèche haut : retour, choix par choix, focus et sélection ensemble.
        for (final DischargeFreshnessCriterion back
            in <DischargeFreshnessCriterion>[
              DischargeFreshnessCriterion.moinsDe2h,
              DischargeFreshnessCriterion.toutes,
            ]) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(_focusedKey(), mapFilterFreshnessKey(back));
          expect(_selectedFreshness(tester), back);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          _selectedFreshness(tester),
          DischargeFreshnessCriterion.moinsDe24h,
        );

        // Après le dernier choix, Tab passe à « Fermer ».
        await _pressTab(tester);
        expect(_focusedKey(), mapFilterCloseKey);
      },
    );

    testWidgetsOnWindows(
      'débit, « Moins de 24 h » déjà choisi : l\'arrêt de Tab du groupe est '
      'ce choix',
      (WidgetTester tester) async {
        await _open(
          tester,
          scale: MapScaleKind.debit,
          initialFilter: const MapFilter(
            dischargeFreshness: DischargeFreshnessCriterion.moinsDe24h,
          ),
        );

        expect(await _tabStops(tester, 6), <Key>[
          mapFilterClearKey,
          mapFilterDepartementKey,
          mapFilterFreshnessKey(DischargeFreshnessCriterion.moinsDe24h),
          mapFilterCloseKey,
          mapFilterApplyKey,
          mapFilterClearKey,
        ]);
      },
    );

    // `K1` de T3 : la liste des départements illisible (`departements: null`)
    // retire le sélecteur, et son arrêt seulement — l'ordre des autres ne
    // change pas.
    testWidgetsOnWindows(
      'écoulement, liste des départements illisible : aucun arrêt pour le '
      'département ; Effacer, les six cases, Fermer, Appliquer, puis le tour '
      'repart (K1 de T3)',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.ecoulement, departements: null);
        expect(find.byKey(mapFilterDepartementKey), findsNothing);

        expect(await _tabStops(tester, 10), <Key>[
          mapFilterClearKey,
          for (final FlowCategory category in filterableFlowCategories)
            mapFilterCategoryKey(category),
          mapFilterCloseKey,
          mapFilterApplyKey,
          mapFilterClearKey,
        ]);
      },
    );

    testWidgetsOnWindows(
      'débit, liste des départements illisible : aucun arrêt pour le '
      'département ; Effacer, le choix de fraîcheur sélectionné, Fermer, '
      'Appliquer, puis le tour repart (K1 de T3)',
      (WidgetTester tester) async {
        await _open(tester, scale: MapScaleKind.debit, departements: null);
        expect(find.byKey(mapFilterDepartementKey), findsNothing);

        expect(await _tabStops(tester, 5), <Key>[
          mapFilterClearKey,
          mapFilterFreshnessKey(DischargeFreshnessCriterion.toutes),
          mapFilterCloseKey,
          mapFilterApplyKey,
          mapFilterClearKey,
        ]);
      },
    );

    testWidgetsOnWindows('Espace bascule la case focalisée, et elle seule : '
        '« À sec », quatrième case', (WidgetTester tester) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.ecoulement,
      );

      await _tabTo(tester, mapFilterCategoryKey(const Assec()));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      for (final FlowCategory category in filterableFlowCategories) {
        expect(_checked(tester, category), category is! Assec);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_checked(tester, const Assec()), isTrue);
      expect(applied, isEmpty);
    });

    testWidgetsOnWindows('Espace bascule une case ; Entrée sur « Appliquer » '
        'appelle onApply', (WidgetTester tester) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.ecoulement,
      );

      await _tabTo(tester, mapFilterCategoryKey(const Ecoulement()));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_checked(tester, const Ecoulement()), isFalse);
      expect(applied, isEmpty);

      await _tabTo(tester, mapFilterApplyKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(applied, const <MapFilter>[MapFilter(ecoulement: false)]);
      expect(find.byKey(mapFilterSheetKey), findsNothing);
    });

    testWidgetsOnWindows('Entrée sur « Effacer » applique MapFilter.none', (
      WidgetTester tester,
    ) async {
      final List<MapFilter> applied = await _open(
        tester,
        scale: MapScaleKind.debit,
        initialFilter: const MapFilter(departementCode: '41'),
      );

      await _tabTo(tester, mapFilterClearKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(applied, const <MapFilter>[MapFilter.none]);
      expect(find.byKey(mapFilterSheetKey), findsNothing);
    });
  });

  group('MapFilterSheet — sémantique', () {
    testWidgetsOnWindows('chaque case annonce son libellé et son état', (
      WidgetTester tester,
    ) async {
      await _open(
        tester,
        scale: MapScaleKind.ecoulement,
        initialFilter: const MapFilter(assec: false),
      );

      for (final FlowCategory category in filterableFlowCategories) {
        final Finder tile = find.byKey(mapFilterCategoryKey(category));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(tile),
          isSemantics(
            label: flowCategoryLabel(category),
            hasCheckedState: true,
            isChecked: category is! Assec,
            hasTapAction: true,
          ),
          reason: flowCategoryLabel(category),
        );
      }
    });

    testWidgetsOnWindows('les trois choix de fraîcheur forment un groupe '
        'exclusif', (WidgetTester tester) async {
      await _open(
        tester,
        scale: MapScaleKind.debit,
        initialFilter: const MapFilter(
          dischargeFreshness: DischargeFreshnessCriterion.moinsDe24h,
        ),
      );

      expect(
        find.byType(RadioGroup<DischargeFreshnessCriterion>),
        findsOneWidget,
      );
      for (final DischargeFreshnessCriterion criterion
          in DischargeFreshnessCriterion.values) {
        final Finder choice = find.byKey(mapFilterFreshnessKey(criterion));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(choice),
          isSemantics(
            label: dischargeFreshnessCriterionLabel(criterion),
            hasCheckedState: true,
            isChecked: criterion == DischargeFreshnessCriterion.moinsDe24h,
            isInMutuallyExclusiveGroup: true,
          ),
          reason: criterion.name,
        );
      }
    });

    testWidgetsOnWindows('« Appliquer », « Effacer » et « Fermer » sont des '
        'boutons', (WidgetTester tester) async {
      await _open(tester, scale: MapScaleKind.debit);

      final Map<Key, String> buttons = <Key, String>{
        mapFilterClearKey: 'Effacer',
        mapFilterCloseKey: 'Fermer',
        mapFilterApplyKey: 'Appliquer',
      };
      for (final MapEntry<Key, String> button in buttons.entries) {
        await tester.ensureVisible(find.byKey(button.key));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(button.key)),
          matchesSemantics(
            label: button.value,
            isButton: true,
            hasTapAction: true,
          ),
          reason: button.value,
        );
      }
    });
  });

  group('MapFilterSheet — téléphone', () {
    // `L1` de T4 (2026-10-15) : restreinte à l'écoulement et au débit — le
    // cas mesure les libellés des critères et atteint « Appliquer », absents
    // de la lecture Crues ; `K1` reprend les boucles de la feuille.
    for (final MapScaleKind scale in const <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
    ]) {
      testWidgetsOnAndroid(
        'Android : ${scale.name}, 360 × 640, texte à 200 % — aucune '
        'exception de débordement, « Appliquer » atteint par défilement, '
        'aucune troncature posée sur les libellés',
        (WidgetTester tester) async {
          _phone(tester);
          final List<MapFilter> applied = await _open(
            tester,
            scale: scale,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);

          final List<String> labels = <String>[
            if (scale == MapScaleKind.ecoulement)
              for (final FlowCategory category in filterableFlowCategories)
                flowCategoryLabel(category),
            if (scale == MapScaleKind.debit)
              for (final DischargeFreshnessCriterion criterion
                  in DischargeFreshnessCriterion.values)
                dischargeFreshnessCriterionLabel(criterion),
          ];
          for (final String label in labels) {
            final Finder text = find.text(label, skipOffstage: false);
            expect(text, findsOneWidget, reason: label);
            final Text widget = tester.widget<Text>(text);
            expect(widget.maxLines, isNull, reason: label);
            expect(widget.overflow, isNull, reason: label);
            final RenderParagraph paragraph = tester.renderObject(
              find.descendant(
                of: text,
                matching: find.byType(RichText, skipOffstage: false),
                skipOffstage: false,
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            expect(paragraph.maxLines, isNull, reason: label);
          }

          // « Appliquer » est sous le pli : le défilement l'amène.
          final Finder apply = find.byKey(mapFilterApplyKey);
          expect(
            tester.getRect(apply).top,
            greaterThan(tester.view.physicalSize.height - 48),
          );
          await _tap(tester, apply);
          expect(tester.takeException(), isNull);
          expect(applied, const <MapFilter>[MapFilter.none]);
        },
      );
    }
  });
}

/// Les contrôles de la feuille pour [scale], dans l'ordre de construction.
List<Finder> _targets(MapScaleKind scale) => <Finder>[
  find.byKey(mapFilterClearKey, skipOffstage: false),
  if (scale == MapScaleKind.ecoulement)
    for (final FlowCategory category in filterableFlowCategories)
      find.byKey(mapFilterCategoryKey(category), skipOffstage: false),
  find.byKey(mapFilterDepartementKey, skipOffstage: false),
  if (scale == MapScaleKind.debit)
    for (final DischargeFreshnessCriterion criterion
        in DischargeFreshnessCriterion.values)
      find.byKey(mapFilterFreshnessKey(criterion), skipOffstage: false),
  find.byKey(mapFilterCloseKey, skipOffstage: false),
  find.byKey(mapFilterApplyKey, skipOffstage: false),
];

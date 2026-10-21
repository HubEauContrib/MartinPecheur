// Verrouille l'écran « Favoris » (`S9` de T3, cadrage § 5.4 et § 10.1) :
// identité seule de chaque lieu suivi, aucune valeur mesurée, retrait depuis
// la ligne, états vide et illisible dits, « Repartir d'une liste vide ».
//
// Les textes attendus sont écrits EN DUR dans ce fichier : comparer une
// constante à elle-même ne verrouillerait rien.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/favorites/view/favorites_screen.dart';
import 'package:martinpecheur/features/favorites/view_model/favorites_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../project/vocabulary_lists.dart';
import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/in_memory_favorite_repository.dart';
import '../../../support/windows_platform.dart';

const String _noMeasure =
    'Cette liste ne montre aucune mesure. La fiche d\'un lieu donne sa '
    'dernière mesure connue, avec sa date.';

const String _empty =
    'Aucun favori enregistré. L\'étoile d\'une fiche — station de mesure ou '
    'point d\'observation — ajoute ce lieu à cette liste.';

const String _unreadableList =
    'Les favoris enregistrés sur cet appareil n\'ont pas pu être lus. Ils '
    'sont conservés tels quels : aucun favori ne peut être ajouté ni retiré '
    'tant que la liste n\'est pas remplacée.';

const String _startOver = "Repartir d'une liste vide";

const String _startOverHint =
    'Les favoris enregistrés sur cet appareil seront effacés.';

const String _unreadableRow =
    "Favori non lisible par cette version de l'application";

const String _removeFailed = "Le favori n'a pas pu être retiré.";
const String _replaceFailed = "La liste n'a pas pu être remplacée.";
const String _addFailed = "Le favori n'a pas pu être enregistré.";

StationFavorite _station() => StationFavorite(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  addedAt: DateTime.utc(2026, 10, 11, 17, 5),
);

OndePointFavorite _onde() => OndePointFavorite(
  point: OndePoint(
    code: OndeStationCode('K4640001'),
    label: 'LA BONNEURE A MILLANCAY',
    latitude: 47.444182169,
    longitude: 1.78116675,
    waterCourseLabel: 'la Bonne Heure',
    departement: const AdministrativeArea(code: '41', label: '41'),
  ),
  addedAt: DateTime.utc(2026, 10, 12, 8, 30),
);

const UnreadableFavorite _unreadable = UnreadableFavorite(
  raw: '{"type":"point_designe"}',
  label: 'Chez moi',
);

Duration _noOffset(DateTime utcInstant) => Duration.zero;

Finder _row(int i) => find.byKey(ValueKey<String>('favorite-row-$i'));
Finder _remove(int i) => find.byKey(ValueKey<String>('favorite-remove-$i'));

/// La zone qui ouvre le favori de la ligne [i] : l'`InkWell` qui enveloppe son
/// libellé (celui de `_station()`), jamais celui de l'étoile de retrait.
Finder _openZone(int i) => find.ancestor(
  of: find.descendant(of: _row(i), matching: find.text(_station().label)),
  matching: find.byType(InkWell),
);

/// Réduit le texte à 25 % pour la durée du test.
void _tinyText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 0.25;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Ce que l'écran a rappelé.
final class _Calls {
  final List<Favorite> opened = <Favorite>[];
  final List<Favorite> removed = <Favorite>[];
  int startOvers = 0;
}

Widget _screen(
  FavoritesState state, {
  _Calls? calls,
  bool busy = false,
  bool writeFailed = false,
  UtcOffsetOf utcOffsetOf = _noOffset,
}) {
  final _Calls target = calls ?? _Calls();
  return FavoritesScreen(
    state: state,
    busy: busy,
    writeFailed: writeFailed,
    onOpen: target.opened.add,
    onRemove: target.removed.add,
    onStartOver: () => target.startOvers++,
    utcOffsetOf: utcOffsetOf,
  );
}

Widget _app(
  FavoritesState state, {
  _Calls? calls,
  bool busy = false,
  bool writeFailed = false,
  UtcOffsetOf utcOffsetOf = _noOffset,
}) => MaterialApp(
  home: _screen(
    state,
    calls: calls,
    busy: busy,
    writeFailed: writeFailed,
    utcOffsetOf: utcOffsetOf,
  ),
);

/// Tous les textes rendus sous l'écran.
List<String> _renderedTexts(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(FavoritesScreen),
      matching: find.byType(Text),
    ),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

Future<void> _tabUntilInside(WidgetTester tester, Finder target) async {
  for (int press = 0; press < 20; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        find
            .descendant(of: target, matching: find.byWidget(focused.widget))
            .evaluate()
            .isNotEmpty) {
      return;
    }
  }
  fail("Tab n'a jamais atteint la cible");
}

void main() {
  group('FavoritesScreen — textes (cadrage § 10.1)', () {
    test('les constantes sont celles du cadrage, mot pour mot', () {
      expect(favoritesScreenTitle, 'Favoris');
      expect(favoritesNoMeasureNotice, _noMeasure);
      expect(favoritesEmptyText, _empty);
      expect(favoritesUnreadableText, _unreadableList);
      expect(favoritesStartOverLabel, _startOver);
      expect(favoritesStartOverHint, _startOverHint);
      expect(unreadableFavoriteText, _unreadableRow);
      expect(stationFavoriteKind, 'Station hydrométrique');
      expect(ondeFavoriteKind, 'Point ONDE');
      expect(favoriteAddedOnPrefix, 'Ajouté le ');
      expect(favoritesReplaceFailedText, _replaceFailed);
      expect(favoritesStartOverButtonKey, const Key('favorites-start-over'));
      // Arbitrage du commanditaire du 2026-10-14.
      expect(removeNamedFavoritePrefix, 'Retirer des favoris : ');
      expect(removeUnreadableFavoriteLabel, 'Retirer ce favori non lisible');
    });
  });

  group('FavoritesScreen — la liste (critères 1 et 7)', () {
    testWidgetsOnWindows(
      "chaque ligne porte l'identité du lieu, dans l'ordre de la liste, "
      "sous l'avis « aucune mesure »",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station()])),
        );

        final List<Finder> inOrder = <Finder>[
          find.text(_noMeasure),
          find.text('LA BONNEURE A MILLANCAY'),
          find.text('Point ONDE'),
          find.text('la Bonne Heure'),
          find.text('Département 41'),
          find.text('Ajouté le 12/10/2026'),
          find.text('La Loire à Blois'),
          find.text('Station hydrométrique'),
          find.text('Ajouté le 11/10/2026'),
        ];
        for (final Finder finder in inOrder) {
          expect(finder, findsOneWidget);
        }
        for (int i = 1; i < inOrder.length; i++) {
          expect(
            _top(tester, inOrder[i]),
            greaterThan(_top(tester, inOrder[i - 1])),
            reason: 'élément $i',
          );
        }
        expect(
          _top(tester, find.text(_noMeasure)),
          lessThan(_top(tester, _row(0))),
        );
        expect(_top(tester, _row(0)), lessThan(_top(tester, _row(1))));
        expect(
          find.descendant(
            of: _row(0),
            matching: find.text('LA BONNEURE A MILLANCAY'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _row(1), matching: find.text('La Loire à Blois')),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows(
      "aucune mesure : ni unité, ni débit, ni hauteur, ni libellé d'état "
      "d'écoulement",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station(), _unreadable])),
        );

        final List<String> texts = _renderedTexts(tester);
        // Tout ce que l'écran écrit, et rien d'autre : l'identité seule.
        expect(texts, <String>[
          'Favoris',
          _noMeasure,
          'LA BONNEURE A MILLANCAY',
          'Point ONDE',
          'la Bonne Heure',
          'Département 41',
          'Ajouté le 12/10/2026',
          'La Loire à Blois',
          'Station hydrométrique',
          'Ajouté le 11/10/2026',
          'Chez moi',
          _unreadableRow,
        ]);
        final List<String> absent = <String>[
          'm³/s',
          'l/s',
          'mesuré',
          'Débit',
          'Hauteur',
          for (final FlowCategory category in const <FlowCategory>[
            Ecoulement(),
            EcoulementFaible(),
            EcoulementNonVisible(),
            Assec(),
            NonObserve(),
            Inconnu(null),
          ])
            flowCategoryLabel(category),
        ];
        for (final String text in texts) {
          for (final String word in absent) {
            expect(text, isNot(contains(word)), reason: '« $word »');
          }
        }
      },
    );

    testWidgetsOnWindows(
      "la date d'ajout est le jour LOCAL : 22:30 UTC à UTC+2 est le lendemain",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(
            FavorisLus(<Favorite>[
              StationFavorite(
                code: StationCode('K447001001'),
                label: 'La Loire à Blois',
                addedAt: DateTime.utc(2026, 10, 12, 22, 30),
              ),
            ]),
            utcOffsetOf: (DateTime utcInstant) => const Duration(hours: 2),
          ),
        );

        expect(find.text('Ajouté le 13/10/2026'), findsOneWidget);
        expect(find.text('Ajouté le 12/10/2026'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      "un point ONDE sans cours d'eau ni département : ni « Département », "
      'ni ligne vide',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(
            FavorisLus(<Favorite>[
              OndePointFavorite(
                point: OndePoint(
                  code: OndeStationCode('K4640001'),
                  label: 'LA BONNEURE A MILLANCAY',
                  latitude: 47.444182169,
                  longitude: 1.78116675,
                  waterCourseLabel: null,
                  departement: null,
                ),
                addedAt: DateTime.utc(2026, 10, 12, 8, 30),
              ),
            ]),
          ),
        );

        final List<String> rowTexts = <String>[
          for (final Text text in tester.widgetList<Text>(
            find.descendant(of: _row(0), matching: find.byType(Text)),
          ))
            text.data ?? '',
        ];
        expect(rowTexts, <String>[
          'LA BONNEURE A MILLANCAY',
          'Point ONDE',
          'Ajouté le 12/10/2026',
        ]);
        expect(find.textContaining('Département'), findsNothing);
      },
    );
  });

  group('FavoritesScreen — ouvrir et retirer', () {
    testWidgetsOnWindows('un tap sur la ligne de la station rappelle onOpen '
        'avec CE favori', (WidgetTester tester) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _app(FavorisLus(<Favorite>[_onde(), _station()]), calls: calls),
      );

      await tester.tap(_row(1));
      await tester.pump();

      expect(calls.opened, <Favorite>[_station()]);
      expect(calls.opened.single, isA<StationFavorite>());
      expect(calls.removed, isEmpty);
    });

    testWidgetsOnWindows("Tab jusqu'à la ligne puis Entrée, puis Espace : "
        'onOpen à chaque fois', (WidgetTester tester) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _app(FavorisLus(<Favorite>[_onde(), _station()]), calls: calls),
      );
      await tester.pumpAndSettle();

      // Deux arrêts par ligne : la ligne, puis son retrait. La ligne de la
      // station est le quatrième arrêt après le retour.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retour
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // ligne 0
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retrait 0
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // ligne 1
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls.opened, <Favorite>[_station()]);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls.opened, <Favorite>[_station(), _station()]);
      expect(calls.removed, isEmpty);
    });

    testWidgetsOnWindows('un tap sur le bouton de retrait rappelle onRemove, '
        'jamais onOpen ; il est annoncé « Retirer des favoris : » suivi du '
        'nom du lieu', (WidgetTester tester) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _app(FavorisLus(<Favorite>[_onde(), _station()]), calls: calls),
      );

      expect(
        tester.getSemantics(
          find.descendant(
            of: _remove(1),
            matching: find.byKey(favoriteStarButtonKey),
          ),
        ),
        matchesSemantics(
          label: 'Retirer des favoris : La Loire à Blois',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(_remove(1));
      await tester.pump();

      expect(calls.removed, <Favorite>[_station()]);
      expect(calls.opened, isEmpty);
    });

    testWidgetsOnWindows("Tab jusqu'au retrait puis Entrée : onRemove", (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _app(FavorisLus(<Favorite>[_station()]), calls: calls),
      );
      await tester.pumpAndSettle();

      await _tabUntilInside(tester, _remove(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(calls.removed, <Favorite>[_station()]);
      expect(calls.opened, isEmpty);
    });

    // `K1` de T3 : l'ordre nommé arrêt par arrêt. La ligne porte son retrait :
    // l'arrêt « ligne » est sous la ligne ET hors de son retrait.
    testWidgetsOnWindows(
      'deux favoris : Tab atteint le retour, la ligne 0, son retrait, la '
      'ligne 1, son retrait, puis le tour repart sur le retour ; le focus de '
      "l'écran n'est jamais un arrêt (K1 de T3)",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station()])),
        );
        await tester.pumpAndSettle();
        // À l'ouverture, le focus est celui de l'écran (`autofocus`), sauté
        // par Tab (`skipTraversal`).
        expect(FocusManager.instance.primaryFocus?.skipTraversal, isTrue);

        final Finder retour = find.byType(BackButton);
        // (arrêt, ce qui le porte, ce qui ne doit pas le porter)
        final List<(String, Finder, Finder?)> arrets =
            <(String, Finder, Finder?)>[
              ('retour', retour, null),
              ('ligne 0', _row(0), _remove(0)),
              ('retrait 0', _remove(0), null),
              ('ligne 1', _row(1), _remove(1)),
              ('retrait 1', _remove(1), null),
              ('retour, le tour repart', retour, null),
            ];
        for (final (String, Finder, Finder?) arret in arrets) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            focusedWithin(tester, arret.$2),
            isTrue,
            reason: 'attendu à ce Tab : ${arret.$1}',
          );
          final Finder? hors = arret.$3;
          if (hors != null) {
            expect(
              focusedWithin(tester, hors),
              isFalse,
              reason: '${arret.$1} : le focus est sur le retrait',
            );
          }
          expect(
            FocusManager.instance.primaryFocus?.skipTraversal,
            isFalse,
            reason: '${arret.$1} : le focus de l’écran n’est pas un arrêt',
          );
        }
      },
    );

    testWidgetsOnWindows('le bouton de retrait mesure 44 × 44', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      expect(minimumTapTarget, 44);
      expect(tester.getSize(_remove(0)), const Size(44, 44));
    });

    testWidgetsOnAndroid('Android : le bouton de retrait mesure 48 × 48', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      expect(minimumTapTarget, 48);
      expect(tester.getSize(_remove(0)), const Size(48, 48));
    });

    // Mesure de plancher de la zone qui ouvre le favori (son `InkWell`), non
    // de la rangée : la hauteur de la rangée vient de l'étoile et du texte,
    // elle ne dit rien de la zone qui reçoit le tap d'ouverture. Trois lignes
    // de texte tiennent déjà cette zone au-dessus de la cible : le texte est
    // réduit à 25 %, seul cas où sa hauteur minimale agit.
    testWidgetsOnWindows('la zone qui ouvre la ligne mesure au moins 44 de '
        'haut, même à texte réduit', (WidgetTester tester) async {
      _tinyText(tester);
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      expect(_openZone(0), findsOneWidget);
      expect(tester.getSize(_openZone(0)).height, greaterThanOrEqualTo(44));
    });

    testWidgetsOnAndroid('Android : la zone qui ouvre la ligne mesure au '
        'moins 48 de haut, même à texte réduit', (WidgetTester tester) async {
      _tinyText(tester);
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      expect(_openZone(0), findsOneWidget);
      expect(tester.getSize(_openZone(0)).height, greaterThanOrEqualTo(48));
    });
  });

  // Arbitrage du commanditaire du 2026-10-14 (revue finale de T3) : sur cet
  // écran, le retrait nomme le lieu que sa ligne affiche. Les lignes se
  // suivent par rang : après un retrait au clavier, le focus reste au même
  // rang, sur le retrait du favori suivant, qui doit alors dire quel lieu il
  // retire. Les étoiles des fiches ne changent pas
  // (`test/features/shared/favorite_star_button_test.dart`).
  group('FavoritesScreen — le retrait nomme le lieu (arbitrage du '
      'commanditaire du 2026-10-14)', () {
    String removeLabel(WidgetTester tester, int i) => tester
        .getSemantics(
          find.descendant(
            of: _remove(i),
            matching: find.byKey(favoriteStarButtonKey),
          ),
        )
        .getSemanticsData()
        .label;

    testWidgetsOnWindows(
      "chaque retrait s'annonce « Retirer des favoris : » suivi du nom que "
      'sa ligne affiche, station comme point ONDE',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station()])),
        );

        expect(
          removeLabel(tester, 0),
          'Retirer des favoris : LA BONNEURE A MILLANCAY',
        );
        expect(
          removeLabel(tester, 1),
          'Retirer des favoris : La Loire à Blois',
        );
        expect(
          tester.getSemantics(
            find.descendant(
              of: _remove(0),
              matching: find.byKey(favoriteStarButtonKey),
            ),
          ),
          matchesSemantics(
            label: 'Retirer des favoris : LA BONNEURE A MILLANCAY',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      'deux stations de noms différents : deux annonces différentes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(
            FavorisLus(<Favorite>[
              StationFavorite(
                code: StationCode('K447001001'),
                label: 'La Loire à Blois',
                addedAt: DateTime.utc(2026, 10, 11, 17, 5),
              ),
              StationFavorite(
                code: StationCode('K447001002'),
                label: 'La Loire à Orléans',
                addedAt: DateTime.utc(2026, 10, 11, 17, 5),
              ),
            ]),
          ),
        );

        expect(
          removeLabel(tester, 0),
          'Retirer des favoris : La Loire à Blois',
        );
        expect(
          removeLabel(tester, 1),
          'Retirer des favoris : La Loire à Orléans',
        );
        expect(removeLabel(tester, 0), isNot(removeLabel(tester, 1)));
      },
    );

    testWidgetsOnWindows(
      "une entrée non lisible, avec ou sans libellé : « Retirer ce favori non "
      'lisible »',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(
            FavorisLus(const <Favorite>[
              _unreadable,
              UnreadableFavorite(raw: '{"type":"point_designe"}'),
            ]),
          ),
        );

        expect(removeLabel(tester, 0), 'Retirer ce favori non lisible');
        expect(removeLabel(tester, 1), 'Retirer ce favori non lisible');
      },
    );

    testWidgetsOnWindows(
      'après un retrait au clavier, le bouton qui garde le focus annonce le '
      'nom du favori suivant',
      (WidgetTester tester) async {
        final InMemoryFavoriteRepository repository =
            InMemoryFavoriteRepository(<Favorite>[_onde(), _station()]);
        final FavoritesViewModel viewModel = FavoritesViewModel(
          favorites: repository,
        );
        addTearDown(viewModel.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ListenableBuilder(
              listenable: viewModel,
              builder: (BuildContext context, Widget? child) => FavoritesScreen(
                state: viewModel.state,
                busy: viewModel.busy,
                writeFailed: viewModel.writeFailed,
                onOpen: (Favorite favorite) {},
                onRemove: viewModel.remove,
                onStartOver: viewModel.startOver,
                utcOffsetOf: _noOffset,
              ),
            ),
          ),
        );
        await viewModel.load();
        await tester.pumpAndSettle();

        // Le nœud sémantique du bouton qui porte le focus.
        String focusedLabel() {
          final BuildContext? focused =
              FocusManager.instance.primaryFocus?.context;
          expect(focused, isNotNull);
          return tester
              .getSemantics(
                find.byElementPredicate(
                  (Element element) => identical(element, focused),
                ),
              )
              .getSemanticsData()
              .label;
        }

        await _tabUntilInside(tester, _remove(0));
        expect(focusedLabel(), 'Retirer des favoris : LA BONNEURE A MILLANCAY');

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(repository.stored, <Favorite>[_station()]);
        expect(focusedWithin(tester, _remove(0)), isTrue);
        expect(focusedLabel(), 'Retirer des favoris : La Loire à Blois');
      },
    );
  });

  group('FavoritesScreen — entrée non lisible (critère 11)', () {
    testWidgetsOnWindows(
      'son libellé puis la mention ; ni date ; un tap sur la ligne ne '
      "l'ouvre jamais ; son retrait rappelle onRemove",
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(
          _app(FavorisLus(const <Favorite>[_unreadable]), calls: calls),
        );

        expect(find.text('Chez moi'), findsOneWidget);
        expect(find.text(_unreadableRow), findsOneWidget);
        expect(
          _top(tester, find.text('Chez moi')),
          lessThan(_top(tester, find.text(_unreadableRow))),
        );
        expect(find.textContaining('Ajouté le'), findsNothing);

        await tester.tap(_row(0), warnIfMissed: false);
        await tester.tap(find.text('Chez moi'), warnIfMissed: false);
        await tester.tap(find.text(_unreadableRow), warnIfMissed: false);
        await tester.pump();
        expect(calls.opened, isEmpty);

        await tester.tap(_remove(0));
        await tester.pump();
        expect(calls.removed, const <Favorite>[_unreadable]);
        expect(calls.opened, isEmpty);
      },
    );

    testWidgetsOnWindows(
      "au clavier : la ligne non lisible n'est pas un arrêt, seul son "
      "retrait l'est ; Entrée n'ouvre rien",
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(
          _app(FavorisLus(const <Favorite>[_unreadable]), calls: calls),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retour
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retrait 0
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(calls.opened, isEmpty);
        expect(calls.removed, const <Favorite>[_unreadable]);
      },
    );

    testWidgetsOnWindows('sans libellé : la mention seule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          FavorisLus(const <Favorite>[
            UnreadableFavorite(raw: '{"type":"point_designe"}'),
          ]),
        ),
      );

      final List<String> rowTexts = <String>[
        for (final Text text in tester.widgetList<Text>(
          find.descendant(of: _row(0), matching: find.byType(Text)),
        ))
          text.data ?? '',
      ];
      expect(rowTexts, <String>[_unreadableRow]);
    });
  });

  group('FavoritesScreen — états (critères 10 et 12)', () {
    testWidgetsOnWindows(
      'aucun favori : le texte exact, aucune ligne, aucun avis « aucune '
      "mesure », rien qui suggère un état des cours d'eau",
      (WidgetTester tester) async {
        await tester.pumpWidget(_app(const AucunFavori()));

        expect(find.text(_empty), findsOneWidget);
        expect(_row(0), findsNothing);
        expect(find.text(_noMeasure), findsNothing);
        expect(find.byKey(favoritesStartOverButtonKey), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final String all = _renderedTexts(tester).join('\n').toLowerCase();
        for (final String phrase in forbiddenNeutralityPhrases) {
          expect(all, isNot(contains(phrase)), reason: phrase);
        }
        expect(_renderedTexts(tester), <String>['Favoris', _empty]);
      },
    );

    testWidgetsOnWindows(
      "liste illisible : le texte exact, le bouton « Repartir d'une liste "
      'vide » et son sous-titre dessous ; un tap rappelle onStartOver ; '
      'aucune ligne, jamais le texte de la liste vide',
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(_app(const FavorisIllisibles(), calls: calls));

        expect(find.text(_unreadableList), findsOneWidget);
        expect(find.text(_startOver), findsOneWidget);
        expect(find.text(_startOverHint), findsOneWidget);
        final Finder button = find.byKey(favoritesStartOverButtonKey);
        expect(
          tester.getSize(button).height,
          greaterThanOrEqualTo(minimumTapTarget),
        );
        expect(
          find.descendant(of: button, matching: find.text(_startOver)),
          findsOneWidget,
        );
        expect(
          _top(tester, find.text(_unreadableList)),
          lessThan(_top(tester, button)),
        );
        expect(
          tester.getBottomLeft(button).dy,
          lessThanOrEqualTo(_top(tester, find.text(_startOverHint))),
        );
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            label: _startOver,
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        expect(_row(0), findsNothing);
        expect(find.text(_empty), findsNothing);
        expect(find.text(_noMeasure), findsNothing);

        await tester.tap(button);
        await tester.pump();
        expect(calls.startOvers, 1);

        await tester.pumpAndSettle();
        await _tabUntilInside(tester, button);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls.startOvers, 2);
      },
    );

    // La hauteur de « Repartir d'une liste vide » est mesurée plus haut
    // (Windows) et dans le groupe « téléphone » (Android) : ici, la largeur
    // seule, mesure de plancher.
    testWidgetsOnWindows("« Repartir d'une liste vide » mesure au moins 44 de "
        'large', (WidgetTester tester) async {
      await tester.pumpWidget(_app(const FavorisIllisibles()));

      expect(
        tester.getSize(find.byKey(favoritesStartOverButtonKey)).width,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgetsOnAndroid("Android : « Repartir d'une liste vide » mesure au "
        'moins 48 de large', (WidgetTester tester) async {
      await tester.pumpWidget(_app(const FavorisIllisibles()));

      expect(
        tester.getSize(find.byKey(favoritesStartOverButtonKey)).width,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgetsOnWindows('en lecture : un indicateur de progression, aucun '
        "texte d'état", (WidgetTester tester) async {
      await tester.pumpWidget(_app(const FavorisEnLecture()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_renderedTexts(tester), <String>['Favoris']);
      expect(_row(0), findsNothing);
      expect(find.byKey(favoritesStartOverButtonKey), findsNothing);
    });

    testWidgetsOnWindows('fermé : la barre de titre seule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const FavorisFermes()));

      expect(find.byType(ScreenTitleBar), findsOneWidget);
      expect(_renderedTexts(tester), <String>['Favoris']);
      expect(_row(0), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(favoritesStartOverButtonKey), findsNothing);
    });
  });

  group('FavoritesScreen — écriture en cours, écriture en échec', () {
    testWidgetsOnWindows(
      'busy : le retrait ne rappelle rien, ni au tap ni au clavier, et '
      "s'annonce indisponible ; la ligne s'ouvre toujours",
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_station()]), calls: calls, busy: true),
        );
        await tester.pumpAndSettle();

        await tester.tap(_remove(0));
        await tester.pump();
        await _tabUntilInside(tester, _remove(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(calls.removed, isEmpty);
        expect(
          tester.getSemantics(
            find.descendant(
              of: _remove(0),
              matching: find.byKey(favoriteStarButtonKey),
            ),
          ),
          matchesSemantics(
            label: 'Retirer des favoris : La Loire à Blois',
            isButton: true,
            hasEnabledState: true,
          ),
        );

        await tester.tap(_row(0));
        await tester.pump();
        expect(calls.opened, <Favorite>[_station()]);
      },
    );

    testWidgetsOnWindows(
      "busy : « Repartir d'une liste vide » ne rappelle rien, ni au tap ni "
      "au clavier, et s'annonce indisponible",
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(
          _app(const FavorisIllisibles(), calls: calls, busy: true),
        );
        await tester.pumpAndSettle();
        final Finder button = find.byKey(favoritesStartOverButtonKey);

        await tester.tap(button);
        await tester.pump();
        await _tabUntilInside(tester, button);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(calls.startOvers, 0);
        expect(
          tester.getSemantics(button),
          matchesSemantics(
            label: _startOver,
            isButton: true,
            hasEnabledState: true,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      "un retrait en échec : « Le favori n'a pas pu être retiré. », en tête, "
      'en région vivante',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_station()]), writeFailed: true),
        );

        final Finder notice = find.text(_removeFailed);
        expect(notice, findsOneWidget);
        expect(find.byType(FavoriteWriteFailedNotice), findsOneWidget);
        expect(
          tester
              .getSemantics(notice)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        expect(
          _top(tester, notice),
          lessThan(_top(tester, find.text(_noMeasure))),
        );
        expect(find.text(_replaceFailed), findsNothing);
        expect(find.text(_addFailed), findsNothing);
      },
    );

    testWidgetsOnWindows('un retrait en échec sur une liste devenue vide : la '
        'même phrase', (WidgetTester tester) async {
      await tester.pumpWidget(_app(const AucunFavori(), writeFailed: true));

      expect(find.text(_removeFailed), findsOneWidget);
      expect(find.text(_replaceFailed), findsNothing);
      expect(find.text(_addFailed), findsNothing);
    });

    testWidgetsOnWindows(
      "« Repartir d'une liste vide » en échec : « La liste n'a pas pu être "
      "remplacée. », en tête, et pas l'autre phrase",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(const FavorisIllisibles(), writeFailed: true),
        );

        final Finder notice = find.text(_replaceFailed);
        expect(notice, findsOneWidget);
        expect(
          _top(tester, notice),
          lessThan(_top(tester, find.text(_unreadableList))),
        );
        expect(find.text(_removeFailed), findsNothing);
        expect(find.text(_addFailed), findsNothing);
      },
    );

    testWidgetsOnWindows('sans échec : aucun avis, dans aucun état', (
      WidgetTester tester,
    ) async {
      for (final FavoritesState state in <FavoritesState>[
        const FavorisFermes(),
        const FavorisEnLecture(),
        const AucunFavori(),
        FavorisLus(<Favorite>[_station()]),
        const FavorisIllisibles(),
      ]) {
        await tester.pumpWidget(_app(state));
        expect(find.byType(FavoriteWriteFailedNotice), findsNothing);
      }
    });
  });

  group('FavoritesScreen — barre de titre, retour, défilement', () {
    test('le fichier ne construit ni bouton de retour ni barre '
        "d'application : la barre de titre est celle, partagée", () {
      final String source = File(
        'lib/features/favorites/view/favorites_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('BackButton(')));
      expect(source, isNot(contains('AppBar(')));
      expect(source, contains('ScreenTitleBar('));
    });

    testWidgetsOnWindows('un seul ScreenTitleBar, titre « Favoris » annoncé '
        'en en-tête', (WidgetTester tester) async {
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      expect(find.byType(ScreenTitleBar), findsOneWidget);
      expect(
        tester.widget<ScreenTitleBar>(find.byType(ScreenTitleBar)).title,
        'Favoris',
      );
      expect(
        tester
            .getSemantics(find.text('Favoris'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
    });

    Future<void> pushed(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          _screen(FavorisLus(<Favorite>[_station()])),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesScreen), findsOneWidget);
    }

    testWidgetsOnWindows('Échap retire la route', (WidgetTester tester) async {
      await pushed(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesScreen), findsNothing);
    });

    testWidgetsOnWindows('le bouton de retour retire la route', (
      WidgetTester tester,
    ) async {
      await pushed(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesScreen), findsNothing);
    });

    Future<void> wheel(WidgetTester tester, Offset at, double dy) async {
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(at));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pumpAndSettle();
    }

    testWidgetsOnWindows('30 favoris : la molette posée sur la barre de titre '
        'fait défiler la liste, dans les deux sens ; une seule barre de '
        'défilement, toujours visible', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          FavorisLus(<Favorite>[
            for (int i = 0; i < 30; i++)
              StationFavorite(
                code: StationCode('K4470010${i.toString().padLeft(2, '0')}'),
                label: 'Station $i',
                addedAt: DateTime.utc(2026, 10, 11, 17, 5),
              ),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      final ScrollableState scrollable = tester.state(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(100));
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isTrue,
      );
      final Offset title = tester.getCenter(find.text('Favoris'));

      await wheel(tester, title, 100);
      expect(scrollable.position.pixels, 100);

      await wheel(tester, title, -100);
      expect(scrollable.position.pixels, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgetsOnWindows('fenêtre large : le contenu reste dans la colonne de '
        'lecture, centrée', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(FavorisLus(<Favorite>[_station()])));

      final Rect row = tester.getRect(_row(0));
      expect(row.width, readingColumnWidth);
      expect(row.center.dx, 800);
    });
  });

  group(
    "FavoritesScreen — l'avis d'échec reste visible, hors du défilement",
    () {
      Rect noticeRect(WidgetTester tester, String text) =>
          tester.getRect(find.text(text));

      testWidgetsOnWindows(
        "liste longue défilée jusqu'en bas, un retrait échoue : l'avis est "
        'dans la fenêtre, sous la barre de titre ; la ligne et son étoile '
        'sont restées',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(800, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final InMemoryFavoriteRepository repository =
              InMemoryFavoriteRepository(<Favorite>[
                for (int i = 0; i < 30; i++)
                  StationFavorite(
                    code: StationCode(
                      'K4470010${i.toString().padLeft(2, '0')}',
                    ),
                    label: 'Station $i',
                    addedAt: DateTime.utc(2026, 10, 11, 17, 5),
                  ),
              ]);
          final FavoritesViewModel viewModel = FavoritesViewModel(
            favorites: repository,
          );
          addTearDown(viewModel.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: ListenableBuilder(
                listenable: viewModel,
                builder: (BuildContext context, Widget? child) =>
                    FavoritesScreen(
                      state: viewModel.state,
                      busy: viewModel.busy,
                      writeFailed: viewModel.writeFailed,
                      onOpen: (Favorite favorite) {},
                      onRemove: viewModel.remove,
                      onStartOver: viewModel.startOver,
                      utcOffsetOf: _noOffset,
                    ),
              ),
            ),
          );
          await viewModel.load();
          await tester.pumpAndSettle();
          final ScrollableState scrollable = tester.state(
            find.byType(Scrollable).first,
          );
          final double bottom = scrollable.position.maxScrollExtent;
          expect(bottom, greaterThan(740));
          scrollable.position.jumpTo(bottom);
          await tester.pumpAndSettle();
          expect(find.text(_removeFailed), findsNothing);

          repository.writeError = StateError('écriture refusée');
          await tester.tap(_remove(29));
          await tester.pumpAndSettle();

          expect(viewModel.writeFailed, isTrue);
          final Finder notice = find.text(_removeFailed);
          expect(notice, findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: notice,
            ),
            findsNothing,
          );
          final Rect rect = noticeRect(tester, _removeFailed);
          expect(
            rect.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(ScreenTitleBar)).bottom,
            ),
          );
          expect(rect.bottom, lessThanOrEqualTo(740));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(800));
          expect(
            rect.bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(Scrollbar)).top),
          );
          expect(
            tester
                .getSemantics(notice)
                .getSemanticsData()
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
          // La liste est intacte : la ligne, son étoile pleine, la position du
          // défilement (la zone défilante a seulement cédé la place de l'avis).
          expect(repository.stored, hasLength(30));
          expect(find.text('Station 29'), findsOneWidget);
          expect(
            find.descendant(of: _remove(29), matching: find.byIcon(Icons.star)),
            findsOneWidget,
          );
          expect(scrollable.position.pixels, bottom);
        },
      );

      testWidgetsOnWindows(
        "« Repartir d'une liste vide » en échec : l'avis est sous la barre de "
        'titre, hors du défilement',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _app(const FavorisIllisibles(), writeFailed: true),
          );

          final Finder notice = find.text(_replaceFailed);
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: notice,
            ),
            findsNothing,
          );
          expect(
            noticeRect(tester, _replaceFailed).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(ScreenTitleBar)).bottom,
            ),
          );
        },
      );

      testWidgetsOnAndroid(
        "Android : à 360 × 640 et 200 % de police, l'avis affiché, rien ne "
        "déborde et l'avis est entier dans la fenêtre",
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          for (final (FavoritesState state, String text)
              in <(FavoritesState, String)>[
                (
                  FavorisLus(<Favorite>[_onde(), _station(), _unreadable]),
                  _removeFailed,
                ),
                (const AucunFavori(), _removeFailed),
                (const FavorisIllisibles(), _replaceFailed),
              ]) {
            await tester.pumpWidget(_app(state, writeFailed: true));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: text);
            final Rect rect = noticeRect(tester, text);
            expect(
              rect.top,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(ScreenTitleBar)).bottom,
              ),
            );
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(360));
            expect(rect.bottom, lessThanOrEqualTo(640));
            // Il reste de quoi lire la liste sous l'avis.
            expect(
              tester.getSize(find.byType(SingleChildScrollView)).height,
              greaterThan(96),
            );
            final Text widget = tester.widget<Text>(find.text(text));
            expect(widget.maxLines, isNull);
            expect(widget.overflow, isNull);
          }
        },
      );
    },
  );

  group('FavoritesScreen — la ligne ouvrable, annoncée et focalisée', () {
    Color? ringColor(WidgetTester tester, Finder row) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find
                  .descendant(of: row, matching: find.byType(KeyboardFocusRing))
                  .first,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).border?.top.color;
    }

    testWidgetsOnWindows(
      'un seul nœud : bouton, action de tap, libellé fusionné des textes de '
      'la ligne',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station()])),
        );

        expect(
          tester.getSemantics(find.text('La Loire à Blois')),
          matchesSemantics(
            label:
                'La Loire à Blois\nStation hydrométrique\n'
                'Ajouté le 11/10/2026',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.text('LA BONNEURE A MILLANCAY')),
          matchesSemantics(
            label:
                'LA BONNEURE A MILLANCAY\nPoint ONDE\nla Bonne Heure\n'
                'Département 41\nAjouté le 12/10/2026',
            isButton: true,
            hasTapAction: true,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      "une entrée non lisible n'est pas annoncée en bouton",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(const <Favorite>[_unreadable])),
        );

        final SemanticsData data = tester
            .getSemantics(find.text(_unreadableRow))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      },
    );

    testWidgetsOnWindows(
      'Tab sur une ligne : son anneau de focus apparaît, et lui seul',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station()])),
        );
        await tester.pumpAndSettle();
        expect(ringColor(tester, _row(0)), Colors.transparent);
        expect(ringColor(tester, _row(1)), Colors.transparent);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retour
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // ligne 0
        await tester.pump();
        expect(ringColor(tester, _row(0)), focusRingColor);
        expect(ringColor(tester, _row(1)), Colors.transparent);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // retrait 0
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // ligne 1
        await tester.pump();
        expect(ringColor(tester, _row(0)), Colors.transparent);
        expect(ringColor(tester, _row(1)), focusRingColor);
      },
    );
  });

  group('FavoritesScreen — téléphone', () {
    testWidgetsOnAndroid(
      'Android : à 360 × 640 et 200 % de police, rien ne déborde',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const Rect viewport = Rect.fromLTWH(0, 0, 360, 640);

        void expectNothingTruncated() {
          for (final Text text in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(FavoritesScreen),
              matching: find.byType(Text),
            ),
          )) {
            expect(text.maxLines, isNull, reason: '${text.data}');
            expect(text.overflow, isNull, reason: '${text.data}');
          }
        }

        Future<void> expectWhole(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final Rect rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(viewport.left));
          expect(rect.right, lessThanOrEqualTo(viewport.right));
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        }

        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[_onde(), _station(), _unreadable])),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // L'échelle est bien appliquée : sans cela ce test ne dirait rien de
        // 200 %.
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(FavoritesScreen)))
              .scale(10),
          20,
        );
        expectNothingTruncated();
        expect(tester.getSize(_remove(0)), const Size(48, 48));
        await expectWhole(find.text(_unreadableRow));
        await expectWhole(_remove(2));

        await tester.pumpWidget(_app(const AucunFavori()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNothingTruncated();
        await expectWhole(find.text(_empty));

        await tester.pumpWidget(_app(const FavorisIllisibles()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNothingTruncated();
        await expectWhole(find.byKey(favoritesStartOverButtonKey));
        await expectWhole(find.text(_startOver));
        await expectWhole(find.text(_startOverHint));
      },
    );

    testWidgetsOnAndroid("Android : à 360 × 640, « Repartir d'une liste "
        'vide » mesure au moins 48 de haut', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const FavorisIllisibles()));

      expect(minimumTapTarget, 48);
      expect(
        tester.getSize(find.byKey(favoritesStartOverButtonKey)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FavoritesScreen — le favori tronçon (M1 de T5)', () {
    FloodSectionFavorite section() => FloodSectionFavorite(
      code: FloodSectionCode('LP106'),
      name: 'Loire amont',
      addedAt: DateTime.utc(2026, 10, 13, 9),
    );

    testWidgetsOnWindows(
      'la ligne porte le nom, « Tronçon Vigicrues » et « Ajouté le … »',
      (WidgetTester tester) async {
        await tester.pumpWidget(_app(FavorisLus(<Favorite>[section()])));

        expect(floodSectionFavoriteKind, 'Tronçon Vigicrues');
        expect(
          find.descendant(of: _row(0), matching: find.byType(Text)),
          findsNWidgets(3),
        );
        expect(
          <String>[
            for (final Text t in tester.widgetList<Text>(
              find.descendant(of: _row(0), matching: find.byType(Text)),
            ))
              t.data ?? '',
          ],
          <String>['Loire amont', 'Tronçon Vigicrues', 'Ajouté le 13/10/2026'],
        );
      },
    );

    testWidgetsOnWindows('un tap sur la ligne ne déclenche pas onOpen', (
      WidgetTester tester,
    ) async {
      final _Calls calls = _Calls();
      await tester.pumpWidget(
        _app(FavorisLus(<Favorite>[section()]), calls: calls),
      );

      await tester.tap(_row(0));
      await tester.pump();

      expect(calls.opened, isEmpty);
      expect(calls.removed, isEmpty);
    });

    testWidgetsOnWindows(
      '« Retirer des favoris : <nom> » appelle onRemove avec ce tronçon',
      (WidgetTester tester) async {
        final _Calls calls = _Calls();
        await tester.pumpWidget(
          _app(FavorisLus(<Favorite>[section()]), calls: calls),
        );

        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: _remove(0),
                  matching: find.byKey(favoriteStarButtonKey),
                ),
              )
              .getSemanticsData()
              .label,
          'Retirer des favoris : Loire amont',
        );
        await tester.tap(_remove(0));
        await tester.pump();

        expect(calls.removed, <Favorite>[section()]);
        expect(calls.opened, isEmpty);
      },
    );

    testWidgetsOnAndroid(
      'Android : à 360 × 640 et 200 % de police, la ligne est entière et le '
      'retrait mesure 48 × 48',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(_app(FavorisLus(<Favorite>[section()])));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(_remove(0)), const Size(48, 48));
        final Rect row = tester.getRect(_row(0));
        expect(row.left, greaterThanOrEqualTo(0));
        expect(row.right, lessThanOrEqualTo(360));
        expect(find.text('Loire amont'), findsOneWidget);
        expect(find.text('Tronçon Vigicrues'), findsOneWidget);
      },
    );
  });
}

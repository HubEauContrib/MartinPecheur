// Reproduction du symptome du 2026-09-29 (Windows, ~1266 x 741, 100 %) :
// « j'ai du mal a scroller en bas ou en haut, je suis bloque sur la page »,
// sur l'ecran des restrictions. Chaque hypothese a son test.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/restrictions/view/reinforced_warning_card.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';

import '../../../support/windows_platform.dart';
import '../zones_samples.dart';

const Size _window = Size(1266, 741);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: RestrictionsScreen(
        state: ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
        onChooseProfile: (UserProfile _) {},
        onRetry: () {},
        onOpenDocument: (DocumentLink _) {},
        onOpenPublicSite: () {},
        utcOffsetOf: (DateTime _) => const Duration(hours: 2),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le defilement de l'ecran — pas celui, interne, d'un `SelectableText`.
final Finder _mainScrollable = find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(_mainScrollable).position.pixels;

double _max(WidgetTester tester) =>
    tester.state<ScrollableState>(_mainScrollable).position.maxScrollExtent;

bool _headerPinned() => find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byKey(reinforcedWarningHeaderKey),
    )
    .evaluate()
    .isEmpty;

Future<void> _wheel(WidgetTester tester, Offset at, double dy) async {
  final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgetsOnWindows('le contenu depasse la hauteur (sinon rien a tester)', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    expect(_max(tester), greaterThan(300));
    expect(_headerPinned(), isTrue);
  });

  group('H2 : oscillation de l epinglage', () {
    testWidgetsOnWindows(
      'aucune bascule sur 30 passages, ni apres defilement',
      (WidgetTester tester) async {
        await _pump(tester);
        final List<bool> seen = <bool>[];
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(_headerPinned());
        }
        expect(seen.toSet(), <bool>{true});

        await _wheel(tester, const Offset(633, 500), 400);
        final double after = _offset(tester);
        expect(after, greaterThan(0));
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(_headerPinned(), isTrue);
        }
        expect(_offset(tester), after);
      },
    );
  });

  group('H3 : la molette defile, ou que soit le pointeur', () {
    testWidgetsOnWindows('au milieu du contenu, vers le bas puis le haut', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 300);
      expect(_offset(tester), 300);
      await _wheel(tester, const Offset(633, 500), -300);
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('jusqu en bas et retour en haut, a la molette', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      for (int i = 0; i < 40; i++) {
        await _wheel(tester, const Offset(633, 500), 200);
      }
      expect(_offset(tester), _max(tester));
      for (int i = 0; i < 40; i++) {
        await _wheel(tester, const Offset(633, 500), -200);
      }
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('sur la tete epinglee de l encart', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Offset header = tester.getCenter(
        find.textContaining(reinforcedWarningHeadline),
      );
      await _wheel(tester, header, 300);
      expect(_offset(tester), greaterThan(0));
    });

    testWidgetsOnWindows('sur l adresse selectionnable du site public', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Offset address = tester.getCenter(
        find.byType(SelectableText).first,
      );
      await _wheel(tester, address, 300);
      expect(_offset(tester), greaterThan(0));
    });

    testWidgetsOnWindows('sur une carte d arrete et sur un choix de profil', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      for (final Finder target in <Finder>[
        find.text('Adresse du document').first,
        find.byKey(restrictionsProfileChoiceKey(UserProfile.particulier)),
      ]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final double before = _offset(tester);
        await _wheel(tester, tester.getCenter(target), 100);
        expect(_offset(tester), greaterThan(before), reason: '$target');
      }
    });

    testWidgetsOnWindows('sur la barre de titre', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(
        tester,
        tester.getCenter(find.text(restrictionsScreenTitle)),
        300,
      );
      expect(_offset(tester), 300);
    });
  });

  group('H3 bis : balayage de la molette et composition', () {
    testWidgetsOnWindows('balayage : chaque point sous la barre de titre fait '
        'defiler, a plusieurs positions', (WidgetTester tester) async {
      await _pump(tester);
      final double barBottom = tester
          .getRect(
            find
                .ancestor(
                  of: find.text(restrictionsScreenTitle),
                  matching: find.byType(Material),
                )
                .first,
          )
          .bottom;
      final List<String> dead = <String>[];
      for (final double start in <double>[0, 400, 900]) {
        for (double y = barBottom + 5; y < _window.height; y += 23) {
          for (double x = 20; x < _window.width; x += 150) {
            final ScrollableState s = tester.state(_mainScrollable);
            s.position.jumpTo(start.clamp(0, s.position.maxScrollExtent - 60));
            await tester.pump();
            final double before = _offset(tester);
            await _wheel(tester, Offset(x, y), 50);
            if (_offset(tester) == before) {
              dead.add('(${x.toInt()},${y.toInt()})@${start.toInt()}');
            }
          }
        }
      }
      debugPrint(
        'points morts (${dead.length}) : ${dead.map((String d) => d.split(',').last).toSet()}',
      );
      expect(dead, isEmpty);
    });

    testWidgetsOnWindows('pousse par-dessus une carte (MaterialPageRoute) : la '
        'molette n atteint pas la carte, l ecran defile', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      int mapSignals = 0;
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Listener(
            onPointerSignal: (PointerSignalEvent _) => mapSignals++,
            child: const SizedBox.expand(
              child: ColoredBox(color: Colors.green),
            ),
          ),
        ),
      );
      final ValueNotifier<int> ticks = ValueNotifier<int>(0);
      addTearDown(ticks.dispose);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ListenableBuilder(
            listenable: ticks,
            builder: (BuildContext context, Widget? _) => RestrictionsScreen(
              state: ZonesTrouvees(zonesAin()),
              profile: UserProfile.particulier,
              onChooseProfile: (UserProfile _) {},
              onRetry: () {},
              onOpenDocument: (DocumentLink _) {},
              onOpenPublicSite: () {},
              utcOffsetOf: (DateTime _) => const Duration(hours: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _wheel(tester, const Offset(633, 500), 300);
      expect(_offset(tester), 300);
      // Le ViewModel notifie (reconstruction) : la position reste.
      ticks.value++;
      await tester.pumpAndSettle();
      expect(_offset(tester), 300);
      expect(mapSignals, 0);
    });

    testWidgetsOnWindows('pave tactile (pan-zoom) : defile', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final TestPointer pad = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pad.panZoomStart(const Offset(633, 500)));
      for (int i = 1; i <= 10; i++) {
        await tester.sendEventToBinding(
          pad.panZoomUpdate(const Offset(633, 500), pan: Offset(0, -30.0 * i)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendEventToBinding(pad.panZoomEnd());
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(0));
    });
  });

  group('H1 : glisser', () {
    testWidgetsOnWindows('au doigt : defile', (WidgetTester tester) async {
      await _pump(tester);
      await tester.dragFrom(const Offset(633, 600), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(0));
    });

    // Comportement par defaut de Flutter, garde : a la souris, le glisser ne
    // defile pas (la molette, la barre et le clavier le font). Sans quoi un
    // clic un peu tremble sur un choix ou un bouton serait perdu.
    testWidgetsOnWindows('a la souris : ne defile PAS', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.dragFrom(
        const Offset(633, 600),
        const Offset(0, -300),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('clic souris tremble de 3 px sur un choix de profil : '
        'le choix est fait', (WidgetTester tester) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final List<UserProfile> chosen = <UserProfile>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RestrictionsScreen(
            state: ZonesTrouvees(zonesAin()),
            profile: null,
            onChooseProfile: chosen.add,
            onRetry: () {},
            onOpenPublicSite: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder choice = find.byKey(
        restrictionsProfileChoiceKey(UserProfile.entreprise),
      );
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final Offset at = tester.getCenter(choice);
      final TestPointer mouse = TestPointer(3, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.down(at));
      await tester.sendEventToBinding(mouse.move(at + const Offset(0, 3)));
      await tester.sendEventToBinding(mouse.up());
      await tester.pumpAndSettle();
      expect(chosen, <UserProfile>[UserProfile.entreprise]);
    });
  });

  group('glisser a la souris et selection', () {
    EditableTextState address(WidgetTester tester) => tester.state(
      find
          .descendant(
            of: find.byType(SelectableText).at(1),
            matching: find.byType(EditableText),
          )
          .first,
    );

    testWidgetsOnWindows('glisser HORIZONTALEMENT sur une adresse la '
        'selectionne, sans defiler', (WidgetTester tester) async {
      await _pump(tester);
      final Finder text = find.byType(SelectableText).at(1);
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();
      final double before = _offset(tester);
      final Rect rect = tester.getRect(text);
      await tester.dragFrom(
        rect.centerLeft + const Offset(2, 0),
        Offset(rect.width * 0.6, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final TextSelection selection = address(tester)
          .textEditingValue
          .selection;
      debugPrint('selection apres glisser horizontal : $selection');
      expect(selection.isCollapsed, isFalse);
      expect(_offset(tester), before);
    });

    // Constat : partant d'une adresse, la selection du texte gagne ; pour
    // faire defiler, glisser ailleurs ou utiliser la molette.
    testWidgetsOnWindows('glisser VERTICALEMENT depuis une adresse la '
        'selectionne', (WidgetTester tester) async {
      await _pump(tester);
      final Finder text = find.byType(SelectableText).at(1);
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();
      final double before = _offset(tester);
      await tester.dragFrom(
        tester.getCenter(text),
        const Offset(0, -200),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      debugPrint(
        'glisser vertical sur l adresse : offset ${before.toInt()} -> '
        '${_offset(tester).toInt()}, selection '
        '${address(tester).textEditingValue.selection}',
      );
      expect(address(tester).textEditingValue.selection.isCollapsed, isFalse);
    });

    testWidgetsOnWindows('barre de defilement toujours visible', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Une seule barre pour le defilement de l'ecran (l'automatique est
      // retiree) ; les `SelectableText` gardent la leur, interne.
      final Finder bars = find.ancestor(
        of: _mainScrollable,
        matching: find.byType(Scrollbar),
      );
      expect(bars, findsOneWidget);
      expect(tester.widget<Scrollbar>(bars).thumbVisibility, isTrue);
      expect(
        find.descendant(of: _mainScrollable, matching: find.byType(Scrollbar)),
        findsNWidgets(find.byType(SelectableText).evaluate().length),
      );
    });
  });

  // `Espace` n'est pas une touche de defilement de Flutter sur Windows :
  // c'est l'activation (`ActivateIntent`, `WidgetsApp.defaultShortcuts`).
  // `PageUp`/`PageDown` et `Ctrl`+fleches le sont.
  group('H4 : clavier (desktop)', () {
    for (final MapEntry<String, LogicalKeyboardKey> key
        in <String, LogicalKeyboardKey>{
          'PageDown': LogicalKeyboardKey.pageDown,
          'Flèche bas': LogicalKeyboardKey.arrowDown,
        }.entries) {
      testWidgetsOnWindows('${key.key} a l ouverture defile vers le bas', (
        WidgetTester tester,
      ) async {
        await _pump(tester);
        await tester.sendKeyEvent(key.value);
        await tester.pumpAndSettle();
        expect(_offset(tester), greaterThan(0));
      });
    }

    testWidgetsOnWindows('PageUp remonte', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(_offset(tester), lessThan(600));
    });
  });
}

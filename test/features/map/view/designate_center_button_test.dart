// Verrouille le bouton « Restrictions au centre de la carte » refait selon le
// canvas de design du 2026-09-29 (`E1` de T2) : bouton large en pilule, fond
// `primaryActionColor`, libellé visible, indice de geste dessous, réticule
// inerte au centre de la carte.
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

const String _label = 'Restrictions au centre de la carte';

/// Un test de widget posé sur une plateforme : les cas de [DesignationBand]
/// (`S4` d'Ergonomie) sont rejoués sur Windows ET sur Android, qui n'ont pas
/// le même comportement de défilement (`MaterialScrollBehavior` pose une
/// `Scrollbar` sur les défilements verticaux du bureau, pas sur Android).
typedef _Test = void Function(
  String description,
  Future<void> Function(WidgetTester tester) body,
);

void _onAndroid(String d, Future<void> Function(WidgetTester tester) body) =>
    testWidgetsOnAndroid('Android : $d', body);

void _onWindows(String d, Future<void> Function(WidgetTester tester) body) =>
    testWidgetsOnWindows(d, body);

/// Ce que la bande a reçu, et ce que le témoin posé DESSOUS a reçu : un geste
/// posé hors de la pilule et de l'indice doit atteindre le témoin, qui figure
/// la carte.
class _Probe {
  int designations = 0;
  int witnessTaps = 0;
  int witnessSecondaryTaps = 0;
  int witnessLongPresses = 0;
  int witnessDrags = 0;
  int witnessWheels = 0;
}

/// Comment la bande est posée : le widget qui l'entoure.
typedef _Place = Widget Function(Widget band);

/// La bande posée à [width] de large, en haut à gauche ; [height] la serre,
/// [maxHeight] la borne sans la serrer.
_Place _placeAt(double width, {double? height, double? maxHeight}) =>
    (Widget band) => Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: height ?? 0,
          maxHeight: height ?? maxHeight ?? double.infinity,
        ),
        child: band,
      ),
    );

/// La bande posée dans une colonne : aucune borne de hauteur.
_Place _placeUnbounded(double width) =>
    (Widget band) => Align(
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[SizedBox(width: width, child: band)],
      ),
    );

Future<_Probe> _pumpBand(
  WidgetTester tester, {
  required _Place place,
  Size view = const Size(800, 740),
  double textScale = 1,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final _Probe probe = _Probe();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (PointerSignalEvent _) =>
                    probe.witnessWheels++,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => probe.witnessTaps++,
                  onSecondaryTap: () => probe.witnessSecondaryTaps++,
                  onLongPress: () => probe.witnessLongPresses++,
                  onHorizontalDragUpdate: (DragUpdateDetails _) =>
                      probe.witnessDrags++,
                ),
              ),
            ),
            place(DesignationBand(onDesignate: () => probe.designations++)),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return probe;
}

/// La fenêtre et la largeur des cas de gestes : plus larges que la pilule, pour
/// qu'il y ait de la bande de part et d'autre d'elle. À 344 de large, au
/// téléphone, la pilule remplit la bande — les marges que la mise en page
/// (`D1`) posera ne sont pas celles de cette pièce. Comme les verrous de la
/// bande actuelle (`map_designation_test.dart`), qui rejouent Android sur une
/// fenêtre de 800 de large.
const Size _roomyView = Size(800, 740);
const double _roomyWidth = 700;

Future<_Probe> _pumpRoomyBand(WidgetTester tester) =>
    _pumpBand(tester, view: _roomyView, place: _placeUnbounded(_roomyWidth));

/// La boîte de la bande : le premier `RenderObject` de [DesignationBand].
RenderBox _band(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(DesignationBand));

final Finder _pill = find.byKey(mapDesignateCenterButtonKey);
final Finder _hint = find.byKey(mapDesignateCenterHintKey);

/// Un point DANS la bande, sur la rangée de la pilule, à mi-chemin entre le
/// bord gauche de la bande et celui de la pilule — donc hors de la pilule et
/// de l'indice. Calculé depuis les rectangles mesurés (jamais par une
/// constante) et gardé : retombé hors de la bande, le test ne prouverait plus
/// rien.
Offset _pointInBand(WidgetTester tester) {
  final Rect band = tester.getRect(find.byType(DesignationBand));
  final Rect pill = tester.getRect(_pill);
  final Offset p = Offset((band.left + pill.left) / 2, pill.center.dy);
  expect(
    band.contains(p) && p.dx > band.left,
    isTrue,
    reason: 'le point $p doit être DANS la bande $band, pas sur son bord',
  );
  expect(pill.contains(p), isFalse, reason: '$p est dans la pilule $pill');
  // L'indice replié reste monté, posé À L'ORIGINE de la bande (son décalage
  // est remis à zéro) : son rectangle chevauche la pilule et ne dit rien. On
  // ne le garde que s'il est affiché, donc touchable.
  if (_hint.hitTestable().evaluate().isNotEmpty) {
    final Rect hint = tester.getRect(_hint);
    expect(hint.contains(p), isFalse, reason: '$p est dans l’indice $hint');
  }
  return p;
}

Future<int Function()> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 740),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  int taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: DesignationBand(onDesignate: () => taps++),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => taps;
}

void main() {
  group('bouton', () {
    testWidgetsOnWindows(
      'libellé visible, gras, sémantique exacte, ≥ 52 de haut',
      (WidgetTester tester) async {
        await _pump(tester);

        final Finder bouton = find.byKey(mapDesignateCenterButtonKey);
        expect(bouton, findsOneWidget);
        final Finder texte = find.descendant(
          of: bouton,
          matching: find.text(_label),
        );
        expect(texte, findsOneWidget);
        final TextStyle? style = tester.widget<Text>(texte).style;
        expect(style?.fontWeight, FontWeight.bold);
        expect(style?.fontSize, inInclusiveRange(16, 17));
        expect(style?.color, onPrimaryActionColor);

        expect(
          tester.getSemantics(bouton),
          matchesSemantics(
            label: _label,
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getSize(bouton).height, greaterThanOrEqualTo(52));
        expect(
          tester.getSize(bouton).height,
          greaterThanOrEqualTo(minimumTapTarget),
        );
      },
    );

    testWidgetsOnWindows(
      'fond primaryActionColor, bordure blanche 2, ombre, pilule',
      (WidgetTester tester) async {
        await _pump(tester);

        final ShapeDecoration decoration = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(mapDesignateCenterButtonKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((DecoratedBox b) => b.decoration)
            .whereType<ShapeDecoration>()
            .first;
        expect(decoration.color, primaryActionColor);
        expect(decoration.shadows, isNotEmpty);
        final StadiumBorder shape = decoration.shape as StadiumBorder;
        expect(shape.side.color, Colors.white);
        expect(shape.side.width, 2);
      },
    );

    testWidgetsOnWindows("l'icône de visée est exclue de la sémantique", (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final Finder icone = find.descendant(
        of: find.byKey(mapDesignateCenterButtonKey),
        matching: find.byIcon(Icons.gps_fixed),
      );
      expect(icone, findsOneWidget);
      expect(tester.widget<Icon>(icone).color, onPrimaryActionColor);
      expect(
        find.ancestor(of: icone, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });

    testWidgetsOnWindows('un tap, Entrée et Espace appellent le rappel', (
      WidgetTester tester,
    ) async {
      final int Function() taps = await _pump(tester);

      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      expect(taps(), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps(), 3);
    });

    for (final (Size, double) cas in <(Size, double)>[
      (const Size(360, 640), 1),
      (const Size(360, 640), 2),
      (const Size(390, 844), 2),
    ]) {
      testWidgetsOnAndroid(
        'Android : à ${cas.$1.width.toInt()} de large, police ${cas.$2 * 100} % : '
        'libellé complet, aucun débordement',
        (WidgetTester tester) async {
          await _pump(tester, size: cas.$1, textScale: cas.$2);

          expect(tester.takeException(), isNull);
          final Rect bouton = tester.getRect(
            find.byKey(mapDesignateCenterButtonKey),
          );
          expect(bouton.left, greaterThanOrEqualTo(16));
          expect(bouton.right, lessThanOrEqualTo(cas.$1.width - 16));
          final Rect texte = tester.getRect(find.text(_label));
          expect(bouton.contains(texte.topLeft), isTrue);
          expect(bouton.contains(texte.bottomRight), isTrue);
        },
      );
    }
  });

  group('indice', () {
    for (final (TargetPlatform, String) cas in <(TargetPlatform, String)>[
      (TargetPlatform.android, 'ou appui long sur n\'importe quel point'),
      (TargetPlatform.iOS, 'ou appui long sur n\'importe quel point'),
      (
        TargetPlatform.windows,
        'ou clic droit sur n\'importe quel point de la carte',
      ),
      (
        TargetPlatform.linux,
        'ou clic droit sur n\'importe quel point de la carte',
      ),
    ]) {
      testWidgetsOnWindows('${cas.$1.name} : « ${cas.$2} », hors sémantique', (
        WidgetTester tester,
      ) async {
        debugDefaultTargetPlatformOverride = cas.$1;
        try {
          await _pump(tester);

          final Finder indice = find.byKey(mapDesignateCenterHintKey);
          expect(indice, findsOneWidget);
          expect(
            find.descendant(of: indice, matching: find.text(cas.$2)),
            findsOneWidget,
          );
          final TextStyle? style = tester.widget<Text>(find.text(cas.$2)).style;
          expect(style?.fontSize, 14);
          expect(
            find.ancestor(
              of: find.text(cas.$2),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          // Sous le bouton, centré.
          final Rect b = tester.getRect(
            find.byKey(mapDesignateCenterButtonKey),
          );
          final Rect h = tester.getRect(indice);
          expect(h.top, greaterThanOrEqualTo(b.bottom));
          expect(h.center.dx, closeTo(b.center.dx, 1));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgetsOnAndroid(
      'Android : sans coup de dépassement à 360 × 640, police 200 %',
      (WidgetTester tester) async {
        await _pump(tester, size: const Size(360, 640), textScale: 2);

        expect(tester.takeException(), isNull);
        final Rect h = tester.getRect(find.byKey(mapDesignateCenterHintKey));
        expect(h.left, greaterThanOrEqualTo(0));
        expect(h.right, lessThanOrEqualTo(360));
      },
    );
  });

  group('réticule', () {
    testWidgetsOnWindows(
      '48 × 48, inerte : hors pointeur, sémantique et focus',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: MapCenterReticle())),
          ),
        );

        final Finder reticule = find.byKey(mapCenterReticleKey);
        expect(reticule, findsOneWidget);
        expect(tester.getSize(reticule), const Size(48, 48));
        expect(tester.getCenter(reticule), const Offset(400, 300));
        expect(
          find.ancestor(of: reticule, matching: find.byType(IgnorePointer)),
          findsWidgets,
        );
        expect(
          find.ancestor(of: reticule, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
        expect(
          find.ancestor(of: reticule, matching: find.byType(ExcludeFocus)),
          findsWidgets,
        );
      },
    );
  });

  // `S4` d'Ergonomie : la bande du bouton, pièce autonome que la mise en page
  // de la carte (`D1`) posera. Clés, libellés et annonces ne changent pas ;
  // les marges, elles, sont celles de la mise en page.
  void bandCases(String where, _Test test, Size view, double width) {
    group('DesignationBand ($where)', () {
      test(
        'entière : la pilule puis l\'indice, centrés sur la bande, séparés de '
        'designateCenterGap ; une seule pilule, un seul indice',
        (WidgetTester tester) async {
          await _pumpBand(tester, view: view, place: _placeUnbounded(width));

          expect(_pill, findsOneWidget);
          expect(_hint, findsOneWidget);
          expect(_hint.hitTestable(), findsOneWidget);
          final Rect band = tester.getRect(find.byType(DesignationBand));
          final Rect pill = tester.getRect(_pill);
          final Rect hint = tester.getRect(_hint);
          expect(band.width, width);
          expect(pill.center.dx, closeTo(band.center.dx, 0.01));
          expect(hint.center.dx, closeTo(band.center.dx, 0.01));
          expect(hint.top - pill.bottom, designateCenterGap);
          expect(band.top, pill.top);
          expect(band.bottom, closeTo(hint.bottom, 0.01));
          expect(
            pill.height,
            greaterThanOrEqualTo(designateCenterButtonHeight),
          );
          expect(pill.height, greaterThanOrEqualTo(minimumTapTarget));
          expect(tester.takeException(), isNull);
        },
      );

      test('un tap sur la pilule appelle onDesignate UNE fois, pas le témoin', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpBand(
          tester,
          view: view,
          place: _placeUnbounded(width),
        );

        await tester.tap(_pill);
        await tester.pump();

        expect(probe.designations, 1);
        expect(probe.witnessTaps, 0);
      });

      for (final double scale in <double>[1, 2]) {
        test('à ${(scale * 100).round()} % : getMinIntrinsicHeight est la '
            'pilule, getMaxIntrinsicHeight la pilule, l\'écart et l\'indice, '
            'sans erreur', (WidgetTester tester) async {
          await _pumpBand(
            tester,
            view: view,
            place: _placeUnbounded(width),
            textScale: scale,
          );

          final double pill = tester.getSize(_pill).height;
          final double hint = tester.getSize(_hint).height;
          final double min = _band(tester).getMinIntrinsicHeight(width);
          final double max = _band(tester).getMaxIntrinsicHeight(width);

          expect(min, closeTo(pill, 0.01));
          expect(max, closeTo(pill + designateCenterGap + hint, 0.01));
          expect(min, lessThan(max));
          expect(_band(tester).size.height, closeTo(max, 0.01));
          expect(tester.takeException(), isNull);
        });
      }

      // Repli 5, local : posée sous sa hauteur entière, la bande efface
      // l'indice d'elle-même — ni peint, ni touchable — et garde la pilule
      // entière. Une seule variante est montée : l'indice reste dans l'arbre,
      // pour que ses intrinsèques restent lisibles.
      for (final (String, _Place Function(double min)) cas
          in <(String, _Place Function(double min))>[
            (
              'serrée à la hauteur de la pilule',
              (double min) => _placeAt(width, height: min),
            ),
            (
              'bornée, sans être serrée, à la hauteur de la pilule',
              (double min) => _placeAt(width, maxHeight: min),
            ),
          ]) {
        test('posée ${cas.$1} : l\'indice est effacé, la pilule est entière '
            'et appelle onDesignate', (WidgetTester tester) async {
          await _pumpBand(tester, view: view, place: _placeUnbounded(width));
          final double min = _band(tester).getMinIntrinsicHeight(width);

          final _Probe probe = await _pumpBand(
            tester,
            view: view,
            place: cas.$2(min),
          );

          expect(tester.takeException(), isNull);
          expect(_hint, findsOneWidget);
          expect(_hint.hitTestable(), findsNothing);
          expect(
            _band(tester),
            paintsExactlyCountTimes(#drawParagraph, 2),
            reason: 'le libellé et son icône ; l\'indice n\'est pas peint',
          );
          expect(tester.getSize(_pill).height, closeTo(min, 0.01));
          expect(_band(tester).size.height, closeTo(min, 0.01));
          expect(_pill.hitTestable(), findsOneWidget);
          expect(
            tester.getSemantics(_pill),
            matchesSemantics(
              label: designateCenterLabel,
              isButton: true,
              isEnabled: true,
              hasEnabledState: true,
              hasTapAction: true,
            ),
          );

          await tester.tap(_pill);
          await tester.pump();
          expect(probe.designations, 1);
          expect(probe.witnessTaps, 0);
        });
      }

      test('la frontière est la hauteur entière : à max l\'indice est là, '
          'à max − 1 il est effacé, de nouveau à max il revient', (
        WidgetTester tester,
      ) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));
        final double max = _band(tester).getMaxIntrinsicHeight(width);

        await _pumpBand(
          tester,
          view: view,
          place: _placeAt(width, height: max),
        );
        expect(_hint.hitTestable(), findsOneWidget);
        expect(_band(tester), paintsExactlyCountTimes(#drawParagraph, 3));

        await _pumpBand(
          tester,
          view: view,
          place: _placeAt(width, height: max - 1),
        );
        expect(_hint.hitTestable(), findsNothing);
        expect(_band(tester), paintsExactlyCountTimes(#drawParagraph, 2));

        await _pumpBand(
          tester,
          view: view,
          place: _placeAt(width, height: max),
        );
        expect(_hint.hitTestable(), findsOneWidget);
        expect(_band(tester), paintsExactlyCountTimes(#drawParagraph, 3));
        expect(tester.takeException(), isNull);
      });

      test('posée plus haut que sa hauteur entière : indice présent, '
          'contenu en haut, aucune erreur', (WidgetTester tester) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));
        final double max = _band(tester).getMaxIntrinsicHeight(width);

        await _pumpBand(
          tester,
          view: view,
          place: _placeAt(width, height: max + 40),
        );

        expect(tester.takeException(), isNull);
        expect(_hint.hitTestable(), findsOneWidget);
        expect(_band(tester).size.height, max + 40);
        expect(
          tester.getRect(_pill).top,
          tester.getRect(find.byType(DesignationBand)).top,
        );
      });

      test('posée sous la pilule elle-même : la pilule défile, aucune erreur '
          'de débordement', (WidgetTester tester) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));
        final double min = _band(tester).getMinIntrinsicHeight(width);

        await _pumpBand(
          tester,
          view: view,
          place: _placeAt(width, height: min - 20),
        );
        expect(tester.takeException(), isNull);
        expect(_hint.hitTestable(), findsNothing);
        expect(_band(tester).size.height, closeTo(min - 20, 0.01));
        final double before = tester.getTopLeft(_pill).dy;

        await tester.drag(_pill, const Offset(0, -80));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(_pill).dy, closeTo(before - 20, 0.5));
      });

      // Les verrous de gestes de la bande actuelle
      // (`map_designation_test.dart`, `verrousDeGestes`) : un geste posé dans
      // la bande, à côté de la pilule, atteint la carte dessous. Sur une
      // fenêtre et une bande plus larges que la pilule (`_roomyView`).
      test('un tap à côté de la pilule atteint le témoin dessous', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpRoomyBand(tester);
        final Offset p = _pointInBand(tester);

        await tester.tapAt(p);
        await tester.pumpAndSettle();

        expect(probe.witnessTaps, 1);
        expect(probe.designations, 0);
      });

      test('un clic droit à côté de la pilule atteint le témoin dessous', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpRoomyBand(tester);
        final Offset p = _pointInBand(tester);

        await tester.tapAt(p, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(probe.witnessSecondaryTaps, 1);
        expect(probe.designations, 0);
      });

      test('un appui long à côté de la pilule atteint le témoin dessous', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpRoomyBand(tester);
        final Offset p = _pointInBand(tester);

        await tester.longPressAt(p);
        await tester.pumpAndSettle();

        expect(probe.witnessLongPresses, 1);
        expect(probe.designations, 0);
      });

      test('un glisser à côté de la pilule atteint le témoin dessous', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpRoomyBand(tester);
        final Offset p = _pointInBand(tester);

        await tester.dragFrom(p, const Offset(-30, 0));
        await tester.pumpAndSettle();

        expect(probe.witnessDrags, greaterThan(0));
      });

      test('un cran de molette à côté de la pilule atteint le témoin '
          'dessous', (WidgetTester tester) async {
        final _Probe probe = await _pumpRoomyBand(tester);
        final Offset p = _pointInBand(tester);

        final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(p));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
        await tester.pumpAndSettle();

        expect(probe.witnessWheels, 1);
      });

      // Bande REPLIÉE (`D1` la posera serrée entre la pilule et la hauteur
      // entière, s'il y a un reste) : l'indice n'est plus là, mais la bande
      // garde la hauteur qu'on lui donne. Le blanc sous la pilule, comme celui
      // à côté d'elle, est de la carte.
      test('bande repliée, serrée entre la pilule et la hauteur entière : un '
          'tap sous la pilule et un tap à côté d\'elle atteignent le témoin '
          'dessous', (WidgetTester tester) async {
        await _pumpRoomyBand(tester);
        final double min = _band(tester).getMinIntrinsicHeight(_roomyWidth);
        final double max = _band(tester).getMaxIntrinsicHeight(_roomyWidth);

        final _Probe probe = await _pumpBand(
          tester,
          view: _roomyView,
          place: _placeAt(_roomyWidth, height: (min + max) / 2),
        );
        expect(
          _hint.hitTestable(),
          findsNothing,
          reason: 'la bande est repliée',
        );
        final Rect band = tester.getRect(find.byType(DesignationBand));
        final Rect pill = tester.getRect(_pill);
        expect(band.height, closeTo((min + max) / 2, 0.01));
        final Offset below = Offset(
          pill.center.dx,
          (pill.bottom + band.bottom) / 2,
        );
        expect(
          band.contains(below) && !pill.contains(below),
          isTrue,
          reason:
              'le point $below doit être DANS la bande $band, sous la pilule',
        );
        final Offset beside = _pointInBand(tester);

        await tester.tapAt(below);
        await tester.pumpAndSettle();
        expect(probe.witnessTaps, 1);

        await tester.tapAt(beside);
        await tester.pumpAndSettle();
        expect(probe.witnessTaps, 2);
        expect(probe.designations, 0);
      });

      test('l\'indice, lui, capte les gestes posés sur lui (il fait partie '
          'de la bande)', (WidgetTester tester) async {
        final _Probe probe = await _pumpRoomyBand(tester);

        await tester.tap(_hint);
        await tester.pump();

        expect(probe.witnessTaps, 0);
        expect(probe.designations, 0);
      });
    });
  }

  // Ce qui ne dépend pas de la plateforme — focus, annonce, intrinsèques en
  // largeur, structure du défilement — n'est rejoué que sur Windows : Android
  // n'y ajouterait rien. (Le reste de la bande, qui touche la cible de 48, le
  // texte de l'indice ou le défilement d'Android, l'est sur les deux.)
  void bandBehaviourCases(_Test test, Size view, double width) {
    group('DesignationBand (Windows, comportement)', () {
      test('Tab, Entrée : un seul arrêt de tabulation, la pilule, qui appelle '
          'onDesignate ; le défilement n\'en ajoute aucun', (
        WidgetTester tester,
      ) async {
        final _Probe probe = await _pumpBand(
          tester,
          view: view,
          place: _placeUnbounded(width),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, _pill), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(probe.designations, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, _pill), isTrue);
      });

      test('sans borne de largeur : la bande prend sa largeur intrinsèque '
          'maximale, la pilule y tient', (WidgetTester tester) async {
        await _pumpBand(
          tester,
          view: _roomyView,
          place: (Widget band) => Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[band],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final Rect bandRect = tester.getRect(find.byType(DesignationBand));
        expect(
          bandRect.width,
          closeTo(_band(tester).getMaxIntrinsicWidth(double.infinity), 0.01),
        );
        // `Rect.contains` exclut le bord droit et le bord bas : on les inclut.
        final Rect room = bandRect.inflate(0.01);
        expect(room.contains(tester.getRect(_pill).topLeft), isTrue);
        expect(room.contains(tester.getRect(_pill).bottomRight), isTrue);
        expect(_hint.hitTestable(), findsOneWidget);
      });

      test('la pilule garde son annonce, l\'indice reste hors sémantique', (
        WidgetTester tester,
      ) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));

        expect(
          tester.getSemantics(_pill),
          matchesSemantics(
            label: designateCenterLabel,
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
        expect(
          find.descendant(of: _hint, matching: find.byType(Semantics)),
          findsNothing,
        );
        expect(
          find.ancestor(of: _hint, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
      });

      test('intrinsèques en largeur : test de non-erreur — ils répondent, '
          '0 < min ≤ max, et min tient dans la largeur donnée ; aucune valeur '
          'exacte n\'est vérifiée', (WidgetTester tester) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));

        final double minWidth = _band(tester)
            .getMinIntrinsicWidth(double.infinity);
        final double maxWidth = _band(tester)
            .getMaxIntrinsicWidth(double.infinity);
        expect(minWidth, greaterThan(0));
        expect(minWidth, lessThanOrEqualTo(maxWidth));
        expect(minWidth, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      });

      test('SingleChildScrollView : primary faux et hitTestBehavior '
          'deferToChild (les propriétés seules ; les gestes sont prouvés par '
          'les cas de gestes) ; ni ListView, ni barre', (
        WidgetTester tester,
      ) async {
        await _pumpBand(tester, view: view, place: _placeUnbounded(width));

        final Finder inBand = find.descendant(
          of: find.byType(DesignationBand),
          matching: find.byType(SingleChildScrollView),
        );
        expect(inBand, findsOneWidget);
        final SingleChildScrollView scroll = tester
            .widget<SingleChildScrollView>(inBand);
        expect(scroll.primary, isFalse);
        expect(scroll.hitTestBehavior, HitTestBehavior.deferToChild);
        expect(
          find.descendant(
            of: find.byType(DesignationBand),
            matching: find.byType(ListView),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(DesignationBand),
            matching: find.byType(Scrollbar),
          ),
          findsNothing,
        );
      });
    });
  }

  bandCases('Windows', _onWindows, const Size(800, 740), 420);
  bandCases('Android', _onAndroid, const Size(360, 640), 344);
  bandBehaviourCases(_onWindows, const Size(800, 740), 420);
}

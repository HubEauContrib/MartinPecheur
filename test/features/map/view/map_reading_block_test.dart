// Verrouille le bloc de lecture en trois pièces (`B1` d'Ergonomie, cadrage du
// 2026-10-17, § 5.3) : la partie fixe (sélecteur et en-tête), les avis et la
// légende, trois enfants de la future mise en page (`D1`) qui dessinent
// ENSEMBLE une seule carte blanche — bord `#C9CFC4`, rayon 8, l'ombre de la
// pilule (`designate_center_button.dart`).
//
// Ce que le fichier prouve :
// - les hauteurs intrinsèques sont celles des pièces mesurées SEULES (porte
//   `S6`) : la partie fixe, sélecteur plus en-tête ; les avis, 0 à leur pile ;
//   la légende, 0 à elle-même — aucune marge interne ajoutée ;
// - la partie fixe se replie d'elle-même (repli 4 : sous-titres effacés) et,
//   en deçà de sa hauteur repliée, défile ; « ⚠ Avertissement » s'amène en vue
//   par un glisser, par `Scrollable.ensureVisible` et par le focus ;
// - les avis et la légende défilent dans la hauteur reçue, au glisser et à la
//   molette, sans barre de bureau, `primary: false` ;
// - la carte blanche ABSORBE les gestes posés sur sa surface (décision de la
//   boucle principale) : un tap ou un appui long dessus n'atteint pas la carte
//   dessous ;
// - la peinture : aucun trait, aucune ombre, aucune transparence à la jonction
//   de deux pièces, même à une hauteur fractionnaire ; un rayon en haut, un en
//   bas, dont celui du bas quand la légende (puis les avis) tombe à 0.
//
// Les mesures sont faites en ROBOTO, chargée depuis le SDK (`chargerRoboto`).

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

/// Largeur du bloc sous Windows (la plus large que la mise en page lui donne).
const double _windowsWidth = 480;

/// Largeur du bloc au téléphone : 360 − 2 × 8.
const double _phoneWidth = 344;

/// Un cas rejoué sur Windows (480) ET sur Android (344).
typedef _Body = Future<void> Function(WidgetTester tester, double width);

/// Le déclarant de test de la plateforme de [width] : Windows pour la largeur
/// du bureau, Android — titre commençant par « Android : » — pour celle du
/// téléphone.
void Function(String, Future<void> Function(WidgetTester)) _runFor(
  double width,
) =>
    (String description, Future<void> Function(WidgetTester) body) =>
        width == _windowsWidth
        ? testWidgetsOnWindows(description, body)
        : testWidgetsOnAndroid('Android : $description', body);

void _onBothPlatforms(String description, _Body body) {
  testWidgetsOnWindows(
    description,
    (WidgetTester tester) => body(tester, _windowsWidth),
  );
  testWidgetsOnAndroid(
    'Android : $description',
    (WidgetTester tester) => body(tester, _phoneWidth),
  );
}

/// Ce que le témoin posé SOUS le bloc a reçu, et ce que l'action des avis a
/// reçu : la carte est figurée par le témoin.
class _Probe {
  int taps = 0;
  int longPresses = 0;
  int drags = 0;
  int wheels = 0;
  int widen = 0;
}

Widget _witness(_Probe probe) => Listener(
  behavior: HitTestBehavior.opaque,
  onPointerSignal: (PointerSignalEvent _) => probe.wheels++,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => probe.taps++,
    onLongPress: () => probe.longPresses++,
    onVerticalDragUpdate: (DragUpdateDetails _) => probe.drags++,
  ),
);

void _setView(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _app(Widget body) => MaterialApp(home: Scaffold(body: body));

MapReadingSelector _selector({MapScaleKind scale = MapScaleKind.ecoulement}) =>
    MapReadingSelector(
      scale: scale,
      onSelect: (MapScaleKind _) {},
      onToggleDesignationMode: () {},
    );

MapLegendHeader _header({
  MapScaleKind scale = MapScaleKind.ecoulement,
  Widget link = const WarningLink(),
}) => MapLegendHeader(scale: scale, warningLink: link);

MapReadingBlockFixed _fixed({
  MapScaleKind scale = MapScaleKind.ecoulement,
  Widget link = const WarningLink(),
}) => MapReadingBlockFixed(
  selector: _selector(scale: scale),
  header: _header(scale: scale, link: link),
);

MapReadingBlockLegend _legend({MapScaleKind scale = MapScaleKind.ecoulement}) =>
    MapReadingBlockLegend(legend: MapLegend(scale: scale));

/// [piece] posée à la hauteur serrée [height], ou à sa hauteur naturelle.
Widget _sized(Widget piece, double? height) =>
    height == null ? piece : SizedBox(height: height, child: piece);

/// Les trois pièces empilées SANS ÉCART dans une colonne de [width], en haut à
/// gauche d'une fenêtre de [width] × 1 000, au-dessus d'un témoin qui figure la
/// carte. Une hauteur nulle fait de la pièce un `SizedBox` de hauteur nulle.
Future<_Probe> _pumpBlock(
  WidgetTester tester, {
  required double width,
  double? fixedHeight,
  double? noticesHeight,
  double? legendHeight,
  MapScaleKind scale = MapScaleKind.ecoulement,
  double textScale = 1,
  bool showNotices = true,
}) async {
  _setView(tester, Size(width, 1000), textScale: textScale);
  final _Probe probe = _Probe();
  await tester.pumpWidget(
    _app(
      Stack(
        children: <Widget>[
          Positioned.fill(child: _witness(probe)),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _sized(_fixed(scale: scale), fixedHeight),
                  _sized(
                    MapReadingBlockNotices(
                      notices: showNotices
                          ? <Widget>[
                              NoDataInAreaNotice(onWiden: () => probe.widen++),
                            ]
                          : const <Widget>[],
                    ),
                    noticesHeight,
                  ),
                  _sized(_legend(scale: scale), legendHeight),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return probe;
}

/// Les hauteurs intrinsèques d'une pièce posée seule, à [width].
Future<({double min, double max})> _intrinsics(
  WidgetTester tester,
  Widget widget,
  Finder finder, {
  required double width,
  double textScale = 1,
}) async {
  _setView(tester, Size(width, 1000), textScale: textScale);
  await tester.pumpWidget(
    _app(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: widget),
      ),
    ),
  );
  final RenderBox box = tester.renderObject<RenderBox>(finder);
  return (
    min: box.getMinIntrinsicHeight(width),
    max: box.getMaxIntrinsicHeight(width),
  );
}

ScrollableState _scrollOf(WidgetTester tester, Finder piece) =>
    tester.state<ScrollableState>(
      find.descendant(of: piece, matching: find.byType(Scrollable)),
    );

/// Le rectangle du contrôle « ⚠ Avertissement ».
Rect _linkRect(WidgetTester tester) =>
    tester.getRect(find.byKey(warningLinkKey));

bool _isWithin(Rect inner, Rect outer) =>
    inner.top >= outer.top - 0.01 &&
    inner.bottom <= outer.bottom + 0.01 &&
    inner.left >= outer.left - 0.01 &&
    inner.right <= outer.right + 0.01;

/// Les textes des entrées du sélecteur : titre et sous-titre, dans l'ordre.
List<(String, String)> _entryTexts() => <(String, String)>[
  for (final MapScaleKind kind in MapScaleKind.values)
    (mapScaleEntryTitle(kind), mapScaleEntrySubtitle(kind)),
  (designationChipLabel, designationEntrySubtitle),
];

void main() {
  setUpAll(chargerRoboto);

  group('MapReadingBlock — hauteurs intrinsèques', () {
    for (final (double width, double scale) in <(double, double)>[
      (_windowsWidth, 1),
      (_windowsWidth, 2),
      (_phoneWidth, 1),
      (_phoneWidth, 2),
    ]) {
      final String platformWhere =
          '${width == _windowsWidth ? 'Windows' : 'Android'}, '
          '${width.round()} px, ${(scale * 100).round()} %';
      final void Function(String, Future<void> Function(WidgetTester)) run =
          _runFor(width);

      for (final MapScaleKind kind in MapScaleKind.values) {
        final String where = '$platformWhere, ${mapScaleLabel(kind)}';

        run('partie fixe ($where) : min = sélecteur replié + en-tête, max = '
            'sélecteur entier + en-tête, sans marge ajoutée', (
          WidgetTester tester,
        ) async {
          final ({double min, double max}) selector = await _intrinsics(
            tester,
            _selector(scale: kind),
            find.byType(MapReadingSelector),
            width: width,
            textScale: scale,
          );
          final ({double min, double max}) header = await _intrinsics(
            tester,
            _header(scale: kind),
            find.byType(MapLegendHeader),
            width: width,
            textScale: scale,
          );
          final ({double min, double max}) fixed = await _intrinsics(
            tester,
            _fixed(scale: kind),
            find.byType(MapReadingBlockFixed),
            width: width,
            textScale: scale,
          );

          expect(header.min, moreOrLessEquals(header.max));
          expect(fixed.min, moreOrLessEquals(selector.min + header.max));
          expect(fixed.max, moreOrLessEquals(selector.max + header.max));
          expect(fixed.min, lessThan(fixed.max));
        });

        run('légende ($where) : min 0, max = la légende seule', (
          WidgetTester tester,
        ) async {
          final ({double min, double max}) legend = await _intrinsics(
            tester,
            MapLegend(scale: kind),
            find.byType(MapLegend),
            width: width,
            textScale: scale,
          );
          final ({double min, double max}) piece = await _intrinsics(
            tester,
            _legend(scale: kind),
            find.byType(MapReadingBlockLegend),
            width: width,
            textScale: scale,
          );

          expect(piece.min, 0);
          expect(piece.max, moreOrLessEquals(legend.max));
          expect(piece.max, greaterThan(0));
        });
      }

      run('avis ($platformWhere) : min 0, max = les avis empilés nus', (
        WidgetTester tester,
      ) async {
        final List<Widget> notices = <Widget>[
          NoDataInAreaNotice(onWiden: () {}),
          const SourceUnavailableNotice(sourceName: 'Source de test'),
        ];
        const Key stackKey = Key('pile-des-avis');
        final ({double min, double max}) stacked = await _intrinsics(
          tester,
          Column(
            key: stackKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: notices,
          ),
          find.byKey(stackKey),
          width: width,
          textScale: scale,
        );
        final ({double min, double max}) piece = await _intrinsics(
          tester,
          MapReadingBlockNotices(notices: notices),
          find.byType(MapReadingBlockNotices),
          width: width,
          textScale: scale,
        );

        expect(piece.min, 0);
        expect(piece.max, moreOrLessEquals(stacked.max));
        expect(piece.max, greaterThan(0));
      });

      if (scale == 1) {
        run('avis ($platformWhere) : aucun avis, hauteur 0 (min = max = 0)', (
          WidgetTester tester,
        ) async {
          final ({double min, double max}) piece = await _intrinsics(
            tester,
            const MapReadingBlockNotices(notices: <Widget>[]),
            find.byType(MapReadingBlockNotices),
            width: width,
            textScale: scale,
          );

          expect(piece.min, 0);
          expect(piece.max, 0);
        });
      }
    }

    _onBothPlatforms(
      'les trois pièces répondent à toutes les demandes d intrinsèques et de '
      'mise en page à vide sans erreur',
      (WidgetTester tester, double width) async {
        await _pumpBlock(tester, width: width);

        for (final Type type in <Type>[
          MapReadingBlockFixed,
          MapReadingBlockNotices,
          MapReadingBlockLegend,
        ]) {
          final RenderBox box = tester.renderObject<RenderBox>(
            find.byType(type),
          );
          box.getMinIntrinsicHeight(width);
          box.getMaxIntrinsicHeight(width);
          box.getMinIntrinsicWidth(double.infinity);
          box.getMaxIntrinsicWidth(double.infinity);
          box.getDryLayout(BoxConstraints(maxWidth: width));
          box.getDryLayout(BoxConstraints.tightFor(width: width, height: 80));
        }
        expect(tester.takeException(), isNull);
      },
    );

    _onBothPlatforms(
      'la mise en page à vide de la partie fixe est la vraie, quelle que soit '
      'la hauteur où elle est posée',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );
        final List<double> heights = <double>[
          fixed.max + 40,
          fixed.max,
          fixed.max - 1,
          (fixed.min + fixed.max) / 2,
          fixed.min,
          fixed.min - 30,
        ];
        BoxConstraints loose(double height) =>
            BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height);
        Future<void> pumpAt(double height) => tester.pumpWidget(
          _app(
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: loose(height),
                child: _fixed(),
              ),
            ),
          ),
        );
        final Finder block = find.byType(MapReadingBlockFixed);

        final Map<double, Size> real = <double, Size>{};
        for (final double height in heights) {
          await pumpAt(height);
          real[height] = tester.getSize(block);
        }
        // Posée à chaque hauteur, la pièce répond à vide, pour toutes les
        // autres, ce qu'une vraie mise en page donne.
        for (final double laidOut in heights) {
          await pumpAt(laidOut);
          final RenderBox box = tester.renderObject<RenderBox>(block);
          for (final double asked in heights) {
            final Size dry = box.getDryLayout(loose(asked));
            expect(
              dry.width,
              moreOrLessEquals(real[asked]!.width),
              reason: 'largeur à vide, posée à $laidOut, demandée à $asked',
            );
            expect(
              dry.height,
              moreOrLessEquals(real[asked]!.height),
              reason: 'hauteur à vide, posée à $laidOut, demandée à $asked',
            );
          }
        }
      },
    );
  });

  group('MapReadingBlock — une seule carte', () {
    _onBothPlatforms(
      'empilées sans écart, les trois pièces ont la même largeur et se '
      'touchent : une carte continue',
      (WidgetTester tester, double width) async {
        await _pumpBlock(tester, width: width);

        final Rect fixed = tester.getRect(find.byType(MapReadingBlockFixed));
        final Rect notices = tester.getRect(
          find.byType(MapReadingBlockNotices),
        );
        final Rect legend = tester.getRect(find.byType(MapReadingBlockLegend));
        for (final Rect rect in <Rect>[fixed, notices, legend]) {
          expect(rect.left, 0);
          expect(rect.width, width);
          expect(rect.height, greaterThan(0));
        }
        expect(notices.top, closeTo(fixed.bottom, 1e-6));
        expect(legend.top, closeTo(notices.bottom, 1e-6));
      },
    );
  });

  group('MapReadingBlockFixed — repli des sous-titres et défilement', () {
    _onBothPlatforms(
      'posée à sa hauteur repliée : titres et en-tête entiers, sous-titres '
      'absents, rien ne défile',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );

        await _pumpBlock(
          tester,
          width: width,
          fixedHeight: fixed.min,
          noticesHeight: 0,
          legendHeight: 0,
        );
        final Rect block = tester.getRect(find.byType(MapReadingBlockFixed));

        expect(block.height, closeTo(fixed.min, 0.01));
        for (final (String title, String subtitle) in _entryTexts()) {
          expect(find.text(title).hitTestable(), findsOneWidget);
          expect(_isWithin(tester.getRect(find.text(title)), block), isTrue);
          // Une seule variante montée : le texte reste dans l'arbre, ni peint
          // ni touchable.
          expect(find.text(subtitle), findsOneWidget);
          expect(find.text(subtitle).hitTestable(), findsNothing);
        }
        expect(
          _isWithin(tester.getRect(find.byType(MapLegendHeader)), block),
          isTrue,
          reason: 'l en-tête reste entier',
        );
        expect(find.byKey(warningLinkKey).hitTestable(), findsOneWidget);
        expect(
          _scrollOf(
            tester,
            find.byType(MapReadingBlockFixed),
          ).position.maxScrollExtent,
          closeTo(0, 0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );

    _onBothPlatforms(
      'posée à sa hauteur entière, tous les sous-titres sont à l écran',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );

        await _pumpBlock(
          tester,
          width: width,
          fixedHeight: fixed.max,
          noticesHeight: 0,
          legendHeight: 0,
        );

        for (final (String title, String subtitle) in _entryTexts()) {
          expect(find.text(title).hitTestable(), findsOneWidget);
          expect(find.text(subtitle).hitTestable(), findsOneWidget);
        }
        expect(
          _scrollOf(
            tester,
            find.byType(MapReadingBlockFixed),
          ).position.maxScrollExtent,
          closeTo(0, 0.01),
        );
      },
    );

    _onBothPlatforms(
      'le repli suit la hauteur reçue d une trame à l autre : entière, '
      'repliée, entière',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );
        final String subtitle = mapScaleEntrySubtitle(MapScaleKind.debit);

        for (final (double height, bool shown) in <(double, bool)>[
          (fixed.max, true),
          (fixed.max - 1, false),
          (fixed.min, false),
          ((fixed.min + fixed.max) / 2, false),
          (fixed.max + 40, true),
        ]) {
          await _pumpBlock(
            tester,
            width: width,
            fixedHeight: height,
            noticesHeight: 0,
            legendHeight: 0,
          );
          expect(
            find.text(subtitle).hitTestable(),
            shown ? findsOneWidget : findsNothing,
            reason:
                'à ${height.toStringAsFixed(2)} px (entière : '
                '${fixed.max.toStringAsFixed(2)})',
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    for (final (double width, double textScale) in <(double, double)>[
      (_windowsWidth, 2),
      (_phoneWidth, 2),
    ]) {
      final void Function(String, Future<void> Function(WidgetTester)) run =
          _runFor(width);
      run(
        'à ${width.round()} px et '
        '200 %, repliée : l en-tête reste entier et le contrôle atteignable',
        (WidgetTester tester) async {
          final ({double min, double max}) fixed = await _intrinsics(
            tester,
            _fixed(),
            find.byType(MapReadingBlockFixed),
            width: width,
            textScale: textScale,
          );

          await _pumpBlock(
            tester,
            width: width,
            textScale: textScale,
            fixedHeight: fixed.min,
            noticesHeight: 0,
            legendHeight: 0,
          );

          final Rect block = tester.getRect(find.byType(MapReadingBlockFixed));
          expect(
            _isWithin(tester.getRect(find.byType(MapLegendHeader)), block),
            isTrue,
          );
          expect(find.byKey(warningLinkKey).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    /// La hauteur à laquelle la partie fixe défile : au téléphone, 120 (le
    /// cas de la consigne, en deçà de sa hauteur repliée), sous Windows
    /// quelques pixels au-dessus du sélecteur replié — l'en-tête y est coupé.
    Future<double> scrollingHeight(
      WidgetTester tester,
      double width,
      ({double min, double max}) fixed,
    ) async {
      if (width == _phoneWidth) {
        expect(120, lessThan(fixed.min));
        return 120;
      }
      final ({double min, double max}) selector = await _intrinsics(
        tester,
        _selector(),
        find.byType(MapReadingSelector),
        width: width,
      );
      return selector.min + 10;
    }

    _onBothPlatforms(
      'posée sous sa hauteur repliée : elle défile, et « ⚠ Avertissement » '
      's amène en vue par un glisser sur le bloc',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );
        final double height = await scrollingHeight(tester, width, fixed);

        await _pumpBlock(
          tester,
          width: width,
          fixedHeight: height,
          noticesHeight: 0,
          legendHeight: 0,
        );
        final Rect block = tester.getRect(find.byType(MapReadingBlockFixed));
        final ScrollableState scroll = _scrollOf(
          tester,
          find.byType(MapReadingBlockFixed),
        );

        expect(block.height, closeTo(height, 0.01));
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        expect(
          _isWithin(_linkRect(tester), block),
          isFalse,
          reason: 'le contrôle est coupé au repos',
        );

        await tester.drag(
          find.byType(MapReadingBlockFixed),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        expect(scroll.position.pixels, greaterThan(0));
        expect(_isWithin(_linkRect(tester), block), isTrue);
        expect(find.byKey(warningLinkKey).hitTestable(), findsOneWidget);
      },
    );

    _onBothPlatforms(
      'Scrollable.ensureVisible amène « ⚠ Avertissement » en vue',
      (WidgetTester tester, double width) async {
        final ({double min, double max}) fixed = await _intrinsics(
          tester,
          _fixed(),
          find.byType(MapReadingBlockFixed),
          width: width,
        );
        final double height = await scrollingHeight(tester, width, fixed);

        await _pumpBlock(
          tester,
          width: width,
          fixedHeight: height,
          noticesHeight: 0,
          legendHeight: 0,
        );
        final Rect block = tester.getRect(find.byType(MapReadingBlockFixed));
        expect(_isWithin(_linkRect(tester), block), isFalse);

        await Scrollable.ensureVisible(
          tester.element(find.byKey(warningLinkKey)),
        );
        await tester.pumpAndSettle();

        expect(_isWithin(_linkRect(tester), block), isTrue);
      },
    );

    _onBothPlatforms('le focus clavier amène « ⚠ Avertissement » en vue', (
      WidgetTester tester,
      double width,
    ) async {
      final ({double min, double max}) fixed = await _intrinsics(
        tester,
        _fixed(),
        find.byType(MapReadingBlockFixed),
        width: width,
      );
      final double height = await scrollingHeight(tester, width, fixed);

      await _pumpBlock(
        tester,
        width: width,
        fixedHeight: height,
        noticesHeight: 0,
        legendHeight: 0,
      );
      final Rect block = tester.getRect(find.byType(MapReadingBlockFixed));
      expect(_isWithin(_linkRect(tester), block), isFalse);

      for (int i = 0; i < 12; i++) {
        if (focusedWithin(tester, find.byKey(warningLinkKey))) {
          break;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }

      expect(focusedWithin(tester, find.byKey(warningLinkKey)), isTrue);
      expect(_isWithin(_linkRect(tester), block), isTrue);
    });
  });

  group('MapReadingBlockNotices — défilement', () {
    _onBothPlatforms(
      'posés sous leur hauteur, l action « Élargir la recherche » s atteint '
      'en faisant défiler',
      (WidgetTester tester, double width) async {
        final _Probe probe = await _pumpBlock(
          tester,
          width: width,
          noticesHeight: 40,
          legendHeight: 0,
        );
        final Rect block = tester.getRect(find.byType(MapReadingBlockNotices));
        final ScrollableState scroll = _scrollOf(
          tester,
          find.byType(MapReadingBlockNotices),
        );

        expect(block.height, closeTo(40, 0.01));
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        expect(find.byKey(widenSearchKey).hitTestable(), findsNothing);

        await tester.drag(
          find.byType(MapReadingBlockNotices),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        expect(scroll.position.pixels, greaterThan(0));
        expect(find.byKey(widenSearchKey).hitTestable(), findsOneWidget);
        await tester.tap(find.byKey(widenSearchKey));
        await tester.pump();
        expect(probe.widen, 1);
        expect(probe.taps, 0);
      },
    );

    _onBothPlatforms(
      'aucun avis : la pièce est à hauteur 0, rien n est touchable dessus',
      (WidgetTester tester, double width) async {
        final _Probe probe = await _pumpBlock(
          tester,
          width: width,
          showNotices: false,
        );
        final Rect fixed = tester.getRect(find.byType(MapReadingBlockFixed));
        final Rect notices = tester.getRect(
          find.byType(MapReadingBlockNotices),
        );

        expect(notices.height, 0);
        expect(notices.top, closeTo(fixed.bottom, 1e-6));
        await tester.tapAt(Offset(width / 2, 950));
        expect(probe.taps, 1, reason: 'le témoin reçoit un tap hors du bloc');
      },
    );
  });

  group('MapReadingBlockLegend — défilement', () {
    for (final MapScaleKind kind in MapScaleKind.values) {
      _onBothPlatforms(
        '${mapScaleLabel(kind)} : posée sous sa hauteur, la légende défile '
        'au glisser',
        (WidgetTester tester, double width) async {
          await _pumpBlock(
            tester,
            width: width,
            scale: kind,
            noticesHeight: 0,
            legendHeight: 60,
          );
          final ScrollableState scroll = _scrollOf(
            tester,
            find.byType(MapReadingBlockLegend),
          );
          expect(
            tester.getRect(find.byType(MapReadingBlockLegend)).height,
            closeTo(60, 0.01),
          );
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          expect(scroll.position.pixels, 0);

          await tester.drag(
            find.byType(MapReadingBlockLegend),
            const Offset(0, -80),
          );
          await tester.pumpAndSettle();

          expect(scroll.position.pixels, greaterThan(0));
        },
      );
    }
  });

  group('MapReadingBlock — ni barre de défilement, ni contrôleur primaire', () {
    // Windows seulement : `MaterialScrollBehavior` ne pose de barre que sur un
    // défilement vertical du bureau ; sous Android, le cas ne pourrait rougir
    // que sur `primary`, que celui-ci éprouve aussi.
    testWidgetsOnWindows(
      'aucune barre de défilement de bureau, primary: false sur les trois '
      'défilements',
      (WidgetTester tester) async {
        await _pumpBlock(
          tester,
          width: _windowsWidth,
          fixedHeight: 60,
          noticesHeight: 40,
          legendHeight: 60,
        );

        expect(find.byType(Scrollbar), findsNothing);
        expect(find.byType(RawScrollbar), findsNothing);
        for (final Type type in <Type>[
          MapReadingBlockFixed,
          MapReadingBlockNotices,
          MapReadingBlockLegend,
        ]) {
          final Finder scroll = find.descendant(
            of: find.byType(type),
            matching: find.byType(SingleChildScrollView),
          );
          expect(scroll, findsOneWidget, reason: '$type');
          expect(tester.widget<SingleChildScrollView>(scroll).primary, isFalse);
        }
      },
    );
  });

  group('MapReadingBlock — la carte blanche absorbe les gestes', () {
    /// Les points d'une grille sur [rect], à l'écart de [avoid].
    List<Offset> surface(Rect rect, {Rect? avoid}) => <Offset>[
      for (final double fx in <double>[0.02, 0.25, 0.5, 0.75, 0.98])
        for (final double fy in <double>[0.1, 0.5, 0.9])
          if (avoid == null ||
              !avoid
                  .inflate(2)
                  .contains(
                    Offset(
                      rect.left + rect.width * fx,
                      rect.top + rect.height * fy,
                    ),
                  ))
            Offset(rect.left + rect.width * fx, rect.top + rect.height * fy),
    ];

    _onBothPlatforms(
      'un tap et un appui long sur la surface du bloc n atteignent pas la '
      'carte dessous',
      (WidgetTester tester, double width) async {
        final _Probe probe = await _pumpBlock(tester, width: width);
        final Rect link = _linkRect(tester);

        for (final Type type in <Type>[
          MapReadingBlockFixed,
          MapReadingBlockNotices,
          MapReadingBlockLegend,
        ]) {
          final Rect rect = tester.getRect(find.byType(type));
          final List<Offset> points = surface(rect, avoid: link);
          expect(points, isNotEmpty);
          for (final Offset point in points) {
            await tester.tapAt(point);
            await tester.pump();
            await tester.longPressAt(point);
            await tester.pump();
          }
        }

        expect(probe.taps, 0, reason: 'aucun tap ne traverse la carte');
        expect(probe.longPresses, 0, reason: 'aucun appui long ne traverse');
        expect(probe.drags, 0);

        // Témoin de sensibilité : hors du bloc, la carte reçoit le tap.
        await tester.tapAt(Offset(width / 2, 950));
        expect(probe.taps, 1);
      },
    );

    _onBothPlatforms(
      'un glisser sur les avis et sur la légende n atteint pas la carte '
      'dessous',
      (WidgetTester tester, double width) async {
        final _Probe probe = await _pumpBlock(tester, width: width);

        for (final Type type in <Type>[
          MapReadingBlockNotices,
          MapReadingBlockLegend,
        ]) {
          await tester.drag(find.byType(type), const Offset(0, -30));
          await tester.pumpAndSettle();
        }

        expect(probe.drags, 0);
      },
    );

    for (final (Type type, double noticesHeight, double legendHeight)
        in <(Type, double, double)>[
          (MapReadingBlockNotices, 40, 0),
          (MapReadingBlockLegend, 0, 60),
        ]) {
      _onBothPlatforms(
        'un cran de molette sur ${type == MapReadingBlockNotices ? 'les avis' : 'la légende'} '
        'les fait défiler et ne traverse pas jusqu à la carte',
        (WidgetTester tester, double width) async {
          final _Probe probe = await _pumpBlock(
            tester,
            width: width,
            noticesHeight: noticesHeight,
            legendHeight: legendHeight,
          );
          final ScrollableState scroll = _scrollOf(tester, find.byType(type));
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          final Offset point = tester.getCenter(find.byType(type));

          final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(pointer.hover(point));
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
          await tester.pumpAndSettle();

          expect(scroll.position.pixels, greaterThan(0));
          expect(probe.wheels, 0);
        },
      );
    }
  });

  group('MapReadingBlock — peinture', () {
    const Color mapColor = Color(0xFF6A8CAF);
    const int pad = 24;

    /// Un cas de peinture, rejoué sur les deux plateformes, avec les VRAIES
    /// ombres : `TestWidgetsFlutterBinding` les remplace par des aplats
    /// (`debugDisableShadows`), et le flou est ce que le cas éprouve. Le drapeau
    /// est rétabli AVANT la vérification des invariants de fin de test — un
    /// `addTearDown` passerait trop tard.
    void onBothPixels(String description, _Body body) {
      _onBothPlatforms(description, (WidgetTester tester, double width) async {
        final bool previous = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await body(tester, width);
        } finally {
          debugDisableShadows = previous;
        }
      });
    }

    /// Un rendu en pixels : ce qui se voit, pas la liste des appels de dessin.
    Future<_Shot> shot(
      WidgetTester tester, {
      required double width,
      required List<Widget> pieces,
      required double totalHeight,
      List<double?>? pileHeights,
      Future<void> Function()? beforeCapture,
    }) async {
      _setView(tester, Size(width + 2 * pad, totalHeight + 2 * pad + 100));
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: mapColor,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: width,
                    child: pileHeights == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: pieces,
                          )
                        : _Pile(heights: pileHeights, children: pieces),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await beforeCapture?.call();
      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final ByteData? data = await tester.runAsync<ByteData?>(() async {
        final ui.Image image = await boundary.toImage();
        return image.toByteData();
      });
      return _Shot(data!, boundary.size.width.round());
    }

    /// Une pile à hauteurs FRACTIONNAIRES (le cas des coutures) : la partie
    /// fixe, des avis blancs, la légende. Contenus laissés vides ou à gauche,
    /// pour que les colonnes de droite soient de la carte blanche seule.
    List<Widget> seamPieces(double width, {required List<double> heights}) =>
        <Widget>[
          SizedBox(
            height: heights[0],
            child: _fixed(link: const SizedBox.shrink()),
          ),
          SizedBox(
            height: heights[1],
            child: const MapReadingBlockNotices(
              notices: <Widget>[SizedBox(height: 40)],
            ),
          ),
          SizedBox(height: heights[2], child: _legend()),
        ];

    /// Les trois hauteurs de la pile fractionnaire, de somme entière.
    List<double> fractional(double width) =>
        width < 400 ? <double>[200.4, 60.3, 47.3] : <double>[150.4, 60.3, 47.3];

    void expectNear(
      int actual,
      int expected, {
      required String reason,
      int tolerance = 3,
    }) => expect(
      (actual - expected).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$reason : $actual (attendu $expected ± $tolerance)',
    );

    onBothPixels(
      'aucune couture à la jonction de deux pièces, à hauteurs fractionnaires '
      ': fond, bord et ombre continus',
      (WidgetTester tester, double width) async {
        final List<double> heights = fractional(width);
        final double total = heights.fold(0, (double a, double b) => a + b);
        expect(total, closeTo(total.roundToDouble(), 1e-9));
        final _Shot image = await shot(
          tester,
          width: width,
          pieces: seamPieces(width, heights: heights),
          totalHeight: total,
        );
        final int w = width.round();
        final List<double> junctions = <double>[
          pad + heights[0],
          pad + heights[0] + heights[1],
        ];

        // Le fond : blanc PUR, opaque, sur les rangées de part et d'autre de
        // chaque jonction — une couture laisserait voir la carte.
        final List<List<int>> whiteColumns = <List<int>>[
          <int>[(w * 0.55).round(), (w * 0.65).round(), (w * 0.75).round()],
          <int>[w - 14, w - 10, w - 6],
        ];
        for (int j = 0; j < junctions.length; j++) {
          for (int dy = -3; dy <= 3; dy++) {
            for (final int x in whiteColumns[j]) {
              final int y = junctions[j].floor() + dy;
              expect(
                image.at(pad + x, y),
                const _Rgba(255, 255, 255, 255),
                reason: 'jonction ${j + 1}, x=$x, y=$y : fond du bloc',
              );
            }
          }
        }

        // Le bord : la colonne gauche et la colonne droite gardent la couleur
        // du bord sur toute la hauteur, jonctions comprises.
        const _Rgba border = _Rgba(0xC9, 0xCF, 0xC4, 255);
        for (final int x in <int>[pad, pad + w - 1]) {
          for (final double junction in junctions) {
            for (int dy = -3; dy <= 3; dy++) {
              final int y = junction.floor() + dy;
              final _Rgba got = image.at(x, y);
              expectNear(got.r, border.r, reason: 'bord x=$x y=$y (rouge)');
              expectNear(got.g, border.g, reason: 'bord x=$x y=$y (vert)');
              expectNear(got.b, border.b, reason: 'bord x=$x y=$y (bleu)');
              expect(got.a, 255);
            }
          }
        }

        // L'ombre : hors de la carte, à gauche et à droite, la même à la
        // jonction qu'au milieu de la partie fixe — ni trait clair ni bande
        // plus sombre là où deux ombres se recouvriraient.
        for (final int x in <int>[pad - 3, pad + w + 2]) {
          final _Rgba reference = image.at(x, pad + 60);
          expect(
            reference.r,
            lessThan(0x6A),
            reason: 'l ombre existe (le témoin de sensibilité du test)',
          );
          for (final double junction in junctions) {
            for (int dy = -3; dy <= 3; dy++) {
              final int y = junction.floor() + dy;
              final _Rgba got = image.at(x, y);
              expectNear(
                got.r,
                reference.r,
                tolerance: 2,
                reason: 'ombre x=$x y=$y',
              );
              expectNear(
                got.g,
                reference.g,
                tolerance: 2,
                reason: 'ombre x=$x y=$y',
              );
              expectNear(
                got.b,
                reference.b,
                tolerance: 2,
                reason: 'ombre x=$x y=$y',
              );
            }
          }
        }
      },
    );

    /// Un rendu à la densité [pixelRatio], le bord gauche de la carte à
    /// [left] px logiques de celui du rendu (24 ou 24,4 : entre deux pixels
    /// physiques à 1,25 et à 2,625), les pièces directement sous une mise en
    /// page, peintes de bas en haut si [reversed].
    Future<_Shot> shotAt(
      WidgetTester tester, {
      required double width,
      required double pixelRatio,
      required double left,
      bool reversed = false,
    }) async {
      final List<double> heights = fractional(width);
      _setView(
        tester,
        Size(
          left + width + pad,
          heights.reduce((a, b) => a + b) + 2 * pad + 60,
        ),
      );
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: mapColor,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(left, 24, 24, 24),
                  child: SizedBox(
                    width: width,
                    child: _Pile(
                      heights: heights,
                      reversed: reversed,
                      children: <Widget>[
                        _fixed(link: const SizedBox.shrink()),
                        const MapReadingBlockNotices(
                          notices: <Widget>[SizedBox(height: 40)],
                        ),
                        _legend(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final (ByteData, int)? got = await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        return ((await image.toByteData())!, image.width);
      });
      return _Shot(got!.$1, got.$2);
    }

    /// L'écart maximal, sur un canal (sur 255), entre les pixels des colonnes
    /// [x0] à [x0] + 8 aux rangées de part et d'autre de la jonction [junction]
    /// (logique, ± 4 rangées) et ceux de la rangée de référence [referenceRow]
    /// du MÊME rendu : un trait ou une ombre continus sont les mêmes partout.
    int seamGap(
      _Shot image, {
      required int x0,
      required double junction,
      required double pixelRatio,
      required int referenceRow,
    }) {
      int worst = 0;
      final int row = (junction * pixelRatio).floor();
      for (int dy = -4; dy <= 4; dy++) {
        for (int x = x0; x < x0 + 9; x++) {
          final _Rgba got = image.at(x, row + dy);
          final _Rgba reference = image.at(x, referenceRow);
          worst = <int>[
            worst,
            (got.r - reference.r).abs(),
            (got.g - reference.g).abs(),
            (got.b - reference.b).abs(),
          ].reduce((int a, int b) => a > b ? a : b);
        }
      }
      return worst;
    }

    /// La carte tient à la densité [pixelRatio] : aux jonctions, le bord et
    /// l'ombre sont ceux du reste de la carte, aux colonnes du bord gauche
    /// (jonction des avis seulement : la légende y a du contenu) et du bord
    /// droit.
    void expectSeamless(
      _Shot image, {
      required double width,
      required double pixelRatio,
      required double left,
    }) {
      final List<double> heights = fractional(width);
      final int referenceRow = ((24 + heights[0] + 30) * pixelRatio).round();
      final int leftX = (left * pixelRatio).floor() - 4;
      final int rightX = ((left + width) * pixelRatio).floor() - 5;
      for (final (String side, int x0, double junction)
          in <(String, int, double)>[
            ('gauche, avis', leftX, 24 + heights[0]),
            ('droite, avis', rightX, 24 + heights[0]),
            ('droite, légende', rightX, 24 + heights[0] + heights[1]),
          ]) {
        expect(
          seamGap(
            image,
            x0: x0,
            junction: junction,
            pixelRatio: pixelRatio,
            referenceRow: referenceRow,
          ),
          lessThanOrEqualTo(6),
          reason:
              'jonction $side, densité $pixelRatio, bord à $left : un trait ou '
              'une ombre plus clairs ou plus sombres à la jonction',
        );
      }
    }

    for (final (double pixelRatio, double left) in <(double, double)>[
      (1.25, 24.4),
      (2.625, 24.4),
    ]) {
      onBothPixels(
        'aucune couture aux densités des cibles (rendu à $pixelRatio, bord à '
        '$left) : le bord et l ombre de la jonction sont ceux du reste de la '
        'carte',
        (WidgetTester tester, double width) async {
          expectSeamless(
            await shotAt(
              tester,
              width: width,
              pixelRatio: pixelRatio,
              left: left,
            ),
            width: width,
            pixelRatio: pixelRatio,
            left: left,
          );
        },
      );
    }

    for (final (double pixelRatio, double left) in <(double, double)>[
      (1, 24),
      (2.625, 24.4),
    ]) {
      onBothPixels(
        'aucune couture si les pièces se peignent de bas en haut (rendu à '
        '$pixelRatio, bord à $left)',
        (WidgetTester tester, double width) async {
          expectSeamless(
            await shotAt(
              tester,
              width: width,
              pixelRatio: pixelRatio,
              left: left,
              reversed: true,
            ),
            width: width,
            pixelRatio: pixelRatio,
            left: left,
          );
        },
      );
    }

    /// Vrai si le pixel est de la carte (ou de son ombre) : ni blanc ni trait.
    bool isMap(_Rgba p) => p.b < 0xC0 && p.a == 255;

    void expectRoundedCorners(
      _Shot image, {
      required int width,
      required int bottom,
      required bool top,
    }) {
      // Hors de l'arc de rayon 8 (centre à 8 px des deux côtés) : le pixel (d, d)
      // en est tout entier hors pour d = 0 et 1 — la carte, pas la pointe d'un
      // angle droit.
      for (final int d in <int>[0, 1]) {
        if (top) {
          expect(
            isMap(image.at(pad + d, pad + d)),
            isTrue,
            reason: 'angle haut gauche, d=$d',
          );
          expect(
            isMap(image.at(pad + width - 1 - d, pad + d)),
            isTrue,
            reason: 'angle haut droit, d=$d',
          );
        }
        expect(
          isMap(image.at(pad + d, bottom - 1 - d)),
          isTrue,
          reason: 'angle bas gauche, d=$d',
        );
        expect(
          isMap(image.at(pad + width - 1 - d, bottom - 1 - d)),
          isTrue,
          reason: 'angle bas droit, d=$d',
        );
      }
    }

    void expectBottomEdge(
      _Shot image, {
      required int width,
      required int bottom,
      required int x,
    }) {
      const _Rgba border = _Rgba(0xC9, 0xCF, 0xC4, 255);
      final _Rgba line = image.at(x, bottom - 1);
      expectNear(line.r, border.r, reason: 'trait du bas (rouge)');
      expectNear(line.g, border.g, reason: 'trait du bas (vert)');
      expectNear(line.b, border.b, reason: 'trait du bas (bleu)');
      // Sous le bord, l'ombre : plus sombre que la carte.
      expect(
        image.at(x, bottom + 1).r,
        lessThan(0x6A),
        reason: 'ombre sous le bord bas',
      );
      // Et la carte reste blanche au-dessus du trait.
      expect(image.at(x, bottom - 3), const _Rgba(255, 255, 255, 255));
    }

    onBothPixels(
      'les trois pièces : un rayon en haut, un rayon en bas, le trait du bas '
      'et son ombre',
      (WidgetTester tester, double width) async {
        final List<double> heights = fractional(width);
        final double total = heights.fold(0, (double a, double b) => a + b);
        final _Shot image = await shot(
          tester,
          width: width,
          pieces: seamPieces(width, heights: heights),
          totalHeight: total,
        );
        final int w = width.round();
        final int bottom = pad + total.round();

        expectRoundedCorners(image, width: w, bottom: bottom, top: true);
        expectBottomEdge(image, width: w, bottom: bottom, x: pad + w - 20);
      },
    );

    for (final (String name, List<double> heights, bool noticesEmpty)
        in <(String, List<double>, bool)>[
          (
            'légende à 0 : la dernière pièce visible, les avis, ferme la '
                'carte',
            <double>[150, 60, 0],
            false,
          ),
          (
            'légende et avis à 0 : la partie fixe ferme la carte',
            <double>[150, 0, 0],
            true,
          ),
        ]) {
      for (final bool direct in <bool>[false, true]) {
        onBothPixels(
          '$name (${direct ? 'pièces enfants directes de la mise en page' : 'pièces sous des SizedBox'})'
          ' : rayon et trait du bas, ombre dessous',
          (WidgetTester tester, double width) async {
            final double fixedHeight = width < 400 ? 200 : heights[0];
            final double total = fixedHeight + heights[1] + heights[2];
            final List<Widget> pieces = <Widget>[
              _fixed(link: const SizedBox.shrink()),
              MapReadingBlockNotices(
                notices: noticesEmpty
                    ? const <Widget>[]
                    : const <Widget>[SizedBox(height: 40)],
              ),
              _legend(),
            ];
            final List<double> sizes = <double>[
              fixedHeight,
              heights[1],
              heights[2],
            ];
            final _Shot image = await shot(
              tester,
              width: width,
              pieces: direct
                  ? pieces
                  : <Widget>[
                      for (int i = 0; i < pieces.length; i++)
                        SizedBox(height: sizes[i], child: pieces[i]),
                    ],
              pileHeights: direct ? sizes : null,
              totalHeight: total,
            );
            final int w = width.round();
            final int bottom = pad + total.round();

            expectRoundedCorners(image, width: w, bottom: bottom, top: true);
            expectBottomEdge(
              image,
              width: w,
              bottom: bottom,
              x: pad + (w * 0.6).round(),
            );
          },
        );
      }
    }

    onBothPixels(
      'le contenu est rogné par le rayon : un contenu à angles droits ne '
      'dépasse pas de la carte aux angles du bas',
      (WidgetTester tester, double width) async {
        final double fixedHeight = width < 400 ? 200 : 150;
        final _Shot image = await shot(
          tester,
          width: width,
          pieces: <Widget>[
            _fixed(link: const SizedBox.shrink()),
            const MapReadingBlockNotices(
              notices: <Widget>[
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
              ],
            ),
            _legend(),
          ],
          pileHeights: <double?>[fixedHeight, 60, 0],
          totalHeight: fixedHeight + 60,
        );
        final int w = width.round();
        final int bottom = pad + fixedHeight.round() + 60;

        // Les avis ferment la carte (légende à 0) : leur aplat rouge, aux
        // angles droits, est rogné par l'arc ; il remplit le reste du bas.
        expect(image.at(pad + w ~/ 2, bottom - 3), const _Rgba(255, 0, 0, 255));
        for (final int d in <int>[0, 1]) {
          expect(image.at(pad + d, bottom - 1 - d).r, lessThan(0xB0));
          expect(image.at(pad + w - 1 - d, bottom - 1 - d).r, lessThan(0xB0));
        }
      },
    );

    onBothPixels('l anneau de focus d une entrée de coin n est rogné que de son angle '
        'carré', (WidgetTester tester, double width) async {
      final _Shot image = await shot(
        tester,
        width: width,
        pieces: <Widget>[SizedBox(height: 200, child: _fixed())],
        totalHeight: 200,
        beforeCapture: () async {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        },
      );
      expect(
        focusedWithin(
          tester,
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
        ),
        isTrue,
        reason: 'le premier arrêt de tabulation est l entrée de coin',
      );
      const _Rgba ring = _Rgba(0x15, 0x65, 0xC0, 255);

      // Les deux traits de l'anneau (3 px, dans la boîte de l'entrée), au
      // milieu des côtés haut et gauche, puis jusqu'à l'arc du coin : (6, 2) et
      // (2, 6) sont tout entiers dans le rayon, bord de la carte non compris.
      for (final int offset in <int>[1, 2]) {
        expect(image.at(pad + 40, pad + offset), ring, reason: 'haut');
        expect(image.at(pad + offset, pad + 30), ring, reason: 'gauche');
      }
      expect(image.at(pad + 6, pad + 2), ring, reason: 'haut, coin');
      expect(image.at(pad + 2, pad + 6), ring, reason: 'gauche, coin');
      // Seul l'angle carré de l'anneau, hors de l'arc, est rogné.
      expect(isMap(image.at(pad, pad)), isTrue);
      expect(isMap(image.at(pad + 1, pad + 1)), isTrue);
    });
  });
}

/// Un pixel RGBA.
class _Rgba {
  const _Rgba(this.r, this.g, this.b, this.a);

  final int r;
  final int g;
  final int b;
  final int a;

  @override
  bool operator ==(Object other) =>
      other is _Rgba &&
      r == other.r &&
      g == other.g &&
      b == other.b &&
      a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'rgba($r, $g, $b, $a)';
}

/// Les pixels d'un rendu, lus par [at].
class _Shot {
  const _Shot(this.data, this.width);

  final ByteData data;
  final int width;

  _Rgba at(int x, int y) {
    final int offset = (y * width + x) * 4;
    return _Rgba(
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    );
  }
}

/// Une mise en page minimale qui pose ses enfants l'un sous l'autre, sans
/// écart, à la hauteur serrée donnée (ou à leur hauteur naturelle si `null`) :
/// ce que fera `D1`, sans enveloppe autour des pièces. [reversed] les PEINT de
/// bas en haut : la carte ne doit pas dépendre de l'ordre de peinture.
class _Pile extends MultiChildRenderObjectWidget {
  const _Pile({
    required this.heights,
    required super.children,
    this.reversed = false,
  });

  final List<double?> heights;
  final bool reversed;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPile(heights, reversed: reversed);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderPile renderObject,
  ) {
    renderObject
      ..heights = heights
      ..reversed = reversed;
  }
}

class _PileParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPile extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PileParentData> {
  _RenderPile(this._heights, {required this._reversed});

  List<double?> _heights;
  bool _reversed;

  set heights(List<double?> value) {
    _heights = value;
    markNeedsLayout();
  }

  set reversed(bool value) {
    _reversed = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PileParentData) {
      child.parentData = _PileParentData();
    }
  }

  @override
  void performLayout() {
    final double width = constraints.maxWidth;
    double y = 0;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final double? height = _heights[index];
      child.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: height ?? 0,
          maxHeight: height ?? double.infinity,
        ),
        parentUsesSize: true,
      );
      (child.parentData! as _PileParentData).offset = Offset(0, y);
      y += child.size.height;
      index++;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_reversed) {
      defaultPaint(context, offset);
      return;
    }
    RenderBox? child = lastChild;
    while (child != null) {
      context.paintChild(
        child,
        offset + (child.parentData! as _PileParentData).offset,
      );
      child = childBefore(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// Verrouille le cadre commun des fiches (`S3` d'Ergonomie, arbitrage 3, spec
// § 6.1) : [SheetFrame], son en-tête épinglé (nature, étoile, fermeture, puis
// « ⚠ Avertissement », puis l'avis d'échec d'écriture du favori) et son corps
// défilant, et [NoMinIntrinsicHeight], l'enveloppe qui annonce 0 de hauteur
// intrinsèque minimale.
//
// Ce que la mise en page de la carte interroge (`D1`) : `getMinIntrinsicHeight`
// = l'en-tête seul, `getMaxIntrinsicHeight` = la fiche entière, et depuis `D7`
// (arbitrages 18 et 19) `sheetFeaturedHeightOf` = l'en-tête et la mesure mise
// en avant du corps. Aucun `LayoutBuilder`, aucun `ListView` dans le cadre : un
// défilement s'y fait par `SingleChildScrollView`, qui sait répondre aux
// intrinsèques.
//
// Les mesures sont en Roboto, chargée depuis le SDK (`test/support/roboto.dart`) ;
// sous Windows c'est un substitut de Segoe UI, jamais sa mesure.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../support/android_platform.dart';
import '../../support/focus.dart';
import '../../support/roboto.dart';
import '../../support/windows_platform.dart';

/// La clé de fermeture que l'appelant (une fiche) fournit au cadre.
const Key _closeKey = Key('test-sheet-close');

/// Posée sur le premier élément du corps : sa position dit où est le corps.
const Key _bodyTopKey = Key('test-sheet-body-top');

const String _nature = 'Station hydrométrique · K447001001';

const FavoriteStar _emptyStar = FavoriteStar(filled: false, enabled: true);

/// La dépendance que ces mesures exercent : `sheetFeaturedHeightOf` retombe en
/// silence sur l'en-tête si la forme interne de `Material` change.
const String _featuredDependency =
    'sheetFeaturedHeightOf traverse le Material (RenderPhysicalModel, '
    '_RenderInkFeatures) par RenderProxyBox : si Flutter change cette forme, '
    "la hauteur retombe sur l'en-tête (lib/features/shared/sheet_frame.dart)";

/// Un corps de [height] pixels exactement, son premier élément en haut.
Widget _body(double height) => SizedBox(
  height: height,
  child: const Align(
    alignment: Alignment.topLeft,
    child: Text('Corps de la fiche', key: _bodyTopKey),
  ),
);

SheetFrame _frame({
  String nature = _nature,
  VoidCallback? onClose,
  Widget? body,
  FavoriteStar? star,
  VoidCallback? onToggle,
  String? warningExtraText,
  ScrollController? controller,
}) {
  return SheetFrame(
    nature: nature,
    closeButtonKey: _closeKey,
    onClose: onClose ?? () {},
    body: body ?? _body(100),
    warningExtraText: warningExtraText,
    favoriteStar: star,
    onToggleFavorite: star == null ? null : (onToggle ?? () {}),
    bodyScrollController: controller,
  );
}

/// Le cadre posé sous une hauteur BORNÉE à [maxHeight] (et une largeur de
/// [width]) : c'est la fiche du bas ou le panneau latéral de la carte.
Future<void> _pumpBounded(
  WidgetTester tester,
  Widget frame, {
  double width = 400,
  double maxHeight = 400,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: frame,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Le cadre posé sous une hauteur NON bornée : un `SingleChildScrollView`
/// parent, comme la zone des fiches avant `D5`.
Future<void> _pumpUnbounded(
  WidgetTester tester,
  Widget frame, {
  double width = 400,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: frame),
          ),
        ),
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

RenderBox _frameBox(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(SheetFrame));

void main() {
  setUpAll(chargerRoboto);

  group('SheetFrame — l\'en-tête', () {
    testWidgetsOnWindows(
      'nature, étoile et fermeture sur la même rangée ; « ⚠ Avertissement » '
      'dessous ; le corps ensuite',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(star: _emptyStar));

        final Rect nature = _rect(tester, find.text(_nature));
        final Rect star = _rect(tester, find.byKey(favoriteStarButtonKey));
        final Rect close = _rect(tester, find.byKey(_closeKey));
        final Rect warning = _rect(tester, find.byKey(warningLinkKey));
        final Rect body = _rect(tester, find.byKey(sheetFrameBodyKey));
        final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));

        // De gauche à droite : nature, étoile, fermeture.
        expect(nature.right, lessThanOrEqualTo(star.left));
        expect(star.right, lessThanOrEqualTo(close.left));
        // 8 px entre « ajouter/retirer un favori » et « fermer » : deux
        // actions opposées ne se touchent pas. L'écart de l'amendement `S7b`
        // (vertical : l'étoile sous la fermeture), transposé sur la rangée —
        // choix de la boucle principale sur le croquis du § 6.1.
        expect(close.left - star.right, closeTo(8, 0.01));
        // Une seule rangée : mêmes centres verticaux.
        expect(nature.center.dy, closeTo(star.center.dy, 0.5));
        expect(star.center.dy, closeTo(close.center.dy, 0.01));
        // « ⚠ Avertissement » dessous, dans l'en-tête ; le corps après.
        expect(warning.top, greaterThanOrEqualTo(star.bottom));
        expect(warning.top, greaterThanOrEqualTo(close.bottom));
        expect(warning.bottom, lessThanOrEqualTo(header.bottom + 0.01));
        expect(body.top, greaterThanOrEqualTo(header.bottom - 0.01));
        expect(
          _rect(tester, find.byKey(_bodyTopKey)).top,
          greaterThan(warning.bottom),
        );
      },
    );

    testWidgetsOnWindows('sans étoile : la nature et la fermeture', (
      WidgetTester tester,
    ) async {
      await _pumpBounded(tester, _frame());

      expect(find.byType(FavoriteStarButton), findsNothing);
      final Rect nature = _rect(tester, find.text(_nature));
      final Rect close = _rect(tester, find.byKey(_closeKey));
      expect(nature.right, lessThanOrEqualTo(close.left));
      expect(nature.center.dy, closeTo(close.center.dy, 0.5));
      // La fermeture est à l'extrémité droite de la rangée.
      final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));
      expect(close.right, lessThanOrEqualTo(header.right));
      expect(header.right - close.right, lessThan(16));
      // Les 8 px ne viennent qu'avec l'étoile : sans elle, aucune boîte vide
      // avant la fermeture — la nature court jusqu'à elle, et la fermeture est
      // collée au bord droit du contenu de l'en-tête (ses 12 de marge).
      expect(close.left - nature.right, closeTo(0, 0.01));
      expect(header.right - close.right, closeTo(12, 0.01));
    });

    testWidgetsOnWindows(
      "un filet sous l'en-tête, sur toute la largeur du cadre, sans ajouter "
      'de hauteur',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(star: _emptyStar, body: _body(2000)));

        // Le plus proche `DecoratedBox` au-dessus de l'en-tête : un
        // `DecoratedBox` et non un `Container`, qui ajouterait l'épaisseur de
        // la bordure en marge et grandirait l'en-tête.
        final Finder filet = find
            .ancestor(
              of: find.byKey(sheetFrameHeaderKey),
              matching: find.byType(DecoratedBox),
            )
            .first;
        final BoxDecoration decoration =
            tester.widget<DecoratedBox>(filet).decoration as BoxDecoration;
        final Border border = decoration.border! as Border;
        expect(border.bottom.color, const Color(0xFFC9CFC4));
        expect(border.bottom.width, 1);
        expect(border.bottom.style, BorderStyle.solid);
        expect(border.top, BorderSide.none);
        expect(border.left, BorderSide.none);
        expect(border.right, BorderSide.none);

        // Sous l'en-tête, pleine largeur du cadre ; même boîte que l'en-tête.
        final Rect frame = _rect(tester, find.byType(SheetFrame));
        final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));
        final Rect line = _rect(tester, filet);
        expect(line.left, closeTo(frame.left, 0.01));
        expect(line.right, closeTo(frame.right, 0.01));
        expect(line.bottom, closeTo(header.bottom, 0.01));
        expect(line.top, closeTo(header.top, 0.01));
        expect(line.height, closeTo(header.height, 0.01));
        // Le corps commence sous le filet.
        expect(
          _rect(tester, find.byKey(sheetFrameBodyKey)).top,
          greaterThanOrEqualTo(line.bottom - 0.01),
        );
      },
    );

    testWidgetsOnWindows(
      'la nature : 12, gras, #3A4148 ; à 240 de large elle se replie, sans '
      'ellipse',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(star: _emptyStar), width: 240);

        final Text text = tester.widget<Text>(find.text(_nature));
        expect(text.style?.fontSize, 12);
        expect(text.style?.fontWeight, FontWeight.bold);
        expect(text.style?.color, const Color(0xFF3A4148));

        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.text(_nature),
        );
        final Set<double> lineTops = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: _nature.length),
            )
            .map((TextBox box) => box.top)
            .toSet();
        expect(lineTops.length, greaterThanOrEqualTo(2));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'le « ⚠ Avertissement » reçoit la phrase propre à la fiche',
      (WidgetTester tester) async {
        await _pumpBounded(
          tester,
          _frame(warningExtraText: 'Mesure du 27 août 2026.'),
        );

        expect(
          tester.widget<WarningLink>(find.byType(WarningLink)).extraText,
          'Mesure du 27 août 2026.',
        );

        await _pumpBounded(tester, _frame());
        expect(
          tester.widget<WarningLink>(find.byType(WarningLink)).extraText,
          isNull,
        );
      },
    );

    testWidgetsOnWindows(
      'une étoile sans onToggleFavorite est refusée (assert)',
      (WidgetTester tester) async {
        expect(
          () => SheetFrame(
            nature: _nature,
            closeButtonKey: _closeKey,
            onClose: () {},
            body: const SizedBox(),
            favoriteStar: _emptyStar,
          ),
          throwsAssertionError,
        );
      },
    );
  });

  group('SheetFrame — l\'en-tête est épinglé', () {
    testWidgetsOnWindows(
      'un corps de 2 000 px dans un cadre borné à 400 : le corps défile de '
      '600, l\'en-tête ne bouge pas',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await _pumpBounded(
          tester,
          _frame(star: _emptyStar, body: _body(2000), controller: controller),
        );

        expect(tester.getSize(find.byType(SheetFrame)).height, 400);
        final Rect headerBefore = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        );
        final Rect starBefore = _rect(
          tester,
          find.byKey(favoriteStarButtonKey),
        );
        final Rect closeBefore = _rect(tester, find.byKey(_closeKey));
        final double bodyTopBefore = _rect(tester, find.byKey(_bodyTopKey)).top;

        controller.jumpTo(600);
        await tester.pump();

        expect(controller.offset, 600);
        expect(_rect(tester, find.byKey(sheetFrameHeaderKey)), headerBefore);
        expect(_rect(tester, find.byKey(favoriteStarButtonKey)), starBefore);
        expect(_rect(tester, find.byKey(_closeKey)), closeBefore);
        // Le corps, lui, a bien défilé.
        expect(
          _rect(tester, find.byKey(_bodyTopKey)).top,
          closeTo(bodyTopBefore - 600, 0.01),
        );
      },
    );

    testWidgetsOnWindows('un glisser sur le corps le défile, pas l\'en-tête', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pumpBounded(
        tester,
        _frame(body: _body(2000), controller: controller),
      );
      final Rect headerBefore = _rect(tester, find.byKey(sheetFrameHeaderKey));

      await tester.drag(find.byKey(sheetFrameBodyKey), const Offset(0, -200));
      await tester.pump();

      expect(controller.offset, closeTo(200, 1));
      expect(_rect(tester, find.byKey(sheetFrameHeaderKey)), headerBefore);
    });

    testWidgetsOnWindows(
      'bodyScrollController.jumpTo(0) ramène le corps en haut',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await _pumpBounded(
          tester,
          _frame(body: _body(2000), controller: controller),
        );
        final double topAtRest = _rect(tester, find.byKey(_bodyTopKey)).top;

        controller.jumpTo(600);
        await tester.pump();
        expect(_rect(tester, find.byKey(_bodyTopKey)).top, lessThan(topAtRest));

        controller.jumpTo(0);
        await tester.pump();

        expect(controller.offset, 0);
        expect(_rect(tester, find.byKey(_bodyTopKey)).top, topAtRest);
      },
    );

    testWidgetsOnWindows('aucune barre de défilement de bureau sur le corps', (
      WidgetTester tester,
    ) async {
      await _pumpBounded(tester, _frame(body: _body(2000)));

      expect(find.byType(Scrollbar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SheetFrame),
          matching: find.byType(RawScrollbar),
        ),
        findsNothing,
      );
    });

    testWidgetsOnWindows(
      'un corps plus court que la place : la fiche a la hauteur de son '
      'contenu',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(body: _body(100)));

        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        final double body = _rect(tester, find.byKey(sheetFrameBodyKey)).height;
        expect(tester.getSize(find.byType(SheetFrame)).height, lessThan(400));
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(header + body, 0.01),
        );
      },
    );
  });

  group('SheetFrame — sous une hauteur non bornée', () {
    testWidgetsOnWindows(
      'aucune erreur de rendu ; la fiche a la hauteur de son contenu',
      (WidgetTester tester) async {
        await _pumpUnbounded(
          tester,
          _frame(star: _emptyStar, body: _body(300)),
        );

        expect(tester.takeException(), isNull);
        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        final double body = _rect(tester, find.byKey(sheetFrameBodyKey)).height;
        expect(body, greaterThanOrEqualTo(300));
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(header + body, 0.01),
        );
      },
    );

    testWidgetsOnWindows(
      'un corps de 2 000 px est posé entier : il ne défile pas dans le cadre',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await _pumpUnbounded(
          tester,
          _frame(body: _body(2000), controller: controller),
        );

        expect(tester.takeException(), isNull);
        expect(controller.position.maxScrollExtent, 0);
        expect(
          _rect(tester, find.byKey(sheetFrameBodyKey)).height,
          greaterThanOrEqualTo(2000),
        );
      },
    );
  });

  group('SheetFrame — les hauteurs intrinsèques', () {
    testWidgetsOnWindows(
      'min = l\'en-tête seul ; max = l\'en-tête et le corps entier',
      (WidgetTester tester) async {
        // La fiche entière, mesurée sous une hauteur non bornée.
        await _pumpUnbounded(
          tester,
          _frame(star: _emptyStar, body: _body(2000)),
        );
        final double whole = tester.getSize(find.byType(SheetFrame)).height;
        final double headerWhole = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;

        // Puis bornée : les intrinsèques ne dépendent pas de la hauteur reçue.
        await _pumpBounded(tester, _frame(star: _emptyStar, body: _body(2000)));
        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        final double width = tester.getSize(find.byType(SheetFrame)).width;

        expect(header, closeTo(headerWhole, 0.01));
        expect(
          _frameBox(tester).getMinIntrinsicHeight(width),
          closeTo(header, 0.5),
        );
        expect(
          _frameBox(tester).getMaxIntrinsicHeight(width),
          closeTo(whole, 0.5),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'avec l\'avis d\'échec sous l\'en-tête, min suit l\'en-tête',
      (WidgetTester tester) async {
        const FavoriteStar failed = FavoriteStar(
          filled: false,
          enabled: true,
          writeFailed: true,
        );
        await _pumpBounded(tester, _frame(star: failed, body: _body(2000)));

        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        final double width = tester.getSize(find.byType(SheetFrame)).width;
        expect(
          _frameBox(tester).getMinIntrinsicHeight(width),
          closeTo(header, 0.5),
        );
        expect(
          _frameBox(tester).getMaxIntrinsicHeight(width),
          greaterThan(header + 2000),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'à 240 de large, la nature se replie : min suit encore l\'en-tête',
      (WidgetTester tester) async {
        await _pumpBounded(
          tester,
          _frame(star: _emptyStar, body: _body(2000)),
          width: 240,
        );

        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        final double width = tester.getSize(find.byType(SheetFrame)).width;
        expect(width, 240);
        expect(
          _frameBox(tester).getMinIntrinsicHeight(width),
          closeTo(header, 0.5),
        );
      },
    );
  });

  group('SheetFrame — la mesure mise en avant (arbitrages 18 et 19)', () {
    const Key featuredKey = Key('test-sheet-featured');
    const Key restKey = Key('test-sheet-rest');
    const Key wrapKey = Key('test-sheet-wrap');

    /// Un corps dont la mesure mise en avant fait [featured] px, suivie de
    /// [rest] px qui cèdent (`NoMinIntrinsicHeight`).
    Widget featuredBody({double featured = 120, double rest = 500}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(key: featuredKey, height: featured, width: 50),
        NoMinIntrinsicHeight(
          child: SizedBox(key: restKey, height: rest, width: 50),
        ),
      ],
    );

    double featuredOf(WidgetTester tester, double width) =>
        sheetFeaturedHeightOf(_frameBox(tester), width);

    testWidgetsOnWindows('trois hauteurs : l\'en-tête seul, l\'en-tête et la mesure mise en avant '
        '(marge haute du corps comprise, jusqu\'au bas de la mesure), la fiche '
        'entière', (WidgetTester tester) async {
      await _pumpUnbounded(
        tester,
        _frame(star: _emptyStar, body: featuredBody()),
      );

      final Rect frame = _rect(tester, find.byType(SheetFrame));
      final double header = _rect(
        tester,
        find.byKey(sheetFrameHeaderKey),
      ).height;
      final double width = frame.width;
      expect(
        _frameBox(tester).getMinIntrinsicHeight(width),
        closeTo(header, 0.01),
      );
      expect(
        featuredOf(tester, width),
        closeTo(header + 8 + 120, 0.01),
        reason: _featuredDependency,
      );
      expect(
        featuredOf(tester, width),
        closeTo(
          _rect(tester, find.byKey(featuredKey)).bottom - frame.top,
          0.01,
        ),
        reason:
            'la mesure mise en avant finit au bas de l’élément ; $_featuredDependency',
      );
      expect(
        _frameBox(tester).getMaxIntrinsicHeight(width),
        closeTo(frame.height, 0.01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgetsOnWindows(
      'un corps qui ne marque rien (un état « en cours ») : la mesure mise en '
      'avant est le corps entier, sans la marge basse ; un corps qui cède tout : '
      'l\'en-tête seul',
      (WidgetTester tester) async {
        await _pumpUnbounded(tester, _frame(body: _body(100)));
        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;
        expect(featuredOf(tester, 400), closeTo(header + 8 + 100, 0.01));

        await _pumpUnbounded(
          tester,
          _frame(body: NoMinIntrinsicHeight(child: _body(100))),
        );
        expect(featuredOf(tester, 400), closeTo(header, 0.01));
      },
    );

    testWidgetsOnWindows(
      'posé à sa hauteur mise en avant : l\'en-tête et la mesure entiers, le '
      'reste défile sous l\'en-tête',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await _pumpUnbounded(tester, _frame(body: featuredBody()));
        final double featured = featuredOf(tester, 400);

        await _pumpBounded(
          tester,
          _frame(body: featuredBody(), controller: controller),
          maxHeight: featured,
        );

        expect(tester.takeException(), isNull);
        final Rect frame = _rect(tester, find.byType(SheetFrame));
        expect(frame.height, closeTo(featured, 0.01));
        final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));
        expect(header.top, closeTo(frame.top, 0.01));
        expect(
          _rect(tester, find.byKey(featuredKey)).bottom,
          closeTo(frame.bottom, 0.01),
          reason: 'la mesure mise en avant finit au bas de la fiche',
        );
        expect(
          _rect(tester, find.byKey(restKey)).top,
          greaterThanOrEqualTo(frame.bottom - 0.01),
          reason: 'ce qui la suit est sous la fiche, à faire défiler',
        );
        expect(controller.position.maxScrollExtent, greaterThan(0));
      },
    );

    testWidgetsOnWindows(
      'posé sous sa hauteur mise en avant : l\'en-tête reste entier, le corps '
      'défile, aucune erreur de rendu (arbitrage 19)',
      (WidgetTester tester) async {
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await _pumpUnbounded(tester, _frame(body: featuredBody()));
        final double header = _rect(
          tester,
          find.byKey(sheetFrameHeaderKey),
        ).height;

        await _pumpBounded(
          tester,
          _frame(body: featuredBody(), controller: controller),
          maxHeight: header + 30,
        );

        expect(tester.takeException(), isNull);
        expect(
          _rect(tester, find.byKey(sheetFrameHeaderKey)).height,
          closeTo(header, 0.01),
        );
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(header + 30, 0.01),
        );
        expect(controller.position.maxScrollExtent, greaterThan(0));
      },
    );

    testWidgetsOnWindows(
      'sheetFeaturedHeightOf traverse une enveloppe qui garde les hauteurs de '
      'son enfant ; une enveloppe qui les change, ou une boîte quelconque, '
      'rend sa hauteur repliée',
      (WidgetTester tester) async {
        await _pumpUnbounded(
          tester,
          SizedBox(
            key: wrapKey,
            child: _frame(body: featuredBody()),
          ),
        );
        final RenderBox wrap = tester.renderObject<RenderBox>(
          find.byKey(wrapKey),
        );
        expect(
          sheetFeaturedHeightOf(wrap, 400),
          closeTo(featuredOf(tester, 400), 0.01),
        );

        await _pumpUnbounded(
          tester,
          SizedBox(
            key: wrapKey,
            height: 50,
            child: _frame(body: featuredBody()),
          ),
        );
        expect(
          sheetFeaturedHeightOf(
            tester.renderObject<RenderBox>(find.byKey(wrapKey)),
            400,
          ),
          50,
        );
        expect(
          sheetFeaturedHeightOf(
            tester.renderObject<RenderBox>(find.byKey(restKey)),
            400,
          ),
          500,
        );
      },
    );
  });

  group('SheetFrame — la première rangée de l’en-tête (arbitrage 24, D8)', () {
    // En deçà des quatre tailles, l'en-tête de la fiche cède — la zone des
    // fiches le rogne par le bas —, jamais sous sa première rangée : nature,
    // étoile et fermeture restent entières et touchables. Sa hauteur, lue
    // par `sheetFirstRowHeightOf`, est la marge haute de l'en-tête et la
    // rangée.

    /// Le bas de la première rangée : celui de la rangée qui porte la
    /// fermeture, compté depuis le haut du cadre.
    double basDeLaRangee(WidgetTester tester) =>
        _rect(
          tester,
          find
              .ancestor(of: find.byKey(_closeKey), matching: find.byType(Row))
              .first,
        ).bottom -
        _rect(tester, find.byType(SheetFrame)).top;

    for (final (String, double) cas in <(String, double)>[
      ('100 %', 1),
      ('200 %, la nature sur plusieurs lignes', 2),
    ]) {
      testWidgetsOnAndroid('Android : ${cas.$1} — la marge haute et la rangée '
          'nature · étoile · fermeture, sous l’en-tête entier', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(cas.$2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 360,
                      child: _frame(
                        star: const FavoriteStar(
                          filled: false,
                          enabled: true,
                          writeFailed: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final double premiere = sheetFirstRowHeightOf(_frameBox(tester), 360);
        expect(premiere, closeTo(basDeLaRangee(tester), 0.01));
        expect(premiere, greaterThanOrEqualTo(12 + minimumTapTarget - 0.01));
        expect(
          premiere,
          lessThan(_rect(tester, find.byKey(sheetFrameHeaderKey)).height),
        );
      });
    }

    testWidgetsOnWindows('sheetFirstRowHeightOf traverse une enveloppe qui '
        'garde les hauteurs ; une boîte quelconque rend sa hauteur repliée — '
        'son en-tête ne cède pas', (WidgetTester tester) async {
      const Key enveloppe = Key('test-sheet-first-row-wrap');
      await _pumpUnbounded(
        tester,
        SizedBox(
          key: enveloppe,
          child: _frame(star: _emptyStar),
        ),
      );
      expect(
        sheetFirstRowHeightOf(
          tester.renderObject<RenderBox>(find.byKey(enveloppe)),
          400,
        ),
        closeTo(sheetFirstRowHeightOf(_frameBox(tester), 400), 0.01),
      );
      expect(
        sheetFirstRowHeightOf(
          tester.renderObject<RenderBox>(find.byKey(_bodyTopKey)),
          400,
        ),
        closeTo(
          tester
              .renderObject<RenderBox>(find.byKey(_bodyTopKey))
              .getMinIntrinsicHeight(400),
          0.01,
        ),
      );
    });
  });

  group('SheetFrame — l\'avis d\'échec d\'écriture du favori', () {
    testWidgetsOnWindows(
      'étoile pleine en échec : la phrase du retrait, sous l\'en-tête, en '
      'région vivante',
      (WidgetTester tester) async {
        await _pumpBounded(
          tester,
          _frame(
            star: const FavoriteStar(
              filled: true,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );

        final Finder text = find.text("Le favori n'a pas pu être retiré.");
        expect(text, findsOneWidget);
        expect(favoriteRemoveFailedText, "Le favori n'a pas pu être retiré.");
        expect(
          tester
              .getSemantics(text)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        // Sous « ⚠ Avertissement », dans l'en-tête épinglé.
        expect(
          _rect(tester, text).top,
          greaterThanOrEqualTo(
            _rect(tester, find.byKey(warningLinkKey)).bottom,
          ),
        );
        final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));
        expect(
          _rect(tester, text).bottom,
          lessThanOrEqualTo(header.bottom + 0.01),
        );
      },
    );

    testWidgetsOnWindows('étoile vide en échec : la phrase de l\'ajout', (
      WidgetTester tester,
    ) async {
      await _pumpBounded(
        tester,
        _frame(
          star: const FavoriteStar(
            filled: false,
            enabled: true,
            writeFailed: true,
          ),
        ),
      );

      expect(favoriteWriteFailedText, "Le favori n'a pas pu être enregistré.");
      expect(
        find.text("Le favori n'a pas pu être enregistré."),
        findsOneWidget,
      );
      expect(find.text("Le favori n'a pas pu être retiré."), findsNothing);
    });

    testWidgetsOnWindows('sans échec, ou sans étoile : aucune phrase', (
      WidgetTester tester,
    ) async {
      await _pumpBounded(tester, _frame(star: _emptyStar));
      expect(find.byType(FavoriteWriteFailedNotice), findsNothing);

      await _pumpBounded(tester, _frame());
      expect(find.byType(FavoriteWriteFailedNotice), findsNothing);
    });

    testWidgetsOnWindows('l\'avis reste en place quand le corps défile', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pumpBounded(
        tester,
        _frame(
          star: const FavoriteStar(
            filled: true,
            enabled: true,
            writeFailed: true,
          ),
          body: _body(2000),
          controller: controller,
        ),
      );
      final Finder notice = find.byType(FavoriteWriteFailedNotice);
      final Rect before = _rect(tester, notice);

      controller.jumpTo(600);
      await tester.pump();

      expect(_rect(tester, notice), before);
    });
  });

  group('SheetFrame — la fermeture et l\'étoile', () {
    testWidgetsOnWindows('un tap sur la fermeture appelle onClose une fois', (
      WidgetTester tester,
    ) async {
      int closed = 0;
      int toggled = 0;
      await _pumpBounded(
        tester,
        _frame(
          star: _emptyStar,
          onClose: () => closed++,
          onToggle: () => toggled++,
        ),
      );

      await tester.tap(find.byKey(_closeKey));
      await tester.pump();

      expect(closed, 1);
      expect(toggled, 0);

      await tester.tap(find.byKey(favoriteStarButtonKey));
      await tester.pump();
      expect(toggled, 1);
      expect(closed, 1);
    });

    testWidgetsOnWindows(
      'la fermeture : « Fermer la fiche », bouton, cible de 44 x 44',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame());

        expect(sheetCloseLabel, 'Fermer la fiche');
        expect(
          tester.getSemantics(find.byKey(_closeKey)),
          matchesSemantics(
            label: 'Fermer la fiche',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getSize(find.byKey(_closeKey)), const Size(44, 44));
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgetsOnAndroid(
      'Android : la fermeture et l\'étoile mesurent 48 x 48',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(star: _emptyStar));

        expect(tester.getSize(find.byKey(_closeKey)), const Size(48, 48));
        expect(
          tester.getSize(find.byKey(favoriteStarButtonKey)),
          Size(minimumTapTarget, minimumTapTarget),
        );
        expect(minimumTapTarget, 48);
      },
    );

    testWidgetsOnWindows(
      'Tab : l\'étoile est un arrêt de tabulation, la fermeture n\'en est '
      'pas un (Échap ferme), puis « ⚠ Avertissement »',
      (WidgetTester tester) async {
        await _pumpBounded(tester, _frame(star: _emptyStar));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byType(FavoriteStarButton)), isTrue);

        // La fermeture se trouve, dans l'arbre, entre l'étoile et le lien :
        // si elle était un arrêt, le deuxième Tab s'y poserait.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byType(WarningLink)), isTrue);
        expect(focusedWithin(tester, find.byKey(_closeKey)), isFalse);
        expect(
          find.descendant(
            of: find.byKey(_closeKey),
            matching: find.byType(KeyboardFocusRing),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(_closeKey),
            matching: find.byType(Focus),
          ),
          findsNothing,
        );
      },
    );
  });

  group('SheetFrame — à 360 × 640 et 200 %', () {
    testWidgetsOnAndroid(
      'Android : « Station hydrométrique · K447001001 » se replie sans '
      'chevaucher l\'étoile ni la fermeture',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);

        await _pumpBounded(
          tester,
          _frame(star: _emptyStar, body: _body(2000), controller: controller),
          width: 360,
          maxHeight: 640,
        );

        expect(tester.takeException(), isNull);
        final Rect nature = _rect(tester, find.text(_nature));
        final Rect star = _rect(tester, find.byKey(favoriteStarButtonKey));
        final Rect close = _rect(tester, find.byKey(_closeKey));
        final Rect header = _rect(tester, find.byKey(sheetFrameHeaderKey));

        // La ligne se replie : au moins deux lignes de texte.
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.text(_nature),
        );
        final Set<double> lineTops = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: _nature.length),
            )
            .map((TextBox box) => box.top)
            .toSet();
        expect(lineTops.length, greaterThanOrEqualTo(2));
        // Sans chevaucher l'étoile ni la fermeture, ni déborder du cadre.
        expect(nature.right, lessThanOrEqualTo(star.left));
        expect(star.right, lessThanOrEqualTo(close.left));
        expect(close.left - star.right, closeTo(8, 0.01));
        expect(nature.left, greaterThanOrEqualTo(header.left));
        expect(close.right, lessThanOrEqualTo(header.right));
        expect(nature.overlaps(star), isFalse);
        expect(nature.overlaps(close), isFalse);
        expect(star.overlaps(close), isFalse);
        // L'en-tête reste entier et laisse de la place au corps.
        final Rect warning = _rect(tester, find.byKey(warningLinkKey));
        expect(warning.top, greaterThanOrEqualTo(nature.bottom));
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(640, 0.01),
        );
        expect(
          _rect(tester, find.byKey(sheetFrameBodyKey)).height,
          greaterThan(0),
        );
        // Les intrinsèques restent lisibles à cette échelle.
        expect(
          _frameBox(tester).getMinIntrinsicHeight(360),
          closeTo(header.height, 0.5),
        );
        // Le max, que la carte lit pour savoir si une fiche est ouverte, passe
        // aussi par le chemin de défilement propre à Android (indicateur
        // d'étirement) : il dit l'en-tête et le corps entier.
        final double maxIntrinsic = _frameBox(tester)
            .getMaxIntrinsicHeight(360);
        expect(maxIntrinsic, greaterThan(header.height + 2000));
        expect(tester.takeException(), isNull);

        // Et c'est la hauteur de la fiche posée sans limite, à cette échelle.
        await _pumpUnbounded(
          tester,
          _frame(star: _emptyStar, body: _body(2000)),
          width: 360,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(maxIntrinsic, 0.5),
        );
      },
    );
  });

  group('NoMinIntrinsicHeight', () {
    const Key childKey = Key('no-min-child');

    testWidgetsOnWindows(
      'annonce 0 de hauteur minimale et transmet largeurs, hauteur maximale '
      'et mise en page',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: NoMinIntrinsicHeight(
                child: SizedBox(key: childKey, width: 70, height: 100),
              ),
            ),
          ),
        );

        final RenderBox box = tester.renderObject<RenderBox>(
          find.byType(NoMinIntrinsicHeight),
        );
        expect(box.getMinIntrinsicHeight(70), 0);
        expect(box.getMaxIntrinsicHeight(70), 100);
        expect(box.getMinIntrinsicWidth(100), 70);
        expect(box.getMaxIntrinsicWidth(100), 70);
        expect(box.getDryLayout(const BoxConstraints()), const Size(70, 100));
        expect(
          tester.getSize(find.byType(NoMinIntrinsicHeight)),
          const Size(70, 100),
        );
        expect(tester.getSize(find.byKey(childKey)), const Size(70, 100));
      },
    );

    testWidgetsOnWindows('l\'enfant reste touchable', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: NoMinIntrinsicHeight(
              child: GestureDetector(
                onTap: () => taps++,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(key: childKey, width: 70, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(taps, 1);
    });

    testWidgetsOnWindows(
      'sous IntrinsicHeight, la hauteur reste celle de l\'enfant (le max '
      'décide), sans erreur',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: IntrinsicHeight(
                child: NoMinIntrinsicHeight(
                  child: SizedBox(key: childKey, width: 70, height: 100),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(childKey)).height, 100);
      },
    );
  });
}

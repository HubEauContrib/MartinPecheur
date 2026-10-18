// Verrouille le panneau de la fiche tronçon (F3 de T4, cadrage § 8) : l'ordre
// nom → encart → niveau → citation → date → bouton, les textes mot pour mot,
// l'inconnu sans citation, le bulletin, l'avis de lien non ouvert.
//
// Depuis `F3` d'Ergonomie (cadrage du 2026-10-17, § 6.1, § 6.4, critère 13), la
// fiche est dans le cadre commun (`SheetFrame`) : un en-tête épinglé — « Tronçon
// Vigicrues », la fermeture, puis « ⚠ Avertissement » avec le texte de crue —
// et un corps qui défile, dans l'ORDRE DE T4 (nom, encart, niveau, citations,
// date, bulletin, adresse, avis de lien). Sans étoile : T5. Seul changement
// d'ordre : « ⚠ Avertissement » passe avant le nom.
//
// Niveaux 2 à 4 : cas construits, niveaux jamais observés en production
// (`VC-04`) ; seul le vert est une valeur publiée constatée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_warning_card.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/unopened_link_notice.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

final DateTime _date = DateTime.utc(2026, 10, 14, 13, 55, 31);

FloodSection _section(FloodVigilanceLevel level) => FloodSection(
  code: FloodSectionCode('TRC1'),
  name: 'Blavet aval',
  territoryCode: '12',
  level: level,
  lines: <List<GeoPoint>>[
    <GeoPoint>[
      GeoPoint(latitude: 47.8, longitude: -3.2),
      GeoPoint(latitude: 47.9, longitude: -3.1),
    ],
  ],
);

FloodSheetState _open(FloodVigilanceLevel level, {int unopened = 0}) =>
    FicheTronconOuverte(
      section: _section(level),
      informationDate: _date,
      unopenedBulletinCount: unopened,
    );

/// Le panneau dans une zone sans hauteur bornée (le défilement de la zone des
/// fiches d'avant `D5`), ou, avec [height], dans une zone de cette hauteur : le
/// corps du cadre défile alors sous l'en-tête épinglé (la fiche du bas, le
/// panneau latéral).
Widget _host(
  FloodSheetState state, {
  VoidCallback? onClose,
  VoidCallback? onOpenBulletin,
  double? height,
  ScrollController? bodyScrollController,
}) {
  final Widget panel = FloodSheetPanel(
    state: state,
    onClose: onClose ?? () {},
    onOpenBulletin: onOpenBulletin ?? () {},
    utcOffsetOf: (_) => const Duration(hours: 2),
    bodyScrollController: bodyScrollController,
  );
  return MaterialApp(
    home: Scaffold(
      body: height == null
          ? SingleChildScrollView(child: panel)
          : Align(
              alignment: Alignment.topLeft,
              child: SizedBox(height: height, child: panel),
            ),
    ),
  );
}

void main() {
  test('floodSheetNature : « Tronçon Vigicrues », le texte de T4 nommé', () {
    expect(floodSheetNature, 'Tronçon Vigicrues');
  });

  testWidgetsOnWindows('fermée : rien à l’écran', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const FicheTronconFermee()));

    expect(find.byType(SheetFrame), findsNothing);
    expect(find.byType(FloodWarningCard), findsNothing);
    expect(find.byKey(floodSheetCloseButtonKey), findsNothing);
  });

  testWidgetsOnWindows(
    'ouverte : nature < « ⚠ Avertissement » < nom < encart < niveau < '
    'citation < date < bouton',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_open(const Orange())));

      final double header = tester.getTopLeft(find.text(floodSheetNature)).dy;
      final double warning = tester.getTopLeft(find.byKey(warningLinkKey)).dy;
      final double name = tester
          .getTopLeft(find.textContaining('Blavet aval'))
          .dy;
      final double card = tester.getTopLeft(find.byType(FloodWarningCard)).dy;
      final double level = tester
          .getTopLeft(find.text(floodVigilanceTitle(const Orange())))
          .dy;
      final double quote = tester
          .getTopLeft(find.text('« ${publishedFloodLegend(const Orange())} »'))
          .dy;
      final double date = tester
          .getTopLeft(find.textContaining('Information de vigilance du'))
          .dy;
      final double button = tester
          .getTopLeft(find.byKey(floodBulletinButtonKey))
          .dy;

      expect(header, lessThan(warning));
      expect(warning, lessThan(name));
      expect(name, lessThan(card));
      expect(card, lessThan(level));
      expect(level, lessThan(quote));
      expect(quote, lessThan(date));
      expect(date, lessThan(button));
    },
  );

  testWidgetsOnWindows(
    'orange (cas construit, niveau jamais observé en production — VC-04) : '
    'titre, jauge, deux citations exactes, source',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host(_open(const Orange())));

      expect(find.text('Vigilance orange'), findsOneWidget);
      expect(
        tester.widget<FloodLevelGauge>(find.byType(FloodLevelGauge)).level,
        const Orange(),
      );
      expect(
        tester.widget<FloodLevelGauge>(find.byType(FloodLevelGauge)).size,
        26,
      );
      expect(
        find.text('« Risque de crue génératrice de débordements importants »'),
        findsOneWidget,
      );
      expect(
        find.text(
          '« Risque de crue génératrice de débordements importants '
          'susceptibles d’avoir un impact significatif sur la vie collective '
          'et la sécurité des biens et des personnes. »',
        ),
        findsOneWidget,
      );
      expect(find.text('— Vigicrues'), findsOneWidget);
    },
  );

  testWidgetsOnWindows('vert : la légende seule, aucune explication', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_open(const Vert())));

    expect(find.text('Vigilance verte'), findsOneWidget);
    expect(
      find.text('« Pas de vigilance particulière requise »'),
      findsOneWidget,
    );
    expect(find.text('— Vigicrues'), findsOneWidget);
    expect(find.textContaining('«'), findsOneWidget);
  });

  testWidgetsOnWindows('inconnu : le titre, la phrase, aucune citation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_open(const NiveauCruesInconnu(7))));

    expect(find.text('Niveau de vigilance non reconnu'), findsOneWidget);
    expect(find.text(floodUnknownLevelText), findsOneWidget);
    expect(
      floodUnknownLevelText,
      'Vigicrues a publié un niveau que cette application ne sait pas lire. '
      'Le bulletin sur www.vigicrues.gouv.fr fait foi.',
    );
    expect(find.textContaining('«'), findsNothing);
    expect(find.text('— Vigicrues'), findsNothing);
    expect(
      tester.widget<FloodLevelGauge>(find.byType(FloodLevelGauge)).level,
      const NiveauCruesInconnu(7),
    );
    expect(
      tester.widget<FloodLevelGauge>(find.byType(FloodLevelGauge)).size,
      26,
    );
  });

  testWidgetsOnWindows('la date est celle de la carte, à l’heure locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_open(const Vert())));

    expect(
      find.text('Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES'),
      findsOneWidget,
    );
  });

  testWidgetsOnWindows('le bouton du bulletin, l’adresse sélectionnable', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      _host(_open(const Vert()), onOpenBulletin: () => calls++),
    );

    expect(
      find.text('Lire le bulletin sur www.vigicrues.gouv.fr'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(floodBulletinButtonKey));
    expect(calls, 1);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      find.text('https://www.vigicrues.gouv.fr/bulletin_local/12'),
      findsOneWidget,
    );
    expect(find.byType(UnopenedLinkNotice), findsNothing);
  });

  testWidgetsOnWindows('lien non ouvert : l’avis, nouveau à chaque échec', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_open(const Vert(), unopened: 1)));
    expect(find.byType(UnopenedLinkNotice), findsOneWidget);
    expect(find.text(unopenedLinkText), findsOneWidget);
    final Key? first = tester
        .widget<UnopenedLinkNotice>(find.byType(UnopenedLinkNotice))
        .key;

    await tester.pumpWidget(_host(_open(const Vert(), unopened: 2)));
    final Key? second = tester
        .widget<UnopenedLinkNotice>(find.byType(UnopenedLinkNotice))
        .key;

    expect(first, const ValueKey<int>(1));
    expect(second, const ValueKey<int>(2));
    expect(second, isNot(first));
  });

  testWidgetsOnWindows('l’encart est présent et sans repli (BR-015)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_open(const Jaune())));

    expect(find.text(floodWarningHeadline), findsOneWidget);
    expect(find.text(floodWarningBody), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgetsOnWindows(
    'la fenêtre « ⚠ Avertissement » porte le texte de crue',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_open(const Vert())));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      expect(find.text(floodWarningWindowText), findsOneWidget);
    },
  );

  testWidgetsOnWindows('le bouton de fermeture appelle onClose, sans étoile', (
    WidgetTester tester,
  ) async {
    int closed = 0;
    await tester.pumpWidget(
      _host(_open(const Vert()), onClose: () => closed++),
    );

    await tester.tap(find.byKey(floodSheetCloseButtonKey));
    expect(closed, 1);
    expect(find.byType(FavoriteStarButton), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  group('FloodSheetPanel — le cadre commun (F3 d’Ergonomie, spec § 6.1, § 6.4, '
      'critère 13)', () {
    testWidgetsOnWindows(
      'l’en-tête épinglé porte la nature, « ⚠ Avertissement » et la '
      'fermeture ; le corps porte le nom, l’encart et le bulletin',
      (WidgetTester tester) async {
        await tester.pumpWidget(_host(_open(const Orange(), unopened: 1)));

        expect(find.byType(SheetFrame), findsOneWidget);
        final Finder header = find.byKey(sheetFrameHeaderKey);
        expect(
          find.descendant(of: header, matching: find.text(floodSheetNature)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.byType(WarningLink)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: header,
            matching: find.byKey(floodSheetCloseButtonKey),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: header,
            matching: find.textContaining('Blavet aval'),
          ),
          findsNothing,
          reason: 'le nom publié est dans le corps, après l’en-tête',
        );

        final Finder body = find.byKey(sheetFrameBodyKey);
        for (final Finder inBody in <Finder>[
          find.textContaining('Blavet aval'),
          find.byType(FloodWarningCard),
          find.byType(FloodLevelGauge),
          find.byKey(floodBulletinButtonKey),
          find.byType(SelectableText),
          find.byType(UnopenedLinkNotice),
        ]) {
          expect(
            find.descendant(of: body, matching: inBody),
            findsOneWidget,
            reason: inBody.toString(),
          );
        }
      },
    );

    testWidgetsOnWindows(
      'la fenêtre de l’en-tête ajoute le texte de crue, sous le texte général',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(_open(const Jaune())));

        await tester.tap(
          find.descendant(
            of: find.byKey(sheetFrameHeaderKey),
            matching: find.byKey(warningLinkKey),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(floodWarningWindowText), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'le corps défile sous l’en-tête, qui ne bouge pas ; le contrôleur reçu '
      'pilote ce défilement',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final ScrollController controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _host(
            _open(const Orange()),
            height: 300,
            bodyScrollController: controller,
          ),
        );

        final Rect headerBefore = tester.getRect(
          find.byKey(sheetFrameHeaderKey),
        );
        final Rect closeBefore = tester.getRect(
          find.byKey(floodSheetCloseButtonKey),
        );
        expect(controller.hasClients, isTrue);
        expect(controller.position.maxScrollExtent, greaterThan(0));
        expect(
          controller.position.pixels,
          0,
          reason: 'une fiche s’ouvre en haut',
        );

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();

        expect(tester.getRect(find.byKey(sheetFrameHeaderKey)), headerBefore);
        expect(
          tester.getRect(find.byKey(floodSheetCloseButtonKey)),
          closeBefore,
        );
        expect(
          tester.getTopLeft(find.textContaining('Blavet aval')).dy,
          lessThan(headerBefore.bottom),
          reason: 'le nom, premier du corps, est remonté sous l’en-tête',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'l’avis de lien non ouvert se montre dans le corps défilant, sous '
      'l’en-tête',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(_open(const Orange(), unopened: 1), height: 300),
        );
        await tester.pump();

        final Rect header = tester.getRect(find.byKey(sheetFrameHeaderKey));
        final Rect notice = tester.getRect(find.byType(UnopenedLinkNotice));
        expect(notice.bottom, lessThanOrEqualTo(300 + 0.5));
        expect(notice.top, greaterThanOrEqualTo(header.bottom - 0.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'les intrinsèques : min = l’en-tête seul, max = la fiche entière, sans '
      'LayoutBuilder ni Viewport dans le corps',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Bornée à 300 : le cadre est plus court que sa fiche entière.
        await tester.pumpWidget(
          _host(_open(const Orange(), unopened: 1), height: 300),
        );
        final RenderBox bounded = tester.renderObject<RenderBox>(
          find.byType(SheetFrame),
        );
        final double width = bounded.size.width;
        final double header = tester
            .getSize(find.byKey(sheetFrameHeaderKey))
            .height;
        final double minIntrinsic = bounded.getMinIntrinsicHeight(width);
        final double maxIntrinsic = bounded.getMaxIntrinsicHeight(width);

        expect(minIntrinsic, closeTo(header, 0.5));
        expect(maxIntrinsic, greaterThan(300));
        expect(tester.takeException(), isNull);

        // Non bornée : la fiche se pose à sa hauteur entière, celle que
        // l’intrinsèque maximale annonçait.
        await tester.pumpWidget(_host(_open(const Orange(), unopened: 1)));
        expect(
          tester.getSize(find.byType(SheetFrame)).height,
          closeTo(maxIntrinsic, 0.5),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgetsOnWindows(
      'un niveau non reconnu garde le même cadre et la même fenêtre',
      (WidgetTester tester) async {
        await tester.pumpWidget(_host(_open(const NiveauCruesInconnu(7))));

        expect(find.byType(SheetFrame), findsOneWidget);
        final SheetFrame frame = tester.widget<SheetFrame>(
          find.byType(SheetFrame),
        );
        expect(frame.nature, floodSheetNature);
        expect(frame.warningExtraText, floodWarningWindowText);
        expect(frame.favoriteStar, isNull);
        expect(frame.onToggleFavorite, isNull);
        expect(frame.closeButtonKey, floodSheetCloseButtonKey);
      },
    );
  });

  testWidgetsOnAndroid(
    'Android : fermeture et bulletin à 48 au moins, le corps défile sous '
    'l’en-tête',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(_open(const Rouge(), unopened: 1), height: 360),
      );

      expect(minimumTapTarget, 48);
      final Size close = tester.getSize(find.byKey(floodSheetCloseButtonKey));
      expect(close.width, greaterThanOrEqualTo(48));
      expect(close.height, greaterThanOrEqualTo(48));
      final Rect closeBefore = tester.getRect(
        find.byKey(floodSheetCloseButtonKey),
      );

      await tester.ensureVisible(find.byKey(floodBulletinButtonKey));
      await tester.pump();
      final Size button = tester.getSize(find.byKey(floodBulletinButtonKey));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      // Le premier défilement du corps est le sien ; l'adresse sélectionnable
      // en porte un autre, plus bas.
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(sheetFrameBodyKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(scrollable.position.pixels, greaterThan(0));
      expect(
        tester.getRect(find.byKey(floodSheetCloseButtonKey)),
        closeBefore,
        reason: 'la fermeture est dans l’en-tête épinglé',
      );
    },
  );
}

// Verrouille le panneau de la fiche tronçon (F3 de T4, cadrage § 8) : l'ordre
// nom → encart → niveau → citation → date → bouton, les textes mot pour mot,
// l'inconnu sans citation, le bulletin, l'avis de lien non ouvert.
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
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
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

Widget _host(
  FloodSheetState state, {
  VoidCallback? onClose,
  VoidCallback? onOpenBulletin,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: FloodSheetPanel(
        state: state,
        onClose: onClose ?? () {},
        onOpenBulletin: onOpenBulletin ?? () {},
        utcOffsetOf: (_) => const Duration(hours: 2),
      ),
    ),
  ),
);

void main() {
  testWidgetsOnWindows('fermée : rien à l’écran', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const FicheTronconFermee()));

    expect(find.byType(FloodWarningCard), findsNothing);
    expect(find.byKey(floodSheetCloseButtonKey), findsNothing);
  });

  testWidgetsOnWindows(
    'ouverte : nom < encart < niveau < citation < date < bouton',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_open(const Orange())));

      final double header = tester
          .getTopLeft(find.textContaining('Tronçon Vigicrues'))
          .dy;
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

      expect(header, lessThan(name));
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
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgetsOnAndroid(
    'Android : fermeture et bulletin à 48 au moins, la fiche défile',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(_open(const Rouge(), unopened: 1)));

      expect(minimumTapTarget, 48);
      final Size close = tester.getSize(find.byKey(floodSheetCloseButtonKey));
      expect(close.width, greaterThanOrEqualTo(48));
      expect(close.height, greaterThanOrEqualTo(48));

      await tester.ensureVisible(find.byKey(floodBulletinButtonKey));
      await tester.pump();
      final Size button = tester.getSize(find.byKey(floodBulletinButtonKey));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(scrollable.position.pixels, greaterThan(0));
    },
  );
}

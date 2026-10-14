// Verrouille `ScreenTitleBar` (`B1` de T3, dette 3 de T2) : la barre de titre
// des écrans pleins, une seule dans `lib/`. Retour, titre annoncé comme
// en-tête, fond et couleur du titre passés par l'écran (les couleurs d'une
// tranche ne s'importent pas depuis `lib/features/shared/`).
//
// Les écrans qui l'emploient gardent leurs propres tests, inchangés :
// `test/features/restrictions/` et `data_sources_view_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../support/android_platform.dart';
import '../../support/windows_platform.dart';

const String _titre = 'Titre de test';

Widget _banc(ScreenTitleBar barre) => MaterialApp(
  home: Scaffold(body: Column(children: <Widget>[barre])),
);

/// Le `Material` de la barre : le plus proche ancêtre du titre.
Material _materialDuTitre(WidgetTester tester, String titre) =>
    tester.widget<Material>(
      find
          .ancestor(of: find.text(titre), matching: find.byType(Material))
          .first,
    );

void main() {
  group('ScreenTitleBar', () {
    testWidgetsOnWindows('le titre est rendu, annoncé comme en-tête, avec un '
        'retour', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_banc(const ScreenTitleBar(title: _titre)));

      expect(find.text(_titre), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text(_titre))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.byType(BackButton), findsOneWidget);

      handle.dispose();
    });

    testWidgetsOnWindows('sans couleur : fond du thème, élévation 1, style '
        'titleLarge', (WidgetTester tester) async {
      await tester.pumpWidget(_banc(const ScreenTitleBar(title: _titre)));

      final Material material = _materialDuTitre(tester, _titre);
      expect(material.color, isNull);
      expect(material.elevation, 1);

      final BuildContext context = tester.element(find.text(_titre));
      expect(
        tester.widget<Text>(find.text(_titre)).style,
        Theme.of(context).textTheme.titleLarge,
      );
    });

    testWidgetsOnWindows('le fond et la couleur du titre passés sont '
        'appliqués', (WidgetTester tester) async {
      await tester.pumpWidget(
        _banc(
          const ScreenTitleBar(
            title: _titre,
            backgroundColor: Color(0xFF112233),
            titleColor: Color(0xFF445566),
          ),
        ),
      );

      expect(_materialDuTitre(tester, _titre).color, const Color(0xFF112233));
      expect(
        tester.widget<Text>(find.text(_titre)).style!.color,
        const Color(0xFF445566),
      );
    });

    testWidgetsOnWindows('le retour mesure au moins la cible minimale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_banc(const ScreenTitleBar(title: _titre)));

      expect(minimumTapTarget, 44);
      final Size retour = tester.getSize(find.byType(BackButton));
      expect(retour.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(retour.height, greaterThanOrEqualTo(minimumTapTarget));
    });

    testWidgetsOnWindows('un appui sur le retour retire la route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Accueil'))),
      );
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Scaffold(
            body: Column(children: <Widget>[ScreenTitleBar(title: _titre)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_titre), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(_titre), findsNothing);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgetsOnAndroid('Android : à 360 × 640 et 200 % de police, la barre '
        'grandit au lieu de tronquer', (WidgetTester tester) async {
      const String titre = 'Sécheresse et restrictions';
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget banc(double facteur) => MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(facteur)),
          child: child!,
        ),
        home: const Scaffold(
          body: Column(children: <Widget>[ScreenTitleBar(title: titre)]),
        ),
      );

      await tester.pumpWidget(banc(1));
      final double hauteurA100 = tester
          .getSize(find.byType(ScreenTitleBar))
          .height;

      await tester.pumpWidget(banc(2));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ScreenTitleBar)).height,
        greaterThan(hauteurA100),
      );

      final Size retour = tester.getSize(find.byType(BackButton));
      expect(retour.width, greaterThanOrEqualTo(48));
      expect(retour.height, greaterThanOrEqualTo(48));
    });
  });
}

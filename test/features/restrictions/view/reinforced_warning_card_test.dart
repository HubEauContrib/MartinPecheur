// Verrouille l'encart renforce (E4 de T2, `BR-013`, avertissement 4 sur 4) :
// deux morceaux (Q-4 (a)), une tete epinglee (titre, action) et un corps
// (texte, adresse du site public), textes IMPORTES de `warning_texts.dart`.
// L'ordre dans les six etats de l'ecran est verrouille dans
// `restrictions_screen_test.dart`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';
import 'package:martinpecheur/features/restrictions/view/reinforced_warning_card.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/windows_platform.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('tete epinglee : titre et action', () {
    testWidgets('titre et libelle importes, action appelee', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _host(ReinforcedWarningHeader(onConsultDecrees: () => calls++)),
      );
      expect(find.textContaining(reinforcedWarningHeadline), findsOneWidget);
      expect(find.text(reinforcedWarningActionLabel), findsOneWidget);

      await tester.tap(find.text(reinforcedWarningActionLabel));
      expect(calls, 1);
    });

    testWidgets('region d alerte (liveRegion)', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(ReinforcedWarningHeader(onConsultDecrees: () {})),
      );
      final SemanticsNode region = tester.getSemantics(
        find.byKey(reinforcedWarningHeaderKey),
      );
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('titre lu avant l action', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(ReinforcedWarningHeader(onConsultDecrees: () {})),
      );
      expect(
        tester.getTopLeft(find.textContaining(reinforcedWarningHeadline)).dy,
        lessThan(tester.getTopLeft(find.text(reinforcedWarningActionLabel)).dy),
      );
    });

    testWidgets('cible tactile minimale', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(ReinforcedWarningHeader(onConsultDecrees: () {})),
      );
      final Size size = tester.getSize(
        find.widgetWithText(OutlinedButton, reinforcedWarningActionLabel),
      );
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    });

    testWidgetsOnWindows('cible tactile de 44 sous Windows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(ReinforcedWarningHeader(onConsultDecrees: () {})),
      );
      final Size size = tester.getSize(
        find.widgetWithText(OutlinedButton, reinforcedWarningActionLabel),
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('corps : texte et adresse', () {
    testWidgets('corps importe en deux paragraphes, adresse selectionnable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const ReinforcedWarningBody()));
      expect(find.text(reinforcedWarningBody), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        find.textContaining(restrictionsPublicSiteUrl, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('pas de region d alerte : une seule, sur la tete', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ReinforcedWarningBody()));
      final SemanticsNode region = tester.getSemantics(
        find.byKey(reinforcedWarningBodyKey),
      );
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    testWidgets('contraste d au moins 7:1 avec le fond reel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: droughtScreenBackground,
            body: Column(
              children: <Widget>[
                ReinforcedWarningHeader(onConsultDecrees: () {}),
                const ReinforcedWarningBody(),
              ],
            ),
          ),
        ),
      );
      double ratio(Color a, Color b) {
        final double la = a.computeLuminance();
        final double lb = b.computeLuminance();
        return (la > lb ? la + 0.05 : lb + 0.05) /
            (la > lb ? lb + 0.05 : la + 0.05);
      }

      final Color background = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(reinforcedWarningHeaderKey),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(background, droughtScreenBackground);

      for (final Finder text in <Finder>[
        find.textContaining(reinforcedWarningHeadline),
        find.text(reinforcedWarningBody),
      ]) {
        final RichText rich = tester.widget<RichText>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );
        final Color? color = rich.text.style?.color;
        expect(color, isNotNull);
        expect(ratio(color!, background), greaterThanOrEqualTo(7));
      }
      final Color? address = tester
          .widget<EditableText>(find.byType(EditableText))
          .style
          .color;
      expect(ratio(address!, background), greaterThanOrEqualTo(7));
    });
  });

  group('surface verrouillee (aucun repli, fermeture ni masquage)', () {
    testWidgets('ni ExpansionTile, ni Dismissible, ni Visibility', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              ReinforcedWarningHeader(onConsultDecrees: () {}),
              const ReinforcedWarningBody(),
            ],
          ),
        ),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byType(Visibility), findsNothing);
    });

    test('les constructeurs n acceptent que onConsultDecrees et key', () {
      // Liste blanche : le fichier ne declare aucun autre parametre.
      final String source = File(
        'lib/features/restrictions/view/reinforced_warning_card.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'const ReinforcedWarningHeader\(\{([^}]*)\}\)')
            .firstMatch(source)!
            .group(1)!
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        'required this.onConsultDecrees, super.key',
      );
      expect(
        RegExp(r'const ReinforcedWarningBody\(\{([^}]*)\}\)')
            .firstMatch(source)!
            .group(1)!
            .replaceAll(',', '')
            .trim(),
        'super.key',
      );
    });

    test('aucun texte de l encart n est ecrit hors de warning_texts', () {
      final String source = File(
        'lib/features/restrictions/view/reinforced_warning_card.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('NE FONDEZ')));
      expect(source, isNot(contains("s'appliquent chez vous")));
    });
  });
}

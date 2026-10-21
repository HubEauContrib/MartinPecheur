// Verrouille [DroughtFollowUpSection] (`W1` de T5, `BR-016`) : l'interrupteur
// « Me prévenir des restrictions sécheresse » des fiches station et ONDE, sa
// règle, l'échec d'écriture et l'avertissement de suivi complet.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/drought_follow_up_section.dart';
import 'package:martinpecheur/features/shared/follow_up_toggle.dart';
import 'package:martinpecheur/features/shared/follow_up_warning_card.dart';

import '../../support/android_platform.dart';
import '../../support/focus.dart';
import '../../support/windows_platform.dart';

Future<void> _pump(
  WidgetTester tester,
  FollowUpToggle toggle,
  VoidCallback onToggle, {
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: DroughtFollowUpSection(toggle: toggle, onToggle: onToggle),
          ),
        ),
      ),
    ),
  );
}

Tristate _toggled(WidgetTester tester) => tester
    .getSemantics(find.byKey(droughtFollowUpSwitchKey))
    .flagsCollection
    .isToggled;

void main() {
  test('les textes de la section', () {
    expect(droughtFollowUpLabel, 'Me prévenir des restrictions sécheresse');
    expect(
      droughtFollowUpRule,
      "Un avis quand la gravité d'une zone d'alerte change à cet endroit, "
      "d'après $restrictionsSourceName.",
    );
  });

  group('Windows', () {
    testWidgetsOnWindows('annonce le libellé, activé selon on', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FollowUpToggle(on: false, enabled: true),
        () {},
      );
      expect(
        tester.getSemantics(find.byKey(droughtFollowUpSwitchKey)).label,
        droughtFollowUpLabel,
      );
      expect(_toggled(tester), Tristate.isFalse);

      await _pump(tester, const FollowUpToggle(on: true, enabled: true), () {});
      expect(_toggled(tester), Tristate.isTrue);
    });

    testWidgetsOnWindows('un tap, Entrée et Espace appellent onToggle', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await _pump(
        tester,
        const FollowUpToggle(on: false, enabled: true),
        () => calls++,
      );

      await tester.tap(find.byKey(droughtFollowUpSwitchKey));
      await tester.pump();
      expect(calls, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, 3);
    });

    testWidgetsOnWindows("inactive : rien n'est appelé", (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await _pump(
        tester,
        const FollowUpToggle(on: false, enabled: false),
        () => calls++,
      );

      await tester.tap(find.byKey(droughtFollowUpSwitchKey));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Inactive, la rangée reste dans l'ordre de tabulation.
      expect(
        focusedWithin(tester, find.byKey(droughtFollowUpSwitchKey)),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byKey(droughtFollowUpSwitchKey))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );

      expect(calls, 0);
    });

    testWidgetsOnWindows('writeFailed affiche la phrase', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FollowUpToggle(on: false, enabled: true, writeFailed: true),
        () {},
      );
      expect(find.text(followUpWriteFailedText), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text(followUpWriteFailedText))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await _pump(
        tester,
        const FollowUpToggle(on: false, enabled: true),
        () {},
      );
      expect(find.text(followUpWriteFailedText), findsNothing);
    });

    testWidgetsOnWindows(
      "la règle, puis l'avertissement complet, sous l'interrupteur",
      (WidgetTester tester) async {
        await _pump(
          tester,
          const FollowUpToggle(on: true, enabled: true),
          () {},
        );

        expect(find.text(droughtFollowUpRule), findsOneWidget);
        expect(find.byType(FollowUpWarningCard), findsOneWidget);
        expect(find.text(followUpWarningHeadline), findsOneWidget);
        expect(find.text(followUpWarningBody), findsOneWidget);

        final double switchBottom = tester
            .getBottomLeft(find.byKey(droughtFollowUpSwitchKey))
            .dy;
        final double ruleTop = tester
            .getTopLeft(find.text(droughtFollowUpRule))
            .dy;
        final double cardTop = tester
            .getTopLeft(find.byType(FollowUpWarningCard))
            .dy;
        expect(ruleTop, greaterThanOrEqualTo(switchBottom - 1));
        expect(cardTop, greaterThan(ruleTop));
      },
    );
  });

  group('Android à 360 × 640 et à 200 %', () {
    testWidgetsOnAndroid(
      'Android : rien n\'est coupé, la cible fait au moins 48',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await _pump(
          tester,
          const FollowUpToggle(on: true, enabled: true, writeFailed: true),
          () {},
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        final Size target = tester.getSize(
          find.byKey(droughtFollowUpSwitchKey),
        );
        expect(target.height, greaterThanOrEqualTo(48));
        expect(target.width, greaterThanOrEqualTo(48));
        for (final String text in <String>[
          droughtFollowUpLabel,
          droughtFollowUpRule,
          followUpWriteFailedText,
          followUpWarningHeadline,
          followUpWarningBody,
        ]) {
          final Finder finder = find.text(text);
          expect(finder, findsOneWidget, reason: text);
          final Rect rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: text);
          expect(rect.right, lessThanOrEqualTo(360), reason: text);
        }
      },
    );
  });
}

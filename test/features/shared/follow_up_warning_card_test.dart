// Verrouille [FollowUpWarningCard] (`W1` de T5, `BR-016`) : l'encart de suivi,
// non repliable, annoncé en priorité seulement quand [announced].
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/follow_up_warning_card.dart';

import '../../support/windows_platform.dart';

Future<void> _pump(WidgetTester tester, {bool announced = false}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: FollowUpWarningCard(announced: announced)),
    ),
  );
}

bool _isLiveRegion(WidgetTester tester) => tester
    .getSemantics(find.byKey(followUpWarningCardKey))
    .flagsCollection
    .isLiveRegion;

void main() {
  testWidgetsOnWindows('montre le titre puis le corps arbitrés', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text(followUpWarningHeadline), findsOneWidget);
    expect(find.text(followUpWarningBody), findsOneWidget);
  });

  testWidgetsOnWindows(
    'un seul nœud conteneur, annoncé seulement si announced',
    (WidgetTester tester) async {
      await _pump(tester);
      final SemanticsNode node = tester.getSemantics(
        find.byKey(followUpWarningCardKey),
      );
      // Un seul nœud : le titre et le corps y sont réunis, l'icône exclue
      // ne lui laisse aucun enfant.
      expect(node.label, contains(followUpWarningHeadline));
      expect(node.label, contains(followUpWarningBody));
      expect(node.childrenCount, 0);
      expect(_isLiveRegion(tester), isFalse);

      await _pump(tester, announced: true);
      expect(find.byKey(followUpWarningCardKey), findsOneWidget);
      expect(_isLiveRegion(tester), isTrue);
    },
  );

  testWidgetsOnWindows('aucun widget repliable, fermable ni masquable', (
    WidgetTester tester,
  ) async {
    await _pump(tester, announced: true);

    for (final Type type in <Type>[
      ExpansionTile,
      Dismissible,
      Visibility,
      IconButton,
      TextButton,
    ]) {
      expect(
        find.descendant(
          of: find.byKey(followUpWarningCardKey),
          matching: find.byType(type),
        ),
        findsNothing,
        reason: '$type',
      );
    }
  });
}

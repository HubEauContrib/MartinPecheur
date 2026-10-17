// Verrouille l'encart de crue de la fiche tronçon (F3 de T4, `BR-015`) :
// textes, absence de tout contrôle de repli, région annoncée.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_warning_card.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

Widget _host() => const MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: FloodWarningCard())),
);

void main() {
  testWidgetsOnWindows('l’encart porte le titre et le corps de BR-015', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.text(floodWarningHeadline), findsOneWidget);
    expect(find.text(floodWarningBody), findsOneWidget);
  });

  testWidgetsOnWindows('l’encart n’a aucun contrôle de repli ni de fermeture', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byType(Visibility), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgetsOnWindows('l’encart est une région annoncée', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());

    final SemanticsNode node = tester.getSemantics(
      find.byKey(floodWarningCardKey),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(node.label, contains(floodWarningHeadline));
  });

  testWidgetsOnAndroid('Android : l’encart tient à 360 × 640 sans déborder', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());

    expect(tester.takeException(), isNull);
    expect(find.text(floodWarningBody), findsOneWidget);
  });
}

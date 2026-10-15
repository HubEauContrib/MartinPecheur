// L'avis « lien non ouvert », partagé entre l'écran des restrictions et la
// fiche tronçon (F2 de T4) : même texte, région annoncée, amené dans le champ
// d'un défilement à son apparition.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/unopened_link_notice.dart';

import '../../support/windows_platform.dart';

void main() {
  testWidgetsOnWindows('l\'avis dit le texte publié', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UnopenedLinkNotice())),
    );

    expect(
      unopenedLinkText,
      "Ce lien n'a pas pu être ouvert depuis l'application. Son adresse "
      'reste affichée ci-dessus.',
    );
    expect(find.text(unopenedLinkText), findsOneWidget);
  });

  testWidgetsOnWindows('l\'avis est une région annoncée', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UnopenedLinkNotice())),
    );

    expect(
      tester.getSemantics(find.byType(UnopenedLinkNotice)),
      matchesSemantics(isLiveRegion: true, label: unopenedLinkText),
    );
    handle.dispose();
  });

  testWidgetsOnWindows(
    'l\'avis né sous la zone visible est amené dans le champ',
    (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: const Column(
                children: <Widget>[
                  SizedBox(height: 3000),
                  UnopenedLinkNotice(),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      final Rect notice = tester.getRect(find.byType(UnopenedLinkNotice));
      final Rect screen =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      expect(screen.overlaps(notice), isTrue);
      expect(notice.bottom, lessThanOrEqualTo(screen.bottom));
    },
  );
}

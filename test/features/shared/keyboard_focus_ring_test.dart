// Verrouille [KeyboardFocusRing] : focalisable et activable au clavier
// (Entrée/Espace), et son anneau de focus VISIBLE — relecture du
// commanditaire du 2026-09-23 (🔴 2) : `DecoratedBox` peint sa décoration en
// ARRIÈRE-PLAN par défaut, recouverte par tout contenu opaque (le fond plein
// d'une puce sélectionnée, un bouton, une tuile de carte). Sans
// `position: DecorationPosition.foreground`, l'anneau existe dans l'arbre
// mais ne se voit jamais — un défaut qu'aucun test ne verrouillait avant
// celui-ci (`grep -rn "DecorationPosition.foreground" test/` rendait vide).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';

void main() {
  group('KeyboardFocusRing — l anneau de focus est peint EN PREMIER PLAN '
      '(🔴 2, relecture du 2026-09-23)', () {
    testWidgets("la DecoratedBox porteuse de l'anneau a "
        'position == DecorationPosition.foreground', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardFocusRing(
              onActivate: () {},
              child: Container(
                // Un fond OPAQUE, comme une puce sélectionnée ou une
                // tuile de carte : c'est précisément ce qui recouvrait
                // l'anneau avant ce correctif, tant qu'il restait peint
                // en arrière-plan.
                color: Colors.black,
                width: 44,
                height: 44,
              ),
            ),
          ),
        ),
      );

      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );

      expect(
        box.position,
        DecorationPosition.foreground,
        reason:
            'sans ce réglage, `DecoratedBox` peint la décoration SOUS '
            "[child] — le Container opaque de ce test la masquerait "
            'entièrement, focus ou non',
      );
    });

    testWidgets(
      'le contour devient visible (couleur non transparente) une fois le '
      'focus obtenu',
      (WidgetTester tester) async {
        final FocusNode probe = FocusNode();
        addTearDown(probe.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  // Un `Focus` neutre pour pouvoir en sortir explicitement
                  // (`unfocus`) et constater l'état SANS focus.
                  Focus(focusNode: probe, child: const SizedBox()),
                  KeyboardFocusRing(
                    onActivate: () {},
                    child: const SizedBox(width: 44, height: 44),
                  ),
                ],
              ),
            ),
          ),
        );

        BoxDecoration decorationOf() =>
            tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
                as BoxDecoration;

        expect(
          decorationOf().border?.top.color,
          Colors.transparent,
          reason: 'sans focus, aucun contour visible',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          decorationOf().border?.top.color,
          isNot(Colors.transparent),
          reason: 'le focus doit rendre le contour visible',
        );
      },
    );
  });
}

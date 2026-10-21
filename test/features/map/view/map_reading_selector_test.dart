// Verrouille [MapReadingSelector] (`S1` d'Ergonomie, cadrage du 2026-10-17) :
// le sélecteur à quatre entrées — trois lectures, puis l'interrupteur
// « Restrictions » —, chacune un pictogramme, un titre et un sous-titre
// annoncés ensemble (critère 2, textes du § 11.2).
//
// La grille est un `RenderObject` : le nombre de colonnes est le plus grand
// de 4, 2, 1 pour lequel aucun mot de titre n'est coupé (`PD5`), et elle
// efface tous ses sous-titres quand elle est posée sous sa hauteur entière
// (repli 4, local). Les deux hauteurs intrinsèques sont celles qu'une pièce
// ultérieure (`allocateMapLayout`, `S5` ; `RenderMapLayout`, `D1`)
// interrogera.
//
// Les mesures sont faites en ROBOTO, chargée depuis le SDK Flutter
// (`FLUTTER_ROOT`) et enregistrée aussi sous « Segoe UI » (contrainte
// globale du plan d'Ergonomie) : en police de test, chaque glyphe mesure un
// cadratin et « Restrictions » ne tiendrait jamais en quatre colonnes à
// 480 px. Chargeur : `chargerRoboto` (`test/support/roboto.dart`) ; si la
// police manque, le fichier échoue — jamais de repli silencieux.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

/// Largeur du bloc au téléphone : 360 − 2 × 8.
const double _phoneBlockWidth = 344;

/// Les clés des quatre entrées, dans l'ordre attendu.
final List<Key> _entryKeys = <Key>[
  for (final MapScaleKind kind in MapScaleKind.values)
    ValueKey<MapScaleKind>(kind),
  mapDesignationChipKey,
];

/// Titre et sous-titre attendus de chaque entrée, dans l'ordre.
const List<(String, String)> _expectedTexts = <(String, String)>[
  ('Écoulement', 'observé sur le terrain'),
  ('Débit', "relatif à l'historique"),
  ('Vigilance crues', 'publiée par Vigicrues'),
  ('Restrictions', 'arrêtés préfectoraux'),
];

Future<void> _pumpSelector(
  WidgetTester tester, {
  MapScaleKind scale = MapScaleKind.ecoulement,
  void Function(MapScaleKind kind)? onSelect,
  bool designationMode = false,
  VoidCallback? onToggle,
  bool withToggle = true,
  double width = 480,
  double textScale = 1,
  double? height,
}) {
  final Widget selector = MapReadingSelector(
    scale: scale,
    onSelect: onSelect ?? (MapScaleKind kind) {},
    designationMode: designationMode,
    onToggleDesignationMode: withToggle ? (onToggle ?? () {}) : null,
  );
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: Size(width, 800),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: height, child: selector),
          ),
        ),
      ),
    ),
  );
}

/// La boîte de la grille : le premier `RenderObject` du sélecteur.
RenderBox _grid(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(MapReadingSelector));

/// Le nombre de colonnes posées : les entrées de la première rangée.
int _columns(WidgetTester tester, List<Key> keys) {
  final double firstTop = tester.getRect(find.byKey(keys.first)).top;
  return keys
      .where((Key k) => tester.getRect(find.byKey(k)).top == firstTop)
      .length;
}

/// La largeur, mesurée par [TextPainter], de chaque mot de [paragraph] — même
/// texte, même style, même échelle de texte que le paragraphe posé.
List<double> _wordWidths(RenderParagraph paragraph) {
  final InlineSpan span = paragraph.text;
  final TextStyle? style = span is TextSpan ? span.style : null;
  final String text = paragraph.text.toPlainText();
  return <double>[
    for (final String word in text.split(' '))
      (TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout()).width,
  ];
}

RenderParagraph _titleParagraph(WidgetTester tester, String title) =>
    tester.renderObject<RenderParagraph>(find.text(title));

void main() {
  setUpAll(chargerRoboto);

  group('MapReadingSelector — entrées, ordre et annonces', () {
    testWidgetsOnWindows(
      'quatre entrées, dans l ordre Écoulement, Débit, Vigilance crues, '
      'Restrictions',
      (WidgetTester tester) async {
        await _pumpSelector(tester);

        final List<Rect> rects = <Rect>[
          for (final Key key in _entryKeys) tester.getRect(find.byKey(key)),
        ];
        for (int i = 1; i < rects.length; i++) {
          final Rect before = rects[i - 1];
          final Rect after = rects[i];
          final bool sameRowAfter =
              after.top == before.top && after.left > before.left;
          final bool nextRow = after.top >= before.bottom;
          expect(
            sameRowAfter || nextRow,
            isTrue,
            reason: 'entrée $i ($after) après entrée ${i - 1} ($before)',
          );
        }
        for (final (String title, String subtitle) in _expectedTexts) {
          expect(find.text(title), findsOneWidget);
          expect(find.text(subtitle), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows(
      'sans onToggleDesignationMode : trois entrées, aucune « Restrictions »',
      (WidgetTester tester) async {
        await _pumpSelector(tester, withToggle: false);

        expect(find.byKey(mapDesignationChipKey), findsNothing);
        expect(find.text(designationChipLabel), findsNothing);
        expect(find.text(designationEntrySubtitle), findsNothing);
        for (final MapScaleKind kind in MapScaleKind.values) {
          expect(find.byKey(ValueKey<MapScaleKind>(kind)), findsOneWidget);
        }
      },
    );

    testWidgetsOnWindows(
      'chaque entrée s annonce « titre, sous-titre », en un seul nœud',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pumpSelector(tester);

        const List<String> expected = <String>[
          'Écoulement, observé sur le terrain',
          "Débit, relatif à l'historique",
          'Vigilance crues, publiée par Vigicrues',
          'Restrictions, arrêtés préfectoraux',
        ];
        for (int i = 0; i < _entryKeys.length; i++) {
          final SemanticsNode node = tester.getSemantics(
            find.byKey(_entryKeys[i]),
          );
          expect(node.label, expected[i]);
          expect(node.mergeAllDescendantsIntoThisNode, isFalse);
          // `excludeSemantics` : aucun nœud enfant, les textes ne
          // s'annoncent pas une seconde fois.
          int children = 0;
          node.visitChildren((SemanticsNode child) {
            children++;
            return true;
          });
          expect(children, 0, reason: expected[i]);
        }
        expect(
          readingEntrySemanticsLabel('Débit', "relatif à l'historique"),
          "Débit, relatif à l'historique",
        );
        handle.dispose();
      },
    );

    testWidgetsOnWindows(
      'la lecture active est `selected`, les autres non ; « Restrictions » '
      'est `toggled` selon le mode, jamais `selected` ; en mode, la lecture '
      'active reste `selected`',
      (WidgetTester tester) async {
        for (final bool mode in <bool>[false, true]) {
          for (final MapScaleKind active in MapScaleKind.values) {
            await _pumpSelector(tester, scale: active, designationMode: mode);

            for (final MapScaleKind kind in MapScaleKind.values) {
              final Semantics entry = tester.widget<Semantics>(
                find.byKey(ValueKey<MapScaleKind>(kind)),
              );
              expect(entry.properties.button, isTrue);
              expect(
                entry.properties.selected,
                kind == active,
                reason: 'mode $mode, active $active, $kind',
              );
              expect(entry.properties.toggled, isNull);
            }
            final Semantics restrictions = tester.widget<Semantics>(
              find.byKey(mapDesignationChipKey),
            );
            expect(restrictions.properties.button, isTrue);
            expect(restrictions.properties.toggled, mode);
            expect(restrictions.properties.selected, isNot(isTrue));
          }
        }
      },
    );

    testWidgetsOnWindows(
      'allumée : fond noir, texte blanc ; éteinte : fond #F3F4F1, bord '
      '#C9CFC4 — la lecture et « Restrictions » allumées ensemble',
      (WidgetTester tester) async {
        await _pumpSelector(
          tester,
          scale: MapScaleKind.debit,
          designationMode: true,
        );

        BoxDecoration decorationOf(Key key) {
          final DecoratedBox box = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byKey(key),
                  matching: find.byWidgetPredicate(
                    (Widget w) =>
                        w is DecoratedBox &&
                        w.decoration is BoxDecoration &&
                        (w.decoration as BoxDecoration).color != null,
                  ),
                )
                .first,
          );
          return box.decoration as BoxDecoration;
        }

        for (final Key lit in <Key>[
          const ValueKey<MapScaleKind>(MapScaleKind.debit),
          mapDesignationChipKey,
        ]) {
          expect(decorationOf(lit).color, Colors.black, reason: '$lit');
        }
        for (final Key off in <Key>[
          const ValueKey<MapScaleKind>(MapScaleKind.ecoulement),
          const ValueKey<MapScaleKind>(MapScaleKind.crues),
        ]) {
          final BoxDecoration decoration = decorationOf(off);
          expect(decoration.color, const Color(0xFFF3F4F1), reason: '$off');
          expect(
            (decoration.border! as Border).top.color,
            const Color(0xFFC9CFC4),
            reason: '$off',
          );
        }
        expect(
          tester.widget<Text>(find.text('Débit')).style?.color,
          Colors.white,
        );
        expect(
          tester.widget<Text>(find.text('Écoulement')).style?.color,
          isNot(Colors.white),
        );
      },
    );

    testWidgetsOnWindows(
      'pictogrammes PD4 ; celui de « Restrictions » n est pas celui de '
      '« ⚠ Avertissement »',
      (WidgetTester tester) async {
        await _pumpSelector(tester);

        const List<IconData> expected = <IconData>[
          Icons.water_drop,
          Icons.timeline,
          Icons.waves,
          Icons.gavel,
        ];
        for (int i = 0; i < _entryKeys.length; i++) {
          final Icon icon = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(_entryKeys[i]),
              matching: find.byType(Icon),
            ),
          );
          expect(icon.icon, expected[i]);
        }
        final Icon restrictions = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(mapDesignationChipKey),
            matching: find.byType(Icon),
          ),
        );
        expect(restrictions.icon, isNot(Icons.warning_amber_rounded));
      },
    );
  });

  group('MapReadingSelector — activation', () {
    testWidgetsOnWindows(
      'un tap sur chaque entrée appelle onSelect(kind) ou le rappel, une fois',
      (WidgetTester tester) async {
        final List<MapScaleKind> selected = <MapScaleKind>[];
        int toggles = 0;
        await _pumpSelector(
          tester,
          onSelect: selected.add,
          onToggle: () => toggles++,
        );

        for (final MapScaleKind kind in MapScaleKind.values) {
          selected.clear();
          await tester.tap(find.byKey(ValueKey<MapScaleKind>(kind)));
          await tester.pump();
          expect(selected, <MapScaleKind>[kind]);
        }
        await tester.tap(find.byKey(mapDesignationChipKey));
        await tester.pump();
        expect(toggles, 1);
      },
    );

    testWidgetsOnWindows('un tap sur un sous-titre active son entrée', (
      WidgetTester tester,
    ) async {
      final List<MapScaleKind> selected = <MapScaleKind>[];
      await _pumpSelector(tester, onSelect: selected.add);

      await tester.tap(find.text("relatif à l'historique"));
      await tester.pump();
      expect(selected, <MapScaleKind>[MapScaleKind.debit]);
    });

    testWidgetsOnWindows(
      'Entrée puis Espace activent chaque entrée focalisée, une fois chacun',
      (WidgetTester tester) async {
        final List<MapScaleKind> selected = <MapScaleKind>[];
        int toggles = 0;
        await _pumpSelector(
          tester,
          onSelect: selected.add,
          onToggle: () => toggles++,
        );

        Future<void> focus(Key key) async {
          final BuildContext context = tester.element(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(GestureDetector),
            ),
          );
          Focus.of(context).requestFocus();
          await tester.pump();
        }

        for (final MapScaleKind kind in MapScaleKind.values) {
          selected.clear();
          await focus(ValueKey<MapScaleKind>(kind));
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(selected, <MapScaleKind>[kind]);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          expect(selected, <MapScaleKind>[kind, kind]);
        }
        await focus(mapDesignationChipKey);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggles, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggles, 2);
      },
    );

    testWidgetsOnWindows(
      'Tab parcourt les entrées dans l ordre : la quatrième tabulation '
      'atteint « Restrictions »',
      (WidgetTester tester) async {
        int toggles = 0;
        await _pumpSelector(tester, onToggle: () => toggles++);

        for (int i = 0; i < _entryKeys.length; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggles, 1);
      },
    );

    testWidgetsOnWindows(
      "l'action sémantique tap de chaque entrée appelle son rappel une fois",
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final List<MapScaleKind> selected = <MapScaleKind>[];
        int toggles = 0;
        await _pumpSelector(
          tester,
          onSelect: selected.add,
          onToggle: () => toggles++,
        );

        for (final MapScaleKind kind in MapScaleKind.values) {
          final SemanticsNode node = tester.getSemantics(
            find.byKey(ValueKey<MapScaleKind>(kind)),
          );
          expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);
          selected.clear();
          node.owner!.performAction(node.id, SemanticsAction.tap);
          await tester.pump();
          expect(selected, <MapScaleKind>[kind]);
        }
        final SemanticsNode node = tester.getSemantics(
          find.byKey(mapDesignationChipKey),
        );
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(toggles, 1);
        handle.dispose();
      },
    );
  });

  group('MapReadingSelector — colonnes (PD5 : aucun mot de titre coupé)', () {
    void expectNoTitleWordCut(WidgetTester tester) {
      for (final (String title, String _) in _expectedTexts) {
        final RenderParagraph paragraph = _titleParagraph(tester, title);
        for (final double word in _wordWidths(paragraph)) {
          expect(
            paragraph.constraints.maxWidth,
            greaterThanOrEqualTo(word),
            reason: '« $title » : zone de titre trop étroite pour un mot',
          );
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(word),
            reason: '« $title » : une ligne plus étroite que son mot',
          );
        }
      }
    }

    void expectTapTargets(WidgetTester tester) {
      for (final Key key in _entryKeys) {
        final Size size = tester.getSize(find.byKey(key));
        expect(
          size.width,
          greaterThanOrEqualTo(minimumTapTarget),
          reason: '$key',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(minimumTapTarget),
          reason: '$key',
        );
      }
    }

    testWidgetsOnWindows('à 480 px et 100 % : quatre colonnes, cibles ≥ 44', (
      WidgetTester tester,
    ) async {
      await _pumpSelector(tester);

      expect(tester.takeException(), isNull);
      expect(_columns(tester, _entryKeys), 4);
      expectNoTitleWordCut(tester);
      expect(minimumTapTarget, 44);
      expectTapTargets(tester);
    });

    testWidgetsOnAndroid(
      'Android : à 344 px et 100 % : deux colonnes, cibles ≥ 48',
      (WidgetTester tester) async {
        await _pumpSelector(tester, width: _phoneBlockWidth);

        expect(tester.takeException(), isNull);
        expect(_columns(tester, _entryKeys), 2);
        expectNoTitleWordCut(tester);
        expect(minimumTapTarget, 48);
        expectTapTargets(tester);
      },
    );

    testWidgetsOnAndroid(
      'Android : à 344 px et 200 % : le nombre de colonnes que la règle '
      'donne, calculé sur les largeurs des titres ; aucun mot coupé',
      (WidgetTester tester) async {
        // L'espacement entre colonnes, lu à 100 % sur deux colonnes.
        await _pumpSelector(tester, width: _phoneBlockWidth);
        final double spacing =
            tester.getRect(find.byKey(_entryKeys[1])).left -
            tester.getRect(find.byKey(_entryKeys[0])).right;

        await _pumpSelector(tester, width: _phoneBlockWidth, textScale: 2);
        expect(tester.takeException(), isNull);

        // Ce qu'une entrée ajoute autour de sa zone de titre (pictogramme,
        // marges), lu sur l'entrée posée : indépendant du nombre de colonnes.
        double chrome = 0;
        double longestWord = 0;
        for (int i = 0; i < _entryKeys.length; i++) {
          final RenderParagraph paragraph = _titleParagraph(
            tester,
            _expectedTexts[i].$1,
          );
          final double entryWidth = tester
              .getSize(find.byKey(_entryKeys[i]))
              .width;
          chrome = entryWidth - paragraph.constraints.maxWidth > chrome
              ? entryWidth - paragraph.constraints.maxWidth
              : chrome;
          for (final double word in _wordWidths(paragraph)) {
            longestWord = word > longestWord ? word : longestWord;
          }
        }
        int expected = 1;
        for (final int columns in <int>[4, 2, 1]) {
          final double columnWidth =
              (_phoneBlockWidth - (columns - 1) * spacing) / columns;
          if (columnWidth >= chrome + longestWord) {
            expected = columns;
            break;
          }
        }

        expect(_columns(tester, _entryKeys), expected);
        expectNoTitleWordCut(tester);
        expectTapTargets(tester);
      },
    );
  });

  group('MapReadingSelector — intrinsèques et repli 4', () {
    for (final (double width, double scale) in <(double, double)>[
      (480, 1),
      (480, 2),
      (800, 1),
      (800, 2),
    ]) {
      testWidgetsOnWindows('à $width px et ${(scale * 100).round()} % : '
          'getMinIntrinsicHeight < getMaxIntrinsicHeight ; posée à la '
          'première, aucune erreur', (WidgetTester tester) async {
        await _pumpSelector(tester, width: width, textScale: scale);
        final double min = _grid(tester).getMinIntrinsicHeight(width);
        final double max = _grid(tester).getMaxIntrinsicHeight(width);
        expect(min, lessThan(max));
        expect(_grid(tester).size.height, max);

        await _pumpSelector(
          tester,
          width: width,
          textScale: scale,
          height: min,
        );
        expect(tester.takeException(), isNull);
        expect(_grid(tester).size.height, min);
      });
    }

    testWidgetsOnAndroid(
      'Android : à 344 px, 100 % et 200 % : min < max ; posée à min, '
      'aucune erreur',
      (WidgetTester tester) async {
        for (final double scale in <double>[1, 2]) {
          await _pumpSelector(
            tester,
            width: _phoneBlockWidth,
            textScale: scale,
          );
          final double min = _grid(tester)
              .getMinIntrinsicHeight(_phoneBlockWidth);
          final double max = _grid(tester)
              .getMaxIntrinsicHeight(_phoneBlockWidth);
          expect(min, lessThan(max), reason: '$scale');

          await _pumpSelector(
            tester,
            width: _phoneBlockWidth,
            textScale: scale,
            height: min,
          );
          expect(tester.takeException(), isNull);
          expect(_grid(tester).size.height, min);
        }
      },
    );

    testWidgetsOnWindows(
      'posée à sa hauteur entière, tous les sous-titres sont à l écran',
      (WidgetTester tester) async {
        await _pumpSelector(tester);

        for (final (String title, String subtitle) in _expectedTexts) {
          expect(find.text(title).hitTestable(), findsOneWidget);
          expect(find.text(subtitle).hitTestable(), findsOneWidget);
        }
      },
    );

    for (final (double width, double scale) in <(double, double)>[
      (480, 1),
      (480, 2),
    ]) {
      testWidgetsOnWindows(
        'à $width px et ${(scale * 100).round()} %, bornée sous '
        'getMaxIntrinsicHeight : tous les sous-titres effacés, les titres '
        'restent, les annonces sont inchangées, les cibles tiennent',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          await _pumpSelector(tester, width: width, textScale: scale);
          final double max = _grid(tester).getMaxIntrinsicHeight(width);
          final Map<Key, String> labels = <Key, String>{
            for (final Key key in _entryKeys)
              key: tester.getSemantics(find.byKey(key)).label,
          };

          await _pumpSelector(
            tester,
            width: width,
            textScale: scale,
            height: max - 1,
          );
          expect(tester.takeException(), isNull);

          for (final (String title, String subtitle) in _expectedTexts) {
            expect(find.text(title).hitTestable(), findsOneWidget);
            // Une seule variante montée : le texte reste dans l'arbre, mais
            // il n'est ni peint ni touchable.
            expect(find.text(subtitle), findsOneWidget);
            expect(find.text(subtitle).hitTestable(), findsNothing);
          }
          for (final Key key in _entryKeys) {
            expect(tester.getSemantics(find.byKey(key)).label, labels[key]);
            final Size size = tester.getSize(find.byKey(key));
            expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
            expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
          }
          handle.dispose();
        },
      );
    }

    testWidgetsOnWindows(
      'sous-titres effacés : chaque entrée tient dans la hauteur des titres '
      'seuls, et un tap l active encore',
      (WidgetTester tester) async {
        final List<MapScaleKind> selected = <MapScaleKind>[];
        await _pumpSelector(tester, onSelect: selected.add);
        final double max = _grid(tester).getMaxIntrinsicHeight(480);
        final double min = _grid(tester).getMinIntrinsicHeight(480);

        await _pumpSelector(tester, onSelect: selected.add, height: max - 1);
        for (final Key key in _entryKeys) {
          expect(
            tester.getRect(find.byKey(key)).bottom,
            lessThanOrEqualTo(min),
          );
        }
        await tester.tap(
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.crues)),
        );
        await tester.pump();
        expect(selected, <MapScaleKind>[MapScaleKind.crues]);
      },
    );
  });
}

// Verrouille l'ecran « D'ou vient cette donnee ? » (T2, `S1`) selon la
// conception arbitree
// (`docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md` § 8,
// Q-8 (a) du 2026-09-29) : ecran plein, titre `dataSourcesTitle`, bouton de
// retour, contenu defilant ; les QUATRE noms de source par leurs constantes ;
// les textes retenus par le commanditaire, mot pour mot — dont la phrase de
// licence de la source des restrictions, arbitree le 2026-10-03.
//
// Les textes attendus sont ecrits EN DUR dans ce fichier : comparer une
// constante a elle-meme ne verrouillerait rien. Le nom de la source des
// restrictions y est ecrit en toutes lettres (ce fichier n'est pas dans le
// perimetre du confinement, qui ne lit que `lib/`).
//
// Ce fichier verrouille aussi `DataSourcesLink`, le lien partage par le modal
// du premier lancement et par la fenetre d'avertissement.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/cached_restriction_source.dart'
    show restrictionsCacheTtl;
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart'
    show ignAttribution;
import 'package:martinpecheur/features/shared/data_sources_view.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../support/windows_platform.dart';

const String _intro =
    'Chaque valeur affichée porte sa date et le nom de sa source.';

const String _hydrometrie =
    "Débit et hauteur d'eau mesurés par des stations hydrométriques. Une "
    'mesure transmise automatiquement peut être affichée avant tout contrôle '
    'humain : elle peut être corrigée ou supprimée plus tard. Licence '
    "Ouverte Etalab, citation de l'auteur obligatoire.";

const String _onde =
    "Observations visuelles de l'écoulement de petits cours d'eau, faites "
    'par des agents lors de campagnes, de mai à septembre, environ une par '
    "mois. Entre deux campagnes, personne n'observe ces points. France "
    'hexagonale et Corse uniquement. Licence Ouverte Etalab.';

const String _ondeNote =
    "La source distingue six modalités d'écoulement. L'application les "
    'regroupe en quatre catégories et un état « Non observé » : ce '
    "regroupement est un choix de l'application, pas une classification de "
    "l'OFB.";

const String _restrictions =
    "Zones d'alerte sécheresse, niveaux de gravité et usages restreints au "
    'point désigné, tels que transmis par VigiEau. Seul l\'arrêté '
    'préfectoral fait foi : son texte peut comporter des dérogations et des '
    "périmètres que VigiEau ne restitue pas. L'interface de VigiEau est en "
    'version 0.1 et peut changer sans préavis : une réponse que '
    "l'application ne sait pas lire n'est jamais affichée. Une réponse reste "
    "gardée 6 heures, tant que l'application est ouverte, avec sa date de "
    'récupération. Le site VigiEau et son jeu de données publié sur '
    'data.gouv.fr sont sous Licence Ouverte 2.0.';

const String _ignLead = 'Fond de carte : plan IGN.';

const String _dams =
    'Aucune de ces données ne reflète les lâchers ni les manœuvres de '
    'barrages.';

Widget _app() => const MaterialApp(home: DataSourcesView());

/// Tous les textes rendus sous l'ecran : `Text` et `SelectableText`.
List<String> _renderedTexts(WidgetTester tester) {
  final Finder scope = find.byType(DataSourcesView);
  return <String>[
    for (final Text text in tester.widgetList<Text>(
      find.descendant(of: scope, matching: find.byType(Text)),
    ))
      text.data ?? text.textSpan?.toPlainText() ?? '',
    for (final EditableText text in tester.widgetList<EditableText>(
      find.descendant(of: scope, matching: find.byType(EditableText)),
    ))
      text.controller.text,
  ];
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  group('DataSourcesView — contenu (conception § 8)', () {
    testWidgets('le titre est dataSourcesTitle, annonce comme en-tete', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());

      expect(find.text(dataSourcesTitle), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text(dataSourcesTitle))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );

      handle.dispose();
    });

    testWidgets('les quatre sources sont nommees par leurs constantes, '
        'chacune en en-tete', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());

      for (final String name in <String>[
        hydrometrieSourceName,
        ondeSourceName,
        restrictionsSourceName,
        ignSourceName,
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
        expect(
          tester
              .getSemantics(find.text(name))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
          reason: name,
        );
      }

      handle.dispose();
    });

    testWidgets('chaque section rend le texte retenu, mot pour mot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());

      for (final String text in <String>[
        _intro,
        _hydrometrie,
        _onde,
        _ondeNote,
        _restrictions,
        _ignLead,
        ignAttribution,
        _dams,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    test('les constantes du texte sont celles retenues', () {
      expect(dataSourcesIntroText, _intro);
      expect(dataSourcesHydrometrieText, _hydrometrie);
      expect(dataSourcesOndeText, _onde);
      expect(dataSourcesOndeCategoriesNote, _ondeNote);
      expect(dataSourcesRestrictionsText, _restrictions);
      expect(dataSourcesIgnText, _ignLead);
      expect(dataSourcesDamsLimitText, _dams);
    });

    test('la licence de la source des restrictions est celle arbitree le '
        '2026-10-03 : le site et le jeu data.gouv, pas « la donnee de '
        "l'API »", () {
      expect(
        dataSourcesRestrictionsText,
        endsWith(
          'Le site VigiEau et son jeu de données publié sur data.gouv.fr '
          'sont sous Licence Ouverte 2.0.',
        ),
      );
      // Hub'Eau : « Licence Ouverte Etalab », jamais de numero de version
      // (aucun n'est ecrit sur ses 8 pages et ses 2 schemas).
      expect(dataSourcesHydrometrieText, contains('Licence Ouverte Etalab,'));
      expect(dataSourcesOndeText, endsWith('Licence Ouverte Etalab.'));
      for (final String text in <String>[
        dataSourcesHydrometrieText,
        dataSourcesOndeText,
      ]) {
        expect(text, isNot(contains('1.0')));
        expect(text, isNot(contains('2.0')));
      }
    });

    test("la duree de garde de la reponse annoncee est celle du cache : "
        'aucune derive silencieuse', () {
      expect(
        dataSourcesRestrictionsText,
        contains('gardée ${restrictionsCacheTtl.inHours} heures'),
      );
    });

    test("l'attribution du fond de carte est celle de la carte, au "
        'caractere pres (un concept, un mot)', () {
      expect(dataSourcesIgnAttribution, ignAttribution);
    });

    testWidgets("l'adresse du site public est un texte selectionnable, "
        "pas un lien : aucun port d'ouverture, aucune cible actionnable "
        'hors du retour', (WidgetTester tester) async {
      await tester.pumpWidget(_app());

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is SelectableText &&
              widget.data == restrictionsPublicSiteUrl,
        ),
        findsOneWidget,
      );
      final Finder content = find.byType(SingleChildScrollView);
      expect(
        find.descendant(of: content, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: content, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
    });

    testWidgets('le mot « percentile » est absent, comme toute limite de '
        'statistique (Q8-A, Q4-A)', (WidgetTester tester) async {
      await tester.pumpWidget(_app());

      final String all = _renderedTexts(tester).join('\n').toLowerCase();
      expect(all, isNot(contains('percentile')));
    });

    testWidgets("l'ordre est celui de la conception : introduction, "
        'hydrometrie, ONDE et sa note, restrictions et son adresse, fond de '
        'carte, limite des barrages', (WidgetTester tester) async {
      await tester.pumpWidget(_app());

      final List<double> tops = <double>[
        _top(tester, find.text(_intro)),
        _top(tester, find.text(hydrometrieSourceName)),
        _top(tester, find.text(_hydrometrie)),
        _top(tester, find.text(ondeSourceName)),
        _top(tester, find.text(_onde)),
        _top(tester, find.text(_ondeNote)),
        _top(tester, find.text(restrictionsSourceName)),
        _top(tester, find.text(_restrictions)),
        _top(
          tester,
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is SelectableText &&
                widget.data == restrictionsPublicSiteUrl,
          ),
        ),
        _top(tester, find.text(ignSourceName)),
        _top(tester, find.text(_ignLead)),
        _top(tester, find.text(ignAttribution)),
        _top(tester, find.text(_dams)),
      ];

      for (int i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'element $i');
      }
    });
  });

  group('DataSourcesView — retour et clavier', () {
    Future<void> pushed(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const DataSourcesView(),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.byType(DataSourcesView), findsOneWidget);
    }

    testWidgets('le bouton de retour retire la route', (
      WidgetTester tester,
    ) async {
      await pushed(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsNothing);
    });

    testWidgets('Echap retire la route', (WidgetTester tester) async {
      await pushed(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsNothing);
    });

    // `PageDown` est une touche de defilement de Flutter sur Windows ; les
    // fleches suivent, elles, le parcours du focus (aucune n'est liee au
    // defilement). `primary: true` : le defilement de la route est celui que
    // le focus de l'ecran trouve.
    testWidgetsOnWindows('PageDown a l ouverture defile vers le bas, PageUp '
        'remonte', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final ScrollableState scrollable = tester.state(
        find.byType(Scrollable).first,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final double down = scrollable.position.pixels;
      expect(down, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, lessThan(down));
    });
  });

  group('DataSourcesView — cibles et defilement (04-ui.md § 3)', () {
    Future<void> checkBackTarget(WidgetTester tester) async {
      await tester.pumpWidget(_app());
      final Size size = tester.getSize(find.byType(BackButton));
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    }

    testWidgets('Android : le retour mesure 48', (WidgetTester tester) async {
      expect(minimumTapTarget, 48);
      await checkBackTarget(tester);
    });

    testWidgetsOnWindows('Windows : le retour mesure 44', (
      WidgetTester tester,
    ) async {
      expect(minimumTapTarget, 44);
      await checkBackTarget(tester);
    });

    for (final ({String name, Size size}) window
        in <({String name, Size size})>[
          (name: 'telephone 390 x 844', size: const Size(390, 844)),
          (
            name: 'fenetre Windows minimale 800 x 740',
            size: const Size(800, 740),
          ),
        ]) {
      testWidgets('a 200 % de police, ${window.name} : aucun debordement, '
          'l ecran defile, la derniere phrase est atteignable', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = window.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _app(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final ScrollableState scrollable = tester.state(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));

        await tester.ensureVisible(find.text(_dams));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final Rect viewport = Offset.zero & window.size;
        expect(viewport.contains(tester.getTopLeft(find.text(_dams))), isTrue);
        expect(
          viewport.contains(tester.getBottomRight(find.text(_dams))),
          isTrue,
        );
      });
    }

    testWidgets("aucun texte n'est tronque : ni nombre de lignes borne, ni "
        'points de suspension', (WidgetTester tester) async {
      await tester.pumpWidget(_app());

      final Finder scope = find.byType(DataSourcesView);
      for (final Text text in tester.widgetList<Text>(
        find.descendant(of: scope, matching: find.byType(Text)),
      )) {
        expect(text.maxLines, isNull, reason: '${text.data}');
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      }
    });
  });

  group('DataSourcesLink', () {
    const Key linkKey = Key('test-data-sources-link');
    Widget app() => const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: DataSourcesLink(label: 'Un libelle', key: linkKey),
        ),
      ),
    );

    testWidgets('rend le libelle fourni et ouvre l ecran au tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app());
      expect(find.text('Un libelle'), findsOneWidget);
      expect(find.byType(DataSourcesView), findsNothing);

      await tester.tap(find.byKey(linkKey));
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsOneWidget);
    });

    testWidgets('atteignable au Tab, activable a Entree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app());

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsOneWidget);
    });

    testWidgets("porte une action tap pour le lecteur d'ecran", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(app());

      final SemanticsNode node = tester.getSemantics(find.byKey(linkKey));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, 'Un libelle');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.byType(DataSourcesView), findsOneWidget);

      handle.dispose();
    });

    Future<void> checkTarget(WidgetTester tester) async {
      await tester.pumpWidget(app());
      final Size size = tester.getSize(find.byKey(linkKey));
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    }

    testWidgets('Android : la cible mesure 48', (WidgetTester tester) async {
      expect(minimumTapTarget, 48);
      await checkTarget(tester);
    });

    testWidgetsOnWindows('Windows : la cible mesure 44', (
      WidgetTester tester,
    ) async {
      expect(minimumTapTarget, 44);
      await checkTarget(tester);
    });
  });
}

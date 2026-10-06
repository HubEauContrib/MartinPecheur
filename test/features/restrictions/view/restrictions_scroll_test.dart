// Reproduction du symptome du 2026-09-29 (Windows, ~1266 x 741, 100 %) :
// « j'ai du mal a scroller en bas ou en haut, je suis bloque sur la page »,
// sur l'ecran des restrictions. Chaque hypothese a son test.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/restrictions/view/reinforced_warning_card.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart';

import '../../../support/windows_platform.dart';
import '../zones_samples.dart';

const Size _window = Size(1266, 741);

/// Le site public, puis l'arrete de l'Ain, qui ne se sont pas ouverts.
const UnopenedLink _publicSiteFailure = UnopenedLink(
  raw: restrictionsPublicSiteUrl,
  target: LinkTarget.publicSite,
  failureNumber: 1,
);
const UnopenedLink _publicSiteSecondFailure = UnopenedLink(
  raw: restrictionsPublicSiteUrl,
  target: LinkTarget.publicSite,
  failureNumber: 2,
);
const UnopenedLink _decreeSecondFailure = UnopenedLink(
  raw: decreeUrlAin,
  target: LinkTarget.decree,
  failureNumber: 2,
);
const UnopenedLink _decreeFailure = UnopenedLink(
  raw: decreeUrlAin,
  target: LinkTarget.decree,
  failureNumber: 1,
);

/// Largeur de la colonne de lecture, remplissage compris : au-dela, la tete de
/// l'encart et le contenu gardent cette largeur, centres.
const double _readingColumn = readingColumnWidth + 2 * readingColumnGutter;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: RestrictionsScreen(
        state: ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
        onChooseProfile: (UserProfile _) {},
        onRetry: () {},
        onOpenDocument: (DocumentLink _, LinkTarget _) {},
        onOpenPublicSite: () {},
        utcOffsetOf: (DateTime _) => const Duration(hours: 2),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le defilement de l'ecran — pas celui, interne, d'un `SelectableText`.
final Finder _mainScrollable = find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(_mainScrollable).position.pixels;

double _max(WidgetTester tester) =>
    tester.state<ScrollableState>(_mainScrollable).position.maxScrollExtent;

/// Bas de la barre de titre : le haut de la zone ou la tete s'epingle.
double _barBottom(WidgetTester tester) => tester
    .getRect(
      find
          .ancestor(
            of: find.text(restrictionsScreenTitle),
            matching: find.byType(Material),
          )
          .first,
    )
    .bottom;

bool _headerPinned() => find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byKey(reinforcedWarningHeaderKey),
    )
    .evaluate()
    .isEmpty;

Future<void> _wheel(WidgetTester tester, Offset at, double dy) async {
  final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(at));
  await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgetsOnWindows('le contenu depasse la hauteur (sinon rien a tester)', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    expect(_max(tester), greaterThan(300));
    expect(_headerPinned(), isTrue);
  });

  group('H2 : oscillation de l epinglage', () {
    testWidgetsOnWindows(
      'aucune bascule sur 30 passages, ni apres defilement',
      (WidgetTester tester) async {
        await _pump(tester);
        final List<bool> seen = <bool>[];
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(_headerPinned());
        }
        expect(seen.toSet(), <bool>{true});

        await _wheel(tester, const Offset(633, 500), 400);
        final double after = _offset(tester);
        expect(after, greaterThan(0));
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(_headerPinned(), isTrue);
        }
        expect(_offset(tester), after);
      },
    );
  });

  // Constat B de la revue : un retrecissement de la fenetre fait repasser la
  // tete epinglee en defilement (repli synchrone, jamais de debordement),
  // puis la re-epingle apres rendu. Les deux dispositions n'avaient pas la
  // meme racine : le defilement etait remplace deux fois, et sa position
  // perdue, A CHAQUE image d'un retrecissement.
  group('B : le defilement survit au retrecissement de la fenetre', () {
    testWidgetsOnWindows('hauteur reduite pas a pas : la position est gardee', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_max(tester), greaterThan(450));
      expect(_offset(tester), 400);

      for (int step = 1; step <= 10; step++) {
        tester.view.physicalSize = Size(
          _window.width,
          _window.height - 3 * step,
        );
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(_headerPinned(), isTrue);
      expect(_offset(tester), 400);
    });

    testWidgetsOnWindows('largeur reduite pas a pas : la position est gardee', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_offset(tester), 400);

      for (int step = 1; step <= 10; step++) {
        tester.view.physicalSize = Size(
          _window.width - 8 * step,
          _window.height,
        );
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(_headerPinned(), isTrue);
      expect(_offset(tester), 400);
    });

    testWidgetsOnWindows('fenetre trop basse pour epingler : tout defile, '
        'puis la tete se re-epingle sans perdre la position', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_offset(tester), 400);

      // Assez bas pour que la tete (deux fois sa hauteur) ne tienne plus
      // dans la zone sous la barre de titre.
      final double headerHeight = tester
          .getSize(find.byKey(reinforcedWarningHeaderKey))
          .height;
      tester.view.physicalSize = Size(_window.width, headerHeight * 2);
      await tester.pumpAndSettle();
      // Tete en defilement : meme defilement, meme position (la hauteur de
      // la tete n'est plus retranchee de la fenetre, la position reste).
      expect(_headerPinned(), isFalse);
      expect(_offset(tester), 400);

      tester.view.physicalSize = _window;
      await tester.pumpAndSettle();
      expect(_headerPinned(), isTrue);
      expect(_offset(tester), 400);
    });

    // Constat de la relecture : tout retrecissement repliait la tete de facon
    // synchrone. Ecran defile, elle partait hors champ le temps du geste
    // (mesure a 400 : [-348, -256] sur l'image du redimensionnement). En
    // hauteur seule la tete garde sa largeur, donc sa hauteur : elle reste
    // epinglee sur TOUTES les images tant qu'elle tient.
    testWidgetsOnWindows('hauteur reduite, ecran defile : a chaque image, y '
        'compris celle du redimensionnement, la tete est sous la barre de '
        'titre', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_offset(tester), 400);
      final double barBottom = _barBottom(tester);
      final Finder header = find.byKey(reinforcedWarningHeaderKey);

      for (int step = 1; step <= 20; step++) {
        tester.view.physicalSize = Size(
          _window.width,
          _window.height - 7 * step,
        );
        // UN SEUL pump : l'image du redimensionnement elle-meme.
        await tester.pump();
        expect(_headerPinned(), isTrue, reason: 'image du pas $step');
        expect(
          tester.getTopLeft(header).dy,
          closeTo(barBottom, 0.01),
          reason: 'image du pas $step',
        );
        // Et l'image suivante, celle de la decision post-rendu.
        await tester.pump();
        expect(_headerPinned(), isTrue, reason: 'image suivante, pas $step');
        expect(tester.getTopLeft(header).dy, closeTo(barBottom, 0.01));
      }
      expect(tester.takeException(), isNull);
      expect(_offset(tester), 400);
    });

    // Le verrou de l'autre cote : une hauteur sous le double de la tete la
    // replie TOUT DE SUITE (la tete epinglee deborderait), sans exception de
    // debordement, puis la re-epingle quand la fenetre regrandit.
    testWidgetsOnWindows('hauteur sous le double de la tete : repli '
        'immediat, aucun debordement', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      final double headerHeight = tester
          .getSize(find.byKey(reinforcedWarningHeaderKey))
          .height;

      tester.view.physicalSize = Size(
        _window.width,
        _barBottom(tester) + headerHeight * 2 - 1,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_headerPinned(), isFalse);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_headerPinned(), isFalse);
      expect(_offset(tester), 400);

      tester.view.physicalSize = _window;
      await tester.pumpAndSettle();
      expect(_headerPinned(), isTrue);
      expect(_offset(tester), 400);
    });

    // De 1266 a 466, la fenetre traverse la colonne de lecture (792). SOUS
    // elle, la tete peut grandir (son texte passe a la ligne) : le repli y
    // reste synchrone, sans quoi elle deborderait. Image repliee peinte, puis
    // re-epinglage : jamais d'exception de debordement, position gardee.
    testWidgetsOnWindows('largeur reduite, ecran defile : aucun debordement '
        'a aucune image, la position est gardee', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_offset(tester), 400);

      for (int step = 1; step <= 20; step++) {
        tester.view.physicalSize = Size(
          _window.width - 40 * step,
          _window.height,
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'pas $step');
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'pas $step, suivante');
      }
      await tester.pumpAndSettle();

      expect(_headerPinned(), isTrue);
      expect(_offset(tester), 400);
    });

    // Constat de la seconde relecture : au-dessus de la colonne de lecture
    // (`readingColumnWidth + 2 * readingColumnGutter`, 792), la tete a une
    // largeur fixe, donc une hauteur fixe — et Windows impose 800 au minimum.
    // Le repli en largeur n'y servait a rien : ecran defile a 400, largeur
    // 1266 -> 1170 par pas de 8, la tete etait repliee a y = -348 sur chacune
    // des douze images.
    testWidgetsOnWindows('largeur reduite au-dessus de la colonne de lecture, '
        'ecran defile : a chaque image, la tete est sous la barre de titre', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 400);
      expect(_offset(tester), 400);
      final double barBottom = _barBottom(tester);
      final Finder header = find.byKey(reinforcedWarningHeaderKey);

      // Par pas de 8 tant que la fenetre depasse la colonne de lecture, puis
      // la largeur exacte de la colonne : la borne est incluse.
      final List<double> widths = <double>[
        for (double w = _window.width - 8; w > _readingColumn; w -= 8) w,
        _readingColumn,
      ];
      expect(widths.length, greaterThan(12));
      for (final double width in widths) {
        tester.view.physicalSize = Size(width, _window.height);
        // UN SEUL pump : l'image du redimensionnement elle-meme.
        await tester.pump();
        expect(
          tester.getTopLeft(header).dy,
          closeTo(barBottom, 0.01),
          reason: 'largeur $width',
        );
        expect(_headerPinned(), isTrue, reason: 'largeur $width');
      }
      expect(tester.takeException(), isNull);
      expect(_offset(tester), 400);
    });

    // Le verrou de l'autre cote : SOUS la colonne de lecture, la tete suit la
    // largeur de la fenetre, son texte passe a la ligne et elle GRANDIT. Le
    // repli joue des l'image du retrecissement, sans quoi la tete epinglee
    // deborderait de la zone. Mesures (police de test) : a 780 de large la
    // barre de titre fait 52 et la tete 92 ; a 200, 148 et 228. Fenetre haute
    // de 348 : la zone utile passe de 296 a 200. Les garde-fous disent que le
    // repli observe est bien celui de la LARGEUR — la tete, a sa hauteur
    // memorisee (92), tient encore dans la moitie de la zone — et que la tete
    // epinglee aurait deborde (228 > 200).
    testWidgetsOnWindows('largeur reduite sous la colonne de lecture : repli '
        'des la premiere image, aucun debordement', (
      WidgetTester tester,
    ) async {
      const double height = 348;
      tester.view.physicalSize = const Size(780, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RestrictionsScreen(
            state: ZonesTrouvees(zonesAin()),
            profile: UserProfile.particulier,
            onChooseProfile: (UserProfile _) {},
            onRetry: () {},
            onOpenDocument: (DocumentLink _, LinkTarget _) {},
            onOpenPublicSite: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(780, lessThan(_readingColumn));
      expect(_headerPinned(), isTrue);
      final Finder header = find.byKey(reinforcedWarningHeaderKey);
      final double wideHeader = tester.getSize(header).height;

      tester.view.physicalSize = const Size(200, height);
      // UN SEUL pump : l'image du retrecissement elle-meme.
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_headerPinned(), isFalse);

      // Garde-fous, sur les mesures de cette image.
      final double narrowZone = height - _barBottom(tester);
      final double narrowHeader = tester.getSize(header).height;
      expect(
        wideHeader * 2,
        lessThanOrEqualTo(narrowZone),
        reason:
            'le repli doit venir de la largeur, pas de la hauteur : tete '
            '$wideHeader, zone $narrowZone',
      );
      expect(
        narrowHeader,
        greaterThan(narrowZone),
        reason:
            'la tete epinglee doit deborder de la zone : tete '
            '$narrowHeader, zone $narrowZone',
      );

      // La decision apres rendu ne la re-epingle pas : elle ne tient pas.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_headerPinned(), isFalse);

      // La fenetre regrandit : la tete se re-epingle.
      tester.view.physicalSize = const Size(780, height);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_headerPinned(), isTrue);
    });
  });

  // Constat C de la revue : le bouton « Consulter les arretes en vigueur » est
  // dans la tete epinglee, l'avis de son echec en tete du contenu defilant.
  // Un usager descendu aux arretes ne le voyait pas : le bouton paraissait
  // inerte. L'emplacement (sous le corps de l'encart, `UC-002 A6`) ne change
  // pas : c'est le defilement qui va a l'avis, quand il apparait. Meme
  // symptome pour l'avis d'un ARRETE non ouvert : il nait sous son bouton,
  // hors de la zone visible quand le bouton est au bas de l'ecran.
  group('C : l avis d un lien non ouvert est amene a l ecran', () {
    final Finder notice = find.textContaining("Ce lien n'a pas pu être ouvert");

    Widget screen({UnopenedLink? unopenedLink, double textScale = 1}) =>
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: RestrictionsScreen(
                state: ZonesTrouvees(zonesAin()),
                profile: UserProfile.particulier,
                onChooseProfile: (UserProfile _) {},
                onRetry: () {},
                onOpenDocument: (DocumentLink _, LinkTarget _) {},
                onOpenPublicSite: () {},
                unopenedLink: unopenedLink,
                utcOffsetOf: (DateTime _) => const Duration(hours: 2),
              ),
            ),
          ),
        );

    Future<void> pumpAt(
      WidgetTester tester,
      Size window, {
      double textScale = 1,
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(screen(textScale: textScale));
      await tester.pumpAndSettle();
    }

    void expectNoticeInView(WidgetTester tester) {
      expect(notice, findsOneWidget);
      final Rect view = tester.getRect(_mainScrollable);
      final Rect at = tester.getRect(notice);
      expect(at.top, greaterThanOrEqualTo(view.top), reason: '$at / $view');
      expect(at.bottom, lessThanOrEqualTo(view.bottom), reason: '$at / $view');
    }

    testWidgetsOnWindows('ecran descendu aux arretes : l avis, au-dessus de '
        'la zone visible, y est amene', (WidgetTester tester) async {
      await pumpAt(tester, _window);
      tester
          .state<ScrollableState>(_mainScrollable)
          .position
          .jumpTo(_max(tester));
      await tester.pump();
      expect(_offset(tester), greaterThan(300));
      expect(notice, findsNothing);

      await tester.pumpWidget(screen(unopenedLink: _publicSiteFailure));
      await tester.pumpAndSettle();

      expectNoticeInView(tester);
    });

    testWidgetsOnWindows('ecran en haut, avis deja visible : le defilement '
        'ne bouge pas', (WidgetTester tester) async {
      await pumpAt(tester, _window);
      expect(_offset(tester), 0);

      await tester.pumpWidget(screen(unopenedLink: _publicSiteFailure));
      await tester.pumpAndSettle();

      expectNoticeInView(tester);
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('telephone, en haut : l avis sous la ligne de '
        'flottaison y est amene', (WidgetTester tester) async {
      await pumpAt(tester, const Size(411, 420));
      expect(_offset(tester), 0);

      await tester.pumpWidget(screen(unopenedLink: _publicSiteFailure));
      await tester.pumpAndSettle();

      expectNoticeInView(tester);
    });

    // Defaut 2 : l'usager redescend, rappuie sur le meme bouton, nouvel echec
    // du MEME lien. L'avis est deja a l'ecran : sans nouvel etat, il ne se
    // devoile pas et le bouton paraitrait inerte. Le ViewModel numerote
    // chaque echec ; ce numero est la cle de l'avis.
    for (final (String, UnopenedLink, UnopenedLink) failures
        in <(String, UnopenedLink, UnopenedLink)>[
          ('site public', _publicSiteFailure, _publicSiteSecondFailure),
          ('arrete', _decreeFailure, _decreeSecondFailure),
        ]) {
      testWidgetsOnWindows('second echec du meme lien (${failures.$1}) : '
          'l avis, que l usager a quitte des yeux, est ramene dans le champ', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, _window);
        await tester.pumpWidget(screen(unopenedLink: failures.$2));
        await tester.pumpAndSettle();
        expectNoticeInView(tester);

        // L'usager descend : l'avis sort du champ, le meme lien est rappuye.
        tester
            .state<ScrollableState>(_mainScrollable)
            .position
            .jumpTo(_max(tester));
        await tester.pump();
        final Rect view = tester.getRect(_mainScrollable);
        expect(
          tester.getRect(notice).bottom,
          lessThanOrEqualTo(view.top),
          reason: 'l avis doit etre sorti du champ avant le second echec',
        );

        await tester.pumpWidget(screen(unopenedLink: failures.$3));
        await tester.pumpAndSettle();

        expectNoticeInView(tester);
      });
    }

    // Tete NON epinglee : une fenetre trop basse pour epingler (la tete est
    // alors le premier element du defilement). Le test « telephone » ci-dessus
    // tourne, lui, tete epinglee.
    group('tete non epinglee (fenetre trop basse pour epingler)', () {
      Future<void> pumpUnpinned(WidgetTester tester) async {
        await pumpAt(tester, _window);
        final double headerHeight = tester
            .getSize(find.byKey(reinforcedWarningHeaderKey))
            .height;
        tester.view.physicalSize = Size(_window.width, headerHeight * 2);
        await tester.pumpAndSettle();
        expect(_headerPinned(), isFalse);
      }

      testWidgetsOnWindows('en haut, avis sous la ligne de flottaison : y '
          'est amene', (WidgetTester tester) async {
        await pumpUnpinned(tester);
        expect(_offset(tester), 0);

        await tester.pumpWidget(screen(unopenedLink: _publicSiteFailure));
        await tester.pumpAndSettle();

        expectNoticeInView(tester);
      });

      testWidgetsOnWindows('descendu, avis au-dessus de la zone visible : y '
          'est amene', (WidgetTester tester) async {
        await pumpUnpinned(tester);
        tester
            .state<ScrollableState>(_mainScrollable)
            .position
            .jumpTo(_max(tester));
        await tester.pump();
        expect(_offset(tester), greaterThan(300));

        await tester.pumpWidget(screen(unopenedLink: _publicSiteFailure));
        await tester.pumpAndSettle();

        expectNoticeInView(tester);
      });
    });

    testWidgetsOnWindows(
      'arrete non ouvert, bouton au bas de la zone '
      'visible : l avis, qui nait sous le bouton hors du champ, y est amene',
      (WidgetTester tester) async {
        await pumpAt(tester, _window);
        final Finder button = find.text("Ouvrir l'arrêté");
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        // Le bouton remonte jusqu'a 12 px du bas de la zone visible : l'avis,
        // pose juste dessous, n'y tient pas.
        final Rect view = tester.getRect(_mainScrollable);
        final double wanted =
            _offset(tester) +
            tester.getRect(button).bottom -
            (view.bottom - 12);
        tester.state<ScrollableState>(_mainScrollable).position.jumpTo(wanted);
        await tester.pump();
        expect(_offset(tester), wanted);
        final Rect buttonAt = tester.getRect(button);
        expect(buttonAt.top, greaterThanOrEqualTo(view.top));
        expect(buttonAt.bottom, lessThanOrEqualTo(view.bottom));
        expect(notice, findsNothing);

        await tester.pumpWidget(screen(unopenedLink: _decreeFailure));
        await tester.pumpAndSettle();

        expectNoticeInView(tester);
      },
    );

    testWidgetsOnWindows('avis plus haut que la zone visible (petit ecran, '
        '200 %) : son DEBUT est dans le champ, pas sa fin', (
      WidgetTester tester,
    ) async {
      const Size small = Size(411, 500);
      await pumpAt(tester, small, textScale: 2);
      await tester.pumpWidget(
        screen(unopenedLink: _publicSiteFailure, textScale: 2),
      );
      await tester.pumpAndSettle();

      final Rect view = tester.getRect(_mainScrollable);
      final Rect at = tester.getRect(notice);
      expect(
        at.height,
        greaterThan(view.height),
        reason: 'l avis doit etre plus haut que la zone : $at / $view',
      );
      expect(at.top, greaterThanOrEqualTo(view.top), reason: '$at / $view');
      expect(at.top, lessThan(view.bottom), reason: '$at / $view');
    });
  });

  group('H3 : la molette defile, ou que soit le pointeur', () {
    testWidgetsOnWindows('au milieu du contenu, vers le bas puis le haut', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 300);
      expect(_offset(tester), 300);
      await _wheel(tester, const Offset(633, 500), -300);
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('jusqu en bas et retour en haut, a la molette', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      for (int i = 0; i < 40; i++) {
        await _wheel(tester, const Offset(633, 500), 200);
      }
      expect(_offset(tester), _max(tester));
      for (int i = 0; i < 40; i++) {
        await _wheel(tester, const Offset(633, 500), -200);
      }
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('sur la tete epinglee de l encart', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Offset header = tester.getCenter(
        find.textContaining(reinforcedWarningHeadline),
      );
      await _wheel(tester, header, 300);
      expect(_offset(tester), greaterThan(0));
    });

    testWidgetsOnWindows('sur l adresse selectionnable du site public', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Offset address = tester.getCenter(
        find.byType(SelectableText).first,
      );
      await _wheel(tester, address, 300);
      expect(_offset(tester), greaterThan(0));
    });

    testWidgetsOnWindows('sur une carte d arrete et sur un choix de profil', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      for (final Finder target in <Finder>[
        find.text('Adresse du document').first,
        find.byKey(restrictionsProfileChoiceKey(UserProfile.particulier)),
      ]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final double before = _offset(tester);
        await _wheel(tester, tester.getCenter(target), 100);
        expect(_offset(tester), greaterThan(before), reason: '$target');
      }
    });

    testWidgetsOnWindows('sur la barre de titre', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(
        tester,
        tester.getCenter(find.text(restrictionsScreenTitle)),
        300,
      );
      expect(_offset(tester), 300);
    });
  });

  group('H3 bis : balayage de la molette et composition', () {
    testWidgetsOnWindows('balayage : chaque point sous la barre de titre fait '
        'defiler, a plusieurs positions', (WidgetTester tester) async {
      await _pump(tester);
      final double barBottom = tester
          .getRect(
            find
                .ancestor(
                  of: find.text(restrictionsScreenTitle),
                  matching: find.byType(Material),
                )
                .first,
          )
          .bottom;
      final List<String> dead = <String>[];
      for (final double start in <double>[0, 400, 900]) {
        for (double y = barBottom + 5; y < _window.height; y += 23) {
          for (double x = 20; x < _window.width; x += 150) {
            final ScrollableState s = tester.state(_mainScrollable);
            s.position.jumpTo(start.clamp(0, s.position.maxScrollExtent - 60));
            await tester.pump();
            final double before = _offset(tester);
            await _wheel(tester, Offset(x, y), 50);
            if (_offset(tester) == before) {
              dead.add('(${x.toInt()},${y.toInt()})@${start.toInt()}');
            }
          }
        }
      }
      debugPrint(
        'points morts (${dead.length}) : ${dead.map((String d) => d.split(',').last).toSet()}',
      );
      expect(dead, isEmpty);
    });

    testWidgetsOnWindows('pousse par-dessus une carte (MaterialPageRoute) : la '
        'molette n atteint pas la carte, l ecran defile', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      int mapSignals = 0;
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Listener(
            onPointerSignal: (PointerSignalEvent _) => mapSignals++,
            child: const SizedBox.expand(
              child: ColoredBox(color: Colors.green),
            ),
          ),
        ),
      );
      final ValueNotifier<int> ticks = ValueNotifier<int>(0);
      addTearDown(ticks.dispose);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ListenableBuilder(
            listenable: ticks,
            builder: (BuildContext context, Widget? _) => RestrictionsScreen(
              state: ZonesTrouvees(zonesAin()),
              profile: UserProfile.particulier,
              onChooseProfile: (UserProfile _) {},
              onRetry: () {},
              onOpenDocument: (DocumentLink _, LinkTarget _) {},
              onOpenPublicSite: () {},
              utcOffsetOf: (DateTime _) => const Duration(hours: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _wheel(tester, const Offset(633, 500), 300);
      expect(_offset(tester), 300);
      // Le ViewModel notifie (reconstruction) : la position reste.
      ticks.value++;
      await tester.pumpAndSettle();
      expect(_offset(tester), 300);
      expect(mapSignals, 0);
    });

    testWidgetsOnWindows('pave tactile (pan-zoom) : defile', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final TestPointer pad = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pad.panZoomStart(const Offset(633, 500)));
      for (int i = 1; i <= 10; i++) {
        await tester.sendEventToBinding(
          pad.panZoomUpdate(const Offset(633, 500), pan: Offset(0, -30.0 * i)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendEventToBinding(pad.panZoomEnd());
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(0));
    });
  });

  group('H1 : glisser', () {
    testWidgetsOnWindows('au doigt : defile', (WidgetTester tester) async {
      await _pump(tester);
      await tester.dragFrom(const Offset(633, 600), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_offset(tester), greaterThan(0));
    });

    // Comportement par defaut de Flutter, garde : a la souris, le glisser ne
    // defile pas (la molette, la barre et le clavier le font). Sans quoi un
    // clic un peu tremble sur un choix ou un bouton serait perdu.
    testWidgetsOnWindows('a la souris : ne defile PAS', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.dragFrom(
        const Offset(633, 600),
        const Offset(0, -300),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_offset(tester), 0);
    });

    testWidgetsOnWindows('clic souris tremble de 3 px sur un choix de profil : '
        'le choix est fait', (WidgetTester tester) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final List<UserProfile> chosen = <UserProfile>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RestrictionsScreen(
            state: ZonesTrouvees(zonesAin()),
            profile: null,
            onChooseProfile: chosen.add,
            onRetry: () {},
            onOpenDocument: (DocumentLink _, LinkTarget _) {},
            onOpenPublicSite: () {},
            utcOffsetOf: (DateTime _) => const Duration(hours: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder choice = find.byKey(
        restrictionsProfileChoiceKey(UserProfile.entreprise),
      );
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final Offset at = tester.getCenter(choice);
      final TestPointer mouse = TestPointer(3, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.down(at));
      await tester.sendEventToBinding(mouse.move(at + const Offset(0, 3)));
      await tester.sendEventToBinding(mouse.up());
      await tester.pumpAndSettle();
      expect(chosen, <UserProfile>[UserProfile.entreprise]);
    });
  });

  group('glisser a la souris et selection', () {
    EditableTextState address(WidgetTester tester) => tester.state(
      find
          .descendant(
            of: find.byType(SelectableText).at(1),
            matching: find.byType(EditableText),
          )
          .first,
    );

    testWidgetsOnWindows('glisser HORIZONTALEMENT sur une adresse la '
        'selectionne, sans defiler', (WidgetTester tester) async {
      await _pump(tester);
      final Finder text = find.byType(SelectableText).at(1);
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();
      final double before = _offset(tester);
      final Rect rect = tester.getRect(text);
      await tester.dragFrom(
        rect.centerLeft + const Offset(2, 0),
        Offset(rect.width * 0.6, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final TextSelection selection = address(tester)
          .textEditingValue
          .selection;
      debugPrint('selection apres glisser horizontal : $selection');
      expect(selection.isCollapsed, isFalse);
      expect(_offset(tester), before);
    });

    // Constat : partant d'une adresse, la selection du texte gagne ; pour
    // faire defiler, glisser ailleurs ou utiliser la molette.
    testWidgetsOnWindows('glisser VERTICALEMENT depuis une adresse la '
        'selectionne', (WidgetTester tester) async {
      await _pump(tester);
      final Finder text = find.byType(SelectableText).at(1);
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();
      final double before = _offset(tester);
      await tester.dragFrom(
        tester.getCenter(text),
        const Offset(0, -200),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      debugPrint(
        'glisser vertical sur l adresse : offset ${before.toInt()} -> '
        '${_offset(tester).toInt()}, selection '
        '${address(tester).textEditingValue.selection}',
      );
      expect(address(tester).textEditingValue.selection.isCollapsed, isFalse);
    });

    testWidgetsOnWindows('barre de defilement toujours visible', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Une seule barre pour le defilement de l'ecran (l'automatique est
      // retiree) ; les `SelectableText` gardent la leur, interne.
      final Finder bars = find.ancestor(
        of: _mainScrollable,
        matching: find.byType(Scrollbar),
      );
      expect(bars, findsOneWidget);
      expect(tester.widget<Scrollbar>(bars).thumbVisibility, isTrue);
      expect(
        find.descendant(of: _mainScrollable, matching: find.byType(Scrollbar)),
        findsNWidgets(find.byType(SelectableText).evaluate().length),
      );
    });
  });

  // `Espace` n'est pas une touche de defilement de Flutter sur Windows :
  // c'est l'activation (`ActivateIntent`, `WidgetsApp.defaultShortcuts`).
  // `PageUp`/`PageDown` et `Ctrl`+fleches le sont.
  group('H4 : clavier (desktop)', () {
    for (final MapEntry<String, LogicalKeyboardKey> key
        in <String, LogicalKeyboardKey>{
          'PageDown': LogicalKeyboardKey.pageDown,
          'Flèche bas': LogicalKeyboardKey.arrowDown,
        }.entries) {
      testWidgetsOnWindows('${key.key} a l ouverture defile vers le bas', (
        WidgetTester tester,
      ) async {
        await _pump(tester);
        await tester.sendKeyEvent(key.value);
        await tester.pumpAndSettle();
        expect(_offset(tester), greaterThan(0));
      });
    }

    testWidgetsOnWindows('PageUp remonte', (WidgetTester tester) async {
      await _pump(tester);
      await _wheel(tester, const Offset(633, 500), 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(_offset(tester), lessThan(600));
    });
  });
}

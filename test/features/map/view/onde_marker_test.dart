// Verrouille le marqueur ONDE de l'echelle 1 (T1-U3). Les six lignes du
// tableau de `04-ui.md` § 2 — teinte, forme, motif, libelle carte — sont
// RETAPEES ici, litteral par litteral : sur ce projet le test EST la recopie
// verifiee de la specification, jamais un renvoi vers la constante qu'il
// devrait controler. Une teinte changee dans `onde_marker.dart` sans que
// `04-ui.md` bouge doit rendre ce fichier rouge.
//
// Trois autres exigences y sont verrouillees :
// - BR-010 : TOUT point ONDE annonce la date de sa derniere campagne, et
//   au-dela de 60 jours l'etat passe en gris — quelle que soit la categorie
//   — la mention devenant « derniere observation le … » ;
// - `04-ui.md` § 3 : les rendus restent distinguables EN NIVEAUX DE GRIS —
//   le test compare formes et motifs, pas seulement les couleurs — et le
//   halo de 2 px est present sur toutes ;
// - BR-007 : `NonObserve` (fait de terrain) et `Inconnu` (notre ignorance)
//   partagent teinte et forme mais JAMAIS le libelle.
//
// Le peintre est teste par un `Canvas` d'enregistrement plutot qu'a l'oeil :
// il capture les appels de dessin, ce qui prouve d'un coup que la forme est
// DESSINEE (aucun glyphe), que le halo fait 2 px et que les motifs different
// reellement l'un de l'autre. Le rendu lui-meme — l'aspect — est l'affaire
// des goldens de `U5`.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';

/// Les cinq mots proscrits pour qualifier un debit (BR-003, `glossary.md`).
const List<String> bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

/// Les six categories de `FlowCategory`, dans l'ordre du tableau de
/// `04-ui.md` § 2 complete par la sixieme ligne du tableau `U3` du plan T1 et
/// par le domaine (`flowCategoryLabel`) : « Non renseigne », une DEVIATION
/// d'`ADR-006` — qui range un code inconnu sous « Non observe » — retenue
/// pour `BR-007` et a acter par le commanditaire.
const List<FlowCategory> allCategories = <FlowCategory>[
  Ecoulement(),
  EcoulementFaible(),
  EcoulementNonVisible(),
  Assec(),
  NonObserve(),
  Inconnu('9z'),
];

/// Un appel de dessin capture : le trace, et ce qu'on en a fait.
final class _RecordedDraw {
  _RecordedDraw(this.path, Paint paint)
    : argb = paint.color.toARGB32(),
      style = paint.style,
      strokeWidth = paint.strokeWidth;

  final Path path;

  /// La teinte en ARGB entier, et non l'objet `Color` : un `Paint` range ses
  /// composantes en flottants, et la valeur relue n'est plus `==` au
  /// litteral const d'origine alors qu'elle designe la meme couleur.
  final int argb;
  final PaintingStyle style;
  final double strokeWidth;

  /// Nombre de contours du trace. Un cercle plein en a UN ; un contour
  /// pointille et des hachures en ont plusieurs. C'est ce qui separe les
  /// motifs sans avoir a recopier la geometrie de l'implementation.
  int get contours => path.computeMetrics().length;
}

/// Un `Canvas` qui n'affiche rien et note ce qu'on lui demande de dessiner.
/// `noSuchMethod` absorbe le reste de l'interface : le peintre n'appelle que
/// `drawPath`, et c'est precisement ce que ce test veut prouver.
final class _RecordingCanvas implements Canvas {
  final List<_RecordedDraw> draws = <_RecordedDraw>[];

  @override
  void drawPath(Path path, Paint paint) {
    draws.add(_RecordedDraw(path, paint));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<_RecordedDraw> _paint(FlowCategory category, CampaignAge age) {
  final _RecordingCanvas canvas = _RecordingCanvas();
  OndeMarkerPainter.forCategory(
    category: category,
    age: age,
  ).paint(canvas, const Size.square(stationMarkerSize));
  return canvas.draws;
}

/// Le seul trait de contour d'un marqueur : son halo.
_RecordedDraw _halo(List<_RecordedDraw> draws) => draws.singleWhere(
  (_RecordedDraw draw) => draw.style == PaintingStyle.stroke,
);

/// Les remplissages d'un marqueur — zero ou un.
List<_RecordedDraw> _fills(List<_RecordedDraw> draws) => draws
    .where((_RecordedDraw draw) => draw.style == PaintingStyle.fill)
    .toList();

Future<void> _pumpShape(
  WidgetTester tester, {
  required FlowCategory category,
  required CampaignAge age,
  required DateTime? observedAt,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: stationMarkerSize,
            height: stationMarkerSize,
            child: OndeMarkerShape(
              category: category,
              age: age,
              observedAt: observedAt,
            ),
          ),
        ),
      ),
    ),
  );
}

String _labelOf(WidgetTester tester) => tester
    .widget<Semantics>(
      find.descendant(
        of: find.byType(OndeMarkerShape),
        matching: find.byType(Semantics),
      ),
    )
    .properties
    .label!;

void main() {
  group('ondeCategoryColor — les six teintes de 04-ui.md § 2, valeur par '
      'valeur', () {
    test('Ecoulement est #0072B2', () {
      expect(ondeCategoryColor(const Ecoulement()), const Color(0xFF0072B2));
    });

    test('EcoulementFaible est #56B4E9', () {
      expect(
        ondeCategoryColor(const EcoulementFaible()),
        const Color(0xFF56B4E9),
      );
    });

    test('EcoulementNonVisible est #E69F00', () {
      expect(
        ondeCategoryColor(const EcoulementNonVisible()),
        const Color(0xFFE69F00),
      );
    });

    test('Assec est #D55E00', () {
      expect(ondeCategoryColor(const Assec()), const Color(0xFFD55E00));
    });

    test('NonObserve est #767676', () {
      expect(ondeCategoryColor(const NonObserve()), const Color(0xFF767676));
    });

    test('Inconnu est #767676 — la meme teinte que NonObserve (ADR-006)', () {
      expect(ondeCategoryColor(const Inconnu('9z')), const Color(0xFF767676));
    });
  });

  group('ondeCategoryMapLabel — les six libelles carte de 04-ui.md § 2', () {
    test('Ecoulement dit « Eau qui coule »', () {
      expect(ondeCategoryMapLabel(const Ecoulement()), 'Eau qui coule');
    });

    test('EcoulementFaible dit « Écoulement faible »', () {
      expect(
        ondeCategoryMapLabel(const EcoulementFaible()),
        'Écoulement faible',
      );
    });

    test('EcoulementNonVisible dit « Eau stagnante »', () {
      expect(
        ondeCategoryMapLabel(const EcoulementNonVisible()),
        'Eau stagnante',
      );
    });

    test('Assec dit « À sec » — jamais « Assec » ni « asséché » : un '
        'concept, un mot (glossary.md)', () {
      expect(ondeCategoryMapLabel(const Assec()), 'À sec');
      expect(
        ondeCategoryMapLabel(const Assec()).toLowerCase(),
        isNot(contains('assec')),
      );
      expect(
        ondeCategoryMapLabel(const Assec()).toLowerCase(),
        isNot(contains('asséch')),
      );
    });

    test('NonObserve dit « Non observé »', () {
      expect(ondeCategoryMapLabel(const NonObserve()), 'Non observé');
    });

    test('Inconnu dit « Non renseigné »', () {
      expect(ondeCategoryMapLabel(const Inconnu('9z')), 'Non renseigné');
    });

    test('le libelle carte est CELUI DU DOMAINE, pas une seconde liste — un '
        'point annonce « Eau qui coule » ouvre une fiche qui dit « Eau qui '
        'coule » (glossary.md, relecture du 2026-09-14)', () {
      for (final FlowCategory category in allCategories) {
        expect(
          ondeCategoryMapLabel(category),
          flowCategoryLabel(category),
          reason: '$category',
        );
      }
    });

    test('aucun libelle carte ne contient un mot banni (BR-003)', () {
      for (final FlowCategory category in allCategories) {
        final Set<String> words = ondeCategoryMapLabel(category)
            .toLowerCase()
            .split(RegExp(r'[^a-zà-öø-ÿ]+'))
            .toSet();
        for (final String banned in bannedWords) {
          expect(
            words,
            isNot(contains(banned)),
            reason:
                '"$banned" trouve dans « ${ondeCategoryMapLabel(category)} »',
          );
        }
      }
    });
  });

  group('NonObserve et Inconnu — meme rendu, jamais le meme mot (BR-007)', () {
    test('meme teinte et meme forme', () {
      expect(
        ondeCategoryColor(const NonObserve()),
        ondeCategoryColor(const Inconnu(null)),
      );
      expect(
        ondeCategoryShape(const NonObserve()),
        ondeCategoryShape(const Inconnu(null)),
      );
      expect(
        ondeCategoryPattern(const NonObserve()),
        ondeCategoryPattern(const Inconnu(null)),
      );
    });

    test('libelles differents — un fait de terrain constate n est pas notre '
        'ignorance', () {
      expect(
        ondeCategoryMapLabel(const NonObserve()),
        isNot(ondeCategoryMapLabel(const Inconnu(null))),
      );
    });
  });

  group('BR-010 — au-dela de 60 jours, gris et date', () {
    test('age ancienne : la teinte effective est #767676 pour les SIX '
        'categories', () {
      for (final FlowCategory category in allCategories) {
        expect(
          ondeEffectiveColor(category: category, age: CampaignAge.ancienne),
          const Color(0xFF767676),
          reason: '$category doit virer au gris passe 60 jours',
        );
      }
    });

    test('age recente : la teinte de la categorie est conservee', () {
      for (final FlowCategory category in allCategories) {
        expect(
          ondeEffectiveColor(category: category, age: CampaignAge.recente),
          ondeCategoryColor(category),
        );
      }
    });

    test('le peintre remplit avec la teinte effective, pas celle de la '
        'categorie', () {
      expect(
        OndeMarkerPainter.forCategory(
          category: const Assec(),
          age: CampaignAge.ancienne,
        ).fillColor,
        const Color(0xFF767676),
      );
      expect(
        OndeMarkerPainter.forCategory(
          category: const Assec(),
          age: CampaignAge.recente,
        ).fillColor,
        const Color(0xFFD55E00),
      );
    });

    testWidgets('age ancienne : le libelle semantique porte la date de la '
        'derniere observation', (WidgetTester tester) async {
      await _pumpShape(
        tester,
        category: const Assec(),
        age: CampaignAge.ancienne,
        observedAt: DateTime.utc(2025, 9, 26),
      );

      final String label = _labelOf(tester);
      expect(label, contains('À sec'));
      expect(label, contains('dernière observation le 26/09/2025'));
    });

    testWidgets('age recente : la date de campagne est annoncee AUSSI — '
        '« tout point ONDE affiche la date de sa derniere campagne » '
        '(BR-010)', (WidgetTester tester) async {
      await _pumpShape(
        tester,
        category: const Assec(),
        age: CampaignAge.recente,
        observedAt: DateTime.utc(2026, 8, 25),
      );

      expect(_labelOf(tester), contains('campagne du 25/08/2026'));
    });

    test('une legende, elle, n a aucune date a montrer : observedAt y est '
        'passe a null, EXPLICITEMENT — le parametre est requis', () {
      expect(
        () => OndeMarkerShape(
          category: const Assec(),
          age: CampaignAge.recente,
          observedAt: null,
        ),
        returnsNormally,
      );
    });
  });

  group('distinction EN NIVEAUX DE GRIS (04-ui.md § 3)', () {
    test('les cinq rendus visuels ont des couples (forme, motif) deux a deux '
        'distincts — la couleur ne porte aucune information seule', () {
      const List<FlowCategory> visuals = <FlowCategory>[
        Ecoulement(),
        EcoulementFaible(),
        EcoulementNonVisible(),
        Assec(),
        NonObserve(),
      ];

      final Set<(OndeMarkerShapeKind, OndeMarkerPattern)> couples = visuals
          .map(
            (FlowCategory category) =>
                (ondeCategoryShape(category), ondeCategoryPattern(category)),
          )
          .toSet();

      expect(couples, hasLength(visuals.length));
    });

    test('les formes et motifs sont ceux de 04-ui.md § 2, ligne a ligne', () {
      expect(ondeCategoryShape(const Ecoulement()), OndeMarkerShapeKind.cercle);
      expect(ondeCategoryPattern(const Ecoulement()), OndeMarkerPattern.plein);

      expect(
        ondeCategoryShape(const EcoulementFaible()),
        OndeMarkerShapeKind.cercleMiPlein,
      );
      expect(
        ondeCategoryPattern(const EcoulementFaible()),
        OndeMarkerPattern.demiPlein,
      );

      expect(
        ondeCategoryShape(const EcoulementNonVisible()),
        OndeMarkerShapeKind.triangle,
      );
      expect(
        ondeCategoryPattern(const EcoulementNonVisible()),
        OndeMarkerPattern.hachuresObliques,
      );

      expect(ondeCategoryShape(const Assec()), OndeMarkerShapeKind.carre);
      expect(
        ondeCategoryPattern(const Assec()),
        OndeMarkerPattern.pleinContourNoir,
      );

      expect(
        ondeCategoryShape(const NonObserve()),
        OndeMarkerShapeKind.cercleVide,
      );
      expect(
        ondeCategoryPattern(const NonObserve()),
        OndeMarkerPattern.contourPointille,
      );
    });

    test('la forme reste distincte meme quand la teinte ne l est plus : deux '
        'categories grises passe 60 jours gardent leur forme', () {
      final OndeMarkerPainter stagnante = OndeMarkerPainter.forCategory(
        category: const EcoulementNonVisible(),
        age: CampaignAge.ancienne,
      );
      final OndeMarkerPainter aSec = OndeMarkerPainter.forCategory(
        category: const Assec(),
        age: CampaignAge.ancienne,
      );

      expect(stagnante.fillColor, aSec.fillColor);
      expect(stagnante.shape, isNot(aSec.shape));
      expect(stagnante.pattern, isNot(aSec.pattern));
    });
  });

  group('le peintre — une forme DESSINEE, un halo de 2 px', () {
    test('chaque categorie porte un halo noir de 2 px, et un seul', () {
      for (final FlowCategory category in allCategories) {
        final _RecordedDraw halo = _halo(_paint(category, CampaignAge.recente));

        expect(halo.strokeWidth, stationMarkerBorderWidth);
        expect(halo.strokeWidth, 2);
        expect(halo.argb, 0xFF000000);
      }
    });

    test('le halo garde ses 2 px passe 60 jours : l attenuation ne touche '
        'jamais la lisibilite de la forme', () {
      final _RecordedDraw halo = _halo(
        _paint(const Assec(), CampaignAge.ancienne),
      );

      expect(halo.strokeWidth, 2);
      expect(halo.argb, 0xFF000000);
    });

    test('motif « plein » : un remplissage d un seul tenant, qui couvre les '
        'deux cotes du centre', () {
      final List<_RecordedDraw> fills = _fills(
        _paint(const Ecoulement(), CampaignAge.recente),
      );

      expect(fills, hasLength(1));
      expect(fills.single.contours, 1);
      expect(fills.single.argb, 0xFF0072B2);
      expect(fills.single.path.contains(const Offset(3, 6)), isTrue);
      expect(fills.single.path.contains(const Offset(9, 6)), isTrue);
    });

    test('motif « demi-plein » : un seul cote du centre est rempli', () {
      final List<_RecordedDraw> fills = _fills(
        _paint(const EcoulementFaible(), CampaignAge.recente),
      );

      expect(fills, hasLength(1));
      final Path fill = fills.single.path;
      expect(
        fill.contains(const Offset(9, 6)) != fill.contains(const Offset(3, 6)),
        isTrue,
        reason: 'un cercle MI-plein remplit une moitie, pas les deux',
      );
    });

    test('motif « hachures obliques » : plusieurs contours, et des vides '
        'entre eux', () {
      final List<_RecordedDraw> fills = _fills(
        _paint(const EcoulementNonVisible(), CampaignAge.recente),
      );

      expect(fills, hasLength(1));
      final _RecordedDraw hatches = fills.single;
      expect(
        hatches.contours,
        greaterThan(1),
        reason: 'des hachures sont plusieurs traits, pas un aplat',
      );

      // Il existe, dans l'emprise des hachures, au moins un point couvert et
      // au moins un point vide : c'est ce qui fait un MOTIF plutot qu'un
      // remplissage plein.
      final Rect bounds = hatches.path.getBounds();
      bool covered = false;
      bool empty = false;
      for (int x = 1; x < 20; x++) {
        for (int y = 1; y < 20; y++) {
          final Offset point = Offset(
            bounds.left + bounds.width * x / 20,
            bounds.top + bounds.height * y / 20,
          );
          if (hatches.path.contains(point)) {
            covered = true;
          } else {
            empty = true;
          }
        }
      }
      expect(covered, isTrue);
      expect(empty, isTrue);
    });

    test('motif « contour pointille » : aucun remplissage, et un halo '
        'decoupe en plusieurs traits', () {
      final List<_RecordedDraw> draws = _paint(
        const NonObserve(),
        CampaignAge.recente,
      );

      expect(_fills(draws), isEmpty);
      expect(
        _halo(draws).contours,
        greaterThan(1),
        reason: 'un contour pointille est fait de tirets separes',
      );
    });

    test('un contour continu n a qu un seul trace — la contre-epreuve du '
        'pointille', () {
      expect(
        _halo(_paint(const Ecoulement(), CampaignAge.recente)).contours,
        1,
      );
      expect(_halo(_paint(const Assec(), CampaignAge.recente)).contours, 1);
    });

    test('deux peintres de meme categorie et meme age sont egaux : rien ne '
        'se repeint pour rien (NFR-01)', () {
      expect(
        OndeMarkerPainter.forCategory(
          category: const Assec(),
          age: CampaignAge.recente,
        ),
        OndeMarkerPainter.forCategory(
          category: const Assec(),
          age: CampaignAge.recente,
        ),
      );
      expect(
        OndeMarkerPainter.forCategory(
          category: const Assec(),
          age: CampaignAge.recente,
        ).shouldRepaint(
          OndeMarkerPainter.forCategory(
            category: const Assec(),
            age: CampaignAge.recente,
          ),
        ),
        isFalse,
      );
    });
  });

  group('OndeMarkerShape — le widget', () {
    testWidgets('dessine sa forme, jamais un glyphe de police', (
      WidgetTester tester,
    ) async {
      await _pumpShape(
        tester,
        category: const Assec(),
        age: CampaignAge.recente,
        observedAt: null,
      );

      expect(
        find.descendant(
          of: find.byType(OndeMarkerShape),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(OndeMarkerShape),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(OndeMarkerShape),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('mesure stationMarkerSize — 12 px, la taille VISUELLE, pas '
        'la cible tactile', (WidgetTester tester) async {
      await _pumpShape(
        tester,
        category: const Assec(),
        age: CampaignAge.recente,
        observedAt: null,
      );

      expect(
        tester.getSize(find.byType(OndeMarkerShape)),
        const Size(stationMarkerSize, stationMarkerSize),
      );
      expect(stationMarkerSize, 12);
      expect(stationMarkerTapTarget, 44);
    });

    testWidgets('porte son PROPRE libelle semantique : c est ce qui rend la '
        'forme annoncable telle quelle en legende', (
      WidgetTester tester,
    ) async {
      for (final FlowCategory category in allCategories) {
        await _pumpShape(
          tester,
          category: category,
          age: CampaignAge.recente,
          observedAt: null,
        );

        expect(_labelOf(tester), ondeCategoryMapLabel(category));
      }
    });
  });

  group('ondeMarkerLabel — l annonce, assemblee en un seul endroit', () {
    test('categorie seule — la legende, qui n a ni point ni date', () {
      expect(
        ondeMarkerLabel(
          category: const Assec(),
          age: CampaignAge.recente,
          observedAt: null,
        ),
        'À sec',
      );
    });

    test('categorie et point nomme, sans date connue', () {
      expect(
        ondeMarkerLabel(
          category: const Assec(),
          age: CampaignAge.recente,
          observedAt: null,
          pointLabel: 'Le Trey à Vilcey-sur-Trey',
        ),
        'À sec — Le Trey à Vilcey-sur-Trey',
      );
    });

    test('campagne recente : la date est annoncee AUSSI, avec la nature de '
        'l observation — « tout point ONDE affiche la date de sa derniere '
        'campagne » (BR-010, 04-ui.md § 3)', () {
      expect(
        ondeMarkerLabel(
          category: const Assec(),
          age: CampaignAge.recente,
          observedAt: DateTime.utc(2026, 8, 25),
          pointLabel: 'Ruisseau des Fées',
        ),
        'À sec — Ruisseau des Fées, campagne du 25/08/2026, observation '
        'visuelle ponctuelle',
      );
    });

    test('passe 60 jours, la mention de BR-010 remplace « campagne du »', () {
      expect(
        ondeMarkerLabel(
          category: const Assec(),
          age: CampaignAge.ancienne,
          observedAt: DateTime.utc(2025, 9, 26),
          pointLabel: 'Le Trey à Vilcey-sur-Trey',
        ),
        'À sec — Le Trey à Vilcey-sur-Trey, dernière observation le '
        '26/09/2025, observation visuelle ponctuelle',
      );
    });

    test('la date est zero-remplie — 01/05/2026, jamais 1/5/2026', () {
      expect(
        ondeMarkerLabel(
          category: const Ecoulement(),
          age: CampaignAge.ancienne,
          observedAt: DateTime.utc(2026, 5, 1),
        ),
        contains('01/05/2026'),
      );
    });
  });

  test('le peintre ne fait que deux appels de dessin au plus — 4 150 '
      'marqueurs peuvent etre peints a chaque trame (NFR-01)', () {
    for (final FlowCategory category in allCategories) {
      for (final CampaignAge age in CampaignAge.values) {
        expect(
          _paint(category, age).length,
          lessThanOrEqualTo(2),
          reason: '$category / $age',
        );
      }
    }
  });

  test('la geometrie est mise en cache par taille : deux peintures de suite '
      'rendent des traces identiques (aucune allocation par trame)', () {
    final List<_RecordedDraw> first = _paint(
      const EcoulementNonVisible(),
      CampaignAge.recente,
    );
    final List<_RecordedDraw> second = _paint(
      const EcoulementNonVisible(),
      CampaignAge.recente,
    );

    expect(first.length, second.length);
    for (int index = 0; index < first.length; index++) {
      expect(
        identical(first[index].path, second[index].path),
        isTrue,
        reason: 'le trace doit etre celui du cache, pas un trace recalcule',
      );
    }
    // `dart:ui` est importe pour cette assertion de type seulement : un
    // `Path` est bien un trace de `dart:ui`, jamais un widget.
    expect(first.first.path, isA<ui.Path>());
  });
}

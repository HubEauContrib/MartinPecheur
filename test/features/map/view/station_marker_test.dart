// Verrouille la pastille d'une station sur l'echelle « debit » (T1-U2).
//
// Trois choses, et les trois comptent :
// - la teinte est RECOPIEE de `04-ui.md` § 2 (echelle 2, « Indetermine » →
//   `#767676`), jamais choisie ici : en T1 aucun percentile n'existe
//   (ADR-003 hors T1), donc toute station est « Indetermine » au sens de
//   BR-004 ;
// - les six etats de `StationMapState` rendent six combinaisons observables
//   TOUTES distinctes — opacite de remplissage, style de contour, libelle
//   semantique. La couleur ne porte aucune de ces distinctions
//   (`04-ui.md` § 3 : jamais la couleur seule) ;
// - la pastille reste une forme DESSINEE, jamais un glyphe de police : au
//   zoom national les 4 150 points sont tous peints, et un glyphe couterait
//   une passe de texte par marqueur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';

/// Les six etats que `StationMapState` peut prendre. Six, et non les cinq du
/// tableau de U2 : `EnEchec` existe dans le domaine depuis V2 et doit, lui
/// aussi, se distinguer des autres a l'ecran (BR-007).
const List<StationMapState> tousLesEtats = <StationMapState>[
  Chargee(Freshness.fraiche),
  Chargee(Freshness.ancienne),
  Chargee(Freshness.perimee),
  SansDonnee(),
  NonChargee(),
  EnEchec('panne de lecture'),
];

Future<void> _pumpDot(WidgetTester tester, StationMapState state) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: stationMarkerSize,
            height: stationMarkerSize,
            child: StationMarkerDot(state: state),
          ),
        ),
      ),
    ),
  );
}

/// Le peintre effectivement monte par la pastille — ce que l'ecran dessine,
/// pas ce que la fabrique repond hors widget.
StationMarkerPainter _paintedBy(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(StationMarkerDot),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as StationMarkerPainter;
}

/// Le libelle annonce au lecteur d'ecran (`04-ui.md` § 3).
String _semanticLabelOf(WidgetTester tester) {
  final Semantics semantics = tester.widget<Semantics>(
    find.descendant(
      of: find.byType(StationMarkerDot),
      matching: find.byType(Semantics),
    ),
  );
  return semantics.properties.label ?? '';
}

void main() {
  group('teintes et mesures recopiees de 04-ui.md', () {
    test('indetermineGrey est le #767676 de l echelle 2 — aucune teinte n est '
        'choisie ici (BR-004, 04-ui.md § 2)', () {
      expect(indetermineGrey, const Color(0xFF767676));
    });

    test('le contour vaut 2 px, halo de marqueur de 04-ui.md § 3', () {
      expect(stationMarkerBorderWidth, 2.0);
    });

    test('la zone de tap vaut 44 pt et reste plus grande que la pastille', () {
      expect(stationMarkerTapTarget, 44.0);
      expect(stationMarkerSize, lessThan(stationMarkerTapTarget));
    });
  });

  group('les six etats rendent six combinaisons distinctes', () {
    testWidgets('deux etats quelconques ne rendent jamais la meme combinaison '
        '(opacite, contour, libelle)', (WidgetTester tester) async {
      final List<(StationMarkerPainter, String)> rendus =
          <(StationMarkerPainter, String)>[];

      for (final StationMapState state in tousLesEtats) {
        await _pumpDot(tester, state);
        rendus.add((_paintedBy(tester), _semanticLabelOf(tester)));
      }

      expect(
        rendus.toSet(),
        hasLength(tousLesEtats.length),
        reason:
            'chaque etat doit se lire a l ecran : deux rendus identiques '
            'fondraient deux situations differentes (BR-007)',
      );
    });

    testWidgets('Chargee(perimee) est attenuee : opacite de remplissage '
        'STRICTEMENT inferieure a Chargee(fraiche) (BR-005)', (
      WidgetTester tester,
    ) async {
      await _pumpDot(tester, const Chargee(Freshness.fraiche));
      final double fraiche = _paintedBy(tester).fillOpacity;

      await _pumpDot(tester, const Chargee(Freshness.perimee));
      final double perimee = _paintedBy(tester).fillOpacity;

      expect(perimee, lessThan(fraiche));
      expect(perimee, greaterThan(0));
    });

    testWidgets("l attenuation ne touche QUE le remplissage : aucune couche "
        'Opacity ne recouvre la pastille, le contour de 2 px garde son '
        'contraste (BR-005, 04-ui.md § 3)', (WidgetTester tester) async {
      for (final StationMapState state in tousLesEtats) {
        await _pumpDot(tester, state);
        expect(
          find.descendant(
            of: find.byType(StationMarkerDot),
            matching: find.byType(Opacity),
          ),
          findsNothing,
          reason: 'un Opacity sur toute la pastille delaverait le contour',
        );
      }
    });

    testWidgets('SansDonnee porte un contour pointille, NonChargee un contour '
        'continu et neutre (BR-007)', (WidgetTester tester) async {
      await _pumpDot(tester, const SansDonnee());
      expect(_paintedBy(tester).outline, StationMarkerOutline.pointille);
      expect(_paintedBy(tester).fillOpacity, 0);

      await _pumpDot(tester, const NonChargee());
      expect(_paintedBy(tester).outline, StationMarkerOutline.continu);
      expect(_paintedBy(tester).fillOpacity, 0);
    });
  });

  group('libelles annonces au lecteur d ecran', () {
    testWidgets('SansDonnee annonce exactement la formulation de repli de '
        'BR-007', (WidgetTester tester) async {
      await _pumpDot(tester, const SansDonnee());

      expect(_semanticLabelOf(tester), 'Aucune donnée disponible ici.');
    });

    testWidgets('NonChargee n annonce AUCUN libelle d etat — un chargement en '
        "cours n'affiche pas d'etat par defaut (BR-007)", (
      WidgetTester tester,
    ) async {
      await _pumpDot(tester, const NonChargee());
      final String label = _semanticLabelOf(tester);

      expect(label, isEmpty);
      for (final StationMapState autre in <StationMapState>[
        const Chargee(Freshness.ancienne),
        const Chargee(Freshness.perimee),
        const SansDonnee(),
        const EnEchec('panne de lecture'),
      ]) {
        expect(label, isNot(contains(stationMapStateLabel(autre))));
      }
    });

    testWidgets('Chargee(ancienne) et Chargee(perimee) reprennent le libelle '
        'du domaine, jamais une recopie locale (BR-005)', (
      WidgetTester tester,
    ) async {
      await _pumpDot(tester, const Chargee(Freshness.ancienne));
      expect(
        _semanticLabelOf(tester),
        stationMapStateLabel(const Chargee(Freshness.ancienne)),
      );

      await _pumpDot(tester, const Chargee(Freshness.perimee));
      expect(
        _semanticLabelOf(tester),
        stationMapStateLabel(const Chargee(Freshness.perimee)),
      );
    });
  });

  group('une forme dessinee, jamais un glyphe de police', () {
    testWidgets('aucun Text ni Icon dans la pastille, quel que soit l etat — '
        '4 150 passes de texte au zoom national (NFR-01)', (
      WidgetTester tester,
    ) async {
      for (final StationMapState state in tousLesEtats) {
        await _pumpDot(tester, state);

        expect(
          find.descendant(
            of: find.byType(StationMarkerDot),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(StationMarkerDot),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('la pastille monte le peintre de son etat', (
      WidgetTester tester,
    ) async {
      for (final StationMapState state in tousLesEtats) {
        await _pumpDot(tester, state);

        expect(_paintedBy(tester), StationMarkerPainter.forState(state));
      }
    });

    testWidgets('la pastille occupe exactement la taille qu on lui donne', (
      WidgetTester tester,
    ) async {
      await _pumpDot(tester, const Chargee(Freshness.fraiche));

      expect(
        tester.getSize(find.byType(StationMarkerDot)),
        const Size(stationMarkerSize, stationMarkerSize),
      );
    });
  });
}

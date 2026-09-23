// Fige le RENDU de la pastille de station (`U5`), ce qu'aucun autre étage
// de `docs/plan-de-tests.md` § 1 ne sait prouver.
//
// `station_marker_test.dart` vérifie déjà que `Chargee(perimee)` demande une
// opacité de remplissage de 0,4 et un contour continu, et que les six états
// produisent six couples (opacité, contour) distincts. Il ne dit rien de ce
// qui se voit : qu'à 0,4 l'atténuation de `BR-005` est réellement
// perceptible, que le halo de 2 px reste à opacité pleine sur une pastille
// atténuée (`04-ui.md` § 3, `NFR-04`), et que le contour pointillé de
// `SansDonnee` se lit comme un pointillé plutôt que comme un trait sale.
//
// ⚠️ **`EnEchec` n'a PAS d'image à lui**, et c'est délibéré : son rendu est
// identique à celui de `SansDonnee` — creux, contour pointillé — écart
// assumé et documenté en tête de `station_marker.dart` (`04-ui.md` § 2 ne
// donne qu'un seul motif « rien à montrer » pour l'échelle 2, en inventer un
// second serait inventer de la spécification). Une image de plus serait
// octet pour octet la même. `EnEchec` figure en revanche dans l'image en
// niveaux de gris, où les **six** états sont montrés côte à côte : c'est là
// que son identité de rendu avec `SansDonnee` se constate.
//
// Les marqueurs sont agrandis 4 × ; la taille de la carte reste 12 px. Les
// images sont plateforme-dépendantes. Voir `golden_harness.dart`.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';

import 'golden_harness.dart';

/// Les cinq états qui ont chacun leur image, et le nom du fichier qui les
/// porte. `EnEchec` en est absent — voir l'en-tête.
const List<(String, StationMapState)> etatsAvecImage =
    <(String, StationMapState)>[
      ('non_chargee', NonChargee()),
      ('chargee_fraiche', Chargee(Freshness.fraiche)),
      ('chargee_ancienne', Chargee(Freshness.ancienne)),
      ('chargee_perimee', Chargee(Freshness.perimee)),
      ('sans_donnee', SansDonnee()),
    ];

/// Les **six** états de l'échelle 2, dans l'ordre de l'image en niveaux de
/// gris : les cinq ci-dessus, plus `EnEchec`.
const List<StationMapState> toutelEchelle = <StationMapState>[
  NonChargee(),
  Chargee(Freshness.fraiche),
  Chargee(Freshness.ancienne),
  Chargee(Freshness.perimee),
  SansDonnee(),
  EnEchec('panne de lecture'),
];

Widget _pastille(StationMapState etat) =>
    caseAgrandie(StationMarkerDot(state: etat));

void main() {
  group('Une image de référence par état de la pastille', () {
    for (final (String nom, StationMapState etat) in etatsAvecImage) {
      testWidgets('le rendu de « $nom » ne change pas sans qu\'on le voie', (
        WidgetTester tester,
      ) async {
        await pompeLImage(
          tester,
          contenu: _pastille(etat),
          taille: const Size(coteDUneCase, coteDUneCase),
        );

        await verifieLImage('station_marker_$nom.png');
      });
    }
  });

  testWidgets('en niveaux de gris, les six états de l\'échelle 2 restent '
      'distinguables', (WidgetTester tester) async {
    // `04-ui.md` § 3 : « La distinction reste assurée par la forme même en
    // achromatopsie ». Sur cette échelle la teinte est la MÊME pour les six
    // états (`#767676`, l'« Indéterminé » de `BR-004`) : la couleur ne
    // portait déjà aucune distinction, et l'image le montre — ce qui sépare
    // les états est le remplissage (plein, atténué, creux) et le contour
    // (continu, pointillé).
    await pompeLImage(
      tester,
      contenu: ColorFiltered(
        colorFilter: filtreNiveauxDeGris,
        child: rangee(toutelEchelle.map(_pastille).toList()),
      ),
      taille: Size(coteDUneCase * toutelEchelle.length, coteDUneCase),
    );

    await verifieLImage('station_marker_echelle_niveaux_de_gris.png');
  });

  testWidgets(
    'une pastille périmée est atténuée, et son halo de 2 px reste entier',
    (WidgetTester tester) async {
      // Les deux exigences de `BR-005` dans une seule image, parce qu'elles
      // se contredisent si on les lit mal : « le marqueur est visuellement
      // atténué », mais « elle réduit la saturation, pas la lisibilité »
      // — donc le contour de 2 px, lui, ne s'atténue pas (`NFR-04`,
      // `04-ui.md` § 3 : contraste non textuel ≥ 3:1). Côte à côte,
      // l'atténuation doit sauter aux yeux et les deux halos doivent être
      // du même noir.
      await pompeLImage(
        tester,
        contenu: rangee(<Widget>[
          _pastille(const Chargee(Freshness.perimee)),
          _pastille(const Chargee(Freshness.fraiche)),
        ]),
        taille: const Size(coteDUneCase * 2, coteDUneCase),
      );

      await verifieLImage('station_marker_perimee_vs_fraiche.png');
    },
  );
}

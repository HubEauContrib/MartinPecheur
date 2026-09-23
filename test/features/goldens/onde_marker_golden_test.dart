// Fige le RENDU du marqueur ONDE (`U5`) — six catégories × deux âges.
//
// `onde_marker_test.dart` vérifie déjà que chaque catégorie reçoit la forme,
// le motif et la teinte que `04-ui.md` § 2 lui donne, et qu'au-delà de
// `campagneAncienneApres` la teinte vire au gris sans que la forme change
// (`BR-010`). Il ne dit rien de ce qui se voit : qu'un demi-disque se
// distingue d'un disque plein, que des hachures obliques à 1,5 px de trait
// restent des hachures et non un aplat, et surtout que les six rendus
// restent séparables **quand la couleur disparaît** — c'est l'exigence
// d'achromatopsie de `04-ui.md` § 3, et la palette Okabe-Ito n'y répond pas
// toute seule : `#56B4E9` et `#E69F00` ont presque la même luminance.
//
// ⚠️ **`NonObserve` et `Inconnu` ont le même rendu** — même teinte, même
// forme, même motif — et ne se séparent que par le libellé (`ADR-006`,
// écart 1 en tête de `onde_marker.dart`). Leurs deux images sont malgré tout
// produites : le jour où la déviation « Non renseigné » sera actée par le
// commanditaire et donnera peut-être un rendu propre à `Inconnu`, c'est
// cette image-là qui tombera et forcera à regarder.
//
// Les marqueurs sont agrandis 4 × ; la taille de la carte reste 12 px. Les
// images sont plateforme-dépendantes. Voir `golden_harness.dart`.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';

import 'golden_harness.dart';

/// Les six catégories de l'échelle 1, dans l'ordre du tableau de
/// `04-ui.md` § 2. Le code brut d'`Inconnu` est celui d'une valeur qu'ONDE
/// n'émet pas : la nomenclature connaît `1`, `1a`, `1f`, `2`, `3` et `4`
/// (`C-10`), et `Inconnu` porte verbatim tout le reste (`BR-011`).
const List<(String, FlowCategory)> categoriesDeLEchelle =
    <(String, FlowCategory)>[
      ('ecoulement', Ecoulement()),
      ('ecoulement_faible', EcoulementFaible()),
      ('ecoulement_non_visible', EcoulementNonVisible()),
      ('assec', Assec()),
      ('non_observe', NonObserve()),
      ('inconnu', Inconnu('9z')),
    ];

/// Les deux âges de `BR-010`, et le nom qu'ils portent dans le fichier.
const List<(String, CampaignAge)> agesDeCampagne = <(String, CampaignAge)>[
  ('recente', CampaignAge.recente),
  ('ancienne', CampaignAge.ancienne),
];

/// La date de campagne passée aux marqueurs. Elle n'est **pas peinte** — le
/// marqueur ne porte aucun texte, la date part dans `Semantics` — mais le
/// paramètre est requis (`BR-010` : tout point ONDE affiche la date de sa
/// dernière campagne). Une date fixe, jamais `DateTime.now()` : le hasard
/// est injecté, jamais lu (`plan-de-tests.md` § 2, règle 4).
final DateTime dateDeCampagne = DateTime.utc(2026, 8, 25);

Widget _marqueur(FlowCategory categorie, CampaignAge age) => caseAgrandie(
  OndeMarkerShape(category: categorie, age: age, observedAt: dateDeCampagne),
);

void main() {
  group('Une image de référence par catégorie et par âge', () {
    for (final (String nomCategorie, FlowCategory categorie)
        in categoriesDeLEchelle) {
      for (final (String nomAge, CampaignAge age) in agesDeCampagne) {
        testWidgets(
          'le rendu de « $nomCategorie » en campagne $nomAge ne change pas '
          'sans qu\'on le voie',
          (WidgetTester tester) async {
            await pompeLImage(
              tester,
              contenu: _marqueur(categorie, age),
              taille: const Size(coteDUneCase, coteDUneCase),
            );

            await verifieLImage('onde_marker_${nomCategorie}_$nomAge.png');
          },
        );
      }
    }
  });

  testWidgets('en niveaux de gris, les douze rendus de l\'échelle 1 restent '
      'distinguables', (WidgetTester tester) async {
    // Deux rangées : campagnes récentes en haut, anciennes en bas. Une
    // fois la couleur retirée, `#56B4E9` (écoulement faible) et `#E69F00`
    // (eau stagnante) tombent à des luminances presque égales — c'est le
    // couple critique de `04-ui.md` § 3. Ce qui les sépare alors n'est
    // plus la teinte mais le couple (forme, motif) : demi-disque contre
    // triangle hachuré. La rangée du bas, elle, est entièrement grise
    // par `BR-010` : c'est la FORME seule qui y porte l'information.
    await pompeLImage(
      tester,
      contenu: ColorFiltered(
        colorFilter: filtreNiveauxDeGris,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String _, CampaignAge age) in agesDeCampagne)
              rangee(<Widget>[
                for (final (String _, FlowCategory categorie)
                    in categoriesDeLEchelle)
                  _marqueur(categorie, age),
              ]),
          ],
        ),
      ),
      taille: Size(
        coteDUneCase * categoriesDeLEchelle.length,
        coteDUneCase * agesDeCampagne.length,
      ),
    );

    await verifieLImage('onde_marker_echelle_niveaux_de_gris.png');
  });
}

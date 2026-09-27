// La légende de la carte (T1-U2). `BR-008` en fait une pièce obligatoire et
// non une finition : les trois échelles du produit — écoulement (fait
// observé), débit (statistique), et la troisième, qui arrive en T2 —
// réutilisent délibérément les mêmes teintes, chacune avec sa propre famille
// de formes. C'est la légende, **toujours visible, jamais repliée**, qui
// lève l'ambiguïté en nommant l'échelle active.
//
// Une légende ne montre donc **que** les états de son échelle : un symbole
// de l'autre famille rendrait la carte illisible, et le test le vérifie.
//
// ## Ce que la légende « débit » montre en T1, et pourquoi
//
// L'échelle 2 de `04-ui.md` § 2 compte six niveaux (« Très bas » … « Très
// haut », plus « Indéterminé »). **Cinq d'entre eux sont hors de portée en
// T1** : ils supposent un percentile, donc l'asset généré hors exécution
// d'`ADR-003`, qui n'existe pas encore. Les afficher promettrait une lecture
// que l'application ne sait pas rendre — et, sur ce produit, laisserait
// entendre des seuils (`BR-003`). La légende nomme donc le seul niveau
// atteignable, « Indéterminé » (`BR-004`), et explique les **cinq rendus de
// disponibilité** que la carte dessine réellement, pastille par pastille —
// les mêmes widgets que les marqueurs, pas des imitations.
//
// Le sous-texte « Comparaison statistique. Ce n'est pas un seuil
// réglementaire. » est recopié mot pour mot de `BR-003` (`L-01`,
// `docs/02-specifications.md`) : il accompagne toute présentation du niveau.
// Il est rendu en **couleur de texte par défaut**, à la taille des autres
// lignes : c'est le seul garde-fou permanent, à l'écran, contre la lecture
// « seuil » d'un percentile, et un gris clair de deux points plus petit le
// rendrait décoratif. « Indéterminé » porte en plus le **libellé long de
// `BR-004`**, recopié mot pour mot de la règle — près d'une station sur deux
// portera ce niveau, et la légende est le seul endroit de la carte où
// l'explication tient.
//
// ## Ce que la légende « écoulement » montre (T1-U3)
//
// Les **six** libellés carte de l'échelle 1 — les cinq de `04-ui.md` § 2,
// plus « Non renseigné », sixième ligne du tableau `U3` du plan T1 portée
// par le domaine (`flowCategoryLabel`) et **déviation d'`ADR-006`** — chacun
// avec le marqueur QUE LA CARTE DESSINE ([OndeMarkerShape],
// `onde_marker.dart`), pas une imitation : c'est ce qui garantit que la
// légende ne puisse pas diverger des marqueurs. Les formes écrites de `U2`
// (« ● ◐ ▲ ■ ◌ », sans teinte, faute de marqueur ONDE) ont disparu avec leur
// raison d'être.
//
// « Non renseigné » y figure alors que ce n'est pas un état du terrain :
// quasiment aucun marqueur ne le portera en usage courant, mais un code
// d'écoulement non reconnu (`BR-011`) donne exactement ce rendu, et une
// légende qui ne le nommerait pas laisserait l'usager lire « non observé » —
// un fait de terrain — là où il n'y a que notre ignorance (`BR-007`).
//
// Les marqueurs de légende sont rendus à l'âge [CampaignAge.recente] : une
// légende montre la teinte de la catégorie, pas le gris de `BR-010`, qui
// dépend de la date de CHAQUE observation et n'a pas de sens hors d'un
// point. C'est aussi pourquoi ils n'ont **aucune** date à porter : la
// légende est le seul appelant qui passe `observedAt: null`, et elle
// l'écrit explicitement.
//
// La forme « ◇ + ? » de l'échelle 2, elle, reste **écrite** : elle est
// montrée en entier ici et nulle part ailleurs — voir `station_marker.dart`,
// qui explique pourquoi le « ? » n'est pas peint sur les 4 150 pastilles.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Sous-texte permanent de l'indicateur de débit, recopié mot pour mot de
/// `BR-003` et de `L-01` (`docs/02-specifications.md`) : un percentile n'est
/// pas un seuil réglementaire, et il ne dit rien de ce qui est autorisé.
///
/// Privé : la légende est son seul appelant, et les tests retapent le
/// littéral — sur ce projet, le test **est** la recopie vérifiée de la
/// spécification, pas un renvoi vers la constante qu'il devrait contrôler.
const String _comparaisonStatistique =
    "Comparaison statistique. Ce n'est pas un seuil réglementaire.";

/// Libellé du seul niveau atteignable en T1 (`BR-004`, `04-ui.md` § 2,
/// échelle 2), et sa forme telle que la spécification l'écrit.
const String _indetermineLabel = 'Indéterminé';

/// Le libellé long de « Indéterminé », recopié mot pour mot de
/// [`BR-004`](../../../../docs/br/BR-004-historique-insuffisant.md) :
/// c'est l'explication que la règle elle-même donne, et la légende est le
/// seul endroit de la carte où elle tient. Elle compte : près d'une station
/// sur deux porte ce niveau (`project-state.md`, point 5 bis).
const String _indetermineExplication =
    'Pas assez de mesures passées à cette station pour situer la valeur '
    "d'aujourd'hui.";

/// La forme de « Indéterminé » : ◇ + « ? » (`04-ui.md` § 2, échelle 2). Le
/// « ? » n'est dessiné que **là**, jamais sur les 4 150 pastilles.
const String _indetermineShape = '◇ ?';

/// Libellé de légende d'une observation fraîche. `stationMapStateLabel` rend
/// une chaîne **vide** pour cet état — une mesure récente ne s'annonce pas à
/// l'écran (`BR-005`) — mais une légende, elle, doit nommer ce qu'elle
/// montre.
const String _mesureRecenteLabel = 'Mesure récente';

/// Libellé de légende d'une station dont aucune requête n'a encore abouti.
/// Même raison que [_mesureRecenteLabel] : le marqueur reste muet
/// (`BR-007`), la légende explique. Le libellé dit ce que l'usager peut
/// faire, pas un chargement que rien ne mène : hors des 20 stations
/// préchargées (`NFR-07`), la mesure ne vient qu'à la sélection. Verbe
/// neutre vis-à-vis de la plateforme — souris, clavier, toucher — arbitré
/// par le commanditaire le 2026-09-22 (constat d'écran du lot 3).
const String _selectionnezPourChargerLabel = 'Sélectionnez pour charger';

/// Largeur maximale de la légende, en pixels logiques : au-delà, elle
/// mangerait la carte sur un écran étroit.
///
/// **Publique** parce qu'elle a un appelant hors de ce fichier :
/// `buildMapOverlays` (`map_view.dart`) s'en sert pour borner le bandeau
/// d'erreur, qui ne doit jamais recouvrir la légende (`BR-008`).
const double legendMaxWidth = 260;

/// Taille de texte d'une ligne de légende, en pixels logiques.
const double _entryFontSize = 12;

/// Les états de disponibilité que la carte dessine, dans l'ordre de lecture
/// — du plus renseigné au moins renseigné — avec leur libellé de légende.
///
/// `EnEchec` n'y figure pas : son rendu est celui de [SansDonnee] (voir
/// `station_marker.dart`), et c'est le bandeau d'erreur par source qui
/// nomme la panne (`BR-007`), pas la légende.
List<(StationMapState, String)> _availabilityEntries() {
  const Chargee ancienne = Chargee(Freshness.ancienne);
  const Chargee perimee = Chargee(Freshness.perimee);
  const SansDonnee sansDonnee = SansDonnee();

  return <(StationMapState, String)>[
    (const Chargee(Freshness.fraiche), _mesureRecenteLabel),
    // Les libellés d'âge viennent du domaine, jamais d'une recopie : les
    // seuils de `BR-005` y sont déjà, et une révision doit se voir ici sans
    // qu'on y touche.
    (ancienne, stationMapStateLabel(ancienne)),
    (perimee, stationMapStateLabel(perimee)),
    (sansDonnee, stationMapStateLabel(sansDonnee)),
    (const NonChargee(), _selectionnezPourChargerLabel),
  ];
}

/// Les catégories de l'échelle 1, dans l'ordre de lecture de
/// `04-ui.md` § 2 — de l'eau qui coule au lit sec, puis les deux aveux
/// d'absence. Forme, teinte et libellé viennent de `onde_marker.dart`,
/// jamais d'une recopie locale.
///
/// [Inconnu] y porte un code brut nul : la légende parle de la catégorie,
/// pas d'une observation particulière.
const List<FlowCategory> _flowCategories = <FlowCategory>[
  Ecoulement(),
  EcoulementFaible(),
  EcoulementNonVisible(),
  Assec(),
  NonObserve(),
  Inconnu(null),
];

/// La légende de l'échelle active. Toujours visible, jamais repliée
/// (`BR-008`).
class MapLegend extends StatelessWidget {
  const MapLegend({required this.scale, super.key});

  /// L'échelle active, lue sur `MapViewModel.scale`. Une seule à la fois :
  /// c'est le type qui l'impose.
  final MapScaleKind scale;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: legendMaxWidth),
      child: DecoratedBox(
        // Fond opaque : un texte posé sur un fond de carte quelconque ne
        // tient aucun contraste (`04-ui.md` § 3).
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Le nom de l'échelle active, en tête : c'est la raison d'être
              // de la légende (`BR-008`).
              Text(
                mapScaleLabel(scale),
                style: const TextStyle(
                  fontSize: _entryFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              // `switch` exhaustif sur un `enum` fermé (`BR-011`) : une
              // échelle ajoutée sans branche ici ne compile pas.
              ...switch (scale) {
                MapScaleKind.debit => _dischargeRows(),
                MapScaleKind.ecoulement => _flowRows(),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _dischargeRows() => <Widget>[
    const _ShapeRow(shape: _indetermineShape, label: _indetermineLabel),
    // Le libellé long de `BR-004`, puis le sous-texte de `BR-003` : les deux
    // en couleur de texte PAR DÉFAUT et à la taille des autres lignes. Le
    // second est le seul garde-fou permanent, à l'écran, contre la lecture
    // « seuil » d'un percentile — l'affaiblir d'une teinte grise et de deux
    // points de moins le rendrait décoratif.
    const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text(
        _indetermineExplication,
        style: TextStyle(fontSize: _entryFontSize),
      ),
    ),
    const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        _comparaisonStatistique,
        style: TextStyle(fontSize: _entryFontSize),
      ),
    ),
    for (final (StationMapState state, String label) in _availabilityEntries())
      _DotRow(state: state, label: label),
  ];

  List<Widget> _flowRows() => <Widget>[
    for (final FlowCategory category in _flowCategories)
      _OndeRow(category: category),
  ];
}

/// Une ligne de légende dont le symbole est **écrit**. Il n'en reste qu'une :
/// « ◇ + ? », la forme d'« Indéterminé » de l'échelle 2, montrée en entier
/// ici et nulle part ailleurs (voir `station_marker.dart`).
class _ShapeRow extends StatelessWidget {
  const _ShapeRow({required this.shape, required this.label});

  final String shape;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: minimumTapTarget / 2,
            child: Text(
              shape,
              style: const TextStyle(fontSize: _entryFontSize),
            ),
          ),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: _entryFontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de légende de l'échelle 1 : le marqueur ONDE **que la carte
/// dessine**, et son libellé carte. Ni l'un ni l'autre n'est recopié ici —
/// c'est ce qui empêche la légende de diverger des marqueurs.
class _OndeRow extends StatelessWidget {
  const _OndeRow({required this.category});

  final FlowCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: minimumTapTarget / 2,
            child: Center(
              child: SizedBox(
                width: stationMarkerSize,
                height: stationMarkerSize,
                // Âge `recente` et `observedAt` nul : une légende montre la
                // teinte de la catégorie, jamais le gris de `BR-010` — qui
                // dépend de la date d'une observation, et n'a pas de sens
                // hors d'un point. Aucune date n'est donc annoncée ici, et
                // aucune n'est inventée (`BR-007`).
                child: OndeMarkerShape(
                  category: category,
                  age: CampaignAge.recente,
                  observedAt: null,
                ),
              ),
            ),
          ),
          Flexible(
            child: Text(
              ondeCategoryMapLabel(category),
              style: const TextStyle(fontSize: _entryFontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de légende dont le symbole est la **pastille elle-même** — le
/// widget que la carte dessine, pas une imitation : c'est ce qui garantit
/// que la légende ne puisse pas diverger des marqueurs.
class _DotRow extends StatelessWidget {
  const _DotRow({required this.state, required this.label});

  final StationMapState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: minimumTapTarget / 2,
            child: Center(
              child: SizedBox(
                width: stationMarkerSize,
                height: stationMarkerSize,
                child: StationMarkerDot(state: state),
              ),
            ),
          ),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: _entryFontSize),
            ),
          ),
        ],
      ),
    );
  }
}

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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
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

/// Largeur d'une case de la légende (`PD6`, `S2` d'Ergonomie) :
/// les rangées courtes — les six d'écoulement et les cinq de fraîcheur du débit
/// — se posent dans un [Wrap] de cases de cette largeur, deux par ligne dès que
/// le bloc a 320 de large (344 au téléphone), une seule en deçà. 156 laisse 132
/// au libellé après le symbole de 24 : « Dernière mesure il y a plus de 24 h »
/// passe à la ligne, aucun mot n'est coupé. Les rangées de la légende Crues ne
/// sont pas courtes (leurs libellés publiés sont longs) : elles gardent la
/// pleine largeur.
const double legendRowWidth = 156;

/// Écart horizontal entre deux cases de la légende, en pixels logiques : deux
/// cases tiennent donc dans 320 de large (156 + 8 + 156).
const double _legendRowSpacing = 8;

/// Taille de texte d'une ligne de légende, en pixels logiques.
const double _entryFontSize = 12;

/// Taille du texte de l'en-tête de légende, en pixels logiques : un cran
/// au-dessus des lignes (12), pour que le nom de la lecture se lise en premier.
const double _headerFontSize = 13;

/// Les niveaux de la légende Crues, dans l'ordre de lecture : les quatre
/// niveaux publiés, puis l'aveu d'un niveau non reconnu.
const List<FloodVigilanceLevel> _floodLevels = <FloodVigilanceLevel>[
  Vert(),
  Jaune(),
  Orange(),
  Rouge(),
  NiveauCruesInconnu(null),
];

const TextStyle _entryStyle = TextStyle(fontSize: _entryFontSize);

/// Phrase de couverture de la légende Crues (cadrage § 7.6) : un cours d'eau
/// sans trait n'est pas suivi — ce n'est pas un cours d'eau sans crue.
const String floodCoverageText =
    "Un cours d'eau sans trait de couleur n'est pas suivi par "
    '$floodSourceName.';

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

/// Le texte de l'en-tête de légende de [kind] (`S2` d'Ergonomie, § 11.2, mot
/// pour mot) : « Légende · » suivi du nom de la lecture, [mapScaleLabel] —
/// jamais une reformulation locale. C'est le nom de la lecture active que
/// `BR-008` exige en permanence ; il quitte le titre de [MapLegend] pour
/// l'en-tête du bloc de lecture, où « ⚠ Avertissement » le suit.
String mapLegendHeaderText(MapScaleKind kind) =>
    'Légende · ${mapScaleLabel(kind)}';

/// Écart entre le texte de l'en-tête et le lien, quand ils tiennent côte à
/// côte, en pixels logiques.
const double _headerGap = 8;

/// L'en-tête de la légende, dans le bloc de lecture (`S2` d'Ergonomie) : le
/// texte [mapLegendHeaderText] (13, gras, annoncé comme un titre) et
/// [warningLink].
///
/// **Le texte ne coupe jamais un mot.** Le lien est à droite du texte quand le
/// mot le plus long du texte tient dans la largeur que le lien laisse (largeur
/// intrinsèque minimale du texte, plus l'écart, plus le lien, dans la largeur
/// de l'en-tête) ; le texte passe alors à la ligne entre ses mots. Sinon — à
/// 200 % sur 344 de large, par exemple — le lien passe **sous** le texte,
/// aligné à droite, et le texte prend toute la largeur. Le lien garde, dans
/// les deux cas, sa largeur entière : « ⚠ Avertissement » ne cède à aucune
/// taille (arbitrage 11). Hauteur d'au moins [minimumTapTarget].
///
/// [warningLink] est reçu, pas construit : l'en-tête ne connaît ni la phrase
/// propre à la lecture (le texte de crue de `BR-015`) ni l'ordre de focus de
/// la carte, que l'appelant décide.
///
/// Aucun `LayoutBuilder` : une pièce de mise en page interroge les hauteurs
/// intrinsèques de l'en-tête, qui doivent suivre la même règle que la mise en
/// page. Le choix côte à côte ou l'un sous l'autre se prend donc dans un
/// `RenderObject` ([_RenderLegendHeader]) qui rend ses hauteurs intrinsèques,
/// sa mise en page à vide et sa mise en page réelle par la même règle. Écrit
/// pour le sens de lecture de gauche à droite, seul sens de l'application.
class MapLegendHeader extends StatelessWidget {
  const MapLegendHeader({
    required this.scale,
    required this.warningLink,
    super.key,
  });

  /// La lecture active, dont l'en-tête dit le nom.
  final MapScaleKind scale;

  /// Le contrôle « ⚠ Avertissement », posé à droite du texte, ou dessous.
  final Widget warningLink;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumTapTarget),
      child: _LegendHeaderLayout(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              header: true,
              child: Text(
                mapLegendHeaderText(scale),
                style: const TextStyle(
                  fontSize: _headerFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          warningLink,
        ],
      ),
    );
  }
}

/// La mise en page de [MapLegendHeader] : deux enfants, le texte puis le lien.
class _LegendHeaderLayout extends MultiChildRenderObjectWidget {
  const _LegendHeaderLayout({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLegendHeader();
}

/// Le `RenderObject` de [_LegendHeaderLayout] : le texte, premier enfant, et le
/// lien, second. Une seule règle sert la mise en page réelle, la mise en page à
/// vide ([_arrange]) et les hauteurs intrinsèques ([_heightAt]).
class _RenderLegendHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderBox get _text => firstChild!;
  RenderBox get _link => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  /// Vrai quand le texte tient à côté d'un lien de [linkWidth] de large dans
  /// [width] sans couper un mot : son mot le plus long, plus l'écart, plus le
  /// lien. Une largeur non bornée laisse toujours la place.
  bool _fitsBeside(double width, double linkWidth) =>
      !width.isFinite ||
      _text.getMinIntrinsicWidth(double.infinity) + _headerGap + linkWidth <=
          width;

  /// La disposition de l'en-tête sous [constraints] : sa taille, et la place du
  /// texte et du lien. [layoutChild] pose les enfants pour de bon
  /// ([ChildLayoutHelper.layoutChild]) ou à vide
  /// ([ChildLayoutHelper.dryLayoutChild]) ; la règle est la même.
  ({Size size, Offset textOffset, Offset linkOffset}) _arrange(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final double width = constraints.maxWidth;
    // Le lien se pose à sa largeur naturelle, sur une ligne : son libellé est
    // un seul mot, il ne se replie pas.
    final Size link = layoutChild(_link, BoxConstraints(maxWidth: width));
    if (_fitsBeside(width, link.width)) {
      final Size text = layoutChild(
        _text,
        BoxConstraints(maxWidth: width - link.width - _headerGap),
      );
      final Size size = constraints.constrain(
        Size(
          width.isFinite ? width : text.width + _headerGap + link.width,
          math.max(text.height, link.height),
        ),
      );
      return (
        size: size,
        textOffset: Offset(0, (size.height - text.height) / 2),
        linkOffset: Offset(
          size.width - link.width,
          (size.height - link.height) / 2,
        ),
      );
    }
    final Size text = layoutChild(_text, BoxConstraints(maxWidth: width));
    final Size size = constraints.constrain(
      Size(width, text.height + link.height),
    );
    return (
      size: size,
      textOffset: Offset.zero,
      linkOffset: Offset(size.width - link.width, text.height),
    );
  }

  @override
  void performLayout() {
    final ({Size size, Offset textOffset, Offset linkOffset}) arrangement =
        _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arrangement.size;
    (_text.parentData! as MultiChildLayoutParentData).offset =
        arrangement.textOffset;
    (_link.parentData! as MultiChildLayoutParentData).offset =
        arrangement.linkOffset;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  /// La hauteur de l'en-tête à [width] de large, par les seules dimensions
  /// intrinsèques des enfants — la même règle que [_arrange].
  double _heightAt(double width) {
    final double linkWidth = math.min(
      _link.getMaxIntrinsicWidth(double.infinity),
      width,
    );
    final double linkHeight = _link.getMaxIntrinsicHeight(linkWidth);
    if (_fitsBeside(width, linkWidth)) {
      return math.max(
        _text.getMaxIntrinsicHeight(width - linkWidth - _headerGap),
        linkHeight,
      );
    }
    return _text.getMaxIntrinsicHeight(width) + linkHeight;
  }

  // Une seule hauteur : l'en-tête ne se replie pas, il reste entier.
  @override
  double computeMinIntrinsicHeight(double width) => _heightAt(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightAt(width);

  // Le plus étroit : le mot le plus long du texte, ou le lien entier s'il est
  // plus large — l'un sous l'autre est toujours possible.
  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _text.getMinIntrinsicWidth(height),
    _link.getMaxIntrinsicWidth(height),
  );

  // Le plus large : tout sur une rangée.
  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height) +
      _headerGap +
      _link.getMaxIntrinsicWidth(height);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// La légende de l'échelle active, dans le bloc de lecture (`S2` d'Ergonomie,
/// posée par `MapReadingBlockLegend`). Toujours rendue (`BR-008`) ; elle
/// défile quand la place manque (premier repli, écart à `BR-008` accepté le
/// 2026-10-12 et prolongé par l'arbitrage 11).
///
/// Une seule forme depuis `D2` : ni titre — le nom de la lecture est dans
/// [MapLegendHeader] —, ni carte blanche, ni plafond de largeur — le bloc les
/// porte —, et les rangées courtes (écoulement, fraîcheur du débit) en
/// colonnes, dans un [Wrap] de cases de [legendRowWidth]. La légende Crues
/// garde ses rangées pleine largeur.
class MapLegend extends StatelessWidget {
  const MapLegend({
    required this.scale,
    this.floodInformationDate,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// L'échelle active, lue sur `MapViewModel.scale`. Une seule à la fois :
  /// c'est le type qui l'impose.
  final MapScaleKind scale;

  /// Date de la vigilance lue ; non nulle SEULEMENT quand la lecture Crues est
  /// prête (arbitrage 9 du cadrage de T4 : ni couverture ni date avant).
  final DateTime? floodInformationDate;

  /// Décalage horaire injectable, pour qu'un test fixe le fuseau.
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    // `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
    // sans branche ici ne compile pas.
    final List<Widget> rows = switch (scale) {
      MapScaleKind.debit => _dischargeRows(),
      MapScaleKind.ecoulement => _flowRows(),
      MapScaleKind.crues => _floodRows(),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// Les rangées courtes [rows], en colonnes (`PD6`) : un [Wrap] de cases de
  /// [legendRowWidth] séparées de [_legendRowSpacing], deux par ligne dès que
  /// la largeur le permet. Un [Wrap] et non un `LayoutBuilder` : il sait
  /// rendre ses hauteurs intrinsèques, que la mise en page du bloc interroge.
  /// Les phrases longues ne passent pas par ici : elles restent pleine
  /// largeur, comme les rangées de la légende Crues, dont les libellés publiés
  /// sont longs.
  List<Widget> _shortRows(List<Widget> rows) {
    return <Widget>[
      Wrap(
        spacing: _legendRowSpacing,
        children: <Widget>[
          for (final Widget row in rows)
            SizedBox(width: legendRowWidth, child: row),
        ],
      ),
    ];
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
    ..._shortRows(<Widget>[
      for (final (StationMapState state, String label)
          in _availabilityEntries())
        _DotRow(state: state, label: label),
    ]),
  ];

  List<Widget> _flowRows() => _shortRows(<Widget>[
    for (final FlowCategory category in _flowCategories)
      _OndeRow(category: category),
  ]);

  List<Widget> _floodRows() {
    final DateTime? date = floodInformationDate;
    return <Widget>[
      // Pleine largeur dans le bloc comme dehors : les libellés publiés des
      // niveaux sont longs (« Orange — Risque de crue génératrice de
      // débordements importants »), une case de 156 les mettrait sur quatre
      // lignes.
      for (final FloodVigilanceLevel level in _floodLevels)
        _FloodRow(level: level),
      // Une fois la vigilance lue seulement (arbitrage 9, `BR-001`, licence
      // `VC-09`) : avant, ni couverture ni date ne se disent.
      if (date != null) ...<Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(floodCoverageText, style: _entryStyle),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Information de vigilance du '
            '${formatLocalDateTime(date, offsetOf: utcOffsetOf)} — '
            '$floodAttribution',
            style: _entryStyle,
          ),
        ),
      ],
    ];
  }
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
                width: compactMarkerSize,
                height: compactMarkerSize,
                // Âge `recente` et `observedAt` nul : une légende montre la
                // teinte de la catégorie, jamais le gris de `BR-010` — qui
                // dépend de la date d'une observation, et n'a pas de sens
                // hors d'un point. Aucune date n'est donc annoncée ici, et
                // aucune n'est inventée (`BR-007`).
                child: OndeMarkerShape(
                  category: category,
                  age: CampaignAge.recente,
                  observedAt: null,
                  compact: true,
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
                width: compactMarkerSize,
                height: compactMarkerSize,
                child: StationMarkerDot(state: state, compact: true),
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

/// Une rangée de la légende Crues : l'échantillon de trait, la jauge de 18 px,
/// puis la légende publiée du niveau (« Niveau non reconnu » pour l'inconnu).
class _FloodRow extends StatelessWidget {
  const _FloodRow({required this.level});

  final FloodVigilanceLevel level;

  @override
  Widget build(BuildContext context) {
    final String? published = publishedFloodLegend(level);
    final String label = published == null
        ? floodLevelLabel(level)
        : '${floodLevelLabel(level)} — $published';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloodStrokeSample(level: level),
          const SizedBox(width: 4),
          FloodLevelGauge(level: level, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: _entryStyle)),
        ],
      ),
    );
  }
}

/// Échantillon de trait de la légende Crues, 24 × 8 px : la teinte, le contour
/// noir, le pointillé de l'inconnu, l'épaisseur ramenée à l'échelle de la
/// rangée (le trait le plus épais, contour compris, tient en 8 px).
class FloodStrokeSample extends StatelessWidget {
  const FloodStrokeSample({required this.level, super.key});

  final FloodVigilanceLevel level;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(24, 8),
        painter: _FloodStrokePainter(floodLevelStyle(level)),
      ),
    );
  }
}

class _FloodStrokePainter extends CustomPainter {
  const _FloodStrokePainter(this.style);

  final FloodLevelStyle style;

  // Le trait le plus épais (7) et son contour de 2 px de chaque côté.
  static const double _thickest = 7 + 4 * floodContourWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / _thickest;
    final double stroke = style.strokeWidth * scale;
    final double contour = (style.strokeWidth + 2 * floodContourWidth) * scale;
    final double y = size.height / 2;
    _line(canvas, size, y, contour, floodContourColor);
    _line(canvas, size, y, stroke, style.tint);
  }

  void _line(Canvas canvas, Size size, double y, double width, Color color) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    if (!style.dotted) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(x + 3, y), paint);
    }
  }

  @override
  bool shouldRepaint(_FloodStrokePainter old) => old.style != style;
}

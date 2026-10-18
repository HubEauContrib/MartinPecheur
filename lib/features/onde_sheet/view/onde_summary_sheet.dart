// La vue de la tranche fiche ONDE (MVVM, ADR-014) : elle reçoit un
// [OndeSheetData] déjà prêt et l'affiche. Aucun dépôt, aucun ViewModel
// appelé — c'est ce qui la rend testable sans réseau, sans asset et sans
// carte.
//
// ## L'invariant de cette fiche
//
// La **catégorie**, la **modalité officielle** et la **date de campagne**
// sont sur la MÊME fiche et dans CET ordre, sans exception (`UC-004 § 2` et
// § 3, `BR-010`, `ADR-006`). Le regroupement en quatre catégories sert la
// lisibilité de la carte ; il ne remplace jamais la modalité de la source, et
// aucune des trois ne se lit sans les deux autres :
//
// - la catégorie seule masquerait la nomenclature réelle (`ADR-006`) ;
// - la modalité seule serait illisible hors du vocabulaire ONDE ;
// - sans la date, une observation de septembre se lirait en février comme un
//   fait du jour (`BR-010`, la justification même de la règle).
//
// ## Le cadre commun et le contrôle d'avertissement (F2 d'Ergonomie)
//
// Depuis `F2` (cadrage d'ergonomie du 2026-10-17, § 6.1 et § 6.3), la fiche
// est dans le cadre commun des fiches ([SheetFrame],
// `lib/features/shared/sheet_frame.dart`) : un EN-TÊTE épinglé — « Point
// ONDE », l'étoile, la fermeture, puis le contrôle « ⚠ Avertissement »
// ([WarningLink], `W3c`) — et un CORPS qui défile ([OndeSummarySheet]). Le
// contrôle est donc TOUJOURS rendu, dans les trois états visibles, avant le
// titre et la catégorie. Sa fenêtre porte la phrase « Observation du {date},
// lors d'une campagne ponctuelle… » quand une campagne existe
// ([OndeSheetData.latest] non nul), seulement en [OndeSheetPrete] ; sans
// campagne, elle s'ouvre sans phrase propre — c'est le message d'absence de
// `UC-004 A4` qui porte alors l'avertissement (arbitrage du commanditaire du
// 2026-09-23).
//
// ## Le symbole de légende est FOURNI (`PD8`, R13)
//
// Le corps montre une TUILE — le symbole de légende de la catégorie, la
// catégorie mise en avant, la phrase du code `4`, la modalité, la campagne
// datée et sourcée — puis l'historique, où chaque campagne porte son symbole
// compact. La fiche ne dessine aucun symbole : [OndeCategorySymbol] le lui
// donne, la racine de composition le branche (`D5`). Sans lui, la fiche
// s'affiche sans symbole et sans erreur. La tuile est UN SEUL nœud d'annonce
// ([MergeSemantics], comme la tuile Débit de la fiche station) : la catégorie
// ne s'annonce jamais sans sa modalité, sa date ni sa source (`BR-001`,
// `BR-010`) ; le symbole, décoratif, n'est pas annoncé.
//
// ⚠️ Cette tranche n'importe AUCUNE autre tranche (`layers_test.dart`, règle
// `feature-vers-feature`) : ni `features/map/`, ni `features/station_sheet/`.
// `features/shared/` reste ouverte à toute tranche (règle
// `shared-sans-tranche`). Le format de date, lui, n'est plus recopié depuis
// `H1` (2026-09-22) : `formatCalendarDate` vit dans
// `lib/domain/formatting/display_date.dart`, lu par les trois tranches sans
// que l'une importe l'autre (le domaine leur est ouvert à toutes).
//
// ## Contraste du libellé d'état (relecture du 2026-09-14)
//
// La catégorie (`flowCategoryLabel`) ne porte AUCUNE couleur grise, même
// après `campagneAncienneApres`. `#767676` tient 4,54:1 sur blanc — assez
// pour du texte standard, pas pour un LIBELLÉ D'ÉTAT, que `04-ui.md § 3`
// tient à ≥ 7:1. `BR-010` (« l'état est affiché en gris ») reste respecté :
// le marqueur de la carte (`U3`) porte déjà cette teinte, et cette fiche
// rend la mention datée (« dernière observation le JJ/MM/AAAA ») — deux
// signaux indépendants de toute couleur de texte.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show SheetWarningKind, sheetWarningText;
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart';

// ⚠️ Décision de relecture (2026-09-14) : aucune teinte grise sur cette
// fiche. `#767676` tient 4,54:1 sur blanc — suffisant pour du texte
// standard, mais `flowCategoryLabel(latest.category)` est un LIBELLÉ
// D'ÉTAT, pour lequel `04-ui.md` § 3 exige ≥ 7:1. Le colorer en gris y
// contreviendrait. La catégorie garde donc sa couleur par défaut, dans
// TOUS les cas — `BR-010` (« l'état est affiché en gris ») reste porté,
// mais par le marqueur de la carte (`U3`, `_ondeGrey`) et par la mention
// datée que cette fiche rend (« dernière observation le JJ/MM/AAAA ») :
// deux signaux qui ne dépendent d'aucune couleur de texte.

/// Clé du bouton de fermeture de la fiche — le seul contrôle du panneau, et
/// le seul chemin qui la ferme. Nommée pour que le test puisse en mesurer la
/// taille sans dépendre d'une icône ou d'un libellé.
const Key ondeSheetCloseButtonKey = Key('onde-sheet-close');

/// La ligne de nature de l'en-tête de la fiche (spec § 11.2) : le point ONDE
/// n'affiche aucun code (arbitrage 5).
const String ondeSheetNature = 'Point ONDE';

/// Clé de la tuile de la catégorie.
const Key ondeCategoryTileKey = Key('onde-category-tile');

/// Le symbole de légende d'une catégorie, FOURNI à la fiche par la racine de
/// composition (`PD8`, R13) : la fiche ne dessine aucun symbole et n'importe
/// pas `features/map/` (règle `feature-vers-feature`). [compact] : la taille
/// d'une ligne d'historique plutôt que celle de la tuile.
typedef OndeCategorySymbol = Widget Function(
  FlowCategory category, {
  required bool compact,
});

/// Absence de cours d'eau au référentiel ONDE : [OndePoint.waterCourseLabel]
/// vaut `null`. Une absence se dit, elle ne se masque pas par une ligne vide
/// (`BR-007`).
const String ondeCoursDEauNonRenseigne = "Cours d'eau non renseigné";

/// Absence de département au référentiel ONDE, pour la même raison.
const String ondeDepartementNonRenseigne = 'Département non renseigné';

/// Le texte de `UC-004 A2`, recopié mot pour mot : le code `4` est un FAIT de
/// terrain — l'observateur n'a pas pu observer — et non notre ignorance d'un
/// code (`BR-007`, qui sépare les deux). Un état neutre laisserait croire à
/// une absence de problème.
const String ondePointNonObserveText =
    "Ce point n'a pas pu être observé lors de la dernière campagne. Aucune "
    'information disponible ici.';

/// Préfixe de la ligne de modalité, recopié du gabarit de `04-ui.md`
/// (« Modalité officielle ONDE : »).
///
/// ⚠️ Le mot « officielle » y ATTRIBUE la nomenclature à sa source — la même
/// réserve que `BR-014` pose pour les libellés d'une autorité, cités tels
/// quels et attribués. Il ne qualifie jamais nos données, et c'est la seule
/// occurrence tolérée dans toute la tranche : le test
/// « le mot officiel ne sert qu'à attribuer la nomenclature ONDE » la borne.
const String ondeModalitePrefix = 'Modalité officielle ONDE : ';

/// Titre de la liste des campagnes (`04-ui.md`, « Campagnes précédentes »).
const String ondeHistoriqueTitre = 'Campagnes précédentes';

/// Mention qui introduit la date d'une campagne [CampaignAge.recente].
const String _campagneRecenteMention = 'Campagne du ';

/// Mention qui introduit la date d'une campagne [CampaignAge.ancienne],
/// recopiée de `BR-010` (« dernière observation le JJ/MM ») — avec l'ANNÉE,
/// comme `U3` l'a tranché pour l'annonce du marqueur : hors saison, l'écart
/// se compte en mois et une date sans année se lirait comme celle de l'année
/// en cours.
const String _campagneAncienneMention = 'dernière observation le ';

/// L'âge [days] d'une campagne, en jours calendaires (`BR-010`) : « il y a
/// 19 jours », « il y a 1 jour » au singulier, « aujourd'hui » à zéro.
///
/// Un âge négatif — observation datée du futur, anomalie de la source — rend
/// « aujourd'hui » plutôt que « il y a −2 jours » : c'est le même traitement
/// que [campaignAgeOf] applique à une campagne future, qu'il compte
/// [CampaignAge.recente].
String formatCampaignAge(int days) {
  if (days <= 0) {
    return "aujourd'hui";
  }
  if (days == 1) {
    return 'il y a 1 jour';
  }
  return 'il y a $days jours';
}

/// Le filet d'une tuile : celui des filets déjà en usage (`sheet_frame.dart`,
/// la tuile de la fiche station).
const Color _tileRuleColor = Color(0xFFC9CFC4);

/// L'écart entre le symbole et le texte qu'il précède : 10 dans la tuile, 8
/// sur une ligne d'historique.
const double _tileSymbolGap = 10;
const double _historySymbolGap = 8;

/// Le corps de la fiche d'un point ONDE prête, dans l'ordre de la spec
/// d'Ergonomie (§ 6.3, critère 12) : le titre ; « `cours d'eau` · Département
/// `NN` » ; une **tuile** — le symbole de légende, puis **catégorie → modalité
/// officielle → date de campagne** ; l'historique des campagnes, chacune avec
/// son symbole ; le rappel de rythme.
///
/// Le contrôle « ⚠ Avertissement » n'est plus ici : il est dans l'en-tête
/// épinglé du cadre commun ([SheetFrame]), que pose [OndeSheetPanel].
///
/// Ne connaît aucun dépôt et aucun ViewModel : elle reçoit un
/// [OndeSheetData] déjà prêt et l'affiche. Elle répond aux demandes de
/// dimensions intrinsèques (contrat de [SheetFrame.body]) : ni
/// `LayoutBuilder` ni `ListView`.
class OndeSummarySheet extends StatelessWidget {
  const OndeSummarySheet({required this.data, this.categorySymbol, super.key});

  /// Les données à afficher, produites par [OndeSheetViewModel].
  final OndeSheetData data;

  /// Le symbole de légende de chaque catégorie, fourni par la racine de
  /// composition, ou `null` : la fiche s'affiche alors sans symbole.
  final OndeCategorySymbol? categorySymbol;

  @override
  Widget build(BuildContext context) {
    final OndePoint point = data.point;
    // ADR-015 : departement porte desormais un AdministrativeArea (code +
    // libelle) ; cette fiche ne lit que le code, exactement ce qu'elle
    // affichait avant Z2.
    final AdministrativeArea? departement = point.departement;
    final String departementText = departement == null
        ? ondeDepartementNonRenseigne
        : 'Département ${departement.code}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          point.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(
          '${point.waterCourseLabel ?? ondeCoursDEauNonRenseigne} · '
          '$departementText',
        ),
        const SizedBox(height: 12),
        _CategoryTile(data: data, categorySymbol: categorySymbol),
        if (data.history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            ondeHistoriqueTitre,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          // L'ordre du dépôt, la plus récente en tête — jamais retrié ici
          // (`UC-004 § 4`).
          for (final OndeObservation observation in data.history)
            _SymbolLine(
              symbol: categorySymbol?.call(observation.category, compact: true),
              gap: _historySymbolGap,
              child: Text(
                '${formatCalendarDate(observation.observedAt)} — '
                '${flowCategoryLabel(observation.category)}',
              ),
            ),
        ],
        const SizedBox(height: 12),
        // Le rappel de rythme, dans TOUS les cas (`UC-004 § 5`, `BR-010`) —
        // y compris sans aucune campagne connue.
        Text(data.seasonNotice),
      ],
    );
  }
}

/// La tuile de la catégorie : le symbole de légende, la catégorie mise en
/// avant (22, gras), la phrase du code `4` s'il y a lieu, la modalité
/// officielle, puis la campagne datée et sourcée — les trois lignes de
/// l'invariant de la fiche, dans l'ordre. Sans campagne, le texte d'absence
/// que le ViewModel a déjà écrit (`UC-004 A4`), seul.
///
/// La tuile est UN SEUL nœud d'annonce ([MergeSemantics]), comme la tuile
/// Débit de la fiche station (`F1`) : la catégorie ne s'annonce jamais sans sa
/// modalité, sa date ni sa source (`BR-001`, `BR-010`). Le symbole fourni en
/// est exclu ([_SymbolLine]) : le texte dit déjà la catégorie.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.data, required this.categorySymbol});

  final OndeSheetData data;
  final OndeCategorySymbol? categorySymbol;

  @override
  Widget build(BuildContext context) {
    final OndeObservation? latest = data.latest;
    return MergeSemantics(
      child: Container(
        key: ondeCategoryTileKey,
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: _tileRuleColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (latest == null)
              Text(data.officialModalityText)
            else ...<Widget>[
              // Aucune couleur grise ici, campagne ancienne ou non — un
              // libellé d'état exige 7:1 (`04-ui.md` § 3), que `#767676`
              // (4,54:1) ne tient pas. `BR-010` reste porté par le marqueur
              // de la carte et par la mention datée ci-dessous, pas par cette
              // couleur.
              _SymbolLine(
                symbol: categorySymbol?.call(latest.category, compact: false),
                gap: _tileSymbolGap,
                child: Text(
                  flowCategoryLabel(latest.category),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Un code `4` est un fait de terrain constaté, pas une absence
              // de donnée : la phrase de `UC-004 A2` le dit en toutes lettres.
              if (latest.category is NonObserve) Text(ondePointNonObserveText),
              Text('$ondeModalitePrefix${data.officialModalityText}'),
              Text(_campagneLine(latest.observedAt, data.age, data.ageInDays)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne : le [symbol] fourni, s'il y en a un, puis [child]. Sans symbole,
/// [child] seul, sans emplacement vide.
///
/// Le symbole est DÉCORATIF ([ExcludeSemantics]) : le texte dit déjà la
/// catégorie, et le pictogramme n'est jamais seul porteur du sens (R7) — son
/// libellé éventuel ne s'ajoute pas à l'annonce du texte.
class _SymbolLine extends StatelessWidget {
  const _SymbolLine({
    required this.symbol,
    required this.gap,
    required this.child,
  });

  final Widget? symbol;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget? symbol = this.symbol;
    if (symbol == null) {
      return child;
    }
    return Row(
      children: <Widget>[
        ExcludeSemantics(child: symbol),
        SizedBox(width: gap),
        Expanded(child: child),
      ],
    );
  }
}

/// La ligne de date d'une campagne : la mention que son âge commande, la
/// date, et l'âge en clair — dans un SEUL `Text`.
///
/// Un seul `Text` et non deux : `BR-010` fait de l'âge et de la date une
/// information unique, et deux lignes séparées se laisseraient dissocier par
/// un remaniement de mise en page — exactement ce que `BR-001` interdit pour
/// une valeur et sa date.
///
/// [age] et [ageInDays] sont `null` dans le seul cas où la campagne l'est
/// aussi ; cette fonction n'est alors pas appelée. Le repli est néanmoins
/// explicite : la date reste rendue, jamais escamotée.
///
/// Porte aussi [ondeSourceName] (`BR-001`, point 32) : la valeur (catégorie
/// et modalité, sur les lignes précédentes), sa date et sa source sont
/// visibles au même endroit.
String _campagneLine(DateTime observedAt, CampaignAge? age, int? ageInDays) {
  final String mention = switch (age) {
    CampaignAge.ancienne => _campagneAncienneMention,
    CampaignAge.recente || null => _campagneRecenteMention,
  };
  final String date = '$mention${formatCalendarDate(observedAt)}';

  final String dated = ageInDays == null
      ? date
      : '$date — ${formatCampaignAge(ageInDays)}';
  return '$dated — $ondeSourceName';
}

/// La phrase datée de la fenêtre « ⚠ Avertissement » d'une fiche prête : la
/// version ONDE, plus insistante que la version station, quand une campagne
/// existe. Sans campagne, aucune date n'existe à dater (`BR-001`) : la fenêtre
/// s'ouvre alors sans phrase propre.
String? _warningExtraText(OndeSheetData data) {
  final OndeObservation? latest = data.latest;
  return latest == null
      ? null
      : sheetWarningText(SheetWarningKind.onde, latest.observedAt);
}

/// Le panneau de la fiche ONDE : rend l'état porté par
/// [OndeSheetViewModel], quel qu'il soit. `switch` exhaustif sur un `sealed`
/// (`BR-011`) — une branche oubliée est une erreur de compilation, pas un
/// écran muet.
///
/// Chaque état visible se dit dans le cadre commun des fiches ([SheetFrame],
/// `F2` d'Ergonomie, spec § 6.1) : en-tête épinglé — « Point ONDE », l'étoile,
/// la fermeture, puis « ⚠ Avertissement », présent dans les trois états — et
/// corps qui défile. La phrase datée de la fenêtre d'avertissement n'existe
/// qu'en [OndeSheetPrete], avec une campagne : ailleurs, aucune date n'est
/// connue.
///
/// La fiche ne se ferme que par [onClose] : un tap sur la carte hors marqueur
/// ne la ferme pas. Une fermeture par un geste que rien ne teste serait une
/// magie invisible.
class OndeSheetPanel extends StatelessWidget {
  const OndeSheetPanel({
    required this.state,
    required this.onClose,
    this.favoriteStar,
    this.onToggleFavorite,
    this.categorySymbol,
    this.bodyScrollController,
    super.key,
  }) : assert(
         favoriteStar == null || onToggleFavorite != null,
         'une étoile à montrer exige son rappel de bascule',
       );

  /// L'état courant de la fiche.
  final OndeSheetState state;

  /// Appelé par le bouton de fermeture — branché sur
  /// `OndeSheetViewModel.close`.
  final VoidCallback onClose;

  /// L'étoile de favori à montrer, telle que `OndeSheetViewModel` la produit
  /// (`S7a` de T3). `null` : aucune étoile et aucun emplacement vide.
  final FavoriteStar? favoriteStar;

  /// Appelé par l'étoile — branché sur `OndeSheetViewModel.toggleFavorite`.
  /// Obligatoire dès que [favoriteStar] est non nul.
  final VoidCallback? onToggleFavorite;

  /// Le symbole de légende de chaque catégorie, fourni par la racine de
  /// composition (`PD8`), ou `null` : la fiche s'affiche sans symbole.
  final OndeCategorySymbol? categorySymbol;

  /// La position du corps du cadre, que l'appelant remet à zéro à chaque
  /// ouverture (`K4` de T3), ou `null`.
  final ScrollController? bodyScrollController;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      OndeSheetFermee() => const SizedBox.shrink(),
      OndeSheetEnCours(:final OndePoint point) => _frame(
        Text('Chargement du point ${point.label}…'),
      ),
      OndeSheetPrete(:final OndeSheetData data) => _frame(
        OndeSummarySheet(data: data, categorySymbol: categorySymbol),
        warningExtraText: _warningExtraText(data),
      ),
      // La cause technique (`OndeSheetEnEchec.cause`) n'est PAS affichée :
      // c'est une donnée de diagnostic, pas un texte pour l'usager. Le
      // message nomme la source défaillante et le point (`UC-001 A4`), et la
      // feuille n'est jamais vide (`BR-007`).
      OndeSheetEnEchec(:final OndePoint point) => _frame(
        Text(
          "Hub'Eau n'a pas répondu pour le point ${point.label}. Aucune "
          "observation n'est disponible pour l'instant.",
        ),
      ),
    };
  }

  /// Le cadre commun d'un état visible : la nature (sans code), la fermeture
  /// (sa clé [ondeSheetCloseButtonKey]), l'étoile, et [warningExtraText] —
  /// `null` hors [OndeSheetPrete].
  Widget _frame(Widget body, {String? warningExtraText}) {
    return SheetFrame(
      nature: ondeSheetNature,
      closeButtonKey: ondeSheetCloseButtonKey,
      onClose: onClose,
      favoriteStar: favoriteStar,
      onToggleFavorite: onToggleFavorite,
      bodyScrollController: bodyScrollController,
      warningExtraText: warningExtraText,
      body: body,
    );
  }
}

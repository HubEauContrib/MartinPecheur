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
// ## Le contrôle d'avertissement de tête (Task W3c, ex-W4)
//
// Le contrôle de tête est [WarningLink]
// (`lib/features/shared/warning_link.dart`), TOUJOURS rendu en tête de
// [OndeSummarySheet], avant la catégorie (arbitrage du commanditaire du
// 2026-09-23, qui retire l'ancien encart daté, le widget de `W4`). Sa
// fenêtre porte la phrase « Observation du {date}, lors d'une
// campagne ponctuelle… » quand une campagne existe
// ([OndeSheetData.latest] non nul) ; sans campagne, elle s'ouvre sans
// phrase propre — c'est le message d'absence de `UC-004 A4` qui porte alors
// l'avertissement.
//
// ⚠️ Cette tranche n'importe AUCUNE autre tranche (`layers_test.dart`, règle
// `feature-vers-feature`) : ni `features/map/`, ni `features/station_sheet/`.
// La cible tactile de 44 pt (`04-ui.md § 3`) y est donc recopiée de sa
// spécification, jamais de l'autre tranche — duplication assumée,
// conséquence directe de la règle de couches. Le format de date, lui, n'est
// plus recopié depuis `H1` (2026-09-22) : `formatCalendarDate` vit dans
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
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show SheetWarningKind, sheetWarningText;
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Côté minimal d'une cible tactile, en pixels logiques : 44 × 44 pt (iOS)
/// selon `04-ui.md` § 3. Recopié de la spécification, jamais choisi ici.
///
/// ⚠️ La fiche station et la carte tiennent la même exigence avec LEURS
/// propres constantes (`minimumTapTarget`, `stationMarkerTapTarget`) : une
/// tranche n'importe pas une autre tranche (`layers_test.dart`, règle
/// `feature-vers-feature`). Les trois recopient la même ligne de `04-ui.md`,
/// elles ne se recopient pas l'une l'autre.
const double ondeSheetTapTarget = 44.0;

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

/// La feuille de résumé d'un point ONDE, dans l'ordre de `04-ui.md`
/// § « Fiche point ONDE » : identité (libellé, cours d'eau, département),
/// puis **catégorie → modalité officielle → date de campagne**, puis
/// l'historique des campagnes, puis le rappel de rythme.
///
/// Ne connaît aucun dépôt et aucun ViewModel : elle reçoit un
/// [OndeSheetData] déjà prêt et l'affiche.
class OndeSummarySheet extends StatelessWidget {
  const OndeSummarySheet({required this.data, super.key});

  /// Les données à afficher, produites par [OndeSheetViewModel].
  final OndeSheetData data;

  @override
  Widget build(BuildContext context) {
    final OndePoint point = data.point;
    final OndeObservation? latest = data.latest;
    final DepartementCode? departement = point.departement;

    // Le contrôle d'avertissement (`W3c`) : TOUJOURS rendu, la fenêtre porte
    // la version ONDE, plus insistante que la version station, quand une
    // campagne existe. Sans campagne, aucune date n'existe à dater
    // (`BR-001`) : la fenêtre s'ouvre alors sans phrase propre.
    final String? warningExtraText = latest == null
        ? null
        : sheetWarningText(SheetWarningKind.onde, latest.observedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WarningLink(extraText: warningExtraText),
        const SizedBox(height: 8),
        Text(
          point.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(point.waterCourseLabel ?? ondeCoursDEauNonRenseigne),
        Text(
          departement == null
              ? ondeDepartementNonRenseigne
              : 'Département ${departement.value}',
        ),
        const SizedBox(height: 8),
        // Les trois lignes de l'invariant, dans l'ordre — ou, sans campagne,
        // le texte d'absence que le ViewModel a déjà écrit (`UC-004 A4`).
        if (latest == null)
          Text(data.officialModalityText)
        else ...<Widget>[
          // Aucune couleur grise ici, campagne ancienne ou non — un libellé
          // d'état exige 7:1 (`04-ui.md` § 3), que `#767676` (4,54:1) ne
          // tient pas. `BR-010` reste porté par le marqueur de la carte et
          // par la mention datée ci-dessous, pas par cette couleur.
          Text(
            flowCategoryLabel(latest.category),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // Un code `4` est un fait de terrain constaté, pas une absence de
          // donnée : la phrase de `UC-004 A2` le dit en toutes lettres.
          if (latest.category is NonObserve) Text(ondePointNonObserveText),
          Text('$ondeModalitePrefix${data.officialModalityText}'),
          Text(_campagneLine(latest.observedAt, data.age, data.ageInDays)),
        ],
        if (data.history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            ondeHistoriqueTitre,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          // L'ordre du dépôt, la plus récente en tête — jamais retrié ici
          // (`UC-004 § 4`).
          for (final OndeObservation observation in data.history)
            Text(
              '${formatCalendarDate(observation.observedAt)} — '
              '${flowCategoryLabel(observation.category)}',
            ),
        ],
        const SizedBox(height: 8),
        // Le rappel de rythme, dans TOUS les cas (`UC-004 § 5`, `BR-010`) —
        // y compris sans aucune campagne connue.
        Text(data.seasonNotice),
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

/// Le panneau de la fiche ONDE : rend l'état porté par
/// [OndeSheetViewModel], quel qu'il soit. `switch` exhaustif sur un `sealed`
/// (`BR-011`) — une branche oubliée est une erreur de compilation, pas un
/// écran muet.
///
/// La fiche ne se ferme que par [onClose] : un tap sur la carte hors marqueur
/// ne la ferme pas. Une fermeture par un geste que rien ne teste serait une
/// magie invisible.
class OndeSheetPanel extends StatelessWidget {
  const OndeSheetPanel({required this.state, required this.onClose, super.key});

  /// L'état courant de la fiche.
  final OndeSheetState state;

  /// Appelé par le bouton de fermeture — branché sur
  /// `OndeSheetViewModel.close`.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      OndeSheetFermee() => const SizedBox.shrink(),
      OndeSheetEnCours(:final OndePoint point) => _frame(
        Text('Chargement du point ${point.label}…'),
      ),
      OndeSheetPrete(:final OndeSheetData data) => _frame(
        OndeSummarySheet(data: data),
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

  /// Le cadre commun aux trois états visibles : le contenu, et le bouton de
  /// fermeture à sa droite.
  Widget _frame(Widget content) {
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: content),
            const SizedBox(width: 8),
            _CloseButton(onClose: onClose),
          ],
        ),
      ),
    );
  }
}

/// Le bouton de fermeture, dimensionné à [ondeSheetTapTarget] par un
/// `SizedBox` explicite et non par les valeurs par défaut d'un bouton
/// Material : la taille est alors une propriété du code, mesurable par test
/// (`04-ui.md` § 3), pas un effet de thème.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fermer la fiche',
      child: GestureDetector(
        key: ondeSheetCloseButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: const SizedBox(
          width: ondeSheetTapTarget,
          height: ondeSheetTapTarget,
          child: Center(child: Icon(Icons.close)),
        ),
      ),
    );
  }
}

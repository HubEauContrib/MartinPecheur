// Ce que la carte DIT quand elle n'a rien à dessiner, et ce qu'elle dit
// quand une source est tombée (`U6`).
//
// Une carte sans marqueur se lit spontanément comme « il n'y a pas de
// problème ici ». C'est l'inverse : cela signifie que **personne ne mesure**
// (`BR-007`). Chaque absence a donc son texte, chaque panne nomme sa source,
// et il n'y a **jamais d'écran blanc** ni d'état par défaut.
//
// ⚠️ **Les textes sont RECOPIÉS, pas réécrits** — `docs/02-specifications.md
// § 4`, `docs/br/BR-007-absence-de-donnee-jamais-neutre.md` et `UC-001 A5`
// font foi, et `docs/glossary.md` fait foi sur toute reformulation. Le texte
// de `BR-007` contient lui-même « tout va bien », dans une NÉGATION (« Ce
// n'est pas un signe que tout va bien ») : c'est l'affirmation qui est
// interdite, et le balayage du test dit exactement cela.
//
// ⚠️ **Deux exceptions déclarées** : [sourceUnavailableHint] et
// [unreadableRowsHint] n'ont **aucune source dans la spec** — ni
// `02-specifications.md § 4`, ni `BR-007`, ni `UC-001` ne les donnent. Elles
// appliquent l'esprit de `BR-007` (une panne ne dit rien de l'eau) à deux
// cas que la spec ne traite pas. Dites ici pour ne pas les faire passer
// pour des recopies.
//
// La décision — quel avis pour quel état d'écran — vit dans [mapNoticesFor],
// une fonction PURE : `buildMapOverlays` l'appelle et se contente de rendre
// ce qu'elle décide. Sans cette séparation, « une panne ne doit pas
// s'afficher à côté de "personne ne mesure ici" » ne serait vérifiable qu'en
// montant un écran entier.
//
// ⚠️ Ce fichier ne connaît aucun type de `lib/data/` : il ne peut pas
// inspecter une `HubEauFailure` pour deviner qui est tombé (règle
// `features-vers-data` de `test/architecture/layers_test.dart`). C'est le
// ViewModel qui nomme la source, par [MapErrorSource] — une information
// qu'il possède au moment où il pose l'erreur, jamais une lecture de message.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart'
    show MapErrorSource;
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Zone sans station ni point, recopié de `BR-007` § « Invariants & cas
/// limites » et de `02-specifications.md § 4` (« Aucune station dans la
/// zone »).
const String noDataInAreaText =
    "Il n'y a ni station de mesure ni point d'observation dans le secteur "
    "affiché. Ce n'est pas un signe que tout va bien : c'est simplement que "
    'personne ne mesure ici.';

/// L'action qui accompagne ce message (`02-specifications.md § 4`,
/// `UC-001 A2`).
const String widenSearchLabel = 'Élargir la recherche';

/// Zone hors couverture ONDE, recopié de `02-specifications.md § 4`. Il
/// **nomme le périmètre réel** du réseau, comme l'exige `UC-001 A5` : France
/// hexagonale et Corse, sur de petits cours d'eau choisis (`01-analyse.md
/// § 3`, `BR-007`). Le décompte des points du réseau — 3 548 — appartient à
/// la règle, pas à l'écran : une absence s'explique par un périmètre, pas
/// par un chiffre que l'usager ne peut pas recouper.
const String outsideOndeCoverageText =
    "Le réseau ONDE ne suit que certains petits cours d'eau de France "
    'hexagonale et de Corse.';

/// Formulation de repli de `BR-007`, mot pour mot. Employée là où l'absence
/// doit être **nommée** en plus d'être expliquée.
const String noDataFallbackText = 'Aucune donnée disponible ici.';

/// Zone sans station, sur l'échelle [MapScaleKind.debit] — recopié de
/// `02-specifications.md § 4` et de `BR-007` § « Invariants & cas limites »,
/// arbitrage du commanditaire du 2026-09-18.
///
/// Avant cet arbitrage, ce cas rendait [noDataFallbackText] : la seule
/// phrase de spec disait « ni station ni point d'observation », or l'ONDE
/// n'est pas interrogée sur cette échelle (`BR-008`). Cette phrase-ci
/// n'affirme qu'une seule absence, celle qui a été lue.
const String noStationInAreaText =
    "Il n'y a aucune station de mesure dans le secteur affiché. Cela ne dit "
    "rien de l'état des cours d'eau : le débit n'est simplement pas mesuré "
    'ici.';

/// Ce qu'une panne de source ne dit PAS : elle ne dit rien de l'eau. Sans
/// cette ligne, un message d'erreur seul se lirait comme un constat de
/// terrain (`BR-007`).
const String sourceUnavailableHint =
    "L'absence de marqueur ne dit rien de l'état des cours d'eau.";

/// Même précaution pour les lignes illisibles : ces points existent, ils ne
/// sont simplement pas affichés.
const String unreadableRowsHint =
    "Ces points ne sont pas affichés. Leur absence ne dit rien de l'état de "
    "l'eau.";

/// « Le service Hub'Eau n'a pas répondu. » de `02-specifications.md § 4`,
/// paramétré par la source : la règle est « message **par source** », et un
/// message unique pour toutes les sources ne la respecterait pas.
String sourceUnavailableText(String sourceName) =>
    "$sourceName n'a pas répondu.";

/// Combien de lignes ONDE la source a rendues sans qu'on sache les lire, sur
/// l'emprise regardée (`T-14`). Singulier à 0 et 1, comme en français.
String unreadableRowsText(int count) => count > 1
    ? "$count points d'observation non lisibles sur cette emprise."
    : "$count point d'observation non lisible sur cette emprise.";

/// Le nom affichable d'une source défaillante. `switch` exhaustif sur un
/// `enum` fermé, **avec une branche par défaut** (`BR-011`) : une source
/// ajoutée sans branche ne compile pas, et une source inconnue a tout de
/// même un nom — un message qui ne nomme personne serait précisément ce que
/// `BR-007` refuse.
String mapSourceName(MapErrorSource? source) => switch (source) {
  MapErrorSource.referentiel => 'Le référentiel embarqué des stations',
  // Réutilise [ondeSourceName] (`lib/domain/sources/source_names.dart`,
  // `W4`) : la même chaîne nomme cette source sur la carte et dans la fiche
  // ONDE — jamais dans la fenêtre d'avertissement, qui ne nomme aucune
  // source — un concept, un mot (`glossary.md`).
  MapErrorSource.ecoulement => ondeSourceName,
  null => 'Une source de données',
};

/// Clé de l'action « Élargir la recherche ». Posée sur le nœud sémantique,
/// donc sur la boîte entière : c'est elle que les tests tapent et mesurent,
/// comme pour les puces d'échelle.
const Key widenSearchKey = ValueKey<String>('map-elargir-la-recherche');

/// Ce que la carte doit **dire** d'une emprise, au-delà de ses marqueurs.
///
/// Une `sealed class` et non un `enum` : deux avis portent des données
/// (le nom de la source, le nombre de lignes). Le `switch` de
/// [buildMapNotice] est exhaustif — un avis ajouté sans branche est une
/// erreur de compilation, jamais un avis silencieusement non rendu
/// (`BR-011`).
sealed class MapNotice {
  const MapNotice();
}

/// Ni station ni point dans le secteur affiché (`BR-007`, `UC-001 A2`).
///
/// ⚠️ Cette phrase **affirme deux absences** : elle n'est employable que là
/// où les deux ensembles ont été lus, c'est-à-dire sur l'échelle
/// [MapScaleKind.ecoulement]. Ailleurs, c'est [NoStationInArea].
final class NoDataInArea extends MapNotice {
  const NoDataInArea();
}

/// Zone sans station, sur l'échelle [MapScaleKind.debit] (`BR-008`,
/// `BR-007`, arbitrage du commanditaire du 2026-09-18).
///
/// L'ONDE n'est pas interrogée sur cette échelle (`BR-008`), et « ni station
/// ni point d'observation » adosserait la moitié de la phrase à une lecture
/// qui n'a pas eu lieu — l'app pourrait même porter en mémoire des
/// observations du dernier passage sur l'autre échelle. L'avis dit donc
/// [noStationInAreaText] : on n'affirme que ce qu'on a lu, et l'absence
/// reste nommée plutôt que muette.
final class NoStationInArea extends MapNotice {
  const NoStationInArea();
}

/// Des stations existent dans le secteur, mais aucun point ONDE : c'est le
/// périmètre du réseau qu'il faut nommer, pas une absence de mesure
/// (`UC-001 A5`).
final class OutsideOndeCoverage extends MapNotice {
  const OutsideOndeCoverage();
}

/// Une source n'a pas répondu, et [sourceName] la nomme.
///
/// ⚠️ **Aucune cause technique.** L'exception qui a déclenché cet avis ne le
/// traverse pas : c'est une donnée de diagnostic, pas un texte pour
/// l'usager — la même convention que les deux fiches
/// (`station_summary_sheet.dart`, `onde_summary_sheet.dart`), et le grief
/// qui a fait retirer `MapErrorBanner`.
final class SourceUnavailable extends MapNotice {
  const SourceUnavailable({required this.sourceName});

  /// Le nom affichable de la source, produit par [mapSourceName].
  final String sourceName;
}

/// [count] lignes ONDE ont été rendues par la source sans qu'on sache les
/// lire, sur cette emprise (`T-14`, `BR-007`).
final class UnreadableRows extends MapNotice {
  const UnreadableRows(this.count);

  /// Le nombre de lignes laissées de côté sur l'emprise courante.
  final int count;
}

/// Décide des avis à afficher par-dessus la carte. Fonction **pure** : aucun
/// widget, aucune horloge, aucun dépôt — c'est ce qui rend chaque
/// combinaison (échelle × vide/non vide × panne × lignes illisibles)
/// vérifiable sans monter d'écran.
///
/// Trois règles, dans cet ordre, et l'ordre est la décision :
///
/// 1. **Une panne parle seule.** Quand [error] n'est pas nul, l'absence de
///    marqueur s'explique par la panne : afficher en plus « personne ne
///    mesure ici » affirmerait un fait de terrain que personne n'a constaté
///    (`BR-007`, `UC-001 A4`). Le message nomme la source, jamais « une
///    erreur est survenue ».
/// 2. **Des lignes illisibles expliquent l'absence qu'elles causent.**
///    Quand [ondeUnreadableRows] est positif sur l'échelle écoulement, c'est
///    ce compte qui est dit — et aucun avis d'absence ne l'accompagne, sinon
///    l'écran dirait à la fois « personne ne mesure ici » et « N points non
///    lisibles », ce qui se contredit.
/// 3. **On n'affirme que ce qu'on a lu.** « Ni station ni point » n'est vrai
///    **que si les deux manquent**, et ne se dit que là où les deux ont été
///    cherchés : c'est la lettre de `BR-007`. Sur l'échelle écoulement, des
///    stations sans observation ONDE donnent l'avis du périmètre du réseau
///    ([OutsideOndeCoverage], `UC-001 A5`) ; sur l'échelle débit, où l'ONDE
///    n'est pas interrogée (`BR-008`), une emprise sans station donne
///    [NoStationInArea] — une formulation propre à ce cas, arbitrage du
///    commanditaire du 2026-09-18 : l'absence est nommée, sans prétendre
///    dire ce qui manque côté ONDE.
///
/// Sur l'échelle [MapScaleKind.debit], les observations et les lignes ONDE
/// ne disent rien : aucune n'est dessinée (`BR-008`), il n'y a donc rien à
/// expliquer les concernant — et rien à en conclure non plus, un résidu du
/// dernier passage sur l'écoulement ne décrivant pas cette emprise-ci.
///
/// De [error], seule la **nullité** est lue : la cause technique ne décide
/// rien et ne s'affiche pas.
List<MapNotice> mapNoticesFor({
  required MapScaleKind scale,
  required bool hasStations,
  required bool hasOndeObservations,
  required Object? error,
  required MapErrorSource? errorSource,
  required int ondeUnreadableRows,
}) {
  if (error != null) {
    return <MapNotice>[
      SourceUnavailable(sourceName: mapSourceName(errorSource)),
    ];
  }

  // `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
  // sans branche ne compile pas — jamais un écran silencieusement muet.
  return switch (scale) {
    MapScaleKind.debit =>
      hasStations ? const <MapNotice>[] : const <MapNotice>[NoStationInArea()],
    MapScaleKind.ecoulement => <MapNotice>[
      if (ondeUnreadableRows > 0) UnreadableRows(ondeUnreadableRows),
      if (!hasOndeObservations && ondeUnreadableRows == 0)
        if (hasStations) const OutsideOndeCoverage() else const NoDataInArea(),
    ],
  };
}

/// Rend l'avis [notice]. `switch` exhaustif sur la `sealed class`
/// (`BR-011`). [onWiden] n'est utilisé que par les deux avis d'absence,
/// seuls porteurs d'une action (`UC-001 A2`).
Widget buildMapNotice(MapNotice notice, {required VoidCallback onWiden}) =>
    switch (notice) {
      NoDataInArea() => NoDataInAreaNotice(onWiden: onWiden),
      NoStationInArea() => NoStationInAreaNotice(onWiden: onWiden),
      OutsideOndeCoverage() => const OutsideOndeCoverageNotice(),
      SourceUnavailable(:final String sourceName) => SourceUnavailableNotice(
        sourceName: sourceName,
      ),
      UnreadableRows(:final int count) => UnreadableRowsNotice(count: count),
    };

/// Ni station ni point dans le secteur affiché, avec l'action « Élargir la
/// recherche » (`BR-007`, `02-specifications.md § 4`, `UC-001 A2`).
class NoDataInAreaNotice extends StatelessWidget {
  const NoDataInAreaNotice({required this.onWiden, super.key});

  /// Appelé au tap sur « Élargir la recherche ». En production,
  /// `MapViewModel.widenSearch` : la vue ne calcule aucune emprise.
  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) =>
      _AbsenceNotice(text: noDataInAreaText, onWiden: onWiden);
}

/// Zone sans station, sur l'échelle débit — [noStationInAreaText], arbitrage
/// du commanditaire du 2026-09-18 : employée là où l'écran n'a pas cherché
/// tout ce qu'il faudrait pour en dire plus (l'ONDE n'est pas interrogée sur
/// cette échelle, `BR-008`). Un type distinct de [NoDataInAreaNotice], et non
/// un paramètre : c'est ce qui permet à un test d'écran d'exiger l'un **et
/// de refuser l'autre**.
class NoStationInAreaNotice extends StatelessWidget {
  const NoStationInAreaNotice({required this.onWiden, super.key});

  /// Appelé au tap sur « Élargir la recherche », comme pour
  /// [NoDataInAreaNotice] : une absence sans issue serait un cul-de-sac.
  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) =>
      _AbsenceNotice(text: noStationInAreaText, onWiden: onWiden);
}

/// L'habillage commun des deux avis d'absence : le texte, puis l'action
/// « Élargir la recherche ». Ce qui change entre eux est la **phrase**, donc
/// ce qu'on affirme — jamais la mise en page.
class _AbsenceNotice extends StatelessWidget {
  const _AbsenceNotice({required this.text, required this.onWiden});

  final String text;
  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      children: <Widget>[
        Text(text, style: _bodyStyle),
        const SizedBox(height: _noticeSpacing),
        _WidenSearchAction(onWiden: onWiden),
      ],
    );
  }
}

/// L'action « Élargir la recherche ». Construite à la main plutôt qu'avec un
/// bouton Material, pour la même raison que les puces d'échelle : la cible
/// tactile de 44 pt (`04-ui.md § 3`) est ici une contrainte explicite, pas
/// la densité que le thème veut bien accorder.
class _WidenSearchAction extends StatelessWidget {
  const _WidenSearchAction({required this.onWiden});

  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: widenSearchKey,
      button: true,
      label: widenSearchLabel,
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud.
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que le
      // geste porterait sinon lui-même : un double-tap au lecteur d'écran
      // n'activerait plus rien (relecture du 2026-09-23).
      onTap: onWiden,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onWiden,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minimumTapTarget,
            minHeight: minimumTapTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black),
              borderRadius: const BorderRadius.all(
                Radius.circular(minimumTapTarget / 2),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // `Align` à facteurs 1 : la boîte se dimensionne sur son
              // texte, et c'est le `ConstrainedBox` au-dessus qui impose le
              // plancher de 44 pt.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(widenSearchLabel, style: _bodyStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zone hors couverture ONDE : le message **nomme le périmètre réel** du
/// réseau (`UC-001 A5`), et nomme l'absence (`BR-007`).
class OutsideOndeCoverageNotice extends StatelessWidget {
  const OutsideOndeCoverageNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NoticeCard(
      children: <Widget>[
        Text(outsideOndeCoverageText, style: _bodyStyle),
        SizedBox(height: _noticeSpacing),
        Text(noDataFallbackText, style: _bodyStyle),
      ],
    );
  }
}

/// Une source n'a pas répondu, et le message la **nomme** (`BR-007` :
/// « message par source. Les autres sources restent affichées. Jamais
/// d'écran blanc »).
/// ⚠️ **La cause technique n'est pas affichée**, et le widget ne l'accepte
/// même pas : `error.toString()` est une donnée de diagnostic, pas un texte
/// pour l'usager — même convention que les deux fiches
/// (`station_summary_sheet.dart`, `onde_summary_sheet.dart`). C'est ce
/// reproche qui a fait retirer `MapErrorBanner` et son
/// « Les stations n'ont pas pu être chargées : $error ».
class SourceUnavailableNotice extends StatelessWidget {
  const SourceUnavailableNotice({required this.sourceName, super.key});

  /// Le nom affichable de la source, produit par [mapSourceName] —
  /// « Hub'Eau écoulement ONDE », jamais « le serveur ».
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      children: <Widget>[
        Text(sourceUnavailableText(sourceName), style: _bodyStyle),
        const SizedBox(height: _noticeSpacing),
        const Text(sourceUnavailableHint, style: _bodyStyle),
      ],
    );
  }
}

/// N lignes ONDE rendues par la source et illisibles, sur cette emprise
/// (`T-14`, `BR-007`). Sans ce message, ces points disparaîtraient de
/// l'écran sans que rien ne l'explique.
class UnreadableRowsNotice extends StatelessWidget {
  const UnreadableRowsNotice({required this.count, super.key});

  /// Le nombre de lignes laissées de côté, lu sur
  /// `MapViewModel.ondeUnreadableRows`.
  final int count;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      children: <Widget>[
        Text(unreadableRowsText(count), style: _bodyStyle),
        const SizedBox(height: _noticeSpacing),
        const Text(unreadableRowsHint, style: _bodyStyle),
      ],
    );
  }
}

/// L'habillage commun des avis : un fond opaque et une largeur bornée. Un
/// texte posé directement sur un fond de carte quelconque ne tient aucun
/// contraste (`04-ui.md § 3`) — même raison que l'attribution IGN.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _noticeMaxWidth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Noir sur blanc : le contraste maximal, là où `04-ui.md § 3` exige ≥ 7:1
/// sur les libellés d'état et les avertissements.
const TextStyle _bodyStyle = TextStyle(fontSize: 13, color: Colors.black);

/// Écart vertical entre deux lignes d'un avis, en pixels logiques.
const double _noticeSpacing = 8;

/// Largeur maximale d'un avis, en pixels logiques — alignée sur celle du
/// panneau de fiche : au-delà, une ligne de texte devient illisible.
const double _noticeMaxWidth = 420;

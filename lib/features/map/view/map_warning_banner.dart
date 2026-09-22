// Le bandeau d'avertissement de la carte (`W3`, emplacement 2 de
// `04-ui.md § 5`, `BR-014`) : affiché à CHAQUE lancement, à tous les niveaux
// de zoom et sur tous les écrans de détail. `map_warning_banner_test.dart`
// verrouille sa surface publique en liste blanche en lisant le code
// source — `onExplain` et `onDismiss`, rien d'autre — pas seulement le
// comportement : un paramètre ajouté demain sans mise à jour de ce verrou
// romprait l'intention sans qu'aucun test de comportement ne le remarque
// forcément.
//
// ⚠️ Arbitrage du commanditaire du 2026-09-23 (`W3b`) : le bandeau n'est
// plus permanent ni non repliable — il porte désormais un bouton « Fermer »
// ([onDismiss]) qui le referme pour la SEULE session en cours, sans rien
// persister ; au lancement suivant il revient. C'est `MapViewModel`
// (`bannerVisible`, `dismissBanner`, `showBanner`) qui porte cet état :
// [MapWarningBanner] lui-même ne décide toujours rien, il se contente
// d'appeler [onDismiss] au tap. `buildMapScreen` (`map_view.dart`) ne le
// rend que si `bannerVisible` est vrai. Un menu de la carte
// ([map_menu.dart], entrée « Avertissement ») le réaffiche.
//
// ⚠️ Choix d'emplacement (révision du plan T1 du 2026-09-22, confirmé le
// même jour pour la feuille de relecture) : `features/map/` est le SEUL
// consommateur de ce bandeau — `test/architecture/layers_test.dart`
// (règle `feature-vers-feature`) interdit de toute façon à cette tranche
// d'importer `features/warnings/`, où vivait la première version du plan.
// `lib/features/shared/` n'est pas non plus retenu : un seul consommateur ne
// justifie pas un emplacement partagé (YAGNI, CLAUDE.md).
//
// La feuille de relecture ([WarningReviewSheet]) vit dans CE MÊME fichier,
// pour la même raison : c'est la seule action du bandeau qui l'ouvre, elle
// ne dépend d'aucun ViewModel — seulement des textes déjà figés du modal
// initial (`lib/domain/warnings/warning_texts.dart`) — et n'a donc rien à
// gagner à être injectée depuis `main.dart` comme les fiches station et
// ONDE, qui possèdent chacune un ViewModel à câbler. Un fichier séparé
// n'ajouterait ici aucune lisibilité.
//
// Couple de teintes déclaré pour le contraste (`04-ui.md § 3`, ≥ 7:1) :
// texte noir sur fond blanc — le contraste maximal (21:1), la même
// convention que l'attribution IGN et les avis de `map_empty_states.dart`.
// Aucune teinte d'état (`04-ui.md § 2`) n'est engagée ici.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart'
    show stationMarkerTapTarget;

/// Clé de la région d'alerte que forme le bandeau.
const Key mapWarningBannerRegionKey = Key('map-warning-banner-region');

/// Clé de l'action « Ce que ça dit ».
const Key mapWarningBannerExplainKey = Key('map-warning-banner-explain');

/// Clé du bouton de fermeture du bandeau (W3b, session seulement).
const Key mapWarningBannerDismissKey = Key('map-warning-banner-dismiss');

/// Clé de la région d'alerte que forme la feuille de relecture.
const Key warningReviewSheetRegionKey = Key('warning-review-sheet-region');

/// Clé du bouton de fermeture de la feuille de relecture.
const Key warningReviewSheetCloseButtonKey = Key('warning-review-sheet-close');

/// Fond du bandeau — seul [MapWarningBanner] est couvert par le verrou de
/// contraste (`04-ui.md § 3`) ; [WarningReviewSheet] suit le thème ambiant,
/// elle n'a pas à en porter un propre.
const Color mapWarningBannerBackground = Colors.white;

/// Texte et icône du bandeau — 21:1 sur [mapWarningBannerBackground], très
/// au-dessus du seuil de 7:1 (`04-ui.md § 3`).
const Color mapWarningBannerForeground = Colors.black;

/// Le bandeau d'avertissement (`BR-014`, emplacement 2 de `04-ui.md § 5`) :
/// affiché à chaque lancement, refermable pour la session par [onDismiss]
/// (arbitrage du 2026-09-23, `W3b`). [onExplain] est l'action « Ce que ça
/// dit », jamais un moyen de faire disparaître le bandeau — sans lui,
/// l'action ouvre elle-même [WarningReviewSheet] via
/// `showModalBottomSheet`, si bien que la carte n'a RIEN à câbler pour que
/// `04-ui.md § 1` soit respecté.
class MapWarningBanner extends StatelessWidget {
  const MapWarningBanner({this.onExplain, this.onDismiss, super.key});

  /// Appelé au tap sur « Ce que ça dit ». `null` par défaut : le bandeau
  /// ouvre alors lui-même [WarningReviewSheet]. Un test peut fournir cette
  /// valeur pour vérifier que le tap déclenche bien une action, sans monter
  /// la feuille.
  final VoidCallback? onExplain;

  /// Appelé au tap sur « Fermer » (W3b). Ce widget ne décide rien : c'est
  /// l'appelant — en production, `MapViewModel.dismissBanner` — qui porte
  /// l'état « bandeau visible » pour la session. `null` par défaut : le tap
  /// n'a alors aucun effet, plutôt que de faire disparaître un widget qui ne
  /// possède pas son propre état d'affichage.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: mapWarningBannerRegionKey,
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: mapWarningBannerBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // ⚠️ L'action est empilée SOUS le texte, dans la même colonne
            // extensible, plutôt que côte à côte dans la ligne : à 200 % de
            // police (`04-ui.md § 3`), « Ce que ça dit » ne tient plus à
            // côté du texte sur un écran étroit, et une ligne qui la
            // pousserait hors champ la rendrait inatteignable — un bandeau
            // qui rétrécit son action est pire qu'un bandeau qui grandit.
            // Seule l'icône reste sur la ligne : sa taille est fixe, elle ne
            // grandit jamais avec la police (`Icon`, contrairement à
            // `Text`).
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: mapWarningBannerForeground,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mapBannerText,
                        style: const TextStyle(
                          color: mapWarningBannerForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // `Wrap`, comme `MapScaleChips` (`map_view.dart`) :
                      // deux actions ne tiennent pas toujours côte à côte à
                      // 200 % de police (`04-ui.md § 3`) sur un écran
                      // étroit.
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _ExplainAction(
                            onTap: onExplain ?? () => _openReviewSheet(context),
                          ),
                          _DismissAction(onTap: onDismiss ?? () {}),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReviewSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const WarningReviewSheet(),
    );
  }
}

/// L'action « Ce que ça dit », cible tactile de [stationMarkerTapTarget]
/// (44 pt, `04-ui.md § 3`).
class _ExplainAction extends StatelessWidget {
  const _ExplainAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: mapWarningBannerExplainKey,
      button: true,
      label: mapExplainActionLabel,
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud — même choix que
      // `_MapScaleChip` (`map_view.dart`).
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que le
      // geste porterait sinon lui-même : un double-tap au lecteur d'écran
      // n'activerait plus rien (relecture du 2026-09-23).
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: stationMarkerTapTarget,
            minHeight: stationMarkerTapTarget,
          ),
          child: Center(
            child: Text(
              mapExplainActionLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mapWarningBannerForeground,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton de fermeture du bandeau pour la session (W3b), cible tactile de
/// [stationMarkerTapTarget]. Réutilise [warningReviewCloseLabel] — même
/// action de lecture qu'une fermeture de feuille, pas un acquittement
/// (`BR-012` ne s'applique qu'au bouton du modal initial).
///
/// [InkWell] plutôt que le `GestureDetector` nu employé par [_ExplainAction] :
/// un `GestureDetector` ne répond à aucun événement clavier, et « Fermer »
/// doit être atteignable au Tab et activable à Entrée/Espace (`04-ui.md § 3`,
/// relecture du 2026-09-23). `Material(type: transparency)` l'entoure sans
/// changer le fond du bandeau : `InkWell` exige un ancêtre `Material`, et ce
/// type n'en peint aucun — seule l'éclaboussure au tap, déjà attendue d'un
/// contrôle interactif, s'ajoute au rendu.
class _DismissAction extends StatelessWidget {
  const _DismissAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: mapWarningBannerDismissKey,
      button: true,
      label: warningReviewCloseLabel,
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que
      // `InkWell` porterait sinon lui-même : un double-tap au lecteur
      // d'écran n'activerait plus rien (relecture du 2026-09-23).
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: stationMarkerTapTarget,
              minHeight: stationMarkerTapTarget,
            ),
            child: Center(
              child: Text(
                warningReviewCloseLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: mapWarningBannerForeground,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La feuille de relecture des textes du modal initial (arbitrage du
/// commanditaire, 2026-09-22) : réaffiche [initialWarningTitle] et
/// [initialWarningBody] EN LECTURE SEULE — aucune case, aucun bouton
/// d'acquittement, seulement une fermeture. C'est la même information que le
/// modal du premier lancement (`InitialWarningView`), jamais un texte
/// nouveau : l'usager l'a déjà acquittée, cette feuille la lui redonne à
/// relire sans lui redemander de choix.
class WarningReviewSheet extends StatelessWidget {
  const WarningReviewSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        key: warningReviewSheetRegionKey,
        container: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                initialWarningTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(initialWarningBody),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: _CloseAction(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le bouton de fermeture de la feuille ([warningReviewCloseLabel]).
class _CloseAction extends StatelessWidget {
  const _CloseAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: warningReviewSheetCloseButtonKey,
      button: true,
      label: warningReviewCloseLabel,
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que le
      // geste porterait sinon lui-même : un double-tap au lecteur d'écran
      // n'activerait plus rien (relecture du 2026-09-23).
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: stationMarkerTapTarget,
            minHeight: stationMarkerTapTarget,
          ),
          child: const Center(
            // Pas de couleur imposée ici : la feuille suit le thème
            // ambiant, elle ne porte pas le couple de teintes déclaré pour
            // le bandeau.
            child: Text(warningReviewCloseLabel),
          ),
        ),
      ),
    );
  }
}

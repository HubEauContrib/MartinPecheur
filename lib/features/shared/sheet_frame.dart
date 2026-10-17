// Le cadre commun des trois fiches — station, point ONDE, tronçon de
// vigilance (`S3` d'Ergonomie, arbitrage 3, spec § 6.1) : un EN-TÊTE ÉPINGLÉ
// qui ne défile pas, et un CORPS qui défile dessous.
//
// L'en-tête porte, de haut en bas : la rangée « nature · étoile · fermeture »
// (la nature se replie sur la largeur, jamais d'ellipse), le contrôle
// « ⚠ Avertissement » (`W3c`, présent dans tous les états d'une fiche), puis
// l'avis d'échec d'écriture du favori quand il y en a un. Il ne cède jamais à
// un repli (spec § 5.6) : c'est le corps qui défile quand la place manque.
//
// ⚠️ Ce que la mise en page de la carte (`D1`) interroge, sans `LayoutBuilder`
// (note d'architecture du plan) :
// - `getMinIntrinsicHeight` = l'en-tête SEUL — le corps est enveloppé dans
//   [NoMinIntrinsicHeight], qui annonce 0 ;
// - `getMaxIntrinsicHeight` = l'en-tête et le corps ENTIER.
// Rien, dans le cadre, ne lève d'erreur sur une demande d'intrinsèques : un
// défilement s'y fait par `SingleChildScrollView`, jamais par un `ListView` ni
// un autre `Viewport`. Le CONTRAT vaut aussi pour le `body` que la fiche
// fournit (voir [SheetFrame.body]) : le cadre ne peut pas le garantir pour lui.
//
// Un filet (`#C9CFC4`, § 6.1) sépare l'en-tête du corps, peint dans la boîte de
// l'en-tête sans en changer la hauteur. Entre l'étoile et la fermeture, 8 px :
// l'écart de l'amendement `S7b`, qui était VERTICAL (l'étoile sous la
// fermeture), transposé sur la rangée — un choix de la boucle principale sur le
// croquis du § 6.1.
//
// Sous une hauteur BORNÉE (la fiche du bas, le panneau latéral), le corps est
// un `Flexible` : il prend ce que l'en-tête laisse et défile. Sous une hauteur
// NON bornée (la zone des fiches d'avant `D5`, qui défile elle-même), le même
// `Flexible`, dans une `Column` de taille minimale, se pose à la hauteur du
// corps : `RenderFlex` ne partage l'espace libre que si l'axe principal est
// borné, sinon il donne à l'enfant souple des contraintes non bornées — aucune
// branche ici, et un test de ce fichier le verrouille.
//
// Aucune tranche importée (`shared-sans-tranche`) : le cadre reçoit tout par
// paramètre, jusqu'à la clé du bouton de fermeture, que chaque fiche garde
// dans son propre fichier (`stationSheetCloseButtonKey`, …).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Clé de l'en-tête épinglé : nature, étoile, fermeture, « ⚠ Avertissement »
/// et l'avis d'échec d'écriture. C'est elle que les tests mesurent.
const Key sheetFrameHeaderKey = Key('sheet-frame-header');

/// Clé du défilement du corps.
const Key sheetFrameBodyKey = Key('sheet-frame-body');

/// Libellé annoncé du bouton de fermeture, le même sur les trois fiches.
const String sheetCloseLabel = 'Fermer la fiche';

/// La nature de la fiche : 12, gras, `#3A4148` (spec § 6.1).
const TextStyle _natureStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  color: Color(0xFF3A4148),
);

/// Couleur du filet sous l'en-tête : celle des filets déjà en usage
/// (`flood_warning_card.dart`, `reinforced_warning_card.dart`).
const Color _ruleColor = Color(0xFFC9CFC4);

/// Marges de l'en-tête : celles de l'ancien cadre (12), sans bas — le contrôle
/// « ⚠ Avertissement » a déjà sa cible de [minimumTapTarget] (44, 48 sous
/// Android).
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(12, 12, 12, 0);

/// Marges du corps : 12 de chaque côté et en bas, un peu d'air sous l'en-tête.
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

/// Une enveloppe qui annonce 0 de hauteur intrinsèque MINIMALE et transmet le
/// reste à son enfant : largeurs intrinsèques, hauteur intrinsèque maximale,
/// mise en page, peinture et touchers.
///
/// C'est ce qui fait du corps défilant d'une fiche un contenu qui PEUT céder :
/// sa hauteur « repliée » est nulle, sa hauteur « entière » est celle de son
/// contenu. [SheetFrame] s'en sert pour que `getMinIntrinsicHeight` dise
/// l'en-tête seul.
class NoMinIntrinsicHeight extends SingleChildRenderObjectWidget {
  const NoMinIntrinsicHeight({required Widget child, super.key})
    : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoMinIntrinsicHeight();
}

class _RenderNoMinIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;
}

/// Le cadre commun d'une fiche : en-tête épinglé ([nature], étoile,
/// fermeture, « ⚠ Avertissement », avis d'échec d'écriture) et [body]
/// défilant dessous.
///
/// - [closeButtonKey] : la clé que la fiche pose sur son bouton de fermeture
///   (`stationSheetCloseButtonKey`, …) — le cadre ne la connaît pas.
/// - [warningExtraText] : la phrase propre à la fiche, sous le texte général
///   de la fenêtre d'avertissement ; `null` sans date à donner.
/// - [favoriteStar] et [onToggleFavorite] : l'étoile, ensemble ou pas du tout.
///   `null`, aucun emplacement vide (la fiche tronçon, avant T5).
/// - [bodyScrollController] : la position du corps, que l'appelant remet à
///   zéro à chaque ouverture (`K4` de T3).
///
/// Ordre de tabulation : l'étoile est un arrêt ; la fermeture n'en est pas un
/// (`Échap` ferme).
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    required this.nature,
    required this.closeButtonKey,
    required this.onClose,
    required this.body,
    this.warningExtraText,
    this.favoriteStar,
    this.onToggleFavorite,
    this.bodyScrollController,
    super.key,
  }) : assert(
         favoriteStar == null || onToggleFavorite != null,
         "Une étoile sans onToggleFavorite n'a rien à basculer.",
       );

  /// La ligne de nature : « Station hydrométrique · K447001001 »,
  /// « Point ONDE », « Tronçon Vigicrues ». Elle se replie sur la largeur.
  final String nature;

  /// La clé du bouton de fermeture, fournie par la fiche.
  final Key closeButtonKey;

  /// Appelée par le bouton de fermeture.
  final VoidCallback onClose;

  /// Le contenu défilant, sous l'en-tête.
  ///
  /// Il doit LUI-MÊME répondre aux demandes de dimensions intrinsèques, que la
  /// mise en page de la carte adresse au cadre entier : ni `LayoutBuilder`, ni
  /// `ListView`, ni aucun autre `Viewport` dans ce sous-arbre (ils lèvent une
  /// erreur sur une telle demande). Une décision qui dépend de la largeur se
  /// prend dans un `RenderObject` qui sait calculer ses intrinsèques ; un
  /// défilement interne, par `SingleChildScrollView`.
  final Widget body;

  /// La phrase datée de la fenêtre « ⚠ Avertissement », ou `null`.
  final String? warningExtraText;

  /// L'étoile de favori telle qu'elle s'affiche, ou `null` : pas d'étoile.
  final FavoriteStar? favoriteStar;

  /// Ce que fait un tap sur l'étoile ; requis dès que [favoriteStar] est là.
  final VoidCallback? onToggleFavorite;

  /// Le contrôleur de défilement du corps, ou `null`.
  final ScrollController? bodyScrollController;

  @override
  Widget build(BuildContext context) {
    final FavoriteStar? star = favoriteStar;
    final VoidCallback? toggle = onToggleFavorite;
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Le filet du § 6.1 : une bordure basse, pleine largeur, peinte DANS
          // la boîte de l'en-tête. Un `DecoratedBox` et non un `Container`, qui
          // ajouterait l'épaisseur de la bordure en marge de son enfant :
          // aucune hauteur ne change, ni celle de l'en-tête ni les intrinsèques.
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _ruleColor)),
            ),
            child: Padding(
              key: sheetFrameHeaderKey,
              padding: _headerPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(nature, style: _natureStyle)),
                      if (star != null && toggle != null) ...<Widget>[
                        FavoriteStarButton(star: star, onToggle: toggle),
                        // 8 px entre l'étoile et la fermeture : deux actions
                        // opposées dont les cibles ne se touchent pas. C'est
                        // l'écart de l'amendement `S7b` (`docs/04-ui.md`,
                        // vertical : l'étoile sous la fermeture), transposé
                        // sur la rangée — choix de la boucle principale sur
                        // le croquis du § 6.1. Sans étoile, pas de boîte vide.
                        const SizedBox(width: 8),
                      ],
                      _CloseButton(buttonKey: closeButtonKey, onClose: onClose),
                    ],
                  ),
                  WarningLink(extraText: warningExtraText),
                  // `FavoriteStar` ne dit que `writeFailed` : la forme de
                  // l'étoile reste celle d'avant l'échec — pleine, c'est un
                  // retrait qui a échoué, vide un ajout. Une liste illisible
                  // (étoile inactive, sans `writeFailed`) ne laisse aucune
                  // phrase ici : l'écran « Favoris » l'explique.
                  if (star != null && star.writeFailed)
                    FavoriteWriteFailedNotice(
                      star.filled
                          ? favoriteRemoveFailedText
                          : favoriteWriteFailedText,
                    ),
                ],
              ),
            ),
          ),
          Flexible(
            // Sans la barre de défilement que `MaterialScrollBehavior` pose
            // sur un défilement vertical des cibles de bureau : sa
            // `MouseRegion` est opaque sur toute la boîte, et le corps d'une
            // fiche n'a pas à en porter une. Même retrait que
            // `data_sources_view.dart`.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: NoMinIntrinsicHeight(
                child: SingleChildScrollView(
                  key: sheetFrameBodyKey,
                  controller: bodyScrollController,
                  // Un contrôleur propre ou, à défaut, aucun : jamais le
                  // contrôleur primaire de l'écran, que ce corps n'a pas à
                  // capter sur le bureau.
                  primary: false,
                  padding: _bodyPadding,
                  child: body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le bouton de fermeture, dimensionné à [minimumTapTarget] par un
/// `SizedBox` explicite et non par les valeurs par défaut d'un bouton
/// Material : la taille est alors une propriété du code, mesurable par test
/// (`04-ui.md` § 3), pas un effet de thème. Repris tel quel des fiches, où il
/// existait en trois copies (station, ONDE, tronçon).
///
/// Pas un arrêt de tabulation : un `GestureDetector` ne prend pas le focus, et
/// `Échap` ferme déjà la fiche.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.buttonKey, required this.onClose});

  final Key buttonKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: sheetCloseLabel,
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SizedBox(
          width: minimumTapTarget,
          height: minimumTapTarget,
          child: const Center(child: Icon(Icons.close)),
        ),
      ),
    );
  }
}

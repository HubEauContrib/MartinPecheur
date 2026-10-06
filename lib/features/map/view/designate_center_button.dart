// Le bouton « Restrictions au centre de la carte » (`E1` de T2), refait selon
// le canvas de design validé par le commanditaire le 2026-09-29 : il sort de
// la colonne des contrôles (`MapControls`) — une quatrième icône ronde,
// identique aux autres, ne disait pas ce qu'elle faisait — pour devenir un
// bouton large et libellé, en bas au centre de la carte, avec dessous
// l'indice du geste équivalent (appui long au toucher, clic droit à la
// souris).
//
// Il n'existe que dans le MODE de désignation (`E5`, 2026-10-03) : le choix
// « Restrictions » du sélecteur (`map_scale_chips.dart`) le fait apparaître,
// avec son indice et le réticule, et le retire. Il n'est plus permanent.
//
// Comme [MapControls], c'est un widget de CONTENU pur : il ne connaît ni la
// caméra ni le ViewModel. `_MapViewState` construit le rappel.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Clé du bouton « Restrictions au centre de la carte » (`E1` de T2).
const Key mapDesignateCenterButtonKey = Key('map-designate-center');

/// Clé de l'indice de geste posé sous le bouton.
const Key mapDesignateCenterHintKey = Key('map-designate-center-hint');

/// Libellé visible ET annoncé du bouton.
const String designateCenterLabel = 'Restrictions au centre de la carte';

/// Hauteur minimale du bouton : au-delà de [minimumTapTarget], quelle que
/// soit la plateforme (canvas de design du 2026-09-29).
const double designateCenterButtonHeight = 52;

/// Écart entre le bouton et son indice.
const double designateCenterGap = 6;

/// Le bouton et son indice, empilés et centrés. Un seul widget pour que les
/// deux ne soient jamais posés l'un sans l'autre (l'indice sans le bouton
/// décrirait une alternative à rien).
class DesignateCenterControl extends StatelessWidget {
  const DesignateCenterControl({required this.onDesignate, super.key});

  /// Appelé par un tap, Entrée ou Espace : la désignation du centre de la
  /// carte. Non nul : sans désignation branchée, l'appelant n'affiche pas ce
  /// widget (un bouton mort serait pire qu'aucun bouton).
  final VoidCallback onDesignate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        DesignateCenterButton(onTap: onDesignate),
        const SizedBox(height: designateCenterGap),
        const DesignateCenterHint(),
      ],
    );
  }
}

/// Le bouton en pilule. Le libellé passe à la ligne plutôt que d'être tronqué
/// (petit écran, police à 200 %) ; la pilule (`StadiumBorder`) suit alors la
/// hauteur.
class DesignateCenterButton extends StatelessWidget {
  const DesignateCenterButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Même montage que `_MapControlButton` (`map_controls.dart`) : la clé et
    // le libellé sur le `Semantics`, `KeyboardFocusRing` SOUS lui, le
    // `InkWell` sans focus propre (un second nœud ferait deux arrêts de
    // tabulation).
    return Semantics(
      key: mapDesignateCenterButtonKey,
      button: true,
      enabled: true,
      label: designateCenterLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: KeyboardFocusRing(
        onActivate: onTap,
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: primaryActionColor,
            shape: StadiumBorder(
              side: BorderSide(color: Colors.white, width: 2),
            ),
            shadows: <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              canRequestFocus: false,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: designateCenterButtonHeight,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Icon(
                          Icons.gps_fixed,
                          size: 22,
                          color: onPrimaryActionColor,
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          designateCenterLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: onPrimaryActionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'indice du geste équivalent. Exclu de la sémantique : il décrit un geste
/// de pointeur, inutile au lecteur d'écran, qui a le bouton.
class DesignateCenterHint extends StatelessWidget {
  const DesignateCenterHint({super.key});

  @override
  Widget build(BuildContext context) {
    final bool touch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return ExcludeSemantics(
      child: DecoratedBox(
        key: mapDesignateCenterHintKey,
        decoration: BoxDecoration(
          color: const Color(0xF0FFFFFF),
          border: Border.all(color: const Color(0xFFC9CFC4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            touch
                ? 'ou appui long sur n\'importe quel point'
                : 'ou clic droit sur n\'importe quel point de la carte',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF141A1F)),
          ),
        ),
      ),
    );
  }
}

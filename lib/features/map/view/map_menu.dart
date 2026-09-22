// Le menu de la carte (`W3b`, arbitrage du commanditaire du 2026-09-23) :
// remplace l'invariant « bandeau permanent, non repliable » de `W3` par un
// bandeau fermable pour la session ([MapWarningBanner.onDismiss]) que ce
// menu réaffiche. Un bouton d'icône (`Icons.menu`), posé en haut à droite de
// la carte au-dessus de [MapLegend] (`map_view.dart`, [buildMapOverlays]),
// ouvre un `MenuAnchor` (Flutter, zéro bibliothèque d'état) dont l'unique
// entrée en T1, « Avertissement », appelle [onShowBanner] — en production,
// `MapViewModel.showBanner`.
//
// [IconButton] et [MenuItemButton] plutôt que le couple `Semantics` +
// `GestureDetector` du reste de `features/map/view/` (bandeau, puces,
// marqueurs) : la seule exigence explicite de clavier de cette tâche
// (`04-ui.md § 3` : atteignable et activable au Tab, Entrée/Espace) est déjà
// portée par ces deux widgets Material — un `GestureDetector` ne répond à
// aucun événement clavier.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart'
    show stationMarkerTapTarget;

/// Clé du bouton de menu.
const Key mapMenuButtonKey = Key('map-menu-button');

/// Clé de l'entrée « Avertissement » du menu.
const Key mapMenuWarningItemKey = Key('map-menu-warning-item');

/// Fond du bouton de menu — même convention que [MapLegend] et
/// `IgnAttributionBadge` (`map_view.dart`) : un fond opaque, un texte ou une
/// icône posée directement sur un fond de carte quelconque ne tient aucun
/// contraste (`04-ui.md § 3`).
const Color _menuButtonBackground = Colors.white;

/// Le bouton de menu de la carte. [onShowBanner] est appelé quand
/// l'entrée « Avertissement » est activée — en production,
/// `MapViewModel.showBanner`. Requis, sans valeur par défaut : un menu sans
/// rappel serait mort à l'écran.
class MapMenuButton extends StatelessWidget {
  const MapMenuButton({required this.onShowBanner, super.key});

  final VoidCallback onShowBanner;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          key: mapMenuWarningItemKey,
          onPressed: onShowBanner,
          child: const Text(mapMenuWarningItemLabel),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            // Ouvre ou ferme le menu — partagé entre `IconButton.onPressed`
            // (toucher direct) et `Semantics.onTap` (lecteur d'écran) : sans
            // ce second câblage, `excludeSemantics` masque l'action de tap
            // portée par `IconButton`, et un double-tap au lecteur d'écran
            // n'ouvre plus rien, alors même que le rendu répond au toucher
            // direct (relecture du 2026-09-23).
            void toggle() {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            }

            // Le libellé d'accessibilité est posé explicitement — comme
            // partout ailleurs dans `features/map/view/` (puces, marqueurs,
            // actions du bandeau) — plutôt que via `IconButton.tooltip`, qui
            // pose un `Semantics.tooltip` et non un `Semantics.label`
            // (`tooltip.dart`, paquet Flutter installé) : seul un `label`
            // explicite est annoncé comme le nom du contrôle par un lecteur
            // d'écran. `excludeSemantics` masque le nœud par défaut
            // qu'`IconButton` poserait sinon en double, sans toucher à son
            // focus ni à son activation clavier — les deux vivent
            // indépendamment de l'arbre sémantique.
            return Semantics(
              key: mapMenuButtonKey,
              button: true,
              label: mapMenuLabel,
              excludeSemantics: true,
              onTap: toggle,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _menuButtonBackground,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: IconButton(
                  onPressed: toggle,
                  icon: const Icon(Icons.menu, color: Colors.black),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(
                      stationMarkerTapTarget,
                      stationMarkerTapTarget,
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }
}

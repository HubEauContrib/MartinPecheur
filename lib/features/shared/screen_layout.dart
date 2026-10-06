// Ce que partagent les écrans pleins de lecture (« Sécheresse et
// restrictions », « D'où vient cette donnée ? ») : la mesure de leur colonne
// de lecture et la molette posée hors du défilement. Une seule définition de
// chaque, importée par les deux tranches qui s'en servent.
//
// Occupant de `lib/features/shared/` : il n'importe aucune tranche
// (`shared-sans-tranche`, `test/architecture/layers_test.dart`).

import 'package:flutter/gestures.dart'
    show GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

/// Largeur de la colonne de lecture (contenu, hors remplissage) : au-delà,
/// le texte reste en colonne centrée plutôt que de courir sur toute la
/// fenêtre.
const double readingColumnWidth = 760;

/// Remplissage latéral de la colonne de lecture.
const double readingColumnGutter = 16;

/// Fait défiler l'écran à la molette posée HORS du défilement (barre de
/// titre, tête épinglée) : sans lui, c'est une bande morte sous le bord haut
/// de la fenêtre (constat du 2026-09-29, écran des restrictions). Au-dessus
/// du défilement, c'est lui qui prend l'événement : il s'inscrit le premier
/// auprès du `pointerSignalResolver`, et seule la première inscription est
/// servie.
///
/// Défile le défilement PRIMAIRE de la route : l'écran qui l'emploie pose
/// `primary: true` sur son `SingleChildScrollView`.
class WheelScrollsScreen extends StatelessWidget {
  const WheelScrollsScreen({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is! PointerScrollEvent) {
          return;
        }
        final ScrollController? controller = PrimaryScrollController.maybeOf(
          context,
        );
        if (controller == null || controller.positions.length != 1) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (
          PointerSignalEvent resolved,
        ) {
          if (resolved is PointerScrollEvent &&
              controller.positions.length == 1) {
            controller.position.pointerScroll(resolved.scrollDelta.dy);
          }
        });
      },
      child: child,
    );
  }
}

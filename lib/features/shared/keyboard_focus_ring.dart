// Le focus clavier visible, partagé (`K2`, 2026-09-23) : « le focus est
// toujours visible » (`04-ui.md § 3`) et « tout ce qui se fait à la souris se
// fait au clavier ». Avant ce fichier, chaque contrôle de la carte (puces
// d'échelle, boutons de zoom, contrôle d'avertissement) n'avait qu'un `onTap`
// — aucun n'était focalisable ni activable à Entrée/Espace, et aucun ne
// montrait son focus autrement que par le halo implicite, non testable,
// qu'`InkWell` dessine tout seul.
//
// Troisième occupant de `lib/features/shared/` (après `tap_target.dart` et
// `warning_link.dart`) : la seule tranche que `features/map/` peut importer
// sans en importer une autre (`test/architecture/layers_test.dart`, règle
// `shared-sans-tranche`).
//
// Une SEULE décoration de focus pour tout l'écran, jamais recopiée par
// contrôle : un contour de [focusRingWidth], dans [focusRingColor],
// visible dès que le [FocusNode] porté gagne le focus — au clavier (Tab)
// comme par tout autre moyen de focalisation (ex. un lecteur d'écran).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Épaisseur du contour de focus, en pixels logiques.
const double focusRingWidth = 3;

/// Couleur du contour de focus — un bleu suffisamment contrasté sur le fond
/// blanc des contrôles de la carte, distinct des teintes d'état de l'eau
/// (`04-ui.md § 2`, qui ne régit que ces teintes-là).
const Color focusRingColor = Color(0xFF1565C0);

/// Rend [child] focalisable et activable au clavier : Entrée, `NumpadEnter`
/// et Espace appellent [onActivate] — exactement ce qu'un tap ferait — et un
/// contour apparaît dès que le focus arrive dessus.
///
/// [onActivate] `null` : le contrôle reste focalisable (par ex. pour annoncer
/// son état désactivé) mais aucune touche ne déclenche rien.
///
/// [canRequestFocus] `false` : retire le contrôle de l'ordre de tabulation —
/// utilisé pour un bouton de zoom déjà désactivé (`MapViewModel.canZoomIn`/
/// `canZoomOut`), qu'aucune touche ne doit pouvoir atteindre.
///
/// ⚠️ Ni `focusNode` ni `skipTraversal` (relecture du commanditaire du
/// 2026-09-23, 🟢 5, YAGNI) : aucun appelant ne les utilise — la carte
/// (`K2`) réutilise directement le `FocusNode` interne de `flutter_map`
/// (`map_view.dart`, `_mapOptions`), jamais ce widget. Les retirer avec leur
/// `didUpdateWidget` plutôt que de garder un paramètre mort.
class KeyboardFocusRing extends StatefulWidget {
  const KeyboardFocusRing({
    required this.child,
    this.onActivate,
    this.canRequestFocus = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final bool canRequestFocus;

  @override
  State<KeyboardFocusRing> createState() => _KeyboardFocusRingState();
}

class _KeyboardFocusRingState extends State<KeyboardFocusRing> {
  final FocusNode _node = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final VoidCallback? activate = widget.onActivate;
    if (activate == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final bool isActivationKey =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (!isActivationKey) {
      return KeyEventResult.ignored;
    }
    activate();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      canRequestFocus: widget.canRequestFocus,
      // `includeSemantics: false` : sans lui, `Focus` insère son PROPRE
      // nœud `Semantics` (focalisable) entre l'appelant et [child] — un
      // second nœud, non annoncé nulle part, mais qui casse tout parcours
      // « le plus proche ancêtre `Semantics` » depuis un descendant (relu
      // par les tests existants de `map_view_test.dart`, qui cherchent le
      // `Semantics` explicite posé par l'appelant, PAS celui-ci). L'appelant
      // porte déjà sa propre annonce ; ce widget n'a rien à ajouter au
      // lecteur d'écran.
      includeSemantics: false,
      onFocusChange: (bool hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: _handleKeyEvent,
      child: DecoratedBox(
        // `position: DecorationPosition.foreground` (relecture du
        // commanditaire du 2026-09-23, 🔴 2) : par défaut, `DecoratedBox`
        // peint sa décoration EN ARRIÈRE-PLAN de [child] — un fond plein
        // (une puce sélectionnée, un bouton, une tuile de carte) le
        // recouvre alors entièrement, rendant le contour invisible malgré
        // `_focused` vrai. En premier plan, il se peint PAR-DESSUS.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: _focused ? focusRingColor : Colors.transparent,
            width: focusRingWidth,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

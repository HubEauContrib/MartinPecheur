// La section « Me prévenir des restrictions sécheresse » des fiches station et
// ONDE (`W1` de T5, `BR-016`) : l'interrupteur, sa règle, la phrase d'un
// échec d'écriture, puis l'avertissement de suivi en entier.
//
// Même construction que `FavoriteStarButton` : `Semantics` en racine,
// `KeyboardFocusRing` dessous, `InkWell` sans focus propre. Inactif, il garde
// sa forme atténuée et RESTE dans l'ordre de tabulation (le focus ne doit pas
// se perdre pendant une écriture) ; il n'appelle simplement pas `onToggle`.
//
// Aucune tranche importée (`shared-sans-tranche`).

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/shared/follow_up_toggle.dart';
import 'package:martinpecheur/features/shared/follow_up_warning_card.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Libellé de l'interrupteur (cadrage de T5, § 11.2).
const String droughtFollowUpLabel = 'Me prévenir des restrictions sécheresse';

/// Règle du réglage (cadrage de T5, § 11.2).
const String droughtFollowUpRule =
    "Un avis quand la gravité d'une zone d'alerte change à cet endroit, "
    "d'après $restrictionsSourceName.";

/// Posée sur la rangée de l'interrupteur : c'est elle que les tests mesurent.
const Key droughtFollowUpSwitchKey = Key('drought-follow-up-switch');

/// Opacité de l'interrupteur inactif : la forme reste lisible.
const double _disabledOpacity = 0.4;

class DroughtFollowUpSection extends StatelessWidget {
  const DroughtFollowUpSection({
    required this.toggle,
    required this.onToggle,
    super.key,
  });

  final FollowUpToggle toggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? activate = toggle.enabled ? onToggle : null;
    final double size = minimumTapTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          key: droughtFollowUpSwitchKey,
          toggled: toggle.on,
          enabled: toggle.enabled,
          label: droughtFollowUpLabel,
          // Sans ce rappel, `excludeSemantics` masque l'action de tap
          // qu'`InkWell` porterait sinon.
          onTap: activate,
          excludeSemantics: true,
          child: KeyboardFocusRing(
            onActivate: activate,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: activate,
                // `KeyboardFocusRing` porte déjà le focus : un second
                // `FocusNode` ferait de la rangée DEUX arrêts de tabulation.
                canRequestFocus: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size, minWidth: size),
                  child: Opacity(
                    opacity: toggle.enabled ? 1 : _disabledOpacity,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              droughtFollowUpLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ExcludeFocus(
                          child: IgnorePointer(
                            child: Switch(
                              value: toggle.on,
                              onChanged: (bool _) {},
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
        const SizedBox(height: 4),
        const Text(droughtFollowUpRule),
        if (toggle.writeFailed) ...<Widget>[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: const Text(followUpWriteFailedText),
          ),
        ],
        const SizedBox(height: 8),
        const FollowUpWarningCard(),
      ],
    );
  }
}

// Le contrôle d'avertissement partagé (`W3c`, arbitrage du commanditaire du
// 2026-09-23 : « trop de bandeaux à l'écran ») — deuxième occupant de
// `lib/features/shared/` (le premier, l'ancien encart daté de tête de fiche,
// disparaît avec ce même arbitrage) : la seule tranche que `features/map/`,
// `station_sheet` et `onde_sheet` peuvent toutes trois importer sans se voir
// l'une l'autre (`test/architecture/layers_test.dart`, règle
// `shared-sans-tranche`).
//
// Il remplace TROIS éléments d'un coup, tous retirés :
// - le bandeau permanent de la carte (`W3`) et son menu de réaffichage
//   (`W3b`), sous `lib/features/map/view/` ;
// - l'encart daté de tête de fiche (`W4`), sous `lib/features/shared/`.
//
// [WarningLink] est un simple lien (icône + libellé, [warningLinkLabel])
// qui ouvre [WarningWindow] EN LECTURE SEULE : le texte général du modal
// initial ([initialWarningTitle], [initialWarningBody]), complété — QUAND
// [extraText] est fourni — par la phrase propre à l'écran qui l'affiche,
// SOUS le texte général. Sans [extraText] (une fiche sans mesure ni
// campagne), la fenêtre n'a que le texte général : « sans date, aucun
// encart » (arbitrage du 2026-09-23) — la phrase datée ne s'invente pas.
//
// ⚠️ [WarningLink] ne CALCULE aucune phrase : c'est l'appelant qui construit
// [extraText] avec [sheetWarningText], quand il a une date à donner. Ce
// widget ne connaît donc ni [SheetWarningKind] ni aucune date — il reste
// utilisable tel quel par la carte, qui n'a ni l'un ni l'autre.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

// L'alias local que ce fichier portait (`K1`) est retiré (YAGNI, relecture
// du coordinateur du 2026-09-23) : ce fichier lit directement
// [minimumTapTarget] (`lib/features/shared/tap_target.dart`) — un import
// entre deux fichiers de `features/shared/` reste permis
// (`layers_test.dart`, règle `shared-sans-tranche`).

/// Clé du contrôle lui-même.
const Key warningLinkKey = Key('warning-link');

/// Clé de la région d'alerte que forme la fenêtre.
const Key warningWindowRegionKey = Key('warning-window-region');

/// Clé du bouton de fermeture de la fenêtre.
const Key warningWindowCloseButtonKey = Key('warning-window-close');

/// Clé du texte propre à l'écran, quand [WarningLink.extraText] est fourni.
const Key warningWindowExtraTextKey = Key('warning-window-extra-text');

/// Le contrôle d'avertissement (`W3c`) : une icône et [warningLinkLabel],
/// cible tactile ≥ 44 pt, atteignable et activable au clavier (Tab puis
/// Entrée/Espace — porté par [InkWell], comme l'était le bouton « Fermer »
/// du bandeau retiré). Le tap ouvre [WarningWindow] avec [extraText].
class WarningLink extends StatelessWidget {
  const WarningLink({this.extraText, super.key});

  /// La phrase propre à l'écran qui affiche ce contrôle (par exemple
  /// [sheetWarningText] pour une fiche), affichée SOUS le texte général de
  /// [WarningWindow]. `null` quand l'écran n'a pas de date à donner (la
  /// carte, ou une fiche sans mesure ni campagne) : la fenêtre s'ouvre alors
  /// sans phrase propre, jamais une phrase inventée.
  final String? extraText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: warningLinkKey,
      button: true,
      label: warningLinkLabel,
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud — même choix que les contrôles
      // similaires de `features/map/view/`.
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que
      // `InkWell` porterait sinon lui-même : un double-tap au lecteur
      // d'écran n'ouvrirait plus rien (même relecture que les contrôles
      // retirés par `W3c`).
      onTap: () => _open(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _open(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minimumTapTarget,
              minHeight: minimumTapTarget,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded),
                  SizedBox(width: 4),
                  Text(
                    warningLinkLabel,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => WarningWindow(extraText: extraText),
    );
  }
}

/// La fenêtre d'avertissement, EN LECTURE SEULE — aucune case, aucun bouton
/// d'acquittement, seulement une fermeture ([warningReviewCloseLabel]) :
/// même principe que l'ancienne `WarningReviewSheet` (`W3`), qui redonnait à
/// relire le texte déjà acquitté du modal initial sans redemander de choix.
///
/// [extraText], quand il est fourni, est rendu SOUS [initialWarningBody] :
/// c'est la phrase propre à l'écran qui a ouvert cette fenêtre — jamais un
/// texte nouveau, jamais recalculé ici.
class WarningWindow extends StatelessWidget {
  const WarningWindow({this.extraText, super.key});

  /// La phrase propre à l'écran appelant, ou `null` sans date à donner.
  final String? extraText;

  @override
  Widget build(BuildContext context) {
    final String? extra = extraText;
    return Dialog(
      child: SafeArea(
        child: Semantics(
          key: warningWindowRegionKey,
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
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(extra, key: warningWindowExtraTextKey),
                ],
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
      ),
    );
  }
}

/// Le bouton de fermeture de la fenêtre ([warningReviewCloseLabel]).
///
/// [Material] + [InkWell] plutôt que le `GestureDetector` nu employé avant
/// la relecture du 2026-09-23 : un `GestureDetector` ne répond à AUCUN
/// événement clavier, et « Fermer » doit être atteignable au Tab et
/// activable à Entrée/Espace (`04-ui.md § 3`) — même construction que
/// [WarningLink] lui-même. `Material(type: transparency)` n'ajoute aucun
/// fond, seulement l'ancêtre `Material` qu'`InkWell` exige.
class _CloseAction extends StatelessWidget {
  const _CloseAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: warningWindowCloseButtonKey,
      button: true,
      label: warningReviewCloseLabel,
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que
      // `InkWell` porterait sinon lui-même : un double-tap au lecteur
      // d'écran n'activerait plus rien (même relecture que les contrôles
      // retirés).
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minimumTapTarget,
              minHeight: minimumTapTarget,
            ),
            child: const Center(child: Text(warningReviewCloseLabel)),
          ),
        ),
      ),
    );
  }
}

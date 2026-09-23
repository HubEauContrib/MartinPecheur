// La vue de l'écran bloquant du premier lancement (MVVM, ADR-014, tâche
// `W2`) : observe `WarningsViewModel` et n'écrit AUCUN texte en dur — tout
// vient de `lib/domain/warnings/warning_texts.dart` (`BR-012`, `BR-014`).
//
// ⚠️ Cette tranche n'importe aucune autre tranche
// (`test/architecture/layers_test.dart`, règle `feature-vers-feature`), mais
// `features/shared/` lui reste ouverte (règle `shared-sans-tranche`) : la
// cible tactile de 44 pt (`04-ui.md § 3`) vient donc de [minimumTapTarget]
// (`K1`, `lib/features/shared/tap_target.dart`), plus recopiée localement
// depuis la révision qui a posé cette constante unique.
//
// Le corps défile (`SingleChildScrollView`) : à 200 % de police, le texte
// n'est jamais tronqué (`UC-006 A4`). L'écran entier est une région
// d'alerte (`Semantics(liveRegion: true)`) : c'est l'équivalent le plus
// proche qu'offre le paquet `flutter` installé (3.47.4) d'un rôle `alert`
// explicite, qui n'existe pas dans son API de sémantique (04-ui.md § 3,
// « zone active »).
//
// Le bouton reste désactivé (`onPressed: null`) tant que la case n'est pas
// cochée, sans pré-cochage (`BR-012`) — `ElevatedButton` porte alors
// lui-même le flag sémantique « désactivé », sans code supplémentaire ici.
//
// ⚠️ Aucun callback `onAcknowledged` (YAGNI, CLAUDE.md) : la bascule vers la
// carte est déjà assurée par le `ListenableBuilder` de `main.dart` sur
// `WarningsViewModel.requiresAcknowledgement` — un paramètre qui ne ferait
// que dupliquer cette réaction serait un paramètre inutilisé.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';

/// Clé de la région d'alerte que forme l'écran entier — c'est sur ce
/// `Semantics` que les tests vérifient `SemanticsFlag.isLiveRegion`.
const Key initialWarningRegionKey = Key('initial-warning-region');

/// Clé de la case à cocher de l'écran (`UC-006 § 2`, étape 4).
const Key initialWarningCheckboxKey = Key('initial-warning-checkbox');

/// Clé du bouton d'acquittement (`UC-006 § 2`, étapes 3 et 5).
const Key initialWarningButtonKey = Key('initial-warning-button');

/// Clé de la phrase d'échec d'enregistrement, affichée sous le bouton
/// (`UC-006 A6`, arbitrage du commanditaire du 2026-09-22).
const Key initialWarningWriteFailedKey = Key('initial-warning-write-failed');

/// L'écran bloquant du premier lancement (`UC-006`, `BR-012`) : aucune
/// fonctionnalité de l'application n'est atteignable tant qu'il est monté —
/// c'est la racine de composition (`main.dart`) qui garantit cela, en ne
/// construisant JAMAIS la carte tant que
/// `WarningsViewModel.requiresAcknowledgement` est vrai.
final class InitialWarningView extends StatelessWidget {
  const InitialWarningView({required this.viewModel, super.key});

  /// Le ViewModel de l'écran, possédé par la racine de composition — cette
  /// vue ne le construit ni ne le détruit (ADR-014).
  final WarningsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: SafeArea(
            child: Semantics(
              key: initialWarningRegionKey,
              container: true,
              liveRegion: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      initialWarningTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(initialWarningBody),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () =>
                          viewModel.toggleCheckbox(!viewModel.checkboxChecked),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: minimumTapTarget,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Checkbox(
                              key: initialWarningCheckboxKey,
                              value: viewModel.checkboxChecked,
                              onChanged: (bool? value) =>
                                  viewModel.toggleCheckbox(value ?? false),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(initialWarningCheckboxLabel),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: initialWarningButtonKey,
                        onPressed: viewModel.canAcknowledge
                            ? () {
                                unawaited(viewModel.acknowledge());
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(minimumTapTarget),
                        ),
                        child: const Text(initialWarningButtonLabel),
                      ),
                    ),
                    if (viewModel.error != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Semantics(
                        key: initialWarningWriteFailedKey,
                        container: true,
                        liveRegion: true,
                        child: const Text(initialWarningWriteFailedText),
                      ),
                    ],
                    // Le lien « Relire le détail des sources » (`04-ui.md
                    // § 1`) est RETIRÉ ici : arbitrage du commanditaire du
                    // 2026-09-22, `BR-012` reste satisfait sans lui — il
                    // reviendra avec l'écran « D'où vient cette donnée ? ».
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Horloge simulée pour les tests de délai d'attente et de rejeu HTTP : les
// minuteurs NON PÉRIODIQUES créés dans sa zone (`Timer`, `Future.delayed`,
// `Future.timeout`) ne tournent JAMAIS en temps réel, ils suivent un temps que
// le test fait avancer. Un délai de 20 s se vérifie donc à la milliseconde
// près, en quelques millisecondes réelles, sans minuteur réel qui dorme ni
// course entre deux durées voisines. `Timer.periodic` n'est PAS simulé (seul
// `createTimer` est intercepté, un minuteur périodique reste réel) : le
// transport HTTP n'en crée aucun.
//
// Pourquoi pas `fakeAsync` : `package:fake_async` n'est pas une dépendance
// déclarée du projet (`pubspec.yaml`), et `flutter_test` ne le ré-exporte pas.
// Il est bien résolu en 1.3.3 dans `pubspec.lock`, mais en transitif (lu le
// 2026-10-06) : l'importer demanderait de l'ajouter à `dev_dependencies`.
// `testWidgets` avec `tester.pump(durée)` simule aussi le temps sans nouvelle
// dépendance, mais, d'après le relecteur (non vérifié ici), son binding pose
// un `HttpOverrides` global qui gênerait le groupe du vrai `IOClient` de
// `test/data/http/json_http_client_test.dart`. Mécanisme retenu : celui de
// `_espionnerMinuteurs` de ce même fichier de test — une `ZoneSpecification.
// createTimer` —, mais ici le minuteur n'est jamais armé pour de vrai.
//
// Usage : créer la tentative DANS [SimulatedClock.run] (c'est là que ses
// minuteurs sont captés), puis appeler [SimulatedClock.advance] DEPUIS le corps
// du test, hors de la zone simulée.
import 'dart:async';

/// Horloge simulée. Le temps ne s'écoule que par [advance].
final class SimulatedClock {
  Duration _now = Duration.zero;
  final List<_SimulatedTimer> _timers = <_SimulatedTimer>[];

  /// Temps simulé écoulé depuis la création de l'horloge. Lu depuis un
  /// rappel qui s'exécute au déclenchement d'un minuteur, il vaut l'instant
  /// EXACT de ce déclenchement.
  Duration get elapsed => _now;

  /// Exécute [body] dans une zone dont les minuteurs suivent cette horloge.
  T run<T>(T Function() body) {
    return runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        createTimer:
            (
              Zone self,
              ZoneDelegate parent,
              Zone zone,
              Duration duration,
              void Function() action,
            ) {
              final _SimulatedTimer timer = _SimulatedTimer(
                due: _now + (duration.isNegative ? Duration.zero : duration),
                action: action,
              );
              _timers.add(timer);
              return timer;
            },
      ),
    );
  }

  /// Fait avancer le temps de [duration], en déclenchant dans l'ordre de leur
  /// échéance les minuteurs échus (à échéance égale, dans l'ordre de leur
  /// création), et en laissant s'exécuter entre deux déclenchements tout ce
  /// que chacun met en mouvement. À appeler hors de la zone de [run].
  Future<void> advance(Duration duration) async {
    final Duration target = _now + duration;
    await _letMicrotasksRun();
    while (true) {
      _SimulatedTimer? next;
      for (final _SimulatedTimer timer in _timers) {
        if (timer.isActive &&
            timer.due <= target &&
            (next == null || timer.due < next.due)) {
          next = timer;
        }
      }
      if (next == null) {
        break;
      }
      if (next.due > _now) {
        _now = next.due;
      }
      _timers.remove(next);
      next.fire();
      await _letMicrotasksRun();
    }
    _now = target;
    await _letMicrotasksRun();
  }

  /// Un tour de boucle d'événements RÉEL (le minuteur est créé dans la zone
  /// racine, quelle que soit la zone de l'appelant) : toute la file de
  /// microtâches se vide avant lui.
  Future<void> _letMicrotasksRun() {
    final Completer<void> turn = Completer<void>();
    Zone.root.createTimer(Duration.zero, turn.complete);
    return turn.future;
  }
}

final class _SimulatedTimer implements Timer {
  _SimulatedTimer({required this.due, required this._action});

  final Duration due;
  final void Function() _action;
  bool _active = true;
  int _tick = 0;

  void fire() {
    _active = false;
    _tick++;
    _action();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }
}

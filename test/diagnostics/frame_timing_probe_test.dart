// Task X3 (`NFR-01`) : les cas de test portent sur le CALCUL, pas sur le
// rendu (plan `2026-09-13-t1-fiche-station-et-avertissements.md`, § Task
// X3). `FrameTimingProbe` reçoit ses fonctions d'enregistrement/retrait par
// injection — même style que `CachedHydroObservationRepository` injecte
// `_now` — pour rester testable sans lever un vrai `TestWidgetsFlutterBinding`
// ni de vraies trames Flutter : un couple de registres factices capture le
// rappel et le rejoue à la main avec des `FrameTiming` synthétiques
// (constructeur public, prévu pour les tests par la doc du SDK).
import 'package:flutter/scheduler.dart' show FrameTiming, TimingsCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/diagnostics/frame_timing_probe.dart';

/// Un `FrameTiming` synthétique dont le seul champ qui compte, par défaut,
/// est `rasterDuration` : `rasterFinish - rasterStart` vaut [raster] micros.
/// Relecture du 2026-09-23 (🟠 2, 🟠 5) : [build] fixe `buildDuration`
/// (`buildFinish - buildStart`), et [gapBeforeRaster] simule le délai entre
/// la fin de la construction et le début de la rastérisation — c'est LUI
/// qui rend `totalSpan` (vsync → raster fini) différent de `rasterDuration`
/// seul, sans quoi `buildStart == rasterStart == 0` les confondrait
/// toujours et aucun test ne pourrait distinguer les deux.
FrameTiming _timing(
  Duration raster, {
  Duration build = Duration.zero,
  Duration gapBeforeRaster = Duration.zero,
}) {
  final int buildFinish = build.inMicroseconds;
  final int rasterStart = buildFinish + gapBeforeRaster.inMicroseconds;
  final int rasterFinish = rasterStart + raster.inMicroseconds;
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
  );
}

/// Un registre factice : `add` capture le dernier rappel enregistré et
/// compte ses appels ([addCallCount]) — c'est ce compte que verrouille le
/// test du 🟢 6 (un second `start()` ne doit PAS enregistrer un second
/// rappel). `remove` ne l'efface PAS — c'est le test qui décide de rejouer
/// ou non le rappel capturé après un `stop()`, pour vérifier que la sonde
/// elle-même ignore ce qu'elle reçoit hors service, indépendamment de ce
/// que ferait un vrai `SchedulerBinding`.
final class _FakeRegistry {
  TimingsCallback? captured;
  int addCallCount = 0;

  void add(TimingsCallback callback) {
    captured = callback;
    addCallCount++;
  }

  void remove(TimingsCallback callback) {}
}

void main() {
  group('percentile', () {
    test('sur [1, 2, …, 100] ms, p50 vaut 50 ms et p90 vaut 90 ms', () {
      final List<Duration> samples = List<Duration>.generate(
        100,
        (int i) => Duration(milliseconds: i + 1),
      );

      expect(percentile(samples, 0.5), const Duration(milliseconds: 50));
      expect(percentile(samples, 0.9), const Duration(milliseconds: 90));
    });

    test('sur une liste d\'un seul élément, rend cet élément', () {
      const Duration unique = Duration(milliseconds: 7);
      expect(percentile(<Duration>[unique], 0.5), unique);
      expect(percentile(<Duration>[unique], 0.9), unique);
    });

    test('sur une liste vide, lève ArgumentError', () {
      expect(() => percentile(<Duration>[], 0.5), throwsArgumentError);
    });
  });

  group('lateFramePercent', () {
    test('sur 100 trames dont 9 dépassent 16,7 ms, rend 9,0', () {
      final List<Duration> samples = <Duration>[
        for (int i = 0; i < 91; i++) const Duration(milliseconds: 10),
        for (int i = 0; i < 9; i++) const Duration(milliseconds: 20),
      ];

      expect(lateFramePercent(samples), 9.0);
    });

    test('sur 100 trames dont 0 dépasse 16,7 ms, rend 0,0', () {
      final List<Duration> samples = List<Duration>.filled(
        100,
        const Duration(milliseconds: 10),
      );

      expect(lateFramePercent(samples), 0.0);
    });

    group('la frontière du seuil (16 700 µs, opérateur `>` strict — même '
        "opérateur que le spike, `frame_stats.dart`, `jankCount`)", () {
      test('16 699 µs (sous le budget) n\'est pas en retard', () {
        expect(
          lateFramePercent(<Duration>[const Duration(microseconds: 16699)]),
          0.0,
        );
      });

      test('16 700 µs (EXACTEMENT le budget) n\'est PAS en retard — `>`, '
          'jamais `>=`', () {
        expect(
          lateFramePercent(<Duration>[frameBudget]),
          0.0,
          reason:
              'une mutation `>` → `>=` ferait basculer ce cas a 100,0 : '
              "c'est exactement ce que ce test verrouille",
        );
      });

      test('16 701 µs (une seule microseconde au-delà) EST en retard', () {
        expect(
          lateFramePercent(<Duration>[const Duration(microseconds: 16701)]),
          100.0,
        );
      });
    });
  });

  group('FrameTimingProbe', () {
    test('report() avant tout start() rend frameCount 0, jamais une '
        'division par zéro', () {
      final _FakeRegistry registry = _FakeRegistry();
      final FrameTimingProbe probe = FrameTimingProbe(
        addTimingsCallback: registry.add,
        removeTimingsCallback: registry.remove,
      );

      final FrameTimingReport report = probe.report();

      expect(report.frameCount, 0);
      expect(report.rasterP50, Duration.zero);
      expect(report.rasterP90, Duration.zero);
      expect(report.lateFramePercent, 0.0);
      expect(report.buildP90, Duration.zero);
      expect(report.lateFramePercentTotal, 0.0);
    });

    test('start() enregistre les trames publiées à partir du DEUXIÈME lot, '
        'report() calcule les percentiles dessus', () {
      final _FakeRegistry registry = _FakeRegistry();
      final FrameTimingProbe probe = FrameTimingProbe(
        addTimingsCallback: registry.add,
        removeTimingsCallback: registry.remove,
      );

      probe.start();
      // Premier lot : ignoré (contre-relecture du 2026-09-23) — voir le
      // groupe dédié plus bas pour le test qui verrouille précisément ce
      // point avec une mutation.
      registry.captured!(<FrameTiming>[
        _timing(const Duration(milliseconds: 1)),
      ]);
      registry.captured!(<FrameTiming>[
        _timing(const Duration(milliseconds: 10)),
        _timing(const Duration(milliseconds: 20)),
      ]);

      final FrameTimingReport report = probe.report();

      expect(report.frameCount, 2);
      expect(report.lateFramePercent, 50.0);
    });

    test('la sonde n\'enregistre rien entre stop() et le start() suivant', () {
      final _FakeRegistry registry = _FakeRegistry();
      final FrameTimingProbe probe = FrameTimingProbe(
        addTimingsCallback: registry.add,
        removeTimingsCallback: registry.remove,
      );

      probe.start();
      // Premier lot après start() : ignoré (contre-relecture du
      // 2026-09-23) — celui-ci sert donc uniquement à consommer cette
      // règle, le second est le lot qui compte vraiment pour CE test.
      registry.captured!(<FrameTiming>[
        _timing(const Duration(milliseconds: 1)),
      ]);
      registry.captured!(<FrameTiming>[
        _timing(const Duration(milliseconds: 5)),
      ]);
      probe.stop();
      // Rejoué APRÈS stop() : un vrai SchedulerBinding ne le ferait plus,
      // mais la sonde elle-même doit ignorer ce qu'elle reçoit hors
      // service — la garde est dans `FrameTimingProbe`, pas seulement dans
      // le retrait du rappel.
      registry.captured!(<FrameTiming>[
        _timing(const Duration(milliseconds: 999)),
      ]);

      expect(probe.report().frameCount, 1);

      probe.start();
      final FrameTimingReport report = probe.report();
      expect(
        report.frameCount,
        0,
        reason:
            'start() repart sur un relevé vide, il ne cumule pas avec '
            'le geste précédent',
      );
    });

    group('premier lot après start() ignoré (contre-relecture du '
        '2026-09-23)', () {
      test('un premier lot de trames LENTES suivi d\'un lot de trames '
          'RAPIDES : le rapport ne compte que le second', () {
        final _FakeRegistry registry = _FakeRegistry();
        final FrameTimingProbe probe = FrameTimingProbe(
          addTimingsCallback: registry.add,
          removeTimingsCallback: registry.remove,
        );

        probe.start();
        // Premier lot : des trames TRÈS lentes (l'InkRipple du bouton, le
        // clic lui-même) — si la sonde les comptait, rasterP90 serait à
        // 200 ms et 100 % en retard.
        registry.captured!(
          List<FrameTiming>.generate(
            5,
            (_) => _timing(const Duration(milliseconds: 200)),
          ),
        );
        // Second lot : le vrai geste, rapide.
        registry.captured!(
          List<FrameTiming>.generate(
            5,
            (_) => _timing(const Duration(milliseconds: 5)),
          ),
        );

        final FrameTimingReport report = probe.report();

        expect(
          report.frameCount,
          5,
          reason: 'le premier lot (5 trames lentes) ne doit PAS compter',
        );
        expect(
          report.rasterP90,
          const Duration(milliseconds: 5),
          reason:
              'une mutation « premier lot compté » ferait remonter ce '
              'chiffre à 200 ms',
        );
        expect(report.lateFramePercent, 0.0);
      });
    });

    test('un second start() PENDANT un geste en cours n\'enregistre PAS un '
        'second rappel (🟢 6)', () {
      final _FakeRegistry registry = _FakeRegistry();
      final FrameTimingProbe probe = FrameTimingProbe(
        addTimingsCallback: registry.add,
        removeTimingsCallback: registry.remove,
      );

      probe.start();
      probe.start();
      probe.start();

      expect(
        registry.addCallCount,
        1,
        reason:
            'trois start() successifs, sans stop() entre eux, ne doivent '
            'enregistrer le rappel qu\'UNE fois',
      );
    });

    group('buildP90 et lateFramePercentTotal (🟠 2, informatifs — ne '
        'changent AUCUN seuil de NFR-01)', () {
      test('buildP90 et lateFramePercentTotal se calculent sur des '
          'échantillons DISTINCTS de rasterP90/lateFramePercent : un délai '
          'entre build et raster (file d\'attente) fait dépasser le budget '
          'en totalSpan sans que la seule rastérisation ne le dépasse', () {
        final _FakeRegistry registry = _FakeRegistry();
        final FrameTimingProbe probe = FrameTimingProbe(
          addTimingsCallback: registry.add,
          removeTimingsCallback: registry.remove,
        );

        probe.start();
        // Premier lot après start() : ignoré (contre-relecture du
        // 2026-09-23) — sans lui, ce test resterait valide pour la même
        // raison que les deux tests précédents.
        registry.captured!(<FrameTiming>[
          _timing(const Duration(milliseconds: 1)),
        ]);
        // Dix trames identiques : 5 ms de construction, 30 ms d'attente
        // avant la rastérisation (le coût qu'un rechargement par cran de
        // molette, NV-W6, pourrait ajouter), puis 10 ms de rastérisation —
        // largement DANS le budget de NFR-01 (16,7 ms), mais dont le
        // totalSpan (45 ms) le dépasse largement.
        registry.captured!(
          List<FrameTiming>.generate(
            10,
            (_) => _timing(
              const Duration(milliseconds: 10),
              build: const Duration(milliseconds: 5),
              gapBeforeRaster: const Duration(milliseconds: 30),
            ),
          ),
        );

        final FrameTimingReport report = probe.report();

        // Le VERDICT de NFR-01 reste au vert : la rastérisation seule tient
        // le budget.
        expect(report.rasterP90, const Duration(milliseconds: 10));
        expect(report.lateFramePercent, 0.0);

        // Les chiffres INFORMATIFS, eux, montrent le coût caché.
        expect(report.buildP90, const Duration(milliseconds: 5));
        expect(
          report.lateFramePercentTotal,
          100.0,
          reason:
              'totalSpan = 5 + 30 + 10 = 45 ms, largement au-delà de '
              '16,7 ms — une mutation `rasterDuration` → `totalSpan` (ou '
              "l'inverse) sur l'un des deux champs ferait échouer CE test",
        );
      });
    });
  });

  group('drapeau --dart-define=FLUIDITY_PROBE=true', () {
    test('sans le drapeau, la sonde est désactivée par défaut — c\'est ce '
        'que teste ce fichier de test lui-même, lancé sans '
        '--dart-define', () {
      expect(fluidityProbeEnabled, isFalse);
    });
  });
}

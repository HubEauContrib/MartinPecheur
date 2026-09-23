// Task X3 (`NFR-01`) : la première mesure de fluidité de la carte sur
// Windows. La méthode reprend celle du spike (`spike/porte_flutter/lib/
// frame_recorder.dart`, commit `d361146`) — `SchedulerBinding.
// addTimingsCallback` accumule les `FrameTiming` publiées pendant un geste
// défini d'avance, puis les percentiles sont calculés sur les durées de
// rastérisation — sans en reprendre le code : ce fichier ajoute
// l'injection des fonctions d'enregistrement/retrait (même style que
// `CachedHydroObservationRepository` injecte `_now`), pour rester testable
// sans lever un `TestWidgetsFlutterBinding`.
//
// Relecture du 2026-09-23 : deux chiffres INFORMATIFS s'ajoutent au rapport
// (🟠 2) — `buildP90` (percentile 90 de la durée de CONSTRUCTION, sur le
// thread UI) et `lateFramePercentTotal` (trames en retard sur `totalSpan`,
// vsync→raster fini, comparé au MÊME budget que le raster). Aucun des deux
// n'entre dans le verdict de `NFR-01`, qui reste UNIQUEMENT sur le raster
// (`rasterP90`/`lateFramePercent`) — ces deux seuils ne bougent pas. Le but
// est de rendre visible le coût d'un rechargement par cran de molette
// (`NV-W6`) même quand il ne fait pas déborder le budget de rastérisation
// seul.
//
// CONTRE-RELECTURE du même jour : le protocole affiché par le panneau
// (« Démarrer, attendre 1 s, faire le geste, attendre 1 s, Arrêter ») laisse
// s'écouler une seconde avant le geste — mais `SchedulerBinding` publie ses
// `FrameTiming` par LOTS d'environ 100 ms, pas trame par trame. Le PREMIER
// lot reçu après `start()` peut donc encore contenir des trames d'AVANT le
// geste (le clic sur « Démarrer » lui-même, son survol). Combiné à
// l'`InkRipple` d'un bouton par défaut (~675 ms sous Windows), ce premier
// lot dilue le geste mesuré d'environ 50 à 60 trames rapides sur ~600 —
// une dilution d'environ 9 % qui peut faire passer 5,4 % de trames en
// retard SOUS le seuil de 5 % de `NFR-01` (calcul du coordinateur,
// relecture du 2026-09-23) : un FAUX VERT. [FrameTimingProbe] ignore donc
// ELLE-MÊME son premier lot après chaque [start] — le protocole affiché
// reste inchangé, cette garde ne dépend d'aucun minutage externe.
//
// `lib/diagnostics/` n'est importé QUE par `main.dart` (convention, pas une
// règle de `test/architecture/layers_test.dart` — cf. son en-tête, qui
// n'en porte que sept ; celle-ci se vérifie par
// `grep -rn diagnostics lib/`). C'est délibéré : la sonde n'a aucune raison
// d'être connue d'une tranche `features/` ni d'un dépôt `data/`, elle
// n'existe que pour la racine de composition, derrière son drapeau.
//
// Dart pur mis à part `package:flutter/scheduler.dart` (pour
// `SchedulerBinding`, `FrameTiming` et `TimingsCallback`) : ce fichier n'a
// pas les contraintes de `lib/domain/` (il n'y vit pas), mais il n'a pas
// davantage besoin d'un widget.

import 'package:flutter/scheduler.dart'
    show FrameTiming, SchedulerBinding, TimingsCallback;

/// Seuils de `NFR-01` (`docs/nfr.md`), fixés **avant** toute mesure : les
/// déplacer après un résultat décevant serait la seule façon certaine de ne
/// rien apprendre (`CLAUDE.md`, `docs/superpowers/plans/…` § Task X3). Ces
/// deux constantes ne bougent jamais.
const Duration frameBudget = Duration(microseconds: 16700); // p90 ≤ 16,7 ms

/// Seuil de trames en retard de `NFR-01` : moins de 5 %.
const double lateFrameThresholdPercent = 5.0;

/// `true` seulement si l'application a été lancée avec
/// `--dart-define=FLUIDITY_PROBE=true`. `bool.fromEnvironment` est résolu à
/// la COMPILATION : sans ce drapeau, cette constante vaut `false` dans le
/// binaire livré, et rien de ce fichier ne s'exécute jamais en production
/// (`CLAUDE.md`, Task X3 — « la sonde est inerte sans lui »).
const bool fluidityProbeEnabled = bool.fromEnvironment('FLUIDITY_PROBE');

/// Le percentile [fraction] (entre 0 et 1 inclus) de [samples], par la
/// méthode du rang le plus proche (« nearest rank », même formule que le
/// spike, `frame_stats.dart` : `(p * n).ceil()`) : sur `[1, 2, …, 100] ms`,
/// le p50 vaut exactement 50 ms et le p90 exactement 90 ms (cas de test du
/// plan). Lève [ArgumentError] si [samples] est vide — un percentile sans
/// échantillon n'a pas de sens, et ne doit surtout pas rendre
/// silencieusement `Duration.zero`.
Duration percentile(List<Duration> samples, double fraction) {
  if (samples.isEmpty) {
    throw ArgumentError.value(
      samples,
      'samples',
      'un percentile suppose au moins un echantillon',
    );
  }

  final List<Duration> sorted = List<Duration>.of(samples)..sort();
  final int rang = (fraction * sorted.length).ceil() - 1;
  return sorted[rang.clamp(0, sorted.length - 1)];
}

/// Pourcentage de [samples] dont la durée dépasse STRICTEMENT [threshold]
/// (le budget de trame de `NFR-01` par défaut) — même opérateur `>` que le
/// spike (`frame_stats.dart`, `jankCount`) : une trame EXACTEMENT au budget
/// n'est pas en retard, une trame qui le dépasse d'une seule microseconde
/// l'est (cas de test de la frontière, relecture du 2026-09-23). Une liste
/// vide n'a produit aucune trame en retard : `0.0`, jamais une division par
/// zéro.
double lateFramePercent(
  List<Duration> samples, {
  Duration threshold = frameBudget,
}) {
  if (samples.isEmpty) {
    return 0;
  }

  final int enRetard = samples.where((Duration d) => d > threshold).length;
  return enRetard / samples.length * 100;
}

/// Le rapport d'un geste mesuré par [FrameTimingProbe]. Les quatre premiers
/// chiffres sont ceux de `NFR-01` (`frameCount`, `rasterP50`, `rasterP90`,
/// `lateFramePercent`) — le VERDICT du seuil ne se lit QUE sur eux. Les deux
/// derniers (`buildP90`, `lateFramePercentTotal`) sont INFORMATIFS,
/// ajoutés par la relecture du 2026-09-23 (🟠 2) pour instruire `NV-W6` :
/// ils ne changent aucun seuil et ne participent à aucun verdict.
final class FrameTimingReport {
  const FrameTimingReport({
    required this.frameCount,
    required this.rasterP50,
    required this.rasterP90,
    required this.lateFramePercent,
    required this.buildP90,
    required this.lateFramePercentTotal,
  });

  /// Nombre de trames publiées pendant le geste mesuré.
  final int frameCount;

  /// Percentile 50 de la durée de rastérisation.
  final Duration rasterP50;

  /// Percentile 90 de la durée de rastérisation — le chiffre de `NFR-01`.
  final Duration rasterP90;

  /// Pourcentage de trames dont la rastérisation dépasse [frameBudget] — le
  /// second chiffre de `NFR-01`.
  final double lateFramePercent;

  /// INFORMATIF (🟠 2) : percentile 90 de la durée de CONSTRUCTION (thread
  /// UI), comparable au même budget mais hors du verdict de `NFR-01`.
  final Duration buildP90;

  /// INFORMATIF (🟠 2) : pourcentage de trames dont `totalSpan`
  /// (vsync → raster fini, donc build ET file d'attente ET raster) dépasse
  /// [frameBudget] — rend visible un coût de rechargement (`NV-W6`) même
  /// quand la seule rastérisation reste dans le budget.
  final double lateFramePercentTotal;

  @override
  String toString() =>
      'FrameTimingReport(frameCount: $frameCount, rasterP50: $rasterP50, '
      'rasterP90: $rasterP90, lateFramePercent: '
      '${lateFramePercent.toStringAsFixed(1)}, buildP90: $buildP90, '
      'lateFramePercentTotal: '
      '${lateFramePercentTotal.toStringAsFixed(1)})';
}

/// Accumule les `FrameTiming` publiées par le moteur pendant un geste défini
/// d'avance, entre [start] et [stop], puis rend leurs percentiles par
/// [report].
///
/// [addTimingsCallback] et [removeTimingsCallback] sont injectables — par
/// défaut ceux de `SchedulerBinding.instance` — pour que ce fichier reste
/// testable avec un registre factice et des `FrameTiming` synthétiques,
/// sans lever de vrai binding Flutter (cas de test du plan).
final class FrameTimingProbe {
  FrameTimingProbe({
    void Function(TimingsCallback callback)? addTimingsCallback,
    void Function(TimingsCallback callback)? removeTimingsCallback,
  }) : _addTimingsCallback =
           addTimingsCallback ?? SchedulerBinding.instance.addTimingsCallback,
       _removeTimingsCallback =
           removeTimingsCallback ??
           SchedulerBinding.instance.removeTimingsCallback;

  final void Function(TimingsCallback callback) _addTimingsCallback;
  final void Function(TimingsCallback callback) _removeTimingsCallback;

  final List<Duration> _rasterDurations = <Duration>[];
  final List<Duration> _buildDurations = <Duration>[];
  final List<Duration> _totalSpans = <Duration>[];

  /// `true` entre [start] et [stop] : c'est cette garde, et non le seul
  /// retrait du rappel, qui assure qu'aucune trame n'est enregistrée entre
  /// un `stop()` et le `start()` suivant — y compris si une trame publiée
  /// juste avant le retrait effectif du rappel arrivait quand même (cas de
  /// test du plan). C'est aussi elle qui empêche un second [start] pendant
  /// que le premier tourne d'enregistrer un second rappel (relecture du
  /// 2026-09-23, 🟢 6).
  bool _running = false;

  /// `true` jusqu'au PREMIER lot de `FrameTiming` reçu après [start] — ce
  /// lot est ignoré, jamais enregistré (contre-relecture du 2026-09-23, voir
  /// l'en-tête de ce fichier pour le calcul de dilution). Un second lot,
  /// s'il arrive, est enregistré normalement : seul le tout premier est
  /// suspect.
  bool _firstBatchPending = false;

  void _onTimings(List<FrameTiming> timings) {
    if (!_running) {
      return;
    }
    if (_firstBatchPending) {
      _firstBatchPending = false;
      return;
    }
    for (final FrameTiming timing in timings) {
      _rasterDurations.add(timing.rasterDuration);
      _buildDurations.add(timing.buildDuration);
      _totalSpans.add(timing.totalSpan);
    }
  }

  /// Démarre un nouveau geste : repart sur un relevé VIDE, ne cumule jamais
  /// avec un geste précédent. Un [start] alors qu'un geste est DÉJÀ en
  /// cours (deux clics, ou deux appels par erreur) est un NO-OP total : ni
  /// second enregistrement du rappel, ni remise à zéro du relevé en cours
  /// (relecture du 2026-09-23, 🟢 6) — arrêter explicitement le geste en
  /// cours reste la seule façon d'en commencer un autre.
  void start() {
    if (_running) {
      return;
    }
    _rasterDurations.clear();
    _buildDurations.clear();
    _totalSpans.clear();
    _running = true;
    _firstBatchPending = true;
    _addTimingsCallback(_onTimings);
  }

  /// Arrête le geste en cours. Après [stop], plus aucune trame n'est
  /// enregistrée, même si le rappel est encore invoqué.
  void stop() {
    _running = false;
    _removeTimingsCallback(_onTimings);
  }

  /// Le rapport du geste mesuré depuis le dernier [start]. Appelé avant
  /// tout [start], rend un rapport à `frameCount` nul — jamais une division
  /// par zéro.
  FrameTimingReport report() {
    if (_rasterDurations.isEmpty) {
      return const FrameTimingReport(
        frameCount: 0,
        rasterP50: Duration.zero,
        rasterP90: Duration.zero,
        lateFramePercent: 0,
        buildP90: Duration.zero,
        lateFramePercentTotal: 0,
      );
    }

    return FrameTimingReport(
      frameCount: _rasterDurations.length,
      rasterP50: percentile(_rasterDurations, 0.5),
      rasterP90: percentile(_rasterDurations, 0.9),
      lateFramePercent: lateFramePercent(_rasterDurations),
      buildP90: percentile(_buildDurations, 0.9),
      lateFramePercentTotal: lateFramePercent(_totalSpans),
    );
  }
}

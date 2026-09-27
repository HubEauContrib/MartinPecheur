// Task X3 (`NFR-01`) — comment le commanditaire déclenche `G1`/`G2`/`G3` et
// lit leurs rapports : un petit panneau visible SEULEMENT derrière
// `--dart-define=FLUIDITY_PROBE=true` (jamais un raccourci clavier — la
// carte en possède déjà sous `mapShortcuts()` : `+`/`=`/`-`/pavé
// numérique/flèches, plus `Échap` posé par `MapView` elle-même (`K2`) ; un
// raccourci de plus aurait fallu le choisir SANS toucher à cette liste, un
// panneau l'évite entièrement).
//
// Relecture du 2026-09-23, PUIS contre-relecture le même jour :
//
// 🔴 1 — SANS largeur bornée, un `Positioned` sans `left`/`width` laissait
// les contraintes de largeur du panneau REMONTER à l'infini, et
// l'`Expanded` de `_GestureRow` levait « RenderFlex … incoming width
// constraints are unbounded » (débordement de ~600 px en profile,
// recouvrant l'avertissement et la légende). [fluidityProbePanelWidth] fixe
// désormais une largeur NOMMÉE, et [fluidityProbeOverlay] pose le panneau
// EN BAS À GAUCHE — jamais dans un coin déjà occupé (puces + avis, avertisse
// ment + légende, contrôles de zoom + attribution). [fluidityProbeOverlay]
// est la SEULE fonction qui pose ce `Positioned` : `main.dart` et les tests
// l'appellent tous deux, pour ne jamais diverger sur la position.
//
// 🟠 2 — le rapport distingue EXPLICITEMENT les deux chiffres de `NFR-01`
// (rastérisation, « seuils NFR-01 ») des deux chiffres informatifs ajoutés
// par `FrameTimingReport` (construction et `totalSpan`, « informatif »).
//
// 🟠 3 — le protocole affiché sous les boutons absorbe les lots de
// publication d'environ 100 ms de `SchedulerBinding` (aucun filtrage par
// horodatage) : démarrer, attendre 1 s, faire le geste, attendre 1 s,
// arrêter. `G2` précise que ses crans de molette se comptent À LA MAIN, et
// nomme son échelle (écoulement, comme `G1`) — les deux avaient disparu du
// libellé.
//
// CONTRE-RELECTURE (même jour) — le protocole seul ne suffisait pas :
// l'`InkRipple` par défaut d'un `TextButton` dure environ 675 ms sous
// Windows, et le survol/l'appui du bouton publient leurs propres trames.
// Combinées au premier lot de `FrameTiming` reçu après `start()` (qui, avec
// le protocole « attendre 1 s », ne contient QUE des trames d'AVANT le
// geste — voir `frame_timing_probe.dart`), ces trames de l'INTERFACE du
// panneau diluaient le geste mesuré : ~50-60 trames rapides pour ~600
// trames de geste, une dilution d'environ 9 % qui peut faire passer 5,4 %
// de trames en retard SOUS le seuil de 5 % (calcul du coordinateur) — un
// faux vert. Deux corrections, pas une seule :
//   1. les boutons du panneau sont SANS animation (`_panelButtonStyle`) ;
//   2. la sonde ignore elle-même son premier lot après `start()`.
// Position revue aussi : `fluidityProbePanelBottom` redescend à 32 (la
// zone de fiche, vide pendant une mesure — aucune fiche ne s'ouvre pendant
// qu'on mesure la fluidité) pour que les trois lignes ET le rapport de `G2`
// tiennent SANS défilement à 800 × 700, et que le panneau ne recouvre plus
// les avis de carte (« ni station… », « Élargir la recherche », bandeau
// d'erreur) posés SOUS les puces, en haut-gauche.
//
// Un seul [FrameTimingProbe], réutilisé pour les trois gestes l'un après
// l'autre (jamais deux en même temps — un seul geste a lieu à la fois sur
// la carte) : `start()` repart sur un relevé vide (voir son en-tête), pas
// besoin d'une sonde par geste.
//
// `lib/diagnostics/` n'est importé QUE par `main.dart`, qui construit ce
// panneau et non l'inverse — c'est cette convention (pas une règle de
// `layers_test.dart`) qui borne son usage.

import 'package:flutter/material.dart';
import 'package:martinpecheur/diagnostics/counting_station_point_repository.dart';
import 'package:martinpecheur/diagnostics/frame_timing_probe.dart';

/// Largeur FIXE du panneau (🔴 1) : c'est l'absence de cette borne qui
/// laissait `Expanded` recevoir des contraintes de largeur infinies.
const double fluidityProbePanelWidth = 300;

/// Marge du panneau depuis le bord gauche de l'écran.
const double fluidityProbePanelLeft = 8;

/// Marge du panneau depuis le BAS de l'écran (contre-relecture du
/// 2026-09-23 : redescendue de 360 à 32). C'est la marge de la zone de
/// fiche station/ONDE (`_sheetBottomPadding` de `map_view.dart`) — vide
/// PENDANT une mesure de fluidité, puisqu'aucune fiche ne s'ouvre pendant
/// qu'on mesure le geste. Redescendre ici, plutôt que de rester au-dessus
/// de cette zone, est ce qui laisse assez de hauteur pour que les trois
/// lignes ET le rapport de `G2` tiennent SANS défilement, et ce qui écarte
/// le panneau des avis de carte (« ni station… », « Élargir la
/// recherche », bandeau d'erreur), posés SOUS les puces en haut-gauche.
const double fluidityProbePanelBottom = 32;

/// Hauteur MAXIMALE du contenu du panneau : un filet de sécurité, pas le
/// dimensionnement visé — à 800 × 700 avec [fluidityProbePanelBottom] à 32,
/// le contenu réel (titre, protocole, trois lignes, rapport de `G2` sur
/// quatre lignes) tient largement en dessous, sans jamais déclencher le
/// défilement du `SingleChildScrollView` qui reste dessous par prudence
/// (même choix que `buildMapOverlays` pour le contrôle d'avertissement et
/// la légende, `map_view.dart`).
const double fluidityProbePanelMaxHeight = 420;

/// Les trois gestes de `NFR-01`, définis d'avance par le plan — jamais un
/// quatrième choisi après coup. Les trois se mesurent à l'échelle
/// **écoulement** (`G1` et `G3` l'annonçaient déjà ; `G2` le précise depuis
/// la relecture du 2026-09-23, 🟠 3 — c'est elle qui franchit les deux
/// seuils de regroupement, `ADR-015`).
enum FluidityGesture {
  /// Glisser continu à zoom départemental, échelle écoulement — 10 s.
  g1('G1', 'glisser, zoom départemental, écoulement, 10 s'),

  /// Six zooms molette successifs, national → local, échelle écoulement —
  /// 10 s. Seul geste dont le rapport compte aussi les appels à
  /// `StationPointRepository.withinBounds` (`NV-W6`) ; les crans de
  /// molette eux-mêmes se comptent à la main (aucun capteur ne les
  /// distingue d'un défilement).
  g2(
    'G2',
    'six crans de molette (à compter à la main), national → local, '
        'écoulement, 10 s',
  ),

  /// Glisser continu à zoom national, échelle écoulement — 10 s.
  g3('G3', 'glisser, zoom national, écoulement, 10 s');

  const FluidityGesture(this.code, this.description);

  final String code;
  final String description;
}

/// Le protocole affiché sous les boutons (🟠 3) : `SchedulerBinding`
/// publie ses trames par lots d'environ 100 ms — le protocole les absorbe
/// PAR LA MARGE de la seconde d'attente, plutôt qu'un filtrage par
/// horodatage (arbitrage du 2026-09-23). Une seconde ne produit quasiment
/// aucune trame supplémentaire (rien ne bouge à l'écran), mais laisse
/// l'ondulation du bouton s'éteindre et le dernier lot arriver.
const String fluidityProbeProtocol =
    'Protocole : Démarrer, attendre 1 s, faire le geste, attendre 1 s, '
    'Arrêter.';

/// Pose [FluidityProbePanel] au-dessus de l'écran carte : EN BAS À GAUCHE,
/// avec une largeur fixe ([fluidityProbePanelWidth]) — jamais un
/// `Positioned` sans borne (🔴 1). Fonction PARTAGÉE par `main.dart` et les
/// tests, pour que les deux ne puissent jamais diverger sur la position.
Widget fluidityProbeOverlay({
  required FrameTimingProbe probe,
  required CountingStationPointRepository stationPoints,
}) {
  return Positioned(
    left: fluidityProbePanelLeft,
    bottom: fluidityProbePanelBottom,
    width: fluidityProbePanelWidth,
    child: FluidityProbePanel(probe: probe, stationPoints: stationPoints),
  );
}

/// Le panneau de déclenchement/lecture de `NFR-01`. `probe` est réutilisée
/// pour les trois gestes ; `stationPoints` n'est lue que pour `G2`
/// ([FluidityGesture.g2]) — les deux autres gestes affichent son compteur à
/// zéro sans grief, `withinBoundsCallCount` ne redescend jamais.
///
/// Toujours posé avec une largeur BORNÉE (voir [fluidityProbeOverlay]) :
/// c'est cette contrainte, pas un `SizedBox` interne, qui protège
/// `_GestureRow` — un `Expanded` a besoin d'une largeur MAXIMALE finie
/// venue d'un ancêtre, jamais d'une largeur qu'il se donnerait à lui-même.
class FluidityProbePanel extends StatefulWidget {
  const FluidityProbePanel({
    required this.probe,
    required this.stationPoints,
    super.key,
  });

  final FrameTimingProbe probe;
  final CountingStationPointRepository stationPoints;

  @override
  State<FluidityProbePanel> createState() => _FluidityProbePanelState();
}

class _FluidityProbePanelState extends State<FluidityProbePanel> {
  FluidityGesture? _running;
  FluidityGesture? _lastMeasured;
  FrameTimingReport? _lastReport;
  int? _lastPointRepositoryCalls;
  int _callsAtStart = 0;

  void _start(FluidityGesture gesture) {
    // Relu le 2026-09-23 (🟠 5) : la ligne de base est reprise ICI, à
    // CHAQUE `_start()` — un second geste `G2` ne doit jamais hériter du
    // compteur cumulé d'un geste précédent.
    _callsAtStart = widget.stationPoints.withinBoundsCallCount;
    setState(() {
      _running = gesture;
      _lastReport = null;
      _lastPointRepositoryCalls = null;
    });
    widget.probe.start();
  }

  void _stop() {
    final FluidityGesture? gesture = _running;
    if (gesture == null) {
      return;
    }
    widget.probe.stop();
    final FrameTimingReport report = widget.probe.report();
    final int calls =
        widget.stationPoints.withinBoundsCallCount - _callsAtStart;

    final StringBuffer line = StringBuffer(
      '[FLUIDITY_PROBE] ${gesture.code} — $report',
    );
    if (gesture == FluidityGesture.g2) {
      line.write(', appels withinBounds: $calls');
    }
    debugPrint(line.toString());

    setState(() {
      _running = null;
      _lastMeasured = gesture;
      _lastReport = report;
      _lastPointRepositoryCalls = calls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: fluidityProbePanelMaxHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'NFR-01 — sonde de fluidité (FLUIDITY_PROBE)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(fluidityProbeProtocol),
                  const SizedBox(height: 4),
                  for (final FluidityGesture gesture in FluidityGesture.values)
                    _GestureRow(
                      gesture: gesture,
                      running: _running == gesture,
                      disabled: _running != null && _running != gesture,
                      onStart: () => _start(gesture),
                      onStop: _stop,
                    ),
                  if (_lastReport != null && _lastMeasured != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(_reportText(_lastMeasured!, _lastReport!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🟠 2 — les deux chiffres de `NFR-01` (raster) sont libellés
  /// « seuils NFR-01 » ; `buildP90`/`lateFramePercentTotal` sont libellés
  /// « informatif » : le verdict de `NFR-01` ne se lit QUE sur les
  /// premiers, jamais sur les seconds.
  String _reportText(FluidityGesture gesture, FrameTimingReport report) {
    final StringBuffer text = StringBuffer(
      '${gesture.code} — trames : ${report.frameCount}\n'
      'raster (seuils NFR-01) — p50 : '
      '${report.rasterP50.inMicroseconds / 1000} ms, p90 : '
      '${report.rasterP90.inMicroseconds / 1000} ms, en retard : '
      '${report.lateFramePercent.toStringAsFixed(1)} %\n'
      'informatif — build p90 : '
      '${report.buildP90.inMicroseconds / 1000} ms, totalSpan en retard : '
      '${report.lateFramePercentTotal.toStringAsFixed(1)} %',
    );
    if (gesture == FluidityGesture.g2 && _lastPointRepositoryCalls != null) {
      text.write('\nappels withinBounds : $_lastPointRepositoryCalls');
    }
    return text.toString();
  }
}

/// Style commun aux boutons du panneau : SANS animation (contre-relecture
/// du 2026-09-23). `NoSplash.splashFactory` désactive l'`InkRipple` par
/// défaut (~675 ms sous Windows) ; `overlayColor: Colors.transparent`
/// désactive en plus les teintes de survol/appui — les deux publient des
/// trames que la sonde verrait sinon, en tête de geste. Voir l'en-tête de
/// ce fichier pour le calcul de dilution qui a motivé cette correction.
/// `padding`/`minimumSize`/`tapTargetSize` resserrent le bouton — c'est ce
/// qui permet de l'élargir (64 → 84) sans déborder de la ligne à 300 px de
/// large tout en laissant de la place à la description.
final ButtonStyle _panelButtonStyle = TextButton.styleFrom(
  foregroundColor: Colors.white,
  splashFactory: NoSplash.splashFactory,
  overlayColor: Colors.transparent,
  padding: const EdgeInsets.symmetric(horizontal: 4),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Largeur du bouton Démarrer/Arrêter : élargie de 64 à 84 (contre-relecture
/// du 2026-09-23) — à 64, « Démarrer » (le plus long des deux libellés)
/// talonnait le bord du bouton une fois `_panelButtonStyle` posé.
const double _panelButtonWidth = 84;

class _GestureRow extends StatelessWidget {
  const _GestureRow({
    required this.gesture,
    required this.running,
    required this.disabled,
    required this.onStart,
    required this.onStop,
  });

  final FluidityGesture gesture;
  final bool running;
  final bool disabled;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              gesture.code,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: _panelButtonWidth,
            child: TextButton(
              style: _panelButtonStyle,
              onPressed: running ? onStop : (disabled ? null : onStart),
              child: Text(running ? 'Arrêter' : 'Démarrer'),
            ),
          ),
          Expanded(
            child: Text(
              gesture.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Relecture du 2026-09-23 (🔴 1, 🟠 2, 🟠 3, 🟠 5 dernier point) sur
// `FluidityProbePanel` (Task X3, `NFR-01`) :
//
// 🔴 1 — `Expanded` dans un `Row` sans borne de largeur, posé sous un
// `Positioned(top:, right:)` sans `left`/`width`, plante en debug
// (« RenderFlex … incoming width constraints are unbounded ») et s'étale
// sur ~600 px en profile, recouvrant le contrôle d'avertissement et la
// légende. Ce fichier monte le panneau dans le MÊME genre de `Stack` que
// `map_view_test.dart` (groupe `800 × 700`, K3) : `buildMapOverlays` plus
// le panneau, à la taille minimale de fenêtre Windows, et vérifie qu'AUCUNE
// exception n'est levée et qu'AUCUNE surcouche ne se recouvre.
//
// 🟠 3 — le protocole affiché sous les boutons, la mention "à compter à la
// main" pour G2, et l'échelle nommée dans le libellé de G2 (écoulement,
// comme G1).
//
// 🟠 5 (dernier point) — le compteur d'appels `withinBounds` de `G2` doit
// repartir de zéro à CHAQUE geste : deux gestes `G2` successifs, avec des
// appels au dépôt entre les deux, ne doivent pas cumuler.
//
// Contre-relecture du 2026-09-23 (même jour) :
// 1. les boutons du panneau sont SANS animation (`NoSplash.splashFactory`,
//    survol/appui transparents) — l'`InkRipple` par défaut publie des
//    trames que la sonde verrait sinon.
// 3. le panneau redescend à `bottom: 32` : les trois lignes ET le rapport
//    de `G2` doivent tenir SANS défilement à 800 × 700, et ne recouvrir NI
//    les avis de carte sous les puces (« ni station… », « Élargir la
//    recherche ») NI aucune autre surcouche.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show FrameTiming, TimingsCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/diagnostics/counting_station_point_repository.dart';
import 'package:martinpecheur/diagnostics/fluidity_probe_panel.dart';
import 'package:martinpecheur/diagnostics/frame_timing_probe.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart'
    show NoStationInAreaNotice;
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

/// Même registre factice que `frame_timing_probe_test.dart` : `add` capture
/// le dernier rappel enregistré, ce qui permet de simuler des lots de
/// `FrameTiming` sans lever de vrai `SchedulerBinding`.
final class _FakeRegistry {
  TimingsCallback? captured;

  void add(TimingsCallback callback) => captured = callback;

  void remove(TimingsCallback callback) {}
}

void main() {
  group('FluidityProbePanel — disposition (🔴 1, puis contre-relecture '
      '2026-09-23, point 3)', () {
    /// [stationPoints] et [probe] sont exposés à l'appelant (plutôt que
    /// construits ici) pour que le test du rapport puisse démarrer/arrêter
    /// `G2` après le montage et faire apparaître un rapport RÉEL,
    /// multi-lignes — le cas qui a fait déborder le panneau (contre-
    /// relecture du 2026-09-23) est justement celui-là, pas le panneau vide.
    Future<void> pumpPanelWithOverlays(
      WidgetTester tester,
      Size size, {
      required CountingStationPointRepository stationPoints,
      required FrameTimingProbe probe,
    }) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                // `stations` VIDE : déclenche l'avis « ni station… » +
                // « Élargir la recherche » (`NoStationInAreaNotice`), posé
                // SOUS les puces en haut-gauche — exactement ce que le
                // panneau ne doit plus recouvrir (point 3).
                ...buildMapOverlays(
                  scale: MapScaleKind.debit,
                  onSelect: (MapScaleKind kind) {},
                  onWiden: () {},
                  error: null,
                  stations: const <StationPoint>[],
                  ondeObservations: const <OndeStationCode, OndeObservation>{},
                  ondeUnreadableRows: 0,
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onRecenter: () {},
                ),
                fluidityProbeOverlay(
                  probe: probe,
                  stationPoints: stationPoints,
                ),
              ],
            ),
          ),
        ),
      );
    }

    /// Les six surcouches — plus le panneau — dont AUCUNE paire ne doit se
    /// recouvrir.
    Map<String, Rect> rectsAt(WidgetTester tester) => <String, Rect>{
      'WarningLink': tester.getRect(find.byType(WarningLink)),
      'MapLegend': tester.getRect(find.byType(MapLegend)),
      'MapScaleChips': tester.getRect(find.byType(MapScaleChips)),
      'NoStationInAreaNotice': tester.getRect(
        find.byType(NoStationInAreaNotice),
      ),
      'MapControls': tester.getRect(find.byType(MapControls)),
      'IgnAttributionBadge': tester.getRect(find.byType(IgnAttributionBadge)),
      'FluidityProbePanel': tester.getRect(find.byType(FluidityProbePanel)),
    };

    void expectNoOverlap(Map<String, Rect> rects) {
      for (final MapEntry<String, Rect> a in rects.entries) {
        for (final MapEntry<String, Rect> b in rects.entries) {
          if (a.key == b.key) {
            continue;
          }
          expect(
            a.value.overlaps(b.value),
            isFalse,
            reason:
                '${a.key} (${a.value}) recouvre ${b.key} (${b.value}) '
                'à 800 × 700',
          );
        }
      }
    }

    testWidgets(
      'panneau au repos : aucune exception, aucun recouvrement (puces, '
      "avis « ni station… », avertissement, légende, contrôles, "
      'attribution)',
      (WidgetTester tester) async {
        const Size taille = Size(800, 700);
        await pumpPanelWithOverlays(
          tester,
          taille,
          stationPoints: CountingStationPointRepository(
            _EmptyStationPointRepository(),
          ),
          probe: FrameTimingProbe(
            addTimingsCallback: (_) {},
            removeTimingsCallback: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectNoOverlap(rectsAt(tester));
      },
    );

    testWidgets(
      'G2 mesuré ET son rapport affiché (le cas qui déborde le plus) : '
      'toujours aucun recouvrement, et le bas du rapport reste VISIBLE '
      'sans défilement',
      (WidgetTester tester) async {
        const Size taille = Size(800, 700);
        final _FakeRegistry registry = _FakeRegistry();
        final CountingStationPointRepository stationPoints =
            CountingStationPointRepository(_EmptyStationPointRepository());
        final FrameTimingProbe probe = FrameTimingProbe(
          addTimingsCallback: registry.add,
          removeTimingsCallback: registry.remove,
        );

        await pumpPanelWithOverlays(
          tester,
          taille,
          stationPoints: stationPoints,
          probe: probe,
        );
        await tester.pumpAndSettle();

        // Démarre G2 (deuxième bouton « Démarrer »), publie deux lots (le
        // premier ignoré, cf. `frame_timing_probe_test.dart`), appelle le
        // dépôt trois fois, puis arrête : un rapport de G2 COMPLET
        // s'affiche, sur quatre lignes.
        await tester.tap(find.widgetWithText(TextButton, 'Démarrer').at(1));
        await tester.pump();
        registry.captured!(<FrameTiming>[
          FrameTiming(
            vsyncStart: 0,
            buildStart: 0,
            buildFinish: 0,
            rasterStart: 0,
            rasterFinish: 1000,
            rasterFinishWallTime: 1000,
          ),
        ]);
        registry.captured!(<FrameTiming>[
          FrameTiming(
            vsyncStart: 0,
            buildStart: 0,
            buildFinish: 0,
            rasterStart: 0,
            rasterFinish: 5000,
            rasterFinishWallTime: 5000,
          ),
        ]);
        final Bounds bounds = Bounds(west: 0, south: 0, east: 1, north: 1);
        await stationPoints.withinBounds(bounds);
        await stationPoints.withinBounds(bounds);
        await stationPoints.withinBounds(bounds);
        await tester.tap(find.widgetWithText(TextButton, 'Arrêter'));
        await tester.pump();

        expect(
          find.textContaining('appels withinBounds : 3'),
          findsOneWidget,
          reason: 'le rapport complet doit bien être affiché pour ce test',
        );

        expect(tester.takeException(), isNull);
        expectNoOverlap(rectsAt(tester));

        final Rect rapport = tester.getRect(
          find.textContaining('appels withinBounds : 3'),
        );
        final Rect panneau = tester.getRect(find.byType(FluidityProbePanel));
        expect(
          rapport.bottom,
          lessThanOrEqualTo(panneau.bottom),
          reason:
              'le bas du rapport doit rester dans le cadre visible du '
              "panneau — au-delà, il faudrait faire défiler pour le lire, "
              'ce que le point 3 de la contre-relecture interdit',
        );
      },
    );
  });

  group('FluidityProbePanel — boutons SANS animation (contre-relecture du '
      '2026-09-23, point 1)', () {
    testWidgets('le style de CHAQUE bouton Démarrer/Arrêter porte '
        'NoSplash.splashFactory et un overlayColor transparent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluidityProbePanel(
              probe: FrameTimingProbe(
                addTimingsCallback: (_) {},
                removeTimingsCallback: (_) {},
              ),
              stationPoints: CountingStationPointRepository(
                _EmptyStationPointRepository(),
              ),
            ),
          ),
        ),
      );

      final Iterable<TextButton> boutons = tester.widgetList<TextButton>(
        find.byType(TextButton),
      );
      expect(boutons, hasLength(3));

      for (final TextButton bouton in boutons) {
        expect(
          bouton.style?.splashFactory,
          same(NoSplash.splashFactory),
          reason:
              "l'InkRipple par défaut dure environ 675 ms sous Windows "
              'et publie ses propres trames (contre-relecture du '
              '2026-09-23)',
        );
        expect(
          bouton.style?.overlayColor?.resolve(<WidgetState>{}),
          Colors.transparent,
          reason:
              'le survol et l\'appui ne doivent publier aucune trame '
              'supplémentaire',
        );
      }
    });
  });

  group('FluidityProbePanel — protocole affiché (🟠 3)', () {
    testWidgets(
      'affiche le protocole (démarrer, attendre 1 s, geste, attendre 1 s, '
      'arrêter), la mention "à compter à la main" pour G2, et son échelle '
      '(écoulement, comme G1)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FluidityProbePanel(
                probe: FrameTimingProbe(
                  addTimingsCallback: (_) {},
                  removeTimingsCallback: (_) {},
                ),
                stationPoints: CountingStationPointRepository(
                  _EmptyStationPointRepository(),
                ),
              ),
            ),
          ),
        );

        expect(
          find.textContaining('attendre 1 s'),
          findsOneWidget,
          reason:
              'le protocole doit absorber les lots de ~100 ms sans '
              'filtrage par horodatage (arbitrage du 2026-09-23)',
        );
        expect(find.widgetWithText(TextButton, 'Démarrer'), findsNWidgets(3));
        expect(
          find.widgetWithText(TextButton, 'Arrêter'),
          findsNothing,
          reason:
              'aucun geste en cours : aucun bouton "Arrêter" — le mot '
              'apparaît dans le texte du protocole lui-même, ce que '
              '`find.textContaining` seul confondrait',
        );
        expect(
          find.textContaining('crans de molette'),
          findsOneWidget,
          reason: 'à compter à la main pour G2',
        );
        expect(
          find.textContaining('écoulement'),
          findsNWidgets(3),
          reason:
              'les trois gestes (G1, G2, G3) nomment la même échelle '
              '(écoulement)',
        );
      },
    );
  });

  group('FluidityProbePanel — compteur G2 remis à zéro à chaque geste '
      '(🟠 5)', () {
    testWidgets('deux gestes G2 successifs, avec des appels entre les deux, ne '
        'cumulent pas', (WidgetTester tester) async {
      final CountingStationPointRepository stationPoints =
          CountingStationPointRepository(_EmptyStationPointRepository());
      final FrameTimingProbe probe = FrameTimingProbe(
        addTimingsCallback: (_) {},
        removeTimingsCallback: (_) {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluidityProbePanel(
              probe: probe,
              stationPoints: stationPoints,
            ),
          ),
        ),
      );

      final Bounds bounds = Bounds(west: 0, south: 0, east: 1, north: 1);

      // Premier geste G2 : trois appels pendant le geste.
      await tester.tap(find.widgetWithText(TextButton, 'Démarrer').at(1));
      await tester.pump();
      await stationPoints.withinBounds(bounds);
      await stationPoints.withinBounds(bounds);
      await stationPoints.withinBounds(bounds);
      await tester.tap(find.widgetWithText(TextButton, 'Arrêter'));
      await tester.pump();

      expect(find.textContaining('appels withinBounds : 3'), findsOneWidget);

      // Second geste G2 : un seul appel pendant CE geste — le compteur du
      // décorateur, lui, continue de monter (6), mais le rapport du
      // panneau ne doit rapporter QUE ce second geste (1), pas le cumul
      // (9) ni le total du décorateur (6).
      await tester.tap(find.widgetWithText(TextButton, 'Démarrer').at(1));
      await tester.pump();
      await stationPoints.withinBounds(bounds);
      await tester.tap(find.widgetWithText(TextButton, 'Arrêter'));
      await tester.pump();

      expect(stationPoints.withinBoundsCallCount, 4);
      expect(find.textContaining('appels withinBounds : 1'), findsOneWidget);
      expect(find.textContaining('appels withinBounds : 4'), findsNothing);
    });
  });
}

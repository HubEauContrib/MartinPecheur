// Task X3 (`NFR-01`), révision du 2026-09-22 — `NV-W6` : `MapEventScroll
// WheelZoom` n'a pas de variante `…End` dans `flutter_map` 8.3.2
// (`docs/nfr.md`), donc chaque cran de molette déclenche un rechargement.
// `G2` compte le nombre d'appels au dépôt de points PENDANT le geste, pour
// dire si ce coût est visible dans les trames ou non. Ce décorateur est
// posé pour cette seule mesure — câblé par `main.dart` derrière le drapeau
// `FLUIDITY_PROBE`, inerte sans lui, au même titre que `FrameTimingProbe`.
//
// Décore [StationPointRepository] et RIEN d'autre : il délègue chaque appel
// au dépôt décoré, à l'identique — ni cache, ni filtrage, ni transformation
// (une seule responsabilité, CLAUDE.md § SOLID). `all()` est déléguée elle
// aussi (ajoutée pour `ADR-015`/`Z2`), mais SEULE `withinBounds` est
// comptée : c'est elle que `G2` parcourt (le viewport, à chaque cran), pas
// le référentiel entier.
//
// `lib/diagnostics/` n'est importé QUE par `main.dart` — voir l'en-tête de
// `frame_timing_probe.dart` pour la même remarque sur `layers_test.dart`.

import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show StationPointRepository;
import 'package:martinpecheur/domain/station/station_point.dart';

/// Décore un [StationPointRepository] pour compter ses appels à
/// [withinBounds], sans changer aucun résultat rendu.
final class CountingStationPointRepository implements StationPointRepository {
  CountingStationPointRepository(this._inner);

  final StationPointRepository _inner;

  /// Nombre d'appels à [withinBounds] depuis la construction de ce
  /// décorateur. `all()` n'y contribue pas.
  int get withinBoundsCallCount => _withinBoundsCallCount;
  int _withinBoundsCallCount = 0;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) {
    _withinBoundsCallCount++;
    return _inner.withinBounds(bounds, margin: margin);
  }

  @override
  Future<List<StationPoint>> all() => _inner.all();
}

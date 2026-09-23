// Task X3 (`NFR-01`), relecture du 2026-09-23 (🟠 4) : « l'inertie sans
// drapeau » n'était vérifiée qu'indirectement, par la constante
// `fluidityProbeEnabled` — jamais par le câblage lui-même de `main.dart`.
// Cette fonction EXTRAIT ce câblage pour le rendre testable : elle reçoit
// le booléen en paramètre (jamais `bool.fromEnvironment` directement), ce
// qui permet un test « drapeau faux » et un test « drapeau vrai » sans
// dépendre d'un `--dart-define` au lancement de `flutter test`.
//
// `main.dart` reste le seul appelant — c'est lui qui décide QUEL booléen
// passer (`fluidityProbeEnabled`, résolu à la compilation).

import 'package:martinpecheur/diagnostics/counting_station_point_repository.dart';
import 'package:martinpecheur/diagnostics/frame_timing_probe.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart'
    show StationPointRepository;

/// Le résultat du câblage `NFR-01`, tel que [wireFluidityProbe] le rend.
final class FluidityWiring {
  const FluidityWiring({
    required this.stationPoints,
    this.probe,
    this.countingStationPoints,
  });

  /// Le dépôt à câbler dans `MapViewModel` : le MÊME objet que celui reçu
  /// par [wireFluidityProbe] (`identical`) si le drapeau était désactivé,
  /// décoré par [countingStationPoints] sinon.
  final StationPointRepository stationPoints;

  /// `null` si et seulement si le drapeau était désactivé.
  final FrameTimingProbe? probe;

  /// `null` si et seulement si le drapeau était désactivé — la même
  /// instance que celle qui décore [stationPoints] quand il est non nul.
  final CountingStationPointRepository? countingStationPoints;
}

/// Décide, à partir du SEUL booléen [enabled], s'il faut décorer
/// [stationPoints] par [CountingStationPointRepository] et instancier une
/// [FrameTimingProbe].
///
/// `enabled == false` : rien n'est construit — ni sonde, ni décorateur —
/// et [FluidityWiring.stationPoints] EST [stationPoints] (`identical`),
/// jamais une copie ni un décorateur transparent : c'est cette identité
/// qu'un test verrouille contre la mutation « le drapeau est ignoré ».
FluidityWiring wireFluidityProbe({
  required bool enabled,
  required StationPointRepository stationPoints,
}) {
  if (!enabled) {
    return FluidityWiring(stationPoints: stationPoints);
  }

  final CountingStationPointRepository counting =
      CountingStationPointRepository(stationPoints);
  return FluidityWiring(
    stationPoints: counting,
    probe: FrameTimingProbe(),
    countingStationPoints: counting,
  );
}

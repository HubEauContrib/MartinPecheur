// Le type de la reponse voyage avec le message : c'est ce qui permet au
// registre (lib/application/bus.dart) de rendre un List<Station> et non un
// dynamic. abstract interface class et non sealed (arbitrage 2026-09-13) :
// une requete se declare dans sa tranche (features/…) sans devoir etre
// listee ici — le registre achemine par Type, pas par un switch exhaustif.
//
// Aucune commande n'est declaree en T0 : rien n'est encore ecrit cote
// application (ADR-011 reserve le stockage local). Command<R> est pose pour
// figer la couture — Query et Command descendent toutes deux de Message afin
// qu'un seul registre (Bus) puisse les acheminer toutes les deux.

import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Un message porte a la fois sa nature (Query ou Command) et le type [R] de
/// sa reponse.
abstract interface class Message<R> {}

/// Une question posee au systeme : ne modifie rien, se rejoue sans effet de
/// bord.
abstract interface class Query<R> implements Message<R> {}

/// Un ordre donne au systeme : modifie un etat. Aucune commande en T0 — le
/// type est pose pour figer la couture.
abstract interface class Command<R> implements Message<R> {}

/// Les stations dont les coordonnees tombent dans [bounds]. C'est l'emprise
/// affichee a l'ecran qui borne le travail — jamais les 4 150 stations du
/// referentiel chargees puis filtrees en memoire (voir
/// [StationRepository.findWithinBounds]).
final class StationsWithinBoundsQuery implements Query<List<Station>> {
  const StationsWithinBoundsQuery(this.bounds);

  /// L'emprise a l'interieur de laquelle chercher.
  final Bounds bounds;
}

/// La station de code [code]. Rend `null` si aucune station ne porte ce
/// code — une absence, jamais une erreur (BR-007).
final class StationByCodeQuery implements Query<Station?> {
  const StationByCodeQuery(this.code);

  /// Le code de la station recherchee.
  final StationCode code;
}

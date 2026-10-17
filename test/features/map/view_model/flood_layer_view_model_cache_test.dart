// `FloodLayerViewModel` monté sur un VRAI `CachedFloodVigilanceSource`
// (relecture d'ensemble de T4, point D) : ni l'un ni l'autre n'est redémontré
// seul — `flood_layer_view_model_test.dart` et
// `test/data/floods/cached_flood_vigilance_source_test.dart` le font —, ce
// fichier éprouve leur ASSEMBLAGE : le ViewModel relit la source à chaque
// geste sur une carte lue, le décorateur décide (arbitrage 12).
//
// La source intérieure est pilotée (barrière, échec) et comptée ; l'horloge
// est injectée ; les instants s'écrivent à partir de `floodVigilanceCacheTtl`,
// jamais en dur. Un test peut importer `lib/data/` : seul `lib/features/` ne
// le peut pas (`test/architecture/layers_test.dart`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/floods/cached_flood_vigilance_source.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';

FloodVigilanceMap _carte(int heure) => FloodVigilanceMap(
  informationDate: DateTime.utc(2026, 10, 14, heure),
  sections: const [],
  skippedEntities: 0,
);

/// Source intérieure : compte ses appels, rend la prochaine carte réglée,
/// peut lever, et peut retenir sa réponse derrière une barrière.
final class _SourceInterieure implements FloodVigilanceSource {
  int appels = 0;
  FloodVigilanceMap prochaine = _carte(1);
  Object? erreur;
  Completer<void>? barriere;

  @override
  Future<FloodVigilanceMap> current() async {
    appels++;
    final Completer<void>? attente = barriere;
    if (attente != null) {
      await attente.future;
    }
    final Object? echec = erreur;
    if (echec != null) {
      throw echec;
    }
    return prochaine;
  }
}

final Bounds _emprise = Bounds(west: 0, south: 46, east: 2, north: 48);

Future<void> _laisserCourir() => Future<void>.delayed(Duration.zero);

void main() {
  late _SourceInterieure interieure;
  late DateTime maintenant;
  late FloodLayerViewModel viewModel;

  /// Un geste sur la lecture Crues, attendu jusqu'au bout de sa relecture.
  Future<void> geste() async {
    await viewModel.onViewportChanged(_emprise, individualLevel: false);
    await _laisserCourir();
  }

  FloodVigilanceMap carteAffichee() {
    final FloodLayerState state = viewModel.state;
    expect(state, isA<LectureCruesPrete>());
    return (state as LectureCruesPrete).map;
  }

  setUp(() async {
    interieure = _SourceInterieure();
    maintenant = DateTime.utc(2026, 10, 14, 12);
    viewModel = FloodLayerViewModel(
      source: CachedFloodVigilanceSource(
        inner: interieure,
        now: () => maintenant,
      ),
    );
    addTearDown(viewModel.dispose);
  });

  test('premier chargement : un appel à la source intérieure, sa carte '
      'affichée', () async {
    await viewModel.activate();

    expect(interieure.appels, 1);
    expect(carteAffichee(), same(interieure.prochaine));
  });

  test('geste avant la TTL : aucun appel, même carte', () async {
    await viewModel.activate();
    final FloodVigilanceMap premiere = carteAffichee();

    maintenant = maintenant.add(
      floodVigilanceCacheTtl - const Duration(seconds: 1),
    );
    await geste();

    expect(interieure.appels, 1);
    expect(carteAffichee(), same(premiere));
  });

  test(
    'geste à la TTL : l’ancienne carte reste, UN rafraîchissement part ; '
    'deux gestes pendant qu’il court n’en lancent pas d’autre ; la '
    'nouvelle carte paraît au geste qui suit sa fin (arbitrage 12)',
    () async {
      await viewModel.activate();
      final FloodVigilanceMap ancienne = carteAffichee();
      final FloodVigilanceMap nouvelle = _carte(2);
      interieure.prochaine = nouvelle;
      final Completer<void> barriere = Completer<void>();
      interieure.barriere = barriere;

      maintenant = maintenant.add(floodVigilanceCacheTtl);
      await geste();
      expect(interieure.appels, 2);
      expect(carteAffichee(), same(ancienne));

      await geste();
      await geste();
      expect(interieure.appels, 2, reason: 'un seul rafraîchissement en vol');
      expect(carteAffichee(), same(ancienne));

      barriere.complete();
      await _laisserCourir();
      expect(
        carteAffichee(),
        same(ancienne),
        reason: 'la fin du rafraîchissement ne notifie rien',
      );

      await geste();
      expect(carteAffichee(), same(nouvelle));
      expect(interieure.appels, 2, reason: 'la nouvelle carte est fraîche');
    },
  );

  test('rafraîchissement en échec : l’ancienne carte reste, aucune '
      'exception ; le geste suivant relance un rafraîchissement', () async {
    await viewModel.activate();
    final FloodVigilanceMap ancienne = carteAffichee();
    interieure.erreur = StateError('panne');

    maintenant = maintenant.add(floodVigilanceCacheTtl);
    await geste();
    await _laisserCourir();
    expect(interieure.appels, 2);
    expect(carteAffichee(), same(ancienne));

    await geste();
    await _laisserCourir();
    expect(interieure.appels, 3, reason: 'retenté au geste suivant');
    expect(carteAffichee(), same(ancienne));

    interieure.erreur = null;
    final FloodVigilanceMap nouvelle = _carte(3);
    interieure.prochaine = nouvelle;
    await geste();
    await _laisserCourir();
    expect(interieure.appels, 4);
    await geste();
    expect(carteAffichee(), same(nouvelle));
  });
}

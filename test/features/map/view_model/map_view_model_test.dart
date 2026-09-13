// Verrouille le ViewModel de la carte, sans monter aucun widget et sans
// rendre de `FlutterMap`. Ces cas sont ceux de `MapStationsController`
// (T0-M4), reecrits sur `MapViewModel` : appel typé au depot au lieu d'un
// message envoye a un registre (R3, arbitrage 2026-09-13).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

StationPoint _blois() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
);

StationPoint _guadeloupe() => StationPoint(
  code: StationCode('1011000101'),
  label: 'Grande Rivière à Goyaves',
  latitude: 16.189402,
  longitude: -61.658989,
);

/// Double de test du depot de points : compte les appels, note l'emprise
/// recue, et rend ce qu'on lui a dit de rendre — ou leve.
final class _StationPointRepositoryDouble implements StationPointRepository {
  int calls = 0;
  Bounds? receivedBounds;
  double? receivedMargin;
  Future<List<StationPoint>> Function(int call)? answer;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) {
    calls++;
    receivedBounds = bounds;
    receivedMargin = margin;
    final Future<List<StationPoint>> Function(int call)? configured = answer;
    if (configured == null) {
      return Future<List<StationPoint>>.value(<StationPoint>[]);
    }
    return configured(calls);
  }
}

void main() {
  late _StationPointRepositoryDouble repository;

  setUp(() {
    repository = _StationPointRepositoryDouble();
  });

  test('charge deux points au demarrage, en un seul appel au depot', () async {
    repository.answer = (int _) async => <StationPoint>[
      _blois(),
      _guadeloupe(),
    ];
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.loadInitial();

    expect(repository.calls, 1);
    expect(viewModel.stations, hasLength(2));
    expect(viewModel.error, isNull);
    expect(
      repository.receivedBounds,
      same(MapViewModel.startupBounds),
      reason:
          "l'emprise de demarrage est celle du ViewModel, jamais une "
          'valeur reconstruite au vol',
    );
  });

  test('loadFor notifie ses auditeurs une fois par chargement', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));

    expect(notifications, 1);
    expect(viewModel.stations, hasLength(1));
  });

  test('loadFor — une emprise inchangee ne renvoie pas de requete', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));
    await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));

    expect(repository.calls, 1);
  });

  test(
    'loadFor sur un ViewModel dispose ne leve rien et ne notifie pas',
    () async {
      final Completer<List<StationPoint>> completer =
          Completer<List<StationPoint>>();
      repository.answer = (int _) => completer.future;
      final MapViewModel viewModel = MapViewModel(repository);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      final Future<void> pending = viewModel.loadFor(
        Bounds(west: -1, south: 46, east: 3, north: 48),
      );
      viewModel.dispose();
      completer.complete(<StationPoint>[_blois()]);

      await expectLater(pending, completes);
      expect(notifications, 0);
    },
  );

  test('un depot qui leve rend une erreur visible via error, plutot que de '
      'la laisser remonter (BR-007)', () async {
    repository.answer = (int _) async => throw StateError('panne de depot');
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.loadFor(Bounds(west: -1, south: 46, east: 3, north: 48));

    expect(viewModel.error, isA<StateError>());
    expect(viewModel.stations, isEmpty);
  });

  test('un chargement reussi efface une erreur precedente, sur la MEME '
      'emprise', () async {
    repository.answer = (int call) async {
      if (call == 1) {
        throw StateError('panne temporaire');
      }
      return <StationPoint>[_blois()];
    };
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);
    final Bounds bounds = Bounds(west: -1, south: 46, east: 3, north: 48);

    await viewModel.loadFor(bounds);
    expect(viewModel.error, isNotNull);

    await viewModel.loadFor(bounds);
    expect(viewModel.error, isNull);
    expect(viewModel.stations, hasLength(1));
  });

  test(
    'apres un echec, un nouveau chargement sur la MEME emprise rappelle '
    'le depot : une emprise qui a echoue ne compte pas comme chargee, '
    "sinon l'ecran reste en erreur jusqu'a ce que l'usager bouge la carte",
    () async {
      repository.answer = (int call) async {
        if (call == 1) {
          throw StateError('panne temporaire');
        }
        return <StationPoint>[_blois()];
      };
      final MapViewModel viewModel = MapViewModel(repository);
      addTearDown(viewModel.dispose);
      final Bounds bounds = Bounds(west: -1, south: 46, east: 3, north: 48);

      await viewModel.loadFor(bounds);
      await viewModel.loadFor(bounds);

      expect(repository.calls, 2);
    },
  );

  test('deux chargements rapproches sur des emprises differentes : la '
      'reponse de la premiere, plus lente, ne doit pas ecraser celle de la '
      'seconde', () async {
    final Completer<List<StationPoint>> slow = Completer<List<StationPoint>>();
    final Completer<List<StationPoint>> fast = Completer<List<StationPoint>>();
    repository.answer = (int call) => call == 1 ? slow.future : fast.future;
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);

    final Future<void> firstLoad = viewModel.loadFor(
      Bounds(west: -1, south: 46, east: 3, north: 48),
    );
    final Future<void> secondLoad = viewModel.loadFor(
      Bounds(west: -62, south: 15, east: -61, north: 17),
    );

    fast.complete(<StationPoint>[_guadeloupe()]);
    await secondLoad;
    slow.complete(<StationPoint>[_blois()]);
    await firstLoad;

    expect(repository.calls, 2);
    expect(
      viewModel.stations.single.code.value,
      _guadeloupe().code.value,
      reason:
          "l'etat doit finir sur l'emprise demandee en DERNIER, quel que "
          "soit l'ordre d'arrivee des reponses",
    );
  });

  test("stations expose une vue immuable : un appelant ne peut pas y "
      'ajouter un point', () async {
    repository.answer = (int _) async => <StationPoint>[_blois()];
    final MapViewModel viewModel = MapViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.loadInitial();

    expect(() => viewModel.stations.add(_guadeloupe()), throwsUnsupportedError);
  });
}

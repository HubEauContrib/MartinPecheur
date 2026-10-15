// FloodLayerViewModel (L2 de T4) : l'état de la lecture Crues, sans rendu.
//
// Le double de source est piloté par `Completer` et compte ses appels : c'est
// ce compte qui éprouve le Review Focus 2 (un seul téléchargement tant que le
// premier chargement court) et le Review Focus 4 (une carte lue n'est jamais
// remplacée par un échec).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_section_rules.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';

/// Double de la source : chaque appel attend un `Completer` piloté par le
/// test ; le nombre d'appels est celui des `Completer` créés.
final class _SourceDouble implements FloodVigilanceSource {
  final List<Completer<FloodVigilanceMap>> pending =
      <Completer<FloodVigilanceMap>>[];

  int get calls => pending.length;

  Completer<FloodVigilanceMap> get last => pending.last;

  @override
  Future<FloodVigilanceMap> current() {
    final Completer<FloodVigilanceMap> c = Completer<FloodVigilanceMap>();
    pending.add(c);
    return c.future;
  }
}

FloodSection _section(
  String code,
  FloodVigilanceLevel level,
  List<GeoPoint> line,
) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: '8',
  level: level,
  lines: <List<GeoPoint>>[line],
);

/// Un tronçon jaune et un vert, tous deux dans [_inside].
FloodVigilanceMap _map() => FloodVigilanceMap(
  informationDate: DateTime.utc(2026, 10, 14, 13, 55),
  sections: <FloodSection>[
    _section('J1', const Jaune(), <GeoPoint>[
      GeoPoint(latitude: 45, longitude: 3),
      GeoPoint(latitude: 45.1, longitude: 3.1),
    ]),
    _section('V1', const Vert(), <GeoPoint>[
      GeoPoint(latitude: 45.05, longitude: 2.95),
      GeoPoint(latitude: 45.05, longitude: 3.15),
    ]),
  ],
  skippedEntities: 0,
);

final Bounds _inside = Bounds(west: 2.9, south: 44.9, east: 3.2, north: 45.2);
final Bounds _outside = Bounds(west: 10, south: 50, east: 11, north: 51);

/// Les étiquettes attendues, lues dans la règle du domaine.
List<(FloodSection, GeoPoint)> _expected(
  FloodVigilanceMap map,
  Bounds bounds, {
  required bool individualLevel,
}) => floodLabelsFor(map.sections, bounds, individualLevel: individualLevel);

List<(FloodSection, GeoPoint)> _pairs(List<FloodLabel> labels) =>
    <(FloodSection, GeoPoint)>[
      for (final FloodLabel l in labels) (l.section, l.anchor),
    ];

void main() {
  test('état initial : NonDemandee, labels vide, aucune emprise', () {
    final FloodLayerViewModel vm = FloodLayerViewModel(source: _SourceDouble());
    expect(vm.state, isA<LectureCruesNonDemandee>());
    expect(vm.labels, isEmpty);
    expect(vm.anySectionInBounds, isNull);
  });

  test('activate : EnCours puis Prete ; labels de floodLabelsFor '
      '(vert caché sous le niveau individuel)', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final List<FloodLayerState> seen = <FloodLayerState>[];
    vm.addListener(() => seen.add(vm.state));

    final Future<void> activation = vm.activate();
    expect(vm.state, isA<LectureCruesEnCours>());
    expect(source.calls, 1);

    final FloodVigilanceMap map = _map();
    source.last.complete(map);
    await activation;
    expect(vm.state, isA<LectureCruesPrete>());
    expect((vm.state as LectureCruesPrete).map, same(map));
    expect(seen.first, isA<LectureCruesEnCours>());
    expect(seen.last, isA<LectureCruesPrete>());

    final Future<void> zoomedOut = vm.onViewportChanged(
      _inside,
      individualLevel: false,
    );
    source.last.complete(map);
    await zoomedOut;
    expect(_pairs(vm.labels), _expected(map, _inside, individualLevel: false));
    expect(vm.labels.map((FloodLabel l) => l.section.code.value), <String>[
      'J1',
    ]);

    final Future<void> zoomedIn = vm.onViewportChanged(
      _inside,
      individualLevel: true,
    );
    source.last.complete(map);
    await zoomedIn;
    expect(_pairs(vm.labels), _expected(map, _inside, individualLevel: true));
    expect(
      vm.labels.map((FloodLabel l) => l.section.code.value).toSet(),
      <String>{'J1', 'V1'},
    );
  });

  test('bloquant de la relecture : une emprise donnée pendant EnCours sert '
      "à l'aboutissement, sans nouveau geste", () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    final Future<void> activation = vm.activate();
    await vm.onViewportChanged(_inside, individualLevel: false);
    expect(vm.labels, isEmpty);
    expect(vm.anySectionInBounds, isNull);

    final FloodVigilanceMap map = _map();
    source.last.complete(map);
    await activation;

    expect(vm.state, isA<LectureCruesPrete>());
    expect(vm.labels, isNotEmpty);
    expect(_pairs(vm.labels), _expected(map, _inside, individualLevel: false));
    expect(vm.anySectionInBounds, isTrue);
    expect(source.calls, 1);
  });

  test('aucune emprise jamais donnée, puis Prete : anySectionInBounds '
      'vaut null (BR-007)', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    final Future<void> activation = vm.activate();
    source.last.complete(_map());
    await activation;

    expect(vm.state, isA<LectureCruesPrete>());
    expect(vm.anySectionInBounds, isNull);
    expect(vm.labels, isEmpty);
  });

  test('hors de l\'emprise, Prete : anySectionInBounds == false', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodVigilanceMap map = _map();

    final Future<void> activation = vm.activate();
    source.last.complete(map);
    await activation;

    final Future<void> moved = vm.onViewportChanged(
      _outside,
      individualLevel: true,
    );
    source.last.complete(map);
    await moved;

    expect(vm.state, isA<LectureCruesPrete>());
    expect(vm.anySectionInBounds, isFalse);
    expect(vm.labels, isEmpty);
  });

  test('Review Focus 2 : activate trois fois et onViewportChanged deux fois '
      'pendant le chargement → un seul appel à la source', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    final Future<void> first = vm.activate();
    unawaited(vm.activate());
    unawaited(vm.onViewportChanged(_inside, individualLevel: false));
    unawaited(vm.activate());
    unawaited(vm.onViewportChanged(_outside, individualLevel: true));
    expect(source.calls, 1);
    expect(vm.state, isA<LectureCruesEnCours>());

    source.last.complete(_map());
    await first;
    expect(vm.state, isA<LectureCruesPrete>());
    expect(source.calls, 1);
    // La dernière emprise retenue est celle du second geste.
    expect(vm.anySectionInBounds, isFalse);
  });

  test(
    'échec au premier chargement → EnEchec ; onViewportChanged puis '
    'activate ne relancent rien ; retry → EnCours, un appel, Prete',
    () async {
      final _SourceDouble source = _SourceDouble();
      final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
      const VigilanceInjoignable failure = VigilanceInjoignable('réseau coupé');

      final Future<void> activation = vm.activate();
      source.last.completeError(failure);
      await activation;
      expect(vm.state, isA<LectureCruesEnEchec>());
      expect((vm.state as LectureCruesEnEchec).cause, failure);
      expect(vm.labels, isEmpty);
      expect(vm.anySectionInBounds, isNull);

      await vm.onViewportChanged(_inside, individualLevel: false);
      await vm.activate();
      expect(source.calls, 1);
      expect(vm.state, isA<LectureCruesEnEchec>());
      expect(vm.anySectionInBounds, isNull);

      final Future<void> retried = vm.retry();
      expect(vm.state, isA<LectureCruesEnCours>());
      expect(source.calls, 2);

      source.last.complete(_map());
      await retried;
      expect(vm.state, isA<LectureCruesPrete>());
      expect(source.calls, 2);
      // L'emprise donnée pendant EnEchec est la dernière retenue.
      expect(vm.anySectionInBounds, isTrue);
    },
  );

  test('retry hors EnEchec ne fait rien', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    await vm.retry();
    expect(vm.state, isA<LectureCruesNonDemandee>());
    expect(source.calls, 0);

    final Future<void> activation = vm.activate();
    await vm.retry();
    expect(source.calls, 1);
    source.last.complete(_map());
    await activation;

    await vm.retry();
    expect(source.calls, 1);
    expect(vm.state, isA<LectureCruesPrete>());
  });

  test('Review Focus 4 : Prete, puis une relecture qui lève → l\'état reste '
      'Prete avec l\'ancienne carte', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodVigilanceMap map = _map();

    final Future<void> activation = vm.activate();
    source.last.complete(map);
    await activation;

    int notified = 0;
    vm.addListener(() => notified++);

    final Future<void> reread = vm.activate();
    expect(vm.state, isA<LectureCruesPrete>());
    expect(source.calls, 2);
    source.last.completeError(const VigilanceInjoignable('31e minute'));
    await reread;

    expect(vm.state, isA<LectureCruesPrete>());
    expect((vm.state as LectureCruesPrete).map, same(map));
    expect(notified, 0);

    final Future<void> gesture = vm.onViewportChanged(
      _inside,
      individualLevel: false,
    );
    expect(source.calls, 3);
    source.last.completeError(const VigilanceInjoignable('toujours coupé'));
    await gesture;
    expect(vm.state, isA<LectureCruesPrete>());
    expect((vm.state as LectureCruesPrete).map, same(map));
    expect(vm.anySectionInBounds, isTrue);
  });

  test('relecture qui rend la même instance → aucune notification ; une '
      'nouvelle instance → notification et nouvelle carte', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodVigilanceMap map = _map();

    final Future<void> activation = vm.activate();
    source.last.complete(map);
    await activation;

    int notified = 0;
    vm.addListener(() => notified++);

    final Future<void> same1 = vm.activate();
    source.last.complete(map);
    await same1;
    expect(notified, 0);
    expect((vm.state as LectureCruesPrete).map, same(map));

    final FloodVigilanceMap fresher = _map();
    final Future<void> fresh = vm.activate();
    source.last.complete(fresher);
    await fresh;
    expect(notified, 1);
    expect((vm.state as LectureCruesPrete).map, same(fresher));
  });

  test('une nouvelle carte recalcule labels sur la dernière emprise', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodVigilanceMap map = _map();

    final Future<void> activation = vm.activate();
    source.last.complete(map);
    await activation;

    final Future<void> gesture = vm.onViewportChanged(
      _inside,
      individualLevel: false,
    );
    final FloodVigilanceMap fresher = _map();
    source.last.complete(fresher);
    await gesture;

    expect((vm.state as LectureCruesPrete).map, same(fresher));
    expect(vm.labels.single.section.code.value, 'J1');
    expect(vm.labels.single.section, same(fresher.sections.first));
  });

  test(
    'onViewportChanged en Prete : notifie quand labels change, pas sinon',
    () async {
      final _SourceDouble source = _SourceDouble();
      final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
      final FloodVigilanceMap map = _map();

      final Future<void> activation = vm.activate();
      source.last.complete(map);
      await activation;

      int notified = 0;
      vm.addListener(() => notified++);

      final Future<void> g1 = vm.onViewportChanged(
        _inside,
        individualLevel: false,
      );
      expect(notified, 1);
      source.last.complete(map);
      await g1;
      expect(notified, 1);

      final Future<void> g2 = vm.onViewportChanged(
        _inside,
        individualLevel: false,
      );
      source.last.complete(map);
      await g2;
      expect(notified, 1);
    },
  );

  test('une lecture dépassée par une plus récente n\'écrit rien', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodVigilanceMap map = _map();

    final Future<void> activation = vm.activate();
    source.last.complete(map);
    await activation;

    final Future<void> older = vm.activate();
    final Completer<FloodVigilanceMap> olderRead = source.last;
    final Future<void> newer = vm.activate();
    final FloodVigilanceMap newest = _map();
    source.last.complete(newest);
    await newer;

    olderRead.complete(_map());
    await older;
    expect((vm.state as LectureCruesPrete).map, same(newest));
  });

  test('lecture qui aboutit après dispose : rien n\'est écrit, aucune '
      'exception', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    final Future<void> activation = vm.activate();
    vm.dispose();
    source.last.complete(_map());
    await activation;
    expect(vm.state, isA<LectureCruesEnCours>());
  });

  test('échec qui aboutit après dispose : rien n\'est écrit, aucune '
      'exception', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);

    final Future<void> activation = vm.activate();
    vm.dispose();
    source.last.completeError(const VigilanceIllisible('après coup'));
    await activation;
    expect(vm.state, isA<LectureCruesEnCours>());
  });

  test('sectionByCode : trouve en Prete, null ailleurs', () async {
    final _SourceDouble source = _SourceDouble();
    final FloodLayerViewModel vm = FloodLayerViewModel(source: source);
    final FloodSectionCode code = FloodSectionCode('J1');

    expect(vm.sectionByCode(code), isNull);

    final Future<void> activation = vm.activate();
    expect(vm.sectionByCode(code), isNull);
    final FloodVigilanceMap map = _map();
    source.last.complete(map);
    await activation;

    expect(vm.sectionByCode(code), same(map.sections.first));
    expect(vm.sectionByCode(FloodSectionCode('absent')), isNull);

    final _SourceDouble failing = _SourceDouble();
    final FloodLayerViewModel failed = FloodLayerViewModel(source: failing);
    final Future<void> failedActivation = failed.activate();
    failing.last.completeError(const VigilanceIllisible('illisible'));
    await failedActivation;
    expect(failed.state, isA<LectureCruesEnEchec>());
    expect(failed.sectionByCode(code), isNull);
  });
}

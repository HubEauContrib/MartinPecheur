import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';

final class _LinksDouble implements ExternalLinkOpener {
  final List<Uri> opened = <Uri>[];
  final List<Completer<bool>> pending = <Completer<bool>>[];

  /// Si non nul, chaque appel attend un `Completer` piloté par le test.
  bool deferred = false;
  bool result = true;

  @override
  Future<bool> open(Uri uri) {
    opened.add(uri);
    if (deferred) {
      final Completer<bool> c = Completer<bool>();
      pending.add(c);
      return c.future;
    }
    return Future<bool>.value(result);
  }
}

FloodSection _section(String code, String territory) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: territory,
  level: const Vert(),
  lines: <List<GeoPoint>>[
    <GeoPoint>[
      GeoPoint(latitude: 45, longitude: 3),
      GeoPoint(latitude: 45.1, longitude: 3.1),
    ],
  ],
);

void main() {
  final DateTime date = DateTime.utc(2026, 10, 14, 13, 55);

  test('open puis close', () {
    final FloodSheetViewModel vm = FloodSheetViewModel(links: _LinksDouble());
    expect(vm.state, isA<FicheTronconFermee>());
    final FloodSection s = _section('A', '8');
    vm.open(s, date);
    final FloodSheetState st = vm.state;
    expect(st, isA<FicheTronconOuverte>());
    st as FicheTronconOuverte;
    expect(st.section, s);
    expect(st.informationDate, date);
    expect(st.unopenedBulletinCount, 0);
    vm.close();
    expect(vm.state, isA<FicheTronconFermee>());
  });

  test('close sur Fermee : aucune notification', () {
    final FloodSheetViewModel vm = FloodSheetViewModel(links: _LinksDouble());
    int n = 0;
    vm.addListener(() => n++);
    vm.close();
    expect(n, 0);
  });

  test('openBulletin : adresse, échecs comptés, réussite sans effet', () async {
    final _LinksDouble links = _LinksDouble();
    final FloodSheetViewModel vm = FloodSheetViewModel(links: links);
    vm.open(_section('A', '8'), date);
    links.result = false;
    int notified = 0;
    vm.addListener(() => notified++);
    await vm.openBulletin();
    await vm.openBulletin();
    expect(
      links.opened.first,
      Uri.parse('https://www.vigicrues.gouv.fr/bulletin_local/8'),
    );
    expect(notified, 2);
    expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 2);
    links.result = true;
    await vm.openBulletin();
    expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 2);
  });

  test('openBulletin sur Fermee : rien', () async {
    final _LinksDouble links = _LinksDouble();
    await FloodSheetViewModel(links: links).openBulletin();
    expect(links.opened, isEmpty);
  });

  test(
    'réponse tardive après l\'ouverture d\'un autre tronçon : ignorée',
    () async {
      final _LinksDouble links = _LinksDouble()..deferred = true;
      final FloodSheetViewModel vm = FloodSheetViewModel(links: links);
      vm.open(_section('A', '8'), date);
      final Future<void> f = vm.openBulletin();
      vm.open(_section('B', '9'), date);
      links.pending.single.complete(false);
      await f;
      expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 0);
    },
  );

  test('réponse tardive après close : ignorée', () async {
    final _LinksDouble links = _LinksDouble()..deferred = true;
    final FloodSheetViewModel vm = FloodSheetViewModel(links: links);
    vm.open(_section('A', '8'), date);
    final Future<void> f = vm.openBulletin();
    vm.close();
    int n = 0;
    vm.addListener(() => n++);
    links.pending.single.complete(false);
    await f;
    expect(vm.state, isA<FicheTronconFermee>());
    expect(n, 0);
  });

  test(
    'close puis réouverture du même tronçon : réponse tardive ignorée',
    () async {
      final _LinksDouble links = _LinksDouble()..deferred = true;
      final FloodSheetViewModel vm = FloodSheetViewModel(links: links);
      final FloodSection s = _section('A', '8');
      vm.open(s, date);
      final Future<void> f = vm.openBulletin();
      vm.close();
      vm.open(s, date);
      links.pending.single.complete(false);
      await f;
      expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 0);
    },
  );

  test('deux liens en vol sur la même fiche : deux échecs comptés', () async {
    final _LinksDouble links = _LinksDouble()..deferred = true;
    final FloodSheetViewModel vm = FloodSheetViewModel(links: links);
    vm.open(_section('A', '8'), date);
    final Future<void> f1 = vm.openBulletin();
    final Future<void> f2 = vm.openBulletin();
    links.pending[0].complete(false);
    links.pending[1].complete(false);
    await f1;
    await f2;
    expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 2);
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

import '../../../support/in_memory_favorite_repository.dart';
import '../../../support/in_memory_follow_up_repository.dart';

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

FloodSheetViewModel _make({
  _LinksDouble? links,
  InMemoryFavoriteRepository? favorites,
  InMemoryFollowUpRepository? followUps,
  DateTime Function()? now,
}) => FloodSheetViewModel(
  links: links ?? _LinksDouble(),
  favorites: favorites ?? InMemoryFavoriteRepository(),
  followUps: followUps ?? InMemoryFollowUpRepository(),
  now: now,
);

void main() {
  final DateTime date = DateTime.utc(2026, 10, 14, 13, 55);

  test('open puis close', () {
    final FloodSheetViewModel vm = _make(links: _LinksDouble());
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
    final FloodSheetViewModel vm = _make(links: _LinksDouble());
    int n = 0;
    vm.addListener(() => n++);
    vm.close();
    expect(n, 0);
  });

  test('openBulletin : adresse, échecs comptés, réussite sans effet', () async {
    final _LinksDouble links = _LinksDouble();
    final FloodSheetViewModel vm = _make(links: links);
    vm.open(_section('A', '8'), date);
    // La lecture des favoris et du suivi notifie une fois ses réponses reçues
    // (V1 de T5) : on la laisse finir avant de compter les échecs de lien.
    await pumpEventQueue();
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
    await _make(links: links).openBulletin();
    expect(links.opened, isEmpty);
  });

  test(
    'réponse tardive après l\'ouverture d\'un autre tronçon : ignorée',
    () async {
      final _LinksDouble links = _LinksDouble()..deferred = true;
      final FloodSheetViewModel vm = _make(links: links);
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
    final FloodSheetViewModel vm = _make(links: links);
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
      final FloodSheetViewModel vm = _make(links: links);
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
    final FloodSheetViewModel vm = _make(links: links);
    vm.open(_section('A', '8'), date);
    final Future<void> f1 = vm.openBulletin();
    final Future<void> f2 = vm.openBulletin();
    links.pending[0].complete(false);
    links.pending[1].complete(false);
    await f1;
    await f2;
    expect((vm.state as FicheTronconOuverte).unopenedBulletinCount, 2);
  });

  // ------------------------------------------------------------------------
  // V1 de T5 : l'étoile de favori, le seuil « Me prévenir », le tronçon absent.
  // ------------------------------------------------------------------------
  group('étoile, seuil et tronçon absent (V1 de T5)', () {
    final DateTime now = DateTime.utc(2026, 10, 21, 8);
    final FloodSectionCode codeA = FloodSectionCode('A');
    final FloodSectionPlace placeA = FloodSectionPlace(codeA);
    final FloodSectionFavorite favoriteA = FloodSectionFavorite(
      code: codeA,
      name: 'Tronçon A',
      addedAt: DateTime.utc(2026, 9, 1),
    );
    const FavoriteStar filledActive = FavoriteStar(filled: true, enabled: true);
    const FavoriteStar emptyActive = FavoriteStar(filled: false, enabled: true);

    FloodFollowUp orangeFollowUp() =>
        FloodFollowUp(place: placeA, threshold: FloodThreshold.orange);

    InMemoryFollowUpRepository followUpsWith(List<FollowUp> followUps) =>
        InMemoryFollowUpRepository(FollowUpBook(followUps: followUps));

    Future<FloodSheetViewModel> opened({
      InMemoryFavoriteRepository? favorites,
      InMemoryFollowUpRepository? followUps,
    }) async {
      final FloodSheetViewModel vm = _make(
        favorites: favorites,
        followUps: followUps,
        now: () => now,
      );
      vm.open(_section('A', '8'), date);
      await pumpEventQueue();
      return vm;
    }

    group('étoile', () {
      test('avant la fin des lectures : ni étoile ni choix', () {
        final FloodSheetViewModel vm = _make(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
        );
        expect(vm.favoriteStar, isNull);
        vm.open(_section('A', '8'), date);
        expect(vm.favoriteStar, isNull);
        expect(vm.followUpChoice, isNull);
      });

      test('fiche fermée : pas d\'étoile', () async {
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
        );
        vm.close();
        expect(vm.favoriteStar, isNull);
        expect(vm.followUpChoice, isNull);
      });

      test('l\'étoile est pleine si le tronçon est en favori', () async {
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
        );
        expect(vm.favoriteStar, filledActive);
      });

      test('l\'étoile est vide si le tronçon n\'y est pas', () async {
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[
            FloodSectionFavorite(
              code: FloodSectionCode('B'),
              name: 'Tronçon B',
              addedAt: DateTime.utc(2026, 9, 1),
            ),
          ]),
        );
        expect(vm.favoriteStar, emptyActive);
      });

      test('ajout : le favori porte le code, le nom publié et la date '
          'd\'ajout en UTC', () async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        await vm.toggleFavorite();
        expect(favorites.stored, hasLength(1));
        final Favorite stored = favorites.stored.single;
        expect(stored, isA<FloodSectionFavorite>());
        stored as FloodSectionFavorite;
        expect(stored.code, codeA);
        expect(stored.name, 'Tronçon A');
        expect(stored.addedAt, now);
        expect(stored.addedAt.isUtc, isTrue);
        expect(vm.favoriteStar, filledActive);
      });

      test('retrait : le favori part et l\'étoile se vide', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        await vm.toggleFavorite();
        expect(favorites.stored, isEmpty);
        expect(vm.favoriteStar, emptyActive);
      });

      test('le retrait éteint le suivi du tronçon', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(
          favorites: favorites,
          followUps: followUps,
        );
        await vm.toggleFavorite();
        expect(followUps.stored.followUps, isEmpty);
        expect(vm.followUpChoice, isNull);
      });

      test(
        'le retrait réussit même si l\'extinction du suivi échoue',
        () async {
          final InMemoryFavoriteRepository favorites =
              InMemoryFavoriteRepository(<Favorite>[favoriteA]);
          final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
            orangeFollowUp(),
          ]);
          final FloodSheetViewModel vm = await opened(
            favorites: favorites,
            followUps: followUps,
          );
          followUps.writeError = const EcritureDuSuiviEnEchec('refus');
          await vm.toggleFavorite();
          expect(favorites.stored, isEmpty);
          expect(vm.favoriteStar, emptyActive);
        },
      );

      test('PD20 : un suivi resté d\'un ancien favori ne revient jamais — '
          'l\'ajout l\'éteint et « Me prévenir » est sur « Non »', () async {
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(followUps: followUps);
        expect(vm.followUpChoice, isNull, reason: 'pas en favori');
        await vm.toggleFavorite();
        expect(followUps.stored.followUps, isEmpty);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(selected: null, enabled: true),
        );
      });

      test('l\'ajout réussit même si l\'extinction du suivi échoue : le '
          'réglage dit le seuil stocké et porte writeFailed, qui retombe au '
          'prochain choix réussi', () async {
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(followUps: followUps);
        followUps.writeError = const EcritureDuSuiviEnEchec('refus');
        await vm.toggleFavorite();
        expect(
          vm.favoriteStar,
          filledActive,
          reason: 'étoile sans writeFailed',
        );
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: FloodThreshold.orange,
            enabled: true,
            writeFailed: true,
          ),
          reason:
              'le suivi stocké reste dit tel qu\'il est, et l\'échec se dit',
        );
        followUps.writeError = null;
        await vm.chooseThreshold(FloodThreshold.rouge);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: FloodThreshold.rouge,
            enabled: true,
          ),
        );
      });

      test('liste illisible : étoile inactive, aucune écriture', () async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository()
              ..readError = const ListeDeFavorisIllisible('x');
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        expect(
          vm.favoriteStar,
          const FavoriteStar(filled: false, enabled: false),
        );
        await vm.toggleFavorite();
        expect(favorites.writeCalls, 0);
        expect(vm.followUpChoice, isNull);
      });

      test('échec d\'écriture du favori : writeFailed, forme gardée, '
          'puis réussite qui l\'efface', () async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository()
              ..writeError = const EcritureDeFavorisEnEchec('x');
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        await vm.toggleFavorite();
        expect(
          vm.favoriteStar,
          const FavoriteStar(filled: false, enabled: true, writeFailed: true),
        );
        favorites.writeError = null;
        await vm.toggleFavorite();
        expect(vm.favoriteStar, filledActive);
      });

      test('pendant l\'écriture : étoile inactive, un second toucher est '
          'ignoré', () async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        final Completer<void> gate = Completer<void>();
        favorites.writeGate = gate;
        final Future<void> first = vm.toggleFavorite();
        expect(
          vm.favoriteStar,
          const FavoriteStar(filled: false, enabled: false),
        );
        await vm.toggleFavorite();
        expect(favorites.writeCalls, 1);
        gate.complete();
        await first;
        expect(vm.favoriteStar, filledActive);
      });

      test(
        'basculer l\'étoile notifie mais ne remplace jamais l\'état',
        () async {
          final FloodSheetViewModel vm = await opened();
          final FloodSheetState before = vm.state;
          int n = 0;
          vm.addListener(() => n++);
          await vm.toggleFavorite();
          expect(n, greaterThan(0));
          expect(identical(vm.state, before), isTrue);
        },
      );
    });

    group('choix du seuil', () {
      test('hors favori : null', () async {
        final FloodSheetViewModel vm = await opened();
        expect(vm.followUpChoice, isNull);
      });

      test('en favori sans suivi : « Non », actif', () async {
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
        );
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(selected: null, enabled: true),
        );
      });

      test('en favori avec un suivi orange stocké : orange', () async {
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUpsWith(<FollowUp>[orangeFollowUp()]),
        );
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: FloodThreshold.orange,
            enabled: true,
          ),
        );
      });

      test('choisir orange écrit le suivi orange', () async {
        final InMemoryFollowUpRepository followUps =
            InMemoryFollowUpRepository();
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        await vm.chooseThreshold(FloodThreshold.orange);
        expect(followUps.stored.followUps, <FollowUp>[
          FloodFollowUp(place: placeA, threshold: FloodThreshold.orange),
        ]);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: FloodThreshold.orange,
            enabled: true,
          ),
        );
      });

      test('changer de seuil remplace le seuil', () async {
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        await vm.chooseThreshold(FloodThreshold.rouge);
        expect(
          (followUps.stored.followUps.single as FloodFollowUp).threshold,
          FloodThreshold.rouge,
        );
      });

      test('choisir « Non » éteint le suivi', () async {
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        await vm.chooseThreshold(null);
        expect(followUps.stored.followUps, isEmpty);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(selected: null, enabled: true),
        );
      });

      test('le choix déjà fait : aucune écriture', () async {
        final InMemoryFollowUpRepository followUps = followUpsWith(<FollowUp>[
          orangeFollowUp(),
        ]);
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        await vm.chooseThreshold(FloodThreshold.orange);
        expect(followUps.writeCalls, 0);

        final InMemoryFollowUpRepository empty = InMemoryFollowUpRepository();
        final FloodSheetViewModel off = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: empty,
        );
        await off.chooseThreshold(null);
        expect(empty.writeCalls, 0);
      });

      test('hors favori : choisir un seuil ne fait rien', () async {
        final InMemoryFollowUpRepository followUps =
            InMemoryFollowUpRepository();
        final FloodSheetViewModel vm = await opened(followUps: followUps);
        await vm.chooseThreshold(FloodThreshold.jaune);
        expect(followUps.writeCalls, 0);
      });

      test('échec d\'écriture : writeFailed, choix gardé, puis réussite qui '
          'l\'efface', () async {
        final InMemoryFollowUpRepository followUps =
            InMemoryFollowUpRepository()
              ..writeError = const EcritureDuSuiviEnEchec('x');
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        await vm.chooseThreshold(FloodThreshold.jaune);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: null,
            enabled: true,
            writeFailed: true,
          ),
        );
        followUps.writeError = null;
        await vm.chooseThreshold(FloodThreshold.jaune);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(
            selected: FloodThreshold.jaune,
            enabled: true,
          ),
        );
      });

      test('suivi illisible : choix inactif, aucune écriture', () async {
        final InMemoryFollowUpRepository followUps =
            InMemoryFollowUpRepository()..readError = const SuiviIllisible('x');
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(selected: null, enabled: false),
        );
        await vm.chooseThreshold(FloodThreshold.rouge);
        expect(followUps.writeCalls, 0);
        expect(vm.favoriteStar, filledActive, reason: 'l\'étoile reste');
      });

      test('pendant l\'écriture : choix inactif, un second choix est '
          'ignoré', () async {
        final InMemoryFollowUpRepository followUps =
            InMemoryFollowUpRepository();
        final FloodSheetViewModel vm = await opened(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          followUps: followUps,
        );
        final Completer<void> gate = Completer<void>();
        followUps.writeGate = gate;
        final Future<void> first = vm.chooseThreshold(FloodThreshold.jaune);
        expect(vm.followUpChoice!.enabled, isFalse);
        await vm.chooseThreshold(FloodThreshold.rouge);
        expect(followUps.writeCalls, 1);
        gate.complete();
        await first;
        expect(vm.followUpChoice!.selected, FloodThreshold.jaune);
      });

      test(
        'choisir un seuil notifie mais ne remplace jamais l\'état',
        () async {
          final FloodSheetViewModel vm = await opened(
            favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          );
          final FloodSheetState before = vm.state;
          int n = 0;
          vm.addListener(() => n++);
          await vm.chooseThreshold(FloodThreshold.jaune);
          expect(n, greaterThan(0));
          expect(identical(vm.state, before), isTrue);
        },
      );

      test('FloodFollowUpChoice : égalité par valeur', () {
        expect(
          const FloodFollowUpChoice(selected: null, enabled: true),
          const FloodFollowUpChoice(selected: null, enabled: true),
        );
        expect(
          const FloodFollowUpChoice(selected: null, enabled: true),
          isNot(const FloodFollowUpChoice(selected: null, enabled: false)),
        );
        expect(
          const FloodFollowUpChoice(selected: null, enabled: true),
          isNot(
            const FloodFollowUpChoice(
              selected: null,
              enabled: true,
              writeFailed: true,
            ),
          ),
        );
        expect(
          const FloodFollowUpChoice(
            selected: FloodThreshold.jaune,
            enabled: true,
          ),
          isNot(const FloodFollowUpChoice(selected: null, enabled: true)),
        );
        expect(
          const FloodFollowUpChoice(
            selected: FloodThreshold.rouge,
            enabled: true,
          ).hashCode,
          const FloodFollowUpChoice(
            selected: FloodThreshold.rouge,
            enabled: true,
          ).hashCode,
        );
      });
    });

    group('tronçon absent', () {
      test('openAbsent donne l\'état absent, daté, au nom copié', () {
        final FloodSheetViewModel vm = _make();
        vm.openAbsent(favoriteA, date);
        final FloodSheetState st = vm.state;
        expect(st, isA<FicheTronconAbsente>());
        st as FicheTronconAbsente;
        expect(st.code, codeA);
        expect(st.name, 'Tronçon A');
        expect(st.informationDate, date);
      });

      test('l\'étoile y est disponible et pleine', () async {
        final FloodSheetViewModel vm = _make(
          favorites: InMemoryFavoriteRepository(<Favorite>[favoriteA]),
          now: () => now,
        );
        vm.openAbsent(favoriteA, date);
        expect(vm.favoriteStar, isNull, reason: 'pas avant la lecture');
        await pumpEventQueue();
        expect(vm.favoriteStar, filledActive);
        expect(
          vm.followUpChoice,
          const FloodFollowUpChoice(selected: null, enabled: true),
        );
      });

      test('retirer l\'étoile la laisse, vide, et le tronçon peut être '
          'ré-ajouté sous son nom copié', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final FloodSheetViewModel vm = _make(
          favorites: favorites,
          now: () => now,
        );
        vm.openAbsent(favoriteA, date);
        await pumpEventQueue();
        await vm.toggleFavorite();
        expect(favorites.stored, isEmpty);
        expect(vm.favoriteStar, emptyActive);
        expect(vm.state, isA<FicheTronconAbsente>());
        await vm.toggleFavorite();
        final FloodSectionFavorite again =
            favorites.stored.single as FloodSectionFavorite;
        expect(again.code, codeA);
        expect(again.name, 'Tronçon A');
        expect(again.addedAt, now);
      });

      test('close referme l\'état absent', () {
        final FloodSheetViewModel vm = _make();
        vm.openAbsent(favoriteA, date);
        vm.close();
        expect(vm.state, isA<FicheTronconFermee>());
        expect(vm.favoriteStar, isNull);
      });

      test('openBulletin sur un tronçon absent : rien', () async {
        final _LinksDouble links = _LinksDouble();
        final FloodSheetViewModel vm = _make(links: links);
        vm.openAbsent(favoriteA, date);
        await vm.openBulletin();
        expect(links.opened, isEmpty);
      });
    });

    group('générations', () {
      test('une ouverture plus récente l\'emporte sur une lecture lente des '
          'favoris', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final FloodSheetViewModel vm = _make(favorites: favorites);
        final Completer<void> gate = Completer<void>();
        favorites.readGate = gate;
        vm.open(_section('A', '8'), date);
        favorites.readGate = null;
        vm.open(_section('B', '9'), date);
        await pumpEventQueue();
        expect(vm.favoriteStar, emptyActive, reason: 'B n\'est pas en favori');
        gate.complete();
        await pumpEventQueue();
        expect(vm.favoriteStar, emptyActive);
        expect(
          (vm.state as FicheTronconOuverte).section.code,
          FloodSectionCode('B'),
        );
      });

      test('une lecture lente arrivée après close n\'écrit rien', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final FloodSheetViewModel vm = _make(favorites: favorites);
        final Completer<void> gate = Completer<void>();
        favorites.readGate = gate;
        vm.open(_section('A', '8'), date);
        vm.close();
        int n = 0;
        vm.addListener(() => n++);
        gate.complete();
        await pumpEventQueue();
        expect(vm.favoriteStar, isNull);
        expect(n, 0);
      });

      test('une écriture lente arrivée après la fermeture n\'écrit rien dans '
          'la fiche suivante', () async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final FloodSheetViewModel vm = await opened(favorites: favorites);
        final Completer<void> gate = Completer<void>();
        favorites.writeGate = gate;
        final Future<void> write = vm.toggleFavorite();
        vm.close();
        vm.open(_section('B', '9'), date);
        await pumpEventQueue();
        gate.complete();
        await write;
        expect(vm.favoriteStar, emptyActive, reason: 'B n\'est pas en favori');
      });

      test('après dispose, une lecture lente ne notifie plus', () async {
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[favoriteA],
        );
        final FloodSheetViewModel vm = _make(favorites: favorites);
        final Completer<void> gate = Completer<void>();
        favorites.readGate = gate;
        vm.open(_section('A', '8'), date);
        vm.dispose();
        gate.complete();
        await pumpEventQueue();
        // Aucune exception : notifyListeners après dispose lèverait.
      });
    });
  });
}

// ViewModel de l'écran « Avis reçus » (V4 de T5) : le seul chemin vers la
// vérification (PD6), l'annonce de la carte (PD19, Q2), la lecture et la
// fermeture de l'écran, les gestes « Repartir… » et le lien Vigicrues.
//
// Testé sans rendu, sur un VRAI `FollowUpCheck` construit sur les doubles en
// mémoire : `check()` passe par `run()`, rien d'autre.
//
// Les niveaux de vigilance lus ici sont des cas construits, jamais observés en
// production — `VC-04`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_check.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/notices/view_model/notices_view_model.dart';

import '../../../support/in_memory_favorite_repository.dart';
import '../../../support/in_memory_follow_up_repository.dart';
import '../../../support/in_memory_notice_repository.dart';

final DateTime _now = DateTime.utc(2026, 10, 21, 10, 30);
final DateTime _added = DateTime.utc(2026, 10, 1);
final DateTime _info = DateTime.utc(2026, 10, 21, 6);
final DateTime _lastCheck = DateTime.utc(2026, 10, 20, 18);

final FloodSectionCode _code = FloodSectionCode('AG1');
final FloodSectionPlace _place = FloodSectionPlace(_code);
final FloodSectionFavorite _favorite = FloodSectionFavorite(
  code: _code,
  name: 'Garonne amont',
  addedAt: _added,
);

/// Un tronçon suivi jamais lu : la vérification donne « Suivi commencé ».
FloodFollowUp _neverRead() =>
    FloodFollowUp(place: _place, threshold: FloodThreshold.orange);

/// Un tronçon suivi déjà lu en jaune : relu en jaune, aucun avis.
FloodFollowUp _readYellow() => FloodFollowUp(
  place: _place,
  threshold: FloodThreshold.orange,
  lastKnown: LastKnownFloodLevel(level: const Jaune(), informationDate: _info),
);

FloodVigilanceMap _yellowMap() => FloodVigilanceMap(
  informationDate: _info,
  sections: <FloodSection>[
    FloodSection(
      code: _code,
      name: 'Garonne amont',
      territoryCode: '10',
      level: const Jaune(),
      lines: <List<GeoPoint>>[
        <GeoPoint>[
          GeoPoint(latitude: 44, longitude: 1),
          GeoPoint(latitude: 44.1, longitude: 1.1),
        ],
      ],
    ),
  ],
  skippedEntities: 0,
);

/// Un avis déjà stocké, non lu sauf mention.
PlaceNotVerifiable _stored(String label, {bool read = false}) =>
    PlaceNotVerifiable(
      placeLabel: label,
      reason: const StationAbsent(),
      receivedAt: DateTime.utc(2026, 10, 19),
      read: read,
    );

final class _FloodSource implements FloodVigilanceSource {
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<FloodVigilanceMap> current() async {
    calls++;
    await gate?.future;
    return _yellowMap();
  }
}

/// Aucun lieu de sécheresse n'est suivi dans ces cas : un appel est une faute.
final class _NoRestrictions implements RestrictionSource {
  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) =>
      throw StateError('aucune restriction ne doit être lue');
}

final class _NoStations implements StationRepository {
  @override
  Future<Station?> findByCode(StationCode code) =>
      throw StateError('aucune station ne doit être lue');
}

final class _Links implements ExternalLinkOpener {
  bool result = true;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

final class _Fixture {
  _Fixture({
    List<Favorite>? favorites,
    List<FollowUp>? followUps,
    List<ReceivedNotice> notices = const <ReceivedNotice>[],
    DateTime? lastCheckAt,
  }) : favorites = InMemoryFavoriteRepository(
         favorites ?? <Favorite>[_favorite],
       ),
       followUps = InMemoryFollowUpRepository(
         FollowUpBook(
           followUps: followUps ?? <FollowUp>[_neverRead()],
           lastCheckAt: lastCheckAt,
         ),
       ),
       notices = InMemoryNoticeRepository(notices);

  final InMemoryFavoriteRepository favorites;
  final InMemoryFollowUpRepository followUps;
  final InMemoryNoticeRepository notices;
  late final _GatedNotices gatedNotices = _GatedNotices(notices);
  final _FloodSource floods = _FloodSource();
  final _Links links = _Links();

  /// L'horloge de la vérification ; une horloge qui lève fait lever `run()`.
  DateTime Function() clock = () => _now;

  late final NoticesViewModel viewModel = NoticesViewModel(
    notices: gatedNotices,
    followUps: followUps,
    favorites: favorites,
    check: FollowUpCheck(
      favorites: favorites,
      followUps: followUps,
      notices: gatedNotices,
      floods: floods,
      restrictions: _NoRestrictions(),
      stations: _NoStations(),
      now: () => clock(),
    ),
    links: links,
  );
}

/// Délègue au double en mémoire. Armée par [holdNextReadAfterWrite], la
/// première lecture qui suit un `addAll` attend [release] ; [held] aboutit
/// quand elle s'arrête.
final class _GatedNotices implements NoticeRepository {
  _GatedNotices(this._inner);

  final InMemoryNoticeRepository _inner;
  bool _armed = false;
  bool _wrote = false;
  Completer<void>? held;
  Completer<void>? release;

  void holdNextReadAfterWrite() {
    _armed = true;
    held = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<List<ReceivedNotice>> readAll() async {
    if (_armed && _wrote) {
      _armed = false;
      held!.complete();
      await release!.future;
    }
    return _inner.readAll();
  }

  @override
  Future<void> addAll(List<ReadableNotice> notices) async {
    await _inner.addAll(notices);
    _wrote = true;
  }

  @override
  Future<void> markAllRead() => _inner.markAllRead();

  @override
  Future<void> clear() => _inner.clear();
}

void main() {
  group('Les états de l’écran', () {
    test('avant toute lecture : AvisFermes, aucune annonce', () {
      final _Fixture f = _Fixture();
      expect(f.viewModel.state, isA<AvisFermes>());
      expect(f.viewModel.announcement, isNull);
      expect(f.viewModel.checking, isFalse);
      expect(f.viewModel.lastCheckNotRecorded, isFalse);
      expect(f.viewModel.unopenedLinkCount, 0);
    });

    test('load() passe par AvisEnLecture', () async {
      final _Fixture f = _Fixture();
      final List<NoticesState> seen = <NoticesState>[];
      f.viewModel.addListener(() => seen.add(f.viewModel.state));
      await f.viewModel.load();
      expect(seen.first, isA<AvisEnLecture>());
      expect(seen.last, isA<AvisPrets>());
    });

    test('aucun lieu suivi : followsAnyPlace faux', () async {
      final _Fixture f = _Fixture(followUps: <FollowUp>[]);
      await f.viewModel.load();
      final AvisPrets state = f.viewModel.state as AvisPrets;
      expect(state.followsAnyPlace, isFalse);
      expect(state.favoritesUnreadable, isFalse);
    });

    test(
      'un suivi sans son favori ne compte pas : followsAnyPlace faux',
      () async {
        final _Fixture f = _Fixture(favorites: <Favorite>[]);
        await f.viewModel.load();
        expect((f.viewModel.state as AvisPrets).followsAnyPlace, isFalse);
      },
    );

    test('un tronçon suivi en favori : followsAnyPlace vrai', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      expect((f.viewModel.state as AvisPrets).followsAnyPlace, isTrue);
    });

    test(
      'favoris illisibles : favoritesUnreadable vrai, followsAnyPlace faux',
      () async {
        final _Fixture f = _Fixture();
        f.favorites.readError = const ListeDeFavorisIllisible('test');
        await f.viewModel.load();
        final AvisPrets state = f.viewModel.state as AvisPrets;
        expect(state.favoritesUnreadable, isTrue);
        expect(state.followsAnyPlace, isFalse);
      },
    );

    test('aucun avis : une liste vide, sans dernière vérification', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      final AvisPrets state = f.viewModel.state as AvisPrets;
      expect(state.notices, isEmpty);
      expect(state.lastCheckAt, isNull);
    });

    test('avis lus avec lastCheckAt', () async {
      final _Fixture f = _Fixture(
        notices: <ReceivedNotice>[
          _stored('La Loire à Blois', read: true),
          _stored('Le Loir à Vendôme', read: true),
        ],
        lastCheckAt: _lastCheck,
      );
      await f.viewModel.load();
      final AvisPrets state = f.viewModel.state as AvisPrets;
      expect(state.notices, <ReceivedNotice>[
        _stored('La Loire à Blois', read: true),
        _stored('Le Loir à Vendôme', read: true),
      ]);
      expect(state.lastCheckAt, _lastCheck);
    });

    test('avis illisibles : AvisIllisibles', () async {
      final _Fixture f = _Fixture();
      f.notices.readError = const ListeDAvisIllisible('test');
      await f.viewModel.load();
      expect(f.viewModel.state, isA<AvisIllisibles>());
    });

    test('suivi illisible : ReglagesDeSuiviIllisibles', () async {
      final _Fixture f = _Fixture();
      f.followUps.readError = const SuiviIllisible('test');
      await f.viewModel.load();
      expect(f.viewModel.state, isA<ReglagesDeSuiviIllisibles>());
    });
  });

  group('check() — le seul chemin vers la vérification (PD6)', () {
    test('deux appels pendant une vérification : la même, une seule '
        'lecture des sources, un seul jeu d’avis', () async {
      final _Fixture f = _Fixture();
      f.floods.gate = Completer<void>();
      final Future<CheckOutcome> first = f.viewModel.check();
      final Future<CheckOutcome> second = f.viewModel.check();
      expect(identical(first, second), isTrue);
      f.floods.gate!.complete();
      expect(await first, const CheckDone(1));
      expect(await second, const CheckDone(1));
      expect(f.floods.calls, 1);
      expect(f.notices.stored, hasLength(1));
    });

    test('checking vaut vrai pendant la vérification et faux après', () async {
      final _Fixture f = _Fixture();
      f.floods.gate = Completer<void>();
      expect(f.viewModel.checking, isFalse);
      final Future<CheckOutcome> running = f.viewModel.check();
      expect(f.viewModel.checking, isTrue);
      f.floods.gate!.complete();
      await running;
      expect(f.viewModel.checking, isFalse);
    });

    test('checking notifie à son début et à sa fin', () async {
      final _Fixture f = _Fixture();
      f.floods.gate = Completer<void>();
      final List<bool> seen = <bool>[];
      f.viewModel.addListener(() => seen.add(f.viewModel.checking));
      final Future<CheckOutcome> running = f.viewModel.check();
      expect(seen, <bool>[true]);
      f.floods.gate!.complete();
      await running;
      expect(seen.last, isFalse);
    });

    test(
      'une nouvelle vérification part une fois la précédente finie',
      () async {
        final _Fixture f = _Fixture();
        await f.viewModel.check();
        await f.viewModel.check();
        expect(f.floods.calls, 2);
      },
    );
  });

  group('L’annonce de la carte, l’écran fermé', () {
    test('un avis nouveau : NewNoticesAnnouncement(1)', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.check();
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
    });

    test('avec 2 non lus déjà stockés : NewNoticesAnnouncement(3) — les non '
        'lus après la vérification (PD19)', () async {
      final _Fixture f = _Fixture(
        notices: <ReceivedNotice>[
          _stored('La Loire à Blois'),
          _stored('Le Loir à Vendôme'),
          _stored('La Garonne à Toulouse', read: true),
        ],
      );
      expect(await f.viewModel.check(), const CheckDone(1));
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(3));
    });

    test('stockage illisible : UnreadableStorageAnnouncement', () async {
      final _Fixture f = _Fixture();
      f.followUps.readError = const SuiviIllisible('test');
      expect(
        await f.viewModel.check(),
        const CheckBlockedByUnreadableStorage(),
      );
      expect(f.viewModel.announcement, const UnreadableStorageAnnouncement());
    });

    test('favoris illisibles : UnreadableStorageAnnouncement (Q1)', () async {
      final _Fixture f = _Fixture();
      f.favorites.readError = const ListeDeFavorisIllisible('test');
      await f.viewModel.check();
      expect(f.viewModel.announcement, const UnreadableStorageAnnouncement());
    });

    test('écriture des avis en échec : NotRecordedAnnouncement, '
        'lastCheckNotRecorded vrai, puis faux après un CheckDone', () async {
      final _Fixture f = _Fixture();
      f.notices.writeError = const EcritureDAvisEnEchec('test');
      expect(await f.viewModel.check(), const CheckNotRecorded(0));
      expect(f.viewModel.announcement, const NotRecordedAnnouncement());
      expect(f.viewModel.lastCheckNotRecorded, isTrue);

      // Rien n'est perdu : la vérification suivante redonne le même avis.
      f.notices.writeError = null;
      expect(await f.viewModel.check(), const CheckDone(1));
      expect(f.viewModel.lastCheckNotRecorded, isFalse);
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
    });

    test('report en échec après des avis écrits : NewNoticesAnnouncement, '
        'jamais tu ; lastCheckNotRecorded vrai, puis faux après un '
        'CheckDone', () async {
      final _Fixture f = _Fixture();
      f.followUps.writeError = const EcritureDuSuiviEnEchec('test');
      expect(await f.viewModel.check(), const CheckNotRecorded(1));
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
      expect(f.viewModel.lastCheckNotRecorded, isTrue);

      f.followUps.writeError = null;
      expect(await f.viewModel.check(), isA<CheckDone>());
      expect(f.viewModel.lastCheckNotRecorded, isFalse);
    });

    test('lastCheckNotRecorded retombe aussi sur NothingFollowed', () async {
      final _Fixture f = _Fixture();
      f.notices.writeError = const EcritureDAvisEnEchec('test');
      await f.viewModel.check();
      expect(f.viewModel.lastCheckNotRecorded, isTrue);
      f.notices.writeError = null;
      await f.followUps.clear();
      expect(await f.viewModel.check(), const NothingFollowed());
      expect(f.viewModel.lastCheckNotRecorded, isFalse);
    });

    test('CheckDone(0) n’ajoute rien', () async {
      final _Fixture f = _Fixture(followUps: <FollowUp>[_readYellow()]);
      expect(await f.viewModel.check(), const CheckDone(0));
      expect(f.viewModel.announcement, isNull);
    });

    test('CheckDone(0) ne retire rien', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.check();
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
      // Le tronçon est maintenant lu en jaune : relu en jaune, aucun avis.
      expect(await f.viewModel.check(), const CheckDone(0));
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
    });

    test('NothingFollowed ne retire rien', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.check();
      await f.followUps.clear();
      expect(await f.viewModel.check(), const NothingFollowed());
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
    });

    test('dismissAnnouncement() retire l’annonce et notifie', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.check();
      int notified = 0;
      f.viewModel.addListener(() => notified++);
      f.viewModel.dismissAnnouncement();
      expect(f.viewModel.announcement, isNull);
      expect(notified, 1);
    });
  });

  group('L’écran ouvert', () {
    test('load() retire l’annonce', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.check();
      expect(f.viewModel.announcement, isNotNull);
      await f.viewModel.load();
      expect(f.viewModel.announcement, isNull);
    });

    test('un check() ne pose pas d’annonce, et l’état se relit avec les '
        'nouveaux avis', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      expect((f.viewModel.state as AvisPrets).notices, isEmpty);
      expect(await f.viewModel.check(), const CheckDone(1));
      expect(f.viewModel.announcement, isNull);
      final AvisPrets state = f.viewModel.state as AvisPrets;
      expect(state.notices, hasLength(1));
      expect(state.notices.single, isA<FloodFollowUpStarted>());
      expect(state.lastCheckAt, _now);
    });

    test('un stockage illisible, l’écran ouvert : aucune annonce, l’état '
        'se relit', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      f.notices.readError = const ListeDAvisIllisible('test');
      await f.viewModel.check();
      expect(f.viewModel.announcement, isNull);
      expect(f.viewModel.state, isA<AvisIllisibles>());
    });

    test('une écriture en échec, l’écran ouvert : aucune annonce, '
        'lastCheckNotRecorded vrai (Q2)', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      f.notices.writeError = const EcritureDAvisEnEchec('test');
      await f.viewModel.check();
      expect(f.viewModel.announcement, isNull);
      expect(f.viewModel.lastCheckNotRecorded, isTrue);
    });
  });

  group('La fermeture', () {
    test(
      'close() marque tout lu ; la réouverture n’a plus de « Nouveau »',
      () async {
        final _Fixture f = _Fixture(
          notices: <ReceivedNotice>[_stored('La Loire à Blois')],
        );
        await f.viewModel.check();
        await f.viewModel.load();
        final AvisPrets before = f.viewModel.state as AvisPrets;
        expect(
          before.notices.whereType<ReadableNotice>().where(
            (ReadableNotice n) => !n.read,
          ),
          hasLength(2),
        );

        await f.viewModel.close();
        expect(f.viewModel.state, isA<AvisFermes>());

        await f.viewModel.load();
        final AvisPrets after = f.viewModel.state as AvisPrets;
        expect(after.notices, hasLength(2));
        expect(
          after.notices.whereType<ReadableNotice>().every(
            (ReadableNotice n) => n.read,
          ),
          isTrue,
        );
      },
    );

    test('close() en échec est ignoré : AvisFermes, les avis restent '
        '« Nouveau »', () async {
      final _Fixture f = _Fixture(
        notices: <ReceivedNotice>[_stored('La Loire à Blois')],
      );
      await f.viewModel.load();
      f.notices.writeError = const EcritureDAvisEnEchec('test');
      await f.viewModel.close();
      expect(f.viewModel.state, isA<AvisFermes>());
      expect((f.notices.stored.single as ReadableNotice).read, isFalse);
    });

    test('après close(), une vérification pose de nouveau l’annonce', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      await f.viewModel.close();
      await f.viewModel.check();
      expect(f.viewModel.announcement, const NewNoticesAnnouncement(1));
    });
  });

  group('Repartir…', () {
    test('startOverNotices() appelle notices.clear(), puis relit', () async {
      final _Fixture f = _Fixture(
        notices: <ReceivedNotice>[_stored('La Loire à Blois')],
      );
      f.notices.readError = const ListeDAvisIllisible('test');
      await f.viewModel.load();
      expect(f.viewModel.state, isA<AvisIllisibles>());

      await f.viewModel.startOverNotices();
      expect(f.notices.stored, isEmpty);
      expect(f.followUps.stored.followUps, hasLength(1));
      final AvisPrets state = f.viewModel.state as AvisPrets;
      expect(state.notices, isEmpty);
    });

    test(
      'startOverFollowUps() appelle followUps.clear(), puis relit',
      () async {
        final _Fixture f = _Fixture(
          notices: <ReceivedNotice>[_stored('La Loire à Blois')],
        );
        await f.viewModel.load();
        await f.viewModel.startOverFollowUps();
        expect(f.followUps.stored.followUps, isEmpty);
        expect(f.notices.stored, hasLength(1));
        final AvisPrets state = f.viewModel.state as AvisPrets;
        expect(state.followsAnyPlace, isFalse);
        expect(state.notices, hasLength(1));
      },
    );
  });

  group('Relecture de V4 — courses entre la vérification et l’écran', () {
    test('la fermeture tombe entre l’écriture des avis et la fin de la '
        'vérification : les avis écrits ne sont jamais tus, l’annonce vaut '
        'au moins 1', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.load();
      // Le report des derniers états attend : les avis sont déjà écrits.
      f.followUps.writeGate = Completer<void>();
      final Future<CheckOutcome> running = f.viewModel.check();
      await pumpEventQueue();
      expect(f.notices.stored, hasLength(1));

      // L'usager ferme l'écran : l'avis jamais montré est marqué lu.
      await f.viewModel.close();
      expect((f.notices.stored.single as ReadableNotice).read, isTrue);

      f.followUps.writeGate!.complete();
      expect(await running, const CheckDone(1));
      final MapAnnouncement? announcement = f.viewModel.announcement;
      expect(announcement, isA<NewNoticesAnnouncement>());
      expect(
        (announcement! as NewNoticesAnnouncement).count,
        greaterThanOrEqualTo(1),
      );
    });

    test('run() qui lève malgré son contrat : checking retombe, une '
        'vérification suivante repart', () async {
      final _Fixture f = _Fixture();
      f.clock = () => throw StateError('horloge en panne');
      await expectLater(f.viewModel.check(), throwsStateError);
      expect(f.viewModel.checking, isFalse);

      f.clock = () => _now;
      expect(await f.viewModel.check(), const CheckDone(1));
    });

    test('l’écran s’ouvre pendant la relecture des non lus : aucune '
        'annonce, l’état se relit avec l’avis', () async {
      final _Fixture f = _Fixture();
      f.gatedNotices.holdNextReadAfterWrite();
      final Future<CheckOutcome> running = f.viewModel.check();
      await f.gatedNotices.held!.future;

      await f.viewModel.load();
      f.gatedNotices.release!.complete();
      await running;

      expect(f.viewModel.announcement, isNull);
      expect((f.viewModel.state as AvisPrets).notices, hasLength(1));
    });
  });

  group('Le lien Vigicrues', () {
    test('openVigicrues() ouvre le site public', () async {
      final _Fixture f = _Fixture();
      await f.viewModel.openVigicrues();
      expect(f.links.opened, <Uri>[Uri.parse(floodPublicSiteUrl)]);
      expect(f.viewModel.unopenedLinkCount, 0);
    });

    test('un openVigicrues en échec : unopenedLinkCount == 1', () async {
      final _Fixture f = _Fixture();
      f.links.result = false;
      await f.viewModel.openVigicrues();
      expect(f.viewModel.unopenedLinkCount, 1);
    });
  });
}

// Verrouille le ViewModel de l'ecran des restrictions, sans monter aucun
// widget. Meme style que `station_sheet_view_model_test.dart` : un double
// de source qui compte ses appels et rend ce qu'on lui dit de rendre, des
// `Completer` pour rejouer les courses.
//
// Cas de test — conception T2 § 6, plan V1 :
// - Initial : RestrictionsFermees, profile == null.
// - open(p) : EnCours(p) notifie AVANT la reponse, puis ZonesTrouvees ;
//   reponse vide -> AucuneZone(point, retrievedAt).
// - Les trois branches d'echec -> RestrictionsEnEchec avec la MEME cause ;
//   un StateError -> RestrictionsEnEchec(cause: SourceInjoignable(...)) dont
//   diagnostic contient "StateError".
// - chooseProfile(exploitation) notifie ; le meme profil de nouveau ->
//   AUCUNE notification ; le profil survit a close() puis open(p2).
// - Reponse perimee : open(p1) lent puis open(p2) rapide -> l'etat final
//   est celui de p2 ; close() pendant un chargement -> reste
//   RestrictionsFermees.
// - retry() apres echec sur p -> EnCours(p) puis le resultat ; retry()
//   depuis Fermees -> sans effet.
// - dispose() pendant un chargement -> aucune notification apres.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, FlutterExceptionHandler;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';

GeoPoint _pointAin() => GeoPoint(latitude: 46.204, longitude: 5.226);
GeoPoint _pointCorse() => GeoPoint(latitude: 41.927, longitude: 8.737);

AlertZone _zone({
  String name = 'Dombes - Certines - Nord',
  ZoneKind kind = const EauxSuperficielles(),
}) => AlertZone(
  name: name,
  kind: kind,
  severity: const Alerte(),
  decree: RestrictionDecree(validFrom: DateTime.utc(2026, 8, 20)),
  usages: const <RestrictedUsage>[],
);

ZonesAtPoint _zonesTrouvees(GeoPoint point, {DateTime? retrievedAt}) =>
    ZonesAtPoint(
      point: point,
      retrievedAt: retrievedAt ?? DateTime.utc(2026, 9, 27, 12),
      zones: <AlertZone>[_zone()],
    );

ZonesAtPoint _aucuneZone(GeoPoint point, {DateTime? retrievedAt}) =>
    ZonesAtPoint(
      point: point,
      retrievedAt: retrievedAt ?? DateTime.utc(2026, 9, 27, 12),
      zones: const <AlertZone>[],
    );

/// Double en memoire de `RestrictionSource` : compte les appels, rend ce
/// qu'on lui a dit de rendre, ou leve.
final class _RestrictionSourceDouble implements RestrictionSource {
  int calls = 0;
  final List<GeoPoint> requested = <GeoPoint>[];
  Future<ZonesAtPoint> Function(GeoPoint point)? answer;

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) {
    calls++;
    requested.add(point);
    final Future<ZonesAtPoint> Function(GeoPoint point)? configured = answer;
    if (configured == null) {
      return Future<ZonesAtPoint>.value(_zonesTrouvees(point));
    }
    return configured(point);
  }
}

void main() {
  late _RestrictionSourceDouble source;

  setUp(() {
    source = _RestrictionSourceDouble();
  });

  test('etat initial : RestrictionsFermees, aucun profil preselectionne', () {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.state, isA<RestrictionsFermees>());
    expect(viewModel.profile, isNull);
  });

  test(
    'open(p) notifie EnCours(p) avant la reponse, puis ZonesTrouvees',
    () async {
      final Completer<ZonesAtPoint> completer = Completer<ZonesAtPoint>();
      source.answer = (GeoPoint point) => completer.future;
      final RestrictionsViewModel viewModel = RestrictionsViewModel(
        source: source,
      );
      addTearDown(viewModel.dispose);
      final List<RestrictionsState> seen = <RestrictionsState>[];
      viewModel.addListener(() => seen.add(viewModel.state));

      final Future<void> opening = viewModel.open(_pointAin());
      expect(viewModel.state, isA<RestrictionsEnCours>());
      expect((viewModel.state as RestrictionsEnCours).point, _pointAin());

      completer.complete(_zonesTrouvees(_pointAin()));
      await opening;

      expect(seen, hasLength(2));
      expect(seen.first, isA<RestrictionsEnCours>());
      expect(seen.last, isA<ZonesTrouvees>());
    },
  );

  test('reponse vide -> AucuneZone(point, retrievedAt)', () async {
    final DateTime retrievedAt = DateTime.utc(2026, 9, 27, 13);
    source.answer = (GeoPoint point) => Future<ZonesAtPoint>.value(
      _aucuneZone(point, retrievedAt: retrievedAt),
    );
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<AucuneZone>());
    expect((state as AucuneZone).point, _pointAin());
    expect(state.retrievedAt, retrievedAt);
  });

  test('SourceInjoignable -> RestrictionsEnEchec avec la meme cause', () async {
    const SourceInjoignable failure = SourceInjoignable('panne reseau');
    source.answer = (GeoPoint point) => throw failure;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<RestrictionsEnEchec>());
    expect((state as RestrictionsEnEchec).point, _pointAin());
    expect(state.cause, same(failure));
  });

  test('RequeteRefusee -> RestrictionsEnEchec avec la meme cause', () async {
    const RequeteRefusee failure = RequeteRefusee(
      statusCode: 409,
      diagnostic: '409',
    );
    source.answer = (GeoPoint point) => throw failure;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<RestrictionsEnEchec>());
    expect((state as RestrictionsEnEchec).cause, same(failure));
  });

  test('ReponseIllisible -> RestrictionsEnEchec avec la meme cause', () async {
    const ReponseIllisible failure = ReponseIllisible('racine non tableau');
    source.answer = (GeoPoint point) => throw failure;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<RestrictionsEnEchec>());
    expect((state as RestrictionsEnEchec).cause, same(failure));
  });

  test('un StateError (Error, non nomme) -> RestrictionsEnEchec(cause: '
      'SourceInjoignable) dont diagnostic contient "StateError", ET '
      "l'erreur est remontee a FlutterError.onError (arbitrage du "
      '2026-09-27 : echec neutre a l ecran, erreur remontee)', () async {
    final StateError thrown = StateError('inattendu');
    source.answer = (GeoPoint point) => throw thrown;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<RestrictionsEnEchec>());
    final RestrictionLookupFailure cause = (state as RestrictionsEnEchec).cause;
    expect(cause, isA<SourceInjoignable>());
    expect(cause.diagnostic, contains('StateError'));

    expect(
      reported,
      hasLength(1),
      reason: "l'erreur ne doit plus disparaitre en silence",
    );
    expect(reported.single.exception, same(thrown));
    expect(reported.single.library, 'restrictions');
  });

  test('une Exception ordinaire (echec non nomme) -> RestrictionsEnEchec('
      'cause: SourceInjoignable), et NE remonte RIEN a FlutterError.onError '
      '(distinct d une Error)', () async {
    final Exception thrown = Exception('panne ordinaire');
    source.answer = (GeoPoint point) => throw thrown;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    final FlutterExceptionHandler? previousOnError = FlutterError.onError;
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await viewModel.open(_pointAin());

    final RestrictionsState state = viewModel.state;
    expect(state, isA<RestrictionsEnEchec>());
    final RestrictionLookupFailure cause = (state as RestrictionsEnEchec).cause;
    expect(cause, isA<SourceInjoignable>());

    expect(reported, isEmpty);
  });

  test('chooseProfile notifie ; le meme profil de nouveau ne notifie pas', () {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.chooseProfile(UserProfile.exploitation);
    expect(viewModel.profile, UserProfile.exploitation);
    expect(notifications, 1);

    viewModel.chooseProfile(UserProfile.exploitation);
    expect(notifications, 1, reason: 'le meme profil ne notifie pas deux fois');
  });

  test('le profil survit a close() puis open(p2)', () async {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    viewModel.chooseProfile(UserProfile.collectivite);
    viewModel.close();
    expect(viewModel.profile, UserProfile.collectivite);

    await viewModel.open(_pointCorse());
    expect(viewModel.profile, UserProfile.collectivite);
  });

  test('reponse perimee : open(p1) lent puis open(p2) rapide -> l etat '
      'final est celui de p2', () async {
    final Completer<ZonesAtPoint> slow = Completer<ZonesAtPoint>();
    final Completer<ZonesAtPoint> fast = Completer<ZonesAtPoint>();
    int attempt = 0;
    source.answer = (GeoPoint point) {
      attempt++;
      return attempt == 1 ? slow.future : fast.future;
    };
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    final Future<void> openingA = viewModel.open(_pointAin());
    final Future<void> openingB = viewModel.open(_pointCorse());

    fast.complete(_zonesTrouvees(_pointCorse()));
    await openingB;
    slow.complete(_zonesTrouvees(_pointAin()));
    await openingA;

    final RestrictionsState state = viewModel.state;
    expect(state, isA<ZonesTrouvees>());
    expect((state as ZonesTrouvees).zones.point, _pointCorse());
  });

  test('close() pendant un chargement reste RestrictionsFermees, sans '
      'ecriture tardive', () async {
    final Completer<ZonesAtPoint> late = Completer<ZonesAtPoint>();
    source.answer = (GeoPoint point) => late.future;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    final Future<void> opening = viewModel.open(_pointAin());
    expect(viewModel.state, isA<RestrictionsEnCours>());

    viewModel.close();
    expect(viewModel.state, isA<RestrictionsFermees>());

    late.complete(_zonesTrouvees(_pointAin()));
    await opening;

    expect(
      viewModel.state,
      isA<RestrictionsFermees>(),
      reason: "la reponse tardive de l'open abandonne ne doit rien ecrire",
    );
  });

  test('retry() apres echec sur p -> EnCours(p) puis le resultat', () async {
    const SourceInjoignable failure = SourceInjoignable('panne');
    int attempt = 0;
    source.answer = (GeoPoint point) {
      attempt++;
      if (attempt == 1) {
        throw failure;
      }
      return Future<ZonesAtPoint>.value(_zonesTrouvees(point));
    };
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());
    expect(viewModel.state, isA<RestrictionsEnEchec>());

    final List<RestrictionsState> seen = <RestrictionsState>[];
    viewModel.addListener(() => seen.add(viewModel.state));
    await viewModel.retry();

    expect(seen.first, isA<RestrictionsEnCours>());
    expect((seen.first as RestrictionsEnCours).point, _pointAin());
    expect(seen.last, isA<ZonesTrouvees>());
  });

  test('retry() depuis Fermees est sans effet', () async {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.retry();

    expect(viewModel.state, isA<RestrictionsFermees>());
    expect(notifications, 0);
    expect(source.calls, 0);
  });

  test('dispose() pendant un chargement : aucune notification apres', () async {
    final Completer<ZonesAtPoint> late = Completer<ZonesAtPoint>();
    source.answer = (GeoPoint point) => late.future;
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    final Future<void> opening = viewModel.open(_pointAin());
    viewModel.dispose();
    late.complete(_zonesTrouvees(_pointAin()));

    await expectLater(opening, completes);
    expect(
      notifications,
      1,
      reason: 'seule la transition EnCours, emise avant dispose(), a notifie',
    );
  });

  test(
    'ZonesTrouvees porte la reponse SANS filtrage du ViewModel : des '
    'usages de profils differents restent tous les deux dans la zone',
    () async {
      final RestrictedUsage particulierOnly = RestrictedUsage(
        name: 'Arrosage du jardin',
        theme: 'Arroser',
        description: 'Interdit de 8h a 20h',
        concernedProfiles: const <UserProfile>{UserProfile.particulier},
      );
      final RestrictedUsage exploitationOnly = RestrictedUsage(
        name: 'Irrigation agricole',
        theme: 'Irriguer',
        description: 'Interdiction totale',
        concernedProfiles: const <UserProfile>{UserProfile.exploitation},
      );
      final AlertZone zone = AlertZone(
        name: 'Dombes - Certines - Nord',
        kind: const EauxSuperficielles(),
        severity: const Alerte(),
        decree: RestrictionDecree(validFrom: DateTime.utc(2026, 8, 20)),
        usages: <RestrictedUsage>[particulierOnly, exploitationOnly],
      );
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _pointAin(),
        retrievedAt: DateTime.utc(2026, 9, 27, 12),
        zones: <AlertZone>[zone],
      );
      source.answer = (GeoPoint point) => Future<ZonesAtPoint>.value(reponse);
      final RestrictionsViewModel viewModel = RestrictionsViewModel(
        source: source,
      );
      addTearDown(viewModel.dispose);

      await viewModel.open(_pointAin());

      final RestrictionsState state = viewModel.state;
      expect(state, isA<ZonesTrouvees>());
      // Egalite de REFERENCE, pas seulement structurelle : le ViewModel
      // transmet la reponse de la source telle quelle, il ne la reconstruit
      // ni ne la filtre.
      expect((state as ZonesTrouvees).zones, same(reponse));
      final AlertZone zoneVue = state.zones.zones.single;
      expect(zoneVue.usagesFor(UserProfile.particulier), <RestrictedUsage>[
        particulierOnly,
      ]);
      expect(zoneVue.usagesFor(UserProfile.exploitation), <RestrictedUsage>[
        exploitationOnly,
      ]);
      // Les deux usages sont presents dans la zone, quel que soit le
      // profil : le ViewModel n'en a ecarte aucun avant meme tout choix de
      // profil (BR-013, Q5-B — aucune omission silencieuse).
      expect(zoneVue.usages, <RestrictedUsage>[
        particulierOnly,
        exploitationOnly,
      ]);
    },
  );

  test('open -> close -> retry ne relance aucune requete : plus de point '
      'a reinterroger une fois ferme', () async {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());
    expect(source.calls, 1);
    viewModel.close();

    await viewModel.retry();

    expect(source.calls, 1, reason: 'retry() depuis Fermees est sans effet');
    expect(viewModel.state, isA<RestrictionsFermees>());
  });

  test('retry() apres un succes (ZonesTrouvees) est sans effet : une reponse '
      'deja recue ne se reinterroge pas d elle-meme', () async {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_pointAin());
    expect(source.calls, 1);
    expect(viewModel.state, isA<ZonesTrouvees>());

    await viewModel.retry();

    expect(source.calls, 1);
    expect(viewModel.state, isA<ZonesTrouvees>());
  });

  test('chooseProfile apres dispose() ne notifie pas et ne leve rien', () {
    final RestrictionsViewModel viewModel = RestrictionsViewModel(
      source: source,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);
    viewModel.dispose();

    expect(
      () => viewModel.chooseProfile(UserProfile.particulier),
      returnsNormally,
    );
    expect(notifications, 0);
  });

  test('switch exhaustif sur RestrictionsState, sans default (BR-011)', () {
    const RestrictionsState state = RestrictionsFermees();

    final String label = switch (state) {
      RestrictionsFermees() => 'fermee',
      RestrictionsEnCours() => 'en cours',
      ZonesTrouvees() => 'zones trouvees',
      AucuneZone() => 'aucune zone',
      RestrictionsEnEchec() => 'en echec',
    };

    expect(label, 'fermee');
  });
}

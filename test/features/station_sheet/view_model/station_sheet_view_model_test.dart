// Verrouille le ViewModel de la fiche station, sans monter aucun widget.
// Même style que `test/features/map/view_model/map_view_model_test.dart` :
// des doubles de dépôt qui comptent leurs appels et rendent ce qu'on leur
// dit de rendre, une horloge injectée, des `Completer` pour rejouer les
// courses.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

import '../../../support/in_memory_favorite_repository.dart';

StationCode _codeBlois() => StationCode('K447001001');
StationCode _codeGoyaves() => StationCode('1011000101');

Station _station(StationCode code) => Station(
  code: code,
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
  departement: DepartementCode('41'),
  riverLabel: 'La Loire',
  inService: true,
);

/// Le libellé de qualification RÉEL de Hub'Eau est « Bonne » (BR-006 :
/// transporté verbatim, ce n'est jamais l'app qui qualifie un débit) — un
/// balayage par SOUS-CHAÎNE le confondrait à tort avec le mot banni « bon » ;
/// le balayage par MOT ENTIER du test BR-003 ci-dessous l'évite correctement.
HydroObservation _dischargeObservation({
  required DateTime measuredAt,
  CubicMetresPerSecond value = const CubicMetresPerSecond(47.8),
  String? statusLabel = 'Temps réel',
  String? qualificationLabel = 'Bonne',
}) => HydroObservation(
  station: _codeBlois(),
  measuredAt: measuredAt,
  grandeur: Grandeur.debit,
  discharge: value,
  level: null,
  qualification: Qualification(
    statusCode: null,
    statusLabel: statusLabel,
    qualificationCode: null,
    qualificationLabel: qualificationLabel,
  ),
);

/// Observation de hauteur, distincte de [_dischargeObservation] : sert à
/// prouver que débit et hauteur ne sont jamais confondus (`Grandeur`).
HydroObservation _levelObservation({
  required DateTime measuredAt,
  Metres value = const Metres(-1.232),
}) => HydroObservation(
  station: _codeBlois(),
  measuredAt: measuredAt,
  grandeur: Grandeur.hauteur,
  discharge: null,
  level: value,
  qualification: const Qualification(
    statusCode: null,
    statusLabel: null,
    qualificationCode: null,
    qualificationLabel: null,
  ),
);

/// Double du dépôt de stations : compte les appels, rend ce qu'on lui a dit
/// de rendre — ou lève.
final class _StationRepositoryDouble implements StationRepository {
  int calls = 0;
  Future<Station?> Function(StationCode code)? answer;

  @override
  Future<Station?> findByCode(StationCode code) {
    calls++;
    final Future<Station?> Function(StationCode code)? configured = answer;
    if (configured == null) {
      return Future<Station?>.value(_station(code));
    }
    return configured(code);
  }
}

/// Double du dépôt d'observations hydrométriques : compte les appels PAR
/// grandeur, pour vérifier que le débit ET la hauteur sont demandés.
/// [answer] n'est PAS forcément `async` : un des tests le déclare volontairement
/// synchrone, pour prouver que `Future.sync` protège contre une levée
/// immédiate (`CachedHydroObservationRepository.findLatest` n'est pas
/// `async` et peut lever ainsi en production).
final class _HydroObservationRepositoryDouble
    implements HydroObservationRepository {
  int calls = 0;
  final List<Grandeur> requested = <Grandeur>[];
  Future<HydroObservation?> Function(StationCode code, Grandeur grandeur)?
  answer;

  @override
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur) {
    calls++;
    requested.add(grandeur);
    final Future<HydroObservation?> Function(
      StationCode code,
      Grandeur grandeur,
    )?
    configured = answer;
    if (configured == null) {
      return Future<HydroObservation?>.value(null);
    }
    return configured(station, grandeur);
  }
}

/// L'instant d'ajout d'un favori déjà stocké, distinct de l'horloge des tests.
final DateTime _addedBefore = DateTime.utc(2026, 10, 1, 8);

StationFavorite _favoriteBlois() => StationFavorite(
  code: _codeBlois(),
  label: 'La Loire à Blois',
  addedAt: _addedBefore,
);

const FavoriteStar _emptyActive = FavoriteStar(filled: false, enabled: true);
const FavoriteStar _emptyInactive = FavoriteStar(filled: false, enabled: false);
const FavoriteStar _filledActive = FavoriteStar(filled: true, enabled: true);

void main() {
  late _StationRepositoryDouble stations;
  late _HydroObservationRepositoryDouble observations;
  late InMemoryFavoriteRepository favorites;

  setUp(() {
    stations = _StationRepositoryDouble();
    observations = _HydroObservationRepositoryDouble();
    favorites = InMemoryFavoriteRepository();
  });

  test(
    "open passe par EnCours puis Prete, et notifie exactement deux fois",
    () async {
      observations.answer = (StationCode code, Grandeur grandeur) async =>
          grandeur == Grandeur.debit
          ? _dischargeObservation(measuredAt: DateTime.utc(2026, 9, 13, 9))
          : null;
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        favorites: favorites,
        now: () => DateTime.utc(2026, 9, 13, 10),
      );
      addTearDown(viewModel.dispose);
      final List<StationSheetState> seen = <StationSheetState>[];
      viewModel.addListener(() => seen.add(viewModel.state));

      await viewModel.open(_codeBlois());

      expect(seen, hasLength(2));
      expect(seen.first, isA<EnCours>());
      expect(seen.last, isA<Prete>());
    },
  );

  test(
    'open interroge le debit ET la hauteur aupres du depot, chacun une fois',
    () async {
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        favorites: favorites,
      );
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());

      expect(observations.calls, 2);
      expect(observations.requested.toSet(), <Grandeur>{
        Grandeur.debit,
        Grandeur.hauteur,
      });
    },
  );

  test('quand le depot rend un debit ET une hauteur, les deux restent '
      'distincts dans les donnees pretes', () async {
    final DateTime measuredAt = DateTime.utc(2026, 9, 13, 9);
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _dischargeObservation(measuredAt: measuredAt)
        : _levelObservation(measuredAt: measuredAt);
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => measuredAt,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetData data = (viewModel.state as Prete).data;
    expect(data.discharge?.discharge, const CubicMetresPerSecond(47.8));
    expect(data.level?.level, const Metres(-1.232));
    expect(data.discharge, isNot(same(data.level)));
  });

  test('le debit converti vaut 47,8 m3/s, et aucun MOT ENTIER produit ne '
      'correspond a un mot banni (BR-003)', () async {
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _dischargeObservation(measuredAt: DateTime.utc(2026, 9, 13, 9, 30))
        : null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<Prete>());
    final StationSheetData data = (state as Prete).data;
    expect(data.discharge?.discharge, const CubicMetresPerSecond(47.8));

    const List<String> bannedWords = <String>[
      'suffisant',
      'insuffisant',
      'normal',
      'bon',
      'sûr',
    ];
    final List<String?> labels = <String?>[
      data.statusLabel,
      data.qualificationLabel,
      data.stalenessNotice,
    ];
    for (final String? label in labels) {
      if (label == null) {
        continue;
      }
      final Set<String> words = label
          .toLowerCase()
          .split(RegExp(r'[^a-zà-öø-ÿ]+'))
          .toSet();
      for (final String banned in bannedWords) {
        expect(
          words,
          isNot(contains(banned)),
          reason: '"$banned" trouve MOT POUR MOT dans "$label" (BR-003)',
        );
      }
    }
  });

  test('une observation du 2026-08-27T08:00Z vue le 2026-09-13T10:00Z est '
      'perimee, avec un avis qui cite la date en heure locale, decalage '
      'injecte +2h (BR-005, H1, le cas des 17 jours)', () async {
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _dischargeObservation(measuredAt: DateTime.utc(2026, 8, 27, 8))
        : null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13, 10),
      utcOffsetOf: (DateTime _) => const Duration(hours: 2),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetData data = (viewModel.state as Prete).data;
    expect(data.freshness, Freshness.perimee);
    expect(data.stalenessNotice, 'Dernière mesure le 27/08/2026 à 10:00');
  });

  test('vue 1 h apres la mesure : fraiche et aucun avis ; vue 3 h apres : '
      'ancienne et « il y a 3 h » (BR-005)', () async {
    final DateTime measuredAt = DateTime.utc(2026, 9, 13, 8);
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _dischargeObservation(measuredAt: measuredAt)
        : null;

    final StationSheetViewModel freshViewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => measuredAt.add(const Duration(hours: 1)),
    );
    addTearDown(freshViewModel.dispose);
    await freshViewModel.open(_codeBlois());
    final StationSheetData freshData = (freshViewModel.state as Prete).data;
    expect(freshData.freshness, Freshness.fraiche);
    expect(freshData.stalenessNotice, isNull);

    final StationSheetViewModel staleViewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => measuredAt.add(const Duration(hours: 3)),
    );
    addTearDown(staleViewModel.dispose);
    await staleViewModel.open(_codeBlois());
    final StationSheetData staleData = (staleViewModel.state as Prete).data;
    expect(staleData.freshness, Freshness.ancienne);
    expect(staleData.stalenessNotice, contains('il y a 3 h'));
  });

  test('qualification et statut absents deviennent "non qualifiee" et "non '
      'renseigne", jamais une chaine vide (BR-006, BR-011)', () async {
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _dischargeObservation(
            measuredAt: DateTime.utc(2026, 9, 13, 9),
            statusLabel: null,
            qualificationLabel: null,
          )
        : null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetData data = (viewModel.state as Prete).data;
    expect(data.statusLabel, 'non renseigné');
    expect(data.qualificationLabel, 'non qualifiée');
  });

  test('un debit absent laisse Prete sans valeur, sans fraicheur ni avis : '
      'jamais un zero (BR-007, UC-003 A3)', () async {
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<Prete>());
    final StationSheetData data = (state as Prete).data;
    expect(data.discharge, isNull);
    expect(data.freshness, isNull);
    expect(data.stalenessNotice, isNull);
  });

  test('un depot d observations qui leve fait passer en EnEchec, la cause est '
      'conservee (UC-001 A4)', () async {
    final Exception failure = Exception('panne');
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        throw failure;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<EnEchec>());
    expect((state as EnEchec).cause, same(failure));
    expect(state.code, _codeBlois());
  });

  test(
    'un depot dont findLatest leve de facon SYNCHRONE (sans async) est '
    'quand meme interroge sur les DEUX grandeurs avant l etat EnEchec',
    () async {
      final Exception failure = Exception('panne synchrone');
      final List<Grandeur> requestedBeforeFailure = <Grandeur>[];
      // Pas de `async` ici : la levee survient AVANT tout `await`, ce que
      // `Future.sync` (dans le ViewModel) doit absorber sans empecher le
      // second appel.
      observations.answer = (StationCode code, Grandeur grandeur) {
        requestedBeforeFailure.add(grandeur);
        throw failure;
      };
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        favorites: favorites,
      );
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());

      expect(requestedBeforeFailure.toSet(), <Grandeur>{
        Grandeur.debit,
        Grandeur.hauteur,
      });
      expect(viewModel.state, isA<EnEchec>());
    },
  );

  // Les 37 stations du referentiel sans `code_departement` sont dans
  // `points` (la carte les affiche, elles sont tapables) mais absentes de
  // `stations` (fait constate le 2026-09-13,
  // `test/data/referentiel/stations_asset_test.dart`). `findByCode` rend
  // alors `null` SANS qu'aucun appel reseau ait eu lieu : l'etat est
  // `Introuvable`, jamais `EnEchec`, qui nommerait Hub'Eau a tort (BR-007,
  // UC-001 A4).
  test('une station absente du referentiel embarque (findByCode rend null) '
      'fait passer en Introuvable, avec son code, sans appeler le depot '
      'd observations', () async {
    stations.answer = (StationCode code) async => null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<Introuvable>());
    expect((state as Introuvable).code, _codeBlois());
    expect(observations.calls, 0);
  });

  test('Introuvable n est PAS un EnEchec : un echec de depot et une absence '
      'du referentiel ne se confondent pas', () async {
    stations.answer = (StationCode code) async => null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    expect(viewModel.state, isNot(isA<EnEchec>()));
  });

  test('un depot de stations qui LEVE reste un EnEchec : la panne de lecture '
      'n est pas une absence (UC-001 A4)', () async {
    final Exception failure = Exception('asset illisible');
    stations.answer = (StationCode code) async => throw failure;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<EnEchec>());
    expect((state as EnEchec).cause, same(failure));
  });

  test('close() ferme immediatement, avec une notification', () {
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.close();

    expect(viewModel.state, isA<Fermee>());
    expect(notifications, 1);
  });

  test('une reponse tardive d un open() precedent n ecrase pas close() '
      '(garde par jeton de generation, comme MapViewModel)', () async {
    final Completer<Station?> late = Completer<Station?>();
    stations.answer = (StationCode code) => late.future;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    final Future<void> opening = viewModel.open(_codeBlois());
    expect(viewModel.state, isA<EnCours>());

    viewModel.close();
    expect(viewModel.state, isA<Fermee>());

    late.complete(_station(_codeBlois()));
    await opening;

    expect(
      viewModel.state,
      isA<Fermee>(),
      reason: "la reponse tardive de l'open abandonne ne doit rien ecrire",
    );
  });

  test('B ouvert pendant A : B gagne (garde par jeton de generation, comme '
      'MapViewModel)', () async {
    final StationCode codeA = _codeBlois();
    final StationCode codeB = _codeGoyaves();
    final Completer<Station?> slow = Completer<Station?>();
    final Completer<Station?> fast = Completer<Station?>();
    int attempt = 0;
    stations.answer = (StationCode code) {
      attempt++;
      return attempt == 1 ? slow.future : fast.future;
    };
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    final Future<void> openingA = viewModel.open(codeA);
    final Future<void> openingB = viewModel.open(codeB);

    fast.complete(_station(codeB));
    await openingB;
    slow.complete(_station(codeA));
    await openingA;

    final StationSheetState state = viewModel.state;
    expect(state, isA<Prete>());
    expect((state as Prete).data.station.code, codeB);
  });

  test('open sur un ViewModel dispose ne leve rien : la reponse tardive ne '
      'notifie plus', () async {
    final Completer<Station?> late = Completer<Station?>();
    stations.answer = (StationCode code) => late.future;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      favorites: favorites,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    final Future<void> opening = viewModel.open(_codeBlois());
    viewModel.dispose();
    late.complete(_station(_codeBlois()));

    await expectLater(opening, completes);
    expect(
      notifications,
      1,
      reason: "seule la transition EnCours, emise avant dispose(), a notifie",
    );
  });

  test('switch exhaustif sur StationSheetState, sans default (BR-011)', () {
    const StationSheetState state = Fermee();

    final String label = switch (state) {
      Fermee() => 'fermee',
      EnCours() => 'en cours',
      Prete() => 'prete',
      EnEchec() => 'en echec',
      Introuvable() => 'introuvable',
    };

    expect(label, 'fermee');
  });

  group('favori', () {
    final DateTime clock = DateTime.utc(2026, 10, 12, 9, 30);

    StationSheetViewModel build() {
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        favorites: favorites,
        // Une horloge LOCALE : l'instant d'ajout doit sortir en UTC.
        now: () => clock.toLocal(),
      );
      return viewModel;
    }

    test('fiche Prete, liste vide : etoile vide et active ; la bascule ajoute '
        'la station, son libelle et l instant de l horloge en UTC, puis '
        'l etoile est pleine et active', () async {
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.state, isA<Prete>());
      expect(viewModel.favoriteStar, _emptyActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, <Favorite>[
        StationFavorite(
          code: _codeBlois(),
          label: 'La Loire à Blois',
          addedAt: clock,
        ),
      ]);
      expect((favorites.stored.single as StationFavorite).addedAt.isUtc, true);
      expect(viewModel.favoriteStar, _filledActive);
    });

    test(
      'pendant une ecriture l etoile garde sa forme, inactive ; une seconde '
      'bascule n appelle pas le depot ; porte ouverte : pleine, active',
      () async {
        final StationSheetViewModel viewModel = build();
        addTearDown(viewModel.dispose);
        await viewModel.open(_codeBlois());
        final Completer<void> gate = Completer<void>();
        favorites.writeGate = gate;

        final Future<void> toggling = viewModel.toggleFavorite();
        expect(viewModel.favoriteStar, _emptyInactive);

        await viewModel.toggleFavorite();
        expect(favorites.writeCalls, 1);
        expect(viewModel.favoriteStar, _emptyInactive);

        gate.complete();
        await toggling;

        expect(favorites.writeCalls, 1);
        expect(viewModel.favoriteStar, _filledActive);
      },
    );

    test('ecriture en echec : l etoile garde sa forme d avant, active, et le '
        'dit ; la fiche reste Prete ; une bascule reussie l efface', () async {
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.open(_codeBlois());
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.toggleFavorite();

      expect(
        viewModel.favoriteStar,
        const FavoriteStar(filled: false, enabled: true, writeFailed: true),
      );
      expect(viewModel.state, isA<Prete>());
      expect(favorites.stored, isEmpty);

      favorites.writeError = null;
      await viewModel.toggleFavorite();

      expect(viewModel.favoriteStar, _filledActive);
      expect(favorites.stored, hasLength(1));
    });

    test('un retrait en echec laisse l etoile pleine, active, et le dit ; '
        'une nouvelle ouverture l efface', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.open(_codeBlois());
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.toggleFavorite();

      expect(
        viewModel.favoriteStar,
        const FavoriteStar(filled: true, enabled: true, writeFailed: true),
      );
      expect(favorites.stored, hasLength(1));

      await viewModel.open(_codeBlois());
      expect(viewModel.favoriteStar, _filledActive);
    });

    test(
      'station deja en favori, fiche EnEchec : etoile pleine et active ; la '
      'bascule la retire, l etoile disparait, la fiche reste EnEchec',
      () async {
        favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
        observations.answer = (StationCode code, Grandeur grandeur) async =>
            throw Exception('panne');
        final StationSheetViewModel viewModel = build();
        addTearDown(viewModel.dispose);

        await viewModel.open(_codeBlois());
        expect(viewModel.state, isA<EnEchec>());
        expect(viewModel.favoriteStar, _filledActive);

        await viewModel.toggleFavorite();

        expect(favorites.stored, isEmpty);
        expect(viewModel.favoriteStar, isNull);
        expect(viewModel.state, isA<EnEchec>());
      },
    );

    test('station deja en favori, fiche EnCours : l etoile est pleine AVANT '
        'la fin du chargement, et retirable', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      final Completer<HydroObservation?> pending =
          Completer<HydroObservation?>();
      observations.answer = (StationCode code, Grandeur grandeur) =>
          pending.future;
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      final Future<void> opening = viewModel.open(_codeBlois());
      await pumpEventQueue();

      expect(viewModel.state, isA<EnCours>());
      expect(viewModel.favoriteStar, _filledActive);

      await viewModel.toggleFavorite();
      expect(favorites.stored, isEmpty);
      expect(viewModel.favoriteStar, isNull);
      expect(viewModel.state, isA<EnCours>());

      pending.complete(null);
      await opening;
      expect(viewModel.state, isA<Prete>());
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('station Introuvable, pas en favori : aucune etoile, et la bascule '
        'n appelle pas le depot', () async {
      stations.answer = (StationCode code) async => null;
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.state, isA<Introuvable>());
      expect(viewModel.favoriteStar, isNull);

      await viewModel.toggleFavorite();

      expect(favorites.writeCalls, 0);
    });

    test('station Introuvable et deja en favori : etoile pleine, active, '
        'retirable', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      stations.answer = (StationCode code) async => null;
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.state, isA<Introuvable>());
      expect(viewModel.favoriteStar, _filledActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, isEmpty);
      expect(viewModel.favoriteStar, isNull);
      expect(viewModel.state, isA<Introuvable>());
    });

    test(
      'fiche EnEchec, pas en favori : aucune etoile, aucune ecriture',
      () async {
        observations.answer = (StationCode code, Grandeur grandeur) async =>
            throw Exception('panne');
        final StationSheetViewModel viewModel = build();
        addTearDown(viewModel.dispose);

        await viewModel.open(_codeBlois());
        expect(viewModel.state, isA<EnEchec>());
        expect(viewModel.favoriteStar, isNull);

        await viewModel.toggleFavorite();
        expect(favorites.writeCalls, 0);
      },
    );

    test(
      'fiche EnCours, pas en favori : aucune etoile, aucune ecriture',
      () async {
        final Completer<HydroObservation?> pending =
            Completer<HydroObservation?>();
        observations.answer = (StationCode code, Grandeur grandeur) =>
            pending.future;
        final StationSheetViewModel viewModel = build();
        addTearDown(viewModel.dispose);

        final Future<void> opening = viewModel.open(_codeBlois());
        await pumpEventQueue();

        expect(viewModel.state, isA<EnCours>());
        expect(favorites.readCalls, 1);
        expect(viewModel.favoriteStar, isNull);
        await viewModel.toggleFavorite();
        expect(favorites.writeCalls, 0);

        pending.complete(null);
        await opening;
      },
    );

    test('un point ONDE de meme code que la station, seul dans le depot : '
        'l etoile de la station est vide', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        OndePointFavorite(
          point: OndePoint(
            code: OndeStationCode('K447001001'),
            label: 'Un point ONDE',
            latitude: 47.5,
            longitude: 1.3,
            waterCourseLabel: null,
            departement: null,
          ),
          addedAt: _addedBefore,
        ),
      ]);
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());

      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('liste illisible, fiche Prete : etoile vide et inactive, la bascule '
        'n appelle pas le depot', () async {
      favorites.readError = const ListeDeFavorisIllisible('x');
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.state, isA<Prete>());
      expect(viewModel.favoriteStar, _emptyInactive);

      await viewModel.toggleFavorite();
      expect(favorites.writeCalls, 0);
    });

    test('liste illisible, fiche EnEchec : etoile vide et inactive, la bascule '
        'n appelle pas le depot', () async {
      favorites.readError = const ListeDeFavorisIllisible('x');
      observations.answer = (StationCode code, Grandeur grandeur) async =>
          throw Exception('panne');
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.state, isA<EnEchec>());
      expect(viewModel.favoriteStar, _emptyInactive);

      await viewModel.toggleFavorite();
      expect(favorites.writeCalls, 0);
    });

    test('toute autre levee de la lecture vaut liste illisible, et la fiche '
        'reste Prete', () async {
      favorites.readError = StateError('autre');
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());

      expect(viewModel.state, isA<Prete>());
      expect(viewModel.favoriteStar, _emptyInactive);
    });

    test('chaque ouverture relit le depot : un ajout fait par un autre client '
        'entre deux ouvertures donne une etoile pleine', () async {
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());
      expect(viewModel.favoriteStar, _emptyActive);

      await favorites.add(_favoriteBlois());
      viewModel.close();
      await viewModel.open(_codeBlois());

      expect(viewModel.favoriteStar, _filledActive);
      expect(favorites.readCalls, 2);
    });

    test('la fiche passe a Prete sans attendre la lecture des favoris ; le '
        'futur d open ne se complete qu apres elle', () async {
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      bool opened = false;

      final Future<void> opening = viewModel
          .open(_codeBlois())
          .then((_) => opened = true);
      await pumpEventQueue();

      expect(viewModel.state, isA<Prete>());
      expect(viewModel.favoriteStar, isNull);
      expect(opened, isFalse);

      gate.complete();
      await opening;

      expect(opened, isTrue);
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('close() pendant la lecture des favoris : aucune etoile, aucune '
        'notification tardive', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      final Future<void> opening = viewModel.open(_codeBlois());
      await pumpEventQueue();
      viewModel.close();
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      gate.complete();
      await opening;

      expect(viewModel.state, isA<Fermee>());
      expect(viewModel.favoriteStar, isNull);
      expect(notifications, 0);
    });

    test('open(A) puis open(B) avant la fin de la lecture de A : l etoile est '
        'celle de B', () async {
      // A (Blois) est en favori, B ne l'est pas.
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      // Une porte par lecture : `readAll` lit `readGate` à l'appel, donc on la
      // change entre les deux `open`.
      final Completer<void> gateA = Completer<void>();
      final Completer<void> gateB = Completer<void>();

      favorites.readGate = gateA;
      final Future<void> openingA = viewModel.open(_codeBlois());
      favorites.readGate = gateB;
      final Future<void> openingB = viewModel.open(_codeGoyaves());
      expect(favorites.readCalls, 2);

      gateB.complete();
      await openingB;
      expect(viewModel.favoriteStar, _emptyActive);

      gateA.complete();
      await openingA;

      expect((viewModel.state as Prete).data.station.code, _codeGoyaves());
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('une ecriture d une ouverture abandonnee n ecrit rien dans l etoile '
        'de la suivante', () async {
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.open(_codeBlois());
      final Completer<void> gate = Completer<void>();
      favorites.writeGate = gate;
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      final Future<void> toggling = viewModel.toggleFavorite();
      await viewModel.open(_codeGoyaves());
      expect(viewModel.favoriteStar, _emptyActive);

      gate.complete();
      await toggling;

      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('dispose() pendant une ecriture : aucune exception, aucune '
        'notification', () async {
      final StationSheetViewModel viewModel = build();
      await viewModel.open(_codeBlois());
      final Completer<void> gate = Completer<void>();
      favorites.writeGate = gate;

      final Future<void> toggling = viewModel.toggleFavorite();
      int notifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.dispose();
      gate.complete();

      await expectLater(toggling, completes);
      expect(notifications, 0);
    });

    test('apres dispose(), toggleFavorite n appelle pas le depot', () async {
      final StationSheetViewModel viewModel = build();
      await viewModel.open(_codeBlois());
      expect(viewModel.favoriteStar, _emptyActive);
      viewModel.dispose();

      await viewModel.toggleFavorite();

      expect(favorites.writeCalls, 0);
      expect(favorites.stored, isEmpty);
    });

    test(
      'une lecture de favoris qui change l etoile notifie, et elle seule',
      () async {
        favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
        final Completer<void> gate = Completer<void>();
        favorites.readGate = gate;
        final StationSheetViewModel viewModel = build();
        addTearDown(viewModel.dispose);
        final Future<void> opening = viewModel.open(_codeBlois());
        await pumpEventQueue();
        expect(viewModel.state, isA<Prete>());
        final List<FavoriteStar?> seen = <FavoriteStar?>[];
        viewModel.addListener(() => seen.add(viewModel.favoriteStar));

        gate.complete();
        await opening;

        expect(seen, <FavoriteStar?>[_filledActive]);
      },
    );

    test('chaque bascule notifie : inactive pendant l ecriture, puis la '
        'nouvelle forme', () async {
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);
      await viewModel.open(_codeBlois());
      final List<FavoriteStar?> seen = <FavoriteStar?>[];
      viewModel.addListener(() => seen.add(viewModel.favoriteStar));

      await viewModel.toggleFavorite();

      expect(seen, <FavoriteStar?>[_emptyInactive, _filledActive]);
    });

    test('fiche Fermee : aucune etoile, avant toute ouverture comme apres '
        'close(), et la bascule n appelle pas le depot', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[_favoriteBlois()]);
      final StationSheetViewModel viewModel = build();
      addTearDown(viewModel.dispose);

      expect(viewModel.favoriteStar, isNull);

      await viewModel.open(_codeBlois());
      expect(viewModel.favoriteStar, _filledActive);
      viewModel.close();

      expect(viewModel.favoriteStar, isNull);
      await viewModel.toggleFavorite();
      expect(favorites.writeCalls, 0);
    });
  });
}

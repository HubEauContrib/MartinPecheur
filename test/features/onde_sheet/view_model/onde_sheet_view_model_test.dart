// Verrouille le ViewModel de la fiche ONDE, sans monter aucun widget. Même
// style que `test/features/station_sheet/view_model/
// station_sheet_view_model_test.dart` : un double de dépôt programmable qui
// compte ses appels, une horloge injectée, des `Completer` pour rejouer les
// courses.
//
// ⚠️ Toutes les valeurs attendues viennent de la fixture RÉELLE de `D1`
// (`test/fixtures/onde/observations_station_K4520001_2026-09-13.json`,
// capturée par appel HTTP le 2026-09-13), lue ici et convertie par le
// mapper déjà verrouillé (`onde_observation_mapper_test.dart`) : aucune date,
// aucun code, aucun libellé n'est écrit de mémoire (CLAUDE.md,
// anti-hallucination ; `docs/plan-de-tests.md § 2`). Quatre cas sont
// construits à la main, signalés comme tels à chaque fois :
// - l'absence complète de modalité (ni code ni libellé) ;
// - un code présent sans libellé, et symétriquement un libellé présent sans
//   code — `Q-05` a compté zéro `code_ecoulement` nul le 2026-09-13, il
//   n'existe donc aucune capture réelle d'aucun de ces trois cas, que
//   `BR-007` impose pourtant de tenir ;
// - le point B du test « B ouvert pendant A », assemblé à partir des VRAIES
//   valeurs de la station `K4640001` lues dans
//   `test/fixtures/onde/observations_bbox_loire_2026-09-13.json` — pas de la
//   fixture `K4520001` utilisée partout ailleurs dans ce fichier.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

import '../../../support/in_memory_favorite_repository.dart';

/// Les dix lignes de la fixture réelle de `K4520001`, converties par le
/// mapper de `D3`/`D8` — jamais recopiées à la main.
List<OndeObservation> _fixtureObservations() {
  final String raw = File(
    'test/fixtures/onde/observations_station_K4520001_2026-09-13.json',
  ).readAsStringSync();
  final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
  final List<dynamic> rows = decoded['data'] as List<dynamic>;

  return rows
      .map((dynamic row) => mapOndeObservation(row as Map<String, dynamic>))
      .toList();
}

/// Le point ONDE de la fixture, tel que la carte le passerait à `open` (D8).
OndePoint _fixturePoint() => _fixtureObservations().first.point;

/// Les [limit] observations les plus récentes de la fixture, dans l'ordre
/// où le dépôt les rend (le plus récent en tête, contrat de
/// [OndeObservationRepository.historyFor]).
List<OndeObservation> _fixtureHistory({int limit = 5}) =>
    _fixtureObservations().take(limit).toList();

/// Double du dépôt ONDE : compte ses appels, retient ce qu'on lui a demandé,
/// et rend ce qu'on lui a dit de rendre — ou lève. [answer] n'est pas
/// forcément `async` : un des tests le déclare volontairement synchrone,
/// pour prouver qu'une levée immédiate est absorbée
/// (`CachedOndeObservationRepository.historyFor` n'est pas `async` et peut
/// lever ainsi en production).
final class _OndeObservationRepositoryDouble
    implements OndeObservationRepository {
  int calls = 0;
  final List<OndeStationCode> requested = <OndeStationCode>[];
  Future<List<OndeObservation>> Function(OndeStationCode station, int limit)?
  answer;

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) {
    calls++;
    requested.add(station);
    final Future<List<OndeObservation>> Function(
      OndeStationCode station,
      int limit,
    )?
    configured = answer;
    if (configured == null) {
      return Future<List<OndeObservation>>.value(_fixtureHistory(limit: limit));
    }
    return configured(station, limit);
  }

  /// La fiche ONDE ne lit jamais par emprise : c'est l'affaire de la carte
  /// (`MapViewModel`, V2). Une levée ici rendrait rouge tout test où le
  /// ViewModel s'y tromperait.
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) => throw UnsupportedError(
    'la fiche ONDE lit un point par son code, jamais une emprise',
  );
}

/// Les cinq mots bannis pour qualifier un débit (BR-003, CLAUDE.md).
const List<String> _bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

/// Vérifie qu'aucun MOT ENTIER de [label] n'est un mot banni. Le balayage se
/// fait par mot et non par sous-chaîne : « Assec », libellé officiel
/// transporté verbatim, ne doit pas être confondu avec un mot banni, et
/// inversement un « bon » caché dans « bonne » doit rester détectable.
void _expectNoBannedWord(String label) {
  final Set<String> words = label
      .toLowerCase()
      .split(RegExp(r'[^a-zà-öø-ÿ]+'))
      .toSet();
  for (final String banned in _bannedWords) {
    expect(
      words,
      isNot(contains(banned)),
      reason: '"$banned" trouvé MOT POUR MOT dans "$label" (BR-003)',
    );
  }
}

/// Mots interdits par `BR-014` — verbes d'instruction, d'autorisation ou
/// d'interdiction sur un usage de l'eau (table de la règle : « vous pouvez
/// arroser », « baignade possible », « traversée déconseillée »), et mots de
/// garantie (« aucun mot de garantie : ni temps réel, ni exactitude, ni
/// exhaustivité, ni sécurité, ni conformité réglementaire » et les exemples
/// « données fiables », « vérifié », « en direct »), repris mot pour mot de
/// `docs/br/BR-014-aucun-verbe-d-instruction.md`.
///
/// ⚠️ « officiel » figure lui aussi comme mot de garantie dans `BR-014`
/// (« "Données fiables", "vérifié", "officiel", "en direct" ») mais reste
/// ABSENT de cette liste, volontairement : c'est le mot qui nomme la
/// nomenclature officielle de la source ONDE dans `_noModalityText`
/// (`ADR-006`, `UC-004 § 3`), pas une garantie que l'application donnerait
/// sur ses propres données — la relecture du 2026-09-14 juge le mot
/// acceptable dans ce rôle précis.
const List<String> _br014ForbiddenWords = <String>[
  'pouvez',
  'possible',
  'déconseillée',
  'déconseillé',
  'fiable',
  'fiables',
  'vérifié',
  'vérifiée',
  'direct',
  'réel',
  'réelle',
  'exactitude',
  'exhaustivité',
  'sécurité',
  'conformité',
  'réglementaire',
];

/// Vérifie qu'aucun MOT ENTIER de [label] n'est un mot interdit par
/// `BR-014`. Même méthode de balayage que [_expectNoBannedWord] (BR-003).
void _expectNoBr014ForbiddenWord(String label) {
  final Set<String> words = label
      .toLowerCase()
      .split(RegExp(r'[^a-zà-öø-ÿ]+'))
      .toSet();
  for (final String forbidden in _br014ForbiddenWords) {
    expect(
      words,
      isNot(contains(forbidden)),
      reason: '"$forbidden" trouvé MOT POUR MOT dans "$label" (BR-014)',
    );
  }
}

void main() {
  late _OndeObservationRepositoryDouble onde;
  late InMemoryFavoriteRepository favorites;

  setUp(() {
    onde = _OndeObservationRepositoryDouble();
    favorites = InMemoryFavoriteRepository();
  });

  test('open passe par OndeSheetEnCours puis OndeSheetPrete, en deux etats, '
      'et la campagne du 2026-08-25 vue le 2026-09-13 a 19 jours '
      '(BR-010)', () async {
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);
    final List<OndeSheetState> seen = <OndeSheetState>[];
    // La lecture des favoris notifie aussi (l'étoile apparaît, `S6`) : `seen`
    // ne consigne que les CHANGEMENTS d'état de la fiche, `notifications`
    // compte tout, brut.
    int notifications = 0;
    viewModel.addListener(() {
      notifications++;
      if (seen.isEmpty || !identical(seen.last, viewModel.state)) {
        seen.add(viewModel.state);
      }
    });

    await viewModel.open(_fixturePoint());

    // EnCours, l'étoile, puis Prete : une double émission du même état serait
    // vue ici.
    expect(notifications, 3);
    expect(seen, hasLength(2));
    expect(seen.first, isA<OndeSheetEnCours>());
    expect(
      (seen.first as OndeSheetEnCours).point.code,
      OndeStationCode('K4520001'),
    );
    expect(seen.last, isA<OndeSheetPrete>());

    expect(onde.calls, 1);
    expect(onde.requested.single, OndeStationCode('K4520001'));

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.point.code, OndeStationCode('K4520001'));
    expect(data.latest?.observedAt, DateTime.utc(2026, 8, 25));
    expect(data.ageInDays, 19);
    expect(data.age, CampaignAge.recente);
  });

  test('la modalite officielle exacte reste affichee — « code 3 » et '
      '« Assec » — tandis que la categorie affichee dit « A sec », jamais '
      '« Assec » (ADR-006, UC-004 § 3, glossaire)', () async {
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.officialModalityText, contains('code 3'));
    expect(data.officialModalityText, contains('Assec'));

    final OndeObservation latest = data.latest!;
    expect(latest.rawFlowCode, '3');
    expect(latest.officialLabel, 'Assec');
    expect(latest.category, const Assec());
    expect(flowCategoryLabel(latest.category), 'À sec');
    expect(flowCategoryLabel(latest.category), isNot(contains('Assec')));
  });

  test('history rend les cinq dernieres campagnes, decroissantes en date, '
      'latest en tete, chacune avec sa categorie (UC-004 § 4)', () async {
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.history, hasLength(5));
    expect(data.latest, same(data.history.first));

    // Les cinq dates et les cinq codes de la fixture réelle, dans l'ordre
    // rendu par `sort=desc` : deux assecs, une eau stagnante, un écoulement
    // acceptable, un écoulement faible.
    expect(
      data.history.map((OndeObservation o) => o.observedAt).toList(),
      <DateTime>[
        DateTime.utc(2026, 8, 25),
        DateTime.utc(2026, 7, 24),
        DateTime.utc(2026, 6, 26),
        DateTime.utc(2026, 5, 26),
        DateTime.utc(2025, 9, 26),
      ],
    );
    expect(
      data.history.map((OndeObservation o) => o.category).toList(),
      <FlowCategory>[
        const Assec(),
        const Assec(),
        const EcoulementNonVisible(),
        const Ecoulement(),
        const EcoulementFaible(),
      ],
    );

    for (int i = 1; i < data.history.length; i++) {
      expect(
        data.history[i].observedAt.isBefore(data.history[i - 1].observedAt),
        isTrue,
        reason: 'history doit rester décroissante en date (UC-004 § 4)',
      );
    }
  });

  test('seasonNotice cite mai et septembre, campagne presente ou non '
      '(BR-010, UC-004 § 5)', () async {
    final OndeSheetViewModel withHistory = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(withHistory.dispose);
    await withHistory.open(_fixturePoint());
    final OndeSheetData present = (withHistory.state as OndeSheetPrete).data;
    expect(present.seasonNotice, contains('mai'));
    expect(present.seasonNotice, contains('septembre'));

    onde.answer = (OndeStationCode station, int limit) async =>
        <OndeObservation>[];
    final OndeSheetViewModel withoutHistory = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 2, 15),
    );
    addTearDown(withoutHistory.dispose);
    await withoutHistory.open(_fixturePoint());
    final OndeSheetData absent = (withoutHistory.state as OndeSheetPrete).data;
    expect(absent.seasonNotice, contains('mai'));
    expect(absent.seasonNotice, contains('septembre'));
    expect(absent.seasonNotice, present.seasonNotice);
  });

  test('la campagne du 2025-09-26 vue le 2026-02-15 a 142 jours et devient '
      'ancienne (BR-010, UC-004 A1, le cas hors saison)', () async {
    // Les cinq observations de la fixture à partir de la campagne du
    // 2025-09-26 : la plus récente connue pour ce point, un 15 février.
    final List<OndeObservation> all = _fixtureObservations();
    final int index = all.indexWhere(
      (OndeObservation o) => o.observedAt == DateTime.utc(2025, 9, 26),
    );
    expect(index, isNonNegative, reason: 'la fixture porte cette campagne');
    onde.answer = (OndeStationCode station, int limit) async =>
        all.skip(index).take(limit).toList();

    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 2, 15),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.latest?.observedAt, DateTime.utc(2025, 9, 26));
    expect(data.ageInDays, 142);
    expect(data.age, CampaignAge.ancienne);
  });

  test('aucune campagne pour le point : OndeSheetPrete sans observation, sans '
      'age, avec un texte d absence explicite — le point n est jamais retire '
      '(BR-007, UC-004 A4, D8)', () async {
    onde.answer = (OndeStationCode station, int limit) async =>
        <OndeObservation>[];
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 2, 15),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetState state = viewModel.state;
    expect(state, isA<OndeSheetPrete>());
    final OndeSheetData data = (state as OndeSheetPrete).data;
    expect(data.point.code, OndeStationCode('K4520001'));
    expect(data.latest, isNull);
    expect(data.history, isEmpty);
    expect(data.age, isNull);
    expect(data.ageInDays, isNull);
    expect(data.officialModalityText, isNotEmpty);
    _expectNoBannedWord(data.officialModalityText);
  });

  test('modalite officielle absente : texte explicite, jamais une chaine '
      'vide ni un « code null » (BR-007, BR-011)', () async {
    // Cas SYNTHÉTIQUE, et assumé comme tel : `Q-05` a compté zéro
    // `code_ecoulement` nul le 2026-09-13, aucune capture réelle ne porte
    // donc ce cas — que BR-007 impose pourtant de tenir. Le point et la date
    // restent ceux de la fixture.
    final OndeObservation real = _fixtureObservations().first;
    final OndeObservation withoutModality = OndeObservation(
      station: real.station,
      point: real.point,
      observedAt: real.observedAt,
      category: const Inconnu(null),
      rawFlowCode: null,
      officialLabel: null,
      campaignCode: real.campaignCode,
    );
    onde.answer = (OndeStationCode station, int limit) async =>
        <OndeObservation>[withoutModality];

    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.officialModalityText, isNotEmpty);
    expect(data.officialModalityText, isNot(contains('null')));
    expect(flowCategoryLabel(data.latest!.category), 'Non renseigné');
    // L'âge reste affiché : BR-010 ne souffre aucune exception, même quand
    // la modalité manque.
    expect(data.ageInDays, 19);
    expect(data.age, CampaignAge.recente);
  });

  test('modalite officielle : code present, libelle absent — le repli nomme '
      'le manque, jamais un « code 3 — null » (BR-007)', () async {
    // Cas SYNTHÉTIQUE, et assumé comme tel : le mapper lit `code_ecoulement`
    // et `libelle_ecoulement` indépendamment
    // (`lib/data/mappers/onde_observation_mapper.dart` l.53 et 62), chacun
    // pouvant être `null` sans l'autre — `Q-05` n'a capturé aucune ligne où
    // seul l'un des deux manque. Le point et la date restent ceux de la
    // fixture.
    final OndeObservation real = _fixtureObservations().first;
    final OndeObservation codeOnly = OndeObservation(
      station: real.station,
      point: real.point,
      observedAt: real.observedAt,
      category: real.category,
      rawFlowCode: real.rawFlowCode,
      officialLabel: null,
      campaignCode: real.campaignCode,
    );
    onde.answer = (OndeStationCode station, int limit) async =>
        <OndeObservation>[codeOnly];

    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.officialModalityText, contains('code 3'));
    expect(data.officialModalityText, contains('libellé non renseigné'));
    expect(data.officialModalityText, isNot(contains('null')));
  });

  test('modalite officielle : libelle present, code absent — le repli nomme '
      'le manque, jamais un « null — Assec » (BR-007)', () async {
    // Cas SYNTHÉTIQUE, et assumé comme tel : même raison que ci-dessus, la
    // branche symétrique.
    final OndeObservation real = _fixtureObservations().first;
    final OndeObservation labelOnly = OndeObservation(
      station: real.station,
      point: real.point,
      observedAt: real.observedAt,
      category: real.category,
      rawFlowCode: null,
      officialLabel: real.officialLabel,
      campaignCode: real.campaignCode,
    );
    onde.answer = (OndeStationCode station, int limit) async =>
        <OndeObservation>[labelOnly];

    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    expect(data.officialModalityText, contains('code non renseigné'));
    expect(data.officialModalityText, contains('Assec'));
    expect(data.officialModalityText, isNot(contains('null')));
  });

  test(
    'aucun MOT ENTIER banni dans les chaines produites, et jamais '
    '« Assec » dans un libelle de categorie affiche (BR-003, glossaire)',
    () async {
      final OndeSheetViewModel viewModel = OndeSheetViewModel(
        onde: onde,
        favorites: favorites,
        now: () => DateTime.utc(2026, 9, 13),
      );
      addTearDown(viewModel.dispose);

      await viewModel.open(_fixturePoint());

      final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
      final List<String> produced = <String>[
        data.officialModalityText,
        data.seasonNotice,
        ...data.history.map(
          (OndeObservation o) => flowCategoryLabel(o.category),
        ),
      ];
      expect(produced, hasLength(7));
      for (final String label in produced) {
        _expectNoBannedWord(label);
      }
      for (final OndeObservation observation in data.history) {
        expect(
          flowCategoryLabel(observation.category),
          isNot(contains('Assec')),
          reason: 'le glossaire proscrit « Assec » côté interface : « À sec »',
        );
      }
    },
  );

  test('aucun verbe d instruction ni mot de garantie de BR-014 dans les '
      'chaines produites (officialModalityText, seasonNotice, '
      'flowCategoryLabel)', () async {
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
      now: () => DateTime.utc(2026, 9, 13),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetData data = (viewModel.state as OndeSheetPrete).data;
    final List<String> produced = <String>[
      data.officialModalityText,
      data.seasonNotice,
      ...data.history.map((OndeObservation o) => flowCategoryLabel(o.category)),
    ];
    expect(produced, hasLength(7));
    for (final String label in produced) {
      _expectNoBr014ForbiddenWord(label);
    }
  });

  test('un depot qui leve fait passer en OndeSheetEnEchec : la cause est '
      'conservee, le point aussi, pour que la vue nomme le lieu et la source '
      '(UC-001 A4)', () async {
    final Exception failure = Exception('panne Hub Eau');
    onde.answer = (OndeStationCode station, int limit) async => throw failure;
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    final OndeSheetState state = viewModel.state;
    expect(state, isA<OndeSheetEnEchec>());
    expect((state as OndeSheetEnEchec).cause, same(failure));
    expect(state.point.code, OndeStationCode('K4520001'));
    expect(state.point.label, 'LA RIVIERE AUX LOCHES A CHAON');
  });

  test('un depot qui leve de facon SYNCHRONE (sans async) fait aussi passer '
      'en OndeSheetEnEchec, sans propager', () async {
    final Exception failure = Exception('panne synchrone');
    // Pas de `async` ici : la levée survient AVANT tout `await`.
    onde.answer = (OndeStationCode station, int limit) => throw failure;
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_fixturePoint());

    expect(viewModel.state, isA<OndeSheetEnEchec>());
    expect((viewModel.state as OndeSheetEnEchec).cause, same(failure));
  });

  test('close() ferme immediatement, avec une notification', () {
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.close();

    expect(viewModel.state, isA<OndeSheetFermee>());
    expect(notifications, 1);
  });

  test('une reponse tardive d un open() precedent n ecrase pas close() '
      '(garde par jeton de generation)', () async {
    final Completer<List<OndeObservation>> tardive =
        Completer<List<OndeObservation>>();
    onde.answer = (OndeStationCode station, int limit) => tardive.future;
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
    );
    addTearDown(viewModel.dispose);

    final Future<void> opening = viewModel.open(_fixturePoint());
    expect(viewModel.state, isA<OndeSheetEnCours>());

    viewModel.close();
    expect(viewModel.state, isA<OndeSheetFermee>());

    tardive.complete(_fixtureHistory());
    await opening;

    expect(
      viewModel.state,
      isA<OndeSheetFermee>(),
      reason: "la réponse tardive de l'open abandonné ne doit rien écrire",
    );
  });

  test(
    'B ouvert pendant A : B gagne (garde par jeton de generation)',
    () async {
      final Completer<List<OndeObservation>> slow =
          Completer<List<OndeObservation>>();
      final Completer<List<OndeObservation>> fast =
          Completer<List<OndeObservation>>();
      int attempt = 0;
      onde.answer = (OndeStationCode station, int limit) {
        attempt++;
        return attempt == 1 ? slow.future : fast.future;
      };
      final OndePoint pointA = _fixturePoint();
      // Vraies valeurs de la station `K4640001`, lues dans
      // `test/fixtures/onde/observations_bbox_loire_2026-09-13.json` — pas
      // celles de `K4520001` (la fixture de ce fichier) : ce point n'est là
      // que pour être un point B distinct, pas pour porter une observation.
      final OndePoint pointB = OndePoint(
        code: OndeStationCode('K4640001'),
        label: 'LA BONNEURE A MILLANCAY',
        latitude: 47.444182169,
        longitude: 1.78116675,
        waterCourseLabel: 'la Bonne Heure',
        departement: const AdministrativeArea(code: '41', label: '41'),
      );
      final OndeSheetViewModel viewModel = OndeSheetViewModel(
        onde: onde,
        favorites: favorites,
        now: () => DateTime.utc(2026, 9, 13),
      );
      addTearDown(viewModel.dispose);

      final Future<void> openingA = viewModel.open(pointA);
      final Future<void> openingB = viewModel.open(pointB);

      fast.complete(_fixtureHistory());
      await openingB;
      slow.complete(_fixtureHistory());
      await openingA;

      final OndeSheetState state = viewModel.state;
      expect(state, isA<OndeSheetPrete>());
      expect((state as OndeSheetPrete).data.point.code, pointB.code);
    },
  );

  test('open sur un ViewModel dispose ne leve rien : la reponse tardive ne '
      'notifie plus', () async {
    final Completer<List<OndeObservation>> tardive =
        Completer<List<OndeObservation>>();
    onde.answer = (OndeStationCode station, int limit) => tardive.future;
    final OndeSheetViewModel viewModel = OndeSheetViewModel(
      onde: onde,
      favorites: favorites,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    final Future<void> opening = viewModel.open(_fixturePoint());
    viewModel.dispose();
    tardive.complete(_fixtureHistory());

    await expectLater(opening, completes);
    expect(
      notifications,
      1,
      reason:
          'seule la transition OndeSheetEnCours, émise avant dispose(), '
          'a notifié',
    );
  });

  test('switch exhaustif sur OndeSheetState, sans default (BR-011)', () {
    const OndeSheetState state = OndeSheetFermee();

    final String label = switch (state) {
      OndeSheetFermee() => 'fermee',
      OndeSheetEnCours() => 'en cours',
      OndeSheetPrete() => 'prete',
      OndeSheetEnEchec() => 'en echec',
    };

    expect(label, 'fermee');
  });

  group('favori', () {
    final DateTime clock = DateTime.utc(2026, 10, 12, 9, 30);

    OndeSheetViewModel build([FavoriteRepository? repository]) {
      final OndeSheetViewModel viewModel = OndeSheetViewModel(
        onde: onde,
        favorites: repository ?? favorites,
        // Une horloge LOCALE : l'instant d'ajout doit sortir en UTC.
        now: () => clock.toLocal(),
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    /// Le point de la fixture, sous un autre code (mêmes autres champs).
    OndePoint pointWithCode(String code) {
      final OndePoint base = _fixturePoint();
      return OndePoint(
        code: OndeStationCode(code),
        label: base.label,
        latitude: base.latitude,
        longitude: base.longitude,
        waterCourseLabel: base.waterCourseLabel,
        departement: base.departement,
        region: base.region,
      );
    }

    OndePointFavorite favoriteOf(OndePoint point) =>
        OndePointFavorite(point: point, addedAt: _addedBefore);

    /// La bascule d'ajout, commune aux trois états visibles : étoile vide et
    /// active avant, le dépôt porte le point ENTIER et l'horloge en UTC, puis
    /// étoile pleine et active.
    Future<void> expectAddsFrom(
      OndeSheetViewModel viewModel,
      OndePoint point,
    ) async {
      expect(viewModel.favoriteStar, _emptyActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, <Favorite>[
        OndePointFavorite(point: point, addedAt: clock),
      ]);
      final OndePointFavorite stored =
          favorites.stored.single as OndePointFavorite;
      expect(stored.addedAt.isUtc, true);
      expect(stored.point, same(point));
      expect(viewModel.favoriteStar, _filledActive);
    }

    test('fiche OndeSheetEnCours, liste vide : etoile vide et active ; la '
        'bascule ajoute le point entier et l instant de l horloge en UTC, '
        'puis l etoile est pleine et active', () async {
      final Completer<List<OndeObservation>> pending =
          Completer<List<OndeObservation>>();
      onde.answer = (OndeStationCode station, int limit) => pending.future;
      final OndeSheetViewModel viewModel = build();
      final OndePoint point = _fixturePoint();

      final Future<void> opening = viewModel.open(point);
      await pumpEventQueue();
      expect(viewModel.state, isA<OndeSheetEnCours>());

      await expectAddsFrom(viewModel, point);
      expect(viewModel.state, isA<OndeSheetEnCours>());

      pending.complete(_fixtureHistory());
      await opening;
      expect(viewModel.state, isA<OndeSheetPrete>());
      expect(viewModel.favoriteStar, _filledActive);
    });

    test('fiche OndeSheetPrete, liste vide : etoile vide et active ; la '
        'bascule ajoute le point entier et l instant de l horloge en UTC, '
        'puis l etoile est pleine et active', () async {
      final OndeSheetViewModel viewModel = build();
      final OndePoint point = _fixturePoint();

      await viewModel.open(point);
      expect(viewModel.state, isA<OndeSheetPrete>());

      await expectAddsFrom(viewModel, point);
    });

    test('fiche OndeSheetEnEchec, liste vide : etoile vide et active ; la '
        'bascule ajoute le point entier et l instant de l horloge en UTC, '
        'puis l etoile est pleine et active', () async {
      onde.answer = (OndeStationCode station, int limit) async =>
          throw Exception('panne');
      final OndeSheetViewModel viewModel = build();
      final OndePoint point = _fixturePoint();

      await viewModel.open(point);
      expect(viewModel.state, isA<OndeSheetEnEchec>());

      await expectAddsFrom(viewModel, point);
      expect(viewModel.state, isA<OndeSheetEnEchec>());
    });

    test('le point stocke est celui recu, code verbatim : un code a espaces '
        'de bord est ajoute tel quel, et la fiche ouverte sur le code sans '
        'espaces a une etoile vide', () async {
      final OndePoint spaced = pointWithCode(' O968 5312 ');
      final OndeSheetViewModel viewModel = build();
      await viewModel.open(spaced);

      await viewModel.toggleFavorite();

      expect(
        (favorites.stored.single as OndePointFavorite).point.code.value,
        ' O968 5312 ',
      );

      await viewModel.open(pointWithCode('O968 5312'));
      expect(viewModel.favoriteStar, _emptyActive);

      await viewModel.open(spaced);
      expect(viewModel.favoriteStar, _filledActive);
    });

    test('point deja en favori, fiche OndeSheetEnEchec : etoile pleine et '
        'active ; la bascule le retire, l etoile est vide et active (le '
        'point reste connu), la fiche reste en echec', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      onde.answer = (OndeStationCode station, int limit) async =>
          throw Exception('panne');
      final OndeSheetViewModel viewModel = build();

      await viewModel.open(_fixturePoint());
      expect(viewModel.state, isA<OndeSheetEnEchec>());
      expect(viewModel.favoriteStar, _filledActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, isEmpty);
      expect(viewModel.favoriteStar, _emptyActive);
      expect(viewModel.state, isA<OndeSheetEnEchec>());
    });

    test('point deja en favori, fiche OndeSheetPrete : etoile pleine ; la '
        'bascule le retire', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final OndeSheetViewModel viewModel = build();

      await viewModel.open(_fixturePoint());
      expect(viewModel.favoriteStar, _filledActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, isEmpty);
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('point deja en favori, fiche OndeSheetEnCours : etoile pleine AVANT '
        'la fin du chargement, et retirable', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final Completer<List<OndeObservation>> pending =
          Completer<List<OndeObservation>>();
      onde.answer = (OndeStationCode station, int limit) => pending.future;
      final OndeSheetViewModel viewModel = build();

      final Future<void> opening = viewModel.open(_fixturePoint());
      await pumpEventQueue();
      expect(viewModel.state, isA<OndeSheetEnCours>());
      expect(viewModel.favoriteStar, _filledActive);

      await viewModel.toggleFavorite();
      expect(favorites.stored, isEmpty);
      expect(viewModel.favoriteStar, _emptyActive);

      pending.complete(_fixtureHistory());
      await opening;
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('meme code, autre type : une station seule au depot ne rend pas '
        'l etoile du point ONDE pleine ; apres la bascule le depot porte '
        'DEUX favoris', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        StationFavorite(
          code: StationCode('K447001001'),
          label: 'La Loire à Blois',
          addedAt: _addedBefore,
        ),
      ]);
      final OndePoint point = pointWithCode('K447001001');
      final OndeSheetViewModel viewModel = build();

      await viewModel.open(point);
      expect(viewModel.favoriteStar, _emptyActive);

      await viewModel.toggleFavorite();

      expect(favorites.stored, hasLength(2));
      expect(favorites.stored.whereType<StationFavorite>(), hasLength(1));
      expect(favorites.stored.whereType<OndePointFavorite>(), hasLength(1));
      expect(viewModel.favoriteStar, _filledActive);
    });

    test(
      'pendant une ecriture l etoile garde sa forme, inactive ; une seconde '
      'bascule n appelle pas le depot ; porte ouverte : pleine, active',
      () async {
        final OndeSheetViewModel viewModel = build();
        await viewModel.open(_fixturePoint());
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
        'dit ; la fiche reste OndeSheetPrete ; une bascule reussie l '
        'efface', () async {
      final OndeSheetViewModel viewModel = build();
      await viewModel.open(_fixturePoint());
      final OndeSheetState before = viewModel.state;
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.toggleFavorite();

      expect(
        viewModel.favoriteStar,
        const FavoriteStar(filled: false, enabled: true, writeFailed: true),
      );
      expect(viewModel.state, same(before));
      expect(favorites.stored, isEmpty);

      favorites.writeError = null;
      await viewModel.toggleFavorite();

      expect(viewModel.favoriteStar, _filledActive);
      expect(favorites.stored, hasLength(1));
    });

    test('un retrait en echec laisse l etoile pleine, active, et le dit ; '
        'une nouvelle ouverture l efface', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final OndeSheetViewModel viewModel = build();
      await viewModel.open(_fixturePoint());
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.toggleFavorite();

      expect(
        viewModel.favoriteStar,
        const FavoriteStar(filled: true, enabled: true, writeFailed: true),
      );
      expect(favorites.stored, hasLength(1));

      await viewModel.open(_fixturePoint());
      expect(viewModel.favoriteStar, _filledActive);
    });

    for (final bool failing in <bool>[false, true]) {
      test('liste illisible, fiche ${failing ? 'OndeSheetEnEchec' : 'Prete'} '
          ': etoile vide et inactive, la bascule n appelle pas le '
          'depot', () async {
        favorites.readError = const ListeDeFavorisIllisible('x');
        if (failing) {
          onde.answer = (OndeStationCode station, int limit) async =>
              throw Exception('panne');
        }
        final OndeSheetViewModel viewModel = build();

        await viewModel.open(_fixturePoint());
        expect(
          viewModel.state,
          failing ? isA<OndeSheetEnEchec>() : isA<OndeSheetPrete>(),
        );
        expect(viewModel.favoriteStar, _emptyInactive);

        await viewModel.toggleFavorite();
        expect(favorites.writeCalls, 0);
      });
    }

    test('toute autre levee de la lecture vaut liste illisible, et la fiche '
        'reste OndeSheetPrete', () async {
      favorites.readError = StateError('autre');
      final OndeSheetViewModel viewModel = build();

      await viewModel.open(_fixturePoint());

      expect(viewModel.state, isA<OndeSheetPrete>());
      expect(viewModel.favoriteStar, _emptyInactive);
    });

    test('chaque ouverture relit le depot : un ajout fait par un autre client '
        'entre deux ouvertures donne une etoile pleine', () async {
      final OndeSheetViewModel viewModel = build();

      await viewModel.open(_fixturePoint());
      expect(viewModel.favoriteStar, _emptyActive);

      await favorites.add(favoriteOf(_fixturePoint()));
      viewModel.close();
      await viewModel.open(_fixturePoint());

      expect(viewModel.favoriteStar, _filledActive);
      expect(favorites.readCalls, 2);
    });

    test('la fiche passe a OndeSheetPrete sans attendre la lecture des '
        'favoris ; le futur d open ne se complete qu apres elle', () async {
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final OndeSheetViewModel viewModel = build();
      bool opened = false;

      final Future<void> opening = viewModel
          .open(_fixturePoint())
          .then((_) => opened = true);
      await pumpEventQueue();

      expect(viewModel.state, isA<OndeSheetPrete>());
      expect(viewModel.favoriteStar, isNull);
      expect(opened, isFalse);

      gate.complete();
      await opening;

      expect(opened, isTrue);
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('close() pendant la lecture des favoris : aucune etoile, aucune '
        'notification tardive', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final OndeSheetViewModel viewModel = build();

      final Future<void> opening = viewModel.open(_fixturePoint());
      await pumpEventQueue();
      viewModel.close();
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      gate.complete();
      await opening;

      expect(viewModel.state, isA<OndeSheetFermee>());
      expect(viewModel.favoriteStar, isNull);
      expect(notifications, 0);
    });

    test('open(A) puis open(B) avant la fin de la lecture : l etoile est '
        'celle de B', () async {
      // A est en favori, B ne l'est pas.
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final OndeSheetViewModel viewModel = build();
      final OndePoint pointB = pointWithCode('K4640001');

      final Future<void> openingA = viewModel.open(_fixturePoint());
      final Future<void> openingB = viewModel.open(pointB);
      expect(favorites.readCalls, 2);

      gate.complete();
      await openingB;
      await openingA;

      expect((viewModel.state as OndeSheetPrete).data.point.code, pointB.code);
      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('une ecriture d une ouverture abandonnee n ecrit rien dans l etoile '
        'de la suivante', () async {
      final OndeSheetViewModel viewModel = build();
      await viewModel.open(_fixturePoint());
      final Completer<void> gate = Completer<void>();
      favorites.writeGate = gate;
      favorites.writeError = const EcritureDeFavorisEnEchec('x');

      final Future<void> toggling = viewModel.toggleFavorite();
      await viewModel.open(pointWithCode('K4640001'));
      expect(viewModel.favoriteStar, _emptyActive);

      gate.complete();
      await toggling;

      expect(viewModel.favoriteStar, _emptyActive);
    });

    test('dispose() pendant une ecriture : aucune exception, aucune '
        'notification', () async {
      final OndeSheetViewModel viewModel = OndeSheetViewModel(
        onde: onde,
        favorites: favorites,
      );
      await viewModel.open(_fixturePoint());
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
      final OndeSheetViewModel viewModel = OndeSheetViewModel(
        onde: onde,
        favorites: favorites,
      );
      await viewModel.open(_fixturePoint());
      expect(viewModel.favoriteStar, _emptyActive);
      viewModel.dispose();

      await viewModel.toggleFavorite();

      expect(favorites.writeCalls, 0);
      expect(favorites.stored, isEmpty);
    });

    test('une lecture de favoris qui change l etoile notifie, et elle '
        'seule', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final Completer<void> gate = Completer<void>();
      favorites.readGate = gate;
      final OndeSheetViewModel viewModel = build();
      final Future<void> opening = viewModel.open(_fixturePoint());
      await pumpEventQueue();
      expect(viewModel.state, isA<OndeSheetPrete>());
      final List<FavoriteStar?> seen = <FavoriteStar?>[];
      viewModel.addListener(() => seen.add(viewModel.favoriteStar));

      gate.complete();
      await opening;

      expect(seen, <FavoriteStar?>[_filledActive]);
    });

    test('chaque bascule notifie : inactive pendant l ecriture, puis la '
        'nouvelle forme', () async {
      final OndeSheetViewModel viewModel = build();
      await viewModel.open(_fixturePoint());
      final List<FavoriteStar?> seen = <FavoriteStar?>[];
      viewModel.addListener(() => seen.add(viewModel.favoriteStar));

      await viewModel.toggleFavorite();

      expect(seen, <FavoriteStar?>[_emptyInactive, _filledActive]);
    });

    test('fiche OndeSheetFermee : aucune etoile, avant toute ouverture comme '
        'apres close(), et la bascule n appelle pas le depot', () async {
      favorites = InMemoryFavoriteRepository(<Favorite>[
        favoriteOf(_fixturePoint()),
      ]);
      final OndeSheetViewModel viewModel = build();

      expect(viewModel.favoriteStar, isNull);

      await viewModel.open(_fixturePoint());
      expect(viewModel.favoriteStar, _filledActive);
      viewModel.close();

      expect(viewModel.favoriteStar, isNull);
      await viewModel.toggleFavorite();
      expect(favorites.writeCalls, 0);
    });
  });
}

/// L'instant d'ajout d'un favori déjà stocké, distinct de l'horloge des tests.
final DateTime _addedBefore = DateTime.utc(2026, 10, 1, 8);

const FavoriteStar _emptyActive = FavoriteStar(filled: false, enabled: true);
const FavoriteStar _emptyInactive = FavoriteStar(filled: false, enabled: false);
const FavoriteStar _filledActive = FavoriteStar(filled: true, enabled: true);

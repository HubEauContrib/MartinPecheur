// Verrouille le ViewModel de la fiche station, sans monter aucun widget.
// Meme style que `test/features/map/view_model/map_view_model_test.dart` :
// des doubles de depot qui comptent leurs appels et rendent ce qu'on leur dit
// de rendre, une horloge injectee, des `Completer` pour rejouer les courses.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

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

/// Libellés choisis pour ne recouper aucun mot banni de BR-003 : un vrai
/// libellé Hub'Eau de qualification (« Bonne ») contiendrait « bon » et
/// ferait échouer le balayage à tort — ce test évite volontairement ce
/// libellé plutôt que d'affaiblir le balayage.
HydroObservation _debit({
  required DateTime measuredAt,
  CubicMetresPerSecond value = const CubicMetresPerSecond(47.8),
  String? statusLabel = 'Temps réel',
  String? qualificationLabel = 'Certifiée',
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

void main() {
  late _StationRepositoryDouble stations;
  late _HydroObservationRepositoryDouble observations;

  setUp(() {
    stations = _StationRepositoryDouble();
    observations = _HydroObservationRepositoryDouble();
  });

  test(
    "open passe par EnCours puis Prete, et notifie exactement deux fois",
    () async {
      observations.answer = (StationCode code, Grandeur grandeur) async =>
          grandeur == Grandeur.debit
          ? _debit(measuredAt: DateTime.utc(2026, 9, 13, 9))
          : null;
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        now: () => DateTime.utc(2026, 9, 13, 10),
      );
      addTearDown(viewModel.dispose);
      final List<StationSheetState> vus = <StationSheetState>[];
      viewModel.addListener(() => vus.add(viewModel.state));

      await viewModel.open(_codeBlois());

      expect(vus, hasLength(2));
      expect(vus.first, isA<EnCours>());
      expect(vus.last, isA<Prete>());
    },
  );

  test(
    'open interroge le debit ET la hauteur aupres du depot, chacun une fois',
    () async {
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
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

  test('le debit converti vaut 47,8 m3/s, et aucun libelle produit ne contient '
      'un mot banni (BR-003)', () async {
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _debit(measuredAt: DateTime.utc(2026, 9, 13, 9, 30))
        : null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<Prete>());
    final StationSheetData data = (state as Prete).data;
    expect(data.discharge?.discharge, const CubicMetresPerSecond(47.8));

    const List<String> motsBannis = <String>[
      'suffisant',
      'insuffisant',
      'normal',
      'bon',
      'sûr',
    ];
    final List<String?> libelles = <String?>[
      data.statusLabel,
      data.qualificationLabel,
      data.stalenessNotice,
    ];
    for (final String? libelle in libelles) {
      if (libelle == null) {
        continue;
      }
      final String enMinuscules = libelle.toLowerCase();
      for (final String mot in motsBannis) {
        expect(
          enMinuscules.contains(mot),
          isFalse,
          reason: '"$mot" trouve dans le libelle "$libelle" (BR-003)',
        );
      }
    }
  });

  test(
    'une observation du 2026-08-27T08:00Z vue le 2026-09-13T10:00Z est '
    'perimee, avec un avis qui cite la date (BR-005, le cas des 17 jours)',
    () async {
      observations.answer = (StationCode code, Grandeur grandeur) async =>
          grandeur == Grandeur.debit
          ? _debit(measuredAt: DateTime.utc(2026, 8, 27, 8))
          : null;
      final StationSheetViewModel viewModel = StationSheetViewModel(
        observations: observations,
        stations: stations,
        now: () => DateTime.utc(2026, 9, 13, 10),
      );
      addTearDown(viewModel.dispose);

      await viewModel.open(_codeBlois());

      final StationSheetData data = (viewModel.state as Prete).data;
      expect(data.freshness, Freshness.perimee);
      expect(data.stalenessNotice, isNotNull);
      expect(data.stalenessNotice, contains('27/08/2026'));
    },
  );

  test('vue 1 h apres la mesure : fraiche et aucun avis ; vue 3 h apres : '
      'ancienne et « il y a 3 h » (BR-005)', () async {
    final DateTime mesure = DateTime.utc(2026, 9, 13, 8);
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit ? _debit(measuredAt: mesure) : null;

    final StationSheetViewModel fraiche = StationSheetViewModel(
      observations: observations,
      stations: stations,
      now: () => mesure.add(const Duration(hours: 1)),
    );
    addTearDown(fraiche.dispose);
    await fraiche.open(_codeBlois());
    final StationSheetData donneesFraiches = (fraiche.state as Prete).data;
    expect(donneesFraiches.freshness, Freshness.fraiche);
    expect(donneesFraiches.stalenessNotice, isNull);

    final StationSheetViewModel ancienne = StationSheetViewModel(
      observations: observations,
      stations: stations,
      now: () => mesure.add(const Duration(hours: 3)),
    );
    addTearDown(ancienne.dispose);
    await ancienne.open(_codeBlois());
    final StationSheetData donneesAnciennes = (ancienne.state as Prete).data;
    expect(donneesAnciennes.freshness, Freshness.ancienne);
    expect(donneesAnciennes.stalenessNotice, contains('il y a 3 h'));
  });

  test('qualification et statut absents deviennent "non qualifiee" et "non '
      'renseigne", jamais une chaine vide (BR-006, BR-011)', () async {
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        grandeur == Grandeur.debit
        ? _debit(
            measuredAt: DateTime.utc(2026, 9, 13, 9),
            statusLabel: null,
            qualificationLabel: null,
          )
        : null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetData data = (viewModel.state as Prete).data;
    expect(data.statusLabel, 'non renseigné');
    expect(data.qualificationLabel, 'non qualifiée');
    expect(data.statusLabel, isNotEmpty);
    expect(data.qualificationLabel, isNotEmpty);
  });

  test('un debit absent laisse Prete sans valeur, sans fraicheur ni avis : '
      'jamais un zero (BR-007, UC-003 A3)', () async {
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
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
    final Exception panne = Exception('panne');
    observations.answer = (StationCode code, Grandeur grandeur) async =>
        throw panne;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<EnEchec>());
    expect((state as EnEchec).cause, same(panne));
    expect(state.code, _codeBlois());
  });

  test('une station inconnue (findByCode rend null) fait passer en EnEchec, '
      'avec une cause qui nomme le code', () async {
    stations.answer = (StationCode code) async => null;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
    );
    addTearDown(viewModel.dispose);

    await viewModel.open(_codeBlois());

    final StationSheetState state = viewModel.state;
    expect(state, isA<EnEchec>());
    expect((state as EnEchec).cause.toString(), contains('K447001001'));
    expect(observations.calls, 0);
  });

  test('close() ferme immediatement, avec une notification', () {
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
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
    final Completer<Station?> tardive = Completer<Station?>();
    stations.answer = (StationCode code) => tardive.future;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
    );
    addTearDown(viewModel.dispose);

    final Future<void> enCours = viewModel.open(_codeBlois());
    expect(viewModel.state, isA<EnCours>());

    viewModel.close();
    expect(viewModel.state, isA<Fermee>());

    tardive.complete(_station(_codeBlois()));
    await enCours;

    expect(
      viewModel.state,
      isA<Fermee>(),
      reason: "la reponse tardive de l'open abandonne ne doit rien ecrire",
    );
  });

  test('open(B) pendant que open(A) est en cours : l etat final est celui de '
      'B, quel que soit l ordre d arrivee des reponses', () async {
    final StationCode codeA = _codeBlois();
    final StationCode codeB = _codeGoyaves();
    final Completer<Station?> lente = Completer<Station?>();
    final Completer<Station?> rapide = Completer<Station?>();
    int appel = 0;
    stations.answer = (StationCode code) {
      appel++;
      return appel == 1 ? lente.future : rapide.future;
    };
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
    );
    addTearDown(viewModel.dispose);

    final Future<void> chargementA = viewModel.open(codeA);
    final Future<void> chargementB = viewModel.open(codeB);

    rapide.complete(_station(codeB));
    await chargementB;
    lente.complete(_station(codeA));
    await chargementA;

    final StationSheetState state = viewModel.state;
    expect(state, isA<Prete>());
    expect((state as Prete).data.station.code, codeB);
  });

  test('open sur un ViewModel dispose ne leve rien : la reponse tardive ne '
      'notifie plus', () async {
    final Completer<Station?> tardive = Completer<Station?>();
    stations.answer = (StationCode code) => tardive.future;
    final StationSheetViewModel viewModel = StationSheetViewModel(
      observations: observations,
      stations: stations,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    final Future<void> enCours = viewModel.open(_codeBlois());
    viewModel.dispose();
    tardive.complete(_station(_codeBlois()));

    await expectLater(enCours, completes);
    expect(
      notifications,
      1,
      reason: "seule la transition EnCours, emise avant dispose(), a notifie",
    );
  });

  test('switch exhaustif sur StationSheetState, sans default (BR-011)', () {
    const StationSheetState state = Fermee();

    final String libelle = switch (state) {
      Fermee() => 'fermee',
      EnCours() => 'en cours',
      Prete() => 'prete',
      EnEchec() => 'en echec',
    };

    expect(libelle, 'fermee');
  });
}

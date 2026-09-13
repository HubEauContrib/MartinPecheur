// Verrouille le cablage des deux gestionnaires de T0 :
// StationsWithinBoundsQuery achemine vers StationRepository (le chemin
// general, pour un futur appelant qui a besoin de la Station entiere) ;
// StationPointsWithinBoundsQuery filtre directement la liste de
// StationPoint deja chargee, sans passer par le depot (arbitrage T0-M4,
// evite de reconvertir jusqu'a 4 150 Station a chaque geste de camera).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/handlers.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Double de test minimal : rend une reponse fixe, note l'emprise recue.
final class _StationRepositoryDouble implements StationRepository {
  Bounds? empriseRecue;
  List<Station> reponse = <Station>[];

  @override
  Future<Station?> findByCode(StationCode code) async =>
      throw UnimplementedError('non utilise par ces tests');

  @override
  Future<List<Station>> findWithinBounds(Bounds bounds) async {
    empriseRecue = bounds;
    return reponse;
  }

  @override
  Future<List<Station>> findByDepartement(DepartementCode code) async =>
      throw UnimplementedError('non utilise par ces tests');
}

void main() {
  late Bus bus;
  late _StationRepositoryDouble repository;
  late StationPoint blois;
  late StationPoint guadeloupe;

  setUp(() {
    bus = Bus();
    repository = _StationRepositoryDouble();
    blois = StationPoint(
      code: StationCode('K447001001'),
      label: 'La Loire à Blois',
      latitude: 47.584957074,
      longitude: 1.335147948,
    );
    guadeloupe = StationPoint(
      code: StationCode('1011000101'),
      label: 'Grande Rivière à Goyaves',
      latitude: 16.189402,
      longitude: -61.658989,
    );
  });

  group('StationsWithinBoundsQuery — achemine vers StationRepository', () {
    test('la reponse et l\'emprise du depot sont celles envoyees', () async {
      final Station stationBlois = Station(
        code: blois.code,
        label: blois.label,
        latitude: blois.latitude,
        longitude: blois.longitude,
        departement: DepartementCode('41'),
        riverLabel: 'la Loire',
        inService: true,
      );
      repository.reponse = <Station>[stationBlois];
      registerHandlers(
        bus,
        stationRepository: repository,
        stationPoints: <StationPoint>[blois, guadeloupe],
      );
      final Bounds emprise = Bounds(west: -1, south: 46, east: 3, north: 48);

      final List<Station> resultat = await bus.send<List<Station>>(
        StationsWithinBoundsQuery(emprise),
      );

      expect(resultat, <Station>[stationBlois]);
      expect(repository.empriseRecue, same(emprise));
    });
  });

  group(
    'StationPointsWithinBoundsQuery — filtre directement stationPoints',
    () {
      test('ne passe pas par StationRepository, rend les StationPoint dans '
          "l'emprise", () async {
        registerHandlers(
          bus,
          stationRepository: repository,
          stationPoints: <StationPoint>[blois, guadeloupe],
        );

        final List<StationPoint> resultat = await bus.send<List<StationPoint>>(
          StationPointsWithinBoundsQuery(
            Bounds(west: 1, south: 47, east: 2, north: 48),
          ),
        );

        expect(resultat, <StationPoint>[blois]);
        expect(
          repository.empriseRecue,
          isNull,
          reason:
              'StationPointsWithinBoundsQuery ne doit jamais toucher au '
              'depot (arbitrage T0-M4)',
        );
      });

      test('applique la marge par defaut du filtre (defaultViewportMargin, '
          'viewport_filter.dart) : Blois hors de l\'emprise stricte mais '
          'dans la marge de 0,5 est tout de meme retenu', () async {
        registerHandlers(
          bus,
          stationRepository: repository,
          stationPoints: <StationPoint>[blois, guadeloupe],
        );
        // Emprise stricte 1° x 1° qui exclut Blois (lat 47,58 > north
        // 47,2 ; lon 1,335 > east 1) mais que la marge de 0,5 (moitie de
        // la hauteur/largeur) elargit assez pour l'inclure (north+0,5 =
        // 47,7 ; east+0,5 = 1,5).
        final Bounds empriseEtroite = Bounds(
          west: 0,
          south: 46.2,
          east: 1,
          north: 47.2,
        );

        final List<StationPoint> resultat = await bus.send<List<StationPoint>>(
          StationPointsWithinBoundsQuery(empriseEtroite),
        );

        expect(resultat, <StationPoint>[blois]);
      });
    },
  );
}

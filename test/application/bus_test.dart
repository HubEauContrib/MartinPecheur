// Un registre explicite de gestionnaires : ni bibliotheque de mediateur, ni
// reflexion. Ces tests couvrent l'acheminement par Type, le refus d'un
// second gestionnaire pour le meme message, et la propagation sans filet des
// erreurs levees par un gestionnaire (BR-007).

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

void main() {
  late Bus bus;
  late Station blois;

  setUp(() {
    bus = Bus();
    blois = Station(
      code: StationCode('K447001001'),
      label: 'Blois',
      latitude: 47.5861,
      longitude: 1.3359,
      departement: DepartementCode('41'),
      riverLabel: 'La Loire',
      inService: true,
    );
  });

  group('registeredMessages', () {
    test('est vide, puis contient le type enregistre', () {
      expect(bus.registeredMessages, isEmpty);

      bus.register<StationByCodeQuery, Station?>(
        (StationByCodeQuery query) async =>
            query.code == blois.code ? blois : null,
      );

      expect(bus.registeredMessages, <Type>{StationByCodeQuery});
    });
  });

  group('send — acheminement', () {
    test('un message enregistre est achemine, la reponse est statiquement '
        'Station?', () async {
      bus.register<StationByCodeQuery, Station?>(
        (StationByCodeQuery query) async =>
            query.code == blois.code ? blois : null,
      );

      final Station? trouvee = await bus.send<Station?>(
        StationByCodeQuery(blois.code),
      );
      final Station? absente = await bus.send<Station?>(
        StationByCodeQuery(StationCode('ZZZZZZZZZZ')),
      );

      expect(trouvee, blois);
      expect(absente, isNull);
    });

    test(
      'un message sans gestionnaire leve un StateError nommant le type recu',
      () {
        expect(
          () => bus.send<Station?>(StationByCodeQuery(blois.code)),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('StationByCodeQuery'),
            ),
          ),
        );
      },
    );

    test('un message sans gestionnaire nomme aussi la liste des gestionnaires '
        'connus', () {
      bus.register<StationsWithinBoundsQuery, List<Station>>(
        (StationsWithinBoundsQuery query) async => <Station>[blois],
      );

      expect(
        () => bus.send<Station?>(StationByCodeQuery(blois.code)),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('Gestionnaires connus'),
          ),
        ),
      );
    });

    test('deux messages differents rendent chacun sa propre valeur', () async {
      bus.register<StationByCodeQuery, Station?>(
        (StationByCodeQuery query) async =>
            query.code == blois.code ? blois : null,
      );
      bus.register<StationsWithinBoundsQuery, List<Station>>(
        (StationsWithinBoundsQuery query) async => <Station>[blois],
      );

      final Station? station = await bus.send<Station?>(
        StationByCodeQuery(blois.code),
      );
      final List<Station> stations = await bus.send<List<Station>>(
        StationsWithinBoundsQuery(
          Bounds(west: -1, south: 46, east: 3, north: 48),
        ),
      );

      expect(station, blois);
      expect(stations, <Station>[blois]);
    });

    test("le gestionnaire recoit le message entier, l'emprise recue est "
        'identical a celle envoyee', () async {
      Bounds? empriseRecue;
      bus.register<StationsWithinBoundsQuery, List<Station>>((
        StationsWithinBoundsQuery query,
      ) async {
        empriseRecue = query.bounds;
        return <Station>[];
      });
      final Bounds empriseEnvoyee = Bounds(
        west: -1,
        south: 46,
        east: 3,
        north: 48,
      );

      await bus.send<List<Station>>(StationsWithinBoundsQuery(empriseEnvoyee));

      expect(empriseRecue, same(empriseEnvoyee));
    });

    test('une FormatException du gestionnaire remonte telle quelle', () {
      bus.register<StationByCodeQuery, Station?>((
        StationByCodeQuery query,
      ) async {
        throw const FormatException('code illisible');
      });

      expect(
        () => bus.send<Station?>(StationByCodeQuery(blois.code)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('register — un seul gestionnaire par type de message', () {
    test(
      'un second enregistrement pour le meme message leve un StateError',
      () {
        bus.register<StationByCodeQuery, Station?>(
          (StationByCodeQuery query) async => null,
        );

        expect(
          () => bus.register<StationByCodeQuery, Station?>(
            (StationByCodeQuery query) async => null,
          ),
          throwsStateError,
        );
      },
    );
  });
}

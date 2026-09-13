// Verifie que le type de la reponse voyage avec le message, et que Query et
// Command restent deux familles distinctes malgre leur ascendance commune
// (Message) — condition necessaire pour qu'un seul registre (Bus, cf.
// lib/application/bus.dart) les achemine toutes les deux sans jamais les
// confondre.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Double minimal pour tester la relation de type `Query<void>` /
/// `Command<void>` sans dependre d'une requete reelle : aucune des deux
/// requetes du domaine n'est un `Query<void>`.
final class _VoidQuery implements Query<void> {
  const _VoidQuery();
}

void main() {
  group('StationsWithinBoundsQuery', () {
    test('est un Query<List<Station>> et un Message<List<Station>>, '
        "l'emprise est conservee", () {
      final Bounds emprise = Bounds(west: -1, south: 46, east: 3, north: 48);
      final StationsWithinBoundsQuery query = StationsWithinBoundsQuery(
        emprise,
      );

      expect(query, isA<Query<List<Station>>>());
      expect(query, isA<Message<List<Station>>>());
      expect(query.bounds, same(emprise));
    });
  });

  group('StationByCodeQuery', () {
    test('est un Query<Station?>, le code est conserve', () {
      final StationByCodeQuery query = StationByCodeQuery(
        StationCode('K447001001'),
      );

      expect(query, isA<Query<Station?>>());
      expect(query.code.value, 'K447001001');
    });
  });

  group('Query et Command — deux familles distinctes', () {
    test("une requete n'est pas un Command<Object?>", () {
      final StationByCodeQuery query = StationByCodeQuery(
        StationCode('K447001001'),
      );

      expect(query, isNot(isA<Command<Object?>>()));
    });

    test("Query<void> n'est pas Command<void>, et une requete reste un "
        'Message<Station?>', () {
      const _VoidQuery voidQuery = _VoidQuery();
      expect(voidQuery, isNot(isA<Command<void>>()));

      final StationByCodeQuery query = StationByCodeQuery(
        StationCode('K447001001'),
      );
      expect(query, isA<Message<Station?>>());
    });
  });
}

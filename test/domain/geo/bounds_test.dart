// Verrouille Bounds a son nouvel emplacement (`lib/domain/geo/bounds.dart`,
// relecture du 2026-09-13) : ces cas viennent de
// `test/domain/repositories/repositories_test.dart`, ou ils vivaient tant que
// Bounds etait declaree dans le fichier des contrats de depot.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';

void main() {
  group('Bounds', () {
    test('expose ses quatre bords', () {
      final Bounds bounds = Bounds(west: -1, south: 46, east: 3, north: 48);

      expect(bounds.west, -1);
      expect(bounds.south, 46);
      expect(bounds.east, 3);
      expect(bounds.north, 48);
    });

    test('un bord est a l ouest de l ouest est refuse a la construction', () {
      expect(
        () => Bounds(west: 3, south: 46, east: -1, north: 48),
        throwsArgumentError,
      );
    });

    test('un bord nord au sud du bord sud est refuse a la construction', () {
      expect(
        () => Bounds(west: -1, south: 48, east: 3, north: 46),
        throwsArgumentError,
      );
    });

    test('deux emprises aux quatre bords identiques sont egales, et '
        'partagent le meme hashCode', () {
      final Bounds a = Bounds(west: -1, south: 46, east: 3, north: 48);
      final Bounds b = Bounds(west: -1, south: 46, east: 3, north: 48);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('une emprise dont un seul bord differe n est pas egale', () {
      final Bounds reference = Bounds(west: -1, south: 46, east: 3, north: 48);

      expect(
        reference,
        isNot(Bounds(west: -1.1, south: 46, east: 3, north: 48)),
      );
      expect(
        reference,
        isNot(Bounds(west: -1, south: 46.1, east: 3, north: 48)),
      );
      expect(
        reference,
        isNot(Bounds(west: -1, south: 46, east: 3.1, north: 48)),
      );
      expect(
        reference,
        isNot(Bounds(west: -1, south: 46, east: 3, north: 48.1)),
      );
    });
  });
}

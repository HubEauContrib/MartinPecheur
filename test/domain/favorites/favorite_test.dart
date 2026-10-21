// Le favori : type clos à quatre branches (S1 de T3, BR-011).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

final DateTime _added = DateTime.utc(2026, 10, 11, 17, 5);

OndePoint _point({String code = 'K4640001', AdministrativeArea? region}) =>
    OndePoint(
      code: OndeStationCode(code),
      label: 'LA BONNEURE A MILLANCAY',
      latitude: 47.444182169,
      longitude: 1.78116675,
      waterCourseLabel: 'la Bonne Heure',
      departement: const AdministrativeArea(code: '41', label: '41'),
      region: region,
    );

StationFavorite _station({
  String code = 'K447001001',
  String label = 'La Loire à Blois',
  DateTime? addedAt,
}) => StationFavorite(
  code: StationCode(code),
  label: label,
  addedAt: addedAt ?? _added,
);

String _branch(Favorite f) => switch (f) {
  StationFavorite() => 'station',
  OndePointFavorite() => 'onde',
  FloodSectionFavorite() => 'troncon',
  UnreadableFavorite() => 'illisible',
};

void main() {
  group('construction', () {
    test('une station se construit', () {
      final StationFavorite f = _station();
      expect(f.code, StationCode('K447001001'));
      expect(f.label, 'La Loire à Blois');
      expect(f.addedAt, _added);
    });

    test('addedAt local → ArgumentError (station)', () {
      expect(
        () => StationFavorite(
          code: StationCode('K447001001'),
          label: 'La Loire à Blois',
          addedAt: DateTime(2026, 10, 11),
        ),
        throwsArgumentError,
      );
    });

    test('libellé blanc → ArgumentError', () {
      expect(() => _station(label: '  '), throwsArgumentError);
    });

    test('addedAt local → ArgumentError (point ONDE)', () {
      expect(
        () =>
            OndePointFavorite(point: _point(), addedAt: DateTime(2026, 10, 11)),
        throwsArgumentError,
      );
    });
  });

  group('sameFavoritePlace', () {
    test('même code, deux types → faux', () {
      final StationFavorite s = _station();
      final OndePointFavorite o = OndePointFavorite(
        point: _point(code: 'K447001001'),
        addedAt: _added,
      );
      expect(sameFavoritePlace(s, o), isFalse);
      expect(sameFavoritePlace(o, s), isFalse);
      expect(
        stationFavoriteIn(<Favorite>[o], StationCode('K447001001')),
        isNull,
      );
      expect(
        ondePointFavoriteIn(<Favorite>[s], OndeStationCode('K447001001')),
        isNull,
      );
    });

    test('deux stations de même code, libellé et date différents → vrai', () {
      expect(
        sameFavoritePlace(
          _station(),
          _station(label: 'Autre', addedAt: DateTime.utc(2025)),
        ),
        isTrue,
      );
    });

    test("deux points ONDE : l'espace est significatif", () {
      OndePointFavorite f(String c) => OndePointFavorite(
        point: _point(code: c),
        addedAt: _added,
      );
      expect(sameFavoritePlace(f('A721 3011'), f('A7213011')), isFalse);
      expect(sameFavoritePlace(f('A721 3011'), f('A721 3011')), isTrue);
    });

    test('illisibles : par texte brut', () {
      expect(
        sameFavoritePlace(
          const UnreadableFavorite(raw: '{}', label: 'x'),
          const UnreadableFavorite(raw: '{}'),
        ),
        isTrue,
      );
      expect(
        sameFavoritePlace(
          const UnreadableFavorite(raw: 'a', label: 'x'),
          const UnreadableFavorite(raw: 'b', label: 'x'),
        ),
        isFalse,
      );
      expect(
        sameFavoritePlace(const UnreadableFavorite(raw: '{}'), _station()),
        isFalse,
      );
    });

    test('stationFavoriteIn et ondePointFavoriteIn trouvent leur entrée', () {
      final StationFavorite s = _station();
      final OndePointFavorite o = OndePointFavorite(
        point: _point(),
        addedAt: _added,
      );
      final List<Favorite> list = <Favorite>[o, s];
      expect(stationFavoriteIn(list, StationCode('K447001001')), same(s));
      expect(ondePointFavoriteIn(list, OndeStationCode('K4640001')), same(o));
    });
  });

  group('type clos', () {
    test('switch sans default sur Favorite', () {
      expect(_branch(_station()), 'station');
      expect(_branch(const UnreadableFavorite(raw: '{}')), 'illisible');
      expect(
        _branch(OndePointFavorite(point: _point(), addedAt: _added)),
        'onde',
      );
    });
  });

  group('égalité structurelle', () {
    test('deux OndePointFavorite sur les mêmes valeurs sont égaux', () {
      final OndePointFavorite a = OndePointFavorite(
        point: _point(),
        addedAt: _added,
      );
      final OndePointFavorite b = OndePointFavorite(
        point: _point(),
        addedAt: _added,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un seul champ du point change → inégaux', () {
      final OndePointFavorite a = OndePointFavorite(
        point: _point(),
        addedAt: _added,
      );
      final OndePointFavorite b = OndePointFavorite(
        point: _point(
          region: const AdministrativeArea(
            code: '24',
            label: 'Centre-Val de Loire',
          ),
        ),
        addedAt: _added,
      );
      expect(a, isNot(b));
    });

    test('stations et illisibles', () {
      expect(_station(), _station());
      expect(_station().hashCode, _station().hashCode);
      expect(_station(), isNot(_station(label: 'Autre')));
      expect(
        const UnreadableFavorite(raw: '{}', label: 'x'),
        const UnreadableFavorite(raw: '{}', label: 'x'),
      );
      expect(
        const UnreadableFavorite(raw: '{}', label: 'x').hashCode,
        const UnreadableFavorite(raw: '{}', label: 'x').hashCode,
      );
      expect(
        const UnreadableFavorite(raw: '{}', label: 'x'),
        isNot(const UnreadableFavorite(raw: '{}')),
      );
    });
  });

  group('le favori tronçon (M1 de T5)', () {
    FloodSectionFavorite section({
      String code = 'LP106',
      String name = 'Loire amont',
      DateTime? addedAt,
    }) => FloodSectionFavorite(
      code: FloodSectionCode(code),
      name: name,
      addedAt: addedAt ?? _added,
    );

    test('il se construit et porte code, nom et date', () {
      final FloodSectionFavorite f = section();
      expect(f.code, FloodSectionCode('LP106'));
      expect(f.name, 'Loire amont');
      expect(f.addedAt, _added);
      expect(_branch(f), 'troncon');
    });

    test('addedAt local → ArgumentError', () {
      expect(
        () => section(addedAt: DateTime(2026, 10, 11)),
        throwsArgumentError,
      );
    });

    test('nom blanc → ArgumentError', () {
      expect(() => section(name: '  '), throwsArgumentError);
    });

    test('même code, noms différents : le même lieu, mais pas égaux', () {
      final FloodSectionFavorite a = section();
      final FloodSectionFavorite b = section(name: 'Loire (autre nom)');
      expect(sameFavoritePlace(a, b), isTrue);
      expect(a, isNot(b));
      expect(a, section());
      expect(a.hashCode, section().hashCode);
    });

    test('un tronçon et une station de même valeur de code : jamais le même '
        'lieu', () {
      final FloodSectionFavorite t = section(code: 'K447001001');
      final StationFavorite s = _station();
      expect(sameFavoritePlace(t, s), isFalse);
      expect(sameFavoritePlace(s, t), isFalse);
      expect(
        sameFavoritePlace(t, const UnreadableFavorite(raw: '{}')),
        isFalse,
      );
    });

    test('floodSectionFavoriteIn trouve le tronçon, ou rend null', () {
      final FloodSectionFavorite t = section();
      final List<Favorite> list = <Favorite>[_station(), t];
      expect(floodSectionFavoriteIn(list, FloodSectionCode('LP106')), same(t));
      expect(floodSectionFavoriteIn(list, FloodSectionCode('LP107')), isNull);
      expect(
        floodSectionFavoriteIn(<Favorite>[
          _station(code: 'K447001001'),
        ], FloodSectionCode('K447001001')),
        isNull,
      );
    });
  });
}

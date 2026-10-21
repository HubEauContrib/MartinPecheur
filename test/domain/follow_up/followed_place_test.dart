// Le lieu suivi : trois branches closes, déduites d'un favori (M2 de T5).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

final DateTime _added = DateTime.utc(2026, 10, 11, 17, 5);

void main() {
  group('followedPlaceOf', () {
    test('un favori station donne une StationPlace', () {
      final FollowedPlace? place = followedPlaceOf(
        StationFavorite(
          code: StationCode('K447001001'),
          label: 'La Loire à Blois',
          addedAt: _added,
        ),
      );
      expect(place, isA<StationPlace>());
      expect((place! as StationPlace).code, StationCode('K447001001'));
    });

    test('un favori point ONDE donne une OndePointPlace', () {
      final FollowedPlace? place = followedPlaceOf(
        OndePointFavorite(
          point: OndePoint(
            code: OndeStationCode('K4640001'),
            label: 'LA BONNEURE A MILLANCAY',
            latitude: 47.44,
            longitude: 1.78,
            waterCourseLabel: 'la Bonne Heure',
            departement: const AdministrativeArea(code: '41', label: '41'),
          ),
          addedAt: _added,
        ),
      );
      expect(place, isA<OndePointPlace>());
      expect((place! as OndePointPlace).code, OndeStationCode('K4640001'));
    });

    test('un favori tronçon donne une FloodSectionPlace', () {
      final FollowedPlace? place = followedPlaceOf(
        FloodSectionFavorite(
          code: FloodSectionCode('LC135'),
          name: 'La Loire amont',
          addedAt: _added,
        ),
      );
      expect(place, isA<FloodSectionPlace>());
      expect((place! as FloodSectionPlace).code, FloodSectionCode('LC135'));
    });

    test('un favori illisible ne donne aucun lieu', () {
      expect(followedPlaceOf(const UnreadableFavorite(raw: '{}')), isNull);
    });
  });

  group('égalité des lieux', () {
    test('par type et par code', () {
      expect(
        FloodSectionPlace(FloodSectionCode('A')),
        FloodSectionPlace(FloodSectionCode('A')),
      );
      expect(
        FloodSectionPlace(FloodSectionCode('A')),
        isNot(FloodSectionPlace(FloodSectionCode('B'))),
      );
      expect(
        OndePointPlace(OndeStationCode('K4640001')),
        OndePointPlace(OndeStationCode('K4640001')),
      );
      expect(
        StationPlace(StationCode('K447001001')).hashCode,
        StationPlace(StationCode('K447001001')).hashCode,
      );
    });

    test('une station et un point ONDE de même code sont deux lieux', () {
      expect(
        StationPlace(StationCode('K447001001')) ==
            OndePointPlace(OndeStationCode('K447001001')),
        isFalse,
      );
    });
  });
}

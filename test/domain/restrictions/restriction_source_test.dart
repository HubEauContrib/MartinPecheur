// Verrouille le contrat `RestrictionSource` passe au domaine (T2, M4,
// conception § 3) : un double de test en memoire implemente l'interface,
// recoit le `GeoPoint` passe, rend un `ZonesAtPoint`, leve chacune des trois
// branches de `RestrictionLookupFailure` — jamais ne les rend. Un `switch`
// exhaustif sur l'echec compile et rend `diagnostic` (BR-011).
//
// L'ancien contrat `lib/data/restrictions/restriction_source.dart`
// (SurfaceWaterRestriction, ADR-004 T0) est supprime par cette tache : ses
// deux tests d'interface disparaissent avec lui, seul le confinement
// (redefini par l'amendement d'ADR-004) reste teste sous
// `test/data/restrictions/restriction_source_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// Double de test : n'appelle jamais VigiEau, enregistre le point recu et
/// rend soit la reponse preparee, soit leve l'echec prepare.
final class _FakeRestrictionSource implements RestrictionSource {
  GeoPoint? pointRecu;
  ZonesAtPoint? reponse;
  RestrictionLookupFailure? echec;

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) async {
    pointRecu = point;
    final RestrictionLookupFailure? echecPrepare = echec;
    if (echecPrepare != null) {
      throw echecPrepare;
    }
    return reponse!;
  }
}

/// Un `switch` exhaustif sur l'echec — ne compile que si les trois branches
/// sont couvertes (BR-011) — rend le diagnostic de chaque branche.
String _diagnosticDe(RestrictionLookupFailure failure) => switch (failure) {
  SourceInjoignable() => failure.diagnostic,
  RequeteRefusee() => failure.diagnostic,
  ReponseIllisible() => failure.diagnostic,
};

void main() {
  group('RestrictionSource (T2, M4)', () {
    test('interrogee par un GeoPoint, rend un ZonesAtPoint et enregistre le '
        'point recu', () async {
      final GeoPoint point = GeoPoint(
        latitude: 47.584957074,
        longitude: 1.335147948,
      );
      final ZonesAtPoint zonesAttendues = ZonesAtPoint(
        point: point,
        retrievedAt: DateTime.utc(2026, 9, 27, 10),
        zones: const <AlertZone>[],
      );
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..reponse = zonesAttendues;

      final ZonesAtPoint zones = await source.zonesAt(point);

      expect(zones, zonesAttendues);
      expect(source.pointRecu, point);
    });

    test('leve SourceInjoignable, jamais rendu', () async {
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..echec = const SourceInjoignable('panne reseau : timeout');

      await expectLater(
        () => source.zonesAt(GeoPoint(latitude: 0, longitude: 0)),
        throwsA(isA<SourceInjoignable>()),
      );
    });

    test('leve RequeteRefusee, statusCode accessible', () async {
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..echec = const RequeteRefusee(
          statusCode: 409,
          diagnostic: 'statut 409 : commune ambigue',
        );

      RequeteRefusee? capturee;
      try {
        await source.zonesAt(GeoPoint(latitude: 0, longitude: 0));
      } on RequeteRefusee catch (failure) {
        capturee = failure;
      }

      expect(capturee, isNotNull);
      expect(capturee!.statusCode, 409);
    });

    test('leve ReponseIllisible, jamais rendu', () async {
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..echec = const ReponseIllisible('racine non tableau');

      await expectLater(
        () => source.zonesAt(GeoPoint(latitude: 0, longitude: 0)),
        throwsA(isA<ReponseIllisible>()),
      );
    });

    test('le switch exhaustif sur les trois branches rend le diagnostic', () {
      expect(_diagnosticDe(const SourceInjoignable('a')), 'a');
      expect(
        _diagnosticDe(const RequeteRefusee(statusCode: 400, diagnostic: 'b')),
        'b',
      );
      expect(_diagnosticDe(const ReponseIllisible('c')), 'c');
    });
  });
}

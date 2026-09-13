// Verrouille l'interface RestrictionSource (ADR-004) : la signature ne
// propose pas de commune (C-14), le niveau de gravite traverse brut
// (BR-011), et le vocabulaire VigiEau reste confine a ce module — un
// fichier hors `lib/data/restrictions/` qui le mentionnerait romprait la
// couture voulue par ADR-004.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/restriction_source.dart';

/// Double de test : n'appelle jamais VigiEau, enregistre simplement les
/// coordonnees recues et renvoie une reponse preparee.
final class _FakeRestrictionSource implements RestrictionSource {
  double? latitudeRecue;
  double? longitudeRecue;
  List<SurfaceWaterRestriction> reponse = const <SurfaceWaterRestriction>[];

  @override
  Future<List<SurfaceWaterRestriction>> surfaceWaterZonesAt({
    required double latitude,
    required double longitude,
  }) async {
    latitudeRecue = latitude;
    longitudeRecue = longitude;
    return reponse;
  }
}

void main() {
  group('RestrictionSource (ADR-004)', () {
    test('interrogee par latitude/longitude, renvoie une zone et enregistre '
        'les coordonnees recues', () async {
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..reponse = const <SurfaceWaterRestriction>[
          SurfaceWaterRestriction(
            rawSeverityLevel: 'crise',
            decreeFilePath: 'arrete-41-2026-09-13.pdf',
          ),
        ];

      final List<SurfaceWaterRestriction> zones = await source
          .surfaceWaterZonesAt(latitude: 47.584957074, longitude: 1.335147948);

      expect(zones, hasLength(1));
      expect(source.latitudeRecue, 47.584957074);
      expect(source.longitudeRecue, 1.335147948);
    });

    test('un niveau de gravite inedit est conserve tel quel, le PDF peut '
        'etre absent (BR-011)', () async {
      final _FakeRestrictionSource source = _FakeRestrictionSource()
        ..reponse = const <SurfaceWaterRestriction>[
          SurfaceWaterRestriction(
            rawSeverityLevel: 'un_niveau_inedit',
            decreeFilePath: null,
          ),
        ];

      final List<SurfaceWaterRestriction> zones = await source
          .surfaceWaterZonesAt(latitude: 0, longitude: 0);

      expect(zones.single.rawSeverityLevel, 'un_niveau_inedit');
      expect(zones.single.decreeFilePath, isNull);
    });
  });

  group('Confinement du vocabulaire VigiEau (ADR-004)', () {
    test('aucun fichier hors lib/data/restrictions/ ne mentionne vigieau, '
        'beta.gouv ou restriction (casse indifferente)', () {
      final Directory libDir = Directory('lib');
      final RegExp motsInterdits = RegExp(
        r'vigieau|beta\.gouv|restriction',
        caseSensitive: false,
      );

      final List<String> fichiersEnFaute = <String>[];
      for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final String normalizedPath = entity.path.replaceAll('\\', '/');
        if (normalizedPath.contains('lib/data/restrictions/')) {
          continue;
        }
        if (motsInterdits.hasMatch(entity.readAsStringSync())) {
          fichiersEnFaute.add(normalizedPath);
        }
      }

      expect(
        fichiersEnFaute,
        isEmpty,
        reason:
            'ADR-004 confine VigiEau a lib/data/restrictions/ : le risque '
            "de rupture d'une API en version 0.1 doit rester dans un seul "
            'module',
      );
    });

    test('aucun fichier de lib/data/restrictions/ ne contient package:http/ '
        '— aucune implementation en T0', () {
      final Directory restrictionsDir = Directory('lib/data/restrictions');
      final List<String> fichiersEnFaute = <String>[];

      for (final FileSystemEntity entity in restrictionsDir.listSync(
        recursive: true,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.readAsStringSync().contains('package:http/')) {
          fichiersEnFaute.add(entity.path);
        }
      }

      expect(fichiersEnFaute, isEmpty);
    });
  });
}

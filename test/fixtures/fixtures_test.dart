// Verrouille sur les fixtures réelles (capturées le 2026-09-13, verbatim,
// voir docs/sources/hubeau-hydrometrie.md et docs/sources/onde.md) les faits
// que les mappers devront respecter. Un échec ici est un fait nouveau sur
// l'API, pas un bug de test (CLAUDE.md, Anti-hallucination).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readFixture(String path) {
  final String content = File('test/fixtures/$path').readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}

List<Map<String, dynamic>> rows(Map<String, dynamic> response) {
  final List<dynamic> data = response['data'] as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
}

void main() {
  group('Hydrométrie — observations_tr (C-02, C-05, C-06)', () {
    test('le débit arrive en litres par seconde, pas en mètres cubes', () {
      final List<Map<String, dynamic>> lignes = rows(
        readFixture('hubeau/observations_tr_K447001001_Q_2026-09-13.json'),
      );
      final Map<String, dynamic> ligne = lignes.first;
      expect(ligne['grandeur_hydro'], 'Q');
      final num resultat = ligne['resultat_obs'] as num;
      expect(
        resultat > 1000,
        isTrue,
        reason:
            '47 800 l/s lu tel quel dépasserait la crue historique de la '
            "Loire d'un facteur mille si on omettait la division par 1000",
      );
    });

    test('la hauteur arrive en millimètres et peut être négative', () {
      final List<Map<String, dynamic>> lignes = rows(
        readFixture('hubeau/observations_tr_K447001001_H_2026-09-13.json'),
      );
      final Map<String, dynamic> ligne = lignes.first;
      expect(ligne['grandeur_hydro'], 'H');
      final num resultat = ligne['resultat_obs'] as num;
      expect(resultat.abs() > 100, isTrue);
      expect(resultat < 0, isTrue);
    });

    test('un code site renvoie chaque mesure en double, dont une ligne '
        'sans code station (C-05)', () {
      final List<Map<String, dynamic>> lignes = rows(
        readFixture('hubeau/observations_tr_site_K4470010_2026-09-13.json'),
      );
      expect(lignes.length, greaterThanOrEqualTo(2));
      expect(
        lignes.any((Map<String, dynamic> l) => l['code_station'] == null),
        isTrue,
      );
      expect(lignes[0]['date_obs'], lignes[1]['date_obs']);
    });
  });

  group('Hydrométrie — obs_elab (C-04)', () {
    test('sans date_debut_obs_elab, le tri est ignoré et renvoie du 1900', () {
      final Map<String, dynamic> ligne = rows(
        readFixture(
          'hubeau/obs_elab_K447001001_sans_date_debut_2026-09-13.json',
        ),
      ).first;
      expect((ligne['date_obs_elab'] as String).startsWith('1900'), isTrue);
    });

    test(
      'avec date_debut_obs_elab, la première ligne commence à cette date',
      () {
        final Map<String, dynamic> ligne = rows(
          readFixture(
            'hubeau/obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json',
          ),
        ).first;
        expect(ligne['date_obs_elab'], '2026-08-01');
      },
    );

    test('le champ de qualification ne porte pas le même nom selon '
        "l'endpoint : observations_tr expose libelle_qualification_obs "
        '(jamais libelle_qualification), obs_elab expose '
        'libelle_qualification', () {
      final Map<String, dynamic> ligneTr = rows(
        readFixture('hubeau/observations_tr_K447001001_Q_2026-09-13.json'),
      ).first;
      expect(ligneTr.containsKey('libelle_qualification_obs'), isTrue);
      expect(ligneTr.containsKey('libelle_qualification'), isFalse);

      final Map<String, dynamic> ligneElab = rows(
        readFixture(
          'hubeau/obs_elab_K447001001_depuis_2026-08-01_2026-09-13.json',
        ),
      ).first;
      expect(ligneElab.containsKey('libelle_qualification'), isTrue);
    });
  });

  group('Référentiel des stations (nommage des champs)', () {
    test('le référentiel nomme les coordonnées et le département autrement '
        'que observations_tr', () {
      final Map<String, dynamic> ligne = rows(
        readFixture('hubeau/referentiel_stations_K447001001_2026-09-13.json'),
      ).first;
      expect(ligne.containsKey('latitude_station'), isTrue);
      expect(ligne.containsKey('en_service'), isTrue);
      expect(ligne['code_departement'], '41');
    });
  });

  group('Écoulement ONDE (C-10)', () {
    late Map<String, dynamic> reponseOnde;
    late List<Map<String, dynamic>> lignesOnde;

    setUpAll(() {
      reponseOnde = readFixture(
        'onde/observations_departement_41_2026-09-13.json',
      );
      lignesOnde = rows(reponseOnde);
    });

    test('code_ecoulement est toujours une chaîne ou une absence, jamais un entier', () {
      for (final Map<String, dynamic> ligne in lignesOnde) {
        final Object? code = ligne['code_ecoulement'];
        expect(code == null || code is String, isTrue);
      }
    });

    test('les codes observés appartiennent à la nomenclature connue '
        "({'1','1a','1f','2','3','4'})", () {
      const Set<String> codesConnus = <String>{'1', '1a', '1f', '2', '3', '4'};
      final Set<Object?> codesObserves = lignesOnde
          .map((Map<String, dynamic> l) => l['code_ecoulement'])
          .toSet();
      for (final Object? code in codesObserves) {
        if (code == null) {
          continue;
        }
        expect(
          codesConnus.contains(code),
          isTrue,
          reason:
              'code inédit $code — à consigner dans docs/sources/onde.md (BR-011)',
        );
      }
    });
  });

  group('Extrait GeoJSON du référentiel (déclaré comme extrait)', () {
    late List<Map<String, dynamic>> features;

    setUpAll(() {
      final Map<String, dynamic> reponse = readFixture(
        'referentiel/stations_extrait_2026-09-13.json',
      );
      features = (reponse['features'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    });

    test('GeoJSON ordonne [longitude, latitude] — la Guadeloupe reste au '
        "large de la Guadeloupe, pas de la Somalie", () {
      final Map<String, dynamic> guadeloupe = features.firstWhere(
        (Map<String, dynamic> f) =>
            (f['properties'] as Map<String, dynamic>)['code_station'] ==
            '1011000101',
      );
      final List<dynamic> coordinates =
          (guadeloupe['geometry'] as Map<String, dynamic>)['coordinates']
              as List<dynamic>;
      expect(
        coordinates[0] as num,
        closeTo(-61.658989, 1e-5),
        reason:
            'valeur relevée dans assets/referentiel/stations.json le '
            '2026-09-13 : -61.65898959694908, tronquée à 6 décimales '
            'dans la fiche',
      );
      expect(coordinates[1] as num, closeTo(16.189402, 1e-5));
    });

    test('les code_station de l\'extrait font dix caractères', () {
      for (final Map<String, dynamic> feature in features) {
        final String code =
            (feature['properties'] as Map<String, dynamic>)['code_station']
                as String;
        expect(code.length, 10);
      }
    });
  });
}

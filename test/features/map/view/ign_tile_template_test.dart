// Verrouille le gabarit de tuiles IGN : l'ordre TILECOL/TILEROW,
// les paramètres WMTS obligatoires, et les constantes de couche. Intervertir
// TILECOL et TILEROW produit une carte qui s'affiche, transposée : seul un
// test qui distingue x et y à l'exécution attrape la panne.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';

void main() {
  group('ignTileUrlTemplate', () {
    test('porte les trois marqueurs de substitution {z}, {x}, {y}', () {
      expect(ignTileUrlTemplate, contains('TILEMATRIX={z}'));
      expect(ignTileUrlTemplate, contains('TILECOL={x}'));
      expect(ignTileUrlTemplate, contains('TILEROW={y}'));
    });

    test('porte les paramètres WMTS obligatoires', () {
      expect(
        ignTileUrlTemplate,
        contains('LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2'),
      );
      expect(ignTileUrlTemplate, contains('TILEMATRIXSET=PM'));
      expect(ignTileUrlTemplate, contains('FORMAT=image/png'));
      expect(ignTileUrlTemplate, contains('SERVICE=WMTS'));
      expect(ignTileUrlTemplate, contains('REQUEST=GetTile'));
    });

    test(
      "commence par l'hôte Géoplateforme et porte plus de cinq paramètres",
      () {
        expect(ignTileUrlTemplate, startsWith('https://data.geopf.fr/wmts?'));
        expect(ignTileUrlTemplate.split('&').length - 1, greaterThan(5));
      },
    );

    test('une fois les marqueurs substitués, TILECOL porte x et TILEROW '
        'porte y — les intervertir transposerait la carte sans erreur', () {
      final String substituted = ignTileUrlTemplate
          .replaceAll('{z}', '9')
          .replaceAll('{x}', '253')
          .replaceAll('{y}', '180');

      final Uri uri = Uri.parse(substituted);

      expect(uri.host, 'data.geopf.fr');
      expect(uri.queryParameters['TILEMATRIX'], '9');
      expect(uri.queryParameters['TILECOL'], '253');
      expect(uri.queryParameters['TILEROW'], '180');
    });
  });

  group('constantes de couche', () {
    test('la taille de tuile est 256 pixels', () {
      expect(ignTileDimension, 256);
    });

    test('le zoom natif maximal est 18', () {
      expect(ignMaxNativeZoom, 18);
    });

    test("l'attribution porte IGN et la mention Licence Ouverte", () {
      expect(ignAttribution, contains('IGN'));
      expect(ignAttribution, contains('Licence Ouverte'));
    });

    test("l'agent utilisateur nomme l'application appelante (C-12)", () {
      expect(ignUserAgentPackageName, 'fr.martinpecheur.app');
    });
  });
}

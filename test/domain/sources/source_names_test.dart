// Test miroir de `lib/domain/sources/source_names.dart` (Task W4) : deux
// constantes, deux noms distincts, Dart pur — aucun rendu ici. Le nom de
// source n'est PAS un texte d'avertissement (`warning_texts.dart`) : c'est
// pourquoi il vit dans son propre fichier. Les premiers lecteurs sont les
// deux fiches (`_MeasurementLine`, `_campagneLine`) et `mapSourceName`
// (`map_empty_states.dart`, qui ne recopie plus la chaîne ONDE) — pas
// l'encart daté, qui ne nomme aucune source.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';

void main() {
  group('source_names — un concept, un mot (glossary.md)', () {
    test("hydrometrieSourceName nomme la source Hub'Eau hydrométrie", () {
      expect(hydrometrieSourceName, "Hub'Eau hydrométrie");
    });

    test("ondeSourceName nomme la source Hub'Eau écoulement ONDE — la même "
        'chaîne que `mapSourceName(MapErrorSource.ecoulement)` rend déjà', () {
      expect(ondeSourceName, "Hub'Eau écoulement ONDE");
    });

    test('les deux noms sont distincts', () {
      expect(hydrometrieSourceName, isNot(ondeSourceName));
    });

    test('restrictionsSourceName nomme VigiEau (T2, M4)', () {
      expect(restrictionsSourceName, 'VigiEau');
    });

    test('restrictionsPublicSiteUrl est le site public, sans www.', () {
      expect(restrictionsPublicSiteUrl, 'https://vigieau.gouv.fr/');
      expect(restrictionsPublicSiteUrl, isNot(contains('www.')));
    });

    test('ignSourceName nomme le fond de carte IGN Géoplateforme (T2, S1)', () {
      expect(ignSourceName, 'IGN Géoplateforme');
    });

    test("ignAttribution est inchangée au caractère près, et nomme la source "
        'par ignSourceName — la seule définition, lue par la carte et par '
        "l'écran des sources", () {
      expect(ignAttribution, '© IGN Géoplateforme — Licence Ouverte');
      expect(ignAttribution, contains(ignSourceName));
      expect(ignAttribution, contains('Licence Ouverte'));
    });

    test('les quatre noms de source sont distincts', () {
      expect(<String>{
        hydrometrieSourceName,
        ondeSourceName,
        restrictionsSourceName,
        ignSourceName,
      }, hasLength(4));
    });
  });
}

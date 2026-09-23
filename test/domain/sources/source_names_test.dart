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
  });
}

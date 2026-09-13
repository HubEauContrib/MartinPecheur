// Verrouille les libelles des echelles de carte. Deux choses seulement, mais
// les deux comptent : les libelles sont ceux de `04-ui.md` (§ 2, echelles 1 et
// 2) et non une reformulation, et aucun d'eux ne contient un mot banni
// (BR-003) — c'est la legende que l'usager lit pour interpreter la couleur
// d'un marqueur, donc l'endroit exact ou « normal » se glisserait.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

/// Les cinq mots proscrits pour qualifier un debit (BR-003, `glossary.md`).
const List<String> bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

void main() {
  test('les echelles de T1 sont l ecoulement et le debit, et elles seules '
      '(la severite secheresse arrive en T2)', () {
    expect(MapScaleKind.values, <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
    ]);
  });

  test('mapScaleLabel rend les libelles de 04-ui.md, mot pour mot', () {
    expect(
      mapScaleLabel(MapScaleKind.ecoulement),
      'Écoulement',
      reason:
          'le libelle vient du filtre de 04-ui.md l.13 (`[Écoulement*]`), '
          'pas de son § 203 qui est un titre de section (« Écoulement '
          'ONDE »), pas le libelle lui-meme',
    );
    expect(
      mapScaleLabel(MapScaleKind.debit),
      "Débit relatif à l'historique",
      reason:
          'le libelle de l echelle 2 (04-ui.md l.213) dit bien « relatif a '
          "l historique » : c'est cette precision qui empeche de lire le "
          "marqueur comme un jugement sur le debit lui-meme (ADR-002)",
    );
  });

  test('aucun libelle d echelle ne contient un mot banni (BR-003)', () {
    for (final MapScaleKind kind in MapScaleKind.values) {
      final String label = mapScaleLabel(kind);
      final Set<String> words = label
          .toLowerCase()
          .split(RegExp(r'[^a-zà-öø-ÿ]+'))
          .toSet();
      for (final String banned in bannedWords) {
        expect(
          words,
          isNot(contains(banned)),
          reason: '"$banned" trouve MOT POUR MOT dans "$label" (BR-003)',
        );
      }
    }
  });
}

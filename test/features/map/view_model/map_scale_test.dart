// Verrouille les libelles des echelles de carte. Deux choses seulement, mais
// les deux comptent : les libelles sont ceux de `04-ui.md` (§ 2, echelles 1 et
// 2) et non une reformulation, et aucun d'eux ne contient un mot banni
// (BR-003) — c'est la legende que l'usager lit pour interpreter la couleur
// d'un marqueur, donc l'endroit exact ou « normal » se glisserait.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

import '../../../project/vocabulary_lists.dart';

/// Les cinq mots proscrits pour qualifier un debit (BR-003, `glossary.md`).
const List<String> bannedWords = <String>[
  'suffisant',
  'insuffisant',
  'normal',
  'bon',
  'sûr',
];

void main() {
  test('les echelles de la carte sont l ecoulement, le debit et la '
      'vigilance crues, dans cet ordre (L1 de T4, 2026-10-15)', () {
    expect(MapScaleKind.values, <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
      MapScaleKind.crues,
    ]);
  });

  test('mapScaleLabel(crues) vaut « Vigilance crues » (cadrage de T4, '
      '§ 7.2 et § 12.2)', () {
    expect(mapScaleLabel(MapScaleKind.crues), 'Vigilance crues');
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

  group('shouldPreloadOn — le debit ne se precharge que sur son echelle '
      '(C-15, NFR-07, migre de map_view_test.dart en H2, 2026-09-22)', () {
    test("l'echelle « debit » precharge : ses marqueurs sont ceux dont on "
        'lit le debit', () {
      expect(shouldPreloadOn(MapScaleKind.debit), isTrue);
    });

    test("l'echelle « ecoulement » ne precharge RIEN — aucune station n'est "
        "dessinee, et Hub'Eau n'a ni SLA ni quota chiffre (C-15)", () {
      expect(shouldPreloadOn(MapScaleKind.ecoulement), isFalse);
    });

    test("l'echelle « crues » ne precharge RIEN — aucune station n'y est "
        'dessinee (L1 de T4)', () {
      expect(shouldPreloadOn(MapScaleKind.crues), isFalse);
    });

    test('une seule echelle precharge — la decision est exhaustive sur '
        "l'enumeration, jamais un defaut silencieux (BR-011)", () {
      expect(MapScaleKind.values.where(shouldPreloadOn), <MapScaleKind>[
        MapScaleKind.debit,
      ]);
    });
  });

  group('titre et sous-titre des entrées du sélecteur de lecture (S1 '
      "d'Ergonomie, cadrage du 2026-10-17, § 11.2)", () {
    test('les titres sont ceux du § 11.2, mot pour mot', () {
      expect(mapScaleEntryTitle(MapScaleKind.ecoulement), 'Écoulement');
      expect(mapScaleEntryTitle(MapScaleKind.debit), 'Débit');
      expect(mapScaleEntryTitle(MapScaleKind.crues), 'Vigilance crues');
    });

    test('les sous-titres sont ceux du § 11.2, mot pour mot ; celui des '
        'crues nomme la source par floodSourceName', () {
      expect(
        mapScaleEntrySubtitle(MapScaleKind.ecoulement),
        'observé sur le terrain',
      );
      expect(
        mapScaleEntrySubtitle(MapScaleKind.debit),
        "relatif à l'historique",
      );
      expect(
        mapScaleEntrySubtitle(MapScaleKind.crues),
        'publiée par Vigicrues',
      );
    });

    test('aucun titre ni sous-titre ne contient un mot proscrit '
        '(BR-003, BR-014 : listes de vocabulary_lists.dart)', () {
      final List<String> proscrits = <String>[
        ...forbiddenFlowWords,
        ...forbiddenNeutralityPhrases,
        ...forbiddenGuaranteeWords,
      ];
      for (final MapScaleKind kind in MapScaleKind.values) {
        for (final String texte in <String>[
          mapScaleEntryTitle(kind),
          mapScaleEntrySubtitle(kind),
        ]) {
          for (final String mot in proscrits) {
            final RegExp motif = RegExp(
              r'(?<!\p{L})' + RegExp.escape(mot) + r'(?!\p{L})',
              caseSensitive: false,
              unicode: true,
            );
            expect(
              motif.hasMatch(texte),
              isFalse,
              reason: '« $mot » trouvé dans « $texte » ($kind)',
            );
          }
        }
      }
    });
  });
}

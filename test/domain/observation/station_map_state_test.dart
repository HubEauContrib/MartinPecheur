// StationMapState distingue « pas encore chargé » de « aucune donnée » :
// sans cette distinction, un écran en cours de chargement afficherait le
// même état qu'une absence de donnée constatée, ce que BR-007 interdit. Le
// switch exhaustif documenté ici verrouille BR-011 : une sous-classe
// ajoutée sans branche est une erreur de compilation, jamais un oubli
// silencieux à l'écran.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';

/// Les états possibles d'un [StationMapState], un par branche du `switch`
/// — une seule liste, réutilisée par le test des mots bannis et par le
/// test du switch exhaustif, pour ne pas faire diverger deux énumérations
/// manuelles des mêmes cas.
final List<StationMapState> allStates = List<StationMapState>.unmodifiable(
  <StationMapState>[
    const NonChargee(),
    const SansDonnee(),
    const Chargee(Freshness.fraiche),
    const Chargee(Freshness.ancienne),
    const Chargee(Freshness.perimee),
    EnEchec(Exception('panne')),
  ],
);

void main() {
  group('StationMapState (BR-007)', () {
    test('NonChargee et SansDonnee sont deux états distincts', () {
      expect(const NonChargee(), isNot(const SansDonnee()));
    });

    test("EnEchec porte la cause de l'échec", () {
      final Object cause = Exception('panne source');
      final EnEchec state = EnEchec(cause);

      expect(state.cause, cause);
    });

    test("Chargee porte la fraîcheur de l'observation", () {
      const Chargee state = Chargee(Freshness.fraiche);

      expect(state.freshness, Freshness.fraiche);
    });
  });

  group('stationMapStateLabel (BR-007, BR-003)', () {
    test('SansDonnee -> "Aucune donnée disponible ici." exactement', () {
      expect(
        stationMapStateLabel(const SansDonnee()),
        'Aucune donnée disponible ici.',
      );
    });

    test('NonChargee -> aucun libellé (chaîne vide) : un chargement en '
        "cours n'affiche pas d'état par défaut", () {
      expect(stationMapStateLabel(const NonChargee()), '');
    });

    test('Chargee(ancienne) est exactement construit sur ancienneApres '
        '(BR-005) — pas un « 2 » recopié en dur', () {
      expect(
        stationMapStateLabel(const Chargee(Freshness.ancienne)),
        'Dernière mesure il y a plus de ${ancienneApres.inHours} h',
      );
    });

    test('Chargee(perimee) est exactement construit sur perimeeApres '
        '(BR-005) — pas un « 24 » recopié en dur', () {
      expect(
        stationMapStateLabel(const Chargee(Freshness.perimee)),
        'Dernière mesure il y a plus de ${perimeeApres.inHours} h',
      );
    });

    test('EnEchec -> "Donnée indisponible pour le moment."', () {
      expect(
        stationMapStateLabel(EnEchec(Exception('panne'))),
        'Donnée indisponible pour le moment.',
      );
    });

    test('aucun libellé ne contient un mot banni', () {
      const List<String> motsBannis = <String>[
        'suffisant',
        'insuffisant',
        'normal',
        'bon',
        'sûr',
      ];
      final List<String> libelles = allStates
          .map(stationMapStateLabel)
          .toList();

      for (final String libelle in libelles) {
        final String normalized = libelle.toLowerCase();
        for (final String mot in motsBannis) {
          expect(
            normalized.contains(mot),
            isFalse,
            reason: '"$libelle" contient le mot banni "$mot"',
          );
        }
      }
    });

    test('switch exhaustif sur StationMapState : une sous-classe sans '
        'branche est une erreur de compilation (BR-011)', () {
      String describe(StationMapState state) => switch (state) {
        NonChargee() => 'non chargée',
        Chargee() => 'chargée',
        SansDonnee() => 'sans donnée',
        EnEchec() => 'en échec',
      };

      final List<String> descriptions = allStates.map(describe).toList();

      expect(descriptions, <String>[
        'non chargée',
        'sans donnée',
        'chargée',
        'chargée',
        'chargée',
        'en échec',
      ]);
    });
  });
}

// StationMapState distingue « pas encore charge » de « aucune donnee » :
// sans cette distinction, un ecran en cours de chargement afficherait le
// meme etat qu'une absence de donnee constatee, ce que BR-007 interdit. Le
// switch exhaustif documente ici verrouille BR-011 : une sous-classe
// ajoutee sans branche est une erreur de compilation, jamais un oubli
// silencieux a l'ecran.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';

void main() {
  group('StationMapState (BR-007)', () {
    test('NonChargee et SansDonnee sont deux etats distincts', () {
      expect(const NonChargee(), isNot(const SansDonnee()));
    });

    test('EnEchec porte la cause de l\'echec', () {
      final Object cause = Exception('panne source');
      final EnEchec state = EnEchec(cause);

      expect(state.cause, cause);
    });

    test('Chargee porte la fraicheur de l\'observation', () {
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

    test('NonChargee -> aucun libelle (chaine vide) : un chargement en '
        "cours n'affiche pas d'etat par defaut", () {
      expect(stationMapStateLabel(const NonChargee()), '');
    });

    test('Chargee(perimee) contient "Dernière mesure"', () {
      expect(
        stationMapStateLabel(const Chargee(Freshness.perimee)),
        contains('Dernière mesure'),
      );
    });

    test('EnEchec -> "Donnée indisponible pour le moment."', () {
      expect(
        stationMapStateLabel(EnEchec(Exception('panne'))),
        'Donnée indisponible pour le moment.',
      );
    });

    test('aucun libelle ne contient un mot banni', () {
      const List<String> motsBannis = <String>[
        'suffisant',
        'insuffisant',
        'normal',
        'bon',
        'sûr',
      ];
      final List<String> libelles = <String>[
        stationMapStateLabel(const NonChargee()),
        stationMapStateLabel(const SansDonnee()),
        stationMapStateLabel(const Chargee(Freshness.fraiche)),
        stationMapStateLabel(const Chargee(Freshness.ancienne)),
        stationMapStateLabel(const Chargee(Freshness.perimee)),
        stationMapStateLabel(EnEchec(Exception('panne'))),
      ];

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
        NonChargee() => 'non chargee',
        Chargee() => 'chargee',
        SansDonnee() => 'sans donnee',
        EnEchec() => 'en echec',
      };

      expect(describe(const NonChargee()), 'non chargee');
      expect(describe(const Chargee(Freshness.fraiche)), 'chargee');
      expect(describe(const SansDonnee()), 'sans donnee');
      expect(describe(EnEchec(Exception('x'))), 'en echec');
    });
  });
}

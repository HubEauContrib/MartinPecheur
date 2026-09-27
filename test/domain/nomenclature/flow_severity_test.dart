// Verrouille mostSevere (BR-009) : l'ordre de sévérité, les deux branches
// hors classement (NonObserve, Inconnu) et leur ordre de repli, et
// l'indépendance à l'ordre de la liste — cas cités mot pour mot par
// `docs/br/BR-009-cluster-porte-l-etat-le-plus-severe.md`.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/nomenclature/flow_severity.dart';

void main() {
  group('mostSevere (BR-009)', () {
    test('19 × Ecoulement + 1 × Assec → Assec, cas cité par BR-009', () {
      final List<FlowCategory> categories = <FlowCategory>[
        for (int i = 0; i < 19; i++) const Ecoulement(),
        const Assec(),
      ];

      expect(mostSevere(categories), const Assec());
    });

    test('NonObserve + 1 × Ecoulement → Ecoulement, cas cité par BR-009', () {
      expect(
        mostSevere(const <FlowCategory>[NonObserve(), Ecoulement()]),
        const Ecoulement(),
      );
    });

    test('EcoulementFaible et EcoulementNonVisible → EcoulementNonVisible, '
        "et l'inverse rend le même résultat", () {
      expect(
        mostSevere(const <FlowCategory>[
          EcoulementFaible(),
          EcoulementNonVisible(),
        ]),
        const EcoulementNonVisible(),
      );
      expect(
        mostSevere(const <FlowCategory>[
          EcoulementNonVisible(),
          EcoulementFaible(),
        ]),
        const EcoulementNonVisible(),
      );
    });

    test('Ecoulement et EcoulementFaible → EcoulementFaible, et l\'inverse '
        'rend le même résultat', () {
      expect(
        mostSevere(const <FlowCategory>[Ecoulement(), EcoulementFaible()]),
        const EcoulementFaible(),
      );
      expect(
        mostSevere(const <FlowCategory>[EcoulementFaible(), Ecoulement()]),
        const EcoulementFaible(),
      );
    });

    test('NonObserve et Inconnu(9z) → NonObserve : un fait de terrain '
        "constaté prime sur notre ignorance d'un code (BR-007), quel que "
        "soit l'ordre", () {
      expect(
        mostSevere(const <FlowCategory>[NonObserve(), Inconnu('9z')]),
        const NonObserve(),
      );
      expect(
        mostSevere(const <FlowCategory>[Inconnu('9z'), NonObserve()]),
        const NonObserve(),
      );
    });

    test('un seul Inconnu(null) → Inconnu(null)', () {
      expect(
        mostSevere(const <FlowCategory>[Inconnu(null)]),
        const Inconnu(null),
      );
    });

    test('19 × Ecoulement + 1 × Assec, inversé → Assec (mot pour mot '
        'BR-009), le résultat ne dépend pas de l\'ordre de la liste', () {
      final List<FlowCategory> categories = <FlowCategory>[
        for (int i = 0; i < 19; i++) const Ecoulement(),
        const Assec(),
      ];

      expect(mostSevere(categories.reversed), const Assec());
    });

    test('NonObserve + 1 × Ecoulement, inversé → Ecoulement (mot pour mot '
        'BR-009)', () {
      expect(
        mostSevere(const <FlowCategory>[Ecoulement(), NonObserve()]),
        const Ecoulement(),
      );
    });

    test('liste vide : ArgumentError — rien à classer', () {
      expect(() => mostSevere(const <FlowCategory>[]), throwsArgumentError);
    });
  });
}

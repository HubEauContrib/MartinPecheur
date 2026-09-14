// Verrouille C-10 : code_ecoulement est une chaine, jamais normalisee au
// stockage. sealed class et non enumeration : Inconnu doit porter la valeur
// brute recue (BR-011). NonObserve (fait de terrain) et Inconnu (notre
// ignorance) restent distincts (BR-007, ADR-006).
//
// Les six libelles de `flowCategoryLabel` sont RETAPES ici : ce sont ceux de
// la colonne « Libelle carte » d'ADR-006 et de `04-ui.md` § 2, les SEULS du
// projet depuis la relecture du 2026-09-14 (carte et fiche disent le meme
// mot — `glossary.md`, un concept un mot). « Non renseigne » pour Inconnu
// est une deviation d'ADR-006, retenue pour BR-007 et a acter par le
// commanditaire.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';

void main() {
  group('flowCategoryFromCode — codes releves le 2026-09-13 sur le '
      'departement 41 (C-10)', () {
    test("'1a' (116 occurrences) devient Ecoulement", () {
      expect(flowCategoryFromCode('1a'), const Ecoulement());
    });

    test("'1f' (95 occurrences) devient EcoulementFaible — signal "
        'precurseur', () {
      expect(flowCategoryFromCode('1f'), const EcoulementFaible());
    });

    test("'2' (24 occurrences) devient EcoulementNonVisible — flaques, "
        'plus d\'ecoulement', () {
      expect(flowCategoryFromCode('2'), const EcoulementNonVisible());
    });

    test("'3' (65 occurrences) devient Assec — lit sec", () {
      expect(flowCategoryFromCode('3'), const Assec());
    });
  });

  group("flowCategoryFromCode — codes '1' et '4', acceptes sans etre "
      'exiges (releves le 2026-08-01 sur huit departements)', () {
    test("'1' devient Ecoulement", () {
      expect(flowCategoryFromCode('1'), const Ecoulement());
    });

    test("'4' devient NonObserve — fait de terrain", () {
      expect(flowCategoryFromCode('4'), const NonObserve());
    });
  });

  group('flowCategoryFromCode — l\'inconnu porte la valeur brute (BR-011)', () {
    test('null devient Inconnu(null), sans lever', () {
      expect(() => flowCategoryFromCode(null), returnsNormally);
      expect(flowCategoryFromCode(null), const Inconnu(null));
    });

    test("'5z', code non reconnu, devient Inconnu et conserve '5z' dans "
        'rawCode', () {
      final FlowCategory category = flowCategoryFromCode('5z');

      expect(category, const Inconnu('5z'));
      expect((category as Inconnu).rawCode, '5z');
    });

    test("la casse et les espaces ne fabriquent pas un inconnu : '1A' "
        "devient Ecoulement et ' 1f ' devient EcoulementFaible", () {
      expect(flowCategoryFromCode('1A'), const Ecoulement());
      expect(flowCategoryFromCode(' 1f '), const EcoulementFaible());
    });

    test("le brut conserve dans Inconnu est celui RECU, non normalise : "
        "' 9X ' garde ses espaces et sa casse dans rawCode", () {
      final FlowCategory category = flowCategoryFromCode(' 9X ');

      expect((category as Inconnu).rawCode, ' 9X ');
    });

    test("une chaine vide devient Inconnu('')", () {
      expect(flowCategoryFromCode(''), const Inconnu(''));
    });
  });

  group('flowCategoryLabel — les libelles de la colonne « Libelle carte »', () {
    test('chaque categorie a son libelle exact — la colonne « Libelle '
        'carte » d ADR-006 et de 04-ui.md § 2, retapee ici', () {
      expect(flowCategoryLabel(const Ecoulement()), 'Eau qui coule');
      expect(flowCategoryLabel(const EcoulementFaible()), 'Écoulement faible');
      expect(flowCategoryLabel(const EcoulementNonVisible()), 'Eau stagnante');
      expect(flowCategoryLabel(const Assec()), 'À sec');
      expect(flowCategoryLabel(const NonObserve()), 'Non observé');
      expect(flowCategoryLabel(const Inconnu('5z')), 'Non renseigné');
    });

    test('Assec dit « À sec » — jamais « Assec » ni « asséché » : un '
        'concept, un mot (glossary.md)', () {
      final String label = flowCategoryLabel(const Assec()).toLowerCase();

      expect(label, isNot(contains('assec')));
      expect(label, isNot(contains('asséch')));
      expect(label, isNot(contains('tari')));
    });

    test('NonObserve et Inconnu ne portent JAMAIS le meme mot — un fait de '
        'terrain constate n est pas notre ignorance (BR-007)', () {
      expect(
        flowCategoryLabel(const NonObserve()),
        isNot(flowCategoryLabel(const Inconnu(null))),
      );
    });

    test('aucun libelle ne contient un mot banni', () {
      final List<String> labels = <String>[
        flowCategoryLabel(const Ecoulement()),
        flowCategoryLabel(const EcoulementFaible()),
        flowCategoryLabel(const EcoulementNonVisible()),
        flowCategoryLabel(const Assec()),
        flowCategoryLabel(const NonObserve()),
        flowCategoryLabel(const Inconnu(null)),
      ];
      const List<String> motsBannis = <String>[
        'assec',
        'normal',
        'suffisant',
        'insuffisant',
        'rien à signaler',
      ];

      for (final String label in labels) {
        final String lower = label.toLowerCase();
        for (final String motBanni in motsBannis) {
          expect(lower.contains(motBanni), isFalse, reason: label);
        }
      }
    });
  });

  group('Egalite — NonObserve et Inconnu restent distincts (BR-007)', () {
    test('deux Assec() sont egaux et de meme hashCode', () {
      expect(const Assec(), const Assec());
      expect(const Assec().hashCode, const Assec().hashCode);
    });

    test('NonObserve() et Inconnu(null) ne sont pas egaux — fait de '
        "terrain contre notre ignorance", () {
      expect(const NonObserve() == const Inconnu(null), isFalse);
    });
  });
}

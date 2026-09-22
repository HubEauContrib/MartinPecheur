// Le VERROU de version du modal d'acquittement initial (`UC-006 A3`,
// révision du plan T1 du 2026-09-22) : fige, dans UNE table, le texte
// intégral du modal — titre, corps, libellé de case, libellé de bouton — et
// la version qui les couvre. Changer un texte sans changer la version rend ce
// test rouge ; changer les deux oblige à réécrire la table ci-dessous —
// c'est l'acte délibéré que `UC-006 A3` demande.
//
// ⚠️ Portée du verrou (arbitrage du coordinateur, 2026-09-22) :
// `warningTextVersion` ne couvre QUE le texte du modal — celui que
// l'usager acquitte. Le bandeau de carte (`W3`), l'encart daté (`W4`) et
// l'encart renforcé (`W5`) ont chacun leur propre test de verrouillage de
// texte et ne changent jamais `warningTextVersion`.
//
// Les constantes sont importées directement depuis
// `lib/domain/warnings/warning_texts.dart`, la même source que la vue et
// que `test/domain/warnings/warning_texts_test.dart`. C'est la comparaison
// à la table CI-DESSOUS, écrite en dur dans CE fichier, qui fait le verrou :
// comparer la constante à elle-même ne verrouillerait rien.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

void main() {
  test('le texte integral du modal du premier lancement et sa version sont '
      'figes ensemble (UC-006 A3)', () {
    const String expectedVersion = '2026-09-13.1';
    const String expectedTitle = 'Des informations, pas une autorisation';
    const String expectedBody =
        "Données publiques Hub'Eau, indicatives, partielles, parfois "
        'anciennes, non validées ; elles ne tiennent pas compte des '
        'lâchers de barrage ; elles ne remplacent jamais un arrêté '
        "préfectoral, une décision d'irrigation, ni une évaluation de "
        'sécurité avant de se baigner, naviguer ou traverser.';
    const String expectedCheckboxLabel =
        "J'ai lu et compris que ces données ne valent ni autorisation ni "
        'consigne de sécurité.';
    const String expectedButtonLabel = "J'ai compris ces limites";

    expect(
      warningTextVersion,
      expectedVersion,
      reason:
          'warningTextVersion a change sans que ce test ait ete mis a '
          'jour : verifier si le texte du modal a aussi change (UC-006 A3).',
    );
    expect(
      initialWarningTitle,
      expectedTitle,
      reason:
          'Le titre du modal a change sans que warningTextVersion ait '
          'change (UC-006 A3).',
    );
    expect(
      initialWarningBody,
      expectedBody,
      reason:
          'Le corps du modal a change sans que warningTextVersion ait '
          'change : un texte modifie doit etre relu par l\'usager '
          '(UC-006 A3).',
    );
    expect(
      initialWarningCheckboxLabel,
      expectedCheckboxLabel,
      reason:
          'Le libelle de la case a cocher a change sans que '
          'warningTextVersion ait change (UC-006 A3).',
    );
    expect(
      initialWarningButtonLabel,
      expectedButtonLabel,
      reason:
          'Le libelle du bouton a change sans que warningTextVersion ait '
          'change (UC-006 A3).',
    );
  });
}

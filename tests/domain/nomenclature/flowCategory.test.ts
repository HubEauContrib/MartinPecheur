import { assertNever } from "@domain/nomenclature/exhaustive";
import {
  flowCategoryFromOndeCode,
  type FlowCategory,
} from "@domain/nomenclature/flowCategory";

/**
 * Codes relevés par appel réel le 2026-08-01 sur
 * `/v1/ecoulement/observations`, 7 000 observations, 8 départements
 * (01, 13, 29, 34, 41, 63, 75, 84). Répartition constatée :
 *   "1" 1475 · "1a" 2877 · "1f" 1148 · "2" 405 · "3" 1042 · "4" 23 · null 30
 */
describe("projection des codes ONDE vers les catégories (ADR-006)", () => {
  it("projette les six codes observés en production", () => {
    // Les codes sont des CHAÎNES, pas des entiers (C-10).
    expect(flowCategoryFromOndeCode("1")).toBe<FlowCategory>("Ecoulement");
    expect(flowCategoryFromOndeCode("1a")).toBe<FlowCategory>("Ecoulement");
    expect(flowCategoryFromOndeCode("1f")).toBe<FlowCategory>("EcoulementFaible");
    expect(flowCategoryFromOndeCode("2")).toBe<FlowCategory>("EcoulementNonVisible");
    expect(flowCategoryFromOndeCode("3")).toBe<FlowCategory>("Assec");
    expect(flowCategoryFromOndeCode("4")).toBe<FlowCategory>("NonObserve");
  });

  it("range un code absent dans Inconnu — cas réel, pas théorique (BR-011)", () => {
    // 30 observations sur 7 000 ont code_ecoulement = null, soit PLUS que le
    // code "4" lui-même. Le champ est typé `string | null` côté API.
    expect(flowCategoryFromOndeCode(null)).toBe<FlowCategory>("Inconnu");
    expect(flowCategoryFromOndeCode(undefined)).toBe<FlowCategory>("Inconnu");
    expect(flowCategoryFromOndeCode("")).toBe<FlowCategory>("Inconnu");
  });

  it("range un code non répertorié dans Inconnu plutôt que de le perdre", () => {
    // Un code ajouté au référentiel après cette version ne doit pas faire
    // échouer la lecture : nommer notre ignorance vaut mieux que jeter
    // l'observation (BR-007, BR-011).
    expect(flowCategoryFromOndeCode("9z")).toBe<FlowCategory>("Inconnu");
  });

  it("ne confond pas « observation impossible » et « code inconnu »", () => {
    // Le code 4 est un FAIT rapporté par l'observateur : il s'est déplacé et
    // n'a pas pu observer. `Inconnu` dit que NOUS ne savons pas lire la donnée.
    // Les fondre ferait passer notre ignorance pour une observation de terrain.
    expect(flowCategoryFromOndeCode("4")).not.toBe<FlowCategory>("Inconnu");
  });

  it("compare sans dépendre de la casse ni des espaces (C-10)", () => {
    expect(flowCategoryFromOndeCode("1A")).toBe<FlowCategory>("Ecoulement");
    expect(flowCategoryFromOndeCode(" 1f ")).toBe<FlowCategory>("EcoulementFaible");
  });
});

describe("exhaustivité garantie par le compilateur (BR-011)", () => {
  it("couvre toutes les branches, et le compilateur le prouve", () => {
    // Ajouter une valeur à FlowCategory sans traiter son cas fait échouer
    // `tsc` sur assertNever — pas en production, ici.
    const libelle = (categorie: FlowCategory): string => {
      switch (categorie) {
        case "Ecoulement":
          return "Eau qui coule";
        case "EcoulementFaible":
          return "Écoulement faible";
        case "EcoulementNonVisible":
          return "Eau stagnante";
        case "Assec":
          return "À sec";
        case "NonObserve":
          return "Non observé";
        case "Inconnu":
          return "Modalité inconnue";
        default:
          return assertNever(categorie);
      }
    };

    // Libellés de carte d'ADR-006 § Décision.
    expect(libelle("Ecoulement")).toBe("Eau qui coule");
    expect(libelle("EcoulementNonVisible")).toBe("Eau stagnante");
    expect(libelle("Assec")).toBe("À sec");
    expect(libelle("Inconnu")).toBe("Modalité inconnue");
  });

  it("échoue bruyamment si une valeur hors union arrive à l'exécution", () => {
    // Le typage protège à la compilation ; une donnée désérialisée peut le
    // contourner. On veut alors une erreur, pas un silence.
    expect(() => assertNever("PasUneCategorie" as never)).toThrow(/non traité/i);
  });
});

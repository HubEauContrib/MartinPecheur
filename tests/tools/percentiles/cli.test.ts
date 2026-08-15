import { argument, selectionnerCodes } from "../../../tools/percentiles/cli";

/** Un référentiel ordonné, comme celui de Hub'Eau : par code, donc par bassin. */
const REFERENTIEL = Array.from({ length: 100 }, (_, i) => `K${String(i).padStart(9, "0")}`);

describe("options de la ligne de commande", () => {
  it("lit la forme séparée et la forme collée", () => {
    expect(argument(["--limite", "40"], "limite")).toBe("40");
    expect(argument(["--limite=40"], "limite")).toBe("40");
  });

  it("rend undefined quand l'option est absente", () => {
    expect(argument(["--sortie", "x.json"], "limite")).toBeUndefined();
  });

  it("refuse une option sans valeur plutôt que de la traiter comme absente", () => {
    // Le piège : `--limite` sans nombre valait « pas de limite », donc la passe
    // complète — deux heures d'aspiration au lieu d'un échantillon, sans un mot.
    expect(() => argument(["--limite"], "limite")).toThrow(/valeur/i);
    expect(() => argument(["--limite", "--sortie", "x.json"], "limite")).toThrow(/valeur/i);
    expect(() => argument(["--limite="], "limite")).toThrow(/valeur/i);
  });
});

describe("sélection des stations à aspirer", () => {
  it("prend tout le référentiel sans --limite", () => {
    expect(selectionnerCodes(REFERENTIEL, undefined)).toHaveLength(100);
  });

  it("échantillonne à pas régulier, jamais les N premières", () => {
    // Les premières stations du référentiel sont voisines : mesurer sur elles
    // décrirait un bassin, pas la France.
    const codes = selectionnerCodes(REFERENTIEL, "10");

    expect(codes).toHaveLength(10);
    expect(codes[0]).toBe(REFERENTIEL[0]);
    expect(codes[1]).toBe(REFERENTIEL[10]);
    expect(codes[9]).toBe(REFERENTIEL[90]);
  });

  it("plafonne à la taille du référentiel", () => {
    expect(selectionnerCodes(REFERENTIEL, "500")).toHaveLength(100);
  });

  it("refuse une limite illisible plutôt que de rendre une liste vide", () => {
    // `Number("abc")` vaut NaN : la sélection devenait vide, l'asset ne portait
    // aucune station, et il était écrit par-dessus le livrable versionné.
    expect(() => selectionnerCodes(REFERENTIEL, "abc")).toThrow(/entier/i);
    expect(() => selectionnerCodes(REFERENTIEL, "0")).toThrow(/entier/i);
    expect(() => selectionnerCodes(REFERENTIEL, "-5")).toThrow(/entier/i);
    expect(() => selectionnerCodes(REFERENTIEL, "2.5")).toThrow(/entier/i);
  });

  it("refuse un référentiel vide", () => {
    expect(() => selectionnerCodes([], undefined)).toThrow(/vide/i);
  });

  it("ne rend jamais une liste vide sur une entrée acceptée", () => {
    for (const limite of ["1", "3", "7", "99", "100"]) {
      expect(selectionnerCodes(REFERENTIEL, limite).length).toBeGreaterThan(0);
    }
  });
});

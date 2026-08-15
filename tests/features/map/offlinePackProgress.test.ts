import {
  describeError,
  describeProgress,
  type PackProgress,
} from "@features/map/offlinePackProgress";

const EN_COURS: PackProgress = {
  state: "active",
  percentage: 42.5,
  completedTileCount: 1234,
  completedTileSize: 5678901,
};

describe("relevé de progression du pack (M4)", () => {
  it("porte les trois chiffres à consigner, en clé=valeur", () => {
    // Ces chiffres sont la preuve attendue par M4. Ils partent en journal pour
    // être relus par `adb logcat` : un format `clé=valeur` se grep, une phrase
    // se relit à l'œil et se recopie de travers.
    const ligne = describeProgress(EN_COURS, 32100);

    expect(ligne).toContain("tuiles=1234");
    expect(ligne).toContain("octets=5678901");
    expect(ligne).toContain("ms=32100");
  });

  it("porte un préfixe repérable dans le bruit de logcat", () => {
    expect(describeProgress(EN_COURS, 32100).startsWith("M4 ")).toBe(true);
  });

  it("rapporte l'état et le pourcentage", () => {
    const ligne = describeProgress(EN_COURS, 32100);

    expect(ligne).toContain("etat=active");
    expect(ligne).toContain("pourcentage=42.5");
  });

  it("laisse les octets bruts, sans les arrondir en mégaoctets", () => {
    // NV-4 se mesure en octets. Un arrondi d'affichage perdrait la mesure.
    expect(describeProgress(EN_COURS, 32100)).not.toMatch(/Mo|MB/);
  });

  it("distingue un pack terminé d'un pack encore actif", () => {
    const termine: PackProgress = { ...EN_COURS, state: "complete", percentage: 100 };

    expect(describeProgress(termine, 60000)).toContain("etat=complete");
  });

  it("rapporte zéro tuile sans le maquiller — c'est le cas qui infirme NV-1", () => {
    // Si `completedTileCount` reste à 0, la stratégie hors-ligne d'ADR-010
    // tombe. Ce zéro doit apparaître tel quel dans le journal.
    const vide: PackProgress = {
      state: "complete",
      percentage: 100,
      completedTileCount: 0,
      completedTileSize: 0,
    };

    expect(describeProgress(vide, 1500)).toContain("tuiles=0");
    expect(describeProgress(vide, 1500)).toContain("octets=0");
  });
});

describe("relevé d'erreur du pack (M4)", () => {
  it("part sous le même préfixe, pour se relire avec les mesures", () => {
    const ligne = describeError("Mapbox tile limit exceeded 6000");

    expect(ligne.startsWith("M4 ")).toBe(true);
    expect(ligne).toContain("Mapbox tile limit exceeded 6000");
  });
});

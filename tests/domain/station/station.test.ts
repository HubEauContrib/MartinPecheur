import { departementCode, stationCode } from "@domain/station/station";

/**
 * Valeurs relevées par appel réel le 2026-08-01 sur
 * `/v2/hydrometrie/referentiel/stations?code_station=K447001001` :
 *   code_station "K447001001" (10) · code_site "K4470010" (8)
 *   code_departement "41" (chaîne) · en_service true
 */
describe("code station (C-05)", () => {
  it("accepte un code à dix caractères", () => {
    expect(stationCode("K447001001")).toBe("K447001001");
  });

  it("refuse un code site à huit caractères", () => {
    // Interroger un code site renvoie chaque mesure EN DOUBLE (C-05).
    // Le refuser au plus tôt évite de propager des doublons jusqu'à la vue.
    expect(() => stationCode("K4470010")).toThrow(/dix caractères/);
  });

  it("nomme le piège dans le message d'erreur", () => {
    // Un message qui dit seulement « longueur invalide » laisserait chercher.
    expect(() => stationCode("K4470010")).toThrow(/double/i);
  });

  it("refuse une chaîne vide plutôt que de la laisser passer", () => {
    expect(() => stationCode("")).toThrow(/dix caractères/);
  });
});

describe("code département", () => {
  it("conserve le zéro de tête", () => {
    // « 01 » traité comme un nombre deviendrait 1, et ne correspondrait plus à
    // aucun département côté API. Le type interdit de le confondre avec un
    // nombre.
    expect(departementCode("01")).toBe("01");
    expect(departementCode("41")).toBe("41");
  });

  it("accepte les codes d'outre-mer à trois caractères", () => {
    // 971 à 976 — et 974 n'a AUCUN point ONDE, ce que BR-007 oblige à dire.
    expect(departementCode("974")).toBe("974");
  });

  it("accepte la Corse", () => {
    expect(departementCode("2a")).toBe("2A");
    expect(departementCode("2B")).toBe("2B");
  });

  it("refuse un format inattendu", () => {
    expect(() => departementCode("4")).toThrow(/département/i);
    expect(() => departementCode("0041")).toThrow(/département/i);
  });
});

describe("forme du code station, mesurée sur le référentiel", () => {
  it("accepte les deux formes réellement observées", () => {
    // Relevé le 2026-08-15 sur les 4 150 stations en service :
    //   3 974 en « A999999999 » — une lettre puis neuf chiffres
    //     176 en « 9999999999 » — dix chiffres, les stations des DOM
    // Restreindre à ^[A-Z]\d{9}$ rejetterait ces 176 stations.
    expect(stationCode("K447001001")).toBe("K447001001");
    expect(stationCode("1011000101")).toBe("1011000101");
  });

  it("refuse dix caractères qui ne sont pas un code", () => {
    // Sans contrôle de forme, ces valeurs partaient en `code_entite` vers
    // Hub'Eau, revenaient vides, et l'écran affichait « pas de donnée » —
    // un symptôme que BR-007 interdit de rendre neutre.
    expect(() => stationCode("          ")).toThrow(/forme/i);
    expect(() => stationCode("undefined0")).toThrow(/forme/i);
    expect(() => stationCode("k447001001")).toThrow(/forme/i);
  });
});

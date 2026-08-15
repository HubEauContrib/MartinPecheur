import { mapHydroObservation } from "@data/mappers/hydroObservationMapper";
import { cubicMetresPerSecond, metres } from "@domain/units/quantities";

// Charge réelle de /v2/hydrometrie/observations_tr, relevée le 2026-07-30.
// Les huit champs sont ceux constatés sur l'endpoint (01-analyse.md § observations_tr).
const CHARGE_UTILE = {
  code_station: "K447001001",
  date_obs: "2026-07-30T10:00:00Z",
  grandeur_hydro: "Q",
  resultat_obs: 53000.0,
  code_statut: 8,
  libelle_statut: "Corrigée",
  code_qualification_obs: 16,
  libelle_qualification_obs: "Non qualifiée",
};

describe("mapper des observations temps réel", () => {
  it("convertit le débit une seule fois (BR-002)", () => {
    const observation = mapHydroObservation(CHARGE_UTILE);
    expect(observation.debit).toBe(cubicMetresPerSecond(53));
  });

  it("laisse le débit à null quand la station n'a rien transmis (BR-007)", () => {
    const observation = mapHydroObservation({ ...CHARGE_UTILE, resultat_obs: null });
    expect(observation.debit).toBeNull();
  });

  it("range une grandeur inattendue dans Inconnu (BR-011)", () => {
    const observation = mapHydroObservation({ ...CHARGE_UTILE, grandeur_hydro: "Z" });
    expect(observation.grandeur).toBe("Inconnu");
  });

  it("refuse un code site de huit caractères (C-05)", () => {
    expect(() => mapHydroObservation({ ...CHARGE_UTILE, code_station: "10110001" })).toThrow(
      /dix caractères/,
    );
  });

  it("reporte la qualification sans la réinterpréter (BR-006)", () => {
    // Le statut est toujours affiché : le mapper le transporte, il ne le juge pas.
    expect(mapHydroObservation(CHARGE_UTILE).qualification).toEqual({
      codeStatut: 8,
      libelleStatut: "Corrigée",
      codeQualification: 16,
      libelleQualification: "Non qualifiée",
    });
  });

  it("convertit une hauteur négative sans la corriger", () => {
    // resultat_obs = -1232.0 relevé le 2026-08-01 sur K447001001, soit −1,232 m
    // sous le zéro de l'échelle. Aucun contrôle de signe (D4).
    const observation = mapHydroObservation({
      ...CHARGE_UTILE,
      grandeur_hydro: "H",
      resultat_obs: -1232.0,
    });
    expect(observation.hauteur).toBe(metres(-1.232));
    expect(observation.debit).toBeNull();
  });
});

describe("date de mesure (BR-001)", () => {
  it("refuse une date non parsable plutôt que de la laisser filer", () => {
    // Un Invalid Date traverserait tout le domaine en silence et ressortirait
    // en « observation fraîche ». BR-001 fait de la date une donnée obligatoire.
    expect(() => mapHydroObservation({ ...CHARGE_UTILE, date_obs: "2026-13-45" })).toThrow(
      /date de mesure/i,
    );
    expect(() => mapHydroObservation({ ...CHARGE_UTILE, date_obs: "" })).toThrow(/date de mesure/i);
  });

  it("accepte la forme réellement renvoyée par l'API", () => {
    // Relevé le 2026-07-30 sur observations_tr.
    expect(mapHydroObservation(CHARGE_UTILE).dateObs.toISOString()).toBe("2026-07-30T10:00:00.000Z");
  });
});

import {
  freshnessOf,
  ANCIENNE_APRES_MS,
  PERIMEE_APRES_MS,
  type Freshness,
} from "@domain/observation/freshness";

const MAINTENANT = new Date("2026-08-01T12:00:00Z");
const HEURE = 60 * 60 * 1000;

/** Observation datée de `ms` millisecondes avant `MAINTENANT`. */
const ilYA = (ms: number): Date => new Date(MAINTENANT.getTime() - ms);

/**
 * BR-005 fixe des seuils ABSOLUS : 2 h puis 24 h. Ce ne sont pas des multiples
 * du TTL de cache — 03-conception.md § 4.1 parle de « 2 × TTL », mais il y
 * décrit la fraîcheur du CACHE, pas l'âge de la MESURE. Les confondre
 * déclarerait périmée une observation de 40 minutes.
 *
 * L'âge se calcule sur `date_obs`, jamais sur la date de récupération (BR-005).
 */
describe("fraîcheur d'une observation hydrométrique (BR-005)", () => {
  it("expose les seuils de la règle, pas des nombres magiques", () => {
    expect(ANCIENNE_APRES_MS).toBe(2 * HEURE);
    expect(PERIMEE_APRES_MS).toBe(24 * HEURE);
  });

  // Les quatre cas que BR-005 § « Vérifiable par » prescrit nommément.
  it("1 h 59 → fraîche", () => {
    expect(freshnessOf(ilYA(1 * HEURE + 59 * 60_000), MAINTENANT)).toBe<Freshness>("Fraiche");
  });

  it("2 h 01 → ancienne", () => {
    expect(freshnessOf(ilYA(2 * HEURE + 60_000), MAINTENANT)).toBe<Freshness>("Ancienne");
  });

  it("23 h 59 → ancienne", () => {
    expect(freshnessOf(ilYA(23 * HEURE + 59 * 60_000), MAINTENANT)).toBe<Freshness>("Ancienne");
  });

  it("24 h 01 → périmée", () => {
    expect(freshnessOf(ilYA(24 * HEURE + 60_000), MAINTENANT)).toBe<Freshness>("Perimee");
  });

  it("bascule exactement AU seuil, pas après", () => {
    // La borne appartient à l'état le plus sévère : on ne minimise jamais l'âge.
    expect(freshnessOf(ilYA(2 * HEURE), MAINTENANT)).toBe<Freshness>("Ancienne");
    expect(freshnessOf(ilYA(24 * HEURE), MAINTENANT)).toBe<Freshness>("Perimee");
  });

  it("traite une date future comme fraîche plutôt que d'échouer", () => {
    // Une horloge d'appareil en avance ne doit pas casser l'affichage d'une
    // carte. Un âge négatif reste un âge inférieur au seuil.
    expect(freshnessOf(new Date(MAINTENANT.getTime() + 60_000), MAINTENANT)).toBe<Freshness>(
      "Fraiche",
    );
  });

  it("gère l'écart réel constaté en production", () => {
    // Le 2026-07-30, l'âge des observations allait de 7 minutes à 9 jours selon
    // la station (BR-001). Les deux extrêmes doivent être classés correctement.
    expect(freshnessOf(ilYA(7 * 60_000), MAINTENANT)).toBe<Freshness>("Fraiche");
    expect(freshnessOf(ilYA(9 * 24 * HEURE), MAINTENANT)).toBe<Freshness>("Perimee");
  });
});

describe("date de mesure inexploitable", () => {
  it("ne présente jamais une date invalide comme fraîche", () => {
    // NaN >= seuil est faux deux fois : sans garde, la fonction retombe sur
    // « Fraiche », soit l'état le MOINS sévère pour une donnée dont on ne sait
    // rien. C'est l'inverse de la règle que porte cette fonction.
    expect(freshnessOf(new Date(""), MAINTENANT)).toBe<Freshness>("Perimee");
    expect(freshnessOf(new Date("pas-une-date"), MAINTENANT)).toBe<Freshness>("Perimee");
  });

  it("ne présente pas non plus un instant courant invalide comme fraîche", () => {
    expect(freshnessOf(ilYA(1000), new Date("n'importe quoi"))).toBe<Freshness>("Perimee");
  });
});

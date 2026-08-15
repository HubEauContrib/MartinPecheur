import { delayForAttempt, BASE_DELAY_MS, MAX_DELAY_MS } from "@data/http/retry";

/**
 * C-15 — Hub'Eau n'annonce **aucun SLA et aucun quota chiffré**, et
 * l'application n'a pas de proxy pour mutualiser la charge de sa base
 * installée. La gigue n'est donc pas un raffinement : sans elle, tous les
 * appareils réessaient à la même seconde après une panne et forment un
 * troupeau tonnant contre un service public gratuit.
 */
describe("backoff exponentiel à gigue (C-15)", () => {
  /** Gigue neutralisée, pour éprouver la base seule. */
  const sansGigue = () => 0;

  it("expose ses constantes plutôt que de les enfouir", () => {
    expect(BASE_DELAY_MS).toBe(500);
    expect(MAX_DELAY_MS).toBe(30_000);
  });

  it("double à chaque tentative", () => {
    expect(delayForAttempt(0, sansGigue)).toBe(500);
    expect(delayForAttempt(1, sansGigue)).toBe(1000);
    expect(delayForAttempt(2, sansGigue)).toBe(2000);
    expect(delayForAttempt(3, sansGigue)).toBe(4000);
  });

  it("plafonne, sans jamais déborder", () => {
    // 2^20 × 500 ms dépasserait 145 heures. Le plafond n'est pas décoratif.
    //
    // Au plafond, le délai est un INTERVALLE — [15 s, 30 s) — et non une valeur
    // unique. Le fixer à 30 000 ms pile, comme le faisait la première version,
    // annulait la gigue exactement là où elle sert : une panne longue, où toute
    // la base installée réessaie en même temps.
    expect(delayForAttempt(20, sansGigue)).toBe(15_000);
    expect(delayForAttempt(100, sansGigue)).toBe(15_000);
    expect(delayForAttempt(100, () => 0.999_999)).toBeLessThan(30_000);
  });

  it("ajoute une gigue bornée par le délai lui-même", () => {
    const gigueMax = () => 0.999_999;
    const avec = delayForAttempt(1, gigueMax);
    expect(avec).toBeGreaterThan(1000);
    expect(avec).toBeLessThanOrEqual(2000);
  });

  it("respecte le plafond même avec la gigue au maximum", () => {
    // Sans ce garde-fou, la gigue ferait dépasser le plafond de 100 %.
    expect(delayForAttempt(20, () => 0.999_999)).toBeLessThanOrEqual(30_000);
  });

  it("ne rend jamais un délai négatif ni nul", () => {
    expect(delayForAttempt(0, () => 0)).toBeGreaterThan(0);
  });

  it("étale réellement les réessais entre appareils", () => {
    // Deux appareils tirant des gigues différentes ne doivent pas retomber sur
    // la même milliseconde — c'est toute la raison d'être de la gigue.
    const appareilA = delayForAttempt(3, () => 0.1);
    const appareilB = delayForAttempt(3, () => 0.9);
    expect(appareilA).not.toBe(appareilB);
    expect(Math.abs(appareilA - appareilB)).toBeGreaterThan(1000);
  });
});

describe("la gigue survit au plafond (C-15)", () => {
  it("étale encore les tentatives une fois le plafond atteint", () => {
    // L'ancienne formule plafonnait APRÈS avoir ajouté la gigue : dès la 6e
    // tentative, tous les appareils réessayaient à 30 000 ms exactement — le
    // troupeau tonnant que la gigue existe pour empêcher, au pire moment.
    for (const attempt of [6, 8, 12]) {
      expect(delayForAttempt(attempt, () => 0)).not.toBe(delayForAttempt(attempt, () => 0.99));
    }
  });

  it("ne dépasse jamais le plafond, gigue comprise", () => {
    for (const attempt of [0, 3, 6, 10, 50]) {
      expect(delayForAttempt(attempt, () => 0.999)).toBeLessThanOrEqual(MAX_DELAY_MS);
    }
  });

  it("reste croissant jusqu'au plafond", () => {
    expect(delayForAttempt(1, () => 0)).toBeGreaterThan(delayForAttempt(0, () => 0));
    expect(delayForAttempt(3, () => 0)).toBeGreaterThan(delayForAttempt(2, () => 0));
  });
});

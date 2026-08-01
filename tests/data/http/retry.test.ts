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
    expect(delayForAttempt(20, sansGigue)).toBe(30_000);
    expect(delayForAttempt(100, sansGigue)).toBe(30_000);
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

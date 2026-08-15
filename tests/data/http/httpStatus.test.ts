import { isSuccess, isRetryable } from "@data/http/httpStatus";

/**
 * C-06 — **HTTP 206 est un succès.** `fetch` ne lève pas sur un 206, donc un
 * `if (res.status === 200)` passe la revue de code et casse à la première
 * pagination.
 *
 * Constaté trois fois en production cette session, sur trois endpoints :
 *   referentiel/stations?size=10000  → 200
 *   observations_tr?size=3           → 206
 *   ecoulement/observations?size=1000 → 206
 * Le même endpoint rend 200 ou 206 selon `size`. On ne peut donc pas décider
 * par endpoint : il faut accepter les deux, à un seul endroit.
 */
describe("statuts de succès Hub'Eau (C-06)", () => {
  it("accepte 200", () => {
    expect(isSuccess(200)).toBe(true);
  });

  it("accepte 206 — une réponse partielle est un succès paginé", () => {
    expect(isSuccess(206)).toBe(true);
  });

  it("refuse les statuts que l'on a réellement rencontrés en erreur", () => {
    expect(isSuccess(400)).toBe(false); // ValidatePageSize au-delà de size=10000
    expect(isSuccess(403)).toBe(false); // l'API v1 hydrométrie, arrêtée (C-01)
    expect(isSuccess(409)).toBe(false); // VigiEau ?commune= (C-14)
    expect(isSuccess(500)).toBe(false);
  });

  it("refuse les autres 2xx plutôt que de les supposer bons", () => {
    // 204 n'a pas de corps : le traiter en succès ferait échouer le parsing
    // plus loin, avec un message sans rapport.
    expect(isSuccess(204)).toBe(false);
    expect(isSuccess(202)).toBe(false);
  });
});

describe("statuts qui méritent une nouvelle tentative (C-15)", () => {
  it("réessaie sur 429 et sur les 5xx", () => {
    // Hub'Eau n'annonce aucun quota chiffré : le 429 est possible et transitoire.
    expect(isRetryable(429)).toBe(true);
    expect(isRetryable(500)).toBe(true);
    expect(isRetryable(503)).toBe(true);
  });

  it("ne réessaie jamais sur une erreur de requête", () => {
    // 400 vient de NOTRE requête : réessayer ne ferait que marteler un service
    // public gratuit sans aucune chance de succès.
    expect(isRetryable(400)).toBe(false);
    expect(isRetryable(403)).toBe(false);
    expect(isRetryable(409)).toBe(false);
    expect(isRetryable(404)).toBe(false);
  });

  it("ne réessaie pas sur un succès", () => {
    expect(isRetryable(200)).toBe(false);
    expect(isRetryable(206)).toBe(false);
  });
});

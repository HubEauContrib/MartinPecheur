import { createHubEauClient } from "@data/http/hubEauClient";

describe("client Hub'Eau", () => {
  it("accepte une réponse 206 sans réessayer (C-06)", async () => {
    const fetchStub = jest
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify({ count: 1, data: [], next: null }), { status: 206 }),
      );
    const client = createHubEauClient({ fetchImpl: fetchStub, sleep: async () => {} });

    await expect(client.getJson("https://exemple.test/x")).resolves.toEqual({
      count: 1,
      data: [],
      next: null,
    });
    expect(fetchStub).toHaveBeenCalledTimes(1);
  });

  it("réessaie sur 500 puis réussit", async () => {
    const fetchStub = jest
      .fn()
      .mockResolvedValueOnce(new Response("", { status: 500 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true }), { status: 200 }));
    const client = createHubEauClient({ fetchImpl: fetchStub, sleep: async () => {} });

    await expect(client.getJson("https://exemple.test/x")).resolves.toEqual({ ok: true });
    expect(fetchStub).toHaveBeenCalledTimes(2);
  });

  it("ne réessaie pas sur 400 — la requête est fautive, pas le réseau", async () => {
    // size > 10000 → 400 ValidatePageSize. Réessayer ne ferait que marteler l'API.
    const fetchStub = jest.fn().mockResolvedValue(new Response("", { status: 400 }));
    const client = createHubEauClient({ fetchImpl: fetchStub, sleep: async () => {} });

    await expect(client.getJson("https://exemple.test/x")).rejects.toThrow(/400/);
    expect(fetchStub).toHaveBeenCalledTimes(1);
  });

  it("ne réessaie pas sur 403 — l'API v1 est arrêtée, pas indisponible (C-01)", async () => {
    const fetchStub = jest.fn().mockResolvedValue(new Response("", { status: 403 }));
    const client = createHubEauClient({ fetchImpl: fetchStub, sleep: async () => {} });

    await expect(client.getJson("https://exemple.test/x")).rejects.toThrow(/403/);
    expect(fetchStub).toHaveBeenCalledTimes(1);
  });

  it("abandonne après le nombre de tentatives fixé, sans marteler l'API (C-15)", async () => {
    const fetchStub = jest.fn().mockResolvedValue(new Response("", { status: 503 }));
    const client = createHubEauClient({
      fetchImpl: fetchStub,
      sleep: async () => {},
      maxAttempts: 3,
    });

    await expect(client.getJson("https://exemple.test/x")).rejects.toThrow(/503/);
    expect(fetchStub).toHaveBeenCalledTimes(3);
  });

  it("attend entre deux tentatives, avec un délai croissant", async () => {
    // Sans attente, le « retry » martèle l'API au lieu de lui laisser le temps
    // de se relever — l'inverse de ce que C-15 demande.
    const delais: number[] = [];
    const fetchStub = jest
      .fn()
      .mockResolvedValueOnce(new Response("", { status: 500 }))
      .mockResolvedValueOnce(new Response("", { status: 500 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true }), { status: 200 }));
    const client = createHubEauClient({
      fetchImpl: fetchStub,
      sleep: async (ms) => {
        delais.push(ms);
      },
    });

    await client.getJson("https://exemple.test/x");

    expect(delais).toHaveLength(2);
    expect(delais[0]).toBeGreaterThan(0);
    expect(delais[1]).toBeGreaterThan(delais[0] as number);
  });
});

describe("pannes réseau", () => {
  it("réessaie quand fetch rejette, puis réussit", async () => {
    // fetch REJETTE sur coupure, DNS ou TLS : c'est la panne transitoire la
    // plus courante sur mobile. Ne traiter que les statuts HTTP laisserait
    // 4 tentatives à un 500 et aucune à une perte de réseau.
    const fetchStub = jest
      .fn()
      .mockRejectedValueOnce(new TypeError("Network request failed"))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true }), { status: 200 }));
    const client = createHubEauClient({ fetchImpl: fetchStub, sleep: async () => {} });

    await expect(client.getJson("https://exemple.test/x")).resolves.toEqual({ ok: true });
    expect(fetchStub).toHaveBeenCalledTimes(2);
  });

  it("remonte la dernière panne réseau après épuisement des tentatives", async () => {
    const fetchStub = jest.fn().mockRejectedValue(new TypeError("Network request failed"));
    const client = createHubEauClient({
      fetchImpl: fetchStub,
      sleep: async () => {},
      maxAttempts: 3,
    });

    await expect(client.getJson("https://exemple.test/x")).rejects.toThrow(/Network request failed/);
    expect(fetchStub).toHaveBeenCalledTimes(3);
  });
});

describe("corps de réponse illisible", () => {
  it("ne fait pas passer un JSON malformé pour une panne réseau", async () => {
    // Un 200 au corps tronqué mérite d'être rejoué — c'est souvent transitoire.
    // Mais le message final doit dire ce qui s'est réellement passé.
    const fetchStub = jest.fn().mockResolvedValue(new Response("{ pas du json", { status: 200 }));
    const client = createHubEauClient({
      fetchImpl: fetchStub,
      sleep: async () => {},
      maxAttempts: 2,
    });

    await expect(client.getJson("https://exemple.test/x")).rejects.toThrow(/corps illisible/i);
    expect(fetchStub).toHaveBeenCalledTimes(2);
  });
});

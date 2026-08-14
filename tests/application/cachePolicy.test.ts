import { withCachePolicy } from "@application/cachePolicy";

describe("stale-while-revalidate (03-conception.md § 4.1)", () => {
  it("rend le cache immédiatement sans appeler la source quand le TTL tient", async () => {
    const source = jest.fn();
    const lire = withCachePolicy({
      load: source,
      readCache: async () => ({ value: "cache", storedAt: new Date("2026-07-31T11:59:00Z") }),
      writeCache: async () => {},
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"),
      networkAvailable: () => true,
    });

    await expect(lire()).resolves.toBe("cache");
    expect(source).not.toHaveBeenCalled();
  });

  it("rend le cache périmé puis rafraîchit en tâche de fond", async () => {
    const ecritures: string[] = [];
    const lire = withCachePolicy({
      load: async () => "frais",
      readCache: async () => ({ value: "vieux", storedAt: new Date("2026-07-31T10:00:00Z") }),
      writeCache: async (v) => {
        ecritures.push(v);
      },
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"),
      networkAvailable: () => true,
    });

    await expect(lire()).resolves.toBe("vieux"); // l'affichage n'attend pas le réseau
    await new Promise((r) => setImmediate(r));
    expect(ecritures).toEqual(["frais"]);
  });

  it("rend le cache périmé sans appeler la source quand le réseau est absent", async () => {
    const source = jest.fn();
    const lire = withCachePolicy({
      load: source,
      readCache: async () => ({ value: "vieux", storedAt: new Date("2026-07-31T00:00:00Z") }),
      writeCache: async () => {},
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"),
      networkAvailable: () => false,
    });

    await expect(lire()).resolves.toBe("vieux");
    expect(source).not.toHaveBeenCalled();
  });

  it("appelle la source quand le cache est vide", async () => {
    const lire = withCachePolicy({
      load: async () => "frais",
      readCache: async () => null,
      writeCache: async () => {},
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"),
      networkAvailable: () => true,
    });

    await expect(lire()).resolves.toBe("frais");
  });

  it("garde la dernière valeur connue quand le rafraîchissement échoue", async () => {
    // Un réseau qui répond mal ne doit pas vider l'écran : BR-007 interdit de
    // transformer une absence en information neutre.
    const lire = withCachePolicy({
      load: async () => {
        throw new Error("Hub'Eau a répondu 503");
      },
      readCache: async () => ({ value: "vieux", storedAt: new Date("2026-07-31T10:00:00Z") }),
      writeCache: async () => {},
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"),
      networkAvailable: () => true,
    });

    await expect(lire()).resolves.toBe("vieux");
    await new Promise((r) => setImmediate(r));
  });

  it("bascule exactement AU seuil du TTL, pas après", async () => {
    const source = jest.fn().mockResolvedValue("frais");
    const lire = withCachePolicy({
      load: source,
      readCache: async () => ({ value: "vieux", storedAt: new Date("2026-07-31T11:40:00Z") }),
      writeCache: async () => {},
      ttlMs: 20 * 60 * 1000,
      now: () => new Date("2026-07-31T12:00:00Z"), // exactement 20 min
      networkAvailable: () => true,
    });

    await expect(lire()).resolves.toBe("vieux");
    await new Promise((r) => setImmediate(r));
    expect(source).toHaveBeenCalledTimes(1);
  });
});

export interface CachedValue<T> {
  readonly value: T;
  readonly storedAt: Date;
}

export interface CachePolicyOptions<T> {
  readonly load: () => Promise<T>;
  readonly readCache: () => Promise<CachedValue<T> | null>;
  readonly writeCache: (value: T) => Promise<void>;
  readonly ttlMs: number;
  readonly now?: () => Date;
  readonly networkAvailable?: () => boolean;
}

/**
 * L'unique implémentation du stale-while-revalidate du projet (ADR-010, principe
 * repris d'ADR-008). Lecture du cache → rendu immédiat → si le TTL est dépassé
 * ET que le réseau répond, rafraîchissement en tâche de fond.
 *
 * Ne jamais recopier cette logique dans un dépôt ni dans un écran : c'est
 * exactement ce que la décision d'architecture interdit. Chaque recopie est une
 * divergence future.
 *
 * ⚠️ Le TTL est celui du **cache**. Il n'a rien à voir avec la fraîcheur d'une
 * observation, qui se mesure sur `date_obs` aux seuils absolus de BR-005
 * (2 h / 24 h) — voir `domain/observation/freshness.ts`.
 */
export function withCachePolicy<T>(options: CachePolicyOptions<T>): () => Promise<T> {
  const now = options.now ?? (() => new Date());
  const networkAvailable = options.networkAvailable ?? (() => true);

  /**
   * Rafraîchissement en vol, s'il y en a un. Sans cette mémoire, N lectures
   * simultanées sur une entrée expirée déclenchent N appels réseau — un écran
   * de carte en produit autant qu'il affiche de stations. Hub'Eau n'annonce
   * aucun quota (`C-15`) : rien ne nous arrêterait, c'est donc à nous de le
   * faire, et ce composant est le seul endroit qui puisse le faire.
   */
  let enVol: Promise<void> | null = null;

  return async function read(): Promise<T> {
    const cached = await options.readCache();

    if (cached === null) {
      const fresh = await options.load();
      await options.writeCache(fresh);
      return fresh;
    }

    // La borne appartient à l'état périmé : on ne prolonge jamais un cache.
    const expired = now().getTime() - cached.storedAt.getTime() >= options.ttlMs;

    if (expired && networkAvailable() && enVol === null) {
      // Volontairement non attendu : l'affichage ne doit pas dépendre du réseau.
      // Un échec de rafraîchissement laisse la dernière valeur connue en place
      // plutôt que de vider l'écran (BR-007).
      enVol = options
        .load()
        .then((fresh) => options.writeCache(fresh))
        .catch(() => undefined)
        // Libéré dans tous les cas : un rafraîchissement en échec ne doit pas
        // bloquer définitivement les suivants.
        .finally(() => {
          enVol = null;
        });
      void enVol;
    }

    return cached.value;
  };
}

import { isRetryable, isSuccess } from "./httpStatus";
import { delayForAttempt } from "./retry";

export interface HubEauClientOptions {
  readonly fetchImpl?: typeof fetch;
  readonly sleep?: (ms: number) => Promise<void>;
  readonly maxAttempts?: number;
}

export interface HubEauClient {
  getJson<T>(url: string): Promise<T>;
}

export function createHubEauClient(options: HubEauClientOptions = {}): HubEauClient {
  const fetchImpl = options.fetchImpl ?? fetch;
  const sleep = options.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const maxAttempts = options.maxAttempts ?? 4;

  return {
    async getJson<T>(url: string): Promise<T> {
      let lastStatus = 0;
      let lastNetworkError: unknown = null;

      for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
        try {
          const response = await fetchImpl(url, { headers: { Accept: "application/json" } });
          lastStatus = response.status;
          lastNetworkError = null;

          // 206 est un succès : le refuser casserait toute pagination (C-06).
          if (isSuccess(response.status)) return (await response.json()) as T;
          if (!isRetryable(response.status)) break;
        } catch (erreur) {
          // `fetch` REJETTE sur coupure réseau, DNS ou TLS — il ne rend pas un
          // statut. C'est la panne transitoire la plus courante sur mobile :
          // ne pas la réessayer laisserait 4 tentatives à un 500 et aucune à
          // une perte de réseau, soit l'inverse du besoin.
          lastNetworkError = erreur;
        }

        // Dernière tentative : inutile d'attendre avant d'abandonner.
        if (attempt < maxAttempts - 1) await sleep(delayForAttempt(attempt));
      }

      // Une panne réseau est remontée telle quelle : son message dit ce qui
      // s'est passé, là où un statut inventé induirait en erreur.
      if (lastNetworkError !== null) throw lastNetworkError;
      throw new Error(`Hub'Eau a répondu ${lastStatus} pour ${url}`);
    },
  };
}

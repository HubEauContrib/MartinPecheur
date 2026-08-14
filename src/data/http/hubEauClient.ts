import { isSuccess } from "./httpStatus";
import { delayForAttempt } from "./retry";

export interface HubEauClientOptions {
  readonly fetchImpl?: typeof fetch;
  readonly sleep?: (ms: number) => Promise<void>;
  readonly maxAttempts?: number;
}

export interface HubEauClient {
  getJson<T>(url: string): Promise<T>;
}

/**
 * 429 et 5xx sont transitoires ; un 4xx client ne le sera jamais. Réessayer un
 * `400 ValidatePageSize` ou le `403` de l'API v1 arrêtée (C-01) ne corrigerait
 * rien et ne ferait que marteler un service public gratuit (C-15).
 */
function isRetryable(status: number): boolean {
  return status === 429 || status >= 500;
}

export function createHubEauClient(options: HubEauClientOptions = {}): HubEauClient {
  const fetchImpl = options.fetchImpl ?? fetch;
  const sleep = options.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const maxAttempts = options.maxAttempts ?? 4;

  return {
    async getJson<T>(url: string): Promise<T> {
      let lastStatus = 0;

      for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
        const response = await fetchImpl(url, { headers: { Accept: "application/json" } });
        lastStatus = response.status;

        // 206 est un succès : le refuser casserait toute pagination (C-06).
        if (isSuccess(response.status)) return (await response.json()) as T;
        if (!isRetryable(response.status)) break;

        // Dernière tentative : inutile d'attendre avant d'abandonner.
        if (attempt < maxAttempts - 1) await sleep(delayForAttempt(attempt));
      }

      throw new Error(`Hub'Eau a répondu ${lastStatus} pour ${url}`);
    },
  };
}

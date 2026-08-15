import type { DepartementCode, Station, StationCode } from "../station/station";

/** Emprise géographique, en degrés décimaux (WGS 84). */
export interface Bounds {
  readonly west: number;
  readonly south: number;
  readonly east: number;
  readonly north: number;
}

/**
 * Interface seule — aucune implémentation dans `domain/`.
 *
 * Les dépôts restent bêtes : ils lisent et écrivent. Ils n'orchestrent pas, et
 * surtout **ils ne décident pas de la politique de cache**, qui vit dans un
 * unique décorateur (ADR-010, principe repris d'ADR-008).
 *
 * Un composant d'écran n'appelle jamais ce dépôt : il envoie une requête, et un
 * handler l'orchestre.
 */
export interface StationRepository {
  findByCode(code: StationCode): Promise<Station | null>;

  /**
   * ⚠️ Le référentiel compte **4 140 stations en service** (constaté le
   * 2026-07-31). Une implémentation qui les charge toutes pour filtrer ensuite
   * ferait tomber la carte : filtrer à la source.
   */
  findWithinBounds(bounds: Bounds): Promise<readonly Station[]>;

  findByDepartement(code: DepartementCode): Promise<readonly Station[]>;
}

import {
  OfflineManager,
  type OfflinePack,
  type OfflinePackError,
  type OfflinePackStatus,
} from "@maplibre/maplibre-react-native";

import {
  buildOfflinePackOptions,
  OFFLINE_TILE_COUNT_LIMIT,
  type Bounds,
} from "./offlinePackOptions";

/**
 * Enveloppe de `OfflineManager.createPack` — **la seule partie de `M4` qui ne
 * se teste pas sous Node.**
 *
 * 🚨 **Cet appel fait planter l'application.** Constaté le 2026-08-15 sur
 * `@maplibre/maplibre-react-native@11.3.6` (Android x86_64, API 36) :
 * environ 0,7 s après la création du pack, le processus meurt d'un `SIGABRT`
 * levé par une `std::regex_error` non rattrapée dans le fil
 * `DatabaseFileSource` de `libmaplibre.so`. **4 essais sur 4**, base de données
 * vierge comprise, et **avec le style vectoriel de démonstration de MapLibre
 * lui-même** — ce n'est donc ni l'IGN, ni le raster. Voir
 * `docs/adr/ADR-012-hors-ligne-cartographique-bloque.md`.
 *
 * Le module reste au dépôt parce qu'il est le **cas de reproduction** du
 * défaut, pas parce qu'il fonctionne.
 *
 * API v11 (lue dans les typings, pas devinée) : le pack est identifié par un id
 * auto-généré — plus par un nom — et l'abonnement passe par
 * `addListener`/`removeListener`.
 */

/** Ce que `M4` devait relever : des chiffres, pas des impressions. */
export interface PackMeasurement {
  readonly tiles: number;
  readonly bytes: number;
  readonly elapsedMs: number;
}

export interface OfflinePackHandlers {
  readonly onProgress: (status: OfflinePackStatus, elapsedMs: number) => void;
  readonly onError: (message: string) => void;
}

/**
 * Crée le pack et rend la main dès que MapLibre l'a enregistré — le
 * téléchargement, lui, se poursuit et se suit par `onProgress`.
 *
 * ⚠️ `styleUrl` est une **URL**, pas un style sérialisé : `mapStyle` alimente
 * `OfflineTilePyramidRegionDefinition(styleURL, …)` côté Android. Le plan T0
 * écrivait `JSON.stringify(style)` ; `buildOfflinePackOptions` refuse désormais
 * cette forme.
 *
 * `now` est injecté : la durée mesurée doit être reproductible, et rien dans ce
 * module ne doit dépendre d'une horloge implicite.
 */
export async function createOfflinePack(
  bounds: Bounds,
  minZoom: number,
  maxZoom: number,
  styleUrl: string,
  handlers: OfflinePackHandlers,
  now: () => number = () => Date.now(),
): Promise<OfflinePack> {
  // ⚠️ **Avant** la création, jamais après : le plafond par défaut (6000)
  // interromprait un pack départemental en raster sans autre signal qu'une
  // erreur, et la mesure porterait sur un pack tronqué.
  OfflineManager.setTileCountLimit(OFFLINE_TILE_COUNT_LIMIT);

  const debut = now();

  return OfflineManager.createPack(
    buildOfflinePackOptions(bounds, minZoom, maxZoom, styleUrl, new Date(debut)),
    (_pack: OfflinePack, status: OfflinePackStatus) => {
      handlers.onProgress(status, now() - debut);
    },
    (_pack: OfflinePack, error: OfflinePackError) => {
      handlers.onError(error.message);
    },
  );
}

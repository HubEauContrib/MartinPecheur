/**
 * Mise en forme du relevé de progression d'un pack hors-ligne — TypeScript pur.
 *
 * `M4` demande « des chiffres, pas des impressions ». Ce module produit la
 * ligne qui part en journal, dans un format `clé=valeur` que `adb logcat` rend
 * greppable : la mesure se relit sans être recopiée à la main.
 */

/**
 * Sous-ensemble de `OfflinePackStatus` (API v11) réellement mesuré ici.
 * Structurellement compatible : un `OfflinePackStatus` s'y passe tel quel.
 */
export interface PackProgress {
  readonly state: "inactive" | "active" | "complete";
  readonly percentage: number;
  readonly completedTileCount: number;
  readonly completedTileSize: number;
}

/** Repère de recherche dans le bruit de logcat. */
const PREFIXE = "M4";

/**
 * Les octets restent bruts : `NV-4` se mesure en octets, un arrondi en
 * mégaoctets perdrait la mesure. Un `completedTileCount` à zéro s'écrit
 * `tuiles=0` — c'est le cas qui infirmerait `NV-1`, il ne se maquille pas.
 */
export function describeProgress(progress: PackProgress, elapsedMs: number): string {
  return [
    PREFIXE,
    `etat=${progress.state}`,
    `pourcentage=${progress.percentage}`,
    `tuiles=${progress.completedTileCount}`,
    `octets=${progress.completedTileSize}`,
    `ms=${elapsedMs}`,
  ].join(" ");
}

/**
 * Une erreur de pack part sous le même préfixe que les mesures : les deux se
 * relisent d'un seul `logcat`. Le cas le plus attendu ici est le dépassement du
 * plafond de tuiles, qui interrompt le téléchargement sans autre signal.
 */
export function describeError(message: string): string {
  return `${PREFIXE} erreur=${message}`;
}

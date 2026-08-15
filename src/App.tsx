import { StatusBar } from "expo-status-bar";

import { OfflinePackProbe } from "./features/map/OfflinePackProbe";

/**
 * ⚠️ **Provisoire — tâche `M4` du plan T0.** L'application n'affiche qu'un
 * écran de constat : `OfflineManager.createPack` télécharge-t-il réellement les
 * tuiles raster du WMTS IGN (`NV-1`) ?
 *
 * Il affiche le même fond que l'écran de `M2`, dont il reprend donc aussi le
 * constat — `IgnMapProbe` reste au dépôt le temps de T0 et disparaît en T1 avec
 * les deux sondes.
 *
 * Les vrais écrans, le routage et les quatre avertissements obligatoires
 * (`BR-012`, `BR-013`) arrivent en T1. Rien ne part en production sans eux.
 */
export default function App() {
  return (
    <>
      <OfflinePackProbe />
      <StatusBar style="auto" />
    </>
  );
}

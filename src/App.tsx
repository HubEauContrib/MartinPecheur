import { StatusBar } from "expo-status-bar";

import { IgnMapProbe } from "./features/map/IgnMapProbe";

/**
 * ⚠️ **Provisoire — tâche `M2` du plan T0.** L'application n'affiche pour
 * l'instant qu'un écran de constat pour `NV-2` : le fond IGN se charge-t-il ?
 *
 * Les vrais écrans, le routage et les quatre avertissements obligatoires
 * (`BR-012`, `BR-013`) arrivent en T1. Rien ne part en production sans eux.
 */
export default function App() {
  return (
    <>
      <IgnMapProbe />
      <StatusBar style="auto" />
    </>
  );
}

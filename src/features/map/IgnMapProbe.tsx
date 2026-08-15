import { Camera, Map } from "@maplibre/maplibre-react-native";
import { StyleSheet, Text, View } from "react-native";

import { ignRasterStyle } from "./ignRasterStyle";

/**
 * Écran de constat pour `NV-2` — **provisoire, tâche `M2` du plan T0**.
 *
 * Il n'a qu'un but : répondre à une question qu'aucun test unitaire ne peut
 * trancher — MapLibre laisse-t-il les `?` et `&` de l'URL KVP du WMTS IGN
 * intacts en expansant `{z}/{x}/{y}` ?
 *
 * **Lecture du résultat :**
 * - fond de carte visible → `NV-2` est levé, le gabarit KVP survit ;
 * - fond vide ou gris → le gabarit n'a pas survécu. Inspecter le trafic réseau
 *   **avant** de soupçonner autre chose : c'est la seule hypothèse à tester.
 *
 * Les vrais écrans arrivent en T1, sous `features/`, avec le routage. Celui-ci
 * disparaît à ce moment-là.
 */

/** Centré sur la Loire à Blois — la station `K447001001` du cadrage. */
const BLOIS: [number, number] = [1.3333, 47.5861];
const ZOOM_INITIAL = 11;

export function IgnMapProbe() {
  return (
    <View style={styles.container}>
      {/* Aucun transtypage : `ignRasterStyle` est vérifié conforme à
          `StyleSpecification` par `tsc`, dans son propre module. */}
      <Map style={styles.map} mapStyle={ignRasterStyle}>
        {/* v11 : `initialViewState` avec `center`/`zoom`. Le `defaultSettings`
            et le `centerCoordinate`/`zoomLevel` de la v10 n'existent plus. */}
        <Camera initialViewState={{ center: BLOIS, zoom: ZOOM_INITIAL }} />
      </Map>
      <View style={styles.attribution}>
        {/* L'attribution est une obligation de la Licence Ouverte, pas une finition. */}
        <Text style={styles.attributionText}>© IGN Géoplateforme — Licence Ouverte</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
  attribution: {
    backgroundColor: "rgba(255,255,255,0.8)",
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  attributionText: { fontSize: 11 },
});

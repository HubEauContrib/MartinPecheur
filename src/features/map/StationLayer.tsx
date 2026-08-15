import { GeoJSONSource, Layer } from "@maplibre/maplibre-react-native";

import { stationCollection } from "./stationsAsset";

/**
 * Les 4 150 stations en service, en une source clusterisée.
 *
 * `03-conception.md § 6` rend le clustering **obligatoire** dès le zoom
 * départemental : sans lui, la carte est illisible et le rendu s'effondre.
 *
 * ⚠️ **API v11, lue dans les typings.** Le plan T0 décrivait `ShapeSource`,
 * `CircleLayer` et `SymbolLayer` avec une prop `style` : ces composants
 * **n'existent plus**. La v11 expose `GeoJSONSource` et un `Layer` générique
 * dont les propriétés suivent la spécification de style (`paint`/`layout`, en
 * kebab-case). `style` y est déprécié et disparaîtra en v12.
 *
 * ⚠️ **Pas de libellé chiffré sur les clusters, et c'est délibéré.** Une couche
 * `symbol` avec `text-field` exige une source de glyphes ; `ignRasterStyle`
 * n'en déclare pas, et aucune URL de police IGN n'a été vérifiée par appel
 * réel. Une telle couche ne rendrait **rien, sans erreur** — exactement le
 * genre de panne silencieuse que ce projet refuse. Le nombre est donc encodé
 * par la taille et la couleur du cercle, qui se voient sans glyphes. Le
 * libellé arrivera en T1, avec la légende et une source de police constatée.
 *
 * ⚠️ **Aucune couleur ne signifie ici un état de rivière.** Les teintes
 * ci-dessous disent un **nombre de stations**, rien d'autre. Les échelles
 * d'écoulement, de débit et de sécheresse restent séparées (`BR-008`) et
 * arrivent en T1 ; un cluster portera alors l'état le plus sévère de ses
 * membres (`BR-009`).
 */

/** Au-delà, les points se séparent. `clusterMaxZoom`, pas `clusterMaxZoomLevel`. */
const ZOOM_MAX_CLUSTER = 12;
const RAYON_CLUSTER = 50;

export function StationLayer() {
  return (
    <GeoJSONSource
      id="stations"
      data={stationCollection}
      cluster
      clusterRadius={RAYON_CLUSTER}
      clusterMaxZoom={ZOOM_MAX_CLUSTER}
    >
      <Layer
        type="circle"
        id="stations-clusters"
        filter={["has", "point_count"]}
        paint={{
          // Paliers de densité — une taille lisible sans libellé chiffré.
          "circle-radius": ["step", ["get", "point_count"], 14, 20, 20, 100, 28],
          "circle-color": ["step", ["get", "point_count"], "#4b8fc7", 20, "#2c6ca3", 100, "#14507d"],
          "circle-opacity": 0.85,
          "circle-stroke-width": 1.5,
          "circle-stroke-color": "#ffffff",
        }}
      />
      <Layer
        type="circle"
        id="stations-unitaires"
        filter={["!", ["has", "point_count"]]}
        paint={{
          "circle-radius": 5,
          "circle-color": "#14507d",
          "circle-stroke-width": 1,
          "circle-stroke-color": "#ffffff",
        }}
      />
    </GeoJSONSource>
  );
}

import { stationCollection, summarizeStations } from "@features/map/stationsAsset";

/**
 * L'asset figé par `S4` est la source des 4 150 marqueurs de `M3`. Une carte
 * vide ne lève aucune erreur : elle s'affiche, simplement sans points. Ces
 * tests sont le seul endroit où cette panne-là devient bruyante.
 */
describe("référentiel des stations, chargé depuis l'asset", () => {
  it("est une FeatureCollection non vide", () => {
    expect(stationCollection.type).toBe("FeatureCollection");
    expect(stationCollection.features.length).toBeGreaterThan(4000);
  });

  it("ne contient que des points géolocalisés", () => {
    // MapLibre affiche une ShapeSource sans broncher même si les géométries
    // sont absentes. Le contrôle doit donc être fait ici.
    const resume = summarizeStations(stationCollection);

    expect(resume.sansGeometrie).toBe(0);
    expect(resume.nonPonctuelles).toBe(0);
  });

  it("ne porte que des codes station à dix caractères (C-05)", () => {
    // Un code site en fait huit et renverrait chaque mesure en double.
    const resume = summarizeStations(stationCollection);

    expect(resume.longueursDeCode).toEqual([10]);
  });

  it("compte autant de codes distincts que d'entités", () => {
    const resume = summarizeStations(stationCollection);

    expect(resume.codesDistincts).toBe(resume.entites);
  });

  it("reste dans les bornes géographiques du domaine français", () => {
    // Une longitude et une latitude interverties placerait les stations au
    // large de la Somalie, et la carte s'afficherait sans erreur.
    const resume = summarizeStations(stationCollection);

    expect(resume.horsBornes).toBe(0);
  });
});

import {
  cubicMetresPerSecond,
  litresPerSecond,
  metres,
  millimetres,
} from "@domain/units/quantities";
import { toCubicMetresPerSecond, toMetres } from "@domain/units/conversions";

/**
 * BR-002 — le débit s'affiche en m³/s, la hauteur en mètres.
 * C-02 — Hub'Eau renvoie des l/s et des mm, contrairement à ce que son
 * interface laisse croire. Afficher la valeur brute produirait une erreur d'un
 * facteur 1000 : « 53 000 » pour 53 m³/s n'est pas une imprécision, c'est une
 * information fausse sur laquelle un irrigant peut fonder une décision.
 */
describe("débit — litres par seconde vers mètres cubes par seconde (BR-002)", () => {
  it("convertit la valeur réelle de la Loire à Blois", () => {
    // Station K447001001, resultat_obs = 53000.0 → 53 m³/s. Vérifié le 2026-07-30.
    expect(toCubicMetresPerSecond(litresPerSecond(53000))).toBe(cubicMetresPerSecond(53));
  });

  it("convertit la valeur réelle d'obs_elab sans perte de précision", () => {
    // Station K447001001, resultat_obs_elab (QmnJ) = 350571.0 → 350,571 m³/s.
    // Vérifié le 2026-07-30. L'égalité stricte tient : 350571/1000 et le littéral
    // 350.571 arrondissent au même double.
    expect(toCubicMetresPerSecond(litresPerSecond(350571))).toBe(cubicMetresPerSecond(350.571));
  });

  it("propage l'absence sans la transformer en zéro (BR-007)", () => {
    expect(toCubicMetresPerSecond(null)).toBeNull();
    expect(toCubicMetresPerSecond(undefined)).toBeNull();
  });

  it("distingue un zéro mesuré d'une absence de mesure (BR-007)", () => {
    // Un débit mesuré à zéro est un fait — un assec. Le confondre avec une
    // donnée manquante ferait disparaître l'observation la plus grave.
    expect(toCubicMetresPerSecond(litresPerSecond(0))).toBe(cubicMetresPerSecond(0));
    expect(toCubicMetresPerSecond(litresPerSecond(0))).not.toBeNull();
  });

  it("refuse une valeur non finie plutôt que de la faire passer pour une absence", () => {
    // NaN n'est pas « pas de donnée » : c'est un bug. Le confondre avec une
    // absence afficherait « non transmis » alors que le code est cassé.
    expect(() => toCubicMetresPerSecond(litresPerSecond(Number.NaN))).toThrow(/finie/);
    expect(() => toCubicMetresPerSecond(litresPerSecond(Number.POSITIVE_INFINITY))).toThrow(/finie/);
  });
});

describe("hauteur — millimètres vers mètres (BR-002)", () => {
  it("convertit une hauteur", () => {
    expect(toMetres(millimetres(1234))).toBe(metres(1.234));
  });

  it("propage l'absence", () => {
    expect(toMetres(null)).toBeNull();
    expect(toMetres(undefined)).toBeNull();
  });
});

/**
 * Le cœur de la parade TypeScript. En C#, la double conversion se gardait au
 * runtime ; ici les types la rendent NON COMPILABLE. Ces cas ne s'exécutent
 * pas — ils échouent à `tsc`, ce qui est plus tôt et plus sûr.
 */
describe("la double conversion ne compile pas", () => {
  it("refuse de reconvertir des m³/s", () => {
    const debit = toCubicMetresPerSecond(litresPerSecond(53000));
    // @ts-expect-error — des m³/s ne sont pas des l/s. Si cette ligne compilait,
    // `tsc` échouerait sur le @ts-expect-error inutilisé : le garde-fou est actif
    // dans les deux sens.
    toCubicMetresPerSecond(debit);
  });

  it("refuse de mélanger hauteur et débit", () => {
    // @ts-expect-error — des millimètres ne sont pas des litres par seconde.
    toCubicMetresPerSecond(millimetres(1234));
  });

  it("refuse un nombre nu là où une unité est attendue", () => {
    // @ts-expect-error — un `number` sans unité n'est pas un débit. C'est
    // exactement le bug que BR-002 rend impossible.
    toCubicMetresPerSecond(53000);
  });
});

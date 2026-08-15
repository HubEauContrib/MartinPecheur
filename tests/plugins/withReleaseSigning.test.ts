import { readFileSync } from "node:fs";
import { join } from "node:path";

/* eslint-disable @typescript-eslint/no-require-imports */
const { patchAppBuildGradle } = require("../../plugins/withReleaseSigning") as {
  patchAppBuildGradle: (contents: string) => string;
};
/* eslint-enable @typescript-eslint/no-require-imports */

/**
 * Extrait **réel** du `android/app/build.gradle` produit par
 * `npx expo prebuild --platform android` le 2026-08-15 — recopié, pas inventé.
 * C'est le fichier que le plugin doit réécrire.
 */
const BUILD_GRADLE = readFileSync(join(__dirname, "buildGradle.fixture.txt"), "utf8");

describe("signature des builds release (plugin de configuration)", () => {
  it("ajoute un signingConfig release piloté par propriétés Gradle", () => {
    const patche = patchAppBuildGradle(BUILD_GRADLE);

    expect(patche).toContain("MARTINPECHEUR_STORE_FILE");
    expect(patche).toContain("MARTINPECHEUR_KEY_ALIAS");
  });

  it("débranche le buildType release du keystore de debug", () => {
    // Le défaut d'origine : le gabarit Expo publie un APK signé de la clé de
    // debug publique d'Android. Après correctif, le buildType release choisit
    // la vraie clé dès qu'elle est fournie.
    const patche = patchAppBuildGradle(BUILD_GRADLE);
    const release = patche.slice(patche.indexOf("buildTypes {"));

    expect(release).toContain(
      "signingConfig hasProperty('MARTINPECHEUR_STORE_FILE') ? signingConfigs.release : signingConfigs.debug",
    );
  });

  it("laisse le buildType debug intact", () => {
    // Un build de développement n'a rien à signer autrement.
    const patche = patchAppBuildGradle(BUILD_GRADLE);
    const buildTypes = patche.slice(patche.indexOf("buildTypes {"));
    const debut = buildTypes.indexOf("debug {");
    const fin = buildTypes.indexOf("release {");

    expect(buildTypes.slice(debut, fin)).toContain("signingConfig signingConfigs.debug");
  });

  it("est idempotent — deux prebuilds ne dupliquent pas le bloc", () => {
    const une = patchAppBuildGradle(BUILD_GRADLE);

    expect(patchAppBuildGradle(une)).toBe(une);
  });

  it("lève si le gabarit Expo ne présente plus ses ancres", () => {
    // Un plugin qui ne trouve pas son point d'insertion et rend l'entrée
    // inchangée réintroduirait la signature de debug **en silence**. C'est
    // exactement le défaut qu'il existe pour fermer : il doit échouer fort.
    expect(() => patchAppBuildGradle("android {\n}\n")).toThrow(/signingConfigs/);
    expect(() =>
      patchAppBuildGradle("android {\n    signingConfigs {\n        debug {}\n    }\n}\n"),
    ).toThrow(/buildTypes/);
  });

  it("lève si le buildType release ne référence plus signingConfigs.debug", () => {
    const sansAncre = BUILD_GRADLE.replace(
      /release \{[\s\S]*?signingConfig signingConfigs\.debug/,
      "release {\n            // signature déjà gérée ailleurs",
    );

    expect(() => patchAppBuildGradle(sansAncre)).toThrow(/gabarit Expo/);
  });
});

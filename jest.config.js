/**
 * Un seul projet pour l'instant : `unit`, en environnement `node`, SANS le
 * préréglage `jest-expo`.
 *
 * Ce n'est pas un détail de configuration. Le projet n'ayant aucune
 * transformation React Native, un import de React Native depuis `domain/`
 * casse le test au lieu de passer inaperçu : l'invariant d'architecture
 * d'ADR-010 devient une erreur, pas une remarque de revue de code.
 *
 * Le second projet, en préréglage `jest-expo` pour les composants
 * (`*.test.tsx`), s'ajoutera en T1 quand il y aura un composant à tester.
 */
module.exports = {
  projects: [
    {
      displayName: "unit",
      testEnvironment: "node",
      testMatch: ["<rootDir>/tests/**/*.test.ts"],
      transform: {
        "^.+\\.tsx?$": [
          "ts-jest",
          {
            tsconfig: {
              module: "commonjs",
              target: "es2022",
              esModuleInterop: true,
              strict: true,
              noUncheckedIndexedAccess: true,
              exactOptionalPropertyTypes: true,
            },
          },
        ],
      },
      moduleNameMapper: {
        "^@domain/(.*)$": "<rootDir>/src/domain/$1",
        "^@data/(.*)$": "<rootDir>/src/data/$1",
        "^@application/(.*)$": "<rootDir>/src/application/$1",
        "^@features/(.*)$": "<rootDir>/src/features/$1",
      },
    },
  ],
};

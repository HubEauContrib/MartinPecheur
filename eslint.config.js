const tseslint = require("typescript-eslint");

/**
 * Deuxième verrou de la frontière `domain/`, complémentaire du test
 * d'architecture : celui-ci lit les imports en texte, ESLint les comprend.
 * Les deux n'attrapent pas les mêmes contournements.
 */
module.exports = tseslint.config(
  { ignores: ["node_modules/**", "dist/**", ".expo/**", "android/**", "ios/**", "assets/**"] },

  { files: ["src/**/*.ts", "src/**/*.tsx", "tests/**/*.ts"], extends: [tseslint.configs.recommended] },

  {
    files: ["src/domain/**/*.ts"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["react", "react-*", "@react-native*"],
              message: "domain/ ne dépend d'aucun framework (ADR-010).",
            },
            {
              group: ["expo", "expo-*"],
              message: "domain/ ne dépend d'aucun framework (ADR-010).",
            },
            {
              group: ["@maplibre/*", "@op-engineering/*"],
              message: "domain/ ne connaît ni la carte ni le stockage (ADR-010).",
            },
            {
              group: ["@data/*", "@application/*", "@features/*"],
              message: "domain/ est la couche la plus interne : elle n'appelle personne.",
            },
          ],
        },
      ],
    },
  },
);

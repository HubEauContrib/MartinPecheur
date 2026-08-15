import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join } from "node:path";

const DOMAIN_ROOT = join(__dirname, "..", "..", "src", "domain");

/**
 * Ce que `domain/` n'a pas le droit de connaître (ADR-010).
 * `domain/` est du TypeScript pur : ni framework, ni réseau, ni stockage.
 */
const FORBIDDEN_PREFIXES = [
  "react",
  "expo",
  "@maplibre/",
  "@op-engineering/",
  "@react-native",
  "node:",
];

/** Les couches externes : `domain/` est la plus interne, il n'appelle personne. */
const FORBIDDEN_LAYERS = ["@data/", "@application/", "@features/"];

function typeScriptFilesIn(directory: string): string[] {
  if (!existsSync(directory)) return [];
  return readdirSync(directory).flatMap((entry) => {
    const full = join(directory, entry);
    if (statSync(full).isDirectory()) return typeScriptFilesIn(full);
    return full.endsWith(".ts") || full.endsWith(".tsx") ? [full] : [];
  });
}

function importedModulesOf(source: string): string[] {
  const specifiers: string[] = [];
  // `from "x"` couvre import et export ; `require("x")` couvre l'interop CommonJS.
  for (const match of source.matchAll(/(?:from|require\s*\()\s*["']([^"']+)["']/g)) {
    const specifier = match[1];
    if (specifier !== undefined) specifiers.push(specifier);
  }
  return specifiers;
}

describe("frontière du domaine (ADR-010)", () => {
  it("n'importe aucun framework ni aucune infrastructure", () => {
    const offenders: string[] = [];

    for (const file of typeScriptFilesIn(DOMAIN_ROOT)) {
      for (const specifier of importedModulesOf(readFileSync(file, "utf8"))) {
        if (specifier.startsWith(".")) continue;

        const forbidden =
          FORBIDDEN_PREFIXES.some((p) => specifier === p || specifier.startsWith(p)) ||
          FORBIDDEN_LAYERS.some((p) => specifier.startsWith(p));

        if (forbidden) {
          offenders.push(`${file.replace(DOMAIN_ROOT, "src/domain")} importe « ${specifier} »`);
        }
      }
    }

    expect(offenders).toEqual([]);
  });

  it("surveille un dossier qui existe ET qui contient des fichiers", () => {
    // Un test vert parce qu'il ne regarde rien est pire qu'un test absent :
    // il donne une garantie qu'il ne fournit pas. Vérifier la seule existence
    // du dossier ne suffit pas — un `src/domain/` vidé par un déplacement de
    // fichiers laisserait les deux tests au vert, sans plus rien surveiller.
    expect(existsSync(DOMAIN_ROOT)).toBe(true);
    expect(typeScriptFilesIn(DOMAIN_ROOT).length).toBeGreaterThan(0);
  });
});

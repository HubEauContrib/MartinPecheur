/**
 * Analyse des arguments de `build.ts` — **du TypeScript pur**, donc testable
 * sous Node comme le reste de la chaîne.
 *
 * Ce module existe pour une raison précise : `build.ts` écrit par défaut dans
 * `assets/percentiles/reference.json`, qui est un **livrable versionné**
 * (`ADR-003`) produit par une passe de ~2 heures. Une option mal tapée ne doit
 * jamais pouvoir aboutir à un asset vide écrit par-dessus. Un argument refusé
 * bruyamment coûte une seconde ; un asset vide écrit en silence coûte la passe
 * entière, et se remarque à l'exécution sur le téléphone.
 */

/**
 * Valeur d'une option, sous les deux formes usuelles : `--nom valeur` et
 * `--nom=valeur`.
 *
 * ⚠️ **`--nom` sans valeur lève, il ne rend pas `undefined`.** C'est la
 * distinction qui compte ici : `undefined` signifie « option absente », donc
 * « prends le défaut ». Confondre les deux fait qu'un `--limite` dont on a
 * oublié le nombre déclenche silencieusement la passe complète de 4 150
 * stations, soit deux heures d'aspiration au lieu d'un échantillon.
 */
export function argument(argv: readonly string[], nom: string): string | undefined {
  const prefixe = `--${nom}`;

  const index = argv.indexOf(prefixe);
  if (index !== -1) {
    const valeur = argv[index + 1];
    if (valeur === undefined || valeur.startsWith("--")) {
      throw new Error(`L'option ${prefixe} attend une valeur.`);
    }
    return valeur;
  }

  const colle = argv.find((entree) => entree.startsWith(`${prefixe}=`));
  if (colle === undefined) return undefined;

  const valeur = colle.slice(prefixe.length + 1);
  if (valeur === "") throw new Error(`L'option ${prefixe} attend une valeur.`);
  return valeur;
}

/**
 * Codes station à aspirer, éventuellement réduits à un échantillon.
 *
 * ⚠️ Échantillonnage **à pas régulier**, jamais les N premières. Le référentiel
 * est ordonné par code, donc par bassin : les premières stations sont voisines,
 * et mesurer sur elles décrirait un bassin, pas la France.
 *
 * ⚠️ **`--limite` est validée avant tout appel réseau.** `Number("abc")` vaut
 * `NaN` et `Number("0")` vaut zéro ; l'un comme l'autre produisaient une liste
 * vide, donc un asset sans aucune station, écrit par-dessus le livrable et
 * annoncé par un `stations=0` que rien ne distinguait d'un succès.
 */
export function selectionnerCodes(
  tous: readonly string[],
  limiteBrute: string | undefined,
): string[] {
  if (tous.length === 0) {
    throw new Error("Référentiel de stations vide : rien à aspirer.");
  }

  if (limiteBrute === undefined) return [...tous];

  const limite = Number(limiteBrute);
  if (!Number.isInteger(limite) || limite < 1) {
    throw new RangeError(`--limite attend un entier ≥ 1, reçu « ${limiteBrute} ».`);
  }

  const retenues = Math.min(limite, tous.length);
  const pas = Math.max(Math.floor(tous.length / retenues), 1);

  return Array.from({ length: retenues }, (_, i) => tous[i * pas]).filter(
    (code): code is string => code !== undefined,
  );
}

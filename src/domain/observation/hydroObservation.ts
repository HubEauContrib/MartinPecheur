import type { CubicMetresPerSecond, Metres } from "../units/quantities";
import type { StationCode } from "../station/station";

/**
 * Grandeur mesurée, telle que Hub'Eau la nomme : `H` hauteur, `Q` débit.
 * La branche `Inconnu` est obligatoire (BR-011).
 */
export type GrandeurHydro = "H" | "Q" | "Inconnu";

/**
 * Statut de qualification, **toujours affiché** (BR-006). Valeurs constatées le
 * 2026-08-01 sur `K447001001` : `code_statut` 4 « Brute » et 8 « Corrigée » ;
 * `code_qualification_obs` 16 « Non qualifiée ».
 *
 * Les libellés sont conservés tels quels : le produit affiche la nomenclature
 * officielle, il ne la réinterprète pas.
 */
export interface Qualification {
  readonly codeStatut: number | null;
  readonly libelleStatut: string | null;
  readonly codeQualification: number | null;
  readonly libelleQualification: string | null;
}

/**
 * Observation hydrométrique temps réel, **déjà convertie**.
 *
 * Aucune valeur brute d'API n'atteint la vue (BR-002) : `debit` et `hauteur`
 * portent des types d'unité, pas des `number` nus.
 *
 * `null` signifie « la station n'a pas transmis cette grandeur », jamais zéro
 * (BR-007). Un zéro mesuré est un fait — un assec.
 *
 * ⚠️ La hauteur peut être **négative** : `resultat_obs = -1232.0` relevé le
 * 2026-08-01 sur `K447001001`, soit −1,232 m par rapport au zéro de l'échelle.
 * Aucun contrôle de signe ne doit être ajouté.
 */
export interface HydroObservation {
  readonly codeStation: StationCode;
  /** Date de MESURE (`date_obs`), jamais la date de récupération (BR-001, BR-005). */
  readonly dateObs: Date;
  readonly grandeur: GrandeurHydro;
  readonly debit: CubicMetresPerSecond | null;
  readonly hauteur: Metres | null;
  readonly qualification: Qualification;
}

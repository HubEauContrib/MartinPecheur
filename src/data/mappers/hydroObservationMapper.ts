import { toCubicMetresPerSecond, toMetres } from "@domain/units/conversions";
import { litresPerSecond, millimetres } from "@domain/units/quantities";
import { stationCode } from "@domain/station/station";
import type { GrandeurHydro, HydroObservation } from "@domain/observation/hydroObservation";

/**
 * Forme brute renvoyée par `/v2/hydrometrie/observations_tr`, telle que
 * constatée le 2026-07-30 (`01-analyse.md`). Le champ de qualification est
 * `libelle_qualification_obs`, **pas** `libelle_qualification` : ce dernier
 * n'existe que sur `obs_elab`.
 */
export interface HydroObservationPayload {
  readonly code_station: string;
  readonly date_obs: string;
  readonly grandeur_hydro: string;
  readonly resultat_obs: number | null;
  readonly code_statut: number | null;
  readonly libelle_statut: string | null;
  readonly code_qualification_obs: number | null;
  readonly libelle_qualification_obs: string | null;
}

function grandeurFrom(raw: string): GrandeurHydro {
  if (raw === "H") return "H";
  if (raw === "Q") return "Q";
  return "Inconnu"; // BR-011 : jamais de valeur inventée
}

/**
 * Seul point de passage entre la charge utile brute et le domaine. La division
 * par 1000 n'a lieu qu'ici (BR-002) : une conversion faite deux fois est aussi
 * fausse qu'une conversion oubliée.
 */
export function mapHydroObservation(payload: HydroObservationPayload): HydroObservation {
  const grandeur = grandeurFrom(payload.grandeur_hydro);
  const brut = payload.resultat_obs;

  return {
    codeStation: stationCode(payload.code_station),
    dateObs: new Date(payload.date_obs),
    grandeur,
    debit: grandeur === "Q" && brut !== null ? toCubicMetresPerSecond(litresPerSecond(brut)) : null,
    hauteur: grandeur === "H" && brut !== null ? toMetres(millimetres(brut)) : null,
    // Transporté tel quel : le produit affiche la nomenclature officielle, il ne
    // la réinterprète pas (BR-006).
    qualification: {
      codeStatut: payload.code_statut,
      libelleStatut: payload.libelle_statut,
      codeQualification: payload.code_qualification_obs,
      libelleQualification: payload.libelle_qualification_obs,
    },
  };
}

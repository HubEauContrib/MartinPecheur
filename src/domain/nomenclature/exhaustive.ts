/**
 * Rend l'oubli d'une branche non compilable.
 *
 * Ajouter une valeur à une union sans traiter son cas produit une erreur `tsc`
 * ici, et non un comportement silencieux en production. C'est la parade exigée
 * par BR-011 : sur ce produit, une nomenclature incomplète ne se manifeste pas
 * par un plantage mais par un affichage faussement rassurant.
 *
 * Le `throw` couvre le cas où une valeur hors union arrive quand même à
 * l'exécution — typiquement une donnée désérialisée, que le typage ne voit pas.
 */
export function assertNever(value: never): never {
  throw new Error(`Cas non traité : ${JSON.stringify(value)}`);
}

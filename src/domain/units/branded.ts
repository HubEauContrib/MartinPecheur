/**
 * Marque nominale sur un type structurel.
 *
 * TypeScript compare les types par leur forme : sans marque, un `number` en
 * litres par seconde passe partout où on attend des mètres cubes par seconde.
 * C'est le bug le plus coûteux du projet (BR-002) — un facteur 1000 sur une
 * valeur qu'un irrigant peut lire pour décider.
 *
 * C# l'attrapait au runtime. Ici, la marque le rend NON COMPILABLE, ce qui est
 * plus tôt et plus sûr. Le symbole n'existe qu'à la compilation : à l'exécution
 * une quantité marquée reste un `number` ordinaire, sans surcoût ni allocation.
 */
declare const unit: unique symbol;

export type Branded<T, B extends string> = T & { readonly [unit]: B };

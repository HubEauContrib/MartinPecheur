import {
  Camera,
  Map,
  OfflineManager,
  type OfflinePackStatus,
} from "@maplibre/maplibre-react-native";
import { useCallback, useEffect, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { ignRasterStyle } from "./ignRasterStyle";
import { createOfflinePack } from "./offlinePack";
import { LOIR_ET_CHER, OFFLINE_MAX_ZOOM, OFFLINE_MIN_ZOOM } from "./offlinePackOptions";
import { describeError, describeProgress } from "./offlinePackProgress";
import { StationLayer } from "./StationLayer";

/**
 * Écran de constat de `M4` — **provisoire, et le résultat est négatif.**
 *
 * 🚨 **Appuyer sur le bouton fait mourir l'application.** Ce n'est pas un
 * défaut de cet écran : `OfflineManager.createPack` de
 * `@maplibre/maplibre-react-native@11.3.6` plante en natif environ 0,7 s après
 * la création du pack — `SIGABRT` sur `std::regex_error` non rattrapée, fil
 * `DatabaseFileSource`. Reproduit **4 fois sur 4**, base vierge comprise, et
 * avec le style vectoriel de démonstration de MapLibre. Détail et arbitrage :
 * `docs/adr/ADR-012-hors-ligne-cartographique-bloque.md`.
 *
 * L'écran est conservé comme **cas de reproduction minimal** : il tient en un
 * appui, et il redeviendra le constat de `M4` le jour où le défaut amont sera
 * levé. `NV-1`, `NV-3`, `NV-4` et `NV-6` restent **non levés** — le plantage
 * survient avant qu'une seule tuile soit téléchargée.
 *
 * ⚠️ Le style est celui de démonstration de MapLibre, **pas l'IGN**, et c'est
 * délibéré : il prouve que le défaut ne vient ni de notre fond ni du raster.
 * Le fond IGN reste affiché par la carte, ce qui reconduit au passage le
 * constat de `M2`.
 */

/** Centre de l'emprise visée, à un zoom qu'elle couvre. */
const CENTRE: [number, number] = [
  (LOIR_ET_CHER.west + LOIR_ET_CHER.east) / 2,
  (LOIR_ET_CHER.south + LOIR_ET_CHER.north) / 2,
];
const ZOOM_INITIAL = 9;

/**
 * ⚠️ Style de **démonstration MapLibre**, choisi pour isoler le défaut.
 *
 * Le fond IGN ne peut pas être utilisé ici : `mapStyle` exige une URL, et notre
 * style n'existe qu'en mémoire. Le poser sur une URL `file://` demanderait un
 * module de système de fichiers, que le projet n'embarque pas — et cela ne
 * servirait à rien tant que l'appel plante.
 */
const STYLE_DE_REPRODUCTION = "https://demotiles.maplibre.org/style.json";

export function OfflinePackProbe() {
  const [releve, setReleve] = useState("Aucun téléchargement lancé.");
  const [packsEnBase, setPacksEnBase] = useState("packs en base : …");

  /**
   * Au montage, et donc à chaque relance : combien de packs la base contient
   * déjà. C'est ce compteur qui, en mode avion, distinguerait un pack persisté
   * d'un simple cache ambiant — si le téléchargement aboutissait un jour.
   */
  const rafraichirPacks = useCallback(() => {
    OfflineManager.getPacks()
      .then(async (packs) => {
        // `status()` peut résoudre à `null` — constaté le 2026-08-15 sur un
        // pack créé mais jamais alimenté (« getPackStatus - Unknown offline
        // region »). Le déréférencer masquait la vraie mesure derrière un
        // TypeError.
        const statuts = (await Promise.all(packs.map((pack) => pack.status()))).filter(
          (statut): statut is OfflinePackStatus => statut !== null && statut !== undefined,
        );
        const total = statuts.reduce(
          (acc, statut) => ({
            tuiles: acc.tuiles + statut.completedTileCount,
            octets: acc.octets + statut.completedTileSize,
          }),
          { tuiles: 0, octets: 0 },
        );
        const ligne = `M4 packs=${packs.length} statuts=${statuts.length} tuiles=${total.tuiles} octets=${total.octets}`;
        console.log(ligne);
        setPacksEnBase(ligne);
      })
      .catch((erreur: unknown) => {
        const ligne = describeError(`getPacks ${String(erreur)}`);
        console.log(ligne);
        setPacksEnBase(ligne);
      });
  }, []);

  useEffect(rafraichirPacks, [rafraichirPacks]);

  const telecharger = useCallback(() => {
    setReleve("Téléchargement en cours…");

    const suivre = (status: OfflinePackStatus, elapsedMs: number) => {
      const ligne = describeProgress(status, elapsedMs);
      console.log(ligne);
      setReleve(ligne);
      if (status.state === "complete") rafraichirPacks();
    };

    const signaler = (message: string) => {
      const ligne = describeError(message);
      console.log(ligne);
      setReleve(ligne);
    };

    createOfflinePack(
      LOIR_ET_CHER,
      OFFLINE_MIN_ZOOM,
      OFFLINE_MAX_ZOOM,
      STYLE_DE_REPRODUCTION,
      { onProgress: suivre, onError: signaler },
    )
      .then((pack) => {
        // ⚠️ Le processus meurt ~0,7 s après cette ligne. Les événements de
        // progression n'arrivent jamais : c'est pourquoi on interroge le
        // statut plutôt que de les attendre.
        console.log(`M4 pack cree id=${pack.id}`);
        const debut = Date.now();
        const minuteur = setInterval(() => {
          pack
            .status()
            .then((statut) => {
              if (statut === null || statut === undefined) return;
              setReleve(describeProgress(statut, Date.now() - debut));
              if (statut.state === "complete") {
                clearInterval(minuteur);
                rafraichirPacks();
              }
            })
            .catch((erreur: unknown) => signaler(`status ${String(erreur)}`));
        }, 2000);
      })
      .catch((erreur: unknown) => signaler(`createPack ${String(erreur)}`));
  }, [rafraichirPacks]);

  return (
    <View style={styles.container}>
      <Map style={styles.map} mapStyle={ignRasterStyle}>
        <Camera initialViewState={{ center: CENTRE, zoom: ZOOM_INITIAL }} />
        {/* `M3` — les 4 150 stations clusterisées, sur le fond IGN. */}
        <StationLayer />
      </Map>
      <View style={styles.panneau}>
        <Pressable style={styles.bouton} onPress={telecharger}>
          <Text style={styles.boutonTexte}>
            Reproduire le plantage MapLibre (M4) — l&apos;application va mourir
          </Text>
        </Pressable>
        <Text style={styles.releve}>{releve}</Text>
        <Text style={styles.releve}>{packsEnBase}</Text>
        {/* L'attribution est une obligation de la Licence Ouverte, pas une finition. */}
        <Text style={styles.attribution}>© IGN Géoplateforme — Licence Ouverte</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
  panneau: { backgroundColor: "rgba(255,255,255,0.92)", padding: 8, gap: 6 },
  bouton: { backgroundColor: "#8c2f2f", borderRadius: 6, padding: 10 },
  boutonTexte: { color: "#fff", fontSize: 13, textAlign: "center" },
  releve: { fontFamily: "monospace", fontSize: 11 },
  attribution: { fontSize: 11 },
});

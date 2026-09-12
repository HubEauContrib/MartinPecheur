# Design — trancher `M4` et `M5` sur un Android personnel

**Écrit le 2026-08-18.** Cadre l'usage d'un téléphone Android personnel, branché en USB au poste de
développement, pour lever les deux dernières tâches ouvertes de T0 qui exigent un appareil réel.

> Ce document ne remplace pas [`guide-test-appareil.md`](../../guide-test-appareil.md), qui décrit le
> **protocole de mesure** et reste la référence pour les gestes et la lecture des chiffres. Il tranche
> une question que ce guide ne posait pas : **par quel binaire** on met l'application sur l'appareil.

---

## Le constat qui change la réponse

Le `guide-test-appareil.md` prescrit `npx expo run:android --device`, donc une compilation native.
**Deux vérifications faites le 2026-08-18 rendent cette compilation inutile.**

### 1. Un APK release existe déjà

`android/app/build/outputs/apk/release/app-release.apk` — 114 754 978 octets (110 Mio), horodaté
**2026-08-15 12:52**. Produit par le build décrit au [`guide-release.md`](../../guide-release.md),
jamais publié. Quatre ABI, dont **`arm64-v8a`**.

### 2. Il porte l'écran courant — vérifié, pas supposé

Les dates de fichiers suggéraient un binaire périmé : `src/features/map/OfflinePackProbe.tsx` et
`app.json` sont attribués au commit `b15c01b` du **2026-08-15 14:02**, soit **1 h 10 après** le build.

C'est un artefact du *squash-merge* — la date du commit fusionné n'est pas celle de l'écriture du
code. Le contenu, lui, a été contrôlé en ouvrant le binaire :

| Recherche dans `assets/index.android.bundle` | Résultat |
|---|---|
| Format | **bytecode Hermes** (magie `c6 1f bc 03`), chaînes accentuées en **UTF-16** |
| `Reproduire le plantage MapLibre (M4) — l'application va mourir` | ✅ **présent, offset 1334044** — libellé exact de `OfflinePackProbe.tsx:223` |
| `clusterMaxZoom` | ✅ présent — le clustering de `M3` est dans le bundle |
| Asset des stations (`http://id.eaufrance.fr/CEA/…`) | ✅ présent |

Les trois commits postérieurs au build (`dc1c7fa`, `18f27b8`, `7802669`) ne touchent que la CI et des
dépendances de développement (`uuid` sous `xcode`, `js-yaml`) : **rien qui entre dans le bundle.**

> ⚠️ La recherche en ASCII ne trouve rien : les chaînes accentuées sont en UTF-16 dans le bytecode
> Hermes. Un `grep` naïf conclurait à tort que l'APK est périmé. C'est ce piège qui a failli faire
> recompiler pour rien.

---

## Décision

> **On installe l'APK release existant par `adb install -r`. On ne compile pas.**

### Pourquoi, dans l'ordre d'importance

**1. Un build release mesure `M5` plus honnêtement qu'un build de développement.** Le seuil des
**33 ms au 90ᵉ percentile** a été fixé avant toute mesure. Un bundle en mode développement, non
minifié, ajoute du jank qui n'existe pas chez l'utilisateur final : on mesurerait un chiffre
faussement mauvais contre un seuil honnête, et on conclurait à tort que `NV-5` n'est pas levé.

**2. `adb` fonctionne depuis le bac à sable, Gradle non.** Vérifié le 2026-08-18 : `adb 1.0.41`
(*37.0.1*) démarre son démon et répond. À l'inverse, tout JVM lancé depuis ce shell échoue sur
`Selector.open()` — socket AF_UNIX bloquée, constaté le 2026-08-15. Choisir l'APK, c'est donc pouvoir
dérouler la séance **de bout en bout** au lieu de dicter des commandes à recopier.

**3. Le binaire est autonome.** Bundle embarqué : ni Metro, ni `adb reverse`. Le câble ne sert plus
qu'à `logcat` et `gfxinfo`, et la mesure peut être rejouée sans le poste.

### Ce qu'on abandonne en le choisissant

| Renoncement | Portée |
|---|---|
| Rechargement à chaud, *red box* JS lisible | Sans objet : `M4` et `M5` sont des **mesures**, pas une itération de code |
| Signature de projet | L'APK est signé `CN=Android Debug`. Sans conséquence sur son propre téléphone — on ne distribue à personne |
| 30 s de transfert USB pour 110 Mo | Contre 4 à 10 min de Gradle |

**Repli assumé :** si `M4` révèle qu'il faut instrumenter du code pour comprendre le plantage, on
bascule alors sur `npx expo run:android --device`, lancé par l'utilisateur dans son propre terminal.
Ce n'est pas un échec du design, c'est sa suite prévue.

---

## Répartition des rôles

Le partage découle de ce que le bac à sable autorise, pas d'une préférence.

| L'utilisateur seul | L'agent |
|---|---|
| Options développeur (7 appuis sur « Numéro de build »), **débogage USB**, câble en « Transfert de fichiers », « Toujours autoriser » | `adb devices -l`, `adb install -r`, `adb logcat -c`, relevé et `grep` |
| Les gestes tactiles : dézoomer sur la France entière, faire glisser franchement 10 s, appuyer sur le bouton rouge | `dumpsys gfxinfo`, lecture des chiffres contre le seuil |

---

## Déroulé

**`M5` passe avant `M4` : `M4` tue l'application.**

1. **Installer** — `adb install -r android/app/build/outputs/apk/release/app-release.apk`.
2. **`M5`** — dézoom jusqu'à la France entière, glissement franc de 10 s (c'est le déplacement qui
   sollicite le clustering, pas l'immobilité), puis `dumpsys gfxinfo fr.martinpecheur.app`.
   Lecture : `90th percentile > 33 ms` = sous le seuil ; `Janky frames` au-delà de ~20 % se sent ;
   `Number Missed Vsync` confirme les décrochages francs.
3. **`M4`** — `adb logcat -c`, appui sur le bouton rouge, attente ~30 s, puis extraction de
   `regex_error|SIGABRT|M4 |has died`. **C'est la ligne de journal qui fait preuve, pas l'écran :**
   « l'application s'est fermée » est une impression.
4. **Modèle et version d'Android** du téléphone : partie du relevé, pas anecdote.

**Seul échec d'installation plausible :** `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, si une version signée
autrement traîne sur l'appareil → `adb uninstall fr.martinpecheur.app` puis réinstaller. Les quatre
ABI écartent `INSTALL_FAILED_NO_MATCHING_ABIS`.

---

## Où atterrissent les résultats

Trois fichiers, dans le même commit que le relevé.

| Fichier | Ce qui change |
|---|---|
| [`docs/adr/ADR-012`](../../adr/ADR-012-hors-ligne-cartographique-bloque.md) | Le verdict `M4`. Plantage reproduit sur `arm64` → les options A/B/C tiennent et le bug amont devient documentable ; sinon `M4` reprend à `NV-1` |
| [`docs/project-state.md`](../../project-state.md) | Statuts `M4` et `M5`, datés |
| [`CLAUDE.md`](../../../CLAUDE.md) | Ligne « Hors-ligne carto » du tableau de stack, qui affirme aujourd'hui un constat limité à `x86_64` |

### Réserve à écrire noir sur blanc

`NV-5` porte sur un Android **d'entrée de gamme**. Si l'appareil est récent, un bon chiffre donne une
**borne haute**, pas la levée de `NV-5`. Cette limite se consigne dans `project-state.md` — conclure
plus large serait exactement le genre de raccourci que l'anti-hallucination du projet interdit.

---

## Hors périmètre

| Exclu | Raison |
|---|---|
| `S5` — bibliothèque SQLite | Aucun code SQLite n'existe ; le banc de mesure est à écrire. L'appareil ne la débloque pas |
| Keystore de projet, `gh release create` | On n'installe chez personne d'autre. Le verrou produit de `BR-012` n'est pas engagé |
| Réduction du poids de l'APK (`-PreactNativeArchitectures`) | Les quatre ABI sont ici un **atout** : l'APK marche sur l'appareil sans recompiler |
| Rapport de plantage automatisé (Sentry, Play Console) | `adb logcat` suffit sur un appareil branché |

# Guide de release — livrer un APK à un testeur distant

Ce guide décrit comment produire un binaire Android **installable par quelqu'un d'autre que toi**,
et le publier en release GitHub. Il ne concerne pas le développement au quotidien — pour cela, voir
le [`guide-installation.md`](guide-installation.md).

> ✅ **La chaîne de build a été exécutée le 2026-08-15.** `prebuild` puis `assembleRelease`
> produisent un APK : `BUILD SUCCESSFUL in 3m 51s`, 311 tâches, **110 Mo**, `versionCode=1`,
> `versionName=0.1.0`, signé `CN=Android Debug`. La première rédaction de ce guide se trompait sur
> **trois points**, tous corrigés ci-dessous et tous invisibles à la lecture.
>
> 🔄 **Aucune release n'a en revanche jamais été publiée.** Les étapes `gh release create` et la
> réception côté testeur restent **écrites, pas exécutées**.

## 🔒 Le verrou produit — quand a-t-on le droit de publier

Le dépôt `HubEauContrib/MartinPecheur` est **public**. Une release GitHub y est téléchargeable par
n'importe qui : cocher *pre-release* n'y change rien. C'est formellement la même exposition qu'une
piste ouverte du Play Store, donc en principe le même verrou —
[`BR-012`](br/BR-012-acquittement-au-premier-lancement.md) et
[`BR-013`](br/BR-013-avertissement-renforce-sur-ecrans-ressource.md), qui arrivent en T1.

> 🔄 **Règle proposée, en attente d'arbitrage du commanditaire :**
>
> **Une release est publiable tant que l'application n'affiche aucun état de la ressource.**
> Dès qu'un débit, une modalité ONDE ou une qualification apparaît à l'écran, le verrou se referme
> jusqu'à la livraison des quatre avertissements.

La justification tient en une phrase : `BR-012` protège contre la **mauvaise lecture d'un état de
rivière**. Tant que l'application n'en affiche aucun — c'est le cas au 2026-08-15, `App.tsx` ne monte
qu'une sonde — il n'y a rien à mal lire. La tâche `M3` (des points sur une carte, sans état) reste du
bon côté de la ligne ; la première fiche station, non.

Tant que cet arbitrage n'est pas rendu, **s'en tenir aux alphas techniques** et écrire la limite noir
sur blanc dans la note de version.

## 🚨 Le piège n°1 — le build de développement n'est pas distribuable

L'APK produit par `npx expo run:android` est un **build debug**. Le JavaScript n'y est pas
embarqué : il est servi par Metro depuis ta machine, via `adb reverse` sur le câble USB. Envoyé à
quelqu'un, il affiche `Unable to load script`.

**Un testeur distant exige un build `release`**, où le bundle est empaqueté dans le binaire. C'est
une autre commande et un autre fichier — voir ci-dessous.

## 🚨 Le piège n°2 — le `versionCode` ne bouge pas tout seul

Constaté le 2026-08-15 dans `android/app/build.gradle`, régénéré par `prebuild` :

```gradle
versionCode 1
versionName "0.1.0"
```

`app.json` **ne déclare aucun `android.versionCode`** : Expo retombe donc sur `1`, à chaque
`prebuild`, indéfiniment. Or Android **refuse d'installer une mise à jour dont le `versionCode` n'est
pas supérieur** à celui déjà posé. Le testeur reçoit un `App not installed` sans autre explication,
et la seule issue est de désinstaller.

**Fait le 2026-08-15 :** le champ est déclaré dans `app.json`. Reste à l'**incrémenter à chaque
release**.

```json
"android": {
  "package": "fr.martinpecheur.app",
  "versionCode": 1
}
```

> ✅ **Câblage contre-éprouvé le 2026-08-15**, et pas seulement constaté : déclarer `1` ne prouvait
> rien, puisque c'est aussi la valeur par défaut. Poussé temporairement à `2`, `prebuild` produit
> bien `versionCode 2` dans `build.gradle`, et l'APK final rapporte `versionCode='1'` une fois
> revenu à `1`. Le champ agit réellement.

> `versionName` (`0.1.0`) est ce que lit l'humain ; `versionCode` est ce que compare Android. Les
> deux doivent avancer, mais seul le second est bloquant.

## 🔑 La signature — ce qui est vrai aujourd'hui

Lu le 2026-08-15 dans `android/app/build.gradle`, généré par `prebuild` :

```gradle
release {
    // Caution! In production, you need to generate your own keystore file.
    signingConfig signingConfigs.debug
}
```

**Le build `release` est signé avec le keystore de debug.** Ce keystore
(`android/app/debug.keystore`, alias `androiddebugkey`, mot de passe `android`) est le fichier fixe
du gabarit React Native — **valide du 2013-12-31 au 2052-05-01**, donc identique sur toutes les
machines et stable d'un `prebuild` à l'autre.

> ✅ **Confirmé sur le binaire le 2026-08-15**, et pas seulement lu dans `build.gradle` :
> `apksigner verify --print-certs` rapporte `Signer #1 certificate DN: CN=Android Debug, OU=Android,
> O=Unknown`.

| Conséquence | |
|---|---|
| Les mises à jour s'installent par-dessus la précédente | ✅ pas de désinstallation à demander au testeur |
| Le `debug.keystore` disparaît si `android/` est supprimé | ✅ sans effet, `prebuild` le repose à l'identique |
| **Le mot de passe est public** — ce keystore est dans tous les projets React Native du monde | 🚨 n'importe qui peut signer un faux « MartinPêcheur v0.1.1 » qui s'installera comme une mise à jour |
| Le Play Store **refuse** un binaire signé par une clé de debug | 🚨 bloquant le jour où on y va |

**Tolérable pour une alpha technique envoyée à trois personnes que tu connais. À remplacer avant
toute release régulière ou publique.** La marche à suivre est en annexe.

> ✅ **Corrigé pour la voie B le 2026-08-15.** La CI ne peut plus publier un APK signé en debug :
> [`plugins/withReleaseSigning.js`](../plugins/withReleaseSigning.js) câble un `signingConfigs.release`
> piloté par propriétés Gradle, et le workflow **refuse la publication** si `apksigner` lit encore
> `CN=Android Debug` sur le binaire produit. La voie A, manuelle, reste signée en debug tant que le
> keystore n'est pas généré — voir l'annexe.

---

## Voie A — release manuelle, depuis ton poste

Disponible **aujourd'hui**, sans compte tiers ni CI. C'est la voie à emprunter pour la première.

### 1. Ne rien publier sur du rouge

```bash
npm run verify
```

### 2. Régénérer le projet natif

```bash
npx expo prebuild --platform android --clean
```

> `android/` est **gitignoré** — il n'existe que localement et `prebuild` le reconstruit. Toute
> retouche manuelle qu'on y ferait serait effacée ici : c'est ce qui est arrivé au contournement
> `buildToolsVersion` le 2026-08-15.

> 🚨 **`EBUSY` — constaté le 2026-08-15.** Si un émulateur, `adb` ou un démon Gradle tient encore
> l'APK d'un build précédent, l'effacement d'`android/` échoue :
> `EBUSY: resource busy or locked, unlink '…/app-debug.apk'`. Le verrou est transitoire : relancer
> suffit le plus souvent, sinon `./gradlew --stop` avant.

### 3. Pointer le bon SDK Android

🚨 **Constaté le 2026-08-15, et c'est l'étape que la première version de ce guide oubliait.**

`prebuild` **n'écrit pas de `android/local.properties`**. Gradle retombe donc sur `ANDROID_HOME`,
qui vaut encore `C:\Program Files (x86)\Android\android-sdk` — le SDK Visual Studio, en lecture
seule, qui ne porte que `build-tools;36.0.0`. Le build échoue alors en 5 s :

```
Could not determine the dependencies of task
':maplibre_maplibre-react-native:compileReleaseJavaWithJavac'.
> Failed to install the following SDK components:
      build-tools;35.0.0 Android SDK Build-Tools 35
```

Le correctif de `M1` — basculer sur le SDK utilisateur, qui porte `35.0.0` **et** `36.0.0` — ne
vivait que dans l'environnement interactif. **Il ne survit ni à un shell non interactif, ni à la CI.**
Le forcer pour la durée du build :

```bash
export ANDROID_HOME="$LOCALAPPDATA/Android/Sdk" && export ANDROID_SDK_ROOT="$ANDROID_HOME"
```

### 4. Compiler en release

```bash
cd android && ./gradlew assembleRelease
```

En PowerShell, `.\gradlew.bat assembleRelease`.

> 🚨 **Ne pas enchaîner Gradle dans un tube.** `./gradlew … | tee x.log | tail` renvoie le code de
> sortie du **dernier maillon**, pas celui de Gradle : un `BUILD FAILED` remonte alors en `exit 0`.
> Constaté le 2026-08-15 — le build avait échoué et était rapporté comme réussi. Rediriger, ne pas
> tuber : `./gradlew assembleRelease > build.log 2>&1`.

L'APK sort dans `android/app/build/outputs/apk/release/app-release.apk`.

**Mesuré le 2026-08-15 :** `BUILD SUCCESSFUL in 3m 51s`, 311 tâches, **110 Mo**. Vérifier ce qu'on
vient de produire plutôt que de le supposer — `aapt2` et `apksigner` sont dans
`$ANDROID_HOME/build-tools/36.0.0/` :

```bash
aapt2 dump badging app-release.apk | grep -E "^package|native-code"
```

Au 2026-08-15 : `versionCode='1' versionName='0.1.0'`, `targetSdkVersion:'36'`, et
`native-code: 'arm64-v8a' 'armeabi-v7a' 'x86' 'x86_64'`.

### 5. Publier la release

```bash
gh release create v0.1.0-alpha.1 android/app/build/outputs/apk/release/app-release.apk --prerelease --title "v0.1.0-alpha.1 — sonde hors-ligne" --notes-file docs/notes-release.md
```

**Convention de tag :** `vMAJEUR.MINEUR.CORRECTIF[-alpha.N]`, aligné sur le `version` d'`app.json`.
Toujours `--prerelease` tant que le verrou produit ci-dessus n'est pas levé.

---

## Numéroter une release

Les deux numéros ne suivent pas le même rythme, et c'est voulu.

**`versionCode` — un compteur, pas une version.** `+1` à chaque binaire remis à qui que ce soit.
Jamais remis à zéro, jamais réutilisé, même si le `versionName` ne bouge pas. C'est le seul des deux
qu'Android regarde pour décider si une installation est une mise à jour — voir le piège n°2
ci-dessus.

**`versionName` — il suit les tranches.** C'est ce que lit l'humain : il doit dire où en est le
produit, pas où en est le build.

| `versionName` | Tranche | Ce qu'il signale |
|---|---|---|
| **`0.1.x`** | T0 | Socle, sondes, carte nue. **Aucun état de la ressource affiché** |
| `0.2.x` | T1 | Carte, fiches, les 4 avertissements. Premier moment où une release publique devient envisageable |
| `0.3.x` | T2 | Sécheresse et restrictions (VigiEau) |
| `0.4.x` | T3 | Hors-ligne, favoris, filtres |
| `1.0.0` | — | Production Play Store |

Le `0.` de tête n'est pas une coquetterie : en semver il dit « aucune promesse de stabilité », ce qui
est exactement le statut du produit. Et il fait coïncider le passage à `0.2.0` avec le moment où le
verrou de [`BR-012`](br/BR-012-acquittement-au-premier-lancement.md) se lève — les deux évènements
sont le même.

**État au 2026-08-15 :** `versionName 0.1.0`, `versionCode 1` déclaré dans `app.json`, aucune release
produite. La prochaine sera donc `v0.1.0-alpha.1`.

---

## Voie B — release par GitHub Actions

✅ **Posé le 2026-08-15 :** [`.github/workflows/release-android.yml`](../.github/workflows/release-android.yml).
🚨 **Déclenché deux fois le 2026-08-15, échoué deux fois** — par le tag `v0.1.0`, puis par un
`workflow_dispatch` sur `dev`. Même erreur les deux fois, à la **troisième étape**, avant même
`npm ci` (voir l'encadré ci-dessous). **La CI n'a encore produit aucun APK** : au-delà du *checkout*
et de `setup-node`, rien de ce qui suit n'est constaté.

L'intérêt dépasse le confort. Le *runner* `ubuntu-latest` porte un SDK Android sur un chemin sans
espace ni parenthèse, donc **toute la saga du NDK décrite au
[`guide-installation.md`](guide-installation.md#-le-piège-qui-coûte-une-nuit--le-chemin-du-sdk)
disparaît** — et le **piège n° 2 ci-dessus avec elle**, puisque le `ANDROID_HOME` du *runner* pointe
sur un SDK complet et inscriptible. Le passage par la CI est donc, sur ce projet, plus fiable que le
build local. Et `prebuild --clean` y transforme le caractère volatil d'`android/` en propriété : le
natif est reconstruit de zéro à chaque fois, donc reproductible.

> 🚨 **Constaté le 2026-08-15 : `setup-java` ne peut pas se placer avant le prebuild.**
> Son `cache: gradle` calcule sa clé de cache en cherchant des fichiers Gradle dans l'arbre de
> travail. Or `/android` est dans le `.gitignore` : au *checkout*, il n'existe pas.
>
> ```
> Error: No file in /home/runner/work/MartinPecheur/MartinPecheur matched to
> [**/*.gradle*, **/gradle-wrapper.properties, ...]
> ```
>
> L'étape est donc placée **après** `expo prebuild`, qui fait naître `android/build.gradle`,
> `android/app/build.gradle`, `android/settings.gradle` et `gradle/wrapper/gradle-wrapper.properties`.
> Rien avant elle n'a besoin d'un JDK : `npm ci`, la vérification, les garde-fous et le prebuild
> lui-même sont tous en Node. **Corrigé le 2026-08-15, pas encore éprouvé.**

**Deux déclencheurs :** un tag `v*` construit **et publie** ; un `workflow_dispatch` construit
**sans rien publier** et dépose l'APK en artefact — c'est ainsi qu'on éprouve la chaîne sans
engager de release.

> 🚨 **Constaté le 2026-08-15 : `workflow_dispatch` ne marche pas depuis une branche de feature.**
> GitHub cherche le workflow sur la **branche par défaut**, et refuse même avec `--ref` explicite :
>
> ```
> HTTP 404: workflow release-android.yml not found on the default branch
> ```
>
> **Le workflow ne peut donc pas être éprouvé avant d'être fusionné dans `dev`.** Un tag, lui,
> déclencherait bien le job depuis n'importe quel commit — mais il engagerait une release, ce que le
> verrou produit interdit tant qu'il n'est pas arbitré.

**Quatre garde-fous. Trois ne s'arment que sur un tag ; le quatrième porte sur tous les builds.**

| Garde-fou | Ce qu'il empêche |
|---|---|
| Cohérence du tag et d'`app.json` | Publier un `v0.2.0` qui rapporte `0.1.0` une fois installé |
| **`versionCode` strictement croissant** | Publier deux releases portant le même `versionCode`, qui ne s'installent pas l'une sur l'autre. Comparé à l'`app.json` du **tag précédent** — c'est pourquoi le *checkout* prend `fetch-depth: 0`. La première release, sans tag antérieur, est acceptée telle quelle |
| Présence de `docs/notes-release.md`, non vide | Publier sans note rédigée. La note porte les limites tant que `BR-012` n'est pas livré, et elle est soumise à `BR-003` et `BR-014` : elle s'écrit, elle ne se génère pas depuis les messages de commit |
| **Signature vérifiée sur l'APK produit** | Publier un binaire signé de la clé de debug publique. Le secret manquant fait échouer le job **avant** de compiler ; `apksigner verify --print-certs` reprend la vérification **après**, sur le fichier réel — un plugin qui aurait cessé de s'appliquer ou une propriété Gradle mal transmise ne se verraient nulle part ailleurs |

> ⚠️ **Contrôler le `versionName` sans le `versionCode` ne fermait que la moitié du piège n° 2.**
> Le premier est ce que lit l'humain, le second est ce que compare Android — et c'est le second qui
> est piloté à la main, donc celui qui s'oublie.

**Trois secrets de dépôt** sont nécessaires à la publication. Sans `ANDROID_KEYSTORE_BASE64`, un
tag échoue avec un message explicite ; un `workflow_dispatch` continue en signant en debug et
étiquette l'APK comme non distribuable.

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le `.jks` encodé — `base64 -w0 martinpecheur-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du magasin |
| `ANDROID_KEY_ALIAS` · `ANDROID_KEY_PASSWORD` | alias et mot de passe de la clé |

La publication passe par `gh release create`, déjà présent sur le *runner* — même commande que la
voie A, et **aucune action tierce** dans la chaîne.

**Un point reste ouvert :**

| # | Point |
|---|---|
| 1 | **Le poids.** ⚠️ **Mesuré le 2026-08-15 : 110 Mo**, parce qu'`assembleRelease` embarque les **quatre** ABI là où `expo run:android` n'en compilait qu'une. Détail : `arm64-v8a` 25,4 Mo · `armeabi-v7a` 17,9 Mo · `x86` 26,4 Mo · `x86_64` 26,1 Mo. **Les 52,5 Mo de `x86`/`x86_64` ne servent qu'à l'émulateur.** Le workflow porte la ligne à ajouter en commentaire — `-PreactNativeArchitectures=arm64-v8a` — décision non prise |

> Le **keystore** n'est plus un point ouvert côté CI : le câblage existe et est testé. Il reste à
> **générer la clé et à déposer les secrets** — voir l'annexe. Tant que ce n'est pas fait, un tag
> échoue avant de compiler, ce qui est le comportement voulu.

> Le `versionCode`, lui, **n'est plus un point ouvert** : il reste piloté à la main dans `app.json`,
> conformément à la convention ci-dessus, et le garde-fou de cohérence le donne à lire dans le
> journal du build. Le dériver du tag entrerait en conflit avec cette convention.

---

## Ce qu'on écrit dans la note de version

La note de version **est** le support des limites, tant que les avertissements de `BR-012` ne sont pas
dans l'application. Elle est soumise à
[`BR-003`](br/BR-003-jamais-qualifier-un-debit-de-suffisant.md) et
[`BR-014`](br/BR-014-aucun-verbe-d-instruction.md) au même titre qu'un écran : aucun *suffisant*,
*normal*, *sûr*, aucun verbe d'instruction sur un usage de l'eau.

Modèle :

```markdown
⚠️ Version alpha, destinée à l'essai technique. Elle n'informe pas sur l'état d'une rivière.

**Ce qu'elle fait**
- …

**Ce qu'elle ne fait pas**
- Aucun débit, aucun état d'écoulement, aucune restriction n'est affiché.
- Le mode hors ligne n'est pas disponible (ADR-012).

**Installation** — Android 7 minimum. Télécharger l'APK depuis Chrome sur le téléphone, puis
autoriser l'installation depuis cette source quand Android le demande.

Données : IGN Géoplateforme, Hub'Eau. Code sous licence MIT.
```

## Côté testeur

1. Ouvrir le lien **dans Chrome sur le téléphone** — pas depuis une messagerie, qui bloque souvent
   les `.apk`.
2. Télécharger l'APK.
3. Android affiche « Pour votre sécurité… » → **Paramètres ▸ autoriser cette source** (permission par
   application depuis Android 8).
4. Installer, revenir, ouvrir.

## Ce que ce canal ne donne pas

| Manque | Conséquence | Palliatif |
|---|---|---|
| **Aucune mise à jour automatique** | Chaque version = un nouveau lien à envoyer | La piste interne du Play Store, seule, le résout |
| **Aucun rapport de plantage** | Le testeur peut dire *que* l'app s'est fermée, jamais *pourquoi* : la pile d'un `SIGABRT` natif ne lui est pas accessible | Play Console (gratuit, symbolisé) ou `@sentry/react-native` |

> Pour l'**option D d'[`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md)** — savoir si
> `createPack` plante aussi sur un `arm64` réel — c'est suffisant : « j'appuie sur le bouton et
> l'application se ferme » répond déjà à la question posée.

---

## Annexe — passer à un keystore de projet

🔄 **Non fait au 2026-08-15.** À faire avant toute release régulière, et obligatoirement avant le
Play Store.

```bash
keytool -genkeypair -v -keystore martinpecheur-release.jks -alias martinpecheur -keyalg RSA -keysize 2048 -validity 10000
```

> 🚨 **Cette clé est irremplaçable.** La perdre interdit définitivement de mettre à jour l'application
> pour ceux qui l'ont installée. La sauvegarder hors du poste.

`*.jks` est déjà couvert par le `.gitignore` — le fichier ne doit **jamais** entrer au dépôt. Pour la
CI, le transmettre en secret GitHub encodé en base64, avec ses mots de passe :

```bash
base64 -w0 martinpecheur-release.jks
```

✅ **Le câblage Gradle, lui, est fait** (2026-08-15). Comme `android/` est régénéré par `prebuild`,
il ne pouvait pas vivre dans `android/` : il vit dans un *config plugin* Expo versionné,
[`plugins/withReleaseSigning.js`](../plugins/withReleaseSigning.js), déclaré dans `app.json`.

Le plugin réécrit `android/app/build.gradle` à chaque `prebuild` pour ajouter un
`signingConfigs.release` alimenté par quatre propriétés Gradle, et brancher le buildType `release`
dessus **dès que `MARTINPECHEUR_STORE_FILE` est fournie** :

```bash
./gradlew assembleRelease \
  -PMARTINPECHEUR_STORE_FILE=release.keystore \
  -PMARTINPECHEUR_STORE_PASSWORD=… \
  -PMARTINPECHEUR_KEY_ALIAS=… \
  -PMARTINPECHEUR_KEY_PASSWORD=…
```

Sans ces propriétés, le comportement d'origine est conservé : un build local reste possible sans
keystore, signé en debug. C'est la CI qui interdit d'en **publier** un.

> ⚠️ **Le plugin lève si le gabarit Expo change.** S'il ne retrouve pas ses ancres
> (`signingConfigs {`, `buildTypes {`, `release {`, `signingConfig signingConfigs.debug`), il fait
> échouer `prebuild` au lieu de rendre le fichier inchangé — un plugin muet réintroduirait la
> signature de debug en silence, ce qu'il existe précisément pour empêcher. Six tests couvrent ces
> cas dans [`tests/plugins/withReleaseSigning.test.ts`](../tests/plugins/withReleaseSigning.test.ts),
> sur une copie **réelle** du `build.gradle` généré le 2026-08-15.
>
> 🔄 **Non éprouvé sur un build natif** : le plugin est testé sur la transformation de texte, pas
> encore par un `prebuild` suivi d'un `assembleRelease` signé. La première release le constatera.

Il reste donc, avant de publier : générer la clé ci-dessus, et déposer les trois secrets listés à la
voie B.

## Liens

- [`guide-installation.md`](guide-installation.md) — poste de développement, et le piège du chemin du SDK
- [`project-state.md`](project-state.md) — source de vérité des statuts
- [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) — hors-ligne bloqué, option D
- `BR-003`, `BR-012`, `BR-013`, `BR-014` — ce que la note de version et la fiche ne peuvent pas dire

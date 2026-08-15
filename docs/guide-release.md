# Guide de release — livrer un APK à un testeur distant

Ce guide décrit comment produire un binaire Android **installable par quelqu'un d'autre que toi**,
et le publier en release GitHub. Il ne concerne pas le développement au quotidien — pour cela, voir
le [`guide-installation.md`](guide-installation.md).

> 🔄 **Aucune release n'a jamais été produite sur ce projet au 2026-08-15.** Tout ce qui suit est
> **écrit, pas exécuté**. Les commandes viennent de la configuration réelle du dépôt, lue le
> 2026-08-15 ; leur résultat n'est pas constaté. Sur ce projet, la nuance n'est pas cosmétique :
> [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) est né d'un chemin de code lu et
> réputé bon, qui plantait à l'exécution. **Mettre ce guide à jour au premier essai réel.**

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

**À faire avant la première release :** ajouter le champ dans `app.json`, et l'**incrémenter à chaque
release**.

```json
"android": {
  "package": "fr.martinpecheur.app",
  "versionCode": 1
}
```

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

| Conséquence | |
|---|---|
| Les mises à jour s'installent par-dessus la précédente | ✅ pas de désinstallation à demander au testeur |
| Le `debug.keystore` disparaît si `android/` est supprimé | ✅ sans effet, `prebuild` le repose à l'identique |
| **Le mot de passe est public** — ce keystore est dans tous les projets React Native du monde | 🚨 n'importe qui peut signer un faux « MartinPêcheur v0.1.1 » qui s'installera comme une mise à jour |
| Le Play Store **refuse** un binaire signé par une clé de debug | 🚨 bloquant le jour où on y va |

**Tolérable pour une alpha technique envoyée à trois personnes que tu connais. À remplacer avant
toute release régulière ou publique.** La marche à suivre est en annexe.

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

### 3. Compiler en release

```bash
cd android && ./gradlew assembleRelease
```

En PowerShell, `.\gradlew.bat assembleRelease`.

L'APK sort dans `android/app/build/outputs/apk/release/app-release.apk`.

### 4. Publier la release

```bash
gh release create v0.1.0-alpha.1 android/app/build/outputs/apk/release/app-release.apk --prerelease --title "v0.1.0-alpha.1 — sonde hors-ligne" --notes-file docs/notes-release.md
```

**Convention de tag :** `vMAJEUR.MINEUR.CORRECTIF[-alpha.N]`, aligné sur le `version` d'`app.json`.
Toujours `--prerelease` tant que le verrou produit ci-dessus n'est pas levé.

---

## Voie B — release par GitHub Actions

🔄 **Cible, non implémentée au 2026-08-15.** Le dépôt n'a aucun workflow.

L'intérêt dépasse le confort : le *runner* `ubuntu-latest` porte un SDK Android sur un chemin sans
espace ni parenthèse, donc **toute la saga du NDK décrite au
[`guide-installation.md`](guide-installation.md#-le-piège-qui-coûte-une-nuit--le-chemin-du-sdk)
disparaît**. Et `prebuild --clean` en CI transforme le caractère volatil d'`android/` en propriété :
le natif est reconstruit de zéro à chaque fois, donc reproductible.

Contenu attendu de `.github/workflows/release-android.yml`, déclenché par un tag `v*` :

```yaml
name: Release Android
on:
  push:
    tags: ["v*"]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - run: npm ci
      - run: npm run verify
      - run: npx expo prebuild --platform android --clean
      - run: ./gradlew assembleRelease
        working-directory: android
      - uses: softprops/action-gh-release@v2
        with:
          prerelease: true
          files: android/app/build/outputs/apk/release/app-release.apk
```

**Trois points à trancher avant de le poser :**

| # | Point |
|---|---|
| 1 | **Le keystore.** En l'état, la CI signera avec la clé de debug publique. Voir l'annexe pour le keystore de projet en secret GitHub |
| 2 | **Le `versionCode`.** Il faut l'incrémenter à chaque tag — soit à la main dans `app.json`, soit dérivé du tag par une étape du workflow |
| 3 | **Le poids.** Restreindre l'ABI à `arm64-v8a` réduit nettement l'APK et couvre tous les téléphones réels visés. Les 58 Mo du build de développement ne sont pas une fatalité |

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

Reste à câbler `signingConfigs.release` dans Gradle. Comme `android/` est régénéré par `prebuild`,
**ce câblage ne peut pas vivre dans `android/`** : il doit passer par un *config plugin* Expo
versionné, ou par un `--gradle-property` fourni au moment du build. C'est le point ouvert de cette
annexe, et il est à trancher avant la voie B.

## Liens

- [`guide-installation.md`](guide-installation.md) — poste de développement, et le piège du chemin du SDK
- [`project-state.md`](project-state.md) — source de vérité des statuts
- [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md) — hors-ligne bloqué, option D
- `BR-003`, `BR-012`, `BR-013`, `BR-014` — ce que la note de version et la fiche ne peuvent pas dire

# Guide d'installation — poste de développement

Ce guide sort du [`README`](../README.md) pour ne pas l'encombrer. Il ne concerne que le fait de
**voir l'application à l'écran**. Les tests, le typecheck et le lint ne demandent rien de plus que
Node : `npm install && npm run verify` suffit.

## Prérequis

| Pour | Outil | Version constatée |
|---|---|---|
| Compiler, tester, linter | **Node.js** LTS et npm | Node `24.18.1`, npm `11.16.0` — 2026-08-01 |
| Lancer sur Android | **Android Studio** + **JDK 17** | Studio `2026.1.3.7`, JDK `17.0.20.8` — 2026-08-01 |
| Lancer sur iOS | **macOS** avec Xcode | ⚠️ impossible depuis Windows ou Linux |

## 🚨 Le piège qui coûte une nuit : le chemin du SDK

> **Installez le SDK Android sur un chemin sans espace ni parenthèse.**

Le NDK ne les supporte pas. Sous `C:\Program Files (x86)\…`, Windows réduit le chemin en notation
8.3 et `clang++.exe` devient `CLANG_~1.EXE`. Or **clang choisit son mode C ou C++ d'après son propre
nom d'exécutable** : privé de ses `++`, il compile en C et ne lie pas la bibliothèque standard.

Le symptôme ne désigne jamais la cause :

```
ld.lld: error: undefined symbol: operator new(unsigned long)
ld.lld: error: undefined symbol: operator delete(void*)
```

**Ne réutilisez pas un SDK hérité des workloads .NET Android de Visual Studio** : il vit sous
`Program Files (x86)`, et il n'est pas inscriptible sans élévation — Gradle ne pourra pas y
installer les composants qui lui manquent. Constaté le 2026-08-15, trois obstacles en cascade avant
d'identifier la cause. Emplacement recommandé : `%LOCALAPPDATA%\Android\Sdk`.

## Installation sous Windows

```bash
winget install --exact --id Microsoft.OpenJDK.17 --accept-package-agreements
```

```bash
winget install --exact --id Google.AndroidStudio --accept-package-agreements
```

> ⚠️ **Pas les deux en même temps** : Windows n'accepte qu'un installateur MSI à la fois, le second
> échoue en code **1618**.
>
> ⚠️ `sdkmanager` en ligne de commande **échoue en silence** s'il ne peut pas écrire : il n'affiche
> que `Failed to read or create install properties file`, ne renvoie aucun code d'erreur, et
> n'installe rien. Passez par l'assistant graphique, qui gère l'élévation.

### Compléter le SDK

winget n'installe que l'IDE. Ouvrez Android Studio une fois et laissez l'assistant télécharger le
SDK — plusieurs Go.

> ⚠️ **L'installation « Standard » ne suffit pas.** Elle pose la plateforme la plus récente
> (`android-37`), **aucune image système** — donc aucun émulateur ne démarre — et pas les
> *Command-line Tools*.

Expo SDK 57 veut l'**API 36**. Vérifié à la source, pas d'après la documentation
(`node_modules/expo-modules-core/android/ExpoModulesCorePlugin.gradle`) :

```gradle
compileSdkVersion project.ext.safeExtGet("compileSdkVersion", 36)
minSdkVersion     project.ext.safeExtGet("minSdkVersion", 24)
targetSdkVersion  project.ext.safeExtGet("targetSdkVersion", 36)
```

Complétez par **More Actions ▸ SDK Manager**, avec *Show Package Details* :

| Onglet | À cocher |
|---|---|
| **SDK Platforms** → *Android 16 (Baklava) — API 36* | **Android SDK Platform 36** · une **image système x86_64** |
| **SDK Tools** | **NDK** · **Android SDK Build-Tools** · **Command-line Tools (latest)** |

Puis créez un appareil virtuel : **More Actions ▸ Virtual Device Manager ▸ Create Device**.

### Déclarer le SDK

```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
```

> ⚠️ **Rouvrez le terminal après cette commande.** Un terminal déjà ouvert garde l'ancien
> environnement, et l'erreur *« Failed to resolve the Android SDK path »* persistera pour cette
> seule raison.

```bash
npm run android
```

## Le piège du JDK

**JDK 17, pas plus récent** — la documentation React Native est explicite : *« you may encounter
problems using higher JDK versions »*.

Or **Android Studio embarque son propre runtime Java**, et ce n'en est pas un : le JBR livré avec
Studio `2026.1.3.7` est un **openjdk 25.0.2**, précisément la version déconseillée, et c'est celle
que Gradle prend par défaut. Le JDK 17 séparé n'est donc pas redondant.

Si un build Gradle échoue bizarrement : *Settings ▸ Build, Execution, Deployment ▸ Build Tools ▸
Gradle ▸ Gradle JDK*, à pointer sur `C:\Program Files\Microsoft\jdk-17…`, pas sur le JBR embarqué.

## Ce qu'on peut exécuter, et où

| | Windows | Linux | macOS |
|---|:---:|:---:|:---:|
| `domain/`, `data/`, `application/` | ✅ | ✅ | ✅ |
| `typecheck`, `lint`, `test` | ✅ | ✅ | ✅ |
| Outillage percentiles | ✅ | ✅ | ✅ |
| Lancer sur **Android** | ✅ | ✅ | ✅ |
| Lancer ou livrer sur **iOS** | ❌ | ❌ | ✅ |

**Sur Windows, tout sauf iOS.** Les trois couches internes sont du TypeScript pur testé sous Node :
ni émulateur, ni téléphone, ni carte. C'est délibéré, et vérifié par un test d'architecture.

> ⚠️ **Windows n'est pas une cible du produit** — ajouté puis retiré le 2026-07-31
> ([`ADR-009`](adr/ADR-009-cible-windows.md) → [`ADR-010`](adr/ADR-010-react-native.md)).
> Machine de développement valable, pas plateforme de livraison.
>
> ⚠️ **Expo Go ne suffit plus** depuis l'ajout de MapLibre : l'application embarque du code natif
> et exige un *development build* (`npx expo prebuild` puis `npx expo run:android`).

## Travailler sous VS Code

L'espace de travail est préconfiguré dans [`.vscode/`](../.vscode/), versionné parce que c'est de la
config d'équipe. Au premier démarrage, dans cet ordre :

1. `code .` à la racine — **ouvrir le dossier, pas un fichier** : sans cela, ni les tâches, ni le
   débogueur, ni les chemins `@domain/*` ne fonctionnent.
2. Accepter la bannière **« Cet espace de travail recommande des extensions »**.
3. Ouvrir un `.ts` et accepter **« Utiliser la version TypeScript de l'espace de travail »**.
   Sinon : `Ctrl+Shift+P` ▸ *TypeScript: Select TypeScript Version…* ▸ **Use Workspace Version**.

| Extension | Rôle |
|---|---|
| `dbaeumer.vscode-eslint` | Lint en direct, dont les règles de frontière entre couches |
| `expo.vscode-expo-tools` | Complétion et validation d'`app.json` |
| `msjsdiag.vscode-react-native` | Débogage React Native, gestion de Metro |
| `Orta.vscode-jest` | Tests dans l'explorateur |

Câblé d'office : **`Ctrl+Shift+B`** lance `verify` · **`F5`** débogue les tests unitaires, sans
appareil ni émulateur · l'éditeur utilise le TypeScript du projet, pas celui de VS Code — sans quoi
l'éditeur et `npm run typecheck` peuvent diverger, et c'est toujours l'éditeur qu'on croit.

> ℹ️ Les extensions C# / .NET sont marquées non souhaitées : plus une ligne de C# dans ce dépôt
> depuis le 2026-07-31.

## Git en SSH

Si `git push` échoue sur `Permission denied (publickey)` alors que votre clé est valide, c'est
probablement son **nom** : `ssh` ne teste par défaut que `id_rsa`, `id_ecdsa` et `id_ed25519`.
Déclarez-la dans `~/.ssh/config` :

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/<votre-cle>
    IdentitiesOnly yes
```

# Guide d'installation — poste de développement

Ce guide sort du [`README`](../README.md) pour ne pas l'encombrer. Il ne concerne que le fait de
**voir l'application à l'écran**. `flutter analyze` et `flutter test` ne demandent rien de plus que
le SDK Flutter sur le poste.

## Prérequis

| Pour | Outil | Version constatée |
|---|---|---|
| Compiler, tester, lancer sur Windows | **Flutter** stable, **Dart** (fourni avec Flutter) | Flutter `3.47.4`, Dart `3.13.3` — `flutter --version`, 2026-09-13 |
| Lancer sur Android | **Android Studio** + JDK + SDK (API 36) + NDK | JDK `17.0.20.8`, SDK `36.0.0`, NDK `28.2.13676358` — constatés le 2026-09-18 |
| Lancer ou livrer sur iOS | **macOS** avec Xcode | ⚠️ impossible depuis Windows ou Linux — jamais compilé sur ce projet |

> ⚠️ **Flutter est hors `PATH` sur ce poste** : appeler le binaire par chemin absolu,
> `C:\Users\oliver254\develop\flutter\bin\flutter.bat`. `pubspec.yaml` exige `^3.13.3`.

## 🚨 Le piège qui coûte une nuit : le chemin du SDK Android

> **Installez le SDK Android sur un chemin sans espace ni parenthèse.**

Le NDK ne les supporte pas. Sous `C:\Program Files (x86)\…`, Windows réduit le chemin en notation
8.3 et `clang++.exe` devient `CLANG_~1.EXE`. Or **clang choisit son mode C ou C++ d'après son propre
nom d'exécutable** : privé de ses `++`, il compile en C et ne lie pas la bibliothèque standard —
symptôme qui touche tout autant une compilation Flutter/NDK qu'un outillage antérieur.

Le symptôme ne désigne jamais la cause :

```
ld.lld: error: undefined symbol: operator new(unsigned long)
ld.lld: error: undefined symbol: operator delete(void*)
```

**Ne réutilisez pas un SDK hérité d'un autre outillage** (par exemple les workloads .NET Android de
Visual Studio) : il vit sous `Program Files (x86)`, et il n'est pas inscriptible sans élévation —
Gradle ne pourra pas y installer les composants qui lui manquent. Constaté le 2026-08-15, trois
obstacles en cascade avant d'identifier la cause. Emplacement recommandé, sans espace et
inscriptible sans élévation : `%LOCALAPPDATA%\Android\Sdk`.

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

> ⚠️ **L'installation « Standard » ne suffit pas.** Elle pose la plateforme la plus récente,
> **aucune image système** — donc aucun émulateur ne démarre — et pas les *Command-line Tools*.

Flutter 3.47.4 exige le NDK `28.2.13676358` (lu dans `FlutterExtension.kt` du SDK Flutter installé,
constaté le 2026-09-18 — ne pas se fier à la documentation seule, cette version change d'une
release Flutter à l'autre). Complétez par **More Actions ▸ SDK Manager**, avec *Show Package
Details* :

| Onglet | À cocher |
|---|---|
| **SDK Platforms** → *Android 16 (Baklava) — API 36* | **Android SDK Platform 36** · une **image système x86_64** |
| **SDK Tools** | **NDK** (version exigée par Flutter, ci-dessus) · **Android SDK Build-Tools** · **Command-line Tools (latest)** |

Puis créez un appareil virtuel : **More Actions ▸ Virtual Device Manager ▸ Create Device**.

### Déclarer le SDK

```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
```

> ⚠️ **Rouvrez le terminal après cette commande.** Un terminal déjà ouvert garde l'ancien
> environnement, et l'erreur *« Failed to resolve the Android SDK path »* persistera pour cette
> seule raison.
>
> ⚠️ **Sonder le registre (`HKCU\Environment`), pas l'environnement du processus courant** : un
> inventaire a déjà déclaré l'outillage Android absent alors qu'il ne l'était pas — la variable
> existait, seul le processus qui inventoriait ne l'avait pas rechargée.

```bash
flutter run -d emulator-5554
```

## Ce qu'on peut exécuter, et où

| | Windows | Linux | macOS |
|---|:---:|:---:|:---:|
| `lib/domain/`, `lib/data/`, `flutter analyze`, `flutter test` | ✅ | 🔄 non constaté | 🔄 non constaté |
| `flutter run -d windows` / `flutter build windows` | ✅ construite et lancée hors Flutter (`0.1.0`, `F3`) | — | — |
| Lancer sur **Android** | — | — | — |
| ↳ chaîne d'outils vue par `flutter doctor`, gabarit généré, émulateur démarré | ✅ (2026-09-18) | 🔄 non constaté | 🔄 non constaté |
| ↳ construction et lancement réels sur l'émulateur | 🔄 **jamais constaté** — `flutter run -d emulator-5554` reste à exécuter | — | — |
| Lancer ou livrer sur **iOS** | ❌ | ❌ | 🔄 configuré, jamais compilé (aucun hôte macOS) |

**Le bac à sable ne compile pas de natif** : `flutter run`, `flutter build` (Windows ou Android)
sont exécutés **par le commanditaire**, jamais par l'agent. `flutter analyze`, `flutter test` et
`dart format` sont, eux, lancés directement.

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

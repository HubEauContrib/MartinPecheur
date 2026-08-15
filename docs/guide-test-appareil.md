# Tester sur un Android réel — `M4` et `M5`

**Écrit le 2026-08-15.** Deux tâches de T0 attendent un appareil physique. Elles se font en une
seule session, sur le même téléphone, en une vingtaine de minutes.

> ⚠️ **`S5` n'est pas de la partie.** Le choix de bibliothèque SQLite demande un banc de mesure qui
> **n'existe pas encore** — aucun code SQLite n'est écrit. Le téléphone ne le débloque pas
> aujourd'hui.

| Tâche | Ce qu'elle tranche | Pourquoi l'émulateur ne suffit pas |
|---|---|---|
| **`M4`** | Le plantage de `OfflineManager.createPack` est-il celui de la bibliothèque, ou celui de l'émulateur ? | Le constat du 2026-08-15 ne porte que sur `x86_64`. L'écart entre les deux réponses est celui entre « le hors-ligne fonctionne » et « le lot est à réécrire » ([`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md)) |
| **`M5`** | Les 4 150 marqueurs tiennent-ils sur un Android d'entrée de gamme ? (`NV-5`) | Un émulateur tourne sur le GPU du poste de travail. Il ne dit rien de la tenue réelle |

---

## 0. Préparer l'appareil

Sur le téléphone : **Réglages → À propos** → sept appuis sur **« Numéro de build »**, puis
**Système → Options pour les développeurs → Débogage USB**.

Branche le câble, choisis **« Transfert de fichiers »**, et accepte la fenêtre **« Autoriser le
débogage USB ? »** en cochant **« Toujours autoriser »**. Sans cela `adb` verra l'appareil en
`unauthorized`.

```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices -l
```

Le téléphone doit apparaître en statut `device`. S'il n'apparaît pas du tout, c'est le pilote USB
du constructeur qui manque côté Windows.

> **Sans câble :** *Options pour les développeurs → Débogage sans fil → Associer l'appareil à l'aide
> d'un code*, puis `adb pair IP:PORT` et `adb connect IP:AUTRE_PORT`. ⚠️ Les deux ports sont
> **différents** — celui de l'association n'est pas celui de la connexion.

## 1. Installer

L'APK cible déjà les quatre ABI (`armeabi-v7a, arm64-v8a, x86, x86_64`) : rien à changer.
L'émulateur étant probablement encore lancé, précise la cible :

```bash
npx expo run:android --device
```

Expo propose la liste : choisis le téléphone. Il compile, installe et branche Metro par USB.

---

## 2. `M4` — le plantage se reproduit-il sur `arm64` ?

**Vide le journal d'abord**, sinon le bruit de l'émulateur s'y mélange :

```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" logcat -c
```

Dans l'application, appuie sur le **bouton rouge** — « Reproduire le plantage MapLibre (M4) ».
Attends une trentaine de secondes, puis relève :

```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" logcat -d > m4-telephone.txt
```

### Lire le résultat

| Ce que tu observes | Ce que ça veut dire |
|---|---|
| L'application **disparaît**, et `m4-telephone.txt` contient `regex_error` | Le défaut est **réel sur `arm64`**. `ADR-012` garde ses options A, B, C, et on a de quoi remonter un bug amont solide |
| L'application **reste**, la ligne `tuiles=` **monte** | **Le problème était l'émulateur.** `M4` reprend là où elle s'est arrêtée : `NV-1`, `NV-3` et `NV-4` se mesurent enfin |
| L'application **reste**, `tuiles=0` **ne bouge pas** | Le hors-ligne raster échoue pour une autre cause — mais avec un chemin vivant à instrumenter |

⚠️ **Ne conclus pas sur l'écran seul.** « L'application s'est fermée » est une impression ; c'est la
ligne du journal qui est la preuve. Pour la retrouver d'un coup :

```bash
grep -aE "regex_error|SIGABRT|M4 |has died" m4-telephone.txt
```

> **Même dans le cas favorable, le hors-ligne n'est pas livrable pour autant.** Il restera à fournir
> le style IGN sous forme d'**URL** : `mapStyle` n'accepte pas un style en mémoire, et le projet
> n'embarque aucun module de système de fichiers.

---

## 3. `M5` — les 4 150 marqueurs tiennent-ils ?

⚠️ **À faire avant `M4` si tu ne veux pas relancer l'application** — `M4` la tue.

Sur la carte, **écarte les doigts pour dézoomer** jusqu'à voir la France entière, puis fais glisser
la carte pendant une dizaine de secondes, franchement, sans t'arrêter. C'est le déplacement qui
sollicite le clustering, pas l'immobilité.

Puis relève les chiffres — **pas une impression** :

```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" shell dumpsys gfxinfo fr.martinpecheur.app
```

### Seuil, fixé avant de mesurer

Le plan T0 retient **30 images par seconde** comme seuil d'alerte, soit **33 ms par image**.

| Ligne de `gfxinfo` | Lecture |
|---|---|
| `90th percentile` | **> 33 ms → sous le seuil.** C'est la ligne qui compte : elle décrit les à-coups, que la moyenne masque |
| `Janky frames` | Le pourcentage d'images en retard. Au-delà de ~20 %, le déplacement se sent |
| `Number Missed Vsync` | Confirme les décrochages francs |

Note aussi le **modèle du téléphone et son année** : « ça tient » n'a pas le même sens sur un
appareil de l'année et sur un modèle d'entrée de gamme de cinq ans, et `NV-5` porte précisément sur
le second.

---

## 4. Ce qu'il faut rapporter

Trois choses, et rien de plus :

1. **Modèle et version d'Android** du téléphone.
2. Le fichier `m4-telephone.txt`, ou au minimum la sortie du `grep` ci-dessus.
3. Les lignes `90th percentile`, `Janky frames` et `Number Missed Vsync` de `gfxinfo`.

Avec ça, `ADR-012` se tranche et `NV-5` se lève.

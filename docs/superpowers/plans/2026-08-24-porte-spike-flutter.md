# Porte de spike Flutter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Constater par exécution, sur un projet jetable, que Flutter + `flutter_map` affichent le fond IGN sur Android **et** Windows, tiennent 4 150 marqueurs clusterisés, et produisent un exécutable Windows — avant qu'une seule ligne du socle applicatif soit réécrite.

**Architecture:** Un projet Flutter jetable sous `spike/porte_flutter/`, entièrement séparé du code de production. Trois épreuves (`F1`, `F2`, `F3`) accessibles depuis un menu. La logique testable — gabarit d'URL, lecture de l'asset, calcul de percentiles — vit dans des fichiers Dart purs avec leurs tests ; les écrans ne font que l'afficher.

**Tech Stack:** Flutter (canal `stable`), Dart, `flutter_map` 8.3.1, `latlong2`, `flutter_map_marker_cluster` 8.2.2. Mesure de fluidité par `SchedulerBinding.addTimingsCallback` — **pas** par `dumpsys gfxinfo`, qui a échoué en `M5`.

**Spec :** [`2026-08-24-bascule-flutter-trois-cibles-design.md`](../specs/2026-08-24-bascule-flutter-trois-cibles-design.md)

---

## Deux contraintes d'exécution, à lire avant de commencer

> 🚨 **L'agent ne peut pas compiler du natif.** Le bac à sable ferme les sockets `AF_UNIX`, donc
> `Selector.open()` échoue et Gradle ne démarre pas. **Toute étape marquée 🖥️ se lance depuis un
> terminal utilisateur**, et son résultat est rapporté à l'agent. L'agent écrit le code et les
> tests ; l'utilisateur lance les builds et regarde l'écran.

> ⚠️ **Le plan T0 précédent s'est trompé neuf fois sur l'API MapLibre v11** parce qu'il décrivait la
> v10 de mémoire. Le code Dart ci-dessous est écrit à partir des signatures relevées sur
> `pub.dev/documentation` le 2026-08-24, **sauf celle de `flutter_map_marker_cluster`**, qui porte
> sa propre étape de vérification (tâche 9, étape 1). Devant tout écart : **le paquet installé a
> raison, ce plan a tort.**

---

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `spike/porte_flutter/lib/ign_tile_template.dart` | Le gabarit d'URL WMTS IGN et ses constantes. **Dart pur**, aucune importation de Flutter |
| `spike/porte_flutter/lib/stations_asset.dart` | Lecture du GeoJSON des stations → liste de points. **Dart pur** |
| `spike/porte_flutter/lib/frame_stats.dart` | Percentiles et compte de trames en retard. **Dart pur** |
| `spike/porte_flutter/lib/frame_recorder.dart` | Branchement sur `SchedulerBinding`, accumulation des `FrameTiming` |
| `spike/porte_flutter/lib/f1_fond_ign.dart` | Écran `F1` — fond IGN seul |
| `spike/porte_flutter/lib/f2_marqueurs.dart` | Écran `F2` — 4 150 marqueurs clusterisés + relevé à l'écran |
| `spike/porte_flutter/lib/main.dart` | Menu des trois épreuves |
| `spike/porte_flutter/test/*.dart` | Les tests des trois fichiers Dart purs |
| `spike/porte_flutter/assets/stations.json` | Copie de l'asset de production |
| `docs/superpowers/specs/2026-08-24-porte-spike-resultat.md` | Le compte rendu, écrit à la fin |

**Pourquoi ce découpage :** les trois fichiers « purs » se testent sous `flutter test` sans rendu,
en quelques millisecondes. Les écrans n'ont plus de logique à tester — ils ne portent que ce qui se
constate à l'œil, et c'est précisément ce qui ne se teste pas automatiquement.

---

## Lot 0 — Prérequis du poste

### Task 1: Installer le SDK Flutter

**Fichiers :** aucun — installation sur le poste.

Sondé le 2026-08-24 : `where.exe flutter` et `where.exe dart` ne renvoient rien. **Flutter est absent.**

- [ ] **Step 1: 🖥️ Cloner le SDK dans un chemin sans espaces**

`%LOCALAPPDATA%` vaut `C:\Users\oliver254\AppData\Local` — aucun espace, ce qui évite la panne de
chemin 8.3 déjà rencontrée sur ce poste avec le NDK.

```powershell
git clone https://github.com/flutter/flutter.git -b stable "$env:LOCALAPPDATA\flutter"
```

Attendu : clone terminé, `C:\Users\oliver254\AppData\Local\flutter\bin\flutter.bat` existe.

- [ ] **Step 2: 🖥️ Ajouter Flutter au PATH utilisateur**

```powershell
$p = [Environment]::GetEnvironmentVariable('Path','User')
[Environment]::SetEnvironmentVariable('Path', "$p;$env:LOCALAPPDATA\flutter\bin", 'User')
```

Attendu : aucune sortie. **Ouvrir un nouveau terminal** pour que le PATH soit pris.

- [ ] **Step 3: 🖥️ Vérifier la version**

```powershell
flutter --version
```

Attendu : une ligne `Flutter 3.x.x • channel stable`, puis `Dart 3.x.x`. Si la commande n'est pas
trouvée, le terminal n'a pas été rouvert.

- [ ] **Step 4: 🖥️ Lancer le diagnostic et accepter les licences Android**

```powershell
flutter doctor -v
```

Attendu : `[√] Android toolchain` (le SDK est déjà en place, `ANDROID_HOME` est défini).
`[X] Visual Studio` est **normal à ce stade** — c'est l'objet de la tâche 2.
Si les licences Android sont signalées manquantes :

```powershell
flutter doctor --android-licenses
```

- [ ] **Step 5: Rapporter la sortie de `flutter doctor -v` à l'agent**

Elle sert de ligne de base : toute erreur de build ultérieure se lit contre elle.

---

### Task 2: Ajouter la charge C++ à Visual Studio

**Fichiers :** aucun — installation sur le poste.

Sondé le 2026-08-24 : `vswhere -requires Microsoft.VisualStudio.Workload.NativeDesktop` ne renvoie
**aucune** installation, alors que « Visual Studio Professional 2026 » est présent. **`flutter build
windows` ne peut pas fonctionner sans cette charge.**

> ⏱️ **Plusieurs gigaoctets à télécharger.** À lancer maintenant : les tâches 3 à 9 n'en dépendent
> pas et peuvent avancer pendant l'installation. Seules les tâches 6 et 10 l'exigent.

- [ ] **Step 1: 🖥️ Relever le chemin d'installation**

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -all -products * -format value -property installationPath
```

Attendu : un chemin, par exemple `C:\Program Files\Microsoft Visual Studio\2026\Professional`.

- [ ] **Step 2: 🖥️ Ajouter la charge « Développement Desktop en C++ »**

Remplacer `<CHEMIN>` par la valeur de l'étape 1.

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "<CHEMIN>" --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --passive --norestart
```

Attendu : l'installateur s'ouvre en mode discret et progresse. **Cette commande rend la main avant
la fin** — l'installation continue en arrière-plan.

- [ ] **Step 3: 🖥️ Vérifier que la charge est bien posée**

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -all -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -format value -property displayName
```

Attendu : `Visual Studio Professional 2026`. **Une sortie vide signifie que l'installation n'est pas
terminée** — attendre et refaire.

- [ ] **Step 4: 🖥️ Confirmer par Flutter**

```powershell
flutter doctor -v
```

Attendu : `[√] Visual Studio - develop Windows apps`.

---

## Lot 1 — Le bac à sable

### Task 3: Créer le projet jetable et ses dépendances

**Fichiers :**
- Créer : `spike/porte_flutter/` (généré)
- Modifier : `.gitignore`

- [ ] **Step 1: 🖥️ Générer le projet**

iOS est absent des cibles : le poste n'a pas d'hôte macOS, et déclarer une cible qu'on ne peut pas
construire afficherait un support non vérifié.

```powershell
flutter create --platforms=android,windows --org fr.martinpecheur --project-name porte_flutter spike/porte_flutter
```

Attendu : `All done!` et l'arborescence `spike/porte_flutter/{lib,test,android,windows,pubspec.yaml}`.

- [ ] **Step 2: 🖥️ Ajouter les trois paquets**

```powershell
cd spike/porte_flutter
flutter pub add flutter_map latlong2 flutter_map_marker_cluster
```

Attendu : `Changed 3 dependencies!`

- [ ] **Step 3: 🖥️ Vérifier les versions réellement résolues**

C'est la leçon de l'option E d'`ADR-012` : on vérifie ce qui est lié, on ne le suppose pas.

```powershell
flutter pub deps --style=compact | Select-String -Pattern "flutter_map|latlong2|marker_cluster"
```

Attendu : `flutter_map 8.x.x`, `flutter_map_marker_cluster 8.2.x`, `latlong2 0.9.x`.
🚨 **Si `flutter_map` résout en 7.x ou moins, s'arrêter** : `flutter_map_marker_cluster` aurait tiré
la version vers le bas, et tout le raisonnement de la spec porte sur la 8.x.

- [ ] **Step 4: Ignorer les artefacts de build du spike**

Ajouter à la fin de `.gitignore` :

```gitignore

# Spike Flutter — jetable, artefacts non versionnés
spike/porte_flutter/build/
spike/porte_flutter/.dart_tool/
spike/porte_flutter/android/.gradle/
spike/porte_flutter/assets/stations.json
```

`stations.json` est ignoré parce que c'est une **copie** de `assets/referentiel/stations.json`, déjà
versionné à la racine : 6,6 Mo en double au dépôt n'apporteraient rien.

- [ ] **Step 5: Commit**

```bash
git add .gitignore spike/porte_flutter
git commit -m "chore(map): projet Flutter jetable pour la porte de spike"
```

---

## Lot 2 — F1 : le fond IGN

### Task 4: Le gabarit d'URL WMTS IGN

**Fichiers :**
- Créer : `spike/porte_flutter/lib/ign_tile_template.dart`
- Test : `spike/porte_flutter/test/ign_tile_template_test.dart`

- [ ] **Step 1: Écrire le test qui échoue**

Le test porte sur le piège documenté dans la version TypeScript : **l'ordre des trois marqueurs
compte**. Intervertir `TILECOL` et `TILEROW` produit une carte qui s'affiche mais transposée — une
panne silencieuse.

Créer `spike/porte_flutter/test/ign_tile_template_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:porte_flutter/ign_tile_template.dart';

void main() {
  group('gabarit WMTS IGN', () {
    test('associe chaque marqueur au bon parametre WMTS', () {
      expect(ignTileUrlTemplate, contains('TILEMATRIX={z}'));
      expect(ignTileUrlTemplate, contains('TILECOL={x}'));
      expect(ignTileUrlTemplate, contains('TILEROW={y}'));
    });

    test('vise la couche et le jeu de tuiles verifies le 2026-08-15', () {
      expect(ignTileUrlTemplate, contains('LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2'));
      expect(ignTileUrlTemplate, contains('TILEMATRIXSET=PM'));
      expect(ignTileUrlTemplate, contains('FORMAT=image/png'));
    });

    test('est une URL KVP, donc porte un ? et des &', () {
      expect(ignTileUrlTemplate, startsWith('https://data.geopf.fr/wmts?'));
      expect(ignTileUrlTemplate.split('&').length, greaterThan(5));
    });

    test('declare la taille de tuile constatee', () {
      expect(ignTileDimension, 256);
    });

    test('porte l attribution obligatoire en Licence Ouverte', () {
      expect(ignAttribution, contains('IGN'));
      expect(ignAttribution, contains('Licence Ouverte'));
    });
  });
}
```

- [ ] **Step 2: 🖥️ Lancer le test pour vérifier qu'il échoue**

```powershell
flutter test test/ign_tile_template_test.dart
```

Attendu : **ÉCHEC** à la compilation — `Error: Couldn't resolve the package 'porte_flutter'` ou
`Undefined name 'ignTileUrlTemplate'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `spike/porte_flutter/lib/ign_tile_template.dart` :

```dart
/// Fond cartographique IGN Géoplateforme, en WMTS KVP.
///
/// Vérifié par appel réel le 2026-07-31, revérifié le 2026-08-15 : HTTP 200,
/// `image/png`, 256×256 sur `TILEMATRIXSET=PM`. `PM` est du Pseudo-Mercator,
/// le seul jeu de tuiles adressable en `{z}/{x}/{y}`.
///
/// Dart pur : aucune importation de Flutter, donc testable sans rendu.
library;

/// Les trois marqueurs sont associés à leur paramètre WMTS et **cet ordre
/// compte** : intervertir `TILECOL` et `TILEROW` produit une carte qui
/// s'affiche, mais transposée. C'est une panne silencieuse.
const String ignTileUrlTemplate =
    'https://data.geopf.fr/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile'
    '&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal&TILEMATRIXSET=PM'
    '&FORMAT=image/png&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

/// Taille constatée de la tuile IGN. Une valeur erronée décale tout le fond.
const int ignTileDimension = 256;

/// Obligatoire en Licence Ouverte Etalab, et due même sur un spike.
const String ignAttribution = '© IGN Géoplateforme — Licence Ouverte';
```

- [ ] **Step 4: 🖥️ Lancer le test pour vérifier qu'il passe**

```powershell
flutter test test/ign_tile_template_test.dart
```

Attendu : `All tests passed!` — 5 tests.

- [ ] **Step 5: Commit**

```bash
git add spike/porte_flutter/lib/ign_tile_template.dart spike/porte_flutter/test/ign_tile_template_test.dart
git commit -m "test(map): gabarit WMTS IGN en Dart pur, ordre des marqueurs verrouille"
```

---

### Task 5: L'écran F1 et le constat sur Android

**Fichiers :**
- Créer : `spike/porte_flutter/lib/f1_fond_ign.dart`
- Modifier : `spike/porte_flutter/lib/main.dart` (remplacement complet)

- [ ] **Step 1: Écrire l'écran**

Créer `spike/porte_flutter/lib/f1_fond_ign.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'ign_tile_template.dart';

/// F1 — le fond IGN seul. Aucun marqueur, aucune couche : si rien ne
/// s'affiche, la cause est le gabarit ou le réseau, rien d'autre.
class F1FondIgn extends StatelessWidget {
  const F1FondIgn({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F1 — fond IGN')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              // Bordeaux — une zone où le fond IGN est dense et reconnaissable.
              initialCenter: const LatLng(44.8378, -0.5792),
              initialZoom: 9,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: ignTileUrlTemplate,
                tileDimension: ignTileDimension,
                maxNativeZoom: 18,
                userAgentPackageName: 'fr.martinpecheur.spike',
              ),
            ],
          ),
          // Attribution posée à la main : un simple Text suffit à la Licence
          // Ouverte, et évite de parier sur l'API d'attribution de flutter_map.
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: const Text(ignAttribution, style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Écrire le menu**

Remplacer **tout** le contenu de `spike/porte_flutter/lib/main.dart` :

```dart
import 'package:flutter/material.dart';

import 'f1_fond_ign.dart';

void main() => runApp(const PorteApp());

class PorteApp extends StatelessWidget {
  const PorteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Porte de spike Flutter',
      home: const MenuEpreuves(),
    );
  }
}

class MenuEpreuves extends StatelessWidget {
  const MenuEpreuves({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porte de spike')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('F1 — fond IGN'),
            subtitle: const Text('Le WMTS raster s affiche-t-il ?'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const F1FondIgn()),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 🖥️ Déclarer la permission réseau sur Android**

Sans elle, l'application se lance et le fond reste gris — panne silencieuse classique.

Ajouter dans `spike/porte_flutter/android/app/src/main/AndroidManifest.xml`, **avant** la balise
`<application>` :

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 4: 🖥️ Démarrer l'émulateur et lancer**

L'AVD `Pixel_7` est présent sur le poste et démarrait en 38 s le 2026-08-24.

```powershell
flutter emulators --launch Pixel_7
flutter run -d emulator-5554
```

Attendu : l'application démarre, le menu s'affiche, et `F1` montre **le plan IGN de Bordeaux**.

- [ ] **Step 5: 🖥️ Constater, et distinguer les trois issues**

| Ce qu'on voit | Ce que ça veut dire |
|---|---|
| Le plan IGN, lisible | ✅ **`NV-F1` levé sur Android.** `flutter_map` expanse `{z}`/`{x}`/`{y}` dans une chaîne de requête |
| Fond uni, aucune tuile | Le gabarit KVP n'est pas expansé, **ou** la permission `INTERNET` manque. Inspecter la console `flutter run` : les erreurs de tuile y sont journalisées |
| Tuiles présentes mais désordonnées | `TILECOL`/`TILEROW` intervertis — mais la tâche 4 verrouille ce point par test |

**Photographier l'écran.** C'est la preuve, et elle ne dépend pas d'`adb` — dont la révocation a
fait échouer le relevé du 2026-08-18.

- [ ] **Step 6: Commit**

```bash
git add spike/porte_flutter/lib/f1_fond_ign.dart spike/porte_flutter/lib/main.dart spike/porte_flutter/android/app/src/main/AndroidManifest.xml
git commit -m "feat(map): ecran F1, fond IGN sous flutter_map"
```

---

### Task 6: Le constat sur Windows

**Fichiers :** aucun — exécution seule.

> ⛔ **Dépend de la tâche 2.** Si `flutter doctor` n'affiche pas `[√] Visual Studio`, s'arrêter ici
> et attendre la fin de l'installation.

- [ ] **Step 1: 🖥️ Lancer sur Windows**

```powershell
flutter run -d windows
```

Attendu : une fenêtre de bureau s'ouvre, le menu s'affiche, `F1` montre le plan IGN.

- [ ] **Step 2: 🖥️ Constater le comportement clavier et souris**

Molette pour zoomer, glisser pour déplacer. **Ce n'est pas un test de recette** — les wireframes
d'`04-ui.md` sont écrits pour le tactile, et le lot responsive reste à faire. On note simplement si
la carte est manipulable à la souris **ou pas du tout**.

- [ ] **Step 3: Rapporter le résultat de `F1`**

`F1` est **vert** si le fond IGN s'affiche sur **les deux** cibles. Un vert sur une seule ne suffit
pas : c'est Windows qui justifie toute la bascule.

🚨 **Règle d'arrêt de la spec :** si `F1` échoue, **aucune ligne de `lib/domain/` n'est réécrite** et
on revient à l'arbitrage — l'alternative « tout web » reprend la main.

---

## Lot 3 — F2 : 4 150 marqueurs

### Task 7: La lecture de l'asset des stations

**Fichiers :**
- Créer : `spike/porte_flutter/lib/stations_asset.dart`
- Test : `spike/porte_flutter/test/stations_asset_test.dart`

Le format est **constaté** dans `assets/referentiel/stations.json` : une `FeatureCollection` de
4 150 entités, `geometry.coordinates` en `[longitude, latitude]`, `properties.code_station` sur
10 caractères.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `spike/porte_flutter/test/stations_asset_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:porte_flutter/stations_asset.dart';

const String _fixture = '''
{
  "type": "FeatureCollection",
  "count": 2,
  "features": [
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-61.658989, 16.189402]},
      "properties": {"code_station": "1011000101", "libelle_station": "La Grande Riviere"}
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-0.5792, 44.8378]},
      "properties": {"code_station": "P123456789", "libelle_station": "Bordeaux"}
    }
  ]
}
''';

void main() {
  group('lecture du referentiel des stations', () {
    test('lit chaque entite en un point', () {
      final stations = parseStations(_fixture);
      expect(stations.length, 2);
    });

    test('n inverse pas longitude et latitude', () {
      final stations = parseStations(_fixture);
      // GeoJSON ordonne [longitude, latitude] — l inverse placerait la
      // Guadeloupe au large de la Somalie, sans aucune erreur levee.
      expect(stations.first.longitude, closeTo(-61.658989, 1e-6));
      expect(stations.first.latitude, closeTo(16.189402, 1e-6));
    });

    test('conserve le code station', () {
      final stations = parseStations(_fixture);
      expect(stations.first.code, '1011000101');
      expect(stations.first.code.length, 10);
    });

    test('ignore une entite sans geometrie plutot que de planter', () {
      const casse = '{"type":"FeatureCollection","features":['
          '{"type":"Feature","geometry":null,"properties":{"code_station":"X"}}]}';
      expect(parseStations(casse), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 🖥️ Lancer le test pour vérifier qu'il échoue**

```powershell
flutter test test/stations_asset_test.dart
```

Attendu : **ÉCHEC** — `Undefined name 'parseStations'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `spike/porte_flutter/lib/stations_asset.dart` :

```dart
import 'dart:convert';

/// Une station hydrométrique réduite à ce dont la carte a besoin.
/// Dart pur : ce n'est pas l'entité de domaine, c'est un point à dessiner.
class StationPoint {
  const StationPoint({
    required this.code,
    required this.latitude,
    required this.longitude,
  });

  final String code;
  final double latitude;
  final double longitude;
}

/// Lit la `FeatureCollection` du référentiel figé en `S4`.
///
/// ⚠️ GeoJSON ordonne les coordonnées en **[longitude, latitude]**. Les
/// inverser ne lève aucune erreur : la carte s'affiche simplement ailleurs.
List<StationPoint> parseStations(String jsonText) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final features = decoded['features'] as List<dynamic>? ?? const <dynamic>[];

  final points = <StationPoint>[];
  for (final feature in features) {
    final map = feature as Map<String, dynamic>;
    final geometry = map['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;

    final coordinates = geometry['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) continue;

    final properties = map['properties'] as Map<String, dynamic>? ?? const {};
    points.add(StationPoint(
      code: properties['code_station'] as String? ?? '',
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
    ));
  }
  return points;
}
```

- [ ] **Step 4: 🖥️ Lancer le test pour vérifier qu'il passe**

```powershell
flutter test test/stations_asset_test.dart
```

Attendu : `All tests passed!` — 4 tests.

- [ ] **Step 5: 🖥️ Copier l'asset et le déclarer**

```powershell
New-Item -ItemType Directory -Force spike/porte_flutter/assets
Copy-Item assets/referentiel/stations.json spike/porte_flutter/assets/stations.json
```

Puis dans `spike/porte_flutter/pubspec.yaml`, sous la clé `flutter:`, ajouter :

```yaml
  assets:
    - assets/stations.json
```

- [ ] **Step 6: Commit**

```bash
git add spike/porte_flutter/lib/stations_asset.dart spike/porte_flutter/test/stations_asset_test.dart spike/porte_flutter/pubspec.yaml
git commit -m "test(map): lecture du referentiel des stations, ordre lon/lat verrouille"
```

---

### Task 8: Le calcul des percentiles de trame

**Fichiers :**
- Créer : `spike/porte_flutter/lib/frame_stats.dart`
- Test : `spike/porte_flutter/test/frame_stats_test.dart`

`M5` a échoué parce que `dumpsys gfxinfo` a renvoyé un histogramme vide et qu'`adb` était révoqué.
Ici, la mesure vient de Flutter lui-même et **s'affiche à l'écran** : une photo suffit.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `spike/porte_flutter/test/frame_stats_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:porte_flutter/frame_stats.dart';

void main() {
  group('percentileMicros', () {
    test('rend la mediane sur un echantillon impair', () {
      expect(percentileMicros([1, 2, 3, 4, 5], 0.5), 3);
    });

    test('n exige pas un echantillon deja trie', () {
      expect(percentileMicros([5, 1, 4, 2, 3], 0.5), 3);
    });

    test('rend le maximum au centieme percentile', () {
      expect(percentileMicros([10, 20, 30], 1.0), 30);
    });

    test('rend zero sur un echantillon vide plutot que de planter', () {
      expect(percentileMicros(const [], 0.9), 0);
    });
  });

  group('FrameStats', () {
    test('compte les trames au dela du budget', () {
      // Budget 60 Hz = 16 667 us. Deux trames le depassent.
      final stats = FrameStats(
        buildMicros: [1000, 2000, 3000],
        rasterMicros: [5000, 20000, 30000],
      );
      expect(stats.frameCount, 3);
      expect(stats.jankCount(16667), 2);
    });

    test('exprime le jank en pourcentage', () {
      final stats = FrameStats(
        buildMicros: [1, 1, 1, 1],
        rasterMicros: [1, 1, 99999, 99999],
      );
      expect(stats.jankPercent(16667), closeTo(50.0, 0.01));
    });

    test('rend zero pour cent quand aucune trame n a ete vue', () {
      final stats = FrameStats(buildMicros: const [], rasterMicros: const []);
      expect(stats.jankPercent(16667), 0);
    });
  });
}
```

- [ ] **Step 2: 🖥️ Lancer le test pour vérifier qu'il échoue**

```powershell
flutter test test/frame_stats_test.dart
```

Attendu : **ÉCHEC** — `Undefined name 'percentileMicros'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `spike/porte_flutter/lib/frame_stats.dart` :

```dart
/// Statistiques de fluidité. Dart pur : se teste sans rendu, en millisecondes
/// de calcul.
///
/// Le jank est compté sur la durée de **rastérisation**, pas de construction :
/// c'est elle qui fait sauter une image à l'écran.
class FrameStats {
  const FrameStats({required this.buildMicros, required this.rasterMicros});

  final List<int> buildMicros;
  final List<int> rasterMicros;

  int get frameCount => buildMicros.length;

  /// Nombre de trames dont la rastérisation dépasse le budget.
  int jankCount(int budgetMicros) =>
      rasterMicros.where((d) => d > budgetMicros).length;

  /// Part des trames en retard, en pourcentage.
  double jankPercent(int budgetMicros) =>
      frameCount == 0 ? 0 : 100.0 * jankCount(budgetMicros) / frameCount;
}

/// Percentile par rang le plus proche, sur un échantillon non trié.
/// Rend `0` sur un échantillon vide — une valeur sentinelle visible, plutôt
/// qu'une exception au milieu d'une mesure.
int percentileMicros(List<int> samples, double p) {
  if (samples.isEmpty) return 0;
  final tries = List<int>.of(samples)..sort();
  final rang = (p * tries.length).ceil().clamp(1, tries.length);
  return tries[rang - 1];
}
```

- [ ] **Step 4: 🖥️ Lancer le test pour vérifier qu'il passe**

```powershell
flutter test test/frame_stats_test.dart
```

Attendu : `All tests passed!` — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add spike/porte_flutter/lib/frame_stats.dart spike/porte_flutter/test/frame_stats_test.dart
git commit -m "test(map): percentiles de trame, mesure independante d adb"
```

---

### Task 9: L'écran F2 clusterisé et la mesure

**Fichiers :**
- Créer : `spike/porte_flutter/lib/frame_recorder.dart`
- Créer : `spike/porte_flutter/lib/f2_marqueurs.dart`
- Modifier : `spike/porte_flutter/lib/main.dart`

- [ ] **Step 1: 🚨 Lire l'API réelle de `flutter_map_marker_cluster` avant d'écrire**

Le plan T0 précédent s'est trompé neuf fois en décrivant une API de mémoire. Cette étape n'est pas
une formalité.

```powershell
Get-Content $env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_map_marker_cluster-*\lib\src\marker_cluster_layer_options.dart | Select-Object -First 80
```

Relever : le **nom exact** de la classe d'options, ses paramètres requis, et le type attendu par
`builder`. **Si l'un diffère du code de l'étape 3, c'est le paquet qui a raison.** Rapporter l'écart
à l'agent avant de corriger.

Vérifier au passage la signature de `Marker` — elle a changé entre les versions de `flutter_map`
(`builder:` en v4, `child:` depuis la v6) :

```powershell
Select-String -Path $env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_map-*\lib\src\layer\marker_layer\marker.dart -Pattern "  const Marker\(" -Context 0,12
```

Attendu : un constructeur portant `point`, `child`, `width`, `height`. **Si c'est `builder`, la
version résolue n'est pas la 8.x** et la tâche 3 étape 3 a été mal lue.

- [ ] **Step 2: Écrire l'enregistreur de trames**

Créer `spike/porte_flutter/lib/frame_recorder.dart` :

```dart
import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart';

import 'frame_stats.dart';

/// Accumule les `FrameTiming` que Flutter publie après chaque image.
///
/// C'est la source de mesure retenue plutôt que `dumpsys gfxinfo` : elle vient
/// du moteur lui-même, elle ne dépend pas d'`adb`, et elle survit donc à une
/// politique de terminal qui révoque le débogage USB.
class FrameRecorder {
  final List<int> _build = <int>[];
  final List<int> _raster = <int>[];
  bool _actif = false;

  bool get actif => _actif;

  void _onTimings(List<FrameTiming> timings) {
    if (!_actif) return;
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
    }
  }

  void demarrer() {
    _build.clear();
    _raster.clear();
    _actif = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  FrameStats arreter() {
    _actif = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    return FrameStats(
      buildMicros: List<int>.of(_build),
      rasterMicros: List<int>.of(_raster),
    );
  }
}
```

- [ ] **Step 3: Écrire l'écran F2**

Créer `spike/porte_flutter/lib/f2_marqueurs.dart`. ⚠️ **Le bloc `MarkerClusterLayerWidget` est à
confronter au relevé de l'étape 1 avant de lancer.**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'frame_recorder.dart';
import 'frame_stats.dart';
import 'ign_tile_template.dart';
import 'stations_asset.dart';

/// Budget d'une image à 60 Hz, en microsecondes.
const int budget60Hz = 16667;

class F2Marqueurs extends StatefulWidget {
  const F2Marqueurs({super.key});

  @override
  State<F2Marqueurs> createState() => _F2MarqueursState();
}

class _F2MarqueursState extends State<F2Marqueurs> {
  final FrameRecorder _recorder = FrameRecorder();
  List<Marker> _markers = const <Marker>[];
  FrameStats? _resultat;
  int _nbStations = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final texte = await rootBundle.loadString('assets/stations.json');
    final stations = parseStations(texte);
    setState(() {
      _nbStations = stations.length;
      _markers = stations
          .map((s) => Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 20,
                height: 20,
                child: const Icon(Icons.place, size: 20, color: Colors.blue),
              ))
          .toList();
    });
  }

  void _basculerMesure() {
    if (_recorder.actif) {
      final stats = _recorder.arreter();
      setState(() => _resultat = stats);
    } else {
      setState(() => _resultat = null);
      _recorder.demarrer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    return Scaffold(
      appBar: AppBar(title: Text('F2 — $_nbStations marqueurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _basculerMesure,
        label: Text(_recorder.actif ? 'Arreter la mesure' : 'Mesurer'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              // Centre de la France métropolitaine, au zoom national.
              initialCenter: const LatLng(46.6, 2.2),
              initialZoom: 5,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: ignTileUrlTemplate,
                tileDimension: ignTileDimension,
                maxNativeZoom: 18,
                userAgentPackageName: 'fr.martinpecheur.spike',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  markers: _markers,
                  builder: (context, markers) => DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                    ),
                    child: Center(
                      child: Text(
                        '${markers.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (r != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(8),
                child: Text(
                  'trames ${r.frameCount}\n'
                  'raster p50 ${(percentileMicros(r.rasterMicros, 0.5) / 1000).toStringAsFixed(1)} ms\n'
                  'raster p90 ${(percentileMicros(r.rasterMicros, 0.9) / 1000).toStringAsFixed(1)} ms\n'
                  'raster p99 ${(percentileMicros(r.rasterMicros, 0.99) / 1000).toStringAsFixed(1)} ms\n'
                  'build  p90 ${(percentileMicros(r.buildMicros, 0.9) / 1000).toStringAsFixed(1)} ms\n'
                  'jank ${r.jankCount(budget60Hz)} soit ${r.jankPercent(budget60Hz).toStringAsFixed(1)} %',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Ajouter l'entrée au menu**

Dans `spike/porte_flutter/lib/main.dart`, ajouter l'importation `import 'f2_marqueurs.dart';` puis,
dans la liste `children` du `ListView`, après la tuile `F1` :

```dart
          ListTile(
            title: const Text('F2 — 4 150 marqueurs'),
            subtitle: const Text('Le clustering tient-il, et a quel prix ?'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const F2Marqueurs()),
            ),
          ),
```

- [ ] **Step 5: 🖥️ Lancer en mode `profile`, pas en `debug`**

**Le mode `debug` mesure faux** : les assertions et l'absence d'optimisation gonflent les durées de
plusieurs fois. Une mesure en `debug` ne vaut rien.

```powershell
flutter run --profile -d emulator-5554
```

Attendu : l'application démarre, `F2` affiche la France entière et des pastilles de cluster portant
un compte.

- [ ] **Step 6: 🖥️ Exécuter la séquence de mesure**

Toujours la même séquence, pour que deux relevés soient comparables :

1. ouvrir `F2`, attendre que les tuiles soient chargées ;
2. appuyer sur **Mesurer** ;
3. **30 secondes** : glisser du nord au sud, zoomer jusqu'à l'échelle départementale, dégrouper un
   cluster, revenir au zoom national ;
4. appuyer sur **Arreter la mesure** ;
5. **photographier l'encart noir.**

- [ ] **Step 7: 🖥️ Lire le résultat**

| Relevé | Lecture |
|---|---|
| `trames` = 0 | 🚨 **La mesure a échoué**, comme `M5` le 2026-08-18. Ne rien conclure. Vérifier que le bouton a bien été pressé avant les gestes |
| `raster p90` ≤ 16,7 ms **et** `jank` < 5 % | ✅ `F2` vert sur émulateur |
| `raster p90` > 16,7 ms **ou** `jank` ≥ 5 % | ⚠️ `F2` rouge. Repli prévu par la spec : ne charger que les marqueurs du viewport, ce qu'`04-ui.md` prévoit déjà |

⚠️ **Une mesure sur émulateur `x86_64` n'est pas une mesure sur Android d'entrée de gamme.** Elle
donne une **borne haute** : si l'émulateur rame déjà, un téléphone d'entrée de gamme ramera plus.
L'inverse ne se déduit pas. **`NV-5` reste ouvert** tant qu'un appareil réel n'a pas été mesuré —
c'est la même réserve qu'`ADR-012` posait le 2026-08-18.

- [ ] **Step 8: Commit**

```bash
git add spike/porte_flutter/lib/frame_recorder.dart spike/porte_flutter/lib/f2_marqueurs.dart spike/porte_flutter/lib/main.dart
git commit -m "feat(map): ecran F2, 4150 marqueurs clusterises et mesure a l ecran"
```

---

## Lot 4 — F3 : l'exécutable Windows

### Task 10: Produire et lancer le binaire Windows

**Fichiers :** aucun — exécution seule.

> ⛔ **Dépend de la tâche 2.**

- [ ] **Step 1: 🖥️ Construire en release**

⚠️ **Ne pas rediriger la sortie dans un tube.** Le retour d'expérience du 2026-08-15 sur Gradle vaut
ici : un tube masque le code de sortie, et un build rouge passe pour vert.

```powershell
flutter build windows --release
```

Attendu : `√ Built build\windows\x64\runner\Release\porte_flutter.exe`.

- [ ] **Step 2: 🖥️ Relever la taille produite**

Aucun seuil n'est fixé — c'est un chiffre de référence pour la suite, comme les 110 Mo de l'APK du
2026-08-15.

```powershell
Get-ChildItem -Recurse build\windows\x64\runner\Release | Measure-Object -Property Length -Sum | Select-Object @{n='Mo';e={[math]::Round($_.Sum/1MB,1)}}, Count
```

- [ ] **Step 3: 🖥️ Lancer l'exécutable hors de Flutter**

C'est le point de `F3` : que le binaire tourne **seul**, pas seulement sous `flutter run`.

```powershell
.\build\windows\x64\runner\Release\porte_flutter.exe
```

Attendu : la fenêtre s'ouvre, le menu s'affiche, `F1` montre le plan IGN.

- [ ] **Step 4: Rapporter le résultat de `F3`**

`F3` est vert si l'exécutable démarre et affiche la carte hors du harnais de développement.

---

## Lot 5 — Le verdict

### Task 11: Écrire le compte rendu et trancher

**Fichiers :**
- Créer : `docs/superpowers/specs/2026-08-24-porte-spike-resultat.md`
- Modifier : `docs/project-state.md`

- [ ] **Step 1: Rassembler les faits, sans les interpréter**

Reprendre pour chaque épreuve : la date, la cible (émulateur `x86_64` ou Windows), les versions
réellement résolues à la tâche 3 étape 3, les chiffres relevés, et **les photographies**.

⚠️ **Distinguer ce qui est constaté de ce qui est déduit.** C'est la règle qu'`ADR-012` s'applique à
lui-même : « l'application s'est fermée » est une impression, une ligne de journal est un fait.

- [ ] **Step 2: Écrire le compte rendu**

Créer `docs/superpowers/specs/2026-08-24-porte-spike-resultat.md` avec ce squelette, rempli des
valeurs réelles :

```markdown
# Porte de spike Flutter — résultat

- **Date d'exécution :** AAAA-MM-JJ
- **Verdict :** ✅ franchie / 🚨 échouée en Fn
- **Versions liées :** flutter X.Y.Z · flutter_map X.Y.Z · flutter_map_marker_cluster X.Y.Z

| Épreuve | Cible | Résultat | Preuve |
|---|---|---|---|
| `F1` fond IGN | émulateur Pixel_7 | | photo |
| `F1` fond IGN | Windows | | photo |
| `F2` 4 150 marqueurs | émulateur Pixel_7, mode profile | trames … · raster p90 … ms · jank … % | photo |
| `F3` exécutable Windows | Windows | | taille … Mo |

## Ce qui reste non vérifié

- `NV-5` — tenue sur Android **d'entrée de gamme réel**. Non levé : la mesure est sur émulateur,
  elle ne donne qu'une borne haute.
- iOS — aucune cible construite, faute d'hôte macOS.

## Décision
```

- [ ] **Step 3: Mettre à jour l'état du projet**

Dans `docs/project-state.md`, remplacer l'en-tête `**Mis à jour :**` par la date et le verdict, et
ajouter les lignes `F1`, `F2`, `F3` au tableau des tâches.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-08-24-porte-spike-resultat.md docs/project-state.md
git commit -m "docs(map): resultat de la porte de spike Flutter"
```

- [ ] **Step 5: Décider de la suite**

| Verdict | Suite |
|---|---|
| Les trois vertes | Écrire `ADR-013`, puis le plan de réécriture T0 — c'est un **plan distinct**, à rédiger sur les faits de ce compte rendu et pas avant |
| `F1` rouge | 🚨 **Arrêt.** Retour à l'arbitrage : l'alternative « tout web » reprend la main, avec son risque WebView documenté |
| `F2` rouge seule | Ni arrêt ni feu vert : appliquer le repli viewport prévu par `04-ui.md`, remesurer, et **ne pas escamoter le chiffre** dans le compte rendu |
| `F3` rouge | Windows ne tient pas, or c'est la seule justification de la bascule. Retour à l'arbitrage |

---

## Ce que ce plan ne couvre volontairement pas

- **La réécriture de `lib/domain/`, `lib/data/`, `lib/application/`** — barrée par la règle d'arrêt
  de la spec. Son plan s'écrira après le verdict.
- **Le hors-ligne cartographique** — sorti de la v1 (`ADR-012`, option C).
- **Les tracés de cours d'eau** — sortis de la v1 le 2026-08-24.
- **Le stockage local, la gestion d'état, les graphes** — décisions rouvertes mais non bloquantes
  pour la porte (spec, section 8).
- **iOS** — aucun hôte macOS. La cible est absente du `flutter create` plutôt que déclarée sans être
  constructible.

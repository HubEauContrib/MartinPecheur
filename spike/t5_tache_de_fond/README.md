# Essai jetable de T5 — tâche de fond et notification (étape 2)

Projet Flutter **à part**, créé le 2026-10-21 (tâche `T5-Z1`), pour les essais `E-A` (Android) et `E-W` (Windows) du cadrage de T5 ([`docs/superpowers/specs/2026-10-17-cadrage-t5-design.md`](../../docs/superpowers/specs/2026-10-17-cadrage-t5-design.md), § 10.1). Il n'est **jamais** importé par `lib/` ni par `test/` de l'application, il est exclu de l'analyse de la racine (`spike/**` dans `analysis_options.yaml`) et n'entre pas dans le décompte des tests. Un essai qui échoue est un **résultat**, pas un défaut de T5. Le relevé des bibliothèques qui précède l'essai est [`RELEVE-BIBLIOTHEQUES.md`](RELEVE-BIBLIOTHEQUES.md), gardé tel quel.

Rien de ce projet n'a encore été construit ni lancé : seuls `flutter pub get` et `flutter analyze` (zéro remarque) ont tourné, le 2026-10-21.

## Ce que fait l'essai

- **Vérification** (`verifyAndNotify`, `lib/main.dart`) : lit le GeoJSON national de Vigicrues, en tire la date de l'information de vigilance, la compare à celle de l'exécution précédente (fichier `t5_tache_de_fond_derniere_date.txt`), **notifie** si elle a changé ou si aucune n'était connue, notifie aussi un échec de lecture, et écrit **une ligne au journal dans tous les cas** : heure réelle (locale et UTC), origine (planificateur, `workmanager`, écran), plateforme, date lue ou cause de l'échec, et la notification : « non demandée (date inchangée) », ou « demandée (aucune date connue | date changée | échec de lecture) » suivie de son issue (« oui » ou la cause de l'échec). Avec `--verifier`, `exit(0)` est dans un `finally` : le processus caché quitte même si le journal ne s'écrit pas.
- **Journal** : `t5_tache_de_fond_journal.txt`, dans le dossier temporaire de la plateforme (`Directory.systemTemp`). Son chemin exact s'affiche sur l'écran de pilotage.
- **Point d'entrée** `main(List<String> args)` :
  - avec `--verifier` (Windows, planificateur) : vérifie, notifie si besoin, écrit le journal, puis `exit(0)`. Aucun `runApp`.
  - sans argument : écran de pilotage — « Demander l'autorisation » (Android 13+), « Programmer la tâche (15 min) », « Annuler la tâche », « Vérifier maintenant », « Oublier la dernière date » (supprime le fichier de la dernière date), « Relire le journal », et le journal. Hors Android, « Demander l'autorisation », « Programmer la tâche », « Annuler la tâche » et « Oublier la dernière date » sont inactifs.
- **Android** : `callbackDispatcher` de premier niveau, annoté `@pragma('vm:entry-point')` ; tâche périodique `workmanager` de 15 min (nom unique `t5-essai-verification`, réseau requis, politique `update`) ; `INTERNET` et `POST_NOTIFICATIONS` déclarées dans `android/app/src/main/AndroidManifest.xml` ; désucrage dans `android/app/build.gradle.kts`.
- **Windows** : `windows/runner/main.cpp` repère `--verifier` et construit `FlutterWindow(project, !verifier)`. La fenêtre est **créée** (`Win32Window::Create` ne la rend pas visible) mais le rappel de première trame qui appelle `Show()` n'est **pas enregistré** (`windows/runner/flutter_window.cpp`) : elle n'est jamais montrée. Le toast passe par l'AUMID de l'essai, enregistré par le plugin sous `HKCU`, **sans** MSIX ni raccourci.

### Ce qui est recopié de l'application, jamais importé

| Valeur | Recopiée de (code à `e8d10ce`) |
|---|---|
| `https://www.vigicrues.gouv.fr/services/InfoVigiCru.geojson` | `lib/data/floods/vigicrues_endpoint.dart`, `vigicruesInformationUri` |
| délai d'une tentative, 20 s | `lib/data/floods/vigicrues_endpoint.dart`, `vigicruesRequestTimeout` |
| champ de date de la racine, `DtHrInfoVigiCru` | `lib/data/floods/flood_vigilance_mapper.dart`, `_informationDate(json['DtHrInfoVigiCru'])` |

L'essai ne rejoue pas les tentatives (une seule requête) et garde la date telle que publiée, sans la convertir : il note un changement, il n'interprète rien.

### Identité Windows de l'essai

Propre à l'essai, distincte de celle de l'application (`msix_config`) :

- `appName` : `Essai T5 MartinPecheur`
- `appUserModelId` : `MartinPecheur.EssaiT5`
- `guid` : `0b8dce4b-c217-4c66-8968-17de6195d081` (tiré au hasard le 2026-10-21)

Clés que le plugin **écrit** à l'initialisation, lues dans `flutter_local_notifications_windows` 3.1.1, `src/plugin.cpp` (l. 80-160) — à lister après l'essai (`E-W` f), leur suppression appartient au commanditaire :

- `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\MartinPecheur.EssaiT5` (`appType`, `Setting`, `wnsId`)
- `HKCU\Software\Classes\AppUserModelId\MartinPecheur.EssaiT5` (`DisplayName`, `IconUri`, `CustomActivator` = `{0b8dce4b-c217-4c66-8968-17de6195d081}`)

Aucune clé `LocalServer32` n'est écrite (lecture du même fichier).

## Versions résolues — `flutter pub get` du 2026-10-21

Flutter 3.47.7, Dart 3.13.5. `pubspec.lock` est **versionné** (arbitrage 14 : reconstruire sur un autre poste).

| Paquet | Contrainte | Résolue |
|---|---|---|
| `flutter_local_notifications` | `22.3.2` exacte | 22.3.2 |
| `flutter_local_notifications_windows` | transitive | 3.1.1 |
| `flutter_local_notifications_platform_interface` | transitive | 12.2.0 |
| `workmanager` | `0.10.10` exacte | 0.10.10 |
| `workmanager_android` | transitive | 0.10.9 |
| `workmanager_platform_interface` | transitive | 0.10.5 |
| `http` | `^1.6.0` | 1.6.0 |
| `timezone`, `xml` | transitives | 0.11.2, 7.0.1 |

## Signatures employées — lues dans les paquets installés (cache pub), le 2026-10-21

`flutter_local_notifications` 22.3.2 :

- `lib/src/flutter_local_notifications_plugin.dart:111` — `Future<bool?> initialize({required InitializationSettings settings, DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse, DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse})`
- `lib/src/flutter_local_notifications_plugin.dart:252` — `Future<void> show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload})`
- `lib/src/initialization_settings.dart:6` — `const InitializationSettings({android, iOS, macOS, linux, windows, web})` ; `lib/src/notification_details.dart:11` — `const NotificationDetails({android, iOS, macOS, linux, windows, web})`
- `lib/src/platform_specifics/android/initialization_settings.dart:4` — `const AndroidInitializationSettings(this.defaultIcon)`
- `lib/src/platform_specifics/android/notification_details.dart:111` — `const AndroidNotificationDetails(this.channelId, this.channelName, {channelDescription, icon, importance = Importance.defaultImportance, …, priority = Priority.defaultPriority, …})`
- `lib/src/platform_flutter_local_notifications.dart:205` — `Future<bool?> requestNotificationsPermission()` sur `AndroidFlutterLocalNotificationsPlugin`

`flutter_local_notifications_windows` 3.1.1 :

- `lib/src/details/initialization_settings.dart:4` — `const WindowsInitializationSettings({required this.appName, required this.appUserModelId, required this.guid, this.iconPath})`
- `lib/src/details/notification_details.dart:47` — `const WindowsNotificationDetails({actions = const [], inputs = const [], images = const [], rows = const [], …})`
- `lib/src/plugin/ffi.dart:73-79` — un GUID mal formé lève une `ArgumentError` (« xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx »)
- `src/ffi_api.cpp:30-34` — avec une identité de paquet `CreateToastNotifier()`, sinon `CreateToastNotifier(aumid)`

`workmanager` 0.10.10 :

- `lib/src/workmanager_impl.dart:172` — `Future<void> initialize(Function callbackDispatcher, {@Deprecated bool isInDebugMode = false})`
- `lib/src/workmanager_impl.dart:218` — `void executeTask(BackgroundTaskHandler backgroundTaskHandler, {BackgroundTaskStoppedHandler? onTaskStopped})` ; `:26` — `typedef BackgroundTaskHandler = Future<bool> Function(String taskName, Map<String, dynamic>? inputData)`
- `lib/src/workmanager_impl.dart:345` — `Future<void> registerPeriodicTask(String uniqueName, String taskName, {Duration? frequency, Duration? flexInterval, Map<String, dynamic>? inputData, Duration? initialDelay, Constraints? constraints, ExistingPeriodicWorkPolicy? existingWorkPolicy, BackoffPolicy? backoffPolicy, Duration? backoffPolicyDelay, String? tag, ForegroundServiceConfig? foregroundServiceConfig})`
- `lib/src/workmanager_impl.dart:532` — `Future<void> cancelByUniqueName(String uniqueName)`
- `workmanager_platform_interface` 0.10.5, `lib/src/pigeon/workmanager_api.g.dart` : `enum NetworkType` (l. 138, `connected` …), `enum ExistingPeriodicWorkPolicy` (l. 192, `keep`, `replace`, `update` — `update` dit « recommandé »), `class Constraints` (l. 344)
- ⚠️ `lib/src/workmanager_impl.dart:224-226` : `executeTask` écrit lui-même un fichier `wm_execute_task_marker` dans `Directory.systemTemp`, à chaque appel.

### Manifeste Android et désucrage — README des paquets installés

- `flutter_local_notifications` 22.3.2, `README.md` l. 217 : le désucrage est exigé depuis la v10, même sans notification planifiée ; l. 246-271 (`build.gradle.kts`) : `isCoreLibraryDesugaringEnabled = true`, `multiDexEnabled = true`, `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` — **version reprise : 2.1.4**. Le `kotlinOptions` du même extrait n'est pas repris : le gabarit de Flutter 3.47.7 pose déjà `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.
- id., l. 346 : `compileSdk` 35 au minimum (le gabarit pose `flutter.compileSdkVersion`, 36 d'après le relevé) ; l. 374 : le plugin ne déclare que `POST_NOTIFICATIONS` et `VIBRATE` (constaté dans son `android/src/main/AndroidManifest.xml`) ; l. 414-420 : la demande d'autorisation passe par `requestNotificationsPermission()`.
- id., l. 171-174 : sous Windows, `periodicallyShow` lève `UnsupportedError` ; sans MSIX, `cancel` ne fait rien et `getActiveNotifications` rend une liste vide.
- `workmanager` 0.10.10, `README.md` l. 40-48 : l'exemple `@pragma('vm:entry-point') void callbackDispatcher() { Workmanager().executeTask(…) }`. Le README ne donne **aucune** consigne de manifeste ; la configuration par plateforme est renvoyée à `docs.page`, non relue ici. Le manifeste de `workmanager_android` 0.10.9 déclare lui-même `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE` et `FOREGROUND_SERVICE_SHORT_SERVICE`, fusionnés dans celui de l'essai.

## Comment le lancer — par le commanditaire

Le bac à sable de Claude ne construit rien en natif : chaque commande ci-dessous est lancée par le commanditaire, dans `spike/t5_tache_de_fond/`. Ce qui en sort se **constate**, et va au compte rendu de l'essai.

### `E-A` — Android, émulateur `Pixel_7`, en débogage

```bash
cd spike/t5_tache_de_fond
flutter pub get
flutter run -d emulator-5554
```

Attendu : l'écran « Essai T5 — tâche de fond ». Puis, à l'écran, dans cet ordre :

1. « Demander l'autorisation » — attendu : la fenêtre du système paraît.
2. « Vérifier maintenant » — attendu : une ligne au journal, et une notification si aucune date n'était encore connue.
3. « Oublier la dernière date » — attendu : une ligne « dernière date oubliée » au journal. Sans cette étape, la date lue en 2 est enregistrée, et les exécutions de fond ne notifieraient que si Vigicrues publiait une nouvelle information pendant l'essai : la première exécution de fond doit partir **sans date connue**.
4. « Programmer la tâche (15 min) » — attendu : une ligne « tâche programmée » au journal.

Retirer ensuite l'essai des applications récentes. Attendu, à la première exécution de fond : une notification et une ligne « notification demandée (aucune date connue) » au journal.

Doze forcé, une fois au moins une exécution de fond constatée au journal :

```bash
adb shell dumpsys deviceidle force-idle
```

Attendu : une ligne de sortie de `dumpsys` qui dit l'appareil en veille. Observer **au moins 20 minutes**, soit plus d'une période de 15 min, pour couvrir le passage prévu de la tâche, puis sortir du Doze forcé :

```bash
adb shell dumpsys deviceidle unforce
```

Attendu : le journal dit si une exécution a eu lieu pendant ces 20 minutes, ou après la sortie.

Lire le journal sans rouvrir l'essai (le chemin est celui affiché à l'écran) :

```bash
adb shell run-as fr.martinpecheur.essai.t5_tache_de_fond cat <chemin du journal affiché à l'écran>
```

**Trois heures au plus**, puis « Annuler la tâche ».

### `E-W` — Windows, exécutable de release lancé par le planificateur

```bash
cd spike/t5_tache_de_fond
flutter pub get
flutter build windows --release
```

Attendu : `build/windows/x64/runner/Release/t5_tache_de_fond.exe`. Un premier essai à la main, depuis une invite de commandes, avec l'argument :

```bat
"<dossier du dépôt>\spike\t5_tache_de_fond\build\windows\x64\runner\Release\t5_tache_de_fond.exe" --verifier
```

Attendu : aucune fenêtre, un toast si aucune date n'était encore connue, le processus quitte, une ligne au journal `%TEMP%\t5_tache_de_fond_journal.txt`.

Oublier la date enregistrée par ce lancement à la main, pour que la première exécution planifiée parte **sans date connue** (sinon elle ne notifierait que si Vigicrues publiait une nouvelle information pendant l'essai) :

```bat
del "%TEMP%\t5_tache_de_fond_derniere_date.txt"
```

Attendu : aucune sortie ; le fichier n'existe plus (`dir "%TEMP%\t5_tache_de_fond_derniere_date.txt"` répond « Fichier introuvable »).

Tâche planifiée toutes les 30 minutes, créée puis supprimée **à la main** (syntaxe d'après Microsoft Learn, `schtasks create`, relevé du 2026-10-17, § 4.1 de `RELEVE-BIBLIOTHEQUES.md` — **jamais exécutée** ; `/it` : seulement quand la session est ouverte). Création :

```bat
schtasks /create /tn "MartinPecheur-EssaiT5" /sc minute /mo 30 /it /tr "\"<dossier du dépôt>\spike\t5_tache_de_fond\build\windows\x64\runner\Release\t5_tache_de_fond.exe\" --verifier"
```

Attendu : un message de réussite de `schtasks` (ou une demande de mot de passe, à noter). À la première exécution planifiée : un toast et une ligne « notification demandée (aucune date connue) » au journal.

Suppression, au bout de trois heures au plus :

```bat
schtasks /delete /tn "MartinPecheur-EssaiT5" /f
```

Attendu : un message de réussite de `schtasks` ; plus aucune ligne nouvelle au journal ensuite.

**Trois heures au plus**, puis suppression de la tâche, et relevé des clés `HKCU` listées plus haut.

## Ce que l'essai ne fait pas

- Aucune règle d'avis de l'application : il compare une **date** publiée, pas un niveau. Les textes de ses notifications sont ceux d'un essai, jamais des textes d'écran de l'application.
- Aucun MSIX (`PD15`) : ce que l'identité de paquet d'`ADR-018` changerait est lu, non essayé.
- iOS : absent (plateformes créées : `windows`, `android`).

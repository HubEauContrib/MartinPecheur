# T5 « Être prévenu » — bibliothèques de notifications et de tâche de fond

Relevé du **2026-10-17**, par un agent de lecture, sur pub.dev, des dépôts GitHub, Microsoft Learn et developer.android.com, pendant le cadrage de T5 ([`docs/superpowers/specs/2026-10-17-cadrage-t5-design.md`](../../docs/superpowers/specs/2026-10-17-cadrage-t5-design.md), § 4.3). Recopié tel quel le même jour ; aucun `pub get`, rien exécuté sur une cible. Les essais de l'étape 2 (cadrage, § 10.1) partent de ce relevé et le complètent ; ils n'existent pas encore.

Règles de lecture de ce document :

- Un fait sans mention vient d'une page lue aujourd'hui (URL en section 9).
- **« non relevé »** : la page n'a pas pu être lue ou ne contient pas le fait. L'URL tentée est donnée.
- **« inférence »** : conclusion tirée d'une source lue, jamais confirmée par exécution. Rien de ce qui suit n'a été exécuté sur une cible. L'essai technique par cible reste à faire.
- Les dates de publication « exactes » viennent de `https://pub.dev/api/packages/<nom>`. Là où seule une durée relative (« il y a N jours ») était disponible, c'est dit.
- Compatibilité licence : MIT, BSD-2/3 et Apache-2.0 sont tenues pour compatibles GPL-3.0, selon la consigne reçue.

---

## 1. Faits décisifs

1. **`flutter_local_notifications` 22.3.2** (BSD-3-Clause, éditeur vérifié `dexterx.dev`, publié le **2026-10-12**) est le seul paquet relevé qui déclare Windows **et** Android **et** iOS sur pub.dev, avec licence compatible et publication récente. Windows y est pris en charge depuis la **19.0.0**, par le sous-paquet `flutter_local_notifications_windows` 3.1.1 (BSD-3-Clause, 2026-06-14).
2. **Windows, application non empaquetée** : le code natif du plugin (lu sur GitHub) prévoit explicitement l'absence d'identité de paquet. Il enregistre un AUMID dans `HKCU\Software\Classes\AppUserModelId\<aumid>` et crée le notifieur avec cet AUMID. Il ne crée **pas** de raccourci du menu Démarrer. Le MSIX n'est donc pas exigé pour **afficher** une notification. Il l'est pour `getActiveNotifications` et `cancel` (README). **Non vérifié par exécution.**
3. **Windows, planification** : `zonedSchedule` existe et appelle `ScheduledToastNotification` + `AddToSchedule`, donc c'est Windows qui délivre, **application fermée**, d'après Microsoft Learn. Contraintes : fenêtre de livraison de **5 minutes** (au-delà, la notification est abandonnée), maximum **4096** notifications planifiées, pas d'heure passée. `periodicallyShow` lève `UnsupportedError` sur Windows. Une note de la référence Learn réserve `AddToSchedule` aux applications « WinRT par défaut » : à lever par l'essai.
4. **Windows, clic sur une notification application fermée** : le plugin n'écrit aucune clé `CLSID\{guid}\LocalServer32` (lu dans `plugin.cpp`). **Inférence** : un clic ne relancerait pas l'exécutable fermé. Le plugin sert à afficher, pas à rouvrir.
5. **Aucune bibliothèque de tâche de fond ne cible Windows.** `workmanager` (Android, iOS, macOS, web), `background_fetch` (Android, iOS), `android_alarm_manager_plus` (Android seul).
6. **Android, sans serveur** : `workmanager` 0.10.10 (MIT, 2026-09-07). Période minimale **15 minutes**, jamais exacte. Doze et App Standby reportent ou suppriment les exécutions. La permission `POST_NOTIFICATIONS` (API 33+) est demandée à l'exécution.
7. **Windows, application fermée, sans serveur** : aucun paquet requis, le planificateur de tâches (`schtasks`) lance un exécutable avec arguments, y compris au `/sc onlogon`. Le runner du projet transmet déjà les arguments à `main(List<String> args)`. Il crée toujours une fenêtre : un mode sans fenêtre est une modification du runner ou un second exécutable.

---

## 2. Notifications locales

### 2.1 `flutter_local_notifications`

| Champ | Valeur |
|---|---|
| Dernière version stable | **22.3.2** (préversion : 23.0.0-dev.4) |
| Publiée | **2026-10-12T09:13:53Z** (API pub.dev) |
| Éditeur | `dexterx.dev`, vérifié |
| Licence | **BSD-3-Clause** (compatible GPL-3.0) |
| Plateformes pub.dev | Android, iOS, Linux, macOS, web, **Windows** |
| SDK | Dart `^3.10.0`, Flutter `>=3.38.1` |
| Points pub | 150/160, 7,35 k likes |
| Dépendances | `clock ^1.1.0`, `flutter_local_notifications_linux ^8.0.2`, `flutter_local_notifications_platform_interface ^12.2.0`, `flutter_local_notifications_web ^1.0.0`, `flutter_local_notifications_windows ^3.1.1`, `timezone ^0.11.0` |
| Minimums natifs (changelog 21.0.0) | Android 7.0 (API 24), iOS 13, macOS 10.15, `compileSdk` 36 et AGP 8.11.1 pour le plugin ; le README publié de la 22.3.2 dit `compileSdk` « 35 au minimum » |

Points d'attention :

- **README de la branche `master` ≠ README publié.** Le README GitHub master annonce Flutter 3.44.0, `compileSdk` 37 et AGP 9.1.1. Le README de la 22.3.2 sur pub.dev annonce Flutter 3.38.1, `compileSdk` 35 minimum, AGP 8.11.1. La branche master correspond sans doute à la préversion 23 : se fier à pub.dev pour la 22.3.2 (inférence).
- **Historique Windows** (changelog) : 19.0.0 ajoute Windows ; 19.3.1 et 19.4.2 corrigent des caractères non ASCII ; 20.0.0 casse des paramètres nommés ; 22.0.0 précise que `periodicallyShow` n'est pas pris en charge sur Windows.
- **Android** : le plugin déclare seulement `POST_NOTIFICATIONS` et `VIBRATE` depuis la v16. Les alarmes exactes exigent `SCHEDULE_EXACT_ALARM` (autorisation utilisateur via `requestExactAlarmsPermission()`) ou `USE_EXACT_ALARM` (API 33+, soumis à l'examen des magasins). `RECEIVE_BOOT_COMPLETED` et un récepteur de démarrage sont nécessaires pour replanifier après redémarrage. Le README nomme Xiaomi et Huawei comme fabricants dont l'arrêt des applications d'arrière-plan peut faire échouer les notifications planifiées. Samsung plafonnerait à 500 alarmes. Le **desugaring** des bibliothèques cœur est requis depuis la v10.
- **Il n'exécute aucun code réseau de lui-même.** Les notifications planifiées sont écrites à l'avance. Pour qu'une notification dépende d'un appel Vigicrues fait en arrière-plan, il faut un autre mécanisme (section 3).
- **iOS** : 64 notifications en attente au plus (README master, non recoupé avec la page 22.3.2).
- Issues ouvertes relevées sur la recherche « windows » (GitHub, 23 résultats, dont 12 titres nomment Windows) : #2851 crash à l'initialisation quand le service Windows Push Notification est arrêté (2026-10-10, sans réponse du mainteneur) ; #2805 échec de construction `MSB3491` (2026-07-20) ; #2738 icône incohérente (2025-12-30) ; #2730 `cancel()` en boucle fige l'interface (2025-12-12) ; #2688 `cancelAllPendingNotifications()` absent sur Windows (2025-09-18) ; #2666 crash de `showNotification` avec la fusion de fils (2025-08-08, étiquette « question »). La recherche « unpackaged » ne ressort que #2666.

### 2.2 `flutter_local_notifications_windows` (sous-paquet)

| Champ | Valeur |
|---|---|
| Dernière version stable | **3.1.1** (préversions 4.0.0-dev.1 du 2026-09-24 et 4.0.0-dev.2 du 2026-10-05) |
| Publiée | **2026-06-14T07:30:41Z** |
| Éditeur | `dexterx.dev`, vérifié |
| Licence | **BSD-3-Clause** |
| Plateforme | Windows seule (20/20) |
| SDK | Dart `^3.10.0`, Flutter `>=3.38.1` (3.0.0 a relevé le minimum à 3.38.1 / 3.10.0) |
| Dépendances | `ffi ^2.1.2`, `flutter_local_notifications_platform_interface ^12.0.0`, `meta ^1.11.0`, `timezone ^0.11.0`, `xml >=6.5.0 <8.0.0` |
| Points pub | 150/160, ~2,25 M de téléchargements, 2 likes, aucun exemple dans le paquet |

Comportement relevé dans le code (`plugin.cpp`, `ffi_api.cpp`, `plugin.hpp`, `lib/src/plugin/ffi.dart` sur la branche master, donc possiblement en avance sur la 3.1.1) :

- `initialize` exige `WindowsInitializationSettings` avec `appName`, `appUserModelId`, `guid` et `iconPath` optionnel. Un GUID mal formé lève `ArgumentError` (le commentaire dit que le C++ plante sinon).
- `registerApp` écrit sous `HKCU` : `Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\<aumid>` (`appType`, `Setting`, `wnsId`) et `Software\Classes\AppUserModelId\<aumid>` (`DisplayName`, `IconUri` si fourni, `CustomActivator` = `{guid}`). Il enregistre aussi, en mémoire, une fabrique de classe COM (`CoRegisterClassObject`). **Aucune** clé `LocalServer32`, aucun raccourci.
- `hasPackageIdentity` : si le processus a une identité de paquet, `CreateToastNotifier()` ; sinon `CreateToastNotifier(aumid)`. Les deux cas sont donc codés.
- README : sans MSIX, `cancel` ne fait rien et `getActiveNotifications` renvoie une liste vide. Le plugin renvoie vers `package:msix`.
- Planification : `scheduleNotification` construit un `ScheduledToastNotification` et appelle `AddToSchedule`. Côté Dart, une date passée lève `ArgumentError`.
- Le gestionnaire d'activation (clic) transmet les détails de lancement à `onDidReceiveNotificationResponse`. Le fichier ne dit pas comment une application fermée est relancée.

### 2.3 Autres candidats notifications

| Nom | Version | Publiée | Éditeur | Licence | Plateformes pub.dev | SDK | Points d'attention |
|---|---|---|---|---|---|---|---|
| `local_notifier` | 0.1.6 | 2024-04-05 (API) | `leanflutter.dev`, vérifié | MIT | **Linux, macOS, Windows** (ni Android ni iOS) | Dart `>=3.0.0 <4.0.0`, Flutter `>=3.3.0` | Ne couvre pas Android : ne peut pas être l'unique solution. Dernière publication il y a 2 ans. Windows : `ShortcutPolicy`, valeur par défaut `requireCreate` (crée ou modifie un raccourci portant l'AUMID). 150/160 points. Dépôt : 32 commits, 11 issues listées. Planification : non mentionnée au README |
| `windows_notification` | 1.3.0 | 2024-08-20 (API) | `mrtnetwork.com`, vérifié | MIT | **Windows seul** | Dart `>=3.1.1 <4.0.0`, Flutter `>=2.5.0` | 160/160, 85 likes. Pas d'Android. Modèles de toast riches. Le code d'exemple indique que l'identifiant d'application doit être nul en mode empaqueté. Planification : non mentionnée |
| `win_toast` | 0.4.0 | 2025-07-18 (API) | `mixin.dev`, vérifié | Apache-2.0 | **Windows seul** | Dart `>=2.17.0 <4.0.0`, Flutter `>=2.5.0` | 41 likes. AUMID unique exigé ; en MSIX, paramètre `clsid` et section `toast_activator` de `msix_config`. Planification non mentionnée |
| `awesome_notifications` | 0.12.1 | 2026-07-01 (API) | `carda.me`, vérifié | **Apache-2.0** | Android, iOS, Linux, macOS, web, **Windows** (pub.dev) | Dart `>=2.19.0 <4.0.0`, Flutter `>=2.5.0` | 130/160, 3,44 k likes. README : section « plugin under development », la liste « prochaines étapes » contient encore « Desktop support » (écart avec l'étiquette Windows), et il se déclare **incompatible avec `flutter_local_notifications` ou tout autre plugin de notifications**. Minimums annoncés (notes 0.11.X) : Android API 23, AGP 8.10.1, Gradle 8.11.1, iOS 15. Détail de l'implémentation Windows : non relevé |
| `platform_local_notifications` | 2.2.0 | 2026-08-16 (API) | `vchatsdk.com`, vérifié | MIT | Android, iOS, Linux, macOS, web, Windows | Dart `>=3.4.0 <4.0.0`, Flutter `>=3.22.0` | Surcouche : dépend de `flutter_local_notifications ^19.4.0`, `local_notifier ^0.1.6`, `quick_notify_2 ^0.3.0-dev.0` (préversion), `flutter_cache_manager`, `v_platform`. 14 likes, première version le 2023-02-20. Épingle une version 19 de la dépendance principale. Non recommandé |
| `toastification` | 3.2.0 (liste de résultats, « il y a 6 mois ») | non relevé | non relevé | non relevé | non relevé | non relevé | Superposition **dans l'application**, pas une notification du système. Écarté, sans lecture de sa page |

Pas de page lue pour : `quick_notify_2` (non relevé, URL non tentée).

---

## 3. Tâche de fond Android / iOS

| Nom | Version | Publiée | Éditeur | Licence | Plateformes pub.dev | SDK | Points d'attention |
|---|---|---|---|---|---|---|---|
| **`workmanager`** | **0.10.10** | **2026-09-07T10:27:55Z** (API) | `fluttercommunity.dev`, vérifié | **MIT** | **Android, iOS, macOS, web** ; Linux expérimental par `workmanager_linux`. **Pas Windows** (page de score : 4 plateformes sur 6) | Dart `>=3.5.0 <4.0.0`, Flutter `>=3.38.0` | 140/160. Actif : correctifs Android 16 en 0.10.8, 0.10.9, 0.10.10 ; 0.10.6 corrige la construction avec AGP 9 (réglage `android.builtInKotlin=false`). Pana : le composant Android n'est pas prêt pour le Kotlin intégré. Dépôt : 297 commits, 3 issues et 6 PR ouvertes (page GitHub). Dépendances : `workmanager_platform_interface ^0.10.5`, `workmanager_android ^0.10.9`, `workmanager_apple ^0.9.11`, `workmanager_web ^0.2.0`, `workmanager_linux ^0.1.1` |
| `background_fetch` | 1.7.0 | 2026-05-25T14:46:29Z (API) | `transistorsoft.com`, vérifié | MIT | **Android, iOS** | Dart `^3.6.0`, Flutter `>=3.38.0` | 155/160. README : jamais d'événement plus rapide que 15 minutes ; le système peut limiter selon l'usage ; sur iOS plus aucun événement après la fermeture de l'application et `stopOnTerminate: false` n'existe pas ; Android : implémentation « headless » qui continue après la fermeture. Aucune dépendance |
| `android_alarm_manager_plus` | 5.1.2 | 2026-10-01T19:31:39Z (API) | `fluttercommunity.dev`, vérifié | BSD-3-Clause | **Android seul** | Dart `>=3.1.0 <4.0.0`, Flutter `>=3.12.0` | Permissions : `SCHEDULE_EXACT_ALARM` (Android 12+), `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`. La page dit que la permission est refusée par défaut depuis Android 14 et que le plugin ne la demande pas (un autre paquet est nécessaire). Le rappel s'exécute dans un isolat séparé. Le README ne dit pas que les alarmes sont replanifiées au redémarrage |

Ce que dit la documentation du plugin `workmanager` (`docs.page`, lue) :

- **Android** : support « complet ». Tâche périodique : fréquence minimale **15 minutes**, présentée comme fiable. Les tâches s'exécutent encore après la fermeture de l'application ; WorkManager peut les différer.
- **iOS** : au mieux. Les tâches de rafraîchissement ont environ 30 secondes, au moins 15 minutes entre deux lancements, sans intervalle garanti, et **aucune exécution après terminaison de l'application**. La fréquence se règle dans `AppDelegate.swift`, pas en Dart. Pas de tâche « processing » sur Android.
- **macOS** : seulement tant que l'application tourne.
- **Windows** : non mentionné dans les pages lues.

Source Apple sur `BGTaskScheduler` : **non relevé**. La page `developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app` n'a renvoyé que son titre. Les chiffres iOS ci-dessus viennent donc de la documentation du plugin, pas d'Apple. iOS n'a jamais été compilé dans le projet.

---

## 4. Windows sans serveur : lancer une vérification application fermée

### 4.1 Planificateur de tâches (aucun paquet)

Source : Microsoft Learn `schtasks create` (mis à jour le 2025-10-22) et « About the Task Scheduler » (mis à jour le 2026-07-17).

- Le planificateur est installé sur toutes les versions de Windows prises en charge et démarre avec le système. Une tâche lance un programme, avec arguments, quand un critère de temps ou d'événement est satisfait.
- Déclencheurs de `schtasks /create /sc` : MINUTE, HOURLY, DAILY, WEEKLY, MONTHLY, ONCE, **ONSTART**, **ONLOGON**, ONIDLE, ONEVENT. `/mo` fixe l'intervalle : de 1 à 1439 minutes pour MINUTE, de 1 à 23 heures pour HOURLY.
- `/tr` : « le programme ou la commande exécutée ». Un chemin d'au plus 262 caractères. Une seule exécution de programme par tâche (un `.bat` peut en enchaîner plusieurs).
- `/it` : n'exécute la tâche que si l'utilisateur concerné est connecté (interactif seulement). `/np` : aucun mot de passe stocké, la tâche s'exécute non interactivement. `/rl LIMITED` est le niveau par défaut. `/ru system` : pas d'ouverture de session interactive, l'utilisateur ne voit rien : à éviter pour une notification.
- La page dit que `schtasks` demande toujours un mot de passe sauf s'il est fourni, même pour l'utilisateur courant.
- Recommandation de la page « Task Scheduler » : ne jamais utiliser de tâche d'interrogation à intervalle court sur une machine sur batterie (exemple : 5 minutes), préférer événements, inactivité ou maintenance.
- **Arguments dans le projet (lecture seule)** : `windows/runner/main.cpp` appelle `GetCommandLineArguments()` et `project.set_dart_entrypoint_arguments(...)`, donc `main(List<String> args)` reçoit les arguments de `schtasks`. Le même fichier crée **toujours** une fenêtre (`window.Create(...)`, boucle de messages) : aucun mode sans fenêtre n'existe aujourd'hui.
- **Lien avec la notification** : une tâche lancée en tâche de fond puis affichant un toast par `flutter_local_notifications` repose sur les mêmes conditions que la section 2.2 (AUMID enregistré, identité absente). Non vérifié.

### 4.2 Lancement à l'ouverture de session : `launch_at_startup`

| Champ | Valeur |
|---|---|
| Version | **0.5.1**, publiée 2025-04-01 (API) |
| Éditeur | `leanflutter.dev`, vérifié |
| Licence | MIT |
| Plateformes | Linux, macOS, Windows |
| SDK | Dart `>=3.0.0 <4.0.0`, Flutter `>=3.3.0` |
| Dépendance | `win32_registry ^2.0.0` |
| Points pub | 125/160 (dépendances à jour 10/40 : `win32_registry` plafonnée sous la 3.0.x ; analyse des bornes basses en échec) |

Source (`app_auto_launcher_impl_windows.dart`) : hors MSIX, valeur dans `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (chemin plus arguments, **chemin non entouré de guillemets**, donc un chemin avec espaces peut mal s'analyser) et entrée `StartupApproved\Run`. En MSIX : raccourci `.lnk` dans le dossier Démarrage. Les arguments de lancement sont donc possibles (`setup(... )` n'en montre pas dans l'exemple du README).

### 4.3 Zone de notification

| Nom | Version | Publiée | Éditeur | Licence | Plateformes | SDK | Points d'attention |
|---|---|---|---|---|---|---|---|
| `tray_manager` | **0.8.0** | 2026-10-08T13:06:24Z (API) | `leanflutter.dev`, vérifié | MIT | Linux, macOS, Windows | Dart `^3.13.0`, **Flutter `>=3.47.0`** | 160/160, 291 likes, 224 k téléchargements. Dépend de `nativeapi ^0.5.1` et `nativeapi_flutter ^0.5.1` (tous deux MIT, `leanflutter.dev`, 0.5.2 publiées il y a 9 jours). Contrainte au plancher exact de la chaîne du projet (Flutter 3.47.7 / Dart 3.13.5). 0.7.0 a réécrit l'API (l'ancienne vit dans `package:tray_manager/legacy.dart`, marquée dépréciée) |
| `system_tray` | 2.0.3 | 2023-04-19 (API) | « unverified uploader » | MIT | Linux, macOS, Windows | **Dart `>=2.12.0 <3.0.0`** | Contrainte Dart 2 : **incompatible avec Dart 3.13.5 d'après la borne lue** (inférence, `pub get` interdit). Publié il y a 3 ans. Écarté |

Garder le processus vivant fenêtre fermée (masquer plutôt que quitter) relève d'un autre paquet ou du runner : **non relevé**.

---

## 5. Windows : notification « toast » et identité d'application (Microsoft Learn)

| Source (date `updated_at`) | Ce qu'elle établit |
|---|---|
| Win32 « How to enable desktop toast notifications through an AppUserModelID » (2025-03-11 ; `ms.date` 2018) | Voie classique : sans un raccourci valide dans le menu Démarrer ou « Tous les programmes », on ne peut pas lever de toast depuis une application de bureau. Le raccourci porte la propriété `System.AppUserModel.ID`. Microsoft recommande de le créer dans l'installeur, pas dans l'application |
| Win32 « Application User Model IDs » (2025-04-15) | L'AppUserModelID est facultatif pour la barre des tâches, mais « fortement recommandé » explicite ; forme `Société.Produit[.SousProduit[.Version]]`, 128 caractères au plus, sans espace |
| « Windows notifications overview » (`ms.date` 2026-03-19, `updated_at` 2026-07-17) | `AppNotificationManager` (Windows App SDK) est l'API recommandée pour WPF, WinForms et Win32 non empaqueté. Identité de paquet requise : non (fonctionne empaqueté et non empaqueté). `ToastNotificationManager` (WinRT) : « requise pour certaines fonctions », maintenance seule |
| « Use app notifications with a .NET app » (`updated_at` 2026-05-08) | Pour une application non empaquetée, `Register()` met en place l'enregistrement du serveur COM qui permet à Windows de relancer l'application au clic ; pas d'AUMID ni de COM à configurer à la main. **Les notifications d'applications élevées (administrateur) ne sont pas prises en charge** |
| Community Toolkit `DesktopNotificationManagerCompat` (obsolète, 2023-08-03) | L'ancienne classe exigeait AUMID et serveur COM enregistré (`RegisterAumidAndComServer` : AUMID et CLSID/EXE dans `LocalServer32`) |
| Community Toolkit `ToastNotificationManagerCompat` (2023-08-03) | Fonctionne pour tous les types d'application, y compris Win32 non MSIX. La classe obsolète recommande cette remplaçante, qui n'exige plus de raccourci du menu Démarrer. Les images en `http` ne sont possibles qu'avec une identité de paquet. Sa sœur `ToastNotifierCompat` « montre et planifie » les toasts |
| « Schedule an app notification » (`ms.date` 2025-07-28, `updated_at` 2026-07-17) | Une notification planifiée apparaît que l'application tourne ou non. Fenêtre de livraison de **5 minutes** : si l'ordinateur est éteint plus de 5 minutes autour de l'heure prévue, elle est abandonnée. Pour une livraison garantie, Microsoft recommande une tâche de fond à déclencheur horaire. Annulation par `Tag` et `Group` |
| Référence `ToastNotifier.AddToSchedule` (2025-11-21) | Échoue au-delà de **4096** notifications planifiées et pour une heure passée. **Note « Important » : la méthode n'est prise en charge que dans les applications qui utilisent WinRT comme cadre applicatif par défaut** : ambiguë pour un exécutable Flutter, à lever par l'essai |

Conclusion sur l'identité (inférence à valider par essai) : la voie « AUMID dans le registre `HKCU`, sans raccourci et sans MSIX » que suit `flutter_local_notifications_windows` correspond à ce que Microsoft décrit pour `ToastNotificationManagerCompat`. La page Win32 la plus ancienne (raccourci obligatoire) décrit la voie classique. Le clic application fermée est la partie la moins couverte par le plugin.

---

## 6. Android : permission, WorkManager, Doze (developer.android.com)

- **`POST_NOTIFICATIONS`** (page mise à jour le 2026-10-16) : permission d'exécution depuis Android 13 (API 33) pour toute notification non exemptée. Si l'application cible l'API 33 ou plus, elle choisit le moment de la demande. Si elle cible 12L (API 32) ou moins, la fenêtre apparaît au premier démarrage d'activité après création d'un canal, et un refus, même unique, n'est plus redemandé avant désinstallation. Si l'utilisateur refuse, l'application ne peut plus notifier. L'utilisateur peut révoquer à tout moment. Le projet cible l'API 36 : le moment de la demande est donc libre.
- **WorkManager, travail périodique** (page mise à jour le 2026-10-16) : intervalle de répétition minimal **15 minutes** (comme `JobScheduler`). C'est un minimum entre deux répétitions, l'heure exacte dépend des contraintes et des optimisations du système. Une contrainte non satisfaite (par exemple recharge, réseau) peut retarder ou même sauter une exécution. Intervalle « flex » possible.
- **Doze** (page mise à jour le 2026-08-18) : appareil immobile, branché ou non, écran éteint : accès réseau suspendu, travaux, synchronisations et alarmes standard reportés à la fenêtre de maintenance suivante. Cela inclut `setExact()`. `JobScheduler` ne s'exécute pas, et **WorkManager n'y échappe pas puisqu'il s'appuie dessus**. `setAndAllowWhileIdle()` et `setExactAndAllowWhileIdle()` ne peuvent pas déclencher plus d'une alarme toutes les neuf minutes par application ; `setAlarmClock()` continue de se déclencher normalement.
- **App Standby** (même page) : retarde l'activité réseau d'arrière-plan des applications sans usage récent ; si l'appareil reste inactif longtemps, le système n'autorise le réseau aux applications inactives qu'environ une fois par jour.
- **Compartiments App Standby** (page mise à jour le 2026-10-16) : actif, ensemble de travail, fréquent, rare, restreint (jobs une fois par jour dans une session groupée de 10 minutes, une alarme par jour). Aucun chiffre pour les compartiments intermédiaires dans cette page. Une application peu ouverte voit donc sa vérification périodique espacée : conséquence directe pour une alerte de crue (inférence).
- Non relevé : comportement de WorkManager après « Forcer l'arrêt » (pas de page lue) et restrictions par fabricant (seulement les noms Xiaomi et Huawei, relevés au README du plugin, sans source tierce).

---

## 7. Compatibilité avec le projet (lecture seule)

Constats lus dans le dépôt, sans rien exécuter :

| Élément | Valeur lue |
|---|---|
| `pubspec.yaml` | `sdk: ^3.13.3`, dépendances actuelles : `flutter_map`, `http`, `shared_preferences`, `url_launcher` ; aucun des paquets candidats n'y figure |
| `android/app/build.gradle.kts` | `minSdk = flutter.minSdkVersion`, `compileSdk = flutter.compileSdkVersion`, `targetSdk = flutter.targetSdkVersion` ; aucune occurrence de `desugar` |
| Valeurs du SDK Flutter installé (`FlutterExtension.kt`) | `minSdkVersion = 24`, `compileSdkVersion = 36`, `targetSdkVersion = 36`, `ndkVersion = 28.2.13676358` |
| Chaîne Android | AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1 ; `gradle.properties` : `android.builtInKotlin=false`, `android.newDsl=false` |
| `windows/runner/main.cpp` | Transmet les arguments de ligne de commande à Dart ; crée toujours une fenêtre ; COM initialisé (`CoInitializeEx`) |

Rapprochement avec les exigences relevées :

| Paquet | Exigence relevée | Projet | Verdict sur le papier |
|---|---|---|---|
| `flutter_local_notifications` 22.3.2 | Flutter `>=3.38.1`, Dart `^3.10.0` | 3.47.7 / 3.13.x | Compatible |
| id. | Android API 24 minimum, `compileSdk` 35 minimum | minSdk 24, compileSdk 36 | Compatible (minSdk pile au plancher) |
| id. | Desugaring des bibliothèques cœur | Non activé | **À ajouter dans `android/app/build.gradle.kts`** |
| id. | Windows : AUMID, GUID, nom d'application | Aucun | À choisir (décision de produit) |
| `workmanager` 0.10.10 | Flutter `>=3.38.0`, Dart `>=3.5.0` | 3.47.7 / 3.13.x | Compatible |
| id. | Composant Android sans Kotlin intégré ; 0.10.6 corrige AGP 9 avec `android.builtInKotlin=false` | `builtInKotlin=false` déjà posé | Cohérent |
| `tray_manager` 0.8.0 | Flutter `>=3.47.0`, Dart `^3.13.0` | 3.47.7 / 3.13.x | Compatible, au plancher |

Aucune résolution de dépendances (`pub get`) n'a été lancée : ces verdicts sont des lectures de contraintes, pas une résolution.

Licences transitives lues (page pub.dev de chacune) : `timezone` 0.11.2 BSD-2-Clause (`labs.dart.dev`) ; `xml` 7.1.0 MIT (`lukas-renggli.ch`) ; `ffi` 2.2.0 BSD-3-Clause (`dart.dev`) ; `clock` 1.1.3 Apache-2.0 (`tools.dart.dev`). Non relevées : `flutter_local_notifications_linux`, `_web`, `_platform_interface`, `plugin_platform_interface`, `win32_registry`, `uuid`, `workmanager_android`, `_apple`, `_web`, `_linux`, `_platform_interface` (URLs non tentées).

---

## 8. Ce qui reste non relevé ou à prouver par essai technique

À prouver par exécution (aucun fait de cette liste n'est établi) :

1. Une notification s'affiche depuis l'exécutable Windows **non empaqueté** du projet, avec le seul enregistrement `HKCU\...\AppUserModelId\<aumid>` du plugin.
2. `zonedSchedule` livre une notification **application fermée** dans ce même cas (note « WinRT par défaut » de la référence `AddToSchedule`).
3. Le clic sur la notification, application fermée, ne relance pas l'exécutable (lecture du code seulement).
4. Un mode « vérifier puis quitter » lancé par une tâche planifiée (fenêtre masquée ou second exécutable) : rien lu. Ni `dart compile exe`, ni masquage de fenêtre côté Flutter n'ont été examinés.
5. Sur Android : le comportement de `workmanager` sur l'émulateur `Pixel_7` (Doze simulé, compartiments) et la demande de `POST_NOTIFICATIONS`.
6. iOS : source Apple non relevée ; jamais compilé.

Non relevé (URL tentée) :

- `https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app` : titre seul, corps absent.
- `https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/send-local-toast`, `.../toast-desktop-apps`, `.../send-local-toast-desktop-cpp-wrl`, `.../send-local-toast-other-apps` : HTTP 404 (adresses supposées, pas les pages en vigueur).
- `https://pub.dev/documentation/flutter_local_notifications_windows/.../WindowsFlutterLocalNotificationsPlugin-class.html` : 404.
- `https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/flutter_local_notifications_windows/lib/src/plugin/implementation.dart` : 404 (le fichier réel est `base.dart` / `ffi.dart`).
- Date exacte de publication via l'API pour `local_notifier`, `windows_notification`, `win_toast`, `launch_at_startup`, `system_tray` : obtenue. Pour `toastification`, `nativeapi`, `nativeapi_flutter`, `timezone`, `xml`, `ffi`, `clock` : seule la durée relative ou aucune date a été relevée.
- Restrictions des fabricants Android (Xiaomi, Huawei, Samsung) hors README du plugin : aucune source tierce lue.
- Activité du dépôt `local_notifier` : date du dernier commit non lisible sur la page (seulement « 32 commits »).

---

## 9. URLs lues (aujourd'hui)

pub.dev (pages et API JSON) :

- https://pub.dev/api/packages/flutter_local_notifications · https://pub.dev/packages/flutter_local_notifications · /changelog · /score · /versions/22.3.2 · /example
- https://pub.dev/api/packages/flutter_local_notifications_windows · https://pub.dev/packages/flutter_local_notifications_windows · /changelog · /score
- https://pub.dev/api/packages/local_notifier · https://pub.dev/packages/local_notifier · /score · https://pub.dev/documentation/local_notifier/latest/local_notifier/ShortcutPolicy.html
- https://pub.dev/api/packages/windows_notification · https://pub.dev/packages/windows_notification · /score
- https://pub.dev/api/packages/win_toast · https://pub.dev/packages/win_toast
- https://pub.dev/api/packages/awesome_notifications · https://pub.dev/packages/awesome_notifications · /score
- https://pub.dev/api/packages/platform_local_notifications · https://pub.dev/packages/platform_local_notifications
- https://pub.dev/api/packages/workmanager · https://pub.dev/packages/workmanager · /changelog · /score
- https://pub.dev/api/packages/background_fetch · https://pub.dev/packages/background_fetch · /score
- https://pub.dev/api/packages/android_alarm_manager_plus · https://pub.dev/packages/android_alarm_manager_plus
- https://pub.dev/api/packages/launch_at_startup · https://pub.dev/packages/launch_at_startup · /score
- https://pub.dev/api/packages/tray_manager · https://pub.dev/packages/tray_manager · /changelog · /score
- https://pub.dev/api/packages/system_tray · https://pub.dev/packages/system_tray
- https://pub.dev/packages/nativeapi · https://pub.dev/packages/nativeapi_flutter · https://pub.dev/packages/timezone · https://pub.dev/packages/xml · https://pub.dev/packages/ffi · https://pub.dev/packages/clock
- Recherches pub.dev : https://pub.dev/packages?q=platform%3Awindows+toast+notification · https://pub.dev/packages?q=platform%3Awindows+platform%3Aandroid+local+notifications

GitHub :

- https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/README.md
- https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications_windows/README.md · https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications_windows · https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications_windows/lib/src/plugin
- https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/flutter_local_notifications_windows/src/plugin.cpp · .../src/ffi_api.cpp · .../src/plugin.hpp · .../lib/src/plugin/base.dart · .../lib/src/plugin/ffi.dart
- https://api.github.com/repos/MaikuB/flutter_local_notifications/contents/flutter_local_notifications_windows/src
- https://github.com/MaikuB/flutter_local_notifications/issues?q=is%3Aissue+is%3Aopen+windows · https://github.com/MaikuB/flutter_local_notifications/issues?q=is%3Aissue+unpackaged · https://github.com/MaikuB/flutter_local_notifications/issues/2851
- https://github.com/leanflutter/local_notifier
- https://github.com/leanflutter/launch_at_startup/tree/main/lib/src · https://raw.githubusercontent.com/leanflutter/launch_at_startup/main/lib/src/app_auto_launcher_impl_windows.dart
- https://github.com/fluttercommunity/flutter_workmanager · https://docs.page/fluttercommunity/flutter_workmanager

Microsoft Learn :

- https://learn.microsoft.com/en-us/windows/win32/shell/enable-desktop-toast-with-appusermodelid
- https://learn.microsoft.com/en-us/windows/win32/shell/appids
- https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/scheduled-toast (redirige vers `.../develop/notifications/app-notifications/app-notifications-scheduled`)
- https://learn.microsoft.com/en-us/windows/apps/develop/notifications/
- https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-dotnet
- https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.addtoschedule?view=winrt-22621
- https://learn.microsoft.com/en-us/dotnet/api/communitytoolkit.winui.notifications.toastnotificationmanagercompat?view=win-comm-toolkit-dotnet-7.0
- https://learn.microsoft.com/en-us/dotnet/api/communitytoolkit.winui.notifications.desktopnotificationmanagercompat?view=win-comm-toolkit-dotnet-7.0
- https://learn.microsoft.com/en-us/dotnet/api/microsoft.toolkit.uwp.notifications.toastnotifiercompat?view=win-comm-toolkit-dotnet-7.1
- https://learn.microsoft.com/en-us/windows/win32/taskschd/about-the-task-scheduler
- https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-create

developer.android.com :

- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://developer.android.com/topic/performance/appstandby

Fichiers lus (lecture seule) :

- Du dépôt : `pubspec.yaml` · `android/app/build.gradle.kts` · `android/settings.gradle.kts` · `android/gradle.properties` · `android/gradle/wrapper/gradle-wrapper.properties` · `windows/runner/main.cpp` · `windows/runner/utils.cpp`
- Du SDK Flutter installé : `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`

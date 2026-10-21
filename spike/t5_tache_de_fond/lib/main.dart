// Essai jetable de T5, étape 2 (Z1 du plan de T5 ; cadrage § 10.1, E-A et
// E-W). Jamais importé par l'application ni par ses tests ; exclu de
// l'analyse de la racine. Un essai qui échoue est un résultat.
//
// Deux voies :
// - Windows : le planificateur lance l'exécutable avec `--verifier`. Il
//   vérifie, notifie si la date de l'information a changé depuis la dernière
//   exécution, écrit une ligne au journal, puis quitte. La fenêtre n'est
//   jamais montrée (`windows/runner/`).
// - Android : une tâche périodique `workmanager` de 15 min fait la même
//   vérification, dans `callbackDispatcher`.
// Sans argument, un écran de pilotage s'ouvre.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

// Recopiés de `lib/data/floods/vigicrues_endpoint.dart` (application, à
// `e8d10ce`), jamais importés : l'adresse finale du GeoJSON national et le
// délai d'une tentative.
final Uri vigicruesInformationUri = Uri.parse(
  'https://www.vigicrues.gouv.fr/services/InfoVigiCru.geojson',
);
const Duration vigicruesRequestTimeout = Duration(seconds: 20);

// Recopié de `lib/data/floods/flood_vigilance_mapper.dart` : le champ de la
// racine qui porte la date de l'information de vigilance.
const String informationDateField = 'DtHrInfoVigiCru';

const String verifierArgument = '--verifier';

// Tâche `workmanager` : nom unique et nom de tâche.
const String periodicTaskUniqueName = 't5-essai-verification';
const String periodicTaskName = 'verificationVigicrues';

// Identité Windows de l'essai, propre à l'essai (distincte de celle de
// l'application) : ce sont les clés que le plugin écrit sous HKCU.
const String windowsAppName = 'Essai T5 MartinPecheur';
const String windowsAppUserModelId = 'MartinPecheur.EssaiT5';
const String windowsGuid = '0b8dce4b-c217-4c66-8968-17de6195d081';

const String androidChannelId = 'essai_t5';
const String androidChannelName = 'Essai T5';

File get journalFile => File(
  '${Directory.systemTemp.path}${Platform.pathSeparator}'
  't5_tache_de_fond_journal.txt',
);

File get lastDateFile => File(
  '${Directory.systemTemp.path}${Platform.pathSeparator}'
  't5_tache_de_fond_derniere_date.txt',
);

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.contains(verifierArgument)) {
    // `finally` : même si le journal ne s'écrit pas, le processus caché
    // quitte (E-W d).
    try {
      await verifyAndNotify(origin: 'planificateur ($verifierArgument)');
    } finally {
      exit(0);
    }
  }
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
  }
  runApp(const EssaiApp());
}

/// Point d'entrée de la tâche de fond Android : de premier niveau, annoté,
/// sinon l'arbre de compilation le retire.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    await verifyAndNotify(origin: 'workmanager ($task)');
    return true;
  });
}

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<bool?> initializeNotifications() => notifications.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    windows: WindowsInitializationSettings(
      appName: windowsAppName,
      appUserModelId: windowsAppUserModelId,
      guid: windowsGuid,
    ),
  ),
);

/// Une vérification : lit la date de l'information de vigilance, la compare
/// à celle de l'exécution précédente, notifie si elle a changé (ou si aucune
/// n'est encore connue), notifie aussi un échec, et écrit une ligne au
/// journal dans tous les cas.
Future<void> verifyAndNotify({required String origin}) async {
  final DateTime startedAt = DateTime.now();
  String result;
  String notification;
  try {
    final String informationDate = await readInformationDate();
    final String? previous = await readLastDate();
    final bool changed = previous != informationDate;
    await lastDateFile.writeAsString(informationDate, flush: true);
    result =
        'information du $informationDate'
        '${changed ? ' (changée ; avant : ${previous ?? 'aucune'})' : ' (inchangée)'}';
    if (!changed) {
      notification = 'non demandée (date inchangée)';
    } else {
      final String reason = previous == null
          ? 'aucune date connue'
          : 'date changée';
      final String outcome = await notify(
        title: 'Essai T5 — date de vigilance changée',
        body:
            'Information de vigilance du $informationDate, '
            'lue le ${startedAt.toIso8601String()}.',
      );
      notification = 'demandée ($reason) : $outcome';
    }
  } on Object catch (error) {
    result = 'échec : $error';
    final String outcome = await notify(
      title: 'Essai T5 — vérification impossible',
      body: 'Lecture de Vigicrues en échec le ${startedAt.toIso8601String()}.',
    );
    notification = 'demandée (échec de lecture) : $outcome';
  }
  await appendJournal(
    'heure réelle ${startedAt.toIso8601String()} '
    '(UTC ${startedAt.toUtc().toIso8601String()}) · $origin · '
    '${Platform.operatingSystem} · $result · notification $notification',
  );
}

Future<String> readInformationDate() async {
  final http.Response response = await http
      .get(vigicruesInformationUri)
      .timeout(vigicruesRequestTimeout);
  if (response.statusCode != 200 && response.statusCode != 206) {
    throw HttpException('HTTP ${response.statusCode}');
  }
  final Object? root = jsonDecode(utf8.decode(response.bodyBytes));
  if (root is! Map<String, Object?>) {
    throw const FormatException('racine : un objet JSON est attendu');
  }
  final Object? date = root[informationDateField];
  if (date is! String) {
    throw FormatException('racine.$informationDateField : chaîne attendue');
  }
  return date;
}

Future<String?> readLastDate() async {
  if (!await lastDateFile.exists()) {
    return null;
  }
  return (await lastDateFile.readAsString()).trim();
}

/// Rend « oui » ou la cause de l'échec, pour le journal.
Future<String> notify({required String title, required String body}) async {
  try {
    await initializeNotifications();
    await notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        windows: WindowsNotificationDetails(),
      ),
    );
    return 'oui';
  } on Object catch (error) {
    return 'échec ($error)';
  }
}

Future<void> appendJournal(String line) async {
  await journalFile.writeAsString(
    '$line\n',
    mode: FileMode.append,
    flush: true,
  );
}

Future<String> readJournal() async {
  if (!await journalFile.exists()) {
    return '(journal vide)';
  }
  return journalFile.readAsString();
}

class EssaiApp extends StatelessWidget {
  const EssaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Essai T5', home: PilotScreen());
  }
}

class PilotScreen extends StatefulWidget {
  const PilotScreen({super.key});

  @override
  State<PilotScreen> createState() => _PilotScreenState();
}

class _PilotScreenState extends State<PilotScreen> {
  String _journal = '';
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshJournal();
  }

  Future<void> _refreshJournal() async {
    final String journal = await readJournal();
    if (!mounted) {
      return;
    }
    setState(() => _journal = journal);
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    String status;
    try {
      status = '$label : ${await action()}';
    } on Object catch (error) {
      status = '$label : échec ($error)';
    }
    await _refreshJournal();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _status = status;
    });
  }

  Future<String> _requestPermission() async {
    await initializeNotifications();
    final bool? granted = await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return 'réponse $granted';
  }

  Future<String> _schedule() async {
    await Workmanager().registerPeriodicTask(
      periodicTaskUniqueName,
      periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    await appendJournal(
      'heure réelle ${DateTime.now().toIso8601String()} · tâche programmée '
      '(15 min)',
    );
    return 'programmée';
  }

  Future<String> _cancel() async {
    await Workmanager().cancelByUniqueName(periodicTaskUniqueName);
    await appendJournal(
      'heure réelle ${DateTime.now().toIso8601String()} · tâche annulée',
    );
    return 'annulée';
  }

  Future<String> _verifyNow() async {
    await verifyAndNotify(origin: 'écran (Vérifier maintenant)');
    return 'faite, voir le journal';
  }

  /// Supprime la dernière date enregistrée : la prochaine exécution part sans
  /// date connue et demande donc une notification.
  Future<String> _forgetLastDate() async {
    final bool existed = await lastDateFile.exists();
    if (existed) {
      await lastDateFile.delete();
    }
    await appendJournal(
      'heure réelle ${DateTime.now().toIso8601String()} · dernière date '
      '${existed ? 'oubliée' : 'absente, rien à oublier'}',
    );
    return existed ? 'oubliée' : 'aucune date enregistrée';
  }

  @override
  Widget build(BuildContext context) {
    final bool android = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('Essai T5 — tâche de fond')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _busy || !android
                      ? null
                      : () => _run(
                          'Demander l\'autorisation',
                          _requestPermission,
                        ),
                  child: const Text('Demander l\'autorisation'),
                ),
                FilledButton(
                  onPressed: _busy || !android
                      ? null
                      : () => _run('Programmer la tâche (15 min)', _schedule),
                  child: const Text('Programmer la tâche (15 min)'),
                ),
                FilledButton(
                  onPressed: _busy || !android
                      ? null
                      : () => _run('Annuler la tâche', _cancel),
                  child: const Text('Annuler la tâche'),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run('Vérifier maintenant', _verifyNow),
                  child: const Text('Vérifier maintenant'),
                ),
                FilledButton(
                  onPressed: _busy || !android
                      ? null
                      : () => _run('Oublier la dernière date', _forgetLastDate),
                  child: const Text('Oublier la dernière date'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refreshJournal,
                  child: const Text('Relire le journal'),
                ),
              ],
            ),
            if (!android)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Hors Android, la tâche de fond passe par le planificateur '
                  'de Windows (README) : seuls « Vérifier maintenant » et le '
                  'journal servent ici.',
                ),
              ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 8),
            SelectableText('Journal : ${journalFile.path}'),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(child: SelectableText(_journal)),
            ),
          ],
        ),
      ),
    );
  }
}

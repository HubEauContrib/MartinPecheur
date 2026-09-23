// Verrouille `WarningsViewModel`, sans monter aucun widget. Même style que
// `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart` : un
// double de dépôt programmable (valeur lue, échec de lecture, échec
// d'écriture, journal des écritures), et un compteur de notifications pour
// vérifier qu'un changement sans effet ne notifie pas.
//
// ⚠️ Aucun balayage BR-003/BR-014 ici : ce ViewModel ne produit AUCUNE
// chaîne — ni libellé, ni message d'erreur formaté. Le texte de
// l'avertissement (BR-012, BR-014) vit dans la vue, tâche `W2` du plan. Un
// balayage sur ce fichier n'aurait donc rien à balayer.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';

/// Double de [AcknowledgementRepository] : programmable en lecture (valeur
/// stockée ou échec) et en écriture (échec, ou une porte à ouvrir pour
/// rejouer une écriture en vol). Journalise chaque écriture pour vérifier
/// que `acknowledge()` sans case cochée n'en produit aucune.
final class _AcknowledgementRepositoryDouble
    implements AcknowledgementRepository {
  /// Valeur rendue par [readAcknowledgedVersion], tant que [readError] est
  /// `null`.
  String? storedVersion;

  /// Levée par [readAcknowledgedVersion] si non nulle.
  Object? readError;

  /// Levée par [writeAcknowledgedVersion] si non nulle — après que
  /// [writeGate], si posée, s'est ouverte.
  Object? writeError;

  /// Si posée, [writeAcknowledgedVersion] attend son ouverture avant de
  /// rendre la main : c'est ce qui simule une écriture « en vol » pendant
  /// laquelle `dispose()` survient.
  Completer<void>? writeGate;

  /// Chaque version écrite, dans l'ordre des appels.
  final List<String> written = <String>[];

  @override
  Future<String?> readAcknowledgedVersion() async {
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return storedVersion;
  }

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    final Completer<void>? gate = writeGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    written.add(version);
    storedVersion = version;
  }
}

void main() {
  const String currentVersion = '2026-09-13.1';

  test('stockage vide : apres load(), requiresAcknowledgement vrai, '
      'canAcknowledge faux, checkboxChecked faux', () async {
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(),
      currentWarningVersion: currentVersion,
    );
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.load();

    expect(viewModel.requiresAcknowledgement, isTrue);
    expect(viewModel.canAcknowledge, isFalse);
    expect(viewModel.checkboxChecked, isFalse);
    // load() notifie toujours une fois, meme quand l'etat ne change pas :
    // « la lecture est finie » est l'evenement que la vue attend.
    expect(notifications, 1);
  });

  test(
    'toggleCheckbox(true) rend canAcknowledge vrai et notifie une fois',
    () async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: currentVersion,
      );
      await viewModel.load();
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.toggleCheckbox(true);

      expect(viewModel.canAcknowledge, isTrue);
      expect(notifications, 1);
    },
  );

  test(
    'toggleCheckbox(false) apres un cochage rend canAcknowledge faux a nouveau',
    () async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: currentVersion,
      );
      await viewModel.load();
      viewModel.toggleCheckbox(true);

      viewModel.toggleCheckbox(false);

      expect(viewModel.canAcknowledge, isFalse);
      expect(viewModel.checkboxChecked, isFalse);
    },
  );

  test('toggleCheckbox avec la meme valeur ne notifie pas : une seule '
      'notification par changement effectif', () async {
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(),
      currentWarningVersion: currentVersion,
    );
    await viewModel.load();
    viewModel.toggleCheckbox(true);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.toggleCheckbox(true);

    expect(notifications, 0);
  });

  test('acknowledge() sans case cochee : aucune ecriture, etat inchange — '
      'defense en profondeur, la vue desactive deja le bouton', () async {
    final _AcknowledgementRepositoryDouble repository =
        _AcknowledgementRepositoryDouble();
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: repository,
      currentWarningVersion: currentVersion,
    );
    await viewModel.load();
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.acknowledge();

    expect(repository.written, isEmpty);
    expect(viewModel.requiresAcknowledgement, isTrue);
    expect(notifications, 0);
  });

  test("acknowledge() case cochee : la version courante est ecrite, "
      'requiresAcknowledgement devient faux', () async {
    final _AcknowledgementRepositoryDouble repository =
        _AcknowledgementRepositoryDouble();
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: repository,
      currentWarningVersion: currentVersion,
    );
    await viewModel.load();
    viewModel.toggleCheckbox(true);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.acknowledge();

    expect(repository.written, <String>[currentVersion]);
    expect(viewModel.requiresAcknowledgement, isFalse);
    // C'est cette notification qui debloque l'ecran (W2) : sans elle,
    // l'acquittement serait persiste et l'usager resterait bloque.
    expect(notifications, 1);
  });

  test('stockage a la version courante : requiresAcknowledgement faux '
      '(UC-006 A1, l ecran ne reapparait pas)', () async {
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble()
        ..storedVersion = currentVersion,
      currentWarningVersion: currentVersion,
    );

    await viewModel.load();

    expect(viewModel.requiresAcknowledgement, isFalse);
  });

  test(
    'stockage a une version differente de la courante : '
    'requiresAcknowledgement vrai (UC-006 A3, le texte a change, il est relu)',
    () async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble()
          ..storedVersion = currentVersion,
        currentWarningVersion: '2026-10-01.1',
      );

      await viewModel.load();

      expect(viewModel.requiresAcknowledgement, isTrue);
    },
  );

  test('stockage a une chaine vide : requiresAcknowledgement vrai — une chaine '
      "vide n'est pas une version acquittee", () async {
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble()..storedVersion = '',
      currentWarningVersion: currentVersion,
    );

    await viewModel.load();

    expect(viewModel.requiresAcknowledgement, isTrue);
  });

  test('echec de lecture du stockage : requiresAcknowledgement vrai — on '
      "rebloque, on n'ouvre pas", () async {
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble()
        ..readError = const FormatException('stockage illisible'),
      currentWarningVersion: currentVersion,
    );

    await viewModel.load();

    expect(viewModel.requiresAcknowledgement, isTrue);
  });

  test('echec d ecriture : etat reste a acquitter, error posee, une '
      'notification', () async {
    final _AcknowledgementRepositoryDouble repository =
        _AcknowledgementRepositoryDouble()
          ..writeError = const FormatException('ecriture impossible');
    final WarningsViewModel viewModel = WarningsViewModel(
      acknowledgements: repository,
      currentWarningVersion: currentVersion,
    );
    await viewModel.load();
    viewModel.toggleCheckbox(true);
    int notifications = 0;
    viewModel.addListener(() => notifications++);

    await viewModel.acknowledge();

    expect(viewModel.requiresAcknowledgement, isTrue);
    expect(viewModel.error, isNotNull);
    expect(notifications, 1);
  });

  test(
    'apres dispose() pendant une ecriture en vol : aucune notification',
    () async {
      final _AcknowledgementRepositoryDouble repository =
          _AcknowledgementRepositoryDouble()..writeGate = Completer<void>();
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: repository,
        currentWarningVersion: currentVersion,
      );
      await viewModel.load();
      viewModel.toggleCheckbox(true);
      int notifications = 0;
      viewModel.addListener(() => notifications++);

      final Future<void> pending = viewModel.acknowledge();
      viewModel.dispose();
      repository.writeGate!.complete();
      await pending;

      expect(notifications, 0);
    },
  );

  test('version courante vide leve un ArgumentError a la construction : une '
      'version vide ne peut etre ni comparee ni ecrite', () {
    expect(
      () => WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: '',
      ),
      throwsArgumentError,
    );
  });
}

// Verrouille `InitialWarningView` (`UC-006`, `BR-012`, tâche `W2`) : le
// bouton reste inactif tant que la case est décochée, sans pré-cochage, le
// texte n'est jamais tronqué (y compris à 200 % de police), et l'écran est
// une région d'alerte pour le lecteur d'écran.
//
// Ce widget n'appelle aucun dépôt ni aucun réseau : il observe le
// `WarningsViewModel` qu'on lui passe, construit directement dans ce
// fichier avec un double de dépôt en mémoire — même style que
// `test/features/warnings/view_model/warnings_view_model_test.dart`.
//
// ⚠️ Le lien « Relire le détail des sources » est RETIRÉ en T1 (arbitrage
// du commanditaire, 2026-09-22) : aucun test ne le cherche plus ici. La
// vue n'a plus de callback `onAcknowledged` non plus (YAGNI, CLAUDE.md) :
// la bascule vers la carte passe par le `ListenableBuilder` de
// `main.dart` sur `requiresAcknowledgement` — c'est donc l'ÉCRITURE dans
// le dépôt (`repository.written`), pas un callback, qui prouve qu'un tap
// sur le bouton actif a bien acquitté.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/warnings/view/initial_warning_view.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';

const String _currentVersion = '2026-09-13.1';

/// Double minimal de [AcknowledgementRepository] : rien n'est jamais
/// acquitté au départ, l'écriture peut être programmée pour échouer, et
/// chaque écriture réussie est journalisée — même style que
/// `test/features/warnings/view_model/warnings_view_model_test.dart`.
final class _AcknowledgementRepositoryDouble
    implements AcknowledgementRepository {
  String? storedVersion;
  Object? writeError;
  final List<String> written = <String>[];

  @override
  Future<String?> readAcknowledgedVersion() async => storedVersion;

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    written.add(version);
    storedVersion = version;
  }
}

_AcknowledgementRepositoryDouble _repository({Object? writeError}) =>
    _AcknowledgementRepositoryDouble()..writeError = writeError;

WarningsViewModel _viewModelFor(_AcknowledgementRepositoryDouble repository) =>
    WarningsViewModel(
      acknowledgements: repository,
      currentWarningVersion: _currentVersion,
    );

Widget _harness(WarningsViewModel viewModel) =>
    MaterialApp(home: InitialWarningView(viewModel: viewModel));

void main() {
  group('case et bouton', () {
    testWidgets('a l\'ouverture : case decochee, bouton desactive', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      final Checkbox checkbox = tester.widget<Checkbox>(
        find.byKey(initialWarningCheckboxKey),
      );
      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byKey(initialWarningButtonKey),
      );

      expect(checkbox.value, isFalse);
      expect(button.onPressed, isNull);
    });

    testWidgets('un tap sur la case l\'active, un second la desactive', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byKey(initialWarningCheckboxKey)).value,
        isTrue,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(initialWarningButtonKey))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byKey(initialWarningCheckboxKey)).value,
        isFalse,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(initialWarningButtonKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets(
      'tap sur le bouton actif : viewModel.acknowledge() ecrit une fois '
      'la version courante',
      (WidgetTester tester) async {
        final _AcknowledgementRepositoryDouble repository = _repository();
        await tester.pumpWidget(_harness(_viewModelFor(repository)));

        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(repository.written, <String>[_currentVersion]);
      },
    );

    testWidgets(
      'tap sur le bouton inactif : aucune ecriture (acknowledge() refuse '
      'sans case cochee)',
      (WidgetTester tester) async {
        final _AcknowledgementRepositoryDouble repository = _repository();
        await tester.pumpWidget(_harness(_viewModelFor(repository)));

        // La case reste decochee : le bouton est desactive, un tap sur sa
        // zone n'a aucun effet (Flutter n'invoque pas onPressed nul).
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(repository.written, isEmpty);
      },
    );

    testWidgets(
      'un echec d\'ecriture laisse l\'ecran bloque et expose l\'erreur du '
      'ViewModel',
      (WidgetTester tester) async {
        final _AcknowledgementRepositoryDouble repository = _repository(
          writeError: const FormatException('ecriture ko'),
        );
        final WarningsViewModel viewModel = _viewModelFor(repository);
        await tester.pumpWidget(_harness(viewModel));

        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(repository.written, isEmpty);
        expect(viewModel.requiresAcknowledgement, isTrue);
        expect(viewModel.error, isNotNull);
      },
    );
  });

  group('echec d\'enregistrement de l\'acquittement (UC-006 A6, arbitrage '
      'du 2026-09-22)', () {
    testWidgets('aucune phrase au premier affichage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      expect(find.text(initialWarningWriteFailedText), findsNothing);
    });

    testWidgets(
      'echec d\'ecriture : la phrase s\'affiche sous le bouton, le modal '
      'reste, la carte n\'est pas construite',
      (WidgetTester tester) async {
        final _AcknowledgementRepositoryDouble repository = _repository(
          writeError: const FormatException('ecriture ko'),
        );
        final WarningsViewModel viewModel = _viewModelFor(repository);
        await tester.pumpWidget(_harness(viewModel));

        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningWriteFailedText), findsOneWidget);
        expect(viewModel.requiresAcknowledgement, isTrue);
        expect(find.byType(InitialWarningView), findsOneWidget);

        final Finder phrase = find.text(initialWarningWriteFailedText);
        final Finder button = find.byKey(initialWarningButtonKey);
        expect(
          tester.getTopLeft(phrase).dy,
          greaterThan(tester.getBottomLeft(button).dy - 1),
        );
      },
    );

    testWidgets(
      'nouvel essai reussi : la phrase disparait et l\'acquittement est ecrit',
      (WidgetTester tester) async {
        final _AcknowledgementRepositoryDouble repository = _repository(
          writeError: const FormatException('ecriture ko'),
        );
        final WarningsViewModel viewModel = _viewModelFor(repository);
        await tester.pumpWidget(_harness(viewModel));

        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();
        expect(find.text(initialWarningWriteFailedText), findsOneWidget);

        repository.writeError = null;
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningWriteFailedText), findsNothing);
        expect(repository.written, <String>[_currentVersion]);
      },
    );

    testWidgets(
      'la phrase est annoncee au lecteur d\'ecran (region d\'alerte)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final _AcknowledgementRepositoryDouble repository = _repository(
          writeError: const FormatException('ecriture ko'),
        );
        final WarningsViewModel viewModel = _viewModelFor(repository);
        await tester.pumpWidget(_harness(viewModel));

        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        final SemanticsNode phrase = tester.getSemantics(
          find.byKey(initialWarningWriteFailedKey),
        );
        expect(phrase.getSemanticsData().flagsCollection.isLiveRegion, isTrue);

        handle.dispose();
      },
    );
  });

  group('libelle du bouton (BR-012)', () {
    testWidgets('est exactement "J\'ai compris ces limites"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      expect(find.text(initialWarningButtonLabel), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(find.text('Continuer'), findsNothing);
      expect(find.text('Fermer'), findsNothing);
    });
  });

  group('contenu du corps (UC-006 § 2)', () {
    testWidgets('contient les termes requis', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      expect(find.textContaining('indicatives'), findsWidgets);
      expect(find.textContaining('partielles'), findsWidgets);
      expect(find.textContaining('lâchers de barrage'), findsWidgets);
      expect(find.textContaining('arrêté préfectoral'), findsWidgets);
    });
  });

  group('typographie dynamique (UC-006 A4, 04-ui.md § 3)', () {
    testWidgets(
      'sur un format telephone, a 200% de police, le texte defile et reste '
      'atteignable jusqu\'au bouton',
      (WidgetTester tester) async {
        // Format téléphone (390 x 844 logiques, ratio 1) : c'est sur un
        // écran étroit, pas sur la fenêtre large des tests par défaut, que
        // `UC-006 A4` doit être prouvé — le contenu déborde vraiment.
        // Remis à zéro après le test : `tester.view` est partagé entre
        // tous les tests du binding.
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final _AcknowledgementRepositoryDouble repository = _repository();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _harness(_viewModelFor(repository)),
          ),
        );
        await tester.pumpAndSettle();

        // Aucune exception de rendu (dépassement, `RenderFlex overflowed`…) :
        // le texte défile au lieu d'être tronqué.
        expect(tester.takeException(), isNull);

        // Le défilement est réel, pas supposé : à 200 %, sur ce format, le
        // contenu dépasse la hauteur visible.
        final ScrollableState scrollable = tester.state(
          find.byType(Scrollable),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));

        // Atteignabilité de bout en bout : `ensureVisible` fait défiler
        // jusqu'à chaque contrôle avant de le taper — un contrôle qui ne
        // défilerait pas jusqu'à l'écran resterait inatteignable, pas
        // seulement invisible.
        await tester.ensureVisible(find.byKey(initialWarningCheckboxKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();

        await tester.ensureVisible(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(repository.written, <String>[_currentVersion]);
      },
    );

    testWidgets(
      "a la taille minimale de fenetre Windows (800 x 700, decision 8 "
      "amendee le 2026-09-23, K3) et 200% de police, le texte defile et "
      "reste atteignable jusqu'au bouton",
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final _AcknowledgementRepositoryDouble repository = _repository();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _harness(_viewModelFor(repository)),
          ),
        );
        await tester.pumpAndSettle();

        // Aucune exception de rendu (dépassement, `RenderFlex overflowed`…) :
        // le texte défile au lieu d'être tronqué, même sur ce format plus
        // large que le téléphone du test précédent.
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byKey(initialWarningCheckboxKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();

        await tester.ensureVisible(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();

        expect(repository.written, <String>[_currentVersion]);
      },
    );
  });

  group('accessibilite (UC-006 A5, 04-ui.md § 3)', () {
    testWidgets('l\'ecran est une region d\'alerte (liveRegion)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      final SemanticsNode region = tester.getSemantics(
        find.byKey(initialWarningRegionKey),
      );
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    testWidgets('l\'etat inactif du bouton est annonce, puis son activation', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_viewModelFor(_repository())));

      final SemanticsNode disabledButton = tester.getSemantics(
        find.byKey(initialWarningButtonKey),
      );
      expect(
        disabledButton.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();

      final SemanticsNode enabledButton = tester.getSemantics(
        find.byKey(initialWarningButtonKey),
      );
      expect(
        enabledButton.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isTrue,
      );

      handle.dispose();
    });
  });
}

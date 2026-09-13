// Le second verrou d'architecture, et il en faut un second : depuis
// l'arbitrage du 2026-09-13 (ADR-014, feature-first + MVVM), les frontieres a
// tenir ne sont plus seulement « aucune infrastructure sous lib/domain/ »
// — c'est ce que verrouille `domain_isolation_test.dart`, qui reste le
// premier test du projet et n'est pas touche ici. Ce fichier le **complete**
// avec les quatre regles de couches que la nouvelle disposition introduit, et
// qu'aucun lint de la chaine Dart ne sait exprimer :
//
// 1. `domaine-ferme` — un fichier de `domain/` n'importe rien du projet hors
//    `domain/`. Le domaine porte les invariants : s'il connait un depot
//    concret, un ViewModel ou un widget, ces invariants ne sont plus
//    testables sans eux (BR-002). La moitie « aucune infrastructure »
//    (paquets, `dart:io`, `dart:ui`) reste dans
//    `domain_isolation_test.dart` : ce fichier ne la recopie pas.
// 2. `data-vers-features` — un fichier de `data/` n'importe aucune tranche de
//    fonctionnalite. Les donnees sont partagees par toutes les tranches ;
//    l'inverse ferait d'une tranche une dependance de la couche commune, et
//    la seconde tranche heriterait de la premiere sans l'avoir demande.
//    C'est exactement la dependance qui s'etait glissee dans
//    `application/handlers.dart` au temps du registre de messages, et que
//    rien ne voyait.
// 3. `view-model-sans-widget` — un fichier sous `view_model/` n'importe ni
//    `material.dart`, ni `widgets.dart`, ni `cupertino.dart`. Un ViewModel
//    qui connait un widget se teste en montant un arbre de widgets, donc
//    lentement et par le rendu : la regle metier finit dans la vue.
//    `package:flutter/foundation.dart` reste autorise — c'est de la ou vient
//    `ChangeNotifier`, qui n'est pas un widget.
// 4. `feature-vers-feature` — une tranche n'importe pas une autre tranche.
//    Deux tranches qui se citent ne sont plus deux tranches : ce qu'elles
//    partagent appartient a `domain/` ou a `data/`.
//
// On lit le **texte** des directives, pas un arbre syntaxique : plus
// grossier, mais sans dependance d'analyse et sans panne silencieuse — un
// commentaire qui nomme un import interdit n'est pas une dependance. Meme
// choix que `domain_isolation_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prefixe des imports internes au projet.
const String selfPackagePrefix = 'package:martinpecheur/';

/// Les bibliotheques de widgets : interdites a un ViewModel.
const List<String> widgetLibraries = <String>[
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
];

/// Un manquement releve : la regle violee, le fichier (chemin relatif a la
/// racine parcourue), la ligne, et l'import fautif. [toString] est ce qui
/// s'affiche dans le message d'echec — il doit suffire a corriger sans
/// relire le test.
final class LayerViolation {
  const LayerViolation({
    required this.rule,
    required this.path,
    required this.line,
    required this.importUri,
  });

  /// Le nom de la regle violee, tel que l'en-tete de ce fichier l'enonce.
  final String rule;

  /// Chemin du fichier fautif, relatif a la racine parcourue, en `/`.
  final String path;

  /// Numero de ligne de la directive, a partir de 1.
  final int line;

  /// L'URI importee, telle qu'elle est ecrite.
  final String importUri;

  @override
  String toString() => '$rule — $path:$line importe $importUri';
}

/// Une directive lue : le fichier, la ligne, l'URI.
final class _Directive {
  const _Directive(this.path, this.line, this.uri);

  final String path;
  final int line;
  final String uri;
}

/// Extrait l'URI d'une ligne `import '…';` ou `export '…';`, ou `null` si la
/// ligne n'est pas une directive. Les guillemets simples et doubles sont
/// acceptes.
String? _uriOf(String line) {
  if (!line.startsWith('import ') && !line.startsWith('export ')) {
    return null;
  }

  final RegExpMatch? match = RegExp('''['"]([^'"]+)['"]''').firstMatch(line);
  return match?.group(1);
}

/// Lit toutes les directives des fichiers `.dart` sous [root], chemins
/// **relatifs a [root]** et separes par `/` — c'est ce qui rend les regles
/// testables sur un dossier temporaire aussi bien que sur `lib/`. Un [root]
/// absent rend une liste vide.
List<_Directive> _directivesUnder(Directory root) {
  if (!root.existsSync()) {
    return <_Directive>[];
  }

  final String rootPath = root.path.replaceAll(r'\', '/');
  final List<_Directive> directives = <_Directive>[];

  for (final FileSystemEntity entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    String relative = entity.path.replaceAll(r'\', '/');
    if (relative.startsWith(rootPath)) {
      relative = relative.substring(rootPath.length);
    }
    relative = relative.startsWith('/') ? relative.substring(1) : relative;

    final List<String> lines = entity.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final String? uri = _uriOf(lines[i]);
      if (uri != null) {
        directives.add(_Directive(relative, i + 1, uri));
      }
    }
  }

  return directives;
}

/// Le premier segment d'une tranche : `features/map/view/x.dart` → `map`.
/// Rend `null` si le chemin n'est pas sous `features/<nom>/`.
String? _featureOf(String path) {
  final List<String> segments = path.split('/');
  if (segments.length < 3 || segments.first != 'features') {
    return null;
  }
  return segments[1];
}

/// Applique les quatre regles de couches aux fichiers sous [root], traite
/// comme s'il etait `lib/` : les chemins releves sont relatifs a [root]
/// (`domain/…`, `data/…`, `features/<tranche>/…`).
List<LayerViolation> layerViolationsUnder(Directory root) {
  final List<LayerViolation> violations = <LayerViolation>[];

  for (final _Directive directive in _directivesUnder(root)) {
    final String path = directive.path;
    final String uri = directive.uri;

    void record(String rule) {
      violations.add(
        LayerViolation(
          rule: rule,
          path: path,
          line: directive.line,
          importUri: uri,
        ),
      );
    }

    // 1 — le domaine ne connait que le domaine.
    if (path.startsWith('domain/') &&
        uri.startsWith(selfPackagePrefix) &&
        !uri.startsWith('${selfPackagePrefix}domain/')) {
      record('domaine-ferme');
    }

    // 2 — les donnees ne connaissent aucune tranche.
    if (path.startsWith('data/') &&
        uri.startsWith('${selfPackagePrefix}features/')) {
      record('data-vers-features');
    }

    // 3 — un ViewModel ne connait aucun widget.
    if (path.contains('view_model/') && widgetLibraries.contains(uri)) {
      record('view-model-sans-widget');
    }

    // 4 — une tranche n'en importe pas une autre.
    final String? feature = _featureOf(path);
    if (feature != null && uri.startsWith('${selfPackagePrefix}features/')) {
      final String importedFeature = uri
          .substring('${selfPackagePrefix}features/'.length)
          .split('/')
          .first;
      if (importedFeature != feature) {
        record('feature-vers-feature');
      }
    }
  }

  return violations;
}

/// Ecrit [content] dans `<root>/<relative>`, dossiers crees au besoin.
void _writeTemp(Directory root, String relative, String content) {
  final File file = File('${root.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Un dossier temporaire, supprime en fin de test.
Directory _tempRoot(String prefix) {
  final Directory root = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });
  return root;
}

void main() {
  group('Couches MVVM (ADR-014)', () {
    test('lib/ respecte les quatre regles de couches', () {
      final List<LayerViolation> violations = layerViolationsUnder(
        Directory('lib'),
      );

      expect(
        violations,
        isEmpty,
        reason:
            'Une frontiere de couche est franchie. Les quatre regles sont '
            "enoncees en tete de ce fichier, avec la raison d'etre de "
            'chacune. Manquements : '
            '${violations.map((LayerViolation v) => v.toString()).join(' · ')}',
      );
    });

    test('un dossier absent ou un dossier vide ne relevent rien', () {
      expect(layerViolationsUnder(Directory('lib_absent')), isEmpty);
      expect(layerViolationsUnder(_tempRoot('layers_vide_')), isEmpty);
    });

    test('domaine-ferme : un fichier de domain/ qui importe data/ est '
        'releve, un import interne au domaine ne l\'est pas', () {
      final Directory root = _tempRoot('layers_domaine_');
      _writeTemp(
        root,
        'domain/station/offender.dart',
        "import 'package:martinpecheur/data/referentiel/stations_asset.dart';\n",
      );
      _writeTemp(
        root,
        'domain/geo/innocent.dart',
        "import 'dart:math';\n"
            "import 'package:martinpecheur/domain/station/station.dart';\n"
            '// pas une dependance : mention de '
            'package:martinpecheur/features/map/ en commentaire\n',
      );

      final List<LayerViolation> violations = layerViolationsUnder(root);

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'domaine-ferme');
      expect(violations.single.path, 'domain/station/offender.dart');
      expect(violations.single.toString(), contains('offender.dart:1'));
    });

    test('data-vers-features : un fichier de data/ qui importe une tranche '
        'est releve', () {
      final Directory root = _tempRoot('layers_data_');
      _writeTemp(
        root,
        'data/referentiel/offender.dart',
        "import 'package:martinpecheur/domain/station/station.dart';\n"
            "import 'package:martinpecheur/features/map/view/map_view.dart';\n",
      );

      final List<LayerViolation> violations = layerViolationsUnder(root);

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'data-vers-features');
      expect(violations.single.line, 2);
    });

    test('view-model-sans-widget : les trois bibliotheques de widgets sont '
        'relevees, foundation.dart ne l\'est pas', () {
      final Directory root = _tempRoot('layers_view_model_');
      _writeTemp(
        root,
        'features/map/view_model/offender.dart',
        "import 'package:flutter/material.dart';\n"
            "import 'package:flutter/widgets.dart';\n"
            "import 'package:flutter/cupertino.dart';\n",
      );
      _writeTemp(
        root,
        'features/map/view_model/innocent.dart',
        "import 'package:flutter/foundation.dart' show ChangeNotifier;\n",
      );

      final List<LayerViolation> violations = layerViolationsUnder(root);

      expect(violations, hasLength(3));
      expect(violations.map((LayerViolation v) => v.rule).toSet(), <String>{
        'view-model-sans-widget',
      });
      expect(
        violations.map((LayerViolation v) => v.importUri).toSet(),
        widgetLibraries.toSet(),
      );
    });

    test('feature-vers-feature : une tranche qui importe une autre tranche '
        "est relevee, un import dans sa propre tranche ne l'est pas", () {
      final Directory root = _tempRoot('layers_features_');
      _writeTemp(
        root,
        'features/map/view/offender.dart',
        "import 'package:martinpecheur/features/map/view_model/"
            "map_view_model.dart';\n"
            "import 'package:martinpecheur/features/station/view/fiche.dart';\n",
      );

      final List<LayerViolation> violations = layerViolationsUnder(root);

      expect(violations, hasLength(1));
      expect(violations.single.rule, 'feature-vers-feature');
      expect(violations.single.importUri, contains('features/station/'));
    });
  });
}

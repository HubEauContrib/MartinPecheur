// Le balayage MÉCANIQUE du vocabulaire proscrit (`BR-003`, `BR-007`,
// `BR-014`), sur les littéraux de chaîne de `lib/domain/` et
// `lib/features/` — jamais `lib/data/`, qui ne produit aucun texte affiché
// mais cite des URL et des champs d'API (`Task W5` du plan T1, révision du
// 2026-09-22 ; relecture et arbitrages du commanditaire du 2026-09-23).
//
// Les COMMENTAIRES sont retirés avant balayage (`//`, `///`, `/* */`) : un
// commentaire qui cite `BR-003` pour expliquer pourquoi un mot est banni ne
// doit pas rendre le test rouge lui-même. Les littéraux ADJACENTS (deux
// tokens de chaîne collés, séparés seulement par des espaces ou des
// COMMENTAIRES — arbitrage du 2026-09-23) sont concaténés avant balayage,
// comme le ferait le compilateur Dart : un mot banni coupé entre deux
// fragments ne doit pas échapper au test.
//
// Le contenu d'une INTERPOLATION (`${expr}`) est balayé RÉCURSIVEMENT :
// toute chaîne littérale qu'elle contient (par exemple une branche d'un
// opérateur ternaire) est elle-même un texte qui peut finir à l'écran, donc
// un littéral à part entière — arbitrage du 2026-09-23. Un `}` rencontré à
// l'intérieur d'une chaîne imbriquée à cette interpolation ne referme pas
// l'interpolation : il fait partie de cette chaîne imbriquée.
//
// Les séquences d'échappement `\uXXXX` et `\u{...}` sont DÉCODÉES avant
// balayage (arbitrage du 2026-09-23) : un mot écrit en échappements
// unicode reste le même mot.
//
// La correspondance se fait en MOT ENTIER, insensible à la casse, par
// `(?<!\p{L})mot(?!\p{L})` compilée `caseSensitive: false, unicode: true` —
// jamais `\b`, qui ne connaît que l'ASCII en Dart et couperait « sûr » ou
// « vérifié » sur leur lettre accentuée.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'vocabulary_lists.dart';

/// Un littéral de chaîne LOGIQUE : le texte d'un ou plusieurs tokens de
/// chaîne adjacents, concaténés comme le fait le compilateur Dart, avec
/// commentaires retirés, échappements décodés et interpolations (`$x`,
/// `${expr}`) neutralisées dans le texte englobant (remplacées par un
/// espace — ce ne sont jamais des mots fixes) mais balayées séparément :
/// voir [_extractLogicalStringLiterals].
class _Literal {
  _Literal(this.text, this.line);

  final String text;
  final int line;
}

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || c == 0x5f;

bool _isIdentPart(int c) => _isIdentStart(c) || (c >= 0x30 && c <= 0x39);

bool _isHexDigit(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x46) ||
    (c >= 0x61 && c <= 0x66);

/// Décode l'échappement démarrant en `source[j]` (`source[j] == '\'`) :
/// `\uXXXX`, `\u{H..H}` (1 à 6 chiffres hexa), `\xXX`, les échappements à
/// un caractère (`\n`, `\t`, `\r`, `\b`, `\f`, `\v`), et par défaut le
/// caractère suivant pris tel quel (`\'`, `\"`, `\\`, `\$`). Rend le texte
/// décodé et l'index juste après l'échappement.
({String text, int nextIndex}) _decodeEscape(String source, int j) {
  final int len = source.length;
  final String next = source[j + 1];

  if (next == 'u' && j + 2 < len && source[j + 2] == '{') {
    final int close = source.indexOf('}', j + 3);
    if (close != -1) {
      final String hex = source.substring(j + 3, close);
      final int? codePoint = int.tryParse(hex, radix: 16);
      if (codePoint != null) {
        return (text: String.fromCharCode(codePoint), nextIndex: close + 1);
      }
    }
  }
  if (next == 'u' &&
      j + 5 < len &&
      _isHexDigit(source.codeUnitAt(j + 2)) &&
      _isHexDigit(source.codeUnitAt(j + 3)) &&
      _isHexDigit(source.codeUnitAt(j + 4)) &&
      _isHexDigit(source.codeUnitAt(j + 5))) {
    final String hex = source.substring(j + 2, j + 6);
    return (
      text: String.fromCharCode(int.parse(hex, radix: 16)),
      nextIndex: j + 6,
    );
  }
  if (next == 'x' &&
      j + 3 < len &&
      _isHexDigit(source.codeUnitAt(j + 2)) &&
      _isHexDigit(source.codeUnitAt(j + 3))) {
    final String hex = source.substring(j + 2, j + 4);
    return (
      text: String.fromCharCode(int.parse(hex, radix: 16)),
      nextIndex: j + 4,
    );
  }

  const Map<String, String> singleCharEscapes = <String, String>{
    'n': '\n',
    't': '\t',
    'r': '\r',
    'b': '\b',
    'f': '\f',
    'v': '\v',
  };
  final String decoded = singleCharEscapes[next] ?? next;
  return (text: decoded, nextIndex: j + 2);
}

/// Trouve la fin (index du `}` inclus) de l'interpolation dont le contenu
/// commence en `start` (juste après `${`), en ignorant tout `}` qui vit à
/// l'intérieur d'une chaîne imbriquée — cette chaîne peut elle-même
/// contenir une interpolation, d'où la récursion mutuelle avec
/// [_skipNestedStringLiteral].
int _findInterpolationEnd(String source, int start) {
  final int len = source.length;
  int depth = 1;
  int i = start;
  while (i < len && depth > 0) {
    final String c = source[i];
    if (c == "'" || c == '"') {
      i = _skipNestedStringLiteral(source, i);
      continue;
    }
    if (c == 'r' &&
        i + 1 < len &&
        (source[i + 1] == "'" || source[i + 1] == '"')) {
      i = _skipNestedStringLiteral(source, i);
      continue;
    }
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return i < len ? i : len - 1;
}

/// Saute une chaîne imbriquée à l'intérieur d'une interpolation, en
/// respectant ses propres échappements et ses propres interpolations (dont
/// un `}` ne referme donc jamais l'interpolation englobante). Rend l'index
/// juste après le délimiteur fermant.
int _skipNestedStringLiteral(String source, int i) {
  final int len = source.length;
  bool isRaw = false;
  int quoteStart = i;
  if (source[i] == 'r') {
    isRaw = true;
    quoteStart = i + 1;
  }
  final String qc = source[quoteStart];
  final bool triple =
      quoteStart + 2 < len &&
      source[quoteStart + 1] == qc &&
      source[quoteStart + 2] == qc;
  final String delim = triple ? qc * 3 : qc;
  int j = quoteStart + delim.length;
  while (j < len) {
    if (source.startsWith(delim, j)) {
      return j + delim.length;
    }
    if (!isRaw && source[j] == r'\') {
      j += 2;
      continue;
    }
    if (!isRaw && source[j] == r'$' && j + 1 < len && source[j + 1] == '{') {
      j = _findInterpolationEnd(source, j + 2) + 1;
      continue;
    }
    j++;
  }
  return len;
}

/// Extrait les littéraux de chaîne LOGIQUES d'une source Dart : un petit
/// automate à états, pas une regex — une regex ne sait pas distinguer un
/// `//` de division d'un `//` de commentaire, ni un `//` dans une URL
/// (`ign_tile_template.dart`) d'un vrai commentaire.
List<_Literal> _extractLogicalStringLiterals(String source) {
  final List<_Literal> literals = <_Literal>[];
  final int len = source.length;
  int i = 0;
  int line = 1;

  StringBuffer? current;
  int? currentStartLine;

  void flush() {
    if (current != null) {
      literals.add(_Literal(current.toString(), currentStartLine!));
      current = null;
      currentStartLine = null;
    }
  }

  while (i < len) {
    final String c = source[i];

    if (c == '\n') {
      line++;
      i++;
      continue;
    }
    if (c == ' ' || c == '\t' || c == '\r') {
      i++;
      continue;
    }

    // Commentaire de ligne. Ne referme PAS le littéral logique en cours
    // (arbitrage du 2026-09-23) : deux littéraux séparés seulement par un
    // commentaire restent adjacents, comme s'ils n'étaient séparés que par
    // des espaces.
    if (c == '/' && i + 1 < len && source[i + 1] == '/') {
      final int nl = source.indexOf('\n', i);
      i = nl == -1 ? len : nl;
      continue;
    }
    // Commentaire de bloc — même règle.
    if (c == '/' && i + 1 < len && source[i + 1] == '*') {
      final int end = source.indexOf('*/', i + 2);
      final String skipped = end == -1
          ? source.substring(i)
          : source.substring(i, end + 2);
      for (final int rune in skipped.runes) {
        if (rune == 0x0A) line++;
      }
      i = end == -1 ? len : end + 2;
      continue;
    }

    // Chaîne brute r'...' / r"...".
    bool isRaw = false;
    int quoteStart = i;
    if (c == 'r' &&
        i + 1 < len &&
        (source[i + 1] == "'" || source[i + 1] == '"')) {
      isRaw = true;
      quoteStart = i + 1;
    }

    if (quoteStart < len &&
        (source[quoteStart] == "'" || source[quoteStart] == '"')) {
      final String qc = source[quoteStart];
      final bool triple =
          quoteStart + 2 < len &&
          source[quoteStart + 1] == qc &&
          source[quoteStart + 2] == qc;
      final String delim = triple ? qc * 3 : qc;
      final int startLine = line;
      int j = quoteStart + delim.length;
      final StringBuffer buf = StringBuffer();

      while (j < len) {
        if (source.startsWith(delim, j)) {
          j += delim.length;
          break;
        }
        final String ch = source[j];
        if (ch == '\n') {
          line++;
          buf.write(' ');
          j++;
          continue;
        }
        if (!isRaw && ch == r'\') {
          final ({String text, int nextIndex}) decoded = _decodeEscape(
            source,
            j,
          );
          for (final int rune in decoded.text.runes) {
            if (rune == 0x0A) line++;
          }
          buf.write(decoded.text);
          j = decoded.nextIndex;
          continue;
        }
        if (!isRaw && ch == r'$' && j + 1 < len) {
          if (source[j + 1] == '{') {
            final int interpStart = j + 2;
            final int interpEnd = _findInterpolationEnd(source, interpStart);
            final String inner = source.substring(interpStart, interpEnd);
            final int innerStartLine = line;
            for (final _Literal nested in _extractLogicalStringLiterals(
              inner,
            )) {
              literals.add(
                _Literal(nested.text, innerStartLine + nested.line - 1),
              );
            }
            for (final int rune in inner.runes) {
              if (rune == 0x0A) line++;
            }
            buf.write(' ');
            j = interpEnd + 1;
            continue;
          } else if (_isIdentStart(source.codeUnitAt(j + 1))) {
            int k = j + 1;
            while (k < len && _isIdentPart(source.codeUnitAt(k))) {
              k++;
            }
            buf.write(' ');
            j = k;
            continue;
          }
        }
        buf.write(ch);
        j++;
      }

      i = j;
      current ??= StringBuffer();
      currentStartLine ??= startLine;
      current!.write(buf.toString());
      continue;
    }

    // Code ordinaire : rien à balayer, mais un littéral en cours doit être
    // clos — deux littéraux ne sont adjacents que s'ils ne sont séparés que
    // par des espaces ou des commentaires, jamais par du vrai code.
    flush();
    i++;
  }
  flush();
  return literals;
}

/// Compile un motif de MOT ENTIER (au sens `\p{L}`, pas `\b`) pour [word],
/// insensible à la casse. [word] peut être une locution (« tout va bien »)
/// : la frontière ne porte que sur ses deux extrémités.
RegExp _wholeWordPattern(String word) {
  final String escaped = RegExp.escape(word);
  return RegExp(
    '(?<!\\p{L})$escaped(?!\\p{L})',
    caseSensitive: false,
    unicode: true,
  );
}

Iterable<File> _dartFilesUnder(String relativeDir) sync* {
  final Directory dir = Directory(relativeDir);
  if (!dir.existsSync()) return;
  for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

/// Chemin relatif à la racine du dépôt, séparateurs `/` — indépendant de la
/// plateforme d'exécution (Windows rend des `\`).
String _repoRelativePath(File file) => file.path.replaceAll(r'\', '/');

void main() {
  final List<String> allBannedWords = <String>[
    ...forbiddenFlowWords,
    ...forbiddenNeutralityPhrases,
    ...forbiddenGuaranteeWords,
  ];

  // Motifs compilés UNE SEULE FOIS (arbitrage du 2026-09-23) : recompiler
  // une `RegExp` par littéral et par mot, à chaque fichier, était un coût
  // inutile — la compilation ne dépend que de [allBannedWords].
  final Map<String, RegExp> patterns = <String, RegExp>{
    for (final String word in allBannedWords) word: _wholeWordPattern(word),
  };

  group('_extractLogicalStringLiterals (l\'automate lui-meme)', () {
    test('retire les commentaires de ligne et de bloc', () {
      const String source = '''
// un commentaire qui dit normal
const String a = 'texte propre'; /* bloc */
''';
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.map((_Literal l) => l.text), <String>['texte propre']);
    });

    test('concatène deux littéraux adjacents en un seul littéral logique', () {
      const String source = '''
const String a = 'debit '
    'normal';
''';
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.map((_Literal l) => l.text), <String>['debit normal']);
    });

    test('un commentaire ENTRE deux littéraux adjacents ne les sépare pas '
        '(arbitrage du 2026-09-23)', () {
      const String source = '''
const String a = 'tout va ' // un commentaire
    'bien';
''';
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.map((_Literal l) => l.text), <String>['tout va bien']);
      expect(patterns['tout va bien']!.hasMatch(literals.single.text), isTrue);
    });

    test('ne casse pas sur un "//" a l\'interieur d\'une chaine (URL)', () {
      const String source = "const String u = 'https://example.org/x';";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, 'https://example.org/x');
    });

    test('un commentaire de bloc suivi immediatement d\'une apostrophe ne '
        'corrompt pas le litteral qui suit', () {
      const String source = r"""
/* commentaire */ const String a = "l'eau";
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, "l'eau");
    });

    test('une chaine entre doubles guillemets porte une apostrophe non '
        'echappee ("l\'eau")', () {
      const String source = r'''
const String a = "l'eau";
''';
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, "l'eau");
    });

    test('une apostrophe echappee (\\\') dans une chaine simple-guillemet '
        'est decodee', () {
      const String source = r"""
const String a = 'l\'eau';
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, "l'eau");
    });

    test('chaine brute r\'...\' : aucun decodage, prise telle quelle', () {
      const String source = r"""
const String a = r'\n normal \n';
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, r'\n normal \n');
    });

    test(
      'chaine triple simple-guillemet \'\'\'...\'\'\' garde son contenu',
      () {
        const String source = "const String a = '''un texte normal''';";
        final List<_Literal> literals = _extractLogicalStringLiterals(source);
        expect(literals.single.text, 'un texte normal');
      },
    );

    test('chaine triple double-guillemet """...""" garde apostrophes et '
        'guillemets internes', () {
      const String source = '''
const String a = """il dit "normal" et c'est faux""";
''';
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, '''il dit "normal" et c'est faux''');
    });

    test('decode \\uXXXX avant balayage ("vérifié")', () {
      const String source = r"""
const String a = 'vérifié';
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, 'vérifié');
      expect(patterns['vérifié']!.hasMatch(literals.single.text), isTrue);
    });

    test('decode \\u{...} avant balayage ("vérifié")', () {
      const String source = r"""
const String a = 'v\u{e9}rifi\u{e9}';
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      expect(literals.single.text, 'vérifié');
    });

    test(
      'neutralise une interpolation simple sans casser le reste du texte',
      () {
        const String source = r"""
const String a = 'debut ${x} fin';
""";
        final List<_Literal> literals = _extractLogicalStringLiterals(source);
        expect(literals.single.text, 'debut   fin');
      },
    );

    test('balaie recursivement le contenu d\'une interpolation ternaire '
        '(arbitrage du 2026-09-23)', () {
      const String source = r"""
const String a = '${c ? 'débit normal' : ''}';
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      final List<String> texts = literals.map((_Literal l) => l.text).toList();
      expect(texts, contains('débit normal'));
      expect(texts.any((String t) => patterns['normal']!.hasMatch(t)), isTrue);
    });

    test('un "}" a l\'interieur d\'une chaine imbriquee ne referme pas '
        'l\'interpolation englobante', () {
      const String source = r"""
const String a = "${cond ? 'a}b' : 'normal'}";
""";
      final List<_Literal> literals = _extractLogicalStringLiterals(source);
      final List<String> texts = literals.map((_Literal l) => l.text).toList();
      expect(texts, contains('a}b'));
      expect(texts, contains('normal'));
    });
  });

  group('mots entiers (?<!\\p{L})mot(?!\\p{L})', () {
    test('« assec » en minuscules, hors nom de type, est detecte', () {
      expect(patterns['assec']!.hasMatch("zone d'assec"), isTrue);
    });

    test('« anormal » n\'est pas confondu avec « normal »', () {
      expect(patterns['normal']!.hasMatch('anormal'), isFalse);
    });

    test(
      '« officielle » est desormais une flexion listee (B2, 2026-09-23)',
      () {
        expect(patterns['officielle']!.hasMatch('officielle'), isTrue);
        expect(patterns['officiel']!.hasMatch('officielle'), isFalse);
      },
    );

    test('« sûr » est détecté malgré son accent (pas « \\b » ASCII)', () {
      expect(patterns['sûr']!.hasMatch('un debit sûr'), isTrue);
      expect(patterns['sûr']!.hasMatch('sûreté'), isFalse);
    });

    test(
      '« dans la normale » est detecte comme locution (glossary.md l.44)',
      () {
        expect(
          patterns['dans la normale']!.hasMatch('un debit dans la normale'),
          isTrue,
        );
      },
    );
  });

  group('table des exceptions', () {
    test("chaque exception nommee existe verbatim dans son fichier", () {
      for (final MapEntry<String, List<String>> entry
          in vocabularyExceptions.entries) {
        final String path = entry.key;
        final File file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Exception déclarée pour un fichier introuvable : $path',
        );
        final List<_Literal> literals = _extractLogicalStringLiterals(
          file.readAsStringSync(),
        );
        final Set<String> texts = literals.map((_Literal l) => l.text).toSet();
        for (final String literal in entry.value) {
          expect(
            texts.contains(literal),
            isTrue,
            reason:
                'Exception périmée : le littéral "$literal" n\'existe '
                'plus dans $path — une exception périmée est une porte '
                'ouverte (Task W5).',
          );
        }
      }
    });

    test('l\'exception du service externe de secheresse est declaree ET vide '
        '(aucune source en T1)', () {
      expect(vigieauLabelExceptions, isEmpty);
    });
  });

  test(
    'aucun littéral de chaîne de lib/domain/ ni de lib/features/ ne contient '
    'un mot proscrit (BR-003, BR-007, BR-014), sauf exception nominative',
    () {
      final List<String> violations = <String>[];

      for (final File file in <File>[
        ..._dartFilesUnder('lib/domain'),
        ..._dartFilesUnder('lib/features'),
      ]) {
        final String path = _repoRelativePath(file);
        final List<_Literal> literals = _extractLogicalStringLiterals(
          file.readAsStringSync(),
        );
        final List<String> admitted = vocabularyExceptions[path] ?? const [];

        for (final _Literal literal in literals) {
          for (final String word in allBannedWords) {
            if (patterns[word]!.hasMatch(literal.text)) {
              if (admitted.contains(literal.text)) continue;
              violations.add(
                '$path:${literal.line} — mot "$word" dans "${literal.text}"',
              );
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Vocabulaire proscrit trouvé (BR-003, BR-007, BR-014) :\n'
            '${violations.join('\n')}',
      );
    },
  );
}

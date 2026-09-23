// Les trois listes de vocabulaire proscrit balayées par `vocabulary_test.dart`,
// et la table des exceptions nominatives. Elles vivent SOUS `test/` — les
// poser sous `lib/` aurait fait que le balayage se serait trouvé lui-même
// (`Task W5` du plan T1, révision du 2026-09-22).
//
// Chaque mot est recopié d'une source datée : `docs/glossary.md` § «
// Vocabulaire proscrit », ou le corps d'une Business Rule. Le plan
// (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`,
// Task `W5`) en donne le minimum ; cette liste ajoute ce que ces mêmes
// sources citent en toutes lettres, jamais un mot inventé.
//
// La correspondance se fait en MOT ENTIER, insensible à la casse, par
// `vocabulary_test.dart` avec `(?<!\p{L})mot(?!\p{L})` compilée
// `caseSensitive: false, unicode: true` — jamais `\b`, qui ne connaît que
// l'ASCII en Dart et couperait « sûr » ou « vérifié » sur leur lettre
// accentuée.

/// Mots proscrits pour qualifier un débit ou un écoulement (`BR-003`,
/// `docs/glossary.md` lignes 43-45) : jamais « suffisant », jamais
/// « normal » ni « dans la normale » (`glossary.md` ligne 44) — la classe
/// médiane se dit « habituel pour la saison » (`BR-003`) — et un seul mot
/// pour le lit à sec, « à sec » (`glossary.md` ligne 45, « Un concept, un
/// mot »), jamais « assec », « tari » ni « asséché ».
///
/// **Formes fléchies incluses** (arbitrage du coordinateur du 2026-09-23,
/// relecture de `Task W5`) : un mot proscrit l'est sous toutes ses
/// flexions — le féminin et le pluriel ne créent pas un mot différent, ce
/// n'est donc pas en inventer un que de les lister. La correspondance reste
/// en mot entier (`vocabulary_test.dart`), donc chaque flexion est un
/// littéral séparé plutôt qu'un radical tronqué.
const List<String> forbiddenFlowWords = <String>[
  'suffisant',
  'suffisante',
  'suffisants',
  'suffisantes',
  'insuffisant',
  'insuffisante',
  'insuffisants',
  'insuffisantes',
  'normal',
  'normale',
  'normales',
  'normaux',
  'dans la normale',
  'bon',
  'bonne',
  'bonnes',
  'bons',
  'sûr',
  'sûre',
  'sûrs',
  'sûres',
  'assec',
  'assecs',
  'tari',
  'tarie',
  'taris',
  'taries',
  'asséché',
  'asséchée',
  'asséchés',
  'asséchées',
];

/// Formulations proscrites qui donneraient à une absence de donnée un air de
/// neutralité (`BR-007`, règle et § « Vérifiable par », ligne 51 : « aucune
/// occurrence de "rien à signaler", "tout va bien", "aucun problème" »).
const List<String> forbiddenNeutralityPhrases = <String>[
  'rien à signaler',
  'tout va bien',
  'aucun problème',
];

/// Mots de garantie proscrits (`BR-014` : « Aucun mot de garantie » ;
/// `docs/glossary.md` lignes 46-47 : « en direct », « temps réel »,
/// « fiable », « vérifié », « officiel »). « garantie » lui-même est ajouté :
/// c'est le mot que `BR-014` interdit d'affirmer (« Aucun mot de
/// garantie »), une négation explicite exigeant alors une exception
/// nominative.
const List<String> forbiddenGuaranteeWords = <String>[
  'fiable',
  'fiables',
  'vérifié',
  'vérifiée',
  'vérifiés',
  'vérifiées',
  'officiel',
  'officielle',
  'officiels',
  'officielles',
  'en direct',
  'temps réel',
  'garantie',
];

/// Exceptions nominatives au balayage, chacune un fichier **et** un
/// littéral exact — jamais un assouplissement du mot lui-même. Une
/// exception dont le littéral n'existe plus dans le fichier rend le test
/// rouge (`vocabulary_test.dart`) : une exception périmée est une porte
/// ouverte.
///
/// Chemins relatifs à la racine du dépôt, séparateurs `/`.
const Map<String, List<String>> vocabularyExceptions = <String, List<String>>{
  // `STYLE=normal` est un paramètre WMTS de l'IGN, pas un jugement sur un
  // débit (`lib/features/map/view/ign_tile_template.dart`, l. 18). Le
  // littéral ci-dessous est le gabarit d'URL complet : les trois segments
  // adjacents ne forment qu'UN SEUL littéral logique une fois concaténés.
  'lib/features/map/view/ign_tile_template.dart': <String>[
    'https://data.geopf.fr/wmts?SERVICE=WMTS&VERSION=1.0.0'
        '&REQUEST=GetTile&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal'
        '&TILEMATRIXSET=PM&FORMAT=image/png&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}',
  ],
  // `mapBannerText` (`W3`) portait « garantie » dans une NÉGATION : « Ni
  // autorisation, ni garantie. » Le texte disparaît avec le bandeau
  // (`W3c`, arbitrage du commanditaire du 2026-09-23) — l'exception n'a
  // plus de littéral à admettre et est retirée avec lui.
  // `noDataInAreaText` (`BR-007`, `U6`) porte « tout va bien » dans une
  // NÉGATION, recopiée du corps même de `BR-007` : « Ce n'est pas un signe
  // que tout va bien ». Les trois segments adjacents ne forment qu'UN SEUL
  // littéral logique une fois concaténés.
  'lib/features/map/view/map_empty_states.dart': <String>[
    "Il n'y a ni station de mesure ni point d'observation dans le secteur "
        "affiché. Ce n'est pas un signe que tout va bien : c'est simplement "
        'que personne ne mesure ici.',
  ],
  // « officielle » ATTRIBUE une nomenclature à sa source, ce que le
  // glossaire admet explicitement (`docs/glossary.md:47` : « sauf pour
  // attribuer une nomenclature à sa source, comme « Modalité officielle
  // ONDE : » ») — le mot qualifie l'origine, jamais nos données.
  // Arbitrage du coordinateur du 2026-09-23, dans la lettre du glossaire.
  'lib/features/onde_sheet/view/onde_summary_sheet.dart': <String>[
    'Modalité officielle ONDE : ',
  ],
  // Même règle : le libellé de repli dit que la modalité de la
  // nomenclature ONDE n'est pas fournie, il ne garantit rien.
  'lib/features/onde_sheet/view_model/onde_sheet_view_model.dart': <String>[
    'Modalité officielle non renseignée',
  ],
};

/// Les libellés cités du service externe de sécheresse sont les mots du
/// préfet, repris tels quels (`BR-014` : « Les libellés de restriction
/// repris de VigiEau sont cités tels quels »). Aucune source de ce type
/// n'existe en T1 (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`
/// § « Ce que T1 ne fait pas ») : l'exception est déclarée pour mémoire, et
/// **vide** — `vocabulary_test.dart` vérifie qu'elle le reste. Une
/// constante séparée plutôt qu'une fausse clé de chemin dans
/// [vocabularyExceptions] : elle ne nomme aucun fichier, elle ne devait
/// donc pas se faire passer pour un.
const List<String> vigieauLabelExceptions = <String>[];

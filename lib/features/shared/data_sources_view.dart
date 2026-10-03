// L'écran « D'où vient cette donnée ? » (T2, tâche `S1`, conception
// `docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md` § 8,
// arbitrage du commanditaire Q-8 (a) du 2026-09-29) : pour chaque source
// affichée par l'application, ce qu'elle est, ce qu'elle ne dit pas, sa
// licence. Il clôt `BR-012` : le lien « Relire le détail des sources » du
// modal du premier lancement, retiré en T1 faute d'écran, revient avec lui.
//
// Occupant de `lib/features/shared/` : DEUX consommateurs, le modal
// du premier lancement (tranche `warnings`) et la fenêtre d'avertissement
// ([WarningWindow], elle-même dans `shared/`), qui ouvre cet écran depuis la
// carte et depuis chaque fiche. Il n'importe aucune tranche
// (`shared-sans-tranche`, `test/architecture/layers_test.dart`).
//
// - ÉCRAN PLEIN, poussé par-dessus l'appelant (Q-8) : titre
//   [dataSourcesTitle], bouton de retour, contenu défilant. Le retour (bouton,
//   `Échap`, retour Android) retire la route par `Navigator.maybePop` : celui
//   qui l'a ouvert se retrouve tel qu'il l'a laissé — pour le modal, case à
//   cocher comprise, car son état vit dans `WarningsViewModel`. Aucun
//   ViewModel ici : l'écran n'a ni état, ni dépôt.
// - NOMS DE SOURCE par leurs constantes (`lib/domain/sources/source_names.dart`),
//   jamais recopiés. Le nom de la source des restrictions ne s'écrit pas en
//   toutes lettres hors de son module (confinement,
//   `test/data/restrictions/restriction_source_test.dart`) : il passe par
//   [restrictionsSourceName], interpolé.
// - TEXTES retenus par le commanditaire (conception § 8), mot pour mot. La
//   licence de la source des restrictions est celle arbitrée le 2026-10-03
//   (aucune licence n'est annoncée pour la donnée servie par l'API) : le site
//   et le jeu de données publié sur data.gouv.fr sont sous Licence Ouverte
//   2.0. Celle de Hub'Eau reste « Licence Ouverte Etalab » SANS numéro de
//   version : aucune n'est écrite sur ses pages ni ses schémas.
// - ABSENTS par construction : les limites `L-01` à `L-05`, le mot
//   « percentile », toute limite de statistique — aucun percentile n'est
//   affiché en T2 (Q-8, Q4-A).
// - L'adresse du site public de la source des restrictions est un texte
//   SÉLECTIONNABLE, pas un lien : rien ne demande de l'ouvrir depuis cet
//   écran, et un lien aurait fait traverser un port d'ouverture à la carte,
//   aux fiches et au modal.
//
// Les textes de cet écran ne sont PAS le texte acquitté du modal : ils sont
// hors de `warningTextVersion` (`UC-006 A3`).

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Introduction : `BR-001`, chaque valeur porte sa date et sa source.
const String dataSourcesIntroText =
    'Chaque valeur affichée porte sa date et le nom de sa source.';

/// Section hydrométrie : ce que mesure la station, et le caractère brut de
/// la mesure transmise (`glossary.md`, « donnée brute »).
const String dataSourcesHydrometrieText =
    "Débit et hauteur d'eau mesurés par des stations hydrométriques. Une "
    'mesure transmise automatiquement peut être affichée avant tout contrôle '
    'humain : elle peut être corrigée ou supprimée plus tard. Licence '
    "Ouverte Etalab, citation de l'auteur obligatoire.";

/// Section écoulement ONDE : des observations ponctuelles, pas une mesure
/// (`04-ui.md § 1`, fiche ONDE ; `BR-007`).
const String dataSourcesOndeText =
    "Observations visuelles de l'écoulement de petits cours d'eau, faites "
    'par des agents lors de campagnes, de mai à septembre, environ une par '
    "mois. Entre deux campagnes, personne n'observe ces points. France "
    'hexagonale et Corse uniquement. Licence Ouverte Etalab.';

/// Note d'`ADR-006` : le regroupement des modalités ONDE est un choix de
/// l'application (« interprétation de notre part »), pas celui de la source.
const String dataSourcesOndeCategoriesNote =
    "La source distingue six modalités d'écoulement. L'application les "
    'regroupe en quatre catégories et un état « Non observé » : ce '
    "regroupement est un choix de l'application, pas une classification de "
    "l'OFB.";

/// Section des restrictions : ce que la source transmet, ce qu'elle ne dit
/// pas (`BR-013`, `ADR-004`, `C-16`), la tenue de la réponse en cache, et la
/// licence — arbitrage du commanditaire du 2026-10-03 : le site et son jeu de
/// données publié sur data.gouv.fr, pas « la donnée de l'API », dont la
/// licence n'est pas établie. « 6 heures » est la durée de garde du cache
/// (`restrictionsCacheTtl`, `lib/data/restrictions/cached_restriction_source.dart`)
/// : un test les lie, une vue n'important pas `data/`.
const String dataSourcesRestrictionsText =
    "Zones d'alerte sécheresse, niveaux de gravité et usages restreints au "
    'point désigné, tels que transmis par $restrictionsSourceName. Seul '
    "l'arrêté préfectoral fait foi : son texte peut comporter des "
    'dérogations et des périmètres que $restrictionsSourceName ne restitue '
    "pas. L'interface de $restrictionsSourceName est en version 0.1 et peut "
    "changer sans préavis : une réponse que l'application ne sait pas lire "
    "n'est jamais affichée. Une réponse reste gardée 6 heures, tant que "
    "l'application est ouverte, avec sa date de récupération. Le site "
    '$restrictionsSourceName et son jeu de données publié sur data.gouv.fr '
    'sont sous Licence Ouverte 2.0.';

/// Section du fond de carte, première ligne.
const String dataSourcesIgnText = 'Fond de carte : plan IGN.';

/// Section du fond de carte, seconde ligne : l'attribution exigée par la
/// Licence Ouverte, la MÊME que celle de la carte (`ignAttribution`,
/// `lib/features/map/view/ign_tile_template.dart`). Cette tranche ne pouvant
/// pas importer la tranche carte (`shared-sans-tranche`), elle la recompose
/// du nom partagé [ignSourceName] ; un test les lie au caractère près.
const String dataSourcesIgnAttribution = '© $ignSourceName — Licence Ouverte';

/// Limite `L-06` (`02-specifications.md`), la seule des limites générales
/// que garde cet écran : aucune de ces données ne reflète les barrages.
const String dataSourcesDamsLimitText =
    'Aucune de ces données ne reflète les lâchers ni les manœuvres de '
    'barrages.';

/// Largeur de lecture : au-delà, le texte reste en colonne centrée plutôt
/// que de courir sur toute la fenêtre. Même mesure que la colonne de l'écran
/// des restrictions (`readingColumnWidth`), dont cette tranche ne peut pas
/// importer la constante.
const double _readingWidth = 760;

/// Marge de la colonne de lecture.
const double _gutter = 16;

/// Ouvre [DataSourcesView] par-dessus l'écran courant.
void _openDataSources(BuildContext context) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const DataSourcesView(),
      ),
    ),
  );
}

/// Le lien qui ouvre [DataSourcesView] : [label] souligné, cible tactile
/// minimale ([minimumTapTarget]), atteignable au Tab et activable à
/// Entrée/Espace, action de tap exposée au lecteur d'écran. Partagé par le
/// modal du premier lancement ([initialWarningSourcesLinkLabel]) et la
/// fenêtre d'avertissement ([dataSourcesTitle]) — même construction que
/// [WarningLink] et son « Fermer ».
class DataSourcesLink extends StatelessWidget {
  const DataSourcesLink({required this.label, super.key});

  /// Le libellé du lien : il change d'un appelant à l'autre.
  final String label;

  @override
  Widget build(BuildContext context) {
    // Même ordre que `WarningLink` : `Semantics` reste la racine du
    // sous-arbre, `KeyboardFocusRing` en dessous — c'est là que se trouve le
    // focus.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap
      // qu'`InkWell` porterait sinon : un double-tap au lecteur d'écran
      // n'ouvrirait rien.
      onTap: () => _openDataSources(context),
      child: KeyboardFocusRing(
        onActivate: () => _openDataSources(context),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _openDataSources(context),
            // `KeyboardFocusRing` porte déjà le focus et l'activation
            // clavier : un second `FocusNode` ferait de ce lien DEUX arrêts
            // de tabulation.
            canRequestFocus: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minimumTapTarget,
                minHeight: minimumTapTarget,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'écran « D'où vient cette donnée ? » (Q-8 (a)) : écran plein, sans
/// état, qui se ferme par son bouton de retour ou `Échap`.
class DataSourcesView extends StatelessWidget {
  const DataSourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(Navigator.maybePop(context));
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _TitleBar(),
                // Une seule barre de défilement, toujours visible (la page
                // défile, cela se voit — constat du 2026-09-29 sur l'écran
                // des restrictions) ; l'automatique du bureau est retirée
                // pour ne pas la doubler. `primary: true` : `PageUp`,
                // `PageDown` et les flèches trouvent le défilement de la
                // route depuis le focus de l'écran.
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: const Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        primary: true,
                        child: _ReadingColumn(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le contenu : colonne de [_readingWidth] centrée quand la fenêtre est plus
/// large, sinon toute la largeur ; remplissage de [_gutter] dans les deux
/// cas. Le défilement garde, lui, la pleine largeur.
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _readingWidth + 2 * _gutter,
        ),
        child: const Padding(
          padding: EdgeInsets.all(_gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(dataSourcesIntroText),
              _Section(
                title: hydrometrieSourceName,
                paragraphs: <Widget>[Text(dataSourcesHydrometrieText)],
              ),
              _Section(
                title: ondeSourceName,
                paragraphs: <Widget>[
                  Text(dataSourcesOndeText),
                  Text(dataSourcesOndeCategoriesNote),
                ],
              ),
              _Section(
                title: restrictionsSourceName,
                paragraphs: <Widget>[
                  Text(dataSourcesRestrictionsText),
                  // Lisible et sélectionnable, jamais un lien (voir l'en-tête).
                  SelectableText(restrictionsPublicSiteUrl),
                ],
              ),
              _Section(
                title: ignSourceName,
                paragraphs: <Widget>[
                  Text(dataSourcesIgnText),
                  Text(dataSourcesIgnAttribution),
                ],
              ),
              SizedBox(height: 24),
              Text(dataSourcesDamsLimitText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une source : son nom en en-tête, puis ses paragraphes.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.paragraphs});

  final String title;
  final List<Widget> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ),
        ),
        for (int i = 0; i < paragraphs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          paragraphs[i],
        ],
      ],
    );
  }
}

/// La barre de titre : retour et [dataSourcesTitle]. Pas d'`AppBar` — sa
/// hauteur est fixe, et son titre serait tronqué à 200 % de police sur un
/// téléphone ; cette barre grandit avec le texte (même choix que l'écran des
/// restrictions).
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: <Widget>[
            BackButton(
              style: IconButton.styleFrom(
                minimumSize: Size.square(minimumTapTarget),
                visualDensity: VisualDensity.standard,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  dataSourcesTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

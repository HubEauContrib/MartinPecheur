// La vue de la tranche restrictions (MVVM, ADR-014), E2 de T2 : l'ecran
// « Secheresse et restrictions », tel qu'arbitre en C1
// (`docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md`).
//
// - ECRAN PLEIN (Q-1) : pousse par-dessus la carte par la racine de
//   composition (E3). Pas d'`onClose` : le retour (bouton, `Echap`, retour
//   Android) retire la route par `Navigator.maybePop`, et c'est E3 qui ferme
//   le ViewModel au retrait.
// - ORDRE du § 3 (Q-3) : point designe, date de recuperation, zones d'eaux
//   superficielles, « Autres zones au meme point », « Arretes » dedoublonnes
//   par adresse exacte (Q-6), un seul choix de « Profil d'usager », puis les
//   usages groupes par zone dans l'ordre des zones. SANS zone d'eaux
//   superficielles (arbitrages du commanditaire du 2026-10-06) : la phrase
//   d'absence d'eaux superficielles d'abord, suivie de la phrase de `BR-007`
//   — celle de l'etat « aucune zone » —, puis « Zones d'alerte a ce point »
//   a la place de « Autres zones au meme point ». Des qu'une des zones
//   affichees est de type non reconnu, la phrase d'absence et la phrase de
//   `BR-007` sont tues (`BR-011`) : le titre et sa phrase restent.
// - TEXTES des § 5.1 a 5.3, mot pour mot (Q-5a/b/c/e). Le nom de la source
//   n'est JAMAIS ecrit ici : il vient de [restrictionsSourceName]
//   (confinement, `test/data/restrictions/restriction_source_test.dart`). Un
//   echec imprevu ([RestrictionsNonObtenues], Q-5d) a un texte neutre, qui
//   ne nomme pas la source.
// - Les mots du prefet (noms de zone, noms et descriptions d'usage,
//   adresses d'arrete) sont rendus A L'IDENTIQUE et attribues (BR-014) :
//   aucune reformulation, aucun `trim`. Le theme (`theme`) n'est pas affiche
//   en T2 (Q-5e).
// - Le ViewModel porte l'etat et le profil ; le domaine partitionne les
//   zones (`ZonesAtPoint`) et filtre les usages (`AlertZone.usagesFor`). La
//   vue dedoublonne l'AFFICHAGE des arretes (Q-6) et, depuis le 2026-10-06,
//   decide si l'absence d'eaux superficielles peut s'ecrire (aucune zone de
//   type non reconnu, `_zonesContent`) : deux decisions qui vivraient mieux
//   dans le domaine — ecart connu, `docs/project-state.md`, point 57.
//
// ENCART RENFORCE (E4, Q-4 (a) amende le 2026-09-29, `BR-013`) : tete
// epinglee (titre, action) sous la barre de titre tant qu'elle prend au plus
// la moitie de la hauteur utile, corps et adresse en premier element du
// defilement ; sinon tout l'encart est le premier element du defilement.
// Dans TOUS les etats. `reinforced_warning_card.dart` porte les
// deux morceaux.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';
import 'package:martinpecheur/features/restrictions/view/reinforced_warning_card.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Titre de l'ecran (Q-1 de C1).
const String restrictionsScreenTitle = 'Sécheresse et restrictions';

/// Phrase de `BR-007`, telle quelle : apres « aucune zone » (`UC-002 A3`),
/// apres la phrase d'absence de zone d'eaux superficielles (arbitrage du
/// 2026-10-06) et apres une gravite « Non renseigné » (Q-5c).
const String restrictionsNoDecreeMeaningText =
    "Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de "
    'votre préfecture.';

/// Cle du choix du profil [profile] — pour mesurer sa cible.
Key restrictionsProfileChoiceKey(UserProfile profile) =>
    ValueKey<String>('restrictions-profile-${profile.name}');

/// Cle de la carte du document d'adresse [raw] et de role [framework] — le
/// role fait partie de la cle : une meme adresse peut etre a la fois arrete de
/// restriction et arrete-cadre (Q-6 dedoublonne par role).
Key restrictionsDecreeCardKey(String raw, {required bool framework}) =>
    ValueKey<String>(
      'restrictions-decree-${framework ? 'cadre' : 'restriction'}-$raw',
    );

/// Cle de la carte de la zone d'index [index] (ordre d'affichage) — pour les
/// tests.
Key restrictionsZoneCardKey(int index) =>
    ValueKey<String>('restrictions-zone-$index');

/// Cle de l'echelle en bande de la zone d'index [index].
Key restrictionsScaleKey(int index) =>
    ValueKey<String>('restrictions-scale-$index');

/// Cle du bandeau du point designe (et de la date de reponse).
const Key restrictionsPointBannerKey = ValueKey<String>(
  'restrictions-point-banner',
);

/// « Point désigné : 46,20000° N, 5,22600° E » — virgule decimale, cinq
/// decimales pour l'affichage seul (la requete garde le point exact), `S` et
/// `O` pour les valeurs negatives (conception T2 § 3).
String formatDesignatedPoint(GeoPoint point) {
  String degrees(double value) =>
      value.abs().toStringAsFixed(5).replaceAll('.', ',');
  final String latitude = point.latitude < 0 ? 'S' : 'N';
  final String longitude = point.longitude < 0 ? 'O' : 'E';
  return 'Point désigné : ${degrees(point.latitude)}° $latitude, '
      '${degrees(point.longitude)}° $longitude';
}

/// L'ecran des restrictions au point designe : rend l'etat porte par
/// `RestrictionsViewModel`, quel qu'il soit (`switch` exhaustif, BR-011).
class RestrictionsScreen extends StatelessWidget {
  const RestrictionsScreen({
    required this.state,
    required this.profile,
    required this.onChooseProfile,
    required this.onRetry,
    required this.onOpenDocument,
    required this.onOpenPublicSite,
    this.unopenedLink,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// L'etat courant, produit par `RestrictionsViewModel`.
  final RestrictionsState state;

  /// Le profil choisi pour la session, ou `null` : aucun n'est
  /// preselectionne (Q2-A).
  final UserProfile? profile;

  /// Appele au choix d'un profil — branche sur
  /// `RestrictionsViewModel.chooseProfile`.
  final ValueChanged<UserProfile> onChooseProfile;

  /// Appele par « Réessayer » — branche sur `RestrictionsViewModel.retry`.
  final VoidCallback onRetry;

  /// Appele par « Ouvrir l'arrêté » / « Ouvrir l'arrêté-cadre » — branche
  /// sur `RestrictionsViewModel.openDocument`. Obligatoire : une adresse
  /// ouvrable a toujours son action d'ouverture.
  final void Function(DocumentLink link, LinkTarget target) onOpenDocument;

  /// Ouvre le site public de la source, hors de l'application : l'action de
  /// l'encart renforce (E4). Obligatoire — l'encart n'a pas de forme sans
  /// son action.
  final VoidCallback onOpenPublicSite;

  /// Le dernier lien qui n'a pas pu s'ouvrir (`UC-002 A6`).
  final UnopenedLink? unopenedLink;

  /// Decalage UTC → heure locale pour la date de recuperation (`H1`).
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    final GeoPoint? point = _pointOf(state);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(Navigator.maybePop(context));
        },
      },
      // Le focus de l'ecran sert `Echap` et `PageDown` des l'ouverture ; il
      // n'est pas un arret de tabulation : sans indicateur visible, ce serait
      // un focus invisible (`K2`).
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Scaffold(
          backgroundColor: droughtScreenBackground,
          body: SafeArea(
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: droughtLevelLabelColor),
              // La molette posee sur la barre de titre ou sur la tete
              // epinglee de l'encart — hors du defilement — fait defiler
              // l'ecran (constat du 2026-09-29 : bande morte sous la barre).
              child: WheelScrollsScreen(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _TitleBar(),
                    // Encart renforce (E4, Q-4 amende le 2026-09-29) : tete
                    // epinglee tant qu'elle tient dans la moitie de la hauteur
                    // utile, sinon tout l'encart defile en tete.
                    Expanded(
                      child: _EncartArea(
                        header: ReinforcedWarningHeader(
                          onConsultDecrees: onOpenPublicSite,
                        ),
                        // Une cle par point : a chaque nouveau point, le
                        // defilement repart EN HAUT (conception T2 § 4).
                        scrollKey: ValueKey<GeoPoint?>(point),
                        children: <Widget>[
                          const ReinforcedWarningBody(),
                          // Lien du site public non ouvert (UC-002 A6) :
                          // dans TOUS les etats, sous le corps de l'encart
                          // dont l'action l'ouvre. L'action est dans la tete
                          // epinglee : a son apparition, l'avis amene le
                          // defilement jusqu'a lui (voir `_UnopenedLinkNotice`),
                          // sans quoi l'usager descendu aux arretes verrait un
                          // bouton inerte.
                          if (unopenedLink case final UnopenedLink link
                              when link.concerns(
                                LinkTarget.publicSite,
                                restrictionsPublicSiteUrl,
                              ))
                            _UnopenedLinkNotice(
                              key: ValueKey<int>(link.failureNumber),
                            ),
                          const SizedBox(height: 16),
                          ..._content(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    final RestrictionsState state = this.state;
    return switch (state) {
      RestrictionsFermees() => const <Widget>[],
      RestrictionsEnCours(:final GeoPoint point) => <Widget>[
        _PointBanner(point: formatDesignatedPoint(point)),
        const SizedBox(height: 16),
        const Text("Recherche des zones d'alerte pour ce point…"),
      ],
      ZonesTrouvees(:final ZonesAtPoint zones) => <Widget>[
        _PointBanner(
          point: formatDesignatedPoint(zones.point),
          retrievedAt: _retrievedAt(zones.retrievedAt),
        ),
        ..._zonesContent(zones),
      ],
      AucuneZone(:final GeoPoint point, :final DateTime retrievedAt) =>
        <Widget>[
          _PointBanner(
            point: formatDesignatedPoint(point),
            retrievedAt: _retrievedAt(retrievedAt),
          ),
          const SizedBox(height: 16),
          const Text(
            '$restrictionsSourceName ne renvoie aucune zone '
            "d'alerte pour ce point.",
          ),
          const SizedBox(height: 8),
          const Text(restrictionsNoDecreeMeaningText),
        ],
      RestrictionsEnEchec(:final GeoPoint point, :final cause) => _failure(
        point,
        _failureText(cause),
      ),
      RestrictionsNonObtenues(:final GeoPoint point) => _failure(
        point,
        // Echec que la source n'a pas leve : la vue ne peut pas l'en
        // accuser, elle ne la nomme pas (Q-5d).
        "Les restrictions n'ont pas pu être obtenues pour ce point. Aucun "
        "niveau n'est affiché.",
      ),
    };
  }

  String _retrievedAt(DateTime retrievedAt) =>
      'Réponse de $restrictionsSourceName obtenue le '
      '${formatLocalDateTime(retrievedAt, offsetOf: utcOffsetOf)}';

  /// Textes du § 5.3, une cause par branche (`switch` exhaustif).
  static String _failureText(RestrictionLookupFailure cause) => switch (cause) {
    SourceInjoignable() =>
      "$restrictionsSourceName n'a pas répondu. Aucun niveau n'est "
          'disponible pour ce point.',
    ReponseIllisible() =>
      "La réponse de $restrictionsSourceName n'a pas pu être lue par "
          "l'application. Aucun niveau n'est affiché.",
    // A repondu : jamais « injoignable ».
    RequeteRefusee() =>
      "$restrictionsSourceName a répondu, mais n'a pas pu servir ce "
          "point. Aucun niveau n'est affiché.",
  };

  List<Widget> _failure(GeoPoint point, String text) => <Widget>[
    _PointBanner(point: formatDesignatedPoint(point)),
    const SizedBox(height: 16),
    Text(text),
    const SizedBox(height: 8),
    const SelectableText(
      "Les arrêtés en vigueur restent consultables à l'adresse "
      '$restrictionsPublicSiteUrl',
    ),
    const SizedBox(height: 16),
    _ActionButton(label: 'Réessayer', onPressed: onRetry),
  ];

  List<Widget> _zonesContent(ZonesAtPoint zones) {
    final List<AlertZone> surface = zones.surfaceWaterZones;
    final List<AlertZone> others = zones.otherZones;
    final List<AlertZone> ordered = <AlertZone>[...surface, ...others];
    final List<_DecreeEntry> decrees = _decreeEntries(ordered);
    final UserProfile? profile = this.profile;

    // Sans zone d'eaux superficielles, rien ne precede les autres zones :
    // « Autres zones » et « aussi » ne suivraient rien (arbitrage du
    // 2026-10-06). La phrase d'absence vient d'abord, puis la phrase de
    // `BR-007` : les deux phrases sont posees comme celles de `AucuneZone`,
    // au meme ecart (arbitrage du 2026-10-06).
    final bool noSurfaceZone = surface.isEmpty && others.isNotEmpty;
    // L'absence d'eaux superficielles ne s'affirme que si TOUTES les zones
    // affichees sont d'un type reconnu : d'une zone de type non reconnu,
    // l'application ne sait pas ce qu'elle est (`BR-011`, arbitrage du
    // 2026-10-06). La phrase d'absence est alors tue, et la phrase de
    // `BR-007` avec elle ; le titre « Zones d'alerte a ce point » et sa
    // phrase restent : ils sont vrais.
    final bool surfaceAbsenceStated =
        noSurfaceZone &&
        !others.any((AlertZone zone) => zone.kind is TypeZoneInconnu);

    return <Widget>[
      if (surfaceAbsenceStated) ...<Widget>[
        const SizedBox(height: 16),
        const Text(
          '$restrictionsSourceName ne renvoie aucune zone '
          "d'alerte d'eaux superficielles pour ce point.",
        ),
        const SizedBox(height: 8),
        const Text(restrictionsNoDecreeMeaningText),
      ],
      if (surface.isNotEmpty) ...<Widget>[
        _SectionTitle(zoneKindLabel(const EauxSuperficielles())),
        for (int i = 0; i < surface.length; i++)
          _ZoneCard(zone: surface[i], index: i),
      ],
      if (others.isNotEmpty) ...<Widget>[
        if (noSurfaceZone) ...<Widget>[
          const _SectionTitle("Zones d'alerte à ce point"),
          const Text(
            "Le point désigné se trouve dans ces zones d'alerte. Chacune a "
            'son niveau et ses usages.',
          ),
        ] else ...<Widget>[
          const _SectionTitle('Autres zones au même point'),
          const Text(
            "Le point désigné se trouve aussi dans ces zones d'alerte. Chacune "
            'a son niveau et ses usages.',
          ),
        ],
        for (int i = 0; i < others.length; i++)
          _ZoneCard(zone: others[i], index: surface.length + i),
      ],
      if (decrees.isNotEmpty) ...<Widget>[
        const _SectionTitle('Arrêtés'),
        Text(
          decrees.length == 1
              ? '1 document pour ce point'
              : '${decrees.length} documents pour ce point',
        ),
        const SizedBox(height: 16),
        for (final _DecreeEntry entry in decrees)
          _DecreeBlock(
            entry: entry,
            sameZonesAsDecree: _isSameZonesAsDecree(entry, decrees),
            unopenedLink: unopenedLink,
            onOpenDocument: onOpenDocument,
          ),
      ],
      const _SectionTitle("Profil d'usager"),
      RadioGroup<UserProfile>(
        groupValue: profile,
        onChanged: (UserProfile? chosen) {
          if (chosen != null) {
            onChooseProfile(chosen);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final UserProfile choice in UserProfile.values)
              RadioListTile<UserProfile>(
                key: restrictionsProfileChoiceKey(choice),
                value: choice,
                title: Text(userProfileLabel(choice)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (profile == null)
        const Text(
          "Les usages restreints s'affichent une fois un profil "
          'choisi.',
        )
      else ...<Widget>[
        Text(
          'Usages restreints pour le profil ${userProfileLabel(profile)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Textes cités tels que transmis par $restrictionsSourceName. Seul '
          "l'arrêté fait foi.",
        ),
        for (final AlertZone zone in ordered)
          _UsageGroup(zone: zone, profile: profile),
      ],
    ];
  }
}

/// La zone sous la barre de titre : l'encart renforce et le contenu.
///
/// Disposition decidee sur la MESURE, sans seuil en pixels (seul le repli
/// synchrone de `_layout` connait la largeur de la colonne de lecture) : la
/// tete (titre et action) est epinglee tant que sa hauteur reelle est au plus la
/// moitie de la hauteur utile de la zone ; sinon tout l'encart est le premier
/// element du defilement. La tete est rendue a la meme largeur dans les deux
/// dispositions (hors du remplissage du defilement), donc sa mesure est la
/// meme : pas d'oscillation. Le premier passage est toujours en defilement
/// (jamais de debordement), l'epinglage vient au passage suivant.
class _EncartArea extends StatefulWidget {
  const _EncartArea({
    required this.header,
    required this.scrollKey,
    required this.children,
  });

  final Widget header;
  final Key scrollKey;
  final List<Widget> children;

  @override
  State<_EncartArea> createState() => _EncartAreaState();
}

class _EncartAreaState extends State<_EncartArea> {
  final GlobalKey _headerKey = GlobalKey();
  bool _pinned = false;

  /// Derniere taille de la zone vue par le `LayoutBuilder`.
  double? _usableHeight;
  double? _usableWidth;
  TextScaler? _scaler;

  /// Derniere hauteur MESUREE de la tete (dans [_decide]) : a largeur
  /// inchangee, ou tant que la zone garde au moins la largeur de la colonne
  /// de lecture, un retrecissement ne la change pas, donc la zone dit
  /// d'elle-meme, sans attendre le rendu, si la tete epinglee y tient.
  double? _headerHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le facteur de police change la hauteur de la tete sans changer les
    // contraintes : on relance la decision, sans compter sur un autre widget
    // (la barre de titre) pour reconstruire cette zone.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    if (_scaler != null && _scaler != scaler) {
      // Une police plus grande peut faire deborder la tete epinglee : on
      // repasse SYNCHRONEMENT en defilement (jamais de debordement), puis la
      // decision post-rendu re-epingle si elle tient.
      _pinned = false;
    }
    _scaler = scaler;
    final double? usable = _usableHeight;
    if (usable != null) {
      _decide(usable);
    }
  }

  void _decide(double usableHeight) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      final RenderObject? box = _headerKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      _headerHeight = box.size.height;
      final bool fits = box.size.height * 2 <= usableHeight;
      if (fits != _pinned) {
        // Bascule de disposition (redimensionnement de fenetre, changement
        // de police) : seule la tete change de creneau (voir `_layout`). Le
        // defilement garde sa place dans l'arbre : sa POSITION et le FOCUS
        // clavier qu'il porte sont conserves.
        setState(() => _pinned = fits);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // La barre de defilement est toujours visible (la page defile, cela se
    // voit) ; l'automatique du bureau est retiree pour ne pas la doubler. Le
    // glisser garde le comportement par defaut de Flutter : au doigt et au
    // pave tactile il fait defiler, a la souris non — un glisser y demarre a
    // 1 px, et un clic un peu tremble sur un choix de profil ou un bouton
    // serait perdu. La souris defile a la molette, a la barre et au clavier.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: _layout(),
    );
  }

  Widget _layout() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? lastWidth = _usableWidth;
        final double? headerHeight = _headerHeight;
        // Repli SYNCHRONE en defilement (jamais de debordement de la tete
        // epinglee), puis nouvelle decision apres rendu — dans deux cas
        // seulement :
        // - la LARGEUR diminue SOUS la colonne de lecture : la tete suit
        //   alors la largeur de la zone, son texte passe a la ligne, elle
        //   peut GRANDIR, sa hauteur memorisee ne dit plus rien ;
        // - la tete, a sa hauteur memorisee, ne tient plus dans la moitie de
        //   la zone : l'epingler deborderait.
        // Partout ailleurs la hauteur de la tete ne change pas : en hauteur
        // seule elle garde sa largeur, et a partir de la colonne de lecture
        // sa largeur est fixe (`ReinforcedWarningHeader` se borne a la meme
        // colonne), quelle que soit celle de la fenetre. Tant qu'elle tient,
        // elle reste donc epinglee sur TOUTES les images. Replier a chaque
        // retrecissement la faisait partir hors champ, ecran defile, le
        // temps du geste.
        if (_pinned &&
            ((lastWidth != null &&
                    constraints.maxWidth < lastWidth &&
                    constraints.maxWidth <
                        readingColumnWidth + 2 * readingColumnGutter) ||
                (headerHeight != null &&
                    headerHeight * 2 > constraints.maxHeight))) {
          _pinned = false;
        }
        _usableHeight = constraints.maxHeight;
        _usableWidth = constraints.maxWidth;
        _decide(constraints.maxHeight);
        final Widget header = KeyedSubtree(
          key: _headerKey,
          child: widget.header,
        );
        // MEME arbre dans les deux dispositions : seule la tete change de
        // creneau — sous la barre de titre, hors du defilement, quand elle
        // est epinglee ; sinon en tete du defilement. Sa `GlobalKey` la
        // deplace sans la reconstruire. Le defilement n'est jamais remplace :
        // sa position, son focus et les selections qu'il porte survivent a
        // un retrecissement de la fenetre. En hauteur, et en largeur a partir
        // de la colonne de lecture, la tete reste epinglee tant qu'elle tient
        // (voir ci-dessus). SOUS la colonne de lecture, tete epinglee, le
        // repli synchrone reste a chaque retrecissement en largeur : UNE
        // bascule par image — repli au rendu du retrecissement, puis
        // epinglage apres rendu, a l'image suivante, si la tete tient encore
        // — et l'image repliee EST peinte : ecran defile, la tete est hors
        // champ pendant cette image.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _pinned ? header : const SizedBox.shrink(),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: widget.scrollKey,
                  // Le defilement de la route : `PageUp`/`PageDown` (et
                  // `Ctrl`+fleches) le trouvent depuis le focus de l'ecran,
                  // qui n'est pas dans le defilement. Sur mobile, c'etait
                  // deja le cas par defaut.
                  primary: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _pinned ? const SizedBox.shrink() : header,
                      _ReadingColumn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Le contenu defilant : colonne de [readingColumnWidth] centree quand la
/// fenetre est plus large, sinon toute la largeur, remplissage de 16 dans les
/// deux cas. Le defilement, lui, garde la pleine largeur (sa barre reste au
/// bord de la fenetre).
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double full = readingColumnWidth + 2 * readingColumnGutter;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth < full ? constraints.maxWidth : full,
            child: Padding(
              padding: const EdgeInsets.all(readingColumnGutter),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Le point de l'etat, ou `null` quand l'ecran est ferme.
GeoPoint? _pointOf(RestrictionsState state) => switch (state) {
  RestrictionsFermees() => null,
  RestrictionsEnCours(:final GeoPoint point) => point,
  ZonesTrouvees(:final ZonesAtPoint zones) => zones.point,
  AucuneZone(:final GeoPoint point) => point,
  RestrictionsEnEchec(:final GeoPoint point) => point,
  RestrictionsNonObtenues(:final GeoPoint point) => point,
};

/// « Eaux souterraines — Dombes - Certines - Nord ».
String _zoneTitle(AlertZone zone) =>
    '${zoneKindLabel(zone.kind)} — ${zone.name}';

/// « Alerte · depuis le 20/08/2026 » : le niveau et sa date de debut de
/// validite dans le MEME texte (BR-001), date calendaire sans conversion.
String _datedLevel(AlertZone zone) =>
    '${droughtSeverityLabel(zone.severity)} · depuis le '
    '${formatCalendarDate(zone.decree.validFrom)}';

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    // Pas d'`AppBar` : sa hauteur est fixe, et son titre serait tronque a
    // 200 % de police sur un telephone. Cette barre grandit avec le texte.
    return Material(
      color: droughtScreenBackground,
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
                  restrictionsScreenTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: droughtLevelLabelColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
    );
  }
}

/// Le badge et le niveau date, a cote : jamais le libelle sur la teinte
/// (Q-7). Annonce comme gravite : l'echelle est nommee (BR-008).
class _DatedLevelRow extends StatelessWidget {
  const _DatedLevelRow({required this.zone});

  final AlertZone zone;

  @override
  Widget build(BuildContext context) {
    final String text = _datedLevel(zone);
    return Semantics(
      container: true,
      // Conception T2 § 7 : « Niveau de gravité : Alerte, depuis le 20 août
      // 2026 » — la date en toutes lettres pour la lecture a voix haute.
      label:
          'Niveau de gravité : ${droughtSeverityLabel(zone.severity)}, '
          'depuis le ${formatLongCalendarDate(zone.decree.validFrom)}',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          DroughtSeverityBadge(severity: zone.severity),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gris des textes secondaires des cartes de zone (14 sur fond blanc, 8,7:1).
const Color _secondaryTextColor = Color(0xFF3A4148);

/// Le bandeau du point designe : viseur, point en gras, et — quand l'etat en
/// porte une — la date de reponse dessous.
class _PointBanner extends StatelessWidget {
  const _PointBanner({required this.point, this.retrievedAt});

  final String point;

  /// La date de reponse de la source, ou `null` (chargement, echecs).
  final String? retrievedAt;

  @override
  Widget build(BuildContext context) {
    final String? retrievedAt = this.retrievedAt;
    return SizedBox(
      key: restrictionsPointBannerKey,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _neutralTileColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ExcludeSemantics(child: Icon(Icons.gps_fixed, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      point,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (retrievedAt != null)
                      Text(
                        retrievedAt,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _secondaryTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le niveau date en grand, sans badge (le badge est en tete de carte) :
/// meme semantique que [_DatedLevelRow].
class _DatedLevelText extends StatelessWidget {
  const _DatedLevelText({required this.zone});

  final AlertZone zone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Niveau de gravité : ${droughtSeverityLabel(zone.severity)}, '
          'depuis le ${formatLongCalendarDate(zone.decree.validFrom)}',
      excludeSemantics: true,
      child: Text(
        _datedLevel(zone),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Une zone, en carte : badge de 48, [surtitre du type pour une autre zone
/// que les eaux superficielles], nom, niveau date, date de fin ; puis la
/// phrase de `BR-007` si la gravite est inconnue, l'echelle en bande, et la
/// phrase d'une zone sans arrete.
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.index});

  final AlertZone zone;
  final int index;

  @override
  Widget build(BuildContext context) {
    final DateTime? validUntil = zone.decree.validUntil;
    final bool showKind = zone.kind is! EauxSuperficielles;
    return Padding(
      key: restrictionsZoneCardKey(index),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DroughtSeverityBadge(severity: zone.severity, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // « type — nom » annonce en entier, jamais le
                        // surtitre seul (les mots du prefet a l'identique,
                        // BR-014).
                        Semantics(
                          container: true,
                          label: _zoneTitle(zone),
                          excludeSemantics: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showKind)
                                Text(
                                  zoneKindLabel(zone.kind).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _addressLabelColor,
                                  ),
                                ),
                              Text(
                                zone.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _DatedLevelText(zone: zone),
                        Text(
                          validUntil == null
                              ? 'Date de fin non transmise par la source.'
                              : "jusqu'au ${formatCalendarDate(validUntil)}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (zone.severity is GraviteInconnue) ...<Widget>[
                const SizedBox(height: 12),
                const Text(restrictionsNoDecreeMeaningText),
              ],
              const SizedBox(height: 16),
              _SeverityScale(index: index, marked: zone.severity),
              if (zone.decree.document == null) ...<Widget>[
                const SizedBox(height: 12),
                const Text(
                  "Le texte de l'arrêté n'est pas accessible depuis "
                  "l'application : la source n'en transmet pas l'adresse.",
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Largeurs de contenu (NON agrandi : largeur divisee par le facteur de
/// police) sous lesquelles l'echelle passe a une, puis a deux colonnes.
const double _scaleOneColumnBelow = 300;
const double _scaleTwoColumnsBelow = 480;

/// L'echelle complete, en bande, une par zone (jamais une echelle commune,
/// conception T2 § 3) : quatre cases cote a cote, deux colonnes sous
/// [_scaleTwoColumnsBelow] de contenu, une sous [_scaleOneColumnBelow]. La case de la zone est marquee. Une
/// gravite inconnue n'y a aucune case (BR-011).
///
/// La largeur est comptee HORS agrandissement de police : a 200 %, un contenu
/// de 730 px se lit comme 365 et prend deux colonnes ; un telephone (contenu
/// sous 300 px non agrandi) prend une colonne. Sans cela, un libelle comme
/// « Vigilance » ou « renforcée » serait coupe au milieu du mot (verrouille
/// avec la vraie police par `restrictions_scale_text_test.dart`).
class _SeverityScale extends StatelessWidget {
  const _SeverityScale({required this.index, required this.marked});

  final int index;
  final DroughtSeverity marked;

  @override
  Widget build(BuildContext context) {
    // Facteur mesure sur 14 px : un facteur non lineaire (Android 14) n'est
    // pas `scale(1)`.
    final double textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      key: restrictionsScaleKey(index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Échelle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _addressLabelColor,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 6;
            final double unscaled =
                constraints.maxWidth / (textScale < 1 ? 1 : textScale);
            final int columns = unscaled < _scaleOneColumnBelow
                ? 1
                : unscaled < _scaleTwoColumnsBelow
                ? 2
                : 4;
            final double width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final DroughtSeverity level in droughtSeverityScale)
                  SizedBox(
                    width: width,
                    child: _ScaleCase(level: level, isMarked: level == marked),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Une case de l'echelle : badge de 22 et libelle a cote (jamais sur la
/// teinte, Q-7). Marquee : bordure de 2, fond neutre, libelle en gras et
/// « ← cette zone » dessous, annoncee « …, niveau de cette zone ».
class _ScaleCase extends StatelessWidget {
  const _ScaleCase({required this.level, required this.isMarked});

  final DroughtSeverity level;
  final bool isMarked;

  @override
  Widget build(BuildContext context) {
    final String label = droughtSeverityLabel(level);
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DroughtSeverityBadge(severity: level, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMarked ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMarked ? _neutralTileColor : null,
        border: isMarked
            ? Border.all(color: const Color(0xFF141A1F), width: 2)
            : Border.all(color: _ruleColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: isMarked
            // La fleche serait lue telle quelle : la case marquee est
            // annoncee « …, niveau de cette zone ».
            ? Semantics(
                label: '$label, niveau de cette zone',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    row,
                    const SizedBox(height: 2),
                    const Text('← cette zone', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : row,
      ),
    );
  }
}

/// Un document distinct de la section « Arrêtés » (Q-6) : son role, son
/// adresse, et les zones qui le citent.
final class _DecreeEntry {
  _DecreeEntry({required this.isFramework, required this.link});

  final bool isFramework;
  final DocumentLink link;
  final List<AlertZone> zones = <AlertZone>[];
}

/// Arretes de restriction puis arretes-cadres, chacun UNE fois par adresse
/// EXACTE (`DocumentLink.raw`, aucune normalisation), dans l'ordre des zones.
List<_DecreeEntry> _decreeEntries(List<AlertZone> zones) {
  final Map<String, _DecreeEntry> decrees = <String, _DecreeEntry>{};
  final Map<String, _DecreeEntry> frameworks = <String, _DecreeEntry>{};
  for (final AlertZone zone in zones) {
    final DocumentLink? document = zone.decree.document;
    if (document != null) {
      decrees
          .putIfAbsent(
            document.raw,
            () => _DecreeEntry(isFramework: false, link: document),
          )
          .zones
          .add(zone);
    }
    final DocumentLink? framework = zone.decree.frameworkDocument;
    if (framework != null) {
      frameworks
          .putIfAbsent(
            framework.raw,
            () => _DecreeEntry(isFramework: true, link: framework),
          )
          .zones
          .add(zone);
    }
  }
  return <_DecreeEntry>[...decrees.values, ...frameworks.values];
}

/// Vrai si [entry] est un arrete-cadre dont l'ensemble de zones est EXACTEMENT
/// celui d'un arrete de restriction affiche : la liste serait alors une
/// repetition, la carte dit « mêmes zones ».
bool _isSameZonesAsDecree(_DecreeEntry entry, List<_DecreeEntry> all) {
  if (!entry.isFramework) {
    return false;
  }
  return all.any(
    (_DecreeEntry other) =>
        !other.isFramework &&
        other.zones.length == entry.zones.length &&
        entry.zones.every(
          (AlertZone zone) =>
              other.zones.any((AlertZone o) => identical(o, zone)),
        ),
  );
}

/// La ligne de dates d'un arrete de restriction, ou `null` : les dates de
/// validite ne s'affichent que si TOUTES ses zones les partagent (rien n'est
/// choisi ni invente a la place d'un desaccord de la source).
String? _validityLine(List<AlertZone> zones) {
  final RestrictionDecree first = zones.first.decree;
  final bool shared = zones.every(
    (AlertZone zone) =>
        zone.decree.validFrom == first.validFrom &&
        zone.decree.validUntil == first.validUntil,
  );
  if (!shared) {
    return null;
  }
  final DateTime? until = first.validUntil;
  return until == null
      ? 'Depuis le ${formatCalendarDate(first.validFrom)}'
      : 'Du ${formatCalendarDate(first.validFrom)} au '
            '${formatCalendarDate(until)}';
}

/// Vrai si le CHEMIN de l'adresse se termine par `.pdf` (casse ignoree).
bool _isPdfAddress(String raw) {
  final String path = Uri.tryParse(raw)?.path ?? raw;
  return path.toLowerCase().endsWith('.pdf');
}

const Color _cardBorderColor = Color(0xFFC9CFC4);
const Color _ruleColor = Color(0xFFE3E6DF);
const Color _neutralTileColor = Color(0xFFF3F4F1);
const Color _primaryTileColor = Color(0xFFE6F0F5);

/// Gris du libelle « Adresse du document » : 7,2:1 sur [_neutralTileColor].
const Color _addressLabelColor = Color(0xFF4A5259);

/// Une carte par document : tete, zones concernees, action d'ouverture,
/// adresse brute (BR-014) et avis de lien non ouvert.
class _DecreeBlock extends StatelessWidget {
  const _DecreeBlock({
    required this.entry,
    required this.sameZonesAsDecree,
    required this.unopenedLink,
    required this.onOpenDocument,
  });

  final _DecreeEntry entry;
  final bool sameZonesAsDecree;
  final UnopenedLink? unopenedLink;
  final void Function(DocumentLink link, LinkTarget target) onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final bool openable = entry.link.openableUri != null;
    final bool framework = entry.isFramework;
    final LinkTarget target = framework
        ? LinkTarget.frameworkDecree
        : LinkTarget.decree;
    final String? secondary = framework ? null : _validityLine(entry.zones);
    final int zoneCount = entry.zones.length;

    return Padding(
      key: restrictionsDecreeCardKey(entry.link.raw, framework: framework),
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: framework
                            ? _neutralTileColor
                            : _primaryTileColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(
                          framework
                              ? Icons.article_outlined
                              : Icons.description_outlined,
                          color: framework
                              ? droughtLevelLabelColor
                              : primaryActionColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          framework ? 'Arrêté-cadre' : 'Arrêté de restriction',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (secondary != null) Text(secondary),
                        if (framework && sameZonesAsDecree)
                          Text(
                            zoneCount == 1
                                ? "S'applique à la même zone"
                                : "S'applique aux $zoneCount mêmes zones",
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!(framework && sameZonesAsDecree)) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  zoneCount == 1
                      ? "S'applique à 1 zone"
                      : "S'applique à $zoneCount zones",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (int i = 0; i < zoneCount; i++)
                  _DecreeZoneRow(zone: entry.zones[i], first: i == 0),
              ],
              const SizedBox(height: 16),
              if (!openable)
                const Text(
                  'Cette adresse ne peut pas être ouverte depuis '
                  "l'application.",
                )
              else ...<Widget>[
                _OpenDocumentButton(
                  label: framework
                      ? "Ouvrir l'arrêté-cadre"
                      : "Ouvrir l'arrêté",
                  filled: !framework,
                  onPressed: () => onOpenDocument(entry.link, target),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPdfAddress(entry.link.raw)
                      ? "PDF · s'ouvre hors de l'application"
                      : "S'ouvre hors de l'application",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _neutralTileColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Adresse du document',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _addressLabelColor,
                        ),
                      ),
                      // L'adresse brute, telle que recue (BR-014),
                      // selectionnable : la copie se fait par selection
                      // (Q9-A).
                      SelectableText(
                        entry.link.raw,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontFamilyFallback: <String>['Consolas', 'Courier'],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (unopenedLink case final UnopenedLink link
                  when link.concerns(target, entry.link.raw)) ...<Widget>[
                const SizedBox(height: 8),
                _UnopenedLinkNotice(key: ValueKey<int>(link.failureNumber)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Une zone de la liste « S'applique à » : badge, titre, niveau a cote
/// (jamais sur la teinte, Q-7). Noms rendus a l'identique (BR-014).
class _DecreeZoneRow extends StatelessWidget {
  const _DecreeZoneRow({required this.zone, required this.first});

  final AlertZone zone;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final String title = _zoneTitle(zone);
    final String level = droughtSeverityLabel(zone.severity);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: _ruleColor)),
            ),
      child: Semantics(
        container: true,
        label: '$title, niveau de gravité : $level',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DroughtSeverityBadge(severity: zone.severity),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: <Widget>[
                  Text(title),
                  Text(
                    level,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Ouvrir l'arrêté » (plein, bleu d'action) ou « Ouvrir l'arrêté-cadre »
/// (contour noir) : pleine largeur, cible tactile minimale (K4), densite
/// standard sans quoi Windows la reduirait.
class _OpenDocumentButton extends StatelessWidget {
  const _OpenDocumentButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Size size = Size(double.infinity, minimumTapTarget);
    final OutlinedBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(width: 8),
        const Icon(Icons.open_in_new, size: 18),
      ],
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: size,
          visualDensity: VisualDensity.standard,
          backgroundColor: primaryActionColor,
          foregroundColor: onPrimaryActionColor,
          shape: shape,
        ),
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        visualDensity: VisualDensity.standard,
        foregroundColor: droughtLevelLabelColor,
        side: const BorderSide(color: droughtLevelLabelColor, width: 1.5),
        shape: shape,
      ),
      child: content,
    );
  }
}

/// Sous une adresse qui ne s'est pas ouverte : rien ne dit que le document
/// existe (`UC-002 A6`). Encart orange, l'icone n'est pas annoncee ; l'avis
/// est une region d'alerte — il arrive apres une action de l'usager, comme la
/// phrase d'echec d'ecriture du modal (`initial_warning_view.dart`).
///
/// A son apparition, l'avis amene le defilement qui le porte jusqu'a lui, UNE
/// fois : l'action qui vient d'echouer (le bouton d'un arrete, l'action de
/// l'encart) est ailleurs que l'avis, qui nait sous elle ou dans le contenu
/// defilant, et peut naitre hors de la zone visible — le bouton paraitrait
/// inerte. Au plus court : rien s'il est deja visible, vers le haut s'il est
/// au-dessus de la zone visible, vers le bas s'il est dessous. Un deuxieme
/// echec du meme lien le ramene de meme : le ViewModel numerote chaque echec,
/// la vue prend ce numero pour cle de l'avis — un nouvel etat, donc un
/// nouveau devoilement (l'usager qui redescend et rappuie sur le meme bouton
/// ne le verrait pas bouger).
class _UnopenedLinkNotice extends StatefulWidget {
  const _UnopenedLinkNotice({super.key});

  @override
  State<_UnopenedLinkNotice> createState() => _UnopenedLinkNoticeState();
}

class _UnopenedLinkNoticeState extends State<_UnopenedLinkNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      // Vers le bas d'abord (avis sous la zone visible : sa FIN y est alignee),
      // vers le haut ensuite (avis plus haut que la zone visible : une fois sa
      // fin alignee, son debut est au-dessus du champ, et c'est le DEBUT qui
      // doit y etre). Chaque politique ne deplace que dans son sens : un avis
      // deja visible ne bouge ni a l'une ni a l'autre.
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          border: Border.all(color: const Color(0xFFB36B00)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(child: Icon(Icons.info_outline, size: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Ce lien n'a pas pu être ouvert depuis l'application. Son "
                  'adresse reste affichée ci-dessus.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les usages d'une zone pour le profil choisi, cites a l'identique. Titre :
/// type, nom et niveau date de la zone.
class _UsageGroup extends StatelessWidget {
  const _UsageGroup({required this.zone, required this.profile});

  final AlertZone zone;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final List<RestrictedUsage> usages = zone.usagesFor(profile);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _zoneTitle(zone),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _DatedLevelRow(zone: zone),
          const SizedBox(height: 4),
          if (usages.isEmpty)
            Text(
              '$restrictionsSourceName ne transmet aucun usage pour le '
              'profil ${userProfileLabel(profile)} dans cette zone. Seul '
              "l'arrêté fait foi : consultez-le.",
            )
          else
            for (final RestrictedUsage usage in usages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      usage.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Guillemets poses HORS de la chaine citee : la
                    // description est un span a elle seule, intacte.
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: '« '),
                          TextSpan(text: usage.description),
                          const TextSpan(text: ' »'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Un bouton d'action a la cible tactile minimale de la plateforme (K4) :
/// densite standard, sans quoi Windows (densite compacte) la reduirait.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.square(minimumTapTarget),
        visualDensity: VisualDensity.standard,
        foregroundColor: droughtLevelLabelColor,
      ),
      child: Text(label),
    );
  }
}

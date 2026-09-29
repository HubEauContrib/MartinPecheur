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
//   usages groupes par zone dans l'ordre des zones.
// - TEXTES des § 5.1 a 5.3, mot pour mot (Q-5a/b/c/e). Le nom de la source
//   n'est JAMAIS ecrit ici : il vient de [restrictionsSourceName]
//   (confinement, `test/data/restrictions/restriction_source_test.dart`). Un
//   echec imprevu ([RestrictionsNonObtenues], Q-5d) a un texte neutre, qui
//   ne nomme pas la source.
// - Les mots du prefet (noms de zone, noms et descriptions d'usage,
//   adresses d'arrete) sont rendus A L'IDENTIQUE et attribues (BR-014) :
//   aucune reformulation, aucun `trim`. Le theme (`theme`) n'est pas affiche
//   en T2 (Q-5e).
// - Aucune decision ici : le ViewModel porte l'etat et le profil ; le
//   domaine partitionne les zones (`ZonesAtPoint`) et filtre les usages
//   (`AlertZone.usagesFor`). La vue dedoublonne seulement l'AFFICHAGE des
//   arretes (Q-6).
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
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Titre de l'ecran (Q-1 de C1).
const String restrictionsScreenTitle = 'Sécheresse et restrictions';

/// Phrase de `BR-007`, telle quelle : apres « aucune zone » (`UC-002 A3`) et
/// apres une gravite « Non renseigné » (Q-5c).
const String restrictionsNoDecreeMeaningText =
    "Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de "
    'votre préfecture.';

/// Cle du choix du profil [profile] — pour mesurer sa cible.
Key restrictionsProfileChoiceKey(UserProfile profile) =>
    ValueKey<String>('restrictions-profile-${profile.name}');

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
    required this.onOpenPublicSite,
    this.onOpenDocument,
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

  /// Appele par « Ouvrir l'arrêté » / « Ouvrir l'arrêté-cadre ». Nul :
  /// aucune action d'ouverture, l'adresse reste visible et selectionnable.
  final ValueChanged<DocumentLink>? onOpenDocument;

  /// Ouvre le site public de la source, hors de l'application : l'action de
  /// l'encart renforce (E4). Obligatoire — l'encart n'a pas de forme sans
  /// son action.
  final VoidCallback onOpenPublicSite;

  /// Adresse brute du dernier lien qui n'a pas pu s'ouvrir (`UC-002 A6`).
  final String? unopenedLink;

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
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: droughtScreenBackground,
          body: SafeArea(
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: droughtLevelLabelColor),
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
                        // dont l'action l'ouvre.
                        if (unopenedLink == restrictionsPublicSiteUrl)
                          const _UnopenedLinkNotice(),
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
    );
  }

  List<Widget> _content() {
    final RestrictionsState state = this.state;
    return switch (state) {
      RestrictionsFermees() => const <Widget>[],
      RestrictionsEnCours(:final GeoPoint point) => <Widget>[
        Text(formatDesignatedPoint(point)),
        const SizedBox(height: 16),
        const Text("Recherche des zones d'alerte pour ce point…"),
      ],
      ZonesTrouvees(:final ZonesAtPoint zones) => <Widget>[
        Text(formatDesignatedPoint(zones.point)),
        _retrievedAt(zones.retrievedAt),
        ..._zonesContent(zones),
      ],
      AucuneZone(:final GeoPoint point, :final DateTime retrievedAt) =>
        <Widget>[
          Text(formatDesignatedPoint(point)),
          _retrievedAt(retrievedAt),
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

  Widget _retrievedAt(DateTime retrievedAt) => Text(
    'Réponse de $restrictionsSourceName obtenue le '
    '${formatLocalDateTime(retrievedAt, offsetOf: utcOffsetOf)}',
  );

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
    Text(formatDesignatedPoint(point)),
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

    return <Widget>[
      if (surface.isNotEmpty) ...<Widget>[
        _SectionTitle(zoneKindLabel(const EauxSuperficielles())),
        for (final AlertZone zone in surface)
          _ZoneBlock(zone: zone, title: zone.name),
      ],
      if (others.isNotEmpty) ...<Widget>[
        const _SectionTitle('Autres zones au même point'),
        const Text(
          "Le point désigné se trouve aussi dans ces zones d'alerte. Chacune "
          'a son niveau et ses usages.',
        ),
        for (final AlertZone zone in others)
          _ZoneBlock(zone: zone, title: _zoneTitle(zone)),
      ],
      if (decrees.isNotEmpty) ...<Widget>[
        const _SectionTitle('Arrêtés'),
        for (final _DecreeEntry entry in decrees)
          _DecreeBlock(
            entry: entry,
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
/// Disposition decidee sur la MESURE, sans seuil en pixels : la tete
/// (titre et action) est epinglee tant que sa hauteur reelle est au plus la
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
      final bool fits = box.size.height * 2 <= usableHeight;
      if (fits != _pinned) {
        // Bascule de disposition (redimensionnement de fenetre, changement
        // de police) : le defilement est reconstruit a un autre endroit de
        // l'arbre, donc sa POSITION et le FOCUS clavier qu'il porte sont
        // perdus. Assume : la bascule est rare, et le defilement repart en
        // haut, ou l'encart est visible. Aucune `GlobalKey` ne conserve
        // cet etat (la cle de mesure ne porte que la tete).
        setState(() => _pinned = fits);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double? lastHeight = _usableHeight;
        final double? lastWidth = _usableWidth;
        if (_pinned &&
            ((lastHeight != null && constraints.maxHeight < lastHeight) ||
                (lastWidth != null && constraints.maxWidth < lastWidth))) {
          // Zone plus petite : la tete epinglee pourrait deborder ; meme
          // repli synchrone en defilement, puis nouvelle decision.
          _pinned = false;
        }
        _usableHeight = constraints.maxHeight;
        _usableWidth = constraints.maxWidth;
        _decide(constraints.maxHeight);
        final Widget header = KeyedSubtree(
          key: _headerKey,
          child: widget.header,
        );
        if (_pinned) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              Expanded(
                child: SingleChildScrollView(
                  key: widget.scrollKey,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          key: widget.scrollKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
            ],
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

/// Une zone : titre, niveau date, date de fin, phrase de `BR-007` si la
/// gravite est inconnue, echelle complete marquee, et la phrase d'une zone
/// sans arrete.
class _ZoneBlock extends StatelessWidget {
  const _ZoneBlock({required this.zone, required this.title});

  final AlertZone zone;
  final String title;

  @override
  Widget build(BuildContext context) {
    final DateTime? validUntil = zone.decree.validUntil;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _DatedLevelRow(zone: zone),
          Text(
            validUntil == null
                ? 'Date de fin non transmise par la source.'
                : "jusqu'au ${formatCalendarDate(validUntil)}",
          ),
          if (zone.severity is GraviteInconnue)
            const Text(restrictionsNoDecreeMeaningText),
          const SizedBox(height: 4),
          _SeverityScale(marked: zone.severity),
          if (zone.decree.document == null)
            const Text(
              "Le texte de l'arrêté n'est pas accessible depuis "
              "l'application : la source n'en transmet pas l'adresse.",
            ),
        ],
      ),
    );
  }
}

/// L'echelle complete, une par zone (jamais une echelle commune, conception
/// T2 § 3), la ligne de la zone marquee. Une gravite inconnue n'y a aucune
/// position (BR-011).
class _SeverityScale extends StatelessWidget {
  const _SeverityScale({required this.marked});

  final DroughtSeverity marked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Échelle :'),
        for (final DroughtSeverity level in droughtSeverityScale)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Row(
              children: <Widget>[
                DroughtSeverityBadge(severity: level),
                const SizedBox(width: 8),
                Flexible(
                  child: level == marked
                      // La fleche serait lue telle quelle : la ligne marquee
                      // est annoncee « …, niveau de cette zone ».
                      ? Semantics(
                          label:
                              '${droughtSeverityLabel(level)}, niveau de '
                              'cette zone',
                          excludeSemantics: true,
                          child: Text(
                            '${droughtSeverityLabel(level)} ← cette zone',
                          ),
                        )
                      : Text(droughtSeverityLabel(level)),
                ),
              ],
            ),
          ),
      ],
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

class _DecreeBlock extends StatelessWidget {
  const _DecreeBlock({
    required this.entry,
    required this.unopenedLink,
    required this.onOpenDocument,
  });

  final _DecreeEntry entry;
  final String? unopenedLink;
  final ValueChanged<DocumentLink>? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<DocumentLink>? onOpenDocument = this.onOpenDocument;
    final bool openable = entry.link.openableUri != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.isFramework ? 'Arrêté-cadre' : 'Arrêté de restriction',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text("S'applique à : ${entry.zones.map(_zoneTitle).join(' ; ')}"),
          // L'adresse brute, telle que recue (BR-014), selectionnable : la
          // copie se fait par selection (Q9-A).
          SelectableText(entry.link.raw),
          if (unopenedLink == entry.link.raw) const _UnopenedLinkNotice(),
          if (!openable)
            const Text(
              "Cette adresse ne peut pas être ouverte depuis l'application.",
            )
          else if (onOpenDocument != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ActionButton(
                label: entry.isFramework
                    ? "Ouvrir l'arrêté-cadre"
                    : "Ouvrir l'arrêté",
                onPressed: () => onOpenDocument(entry.link),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sous une adresse qui ne s'est pas ouverte : rien ne dit que le document
/// existe (`UC-002 A6`).
class _UnopenedLinkNotice extends StatelessWidget {
  const _UnopenedLinkNotice();

  @override
  Widget build(BuildContext context) {
    return const Text(
      "Ce lien n'a pas pu être ouvert depuis l'application. Son adresse "
      'reste affichée ci-dessus.',
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

# Matrice de traçabilité — US · BR · UC · tests

> **Task X2** du plan T1 (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`),
> mise à jour par la **Task X2** du plan T2 (`docs/superpowers/plans/2026-09-27-t2-secheresse-et-restrictions.md`,
> 2026-10-04).
> **Maintenue à la main, vérifiée mécaniquement** (décision 7) : générer cette matrice
> supposerait de parser des noms de test pour en déduire une intention — un couplage fragile
> qui produirait une matrice complète et fausse. `test/project/tracabilite_test.dart` **refuse
> les trous** — chaque `BR`, chaque `UC`, chaque `US` Must apparaît, chaque fichier de test
> cité existe réellement sur le disque (dans les trois tableaux), et les lignes que T2 livre
> citent les fichiers qui les éprouvent — sans jamais juger la justesse de l'intention : cela
> reste affaire de relecture.

Colonnes : **US** · **BR** · **UC** · **Fichier de test** · **Tranche** · **État**.

Légende de l'état : ✅ implémenté et couvert par un test · 🔄 décidé, pas encore couvert par un test.
Ce qu'un test ne prouve pas (un constat d'écran, un appel réel à la plateforme) s'écrit dans la
cellule ou en bas de page, jamais sous la marque ✅.

## User stories Must (US-01 → US-10)

| US | BR | UC | Fichier de test | Tranche | État |
|---|---|---|---|---|---|
| US-01 | BR-012 | UC-006 | `test/features/warnings/view/initial_warning_view_test.dart` (modal, lien « Relire le détail des sources » sans acquitter), `test/data/preferences/shared_preferences_acknowledgement_repository_test.dart`, `test/features/shared/data_sources_view_test.dart` (écran « D'où vient cette donnée ? »), `test/main_test.dart` (composition réelle : le lien du modal ouvre l'écran, rien n'est acquitté, le retour rend le modal tel qu'il était laissé) | T1/T2 | ✅ T1 ; lien du modal et écran des sources ✅ T2 (`S1`) |
| US-02 | BR-012, BR-001 | UC-006 | `test/features/map/view/map_view_test.dart` (contrôle toujours présent, ne recouvre pas les autres overlays, tap ouvre la fenêtre), `test/features/shared/warning_link_test.dart` (icône, libellé, clavier, lecteur d'écran), `test/features/map/view/map_overlays_phone_test.dart` (contrôle entier et atteignable à 360 × 640 et 390 × 844, à 100 % et 200 %, hors mode Restrictions : invariant ; mesuré en police Roboto) | T1/T2 | ✅ T1 (`W3c` constaté à l'écran par le commanditaire le 2026-09-23, `docs/project-state.md` point 41) ; T2 : atteignabilité aux largeurs de téléphone mesurée en test, jamais constatée à l'écran |
| US-03 | BR-007, BR-008, BR-009 | UC-001 | `test/features/map/view_model/map_view_model_test.dart`, `test/features/map/view/map_view_test.dart` | T1 | ✅ T1 |
| US-04 | BR-010, BR-011 | UC-004 | `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart` | T1 | ✅ T1 |
| US-05 | BR-002, BR-001 | UC-003 | `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart` | T1 | ✅ T1 |
| US-06 | BR-001, BR-005 | UC-003, UC-004 | `test/features/station_sheet/view/station_summary_sheet_test.dart` (phrase datée station, la fenêtre s'ouvre sur `warningLinkKey`), `test/features/onde_sheet/view/onde_summary_sheet_test.dart` (phrase datée ONDE, `warningWindowExtraTextKey`) | T1 | ✅ T1 |
| US-07 | BR-001, BR-007, BR-008, BR-011, BR-014 | UC-002 | `test/features/restrictions/view/restrictions_screen_test.dart` (niveau de gravité daté, échelle complète, zones d'eaux superficielles d'abord, aucun profil présélectionné, usages cités, aucune zone, échecs nommés), `test/features/restrictions/view_model/restrictions_view_model_test.dart`, `test/features/restrictions/view/drought_severity_badge_test.dart` (badge de gravité), `test/data/restrictions/vigieau_restriction_source_test.dart` (source, trois échecs nommés), `test/data/restrictions/vigieau_uris_test.dart` (latitude et longitude, jamais une commune), `test/data/restrictions/zones_mapper_test.dart` (mapper, seul point de conversion), `test/data/restrictions/profile_filter_equivalence_test.dart` (équivalence du filtrage par profil), `test/data/restrictions/cached_restriction_source_test.dart` (réponse gardée six heures, datée de sa récupération), `test/domain/restrictions/zones_at_point_test.dart`, `test/domain/restrictions/alert_zone_test.dart` (filtre par profil dans le domaine), `test/features/map/view/map_designation_test.dart` (désigner un point : appui long, clic droit, bouton), `test/features/map/view/designate_center_button_test.dart` (bouton « Restrictions au centre de la carte », indice de geste, réticule), `test/features/map/view/map_scale_chips_test.dart`, `test/features/map/view_model/map_view_model_test.dart` (choix « Restrictions » du sélecteur), `test/domain/restrictions/user_profile_test.dart` (les quatre profils d'usager, dans l'ordre d'`UC-002`), `test/features/restrictions/view/restrictions_scale_text_test.dart` (échelle de gravité en bande : aucun libellé coupé, paliers de colonnes ; mesuré en police Roboto), `test/main_test.dart` (composition réelle) | T2 | ✅ T2 au **point désigné** : ni position de l'appareil, ni échelle de sécheresse sur la carte, ni repli data.gouv, ni conservation au-delà de la session (non livrés) ; constaté à l'écran en partie seulement, par le commanditaire, en débogage sur Windows le 2026-10-04 (`docs/project-state.md`, point 48) ; rien sur l'exécutable de release ni sur Android (`P1`, `P2` dus) |
| US-08 | BR-013, BR-014, BR-007 | UC-002 | `test/features/restrictions/view/restrictions_screen_test.dart` (arrêtés en cartes : ouverture hors de l'application, adresse lisible, lien non ouvert, adresse non ouvrable, zone sans arrêté), `test/features/restrictions/view_model/restrictions_view_model_test.dart` (ouverture de lien), `test/domain/links/external_link_opener_test.dart` (port d'ouverture de lien), `test/data/links/url_launcher_external_link_opener_test.dart` (mode « hors de l'application »), `test/domain/restrictions/alert_zone_test.dart` (adresse ouvrable ou non), `test/data/restrictions/zones_mapper_test.dart` (adresse reprise telle que reçue) | T2 | ✅ T2 ; l'ouverture est éprouvée avec une fonction de lancement injectée : `launchUrl` n'est jamais appelé en vrai et aucun arrêté n'a été ouvert sur une cible (`P1`, `P2` dus) |
| US-09 | BR-013 | UC-002 | `test/features/restrictions/view/reinforced_warning_card_test.dart` (tête épinglée, corps, région d'alerte, aucun repli), `test/features/restrictions/view/restrictions_screen_test.dart` (encart en tête de chacun des états, avant le niveau de gravité, titre et action en place au défilement, à 200 %), `test/domain/warnings/warning_texts_test.dart` (texte de l'encart) | T2 | ✅ T2 (un seul écran de sécheresse existe : l'écran des restrictions) |
| US-10 | BR-005 | UC-005 | — (cache de tuiles constaté à l'écran, `NV-W2` de `docs/nfr.md` ; aucune persistance de `DerniereVueCarte` ni bandeau hors-ligne testés) | T1/T2 | 🔄 T1 (couverture partielle : seul le cache de tuiles des zones déjà parcourues est livré — `docs/project-state.md` point 10) |

## Règles métier (BR-001 → BR-014)

| BR | Fichier de test canonique | Tranche | État |
|---|---|---|---|
| BR-001 | `test/domain/observation/hydro_observation_test.dart` | T1 | ✅ |
| BR-002 | `test/domain/units/conversions_test.dart` | T0/T1 | ✅ |
| BR-003 | `test/project/vocabulary_test.dart` | T1 | ✅ |
| BR-004 | `test/features/map/view/station_marker_test.dart` | T1 | ✅ |
| BR-005 | `test/domain/observation/freshness_test.dart` | T1 | ✅ |
| BR-006 | `test/data/mappers/hydro_observation_mapper_test.dart` | T1 | ✅ |
| BR-007 | `test/domain/geo/viewport_filter_test.dart`, `test/features/restrictions/view/restrictions_screen_test.dart` (aucune zone et échecs nommés : jamais un état neutre) | T0/T1/T2 | ✅ |
| BR-008 | `test/features/map/view_model/map_view_model_test.dart` (l'échelle active ; le mode de désignation ne la change pas), `test/features/map/view/map_scale_chips_test.dart` (la puce « Restrictions » s'allume par `toggled`, jamais par `selected` ; l'échelle active reste sélectionnée), `test/features/map/view/map_designation_test.dart` (en mode, marqueurs et légende de l'échelle en cours restent rendus), `test/features/map/view/map_overlays_phone_test.dart` (ordre de la colonne aux largeurs de téléphone ; mesuré en police Roboto) | T1/T2 | ✅ T1 ; T2 : « Restrictions » est un interrupteur, pas une troisième échelle — **aucune échelle de sécheresse n'est dessinée sur la carte** ; sous 600 px la légende est repoussée sous un avis tant qu'il s'affiche (écart accepté le 2026-10-03, `BR-008`) |
| BR-009 | `test/domain/nomenclature/flow_severity_test.dart` | T1 (lot 4 bis) | ✅ |
| BR-010 | `test/domain/onde/campaign_age_test.dart` | T1 | ✅ |
| BR-011 | `test/domain/nomenclature/flow_category_test.dart`, `test/data/restrictions/zones_mapper_test.dart` (gravité et type de zone inédits gardés avec leur valeur brute, rupture de structure refusée en bloc), `test/domain/restrictions/drought_severity_test.dart`, `test/domain/restrictions/zone_kind_test.dart`, `test/features/restrictions/view/restrictions_screen_test.dart` (« Non renseigné », type de zone non renseigné) | T0/T1/T2 | ✅ |
| BR-012 | `test/features/warnings/view/initial_warning_view_test.dart`, `test/features/shared/data_sources_view_test.dart` (écran des sources, lien partagé par le modal et la fenêtre), `test/features/shared/warning_link_test.dart` (lien « D'où vient cette donnée ? » de la fenêtre), `test/main_test.dart` (composition réelle : relire les sources depuis le modal sans acquitter, puis depuis la carte) | T1/T2 | ✅ |
| BR-013 | `test/features/restrictions/view/reinforced_warning_card_test.dart` (tête épinglée, corps, région d'alerte, aucun repli ni fermeture), `test/features/restrictions/view/restrictions_screen_test.dart` (en tête de chacun des états, avant le niveau de gravité, ni repli ni masquage, à 200 %), `test/domain/warnings/warning_texts_test.dart` (texte de l'encart) | T2 | ✅ T2 (décision 11, révision du 2026-09-22 : l'emplacement attendait un écran de ressource, livré par `E4`) |
| BR-014 | `test/project/vocabulary_test.dart` | T1 | ✅ |

## Cas d'usage (UC-001 → UC-006)

| UC | Fichier de test | Tranche | État |
|---|---|---|---|
| UC-001 | `test/features/map/view_model/map_view_model_test.dart`, `test/features/map/view/map_view_test.dart`, `test/features/map/view/map_empty_states_test.dart` | T1 | ✅ |
| UC-002 | `test/features/restrictions/view/restrictions_screen_test.dart`, `test/features/restrictions/view_model/restrictions_view_model_test.dart`, `test/data/restrictions/vigieau_restriction_source_test.dart` (source, 409 refusé sans commune, trois échecs nommés), `test/data/restrictions/zones_mapper_test.dart`, `test/data/restrictions/profile_filter_equivalence_test.dart`, `test/data/restrictions/cached_restriction_source_test.dart` (réponse de session datée de sa récupération), `test/features/map/view/map_designation_test.dart` (déclencheur : désigner un point), `test/features/map/view/designate_center_button_test.dart` (bouton, indice de geste, réticule), `test/main_test.dart` (composition réelle : route de l'écran, retour, mode conservé) | T2 | ✅ T2 : flux nominal et alternatifs A1, A3, A4, A6 ; A5 pour la session seulement, sans bandeau hors-ligne ; **A2 livré pour l'échec nommé** — source injoignable, requête refusée, réponse illisible ou échec imprévu, avec l'adresse du site public et « Réessayer » (`lib/features/restrictions/view/restrictions_screen.dart`, textes des échecs) —, **seul le repli data.gouv n'est pas livré**, il est différé (Q3-B) ; la précondition est un point désigné, jamais une position ; le texte d'`UC-002` a été aligné sur ces choix le 2026-10-04 (`X3`) |
| UC-003 | `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart` | T1 | ✅ |
| UC-004 | `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart` | T1 | ✅ |
| UC-005 | — | T1/T2 | 🔄 T1 (couverture partielle : seul le cache de tuiles `flutter_map` des zones déjà parcourues est livré — `docs/project-state.md` point 10 ; `DerniereVueCarte`, le bandeau hors-ligne et le téléchargement de zone ne sont pas couverts) |
| UC-006 | `test/features/warnings/view/initial_warning_view_test.dart`, `test/features/warnings/view_model/warnings_view_model_test.dart`, `test/project/warning_texts_version_test.dart`, `test/main_test.dart` | T1 | ✅ |

## Ce que cette matrice ne prétend pas

- **US-07, US-08, US-09, UC-002 et BR-013** passent à ✅ T2 : couverts par des tests de domaine, de
  données (fixtures réelles du 2026-09-27, aucun appel réseau), de ViewModel et de vue. Ce que ces
  tests ne prouvent pas : les écrans de T2 n'ont été constatés qu'en partie, par le commanditaire,
  en débogage sur Windows le 2026-10-04 (`docs/project-state.md`, point 48), et aucun sur
  l'exécutable de release ni sur Android (`P1` et `P2` du plan T2 sont dus) ; `launchUrl` n'est
  jamais appelé en vrai ; les mesures de recouvrement des surcouches de la carte
  (`test/features/map/view/map_overlays_phone_test.dart`) sont des mesures en police Roboto, pas des
  constats d'écran, et Windows (Segoe UI) n'y est pas mesurée. Depuis le 2026-10-06 (revue de la
  PR #17), les verrous de gestes de la carte (`map_designation_test.dart`,
  `map_overlays_phone_test.dart`) et ceux du défilement de l'écran des restrictions sont **rejoués en
  plateforme Windows**, où la barre de défilement automatique du bureau change ce que reçoit la
  carte ; leurs largeurs y sont mesurées en Roboto enregistrée sous le nom « Segoe UI », un substitut :
  Segoe UI réelle n'est pas mesurée, et aucun de ces gestes n'est constaté à l'écran.
- **BR-013 et US-09** : l'annonce de l'encart renforcé par un lecteur d'écran (Narrateur,
  TalkBack) n'est **pas constatée**. `test/features/restrictions/view/reinforced_warning_card_test.dart`
  ne vérifie que l'indicateur de région d'alerte (`isLiveRegion`) sur la tête et son absence sur le
  corps (l'ordre des nœuds sémantiques l'est dans `restrictions_screen_test.dart`) ; ce que le
  lecteur lit réellement reste à constater sur appareil.
- **Non livré en T2, jamais compté comme un acquis** : la position de l'appareil (le point est
  toujours désigné sur la carte) ; l'échelle de sécheresse sur la carte — `BR-008` en nomme trois,
  la carte n'en dessine que deux, et le choix « Restrictions » du sélecteur n'en est pas une, il
  ne fait qu'allumer la désignation d'un point ; le repli `DataGouvBulkRestrictionSource`
  (`ADR-004`), à écrire sur rupture constatée ; la conservation des réponses au-delà de la session.
- **US-10 et UC-005** (carte hors-ligne) restent 🔄 T1 : ce qui est réellement livré et constaté à
  l'écran est le **cache de tuiles intégré à `flutter_map`** sur les zones déjà parcourues
  (`NV-W2`, `docs/nfr.md`). La persistance de `DerniereVueCarte`, le bandeau « Mode hors-ligne » et
  le téléchargement explicite d'une zone (`UC-005` flux nominal étapes 1, 4 et 6) ne sont couverts
  par aucun test — ce n'est pas prétendu ici (vérifié : aucun résultat pour `DerniereVueCarte`
  ni un équivalent dans `git ls-files test`). La réponse des restrictions gardée pendant la session
  (`A5` d'`UC-002`) n'est pas cette conservation : elle disparaît avec l'application.
- **BR-014** garde `test/project/vocabulary_test.dart` : son balayage lit déjà `lib/features/`, donc
  l'écran des restrictions ; la citation des mots du préfet est éprouvée par ailleurs dans
  `test/features/restrictions/view/restrictions_screen_test.dart`, sans que la matrice en fasse
  un fichier canonique de la règle.

# Matrice de traçabilité — US · BR · UC · tests

> **Task X2** du plan T1 (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`).
> **Maintenue à la main, vérifiée mécaniquement** (décision 7) : générer cette matrice
> supposerait de parser des noms de test pour en déduire une intention — un couplage fragile
> qui produirait une matrice complète et fausse. `test/project/tracabilite_test.dart` **refuse
> les trous** — chaque `BR`, chaque `UC`, chaque `US` Must apparaît, et chaque fichier de test
> cité existe réellement sur le disque — sans jamais juger la justesse de l'intention : cela
> reste affaire de relecture.

Colonnes : **US** · **BR** · **UC** · **Fichier de test** · **Tranche** · **État**.

Légende de l'état : ✅ implémenté · 🔄 décidé, pas encore couvert par un test.

## User stories Must (US-01 → US-10)

| US | BR | UC | Fichier de test | Tranche | État |
|---|---|---|---|---|---|
| US-01 | BR-012 | UC-006 | `test/features/warnings/view/initial_warning_view_test.dart`, `test/data/preferences/shared_preferences_acknowledgement_repository_test.dart` | T1 | ✅ T1 |
| US-02 | BR-012, BR-001 | UC-006 | `test/features/map/view/map_view_test.dart` (contrôle toujours présent, ne recouvre pas les autres overlays, tap ouvre la fenêtre), `test/features/shared/warning_link_test.dart` (icône, libellé, clavier, lecteur d'écran) | T1 | ✅ T1 (`W3c` constaté à l'écran par le commanditaire le 2026-09-23, `docs/project-state.md` point 41) |
| US-03 | BR-007, BR-008, BR-009 | UC-001 | `test/features/map/view_model/map_view_model_test.dart`, `test/features/map/view/map_view_test.dart` | T1 | ✅ T1 |
| US-04 | BR-010, BR-011 | UC-004 | `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart` | T1 | ✅ T1 |
| US-05 | BR-002, BR-001 | UC-003 | `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart` | T1 | ✅ T1 |
| US-06 | BR-001, BR-005 | UC-003, UC-004 | `test/features/station_sheet/view/station_summary_sheet_test.dart` (phrase datée station, la fenêtre s'ouvre sur `warningLinkKey`), `test/features/onde_sheet/view/onde_summary_sheet_test.dart` (phrase datée ONDE, `warningWindowExtraTextKey`) | T1 | ✅ T1 |
| US-07 | — | UC-002 | — | T2 | 🔄 T2 |
| US-08 | — | UC-002 | — | T2 | 🔄 T2 |
| US-09 | BR-013 | UC-002 | — | T2 | 🔄 T2 |
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
| BR-007 | `test/domain/geo/viewport_filter_test.dart` | T0/T1 | ✅ |
| BR-008 | `test/features/map/view_model/map_view_model_test.dart` | T1 | ✅ |
| BR-009 | `test/domain/nomenclature/flow_severity_test.dart` | T1 (lot 4 bis) | ✅ |
| BR-010 | `test/domain/onde/campaign_age_test.dart` | T1 | ✅ |
| BR-011 | `test/domain/nomenclature/flow_category_test.dart` | T0/T1 | ✅ |
| BR-012 | `test/features/warnings/view/initial_warning_view_test.dart` | T1 | ✅ |
| BR-013 | `test/domain/warnings/warning_texts_test.dart` (texte `reinforcedWarningBody` seul, pas d'écran) | T2 | 🔄 T2 (décision 11, révision du 2026-09-22 — aucun écran de T1 n'est un écran de ressource) |
| BR-014 | `test/project/vocabulary_test.dart` | T1 | ✅ |

## Cas d'usage (UC-001 → UC-006)

| UC | Fichier de test | Tranche | État |
|---|---|---|---|
| UC-001 | `test/features/map/view_model/map_view_model_test.dart`, `test/features/map/view/map_view_test.dart`, `test/features/map/view/map_empty_states_test.dart` | T1 | ✅ |
| UC-002 | — | T2 | 🔄 T2 (restrictions VigiEau non implémentées) |
| UC-003 | `test/features/station_sheet/view/station_summary_sheet_test.dart`, `test/features/station_sheet/view_model/station_sheet_view_model_test.dart` | T1 | ✅ |
| UC-004 | `test/features/onde_sheet/view/onde_summary_sheet_test.dart`, `test/features/onde_sheet/view_model/onde_sheet_view_model_test.dart` | T1 | ✅ |
| UC-005 | — | T1/T2 | 🔄 T1 (couverture partielle : seul le cache de tuiles `flutter_map` des zones déjà parcourues est livré — `docs/project-state.md` point 10 ; `DerniereVueCarte`, le bandeau hors-ligne et le téléchargement de zone ne sont pas couverts) |
| UC-006 | `test/features/warnings/view/initial_warning_view_test.dart`, `test/features/warnings/view_model/warnings_view_model_test.dart`, `test/project/warning_texts_version_test.dart`, `test/main_test.dart` | T1 | ✅ |

## Ce que cette matrice ne prétend pas

- **US-07, US-08, US-09** (sécheresse) et **UC-002** n'ont aucun fichier de test à l'échelle de
  l'écran ou du cas d'usage : leur état est 🔄 **T2**, la matrice ne compte aucun 🔄 comme un
  acquis. `test/data/restrictions/restriction_source_test.dart` existe déjà (`ADR-004`), mais il
  verrouille seulement la **signature** de l'interface `RestrictionSource` avec un double de
  test — aucun ViewModel ni écran sécheresse ne l'appelle encore, donc il ne couvre pas ces US
  ni `UC-002` au sens de cette matrice.
- **BR-013** (encart renforcé) porte l'état 🔄 **T2** (décision 11, révision du plan du
  2026-09-22) : son texte est verrouillé par `test/domain/warnings/warning_texts_test.dart`, mais
  aucun test ne prouve son **emplacement** — reporté en T2, aucun écran de T1 n'étant un écran de
  ressource.
- **UC-005** (carte hors-ligne) : ce qui est réellement livré et constaté à l'écran est le
  **cache de tuiles intégré à `flutter_map`** sur les zones déjà parcourues (`NV-W2`,
  `docs/nfr.md`). La persistance de `DerniereVueCarte`, le bandeau « Mode hors-ligne » et le
  téléchargement explicite d'une zone (`UC-005` flux nominal étapes 1, 4 et 6) ne sont couverts
  par aucun test — ce n'est pas prétendu ici (vérifié : aucun résultat pour `DerniereVueCarte`
  ni un équivalent dans `git ls-files test`).

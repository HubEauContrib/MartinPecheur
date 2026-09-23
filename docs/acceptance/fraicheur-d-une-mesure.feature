Fonctionnalité: La fraîcheur d'une observation hydrométrique
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD en T1 (décision 6 du plan). Vérifié par
  # test/project/acceptance_features_test.dart.
  #
  # Source : BR-005 (donnée périmée signalée), et les constantes
  # lib/domain/observation/freshness.dart (ancienneApres = 2 h,
  # perimeeApres = 24 h). Chaque borne appartient à l'état le plus sévère :
  # un âge de 2 h pile est déjà « ancienne », un âge de 24 h pile est déjà
  # « périmée » (lib/features/station_sheet/view_model/
  # station_sheet_view_model.dart, lib/domain/observation/
  # station_map_state.dart).
  En tant qu'usager consultant une station
  Je veux savoir depuis quand une observation n'a pas été renouvelée
  Afin de ne jamais confondre une mesure de sept minutes avec une mesure de neuf jours

  Scénario: Une observation de 1 h 59 reste fraîche
    Étant donné une observation hydrométrique mesurée il y a 1 h 59
    Quand la fiche de la station affiche son état
    Alors aucune mention d'ancienneté n'apparaît (BR-005)

  Scénario: Une observation de 2 h 00 devient ancienne
    Étant donné une observation hydrométrique mesurée il y a exactement 2 h 00
    Quand la fiche de la station affiche son état
    Alors la mention « Dernière mesure il y a 2 h » apparaît (BR-005)

  Scénario: Une observation de 23 h 59 reste ancienne
    Étant donné une observation hydrométrique mesurée il y a 23 h 59
    Quand la fiche de la station affiche son état
    Alors la mention « Dernière mesure il y a 23 h » apparaît, et le marqueur de la carte n'est pas encore atténué (BR-005)

  Scénario: Une observation de 24 h 00 devient périmée
    Étant donné une observation hydrométrique mesurée il y a exactement 24 h 00
    Quand la carte affiche le marqueur de cette station
    Alors ce marqueur est visuellement atténué
    Et la fiche affiche la date complète de la mesure à la place d'un décompte d'heures (BR-005)

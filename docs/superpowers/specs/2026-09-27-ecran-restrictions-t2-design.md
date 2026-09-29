# Conception de l'écran des restrictions, de la désignation et de l'écran des sources — T2

**Date :** 2026-09-27 · **Tâche :** `T2-C1`, étapes 1 à 4 · **Statut :** ~~🔄 **proposé, rien n'est arbitré, rien n'est codé** — étape 2 (relecture) et étape 3 (questions au commanditaire, § 10) à suivre ; `docs/04-ui.md` n'est **pas** amendé à cette étape.~~ → ✅ **arbitré** par le commanditaire (Q-1 à Q-5d le 2026-09-27, Q-5e à Q-8 le 2026-09-29), **toutes les recommandations retenues** — voir « Arbitrages du commanditaire » ci-dessous. **Rien n'est codé** : `E1`→`E4` et `S1` appliquent. `docs/04-ui.md` est amendé (§ 1 et § 3) le 2026-09-29 (étape 4).
**Applique, ne rediscute pas :** [cadrage T2](2026-09-27-cadrage-t2-design.md) (Q1 à Q10, § 4 Gherkin) · [modèle des restrictions](2026-09-27-modele-restrictions-t2-design.md) (§ 2, § 3 et sa note du 2026-09-27, § 6) · [plan T2](../plans/2026-09-27-t2-secheresse-et-restrictions.md) (« Décisions à valider » 1 à 10, arbitrées : **48 dp** partout, sources dans `features/shared/`, lien dans la fenêtre « ⚠ Avertissement »).

> Ce document fixe la **forme**, l'**ordre** et les **textes** ; il ne fixe ni le code ni le découpage (`E1`→`E4`, `S1`). Chaque exemple de valeur est **recopié d'une fixture** de `test/fixtures/vigieau/` (capturées le 2026-09-27), ou marqué « illustratif ». Ce qui n'est vérifié par aucune fixture ni aucun test est dit tel quel.

## Arbitrages du commanditaire — 2026-09-27 et 2026-09-29

Questions fermées du § 10, posées à l'étape 3 de `C1`. **Toutes les recommandations sont retenues** : ce qui était « proposé » dans les § 1 à 9 est désormais **décidé** (le mot « proposé » est barré là où il figurait, rien n'est supprimé).

| Question | Option retenue | Date | Conséquence sur le plan T2 |
|---|---|---|---|
| **Q-1** Forme | **(a)** écran plein au-dessus de la carte, titre « Sécheresse et restrictions », bouton de retour | 2026-09-27 | `E2` rend un écran (`RestrictionsScreen`), pas un panneau ; `E3` pousse la route |
| **Q-2** Désignation | **(a)** appui long (toucher) et clic droit (souris), **et** un bouton « Restrictions au centre de la carte », 48 × 48 dp, dans la colonne des contrôles, atteint par `Tab`, qui désigne le centre de la caméra | 2026-09-27 | `E1` |
| **Q-2b** Épingle | **(a)** gardée jusqu'à la désignation suivante, **tenue par l'état de la vue carte** (`_MapViewState`) ; aucun amendement de `V1` ni de `MapViewModel`, aucun état dans `main.dart` | 2026-09-27 | `E1` |
| **Q-3** Profil | **(a)** un seul choix, après les zones et les arrêtés, avant les usages groupés par zone | 2026-09-27 | `E2` |
| **Q-4** Encart au défilement | **(a)** titre et action épinglés, corps (et adresse du site public) en premier élément du défilement ; **`BR-013` (« ni disparition au défilement ») lu comme visant le titre et l'action** ; critère : à 800 × 700 et 200 %, la partie épinglée laisse au moins la moitié de la hauteur utile, sinon arrêt et question | 2026-09-27 | `E4` |
| **Q-4 amendé** (2026-09-29) | Note du 2026-09-29 (arbitrage du commanditaire, Q-4 amendé pour les petits écrans, `E4`) : le titre et l'action restent épinglés **tant qu'ils prennent au plus la moitié de la hauteur utile** (mesure réelle, aucun seuil en pixels) ; sinon **tout l'encart (titre, action, corps) est le premier élément du défilement**, toujours en tête, non repliable, dans tous les états. Mesuré à 200 % : 800 × 740 → 192 px sur 620 (31,0 %, épinglé) ; 411 × 891 → 312 sur 659 (47,3 %, épinglé) ; 360 × 640 → 432 sur 352 (122,7 %, non épinglé). À 100 % sur 360 × 640 : 116 sur 576 (20,1 %, épinglé). | 2026-09-29 | `E4` |
| **Q-5a** Types de zone | **(a)** Eaux superficielles · Eaux souterraines · Eau potable · Type de zone non renseigné | 2026-09-27 | `E2` (`zoneKindLabel`) |
| **Q-5b** Profils (`O9`) | **(a)** titre « Profil d'usager » : Particulier · Exploitation · Collectivité · Entreprise | 2026-09-27 | `E2` (`userProfileLabel`) ; `O9` clos |
| **Q-5c** Gravité inconnue | **(a)** « Non renseigné » accompagné de la phrase de `BR-007` telle quelle | 2026-09-27 | `E2` |
| **Q-5d** Échec imprévu | **(a)** nouvel état du ViewModel **`RestrictionsNonObtenues`**, au texte neutre — **revient sur l'arbitrage du 2026-09-27 relatif à `V1`** (échec imprévu rangé dans `RestrictionsEnEchec(cause: SourceInjoignable(…))`) : deux tests de `V1` réécrits, `retry()` étendu | 2026-09-27 | nouvelle tâche **`T2-V1b`**, avant `E2` |
| **Q-5e** Autres textes | **(a)** textes du § 5.2 et du § 5.3 validés **en bloc**, `theme` non affiché en T2 compris | 2026-09-29 | `E2` |
| **Q-6** Même arrêté | **(a)** section « Arrêtés » dédoublonnée par adresse exacte, zones nommées | 2026-09-29 | `E2` |
| **Q-7** Badge | **(a)** libellé posé **à côté** du badge, contour noir de 2 px sur chaque badge, second liseré de Crise **blanc** | 2026-09-29 | `E2` |
| **Q-8** Écran des sources | **(a)** contenu du § 8, écran plein, lien « D'où vient cette donnée ? » dans la fenêtre « ⚠ Avertissement » | 2026-09-29 | `S1` |

**Restent à vérifier par appel réel** (§ 8, « À valider ») — ajouté à `S1` comme étape préalable : (1) la **licence de la donnée servie par l'API VigiEau** (aujourd'hui relevée pour le jeu data.gouv associé seulement) ; (2) la **version de la Licence Ouverte** qui couvre Hub'Eau. Tant qu'elles ne sont pas constatées, l'écran des sources n'affirme pas de numéro de version.

**Rattaché par ailleurs** : la décision 1 du plan (`minimumTapTarget` porté à 48 sur toutes les plateformes, arrêt et question si la disposition à 800 × 700 rougit), arbitrée le 2026-09-27, devient la tâche **`T2-K4`**, avant `E2`.

## 0. Constats faits pour cette conception

| # | Constat | Où | Conséquence |
|---|---|---|---|
| K-1 | `MapOptions` porte `onTap`, `onSecondaryTap` (clic droit) et `onLongPress`, chacun rendant la position `LatLng` | **lu dans le paquet installé** `flutter_map-8.3.2/lib/src/map/options/options.dart` l. 90-98 | la désignation au pointeur ne demande aucune bibliothèque (§ 2) |
| K-2 | La carte n'utilise aujourd'hui **aucun** des trois : un tap sur le fond de carte ne fait rien | `lib/features/map/view/map_view.dart`, `_mapOptions` | aucun geste existant n'est détourné |
| K-3 | **Aux quatre points qui portent une zone, toutes les zones du point citent le même arrêté et le même arrêté-cadre** (adresses identiques) | `zones_ain_…_sans_profil_…` (3 zones), `zones_paris_…` (3), `zones_corse_…` (3), `zones_ariege_…` (2) | le dédoublonnage n'est pas un cas parisien : c'est le cas **des quatre points à zones capturés** (§ 6) |
| K-4 | **Le ViewModel rabat toute `Exception` ou `Error` non nommée sur `SourceInjoignable`** : la vue ne peut **pas** distinguer une panne de la source d'un échec imprévu | `lib/features/restrictions/view_model/restrictions_view_model.dart` l. 158-196 | la contrainte du 2026-09-27 (texte neutre) **ne peut pas être tenue par la vue seule** : question **Q-5d** (§ 5.4) |
| K-5 | Contrastes WCAG calculés (formule de luminance relative) sur les teintes de `04-ui.md § 2`, échelle 3 : texte blanc sur `#D55E00` = **3,87:1** ; blanc sur `#767676` = **4,54:1** ; `#F0E442` contre blanc = **1,32:1** ; `#E69F00` contre blanc = **2,25:1** | calcul du 2026-09-27, à verrouiller par test en `E2` | un libellé d'état écrit **sur** la teinte n'atteint pas le 7:1 de `04-ui.md § 3` : le libellé se pose **à côté** du badge (§ 7) |
| K-6 | Le panneau des fiches est posé en bas à gauche, 420 px de large au plus, **sur** la carte, qui porte les teintes `#E69F00` et `#D55E00` en échelle écoulement (▲ « Eau stagnante », ■ « À sec ») | `map_view.dart` `buildMapOverlays`, `04-ui.md § 2` | un panneau de restrictions sur la carte montrerait **deux échelles à la fois**, mêmes teintes, formes voisines (▲ contre ▲!) : argument du § 1 |

## 1. Forme — écran plein, au-dessus de la carte

~~**Proposition :**~~ **Décision (Q-1 (a), 2026-09-27) : un écran plein**, poussé par-dessus la carte à la désignation d'un point (route de navigation), titre « Sécheresse et restrictions », bouton de retour. Au retour, la carte réapparaît **avec la marque du point désigné** (§ 2), qui disparaît à la désignation suivante ~~ou à la fermeture~~ — *correction du 2026-09-29 : « ou à la fermeture » contredisait Q-2b (a), l'épingle reste après la fermeture de l'écran jusqu'à la désignation suivante.*

```
┌──────────────────────────────────────┐
│ ←  Sécheresse et restrictions        │
├──────────────────────────────────────┤  ┐
│ ⚠ NE FONDEZ AUCUNE DÉCISION SUR      │  │ partie épinglée de l'encart (§ 4) :
│   CET ÉCRAN                          │  │ ne défile jamais
│ [ Consulter les arrêtés en vigueur ] │  │
├──────────────────────────────────────┤  ┘
│ Les seules règles qui s'appliquent … │  ┐ corps de l'encart, premier élément
│ Ces données ne remplacent pas …      │  │ du défilement
│ https://vigieau.gouv.fr/             │  ┘
│ … contenu selon l'état (§ 3)          │
└──────────────────────────────────────┘
```

| Alternative | Pourquoi écartée |
|---|---|
| **Panneau sur la carte**, à l'emplacement des fiches (défaut du plan, `E2`) | (1) **`BR-008`** : la carte reste en échelle écoulement ou débit sous un panneau en échelle 3, mêmes teintes, formes voisines (K-6) — exactement la superposition que `BR-008` interdit, même si la règle vise la carte. (2) À 800 × 700 et 200 % de police, l'encart seul dépasse la hauteur de la fenêtre (§ 4) : le panneau couvrirait la carte de toute façon, puces et légende comprises. (3) Sur Android (~ 411 dp de large), 420 px = pleine largeur. (4) Clavier et lecteur d'écran : la tabulation traverserait jusqu'à 1 487 marqueurs (constat de `K2`) avant ou après le panneau ; un écran plein contient le focus. |
| Hybride : panneau sur fenêtre large, écran plein sur fenêtre étroite | deux dispositions à tester pour un seul écran (YAGNI) ; garde le défaut (1) sur fenêtre large |

**Ce que coûte la ~~proposition~~ décision :** désigner un autre point demande un retour puis un nouveau geste (deux actions au lieu d'une). Le point interrogé reste rappelé en toutes lettres (§ 3) et marqué sur la carte au retour. Conséquences sur le plan : `E2` rend un écran (`RestrictionsScreen`), pas un panneau ; `E3` pousse la route depuis `onPointDesignated` et appelle `close()` au retour ; « sélection d'une station → écran fermé » devient sans objet (l'écran couvre la carte) ; `Échap` et le retour Android ferment l'écran.

## 2. Désignation d'un point

~~**Proposition :**~~ **Décision (Q-2 (a) et Q-2b (a), 2026-09-27) :**

| Entrée | Geste | Vérifié |
|---|---|---|
| Toucher (Android) | **appui long** sur la carte (`MapOptions.onLongPress`) | signature lue (K-1) ; effet à l'écran **jamais constaté** |
| Souris (Windows) | **clic droit** (`onSecondaryTap`) **et** appui long | idem |
| Clavier, lecteur d'écran, et tout usager qui ignore l'appui long | un **bouton** « Restrictions au centre de la carte » dans la colonne des contrôles (`MapControls`, bas à droite), 48 × 48 dp, qui désigne le **centre de la caméra** ; atteint par `Tab` dans l'ordre existant des contrôles | — |

- **Marque du point désigné : oui.** Une épingle noire à halo blanc (forme hors de toute famille d'échelle : ni rond plein, ni triangle, ni carré, ni chevron, ni badge), **inerte au pointeur** (elle ne capte aucun tap), exclue de la tabulation. Elle **reste jusqu'à la désignation suivante** (Q-2b) : l'écran étant plein (§ 1), l'épingle n'est **visible qu'après le retour**, c'est-à-dire après `close()`.
- **Où vit le point retenu.** `close()` émet `RestrictionsFermees`, qui ne porte **aucun** point : l'état de `RestrictionsViewModel` ne peut pas nourrir l'épingle après la fermeture. Trois emplacements possibles :

  | Emplacement | Effet | Retenu |
  |---|---|---|
  | **L'état de la vue carte** (`_MapViewState`) : la carte connaît le point au moment même du geste ou du bouton (c'est elle qui appelle `onPointDesignated`), elle le garde et dessine l'épingle | aucun amendement de `V1`, ni de `MapViewModel`, ni de `main.dart` ; la carte ne nomme pas la tranche restrictions (`feature-vers-feature`) ; testable par un test de widget de `E1` | ~~**proposé**~~ **retenu (Q-2b (a))** |
  | `RestrictionsViewModel`, par un accesseur `lastPoint` qui survit à `close()` (amendement de `T2-V1`) | un souci d'affichage de la carte logé dans le ViewModel d'une autre tranche ; tests de `V1` à compléter ; `main.dart` doit relayer le point vers `MapView` | écarté |
  | Un état tenu par `main.dart` (un `ValueNotifier<GeoPoint?>` posé au rappel de désignation) | de l'état d'écran dans la racine de composition, qui n'en porte aucun aujourd'hui ; aucun gain sur l'état de la vue carte | écarté |

  *(Q-2b a retenu (a) : la phrase suivante reste pour mémoire.)* Si Q-2b retient « effacée à la fermeture », l'épingle ne serait **jamais vue** avec un écran plein (elle n'existerait que sous l'écran) : cette option n'a de sens qu'avec un panneau (Q-1 b).
- **Conflit avec la sélection d'un marqueur :** le **tap simple** sur un marqueur ouvre toujours sa fiche (tests existants inchangés, `E1`). Un appui long ou un clic droit **sur** un marqueur désigne le **lieu** sous le pointeur, pas la station : une restriction se lit en un lieu, jamais d'une station (Q1-B écartée). ⚠️ **Non vérifié :** que l'arène de gestes de `flutter_map` laisse bien l'appui long à la carte quand il commence sur un `GestureDetector` de marqueur qui n'a que `onTap` — à fixer par un test de `E1`, et à constater à l'écran.
- Les rappels passés à `MapOptions` restent des **références de méthode**, jamais des fermetures créées à chaque `build` (égalité de `MapOptions`, commentaire `NFR-01` de `_mapOptions`).

| Alternative | Pourquoi écartée |
|---|---|
| **Tap simple** sur le fond de carte | désignation accidentelle à chaque tap manqué à côté d'un marqueur : un appel réseau et un écran plein qui s'ouvrent sans intention |
| **Mode « désigner »** à bascule (le tap suivant désigne) | un état de plus à la carte, et à tester, pour ce que l'appui long fait sans état |
| Clavier par **raccourci seul** (une touche sur la carte) | invisible, donc introuvable ; et le nœud « carte » est sauté par `Tab` dès qu'un marqueur est dessiné (`skipTraversal`, `K2`) |
| Pas de marque | au retour de l'écran, rien ne dit quel lieu a été interrogé ; les coordonnées seules ne se lisent pas sur une carte |

## 3. Ordre du contenu

~~**Proposition,**~~ **Décision (Q-3 (a), 2026-09-27), identique dans tous les états** pour sa tête :

1. **Encart renforcé** — partie épinglée puis corps (§ 4). Non négociable, premier contenu dans les cinq états visibles.
2. **Point interrogé** : « Point désigné : 46,20000° N, 5,22600° E » — point de la fixture de l'Ain, `lat=46.2&lon=5.226` (`CAPTURES.md`) — (virgule décimale, cinq décimales pour l'affichage seul — la requête garde le point exact, modèle § 2.2 ; `S` et `O` pour les valeurs négatives).
3. **Date de récupération** (`ZonesTrouvees`, `AucuneZone`) : « Réponse de VigiEau obtenue le 27/09/2026 à 13:25 » — capture de l'Ain à 11:25:24 UTC (`CAPTURES.md`), rendue à l'heure de Paris (UTC+2) — (`formatLocalDateTime`, Q7-A).
4. **Zones d'eaux superficielles** (`surfaceWaterZones`), chacune : libellé de type, nom de zone, badge + libellé de gravité + « depuis le 20/08/2026 », puis « jusqu'au 31/10/2026 », puis l'échelle complète, sa ligne marquée « ← cette zone ».
5. **« Autres zones au même point »** (`otherZones`, ordre du domaine : souterraines, eau potable, type inconnu), même bloc par zone.
6. **Arrêtés** — dédoublonnés (§ 6).
7. **Profil d'usager** — **un seul** choix, pour toutes les zones : quatre boutons de 48 dp, aucun sélectionné.
8. **Usages restreints** pour le profil choisi, **groupés par zone dans l'ordre 4-5**, chaque groupe titré par son type, son nom et son niveau daté ; le profil rappelé au-dessus.

Croquis — Ain (`zones_ain_bourg-en-bresse_sans_profil_…`), profil non choisi :

```
│ Point désigné : 46,20000° N, 5,22600° E      │
│ Réponse de VigiEau obtenue le 27/09/2026 à   │
│ 13:25                                        │
│ EAUX SUPERFICIELLES                          │
│ Rivières de Bresse                           │
│  ▲!  Alerte · depuis le 20/08/2026           │
│      jusqu'au 31/10/2026                     │
│  Échelle : ●! Vigilance                      │
│            ▲! Alerte          ← cette zone   │
│            ▲!! Alerte renforcée              │
│            ⬣✕ Crise                          │
│ AUTRES ZONES AU MÊME POINT                   │
│ Le point désigné se trouve aussi dans ces    │
│ zones d'alerte. Chacune a son niveau et ses  │
│ usages.                                      │
│ Eaux souterraines — Dombes - Certines - Nord │
│  ●!  Vigilance · depuis le 20/08/2026 …      │
│ Eau potable — Rivières de Bresse             │
│  ▲!  Alerte · depuis le 20/08/2026 …         │
│ ARRÊTÉS (§ 6)                                │
│ PROFIL D'USAGER                              │
│ [Particulier][Exploitation]                  │
│ [Collectivité][Entreprise]                   │
│ Les usages restreints s'affichent une fois   │
│ un profil choisi.                            │
```

Par état :

| État (`RestrictionsState`) | Après les points 1-2 |
|---|---|
| `RestrictionsEnCours` | texte de chargement ; **aucun** badge, niveau ni échelle (`BR-007`) |
| `ZonesTrouvees` | 3 à 8 |
| `AucuneZone` | 3, puis les deux phrases d'absence (§ 5) ; ni profil, ni badge |
| `RestrictionsEnEchec` et `RestrictionsNonObtenues` (état neutre de Q-5d (a), tâche `T2-V1b`) | le texte d'échec (§ 5.3), l'adresse du site public, « Réessayer » ; aucun niveau |

| Alternative | Pourquoi écartée |
|---|---|
| Choix du profil **en tête**, avant les zones | retarde la lecture du niveau et fait croire que le niveau dépend du profil (il n'en dépend pas, modèle § 2.4) |
| Un choix de profil **par zone** | le profil est unique pour la session (Q2-A, un seul `profile` dans le ViewModel) ; trois choix identiques à tenir cohérents |
| Usages **sous chaque zone**, dans le bloc du niveau | le profil devrait alors précéder la première zone (même défaut que ci-dessus) ; l'Ain donnerait trois listes (27, 19, 45 usages sans filtre) intercalées entre les niveaux |
| **Une** échelle commune, plusieurs positions marquées | invite à comparer les zones et à en retenir « la plus sévère », ce que le modèle refuse (§ 2.7, aucun rang) |

## 4. Tenue de l'encart au défilement

**Contrainte mesurée par estimation, non constatée :** à 200 % de police, sur 800 × 700 (hauteur utile ~ 644 px sous la barre de titre), le corps de l'encart (`reinforcedWarningBody`, ~ 290 caractères en deux paragraphes), le titre et l'action occupent **de l'ordre de 700 px** — plus que la hauteur utile. **Épingler l'encart entier rend le contenu inatteignable** à 200 %.

~~**Proposition :**~~ **Décision (Q-4 (a), 2026-09-27) : épinglage partiel.** Le **titre** (« ⚠ NE FONDEZ AUCUNE DÉCISION SUR CET ÉCRAN ») **et l'action** (« Consulter les arrêtés en vigueur ») sont épinglés en tête, **ne défilent jamais** ; le **corps** et l'adresse du site public sont le **premier élément** du défilement, sur le même fond, collés à la partie épinglée. Estimation de la partie épinglée à 200 % : ~ 200 px sur 644 (≈ 31 %) à 800 px de large, ~ 250 px sur un téléphone de 411 dp (≈ 36 %). Critère ~~proposé~~ retenu pour `E4` : **à 800 × 700 et 200 %, la partie épinglée laisse au moins la moitié de la hauteur utile au contenu** ; sinon, arrêt et question.

- La région d'alerte (`Semantics(liveRegion: true)`) couvre titre, corps et action, annoncés **dans cet ordre, avant tout autre contenu**.
- Rien de ce que l'usager peut actionner ne replie, ferme ou masque une partie de l'encart ; la partie épinglée ne rétrécit pas au défilement.
- À chaque nouveau point, le défilement revient **en haut** : le corps est de nouveau visible en entier.
- ⚠️ **Limite de la ~~proposition~~ décision, ~~à dire au commanditaire~~ dite au commanditaire et acceptée par lui (Q-4 (a), 2026-09-27) :** le **corps** porte l'énumération de `BR-013` (« ni les arrêtés préfectoraux, ni une décision d'irrigation, ni une évaluation de sécurité ») ; au défilement, **il sort de l'écran**. L'option ne tient « ni disparition au défilement » que si l'on lit `BR-013` comme visant **le titre et l'action**. Aucune des trois options ne tient à la fois la lettre de `BR-013` pour l'encart entier **et** « jamais tronqué » à 200 % : l'arbitrage choisit laquelle des deux exigences se lit au plus près.
- ⚠️ Conséquence sur `E4` : la surface de `ReinforcedWarningCard({onConsultDecrees})` se dédouble en une tête épinglée et un corps. Le verrou « aucun paramètre de repli, de fermeture ni de masquage » vaut pour les deux.
- *Note du 2026-09-29 (arbitrage de la boucle principale, `E4`) : une **seule** région d'alerte, sur la tête épinglée (titre, action) ; le corps n'en est plus une, pour éviter la double annonce. Écart d'ordre assumé : l'annonce dit titre, action, puis le corps est lu au parcours ordinaire — et non « titre, corps, action » comme le disait la phrase ci-dessus.*
- *Note du 2026-09-29 (arbitrage du commanditaire, Q-4 amendé pour les petits écrans, `E4`) : le titre et l'action restent épinglés **tant qu'ils prennent au plus la moitié de la hauteur utile** (mesure réelle, aucun seuil en pixels) ; sinon **tout l'encart (titre, action, corps) est le premier élément du défilement**, toujours en tête, non repliable, dans tous les états. Mesuré à 200 % : 800 × 740 → 192 px sur 620 (31,0 %, épinglé) ; 411 × 891 → 312 sur 659 (47,3 %, épinglé) ; 360 × 640 → 432 sur 352 (122,7 %, non épinglé). À 100 % sur 360 × 640 : 116 sur 576 (20,1 %, épinglé).*

| Alternative | Pourquoi écartée |
|---|---|
| (a) **Encart entier épinglé** | contenu inatteignable à 200 % (estimation ci-dessus) : contraire à « jamais tronqué » (`04-ui.md § 3`) |
| (b) **Premier élément du défilement**, sans rien d'épinglé | le titre et l'action sortent aussi de l'écran au défilement, en plus du corps : écart plus large à `BR-013` que la proposition, qui demanderait un amendement |
| (c) Épinglage **adaptatif** (entier si la place le permet, partiel sinon) | deux comportements à tester selon la police et la fenêtre, pour un gain de confort seulement |

## 5. Textes

Tous au vouvoiement, sans verbe d'instruction sur un usage de l'eau (`BR-014`), sans mot banni. Les **mots du préfet** (noms de zone, `name`, `description`) arrivent à l'exécution et ne sont pas des littéraux (`vigieauLabelExceptions` reste vide).

### 5.1 Libellés des nomenclatures

> **Arbitré le 2026-09-27 : Q-5a (a) et Q-5b (a).** La colonne « Libellé ~~proposé~~ » donne les libellés **retenus**, mot pour mot.

| Fonction | Valeur | Libellé ~~proposé~~ retenu | Provenance |
|---|---|---|---|
| `zoneKindLabel` | `EauxSuperficielles` | **Eaux superficielles** | croquis `04-ui.md § 1` ; schéma `ZoneDto.type` « eau superficielle » (`swagger_…`) |
| | `EauxSouterraines` | **Eaux souterraines** | schéma « eau souterraine » |
| | `EauPotable` | **Eau potable** | schéma « eau potable » |
| | `TypeZoneInconnu` | **Type de zone non renseigné** | `BR-011` (« non renseigné ») ; la valeur brute n'est pas affichée |
| `userProfileLabel` | `particulier` | **Particulier** | `UC-002` étape 4, croquis |
| | `exploitation` | **Exploitation** | `UC-002` étape 4 ; champ `concerneExploitation` |
| | `collectivite` | **Collectivité** | `UC-002`, croquis |
| | `entreprise` | **Entreprise** | `UC-002`, croquis |
| titre du choix | — | **Profil d'usager** | terme que `X3` ajoute au glossaire |
| `droughtSeverityLabel` | — | inchangé : Vigilance, Alerte, Alerte renforcée, Crise, Non renseigné | `04-ui.md § 2` (déjà codé) |

Alternatives écartées : « Exploitant » avec « Je suis : » (croquis) — l'étiquette d'une personne pour un champ qui nomme une **entité** (`concerneExploitation`), et « Je suis : Collectivité » ne se lit pas ; « Exploitation agricole » — précision que ni l'API ni `UC-002` ne donnent (inventée) ; « Alimentation en eau potable » pour `AEP` — développement de sigle que le schéma n'écrit pas.

### 5.2 Textes de l'écran

> **Arbitré : Q-5c (a) le 2026-09-27, Q-5e (a) le 2026-09-29 (validés en bloc).** Les textes ci-dessous sont **retenus**, mot pour mot.

| Situation | Texte ~~proposé~~ retenu |
|---|---|
| Chargement | « Recherche des zones d'alerte pour ce point… » |
| Point interrogé | « Point désigné : {lat}° {N\|S}, {lon}° {E\|O} » |
| Date de récupération | « Réponse de VigiEau obtenue le {JJ/MM/AAAA à HH:MM} » |
| Niveau daté | « {libellé} · depuis le {JJ/MM/AAAA} » (`formatCalendarDate`, sans conversion) |
| Date de fin | « jusqu'au {JJ/MM/AAAA} » |
| Date de fin absente | « Date de fin non transmise par la source. » |
| Intro des autres zones | titre « Autres zones au même point », puis « Le point désigné se trouve aussi dans ces zones d'alerte. Chacune a son niveau et ses usages. » |
| Gravité inconnue | badge et libellé « Non renseigné », puis la phrase de `BR-007` telle quelle : « Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de votre préfecture. » (Q-5c) |
| `AucuneZone` | « VigiEau ne renvoie aucune zone d'alerte pour ce point. » puis, **exactement**, « Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de votre préfecture. » (`UC-002 A3`) |
| Profil non choisi | « Les usages restreints s'affichent une fois un profil choisi. » |
| Profil rappelé | « Usages restreints pour le profil {Particulier} » |
| Attribution des citations (une fois, sous le titre ci-dessus) | « Textes cités tels que transmis par VigiEau. Seul l'arrêté fait foi. » |
| Un usage | `name` en gras, puis `description` **à l'identique** (`\n` et espaces de fin compris), encadrée de « » posés **hors** de la chaîne citée (le test d'égalité de `E2` porte sur la chaîne seule) |
| Aucun usage pour ce profil, dans une zone | « VigiEau ne transmet aucun usage pour le profil {Particulier} dans cette zone. Seul l'arrêté fait foi : consultez-le. » |
| Zone sans lien d'arrêté | « Le texte de l'arrêté n'est pas accessible depuis l'application : la source n'en transmet pas l'adresse. » |
| Adresse non ouvrable (`openableUri` nul) | l'adresse, puis « Cette adresse ne peut pas être ouverte depuis l'application. » |
| Lien qui ne s'est pas ouvert (`unopenedLink`) | sous l'adresse concernée : « Ce lien n'a pas pu être ouvert depuis l'application. Son adresse reste affichée ci-dessus. » — rien ne dit que le document existe (`UC-002 A6`) |
| Bouton d'ouverture | « Ouvrir l'arrêté » · « Ouvrir l'arrêté-cadre » |
| Réessayer | « Réessayer » |

`theme` (`thematique`) n'est **pas** affiché en T2 (~~proposé, compris dans Q-5e~~ décidé par Q-5e (a), 2026-09-29). Le nom de l'usage le recoupe **dans les exemples lus en Ariège** (« Irriguer » / « Irrigation agricole des cultures… »), **pas partout** : dans l'Ain, « Irriguer » couvre « Prélèvements d'eau pour l'horticulture, les cultures expérimentales de divers organismes », et « Nettoyer » couvre « Lavage des façades et toitures ». Le thème reste l'étiquette de VigiEau, pas un mot de l'app ; l'afficher plus tard, en préfixe du nom, ne casse rien. Alternative : l'afficher dès T2 en préfixe discret.

### 5.3 Échecs

> **Arbitré : Q-5d (a) le 2026-09-27, Q-5e (a) le 2026-09-29.** Textes **retenus** ; la ligne « Échec imprévu » est portée par le nouvel état `RestrictionsNonObtenues` (§ 5.4, tâche `T2-V1b`), jamais par `RestrictionsEnEchec`.

| Cause | Texte ~~proposé~~ retenu |
|---|---|
| `SourceInjoignable` | « VigiEau n'a pas répondu. Aucun niveau n'est disponible pour ce point. » — même tournure que la fiche station (« Hub'Eau n'a pas répondu pour la station … ») |
| `ReponseIllisible` | « La réponse de VigiEau n'a pas pu être lue par l'application. Aucun niveau n'est affiché. » |
| `RequeteRefusee` | « VigiEau a répondu, mais n'a pas pu servir ce point. Aucun niveau n'est affiché. » — ne dit pas « injoignable » |
| **Échec imprévu** (ni l'une ni l'autre des trois branches) — état `RestrictionsNonObtenues` | « Les restrictions n'ont pas pu être obtenues pour ce point. Aucun niveau n'est affiché. » — ne nomme pas la source |
| Toutes | puis « Les arrêtés en vigueur restent consultables à l'adresse https://vigieau.gouv.fr/ » (adresse sélectionnable ; l'action de l'encart, épinglée, l'ouvre), puis « Réessayer » |

### 5.4 Le texte neutre ne peut pas être tenu par la vue seule (K-4)

La contrainte du 2026-09-27 demande le texte neutre pour un échec **non nommé**. Or `RestrictionsViewModel.open` le range dans `RestrictionsEnEchec(cause: SourceInjoignable(...))`, **indiscernable** d'une vraie panne de VigiEau. La vue a deux sorties, toutes deux fautives : nommer VigiEau pour un bug qui n'est pas le sien (contraire à la contrainte), ou rendre neutre **toute** panne (contraire au Gherkin `US-07` « il nomme la source qui n'a pas répondu » et à `BR-007`, « message par source »).

~~**Proposition :**~~ **Décision (Q-5d (a), 2026-09-27) :** amender `T2-V1` avant `E2` — tâche **`T2-V1b`** du plan — un **~~cinquième~~ sixième état** du ViewModel (*correction du 2026-09-29 : `RestrictionsState` en compte déjà cinq — `Fermees`, `EnCours`, `ZonesTrouvees`, `AucuneZone`, `EnEchec` ; le nouveau est le sixième*), `RestrictionsNonObtenues(point)`, émis par les clauses `on Exception` et `on Error` (la seconde garde son `FlutterError.reportError`). `RestrictionLookupFailure` et le domaine ne changent pas. Le `switch` exhaustif de la vue rend l'oubli impossible.

⚠️ **Ce que cette ~~proposition~~ décision défait et coûte** (accepté par le commanditaire) **:**
- Elle **revient sur l'arbitrage du 2026-09-27 quant à l'état** : le commanditaire a retenu un échec imprévu rangé dans le **même** `RestrictionsEnEchec(cause: SourceInjoignable(...))` qu'une panne, et ce choix est **verrouillé par un test de `V1`** (`test/features/restrictions/view_model/restrictions_view_model_test.dart`, « un StateError (Error, non nomme) -> RestrictionsEnEchec(cause: SourceInjoignable) … », et le test voisin pour une `Exception` ordinaire). Seul « erreur remontée à `FlutterError` » reste intact.
- **Tests de `V1` à réécrire** : ces deux tests attendront `RestrictionsNonObtenues` ; pour une `Exception`, le `diagnostic` n'a plus de porteur (l'`Error`, elle, reste remontée) — ~~à accepter, ou à doter le nouvel état d'un champ~~ **accepté** : l'option arbitrée nomme `RestrictionsNonObtenues(point)`, sans autre champ ; `T2-V1b` n'en ajoute pas (YAGNI : la vue n'affiche jamais le diagnostic).
- **`retry()` à étendre** : il ne réinterroge aujourd'hui que depuis `RestrictionsEnEchec` (`current is! RestrictionsEnEchec` → sans effet) ; il doit aussi le faire depuis `RestrictionsNonObtenues`, avec son test.

Alternatives écartées : texte neutre pour **tout** `SourceInjoignable` — **cesse de nommer la source lors d'une vraie panne**, ce que `BR-007` demande (« message par source ») et ce que le Gherkin d'`US-07` vérifie (« il nomme la source qui n'a pas répondu ») ; un champ booléen « imprévu » sur `RestrictionsEnEchec` (un état qui porte une cause nommée **et** la dément) ; une quatrième branche de `RestrictionLookupFailure` dans le domaine (un bug de l'app n'est pas un échec de la source).

## 6. Même arrêté pour plusieurs zones

K-3 : **aux quatre points, un seul arrêté et un seul arrêté-cadre** pour toutes les zones. Répéter donnerait à l'Ain trois fois deux adresses de ~ 130 caractères.

~~**Proposition :**~~ **Décision (Q-6 (a), 2026-09-29) : une section « Arrêtés » dédoublonnée**, après les zones (point 6 du § 3). Chaque document distinct (égalité **exacte** de `DocumentLink.raw`, aucune normalisation) apparaît **une fois**, avec :
- son rôle : « Arrêté de restriction » (`document`) ou « Arrêté-cadre » (`frameworkDocument`) ;
- « S'applique à : » la liste des zones qui le citent, par type et nom (« Eaux superficielles — Rivières de Bresse ; Eaux souterraines — Dombes - Certines - Nord ; Eau potable — Rivières de Bresse ») ;
- l'adresse **brute**, sélectionnable (copie par sélection, Windows et Android), puis le bouton d'ouverture si `openableUri` n'est pas nul.
- Une zone **sans** `document` porte, dans son propre bloc, la phrase « Le texte de l'arrêté n'est pas accessible… » (§ 5.2).
- Aucun titre ne date l'arrêté (« Arrêté du 24/07 » du croquis) : la source ne transmet **pas** la date de l'arrêté, seulement ses dates de validité.

⚠️ **Amendement du 2026-09-29 (arbitrage du commanditaire, canvas de design)** : la section prend la forme de **cartes**, un document par carte (bordure 1 px `#C9CFC4`, rayon 12, fond blanc, sans bordure colorée). Textes, sans rien retirer de ce qui précède (dédoublonnage par adresse exacte, ordre restrictions puis cadres, adresse brute) :
- en-tête de section : « Arrêtés » puis « N documents pour ce point » (« 1 document pour ce point ») ;
- tête de carte : icône dans une pastille (document pour l'arrêté de restriction, article sur fond neutre pour l'arrêté-cadre), « Arrêté de restriction » ou « Arrêté-cadre » et, pour l'arrêté de restriction seulement, « Du JJ/MM/AAAA au JJ/MM/AAAA » (ou « Depuis le JJ/MM/AAAA » si aucune date de fin) **uniquement si toutes ses zones partagent les mêmes dates** — sinon aucune ligne de date ;
- « S'applique à N zones » (« S'applique à 1 zone »), puis une ligne par zone : badge, titre « type — nom » à l'identique, niveau en gras **à côté** (jamais sur la teinte, Q-7) ; ce libellé remplace « S'applique à : a ; b ; c » ;
- arrêté-cadre dont l'ensemble de zones est exactement celui d'un arrêté de restriction affiché : « S'applique aux N mêmes zones » (« S'applique à la même zone »), sans liste ; sinon la liste, comme la restriction ;
- adresse non ouvrable : « Cette adresse ne peut pas être ouverte depuis l'application. » au-dessus du bloc d'adresse, à la place du bouton ;
- bouton pleine largeur « Ouvrir l'arrêté » (plein, `#0B5E86`, texte blanc) ou « Ouvrir l'arrêté-cadre » (contour noir de 1,5 px), icône d'ouverture à droite, puis « PDF · s'ouvre hors de l'application » si le chemin de l'adresse finit par `.pdf` (casse ignorée), sinon « S'ouvre hors de l'application » ;
- adresse : bloc « Adresse du document » (`#4A5259` sur `#F3F4F1`, 7,2:1) puis l'adresse brute, entière, sélectionnable, à chasse fixe (BR-014) ;
- lien qui ne s'est pas ouvert : le texte de C1, inchangé, en encart orange (`#FFF4E0`, bordure `#B36B00`) **sous** le bloc d'adresse.

| Alternative | Pourquoi écartée |
|---|---|
| Répéter les adresses sous chaque zone | six adresses identiques à l'Ain, en Corse et à Paris ; à 200 %, plusieurs écrans de défilement pour une information unique |
| Dédoublonner **seulement** les zones consécutives | dépend de l'ordre d'affichage, que le domaine fixe par type : un changement d'ordre changerait l'écran |
| Bouton « Copier l'adresse » en plus de la sélection | un contrôle de 48 dp par adresse ; Q9-A demande « copiable », la sélection y suffit |

## 7. Badge de gravité

**Décision (Q-7 (a), 2026-09-29). Recopié de `04-ui.md § 2`, échelle 3, sans teinte ni forme nouvelle :**

| Niveau | Teinte | Glyphe dans la forme (couleur « texte sur fond ») | Forme | Motif |
|---|---|---|---|---|
| Vigilance | `#F0E442` | « ! » noir | ● | plein, contour noir |
| Alerte | `#E69F00` | « ! » noir | ▲ | plein |
| Alerte renforcée | `#D55E00` | « !! » blanc | ▲ | hachures |
| Crise | `#7B241C` | « ✕ » blanc | ⬣ | plein, double liseré |
| Non renseigné | `#767676` | aucun | ◌ | pointillé |

- **Le libellé du niveau n'est pas écrit sur la teinte** : il est posé **à côté** du badge, dans la couleur de texte de l'écran (noir sur blanc). Sur la teinte, blanc sur `#D55E00` ne fait que 3,87:1 et blanc sur `#767676` 4,54:1 (K-5), sous le 7:1 que `04-ui.md § 3` exige pour les libellés d'état.
- Le glyphe dans la forme est un élément graphique (≥ 3:1 exigé, WCAG 1.4.11) : 3,87:1 au plus bas, tenu.
- **Contour noir de 2 px sur chaque badge** : c'est la règle de halo de `04-ui.md § 3` (« noir sur fond clair »). Sans lui, `#F0E442` (1,32:1) et `#E69F00` (2,25:1) ne tiennent pas le 3:1 contre le fond blanc de l'écran (K-5). Pour Vigilance, il **est** le « contour noir » de `04-ui.md § 2` : un seul trait, pas deux.
- **Crise et son « double liseré »** : le halo noir de 2 px en est le **liseré extérieur** ; le second, **intérieur**, est un filet de 1 px séparé du premier par 1 px de teinte. ⚠️ `04-ui.md § 2` ne donne **pas** la couleur du second liseré : **blanc** ~~est proposé~~ est **retenu** (9,95:1 contre `#7B241C`), ~~à trancher avec Q-7~~ tranché par Q-7 (a) le 2026-09-29 ; `04-ui.md § 3` l'écrit.
- Le badge n'est pas interactif : la cible de 48 dp ne s'y applique pas. Lecteur d'écran : « Niveau de gravité : Alerte, depuis le 20 août 2026 » — l'échelle est nommée (`BR-008`).
- `GraviteInconnue` : forme ◌ `#767676`, **aucune** ligne de l'échelle marquée.

Alternative écartée : libellé écrit **dans** le badge, dans la couleur de la colonne « Texte sur fond » de `04-ui.md § 2` (noir, noir, **blanc**, blanc, **blanc**) — blanc sur `#D55E00` (3,87:1) et sur `#767676` (4,54:1) restent sous 7:1.

## 8. Écran « D'où vient cette donnée ? » (Q8-A)

**Forme :** écran plein, poussé par-dessus l'appelant, titre `dataSourcesTitle` (« D'où vient cette donnée ? »), bouton de retour, contenu défilant ; widget `DataSourcesView` sous `lib/features/shared/` (décision 4). **Accès :** depuis le modal, lien « Relire le détail des sources » (`initialWarningSourcesLinkLabel`), **sans acquitter**, retour au modal case inchangée ; après acquittement, depuis la fenêtre « ⚠ Avertissement » (carte et fiches, décision 5), lien libellé « D'où vient cette donnée ? » — le libellé que cherche le Gherkin du complément `US-01`.

**Décision (Q-8 (a), 2026-09-29) — forme, accès et contenu ci-dessous.**

**Contenu ~~proposé~~ retenu** (noms de source par leurs constantes ; `ignSourceName` est à créer en `S1`) — **sous réserve** des deux mentions de licence, à constater par appel réel en `S1` avant d'être écrites (« À valider » ci-dessous) :

| Section | Texte ~~proposé~~ retenu | Provenance |
|---|---|---|
| Intro | « Chaque valeur affichée porte sa date et le nom de sa source. » | `BR-001` |
| {`hydrometrieSourceName`} | « Débit et hauteur d'eau mesurés par des stations hydrométriques. Une mesure transmise automatiquement peut être affichée avant tout contrôle humain : elle peut être corrigée ou supprimée plus tard. Licence Ouverte Etalab, citation de l'auteur obligatoire. » | `glossary.md` (donnée brute), `docs/sources/hubeau-hydrometrie.md` |
| {`ondeSourceName`} | « Observations visuelles de l'écoulement de petits cours d'eau, faites par des agents lors de campagnes, de mai à septembre, environ une par mois. Entre deux campagnes, personne n'observe ces points. France hexagonale et Corse uniquement. Licence Ouverte Etalab. » | `04-ui.md § 1` (fiche ONDE), `BR-007`, `docs/sources/onde.md` |
| Note d'`ADR-006` | « La source distingue six modalités d'écoulement. L'application les regroupe en quatre catégories et un état « Non observé » : ce regroupement est un choix de l'application, pas une classification de l'OFB. » | `ADR-006` (« interprétation de notre part », l. 85) |
| {`restrictionsSourceName`} | « Zones d'alerte sécheresse, niveaux de gravité et usages restreints au point désigné, tels que transmis par VigiEau. Seul l'arrêté préfectoral fait foi : son texte peut comporter des dérogations et des périmètres que VigiEau ne restitue pas. L'interface de VigiEau est en version 0.1 et peut changer sans préavis : une réponse que l'application ne sait pas lire n'est jamais affichée. Une réponse reste gardée 6 heures, tant que l'application est ouverte, avec sa date de récupération. Licence Ouverte 2.0. » + {`restrictionsPublicSiteUrl`} | `BR-013` (justification), `ADR-004`, `C-16`, AR-2, Q7-A, `docs/sources/vigieau.md` |
| {`ignSourceName`} | « Fond de carte : plan IGN. » + `ignAttribution` (« © IGN Géoplateforme — Licence Ouverte ») | `ign_tile_template.dart`, `docs/sources/ign-geoplateforme.md` |
| `L-06` | « Aucune de ces données ne reflète les lâchers ni les manœuvres de barrages. » | `02-specifications.md` `L-06` |

**Absents, par construction :** `L-01` à `L-05`, le mot « percentile », toute limite de statistique (Q8-A, Q4-A). Aucun « officiel », aucune « garantie ».

Alternatives écartées : fenêtre de dialogue (texte long, 200 %) ; un seul libellé « Relire le détail des sources » aussi dans la fenêtre « ⚠ Avertissement » (le Gherkin cherche « D'où vient cette donnée ? ») ; `L-01`→`L-05` (Q8-A les renvoie aux percentiles).

⚠️ **À valider — toujours ouvert après l'arbitrage du 2026-09-29, vérification par appel réel ajoutée à `S1` (étape 0) :** la licence de VigiEau est relevée pour le **jeu data.gouv associé** (`ADR-004`, l. 30), le dépôt de code de l'API n'ayant **pas** de fichier de licence ; « Licence Ouverte 2.0 » sur l'écran l'attribue à la donnée servie par l'API. Hub'Eau : version de la Licence Ouverte **non précisée** par ses CGU (`01-analyse.md § 7`) — d'où « Licence Ouverte Etalab » sans numéro.

## 9. Cibles et accessibilité (rappel des arbitrages)

Toute cible actionnable de ces écrans — boutons de profil, « Ouvrir l'arrêté », « Réessayer », action de l'encart, bouton de désignation, liens de l'écran des sources, retour — mesure **48 × 48 dp** au moins (`minimumTapTarget` porté à 48 par `T2-K4`, décision 1), espacement 8 dp. Choix du profil : groupe exclusif annoncé comme tel, **aucun coché** à l'ouverture. Tout défile à 200 %, rien n'est tronqué.

## 10. Questions fermées pour le commanditaire

> ✅ **Toutes posées, toutes tranchées sur la recommandation** — Q-1 à Q-5d le 2026-09-27, Q-5e à Q-8 le 2026-09-29. Réponses consignées dans « Arbitrages du commanditaire », en tête. Le tableau ci-dessous reste tel qu'il a été posé.

**Numérotation :** `Q-n` répond au point `n` de la tâche `C1` (§ n de ce document) ; une lettre (`Q-2b`, `Q-5a`…) sépare les choix indépendants d'un même point. Chaque point a sa question, même quand la conception propose d'emblée (`Q-3`, `Q-6`, `Q-7`, `Q-8`).

| # | Question | Options | Recommandation |
|---|---|---|---|
| **Q-1** | Forme de l'écran des restrictions ? | (a) écran plein au-dessus de la carte · (b) panneau sur la carte, comme les fiches · (c) hybride selon la largeur | **(a)** : pas deux échelles aux mêmes teintes à la fois (`BR-008`), place à 200 %, focus contenu |
| **Q-2** | Geste de désignation ? | (a) appui long + clic droit, et bouton « Restrictions au centre de la carte » pour le clavier · (b) appui long + clic droit, raccourci clavier seul · (c) tap simple | **(a)** : aucun geste accidentel, équivalent clavier visible et atteignable par `Tab` |
| **Q-2b** | Épingle du point désigné ? | (a) gardée jusqu'à la désignation suivante, tenue par l'état de la vue carte (aucun amendement de `V1` ni de `MapViewModel`) · (b) effacée à la fermeture de l'écran · (c) aucune épingle | **(a)** : avec un écran plein, (b) ne serait jamais vue (`RestrictionsFermees` ne porte aucun point) ; (c) laisse le retour sans repère |
| **Q-3** | Place du choix du profil ? | (a) un seul choix, après les zones et les arrêtés, avant les usages groupés par zone · (b) en tête, avant les zones · (c) un choix par zone | **(a)** : le niveau se lit sans profil (il n'en dépend pas) ; un seul profil par session (Q2-A) |
| **Q-4** | Tenue de l'encart renforcé au défilement ? | (a) titre et action épinglés, corps en premier élément du défilement — **suppose de lire `BR-013` (« ni disparition au défilement ») comme visant le titre et l'action** : le corps, qui porte l'énumération de `BR-013`, sort de l'écran au défilement · (b) encart entier épinglé — contenu inatteignable à 200 % (estimation) · (c) encart en premier élément, rien d'épinglé (amende `BR-013`) | **(a)**, si cette lecture de `BR-013` est acceptée ; critère « la partie épinglée laisse au moins la moitié de la hauteur utile » vérifié en `E4` |
| **Q-5a** | Libellés des types de zone ? | (a) Eaux superficielles · Eaux souterraines · Eau potable · Type de zone non renseigné · (b) « Alimentation en eau potable » pour `AEP` | **(a)** : recopiés du schéma de l'API |
| **Q-5b** | Libellés des profils (`O9`) ? | (a) « Profil d'usager » : Particulier · Exploitation · Collectivité · Entreprise · (b) « Je suis : » … Exploitant … (croquis) | **(a)** : mots d'`UC-002` et des champs de l'API ; le croquis de `04-ui.md` sera amendé |
| **Q-5c** | Gravité inconnue : la phrase de `BR-007` accompagne-t-elle « Non renseigné » ? | (a) oui, telle quelle · (b) une phrase propre, par amendement de `BR-007` · (c) non, « Non renseigné » seul | **(a)** : `BR-007` la prévoit déjà pour ce cas, aucun amendement |
| **Q-5d** | Échec imprévu indiscernable d'une panne de VigiEau (K-4) ? | (a) amender `T2-V1` : état `RestrictionsNonObtenues`, texte neutre — **défait l'arbitrage du 2026-09-27 sur l'état** (même `RestrictionsEnEchec(SourceInjoignable)`, verrouillé par le test `StateError` de `V1`) : tests de `V1` à réécrire, `retry()` à étendre au nouvel état · (b) texte neutre pour tout `SourceInjoignable` — **cesse de nommer la source lors d'une vraie panne**, ce que `BR-007` demande · (c) garder « VigiEau n'a pas répondu » pour les deux — accuse la source d'un bug de l'app, contraire à la contrainte du 2026-09-27 | **(a)** : seule option qui tient à la fois le texte neutre et `BR-007`, au prix de l'amendement de `V1` |
| **Q-5e** | Le reste des textes du § 5.2 et § 5.3 (dont `theme` non affiché) ? | (a) validés en bloc · (b) validés sauf les lignes désignées | **(a)** |
| **Q-6** | Même arrêté pour plusieurs zones (K-3 : les **quatre** points à zones capturés) ? | (a) section « Arrêtés » dédoublonnée par adresse exacte, zones nommées · (b) adresses répétées sous chaque zone | **(a)** |
| **Q-7** | Badge : libellé posé à côté de la forme, contour noir de 2 px partout ? | (a) oui, second liseré de Crise blanc · (b) libellé dans le badge, dans la couleur de la colonne « Texte sur fond » de `04-ui.md § 2` | **(a)** : (b) donne 3,87:1 (Alerte renforcée) et 4,54:1 (Non renseigné), sous le 7:1 de `04-ui.md § 3` |
| **Q-8** | Écran des sources : contenu du § 8, écran plein, lien « D'où vient cette donnée ? » dans la fenêtre « ⚠ Avertissement » ? | (a) oui · (b) oui, lien libellé « Relire le détail des sources » partout | **(a)** |

✅ **Fait le 2026-09-29 (étape 4)** — réponses consignées en tête ; `04-ui.md` amendé (§ 1 et § 3) ; plan : `E2`/`E3` passés à l'écran, `T2-V1b` et `T2-K4` insérés avant `E2`, `E1` garde le point dans `_MapViewState`, vérification des deux licences ajoutée à `S1`. Consigne d'origine : **Après arbitrage (étape 4) :** consigner ici les réponses ; amender `04-ui.md` (§ 1 : croquis « Sécheresse et restrictions » sans profil présélectionné, plusieurs zones, section « Arrêtés », date de récupération ; croquis « D'où vient cette donnée ? » ; § 3 : désignation au clavier et contraste des badges) ; si Q-1 (a), ajuster `E2`/`E3` (écran au lieu de panneau) ; si Q-5d (a), insérer l'amendement de `T2-V1` avant `E2` ; si Q-2b (a), `E1` garde le point dans `_MapViewState` et dessine l'épingle, sans paramètre `designatedPoint` ni changement de `MapViewModel`.

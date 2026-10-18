// Les tailles de la tranche d'ergonomie (`S6`, arbitrage 10 du commanditaire,
// taille Windows : `PD1`) : les quatre tailles GARANTIES, celles d'en deçà, la
// marge système d'un téléphone (`PD10`), les deux échelles de texte et la marge
// d'une surcouche au bord de la carte. Une seule définition, partagée par les
// tests qui mesurent (`S6`) et par ceux qui posent la nouvelle disposition
// (`D1`, `D2`, `D3`) : une taille recopiée ailleurs finirait par diverger.
//
// Aucune de ces valeurs n'est écrite dans `lib/` pour décider d'un repli
// (contrainte globale du plan) : ce sont les tailles AUXQUELLES on éprouve la
// mise en page, pas des seuils qu'elle lit.
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/widgets.dart' show Size;

/// Les quatre tailles garanties (arbitrage 10) : deux téléphones Android, deux
/// fenêtres Windows. Chacune nomme la plateforme à laquelle elle s'éprouve.
const List<({String nom, Size taille, TargetPlatform plateforme})>
taillesGaranties = <({String nom, Size taille, TargetPlatform plateforme})>[
  (
    nom: '360 × 640',
    taille: Size(360, 640),
    plateforme: TargetPlatform.android,
  ),
  (
    nom: '390 × 844',
    taille: Size(390, 844),
    plateforme: TargetPlatform.android,
  ),
  (
    nom: '800 × 740',
    taille: Size(800, 740),
    plateforme: TargetPlatform.windows,
  ),
  (
    nom: '1 280 × 740',
    taille: Size(1280, 740),
    plateforme: TargetPlatform.windows,
  ),
];

/// En deçà des quatre tailles (spec § 5.6) : seuls « ⚠ Avertissement » et
/// l'entrée « Restrictions » y sont garantis atteignables.
const List<Size> taillesEnDeca = <Size>[
  Size(360, 300),
  Size(640, 360),
  Size(844, 390),
];

/// La marge système d'un téléphone (`PD10`) : barre d'état en haut, barre de
/// navigation en bas. Celle du `Pixel_7` se constate à la porte.
const EdgeInsets margeSystemeTelephone = EdgeInsets.only(top: 24, bottom: 48);

/// Les deux échelles de texte garanties : 100 % et 200 %.
const List<double> echellesDeTexte = <double>[1, 2];

/// La marge d'une surcouche au bord de la carte, et l'écart entre deux groupes
/// de pièces (`allocateMapLayout`, `gap`).
const double margeDeSurcouche = 8;

// Les replis relevés de la porte de faisabilité (`S6` d'Ergonomie) : pour
// chaque configuration de `ergonomie_budget_test.dart`, ce que
// `allocateMapLayout` rend sur les mesures de `mesurerPieces` — les replis en
// vigueur, puis « tient » ou « le bloc défile (arbitrage 13) ». Chaque cas
// AFFIRME sa ligne, et son titre la nomme : une pièce qui change de hauteur au
// point de changer les replis d'une configuration fait rougir le test.
//
// FICHIER GÉNÉRÉ — ne pas éditer à la main. Pour le régénérer, depuis la racine
// du dépôt :
//
//   flutter test --dart-define=RELEVER_REPLIS=true test/features/map/view/ergonomie_budget_test.dart
//   cp build/ergonomie_replis_releves.dart test/features/map/view/
//   dart format test/features/map/view/ergonomie_replis_releves.dart
//
// puis relire le diff dans le commit qui change les hauteurs, avec le tableau
// `.superpowers/sdd/2026-10-17-ergonomie/task-S6-mesures.md`.

const Map<String, String> replisReleves = <String, String>{
  '360 × 640, 100 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, hors mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, en mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, écoulement, en mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche station, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, écoulement, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, débit, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '360 × 640, 100 %, débit, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, débit, hors mode, sans fiche, avis, marge':
      'replis 1 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, débit, en mode, sans fiche, sans avis, marge':
      'replis 1 — tient',
  '360 × 640, 100 %, débit, en mode, sans fiche, avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 100 %, débit, en mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '360 × 640, 100 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, débit, en mode, fiche station, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, débit, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, crues, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '360 × 640, 100 %, crues, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, crues, hors mode, sans fiche, avis, marge':
      'replis 1 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '360 × 640, 100 %, crues, en mode, sans fiche, sans avis, marge':
      'replis 1 — tient',
  '360 × 640, 100 %, crues, en mode, sans fiche, avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 100 %, crues, en mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '360 × 640, 100 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, crues, en mode, fiche station, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '360 × 640, 100 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 100 %, crues, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3 — tient',
  '360 × 640, 200 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 200 %, écoulement, hors mode, sans fiche, sans avis, marge':
      'replis 1, 4 — tient',
  '360 × 640, 200 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '360 × 640, 200 %, écoulement, hors mode, sans fiche, avis, marge':
      'replis 1, 3, 4 — tient',
  '360 × 640, 200 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '360 × 640, 200 %, écoulement, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '360 × 640, 200 %, écoulement, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, sans fiche, sans avis, marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '360 × 640, 200 %, écoulement, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '360 × 640, 200 %, écoulement, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'replis 1, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, sans fiche, sans avis, marge':
      'replis 1, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, sans fiche, avis, marge':
      'replis 1, 3, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '360 × 640, 200 %, débit, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, sans fiche, sans avis, marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '360 × 640, 200 %, débit, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '360 × 640, 200 %, débit, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '360 × 640, 200 %, crues, hors mode, sans fiche, sans avis, marge':
      'replis 1, 4 — tient',
  '360 × 640, 200 %, crues, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '360 × 640, 200 %, crues, hors mode, sans fiche, avis, marge':
      'replis 1, 3, 4 — tient',
  '360 × 640, 200 %, crues, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '360 × 640, 200 %, crues, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '360 × 640, 200 %, crues, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, sans fiche, sans avis, marge':
      'replis 1, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4, 5 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '360 × 640, 200 %, crues, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '360 × 640, 200 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '360 × 640, 200 %, crues, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — le bloc défile (arbitrage 13)',
  '390 × 844, 100 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche station, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche station, avis, marge':
      'replis 1 — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, en mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, en mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, écoulement, en mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, hors mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, hors mode, fiche station, sans avis, marge':
      'replis 1 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche station, avis, marge':
      'replis 1 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, en mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, en mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 100 %, débit, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, débit, en mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, hors mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, hors mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, hors mode, fiche station, sans avis, marge':
      'replis 1 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche station, avis, marge':
      'replis 1 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, en mode, sans fiche, sans avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, en mode, sans fiche, avis, marge':
      'aucun repli — tient',
  '390 × 844, 100 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 100 %, crues, en mode, fiche station, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche station, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 100 %, crues, en mode, fiche tronçon, avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 200 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 200 %, écoulement, hors mode, sans fiche, sans avis, marge':
      'replis 1 — tient',
  '390 × 844, 200 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, écoulement, hors mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '390 × 844, 200 %, écoulement, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3 — tient',
  '390 × 844, 200 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4 — tient',
  '390 × 844, 200 %, écoulement, en mode, sans fiche, sans avis, marge':
      'replis 1, 4 — tient',
  '390 × 844, 200 %, écoulement, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '390 × 844, 200 %, écoulement, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5 — tient',
  '390 × 844, 200 %, écoulement, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 200 %, débit, hors mode, sans fiche, sans avis, marge':
      'replis 1 — tient',
  '390 × 844, 200 %, débit, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, débit, hors mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '390 × 844, 200 %, débit, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, débit, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4 — tient',
  '390 × 844, 200 %, débit, en mode, sans fiche, sans avis, marge':
      'replis 1, 4, 5 — tient',
  '390 × 844, 200 %, débit, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '390 × 844, 200 %, débit, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4, 5 — tient',
  '390 × 844, 200 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5 — tient',
  '390 × 844, 200 %, débit, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5 — tient',
  '390 × 844, 200 %, débit, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '390 × 844, 200 %, crues, hors mode, sans fiche, sans avis, marge':
      'replis 1 — tient',
  '390 × 844, 200 %, crues, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, crues, hors mode, sans fiche, avis, marge':
      'replis 1, 3 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche station, sans avis, marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3 — tient',
  '390 × 844, 200 %, crues, hors mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4 — tient',
  '390 × 844, 200 %, crues, en mode, sans fiche, sans avis, sans marge':
      'replis 1, 4 — tient',
  '390 × 844, 200 %, crues, en mode, sans fiche, sans avis, marge':
      'replis 1, 4, 5 — tient',
  '390 × 844, 200 %, crues, en mode, sans fiche, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '390 × 844, 200 %, crues, en mode, sans fiche, avis, marge':
      'replis 1, 3, 4, 5 — tient',
  '390 × 844, 200 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, en mode, fiche station, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, en mode, fiche station, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 2, 4, 5 — tient',
  '390 × 844, 200 %, crues, en mode, fiche tronçon, sans avis, marge':
      'replis 1, 2, 4, 5, 6 — tient',
  '390 × 844, 200 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 2, 3, 4, 5 — tient',
  '390 × 844, 200 %, crues, en mode, fiche tronçon, avis, marge':
      'replis 1, 2, 3, 4, 5, 6 — tient',
  '800 × 740, 100 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, hors mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, débit, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, crues, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 100 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '800 × 740, 100 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, écoulement, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'replis 1, 6 — tient',
  '800 × 740, 200 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 3, 6 — tient',
  '800 × 740, 200 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 6 — tient',
  '800 × 740, 200 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3, 6 — tient',
  '800 × 740, 200 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, débit, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, débit, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 4 — tient',
  '800 × 740, 200 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '800 × 740, 200 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 4 — tient',
  '800 × 740, 200 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '800 × 740, 200 %, débit, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, débit, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1, 4, 6 — tient',
  '800 × 740, 200 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 3, 4, 6 — tient',
  '800 × 740, 200 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 4, 6 — tient',
  '800 × 740, 200 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3, 4, 6 — tient',
  '800 × 740, 200 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, crues, hors mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, crues, hors mode, fiche station, sans avis, sans marge':
      'replis 1, 4 — tient',
  '800 × 740, 200 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '800 × 740, 200 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 4 — tient',
  '800 × 740, 200 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3, 4 — tient',
  '800 × 740, 200 %, crues, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '800 × 740, 200 %, crues, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '800 × 740, 200 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1, 4, 6 — tient',
  '800 × 740, 200 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 3, 4, 6 — tient',
  '800 × 740, 200 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1, 4, 6 — tient',
  '800 × 740, 200 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3, 4, 6 — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, débit, en mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, sans fiche, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, fiche station, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, fiche station, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 100 %, crues, en mode, fiche tronçon, avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, sans fiche, sans avis, sans marge':
      'aucun repli — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, sans fiche, avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, écoulement, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, débit, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, hors mode, sans fiche, avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, hors mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, débit, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, débit, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, débit, en mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, en mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, débit, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, débit, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, crues, hors mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, hors mode, sans fiche, avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, hors mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, hors mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, crues, hors mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, hors mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, crues, en mode, sans fiche, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, en mode, sans fiche, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, crues, en mode, fiche station, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, en mode, fiche station, avis, sans marge':
      'replis 1, 3 — tient',
  '1 280 × 740, 200 %, crues, en mode, fiche tronçon, sans avis, sans marge':
      'replis 1 — tient',
  '1 280 × 740, 200 %, crues, en mode, fiche tronçon, avis, sans marge':
      'replis 1, 3 — tient',
};

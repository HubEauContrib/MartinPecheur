# Images du Microsoft Store et logo du paquet MSIX

Piste A (« Profil »), choisie par le commanditaire le 2026-10-21 (`ADR-018`). Les `.svg` sont les sources ;
les `.png` en sont les rendus, à régénérer après toute modification d'une source.

| Source | Rendu | Taille | Usage |
|---|---|---|---|
| `logo.svg` | `logo.png` | 1080 × 1080, fond transparent aux coins | `logo_path` de `msix_config` : le paquet en tire ses tuiles |
| `boxart.svg` | `boxart-1080.png`, `boxart-2160.png` | 1080 × 1080, 2160 × 2160 | Fiche du Store : « Image de zone 1:1 » |
| `boxart-1080.png` | `tile-300.png`, `tile-150.png`, `tile-71.png` | 300 × 300, 150 × 150, 71 × 71 | Fiche du Store : « Icône de vignette d'application 1:1 » — réductions bicubiques de `boxart-1080.png` |
| `poster.svg` | `poster-720x1080.png`, `poster-1440x2160.png` | 720 × 1080, 1440 × 2160 | Fiche du Store : « Image d'affiche 9:16 » |

## Icônes de l'application

Le même martin-pêcheur sert d'icône à l'application (décision du commanditaire du 2026-10-21), par
réduction bicubique :

| Cible | Fichiers | Tiré de |
|---|---|---|
| Windows | `windows/runner/resources/app_icon.ico` : 16, 24, 32, 48, 64, 128 et 256 px, en PNG | `logo.png` (coins transparents) |
| Android | `android/app/src/main/res/mipmap-*/ic_launcher.png` : 48, 72, 96, 144, 192 px | `logo.png` (coins transparents) |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`, taille tirée du nom | `boxart-1080.png`, sans couche alpha (iOS arrondit lui-même) |

`test/project/app_icons_test.dart` vérifie les tailles, l'absence d'alpha sur iOS, et qu'aucune icône n'est
revenue au logo de Flutter.

## Régénérer un rendu

Avec Microsoft Edge sans fenêtre : `--window-size` donne la taille en pixels CSS, `--force-device-scale-factor=2`
la double. Un profil temporaire par rendu, et des chemins à barres obliques (`/`) :

```bash
msedge --headless=new --disable-gpu --hide-scrollbars --user-data-dir=<dossier temporaire> --default-background-color=00000000 --window-size=1080,1080 --screenshot=<chemin>/windows/store/logo.png file:///<chemin>/windows/store/logo.svg
```

Pour les images du Store, fond plein : `--default-background-color=0E4C6EFF`. Le texte de l'affiche est en
Segoe UI : le rendu suppose un poste Windows.

⚠️ **Pas de rendu direct sous 720 px de large.** Edge sans fenêtre garde une largeur de page minimale : à
300 ou 150 px, la capture rogne le dessin ou le laisse vide (constaté le 2026-10-21). Les vignettes se font
donc par **réduction** de `boxart-1080.png`, en bicubique de haute qualité (`System.Drawing` sous
PowerShell, `InterpolationMode = HighQualityBicubic`), puis se regardent avant usage.

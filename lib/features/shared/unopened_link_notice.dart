// L'avis « lien non ouvert », partagé entre l'écran des restrictions et la
// fiche tronçon (F2 de T4). Sorti de la vue des restrictions sans changement
// de comportement ; `UnopenedLink` et `LinkTarget` restent dans cette tranche.
import 'package:flutter/material.dart';

/// Le texte de l'avis.
const String unopenedLinkText =
    "Ce lien n'a pas pu être ouvert depuis l'application. Son "
    'adresse reste affichée ci-dessus.';

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
class UnopenedLinkNotice extends StatefulWidget {
  const UnopenedLinkNotice({super.key});

  @override
  State<UnopenedLinkNotice> createState() => _UnopenedLinkNoticeState();
}

class _UnopenedLinkNoticeState extends State<UnopenedLinkNotice> {
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
              Expanded(child: Text(unopenedLinkText)),
            ],
          ),
        ),
      ),
    );
  }
}

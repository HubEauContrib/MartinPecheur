// Le focus clavier, vu d'un test : où est-il ? Une seule aide pour les tests
// de clavier (`K1` de T3), recopiée avant elle dans cinq fichiers de la carte.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le focus courant (`FocusManager.instance.primaryFocus`) est-il porté par un
/// élément du sous-arbre de [ancestor] ? [Focus.of] ne cherche que des
/// ANCÊTRES, jamais l'inverse : on part de [ancestor] et on descend.
bool focusedWithin(WidgetTester tester, Finder ancestor) {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  final Element root = tester.element(ancestor);
  bool found = false;
  void visit(Element element) {
    if (element == focusedContext) {
      found = true;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

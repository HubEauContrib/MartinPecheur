// Le registre explicite de gestionnaires : une seule Map<Type, gestionnaire>,
// aucune bibliotheque de mediateur, aucune reflexion. L'effacement de type a
// lieu une seule fois, a l'enregistrement, dans une fermeture qui connait
// encore le type concret M — c'est ce transtypage local et unique qui permet
// ensuite a send<R> de rendre un Future<R> type, jamais un dynamic.

import 'package:martinpecheur/application/messages.dart';

typedef _ErasedHandler = Future<Object?> Function(Message<Object?> message);

/// Registre explicite de gestionnaires, un par type de [Message]. Achemine
/// par [Type] : aucune reflexion, aucune bibliotheque de mediateur.
final class Bus {
  final Map<Type, _ErasedHandler> _handlers = <Type, _ErasedHandler>{};

  /// Les types de message pour lesquels un gestionnaire est enregistre. Un
  /// ecran muet est presque toujours un gestionnaire oublie : cette liste
  /// permet de le nommer sans deviner.
  Set<Type> get registeredMessages => _handlers.keys.toSet();

  /// Enregistre [handler] pour les messages de type [M]. Leve un
  /// [StateError] si [M] a deja un gestionnaire enregistre.
  ///
  /// La cle du registre est le type **concret** [M] : un gestionnaire par
  /// type concret, jamais par hierarchie. Une sous-classe de [M] n'herite
  /// pas du gestionnaire enregistre pour [M] — elle a besoin du sien.
  void register<M extends Message<R>, R>(
    Future<R> Function(M message) handler,
  ) {
    if (_handlers.containsKey(M)) {
      throw StateError(
        'Un gestionnaire est deja enregistre pour $M. Un second '
        'enregistrement pour le meme message est refuse.',
      );
    }

    _handlers[M] = (Message<Object?> message) async => handler(message as M);
  }

  /// Achemine [message] vers son gestionnaire et attend la reponse. Leve un
  /// [StateError] si aucun gestionnaire n'est enregistre pour le type de
  /// [message] ; laisse remonter telle quelle toute erreur levee par le
  /// gestionnaire (BR-007) : le bus n'avale aucune erreur.
  ///
  /// Le type [R] n'est pas verifie a l'enregistrement — l'effacement de type
  /// de [register] l'accepte tel quel. Un [R] incoherent avec celui declare
  /// par [message] ne se voit donc pas au moment d'enregistrer le
  /// gestionnaire : il se paie ici, en [TypeError], au moment de l'envoi.
  Future<R> send<R>(Message<R> message) async {
    final _ErasedHandler? handler = _handlers[message.runtimeType];
    if (handler == null) {
      throw StateError(
        'Aucun gestionnaire enregistre pour ${message.runtimeType}. '
        'Gestionnaires connus : $registeredMessages.',
      );
    }

    final Object? response = await handler(message);
    return response as R;
  }
}

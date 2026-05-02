/// Message dans le fil de discussion.
///
/// `pending` = bulle assistant en cours de streaming (le texte se complète au
/// fur et à mesure des tokens). On le distingue d'un message terminé pour
/// désactiver les actions (copier, régénérer) tant que la génération n'est
/// pas finie.
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.pending = false,
  });

  final bool isUser;
  final DateTime timestamp;
  String text;
  bool pending;
}

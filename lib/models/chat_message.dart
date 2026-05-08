import '../services/rag/rag_service.dart';

/// Message dans le fil de discussion.
///
/// `pending` = bulle assistant en cours de streaming (le texte se complète au
/// fur et à mesure des tokens). On le distingue d'un message terminé pour
/// désactiver les actions (copier, régénérer) tant que la génération n'est
/// pas finie.
///
/// `sources` (optionnel) = liste des extraits RAG cités dans la réponse,
/// affichés en bas de la bulle assistant pour la traçabilité.
///
/// `id` = clé stable pour `ValueKey` du `ListView.builder` — évite que Flutter
/// "glisse" l'état des bulles voisines à chaque insertion (perte de sélection,
/// re-parsing markdown inutile).
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.pending = false,
    this.sources = const [],
    String? id,
  }) : id = id ?? _genId();

  final String id;
  final bool isUser;
  final DateTime timestamp;
  String text;
  bool pending;
  List<RagSource> sources;

  static int _seq = 0;
  static String _genId() {
    final us = DateTime.now().microsecondsSinceEpoch;
    final n = _seq++;
    return 'm_${us}_$n';
  }
}

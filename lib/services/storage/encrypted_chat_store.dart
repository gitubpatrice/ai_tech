import '../../models/chat_session.dart';
import 'encrypted_json_store.dart';

/// Persistance chiffrée des conversations multi-tour.
///
/// Sous-classe minimale de [EncryptedJsonStore] : ne fournit que le mapping
/// type ↔ disque (sous-dossier, extension, magic, JSON, ordre). Toute la
/// logique crypto + atomicité + isolate vit dans la base.
///
/// Fichiers : `<app_docs>/chats/<id>.aichat`, magic ASCII `AIC1`.
/// Tri : par `updatedAt` décroissant (plus récente en haut).
class EncryptedChatStore extends EncryptedJsonStore<ChatSession> {
  EncryptedChatStore._();
  static final EncryptedChatStore instance = EncryptedChatStore._();

  @override
  String get subdirectory => 'chats';

  @override
  String get fileExtension => '.aichat';

  @override
  String get magicHeader => 'AIC1';

  @override
  ChatSession fromJson(Map<String, dynamic> json) => ChatSession.fromJson(json);

  @override
  Map<String, dynamic> toJson(ChatSession session) => session.toJson();

  @override
  String idOf(ChatSession session) => session.id;

  @override
  int compareDesc(ChatSession a, ChatSession b) =>
      b.updatedAt.compareTo(a.updatedAt);
}

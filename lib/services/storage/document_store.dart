import '../rag/document.dart';
import 'encrypted_json_store.dart';

/// Persistance chiffrée des documents indexés par le RAG.
///
/// Sous-classe minimale de [EncryptedJsonStore] : ne fournit que le mapping
/// type ↔ disque. Toute la logique crypto + atomicité + isolate vit dans la
/// base.
///
/// Fichiers : `<app_docs>/documents/<id>.aidoc`, magic ASCII `AID1`.
/// Tri : par `createdAt` décroissant (plus récent en haut).
class DocumentStore extends EncryptedJsonStore<RagDocument> {
  DocumentStore._();
  static final DocumentStore instance = DocumentStore._();

  @override
  String get subdirectory => 'documents';

  @override
  String get fileExtension => '.aidoc';

  @override
  String get magicHeader => 'AID1';

  @override
  RagDocument fromJson(Map<String, dynamic> json) => RagDocument.fromJson(json);

  @override
  Map<String, dynamic> toJson(RagDocument doc) => doc.toJson();

  @override
  String idOf(RagDocument doc) => doc.id;

  @override
  int compareDesc(RagDocument a, RagDocument b) =>
      b.createdAt.compareTo(a.createdAt);
}

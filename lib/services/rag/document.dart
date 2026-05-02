/// Document utilisateur (PDF, texte) indexé pour RAG.
///
/// La v0.3 ne livre qu'un squelette : l'indexeur keyword [KeywordIndexer]
/// fonctionne, mais la chaîne complète (extraction PDF, embeddings) sera
/// branchée à l'UI dans une session ultérieure.
class RagDocument {
  const RagDocument({
    required this.id,
    required this.title,
    required this.chunks,
  });

  final String id;
  final String title;
  final List<RagChunk> chunks;
}

class RagChunk {
  const RagChunk({
    required this.id,
    required this.text,
    required this.documentId,
    this.position = 0,
  });

  final String id;
  final String text;
  final String documentId;
  final int position;
}

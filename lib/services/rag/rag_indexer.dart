import 'document.dart';

/// Interface d'un indexeur RAG.
///
/// Deux implémentations prévues :
///   - [KeywordIndexer] (livré v0.3) : recherche par occurrences pondérées,
///     pas de modèle supplémentaire à télécharger.
///   - `EmbeddingIndexer` (futur) : utilise un petit modèle d'embeddings
///     `all-MiniLM-L6-v2` (~25 Mo) pour des correspondances sémantiques.
abstract class RagIndexer {
  /// Indexe un document. Idempotent : ré-indexer un même `id` met à jour.
  Future<void> index(RagDocument document);

  /// Retire un document de l'index.
  Future<void> remove(String documentId);

  /// Cherche les chunks les plus pertinents pour [query].
  ///
  /// Renvoie les `k` meilleurs chunks, triés par score décroissant.
  Future<List<RagSearchHit>> search(String query, {int k = 5});

  /// Vide tout l'index (utilisé par le mode panique).
  Future<void> clear();
}

class RagSearchHit {
  const RagSearchHit({
    required this.chunk,
    required this.score,
  });

  final RagChunk chunk;
  final double score;
}

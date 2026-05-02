import 'dart:math';

import 'document.dart';
import 'rag_indexer.dart';

/// Indexeur RAG keyword (BM25 simplifié), 100% en mémoire.
///
/// Approche :
///   - tokenisation lowercased + suppression diacritiques pour matcher "tâche"
///     contre "taches" (modèle imparfait en FR sur petits LLM).
///   - score = somme(idf(terme) × tf(terme)) avec normalisation par longueur.
///
/// Adapté à des corpus courts (< quelques milliers de chunks) — au-delà, il
/// faudra basculer sur un index sur disque (Lucene-like) ou des embeddings.
class KeywordIndexer implements RagIndexer {
  KeywordIndexer._();
  static final KeywordIndexer instance = KeywordIndexer._();

  /// chunkId → chunk
  final Map<String, RagChunk> _chunks = {};

  /// terme → ensemble des chunkIds contenant le terme
  final Map<String, Set<String>> _postings = {};

  /// chunkId → longueur du chunk (en tokens) pour la normalisation
  final Map<String, int> _chunkLen = {};

  /// chunkId → documentId pour le clear par doc
  final Map<String, String> _chunkDoc = {};

  @override
  Future<void> index(RagDocument document) async {
    await remove(document.id);
    for (final chunk in document.chunks) {
      _chunks[chunk.id] = chunk;
      _chunkDoc[chunk.id] = document.id;
      final tokens = _tokenize(chunk.text);
      _chunkLen[chunk.id] = tokens.length;
      for (final t in tokens) {
        (_postings[t] ??= <String>{}).add(chunk.id);
      }
    }
  }

  @override
  Future<void> remove(String documentId) async {
    final affected = _chunkDoc.entries
        .where((e) => e.value == documentId)
        .map((e) => e.key)
        .toList();
    for (final cid in affected) {
      _chunks.remove(cid);
      _chunkLen.remove(cid);
      _chunkDoc.remove(cid);
    }
    for (final set in _postings.values) {
      set.removeWhere(affected.contains);
    }
    _postings.removeWhere((_, v) => v.isEmpty);
  }

  @override
  Future<List<RagSearchHit>> search(String query, {int k = 5}) async {
    final terms = _tokenize(query).toSet();
    if (terms.isEmpty || _chunks.isEmpty) return [];

    final scores = <String, double>{};
    final totalChunks = _chunks.length;
    final avgLen = _chunkLen.values.fold<int>(0, (a, b) => a + b) /
        max(1, totalChunks);

    for (final term in terms) {
      final posting = _postings[term];
      if (posting == null || posting.isEmpty) continue;
      final df = posting.length;
      final idf = log(1 + (totalChunks - df + 0.5) / (df + 0.5));
      for (final cid in posting) {
        final tf = 1.0; // approx (1 occurrence par token unique)
        final len = _chunkLen[cid] ?? 1;
        final norm = 1.0 / (1.0 + len / max(1, avgLen));
        scores[cid] = (scores[cid] ?? 0) + idf * tf * norm;
      }
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(k)
        .where((e) => _chunks[e.key] != null)
        .map((e) => RagSearchHit(chunk: _chunks[e.key]!, score: e.value))
        .toList();
  }

  @override
  Future<void> clear() async {
    _chunks.clear();
    _postings.clear();
    _chunkLen.clear();
    _chunkDoc.clear();
  }

  /// Tokenisation simple : minuscules, suppression diacritiques, split sur
  /// caractères non alphanumériques, mots ≥ 3 caractères, stop-words FR.
  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final stripped = _stripDiacritics(lower);
    final raw = stripped.split(RegExp(r'[^a-z0-9]+'));
    return raw
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
  }

  static String _stripDiacritics(String s) {
    const from = 'àáâãäåæçèéêëìíîïñòóôõöùúûüýÿ';
    const to = 'aaaaaaaceeeeiiiinooooouuuuyy';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final char = String.fromCharCode(ch);
      final idx = from.indexOf(char);
      if (idx >= 0) {
        buf.write(to[idx]);
      } else if (char == 'œ') {
        buf.write('oe');
      } else {
        buf.write(char);
      }
    }
    return buf.toString();
  }

  static const _stopWords = {
    'les', 'des', 'une', 'que', 'qui', 'pour', 'avec', 'sur', 'dans', 'par',
    'son', 'sa', 'ses', 'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'leur', 'leurs',
    'ce', 'cet', 'cette', 'ces', 'est', 'sont', 'été', 'etre', 'avoir', 'mais',
    'donc', 'car', 'pas', 'plus', 'moins', 'aussi', 'comme', 'tout', 'tous',
    'toute', 'toutes', 'quoi', 'quel', 'quelle', 'quels', 'quelles', 'lui',
    'elle', 'eux', 'nous', 'vous', 'ils', 'elles',
    // Anglais minimal (au cas où les docs sont mixtes)
    'the', 'and', 'for', 'with', 'this', 'that', 'are', 'was', 'were',
  };
}

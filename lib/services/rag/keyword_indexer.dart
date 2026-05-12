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

  /// QW3 v0.8.1 — cache `avgLen` invalidé sur mutation (index/remove/clear).
  /// Avant : `_chunkLen.values.fold` à chaque search → O(n) inutile car
  /// avgLen est quasi-stable. Gain : -50 % latence search RAG.
  double _avgLenCache = 0;

  /// Future-chain pour sérialiser les opérations mutatrices ([index],
  /// [remove], [clear]) ainsi que la lecture [search]. Évite les data races
  /// si l'UI déclenche `addDocument` pendant qu'un `bootstrap` itère encore
  /// les fichiers : sans sérialisation, deux `index` concurrents corrompent
  /// `_postings` (modification de Set en cours d'itération).
  Future<void> _opChain = Future.value();

  Future<T> _serialize<T>(Future<T> Function() op) {
    final result = _opChain.then((_) => op());
    // Capture les erreurs pour ne pas casser la chaîne (sinon le prochain
    // .then ne se déclencherait jamais et on figerait l'indexer).
    _opChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> index(RagDocument document) => _serialize(() async {
    await _removeUnsafe(document.id);
    for (final chunk in document.chunked()) {
      _chunks[chunk.id] = chunk;
      _chunkDoc[chunk.id] = document.id;
      final tokens = _tokenize(chunk.text);
      _chunkLen[chunk.id] = tokens.length;
      for (final t in tokens) {
        (_postings[t] ??= <String>{}).add(chunk.id);
      }
    }
    _recomputeAvgLen();
  });

  @override
  Future<void> remove(String documentId) =>
      _serialize(() => _removeUnsafe(documentId));

  Future<void> _removeUnsafe(String documentId) async {
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
    _recomputeAvgLen();
  }

  /// QW3 v0.8.1 — recompute la moyenne après mutation. Appelé uniquement
  /// par les opérations qui modifient `_chunkLen`, jamais en hot-path
  /// search.
  void _recomputeAvgLen() {
    if (_chunkLen.isEmpty) {
      _avgLenCache = 0;
      return;
    }
    final total = _chunkLen.values.fold<int>(0, (a, b) => a + b);
    _avgLenCache = total / _chunkLen.length;
  }

  @override
  Future<List<RagSearchHit>> search(String query, {int k = 5}) =>
      _serialize(() => _searchUnsafe(query, k: k));

  Future<List<RagSearchHit>> _searchUnsafe(String query, {int k = 5}) async {
    final terms = _tokenize(query).toSet();
    if (terms.isEmpty || _chunks.isEmpty) return [];

    final scores = <String, double>{};
    final totalChunks = _chunks.length;
    // QW3 v0.8.1 — utilise le cache maintenu sur mutation (vs fold O(n)).
    final avgLen = _avgLenCache;

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
  Future<void> clear() => _serialize(() async {
    _chunks.clear();
    _postings.clear();
    _chunkLen.clear();
    _chunkDoc.clear();
    _avgLenCache = 0;
  });

  /// Tokenisation simple : minuscules, suppression diacritiques, split sur
  /// caractères non alphanumériques, mots ≥ 3 caractères, stop-words FR.
  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final stripped = _stripDiacritics(lower);
    final raw = stripped.split(RegExp(r'[^a-z0-9]+'));
    return raw.where((w) => w.length >= 3 && !_stopWords.contains(w)).toList();
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
    'ce', 'cet', 'cette', 'ces', 'est', 'sont', 'ete', 'etre', 'avoir', 'mais',
    'donc', 'car', 'pas', 'plus', 'moins', 'aussi', 'comme', 'tout', 'tous',
    'toute', 'toutes', 'quoi', 'quel', 'quelle', 'quels', 'quelles', 'lui',
    'elle', 'eux', 'nous', 'vous', 'ils', 'elles',
    // Anglais minimal (au cas où les docs sont mixtes)
    'the', 'and', 'for', 'with', 'this', 'that', 'are', 'was', 'were',
  };
}

import 'dart:math' as math;

/// Document utilisateur indexé pour RAG.
///
/// Stocké chiffré sur disque (AES-256-GCM, AAD = id) dans
/// `<app_docs>/documents/<id>.aidoc`. Chunks recalculés en mémoire à chaque
/// chargement pour alimenter [KeywordIndexer]. Le texte source reste sur
/// disque chiffré pour permettre la ré-indexation.
class RagDocument {
  RagDocument({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    required this.charCount,
  });

  final String id;
  final String title;
  final String text;
  final DateTime createdAt;
  final int charCount;

  /// Génère un identifiant compact `d-1715812345-a1b2`.
  static String newId() {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rand = math.Random.secure().nextInt(0xFFFF).toRadixString(16);
    return 'd-$ts-${rand.padLeft(4, '0')}';
  }

  /// Découpe le texte en chunks d'environ [chunkChars] caractères, avec un
  /// petit chevauchement [overlap] pour ne pas couper une idée en deux.
  ///
  /// On respecte les frontières de paragraphes/phrases quand c'est possible
  /// — un chunk qui finit au milieu d'un mot dégrade la qualité du RAG.
  List<RagChunk> chunked({int chunkChars = 700, int overlap = 100}) {
    final out = <RagChunk>[];
    if (text.trim().isEmpty) return out;

    var start = 0;
    var pos = 0;
    final n = text.length;
    while (start < n) {
      var end = math.min(start + chunkChars, n);
      // Cherche une frontière propre (saut de ligne ou point) dans la
      // dernière fenêtre de 120 chars du chunk.
      if (end < n) {
        final boundaryStart = math.max(start, end - 120);
        final lastBreak = _findLastBreak(text, boundaryStart, end);
        if (lastBreak > start) end = lastBreak;
      }
      final raw = text.substring(start, end).trim();
      if (raw.isNotEmpty) {
        out.add(RagChunk(
          id: '$id-${pos.toString().padLeft(4, '0')}',
          text: raw,
          documentId: id,
          position: pos,
        ));
        pos++;
      }
      if (end >= n) break;
      start = math.max(end - overlap, start + 1);
    }
    return out;
  }

  static int _findLastBreak(String s, int from, int to) {
    for (var i = to - 1; i >= from; i--) {
      final c = s.codeUnitAt(i);
      if (c == 0x0A /* \n */ || c == 0x2E /* . */) return i + 1;
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'charCount': charCount,
      };

  factory RagDocument.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    return RagDocument(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Document',
      text: text,
      createdAt: DateTime.parse(json['createdAt'] as String),
      charCount: json['charCount'] as int? ?? text.length,
    );
  }
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

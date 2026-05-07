import 'package:ai_tech/services/rag/document.dart';
import 'package:ai_tech/services/rag/keyword_indexer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reset complet de l'indexeur singleton avant chaque test (sinon des
/// chunks d'un test précédent polluent le test courant).
Future<void> _reset() async {
  await KeywordIndexer.instance.clear();
}

RagDocument _doc(String id, String text, {String title = 'T'}) {
  return RagDocument(
    id: id,
    title: title,
    text: text,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    charCount: text.length,
  );
}

void main() {
  group('KeywordIndexer', () {
    setUp(() async => _reset());

    test('index puis search renvoie un hit pertinent', () async {
      final indexer = KeywordIndexer.instance;
      await indexer.index(_doc(
        'doc1',
        'La photosynthèse transforme le dioxyde de carbone et l\'eau en '
            'glucose grâce à la lumière du soleil.',
      ));

      final hits = await indexer.search('photosynthèse glucose');
      expect(hits, isNotEmpty);
      expect(hits.first.chunk.documentId, 'doc1');
      expect(hits.first.score, greaterThan(0));
    });

    test('remove(documentId) purge tous les chunks associés', () async {
      final indexer = KeywordIndexer.instance;
      await indexer.index(_doc('doc1', 'Le chat dort sur le canapé.'));
      await indexer.index(_doc('doc2', 'Le chien aboie dans le jardin.'));

      var hits = await indexer.search('chat');
      expect(hits.any((h) => h.chunk.documentId == 'doc1'), isTrue);

      await indexer.remove('doc1');
      hits = await indexer.search('chat');
      expect(hits.any((h) => h.chunk.documentId == 'doc1'), isFalse);
      // doc2 toujours présent.
      hits = await indexer.search('chien');
      expect(hits.any((h) => h.chunk.documentId == 'doc2'), isTrue);
    });

    test('clear() vide complètement l\'index', () async {
      final indexer = KeywordIndexer.instance;
      await indexer.index(_doc('doc1', 'Hello world from Dart.'));
      await indexer.clear();
      final hits = await indexer.search('hello');
      expect(hits, isEmpty);
    });

    test(
      'opérations concurrentes (Future.wait) ne corrompent pas l\'index',
      () async {
        final indexer = KeywordIndexer.instance;
        // Lance 10 index() en parallèle. Sans la sérialisation interne via
        // _opChain, on aurait des ConcurrentModificationError sur _postings.
        final futures = <Future<void>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(indexer.index(
            _doc('doc-$i', 'Texte numéro $i avec tokens uniques alpha$i'),
          ));
        }
        await Future.wait(futures);

        // Tous les documents doivent être retrouvables.
        for (var i = 0; i < 10; i++) {
          final hits = await indexer.search('alpha$i');
          expect(
            hits.any((h) => h.chunk.documentId == 'doc-$i'),
            isTrue,
            reason: 'doc-$i pas trouvé après index parallèle',
          );
        }
      },
    );

    test('search avec tokens trop courts ou stop-words renvoie vide',
        () async {
      final indexer = KeywordIndexer.instance;
      await indexer.index(_doc('doc1', 'Ceci est un document avec du texte.'));
      // 'le', 'un', etc. sont stop-words ou < 3 chars.
      final hits = await indexer.search('le un');
      expect(hits, isEmpty);
    });

    test('réindexer le même documentId remplace les chunks', () async {
      final indexer = KeywordIndexer.instance;
      await indexer.index(_doc('doc1', 'banane mangue ananas'));
      var hits = await indexer.search('banane');
      expect(hits, isNotEmpty);

      // Réindexation avec un texte totalement différent.
      await indexer.index(_doc('doc1', 'voiture moto vélo'));
      hits = await indexer.search('banane');
      expect(hits, isEmpty,
          reason: 'l\'ancien contenu de doc1 doit être purgé');
      hits = await indexer.search('voiture');
      expect(hits, isNotEmpty);
    });
  });
}

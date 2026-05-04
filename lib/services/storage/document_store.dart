import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../crypto/aes_gcm.dart';
import '../crypto/secret_key.dart';
import '../rag/document.dart';

/// Persiste les documents RAG chiffrés sur disque.
///
/// Format identique à [EncryptedChatStore] :
///   `[4 octets magic "AID1"][12 octets nonce][N octets ciphertext + 16 octets tag]`
///
/// AAD = `id` du document (UTF-8). Renommer un fichier le rend illisible.
/// Stockage : `<app_docs>/documents/<id>.aidoc` — privé à l'app.
///
/// Sauvegardes sérialisées (chaîne de Future) pour éviter les `tmp.rename`
/// concurrents qui s'écraseraient l'un l'autre.
class DocumentStore {
  DocumentStore._();
  static final DocumentStore instance = DocumentStore._();

  static const _magic = [0x41, 0x49, 0x44, 0x31]; // "AID1"
  static const int _magicLen = 4;

  Future<void> _saveChain = Future.value();

  Future<Directory> _docsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/documents');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _docsDir();
    return File('${dir.path}/$id.aidoc');
  }

  Future<RagDocument?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    try {
      final blob = await file.readAsBytes();
      if (blob.length < _magicLen) {
        throw const FormatException('blob trop court');
      }
      for (var i = 0; i < _magicLen; i++) {
        if (blob[i] != _magic[i]) {
          throw const FormatException('magic invalide');
        }
      }
      final body = Uint8List.fromList(blob.sublist(_magicLen));
      final key = await SecretKey.instance.getOrCreate();
      final aad = Uint8List.fromList(utf8.encode(id));
      final plaintext = AesGcm.decrypt(key, body, aad: aad);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return RagDocument.fromJson(json);
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {
        /* best-effort */
      }
      return null;
    }
  }

  Future<void> save(RagDocument doc) {
    _saveChain = _saveChain.then((_) => _doSave(doc));
    return _saveChain;
  }

  Future<void> _doSave(RagDocument doc) async {
    final file = await _fileFor(doc.id);
    final tmp = File('${file.path}.tmp');
    final key = await SecretKey.instance.getOrCreate();
    final plaintext = utf8.encode(jsonEncode(doc.toJson()));
    final aad = Uint8List.fromList(utf8.encode(doc.id));
    final blob = AesGcm.encrypt(key, Uint8List.fromList(plaintext), aad: aad);
    final out = Uint8List.fromList([..._magic, ...blob]);
    await tmp.writeAsBytes(out, flush: true);
    // rename atomique POSIX/Android : remplace l'existant sans fenêtre TOCTOU.
    await tmp.rename(file.path);
  }

  Future<void> deleteOne(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        /* best-effort */
      }
    }
  }

  Future<void> deleteAll() async {
    final dir = await _docsDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        /* best-effort */
      }
    }
  }

  /// Liste tous les documents chiffrés, triés par date de création décroissante.
  Future<List<RagDocument>> listAll() async {
    final dir = await _docsDir();
    if (!await dir.exists()) return const [];
    final out = <RagDocument>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[\\/]')).last;
      if (!name.endsWith('.aidoc')) continue;
      final id = name.substring(0, name.length - '.aidoc'.length);
      final doc = await load(id);
      if (doc != null) out.add(doc);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
}

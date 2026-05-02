import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../models/chat_session.dart';
import '../crypto/aes_gcm.dart';
import '../crypto/secret_key.dart';

/// Persiste les conversations chiffrées sur disque.
///
/// Format de fichier :
///   `[4 octets magic "AIC1"][12 octets nonce][N octets ciphertext + 16 octets tag GCM]`
///
/// L'**AAD** du AEADParameters GCM est l'`id` de la session (UTF-8) : un
/// attaquant qui renomme `aaa.aichat` en `bbb.aichat` ne peut plus le
/// déchiffrer (le tag dépend de l'identité de la session).
///
/// Clé : 256 bits stockée dans l'Android Keystore via [SecretKey].
///
/// Les fichiers vivent dans `<app_docs>/chats/<id>.aichat` (zone privée app).
///
/// Écritures **atomiques** via `.tmp` + rename. Sauvegardes **sérialisées**
/// dans une chaîne `Future` interne pour éviter qu'un tmp.rename concurrent
/// n'écrase une autre sauvegarde.
class EncryptedChatStore {
  EncryptedChatStore._();
  static final EncryptedChatStore instance = EncryptedChatStore._();

  static const _magic = [0x41, 0x49, 0x43, 0x31]; // "AIC1"
  static const int _magicLen = 4;

  Future<void> _saveChain = Future.value();

  Future<Directory> _chatsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/chats');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _chatsDir();
    return File('${dir.path}/$id.aichat');
  }

  /// Charge une session chiffrée, ou null si elle n'existe pas / est corrompue.
  Future<ChatSession?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    try {
      final blob = await file.readAsBytes();
      if (blob.length < _magicLen) {
        throw const FormatException('blob trop court');
      }
      // Magic header — refuse les fichiers étrangers / corrompus.
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
      return ChatSession.fromJson(json);
    } catch (_) {
      // Fichier illisible (clé tournée, données corrompues) : on le supprime
      // pour éviter de retomber dessus à chaque démarrage.
      try {
        await file.delete();
      } catch (_) {/* best-effort */}
      return null;
    }
  }

  /// Sauvegarde une session de manière atomique et sérialisée.
  ///
  /// Les appels concurrents sont chaînés : la sauvegarde N+1 attend la N.
  Future<void> save(ChatSession session) {
    _saveChain = _saveChain.then((_) => _doSave(session));
    return _saveChain;
  }

  Future<void> _doSave(ChatSession session) async {
    final file = await _fileFor(session.id);
    final tmp = File('${file.path}.tmp');
    final key = await SecretKey.instance.getOrCreate();
    final plaintext = utf8.encode(jsonEncode(session.toJson()));
    final aad = Uint8List.fromList(utf8.encode(session.id));
    final blob = AesGcm.encrypt(
      key,
      Uint8List.fromList(plaintext),
      aad: aad,
    );
    final out = Uint8List.fromList([..._magic, ...blob]);
    await tmp.writeAsBytes(out, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  Future<void> deleteAll() async {
    final dir = await _chatsDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
  }
}

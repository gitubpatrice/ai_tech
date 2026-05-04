import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

import '../../models/chat_session.dart';
import '../crypto/aes_gcm.dart';
import '../crypto/secret_key.dart';

/// Argument transmis à l'isolate pour décrypter en parallèle toutes les
/// conversations. La clé est passée comme `Uint8List` (immutable, copiée
/// dans le port d'isolate). L'isolate meurt après la tâche → pas de
/// persistance résiduelle de la clé.
class _ListAllArgs {
  final List<String> paths;
  final Uint8List key;
  const _ListAllArgs(this.paths, this.key);
}

/// Argument transmis à l'isolate pour le save d'une conversation.
class _SaveArgs {
  final String path; // tmp path (le rename atomique reste sur main)
  final Uint8List key;
  final Uint8List aad;
  final Uint8List plaintext;
  const _SaveArgs(this.path, this.key, this.aad, this.plaintext);
}

/// Worker top-level — chiffre + écrit le tmp en parallèle. Le rename
/// atomique reste sur main (très court). Évite ~50ms de freeze sur S9
/// par save.
void _encryptAndWriteInIsolate(_SaveArgs args) {
  const magic = [0x41, 0x49, 0x43, 0x31]; // "AIC1"
  final blob = AesGcm.encrypt(args.key, args.plaintext, aad: args.aad);
  final out = Uint8List.fromList([...magic, ...blob]);
  File(args.path).writeAsBytesSync(out, flush: true);
}

/// Worker top-level — décrypte tous les `.aichat` en parallèle dans un
/// Isolate via `compute()`. Évite le freeze N×AES-GCM sur le UI thread.
List<ChatSession> _decryptAllInIsolate(_ListAllArgs args) {
  const magic = [0x41, 0x49, 0x43, 0x31]; // "AIC1"
  const magicLen = 4;
  final out = <ChatSession>[];
  for (final path in args.paths) {
    try {
      final blob = File(path).readAsBytesSync();
      if (blob.length < magicLen) continue;
      var bad = false;
      for (var i = 0; i < magicLen; i++) {
        if (blob[i] != magic[i]) {
          bad = true;
          break;
        }
      }
      if (bad) continue;
      final body = Uint8List.fromList(blob.sublist(magicLen));
      // L'AAD = id = nom du fichier sans extension.
      final name = path.split(RegExp(r'[\\/]')).last;
      final id = name.endsWith('.aichat')
          ? name.substring(0, name.length - '.aichat'.length)
          : name;
      final aad = Uint8List.fromList(utf8.encode(id));
      final plaintext = AesGcm.decrypt(args.key, body, aad: aad);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      out.add(ChatSession.fromJson(json));
    } catch (_) {
      // Fichier corrompu : on l'ignore. Le main thread le supprimera au
      // prochain `load(id)` qui retombera dessus.
    }
  }
  return out;
}

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
      } catch (_) {
        /* best-effort */
      }
      return null;
    }
  }

  /// Sauvegarde une session de manière atomique et sérialisée.
  ///
  /// Les appels concurrents sont chaînés : la sauvegarde N+1 attend la N.
  ///
  /// **Snapshot immédiat** : `toJson()` est appelé MAINTENANT (synchronously)
  /// avant que la sauvegarde n'entre dans `_saveChain`. Sans ce snapshot, si
  /// l'utilisateur tapait un message pendant qu'un save N était en attente,
  /// le `_doSave` capturait l'état au moment du compute() — pas au moment
  /// du `save()` — et persistait des messages "en cours" (pending) ou des
  /// mutations involontaires.
  Future<void> save(ChatSession session) {
    final id = session.id;
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(session.toJson())),
    );
    _saveChain = _saveChain.then((_) => _doSave(id, plaintext));
    return _saveChain;
  }

  Future<void> _doSave(String id, Uint8List plaintext) async {
    final file = await _fileFor(id);
    final tmp = File('${file.path}.tmp');
    final key = await SecretKey.instance.getOrCreate();
    final aad = Uint8List.fromList(utf8.encode(id));
    // AES-GCM + write tmp dans un Isolate -> évite ~50ms de freeze sur S9
    // par save (chats persistés à chaque tour utilisateur + sur paused).
    await compute(
      _encryptAndWriteInIsolate,
      _SaveArgs(tmp.path, key, aad, plaintext),
    );
    // rename atomique sur main : sur POSIX/Android, rename remplace
    // l'existant en une seule syscall (très court, pas besoin d'isolate).
    await tmp.rename(file.path);
  }

  Future<void> deleteAll() async {
    final dir = await _chatsDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        /* best-effort */
      }
    }
  }

  /// Supprime une conversation précise.
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

  /// Liste toutes les conversations persistées, triées par date de mise à
  /// jour décroissante (plus récente en haut).
  ///
  /// Les fichiers illisibles (clé tournée, corrompus) sont silencieusement
  /// ignorés — ils seront supprimés au prochain `load()` qui leur tomberait
  /// dessus.
  Future<List<ChatSession>> listAll() async {
    final dir = await _chatsDir();
    if (!await dir.exists()) return const [];
    // 1. Énumération filesystem sur main (rapide, juste readdir).
    final paths = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.aichat')) continue;
      paths.add(entity.path);
    }
    if (paths.isEmpty) return const [];
    // 2. Récupère la clé Keystore (1 appel main, indépendant de N).
    final key = await SecretKey.instance.getOrCreate();
    // 3. Décryptage massif des N fichiers DANS L'ISOLATE -> main fluide
    //    même sur 100+ conversations (avant : N × AES-GCM séquentiel
    //    sur thread UI = freeze ~1-2s à l'ouverture de la liste).
    final sessions = await compute(
      _decryptAllInIsolate,
      _ListAllArgs(paths, key),
    );
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }
}

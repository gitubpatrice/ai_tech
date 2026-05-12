import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

import '../crypto/aes_gcm.dart';
import '../crypto/secret_key.dart';

/// Base générique pour la persistance d'objets JSON chiffrés AES-256-GCM.
///
/// Format binaire d'un fichier :
///
/// ```
/// [4 octets magic ASCII][12 octets nonce][N octets ciphertext + 16 octets tag GCM]
/// ```
///
/// L'**AAD** est l'`id` de l'objet (UTF-8). Renommer un fichier le rend
/// illisible : le tag GCM est lié à l'identité, un attaquant ne peut pas
/// recoller `aaa` sur `bbb`.
///
/// La clé maître 256 bits est dans l'Android Keystore via [SecretKey].
///
/// Garanties :
/// - **Écritures atomiques** via `tmp` + `rename` POSIX (pas de fenêtre TOCTOU).
/// - **Sauvegardes sérialisées** dans une chaîne `Future` interne : deux saves
///   concurrents ne s'écrasent jamais.
/// - **Snapshot synchrone** : `toJson()` est appelé immédiatement dans `save()`,
///   avant que la tâche n'entre dans la chaîne — l'objet peut muter ensuite,
///   c'est l'état au moment de l'appel qui est persisté.
/// - **Isolate** : chiffrement/écriture et déchiffrement bulk déportés via
///   `compute()` pour éviter le freeze UI sur petits téléphones.
///
/// Sous-classer en fournissant : [subdirectory], [fileExtension], [magicHeader],
/// [fromJson], [toJson], [idOf], [compareDesc]. Voir [EncryptedChatStore] et
/// [DocumentStore].
abstract class EncryptedJsonStore<T> {
  EncryptedJsonStore();

  /// Nom du sous-dossier dans `getApplicationDocumentsDirectory()`.
  /// Exemple : `'chats'`, `'documents'`.
  String get subdirectory;

  /// Extension de fichier, point inclus. Exemple : `'.aichat'`, `'.aidoc'`.
  String get fileExtension;

  /// Magic header ASCII de 4 octets identifiant le type de fichier.
  /// Exemple : `'AIC1'`, `'AID1'`.
  String get magicHeader;

  /// Désérialisation JSON → objet métier.
  T fromJson(Map<String, dynamic> json);

  /// Sérialisation objet métier → JSON.
  Map<String, dynamic> toJson(T item);

  /// Identifiant unique de l'objet (utilisé comme nom de fichier et AAD).
  String idOf(T item);

  /// Comparateur pour [listAll], typiquement `(a, b) => b.date.compareTo(a.date)`
  /// (ordre décroissant).
  int compareDesc(T a, T b);

  late final Uint8List _magic = _validateMagic(magicHeader);

  Future<void> _saveChain = Future.value();

  static Uint8List _validateMagic(String header) {
    final bytes = utf8.encode(header);
    if (bytes.length != _magicLen) {
      throw ArgumentError(
        'magicHeader doit faire exactement $_magicLen octets ASCII, '
        'reçu ${bytes.length} pour "$header".',
      );
    }
    return Uint8List.fromList(bytes);
  }

  static const int _magicLen = 4;

  Future<Directory> _directory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$subdirectory');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// D9 v0.6.1 — whitelist stricte du nom de fichier dérivé de l'ID.
  /// Refuse tout caractère hors `[a-zA-Z0-9_-]` ou ID vide / trop long.
  /// Sans ça, un futur ID exotique avec `/`, `..`, NULL byte ou caractère
  /// de contrôle bidi écrirait hors du sous-dossier (path traversal).
  static final RegExp _safeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  Future<File> _fileFor(String id) async {
    if (!_safeIdPattern.hasMatch(id)) {
      // QW8 v0.8.1 — defense-in-depth : ne PAS inclure `id` dans le
      // message (peut contenir données contrôlées atterrissant dans logs
      // / crash reports). Le message générique suffit pour le diagnostic.
      throw ArgumentError('ID invalide (whitelist [a-zA-Z0-9_-]{1,64}).');
    }
    final dir = await _directory();
    return File('${dir.path}/$id$fileExtension');
  }

  /// Charge un objet par son [id], ou `null` s'il n'existe pas / est corrompu.
  /// Un fichier illisible (clé tournée, magic invalide, tag GCM cassé) est
  /// supprimé pour ne pas retomber dessus à chaque démarrage.
  Future<T?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    try {
      final blob = await file.readAsBytes();
      _verifyMagic(blob);
      final body = Uint8List.sublistView(blob, _magicLen);
      final key = await SecretKey.instance.getOrCreate();
      final aad = Uint8List.fromList(utf8.encode(id));
      final plaintext = AesGcm.decrypt(key, body, aad: aad);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return fromJson(json);
    } catch (_) {
      await _bestEffortDelete(file);
      return null;
    }
  }

  /// Sauvegarde [item] de manière atomique et sérialisée.
  ///
  /// `toJson(item)` est appelé **synchroniquement** avant que la tâche n'entre
  /// dans la chaîne : si l'objet mute après l'appel à `save`, c'est l'état du
  /// moment qui est persisté, pas l'état futur.
  Future<void> save(T item) {
    final id = idOf(item);
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(toJson(item))));
    final next = _saveChain.then((_) => _doSave(id, plaintext));
    _saveChain = next;
    return next;
  }

  Future<void> _doSave(String id, Uint8List plaintext) async {
    final file = await _fileFor(id);
    final tmp = File('${file.path}.tmp');
    final key = await SecretKey.instance.getOrCreate();
    final aad = Uint8List.fromList(utf8.encode(id));
    // Chiffrement + écriture du tmp dans un isolate : évite ~50 ms de freeze
    // par save sur S9. Le rename atomique reste sur le main (très court).
    await compute(
      _encryptAndWriteIsolate,
      _SaveJob(
        tmpPath: tmp.path,
        key: key,
        aad: aad,
        plaintext: plaintext,
        magic: _magic,
      ),
    );
    await tmp.rename(file.path);
  }

  /// Supprime un objet par [id]. Idempotent — ne lève pas si absent.
  Future<void> deleteOne(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) {
      await _bestEffortDelete(file);
    }
  }

  /// Supprime **tout** le contenu du sous-dossier, y compris d'éventuels
  /// fichiers `.tmp` orphelins (crash entre `write` et `rename`). Mode panique.
  Future<void> deleteAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      await _bestEffortDeleteEntity(entity);
    }
  }

  /// Liste tous les objets persistés, triés via [compareDesc].
  /// Décryptage massif déporté dans un isolate.
  Future<List<T>> listAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return const [];
    final paths = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith(fileExtension)) continue;
      paths.add(entity.path);
    }
    if (paths.isEmpty) return const [];
    final key = await SecretKey.instance.getOrCreate();
    final result = await compute(
      _decryptAllIsolate,
      _ListJob(paths: paths, key: key, magic: _magic, extension: fileExtension),
    );
    // QW7 v0.8.1 — purge les fichiers corrompus signalés par l'isolate
    // (clé tournée, magic invalide, tag GCM cassé). Avant : ils restaient
    // sur disque indéfiniment et étaient re-tentés à chaque listAll.
    for (final path in result.corruptedPaths) {
      try {
        await File(path).delete();
      } catch (_) {
        /* best-effort */
      }
    }
    final items = result.items.map(fromJson).toList()..sort(compareDesc);
    return items;
  }

  void _verifyMagic(Uint8List blob) {
    if (blob.length < _magicLen) {
      throw const FormatException('blob trop court');
    }
    for (var i = 0; i < _magicLen; i++) {
      if (blob[i] != _magic[i]) {
        throw const FormatException('magic invalide');
      }
    }
  }

  static Future<void> _bestEffortDelete(File file) async {
    try {
      await file.delete();
    } catch (_) {
      /* best-effort */
    }
  }

  static Future<void> _bestEffortDeleteEntity(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      /* best-effort */
    }
  }
}

// ---------------------------------------------------------------------------
// Workers d'isolate (top-level requis par `compute`).
// ---------------------------------------------------------------------------

class _SaveJob {
  final String tmpPath;
  final Uint8List key;
  final Uint8List aad;
  final Uint8List plaintext;
  final Uint8List magic;

  const _SaveJob({
    required this.tmpPath,
    required this.key,
    required this.aad,
    required this.plaintext,
    required this.magic,
  });
}

class _ListJob {
  final List<String> paths;
  final Uint8List key;
  final Uint8List magic;
  final String extension;

  const _ListJob({
    required this.paths,
    required this.key,
    required this.magic,
    required this.extension,
  });
}

/// QW7 v0.8.1 — résultat du worker `_decryptAllIsolate` : sépare les
/// items décodés des paths corrompus à purger côté main thread.
class _ListResult {
  final List<Map<String, dynamic>> items;
  final List<String> corruptedPaths;
  const _ListResult({required this.items, required this.corruptedPaths});
}

/// Worker top-level — chiffre + écrit le tmp en parallèle. Le rename atomique
/// reste sur main (très court). Évite le freeze UI sur petit téléphone.
void _encryptAndWriteIsolate(_SaveJob job) {
  final blob = AesGcm.encrypt(job.key, job.plaintext, aad: job.aad);
  final out = Uint8List(job.magic.length + blob.length)
    ..setAll(0, job.magic)
    ..setAll(job.magic.length, blob);
  File(job.tmpPath).writeAsBytesSync(out, flush: true);
}

/// Worker top-level — décrypte tous les fichiers `.<ext>` en parallèle.
/// QW7 v0.8.1 — les fichiers corrompus sont reportés au main thread via
/// `_ListResult.corruptedPaths` pour purge immédiate (sans ça, ils
/// s'accumulaient indéfiniment sur disque).
_ListResult _decryptAllIsolate(_ListJob job) {
  final out = <Map<String, dynamic>>[];
  final corrupted = <String>[];
  final magicLen = job.magic.length;
  final ext = job.extension;
  for (final path in job.paths) {
    try {
      final blob = File(path).readAsBytesSync();
      if (blob.length < magicLen) {
        corrupted.add(path);
        continue;
      }
      var ok = true;
      for (var i = 0; i < magicLen; i++) {
        if (blob[i] != job.magic[i]) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        corrupted.add(path);
        continue;
      }
      final body = Uint8List.sublistView(blob, magicLen);
      // L'AAD = id = nom du fichier sans extension.
      final name = path.split(RegExp(r'[\\/]')).last;
      final id = name.endsWith(ext)
          ? name.substring(0, name.length - ext.length)
          : name;
      final aad = Uint8List.fromList(utf8.encode(id));
      final plaintext = AesGcm.decrypt(job.key, body, aad: aad);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      out.add(json);
    } catch (_) {
      // Fichier corrompu : reporté pour purge main thread.
      corrupted.add(path);
    }
  }
  return _ListResult(items: out, corruptedPaths: corrupted);
}

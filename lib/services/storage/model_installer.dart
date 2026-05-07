import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Événement émis pendant la copie d'un modèle vers le sandbox.
///
/// - Pendant la copie : [finalPath] et [sha256] sont `null`,
///   [copied]/[total] reflètent l'avancement.
/// - À la fin : [finalPath] et [sha256] sont renseignés et
///   [copied] == [total].
typedef ModelInstallEvent = ({
  int copied,
  int total,
  String? finalPath,
  String? sha256,
});

/// Service de copie d'un modèle `.task` / `.litertlm` depuis un chemin
/// fourni par le picker système (SAF) vers le sandbox de l'app
/// (`<appSupport>/models/<basename>`), avec calcul SHA-256 streaming
/// au fil de la copie.
///
/// Pourquoi copier ?
///   1. Persistance : si l'utilisateur déplace/supprime le fichier source,
///      l'app conserve son modèle.
///   2. Lecture rapide : un fichier dans le sandbox est garanti accessible
///      sans permission externe.
///   3. SHA-256 vérifiable : l'utilisateur peut comparer le hash affiché
///      avec celui publié sur Kaggle / HuggingFace (vérification offline).
///
/// Pourquoi pas un hash attendu ?
///   On supporte volontairement tout `.task` / `.litertlm` (Gemma, Qwen,
///   Phi, Llama, variantes communautaires). Imposer une whitelist serait
///   incompatible avec cette philosophie. L'utilisateur a le contrôle.
class ModelInstaller {
  ModelInstaller._();
  static final ModelInstaller instance = ModelInstaller._();

  /// Granularité du yield de progression (4 Mo).
  /// Plus grossier = moins de rebuilds UI.
  /// `File.openRead()` choisit lui-même la taille du buffer en lecture ;
  /// on se contente de flusher la sortie tous les `_yieldEveryBytes`.
  static const int _yieldEveryBytes = 4 * 1024 * 1024;

  /// Renvoie le dossier `<appSupport>/models/`, créé si nécessaire.
  Future<Directory> _modelsDir() async {
    final appSup = await getApplicationSupportDirectory();
    final dir = Directory('${appSup.path}${Platform.pathSeparator}models');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Nettoie les `.tmp` orphelins (crash / annulation pendant une copie).
  Future<void> _cleanupTempFiles(Directory modelsDir) async {
    if (!modelsDir.existsSync()) return;
    try {
      for (final entity in modelsDir.listSync()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          try {
            entity.deleteSync();
          } catch (_) {/* best-effort */}
        }
      }
    } catch (_) {/* best-effort */}
  }

  /// Copie [sourcePath] vers `<appSupport>/models/[filename]` en streaming,
  /// en calculant le SHA-256 au fil de l'eau.
  ///
  /// Atomicité : écrit en `<dest>.tmp` puis rename atomique vers `<dest>`
  /// après la copie complète. En cas d'erreur, `.tmp` est supprimé.
  ///
  /// Émissions du stream :
  ///   - 1 émission tous les ~4 Mo avec `(copied, total, null, null)`.
  ///   - 1 émission finale avec `(total, total, finalPath, sha256Hex)`.
  ///
  /// Pas de hash attendu : l'utilisateur compare lui-même au hash officiel
  /// s'il le souhaite. Cela permet de supporter tous les `.task` /
  /// `.litertlm` (Gemma, Qwen, Phi, Llama, variantes).
  Stream<ModelInstallEvent> installFromSafFile(
    String sourcePath,
    String filename,
  ) async* {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw ArgumentError('Fichier source introuvable : $sourcePath');
    }
    final total = source.lengthSync();
    if (total <= 0) {
      throw ArgumentError('Fichier source vide.');
    }

    // Sécurise le filename : on ne garde que le basename pour éviter
    // toute traversée de path (`../../etc/passwd` → `passwd`).
    final safeName = _sanitizeFilename(filename);

    final dir = await _modelsDir();
    await _cleanupTempFiles(dir);

    final destPath = '${dir.path}${Platform.pathSeparator}$safeName';
    final tmp = File('$destPath.tmp');
    if (tmp.existsSync()) {
      tmp.deleteSync();
    }

    final digestSink = _DigestSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    final input = source.openRead();
    final output = tmp.openWrite();
    var copied = 0;
    var lastYielded = 0;
    var closed = false;

    try {
      await for (final chunk in input) {
        output.add(chunk);
        hashSink.add(chunk);
        copied += chunk.length;
        if (copied - lastYielded >= _yieldEveryBytes || copied == total) {
          await output.flush();
          lastYielded = copied;
          yield (
            copied: copied,
            total: total,
            finalPath: null,
            sha256: null,
          );
        }
      }
      await output.flush();
      await output.close();
      closed = true;
      hashSink.close();
    } catch (_) {
      try {
        if (!closed) await output.close();
      } catch (_) {/* best-effort */}
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {/* best-effort */}
      rethrow;
    }

    final hashHex = digestSink.value.toString().toLowerCase();

    // Rename atomique. Si la destination existe déjà (réinstallation du
    // même fichier), on l'écrase.
    final dest = File(destPath);
    if (dest.existsSync()) {
      try {
        dest.deleteSync();
      } catch (_) {/* best-effort */}
    }
    await tmp.rename(destPath);

    yield (
      copied: total,
      total: total,
      finalPath: destPath,
      sha256: hashHex,
    );
  }

  /// Garde uniquement le basename + caractères safe.
  /// Si le résultat est vide ou suspect, fallback sur `model.task`.
  String _sanitizeFilename(String raw) {
    var name = raw.replaceAll('\\', '/');
    final lastSlash = name.lastIndexOf('/');
    if (lastSlash >= 0) name = name.substring(lastSlash + 1);
    name = name.trim();
    // Whitelist : alphanum + . _ - (tout autre caractère devient _).
    final buf = StringBuffer();
    for (final ch in name.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[A-Za-z0-9._-]').hasMatch(c)) {
        buf.write(c);
      } else {
        buf.write('_');
      }
    }
    var safe = buf.toString();
    if (safe.isEmpty || safe == '.' || safe == '..') {
      safe = 'model.task';
    }
    return safe;
  }
}

/// Sink one-shot pour récupérer le `Digest` final d'un
/// `sha256.startChunkedConversion`.
class _DigestSink implements Sink<Digest> {
  Digest? _value;
  @override
  void add(Digest data) => _value = data;
  @override
  void close() {}
  Digest get value {
    final v = _value;
    if (v == null) {
      throw StateError('Hash non calculé : sink fermé sans données.');
    }
    return v;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_entry.dart';

/// Registre persistant des modèles `.task` / `.litertlm` enregistrés.
///
/// Stocké en JSON dans SharedPreferences (liste typiquement courte, < 10 entrées).
/// Au démarrage, [loadAndPrune] vérifie que chaque chemin existe encore sur
/// disque et nettoie les références mortes (modèle supprimé via file manager).
class ModelRegistry {
  ModelRegistry._();
  static final ModelRegistry instance = ModelRegistry._();

  static const _kRegistry = 'model_registry_v1';

  Future<List<ModelEntry>> loadAndPrune() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRegistry);
    if (raw == null || raw.isEmpty) return [];

    List<ModelEntry> all;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      all = list.map(ModelEntry.fromJson).toList();
    } catch (_) {
      await prefs.remove(_kRegistry);
      return [];
    }

    final alive = <ModelEntry>[];
    for (final entry in all) {
      if (await File(entry.path).exists()) {
        alive.add(entry);
      }
    }
    if (alive.length != all.length) {
      await _saveAll(alive);
    }
    return alive;
  }

  /// Ajoute (ou met à jour) un modèle. Renvoie l'entrée enregistrée.
  ///
  /// Si [sha256] est fourni, il est persisté ; sinon l'entrée garde
  /// `sha256 == null` (cas des modèles ajoutés sans passer par
  /// `ModelInstaller.installFromSafFile`).
  Future<ModelEntry> register({
    required String path,
    required String displayName,
    required String family,
    required String fileType,
    String? sha256,
  }) async {
    final file = File(path);
    final size = await file.exists() ? await file.length() : 0;
    final entry = ModelEntry(
      id: _idFor(path),
      displayName: displayName,
      path: path,
      family: family,
      fileType: fileType,
      sizeBytes: size,
      sha256: sha256,
    );
    final all = await loadAndPrune();
    all.removeWhere((e) => e.id == entry.id);
    all.add(entry);
    await _saveAll(all);
    return entry;
  }

  Future<void> remove(String id) async {
    final all = await loadAndPrune();
    all.removeWhere((e) => e.id == id);
    await _saveAll(all);
  }

  Future<ModelEntry?> findById(String id) async {
    final all = await loadAndPrune();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> wipe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRegistry);
  }

  Future<void> _saveAll(List<ModelEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRegistry,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  String _idFor(String path) {
    final digest = sha256.convert(utf8.encode(path));
    return digest.toString().substring(0, 16);
  }
}

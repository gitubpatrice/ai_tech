import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_entry.dart';
import 'encrypted_json_store.dart';

/// Registre persistant des modèles `.task` / `.litertlm` enregistrés.
///
/// v0.9.0 — Migration depuis SharedPreferences plaintext (`model_registry_v1`)
/// vers un store chiffré AES-256-GCM via [EncryptedJsonStore], pour ne plus
/// laisser fuiter le `displayName` (potentiellement saisi par l'utilisateur)
/// ni les chemins absolus en clair sur disque. La migration est exécutée
/// une seule fois (idempotente : la pref legacy est supprimée après import
/// réussi).
///
/// Format on-disk : un fichier `.aimreg` par modèle, magic `AIM1`,
/// AAD = id du modèle (sha256(path) tronqué 16 chars), même garanties
/// que les autres stores (atomic write, sérialisation, isolate).
class ModelRegistry extends EncryptedJsonStore<ModelEntry> {
  ModelRegistry._();
  static final ModelRegistry instance = ModelRegistry._();

  /// Clé legacy SharedPreferences (plaintext) supprimée après migration.
  /// Conservée publique pour permettre un wipe explicite côté PanicService
  /// même si la migration n'a jamais été exécutée.
  static const _kLegacyPrefKey = 'model_registry_v1';

  @override
  String get subdirectory => 'models_registry';

  @override
  String get fileExtension => '.aimreg';

  @override
  String get magicHeader => 'AIM1';

  @override
  ModelEntry fromJson(Map<String, dynamic> json) => ModelEntry.fromJson(json);

  @override
  Map<String, dynamic> toJson(ModelEntry item) => item.toJson();

  @override
  String idOf(ModelEntry item) => item.id;

  /// Ordre stable par displayName pour l'UI (la liste est typiquement
  /// courte : <10 modèles). Pas de critère temporel sur les `ModelEntry`.
  @override
  int compareDesc(ModelEntry a, ModelEntry b) =>
      a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());

  /// One-shot. Vrai si la migration legacy a déjà été tentée pendant la
  /// vie du process (cache mémoire pour éviter de relire SharedPrefs à
  /// chaque opération).
  bool _migrationDone = false;

  /// Importe (1) le JSON plaintext legacy `model_registry_v1` SharedPrefs
  /// vers le store chiffré, (2) supprime la clé legacy. Idempotent.
  Future<void> _migrateLegacyIfNeeded() async {
    if (_migrationDone) return;
    _migrationDone = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLegacyPrefKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final json in list) {
        try {
          await save(ModelEntry.fromJson(json));
        } catch (_) {
          /* best-effort : on continue avec les autres entrées */
        }
      }
      await prefs.remove(_kLegacyPrefKey);
      if (kDebugMode) {
        debugPrint(
          '[ModelRegistry] migrated ${list.length} entries from legacy '
          'plaintext SharedPreferences to encrypted store.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ModelRegistry._migrateLegacyIfNeeded] $e');
    }
  }

  /// Liste tous les modèles enregistrés, en pruning les références vers
  /// des fichiers qui n'existent plus sur disque (modèle supprimé via
  /// file manager). Déclenche la migration legacy au premier appel.
  Future<List<ModelEntry>> loadAndPrune() async {
    await _migrateLegacyIfNeeded();
    final all = await listAll();
    final alive = <ModelEntry>[];
    final dead = <String>[];
    for (final entry in all) {
      if (await File(entry.path).exists()) {
        alive.add(entry);
      } else {
        dead.add(entry.id);
      }
    }
    for (final id in dead) {
      try {
        await deleteOne(id);
      } catch (_) {
        /* best-effort */
      }
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
    await _migrateLegacyIfNeeded();
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
    await save(entry);
    return entry;
  }

  /// Supprime un modèle par son id. Idempotent.
  Future<void> remove(String id) async {
    await _migrateLegacyIfNeeded();
    await deleteOne(id);
  }

  Future<ModelEntry?> findById(String id) async {
    await _migrateLegacyIfNeeded();
    return load(id);
  }

  /// v0.9.0 — Recherche par chemin (utilisé par le picker pour détecter
  /// une réinstallation au même path, et alerter si le SHA-256 a changé).
  Future<ModelEntry?> findByPath(String path) => findById(_idFor(path));

  /// Mode panique : efface TOUT le sous-dossier chiffré + l'ancienne
  /// clé legacy SharedPreferences si elle existait encore.
  Future<void> wipe() async {
    _migrationDone = true; // évite la migration post-wipe (rien à migrer)
    try {
      await deleteAll();
    } catch (_) {
      /* best-effort */
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLegacyPrefKey);
    } catch (_) {
      /* best-effort */
    }
  }

  /// SHA-256 du chemin tronqué à 16 chars — assez court pour servir
  /// de nom de fichier mais avec une probabilité de collision négligeable
  /// pour les <10 modèles d'un utilisateur réel.
  String _idFor(String path) {
    final digest = sha256.convert(utf8.encode(path));
    return digest.toString().substring(0, 16);
  }
}

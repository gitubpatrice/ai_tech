import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Persiste le chemin du modèle `.task` choisi par l'utilisateur.
///
/// On ne stocke ni l'historique chat ni les prompts ici — uniquement le
/// chemin du modèle, pour éviter à l'user de re-piocher à chaque lancement.
/// Le chemin est revérifié (existence sur disque) au démarrage : si le
/// fichier a disparu (modèle supprimé via le file manager), on oublie la
/// référence proprement.
class ModelSettings {
  static const _kModelPath = 'model_path';

  Future<String?> loadValidModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kModelPath);
    if (path == null || path.isEmpty) return null;
    if (!await File(path).exists()) {
      await prefs.remove(_kModelPath);
      return null;
    }
    return path;
  }

  Future<void> saveModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelPath, path);
  }

  Future<void> clearModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kModelPath);
  }
}

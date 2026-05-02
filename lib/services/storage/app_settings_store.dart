import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_settings.dart';

/// Persiste [AppSettings] dans SharedPreferences (un seul blob JSON).
///
/// Les paramètres ne sont pas sensibles (juste de la configuration UX) :
/// SharedPreferences en clair est acceptable. Les données sensibles
/// (historique chat) sont elles stockées chiffrées séparément.
class AppSettingsStore {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  static const _kSettings = 'app_settings_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      // Données corrompues : on repart d'un état sain plutôt que de planter.
      await prefs.remove(_kSettings);
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  Future<void> wipe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSettings);
  }
}

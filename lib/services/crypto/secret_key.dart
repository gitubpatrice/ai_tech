import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_random.dart' as app;

/// Gère la clé AES-256 utilisée pour chiffrer l'historique des chats.
///
/// La clé est générée aléatoirement au premier lancement (32 octets ≈ 256 bits,
/// via [SecureRandom] qui s'appuie sur `/dev/urandom` Android) et persistée
/// dans le **Android Keystore** via `flutter_secure_storage` (option
/// `encryptedSharedPreferences=true`). Elle ne quitte jamais le téléphone.
///
/// La méthode [wipe] supprime la clé : tous les chats chiffrés deviennent
/// définitivement illisibles. Utilisé par le mode panique.
class SecretKey {
  SecretKey._();
  static final SecretKey instance = SecretKey._();

  static const _kSecretKey = 'aes_master_key_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'ai_tech_secure',
    ),
  );

  Uint8List? _cached;

  /// Récupère la clé. La crée si elle n'existe pas encore.
  Future<Uint8List> getOrCreate() async {
    if (_cached != null) return _cached!;
    final existing = await _storage.read(key: _kSecretKey);
    if (existing != null && existing.isNotEmpty) {
      final key = base64Decode(existing);
      if (key.length == 32) {
        _cached = key;
        return key;
      }
    }
    final fresh = app.SecureRandom().nextBytes(32);
    await _storage.write(key: _kSecretKey, value: base64Encode(fresh));
    _cached = fresh;
    return fresh;
  }

  /// Supprime la clé (utilisé par le mode panique).
  ///
  /// Tous les chats chiffrés avec cette clé deviennent illisibles. Une nouvelle
  /// clé sera générée au prochain appel à [getOrCreate]. Pour ratisser
  /// d'éventuels résidus de migration de backend, on déclenche aussi
  /// [FlutterSecureStorage.deleteAll] côté zone privée de l'app.
  Future<void> wipe() async {
    _cached = null;
    try {
      await _storage.delete(key: _kSecretKey);
    } catch (_) {
      /* on tente deleteAll quand même */
    }
    try {
      await _storage.deleteAll();
    } catch (_) {
      /* best-effort */
    }
  }
}

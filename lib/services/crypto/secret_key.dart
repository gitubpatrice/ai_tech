import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_random.dart' as app;

/// Gère la clé AES-256 utilisée pour chiffrer l'historique des chats.
///
/// La clé est générée aléatoirement au premier lancement (32 octets ≈ 256 bits,
/// via [SecureRandom] qui s'appuie sur `/dev/urandom` Android) et persistée
/// via `flutter_secure_storage`. Elle ne quitte jamais le téléphone.
///
/// **flutter_secure_storage v10** : la lib utilise désormais ses propres
/// ciphers (AES-GCM pour la valeur, RSA-OAEP-SHA256 pour la clé wrap, le tout
/// stocké via DataStore + Android Keystore non-extractible). L'ancienne option
/// `encryptedSharedPreferences=true` (basée sur AndroidX Security
/// EncryptedSharedPreferences, non maintenue) est dépréciée. La migration des
/// données existantes (v9 → v10) est **automatique** au premier accès, grâce
/// à `migrateOnAlgorithmChange: true` (défaut). On conserve le namespace
/// `ai_tech_secure` via `storageNamespace` pour que v10 retrouve les données
/// écrites par v9 dans le même backing store.
///
/// La méthode [wipe] supprime la clé : tous les chats chiffrés deviennent
/// définitivement illisibles. Utilisé par le mode panique.
class SecretKey {
  SecretKey._();
  static final SecretKey instance = SecretKey._();

  static const _kSecretKey = 'aes_master_key_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'ai_tech_secure',
      // Explicite (déjà le défaut en v10) : si le backend de chiffrement
      // change (ex. v9 ESP → v10 DataStore+Keystore), la lib migre les
      // données existantes au premier accès au lieu de les perdre.
      migrateOnAlgorithmChange: true,
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
    // Defensive : on wipe aussi le namespace par défaut au cas où une
    // migration v9 → v10 (ou un futur changement de namespace) aurait
    // laissé des résidus dans l'ancien backing store.
    try {
      await const FlutterSecureStorage().deleteAll();
    } catch (_) {
      /* best-effort */
    }
  }
}

import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import 'secure_random.dart' as app;

/// Chiffrement AES-256-GCM authentifié, avec donnée associée optionnelle (AAD).
///
/// Format binaire produit par [encrypt] :
///   `[12 octets nonce][N octets ciphertext + 16 octets tag GCM]`
///
/// Le nonce est tiré depuis [SecureRandom] (CSPRNG, jamais réutilisé avec la
/// même clé). [decrypt] vérifie le tag d'intégrité ; toute altération du
/// ciphertext OU de l'AAD lève une [ArgumentError].
class AesGcm {
  AesGcm._();

  static const int _nonceLen = 12;
  static const int _macLen = 16;

  /// Chiffre [plaintext] avec [key] (32 octets) et lie le résultat à [aad].
  ///
  /// Si [aad] est fourni, le déchiffrement échouera sauf si la même AAD est
  /// passée — utile pour lier un blob à son emplacement (ex. nom de fichier).
  static Uint8List encrypt(
    Uint8List key,
    Uint8List plaintext, {
    Uint8List? aad,
  }) {
    if (key.length != 32) {
      throw ArgumentError('Clé AES-256 requise (32 octets), reçue ${key.length}.');
    }
    final nonce = app.SecureRandom().nextBytes(_nonceLen);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _macLen * 8,
          nonce,
          aad ?? Uint8List(0),
        ),
      );
    final ct = cipher.process(plaintext);
    return Uint8List.fromList([...nonce, ...ct]);
  }

  /// Déchiffre un buffer produit par [encrypt].
  ///
  /// Lève [ArgumentError] si le tag GCM est invalide (altération détectée).
  static Uint8List decrypt(
    Uint8List key,
    Uint8List blob, {
    Uint8List? aad,
  }) {
    if (key.length != 32) {
      throw ArgumentError('Clé AES-256 requise (32 octets).');
    }
    if (blob.length < _nonceLen + _macLen) {
      throw ArgumentError('Buffer chiffré trop court.');
    }
    final nonce = blob.sublist(0, _nonceLen);
    final ct = blob.sublist(_nonceLen);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _macLen * 8,
          nonce,
          aad ?? Uint8List(0),
        ),
      );
    try {
      return cipher.process(ct);
    } on InvalidCipherTextException catch (_) {
      throw ArgumentError('Données altérées (tag GCM invalide).');
    }
  }
}

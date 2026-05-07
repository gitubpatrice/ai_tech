import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_tech/services/crypto/aes_gcm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test AES-256-GCM round-trip — valide la primitive utilisée par
/// `EncryptedJsonStore<T>` pour persister chats et documents chiffrés.
///
/// On ne teste pas `EncryptedJsonStore` directement parce que sa clé
/// vient de `flutter_secure_storage` (dépend du Keystore Android, pas
/// disponible dans un environnement Dart pur). On teste donc la
/// primitive `AesGcm.encrypt/decrypt` qui est le maillon réellement
/// critique côté sécurité.
void main() {
  // Clé AES-256 fixe pour reproductibilité (NE PAS réutiliser en prod).
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('encrypt/decrypt round-trip sans AAD', () {
    final plaintext = utf8.encode('Bonjour, AI Tech !');
    final blob = AesGcm.encrypt(key, plaintext);
    final decoded = AesGcm.decrypt(key, blob);
    expect(decoded, equals(plaintext));
  });

  test('encrypt/decrypt round-trip avec AAD (id de fichier)', () {
    final plaintext =
        utf8.encode('{"foo":"bar","n":42}');
    final aad = utf8.encode('chat-1234');
    final blob = AesGcm.encrypt(key, plaintext, aad: aad);
    final decoded = AesGcm.decrypt(key, blob, aad: aad);
    expect(decoded, equals(plaintext));
  });

  test('AAD différente entre encrypt et decrypt fait échouer le tag',
      () {
    final plaintext = utf8.encode('secret');
    final aadEnc = utf8.encode('chat-1');
    final aadDec = utf8.encode('chat-2');
    final blob = AesGcm.encrypt(key, plaintext, aad: aadEnc);
    expect(
      () => AesGcm.decrypt(key, blob, aad: aadDec),
      throwsArgumentError,
    );
  });

  test('blob altéré (1 octet flippé) fait échouer le tag GCM', () {
    final plaintext = utf8.encode('integrity check');
    final blob = AesGcm.encrypt(key, plaintext);
    // Inverse un octet du ciphertext (en gardant nonce intact).
    final tampered = Uint8List.fromList(blob);
    final ctOffset = 12 + 4; // après nonce (12 octets), au milieu du ct
    tampered[ctOffset] ^= 0xFF;
    expect(() => AesGcm.decrypt(key, tampered), throwsArgumentError);
  });

  test('encrypt produit un nonce différent à chaque appel (CSPRNG)', () {
    final plaintext = utf8.encode('same plaintext');
    final blob1 = AesGcm.encrypt(key, plaintext);
    final blob2 = AesGcm.encrypt(key, plaintext);
    // Les 12 premiers octets (nonce) doivent différer.
    final nonce1 = blob1.sublist(0, 12);
    final nonce2 = blob2.sublist(0, 12);
    expect(nonce1, isNot(equals(nonce2)));
  });

  test('clé de mauvaise longueur lève ArgumentError', () {
    final badKey = Uint8List(16);
    expect(
      () => AesGcm.encrypt(badKey, Uint8List(0)),
      throwsArgumentError,
    );
  });
}

import 'dart:math' as math;
import 'dart:typed_data';

/// Source unique de bytes aléatoires cryptographiquement sûrs.
///
/// QW6 v0.8.1 — `math.Random.secure()` puise directement `/dev/urandom`
/// sur Android (`getrandom(2)` sur Linux, `BCryptGenRandom` sur Windows).
/// Plus simple et de même qualité d'entropie que le pattern précédent
/// (FortunaRandom seedé une fois avec 32 octets `Random.secure()`) : on
/// supprime la complexité Fortuna inutile, plus de risque oublié de
/// reseed périodique.
class SecureRandom {
  SecureRandom._();
  static final SecureRandom _instance = SecureRandom._();
  factory SecureRandom() => _instance;

  /// Renvoie [length] octets aléatoires.
  Uint8List nextBytes(int length) {
    final rng = math.Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }
}

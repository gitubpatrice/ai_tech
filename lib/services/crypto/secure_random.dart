import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';

/// Source unique de bytes aléatoires cryptographiquement sûrs.
///
/// Utilise [math.Random.secure] (qui s'appuie sur `/dev/urandom` sur Android,
/// `getrandom(2)` sur Linux, `BCryptGenRandom` sur Windows) pour seeder
/// **une seule fois** un PRNG Fortuna réutilisé pour toutes les opérations.
///
/// L'implémentation initiale seedait Fortuna à chaque appel avec
/// `DateTime.now().microsecondsSinceEpoch` (≈ 50 bits d'entropie réelle),
/// ce qui était insuffisant pour des nonces GCM ou une clé maître AES-256.
class SecureRandom {
  SecureRandom._();
  static final SecureRandom _instance = SecureRandom._();
  factory SecureRandom() => _instance;

  final FortunaRandom _rng = FortunaRandom();
  bool _seeded = false;

  /// Renvoie [length] octets aléatoires.
  Uint8List nextBytes(int length) {
    if (!_seeded) {
      final secure = math.Random.secure();
      final seed = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        seed[i] = secure.nextInt(256);
      }
      _rng.seed(KeyParameter(seed));
      _seeded = true;
    }
    return _rng.nextBytes(length);
  }
}

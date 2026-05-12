import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot de l'état mémoire système (lu via `ActivityManager.MemoryInfo`).
///
/// `availMem` peut sous-estimer la mémoire vraiment utilisable car Android
/// inclut le file cache dans `availMem` (libérable sous pression). C'est
/// néanmoins la meilleure estimation portable disponible côté SDK Android.
class MemoryInfo {
  const MemoryInfo({
    required this.availBytes,
    required this.totalBytes,
    required this.thresholdBytes,
    required this.lowMemory,
    required this.isLowRamDevice,
  });

  /// Mémoire actuellement disponible pour les apps (incluant file cache
  /// libérable). En octets.
  final int availBytes;

  /// RAM totale du device (Android 4.0+). En octets.
  final int totalBytes;

  /// Seuil sous lequel le système passe en `lowMemory`. En octets.
  final int thresholdBytes;

  /// Le système est actuellement sous pression mémoire (très peu de marge
  /// avant que le low-memory killer ne commence à tuer les apps).
  final bool lowMemory;

  /// Téléphone marqué "low-RAM device" (Go Edition, <1 Go). Android 4.4+.
  /// Désactive certaines features et augmente l'agressivité du LMK.
  final bool isLowRamDevice;

  /// Rapport humain pour log / debug. Pas affiché en UI directement.
  @override
  String toString() {
    final availMb = (availBytes / (1024 * 1024)).round();
    final totalMb = (totalBytes / (1024 * 1024)).round();
    return 'MemoryInfo(avail=${availMb}Mo, total=${totalMb}Mo, '
        'low=$lowMemory, lowRamDevice=$isLowRamDevice)';
  }
}

/// v0.9.0 — Garde-fou mémoire pour les modèles LLM lourds.
///
/// Gemma 4 E2B occupe ~530 Mo en RAM une fois chargé (KV cache + poids).
/// Sur un device <3 Go (Redmi 9C, Samsung S9, Go Edition), tenter de
/// le charger conduit à un OOM kill brutal (process MediaPipe natif tué,
/// l'app Flutter crash sans message clair). Ce watchdog interroge
/// `ActivityManager.MemoryInfo` AVANT le `installAndLoad` pour avertir
/// l'utilisateur quand la marge est insuffisante.
///
/// Best-effort : si le channel n'est pas joignable (autre plateforme,
/// build sans MainActivity instrumenté), `read()` retourne `null` et les
/// helpers retournent `true` (laisse passer).
class MemoryWatchdog {
  MemoryWatchdog._();
  static final MemoryWatchdog instance = MemoryWatchdog._();

  static const _channel = MethodChannel('com.aitech.ai_tech/memory');

  /// Marge de sécurité requise au-delà de l'estimation modèle, pour
  /// laisser respirer le file cache, l'UI Flutter et le runtime
  /// MediaPipe (allocations natives transitoires).
  static const int safetyMarginMb = 350;

  /// Estimation grossière de l'empreinte RAM par catégorie de modèle.
  /// Utilisée par `hasEnoughFor(family, fileSizeBytes)` quand le caller
  /// ne fournit pas une estimation propre. Valeurs mesurées sur S24 FE.
  /// Pour les familles non listées, on prend 1.3 × fileSize.
  static int estimateRuntimeBytes({required int fileBytes}) {
    // Le runtime MediaPipe a besoin de la taille fichier + ~10-30 %
    // d'overhead (KV cache court terme, tokenizer, runtime).
    return (fileBytes * 1.3).round();
  }

  /// Lit l'état mémoire courant ou `null` si le channel n'est pas
  /// disponible. Best-effort, ne lève jamais.
  Future<MemoryInfo?> read() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAvailableMemory',
      );
      if (raw == null) return null;
      return MemoryInfo(
        availBytes: (raw['availMem'] as num?)?.toInt() ?? 0,
        totalBytes: (raw['totalMem'] as num?)?.toInt() ?? 0,
        thresholdBytes: (raw['threshold'] as num?)?.toInt() ?? 0,
        lowMemory: raw['lowMemory'] as bool? ?? false,
        isLowRamDevice: raw['isLowRamDevice'] as bool? ?? false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MemoryWatchdog.read] $e');
      return null;
    }
  }

  /// Vrai s'il y a assez de RAM dispo pour charger un modèle de
  /// [fileBytes] octets, en tenant compte de [safetyMarginMb] et du
  /// surcoût runtime. Si la lecture échoue (channel KO), retourne
  /// `true` pour ne pas bloquer l'utilisateur (best-effort).
  Future<bool> hasEnoughFor(int fileBytes) async {
    final info = await read();
    if (info == null) return true;
    final needed =
        estimateRuntimeBytes(fileBytes: fileBytes) +
        safetyMarginMb * 1024 * 1024;
    return info.availBytes >= needed;
  }

  /// Variante détaillée pour l'UI : retourne `(ok, info, neededBytes)`.
  /// Permet d'afficher un message précis avec la marge manquante.
  Future<({bool ok, MemoryInfo? info, int neededBytes})> check(
    int fileBytes,
  ) async {
    final info = await read();
    final needed =
        estimateRuntimeBytes(fileBytes: fileBytes) +
        safetyMarginMb * 1024 * 1024;
    if (info == null) return (ok: true, info: null, neededBytes: needed);
    return (ok: info.availBytes >= needed, info: info, neededBytes: needed);
  }
}

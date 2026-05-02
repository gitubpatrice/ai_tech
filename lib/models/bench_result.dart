/// Résultat d'une exécution d'inférence sur le modèle local.
///
/// Mesures simples mais robustes : on chronomètre le premier token (latence
/// "time to first token") et on compte les tokens générés sur la durée totale
/// du stream. Les valeurs sont approximatives — pour le spike, l'objectif est
/// de comparer les devices (S24 / S9 / Redmi 9C) entre eux, pas d'établir une
/// vérité absolue.
class BenchResult {
  const BenchResult({
    required this.firstTokenMs,
    required this.totalMs,
    required this.tokenCount,
    required this.charCount,
    required this.response,
  });

  final int firstTokenMs;
  final int totalMs;
  final int tokenCount;
  final int charCount;
  final String response;

  /// Tokens par seconde sur la phase de génération (hors first-token).
  double get tokensPerSecond {
    final genMs = totalMs - firstTokenMs;
    if (genMs <= 0 || tokenCount <= 1) return 0;
    return (tokenCount - 1) * 1000.0 / genMs;
  }

  /// Caractères par seconde — utile en repli si le décompte de tokens est
  /// indisponible (certains backends ne remontent pas le découpage exact).
  double get charsPerSecond {
    if (totalMs <= 0) return 0;
    return charCount * 1000.0 / totalMs;
  }
}

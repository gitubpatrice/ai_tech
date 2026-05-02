import 'dart:async';

import '../models/bench_result.dart';
import 'llm_service.dart';

/// Lance un prompt et mesure latence + débit.
///
/// On approxime le décompte de tokens par le nombre de chunks reçus depuis le
/// stream. C'est une approximation conservatrice (un chunk ≈ 1 token pour
/// MediaPipe LLM Inference côté Gemma), suffisante pour comparer des devices.
class BenchService {
  const BenchService(this._llm);

  final LlmService _llm;

  /// Exécute [prompt] et renvoie le résultat agrégé.
  ///
  /// Le callback [onPartial] reçoit la réponse cumulée à chaque chunk —
  /// utile pour afficher la génération en direct.
  Future<BenchResult> run(
    String prompt, {
    void Function(String partial)? onPartial,
  }) async {
    final stopwatch = Stopwatch()..start();
    var firstTokenMs = 0;
    var tokenCount = 0;
    final buffer = StringBuffer();

    await for (final chunk in _llm.generateStream(prompt)) {
      if (firstTokenMs == 0) {
        firstTokenMs = stopwatch.elapsedMilliseconds;
      }
      tokenCount++;
      buffer.write(chunk);
      onPartial?.call(buffer.toString());
    }

    stopwatch.stop();
    return BenchResult(
      firstTokenMs: firstTokenMs,
      totalMs: stopwatch.elapsedMilliseconds,
      tokenCount: tokenCount,
      charCount: buffer.length,
      response: buffer.toString(),
    );
  }
}

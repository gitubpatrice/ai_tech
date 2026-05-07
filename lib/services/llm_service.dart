import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/model_family.dart';
import '../models/model_limits.dart';

/// Service single-turn pour le banc d'essai (`SpikeScreen`).
///
/// Utilise une `InferenceModelSession` directe (pas de chat multi-tour) pour
/// mesurer first-token et tok/s sur un prompt unique sans pollution de contexte.
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  InferenceModel? _model;
  InferenceModelSession? _session;
  ModelFamily _family = ModelFamily.gemma;

  bool get isLoaded => _model != null;
  ModelFamily get family => _family;

  /// Installe le modèle (`.task` ou `.litertlm`) auprès du plugin.
  Future<void> installFromFile(
    String path, {
    ModelFamily family = ModelFamily.auto,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ArgumentError('Fichier modèle introuvable: $path');
    }
    final size = await file.length();
    if (size < ModelLimits.minModelBytes) {
      throw ArgumentError(
        'Fichier suspect (${(size / 1024 / 1024).toStringAsFixed(1)} Mo). '
        'Un modèle .task fait typiquement 500 Mo à 4 Go.',
      );
    }
    _family = family == ModelFamily.auto
        ? ModelFamilyUtils.detectFamily(path)
        : family;
    await FlutterGemma.installModel(
      modelType: ModelFamilyUtils.modelTypeFor(_family),
      fileType: ModelFamilyUtils.detectFileType(path),
    ).fromFile(path).install();
  }

  Future<void> load({int maxTokens = 1024, PreferredBackend? backend}) async {
    await dispose();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: backend,
      supportImage: false,
    );
    _session = await _model!.createSession(temperature: 0.7, topK: 40);
  }

  /// Stream tokens pour le prompt donné (single-turn, pas d'historique).
  Stream<String> generateStream(String prompt) async* {
    final session = _session;
    if (session == null) {
      throw StateError('Modèle non chargé. Appelez load() d\'abord.');
    }
    final formatted = ModelFamilyUtils.formatUserMessage(prompt, _family);
    await session.addQueryChunk(Message.text(text: formatted, isUser: true));
    yield* session.getResponseAsync();
  }

  Future<void> dispose() async {
    try {
      await _session?.close();
    } catch (_) {
      /* best-effort */
    }
    try {
      await _model?.close();
    } catch (_) {
      /* best-effort */
    }
    _session = null;
    _model = null;
  }
}

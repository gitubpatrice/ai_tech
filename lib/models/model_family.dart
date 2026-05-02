import 'package:flutter_gemma/flutter_gemma.dart';

/// Famille de modèle, utilisée pour adapter le format de prompt.
///
/// flutter_gemma 0.14 connaît nativement Gemma et DeepSeek. Pour Qwen / Phi /
/// Llama, on passe `ModelType.general` et on applique nous-mêmes le template
/// ChatML attendu via [formatUserMessage] / [formatSystemPrompt].
enum ModelFamily { auto, gemma, qwen, phi, llama, deepseek }

/// Helpers partagés entre `ChatService` et `LlmService`.
class ModelFamilyUtils {
  const ModelFamilyUtils._();

  /// Détecte la famille à partir du nom de fichier (ex. `gemma3-1b-it-int4.task`).
  static ModelFamily detectFamily(String path) {
    final name = path.toLowerCase();
    if (name.contains('gemma')) return ModelFamily.gemma;
    if (name.contains('qwen')) return ModelFamily.qwen;
    if (name.contains('phi')) return ModelFamily.phi;
    if (name.contains('llama')) return ModelFamily.llama;
    if (name.contains('deepseek')) return ModelFamily.deepseek;
    return ModelFamily.gemma;
  }

  /// Détecte le format de fichier d'après l'extension.
  static ModelFileType detectFileType(String path) {
    return path.toLowerCase().endsWith('.litertlm')
        ? ModelFileType.litertlm
        : ModelFileType.task;
  }

  /// Sélectionne le `ModelType` flutter_gemma adapté à la famille.
  static ModelType modelTypeFor(ModelFamily family) {
    return family == ModelFamily.gemma ? ModelType.gemmaIt : ModelType.general;
  }

  /// Formate un message utilisateur selon le template attendu.
  ///
  /// - Gemma : pris en charge nativement par le plugin (`ModelType.gemmaIt`).
  /// - Qwen / Phi / Llama : ChatML générique.
  /// - DeepSeek : format propriétaire.
  static String formatUserMessage(String text, ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma:
      case ModelFamily.auto:
        return text;
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return '<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n';
      case ModelFamily.deepseek:
        return '<｜begin▁of▁sentence｜><｜User｜>$text<｜Assistant｜>';
    }
  }

  /// Formate un prompt système avec le rôle correct.
  ///
  /// Pour Qwen/Phi/Llama, on utilise `<|im_start|>system` (rôle natif ChatML)
  /// au lieu d'injecter le prompt système comme un message user — c'est plus
  /// résistant aux tentatives de prompt injection depuis le chat.
  static String formatSystemPrompt(String text, ModelFamily family) {
    switch (family) {
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return '<|im_start|>system\n$text<|im_end|>\n';
      case ModelFamily.gemma:
      case ModelFamily.auto:
        // flutter_gemma applique le template Gemma natif en interne.
        return text;
      case ModelFamily.deepseek:
        return '<｜begin▁of▁sentence｜>$text';
    }
  }
}

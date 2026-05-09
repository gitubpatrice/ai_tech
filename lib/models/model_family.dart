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

  /// Détecte la famille et renvoie son nom (string court, ex. `'gemma'`).
  /// Centralise la logique partagée entre `SettingsScreen`, `OnboardingScreen`
  /// et `ModelRegistry.register()`.
  static String detectFamilyName(String path) => detectFamily(path).name;

  /// Convertit un nom court (`'gemma'`, `'qwen'`, …) vers `ModelFamily`.
  /// Fallback `gemma` pour toute valeur inconnue. Évite la duplication d'un
  /// switch inline `_familyOf` dans `ChatScreen`.
  static ModelFamily fromName(String s) {
    switch (s) {
      case 'qwen':
        return ModelFamily.qwen;
      case 'phi':
        return ModelFamily.phi;
      case 'llama':
        return ModelFamily.llama;
      case 'deepseek':
        return ModelFamily.deepseek;
      case 'auto':
        return ModelFamily.auto;
      case 'gemma':
      default:
        return ModelFamily.gemma;
    }
  }

  /// Nom affichable d'un modèle à partir de son path. Retire le séparateur
  /// de path (Windows ou Unix) et l'extension `.task` / `.litertlm`.
  /// Source unique de vérité pour `SettingsScreen` + `OnboardingScreen`.
  static String displayNameOf(String path) {
    final base = path.split(RegExp(r'[\\/]')).last;
    return base.replaceAll(RegExp(r'\.(task|litertlm)$'), '');
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
  ///
  /// F1 v0.6.1 — Gemma 3 ne supporte pas nativement de rôle "system" : le
  /// modèle fold le system prompt dans le 1er turn user. On utilise donc le
  /// template Gemma natif `<start_of_turn>user … <end_of_turn>` (le caller
  /// passe `isUser: true` pour ce prompt sur Gemma — voir
  /// `chat_service.applySystemPrompt`). Avant : `isUser: false` produisait
  /// un tour `model` avec autorité affaiblie face aux injections
  /// "ignore les instructions précédentes".
  static String formatSystemPrompt(String text, ModelFamily family) {
    switch (family) {
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return '<|im_start|>system\n$text<|im_end|>\n';
      case ModelFamily.gemma:
      case ModelFamily.auto:
        // F1 — délimiteur Gemma natif. flutter_gemma 0.14.x reconnaît
        // les balises `<start_of_turn>` / `<end_of_turn>` en formattage
        // additionnel. Le caller doit envoyer ce texte avec `isUser:true`
        // car Gemma 3 traite le 1er user turn comme contenant les
        // instructions effectives (pas de rôle `system` séparé).
        return '<start_of_turn>user\n$text<end_of_turn>\n';
      case ModelFamily.deepseek:
        return '<｜begin▁of▁sentence｜>$text';
    }
  }

  /// F1 v0.6.1 — détermine si `Message.text` doit être marqué `isUser:true`
  /// pour le prompt système. Sur Gemma, OUI (1er user turn = instructions).
  /// Sur les autres familles, NON (rôle `system` natif via tag).
  static bool systemPromptIsUser(ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma:
      case ModelFamily.auto:
        return true;
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
      case ModelFamily.deepseek:
        return false;
    }
  }
}

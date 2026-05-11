import 'package:flutter_gemma/flutter_gemma.dart';

/// Famille de modèle, utilisée pour adapter le format de prompt et le
/// `ModelType` flutter_gemma.
///
/// flutter_gemma 0.15.x connaît nativement Gemma 3 (`gemmaIt`), Gemma 4
/// (`gemma4`, rôle `system` natif + speculative decoding) et DeepSeek
/// (`deepSeek`). Pour Qwen / Phi / Llama, on passe `ModelType.general`
/// et on applique nous-mêmes le template ChatML attendu via
/// [ModelFamilyUtils.formatUserMessage] / [ModelFamilyUtils.formatSystemPrompt].
enum ModelFamily { auto, gemma, gemma4, qwen, phi, llama, deepseek }

/// Helpers partagés entre `ChatService` et `LlmService`.
class ModelFamilyUtils {
  const ModelFamilyUtils._();

  /// Détecte la famille à partir du nom de fichier.
  ///
  /// L'ordre de détection est important : `gemma-4` / `gemma4` doit matcher
  /// AVANT `gemma` générique pour éviter qu'un modèle Gemma 4 soit chargé
  /// avec le template Gemma 3 (tokens spéciaux `<start_of_turn>` réinjectés
  /// par le template natif Gemma 4 → gibberish).
  static ModelFamily detectFamily(String path) {
    final name = path.toLowerCase();
    if (name.contains('gemma-4') || name.contains('gemma4')) {
      return ModelFamily.gemma4;
    }
    if (name.contains('gemma')) return ModelFamily.gemma;
    if (name.contains('qwen')) return ModelFamily.qwen;
    if (name.contains('phi')) return ModelFamily.phi;
    if (name.contains('llama')) return ModelFamily.llama;
    if (name.contains('deepseek')) return ModelFamily.deepseek;
    return ModelFamily.gemma;
  }

  /// Détecte la famille et renvoie son nom (string court, ex. `'gemma'`,
  /// `'gemma4'`). Centralise la logique partagée entre `SettingsScreen`,
  /// `OnboardingScreen` et `ModelRegistry.register()`.
  static String detectFamilyName(String path) => detectFamily(path).name;

  /// Convertit un nom court (`'gemma'`, `'gemma4'`, `'qwen'`, …) vers
  /// `ModelFamily`. Fallback `gemma` pour toute valeur inconnue.
  ///
  /// v0.8.0 — `'auto'` est traité comme `gemma` (au lieu de
  /// `ModelFamily.auto`) : `auto` ne doit JAMAIS être persisté dans
  /// `ModelEntry.family`. Si jamais une entrée corrompue contient
  /// `'auto'`, on retombe sur le fallback gemma plutôt que de risquer un
  /// `modelTypeFor(auto) → gemmaIt` appliqué à un Gemma 4 (gibberish).
  /// Pour les paramètres de fonction qui acceptent `auto`, utiliser
  /// directement `ModelFamily.auto` (pas via fromName).
  static ModelFamily fromName(String s) {
    switch (s) {
      case 'gemma4':
        return ModelFamily.gemma4;
      case 'qwen':
        return ModelFamily.qwen;
      case 'phi':
        return ModelFamily.phi;
      case 'llama':
        return ModelFamily.llama;
      case 'deepseek':
        return ModelFamily.deepseek;
      case 'gemma':
      case 'auto':
      default:
        return ModelFamily.gemma;
    }
  }

  /// v0.8.0 — Label affichable pour l'UI (Settings, About, picker).
  /// Plus lisible que `family.name` brut ("gemma4" → "Gemma 4").
  static String displayLabel(ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma:
      case ModelFamily.auto:
        return 'Gemma 3';
      case ModelFamily.gemma4:
        return 'Gemma 4';
      case ModelFamily.qwen:
        return 'Qwen';
      case ModelFamily.phi:
        return 'Phi';
      case ModelFamily.llama:
        return 'Llama';
      case ModelFamily.deepseek:
        return 'DeepSeek';
    }
  }

  /// Variante prenant directement le nom court stocké en JSON.
  static String displayLabelFromName(String s) =>
      displayLabel(fromName(s));

  /// Nom affichable d'un modèle à partir de son path. Retire le séparateur
  /// de path (Windows ou Unix) et l'extension `.task` / `.litertlm`.
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
  ///
  /// - `ModelFamily.gemma4` → `ModelType.gemma4` (rôle `system` natif,
  ///   tokens `<|...|>` parsés par le SDK, function calling natif).
  /// - `ModelFamily.gemma` / `auto` → `ModelType.gemmaIt` (Gemma 2 / 3 / 3n).
  /// - `ModelFamily.deepseek` → `ModelType.deepSeek`.
  /// - Qwen / Phi / Llama → `ModelType.general` (template ChatML appliqué
  ///   manuellement dans [formatUserMessage] / [formatSystemPrompt]).
  static ModelType modelTypeFor(ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma4:
        return ModelType.gemma4;
      case ModelFamily.gemma:
      case ModelFamily.auto:
        return ModelType.gemmaIt;
      case ModelFamily.deepseek:
        return ModelType.deepSeek;
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return ModelType.general;
    }
  }

  /// Détermine la valeur à passer à `enableSpeculativeDecoding` selon la
  /// famille ET le fileType.
  ///
  /// - `gemma4` + `.litertlm` → `null` (le SDK décide selon que le
  ///   `.litertlm` contient un draft model MTP ou non — fallback silencieux
  ///   sans crash si pas de drafter, vrai gain perf si présent).
  /// - sinon → `null` aussi (les autres familles n'ont pas de drafter et
  ///   MediaPipe ignorerait silencieusement le flag de toute façon ; passer
  ///   `null` plutôt que `false` évite de bloquer un futur drafter ajouté
  ///   côté SDK).
  ///
  /// v0.8.0 — auparavant on passait `true`/`false` explicite ce qui (a)
  /// pouvait faire échouer l'init sur un `.litertlm` Gemma 4 pré-MTP, (b)
  /// était silencieusement droppé sur `.task` MediaPipe.
  static bool? speculativeDecodingFor(ModelFamily family, ModelFileType ft) {
    if (family == ModelFamily.gemma4 && ft == ModelFileType.litertlm) {
      return null; // SDK décide — anti-crash si draft model absent
    }
    return null;
  }

  /// Conservé pour rétrocompat éventuelle. Préférer [speculativeDecodingFor].
  @Deprecated('utiliser speculativeDecodingFor(family, fileType)')
  static bool supportsSpeculativeDecoding(ModelFamily family) {
    return family == ModelFamily.gemma4;
  }

  /// True si la famille a un rôle `system` natif géré par le SDK
  /// flutter_gemma via le paramètre `systemInstruction` de `createChat()`.
  /// Dans ce cas, l'application n'a PAS à formater elle-même le prompt
  /// système (et ne doit surtout pas injecter de tokens spéciaux comme
  /// `<start_of_turn>` qui seraient réinterprétés par le template natif).
  ///
  /// - Gemma 3 / 3n : oui (le SDK fold le system prompt dans le 1er user
  ///   turn avec les bons délimiteurs).
  /// - Gemma 4 : oui (vrai rôle `system` natif depuis Gemma 4).
  /// - DeepSeek : oui (rôle natif).
  /// - Qwen / Phi / Llama : non (`ModelType.general` côté SDK, le template
  ///   ChatML est généré côté Dart par [formatSystemPrompt]).
  static bool hasNativeSystemRole(ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma:
      case ModelFamily.gemma4:
      case ModelFamily.auto:
      case ModelFamily.deepseek:
        return true;
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return false;
    }
  }

  /// Formate un message utilisateur selon le template attendu.
  ///
  /// - Gemma 3 / Gemma 4 / DeepSeek : pris en charge nativement par le
  ///   plugin via `ModelType.gemmaIt` / `ModelType.gemma4` /
  ///   `ModelType.deepSeek`. On renvoie le texte brut.
  /// - Qwen / Phi / Llama : ChatML générique, le SDK est en
  ///   `ModelType.general` donc on doit injecter les délimiteurs.
  static String formatUserMessage(String text, ModelFamily family) {
    switch (family) {
      case ModelFamily.gemma:
      case ModelFamily.gemma4:
      case ModelFamily.auto:
      case ModelFamily.deepseek:
        return text;
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return '<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n';
    }
  }

  /// Formate un prompt système pour les familles qui n'ont PAS de rôle
  /// `system` natif côté SDK (Qwen / Phi / Llama). Pour les autres,
  /// préférer passer le prompt brut via [hasNativeSystemRole] +
  /// `systemInstruction` à `createChat()`.
  ///
  /// Lève [StateError] si appelée sur une famille à rôle `system` natif —
  /// ça signalerait une régression du chemin d'injection du prompt système.
  static String formatSystemPrompt(String text, ModelFamily family) {
    switch (family) {
      case ModelFamily.qwen:
      case ModelFamily.phi:
      case ModelFamily.llama:
        return '<|im_start|>system\n$text<|im_end|>\n';
      case ModelFamily.gemma:
      case ModelFamily.gemma4:
      case ModelFamily.auto:
      case ModelFamily.deepseek:
        throw StateError(
          'formatSystemPrompt ne doit pas être appelé pour $family : '
          'utiliser systemInstruction de createChat() à la place.',
        );
    }
  }
}

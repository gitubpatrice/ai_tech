/// Limites partagées concernant les fichiers modèles `.task` / `.litertlm`.
///
/// Centralise les constantes utilisées par plusieurs services
/// (`ChatService`, `LlmService`, `ModelPickerScreen`) pour éviter la
/// dérive (un seuil mis à jour à un endroit et oublié ailleurs).
class ModelLimits {
  const ModelLimits._();

  /// Taille minimale plausible d'un modèle `.task` / `.litertlm`.
  ///
  /// Un modèle MediaPipe LLM Inference fait typiquement entre 500 Mo
  /// et 4 Go. En dessous de 50 Mo, on considère le fichier comme
  /// suspect (texte trompeur, fichier corrompu, mauvaise extension).
  static const int minModelBytes = 50 * 1024 * 1024;

  /// Format humain (`'50 Mo'`) pour les messages d'erreur.
  static String get minModelLabel => '${minModelBytes ~/ (1024 * 1024)} Mo';
}

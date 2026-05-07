/// Métadonnées d'un modèle `.task` / `.litertlm` enregistré dans l'app.
class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.displayName,
    required this.path,
    required this.family,
    required this.sizeBytes,
    required this.fileType,
    this.sha256,
  });

  /// Identifiant stable (hash court du path).
  final String id;

  /// Nom affichable (pris du nom de fichier ou personnalisé par l'user).
  final String displayName;

  /// Chemin absolu du fichier sur le téléphone.
  final String path;

  /// Famille de modèle (gemma / qwen / phi / llama / deepseek).
  final String family;

  /// Format de fichier (`task` ou `litertlm`).
  final String fileType;

  final int sizeBytes;

  /// SHA-256 hex lowercase du fichier au moment de l'installation, ou `null`
  /// pour les entrées créées avant v0.5.0 (legacy) ou ajoutées sans copie
  /// sandbox (chemin direct hors `installFromSafFile`).
  ///
  /// Permet à l'utilisateur de comparer offline avec le hash officiel
  /// publié par Kaggle / HuggingFace, et de vérifier l'intégrité plus tard.
  final String? sha256;

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} Mo';
  }

  ModelEntry copyWith({String? sha256}) => ModelEntry(
    id: id,
    displayName: displayName,
    path: path,
    family: family,
    sizeBytes: sizeBytes,
    fileType: fileType,
    sha256: sha256 ?? this.sha256,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'path': path,
    'family': family,
    'fileType': fileType,
    'sizeBytes': sizeBytes,
    if (sha256 != null) 'sha256': sha256,
  };

  factory ModelEntry.fromJson(Map<String, dynamic> json) {
    return ModelEntry(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      path: json['path'] as String,
      family: json['family'] as String? ?? 'gemma',
      fileType: json['fileType'] as String? ?? 'task',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      sha256: json['sha256'] as String?,
    );
  }
}

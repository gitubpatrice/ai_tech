/// Métadonnées d'un modèle `.task` / `.litertlm` enregistré dans l'app.
class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.displayName,
    required this.path,
    required this.family,
    required this.sizeBytes,
    required this.fileType,
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

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} Mo';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'path': path,
        'family': family,
        'fileType': fileType,
        'sizeBytes': sizeBytes,
      };

  factory ModelEntry.fromJson(Map<String, dynamic> json) {
    return ModelEntry(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      path: json['path'] as String,
      family: json['family'] as String? ?? 'gemma',
      fileType: json['fileType'] as String? ?? 'task',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }
}

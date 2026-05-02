/// Paramètres utilisateur persistés.
///
/// Les valeurs sont volontairement bornées pour éviter les configurations
/// extrêmes qui dégradent la qualité (température > 1.5) ou consomment
/// inutilement la RAM (maxTokens > 4096 sur petit modèle).
class AppSettings {
  const AppSettings({
    this.temperature = 0.7,
    this.topK = 40,
    this.maxTokens = 1024,
    this.activeModelId,
    this.firstLaunchCompleted = false,
  });

  final double temperature;
  final int topK;
  final int maxTokens;
  final String? activeModelId;
  final bool firstLaunchCompleted;

  static const double minTemperature = 0.1;
  static const double maxTemperature = 1.5;
  static const int minTopK = 1;
  static const int maxTopK = 100;
  static const int minMaxTokens = 256;
  static const int maxMaxTokens = 4096;

  AppSettings copyWith({
    double? temperature,
    int? topK,
    int? maxTokens,
    String? activeModelId,
    bool? firstLaunchCompleted,
    bool clearActiveModel = false,
  }) {
    return AppSettings(
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      maxTokens: maxTokens ?? this.maxTokens,
      activeModelId:
          clearActiveModel ? null : (activeModelId ?? this.activeModelId),
      firstLaunchCompleted:
          firstLaunchCompleted ?? this.firstLaunchCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'topK': topK,
        'maxTokens': maxTokens,
        if (activeModelId != null) 'activeModelId': activeModelId,
        'firstLaunchCompleted': firstLaunchCompleted,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      temperature: (json['temperature'] as num?)?.toDouble().clamp(
            minTemperature,
            maxTemperature,
          ) ??
          0.7,
      topK: (json['topK'] as int?)?.clamp(minTopK, maxTopK) ?? 40,
      maxTokens:
          (json['maxTokens'] as int?)?.clamp(minMaxTokens, maxMaxTokens) ?? 1024,
      activeModelId: json['activeModelId'] as String?,
      firstLaunchCompleted: json['firstLaunchCompleted'] as bool? ?? false,
    );
  }
}

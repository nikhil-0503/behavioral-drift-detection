class MlDriftResult {
  final String packageName;
  final String date;
  final bool drift;
  final double confidence;
  final Map<String, dynamic> models;

  MlDriftResult({
    required this.packageName,
    required this.date,
    required this.drift,
    required this.confidence,
    required this.models,
  });

  factory MlDriftResult.fromJson(Map<String, dynamic> json) {
    return MlDriftResult(
      packageName: json['packageName'] as String,
      date: json['date'] as String,
      drift: json['finalDrift'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      models: Map<String, dynamic>.from(json['models'] as Map),
    );
  }
}

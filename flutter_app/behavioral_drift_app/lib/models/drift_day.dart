

class DriftDay {
  final String date;
  final bool drift;
  final double confidence;

  DriftDay({
    required this.date,
    required this.drift,
    required this.confidence,
  });

  factory DriftDay.fromJson(Map<String, dynamic> json) {
    return DriftDay(
      date: json['date'],
      drift: json['drift'],
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

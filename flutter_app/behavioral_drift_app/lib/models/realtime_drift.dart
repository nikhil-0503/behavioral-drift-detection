/// Real-time drift measurement for a single monitored app.
/// Compares the user's current behavior to their own baseline.
class RealtimeDrift {
  final int? id;
  final String packageName;
  final String date; // yyyy-MM-dd
  final double baselineAvgMinutes; // historical daily average
  final double todayMinutes; // usage today
  final double driftScore; // deviation magnitude 0..1+
  final bool isDrifted;
  final String explanation;

  RealtimeDrift({
    this.id,
    required this.packageName,
    required this.date,
    required this.baselineAvgMinutes,
    required this.todayMinutes,
    required this.driftScore,
    required this.isDrifted,
    this.explanation = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'date': date,
      'baseline_avg_minutes': baselineAvgMinutes,
      'today_minutes': todayMinutes,
      'drift_score': driftScore,
      'is_drifted': isDrifted ? 1 : 0,
      'explanation': explanation,
    };
  }

  factory RealtimeDrift.fromMap(Map<String, dynamic> map) {
    return RealtimeDrift(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      date: map['date'] as String,
      baselineAvgMinutes: (map['baseline_avg_minutes'] as num).toDouble(),
      todayMinutes: (map['today_minutes'] as num).toDouble(),
      driftScore: (map['drift_score'] as num).toDouble(),
      isDrifted: (map['is_drifted'] as int) == 1,
      explanation: map['explanation'] as String? ?? '',
    );
  }
}

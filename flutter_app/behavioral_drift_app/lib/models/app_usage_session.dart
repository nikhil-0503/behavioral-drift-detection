/// Records a single usage session for a monitored app.
class AppUsageSession {
  final int? id;
  final String packageName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String date; // yyyy-MM-dd

  AppUsageSession({
    this.id,
    required this.packageName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'date': date,
    };
  }

  factory AppUsageSession.fromMap(Map<String, dynamic> map) {
    return AppUsageSession(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      durationSeconds: map['duration_seconds'] as int,
      date: map['date'] as String,
    );
  }
}

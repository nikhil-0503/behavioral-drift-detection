/// Represents an app that the user has added to the monitoring list.
/// Once added, an app can never be removed (append-only by design).
class MonitoredApp {
  final int? id;
  final String packageName;
  final String appName;
  final int dailyLimitMinutes; // cannot increase once set
  final int todayUsageSeconds;
  final bool isBlocked;
  final DateTime addedAt;

  MonitoredApp({
    this.id,
    required this.packageName,
    required this.appName,
    required this.dailyLimitMinutes,
    this.todayUsageSeconds = 0,
    this.isBlocked = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  MonitoredApp copyWith({
    int? id,
    String? packageName,
    String? appName,
    int? dailyLimitMinutes,
    int? todayUsageSeconds,
    bool? isBlocked,
    DateTime? addedAt,
  }) {
    return MonitoredApp(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      todayUsageSeconds: todayUsageSeconds ?? this.todayUsageSeconds,
      isBlocked: isBlocked ?? this.isBlocked,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'package_name': packageName,
      'app_name': appName,
      'daily_limit_minutes': dailyLimitMinutes,
      'today_usage_seconds': todayUsageSeconds,
      'is_blocked': isBlocked ? 1 : 0,
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory MonitoredApp.fromMap(Map<String, dynamic> map) {
    return MonitoredApp(
      id: map['id'] as int?,
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      dailyLimitMinutes: map['daily_limit_minutes'] as int,
      todayUsageSeconds: map['today_usage_seconds'] as int? ?? 0,
      isBlocked: (map['is_blocked'] as int? ?? 0) == 1,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }

  /// Percentage of daily limit used (0.0 – 1.0+).
  double get usageRatio {
    if (dailyLimitMinutes <= 0) return 0.0;
    return (todayUsageSeconds / 60.0) / dailyLimitMinutes;
  }

  /// Minutes remaining before limit is reached.
  int get remainingMinutes {
    final used = todayUsageSeconds ~/ 60;
    return (dailyLimitMinutes - used).clamp(0, dailyLimitMinutes);
  }

  /// Whether usage has exceeded the set limit.
  bool get isLimitExceeded => todayUsageSeconds >= (dailyLimitMinutes * 60);
}

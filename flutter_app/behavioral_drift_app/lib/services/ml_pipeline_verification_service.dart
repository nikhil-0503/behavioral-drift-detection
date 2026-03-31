import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';

/// Verifies the ML pipeline is correctly receiving and processing
/// real device data. Can be run as a health check from debug settings.
class MlPipelineVerificationService {
  final AppDatabase _db = AppDatabase();

  /// Run a full verification and return a diagnostic report.
  Future<MlPipelineReport> verify(List<MonitoredApp> apps) async {
    if (kIsWeb) {
      return MlPipelineReport(
        status: PipelineStatus.unsupported,
        message: 'ML pipeline verification not available on web.',
      );
    }

    final checks = <String, bool>{};
    final details = <String>[];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check 1: Monitored apps exist
    final monApps = await _db.getMonitoredApps();
    checks['monitored_apps_exist'] = monApps.isNotEmpty;
    details.add('Monitored apps: ${monApps.length}');

    // Check 2: Usage sessions exist for at least one app
    int totalSessions = 0;
    for (final app in monApps) {
      final sessions = await _db.getSessionsForDate(app.packageName, today);
      totalSessions += sessions.length;
    }
    checks['usage_sessions_today'] = totalSessions > 0;
    details.add('Usage sessions today: $totalSessions');

    // Check 3: Daily totals available for baseline computation
    int appsWithHistory = 0;
    for (final app in monApps) {
      final history = await _db.dailyTotals(app.packageName, 14);
      if (history.isNotEmpty) appsWithHistory++;
    }
    checks['historical_data_exists'] = appsWithHistory > 0;
    details.add('Apps with historical data: $appsWithHistory / ${monApps.length}');

    // Check 4: Drift scores exist
    final drifts = await _db.getAllDriftForDate(today);
    checks['drift_scores_computed'] = drifts.isNotEmpty;
    details.add('Drift scores today: ${drifts.length}');

    // Check 5: At least one app has non-zero usage
    final appsWithUsage = monApps.where((a) => a.todayUsageSeconds > 0).length;
    checks['live_usage_data'] = appsWithUsage > 0;
    details.add('Apps with usage today: $appsWithUsage');

    // Determine overall status
    final passed = checks.values.where((v) => v).length;
    final total = checks.length;
    PipelineStatus status;
    String message;

    if (passed == total) {
      status = PipelineStatus.healthy;
      message = 'All $total checks passed. ML pipeline is fully operational.';
    } else if (passed >= 3) {
      status = PipelineStatus.partial;
      message = '$passed/$total checks passed. Pipeline is partially operational. '
          'More usage data will improve accuracy.';
    } else if (monApps.isEmpty) {
      status = PipelineStatus.noData;
      message = 'No monitored apps found. Add apps to start the ML pipeline.';
    } else {
      status = PipelineStatus.degraded;
      message = 'Only $passed/$total checks passed. '
          'Keep the app running to collect more data.';
    }

    return MlPipelineReport(
      status: status,
      message: message,
      checks: checks,
      details: details,
      appsChecked: monApps.length,
      driftScoresToday: drifts.length,
      usageSessionsToday: totalSessions,
      appsWithHistory: appsWithHistory,
    );
  }
}

enum PipelineStatus { healthy, partial, degraded, noData, unsupported }

class MlPipelineReport {
  final PipelineStatus status;
  final String message;
  final Map<String, bool> checks;
  final List<String> details;
  final int appsChecked;
  final int driftScoresToday;
  final int usageSessionsToday;
  final int appsWithHistory;

  MlPipelineReport({
    required this.status,
    required this.message,
    this.checks = const {},
    this.details = const [],
    this.appsChecked = 0,
    this.driftScoresToday = 0,
    this.usageSessionsToday = 0,
    this.appsWithHistory = 0,
  });

  bool get isHealthy => status == PipelineStatus.healthy;
  bool get isUsingRealData =>
      usageSessionsToday > 0 && appsWithHistory > 0;
}

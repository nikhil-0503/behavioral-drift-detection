import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';
import '../models/realtime_drift.dart';

/// Computes per-app behavioral drift by comparing today's usage to
/// the user's own historical baseline (user-vs-own, NOT user-vs-user).
///
/// Drift score = |today - baselineAvg| / max(baselineAvg, 1)
/// Drifted if score > threshold (default 0.5 = 50 % deviation).
class DriftDetectionService extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  static const double _driftThreshold = 0.5;
  static const int _baselineDays = 14;
  static const int _minDaysForRealBaseline = 3;

  List<RealtimeDrift> _latestDrifts = [];
  List<RealtimeDrift> get latestDrifts => List.unmodifiable(_latestDrifts);

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Recompute drift for all monitored apps using today's data.
  Future<void> computeAll(List<MonitoredApp> apps) async {
    final drifts = <RealtimeDrift>[];
    for (final app in apps) {
      final drift = await _computeForApp(app);
      if (drift != null) drifts.add(drift);
    }
    _latestDrifts = drifts;
    notifyListeners();
  }

  Future<RealtimeDrift?> _computeForApp(MonitoredApp app) async {
    // Historical daily totals (last N days, excluding today)
    final history = await _db.dailyTotals(app.packageName, _baselineDays);
    history.remove(_today); // exclude today from baseline

    final todayMin = app.todayUsageSeconds / 60.0;
    double baselineMin;
    String explanation;
    bool usedDummy = false;

    if (history.length < _minDaysForRealBaseline) {
      // Not enough real data — generate dummy baseline for meaningful display
      usedDummy = true;
      final dummyBaseline = _generateDummyBaseline(app.dailyLimitMinutes);
      baselineMin = dummyBaseline;
    } else {
      final avgSeconds =
          history.values.reduce((a, b) => a + b) / history.length;
      baselineMin = avgSeconds / 60.0;
    }

    final score = (todayMin - baselineMin).abs() / max(baselineMin, 1.0);
    final isDrifted = score > _driftThreshold;

    if (usedDummy) {
      if (!isDrifted) {
        explanation =
            'Simulated baseline (${history.length} days collected). '
            'Usage looks normal so far.';
      } else if (todayMin > baselineMin) {
        explanation =
            'Simulated: ${(score * 100).toStringAsFixed(0)}% above estimated baseline. '
            'Collecting more data for accurate drift.';
      } else {
        explanation =
            'Simulated: ${(score * 100).toStringAsFixed(0)}% below estimated baseline.';
      }
    } else {
      if (!isDrifted) {
        explanation = 'Your usage is within normal range.';
      } else if (todayMin > baselineMin) {
        explanation =
            'You\'ve used ${app.appName} ${(score * 100).toStringAsFixed(0)}% more '
            'than your ${_baselineDays}-day average. This is a significant deviation.';
      } else {
        explanation =
            'Usage is ${(score * 100).toStringAsFixed(0)}% below your baseline – '
            'unusual drop detected.';
      }
    }

    final drift = RealtimeDrift(
      packageName: app.packageName,
      date: _today,
      baselineAvgMinutes: baselineMin,
      todayMinutes: todayMin,
      driftScore: score.clamp(0.0, 2.0),
      isDrifted: isDrifted,
      explanation: explanation,
    );

    // Persist
    await _db.insertDrift(drift);
    return drift;
  }

  /// Generate a realistic dummy baseline in minutes based on the app's limit.
  /// Used when < _minDaysForRealBaseline days of data are available.
  double _generateDummyBaseline(int dailyLimitMinutes) {
    // Assume user typically uses ~60% of their set limit
    final rng = Random();
    final base = dailyLimitMinutes * 0.6;
    final jitter = (rng.nextDouble() - 0.5) * dailyLimitMinutes * 0.1;
    return (base + jitter).clamp(1.0, dailyLimitMinutes.toDouble());
  }

  /// Fetch persisted drift history for one app.
  Future<List<RealtimeDrift>> getHistory(String packageName,
      {int limit = 30}) async {
    return _db.getDriftHistory(packageName, limit: limit);
  }

  /// Get all drift entries for today (for dashboard summary).
  Future<List<RealtimeDrift>> getTodayDrifts() async {
    return _db.getAllDriftForDate(_today);
  }
}

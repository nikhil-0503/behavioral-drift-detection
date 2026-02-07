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

    if (history.isEmpty) {
      // Not enough data yet – report zero drift
      return RealtimeDrift(
        packageName: app.packageName,
        date: _today,
        baselineAvgMinutes: 0,
        todayMinutes: app.todayUsageSeconds / 60.0,
        driftScore: 0,
        isDrifted: false,
        explanation: 'Collecting baseline data…',
      );
    }

    final avgSeconds =
        history.values.reduce((a, b) => a + b) / history.length;
    final baselineMin = avgSeconds / 60.0;
    final todayMin = app.todayUsageSeconds / 60.0;

    final score = (todayMin - baselineMin).abs() / max(baselineMin, 1.0);
    final isDrifted = score > _driftThreshold;

    String explanation;
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

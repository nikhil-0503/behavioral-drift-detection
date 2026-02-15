import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';
import '../models/realtime_drift.dart';
import '../models/ml_drift_result.dart';
import 'ml_drift_service.dart';

/// Computes per-app behavioral drift by combining:
///   1. Local statistical comparison (today vs baseline)
///   2. Backend ML models (Isolation Forest + Autoencoder + Z-score)
///
/// If the backend is reachable, ML results augment the local drift score.
/// If not, falls back to local-only analysis.
class DriftDetectionService extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  final MlDriftService _mlService = MlDriftService();
  static const double _driftThreshold = 0.5;
  static const int _baselineDays = 14;
  static const int _minDaysForRealBaseline = 3;

  List<RealtimeDrift> _latestDrifts = [];
  List<RealtimeDrift> get latestDrifts => List.unmodifiable(_latestDrifts);

  List<MlDriftResult> _latestMlResults = [];
  List<MlDriftResult> get latestMlResults => List.unmodifiable(_latestMlResults);

  bool _mlAvailable = false;
  bool get mlAvailable => _mlAvailable;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Recompute drift for all monitored apps using today's data.
  /// Attempts to use ML backend for enhanced accuracy.
  Future<void> computeAll(List<MonitoredApp> apps) async {
    // Step 1: Compute local drift for all apps
    final drifts = <RealtimeDrift>[];
    for (final app in apps) {
      final drift = await _computeForApp(app);
      if (drift != null) drifts.add(drift);
    }

    // Step 2: Try ML backend for enhanced drift analysis
    List<MlDriftResult> mlResults = [];
    try {
      mlResults = await _mlService.computeForApps(apps, historyDays: _baselineDays);
      _mlAvailable = mlResults.isNotEmpty;
    } catch (e) {
      debugPrint('ML backend not available: $e');
      _mlAvailable = false;
    }

    // Step 3: Fuse local + ML results
    if (mlResults.isNotEmpty) {
      for (int i = 0; i < drifts.length; i++) {
        final ml = mlResults
            .where((m) => m.packageName == drifts[i].packageName)
            .firstOrNull;
        if (ml != null) {
          drifts[i] = _fuseWithMl(drifts[i], ml);
        }
      }
    }

    _latestDrifts = drifts;
    _latestMlResults = mlResults;
    notifyListeners();
  }

  /// Fuse local drift result with ML backend result.
  /// Uses weighted combination: 40% local + 60% ML (ML models are stronger).
  RealtimeDrift _fuseWithMl(RealtimeDrift local, MlDriftResult ml) {
    // Weighted fusion: ML confidence (0-1) combined with local score
    final mlScore = ml.confidence; // 0 to 1
    final localScore = local.driftScore; // 0 to 2

    // Normalize local to 0-1 range for fusion
    final localNorm = (localScore / 2.0).clamp(0.0, 1.0);

    // Weighted average: 40% local, 60% ML
    final fusedScore = (0.4 * localNorm + 0.6 * mlScore);
    final fusedDrift = ml.drift || (fusedScore >= 0.34);

    // Build detailed explanation with model breakdown
    final models = ml.models;
    final statDrift = models['statistical']?['drift'] == true;
    final isoDrift = models['isolationForest']?['drift'] == true;
    final aeDrift = models['autoencoder']?['drift'] == true;

    final modelVotes = [
      if (statDrift) 'Statistical' else null,
      if (isoDrift) 'Isolation Forest' else null,
      if (aeDrift) 'Autoencoder' else null,
    ].whereType<String>().toList();

    String explanation;
    if (fusedDrift) {
      if (modelVotes.isEmpty) {
        explanation =
            'Local analysis detected ${(localScore * 100).toStringAsFixed(0)}% '
            'deviation from your baseline.';
      } else {
        explanation =
            'ML detected drift via ${modelVotes.join(" + ")} '
            '(confidence: ${(ml.confidence * 100).toStringAsFixed(0)}%). '
            'Today: ${local.todayMinutes.toStringAsFixed(0)}min vs '
            'baseline: ${local.baselineAvgMinutes.toStringAsFixed(0)}min.';
      }
    } else {
      explanation = 'All ML models confirm normal behavior. '
          'Today: ${local.todayMinutes.toStringAsFixed(0)}min, '
          'baseline: ${local.baselineAvgMinutes.toStringAsFixed(0)}min.';
    }

    return RealtimeDrift(
      id: local.id,
      packageName: local.packageName,
      date: local.date,
      baselineAvgMinutes: local.baselineAvgMinutes,
      todayMinutes: local.todayMinutes,
      driftScore: (fusedScore * 2.0).clamp(0.0, 2.0), // scale back to 0-2
      isDrifted: fusedDrift,
      explanation: explanation,
    );
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

    double score;
    bool isDrifted;

    // When using dummy baseline AND user hasn't used the app at all today,
    // don't flag as drifted — there's no real data to compare against.
    if (usedDummy && todayMin < 0.5) {
      score = 0.0;
      isDrifted = false;
    } else {
      score = (todayMin - baselineMin).abs() / max(baselineMin, 1.0);
      isDrifted = score > _driftThreshold;
    }

    if (usedDummy) {
      if (todayMin < 0.5) {
        explanation =
            'Not enough data yet (${history.length} days collected). '
            'Start using this app to generate a baseline.';
      } else if (!isDrifted) {
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

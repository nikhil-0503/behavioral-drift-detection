// import 'dart:convert';
// import 'package:flutter/services.dart';
// import '../models/drift_day.dart';

// class DriftRepository {
//   static Future<List<DriftDay>> load() async {
//     final jsonStr = await rootBundle.loadString(
//       'assets/drift_results.json',
//     );

//     final List data = json.decode(jsonStr);
//     return data.map((e) => DriftDay.fromJson(e)).toList();
//   }
// }
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/app_database.dart';
import '../models/drift_day.dart';
import '../services/drift_api_service.dart';

class DriftRepository {
  static final DriftApiService _api = DriftApiService();
  static final AppDatabase _db = AppDatabase();

  /// Load drift days from all available sources.
  /// On Android, merges both:
  ///   1. Offline dataset JSON (existing ML pipeline)
  ///   2. Live user-generated drift data (realtime_drift DB table)
  /// On web, uses API or falls back to asset JSON.
  static Future<List<DriftDay>> load({bool preferNetwork = true}) async {
    final useLocal = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final allDays = <String, DriftDay>{};

    // ── Source 1: Offline dataset JSON (always available) ──
    try {
      final jsonStr = await rootBundle.loadString('assets/drift_results.json');
      final List data = json.decode(jsonStr);
      for (final e in data) {
        final day = DriftDay.fromJson(Map<String, dynamic>.from(e));
        allDays[day.date] = day;
      }
    } catch (e) {
      debugPrint('Error loading drift_results.json: $e');
    }

    // ── Source 2: API (if requested and reachable) ──
    if (preferNetwork) {
      try {
        final apiDays = await _api.fetchDriftDays();
        for (final day in apiDays) {
          allDays[day.date] = day; // API data overwrites offline data
        }
      } catch (e) {
        debugPrint('Drift API fetch failed: $e');
      }
    }

    // ── Source 3: Live local DB data (Android only) ──
    if (useLocal) {
      try {
        final localDays = await _loadFromLocal();
        for (final day in localDays) {
          // Live data takes priority — merge with existing
          if (allDays.containsKey(day.date)) {
            // Keep the one with higher confidence (live data is more relevant)
            if (day.confidence > (allDays[day.date]!.confidence)) {
              allDays[day.date] = day;
            }
          } else {
            allDays[day.date] = day;
          }
        }
      } catch (e) {
        debugPrint('Error loading local drift data: $e');
      }
    }

    // Sort by date ascending
    final result = allDays.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// Load only live user data from local DB.
  static Future<List<DriftDay>> loadLiveOnly() async {
    return _loadFromLocal();
  }

  /// Load only offline dataset data.
  static Future<List<DriftDay>> loadOfflineOnly() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/drift_results.json');
      final List data = json.decode(jsonStr);
      return data
          .map((e) => DriftDay.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error loading drift_results.json: $e');
      return [];
    }
  }

  static Future<List<DriftDay>> _loadFromLocal() async {
    try {
      final rows = await _db.getDriftDaySummaries();
      return rows.map((row) {
        final avgScore = (row['avg_score'] as num?)?.toDouble() ?? 0.0;
        final confidence = math.min(avgScore / 2.0, 1.0);
        final isDrifted = (row['is_drifted'] as int?) == 1;
        return DriftDay(
          date: row['date'] as String,
          drift: isDrifted,
          confidence: confidence,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading local drift summaries: $e');
      return [];
    }
  }
}
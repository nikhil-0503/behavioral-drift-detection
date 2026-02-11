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

  static Future<List<DriftDay>> load({bool preferNetwork = true}) async {
    final useLocal = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (useLocal && !preferNetwork) {
      return _loadFromLocal();
    }

    if (preferNetwork) {
      try {
        return await _api.fetchDriftDays();
      } catch (e) {
        debugPrint('Drift API fetch failed: $e');
      }
    }

    if (useLocal) {
      final local = await _loadFromLocal();
      if (local.isNotEmpty) return local;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/drift_results.json');
      final List data = json.decode(jsonStr);
      return data
          .map((e) => DriftDay.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stacktrace) {
      debugPrint('Error loading drift_results.json: $e');
      debugPrint('Stacktrace: $stacktrace');
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
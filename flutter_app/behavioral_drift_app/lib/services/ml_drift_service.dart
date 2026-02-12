import 'package:flutter/foundation.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';
import '../models/ml_drift_result.dart';
import 'ml_drift_api_service.dart';

class MlDriftService {
  final AppDatabase _db = AppDatabase();
  final MlDriftApiService _api = MlDriftApiService();

  Future<List<MlDriftResult>> computeForApps(
    List<MonitoredApp> apps, {
    int historyDays = 30,
  }) async {
    if (apps.isEmpty) return [];

    final payload = <Map<String, dynamic>>[];
    for (final app in apps) {
      final history = await _db.getDailyUsageHistory(
        app.packageName,
        limit: historyDays,
      );
      if (history.isEmpty) continue;

      payload.add({
        'packageName': app.packageName,
        'history': history
            .map((row) => {
                  'date': row['date'] as String,
                  'minutes': (row['total_seconds'] as int) / 60.0,
                })
            .toList(),
      });
    }

    if (payload.isEmpty) return [];

    try {
      return await _api.computeDriftForApps(payload);
    } catch (e) {
      debugPrint('ML drift fetch failed: $e');
      return [];
    }
  }
}

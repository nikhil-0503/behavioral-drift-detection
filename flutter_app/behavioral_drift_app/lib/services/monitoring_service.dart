import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';
import '../models/limit_rules.dart';

/// Manages the list of monitored apps, tracks usage via native Android,
/// and enforces limits (warning + blocking).
class MonitoringService extends ChangeNotifier {
  static const _channel = MethodChannel('com.behavioral_drift/monitoring');

  final AppDatabase _db = AppDatabase();
  List<MonitoredApp> _apps = [];
  List<MonitoredApp> get apps => List.unmodifiable(_apps);

  // Web-only in-memory storage for testing
  final List<MonitoredApp> _webApps = [];

  bool _historyLoaded = false;

  /// Initialise: load apps from DB and refresh usage from native.
  Future<void> init() async {
    if (kIsWeb) {
      _apps = List.from(_webApps);
    } else {
      _apps = await _db.getMonitoredApps();
      await refreshUsage();
      // Load historical usage data once on startup
      if (!_historyLoaded) {
        await _loadUsageHistory();
        _historyLoaded = true;
      }
    }
    notifyListeners();
  }

  /// Add an app to the monitoring list. Cannot be removed later.
  /// The daily limit is capped at [LimitRules.maxLimitMinutes] (30 min).
  Future<bool> addApp({
    required String packageName,
    required String appName,
    required int dailyLimitMinutes,
  }) async {
    // Enforce 30-minute cap
    final capped = LimitRules.clampInitialLimit(dailyLimitMinutes);
    if (capped <= 0) return false;

    // Check if already exists
    if (_apps.any((a) => a.packageName == packageName)) {
      return false;
    }

    // On web: add to in-memory list
    if (kIsWeb) {
      final app = MonitoredApp(
        packageName: packageName,
        appName: appName,
        dailyLimitMinutes: capped,
      );
      _webApps.add(app);
      _apps = List.from(_webApps);
      notifyListeners();
      return true;
    }

    // On Android: use database
    final exists = await _db.isAppMonitored(packageName);
    if (exists) return false; // already present

    final app = MonitoredApp(
      packageName: packageName,
      appName: appName,
      dailyLimitMinutes: capped,
    );
    await _db.insertMonitoredApp(app);
    _apps = await _db.getMonitoredApps();
    notifyListeners();

    // Tell native side to start tracking this package
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('addTrackedApp', {
          'packageName': packageName,
          'limitMinutes': capped,
        });
      } catch (_) {}

      // Immediately load history for the new app
      await _loadUsageHistoryForApp(packageName);
    }
    return true;
  }

  /// Reduce limit (increase rejected). Returns true on success.
  Future<bool> reduceLimit(String packageName, int newLimit) async {
    final app = _apps.firstWhere((a) => a.packageName == packageName,
        orElse: () => throw StateError('App not monitored'));
    if (!LimitRules.canChangeLimit(
        currentMinutes: app.dailyLimitMinutes, proposedMinutes: newLimit)) {
      return false;
    }
    final ok = await _db.reduceLimit(packageName, newLimit);
    if (ok) {
      _apps = await _db.getMonitoredApps();
      // Sync new limit to native SharedPreferences
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _channel.invokeMethod('addTrackedApp', {
            'packageName': packageName,
            'limitMinutes': newLimit,
          });
        } catch (_) {}
      }
      notifyListeners();
    }
    return ok;
  }

  /// Reset limit back to the default (30 min). Only allowed if the
  /// current limit is below 30. Returns true on success.
  Future<bool> resetLimitToDefault(String packageName) async {
    final app = _apps.firstWhere((a) => a.packageName == packageName,
        orElse: () => throw StateError('App not monitored'));
    if (!LimitRules.canResetToDefault(app.dailyLimitMinutes)) return false;
    final ok =
        await _db.resetLimitToDefault(packageName, LimitRules.defaultLimitMinutes);
    if (ok) {
      _apps = await _db.getMonitoredApps();
      // Sync to native
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _channel.invokeMethod('addTrackedApp', {
            'packageName': packageName,
            'limitMinutes': LimitRules.defaultLimitMinutes,
          });
        } catch (_) {}
      }
      notifyListeners();
    }
    return ok;
  }

  /// Pull latest usage data from native Android and update DB.
  Future<void> refreshUsage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final app in _apps) {
      try {
        final seconds = await _channel.invokeMethod<int>('getUsageToday', {
          'packageName': app.packageName,
        });
        if (seconds != null) {
          await _db.updateUsage(app.packageName, seconds);

          // Also upsert today's session so drift baseline has data
          await _db.upsertDailySession(app.packageName, today, seconds);

          // Check enforcement
          if (LimitRules.shouldBlock(seconds, app.dailyLimitMinutes)) {
            await _db.setBlocked(app.packageName, true);
            _blockApp(app.packageName);
          }
        }
      } catch (_) {}
    }
    _apps = await _db.getMonitoredApps();
    notifyListeners();
  }

  /// Fetch usage history from native Android for all monitored apps
  /// and insert into usage_sessions so drift baseline can be computed.
  Future<void> _loadUsageHistory() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    for (final app in _apps) {
      await _loadUsageHistoryForApp(app.packageName);
    }
  }

  Future<void> _loadUsageHistoryForApp(String packageName) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final result = await _channel.invokeListMethod('getUsageHistory', {
        'packageName': packageName,
        'days': 14,
      });
      if (result == null) return;
      for (final entry in result) {
        final map = Map<String, dynamic>.from(entry as Map);
        final date = map['date'] as String;
        final seconds = (map['seconds'] as num).toInt();
        if (seconds > 0) {
          await _db.upsertDailySession(packageName, date, seconds);
        }
      }
    } catch (e) {
      debugPrint('Failed to load history for $packageName: $e');
    }
  }

  /// Get installed apps from the device (for the "add app" picker).
  Future<List<Map<String, String>>> getInstalledApps() async {
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final result = await _channel.invokeListMethod('getInstalledApps');
      if (result == null) return [];
      return result
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _blockApp(String packageName) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _channel.invokeMethod('blockApp', {'packageName': packageName});
    } catch (_) {}
  }

  /// Reset daily usage counters (called by WorkManager at midnight).
  Future<void> resetDaily() async {
    await _db.resetDailyUsage();
    _apps = await _db.getMonitoredApps();
    // Clear native blocked_apps prefs so overlay stops firing
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('midnightReset');
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Start the foreground service for real-time monitoring.
  /// Should be called once after permissions are granted.
  Future<void> startForegroundService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('startMonitoringService');
    } catch (e) {
      debugPrint('Could not start foreground service: $e');
    }
  }
}

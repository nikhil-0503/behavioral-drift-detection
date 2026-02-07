import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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

  /// Initialise: load apps from DB and refresh usage from native.
  Future<void> init() async {
    if (kIsWeb) {
      _apps = List.from(_webApps);
    } else {
      _apps = await _db.getMonitoredApps();
      await refreshUsage();
    }
    notifyListeners();
  }

  /// Add an app to the monitoring list. Cannot be removed later.
  Future<bool> addApp({
    required String packageName,
    required String appName,
    required int dailyLimitMinutes,
  }) async {
    if (dailyLimitMinutes <= 0) return false;
    
    // Check if already exists
    if (_apps.any((a) => a.packageName == packageName)) {
      return false;
    }
    
    // On web: add to in-memory list
    if (kIsWeb) {
      final app = MonitoredApp(
        packageName: packageName,
        appName: appName,
        dailyLimitMinutes: dailyLimitMinutes,
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
      dailyLimitMinutes: dailyLimitMinutes,
    );
    await _db.insertMonitoredApp(app);
    _apps = await _db.getMonitoredApps();
    notifyListeners();

    // Tell native side to start tracking this package
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('addTrackedApp', {
          'packageName': packageName,
          'limitMinutes': dailyLimitMinutes,
        });
      } catch (_) {}
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
      notifyListeners();
    }
    return ok;
  }

  /// Pull latest usage data from native Android and update DB.
  Future<void> refreshUsage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    for (final app in _apps) {
      try {
        final seconds = await _channel.invokeMethod<int>('getUsageToday', {
          'packageName': app.packageName,
        });
        if (seconds != null) {
          await _db.updateUsage(app.packageName, seconds);

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
    notifyListeners();
  }
}

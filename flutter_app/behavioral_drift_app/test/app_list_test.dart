import 'package:flutter_test/flutter_test.dart';
import 'package:behavioral_drift_app/models/monitored_app.dart';

void main() {
  group('MonitoredApp - Immutable Add-Only List', () {
    test('app can be created with valid fields', () {
      final app = MonitoredApp(
        packageName: 'com.example.test',
        appName: 'Test App',
        dailyLimitMinutes: 30,
      );
      expect(app.packageName, equals('com.example.test'));
      expect(app.appName, equals('Test App'));
      expect(app.dailyLimitMinutes, equals(30));
      expect(app.todayUsageSeconds, equals(0));
      expect(app.isBlocked, isFalse);
    });

    test('toMap and fromMap round-trip correctly', () {
      final original = MonitoredApp(
        packageName: 'com.example.app',
        appName: 'My App',
        dailyLimitMinutes: 45,
        todayUsageSeconds: 1200,
        isBlocked: true,
        addedAt: DateTime(2026, 1, 15),
      );

      final map = original.toMap();
      final restored = MonitoredApp.fromMap(map);

      expect(restored.packageName, equals(original.packageName));
      expect(restored.appName, equals(original.appName));
      expect(restored.dailyLimitMinutes, equals(original.dailyLimitMinutes));
      expect(restored.todayUsageSeconds, equals(original.todayUsageSeconds));
      expect(restored.isBlocked, equals(original.isBlocked));
    });

    test('usageRatio computed correctly', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 60, // 60 min = 3600 sec
        todayUsageSeconds: 1800, // 30 min
      );
      expect(app.usageRatio, closeTo(0.5, 0.01));
    });

    test('isLimitExceeded true when at limit', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 30, // 1800 seconds
        todayUsageSeconds: 1800,
      );
      expect(app.isLimitExceeded, isTrue);
    });

    test('isLimitExceeded false when under limit', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 30,
        todayUsageSeconds: 1500,
      );
      expect(app.isLimitExceeded, isFalse);
    });

    test('remainingMinutes computed correctly', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 60,
        todayUsageSeconds: 2400, // 40 min
      );
      expect(app.remainingMinutes, equals(20));
    });

    test('remainingMinutes is 0 when exceeded', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 30,
        todayUsageSeconds: 2400, // 40 min > 30 min limit
      );
      expect(app.remainingMinutes, equals(0));
    });

    test('copyWith preserves unmodified fields', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 60,
        todayUsageSeconds: 100,
      );
      final updated = app.copyWith(todayUsageSeconds: 200);
      expect(updated.packageName, equals('com.test'));
      expect(updated.dailyLimitMinutes, equals(60));
      expect(updated.todayUsageSeconds, equals(200));
    });

    test('map does not include id when null', () {
      final app = MonitoredApp(
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 30,
      );
      final map = app.toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('map includes id when set', () {
      final app = MonitoredApp(
        id: 5,
        packageName: 'com.test',
        appName: 'Test',
        dailyLimitMinutes: 30,
      );
      final map = app.toMap();
      expect(map['id'], equals(5));
    });
  });
}

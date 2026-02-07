import 'package:flutter_test/flutter_test.dart';
import 'package:behavioral_drift_app/models/limit_rules.dart';
import 'package:behavioral_drift_app/models/monitored_app.dart';
import 'package:behavioral_drift_app/models/realtime_drift.dart';

void main() {
  group('Enforcement Trigger Logic', () {
    test('warn fires between 80%-99% of limit', () {
      // 60 min limit
      for (int usedMin = 48; usedMin < 60; usedMin++) {
        final usedSec = usedMin * 60;
        expect(
          LimitRules.shouldWarn(usedSec, 60),
          isTrue,
          reason: 'Should warn at $usedMin/60 minutes',
        );
      }
    });

    test('warn does not fire below 80%', () {
      for (int usedMin = 0; usedMin < 48; usedMin++) {
        final usedSec = usedMin * 60;
        expect(
          LimitRules.shouldWarn(usedSec, 60),
          isFalse,
          reason: 'Should not warn at $usedMin/60 minutes',
        );
      }
    });

    test('block fires at and above 100%', () {
      for (int usedMin = 60; usedMin <= 90; usedMin++) {
        final usedSec = usedMin * 60;
        expect(
          LimitRules.shouldBlock(usedSec, 60),
          isTrue,
          reason: 'Should block at $usedMin/60 minutes',
        );
      }
    });

    test('block does not fire below 100%', () {
      for (int usedMin = 0; usedMin < 60; usedMin++) {
        final usedSec = usedMin * 60;
        expect(
          LimitRules.shouldBlock(usedSec, 60),
          isFalse,
          reason: 'Should not block at $usedMin/60 minutes',
        );
      }
    });

    test('warn and block are mutually exclusive in valid range', () {
      // At exactly the limit: block=true, warn=false
      expect(LimitRules.shouldBlock(60 * 60, 60), isTrue);
      expect(LimitRules.shouldWarn(60 * 60, 60), isFalse);

      // At 50 min out of 60: block=false, warn=true
      expect(LimitRules.shouldBlock(50 * 60, 60), isFalse);
      expect(LimitRules.shouldWarn(50 * 60, 60), isTrue);

      // At 30 min out of 60: both false
      expect(LimitRules.shouldBlock(30 * 60, 60), isFalse);
      expect(LimitRules.shouldWarn(30 * 60, 60), isFalse);
    });

    test('MonitoredApp.isLimitExceeded matches shouldBlock', () {
      for (int used = 0; used <= 3600; used += 300) {
        final app = MonitoredApp(
          packageName: 'com.test',
          appName: 'Test',
          dailyLimitMinutes: 30,
          todayUsageSeconds: used,
        );
        expect(
          app.isLimitExceeded,
          equals(LimitRules.shouldBlock(used, 30)),
          reason: 'Mismatch at $used seconds',
        );
      }
    });

    test('limit reduction chain works correctly', () {
      int limit = 120;

      // Can reduce 120 -> 90
      expect(LimitRules.canChangeLimit(
          currentMinutes: limit, proposedMinutes: 90), isTrue);
      limit = 90;

      // Can reduce 90 -> 60
      expect(LimitRules.canChangeLimit(
          currentMinutes: limit, proposedMinutes: 60), isTrue);
      limit = 60;

      // Cannot increase 60 -> 90 (even though we were at 90 before)
      expect(LimitRules.canChangeLimit(
          currentMinutes: limit, proposedMinutes: 90), isFalse);

      // Cannot increase 60 -> 120 (original value)
      expect(LimitRules.canChangeLimit(
          currentMinutes: limit, proposedMinutes: 120), isFalse);

      // Can still reduce 60 -> 30
      expect(LimitRules.canChangeLimit(
          currentMinutes: limit, proposedMinutes: 30), isTrue);
    });
  });

  group('RealtimeDrift model', () {
    test('round-trip serialization', () {
      final drift = RealtimeDrift(
        packageName: 'com.test',
        date: '2026-02-07',
        baselineAvgMinutes: 45.0,
        todayMinutes: 70.0,
        driftScore: 0.56,
        isDrifted: true,
        explanation: 'Usage 56% above baseline',
      );

      final map = drift.toMap();
      final restored = RealtimeDrift.fromMap(map);

      expect(restored.packageName, equals(drift.packageName));
      expect(restored.driftScore, closeTo(drift.driftScore, 0.001));
      expect(restored.isDrifted, isTrue);
      expect(restored.explanation, equals(drift.explanation));
    });
  });
}

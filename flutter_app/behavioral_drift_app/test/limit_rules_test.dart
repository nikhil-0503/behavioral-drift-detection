import 'package:flutter_test/flutter_test.dart';
import 'package:behavioral_drift_app/models/limit_rules.dart';

void main() {
  group('LimitRules', () {
    group('canChangeLimit', () {
      test('allows reducing limit (30 -> 20)', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 30, proposedMinutes: 20),
          isTrue,
        );
      });

      test('allows reducing limit (60 -> 1)', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 60, proposedMinutes: 1),
          isTrue,
        );
      });

      test('rejects increasing limit (30 -> 40)', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 30, proposedMinutes: 40),
          isFalse,
        );
      });

      test('rejects same limit (30 -> 30)', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 30, proposedMinutes: 30),
          isFalse,
        );
      });

      test('rejects zero limit', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 30, proposedMinutes: 0),
          isFalse,
        );
      });

      test('rejects negative limit', () {
        expect(
          LimitRules.canChangeLimit(currentMinutes: 30, proposedMinutes: -5),
          isFalse,
        );
      });
    });

    group('validateLimitChange', () {
      test('returns new limit when valid reduction', () {
        expect(
          LimitRules.validateLimitChange(
              currentMinutes: 60, proposedMinutes: 30),
          equals(30),
        );
      });

      test('returns null when increase attempted', () {
        expect(
          LimitRules.validateLimitChange(
              currentMinutes: 30, proposedMinutes: 60),
          isNull,
        );
      });
    });

    group('shouldWarn', () {
      test('warns at 80% usage', () {
        // 30 min limit, 24 min used (80%)
        expect(LimitRules.shouldWarn(24 * 60, 30), isTrue);
      });

      test('warns at 90% usage', () {
        // 30 min limit, 27 min used (90%)
        expect(LimitRules.shouldWarn(27 * 60, 30), isTrue);
      });

      test('does not warn below 80%', () {
        // 30 min limit, 20 min used (67%)
        expect(LimitRules.shouldWarn(20 * 60, 30), isFalse);
      });

      test('does not warn at 100% (should block instead)', () {
        // 30 min limit, 30 min used (100%)
        expect(LimitRules.shouldWarn(30 * 60, 30), isFalse);
      });

      test('handles zero limit', () {
        expect(LimitRules.shouldWarn(100, 0), isFalse);
      });
    });

    group('shouldBlock', () {
      test('blocks at exactly limit', () {
        // 30 min limit, 30 min used
        expect(LimitRules.shouldBlock(30 * 60, 30), isTrue);
      });

      test('blocks when over limit', () {
        // 30 min limit, 35 min used
        expect(LimitRules.shouldBlock(35 * 60, 30), isTrue);
      });

      test('does not block below limit', () {
        // 30 min limit, 25 min used
        expect(LimitRules.shouldBlock(25 * 60, 30), isFalse);
      });

      test('handles zero limit', () {
        expect(LimitRules.shouldBlock(100, 0), isFalse);
      });
    });
  });
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../models/monitored_app.dart';
import '../models/app_usage_session.dart';
import '../models/realtime_drift.dart';

/// Single local database for all real-time monitoring data.
/// Tables:
///   monitored_apps  – append-only list of tracked apps
///   usage_sessions   – per-app usage sessions
///   realtime_drift   – daily drift snapshots
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;
  AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Database not available on web');
    }
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'behavioral_drift.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE monitored_apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL UNIQUE,
            app_name TEXT NOT NULL,
            daily_limit_minutes INTEGER NOT NULL,
            today_usage_seconds INTEGER NOT NULL DEFAULT 0,
            is_blocked INTEGER NOT NULL DEFAULT 0,
            added_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE usage_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE realtime_drift (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            date TEXT NOT NULL,
            baseline_avg_minutes REAL NOT NULL,
            today_minutes REAL NOT NULL,
            drift_score REAL NOT NULL,
            is_drifted INTEGER NOT NULL DEFAULT 0,
            explanation TEXT DEFAULT ''
          )
        ''');
      },
    );
  }

  // ──────────────── MONITORED APPS ────────────────

  /// Insert a new monitored app. Throws if already exists (append-only).
  Future<int> insertMonitoredApp(MonitoredApp app) async {
    if (kIsWeb) return 0; // Mock: return success on web
    final db = await database;
    return db.insert('monitored_apps', app.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// Returns all monitored apps. Never deletes.
  Future<List<MonitoredApp>> getMonitoredApps() async {
    if (kIsWeb) return []; // Mock: return empty list on web
    final db = await database;
    final rows = await db.query('monitored_apps', orderBy: 'added_at ASC');
    return rows.map((r) => MonitoredApp.fromMap(r)).toList();
  }

  /// Check if an app is already monitored.
  Future<bool> isAppMonitored(String packageName) async {
    if (kIsWeb) return false; // Mock: not monitored on web

    final db = await database;
    final rows = await db.query('monitored_apps',
        where: 'package_name = ?', whereArgs: [packageName]);
    return rows.isNotEmpty;
  }

  /// Update today's usage seconds for an app.
  Future<void> updateUsage(String packageName, int usageSeconds) async {
    if (kIsWeb) return; // Mock: no-op on web
    final db = await database;
    await db.update(
      'monitored_apps',
      {'today_usage_seconds': usageSeconds},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Reduce limit (enforced: newLimit must be < current).
  /// Returns true if update was applied.
  Future<bool> reduceLimit(String packageName, int newLimitMinutes) async {
    if (kIsWeb) return false; // Mock: reject on web
    final db = await database;
    final rows = await db.query('monitored_apps',
        where: 'package_name = ?', whereArgs: [packageName]);
    if (rows.isEmpty) return false;
    final current = MonitoredApp.fromMap(rows.first);
    if (newLimitMinutes >= current.dailyLimitMinutes || newLimitMinutes <= 0) {
      return false; // reject increase or zero
    }
    await db.update(
      'monitored_apps',
      {'daily_limit_minutes': newLimitMinutes},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return true;
  }

  /// Update limit to any value in [1, 30]. Returns true if applied.
  Future<bool> updateLimit(String packageName, int newLimitMinutes) async {
    if (kIsWeb) return false;
    if (newLimitMinutes <= 0 || newLimitMinutes > 30) return false;
    final db = await database;
    final rows = await db.query('monitored_apps',
        where: 'package_name = ?', whereArgs: [packageName]);
    if (rows.isEmpty) return false;
    await db.update(
      'monitored_apps',
      {'daily_limit_minutes': newLimitMinutes},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return true;
  }

  /// Update the display name for a monitored app.
  Future<void> updateAppName(String packageName, String newName) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'monitored_apps',
      {'app_name': newName},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Reset limit to default (30 min). Only allowed if current < defaultLimit.
  Future<bool> resetLimitToDefault(
      String packageName, int defaultLimit) async {
    if (kIsWeb) return false;
    final db = await database;
    final rows = await db.query('monitored_apps',
        where: 'package_name = ?', whereArgs: [packageName]);
    if (rows.isEmpty) return false;
    final current = MonitoredApp.fromMap(rows.first);
    // Only allow reset upward to default, never beyond
    if (current.dailyLimitMinutes >= defaultLimit) return false;
    await db.update(
      'monitored_apps',
      {'daily_limit_minutes': defaultLimit},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return true;
  }

  /// Mark app as blocked/unblocked.
  Future<void> setBlocked(String packageName, bool blocked) async {
    if (kIsWeb) return; // Mock: no-op on web
    final db = await database;
    await db.update(
      'monitored_apps',
      {'is_blocked': blocked ? 1 : 0},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Reset all daily usage counters (call at midnight).
  Future<void> resetDailyUsage() async {
    if (kIsWeb) return; // Mock: no-op on web
    final db = await database;
    await db.update('monitored_apps', {
      'today_usage_seconds': 0,
      'is_blocked': 0,
    });
  }

  // ──────────────── USAGE SESSIONS ────────────────

  /// Insert or update a daily usage session total for a package+date.
  /// This is the primary way live usage data populates the sessions table
  /// so that drift baseline computation works.
  Future<void> upsertDailySession(
      String packageName, String date, int totalSeconds) async {
    if (kIsWeb) return;
    final db = await database;
    // Check if a session for this date already exists
    final existing = await db.query('usage_sessions',
        where: 'package_name = ? AND date = ?',
        whereArgs: [packageName, date]);
    if (existing.isNotEmpty) {
      await db.update(
        'usage_sessions',
        {'duration_seconds': totalSeconds},
        where: 'package_name = ? AND date = ?',
        whereArgs: [packageName, date],
      );
    } else {
      final now = DateTime.now().toIso8601String();
      await db.insert('usage_sessions', {
        'package_name': packageName,
        'start_time': now,
        'end_time': now,
        'duration_seconds': totalSeconds,
        'date': date,
      });
    }
  }

  Future<int> insertSession(AppUsageSession session) async {
    if (kIsWeb) return 0; // Mock: return success on web
    final db = await database;
    return db.insert('usage_sessions', session.toMap());
  }

  Future<List<AppUsageSession>> getSessionsForDate(
      String packageName, String date) async {
    if (kIsWeb) return []; // Mock: return empty on web
    final db = await database;
    final rows = await db.query('usage_sessions',
        where: 'package_name = ? AND date = ?',
        whereArgs: [packageName, date]);
    return rows.map((r) => AppUsageSession.fromMap(r)).toList();
  }

  /// Total seconds used for a given app on a given date.
  Future<int> totalUsageSeconds(String packageName, String date) async {
    if (kIsWeb) return 0; // Mock: return 0 on web
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(duration_seconds), 0) as total '
      'FROM usage_sessions WHERE package_name = ? AND date = ?',
      [packageName, date],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Daily totals for last N days (for baseline computation).
  Future<Map<String, int>> dailyTotals(String packageName, int days) async {
    if (kIsWeb) return {}; // Mock: return empty map on web
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT date, SUM(duration_seconds) as total '
      'FROM usage_sessions '
      'WHERE package_name = ? AND date >= ? '
      'GROUP BY date ORDER BY date',
      [packageName, cutoff],
    );
    return {for (var r in rows) r['date'] as String: (r['total'] as int?) ?? 0};
  }

  // ──────────────── REALTIME DRIFT ────────────────

  Future<int> insertDrift(RealtimeDrift drift) async {
    if (kIsWeb) return 0; // Mock: return success on web
    final db = await database;
    return db.insert('realtime_drift', drift.toMap());
  }

  Future<List<RealtimeDrift>> getDriftHistory(String packageName,
      {int limit = 30}) async {
    if (kIsWeb) return []; // Mock: return empty on web
    final db = await database;
    final rows = await db.query('realtime_drift',
        where: 'package_name = ?',
        whereArgs: [packageName],
        orderBy: 'date DESC',
        limit: limit);
    return rows.map((r) => RealtimeDrift.fromMap(r)).toList();
  }

  Future<List<RealtimeDrift>> getAllDriftForDate(String date) async {
    if (kIsWeb) return []; // Mock: return empty on web
    final db = await database;
    final rows = await db.query('realtime_drift',
        where: 'date = ?', whereArgs: [date], orderBy: 'drift_score DESC');
    return rows.map((r) => RealtimeDrift.fromMap(r)).toList();
  }

  /// Aggregate per-day drift summaries for Stats/Logs on Android.
  Future<List<Map<String, dynamic>>> getDriftDaySummaries({int? limit}) async {
    if (kIsWeb) return [];
    final db = await database;
    final baseQuery =
        'SELECT date, AVG(drift_score) as avg_score, MAX(is_drifted) as is_drifted '
        'FROM realtime_drift GROUP BY date ORDER BY date DESC';
    final query = limit == null ? baseQuery : '$baseQuery LIMIT $limit';
    final rows = await db.rawQuery(query);
    return rows.reversed.toList();
  }
}

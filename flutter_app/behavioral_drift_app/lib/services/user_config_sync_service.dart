import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/app_database.dart';
import '../models/monitored_app.dart';

/// Syncs monitored apps and settings to Firebase Firestore so
/// user preferences survive logout, reinstall, and device changes.
class UserConfigSyncService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AppDatabase _db = AppDatabase();

  bool _syncing = false;
  bool get isSyncing => _syncing;

  DateTime? _lastSynced;
  DateTime? get lastSynced => _lastSynced;

  UserConfigSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Upload local monitored apps to Firestore.
  Future<void> uploadConfig() async {
    final doc = _userDoc;
    if (doc == null) return;
    if (kIsWeb) return; // DB not available on web

    _syncing = true;
    notifyListeners();

    try {
      final apps = await _db.getMonitoredApps();
      final appsData = apps.map((a) => {
        'packageName': a.packageName,
        'appName': a.appName,
        'dailyLimitMinutes': a.dailyLimitMinutes,
        'addedAt': a.addedAt.toIso8601String(),
      }).toList();

      await doc.set({
        'monitoredApps': appsData,
        'updatedAt': FieldValue.serverTimestamp(),
        'email': _auth.currentUser?.email,
        'displayName': _auth.currentUser?.displayName,
      }, SetOptions(merge: true));

      _lastSynced = DateTime.now();
    } catch (e) {
      debugPrint('Config upload failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Download monitored apps from Firestore and merge with local DB.
  /// Remote apps that don't exist locally are added; local apps are preserved.
  Future<int> downloadConfig() async {
    final doc = _userDoc;
    if (doc == null) return 0;
    if (kIsWeb) return 0;

    _syncing = true;
    notifyListeners();

    int added = 0;
    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return 0;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return 0;

      final remoteApps = (data['monitoredApps'] as List<dynamic>?) ?? [];
      for (final raw in remoteApps) {
        final map = Map<String, dynamic>.from(raw as Map);
        final pkg = map['packageName'] as String? ?? '';
        if (pkg.isEmpty) continue;

        final exists = await _db.isAppMonitored(pkg);
        if (!exists) {
          final app = MonitoredApp(
            packageName: pkg,
            appName: map['appName'] as String? ?? pkg.split('.').last,
            dailyLimitMinutes: (map['dailyLimitMinutes'] as num?)?.toInt() ?? 30,
            addedAt: map['addedAt'] != null
                ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
                : DateTime.now(),
          );
          await _db.insertMonitoredApp(app);
          added++;
        }
      }

      _lastSynced = DateTime.now();
    } catch (e) {
      debugPrint('Config download failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
    return added;
  }

  /// Bidirectional sync: download remote → merge → upload merged state.
  Future<void> syncBidirectional() async {
    await downloadConfig();
    await uploadConfig();
  }
}

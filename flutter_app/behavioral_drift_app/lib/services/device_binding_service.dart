import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Associates a device with a user account to prevent multi-device
/// or multi-account abuse. Stores a unique device fingerprint in
/// Firestore alongside the user profile.
class DeviceBindingService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _deviceIdKey = 'bound_device_id';

  String? _deviceId;
  String? get deviceId => _deviceId;

  bool _isBound = false;
  bool get isBound => _isBound;

  String? _boundDeviceId;
  String? get boundDeviceId => _boundDeviceId;

  DeviceBindingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Generate a stable device fingerprint using Android ID.
  Future<String> _getDeviceFingerprint() async {
    if (_deviceId != null) return _deviceId!;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await DeviceInfoPlugin().androidInfo;
      // Android ID is stable per-app per-device
      _deviceId = info.id; // hardware serial / build ID
      // Prefer fingerprint for more uniqueness
      final fp = info.fingerprint;
      if (fp.isNotEmpty) {
        _deviceId = fp;
      }
    } else {
      _deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Cache locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, _deviceId!);
    return _deviceId!;
  }

  /// Check whether this device is the one bound to the current user.
  /// Returns true if:
  ///   - No device is bound yet (first login)
  ///   - The bound device matches this device
  /// Returns false if a DIFFERENT device is already bound.
  Future<bool> verifyDeviceBinding() async {
    final uid = _uid;
    if (uid == null) return true; // not signed in, skip check

    try {
      final deviceFp = await _getDeviceFingerprint();
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data()?['deviceId'] == null) {
        // No binding yet → bind this device
        await _bindDevice(uid, deviceFp);
        _isBound = true;
        _boundDeviceId = deviceFp;
        notifyListeners();
        return true;
      }

      _boundDeviceId = doc.data()?['deviceId'] as String?;
      _isBound = _boundDeviceId == deviceFp;
      notifyListeners();
      return _isBound;
    } catch (e) {
      debugPrint('Device binding check failed: $e');
      return true; // fail-open on network errors to not block the user
    }
  }

  /// Bind this device to the user account in Firestore.
  Future<void> _bindDevice(String uid, String deviceFp) async {
    await _firestore.collection('users').doc(uid).set({
      'deviceId': deviceFp,
      'deviceBoundAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Force-rebind: when user legitimately changes devices (e.g., new phone).
  /// This should only be callable from a settings/admin flow.
  Future<void> rebindToCurrentDevice() async {
    final uid = _uid;
    if (uid == null) return;
    final fp = await _getDeviceFingerprint();
    await _bindDevice(uid, fp);
    _isBound = true;
    _boundDeviceId = fp;
    notifyListeners();
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Communicates with native Android to check and request special permissions:
///   - Usage Stats (PACKAGE_USAGE_STATS)
///   - Accessibility Service (for app blocking)
///   - Overlay (SYSTEM_ALERT_WINDOW)
///
/// On non-Android platforms all checks return false.
class PermissionService extends ChangeNotifier {
  static const _channel = MethodChannel('com.behavioral_drift/permissions');

  bool _usageStatsGranted = false;
  bool _accessibilityGranted = false;
  bool _overlayGranted = false;

  bool get usageStatsGranted => _usageStatsGranted;
  bool get accessibilityGranted => _accessibilityGranted;
  bool get overlayGranted => _overlayGranted;
  bool get allGranted =>
      _usageStatsGranted && _accessibilityGranted && _overlayGranted;

  /// Refresh permission status from native side.
  Future<void> checkAll() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final result =
          await _channel.invokeMapMethod<String, bool>('checkPermissions');
      if (result != null) {
        _usageStatsGranted = result['usageStats'] ?? false;
        _accessibilityGranted = result['accessibility'] ?? false;
        _overlayGranted = result['overlay'] ?? false;
        notifyListeners();
      }
    } on PlatformException catch (e) {
      debugPrint('Permission check error: $e');
    }
  }

  Future<void> requestUsageStats() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('requestUsageStats');
    } on PlatformException catch (e) {
      debugPrint('requestUsageStats error: $e');
    }
  }

  Future<void> requestAccessibility() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('requestAccessibility');
    } on PlatformException catch (e) {
      debugPrint('requestAccessibility error: $e');
    }
  }

  Future<void> requestOverlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('requestOverlay');
    } on PlatformException catch (e) {
      debugPrint('requestOverlay error: $e');
    }
  }
}

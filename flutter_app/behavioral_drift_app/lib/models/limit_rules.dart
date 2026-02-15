/// Business-rule helper for app limit enforcement.
/// Key invariants:
///   - absolute max limit = 30 minutes (default)
///   - timer can be set to any value between 1 and 30 minutes
///   - user may reset to the DEFAULT (30 min)
///   - once an app is added it cannot be removed
class LimitRules {
  /// The absolute maximum timer a user can ever set.
  static const int maxLimitMinutes = 30;

  /// The default timer value for new apps.
  static const int defaultLimitMinutes = 30;

  /// Clamp a proposed initial limit to the allowed range [1, maxLimitMinutes].
  static int clampInitialLimit(int proposedMinutes) {
    return proposedMinutes.clamp(1, maxLimitMinutes);
  }

  /// Validates whether a proposed new limit is legal.
  /// Allows any value in [1, maxLimitMinutes].
  static bool canChangeLimit({
    required int currentMinutes,
    required int proposedMinutes,
  }) {
    if (proposedMinutes <= 0) return false; // must be positive
    if (proposedMinutes > maxLimitMinutes) return false; // absolute cap
    return proposedMinutes != currentMinutes; // allow any change within range
  }

  /// Whether the user can reset the limit to the default (30 min).
  /// Only allowed if the current limit is already below the default.
  static bool canResetToDefault(int currentMinutes) {
    return currentMinutes < defaultLimitMinutes;
  }

  /// Returns the valid new limit, or `null` if the change is rejected.
  static int? validateLimitChange({
    required int currentMinutes,
    required int proposedMinutes,
  }) {
    final clamped = proposedMinutes.clamp(1, maxLimitMinutes);
    if (clamped != currentMinutes) return clamped;
    return null;
  }

  /// Whether the app should trigger a warning (at 80 % usage).
  static bool shouldWarn(int usedSeconds, int limitMinutes) {
    if (limitMinutes <= 0) return false;
    return (usedSeconds / 60) >= (limitMinutes * 0.8) &&
        (usedSeconds / 60) < limitMinutes;
  }

  /// Whether the app must be blocked (limit exceeded).
  static bool shouldBlock(int usedSeconds, int limitMinutes) {
    if (limitMinutes <= 0) return false;
    return (usedSeconds / 60) >= limitMinutes;
  }
}

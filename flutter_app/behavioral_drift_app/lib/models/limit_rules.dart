/// Business-rule helper for app limit enforcement.
/// Key invariants:
///   - limit can only be REDUCED, never increased
///   - once an app is added it cannot be removed
class LimitRules {
  /// Validates whether a proposed new limit is legal given the current limit.
  /// Returns `true` only when [proposedMinutes] < [currentMinutes].
  static bool canChangeLimit({
    required int currentMinutes,
    required int proposedMinutes,
  }) {
    if (proposedMinutes <= 0) return false; // must be positive
    return proposedMinutes < currentMinutes;
  }

  /// Returns the valid new limit, or `null` if the change is rejected.
  static int? validateLimitChange({
    required int currentMinutes,
    required int proposedMinutes,
  }) {
    if (canChangeLimit(
        currentMinutes: currentMinutes, proposedMinutes: proposedMinutes)) {
      return proposedMinutes;
    }
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

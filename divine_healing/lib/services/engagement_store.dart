import 'package:shared_preferences/shared_preferences.dart';

/// How many times this install has been cold-started, and whether the person
/// has finished a free session yet.
///
/// The full-screen paywall used to open on the first launch, before anyone
/// had heard a session. It now waits for a later launch, or for the first
/// free session to finish. Both counts survive process death; a failed read
/// leaves the launch count at 1 so the paywall stays out of the way.
class EngagementStore {
  EngagementStore._();

  static const _launchesKey = 'dh_cold_starts';
  static const _completionsKey = 'dh_free_completions';

  /// 1 until [recordColdStart] says otherwise, so a caller that races the
  /// write does not treat a brand-new install as a returning one.
  static int coldStarts = 1;

  static Future<void> recordColdStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_launchesKey) ?? 0) + 1;
      await prefs.setInt(_launchesKey, next);
      coldStarts = next;
    } catch (_) {
      coldStarts = 1;
    }
  }

  /// True only the first time a free session is finished on this install.
  static Future<bool> noteFreeCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_completionsKey) ?? 0) + 1;
      await prefs.setInt(_completionsKey, next);
      return next == 1;
    } catch (_) {
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Holds the screen awake while the tuner is listening.
///
/// Wraps `wakelock_plus`, which maps to `FLAG_KEEP_SCREEN_ON` on Android and
/// `isIdleTimerDisabled` on iOS. Both are scoped to the foreground window by
/// the OS: backgrounding the app suspends the effect and resuming restores it,
/// so no app-lifecycle handling is needed here.
///
/// Never throws: the wakelock is best-effort, and callers treat it that way —
/// some (provider teardown) have nowhere to catch. Platform failures are
/// logged and ignored.
class ScreenWakeService {
  Future<void> enable() => _toggle(true);

  Future<void> disable() => _toggle(false);

  Future<void> _toggle(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      debugPrint('ScreenWakeService: failed to set wakelock to $on: $e');
    }
  }
}

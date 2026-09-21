import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/services/screen_wake_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _RecordingWakelockPlatform extends WakelockPlusPlatformInterface {
  final toggles = <bool>[];

  @override
  Future<void> toggle({required bool enable}) async => toggles.add(enable);

  @override
  Future<bool> get enabled async => toggles.isNotEmpty && toggles.last;
}

class _ThrowingWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async =>
      throw Exception('device refused the wakelock');

  @override
  Future<bool> get enabled async => throw Exception('device refused the wakelock');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A device whose OS refuses the wakelock throws at the platform boundary.
  // The service must never let that escape: callers do not await it, so an
  // escaping error becomes an unhandled async error — and from provider
  // teardown, nothing can catch it at all.
  group('ScreenWakeService — platform failure is swallowed', () {
    final original = wakelockPlusPlatformInstance;

    setUp(() => wakelockPlusPlatformInstance = _ThrowingWakelockPlatform());
    tearDown(() => wakelockPlusPlatformInstance = original);

    test('enable() completes instead of throwing', () async {
      await expectLater(ScreenWakeService().enable(), completes);
    });

    test('disable() completes instead of throwing', () async {
      await expectLater(ScreenWakeService().disable(), completes);
    });

    test('disable() before any enable() still completes', () async {
      // stopListening() runs on every mic stop and on the mic error path, so
      // disable() is routinely called when no wakelock is held.
      final s = ScreenWakeService();
      await expectLater(s.disable(), completes);
      await expectLater(s.enable(), completes);
      await expectLater(s.disable(), completes);
    });
  });

  // Polarity is the one thing the notifier-level tests cannot prove: they use a
  // fake that overrides enable/disable wholesale, so swapping the two booleans
  // here would invert the feature with every other test still green.
  group('ScreenWakeService — wakelock polarity', () {
    final original = wakelockPlusPlatformInstance;
    late _RecordingWakelockPlatform platform;

    setUp(() {
      platform = _RecordingWakelockPlatform();
      wakelockPlusPlatformInstance = platform;
    });
    tearDown(() => wakelockPlusPlatformInstance = original);

    test('enable() turns the wakelock on', () async {
      await ScreenWakeService().enable();
      expect(platform.toggles, [true]);
    });

    test('disable() turns the wakelock off', () async {
      await ScreenWakeService().disable();
      expect(platform.toggles, [false]);
    });
  });
}

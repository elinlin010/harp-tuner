import 'package:harp_tuner/services/screen_wake_service.dart';

/// Stands in for the real wakelock so tests never reach the platform channel,
/// which always fails under `flutter test` and logs every failure.
///
/// Tests that assert wake behaviour read the counters; tests that just need the
/// plugin out of the way ignore them.
class FakeScreenWake extends ScreenWakeService {
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async => enableCount++;

  @override
  Future<void> disable() async => disableCount++;
}

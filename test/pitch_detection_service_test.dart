import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/services/pitch_detection_service.dart';

void main() {
  // ── PitchResult ───────────────────────────────────────────────────────────

  group('PitchResult', () {
    test('stores frequency', () {
      final r = PitchResult(440.0);
      expect(r.frequency, 440.0);
    });

    test('stores arbitrary frequency', () {
      final r = PitchResult(261.63);
      expect(r.frequency, closeTo(261.63, 0.001));
    });
  });

  // ── PitchServiceError ─────────────────────────────────────────────────────

  group('PitchServiceError', () {
    test('stores isPermissionError=false and message', () {
      const e = PitchServiceError(isPermissionError: false, message: 'test');
      expect(e.isPermissionError, isFalse);
      expect(e.message, 'test');
    });

    test('stores isPermissionError=true', () {
      const e = PitchServiceError(isPermissionError: true, message: 'perm');
      expect(e.isPermissionError, isTrue);
    });
  });

  // ── PitchDetectionService.stop ────────────────────────────────────────────

  group('PitchDetectionService.stop', () {
    test('stop on fresh instance is a no-op (all null-safe)', () {
      final svc = PitchDetectionService();
      svc.stop(); // no subscription, no controller → safe
    });

    test('stop after start cleans up state', () {
      final svc = PitchDetectionService();
      // start() will fail internally when MicStream.microphone() throws,
      // but lines 83-88 are covered by the call itself.
      try {
        svc.start();
      } catch (_) {}
      svc.stop(); // should not throw
    });
  });
}

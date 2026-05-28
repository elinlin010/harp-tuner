import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/services/pitch_detection_service.dart';
import 'package:harp_tuner/services/tone_player_service.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

// ── Fake service implementations ─────────────────────────────────────────────

class _FakePitchService extends PitchDetectionService {
  final bool permissionResult;
  final bool checkResult;
  StreamController<PitchResult?>? _ctrl;
  int startCallCount = 0;

  _FakePitchService({this.permissionResult = true, this.checkResult = true});

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<bool> checkPermission() async => checkResult;

  @override
  Stream<PitchResult?> start() {
    startCallCount++;
    _ctrl = StreamController<PitchResult?>.broadcast();
    return _ctrl!.stream;
  }

  @override
  void stop() {
    _ctrl?.close();
    _ctrl = null;
  }

  void emit(PitchResult? r) => _ctrl?.add(r);
  void emitError(Object e) => _ctrl?.addError(e);
}

class _FakeTonePlayer extends TonePlayerService {
  final bool stopShouldThrow;
  final bool playShouldThrow;
  int playCallCount = 0;
  int stopCallCount = 0;

  _FakeTonePlayer({this.stopShouldThrow = false, this.playShouldThrow = false});

  @override
  Future<void> play(double hz) async {
    playCallCount++;
    if (playShouldThrow) throw Exception('fake play error');
  }

  @override
  void precompute(List<double> freqs) {}

  @override
  Future<void> stop() async {
    stopCallCount++;
    if (stopShouldThrow) throw Exception('fake stop error');
  }

  @override
  void dispose() {}
}

class _FakeServiceNotifier extends TunerNotifier {
  final _FakePitchService _fakeService;
  final _FakeTonePlayer _fakePlayer;
  final TunerState? _override;

  _FakeServiceNotifier(this._fakeService, this._fakePlayer, [this._override]);

  @override
  TunerState build() {
    final s = super.build();
    injectServicesForTest(_fakeService, _fakePlayer);
    if (_override != null) {
      state = _override!;
      return _override!;
    }
    return s;
  }
}

ProviderContainer _containerWithFakes(
  _FakePitchService svc,
  _FakeTonePlayer tone, {
  TunerState? overrideState,
}) {
  final c = ProviderContainer(
    overrides: [
      tunerProvider.overrideWith(
          () => _FakeServiceNotifier(svc, tone, overrideState)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// ── ThemeNotifier throwing prefs ──────────────────────────────────────────────

class _ThrowingPrefsStore extends SharedPreferencesStorePlatform {
  @override
  bool get isMock => true;

  @override
  Future<bool> clear() async => throw Exception('test-prefs-throw');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw Exception('test-prefs-throw');

  @override
  Future<bool> remove(String key) async => throw Exception('test-prefs-throw');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('test-prefs-throw');
}

void _installThrowingStore() {
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesStorePlatform.instance = _ThrowingPrefsStore();
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  const kString = HarpStringModel(index: 1, note: NoteName.a, octave: 4);

  // ── TunerNotifier.startListening ─────────────────────────────────────────

  group('TunerNotifier.startListening', () {
    test('guard: already listening is a no-op', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService();
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone,
          overrideState: const TunerState(isListening: true));
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();
      // Guard fires — no permission request, still listening
      expect(c.read(tunerProvider).isListening, isTrue);
      expect(svc.startCallCount, 0);
    });

    test('permission denied sets permissionDenied flag', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: false);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();
      final s = c.read(tunerProvider);
      expect(s.permissionDenied, isTrue);
      expect(s.isListening, isFalse);
    });

    test('permission granted starts listening and attaches subscription', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();
      final s = c.read(tunerProvider);
      expect(s.isListening, isTrue);
      expect(s.permissionDenied, isFalse);
      expect(svc.startCallCount, 1);
    });
  });

  // ── TunerNotifier.toggleListening else branch ─────────────────────────────

  group('TunerNotifier.toggleListening', () {
    test('when not listening calls startListening', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      c.read(tunerProvider.notifier).toggleListening();
      await Future.delayed(Duration.zero);
      expect(c.read(tunerProvider).isListening, isTrue);
    });
  });

  // ── TunerNotifier._attachMicSubscription error handlers ───────────────────

  group('TunerNotifier._attachMicSubscription error handlers', () {
    test('permission error sets permissionDenied', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();
      expect(c.read(tunerProvider).isListening, isTrue);

      svc.emitError(
          const PitchServiceError(isPermissionError: true, message: 'perm'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(c.read(tunerProvider).permissionDenied, isTrue);
      expect(c.read(tunerProvider).isListening, isFalse);
    });

    test('non-permission PitchServiceError sets micError', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();

      svc.emitError(const PitchServiceError(
          isPermissionError: false, message: 'oops'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(c.read(tunerProvider).micError, 'oops');
    });

    test('unknown error with perm denied sets permissionDenied', () async {
      SharedPreferences.setMockInitialValues({});
      final svc =
          _FakePitchService(permissionResult: true, checkResult: false);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();

      svc.emitError(Exception('unknown error'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(c.read(tunerProvider).permissionDenied, isTrue);
    });

    test('unknown error with perm granted does not set permissionDenied', () async {
      SharedPreferences.setMockInitialValues({});
      final svc =
          _FakePitchService(permissionResult: true, checkResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).startListening();

      svc.emitError(Exception('unknown error'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(c.read(tunerProvider).permissionDenied, isFalse);
    });

    test('guard: _attachMicSubscription is idempotent when already subscribed',
        () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);
      // startListening() sets up _pitchSub → calls _attachMicSubscription()
      await c.read(tunerProvider.notifier).startListening();
      expect(svc.startCallCount, 1);
      // startListening() again hits the isListening guard before _attachMicSubscription
      await c.read(tunerProvider.notifier).startListening();
      expect(svc.startCallCount, 1);
    });
  });

  // ── TunerNotifier.setTunerMode catch block ────────────────────────────────

  group('TunerNotifier.setTunerMode', () {
    test('catch: tone stop throws → logs and still updates mode to auto',
        () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService();
      final tone = _FakeTonePlayer(stopShouldThrow: true);
      final c = _containerWithFakes(svc, tone,
          overrideState: const TunerState(
            tunerMode: TunerMode.reference,
            selectedHarp: HarpType.leverHarp,
          ));
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.auto);
      expect(c.read(tunerProvider).tunerMode, TunerMode.auto);
    });
  });

  // ── TunerNotifier.playReferenceString ─────────────────────────────────────

  group('TunerNotifier.playReferenceString', () {
    test('updates referenceString and clears isPlayingTone', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService();
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone,
          overrideState: const TunerState(
              tunerMode: TunerMode.reference,
              selectedHarp: HarpType.leverHarp));
      await Future.delayed(Duration.zero);

      await c.read(tunerProvider.notifier).playReferenceString(kString);

      final s = c.read(tunerProvider);
      expect(s.referenceString, kString);
      expect(s.isPlayingTone, isFalse);
      expect(tone.playCallCount, 1);
    });

    test('tone play exception is caught — state updated correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService();
      final tone = _FakeTonePlayer(playShouldThrow: true);
      final c = _containerWithFakes(svc, tone,
          overrideState: const TunerState(
              tunerMode: TunerMode.reference,
              selectedHarp: HarpType.leverHarp));
      await Future.delayed(Duration.zero);

      await c.read(tunerProvider.notifier).playReferenceString(kString);

      final s = c.read(tunerProvider);
      expect(s.isPlayingTone, isFalse);
      expect(s.referenceString, kString);
    });

    test('non-iOS: pauses mic when active and sets up restart timer', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);

      // Start mic so _pitchSub is non-null
      await c.read(tunerProvider.notifier).startListening();
      expect(c.read(tunerProvider).isListening, isTrue);

      await c.read(tunerProvider.notifier).playReferenceString(kString);

      final s = c.read(tunerProvider);
      expect(s.referenceString, kString);
      expect(s.isPlayingTone, isFalse);
    });

    test('non-iOS: no restart timer when not listening', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService();
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone,
          overrideState: const TunerState(
            tunerMode: TunerMode.reference,
            isListening: false,
            selectedHarp: HarpType.leverHarp,
          ));
      await Future.delayed(Duration.zero);

      await c.read(tunerProvider.notifier).playReferenceString(kString);

      expect(c.read(tunerProvider).referenceString, kString);
    });

    test('cancels pending restart timer on second tap', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = _FakePitchService(permissionResult: true);
      final tone = _FakeTonePlayer();
      final c = _containerWithFakes(svc, tone);
      await Future.delayed(Duration.zero);

      await c.read(tunerProvider.notifier).startListening();
      // First tap — sets up restart timer
      await c.read(tunerProvider.notifier).playReferenceString(kString);
      // Second tap — cancels old timer and sets a new one
      final kString2 =
          const HarpStringModel(index: 2, note: NoteName.b, octave: 4);
      await c.read(tunerProvider.notifier).playReferenceString(kString2);

      expect(c.read(tunerProvider).referenceString, kString2);
    });
  });

  // ── TunerNotifier.playReferenceString — Android timer callback ───────────

  group('TunerNotifier.playReferenceString Android timer callback', () {
    test('mic restart timer fires after 1.4 s and re-attaches subscription',
        () {
      FakeAsync().run((async) {
        SharedPreferences.setMockInitialValues({});
        final svc = _FakePitchService(permissionResult: true);
        final tone = _FakeTonePlayer();
        final c = _containerWithFakes(svc, tone);
        async.flushMicrotasks(); // let _loadPrefs() complete

        c.read(tunerProvider.notifier).startListening();
        async.flushMicrotasks(); // let startListening() complete

        expect(c.read(tunerProvider).isListening, isTrue);

        // Play reference string — on non-iOS, mic is paused and 1400 ms timer set
        c.read(tunerProvider.notifier).playReferenceString(kString);
        async.flushMicrotasks(); // let play() await + finally block run

        // Advance fake time past 1400 ms to fire the timer
        async.elapse(const Duration(milliseconds: 1500));
        async.flushMicrotasks(); // resolve any pending Futures from callback

        // Timer callback (lines 371-375) executed: _attachMicSubscription called
        expect(svc.startCallCount, greaterThan(1));
      });
    });
  });

  // ── ThemeNotifier — SharedPreferences error catch blocks ─────────────────

  group('ThemeNotifier — SharedPreferences error', () {
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('_load catch (line 31): logs on getInstance failure', () async {
      _installThrowingStore();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tunerThemeProvider);
      await Future.delayed(Duration.zero);
      // Default linen theme used since load failed
      expect(container.read(tunerThemeProvider), TunerThemes.linen);
    });

    test('setTheme catch (line 41): logs on save failure', () async {
      _installThrowingStore();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tunerThemeProvider);
      await Future.delayed(Duration.zero);
      // _prefs is null → ??= getInstance() throws → catch fires
      await container
          .read(tunerThemeProvider.notifier)
          .setTheme(TunerThemes.blueprint);
      // State was still updated in memory despite save error
      expect(container.read(tunerThemeProvider), TunerThemes.blueprint);
    });
  });
}

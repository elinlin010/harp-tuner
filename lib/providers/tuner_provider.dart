import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/harp_presets.dart';
import '../models/harp_string_model.dart';
import '../models/harp_type.dart';
import '../services/pitch_detection_service.dart';
import '../services/tone_player_service.dart';
import '../utils/music_utils.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TunerMode { auto, reference }

/// Selects which platform-specific pitch corrector runs. iOS and Android ship
/// separate, independently-tuned detection algorithms (frozen to their
/// respective store versions) so tuning one platform can't regress the other.
enum DetectionAlgo { ios, android }

// ── Tuner state ───────────────────────────────────────────────────────────────

class TunerState {
  final bool isListening;
  final bool permissionDenied;
  final bool preferFlats;
  final bool showOctave;
  final int a4Hz;
  final int leverStringCount;
  final HarpType? selectedHarp;
  final TunerMode tunerMode;
  final HarpStringModel? referenceString;
  final bool isPlayingTone;
  final double? cents;
  final double? detectedHz;
  final String? closestNoteName;
  final String? micError;
  final bool isStale;
  final bool showTuningReminder;

  const TunerState({
    this.isListening = false,
    this.permissionDenied = false,
    this.preferFlats = false,
    this.showOctave = false,
    this.a4Hz = 440,
    this.leverStringCount = 34,
    this.selectedHarp,
    this.tunerMode = TunerMode.auto,
    this.referenceString,
    this.isPlayingTone = false,
    this.cents,
    this.detectedHz,
    this.closestNoteName,
    this.micError,
    this.isStale = false,
    this.showTuningReminder = true,
  });

  TunerState copyWith({
    bool? isListening,
    bool? permissionDenied,
    bool? preferFlats,
    bool? showOctave,
    int? a4Hz,
    int? leverStringCount,
    HarpType? selectedHarp,
    bool clearSelectedHarp = false,
    TunerMode? tunerMode,
    HarpStringModel? referenceString,
    bool clearReferenceString = false,
    bool? isPlayingTone,
    bool? showTuningReminder,
    double? cents,
    double? detectedHz,
    String? closestNoteName,
    String? micError,
    bool? isStale,
    bool clearPitch = false,
    bool clearMicError = false,
  }) {
    return TunerState(
      isListening: isListening ?? this.isListening,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      preferFlats: preferFlats ?? this.preferFlats,
      showOctave: showOctave ?? this.showOctave,
      a4Hz: a4Hz ?? this.a4Hz,
      leverStringCount: leverStringCount ?? this.leverStringCount,
      selectedHarp: clearSelectedHarp ? null : (selectedHarp ?? this.selectedHarp),
      tunerMode: tunerMode ?? this.tunerMode,
      referenceString: clearReferenceString ? null : (referenceString ?? this.referenceString),
      isPlayingTone: isPlayingTone ?? this.isPlayingTone,
      showTuningReminder: showTuningReminder ?? this.showTuningReminder,
      cents: clearPitch ? null : (cents ?? this.cents),
      detectedHz: clearPitch ? null : (detectedHz ?? this.detectedHz),
      closestNoteName:
          clearPitch ? null : (closestNoteName ?? this.closestNoteName),
      micError:
          (clearPitch || clearMicError) ? null : (micError ?? this.micError),
      isStale: clearPitch ? false : (isStale ?? this.isStale),
    );
  }
}

// ── Tuner notifier ────────────────────────────────────────────────────────────

class TunerNotifier extends Notifier<TunerState> {
  PitchDetectionService _service    = PitchDetectionService();
  TonePlayerService     _tonePlayer = TonePlayerService();
  StreamSubscription<PitchResult?>? _pitchSub;

  @visibleForTesting
  void injectServicesForTest(PitchDetectionService s, TonePlayerService t) {
    _service = s;
    _tonePlayer = t;
  }
  SharedPreferences? _prefs;

  static const _historyLen      = 8;
  static const _stableNeeded    = 3;   // 3 stable frames to confirm a note
  static const _stableCents     = 25.0;
  // Challenge frames before switching note — differs by platform (see
  // _detectionAlgo). iOS uses the App Store v1.1.10 corrector (3); Android uses
  // the Play Store v1.1.11 corrector (2, tuned for slow-device note-skip).
  static const _challengeNeededIos     = 3;
  static const _challengeNeededAndroid = 2;
  static const _kStaleFrames    = 15;  // ~1.4s silence → dim display
  static const _kHoldFrames     = 22;  // ~2.0s silence → clear display

  static const _kA4HzKey              = 'tuner_a4_hz';
  static const _kPreferFlatsKey       = 'tuner_prefer_flats';
  static const _kShowOctaveKey        = 'tuner_show_octave';
  static const _kHarpTypeKey          = 'tuner_harp_type';
  static const _kLeverStringCountKey  = 'tuner_lever_string_count';
  static const _kShowTuningReminderKey = 'tuner_show_tuning_reminder';
  static const _kA4HzMin = 430;
  static const _kA4HzMax = 450;
  static const _kLeverStringMin = 19;
  static const _kLeverStringMax = 40;

  final _freqHistory = <double>[];
  int _silenceCount = 0;
  String? _confirmedNote;
  String? _challengeNote;
  int _challengeCount = 0;

  // Which platform's detection corrector to run. iOS and Android ship different,
  // independently-tuned pitch correctors (the algorithms diverged when Android's
  // slow-device fixes degraded iOS, so they are now kept separate — see
  // _onPitchResultIos / _onPitchResultAndroid). Defaults from the host platform;
  // dart:io Platform is neither iOS nor Android under `flutter test`, so it
  // falls back to the Android corrector there and tests override per-case.
  DetectionAlgo _detectionAlgo =
      Platform.isIOS ? DetectionAlgo.ios : DetectionAlgo.android;

  @visibleForTesting
  void setDetectionAlgoForTest(DetectionAlgo algo) => _detectionAlgo = algo;

  // On Android, AudioRecord and AudioTrack/MediaPlayer conflict for audio
  // routing: while the mic is active, speaker output is routed to the earpiece.
  // We pause the mic during reference tone playback and restart it after.
  Timer? _micRestartTimer;

  // Mic suppression: ignore pitch results briefly after restarting the mic so
  // the speaker bleed doesn't confuse the pitch detector.
  DateTime? _suppressUntil;

  bool _disposed = false;

  @override
  TunerState build() {
    ref.onDispose(() {
      _disposed = true;
      _micRestartTimer?.cancel();
      _pitchSub?.cancel();
      _service.dispose();
      _tonePlayer.dispose();
    });
    _loadPrefs();
    return const TunerState();
  }

  /// Spawn the pitch-detection isolate ahead of the first [startListening] so
  /// tapping the mic button detects the first note without the ~260 ms cold
  /// spawn. Call when the tuner screen mounts. No-op if already warm.
  void prewarmDetector() => _service.prewarm();

  Future<void> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedA4             = _prefs!.getInt(_kA4HzKey);
      final savedFlats          = _prefs!.getBool(_kPreferFlatsKey);
      final savedOctave         = _prefs!.getBool(_kShowOctaveKey);
      final savedHarpType       = _prefs!.getString(_kHarpTypeKey);
      final savedLeverCount     = _prefs!.getInt(_kLeverStringCountKey);
      final savedShowReminder   = _prefs!.getBool(_kShowTuningReminderKey);

      HarpType? harpType = HarpType.leverHarp; // default on first launch
      if (savedHarpType != null) {
        try {
          harpType = HarpType.values.firstWhere((e) => e.name == savedHarpType);
        } catch (_) {}
      }

      state = state.copyWith(
        a4Hz: savedA4 != null ? savedA4.clamp(_kA4HzMin, _kA4HzMax) : state.a4Hz,
        preferFlats: savedFlats ?? state.preferFlats,
        showOctave: savedOctave ?? state.showOctave,
        selectedHarp: harpType,
        showTuningReminder: savedShowReminder ?? state.showTuningReminder,
        leverStringCount: savedLeverCount != null
            ? savedLeverCount.clamp(_kLeverStringMin, _kLeverStringMax)
            : state.leverStringCount,
      );
    } catch (e) {
      debugPrint('TunerNotifier: failed to load prefs: $e');
    }
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (state.isListening) return;

    final granted = await _service.requestPermission();
    if (!granted) {
      state = state.copyWith(permissionDenied: true);
      return;
    }

    state = state.copyWith(
      isListening: true,
      permissionDenied: false,
      clearPitch: true,
    );

    _attachMicSubscription();
  }

  void _attachMicSubscription() {
    if (_pitchSub != null) return; // already subscribed — don't create a second one
    _pitchSub = _service.start().listen(
      _onPitchResult,
      onError: (e) async {
        stopListening();
        if (e is PitchServiceError && e.isPermissionError) {
          state = state.copyWith(permissionDenied: true);
        } else if (e is PitchServiceError) {
          state = state.copyWith(micError: e.message);
        } else {
          final granted = await _service.checkPermission();
          if (!granted) {
            state = state.copyWith(permissionDenied: true);
          }
        }
      },
      cancelOnError: false,
    );
  }

  void stopListening() {
    _micRestartTimer?.cancel();
    _micRestartTimer = null;
    // On iOS, the restart timer's target is _tonePlayer.stop(); cancel the
    // timer above means the tone must be stopped explicitly here too.
    if (Platform.isIOS) _tonePlayer.stop();
    _pitchSub?.cancel();
    _pitchSub = null;
    _service.stop();
    _freqHistory.clear();
    _silenceCount = 0;
    _confirmedNote = null;
    _challengeNote = null;
    _challengeCount = 0;
    state = state.copyWith(isListening: false, clearPitch: true);
  }

  void toggleListening() {
    if (state.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void clearMicError() {
    state = state.copyWith(clearMicError: true);
  }

  // ── Tone precomputation ────────────────────────────────────────────────────

  void _precomputeHarpTones(HarpType harp) {
    final strings = HarpPresets.stringsFor(harp);
    final freqs = strings.map((s) => s.frequencyAt(state.a4Hz.toDouble())).toList();
    _tonePlayer.precompute(freqs);
  }

  // ── Mode switching ─────────────────────────────────────────────────────────

  Future<void> setTunerMode(TunerMode mode) async {
    if (mode == state.tunerMode) return;
    if (mode == TunerMode.auto) {
      // Leaving reference mode: stop any playing tone and wipe reference state.
      // Also clear _suppressUntil so auto-mode detection isn't silently deaf
      // if the user switches mid-suppression (e.g. during iOS tone playback).
      _suppressUntil = null;
      try {
        await _tonePlayer.stop();
      } catch (e) {
        debugPrint('TunerNotifier: failed to stop tone on mode switch: $e');
      }
      state = state.copyWith(
        tunerMode: TunerMode.auto,
        clearReferenceString: true,
        isPlayingTone: false,
        clearPitch: true,
      );
    } else {
      state = state.copyWith(
        tunerMode: TunerMode.reference,
        clearPitch: true,
      );
      // Kick off background synthesis for all strings so taps are instant.
      if (state.selectedHarp != null) _precomputeHarpTones(state.selectedHarp!);
    }
  }

  // ── Reference tone playback ────────────────────────────────────────────────

  /// Tap a string in reference mode: play its tone and pin it as the tuning
  /// target.
  ///
  /// On Android, AudioRecord and MediaPlayer conflict for audio routing while
  /// both are active simultaneously — output ends up on the earpiece instead
  /// of the speaker. To work around this we pause the mic for the duration of
  /// the tone (2 s) and restart it automatically afterward.
  Future<void> playReferenceString(HarpStringModel string) async {
    // Cancel any pending mic-restart from a previous tap.
    _micRestartTimer?.cancel();
    _micRestartTimer = null;

    state = state.copyWith(
      referenceString: string,
      isPlayingTone: true,
      clearPitch: true,
    );

    // Reset detection history so the next note gets a clean reading.
    _freqHistory.clear();
    _silenceCount = 0;
    _confirmedNote = null;
    _challengeNote = null;
    _challengeCount = 0;

    final hz = string.frequencyAt(state.a4Hz.toDouble());

    if (Platform.isIOS) {
      // iOS: AVAudioSession handles mic + speaker concurrently — no routing
      // conflict. Keep the mic running. Suppress BEFORE play starts so YIN
      // ignores the reference tone during and immediately after playback.
      //
      // The synthesised tone is 2 s long. For bass notes (F♭3 and below) the
      // slow-decay envelope is still ~12% amplitude at 1.5 s — loud enough for
      // YIN to lock onto the tone itself. We stop the tone at 1.1 s (user has
      // heard enough to identify the pitch) and let the remaining 0.4 s of
      // suppression clear room acoustics before detection resumes.
      _suppressUntil = DateTime.now().add(const Duration(milliseconds: 1500));
      _micRestartTimer = Timer(const Duration(milliseconds: 1100), () {
        _micRestartTimer = null;
        if (_disposed) return;
        _tonePlayer.stop();
      });
    } else {
      // Android: AudioRecord + MediaPlayer active simultaneously reroutes
      // speaker output to the earpiece. Pause the mic BEFORE play starts to
      // force speaker routing.
      final wasMicActive = _pitchSub != null;
      if (wasMicActive) {
        _pitchSub!.cancel();
        _pitchSub = null;
        _service.stop();
      }
    }

    try {
      await _tonePlayer.play(hz);
    } catch (e) {
      debugPrint('TunerNotifier: failed to play reference tone: $e');
    } finally {
      if (!_disposed) state = state.copyWith(isPlayingTone: false);
    }

    // Android post-play: stop tone explicitly then restart mic with brief
    // suppression to let room echo decay.
    //
    // 300 ms suppression: for bass notes the room echo of a 12%-amplitude
    // tone needs ~300 ms to fall below YIN's detection floor.
    //
    // Use state.isListening (intent) not wasMicActive (actual) — on rapid
    // double-tap the second call sees _pitchSub == null (already stopped by
    // the first tap), so wasMicActive would be false and no restart fires.
    if (!Platform.isIOS && state.isListening && !_disposed) {
      _micRestartTimer = Timer(const Duration(milliseconds: 1400), () async {
        _micRestartTimer = null;
        if (_disposed || !state.isListening || _pitchSub != null) return;
        try {
          await _tonePlayer.stop();
        } catch (e) {
          debugPrint('TunerNotifier: failed to stop tone in restart timer: $e');
        }
        _suppressUntil = DateTime.now().add(const Duration(milliseconds: 300));
        _attachMicSubscription();
      });
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<void> toggleShowOctave() async {
    final newVal = !state.showOctave;
    state = state.copyWith(showOctave: newVal);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kShowOctaveKey, newVal);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save showOctave: $e');
    }
  }

  Future<void> togglePreferFlats() async {
    final newPreferFlats = !state.preferFlats;
    // Reset hysteresis so the new accidental notation takes effect on the
    // next pitch frame rather than waiting out the challenge counter.
    _confirmedNote = null;
    _challengeNote = null;
    _challengeCount = 0;
    if (state.detectedHz != null && state.selectedHarp == null) {
      // No harp selected: recalculate chromatic note name with new preference.
      final info = MusicUtils.frequencyToNoteInfo(
        state.detectedHz!,
        preferFlats: newPreferFlats,
        pedalHarp: false,
        a4Hz: state.a4Hz.toDouble(),
      );
      state = state.copyWith(
        preferFlats: newPreferFlats,
        closestNoteName: info.noteName,
        cents: info.cents,
      );
    } else {
      // Harp selected: note name comes from the closest string label and does
      // not depend on preferFlats; just update the flag.
      state = state.copyWith(preferFlats: newPreferFlats);
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kPreferFlatsKey, newPreferFlats);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save preferFlats: $e');
    }
  }

  Future<void> setA4Hz(int hz) async {
    final clamped = hz.clamp(_kA4HzMin, _kA4HzMax);
    if (state.detectedHz != null) {
      if (state.selectedHarp != null) {
        // Harp mode: note name is the harp string label (unchanged when a4Hz
        // shifts); recalculate cents against the calibrated string frequency.
        final harpStrings = HarpPresets.stringsFor(
            state.selectedHarp!, leverStringCount: state.leverStringCount);
        final closest = MusicUtils.closestString(state.detectedHz!, harpStrings);
        if (closest != null) {
          state = state.copyWith(
            a4Hz: clamped,
            cents: MusicUtils.centsFromTarget(
                state.detectedHz!, closest.frequencyAt(clamped.toDouble())),
          );
        } else {
          state = state.copyWith(a4Hz: clamped);
        }
      } else {
        final info = MusicUtils.frequencyToNoteInfo(
          state.detectedHz!,
          preferFlats: state.preferFlats,
          pedalHarp: false,
          a4Hz: clamped.toDouble(),
        );
        state = state.copyWith(
          a4Hz: clamped,
          closestNoteName: info.noteName,
          cents: info.cents,
        );
      }
    } else {
      state = state.copyWith(a4Hz: clamped);
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_kA4HzKey, clamped);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save a4Hz: $e');
    }
  }

  Future<void> setLeverStringCount(int count) async {
    final clamped = count.clamp(_kLeverStringMin, _kLeverStringMax);
    state = state.copyWith(leverStringCount: clamped);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_kLeverStringCountKey, clamped);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save leverStringCount: $e');
    }
  }

  Future<void> toggleShowTuningReminder() async {
    final newVal = !state.showTuningReminder;
    state = state.copyWith(showTuningReminder: newVal);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kShowTuningReminderKey, newVal);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save showTuningReminder: $e');
    }
  }

  Future<void> setSelectedHarp(HarpType? harp) async {
    if (harp == null) {
      // Deselecting instrument: also exit reference mode
      await _tonePlayer.stop();
      state = state.copyWith(
        clearSelectedHarp: true,
        tunerMode: TunerMode.auto,
        clearReferenceString: true,
        isPlayingTone: false,
      );
    } else {
      // Harp selected — always enable preferFlats (B♭ convention)
      state = state.copyWith(selectedHarp: harp, preferFlats: true);
      // If already in reference mode, precompute tones for the new harp.
      if (state.tunerMode == TunerMode.reference) _precomputeHarpTones(harp);
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (harp == null) {
        await _prefs!.remove(_kHarpTypeKey);
      } else {
        await _prefs!.setString(_kHarpTypeKey, harp.name);
        await _prefs!.setBool(_kPreferFlatsKey, true);
      }
    } catch (e) {
      debugPrint('TunerNotifier: failed to save harpType: $e');
    }
  }

  // ── Pitch processing ───────────────────────────────────────────────────────

  // Dispatch to the platform-specific corrector. iOS and Android ship
  // independently-tuned algorithms frozen to their respective store versions.
  void _onPitchResult(PitchResult? result) {
    if (_detectionAlgo == DetectionAlgo.ios) {
      _onPitchResultIos(result);
    } else {
      _onPitchResultAndroid(result);
    }
  }

  // ── iOS corrector (App Store v1.1.10) ─────────────────────────────────────
  // Frozen to the iOS store version: octave-only correction, whole-ring
  // stability gate, instant first-acquisition, and a first-null reset. Kept
  // separate from the Android corrector so platform tuning never crosses over.
  void _onPitchResultIos(PitchResult? result) {
    if (result == null) {
      _silenceCount++;
      if (_silenceCount == 1) {
        // First silence frame: reset detection state immediately so the next
        // note has a clean history and no hysteresis blocking. Display stays
        // fully bright until _kStaleFrames to avoid flicker between notes.
        _freqHistory.clear();
        _confirmedNote = null;
        _challengeNote = null;
        _challengeCount = 0;
      } else if (_silenceCount == _kStaleFrames && !state.isStale) {
        // Sustained silence: dim the display to signal stale reading
        if (state.cents != null) state = state.copyWith(isStale: true);
      } else if (_silenceCount >= _kHoldFrames) {
        // Long silence: wipe the display too
        _silenceCount = 0;
        state = state.copyWith(clearPitch: true); // also resets isStale
      }
      return;
    }

    // Suppress pitch updates briefly after playing a reference tone so the
    // speaker output doesn't confuse the pitch detector.
    if (_suppressUntil != null && DateTime.now().isBefore(_suppressUntil!)) {
      return;
    }

    // Signal returned — reset silence tracking
    _silenceCount = 0;

    final hz = result.frequency;

    // Octave correction + outlier rejection
    if (_freqHistory.isNotEmpty) {
      final med = _median(_freqHistory);
      final centsDiff = 1200 * log(hz / med) / ln2;
      if (centsDiff.abs() > 150) {
        final corrected = _octaveCorrectIos(hz, med);
        if (corrected == null) return;
        _addToHistory(corrected);
      } else {
        _addToHistory(hz);
      }
    } else {
      _addToHistory(hz);
    }

    // Stability gate (over the whole history ring)
    if (_freqHistory.length < _stableNeeded) return;
    if (_centSpread(_freqHistory) > _stableCents) return;

    final stableHz = _median(_freqHistory);

    // ── Reference mode: measure cents relative to the pinned string ──────────
    if (state.tunerMode == TunerMode.reference && state.referenceString == null) {
      return;
    }
    if (state.tunerMode == TunerMode.reference && state.referenceString != null) {
      final refHz    = state.referenceString!.frequencyAt(state.a4Hz.toDouble());
      final refCents = (1200 * log(stableHz / refHz) / ln2).clamp(-100.0, 100.0);
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: state.referenceString!.label,
        cents: refCents,
      );
      return;
    }

    // ── Auto mode: find the closest note ────────────────────────────────────
    final String noteName;
    final double centsVal;
    if (state.selectedHarp != null) {
      final harpStrings = HarpPresets.stringsFor(
        state.selectedHarp!,
        leverStringCount: state.leverStringCount,
      );
      final closest = MusicUtils.closestString(stableHz, harpStrings);
      if (closest == null) return;
      noteName = closest.label;
      centsVal = MusicUtils.centsFromTarget(
          stableHz, closest.frequencyAt(state.a4Hz.toDouble()));
    } else {
      final info = MusicUtils.frequencyToNoteInfo(
        stableHz,
        preferFlats: state.preferFlats,
        pedalHarp: false,
        a4Hz: state.a4Hz.toDouble(),
      );
      noteName = info.noteName;
      centsVal = info.cents;
    }

    // Hysteresis: instant first acquisition, challenge-gated switching.
    if (_confirmedNote == null || _confirmedNote == noteName) {
      _confirmedNote = noteName;
      _challengeNote = null;
      _challengeCount = 0;
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: noteName,
        cents: centsVal,
      );
    } else {
      if (_challengeNote == noteName) {
        _challengeCount++;
      } else {
        _challengeNote = noteName;
        _challengeCount = 1;
      }
      if (_challengeCount >= _challengeNeededIos) {
        _confirmedNote = noteName;
        _challengeNote = null;
        _challengeCount = 0;
        state = state.copyWith(
          isStale: false,
          detectedHz: stableHz,
          closestNoteName: noteName,
          cents: centsVal,
        );
      }
    }
  }

  // ── Android corrector (Play Store v1.1.11) ────────────────────────────────
  // Frozen to the Android store version: full harmonic correction (octave,
  // twelfth, two-octave, plus bass inter-harmonic < 250 Hz), sliding stability
  // window, null-frame tolerance, and challenge-gated acquisition — tuned for
  // slow Android devices. Kept separate from the iOS corrector.
  void _onPitchResultAndroid(PitchResult? result) {
    if (result == null) {
      _silenceCount++;
      // Isolated nulls are NOT treated as note ends. On slow Android devices
      // YIN emits null frames intermittently while a string is still ringing
      // (true/null/true/null), and _silenceCount resets to 0 on every pitched
      // frame — so a single null must not disturb history or the acquisition
      // counter, or notes could never confirm. Detection state is only reset
      // on SUSTAINED silence (the note has genuinely stopped).
      if (_silenceCount == _kStaleFrames) {
        // ~1.4s of continuous silence: the note has stopped. Clear detection
        // state so the next note acquires fresh, and dim the display.
        _freqHistory.clear();
        _confirmedNote = null;
        _challengeNote = null;
        _challengeCount = 0;
        if (!state.isStale && state.cents != null) {
          state = state.copyWith(isStale: true);
        }
      } else if (_silenceCount >= _kHoldFrames) {
        // ~2s of silence: wipe the display too.
        _silenceCount = 0;
        _freqHistory.clear();
        _confirmedNote = null;
        _challengeNote = null;
        _challengeCount = 0;
        state = state.copyWith(clearPitch: true); // also resets isStale
      }
      return;
    }

    // Suppress pitch updates briefly after playing a reference tone so the
    // speaker output doesn't confuse the pitch detector.
    if (_suppressUntil != null && DateTime.now().isBefore(_suppressUntil!)) {
      return;
    }

    // Signal returned — reset silence tracking
    _silenceCount = 0;

    final hz = result.frequency;

    // Octave correction + outlier rejection
    if (_freqHistory.isNotEmpty) {
      final med = _median(_freqHistory);
      final centsDiff = 1200 * log(hz / med) / ln2;
      if (centsDiff.abs() > 150) {
        final corrected = _octaveCorrectAndroid(hz, med);
        if (corrected == null) {
          // Too far for harmonic correction — a genuine note change, not a YIN
          // harmonic error (those are corrected above). Clear the stale history
          // so the new note accumulates cleanly and isn't dragged back to the
          // old note by the median/correction. The confirmation counter below
          // still gates the actual switch, so a brief attack transient lands
          // at most one or two challenge frames and never reaches the display.
          _freqHistory.clear();
          _addToHistory(hz);
        } else {
          _addToHistory(corrected);
        }
      } else {
        _addToHistory(hz);
      }
    } else {
      _addToHistory(hz);
    }

    // Stability gate + pitch estimate over the most recent _stableNeeded
    // readings (a sliding window), not the whole ring buffer. The window fills
    // with a new pitch in _stableNeeded frames, so a half-step move — which
    // stays under the 150¢ clear threshold and therefore does NOT flush history
    // — still switches in a few frames instead of waiting for the full
    // _historyLen ring to drain (the half-step lag).
    //
    // _stableNeeded is 3: the median of 3 ignores a single outlier frame (the
    // glitch becomes the min or max, the middle reading wins) and only moves
    // when the true pitch moves — so the cents reading stays steady and a stray
    // octave/harmonic frame can't jerk the note. A median of 2 is just the
    // average of the last two readings: it slides every frame and weights an
    // outlier at 50%, which is what made the display float.
    if (_freqHistory.length < _stableNeeded) return;
    final recent = _freqHistory.sublist(_freqHistory.length - _stableNeeded);
    if (_centSpread(recent) > _stableCents) return;

    final stableHz = _median(recent);

    // ── Reference mode: measure cents relative to the pinned string ──────────
    // If no string has been tapped yet, suppress all updates — the gauge should
    // stay blank rather than silently behaving like auto mode.
    if (state.tunerMode == TunerMode.reference && state.referenceString == null) {
      return;
    }
    if (state.tunerMode == TunerMode.reference && state.referenceString != null) {
      final refHz    = state.referenceString!.frequencyAt(state.a4Hz.toDouble());
      final refCents = (1200 * log(stableHz / refHz) / ln2).clamp(-100.0, 100.0);
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: state.referenceString!.label,
        cents: refCents,
      );
      return;
    }

    // ── Auto mode: find the closest note ────────────────────────────────────
    // When a harp is selected, snap to the nearest harp string so the note
    // name and gauge cents always reference the same string the visualizer
    // highlights. Harp strings only carry ♭ or natural accidentals, so no ♯
    // note names can appear even when preferFlats is set.
    final String noteName;
    final double centsVal;
    if (state.selectedHarp != null) {
      final harpStrings = HarpPresets.stringsFor(
        state.selectedHarp!,
        leverStringCount: state.leverStringCount,
      );
      final closest = MusicUtils.closestString(stableHz, harpStrings);
      if (closest == null) return;
      noteName = closest.label;
      centsVal = MusicUtils.centsFromTarget(
          stableHz, closest.frequencyAt(state.a4Hz.toDouble()));
    } else {
      final info = MusicUtils.frequencyToNoteInfo(
        stableHz,
        preferFlats: state.preferFlats,
        pedalHarp: false,
        a4Hz: state.a4Hz.toDouble(),
      );
      noteName = info.noteName;
      centsVal = info.cents;
    }

    // Confirm / switch with hysteresis. A candidate note must persist for
    // _challengeNeededAndroid consecutive stability-passing frames before shown.
    // This applies to BOTH first acquisition (no confirmed note) and switching,
    // so a brief attack-transient sub-harmonic — e.g. plucking D5 momentarily
    // reading as its sub-harmonic G before the string settles — lands at most
    // one or two challenge frames and never flashes on screen. Re-affirming the
    // note already displayed is instant, so holding/tuning a string has no lag.
    if (_confirmedNote == noteName) {
      _challengeNote = null;
      _challengeCount = 0;
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: noteName,
        cents: centsVal,
      );
    } else {
      if (_challengeNote == noteName) {
        _challengeCount++;
      } else {
        _challengeNote = noteName;
        _challengeCount = 1;
      }
      if (_challengeCount >= _challengeNeededAndroid) {
        _confirmedNote = noteName;
        _challengeNote = null;
        _challengeCount = 0;
        state = state.copyWith(
          isStale: false,
          detectedHz: stableHz,
          closestNoteName: noteName,
          cents: centsVal,
        );
      }
    }
  }

  void _addToHistory(double hz) {
    _freqHistory.add(hz);
    if (_freqHistory.length > _historyLen) _freqHistory.removeAt(0);
  }

  double _median(List<double> list) {
    final s = List<double>.from(list)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  double _centSpread(List<double> list) {
    final s = List<double>.from(list)..sort();
    return 1200 * log(s.last / s.first) / ln2;
  }

  // iOS corrector (App Store v1.1.10): octave-only correction. Pulls a reading
  // that landed exactly an octave off the held note back into [reference]'s
  // octave. Returns null for anything that isn't a ×2/÷2 octave error — i.e. a
  // genuine note change.
  double? _octaveCorrectIos(double hz, double reference) {
    for (final factor in [2.0, 0.5]) {
      final candidate = hz * factor;
      final cents = 1200 * log(candidate / reference) / ln2;
      if (cents.abs() < 80) return candidate;
    }
    return null;
  }

  // Android corrector (Play Store v1.1.11): pulls a reading that landed on a
  // harmonic (or sub-harmonic) of the note back to the fundamental in
  // [reference]'s octave. YIN regularly latches onto the 2nd or 3rd harmonic of
  // a plucked string — e.g. D4's 3rd harmonic ≈ A5, C4's 3rd ≈ G5, C4's sub-3rd
  // ≈ F2 — which would otherwise read as a different (wrong) note that snaps
  // "in tune". Trying ×2/÷2 (octave), ×3/÷3 (twelfth) and ×4/÷4 (two octaves)
  // covers the harmonics strong enough for YIN to misfire on. Returns null when
  // no harmonic ratio lands within 80 cents — i.e. a genuine note change.
  double? _octaveCorrectAndroid(double hz, double reference) {
    for (final factor in [2.0, 0.5, 3.0, 1 / 3, 4.0, 0.25]) {
      final candidate = hz * factor;
      final cents = 1200 * log(candidate / reference) / ln2;
      if (cents.abs() < 80) return candidate;
    }
    // Bass strings (< 250 Hz) have a weak fundamental, so YIN jumps BETWEEN
    // harmonics frame to frame — e.g. a ~61 Hz string read as its 2nd harmonic
    // (124 Hz) one frame and its 3rd (184 Hz) the next. Those differ by 3:2,
    // 4:3, etc. — not a simple multiple of the fundamental — so the factors
    // above miss them and the note flips (C♭ ↔ G♭). Snap these inter-harmonic
    // ratios too, but ONLY in the bass: higher up the same ratios are genuine
    // fifths/fourths between real strings (e.g. A4 → E5) that must NOT collapse.
    if (reference < 250) {
      for (final factor in [3 / 2, 2 / 3, 4 / 3, 3 / 4]) {
        final candidate = hz * factor;
        final cents = 1200 * log(candidate / reference) / ln2;
        if (cents.abs() < 80) return candidate;
      }
    }
    return null;
  }

  // ── Test hooks ─────────────────────────────────────────────────────────────

  @visibleForTesting
  void handlePitchResult(PitchResult? result) => _onPitchResult(result);

  @visibleForTesting
  void setStateForTest(TunerState s) => state = s;

}

final tunerProvider = NotifierProvider<TunerNotifier, TunerState>(
  TunerNotifier.new,
);

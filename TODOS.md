# TODOS

## Audio

### Real mic pitch detection

**What:** Replace `TunerNotifier.mockReading` with `mic_stream` + `pitch_detector_dart` for live pitch detection.

**Why:** The app currently uses mocked pitch data — no real tuning is possible without this.

**Context:** `TunerNotifier` in `providers/tuner_provider.dart` has a `mockReading` stub. Wire in `mic_stream` for audio capture and `pitch_detector_dart` for YIN/AMDF pitch detection. Request mic permission via `permission_handler` before starting.

**Effort:** M
**Priority:** P0
**Depends on:** None

### Reference tone playback

**What:** Replace `TunerNotifier.playTone` stub with real sine-wave generation via `audioplayers`.

**Why:** Reference mode UI exists but playback is a no-op.

**Context:** The synthesiser code and UI are complete. Just needs `audioplayers` wired in where the stub returns.

**Effort:** S
**Priority:** P1
**Depends on:** None

## Completed

### App rename to Harpie

**What:** Rename app from "Harp Tuner" to "Harpie" across Android manifest, iOS Info.plist, and app title.

**Completed:** v1.0.2+4 (2026-04-07)

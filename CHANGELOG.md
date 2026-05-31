# Changelog

All notable changes to Harp Tuner are documented here.

## [1.1.11+21] - 2026-05-31

### Fixed
- Pitch detection is far more reliable on Android, especially on slower devices. Notes are detected faster after pressing start, moving between strings no longer stalls for a second or two, and low strings no longer flip to the wrong note (e.g. a low C reading as G).
- Bass strings hold the correct note instead of jumping between octaves. A weak-fundamental string whose harmonics confuse the detector (reading as a fifth or octave away) is now pulled back to the note you actually played.
- A freshly plucked string no longer flashes a wrong note for a moment before settling — the attack transient is filtered out.
- Held strings read a steady cents value you can tune against, instead of the needle floating.
- Gauge now shows only the note letter and accidental (e.g. "A♭") without the octave or register number, which was redundant with the string list below.
- Note text on the gauge was being clipped by the in-tune circle on devices with different font metrics (observed on iPhone 17). Removed the `Clip.antiAlias` constraint and changed the `FittedBox` alignment from a downward y-offset to exact center, keeping all glyph corners equidistant from the circle edge.

## [1.1.10+20] - 2026-05-29

### Fixed
- Pitch detection now reliably catches notes played in quick succession (~1 per second). Previously, any note plucked during the ~100 ms compute window was silently dropped — its attack never reached the detector. Audio now accumulates continuously; only the detection trigger is gated, so back-to-back notes are no longer missed.
- Fixed three race conditions in the audio pipeline that could occur during rapid reference-mode tapping: a stop-then-start cycle no longer emits stale detection results into the new session, does not reset the new session's concurrency guard, and no longer allows two compute isolates to run simultaneously against the same accumulator.

## [1.1.9+19] - 2026-05-29

### Changed
- String labels now use harp-convention register numbering instead of scientific octave notation. The top two pedal harp strings (G and F) are register 0; each descending group of seven diatonic strings increments the register. The register number appears before the note letter — for example, `0G♭`, `1E♭`, `4C♭`, `7C♭` — matching the numbering harpists use. Both the string list and the tuner gauge now display this format.

## [1.1.8+18] - 2026-05-29

### Fixed
- `PitchDetectionService._startMic`: mic setup now properly yields before emitting errors, so callers can subscribe to the stream before any error is delivered (broadcast streams silently drop events with no listeners).
- `_startMic` now guards against a double-start race: if `start()` is called a second time before the first yield resolves, the stale coroutine detects the controller has been replaced and exits cleanly — preventing a leaked mic subscription that would double CPU usage.
- `MicStream.sampleRate` callback is now guarded with `.catchError` so an unhandled rejection cannot silently corrupt the YIN sample rate; the default of 44100 Hz is preserved on error.
- `PitchServiceError` now `implements Exception` so Dart's zone/stream error system reliably delivers it through broadcast streams on both Android and iOS.

### Changed
- Test coverage for `PitchDetectionService` increased from 85% to 94%. Eleven new tests added: accumulator overflow trim, mic stream injection (catch block, data callback, error wrapping), and pitch accuracy at A4 (440 Hz), C4, G3, A5, C5 — each within ±15 cents. Amplitude-independence and 50% overlap window tests verify the cross-platform detection pipeline.

## [1.1.7+17] - 2026-05-29

### Fixed
- Android pitch detection: switched microphone audio source from `DEFAULT` to `UNPROCESSED` (`AudioSource.UNPROCESSED`, API 24+). Google's audio HAL on Pixel and other Android devices applies AGC and noise suppression on the default source, subtly distorting the YIN autocorrelation waveform and producing a small systematic pitch offset compared to iOS (which uses `.measurement` mode, disabling all signal processing). `UNPROCESSED` bypasses these effects for a raw signal equivalent to iOS.

## [1.1.6+16] - 2026-05-29

### Fixed
- Auto mode with a harp selected: note names now snap to the nearest harp string label (never ♯) instead of using chromatic 12-tone snapping. The displayed note always matches the highlighted string in the string visualizer.
- `togglePreferFlats` now resets the hysteresis counters (`_confirmedNote`, `_challengeNote`, `_challengeCount`) so the new accidental notation takes effect on the very next pitch frame rather than waiting out the challenge delay.
- `setA4Hz` with a harp selected: recalculates cents against the harp string frequency instead of re-running chromatic snapping, preventing the note label from reverting to an off-harp name (e.g. `G4` → `G♭4`).

### Changed
- Six regression tests added to `tuner_notifier_test.dart` guarding the preferFlats/alignment invariants: no-♯ in auto mode, closest-string alignment for common accidental pitches, `setA4Hz` label stability, and hysteresis reset on `togglePreferFlats`.

## [1.1.5+15] - 2026-05-28

### Fixed
- YIN pitch detection now runs on a background isolate (`compute()`), eliminating main-thread jank during pitch analysis. A `_processing` guard drops incoming audio frames while the isolate is busy so the UI never stalls.
- Reference tone playback on iOS: `_suppressUntil` and the early-stop timer are now armed before `play()` instead of after, so the mic suppression window actually covers the tone.
- Reference tone playback on Android: microphone is paused before `play()` starts (restoring correct speaker routing — AudioRecord + MediaPlayer active simultaneously routes output to the earpiece).
- Android restart timer: `_tonePlayer.stop()` is now properly awaited inside an `async` callback; a stop failure no longer silently leaves the mic paused with no recovery path.
- Mode switch mid-suppression: switching from reference to auto mode clears `_suppressUntil` so pitch detection is not silently deaf for up to 1.5 s after the switch.
- iOS early-stop timer now checks `_disposed` before calling `_tonePlayer.stop()`.
- `stopListening()` explicitly stops the tone on iOS when it cancels the pending early-stop timer.
- `fake_async` dev dependency pinned to `^1.3.3` (was unconstrained `any`).

### Changed
- Test coverage raised from 95% to 98.7% (337 tests, all passing). New suites cover the pitch-detection pipeline via a `processChunkForTest` hook, TunerNotifier error handlers and timer callbacks via `FakeAsync`, reference tone playback paths, and the non-const `TunerScreen` constructor.

## [1.1.4+14] - 2026-05-27

### Fixed
- In-tune note circle now clips correctly on iOS — Outfit font glyphs are slightly larger on CoreText than on Skia, causing the note letter to overflow the circle edge. Fixed by moving FittedBox directly inside the AnimatedContainer (tight 160×160 constraints) and adding `clipBehavior: Clip.antiAlias`.

### Changed
- In-tune color scheme inverted: the note circle fills with a medium sage colour (55% alpha) and the gauge card returns to its standard `surfaceHi` background. Previously the card glowed light green and the circle was transparent.
- In-tune note text is white (92% alpha for the letter, 87% for the accidental, 65% for the octave) for legibility against the sage circle. Text colour returns to the standard note colour when out of tune.
- Note font weight no longer changes on in-tune — always `w400`, no bold jump.

## [1.1.3+13] - 2026-05-27

### Changed
- Test coverage raised from 78% to 95% (306 tests, all passing). New test suites cover the tuner state machine, settings persistence error paths, reference tone synthesis, gauge rendering, all 6 locales, and the app entry point.

## [1.1.2+12] - 2026-05-26

### Changed
- Pitch state is now shown directly in the note name area: ♭ and ♯ indicators flank the detected note as glowing circular bulbs, and the note lights up inside a large green circle when you're in tune.
- Note name is larger and bolder when in tune for instant recognition at a glance.
- In dark themes (Blueprint, Void, Phosphor), the note name uses a softer colour to reduce eye strain at display size.
- Flat/sharp bulbs have a transparent background when inactive, matching the clean look of the gauge.
- Removed the separate pitch indicator row below the gauge — pitch feedback is now integrated into the note display.

## [1.1.1+11] - 2026-05-15

### Changed
- CocoaPods updated from 1.12.0 to 1.16.2 (iOS dependency manager maintenance update).

## [1.1.0+10] - 2026-05-11

### Added
- In-tune glow: the gauge section background and note readout text animate to the accent color when the needle is within ±15¢ of the target pitch. Matches the same stability-gated signal used by the pitch light bulbs, so all three indicators agree.

### Fixed
- Gauge card background is now always visible (uses surfaceHi base color) so the card padding is not invisible in idle or out-of-tune states.
- Reminder snackbar English copy: "Set all pedals to ♭ before tuning" → "Set all pedals to flat before tuning".

## [1.0.9+9] - 2026-05-10

### Changed
- Tuning reminder setting renamed from "Show tuning reminder" to "Tuning Reminder" with a short description underneath explaining what it reminds you to do.
- Tuning reminder snackbar is now tappable anywhere to dismiss — no longer requires tapping a small "Got it" button. The dismiss button is now a larger, bold "OK" label for quicker reading.
- Snackbar message text is larger (16px) and more concise, making it easier to read at a glance before you start tuning.
- Swipe-to-dismiss on the tuning reminder snackbar is intentionally disabled — the reminder is safety-critical and should not be accidentally swiped away.

## [1.0.8+8] - 2026-04-24

### Changed
- When a harp is selected, the "Always show flats" toggle is now locked ON and visually dimmed — harps are conventionally notated in flats, so the setting is not user-configurable while a harp type is active.
- Lever harp string count is now shown inline directly below the Lever Harp option in the instrument settings, making the connection between instrument type and string count clearer.
- The instrument display card on the main screen now combines the harp type and string count into a single card ("Lever · 34") instead of two separate cards. The A4 calibration card remains alongside it.

## [1.0.7+7] - 2026-04-10

### Changed
- App renamed to **Harpie** with a new terracotta harp icon across iOS and Android.
- Bundle ID set to `com.career010.harpie` for both platforms.
- Launch screen updated to terracotta background on iOS and Android.
- App defaults to lever harp on first launch so the tuner is immediately usable without setup.

### Fixed
- Android adaptive icon now uses the correct per-density foreground layers with terracotta background.
- Android launch background corrected to use `@color` reference (raw hex was invalid in `<item android:drawable>`).
- Android `MainActivity` moved to `com.career010.harpie` package to match the updated namespace.

## [1.0.6+6] - 2026-04-09

### Changed
- Lever harp string range is now treble-anchored: the top string is always E♭7 and the bass end varies with string count (40 strings → A♭1–E♭7, 34 strings → G2–E♭7, 19 strings → A♭4–E♭7). The subtitle in the harp selector and settings now shows the actual bottom note for the selected count.
- Chinese name for lever harp corrected to 撥鍵豎琴 (was 槓桿豎琴) in zh and zh_TW.
- Tuning reminder snackbar reworded in all 6 locales to lead with "Before tuning, …" structure for clearer action framing.

## [1.0.5+5] - 2026-04-09

### Added
- Tuning reminder: when the tuner starts listening, a snackbar prompts pedal harp users to set all pedals to the flat position and lever harp users to disengage all levers before tuning. The reminder persists until dismissed with "Got it" or the tuner stops.
- Settings toggle: "Show tuning reminder" — disabling it hides the snackbar immediately if it's active; re-enabling it while the tuner is running brings the reminder back.

### Fixed
- Reminder snackbar updates its text in real time when you switch harp type while the tuner is active.
- Reminder snackbar colours are correct across all 5 themes: dark themes use the surfaceHi background with an inTune accent and border ring for clear visibility against near-black screens.
- German translation typo: "obste Raste" corrected to "oberste Raste".

## [1.0.4+4] - 2026-04-07

### Changed
- App renamed from "Harp Tuner" to "Harpie" across Android manifest, iOS Info.plist, and app title

## [1.0.3+4] - 2026-03-26

### Fixed
- Reference mode on Android: tapping a string now plays the tone immediately through the speaker instead of after stopping tuning. Root cause was an Android audio routing conflict — `AudioRecord` (mic) and `MediaPlayer` (tone) simultaneously active routes output to the earpiece. Fix: mic is paused while the tone plays and automatically restarts 2.3 s later.
- Tone synthesis tail wobble: polarisation beating and frequency jitter now fade out faster than the main tone (4× decay multiplier) so the sustain tail rings clean and stable.
- Reference tone pitch accuracy: removed the pitch glide (+8 cents at onset) which could cause users to tune sharp if they matched the attack rather than the settled pitch. Reference tones are now pitch-accurate from the first sample.
- iOS AppDelegate no longer activates `AVAudioSession` at launch (which was interrupting background music and risked App Store rejection). Audio session configuration now happens only when the mic is first activated.
- Body resonance filter: `bodyGain` is now clamped to 1.0 to prevent the 180 Hz resonant peak from boosting partials above unity and causing clipping on bass strings.
- Concurrent precompute: background tone synthesis is now limited to 4 simultaneous isolates (was unbounded), preventing OOM spikes on pedal harp (47 strings × ~9 MB peak = ~420 MB before the fix).
- Double-subscription guard added to `_attachMicSubscription` to prevent a second mic stream being created if called while one is already active.
- Rapid double-tap bug: the mic restart timer now uses `state.isListening` (intent) rather than `_pitchSub != null` (actual) so tapping two strings quickly no longer leaves the mic paused indefinitely.

### Changed
- Tone synthesis upgraded from 4 acoustic layers to 8: register-scaled inharmonicity, pitch-dependent decay, dynamic partial count, soundboard body filter, pluck noise burst, body knock impulse, partial frequency jitter, polarisation beating.
- Reference tone precomputation: all harp string tones are synthesised in the background when entering reference mode so the first tap plays instantly.

## [1.0.2+3] - 2026-03-22

### Added
- Reference mode: tap any string in the string visualizer to hear a harp-like synthesised tone and pin it as the tuning target; the gauge then shows how many cents you are from that specific string
- Reference tone synthesis: inharmonic partials, two-phase pluck decay, polarisation-plane beating, and early reflections for a natural harp-string timbre
- Mic suppression window after playback prevents speaker output from confusing the pitch detector
- `TunerMode.reference` state with `referenceString` and `isPlayingTone` fields; all 5 localisations updated
- `modeAuto` / `modeReference` / `referenceTapHint` localisation strings (EN, DE, FR, IT, ZH)
- `audioplayers` dependency for low-latency audio playback

### Changed
- Mode toggle labels now use `sans` style instead of `label` — removes inappropriate `letterSpacing: 2.5` from mixed-case tab text
- Settings section headers use `sans` with `w600` weight instead of `label` (removes all-caps letter-spacing from body UI labels)
- Dark-mode string colors: removed hardcoded bypass — each theme now uses its own `stringC/F/Natural` from `TunerThemeData`
- Harp select card shadows softened: opacity 40% → 8%, blur 12 → 16 px (lighter, papery lift)
- String visualizer height increased to 116 px, string lines to 68 px for better touch targets
- Gauge arc sizing: proportional cap (`maxH × 0.65`) replaces fixed 150 px floor — prevents `clamp(lower, upper)` crash on small screens in reference mode
- Idle readout icon: `music_note` → `mic_none` (not listening) / `graphic_eq` (listening)
- Gauge layout: `mainAxisSize.min` + `Expanded` wrapper so dead space below button is eliminated
- Pitch light bulb sizes reduced (flat/sharp 40→30 px, in-tune 60→44 px)

### Fixed
- `isPlayingTone` now always resets to `false` via `try/finally`, even when `AudioPlayer` throws
- `TonePlayerService.play()` captures `AudioPlayer` locally before async gap — prevents NPE if `dispose()` runs during `compute()`
- `setTunerMode` errors logged via `try/catch` instead of silently discarded
- Reference mode with no string tapped no longer falls through to auto-mode note detection

## [1.0.1+2] - 2026-03-22

### Added
- Reduced-motion support: animations skip or jump-cut when `MediaQuery.disableAnimationsOf` is set (gauge, fade-in, page transitions)
- Semantics annotations on gauge (stale-reading label), mic error banner, and settings button for screen reader support

### Changed
- Gauge needle: spring physics with EMA smoothing; needle tail anchors at arc midpoint; ±50/0 labels only (removed mispositioned CENT label)
- F-string dark-mode color: inverted landmark approach — near-white `#CDCDC8` on dark themes so F strings are legible at full contrast across all dark themes (Void, Blueprint, Phosphor)
- Landmark string inactive opacity raised to 0.92 (vs 0.65 for naturals) to reinforce C/F identity in all modes
- White rim opacity on dark-mode strings raised from 0.30 → 0.45 for better legibility
- Mic error banner: replaced `Colors.amber` with `theme.sharp` for proper theme integration
- Pitch light indicator: label size 16 → 14px, active weight w700 → w600 (less dominant, better hierarchy)
- Settings button: vertical padding 16 → 10 (less dead space, tighter feel)
- Harp select screen: label capitalisation changed to sentence case; gold accent colours replaced with `textSecondary` for subtler hierarchy
- Language row: `ConstrainedBox(minHeight: 48)` ensures accessible touch target

### Fixed
- Mic error banner Semantics labels were hardcoded English — now use `AppLocalizations` keys
- Dead conditional in `StringCell._inactiveAlpha` simplified (`_isDark ? 0.65 : 0.65` → `0.65`)
- `pumpAndSettle` in widget smoke test caused timeout with repeating `AnimationController` — changed to single `pump()`
- Widget test expected removed text — updated to `find.text('Start Tuning')`

## [1.0.0+1] - initial release

# Changelog

All notable changes to Harp Tuner are documented here.

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

# Changelog

All notable changes to Harp Tuner are documented here.

## [1.0.2+4] - 2026-04-07

### Changed
- App renamed from "Harp Tuner" to "Harpie" across Android manifest, iOS Info.plist, and app title

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

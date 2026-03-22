# Changelog

All notable changes to Harp Tuner are documented here.

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

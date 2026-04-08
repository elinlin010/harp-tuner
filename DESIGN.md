# Design System — Harpie

## Product Context
- **What this is:** A chromatic harp tuner for iOS and Android. Listens to a plucked string and shows, via an animated arc gauge, how sharp or flat it is.
- **Who it's for:** Parents of young harpists, absolute beginners, and casual Celtic/lever harp players who want something that works without music theory knowledge.
- **Space/industry:** Music utility / instrument tuner app. Competing context: GuitarTuna (dark, clinical), Yousician (bright, gamified). Harpie occupies a gap: warm, calm, handmade-quality — unhurried and approachable.
- **Project type:** Mobile app (Flutter) + web landing page + marketing materials.

---

## Aesthetic Direction

**Direction:** Artisan Warmth
**Decoration level:** Intentional — surfaces have warmth (cream, linen), brand moments use terracotta. No gratuitous decoration.
**Mood:** A beautifully made physical tool. Calm, honest, slightly beautiful. Like a well-crafted tuning fork in a felt-lined case, not studio gear or a mobile game.

**Anti-patterns to avoid:**
- Dark-on-neon, clinical precision aesthetics (guitar tuner defaults)
- Gamification elements: smiley faces, XP bars, achievement badges, urgency animations
- Purple gradients, generic rounded cards with coloured icon circles
- Smiley feedback states when a string is in tune — the arc gauge IS the feedback

---

## Typography

> The app uses **Outfit only**. Do not introduce additional fonts into the Flutter app.
> Instrument Serif is the display/hero font for the **landing page and marketing materials only**.

### App (Flutter)

| Role | Font | Weight | Notes |
|------|------|--------|-------|
| All text | Outfit (GoogleFonts) | 400–700 | Single font family throughout the app |
| Labels / section headers | Outfit | 600 | `letterSpacing: 2.5`, uppercase, via `TunerThemeData.label()` |
| Pitch readouts | Outfit | 300–400 | `fontVariantNumeric: tabularNums` for freq numbers |

Use `TunerThemeData.sans(size, weight, color)` and `TunerThemeData.label(size, color)` — never hard-code `TextStyle` outside the theme.

### Brand / Landing / Marketing

| Role | Font | Notes |
|------|------|-------|
| Display / hero headlines | Instrument Serif | Italic for brand emphasis. Load from Google Fonts. Says "instrument", not "software". |
| Body / UI | Outfit | Matches the app. One sans-serif family across all surfaces. |
| CTAs / buttons | Outfit 600 | |

**Google Fonts URL:**
```
https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Outfit:wght@300;400;500;600;700;800&display=swap
```

**Blacklisted (never use):** Inter, Roboto, Montserrat, Poppins, Arial, Helvetica. Outfit is the one sans-serif. No exceptions.

---

## Colour

### Brand layer (logo, landing page, marketing)

| Token | Hex | Usage |
|-------|-----|-------|
| Brand / Terracotta | `#c84b2f` | Landing CTAs, hero moments, brand mark. Not used in the app UI. |
| Brand deep | `#9e3420` | Gradient endpoint for terracotta. `background: linear-gradient(135deg, #c84b2f, #9e3420)` |
| Brand light (tint) | `#f0d4cb` | Tags, pill backgrounds on light surfaces |

### App — Linen theme (default, warm light)

This is the canonical palette. All five themes (`linen`, `milk`, `blueprint`, `void_`, `phosphor`) are defined in `lib/theme/app_theme.dart`.

| Token | Hex | Role |
|-------|-----|------|
| `bg` | `#F5F0E8` | Screen background — warm cream |
| `surface` | `#FFFDF7` | Cards, sheets, tiles |
| `surfaceHi` | `#EDE8DE` | Pressed states, inactive toggles |
| `surfaceRim` | `#C8BBAA` | Borders, dividers |
| `textPrimary` | `#1C1810` | Main text — warm near-black |
| `textSecondary` | `#6B5D4A` | Secondary text, labels |
| `textDim` | `#A89880` | Hint text, disabled, decorative ticks |
| `inTune` | `#2D7A4F` | In-tune state — forest green |
| `sharp` | `#B85C1A` | Sharp state — amber-red |
| `flat` | `#2B5EA7` | Flat state — slate blue |

### String colour coding (traditional harp convention)

| String | Linen hex | Blueprint hex | Role |
|--------|-----------|---------------|------|
| C strings | `#C0280A` | `#E8604A` | Always red family |
| F strings | `#1A1C1E` | `#78C0F8` | Near-black on light, ice blue on dark |
| Natural | `#4E6A80` | `#BEB090` | Slate / warm neutral — distinct from C and F |

### Octave accent colours (app internal — harp string list)

A 7-step amber gradient from `#B08040` (octave 1, deep) to `#FFE090` (octave 7, bright). Used for the left colour bar on `StringTile` and the active state tint. Access via `AppColors.octaveColor(int octave)`.

---

## Spacing

**Base unit:** 8px
**Density:** Comfortable

| Token | Value | Common usage |
|-------|-------|--------------|
| 2xs | 2px | Micro gaps, thin colour bars |
| xs | 4px | Tight inline gaps |
| sm | 8px | Inner padding, gaps between small elements |
| md | 12–14px | Tile horizontal padding (`horizontal: 14`) |
| lg | 16px | Standard horizontal screen margin |
| xl | 20–24px | Section padding |
| 2xl | 32px | Larger gaps, between-section spacing |

**Touch target minimum:** 44×44px (Apple HIG / Material). Play buttons and interactive icons are wrapped in `SizedBox(width: 44, height: 44)`.

---

## Border Radius

| Token | Value | Used for |
|-------|-------|----------|
| micro | 2–3px | Progress bars, thin fill elements |
| sm | 10px | String tiles (`StringTile`) |
| md | 14px | Medium cards, chips |
| lg | 16–18px | Larger cards, input fields, buttons |
| xl | 20px | Bottom sheet top edge (`BorderRadius.vertical`) |
| 2xl | 24px | Sheet corners |
| pill | 9999px | Fully round pills (not currently used in app, used in landing) |

---

## Motion

**Approach:** Intentional — every animation aids comprehension or confirms an action. No decorative motion, no gamification urgency.

| Use case | Duration | Curve | Implementation |
|----------|----------|-------|----------------|
| String tile state (selected/active) | 160ms | `easeOut` | `AnimatedContainer` on `StringTile` |
| Gauge needle movement | Continuous | Smooth audio-driven | Custom `CustomPainter` in `tuner_gauge.dart` |
| Mode toggle / screen transitions | 200–300ms | `easeOut` | Flutter navigation + `AnimatedContainer` |
| Marketing entrance animations | 300–500ms | `ease-out` | CSS `animation` on landing page |

**Never use:** urgency effects (rapid flashing, attention-grabbing pulses), gamification celebrations (confetti, score-popups), any animation that triggers without user intent.

---

## Layout

### App (Flutter)

- **Approach:** Grid-disciplined. The tuner UI is purely functional — nothing decorative interferes with readability during a tuning session.
- **String list:** Full-width list in `tuner_screen.dart`, `horizontal: 16` margin on tiles.
- **Gauge:** Centred `CustomPainter` arc in `tuner_gauge.dart`. The gauge takes ~40% of screen height.
- **Bottom sheet:** `BorderRadius.vertical(top: Radius.circular(24))`. Padding: `fromLTRB(24, 12, 24, 24 + bottomPadding)`.
- **Mode toggle:** Full-width pill row below gauge, `horizontal: 24` padding, `vertical: 14`.

### Landing page

- **Max content width:** 860px
- **Page padding:** 32px horizontal
- **Approach:** Editorial — generous vertical breathing room, left-aligned body text, headings in Instrument Serif italic.
- **Hero:** Left-aligned headline + subtext + CTAs. No full-bleed hero images.
- **Section rhythm:** Sections separated by `border-bottom: 1px solid var(--border)`.

---

## Themes

Five themes are fully implemented in `lib/theme/app_theme.dart`. Each is a `TunerThemeData` constant. Access via the `ThemeProvider` Riverpod provider.

| Theme | Brightness | Character |
|-------|------------|-----------|
| **Linen** | Light | Warm cream parchment — the default. Highest legibility. |
| **Milk** | Light | Near-zero chroma white — clean, clinical alternative. |
| **Blueprint** | Dark | Engineering paper, dark navy + cyan accents. |
| **Void** | Dark | Pure OLED black + neon state colours. Max battery savings. |
| **Phosphor** | Dark | Green phosphor CRT / terminal aesthetic. |

The theme picker UI is planned but not yet implemented. `TunerThemes.all` contains `[linen, milk, blueprint, void_]` (Phosphor is defined but excluded from the picker for now).

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-26 | Terracotta `#c84b2f` as brand colour | Warm, earthy, completely unoccupied territory in the music app category. Not used in-app to avoid collision with the Sharp state. |
| 2026-03-26 | Instrument Serif for landing/marketing display | Every music tuner app is 100% sans-serif. A humanist serif says "instrument" not "software". Scoped to marketing only — app stays Outfit-only. |
| 2026-03-26 | Artisan Warmth aesthetic direction | Music apps split into dark/clinical (GuitarTuna) or bright/gamified (Yousician). The parent-of-a-harp-student user needs neither. Warm + calm is unclaimed. |
| 2026-03-26 | Outfit as the single app typeface | Clean, rounded, friendly. Already shipping. Do not add fonts without a strong reason. |
| 2026-03-26 | No brand colour in the app UI | Terracotta (#c84b2f) is for logo + marketing. In the app, it could be confused with the Sharp state (#B85C1A). Keep them separate. |

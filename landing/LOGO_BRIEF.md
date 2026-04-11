# Logo Design Brief — Harpie

## What We're Building

**Harpie** is a chromatic harp tuner for iOS and Android. You open it, pluck a string, and an animated arc gauge shows you how sharp or flat you are. That's it — beautifully done.

This brief covers the logo and brand mark. We need two things:

1. **A wordmark** — "Harpie" set in type, suitable for nav bars, the landing page, and marketing
2. **An app icon** — a square mark (1024×1024, rounded corners) for the App Store and Google Play

---

## The Name

**Harpie** — lowercase sensibility, but written with a capital H. Not all-caps. Not all-lowercase.

---

## Who This Is For

- Parents of young harpists buying their child's first tuner
- Adult beginners learning Celtic or lever harp at home
- Casual players who want something approachable, not a pro tool

This is not for concert performers or music theory students. The user wants something that **just works** and feels good to use.

---

## Brand Positioning

**Aesthetic direction: Artisan Warmth.**

Harpie sits in a gap between two bad options:
- **GuitarTuna / chromatic tuners** — dark, clinical, precision-instrument aesthetic. Intimidating.
- **Yousician / gamified apps** — bright, badge-heavy, urgency-driven. Childish.

Harpie is neither. Think: *a beautifully made physical tool. Like a well-crafted tuning fork in a felt-lined case.* Calm, honest, slightly beautiful. Unhurried.

**Mood references (conceptual, not visual):**
- A luthier's workshop — hand tools, warm wood, careful craft
- A Celtic harp made by hand in a small studio
- A leather-bound music notebook with a cloth ribbon

**Competitive gap:** Every music tuner app is 100% sans-serif, dark, and digital-feeling. Harpie can own warm + calm + handcrafted — it's completely unoccupied territory.

---

## Typography (already decided — logo must be consistent)

The brand typeface system is set:

| Role | Font | Notes |
|------|------|-------|
| **Display / hero / wordmark** | **Instrument Serif** | *Italic* for brand emphasis. Humanist, warm, says "instrument" not "software". |
| App UI / body | Outfit | Rounded sans-serif. Used exclusively inside the app. |

**The wordmark must be set in Instrument Serif italic.** This is the single most important typographic decision in the design system — it's what separates Harpie from every other tuner app.

Google Fonts: `https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap`

**Blacklisted (never use in the logo):** Inter, Roboto, Montserrat, Poppins, Arial, Helvetica, any geometric sans.

---

## Colour (already decided — logo must use these)

### Brand palette

| Name | Hex | Role |
|------|-----|------|
| **Terracotta** | `#c84b2f` | Primary brand colour. App icon background. CTAs. Hero moments. |
| **Terracotta deep** | `#9e3420` | Gradient end. `linear-gradient(135deg, #c84b2f, #9e3420)` |
| **Terracotta tint** | `#f0d4cb` | Light surfaces — tags, chips on cream backgrounds |

### App palette (for context — do not use in the logo)

The app runs on warm cream (`#F5F0E8` background, `#FFFDF7` surfaces). The logo appears on top of this in nav bars and headers. It also appears on white and on dark backgrounds (`#1C1810`).

**Critical constraint:** Terracotta (`#c84b2f`) is reserved for brand/marketing. The app uses amber-red (`#B85C1A`) for the "sharp" tuning state. These must never be confused — the logo colour must not appear inside the app UI.

### Why terracotta?

Warm, earthy, completely unoccupied in the music app category. GuitarTuna is charcoal + green. Yousician is electric blue. Nobody owns warm terracotta-red. It reads as handmade, not digital.

---

## App Icon Spec

- **Canvas:** 1024 × 1024 px
- **Background:** Terracotta gradient (`linear-gradient(135deg, #c84b2f, #9e3420)`)
- **Corner radius:** 200px (Apple rounds further to ~22.5% automatically, so the SVG `rx="200"` becomes roughly 180px visible)
- **Mark colour:** White (`#ffffff`)
- **Style:** The mark should be bold enough to read at 29×29px (the smallest iOS home screen size). Test at 29, 40, 60, 80, 120, 180px.

The icon is **mark only** — no wordmark inside the app icon square.

---

## Wordmark Spec

- **Typeface:** Instrument Serif italic
- **Colour on light (linen) background:** `#1C1810` (warm near-black) with the initial "H" optionally accented in `#c84b2f`
- **Colour on dark background:** `#F5F0E8` (warm cream)
- **Colour on brand (terracotta) background:** `#ffffff`
- **Sizing:** Should work from 16px (small nav labels) to 80px+ (landing page hero)

---

## Mark Direction

The mark inside the app icon should reference a **harp** — specifically the distinctive curved neck of the instrument. The harp's neck (the curved arch connecting the column to the soundboard) is the one shape that is unmistakably a harp and nothing else.

**What to explore:**
- The harp neck arch as a single confident stroke — one gestural line
- The harp silhouette (column + neck + soundboard) as a minimal filled shape
- A minimal open-frame harp (column + neck + soundboard as strokes, with 2–3 strings)

**What to avoid:**
- Tuning fork hybrids — too obvious, too clinical
- Musical note hybrids — doesn't say "harp"
- Treble clef, G-clef, or any generic music symbol
- Anything that looks like a guitar or string instrument other than harp
- Smiley faces, stars, checkmarks, or gamification metaphors
- More than 4 visual elements in the mark (tends to look like a diagram, not a logo)

**Tone to aim for:**
The mark should look like it could be stamped into wax, embossed on leather, or engraved on wood. A craftsman's mark, not a UI icon.

---

## Lockup Variants Needed

1. **App icon** — 1024×1024, terracotta bg, white mark only
2. **Horizontal lockup** — mark + "Harpie" wordmark, side by side, for nav bars and headers
3. **Stacked lockup** — mark above wordmark, for landing page hero or social profiles
4. **Wordmark only** — for contexts where the mark doesn't fit (email footers, small print)

Each variant in:
- Light version (for use on cream/white backgrounds)
- Dark version (for use on dark backgrounds)
- Brand version (white, for use on terracotta backgrounds)

---

## Deliverables

- SVG source files for all lockup variants
- PNG exports at 1x, 2x, 3x for each lockup
- App icon PNG at 1024×1024 (and ideally 512, 180, 120, 87, 80, 60, 58, 40, 29px)
- A brief note on any typeface weight or optical adjustments made

---

## Context: How the Logo Is Used

### In the mobile app
The app does **not** show the wordmark or logo inside the UI — only the system launcher icon. The design inside the app is Outfit-only, warm cream palette. The logo lives outside the app (the icon, the App Store listing, the splash/loading screen if added later).

### On the landing page
- Nav bar: horizontal lockup (small, ~24px wordmark height) on linen background
- Hero section: wordmark at large size (48–80px), possibly with mark alongside
- Footer: wordmark only, smaller

### Marketing / social
- Profile image: app icon (square)
- Cover images: wordmark on terracotta or linen

---

## Anti-patterns (do not do these)

- Purple gradients — this is not a productivity app
- Neon colours on dark — this is not a gaming app
- Rounded bubbly letterforms — Instrument Serif is already warm, don't over-soften
- Drop shadows, glows, or 3D effects on the mark
- Any element that looks like it could belong to GuitarTuna or Yousician
- "H" inside a circle (looks like a hospital or hotel logo)
- Musical staff / treble clef (too generic)

---

## One-sentence brief

> *A warm, quietly confident tuner for harpists: the logo should feel like a maker's mark from a small instrument workshop, set in a humanist serif italic, anchored in terracotta.*

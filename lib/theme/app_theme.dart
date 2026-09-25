import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── TunerThemeData ────────────────────────────────────────────────────────────
//  All color fields + text style factories in one plain Dart class.

class TunerThemeData {
  final String id;
  final String displayName;
  final Brightness brightness;

  // Backgrounds
  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color surfaceRim;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;

  // States
  final Color inTune;
  final Color sharp;
  final Color flat;

  // Harp string colours — traditional red/black coding, adapted per brightness
  final Color stringC;       // C strings: always red family
  final Color stringF;       // F strings: near-black on light, pale on dark
  final Color stringNatural; // All other strings: amber/gut on light, gold on dark

  // Wood & gold finish — non-null only on the wood themes (Maple, Spruce,
  // Mahogany, Walnut). Every wood-only treatment is gated on this, so the
  // flat themes (Linen, Milk, Blueprint, Void) render exactly as before.
  final WoodFinish? wood;

  bool get isWood => wood != null;

  // ── Frames & borders ──────────────────────────────────────────────────────
  //  Wood themes take these from [wood]; the flat themes derive them from
  //  their own palette (as in the design prototype).

  /// 2px outer frame of the gauge card.
  Color get gaugeBorder => wood?.gaugeBorder ?? surfaceRim;

  /// 1px frame line inset 7px inside the gauge card.
  Color get gaugeInnerLine =>
      wood?.gaugeInnerLine ?? surfaceRim.withValues(alpha: 0.6);

  List<BoxShadow> get gaugeShadow =>
      wood?.gaugeShadow ??
      (brightness == Brightness.dark
          ? const [
              BoxShadow(
                color: Color(0x73000000), // rgba(0,0,0,0.45)
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x1A281E0F), // rgba(40,30,15,0.10)
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ]);

  /// 1px border of the settings cards above the tuner.
  Color get cardBorder =>
      wood?.cardBorder ?? surfaceRim.withValues(alpha: 0.5);

  List<BoxShadow> get cardShadow =>
      wood?.cardShadow ??
      (brightness == Brightness.dark
          ? const <BoxShadow>[]
          : const [
              BoxShadow(
                color: Color(0x14000000), // rgba(0,0,0,0.08)
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ]);

  /// Border of the pill controls (mode toggle, Settings, feedback).
  BorderSide get chipBorder => wood != null
      ? BorderSide(color: wood!.chipBorder, width: 1)
      : BorderSide(color: surfaceRim, width: 0.5);

  /// Harp neck rail and tuning pins above the string visualizer. Wood themes
  /// take theirs from [wood]; the flat themes derive a plain rail with silver
  /// pins from their own palette.
  HarpNeck get neck {
    final w = wood;
    if (w != null) {
      return HarpNeck(
        colors: w.neck,
        grain: true,
        darkGrain: w.neckDarkGrain,
        edgeTop: w.neckEdgeTop,
        edgeBottom: w.neckEdgeBottom,
        shadow: w.neckShadow,
        pin: WoodMaterials.goldGradient,
        pinShadow: WoodMaterials.pinShadow,
      );
    }
    final dark = brightness == Brightness.dark;
    return HarpNeck(
      colors: [surfaceHi, surfaceRim],
      grain: false,
      darkGrain: false,
      edgeTop: Colors.white.withValues(alpha: dark ? 0.14 : 0.6),
      edgeBottom: textSecondary.withValues(alpha: 0.33),
      shadow: Colors.black.withValues(alpha: dark ? 0.5 : 0.15),
      pin: HarpNeck.silverGradient,
      pinShadow: HarpNeck.silverPinShadow,
    );
  }

  const TunerThemeData({
    required this.id,
    required this.displayName,
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.surfaceRim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.inTune,
    required this.sharp,
    required this.flat,
    required this.stringC,
    required this.stringF,
    required this.stringNatural,
    this.wood,
  });

  // Text style — used for all text in the app (Outfit)
  TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrimary,
      );

  // Spaced label caps — section headers, mode toggles (Outfit, w600)
  TextStyle label(double size, {Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? textSecondary,
        letterSpacing: 2.5,
      );
}

// ── Wood & gold materials ─────────────────────────────────────────────────────
//  Concert-harp finish: wood-grain surfaces with gold hardware. The grain itself
//  is drawn by WoodGrainPainter (lib/widgets/wood_surface.dart) over the base
//  colours/gradients held here.

class WoodFinish {
  /// Scaffold background, top → bottom.
  final List<Color> page;

  /// Gauge card fill. Light woods: linear top → bottom. Dark woods: radial,
  /// centred at 50%/30%, centre → edge.
  final List<Color> gauge;
  final bool radialGauge;

  /// Grain overlay variant — dark woods use deeper, lower-contrast stripes.
  final bool darkGrain;

  final Color cardBorder; // settings cards, sheet cards
  final List<BoxShadow> cardShadow;
  final Color chipBorder; // mode toggle, settings/feedback pills
  final Color gaugeBorder; // 2px outer frame of the gauge card
  final Color gaugeInnerLine; // 1px frame line inset 7px
  final List<BoxShadow> gaugeShadow;

  final Color gold; // triangles, sheet edge, inactive bulb rims
  final Color tick;
  final Color arc;
  final Color zone; // in-tune zone on the arc

  /// Needle + in-tune note circle. `inTune` is gold on wood themes (UI accent);
  /// the tuner itself still reads green at a glance.
  final Color tuneGreen;

  /// Harp neck rail above the strings, top → bottom.
  final List<Color> neck;
  final bool neckDarkGrain;
  final Color neckEdgeTop;
  final Color neckEdgeBottom;
  final Color neckShadow;

  /// Check mark on the selected theme swatch.
  final Color swatchCheck;

  const WoodFinish({
    required this.page,
    required this.gauge,
    required this.radialGauge,
    required this.darkGrain,
    required this.cardBorder,
    required this.cardShadow,
    required this.chipBorder,
    required this.gaugeBorder,
    required this.gaugeInnerLine,
    required this.gaugeShadow,
    required this.gold,
    required this.tick,
    required this.arc,
    required this.zone,
    required this.tuneGreen,
    required this.neck,
    required this.neckDarkGrain,
    required this.neckEdgeTop,
    required this.neckEdgeBottom,
    required this.neckShadow,
    required this.swatchCheck,
  });
}

class HarpNeck {
  final List<Color> colors; // rail fill, top → bottom
  final bool grain;         // wood grain over the fill
  final bool darkGrain;
  final Color edgeTop;      // 1px line along the top of the rail
  final Color edgeBottom;   // 1px line along the bottom
  final Color shadow;       // drop shadow under the rail
  final Gradient pin;       // tuning-pin fill
  final BoxShadow pinShadow;

  const HarpNeck({
    required this.colors,
    required this.grain,
    required this.darkGrain,
    required this.edgeTop,
    required this.edgeBottom,
    required this.shadow,
    required this.pin,
    required this.pinShadow,
  });

  // Nickel tuning pins for the flat themes.
  static const silverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7E7E7E),
      Color(0xFFF2F2F2),
      Color(0xFFA6A6A6),
      Color(0xFFE4E4E4),
      Color(0xFF8A8A8A),
    ],
    stops: [0.0, 0.35, 0.55, 0.78, 1.0],
  );
  static const silverPinShadow = BoxShadow(
    color: Color(0x73000000), // rgba(0,0,0,0.45)
    blurRadius: 2,
    offset: Offset(0, 1),
  );
}

/// Makes a [LinearGradient] run at a fixed CSS angle (0° = to top, 90° = to
/// right), independent of the box's aspect ratio, like CSS
/// `linear-gradient(<angle>, …)`. Use with `begin: centerLeft,
/// end: centerRight`.
class CssAngleGradientTransform extends GradientTransform {
  final double degrees;

  const CssAngleGradientTransform(this.degrees);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final a = degrees * pi / 180;
    // CSS gradient-line length for this box, then map the horizontal
    // centerLeft→centerRight line onto it: scale about the centre, rotate.
    final length = (bounds.width * sin(a)).abs() + (bounds.height * cos(a)).abs();
    final c = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(a - pi / 2)
      ..scaleByDouble(length / bounds.width, 1, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is CssAngleGradientTransform && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;
}

class WoodMaterials {
  WoodMaterials._();

  // Gold leaf — tuning pins, active mode tab, Stop button, toggle thumbs.
  // A fixed 135° sheen (CSS angle) whatever the shape: a corner-to-corner
  // gradient would turn into near-vertical stripes on the wide Stop button.
  static const goldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    transform: CssAngleGradientTransform(135),
    colors: [
      Color(0xFF8A6420),
      Color(0xFFE6C66E),
      Color(0xFFB8892E),
      Color(0xFFF2D98A),
      Color(0xFF9A7228),
    ],
    stops: [0.0, 0.32, 0.52, 0.74, 1.0],
  );

  static const goldHighlight = Color(0xFFF2D98A); // 1px rim on gold fills

  /// Inner top highlight on raised gold fills (CSS inset 0 1px 0 white 50%).
  static const goldSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.04],
  );
  static const goldRim = Color(0xFFB8892E); // idle button, wood swatches
  static const onGold = Color(0xFF2B1709); // text/icons on gold fills
  static const goldShadow = Color(0x66785014); // rgba(120,80,20,0.4)

  // In-tune note circle — polished green enamel.
  static const tuneCircle = RadialGradient(
    center: Alignment(-0.3, -0.4), // 35% / 30%
    radius: 0.75,
    colors: [Color(0xFF7FB07A), Color(0xFF3F7A4E), Color(0xFF265238)],
    stops: [0.0, 0.6, 1.0],
  );
  static const tuneCircleText = Color(0xFFFFF4DA);
  static const tuneCircleGlow = [
    BoxShadow(color: Color(0x66468C55), blurRadius: 16, spreadRadius: 5),
    BoxShadow(color: Color(0x3350965A), blurRadius: 32, spreadRadius: 10),
  ];

  static const pinShadow = BoxShadow(
    color: Color(0x80000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  // Grain stripes: (colour, stripe width, period, angle° from vertical).
  static const grainLight = [
    (Color(0x125A320F), 1.0, 6.0, 1.0),
    (Color(0x2EFFFFFF), 2.0, 13.0, -0.7),
    (Color(0x0F6E3C14), 3.0, 29.0, 0.6),
  ];
  static const grainDark = [
    (Color(0x38000000), 1.0, 6.0, 1.0),
    (Color(0x0DFFD296), 2.0, 13.0, -0.7),
    (Color(0x2E000000), 3.0, 29.0, 0.6),
  ];
}

// ── TunerThemes ───────────────────────────────────────────────────────────────
//  Static theme instances. `all` is the picker list, in display order.

class TunerThemes {
  TunerThemes._();

  // Linen — warm cream parchment × ink, high-legibility light theme
  static const linen = TunerThemeData(
    id: 'linen',
    displayName: 'Linen',
    brightness: Brightness.light,
    bg:           Color(0xFFF5F0E8),
    surface:      Color(0xFFFFFDF7),
    surfaceHi:    Color(0xFFEDE8DE),
    surfaceRim:   Color(0xFFC8BBAA),
    textPrimary:   Color(0xFF1C1810),
    textSecondary: Color(0xFF6B5D4A),
    textDim:       Color(0xFFA89880),
    inTune: Color(0xFF2D7A4F),
    sharp:  Color(0xFFB85C1A),
    flat:   Color(0xFF2B5EA7),
    stringC:       Color(0xFFC0280A), // deep red, 5.3:1 on linen
    stringF:       Color(0xFF1A1C1E), // cool neutral near-black, 15.1:1 on linen
    stringNatural: Color(0xFF4E6A80), // cool slate blue — distinct from red C and near-black F, 4.8:1 on linen
  );

  // Blueprint — engineering paper, dark navy with cyan accents
  static const blueprint = TunerThemeData(
    id: 'blueprint',
    displayName: 'Blueprint',
    brightness: Brightness.dark,
    bg:           Color(0xFF1B2B45),
    surface:      Color(0xFF243855),
    surfaceHi:    Color(0xFF2E4870),
    surfaceRim:   Color(0xFF4A6890),
    textPrimary:   Color(0xFFE8F4FF),
    textSecondary: Color(0xFF8FB8D8),
    textDim:       Color(0xFF5A7FA0),
    inTune: Color(0xFF4DCEA0),
    sharp:  Color(0xFFFF8050),
    flat:   Color(0xFF60C0FF),
    stringC:       Color(0xFFE8604A), // coral-red, 5.1:1 on navy
    stringF:       Color(0xFF78C0F8), // vivid sky blue, 6.4:1 on navy
    stringNatural: Color(0xFFBEB090), // warm parchment — distinct from coral C and ice-blue F, 6.5:1 on navy
  );

  // Milk — minimal clean white, near-zero chroma
  static const milk = TunerThemeData(
    id: 'milk',
    displayName: 'Milk',
    brightness: Brightness.light,
    bg:           Color(0xFFFAFAF9),
    surface:      Color(0xFFFFFFFF),
    surfaceHi:    Color(0xFFF0EFE8),
    surfaceRim:   Color(0xFFD8D4CC),
    textPrimary:   Color(0xFF1A1A18),
    textSecondary: Color(0xFF5C5A54),
    textDim:       Color(0xFFA0A09C),
    inTune: Color(0xFF1A7A50),
    sharp:  Color(0xFFCC4420),
    flat:   Color(0xFF1D5CAA),
    stringC:       Color(0xFFB82408), // deep red, 5.5:1 on milk
    stringF:       Color(0xFF1A1C1E), // cool neutral near-black, 16.8:1 on milk
    stringNatural: Color(0xFF4E6A80), // cool slate blue — distinct from red C and near-black F, 5.2:1 on milk
  );

  // Phosphor — green phosphor CRT / terminal aesthetic
  static const phosphor = TunerThemeData(
    id: 'phosphor',
    displayName: 'Phosphor',
    brightness: Brightness.dark,
    bg:           Color(0xFF080E08),
    surface:      Color(0xFF0F180F),
    surfaceHi:    Color(0xFF152015),
    surfaceRim:   Color(0xFF204820),
    textPrimary:   Color(0xFF80FF80),
    textSecondary: Color(0xFF50C050),
    textDim:       Color(0xFF2A6030),
    inTune: Color(0xFF40FF40),
    sharp:  Color(0xFFFF8040),
    flat:   Color(0xFF40FFFF),
    stringC:       Color(0xFFFF6060), // bright coral, 9.2:1 on phosphor bg
    stringF:       Color(0xFF48D0A8), // vivid teal-green, 6.1:1 on phosphor bg
    stringNatural: Color(0xFFC4C090), // warm ivory — distinct from coral C and sage-green F, 12:1 on phosphor bg
  );

  // Void — pure OLED black, maximum battery savings, neon state colours
  static const void_ = TunerThemeData(
    id: 'void',
    displayName: 'Void',
    brightness: Brightness.dark,
    bg:           Color(0xFF000000),
    surface:      Color(0xFF161616), // clearly distinct from bg for sheets/cards
    surfaceHi:    Color(0xFF272727), // toggle tracks, inactive chips
    surfaceRim:   Color(0xFF404040), // dividers and borders — readable
    textPrimary:   Color(0xFFF0F0F0), // 17:1 on black
    textSecondary: Color(0xFFAAAAAA), // 9.1:1 on black
    textDim:       Color(0xFF606060), // 3.3:1 — decorative ticks only
    inTune: Color(0xFF00E676),
    sharp:  Color(0xFFFF6D00),
    flat:   Color(0xFF40C4FF),
    stringC:       Color(0xFFFF6060), // bright coral, 9.5:1 on pure black
    stringF:       Color(0xFF50D8B8), // vivid teal, 7.2:1 on pure black
    stringNatural: Color(0xFFB8B090), // warm parchment — distinct from coral C and mint F, 9.1:1 on pure black
  );


  // ── Wood themes ───────────────────────────────────────────────────────────
  //  Concert-harp finishes. Maple is the first-launch default for new installs
  //  (see resolveStartupTheme); existing installs keep Linen.

  // Maple — pale blonde grain, gold hardware
  static const maple = TunerThemeData(
    id: 'maple',
    displayName: 'Maple',
    brightness: Brightness.light,
    bg: Color(0xFFF4E6C8),
    surface: Color(0xFFFCF5E4),
    surfaceHi: Color(0xFFF6EAD0),
    surfaceRim: Color(0xFFD8BE88),
    textPrimary: Color(0xFF2B1709),
    textSecondary: Color(0xFF5E4020),
    textDim: Color(0xFF9C7E56),
    inTune: Color(0xFFA87B22),
    sharp: Color(0xFFA8322A),
    flat: Color(0xFF2F5A8C),
    stringC: Color(0xFFB3261E),
    stringF: Color(0xFF1E1A18),
    stringNatural: Color(0xFF7E5A2E),
    wood: WoodFinish(
      page: [Color(0xFFF4E6C8), Color(0xFFEAD6AE)],
      gauge: [Color(0xFFFCF3DF), Color(0xFFF2E3C2)],
      radialGauge: false,
      darkGrain: false,
      cardBorder: Color(0xFFB8892E),
      cardShadow: [
        BoxShadow(
          color: Color(0x2E5A320F),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
      chipBorder: Color(0xFFB8892E),
      gaugeBorder: Color(0xFFB8892E),
      gaugeInnerLine: Color(0x8CA07323),
      gaugeShadow: [
        BoxShadow(
          color: Color(0x405A320F),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
      gold: Color(0xFF9A7228),
      tick: Color(0xFF6B4A14),
      arc: Color(0xFF8A6420),
      zone: Color(0xB3C89632),
      tuneGreen: Color(0xFF3F7A4E),
      neck: [Color(0xFFD4AE72), Color(0xFFB08548)],
      neckDarkGrain: false,
      neckEdgeTop: Color(0xFFF2D98A),
      neckEdgeBottom: Color(0xFF9A7228),
      neckShadow: Color(0x4D5A3714),
      swatchCheck: Color(0xFF5E3F20),
    ),
  );

  // Spruce — golden honey grain, dark walnut neck
  static const spruce = TunerThemeData(
    id: 'spruce',
    displayName: 'Spruce',
    brightness: Brightness.light,
    bg: Color(0xFFE8CD9A),
    surface: Color(0xFFF7E9CC),
    surfaceHi: Color(0xFFF3E2C0),
    surfaceRim: Color(0xFFC9A15A),
    textPrimary: Color(0xFF2B1709),
    textSecondary: Color(0xFF5E3F20),
    textDim: Color(0xFF9A7A52),
    inTune: Color(0xFFA87B22),
    sharp: Color(0xFFA8322A),
    flat: Color(0xFF2F5A8C),
    stringC: Color(0xFFB3261E),
    stringF: Color(0xFF1E1A18),
    stringNatural: Color(0xFF7E5A2E),
    wood: WoodFinish(
      page: [Color(0xFFE8CD9A), Color(0xFFDDBC84)],
      gauge: [Color(0xFFF6E7C8), Color(0xFFEDD7AC)],
      radialGauge: false,
      darkGrain: false,
      cardBorder: Color(0xFFB8892E),
      cardShadow: [
        BoxShadow(
          color: Color(0x2E5A320F),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
      chipBorder: Color(0xFFB8892E),
      gaugeBorder: Color(0xFFB8892E),
      gaugeInnerLine: Color(0x8CA07323),
      gaugeShadow: [
        BoxShadow(
          color: Color(0x405A320F),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
      gold: Color(0xFF9A7228),
      tick: Color(0xFF6B4A14),
      arc: Color(0xFF8A6420),
      zone: Color(0xB3C89632),
      tuneGreen: Color(0xFF3F7A4E),
      neck: [Color(0xFF8A5A2E), Color(0xFF5E3818)],
      neckDarkGrain: true,
      neckEdgeTop: Color(0xFFD4AF5A),
      neckEdgeBottom: Color(0xFFD4AF5A),
      neckShadow: Color(0x59281405),
      swatchCheck: Color(0xFF5E3F20),
    ),
  );

  // Mahogany — red-brown grain, gold leaf
  static const mahogany = TunerThemeData(
    id: 'mahogany',
    displayName: 'Mahogany',
    brightness: Brightness.dark,
    bg: Color(0xFF4A1E14),
    surface: Color(0xFF4A2217),
    surfaceHi: Color(0xFF4A2217),
    surfaceRim: Color(0xFF7A3A26),
    textPrimary: Color(0xFFF8E6CE),
    textSecondary: Color(0xFFE2BD98),
    textDim: Color(0xFFA07458),
    inTune: Color(0xFFE0BA5A),
    sharp: Color(0xFFF29274),
    flat: Color(0xFF92B6E8),
    stringC: Color(0xFFF06A52),
    stringF: Color(0xFF9AB6DC),
    stringNatural: Color(0xFFF2D8AA),
    wood: WoodFinish(
      page: [Color(0xFF4A1E14), Color(0xFF2C110A)],
      gauge: [Color(0xFF5C2A1A), Color(0xFF32140C)],
      radialGauge: true,
      darkGrain: true,
      cardBorder: Color(0xFFB08236),
      cardShadow: [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
      chipBorder: Color(0xFFA87A30),
      gaugeBorder: Color(0xFFC9A04A),
      gaugeInnerLine: Color(0x73D4AF5A),
      gaugeShadow: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 30,
          offset: Offset(0, 12),
        ),
      ],
      gold: Color(0xFFE6C66E),
      tick: Color(0xFFE6C66E),
      arc: Color(0xFFE6C66E),
      zone: Color(0xBFF2D98A),
      tuneGreen: Color(0xFF7CC08A),
      neck: [Color(0xFF7A3520), Color(0xFF4A1C10)],
      neckDarkGrain: true,
      neckEdgeTop: Color(0xFFE6C66E),
      neckEdgeBottom: Color(0xFFE6C66E),
      neckShadow: Color(0x80000000),
      swatchCheck: Color(0xFFF6DE92),
    ),
  );

  // Walnut — deep brown grain, gold leaf
  static const walnut = TunerThemeData(
    id: 'walnut',
    displayName: 'Walnut',
    brightness: Brightness.dark,
    bg: Color(0xFF3A2414),
    surface: Color(0xFF3A2618),
    surfaceHi: Color(0xFF3A2618),
    surfaceRim: Color(0xFF6A4A28),
    textPrimary: Color(0xFFF5E6C6),
    textSecondary: Color(0xFFD6BB8A),
    textDim: Color(0xFF8E7250),
    inTune: Color(0xFFE0BA5A),
    sharp: Color(0xFFE57A60),
    flat: Color(0xFF86AEDF),
    stringC: Color(0xFFE8604A),
    stringF: Color(0xFF8AA8D0),
    stringNatural: Color(0xFFEBD3A4),
    wood: WoodFinish(
      page: [Color(0xFF3A2414), Color(0xFF24160C)],
      gauge: [Color(0xFF4A2F1A), Color(0xFF2A190D)],
      radialGauge: true,
      darkGrain: true,
      cardBorder: Color(0xFF9A7228),
      cardShadow: [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
      chipBorder: Color(0xFF9A7228),
      gaugeBorder: Color(0xFFC9A04A),
      gaugeInnerLine: Color(0x73D4AF5A),
      gaugeShadow: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 30,
          offset: Offset(0, 12),
        ),
      ],
      gold: Color(0xFFE6C66E),
      tick: Color(0xFFE6C66E),
      arc: Color(0xFFE6C66E),
      zone: Color(0xBFF2D98A),
      tuneGreen: Color(0xFF7CC08A),
      neck: [Color(0xFF6A4122), Color(0xFF3E2410)],
      neckDarkGrain: true,
      neckEdgeTop: Color(0xFFE6C66E),
      neckEdgeBottom: Color(0xFFE6C66E),
      neckShadow: Color(0x80000000),
      swatchCheck: Color(0xFFF6DE92),
    ),
  );

  /// Picker order: woods first, then the flat themes, per brightness.
  static const all = [
    maple,
    spruce,
    linen,
    milk,
    mahogany,
    walnut,
    blueprint,
    void_,
  ];

  /// Dark-mode toggle pairs each light theme with its dark counterpart.
  static const darkModePairs = {
    'maple': mahogany,
    'mahogany': maple,
    'spruce': walnut,
    'walnut': spruce,
    'linen': blueprint,
    'blueprint': linen,
    'milk': void_,
    'void': milk,
  };
}

// ── Backward-compat facades ───────────────────────────────────────────────────
//  AppColors and AppTextStyles delegate to TunerThemes.linen so un-themified
//  code (main.dart, harp_select_screen, etc.) continues to compile unchanged.

class AppColors {
  AppColors._();

  // Backgrounds — warm cream, light
  static const bg         = Color(0xFFF5F0E8);
  static const surface    = Color(0xFFFFFDF7);
  static const surfaceHi  = Color(0xFFEDE8DE);
  static const surfaceRim = Color(0xFFC8BBAA);

  // Gold spectrum — kept for backward-compat with other screens
  static const goldDeep   = Color(0xFFB08030);
  static const gold       = Color(0xFFD09828);
  static const goldBright = Color(0xFFEAB840);
  static const goldLight  = Color(0xFFF7CC60);
  static const goldPale   = Color(0xFFFFE090);

  // Text — ink → warm brown → warm dim
  static const textPrimary   = Color(0xFF1C1810);
  static const textSecondary = Color(0xFF6B5D4A);
  static const textDim       = Color(0xFFA89880);

  // Tuner states
  static const inTune = Color(0xFF2D7A4F);
  static const sharp  = Color(0xFFB85C1A);
  static const flat   = Color(0xFF2B5EA7);

  // Octave accent colors — retained, unused in current active screens
  static const octaveColors = [
    Color(0xFFB08040),
    Color(0xFFC89030),
    Color(0xFFD8A030),
    Color(0xFFE8B040),
    Color(0xFFF0C050),
    Color(0xFFF8D06A),
    Color(0xFFFFE090),
  ];

  static Color octaveColor(int octave) =>
      octaveColors[(octave - 1).clamp(0, octaveColors.length - 1)];
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      TunerThemes.linen.sans(size, weight: weight, color: color);

  static TextStyle label(double size, {Color? color}) =>
      TunerThemes.linen.label(size, color: color);
}

// ── Theme ────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      surface: AppColors.surface,
      primary: AppColors.inTune,
      secondary: AppColors.textSecondary,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.surface,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    useMaterial3: true,
    dividerColor: AppColors.surfaceRim,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
  );
}

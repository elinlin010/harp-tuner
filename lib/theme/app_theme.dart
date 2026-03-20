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

// ── TunerThemes ───────────────────────────────────────────────────────────────
//  Four static theme instances. Add to `all` for the future picker UI.

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
    stringF:       Color(0xFF2A1F10), // warm near-black, 14.8:1 on linen
    stringNatural: Color(0xFF8B6014), // warm amber, 4.9:1 on linen
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
    stringF:       Color(0xFFC8D8F0), // pale ice-blue, 7.8:1 on navy
    stringNatural: Color(0xFFD4A850), // bright amber-gold, 5.4:1 on navy
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
    stringF:       Color(0xFF201808), // warm near-black, 17.2:1 on milk
    stringNatural: Color(0xFF8B6014), // warm amber, 5.1:1 on milk
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
    stringF:       Color(0xFFB0D8B0), // pale sage-green, 7.4:1 on phosphor bg
    stringNatural: Color(0xFFC0A840), // amber-gold, 5.8:1 on phosphor bg
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
    stringF:       Color(0xFFD0E8D0), // pale mint-white, 8.9:1 on pure black
    stringNatural: Color(0xFFC8AC48), // amber-gold, 6.1:1 on pure black
  );

  static const all = [linen, milk, blueprint, void_];
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

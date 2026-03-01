import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
//  Dark walnut wood × antique gold

class AppColors {
  AppColors._();

  // Backgrounds — more stepped so cards pop off the page
  static const bg         = Color(0xFF0C0804);
  static const surface    = Color(0xFF201408);  // card bg — noticeably lighter than bg
  static const surfaceHi  = Color(0xFF2E1E0E);  // elevated elements
  static const surfaceRim = Color(0xFF4A3018);  // borders — visible

  // Gold spectrum
  static const goldDeep   = Color(0xFFB08030);
  static const gold       = Color(0xFFD09828);
  static const goldBright = Color(0xFFEAB840);
  static const goldLight  = Color(0xFFF7CC60);
  static const goldPale   = Color(0xFFFFE090);

  // Text
  static const textPrimary   = Color(0xFFFAF2DC);
  static const textSecondary = Color(0xFFCCAA7A);
  static const textDim       = Color(0xFF9A7A52);

  // Tuner states
  static const inTune  = Color(0xFF4DB87A);
  static const sharp   = Color(0xFFE05040);
  static const flat    = Color(0xFF5B8FE8);

  // Octave accent colors — all legible on dark bg
  static const octaveColors = [
    Color(0xFFB08040), // oct 1
    Color(0xFFC89030), // oct 2
    Color(0xFFD8A030), // oct 3
    Color(0xFFE8B040), // oct 4
    Color(0xFFF0C050), // oct 5
    Color(0xFFF8D06A), // oct 6
    Color(0xFFFFE090), // oct 7
  ];

  static Color octaveColor(int octave) =>
      octaveColors[(octave - 1).clamp(0, octaveColors.length - 1)];
}

// ── Typography ───────────────────────────────────────────────────────────────
//  Cormorant Garamond: decorative titles only
//  Outfit: all functional UI (notes, readouts, labels, buttons)

class AppTextStyles {
  AppTextStyles._();

  // Decorative — harp names, screen titles
  static TextStyle display(double size, {FontWeight weight = FontWeight.w300}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      );

  // Functional sans — note names, Hz, labels, buttons
  static TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      );

  // Monospaced — cent values, numeric readouts
  static TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  // Spaced label caps — section headers, mode toggles
  static TextStyle label(double size, {Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textSecondary,
        letterSpacing: 2.5,
      );
}

// ── Theme ────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.gold,
      secondary: AppColors.goldBright,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.bg,
    ),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    useMaterial3: true,
    dividerColor: AppColors.surfaceRim,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
  );
}

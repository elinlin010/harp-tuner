import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class PitchLightIndicator extends StatelessWidget {
  final double? cents;
  final bool isListening;
  final bool isStale;
  final TunerThemeData theme;

  const PitchLightIndicator({
    super.key,
    required this.cents,
    required this.isListening,
    this.isStale = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Round to nearest int to prevent flicker at the ±15 boundary
    final cRound   = cents?.round() ?? 0;
    final isFlat   = cents != null && cRound < -15;
    final isInTune = cents != null && cRound.abs() <= 15;
    final isSharp  = cents != null && cRound > 15;

    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final staleDur = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    final l10n = AppLocalizations.of(context)!;

    return AnimatedOpacity(
      opacity: isStale ? 0.35 : 1.0,
      duration: staleDur,
      child: Row(
        children: [
          Expanded(child: _Bulb(
            label: l10n.pitchLightFlatLabel,
            symbol: '♭',
            active: isFlat,
            color: theme.flat,
            size: 30,
            symbolSize: 14,
            theme: theme,
            animDuration: animDuration,
          )),
          Expanded(child: _Bulb(
            label: l10n.pitchLightInTuneLabel,
            symbol: '✓',
            active: isInTune,
            color: theme.inTune,
            size: 44,
            symbolSize: 20,
            theme: theme,
            animDuration: animDuration,
          )),
          Expanded(child: _Bulb(
            label: l10n.pitchLightSharpLabel,
            symbol: '♯',
            active: isSharp,
            color: theme.sharp,
            size: 30,
            symbolSize: 14,
            theme: theme,
            animDuration: animDuration,
          )),
        ],
      ),
    );
  }
}

class _Bulb extends StatelessWidget {
  final String label;
  final String symbol;
  final bool active;
  final Color color;
  final double size;
  final double symbolSize;
  final TunerThemeData theme;
  final Duration animDuration;

  const _Bulb({
    required this.label,
    required this.symbol,
    required this.active,
    required this.color,
    required this.size,
    required this.symbolSize,
    required this.theme,
    required this.animDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
      duration: animDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : theme.surfaceHi,
        border: Border.all(
          color: active
              ? color
              : theme.surfaceRim.withValues(alpha: 0.6),
          width: active ? 0 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: animDuration,
          style: theme.sans(
            symbolSize,
            weight: FontWeight.w700,
            color: active
                ? Colors.white.withValues(alpha: 0.95)
                : theme.textSecondary,
          ),
          child: Text(symbol),
        ),
      ),
    ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: animDuration,
          style: theme.sans(
            14,
            weight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? color : theme.textSecondary,
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

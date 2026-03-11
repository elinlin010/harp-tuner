import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PitchLightIndicator extends StatelessWidget {
  final double? cents;
  final bool isListening;
  final TunerThemeData theme;

  const PitchLightIndicator({
    super.key,
    required this.cents,
    required this.isListening,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isFlat   = cents != null && cents! < -5;
    final isInTune = cents != null && cents!.abs() <= 5;
    final isSharp  = cents != null && cents! > 5;

    final opacity = (!isListening && cents == null) ? 0.35 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Light(color: theme.flat,   active: isFlat,   label: '♭', theme: theme),
          const SizedBox(width: 24),
          _Light(color: theme.inTune, active: isInTune, label: '●', theme: theme),
          const SizedBox(width: 24),
          _Light(color: theme.sharp,  active: isSharp,  label: '♯', theme: theme),
        ],
      ),
    );
  }
}

class _Light extends StatelessWidget {
  final Color color;
  final bool active;
  final String label;
  final TunerThemeData theme;

  const _Light({
    required this.color,
    required this.active,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : theme.surfaceHi,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.70),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: theme.mono(11, color: theme.textDim)),
      ],
    );
  }
}

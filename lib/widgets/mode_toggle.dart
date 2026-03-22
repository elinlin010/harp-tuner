import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';

class ModeToggle extends StatelessWidget {
  final TunerMode mode;
  final ValueChanged<TunerMode> onChanged;
  final TunerThemeData theme;

  const ModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.surfaceHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.surfaceRim, width: 0.5),
      ),
      child: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tab(
              // Tuning fork concept: graphic_eq shows frequency bars (pitch analysis)
              icon: Icons.graphic_eq_rounded,
              label: l10n.modeAuto,
              active: mode == TunerMode.auto,
              onTap: () => onChanged(TunerMode.auto),
              theme: theme,
            ),
            _Tab(
              icon: Icons.volume_up_rounded,
              label: l10n.modeReference,
              active: mode == TunerMode.reference,
              onTap: () => onChanged(TunerMode.reference),
              theme: theme,
            ),
          ],
        );
      }),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: animDuration,
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 12 : 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: active ? theme.inTune.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: active
              ? Border.all(color: theme.inTune.withValues(alpha: 0.45), width: 0.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? theme.inTune : theme.textDim,
            ),
            // Label slides in/out via ClipRect + AnimatedAlign widthFactor.
            // widthFactor 0→1 collapses/expands the label width while the
            // AnimatedContainer above simultaneously adjusts the padding,
            // giving a single smooth pill-resize animation.
            ClipRect(
              child: AnimatedAlign(
                duration: animDuration,
                curve: Curves.easeInOut,
                alignment: Alignment.centerLeft,
                widthFactor: active ? 1.0 : 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: theme.label(12, color: theme.inTune),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

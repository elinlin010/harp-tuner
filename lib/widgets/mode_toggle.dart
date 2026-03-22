import 'package:flutter/material.dart';

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: 'AUTO',
            active: mode == TunerMode.auto,
            onTap: () => onChanged(TunerMode.auto),
            theme: theme,
          ),
          _Tab(
            label: 'REFERENCE',
            active: mode == TunerMode.reference,
            onTap: () => onChanged(TunerMode.reference),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: animDuration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? theme.inTune.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: active
              ? Border.all(color: theme.inTune.withValues(alpha: 0.45), width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: theme.label(
            12,
            color: active ? theme.inTune : theme.textDim,
          ),
        ),
      ),
    );
  }
}

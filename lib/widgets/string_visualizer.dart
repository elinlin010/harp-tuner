import 'package:flutter/material.dart';

import '../models/harp_string_model.dart';
import '../theme/app_theme.dart';

const _kItemWidth = 52.0;

class StringVisualizer extends StatefulWidget {
  final List<HarpStringModel> strings;
  final HarpStringModel? activeString;
  final TunerThemeData theme;

  const StringVisualizer({
    super.key,
    required this.strings,
    required this.activeString,
    required this.theme,
  });

  @override
  State<StringVisualizer> createState() => _StringVisualizerState();
}

class _StringVisualizerState extends State<StringVisualizer> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(StringVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.activeString != old.activeString &&
        widget.activeString != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_scrollCtrl.hasClients) return;
    final idx =
        widget.strings.indexWhere((s) => s == widget.activeString);
    if (idx < 0) return;
    final viewport = _scrollCtrl.position.viewportDimension;
    final target = idx * _kItemWidth - viewport / 2 + _kItemWidth / 2;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _stringColor(NoteName note) => switch (note) {
    NoteName.c => widget.theme.stringC,
    NoteName.f => widget.theme.stringF,
    _ => widget.theme.stringNatural,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        controller: _scrollCtrl,
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.strings.length,
        itemExtent: _kItemWidth,
        itemBuilder: (ctx, i) {
          final s = widget.strings[i];
          final isActive = s == widget.activeString;
          return _StringCell(
            string: s,
            isActive: isActive,
            stringColor: _stringColor(s.note),
            theme: widget.theme,
          );
        },
      ),
    );
  }
}

// ── Single string cell ─────────────────────────────────────────────────────────

class _StringCell extends StatelessWidget {
  final HarpStringModel string;
  final bool isActive;
  final Color stringColor;
  final TunerThemeData theme;

  const _StringCell({
    required this.string,
    required this.isActive,
    required this.stringColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // String + glow
        SizedBox(
          width: _kItemWidth,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 28 : 0,
                height: isActive ? 52 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: stringColor.withValues(alpha: 0.55),
                            blurRadius: 18,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: stringColor.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              // String line
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 4.0 : 2.5,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? stringColor
                      : stringColor.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Label (note + octave, e.g. "C4")
        AnimatedDefaultTextStyle(
          duration: animDuration,
          style: theme.sans(
            isActive ? 13 : 12,
            weight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? stringColor : theme.textSecondary,
          ),
          child: Text(string.label, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}


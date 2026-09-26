import 'package:flutter/material.dart';

import '../models/harp_string_model.dart';
import '../theme/app_theme.dart';
import 'wood_surface.dart';

const _kItemWidth = 52.0;

// Neck rail and tuning-pin geometry within the 116px row.
const _kNeckTop = 12.0;
const _kNeckHeight = 14.0;
const _kPinTop = 9.0;
const _kPinSize = 9.0;
const _kStringTop = _kPinTop + _kPinSize - 3; // starts 3px under the pin
const _kStringHeight = 70.0;

class StringVisualizer extends StatefulWidget {
  final List<HarpStringModel> strings;
  final HarpStringModel? activeString;

  /// Callback fired when a string cell is tapped (reference mode only).
  /// Null in auto mode — taps are disabled.
  final void Function(HarpStringModel)? onTap;

  final TunerThemeData theme;

  const StringVisualizer({
    super.key,
    required this.strings,
    required this.activeString,
    this.onTap,
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
    final idx = widget.strings.indexWhere((s) => s == widget.activeString);
    if (idx < 0) return;
    final position = _scrollCtrl.position;
    final viewport = position.viewportDimension;
    // Cell edges in scroll coordinates (the list has 20px leading padding).
    final cellStart = 20 + idx * _kItemWidth;
    final cellEnd = cellStart + _kItemWidth;

    final double target;
    if (widget.onTap != null) {
      // Reference mode: the active string is the one the user just tapped,
      // so it is already under their finger. Recentring would slide it away
      // mid-tap. Only nudge it in when it sits partly off an edge.
      const margin = 12.0;
      if (cellStart < position.pixels + margin) {
        target = cellStart - margin;
      } else if (cellEnd > position.pixels + viewport - margin) {
        target = cellEnd - viewport + margin;
      } else {
        return;
      }
    } else {
      // Auto mode: the detected string may be anywhere — centre it.
      target = cellStart + _kItemWidth / 2 - viewport / 2;
    }
    _scrollCtrl.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _stringColor(NoteName note) {
    // Each theme (light and dark) defines its own contrast-verified string
    // palette in TunerThemeData.stringC/F/Natural. Use them directly.
    return switch (note) {
      NoteName.c => widget.theme.stringC,
      NoteName.f => widget.theme.stringF,
      _ => widget.theme.stringNatural,
    };
  }

  @override
  Widget build(BuildContext context) {
    final neck = widget.theme.neck;
    final list = ListView.builder(
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
          onTap: widget.onTap != null ? () => widget.onTap!(s) : null,
        );
      },
    );

    final railFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: neck.colors,
    );
    final railEdges = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: neck.edgeTop, width: 1),
          bottom: BorderSide(color: neck.edgeBottom, width: 1),
        ),
      ),
    );

    // The strings hang from a harp neck rail that stays put while the
    // strings scroll beneath it. Wood themes add grain to the rail.
    return SizedBox(
      height: 116,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _kNeckTop,
            height: _kNeckHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: neck.grain ? null : railFill,
                boxShadow: [
                  BoxShadow(
                    color: neck.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: neck.grain
                  ? WoodSurface(
                      gradient: railFill,
                      dark: neck.darkGrain,
                      child: railEdges,
                    )
                  : railEdges,
            ),
          ),
          Positioned.fill(child: list),
        ],
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
  final VoidCallback? onTap;

  const _StringCell({
    required this.string,
    required this.isActive,
    required this.stringColor,
    required this.theme,
    this.onTap,
  });

  bool get _isDark => theme.brightness == Brightness.dark;

  // Landmark strings (C, F) stay more opaque than naturals in both modes.
  double get _inactiveAlpha {
    return switch (string.note) {
      NoteName.c || NoteName.f => 0.92,
      _ => 0.65,
    };
  }

  // Active-string glow: a soft light that hugs the string and fades in and
  // out. It keeps a fixed size and only animates opacity; growing it from
  // zero read as a box popping in. It lights up quickly and fades out
  // slowly, like a plucked string dying away.
  Widget _glow(double height, bool reduceMotion) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.0,
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: isActive ? 280 : 520),
      curve: isActive ? Curves.easeOutCubic : Curves.easeInOut,
      child: Container(
        width: 4,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          // The prototype's string glow geometry (0 0 18px 6px, 0 0 32px 10px), with
          // a denser outer ring (60%) so the hit string reads at a glance.
          boxShadow: [
            BoxShadow(
              color: stringColor.withValues(alpha: 0.60),
              blurRadius: 18,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: stringColor.withValues(alpha: 0.60),
              blurRadius: 32,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(Duration animDuration) => AnimatedDefaultTextStyle(
    duration: animDuration,
    style: theme.sans(
      isActive ? 13 : 12,
      weight: isActive ? FontWeight.w700 : FontWeight.w400,
      color: isActive
          ? stringColor
          : (!_isDark &&
                (string.note == NoteName.c || string.note == NoteName.f))
          ? stringColor.withValues(alpha: 0.70)
          : theme.textSecondary,
    ),
    child: Text(string.label, textAlign: TextAlign.center),
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final neck = theme.neck;

    // A tuning pin on the neck, the string hanging from it.
    final cell = Column(
      children: [
        SizedBox(
          width: _kItemWidth,
          height: _kStringTop + _kStringHeight + 3,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Glow
              Positioned(
                top: _kStringTop,
                child: _glow(_kStringHeight, reduceMotion),
              ),
              // String line
              Positioned(
                top: _kStringTop,
                child: AnimatedContainer(
                  duration: animDuration,
                  width: isActive ? 4.0 : 3.0,
                  height: _kStringHeight,
                  decoration: BoxDecoration(
                    color: isActive
                        ? stringColor
                        : stringColor.withValues(alpha: _inactiveAlpha),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Tuning pin
              Positioned(
                top: _kPinTop,
                child: Container(
                  width: _kPinSize,
                  height: _kPinSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: neck.pin,
                    boxShadow: [neck.pinShadow],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Label (note + octave). Light mode: C and F labels keep a tint of
        // their string colour when inactive to reinforce the landmark; dark
        // mode uses textSecondary for all inactive labels.
        _label(animDuration),
      ],
    );

    return _tappable(cell);
  }

  // In reference mode, wrap with a tap affordance.
  Widget _tappable(Widget cell) {
    if (onTap == null) return cell;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cell,
    );
  }
}

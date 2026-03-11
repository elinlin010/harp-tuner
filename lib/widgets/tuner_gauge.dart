import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class TunerGauge extends StatefulWidget {
  final double? cents;
  final String? noteName;
  final bool isListening;
  final TunerThemeData theme;

  const TunerGauge({
    super.key,
    this.cents,
    this.noteName,
    required this.isListening,
    required this.theme,
  });

  @override
  State<TunerGauge> createState() => _TunerGaugeState();
}

class _TunerGaugeState extends State<TunerGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _stateColor {
    final c = widget.cents;
    if (c == null) return widget.theme.textDim;
    if (c.abs() <= 5) return widget.theme.inTune;
    if (c > 0) return widget.theme.sharp;
    return widget.theme.flat;
  }

  @override
  Widget build(BuildContext context) {
    final hasSignal = widget.cents != null;

    // LayoutBuilder gives us the full Expanded height AND width to work with.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;

        // Arc: prefer semicircle (width/2 + 16), but cap at 50% of height
        // so the readout always has room below.
        final arcH = min(maxW / 2 + 16, maxH * 0.50);

        return Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Arc ─────────────────────────────────────────────────────────
            SizedBox(
              height: arcH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (ctx, child) => CustomPaint(
                        painter: _ArcPainter(
                          cents: widget.cents,
                          stateColor: _stateColor,
                          isListening: widget.isListening,
                          pulse: _pulseCtrl.value,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 14,
                    child: _ScaleLabel('−50', theme: widget.theme),
                  ),
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Center(child: _ScaleLabel('0', theme: widget.theme)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 14,
                    child: _ScaleLabel('+50', theme: widget.theme),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Readout — both states live here simultaneously; cross-fade
            //    between them so the layout never shifts/bounces.
            Expanded(
              child: Stack(
                children: [
                  // Idle state — fades out when a note is detected
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: hasSignal ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: _IdleReadout(
                          isListening: widget.isListening,
                          pulse: _pulseCtrl,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                  // Signal state — fades in when a note is detected
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: hasSignal ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: _SignalReadout(
                          cents: widget.cents ?? 0,
                          noteName: widget.noteName ?? '—',
                          stateColor: _stateColor,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Scale label ───────────────────────────────────────────────────────────────

class _ScaleLabel extends StatelessWidget {
  final String text;
  final TunerThemeData theme;

  const _ScaleLabel(this.text, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.sans(13, color: theme.textDim),
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double? cents;
  final Color stateColor;
  final bool isListening;
  final double pulse;
  final TunerThemeData theme;

  _ArcPainter({
    required this.cents,
    required this.stateColor,
    required this.isListening,
    required this.pulse,
    required this.theme,
  });

  static const _startAngle = pi;
  static const _sweep = pi;

  double _centsToAngle(double c) =>
      _startAngle + _sweep * ((c + 50) / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.height - 16;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Track ────────────────────────────────────────────────────────────────
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = theme.surfaceRim,
    );

    // ── In-tune zone ─────────────────────────────────────────────────────────
    final zoneStart = _centsToAngle(-5);
    final zoneSweep = _sweep * (10 / 100);
    canvas.drawArc(
      arcRect,
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = theme.inTune.withValues(alpha: 0.35),
    );

    // ── Ticks ─────────────────────────────────────────────────────────────────
    for (int c = -50; c <= 50; c += 5) {
      final isMajor = c % 10 == 0;
      final angle = _centsToAngle(c.toDouble());
      final outer = r - 2;
      final inner = r - (isMajor ? 20.0 : 10.0);
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        Paint()
          ..color = isMajor ? theme.textSecondary : theme.textDim
          ..strokeWidth = isMajor ? 2.0 : 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Needle ───────────────────────────────────────────────────────────────
    final hasSignal = cents != null;
    final angle = hasSignal ? _centsToAngle(cents!) : _centsToAngle(0);
    final needleLen = r - 18;
    final tipX = cx + needleLen * cos(angle);
    final tipY = cy + needleLen * sin(angle);

    if (hasSignal) {
      // Soft halo
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor.withValues(alpha: 0.15 + pulse * 0.10)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Pivot dot
    canvas.drawCircle(
      Offset(cx, cy),
      hasSignal ? 6.0 : 4.0,
      Paint()
        ..color = hasSignal ? stateColor : theme.textDim.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // Idle pulse ring
    if (isListening && !hasSignal) {
      canvas.drawCircle(
        Offset(cx, cy),
        16 + pulse * 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = theme.textSecondary.withValues(alpha: 0.15 + pulse * 0.20),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.cents != cents ||
      old.stateColor != stateColor ||
      old.isListening != isListening ||
      old.pulse != pulse ||
      old.theme != theme;
}

// ── Idle readout ──────────────────────────────────────────────────────────────

class _IdleReadout extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulse;
  final TunerThemeData theme;

  const _IdleReadout({
    required this.isListening,
    required this.pulse,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: pulse,
      builder: (ctx, child) => Opacity(
        opacity: isListening ? (0.55 + pulse.value * 0.45) : 1.0,
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening ? Icons.mic_rounded : Icons.music_note_rounded,
            size: 48,
            color: isListening ? theme.textSecondary : theme.textDim,
          ),
          const SizedBox(height: 16),
          Text(
            isListening ? l10n.gaugeListeningMsg : l10n.gaugeTapToBeginMsg,
            style: theme.sans(22, weight: FontWeight.w500, color: theme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Signal readout ────────────────────────────────────────────────────────────

class _SignalReadout extends StatelessWidget {
  final double cents;
  final String noteName;
  final Color stateColor;
  final TunerThemeData theme;

  const _SignalReadout({
    required this.cents,
    required this.noteName,
    required this.stateColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final centsStr =
        cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note name — big serif
        Text(
          noteName,
          style: theme.sans(100, weight: FontWeight.w400).copyWith(height: 1),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Cents deviation — colored to match state
        Text(
          '$centsStr¢',
          style: theme.sans(18, weight: FontWeight.w500,
              color: stateColor.withValues(alpha: 0.75)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

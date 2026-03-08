import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TunerGauge extends StatefulWidget {
  final double? cents;
  final String? noteName;
  final double? detectedHz;
  final bool isListening;
  final TunerThemeData theme;

  const TunerGauge({
    super.key,
    this.cents,
    this.noteName,
    this.detectedHz,
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

  String get _tuneWord {
    final c = widget.cents;
    if (c == null) return '';
    if (c.abs() <= 5) return 'IN TUNE';
    if (c > 0) return 'SHARP';
    return 'FLAT';
  }

  @override
  Widget build(BuildContext context) {
    final hasSignal = widget.cents != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 148,
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
                top: 4,
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
        if (!hasSignal)
          _IdleReadout(
            isListening: widget.isListening,
            pulse: _pulseCtrl,
            theme: widget.theme,
          )
        else
          _SignalReadout(
            cents: widget.cents!,
            noteName: widget.noteName ?? '—',
            detectedHz: widget.detectedHz,
            stateColor: _stateColor,
            tuneWord: _tuneWord,
            theme: widget.theme,
          ),
      ],
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
      style: theme.mono(10, color: theme.textDim),
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
        ..strokeWidth = 1.5
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
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = theme.inTune.withValues(alpha: 0.30),
    );

    // ── Ticks ─────────────────────────────────────────────────────────────────
    for (int c = -50; c <= 50; c += 5) {
      final isMajor = c % 10 == 0;
      final angle = _centsToAngle(c.toDouble());
      final outer = r - 2;
      final inner = r - (isMajor ? 14.0 : 7.0);
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        Paint()
          ..color = isMajor ? theme.textSecondary : theme.textDim
          ..strokeWidth = isMajor ? 1.5 : 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Needle ───────────────────────────────────────────────────────────────
    final hasSignal = cents != null;
    final angle = hasSignal ? _centsToAngle(cents!) : _centsToAngle(0);
    final needleLen = r - 14;
    final tipX = cx + needleLen * cos(angle);
    final tipY = cy + needleLen * sin(angle);

    if (hasSignal) {
      // Soft halo
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor.withValues(alpha: 0.12 + pulse * 0.08)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Pivot dot
    canvas.drawCircle(
      Offset(cx, cy),
      hasSignal ? 3.5 : 3.0,
      Paint()
        ..color = hasSignal ? stateColor : theme.textDim.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // Idle pulse ring
    if (isListening && !hasSignal) {
      canvas.drawCircle(
        Offset(cx, cy),
        12 + pulse * 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
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
    return AnimatedBuilder(
      animation: pulse,
      builder: (ctx, child) => Opacity(
        opacity: isListening ? (0.55 + pulse.value * 0.45) : 1.0,
        child: child,
      ),
      child: Text(
        isListening ? 'Listening for a note…' : 'Play a note to begin tuning',
        style: theme.display(16, weight: FontWeight.w400, color: theme.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Signal readout ────────────────────────────────────────────────────────────

class _SignalReadout extends StatelessWidget {
  final double cents;
  final String noteName;
  final double? detectedHz;
  final Color stateColor;
  final String tuneWord;
  final TunerThemeData theme;

  const _SignalReadout({
    required this.cents,
    required this.noteName,
    required this.detectedHz,
    required this.stateColor,
    required this.tuneWord,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final centsStr =
        cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note name — Libre Baskerville, large, ink
        Text(
          noteName,
          style: theme.display(72, weight: FontWeight.w400)
              .copyWith(height: 1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Cents — JetBrains Mono, state-colored
            Text(
              '$centsStr¢',
              style: theme.mono(22, weight: FontWeight.w500, color: stateColor),
            ),
            if (tuneWord.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                tuneWord,
                style: theme.label(9, color: stateColor.withValues(alpha: 0.80)),
              ),
            ],
            if (detectedHz != null) ...[
              const SizedBox(width: 10),
              Text(
                '${detectedHz!.toStringAsFixed(1)} Hz',
                style: theme.mono(11, color: theme.textSecondary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

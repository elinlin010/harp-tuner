import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

// Shared sweep constant — used by both layout (arcH) and painter (geometry)
const _kGaugeSweep = 1.4; // ~80° — flat meter look matching reference
// Horizontal margin so edge labels/ticks don't clip
const _kGaugeChordInset = 100.0;

class TunerGauge extends StatefulWidget {
  final double? cents;
  final String? noteName;
  final bool isListening;
  final bool isStale;
  final TunerThemeData theme;

  const TunerGauge({
    super.key,
    this.cents,
    this.noteName,
    required this.isListening,
    this.isStale = false,
    required this.theme,
  });

  @override
  State<TunerGauge> createState() => _TunerGaugeState();
}

class _TunerGaugeState extends State<TunerGauge>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _needleCtrl;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 20.0,  // ratio ≈ 0.74 — near-critically damped, minimal overshoot
  );

  // EMA smoothing for the spring target — reduces micro-wobble from noisy pitch
  static const _kSmoothAlpha = 0.3; // 0 = frozen, 1 = no smoothing
  double? _smoothedTarget;

  // Velocity tracking for smooth spring hand-offs (no abrupt momentum reset)
  double _needleVelocity = 0.0;
  double _prevNeedleValue = 0.0;
  double _prevListenTime  = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Wide bounds to allow spring overshoot beyond ±50 cents
    _needleCtrl = AnimationController(
      vsync: this,
      lowerBound: -100.0,
      upperBound: 100.0,
      value: 0.0,
    );
    _needleCtrl.addListener(() {
      final now = DateTime.now().microsecondsSinceEpoch / 1e6;
      final dt  = now - _prevListenTime;
      if (dt > 0.001 && dt < 0.2) {
        _needleVelocity = (_needleCtrl.value - _prevNeedleValue) / dt;
      }
      _prevNeedleValue = _needleCtrl.value;
      _prevListenTime  = now;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0; // full opacity when reduced motion
      _needleCtrl.stop();
      if (widget.cents != null) {
        _needleCtrl.value = widget.cents!.clamp(-50.0, 50.0);
      }
    } else if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TunerGauge old) {
    super.didUpdateWidget(old);
    if (MediaQuery.disableAnimationsOf(context)) {
      if (widget.cents != null) {
        _needleCtrl.value = widget.cents!.clamp(-50.0, 50.0);
      } else {
        _needleCtrl.value = 0.0;
      }
      return;
    }

    if (widget.cents != old.cents) {
      if (widget.cents != null) {
        final raw = widget.cents!.clamp(-50.0, 50.0);
        // EMA smoothing: dampens micro-wobble from noisy pitch input
        _smoothedTarget = (_smoothedTarget == null)
            ? raw
            : _kSmoothAlpha * raw + (1 - _kSmoothAlpha) * _smoothedTarget!;
        _needleCtrl.animateWith(
          SpringSimulation(_spring, _needleCtrl.value, _smoothedTarget!, _needleVelocity),
        );
      } else {
        // clearPitch fired (stop button) — spring needle back to center
        _smoothedTarget = null;
        _needleCtrl.animateWith(
          SpringSimulation(_spring, _needleCtrl.value, 0.0, _needleVelocity),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _needleCtrl.dispose();
    super.dispose();
  }

  Color get _stateColor {
    if (widget.cents == null) return widget.theme.textDim;
    final c = _needleCtrl.value;
    if (c.abs() <= 15) return widget.theme.inTune;
    if (c > 0) return widget.theme.sharp;
    return widget.theme.flat;
  }

  @override
  Widget build(BuildContext context) {
    final hasSignal = widget.cents != null;
    final needlePos = _needleCtrl.value;
    // Show needle whenever signal present OR it's still animating back
    final showNeedle = hasSignal || needlePos.abs() > 1.0;

    final animDur = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return AnimatedOpacity(
      opacity: widget.isStale ? 0.40 : 1.0,
      duration: animDur,
      child: LayoutBuilder(
      builder: (ctx, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        // arcH is derived from the arc geometry so the full arc + pivot always fits.
        // r = radius; pivot is at bottom; arc top is r above pivot.
        // Add 44px: 30 for ticks/labels above arc + 14 for pivot dot below.
        final r = (maxW - _kGaugeChordInset) / (2 * sin(_kGaugeSweep / 2));
        final arcH = (r + 44).clamp(0.0, maxH * 0.65);

        return Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Readout ─────────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: hasSignal ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.center,
                          child: _IdleReadout(
                            isListening: widget.isListening,
                            pulse: _pulseCtrl,
                            theme: widget.theme,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: hasSignal ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _SignalReadout(
                              noteName: widget.noteName ?? '—',
                              theme: widget.theme,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Arc ─────────────────────────────────────────────────────
              SizedBox(
                height: arcH,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _needleCtrl]),
                  builder: (ctx, child) => CustomPaint(
                    size: Size(maxW, arcH),
                    painter: _ArcPainter(
                      needlePos: needlePos,
                      showNeedle: showNeedle,
                      stateColor: _stateColor,
                      isListening: widget.isListening,
                      hasSignal: hasSignal,
                      pulse: _pulseCtrl.value,
                      theme: widget.theme,
                    ),
                  ),
                ),
              ),
            ],
        );
      },
    ),  // LayoutBuilder
    );  // AnimatedOpacity
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double needlePos;
  final bool showNeedle;
  final Color stateColor;
  final bool isListening;
  final bool hasSignal;
  final double pulse;
  final TunerThemeData theme;

  _ArcPainter({
    required this.needlePos,
    required this.showNeedle,
    required this.stateColor,
    required this.isListening,
    required this.hasSignal,
    required this.pulse,
    required this.theme,
  });

  static const _sweep = _kGaugeSweep;
  static const _startAngle = pi + (pi - _sweep) / 2;

  double _centsToAngle(double c) =>
      _startAngle + _sweep * ((c + 50) / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 6;
    // Width-based radius — matches the arcH calculation in build()
    final r = (size.width - _kGaugeChordInset) / (2 * sin(_sweep / 2));
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final tickColor = theme.textPrimary;
    final labelColor = theme.textSecondary;

    // ── Track (the arc line) ──────────────────────────────────────────────
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = tickColor.withValues(alpha: 0.8),
    );

    // ── In-tune zone (thicker highlight on the arc) ──────────────────────
    final zoneStart = _centsToAngle(-15);
    final zoneSweep = _sweep * (30 / 100);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r + 1),
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = theme.inTune.withValues(alpha: 0.4),
    );

    // ── Ticks — OUTSIDE the arc (away from pivot), 3-tier density ────────
    // Every 1¢: short (4px), every 5¢: medium (9px), every 10¢: tall (16px)
    for (int c = -50; c <= 50; c += 1) {
      if (c == 0) continue; // 0 gets a special centerline
      final isMajor  = c % 10 == 0;
      final isMedium = c % 5 == 0;
      final angle = _centsToAngle(c.toDouble());

      final double tickLen;
      final double tickWidth;
      final double tickAlpha;
      if (isMajor) {
        tickLen = 16; tickWidth = 1.6; tickAlpha = 0.9;
      } else if (isMedium) {
        tickLen = 9; tickWidth = 1.2; tickAlpha = 0.7;
      } else {
        tickLen = 4; tickWidth = 0.8; tickAlpha = 0.45;
      }

      // Ticks radiate outward: from the arc line (r) to r + tickLen
      final inner = r;
      final outer = r + tickLen;
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        Paint()
          ..color = tickColor.withValues(alpha: tickAlpha)
          ..strokeWidth = tickWidth
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Center "0" reference line — full length from pivot through arc,
    //    always visible as the resting position guide
    final zeroAngle = _centsToAngle(0);
    canvas.drawLine(
      Offset(cx, cy),                                              // pivot
      Offset(cx + (r + 18) * cos(zeroAngle), cy + (r + 18) * sin(zeroAngle)), // above arc
      Paint()
        ..color = tickColor.withValues(alpha: showNeedle ? 0.18 : 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── In-tune triangles (▼ at ±15¢, above ticks, pointing toward arc) ─
    for (final c in [-15.0, 15.0]) {
      final a = _centsToAngle(c);
      // Triangle tip touches the top of the tallest tick area
      final tipR  = r + 18;
      final baseR = r + 28;
      final tipX  = cx + tipR * cos(a);
      final tipY  = cy + tipR * sin(a);
      // Perpendicular direction for the base width
      final perpX = -sin(a);
      final perpY = cos(a);
      final baseX = cx + baseR * cos(a);
      final baseY = cy + baseR * sin(a);
      final path = Path()
        ..moveTo(tipX, tipY) // tip (pointing toward arc)
        ..lineTo(baseX + perpX * 5, baseY + perpY * 5)
        ..lineTo(baseX - perpX * 5, baseY - perpY * 5)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.inTune.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Scale labels (outside ticks) ─────────────────────────────────────
    _drawLabel(canvas, '−50', _centsToAngle(-47), cx, cy, r + 24, labelColor);
    _drawLabel(canvas, '0', _centsToAngle(0), cx, cy, r + 30, labelColor);
    _drawLabel(canvas, '+50', _centsToAngle(47), cx, cy, r + 24, labelColor);
    // "CENT" unit label near +50 (like the reference tuner)
    _drawLabel(canvas, 'CENT', _centsToAngle(40), cx, cy, r + 24, labelColor);

    // ── Needle ────────────────────────────────────────────────────────────
    final angle = _centsToAngle(needlePos.clamp(-50.0, 50.0));
    final needleLen = r - 4; // needle tip reaches just below the arc
    final tipNX = cx + needleLen * cos(angle);
    final tipNY = cy + needleLen * sin(angle);

    if (showNeedle) {
      // Soft halo
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipNX, tipNY),
        Paint()
          ..color = stateColor.withValues(alpha: 0.10 + pulse * 0.06)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipNX, tipNY),
        Paint()
          ..color = stateColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Pivot dot — always on the center line
    canvas.drawCircle(
      Offset(cx, cy),
      showNeedle ? 5.0 : 4.0,
      Paint()
        ..color = showNeedle
            ? stateColor
            : tickColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // Idle pulse ring — concentric with pivot dot, reinforcing center line
    if (isListening && !hasSignal) {
      canvas.drawCircle(
        Offset(cx, cy),
        12 + pulse * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = tickColor.withValues(alpha: 0.12 + pulse * 0.15),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, double angle,
      double cx, double cy, double labelR, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.sans(13, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = cx + labelR * cos(angle) - tp.width / 2;
    final ly = cy + labelR * sin(angle) - tp.height / 2;
    tp.paint(canvas, Offset(lx, ly));
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.needlePos != needlePos ||
      old.showNeedle != showNeedle ||
      old.stateColor != stateColor ||
      old.isListening != isListening ||
      old.hasSignal != hasSignal ||
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
        opacity: isListening ? (0.80 + pulse.value * 0.20) : 1.0,
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
            style: theme.sans(22,
                weight: FontWeight.w500, color: theme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Signal readout ────────────────────────────────────────────────────────────

class _SignalReadout extends StatelessWidget {
  final String noteName;
  final TunerThemeData theme;

  const _SignalReadout({
    required this.noteName,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Parse e.g. "B♭4" → letter "B", accidental "♭", octave "4"
    final match = RegExp(r'^([A-G])(♭|♯)?(\d+)?$').firstMatch(noteName);
    final noteLetter = match?.group(1) ?? noteName;
    final noteAcc    = match?.group(2) ?? '';
    final noteOctave = match?.group(3) ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          noteLetter,
          style: theme.sans(100, weight: FontWeight.w400).copyWith(height: 1),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (noteAcc.isNotEmpty)
                Text(
                  noteAcc,
                  style: theme.sans(42, weight: FontWeight.w400).copyWith(height: 1),
                ),
              if (noteOctave.isNotEmpty)
                Text(
                  noteOctave,
                  style: theme.sans(30, weight: FontWeight.w300, color: theme.textSecondary).copyWith(height: 1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

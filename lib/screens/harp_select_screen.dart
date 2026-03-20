import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/harp_type.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import 'tuner_screen.dart';

class HarpSelectScreen extends ConsumerStatefulWidget {
  const HarpSelectScreen({super.key});

  @override
  ConsumerState<HarpSelectScreen> createState() => _HarpSelectScreenState();
}

class _HarpSelectScreenState extends ConsumerState<HarpSelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _select(HarpType type) {
    ref.read(tunerProvider.notifier).setSelectedHarp(type);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const TunerScreen(),
        transitionsBuilder: (ctx, anim, a2, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                _Header(),
                const SizedBox(height: 48),
                for (final type in HarpType.values) ...[
                  _HarpCard(
                    type: type,
                    delay: HarpType.values.indexOf(type) * 0.12,
                    controller: _fadeCtrl,
                    onTap: () => _select(type),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'SELECT YOUR INSTRUMENT',
                    style: AppTextStyles.label(13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HARP',
          style: AppTextStyles.label(12, color: AppColors.gold),
        ),
        const SizedBox(height: 4),
        Text(
          'Tuner',
          style: AppTextStyles.sans(52, weight: FontWeight.w300),
        ),
        const SizedBox(height: 8),
        Container(height: 1, width: 60, color: AppColors.goldDeep),
      ],
    );
  }
}

class _HarpCard extends StatelessWidget {
  final HarpType type;
  final double delay;
  final AnimationController controller;
  final VoidCallback onTap;

  const _HarpCard({
    required this.type,
    required this.delay,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = ((controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final opacity = Curves.easeOut.transform(progress);
        final offset = (1.0 - opacity) * 24.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: child,
          ),
        );
      },
      child: _CardContent(type: type, onTap: onTap),
    );
  }
}

class _CardContent extends StatefulWidget {
  final HarpType type;
  final VoidCallback onTap;

  const _CardContent({required this.type, required this.onTap});

  @override
  State<_CardContent> createState() => _CardContentState();
}

class _CardContentState extends State<_CardContent> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.97 : 1.0,
          _pressed ? 0.97 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.surfaceHi : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.surfaceRim,
            width: 0.5,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icon placeholder (stylized harp string icon)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHi,
                border: Border.all(color: AppColors.goldDeep.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: _HarpIcon(type: widget.type),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.type.displayName,
                    style: AppTextStyles.sans(18, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.type.subtitle,
                    style: AppTextStyles.sans(12, color: AppColors.gold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.type.description,
                    style: AppTextStyles.sans(12,
                        color: AppColors.textSecondary)
                        .copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.goldDeep,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HarpIcon extends StatelessWidget {
  final HarpType type;
  const _HarpIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final count = switch (type) {
      HarpType.lapHarp   => 5,
      HarpType.leverHarp => 7,
      HarpType.pedalHarp => 9,
    };

    return CustomPaint(
      size: const Size(22, 26),
      painter: _StringsPainter(count: count),
    );
  }
}

class _StringsPainter extends CustomPainter {
  final int count;
  const _StringsPainter({required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    for (int i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final x = size.width * (0.1 + t * 0.8);
      final h = size.height * (0.4 + t * 0.5);
      final top = size.height - h;
      final c = AppColors.octaveColors[(i * 7 ~/ count).clamp(0, 6)];
      paint.color = c.withValues(alpha: 0.8);
      canvas.drawLine(Offset(x, top), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StringsPainter old) => old.count != count;
}

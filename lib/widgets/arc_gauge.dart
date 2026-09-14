import 'dart:math' as math;

import 'package:flutter/material.dart';

class ArcGauge extends StatelessWidget {
  const ArcGauge({super.key, required this.ratio, required this.child});

  final double? ratio;
  final Widget child;

  static const _size = 220.0;
  static const _thickness = 16.0;

  static Color colorFor(BuildContext context, double? ratio) {
    final scheme = Theme.of(context).colorScheme;
    if (ratio == null) return scheme.outline;
    if (ratio >= 0.9) return scheme.error;
    if (ratio >= 0.75) return const Color(0xFFE08A1E);
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _size,
      height: _size / 2 + _thickness / 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio ?? 0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _ArcPainter(
            ratio: ratio == null ? null : value,
            color: colorFor(context, ratio),
            trackColor: scheme.surfaceContainerHighest,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: _thickness / 2),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.ratio,
    required this.color,
    required this.trackColor,
  });

  final double? ratio;
  final Color color;
  final Color trackColor;

  static const _thickness = ArcGauge._thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - _thickness) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, _thickness / 2 + radius),
      radius: radius,
    );
    final paint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint);

    final r = ratio;
    if (r == null || r <= 0) return;
    canvas.drawArc(rect, math.pi, math.pi * r, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.ratio != ratio || old.color != color || old.trackColor != trackColor;
}

import 'dart:math';

import 'package:flutter/material.dart';

class CircularPercentIndicator extends StatelessWidget {
  final double percent;
  final double dimension;
  final Color backgroundColor;
  final Color progressColor;
  final Widget? child;
  const CircularPercentIndicator({
    super.key,
    required this.percent,
    required this.dimension,
    this.backgroundColor = const Color(0xFF00AABF),
    this.progressColor = const Color(0xFFFFFFFF),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: CustomPaint(
        painter: _CirclePainter(
          percent: percent,
          backgroundColor: backgroundColor,
          dimension: dimension,
          progressColor: progressColor,
        ),

        child: Center(
          child:
              child ??
              Text(
                "${(percent * 100).toInt()}%",
                style: TextStyle(
                  fontSize: dimension * 0.3,
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double percent;
  final Color backgroundColor;
  final Color progressColor;
  final double dimension;
  _CirclePainter({
    required this.percent,
    required this.backgroundColor,
    required this.dimension,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = dimension * 0.1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

    final baseCirclePaint =
        Paint()
          ..color = progressColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final progressPaint =
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius + strokeWidth / 2, backgroundPaint);

    canvas.drawCircle(center, radius, baseCirclePaint);

    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

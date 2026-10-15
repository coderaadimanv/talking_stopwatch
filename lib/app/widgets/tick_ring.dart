import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../style.dart';

/// A ring of marks around whatever it is given, with an arc over them.
///
/// The dial's quieter cousin, for the screen before a workout starts. The
/// marks say "this is a clock, it has not started"; an empty arc on its own
/// would only ask to be read as zero, which is why they are here.
///
/// The arc is **not** progress — nothing is running. It is the share of the
/// session that is work, the same thing the ring on a preset card draws, and
/// that is the only reason it is allowed: a ring at some fraction because the
/// fraction looks good is decoration pretending to be data.
class TickRing extends StatelessWidget {
  const TickRing({
    super.key,
    required this.color,
    required this.child,
    this.progress = 0,
    this.count = 60,
  });

  final Color color;

  /// How much of the arc outside the marks is drawn, from 0 to 1.
  final double progress;

  /// Sixty, like a clock face. Every fifth is longer, which is what stops a
  /// ring of identical dashes reading as a texture.
  ///
  /// They are quieter than the arc outside them on purpose: at equal strength
  /// the two touch and read as one thick band, where what is wanted is a face
  /// with a rim around it.
  final int count;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(
        math.min(
          constraints.maxWidth * Sizes.dialFraction,
          constraints.maxHeight,
        ),
        Sizes.dialMax,
      );
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _Ticks(
            color: color,
            count: count,
            progress: progress.clamp(0, 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.17),
            child: Center(child: child),
          ),
        ),
      );
    },
  );
}

class _Ticks extends CustomPainter {
  const _Ticks({
    required this.color,
    required this.count,
    required this.progress,
  });

  final Color color;
  final int count;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // The arc rides outside the marks, so the two read as a rim around a face
    // rather than as one thick band.
    final outer = size.width / 2 - Sizes.ringStroke;

    final rim = Rect.fromCircle(
      center: centre,
      radius: size.width / 2 - Sizes.ringStroke / 2,
    );
    canvas.drawCircle(
      centre,
      rim.width / 2,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = Sizes.ringStroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        rim,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = Sizes.ringStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < count; i++) {
      final major = i % 5 == 0;
      final length = major ? Sizes.tickMajor : Sizes.tick;
      final angle = 2 * math.pi * i / count - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));

      canvas.drawLine(
        centre + direction * (outer - length),
        centre + direction * outer,
        Paint()
          ..color = color.withValues(alpha: major ? 0.45 : 0.22)
          ..strokeWidth = Sizes.tickWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Ticks old) =>
      old.color != color ||
      old.count != count ||
      old.progress != progress;
}

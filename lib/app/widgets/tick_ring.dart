import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../style.dart';

/// A ring of marks around whatever it is given.
///
/// The dial's quieter cousin, for the screen before a workout starts. There is
/// no progress to draw yet, so drawing an empty arc would only ask to be read
/// as zero — the marks say "this is a clock, it has not started" instead.
class TickRing extends StatelessWidget {
  const TickRing({
    super.key,
    required this.color,
    required this.child,
    this.count = 60,
  });

  final Color color;

  /// Sixty, like a clock face. Every fifth is longer, which is what stops a
  /// ring of identical dashes reading as a texture.
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
          painter: _Ticks(color: color, count: count),
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
  const _Ticks({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;

    for (var i = 0; i < count; i++) {
      final major = i % 5 == 0;
      final length = major ? Sizes.tickMajor : Sizes.tick;
      final angle = 2 * math.pi * i / count - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));

      canvas.drawLine(
        centre + direction * (outer - length),
        centre + direction * outer,
        Paint()
          ..color = color.withValues(alpha: major ? 0.75 : 0.40)
          ..strokeWidth = Sizes.tickWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Ticks old) => old.color != color || old.count != count;
}

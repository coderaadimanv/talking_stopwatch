import 'package:flutter/material.dart';

import '../style.dart';

/// The ground a screen stands on: one colour, with a few very soft shapes
/// drifting through it.
///
/// A flat fill at this size reads as a blank wall. The shapes have no edges at
/// all, so they give the screen depth without ever being noticed as shapes —
/// which is the point. Nothing moves: a running screen is looked at while out
/// of breath, and something drifting in the corner of it would only pull the
/// eye.
///
/// Two moods, because the two kinds of screen need opposite things. On a
/// phase colour the shapes are that colour lifted and dropped a little, and
/// they stay nearly invisible. On a dark screen there is nothing to lift, so
/// they are pools of [glow] instead — which is where the warmth on the list
/// and the settings comes from.
class SoftBackground extends StatelessWidget {
  const SoftBackground({
    super.key,
    required this.color,
    this.glow,
    required this.child,
  });

  final Color color;

  /// Lights a dark ground. Null leaves the subtle lift-and-drop instead.
  final Color? glow;

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color),
    child: CustomPaint(
      painter: _Blobs(glow: glow),
      // The painter has no size of its own; it fills whatever the child needs.
      child: SizedBox.expand(child: child),
    ),
  );
}

class _Blobs extends CustomPainter {
  const _Blobs({this.glow});

  final Color? glow;

  /// Where each shape sits and how big it is, as fractions of the screen, so
  /// the arrangement is the same on every phone. `strength` is how much of it
  /// shows through when the shape is a glow.
  static const _shapes = [
    (x: 0.98, y: 0.00, r: 0.62, light: true, strength: 0.42),
    (x: 0.02, y: 0.30, r: 0.60, light: true, strength: 0.10),
    (x: 0.88, y: 0.74, r: 0.70, light: false, strength: 0.12),
    (x: 0.12, y: 1.02, r: 0.58, light: true, strength: 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in _shapes) {
      final centre = Offset(size.width * shape.x, size.height * shape.y);
      final radius = size.width * shape.r;
      final colour = glow == null
          ? (shape.light ? Brand.veilLight : Brand.veilDark)
          : glow!.withValues(alpha: shape.strength);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            // Solid in the middle and gone by the edge, so there is no rim to
            // catch the eye.
            colors: [colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_Blobs old) => old.glow != glow;
}

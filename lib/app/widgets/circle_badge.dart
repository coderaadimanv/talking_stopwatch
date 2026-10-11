import 'package:flutter/material.dart';

import '../style.dart';

/// A round badge: an icon, or a short piece of text like a duration.
///
/// The same shape as the dial, shrunk. It is what ties a list of workouts to
/// the screen one of them opens into — a row and a running phase are obviously
/// the same app without either having to say so.
class CircleBadge extends StatelessWidget {
  const CircleBadge({
    super.key,
    required this.background,
    required this.child,
    this.size = Sizes.badge,
  });

  // Not const: the icon is built from arguments.
  CircleBadge.icon({
    super.key,
    required this.background,
    required IconData icon,
    required Color color,
    this.size = Sizes.badge,
  }) : child = Icon(icon, color: color, size: Sizes.bigIcon);

  final Color background;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: child,
  );
}

import 'package:flutter/material.dart';

import '../style.dart';
import 'circle_badge.dart';

/// A heading: what the section is, and what it currently does.
///
/// Two lines rather than one, because the second can carry the thing the
/// section is set to — "Audio delay", "3 exercises" — which gets that out of
/// the card and leaves the card for the controls.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// An action belonging to the whole section — adding to the list under it.
  final Widget? trailing;

  /// The colour of the badge, where the section belongs to something with a
  /// colour of its own. Defaults to the brand's accent.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final badge = accent ?? colors.work;
    return Padding(
      padding: const EdgeInsets.only(
        top: Sizes.bigGap,
        bottom: Sizes.gap,
        left: Sizes.gap / 2,
      ),
      child: Row(
        children: [
          // Solid, not washed. A heading is the one place on a dark page
          // where the colour should arrive at full strength: it is what tells
          // workouts from focus from the stopwatch before any of the words
          // under it are read.
          CircleBadge(
            size: Sizes.badgeSmall,
            background: badge,
            child: Icon(
              icon,
              color: colors.readableOn(badge),
              size: Sizes.icon,
            ),
          ),
          const SizedBox(width: Sizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                Text(
                  subtitle,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A heading with its settings in a card under it.
///
/// Use [SectionHeading] on its own where the content is not one card — a list
/// of rounds, say, which reads better as a card each than as one long box.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// The colour of the badge, where the section belongs to something with a
  /// colour of its own.
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(
        icon: icon,
        title: title,
        subtitle: subtitle,
        accent: accent,
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

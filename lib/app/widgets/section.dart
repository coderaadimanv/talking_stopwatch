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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: Sizes.bigGap,
        bottom: Sizes.gap,
        left: Sizes.gap / 2,
      ),
      child: Row(
        children: [
          CircleBadge(
            size: Sizes.badgeTiny,
            // The accent turned right down, not ivory: on a dark screen a
            // pale disc is a hole punched in the page.
            background: Brand.accentWash,
            child: Icon(
              icon,
              color: context.colors.work,
              size: Sizes.iconSmall,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(icon: icon, title: title, subtitle: subtitle),
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

import 'package:flutter/material.dart';

import '../style.dart';

/// How many rounds are done, at a glance: one dot each, filled as they go.
///
/// Dots only work while they can be counted without counting. Past a dozen
/// they stop being information and become texture, so a long workout gets a
/// bar and a number instead.
class RoundTracker extends StatelessWidget {
  const RoundTracker({
    super.key,
    required this.done,
    required this.total,
    required this.filled,
    required this.empty,
    required this.track,
  });

  /// Rounds finished or under way, counting from 1.
  final int done;
  final int total;

  final Color filled;
  final Color empty;

  /// The pill the dots sit in.
  final Color track;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      height: Sizes.control,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.bigGap),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(Sizes.control / 2),
      ),
      child: Center(
        child: total <= Sizes.maxDots
            ? _Dots(done: done, total: total, filled: filled, empty: empty)
            : _Bar(done: done, total: total, filled: filled, empty: empty),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.done,
    required this.total,
    required this.filled,
    required this.empty,
  });

  final int done;
  final int total;
  final Color filled;
  final Color empty;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var round = 1; round <= total; round++)
        Container(
          width: Sizes.dot,
          height: Sizes.dot,
          decoration: BoxDecoration(
            color: round <= done ? filled : empty,
            shape: BoxShape.circle,
          ),
        ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.done,
    required this.total,
    required this.filled,
    required this.empty,
  });

  final int done;
  final int total;
  final Color filled;
  final Color empty;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Sizes.dot / 2),
          child: LinearProgressIndicator(
            value: done / total,
            minHeight: Sizes.dot,
            backgroundColor: empty,
            valueColor: AlwaysStoppedAnimation(filled),
          ),
        ),
      ),
      const SizedBox(width: Sizes.gap),
      Text(
        '$done / $total',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: filled,
        ),
      ),
    ],
  );
}

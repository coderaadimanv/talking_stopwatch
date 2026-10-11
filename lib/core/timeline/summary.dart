import '../format.dart';
import 'timeline.dart';
import 'workout.dart';

/// The one-line description under a workout's name in the list.
///
/// Says the shape of the workout, not its contents: a list is read at a glance
/// to tell one workout from another, and "30s · 10s rest · 8 rounds" does that
/// where a list of every exercise would not.
extension WorkoutSummary on Workout {
  String get summary {
    if (rounds.isEmpty) return 'Empty';
    if (kind == TimerKind.focus) return _focusSummary;

    final parts = <String>[];
    if (rounds.length == 1) {
      final round = rounds.single;
      parts.add('${round.workSeconds}s work');
      if (round.restSeconds > 0) parts.add('${round.restSeconds}s rest');
      parts.add(_plural(repeats, 'round'));
    } else {
      parts.add(_plural(rounds.length, 'exercise'));
      if (repeats > 1) parts.add(_plural(repeats, 'set'));
    }
    return parts.join(' · ');
  }

  /// The same line for a focus session, in minutes rather than seconds.
  ///
  /// Seconds are the right unit for a workout and the wrong one here: nobody
  /// reads "1500s focus". The long break is named only when there is one,
  /// because a plain 50/10 does not have one.
  String get _focusSummary {
    final round = rounds.first;
    final parts = [
      '${round.workSeconds ~/ 60} min',
      // Only where there is one to take: the break after the last block is
      // dropped, so a single block has no break however long it is set to.
      if (round.restSeconds > 0 && repeats > 1)
        '${round.restSeconds ~/ 60} min break',
      _plural(repeats, 'block'),
      if (cooldownSeconds > 0) '${cooldownSeconds ~/ 60} min long break',
    ];
    return parts.join(' · ');
  }

  /// How long the whole thing takes, ready to show.
  String get totalLabel => countdown(expand(this).totalMs);
}

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

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

  /// How much of the session is actually work, from 0 to 1.
  ///
  /// What the ring on a card draws. A ring at some fraction because the
  /// fraction looks good is decoration pretending to be data; this is the one
  /// number worth knowing before committing to a session that you cannot get
  /// from its name — a 30/10 and a 30/60 take the same shape in a list and are
  /// not remotely the same hour.
  double get workShare {
    final timeline = expand(this);
    if (timeline.totalMs <= 0) return 0;
    final working = timeline.segments
        .where((s) => s.kind == SegmentKind.work)
        .fold(0, (sum, s) => sum + s.durationMs);
    return (working / timeline.totalMs).clamp(0.0, 1.0);
  }

  /// The two chips on a card: what kind of session this is, and one fact.
  ///
  /// **The first is inferred and the second is not**, which is worth knowing
  /// before trusting either. Nothing in the model records how hard a workout
  /// is, so the first chip is read off the numbers — and the numbers do say
  /// it, because what makes a session hard is the ratio of work to rest and
  /// the length of a block, which are exactly what a preset is made of. It is
  /// right most of the time and it is still a guess; the second chip is a
  /// plain count and cannot be wrong.
  List<(String, bool)> get tags => [
    (_kindLabel, true),
    if (kind == TimerKind.focus && cooldownSeconds > 0)
      ('${cooldownSeconds ~/ 60} min long break', false)
    else
      (_plural(workPhases, kind == TimerKind.focus ? 'block' : 'round'), false),
  ];

  /// The inferred one.
  ///
  /// The thresholds, and why they sit where they do: half a minute of work
  /// with less rest than work is interval training and nothing else; a minute
  /// or more with as much rest again is strength work, taken steadily. For a
  /// focus session the only question is whether a block is long enough to get
  /// into something, and twenty-five minutes is the pomodoro for a reason.
  String get _kindLabel {
    if (rounds.isEmpty) return 'Empty';
    final round = rounds.first;

    if (kind == TimerKind.focus) {
      if (round.workSeconds >= 25 * 60) return 'Deep work';
      if (round.workSeconds >= 15 * 60) return 'Focused';
      return 'Short blocks';
    }

    if (round.workSeconds <= 45 && round.restSeconds < round.workSeconds) {
      return 'High intensity';
    }
    if (round.restSeconds >= round.workSeconds) return 'Steady';
    return 'Moderate';
  }
}

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

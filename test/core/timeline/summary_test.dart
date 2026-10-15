import 'package:cadent/core/timeline/summary.dart';
import 'package:cadent/core/timeline/workout.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a preset card says about itself.
///
/// Two of the three things here are plain derivations and the middle one is a
/// guess — the kind label is read off the numbers because nothing in the model
/// records how hard a session is. A guess shown as a fact has to be pinned at
/// its edges, or it drifts the next time somebody adjusts a threshold.
void main() {
  Workout workout({
    required int work,
    required int rest,
    int repeats = 8,
  }) => Workout(
    id: 'w',
    prepareSeconds: 0,
    rounds: [Round(workSeconds: work, restSeconds: rest)],
    repeats: repeats,
  );

  Workout focus({required int minutes, int longBreak = 0}) => Workout.focus(
    focusMinutes: minutes,
    breakMinutes: 5,
    blocks: 4,
    longBreakMinutes: longBreak,
  );

  group('the kind label', () {
    test('short work with less rest is interval training', () {
      expect(workout(work: 30, rest: 10).tags.first.$1, 'High intensity');
      expect(workout(work: 45, rest: 44).tags.first.$1, 'High intensity');
    });

    test('as much rest as work is taken steadily, however short', () {
      // The boundary that matters: 45/45 is not interval training, and one
      // second either side of it changes the answer.
      expect(workout(work: 45, rest: 45).tags.first.$1, 'Steady');
      expect(workout(work: 60, rest: 90).tags.first.$1, 'Steady');
    });

    test('long work with a little rest is neither', () {
      expect(workout(work: 60, rest: 20).tags.first.$1, 'Moderate');
      expect(workout(work: 46, rest: 10).tags.first.$1, 'Moderate');
    });

    test('a focus session is judged on the length of a block', () {
      expect(focus(minutes: 25).tags.first.$1, 'Deep work');
      expect(focus(minutes: 24).tags.first.$1, 'Focused');
      expect(focus(minutes: 15).tags.first.$1, 'Focused');
      expect(focus(minutes: 14).tags.first.$1, 'Short blocks');
    });

    test('an empty preset says so rather than guessing', () {
      const empty = Workout(id: 'e', rounds: []);
      expect(empty.tags.first.$1, 'Empty');
    });
  });

  group('the second chip', () {
    test('counts the rounds of a workout', () {
      expect(workout(work: 30, rest: 10, repeats: 8).tags[1].$1, '8 rounds');
      expect(workout(work: 30, rest: 10, repeats: 1).tags[1].$1, '1 round');
    });

    test('names a focus session long break, or counts its blocks', () {
      expect(focus(minutes: 25, longBreak: 15).tags[1].$1, '15 min long break');
      expect(focus(minutes: 25).tags[1].$1, '4 blocks');
    });

    test('is marked as a fact where the first is marked as a guess', () {
      final tags = workout(work: 30, rest: 10).tags;
      expect(tags.first.$2, isTrue, reason: 'the kind label is inferred');
      expect(tags[1].$2, isFalse, reason: 'a count cannot be wrong');
    });
  });

  group('the share of a session that is work', () {
    test('is the work against the whole of it', () {
      // 30 on, 10 off, twice — and the last rest is dropped, so it is
      // 30 + 10 + 30 out of 70.
      final share = workout(work: 30, rest: 10, repeats: 2).workShare;
      expect(share, closeTo(60 / 70, 0.001));
    });

    test('is all of it when nothing rests', () {
      expect(workout(work: 30, rest: 0, repeats: 3).workShare, 1.0);
    });

    test('is nothing at all for an empty preset', () {
      expect(const Workout(id: 'e', rounds: []).workShare, 0);
    });
  });
}

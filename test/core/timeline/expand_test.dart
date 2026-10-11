import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/timeline/timeline.dart';
import 'package:cadent/core/timeline/workout.dart';

void main() {
  group('expand', () {
    test('30s work, 10s rest, 8 rounds, 10s prepare', () {
      final t = expand(
        Workout.simple(workSeconds: 30, restSeconds: 10, rounds: 8),
      );

      // prepare, then 8 work and 7 rest: the trailing rest is dropped.
      expect(t.segments.length, 1 + 8 + 7);
      expect(t.totalMs, (10 + 8 * 30 + 7 * 10) * 1000);

      expect(t.segments.first.kind, SegmentKind.prepare);
      expect(t.segments.first.startMs, 0);
      expect(t.segments.first.endMs, 10000);

      final work = t.segments.where((s) => s.kind == SegmentKind.work).toList();
      expect(work.length, 8);
      expect(work.first.startMs, 10000);
      expect(work.first.endMs, 40000);
      expect(work.first.index, 1);
      expect(work.first.isLastWork, isFalse);
      expect(work.last.startMs, 290000);
      expect(work.last.endMs, 320000);
      expect(work.last.index, 8);
      expect(work.last.isLastWork, isTrue);

      expect(t.segments[2].kind, SegmentKind.rest);
      expect(t.segments[2].startMs, 40000);
      expect(t.segments[2].endMs, 50000);
    });

    test('segments are contiguous and start at zero', () {
      final t = expand(
        Workout.simple(
          workSeconds: 45,
          restSeconds: 15,
          rounds: 3,
          prepareSeconds: 5,
        ),
      );
      var at = 0;
      for (final s in t.segments) {
        expect(s.startMs, at, reason: 'gap before ${s.kind}');
        expect(s.endMs, greaterThan(s.startMs), reason: 'empty ${s.kind}');
        at = s.endMs;
      }
      expect(at, t.totalMs);
    });

    test('the rest after the very last work phase is dropped', () {
      final t = expand(
        Workout.simple(
          workSeconds: 20,
          restSeconds: 10,
          rounds: 1,
          prepareSeconds: 0,
        ),
      );
      expect(t.segments.map((s) => s.kind), [SegmentKind.work]);
      expect(t.totalMs, 20000);
    });

    test('zero-length phases are skipped, not emitted', () {
      final t = expand(
        Workout.simple(
          workSeconds: 30,
          restSeconds: 0,
          rounds: 3,
          prepareSeconds: 0,
        ),
      );
      expect(t.segments.every((s) => s.kind == SegmentKind.work), isTrue);
      expect(t.segments.length, 3);
      expect(t.totalMs, 90000);
    });

    test('a circuit keeps its labels and numbers work phases across repeats', () {
      final t = expand(
        Workout(
          id: 'circuit',
          prepareSeconds: 0,
          rounds: const [
            Round(label: 'push ups', workSeconds: 40, restSeconds: 20),
            Round(label: 'squats', workSeconds: 30, restSeconds: 20),
          ],
          repeats: 2,
          breakSeconds: 60,
        ),
      );

      final work = t.segments.where((s) => s.kind == SegmentKind.work).toList();
      expect(work.map((s) => s.label), [
        'push ups',
        'squats',
        'push ups',
        'squats',
      ]);
      // Numbering is the work phase's position in the whole workout.
      expect(work.map((s) => s.index), [1, 2, 3, 4]);
      expect(work.last.isLastWork, isTrue);

      // One break, between the two repeats only — never after the last.
      final breaks = t.segments
          .where((s) => s.kind == SegmentKind.breakBetween)
          .toList();
      expect(breaks.length, 1);
      expect(breaks.single.startMs, (40 + 20 + 30 + 20) * 1000);
    });

    test('cooldown comes last', () {
      final t = expand(
        Workout(
          id: 'cool',
          prepareSeconds: 0,
          rounds: const [Round(workSeconds: 30, restSeconds: 0)],
          cooldownSeconds: 30,
        ),
      );
      expect(t.segments.map((s) => s.kind), [
        SegmentKind.work,
        SegmentKind.cooldown,
      ]);
      expect(t.totalMs, 60000);
    });

    test('a workout with nothing in it expands to nothing', () {
      final t = expand(
        Workout(id: 'empty', prepareSeconds: 0, rounds: const []),
      );
      expect(t.segments, isEmpty);
      expect(t.totalMs, 0);
    });
  });
}

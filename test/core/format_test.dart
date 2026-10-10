import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/core/format.dart';
import 'package:talking_stopwatch/core/timeline/summary.dart';
import 'package:talking_stopwatch/core/timeline/workout.dart';

void main() {
  group('countdown', () {
    test('rounds up, so a running timer never reads zero', () {
      expect(countdown(22001), '0:23');
      expect(countdown(22000), '0:22');
      expect(countdown(1), '0:01');
      expect(countdown(0), '0:00');
    });

    test('pads the seconds and not the leading minutes', () {
      expect(countdown(65000), '1:05');
      expect(countdown(320000), '5:20');
      expect(countdown(600000), '10:00');
    });

    test('shows hours only once there are any', () {
      expect(countdown(3599000), '59:59');
      expect(countdown(3600000), '1:00:00');
      expect(countdown(3725000), '1:02:05');
    });

    test('never shows a negative time', () {
      expect(countdown(-5000), '0:00');
    });
  });

  group('elapsed', () {
    test('rounds down, so a stopwatch starts at zero', () {
      expect(elapsed(0), '0:00');
      expect(elapsed(999), '0:00');
      expect(elapsed(1000), '0:01');
      expect(elapsed(59999), '0:59');
    });

    test('grows into hours', () {
      expect(elapsed(3661000), '1:01:01');
    });
  });

  group('summary', () {
    test('a simple interval says its shape', () {
      final w = Workout.simple(workSeconds: 30, restSeconds: 10, rounds: 8);
      expect(w.summary, '30s work · 10s rest · 8 rounds');
      expect(w.totalLabel, '5:20');
    });

    test('no rest is left unsaid rather than said as zero', () {
      final w = Workout.simple(workSeconds: 60, restSeconds: 0, rounds: 1);
      expect(w.summary, '60s work · 1 round');
    });

    test('a circuit counts its exercises and sets', () {
      const w = Workout(
        id: 'c',
        rounds: [
          Round(label: 'push ups', workSeconds: 40, restSeconds: 20),
          Round(label: 'squats', workSeconds: 30, restSeconds: 20),
          Round(label: 'plank', workSeconds: 60, restSeconds: 20),
        ],
        repeats: 3,
      );
      expect(w.summary, '3 exercises · 3 sets');
    });

    test('a single set of a circuit does not say "1 set"', () {
      const w = Workout(
        id: 'c',
        rounds: [
          Round(workSeconds: 40, restSeconds: 20),
          Round(workSeconds: 30, restSeconds: 20),
        ],
      );
      expect(w.summary, '2 exercises');
    });

    test('a workout with no rounds says so instead of breaking', () {
      const w = Workout(id: 'empty', rounds: []);
      expect(w.summary, 'Empty');
      expect(w.totalLabel, '0:00');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/core/cues/cue.dart';
import 'package:talking_stopwatch/core/cues/plan_stopwatch.dart';

List<String> script(List<Cue> cues) =>
    cues.map((c) => '${c.atMs} ${c.text}').toList();

void main() {
  group('planStopwatchCues', () {
    test('reads the time out at every interval', () {
      expect(
        script(planStopwatchCues(everySeconds: 30, untilMs: 120000)),
        [
          '30000 30 seconds',
          '60000 1 minute',
          '90000 1 minute 30',
          '120000 2 minutes',
        ],
      );
    });

    test('says nothing at the start — the user just pressed the button', () {
      final cues = planStopwatchCues(everySeconds: 60, untilMs: 60000);
      expect(cues.first.atMs, 60000);
    });

    test('an interval of zero is silence, not a crash', () {
      expect(planStopwatchCues(everySeconds: 0, untilMs: 600000), isEmpty);
      expect(planStopwatchCues(everySeconds: -5, untilMs: 600000), isEmpty);
    });

    test('stops at the horizon rather than running forever', () {
      final cues = planStopwatchCues(
        everySeconds: 60,
        untilMs: stopwatchWindowMs,
      );
      expect(cues.length, 10);
      expect(cues.last.atMs, stopwatchWindowMs);
    });

    test('a minute interval over an hour is sixty things to say', () {
      // The number that matters: every distinct phrase has to be rendered
      // once, and rendering is the only slow part of starting.
      final cues = planStopwatchCues(everySeconds: 60, untilMs: 3600000);
      expect(cues.map((c) => c.text).toSet().length, 60);
    });

    test('the calibration offset shifts the whole script', () {
      final cues = planStopwatchCues(
        everySeconds: 60,
        untilMs: 120000,
        offsetMs: -250,
      );
      expect(script(cues), ['59750 1 minute', '119750 2 minutes']);
    });

    test('nothing is scheduled before zero', () {
      final cues = planStopwatchCues(
        everySeconds: 1,
        untilMs: 3000,
        offsetMs: -5000,
      );
      expect(cues.every((c) => c.atMs >= 0), isTrue);
    });
  });

  group('needsExtending', () {
    test('is false early in the armed window', () {
      expect(needsExtending(elapsedMs: 0, armedUntilMs: stopwatchWindowMs),
          isFalse);
      expect(
        needsExtending(elapsedMs: 60000, armedUntilMs: stopwatchWindowMs),
        isFalse,
      );
    });

    test('is true once the armed window is running out', () {
      expect(
        needsExtending(
          elapsedMs: stopwatchWindowMs - stopwatchExtendAtMs,
          armedUntilMs: stopwatchWindowMs,
        ),
        isTrue,
      );
    });

    test('a silent stopwatch never needs extending', () {
      expect(needsExtending(elapsedMs: 999999, armedUntilMs: 0), isFalse);
    });
  });
}

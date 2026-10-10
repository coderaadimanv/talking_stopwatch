import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/core/audio/cue_player.dart';
import 'package:talking_stopwatch/core/clock/clock.dart';
import 'package:talking_stopwatch/core/session/session.dart';
import 'package:talking_stopwatch/core/timeline/workout.dart';

void main() {
  late FakeClock clock;
  late FakeCuePlayer player;
  late Session session;

  // 10s prepare, 30s work, 10s rest, 3 rounds → 120 s in total.
  final workout = Workout.simple(
    workSeconds: 30,
    restSeconds: 10,
    rounds: 3,
  );

  setUp(() {
    clock = FakeClock();
    player = FakeCuePlayer();
    session = Session(player: player, clock: clock)..load(workout);
  });

  test('loads idle, at zero, with nothing scheduled', () {
    expect(session.state.status, SessionStatus.idle);
    expect(session.state.elapsedMs, 0);
    expect(session.state.timeline.totalMs, 120000);
    expect(player.schedules, isEmpty);
  });

  test('start warms the phrases and schedules the whole script', () async {
    await session.start();

    expect(session.state.status, SessionStatus.running);
    expect(player.warmed.length, 1);
    expect(player.schedules.length, 1);

    // The whole remaining script goes down in one call — that is what keeps
    // the cues firing when Dart is frozen.
    expect(player.schedules.single.first.atMs, 0);
    expect(player.schedules.single.last.text, 'Done');
    expect(player.schedules.single.last.atMs, 120000);
    expect(player.warmed.single.length, player.schedules.single.length);
  });

  test('elapsed follows the clock while running', () async {
    await session.start();
    clock.advance(12500);
    expect(session.state.elapsedMs, 12500);
    expect(session.state.segment!.kind, SegmentKind.work);
    expect(session.state.segmentRemainingMs, 27500);
  });

  test('pause cancels the schedule and freezes the clock', () async {
    await session.start();
    clock.advance(12000);
    await session.pause();

    expect(session.state.status, SessionStatus.paused);
    expect(player.cancels, 1);

    clock.advance(60000);
    expect(session.state.elapsedMs, 12000, reason: 'paused time must not run');
  });

  test('resume reschedules only what is left, rebased to now', () async {
    await session.start();
    clock.advance(12000);
    await session.pause();
    clock.advance(5000); // time spent paused is not part of the workout
    await session.resume();

    expect(session.state.status, SessionStatus.running);
    expect(session.state.elapsedMs, 12000);
    expect(player.schedules.length, 2);

    final rescheduled = player.schedules.last;
    // Nothing from before the pause, and the next cue is now relative to zero.
    expect(rescheduled.every((c) => c.atMs >= 0), isTrue);
    expect(rescheduled.first.text, 'Halfway'); // 25 s absolute, 13 s away
    expect(rescheduled.first.atMs, 13000);
    expect(rescheduled.last.atMs, 120000 - 12000);

    clock.advance(1000);
    expect(session.state.elapsedMs, 13000);
  });

  test('skip jumps to the end of the current phase and reschedules', () async {
    await session.start();
    clock.advance(12000); // 2 s into the first work phase
    await session.skip();

    expect(session.state.elapsedMs, 40000);
    expect(session.state.segment!.kind, SegmentKind.rest);
    expect(player.cancels, 1);
    expect(player.schedules.last.first.text, 'Rest');
    expect(player.schedules.last.first.atMs, 0);
  });

  test('skipping the last phase finishes the session', () async {
    await session.start();
    clock.advance(100000); // inside the final work phase
    await session.skip();

    expect(session.state.status, SessionStatus.finished);
    expect(session.state.elapsedMs, 120000);
  });

  test('running past the end reports finished', () async {
    await session.start();
    clock.advance(120000);
    expect(session.state.status, SessionStatus.finished);
    expect(session.state.segment, isNull);
    expect(session.state.remainingMs, 0);
  });

  test('stop cancels and goes back to the start', () async {
    await session.start();
    clock.advance(40000);
    await session.stop();

    expect(session.state.status, SessionStatus.idle);
    expect(session.state.elapsedMs, 0);
    expect(player.cancels, 1);

    clock.advance(10000);
    expect(session.state.elapsedMs, 0);
  });

  test('restarting after a stop schedules the script from the top', () async {
    await session.start();
    clock.advance(40000);
    await session.stop();
    await session.start();

    expect(session.state.elapsedMs, 0);
    expect(player.schedules.last.first.atMs, 0);
    expect(player.schedules.last.last.atMs, 120000);
  });

  test('the calibration offset reaches the schedule', () async {
    session.load(workout, offsetMs: 250);
    await session.start();
    expect(player.schedules.single.first.atMs, 250);
  });

  test('pause and resume are safe to call out of turn', () async {
    await session.pause(); // not running
    expect(session.state.status, SessionStatus.idle);
    await session.resume(); // not paused
    expect(session.state.status, SessionStatus.idle);
    expect(player.schedules, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/audio/cue_player.dart';
import 'package:cadent/core/clock/clock.dart';
import 'package:cadent/core/session/session.dart';
import 'package:cadent/core/timeline/workout.dart';

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

  test('pause holds the platform rather than cancelling it', () async {
    await session.start();
    clock.advance(12000);
    await session.pause();

    expect(session.state.status, SessionStatus.paused);
    expect(player.pauses, 1);
    // Not cancelled: the platform keeps the list, which is what lets the
    // notification's Pause button work with no UI alive.
    expect(player.cancels, 0);

    clock.advance(60000);
    expect(session.state.elapsedMs, 12000, reason: 'paused time must not run');
  });

  test('resume picks it up where it stopped, arming nothing new', () async {
    await session.start();
    clock.advance(12000);
    await session.pause();
    clock.advance(5000); // time spent paused is not part of the workout
    await session.resume();

    expect(session.state.status, SessionStatus.running);
    expect(session.state.elapsedMs, 12000);
    expect(player.resumes, 1);
    expect(
      player.schedules.length,
      1,
      reason: 'the platform still holds the script it was given',
    );

    clock.advance(1000);
    expect(session.state.elapsedMs, 13000);
  });

  group('adopt', () {
    test('takes over a session the platform is already running', () {
      session.adopt(elapsedMs: 95000, paused: false);

      expect(session.state.status, SessionStatus.running);
      expect(session.state.elapsedMs, 95000);
      expect(session.state.segment!.kind, SegmentKind.work);
      expect(session.state.segment!.index, 3);

      clock.advance(1000);
      expect(session.state.elapsedMs, 96000);
    });

    test('takes over a held one without starting its clock', () {
      session.adopt(elapsedMs: 42000, paused: true);

      expect(session.state.status, SessionStatus.paused);
      clock.advance(10000);
      expect(session.state.elapsedMs, 42000);
    });

    test('arms nothing: the platform is already playing from its own list', () {
      session.adopt(elapsedMs: 42000, paused: false);
      expect(player.schedules, isEmpty);
      expect(player.warmed, isEmpty);
    });

    test('does nothing with no workout loaded', () {
      final empty = Session(player: FakeCuePlayer(), clock: FakeClock());
      empty.adopt(elapsedMs: 5000, paused: false);
      expect(empty.state.status, SessionStatus.idle);
    });
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

  group('activeSegment', () {
    test('is nothing before the session starts, though a phase sits at zero', () {
      expect(session.state.segment, isNotNull, reason: 'prepare is at zero');
      expect(
        session.state.activeSegment,
        isNull,
        reason: 'an idle screen must not wear a running phase colour',
      );
    });

    test('is the running phase once started, and while paused', () async {
      await session.start();
      clock.advance(12000);
      expect(session.state.activeSegment!.kind, SegmentKind.work);

      await session.pause();
      expect(session.state.activeSegment!.kind, SegmentKind.work);
    });

    test('is nothing again after stopping', () async {
      await session.start();
      clock.advance(12000);
      await session.stop();
      expect(session.state.activeSegment, isNull);
    });

    test('is nothing once the session has finished', () async {
      await session.start();
      clock.advance(120000);
      expect(session.state.activeSegment, isNull);
    });
  });
}

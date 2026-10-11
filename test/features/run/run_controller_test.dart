import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/app/providers.dart';
import 'package:talking_stopwatch/core/audio/cue_player.dart';
import 'package:talking_stopwatch/core/clock/clock.dart';
import 'package:talking_stopwatch/core/session/session.dart';
import 'package:talking_stopwatch/core/timeline/timeline.dart';
import 'package:talking_stopwatch/core/store/store.dart';
import 'package:talking_stopwatch/core/timeline/workout.dart';
import 'package:talking_stopwatch/features/run/domain/run_controller.dart';

void main() {
  late Directory dir;
  late FakeCuePlayer player;
  late FakeClock clock;
  late ProviderContainer container;

  // 10 s prepare, 30 s work, 10 s rest, 3 rounds → 120 s.
  final workout = Workout.simple(
    id: 'test',
    name: 'Tabata',
    workSeconds: 30,
    restSeconds: 10,
    rounds: 3,
  );

  // Two blocks of 5 minutes with a 1 minute break, so a focus session is
  // short enough to reason about and still shaped like a real one.
  final focus = Workout.focus(
    id: 'focus',
    name: 'Deep work',
    focusMinutes: 5,
    breakMinutes: 1,
    blocks: 2,
  );

  ProviderContainer makeContainer({
    AppSettings settings = const AppSettings(),
    String? running,
  }) {
    player = FakeCuePlayer();
    clock = FakeClock();
    return ProviderContainer(
      overrides: [
        cuePlayerProvider.overrideWithValue(player),
        clockProvider.overrideWithValue(clock),
        storeProvider.overrideWithValue(Store(File('${dir.path}/data.json'))),
        initialDataProvider.overrideWithValue(
          AppData(
            presets: [workout, focus],
            settings: settings,
            runningWorkoutId: running,
          ),
        ),
      ],
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('run_controller_test');
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await dir.delete(recursive: true);
  });

  RunController controller() => container.read(runProvider.notifier);
  RunState read() => container.read(runProvider);

  test('starts idle with nothing loaded and nothing armed', () {
    expect(read().session.status, SessionStatus.idle);
    expect(player.schedules, isEmpty);
  });

  test('starting asks about notifications, describes, warms and arms', () async {
    await controller().start();

    expect(player.asks, 1);
    expect(player.warmed.length, 1);
    expect(player.schedules.length, 1);
    expect(read().session.status, SessionStatus.running);

    // The whole script in one call, ending with "Done" at the full duration.
    expect(player.schedules.single.last.text, 'Done');
    expect(player.schedules.single.last.atMs, 120000);

    // The notification says where the session is, not just that it exists.
    expect(player.descriptions.first, 'Tabata | Starting');
    expect(player.descriptions.last, 'Tabata | Get ready');
  });

  test('the screen is only held awake when the setting asks for it', () async {
    await controller().start();
    expect(player.awake, isEmpty);

    container.dispose();
    container = makeContainer(settings: const AppSettings(keepScreenOn: true));
    await controller().start();
    expect(player.awake, [true]);
  });

  test('the calibration offset reaches the armed schedule', () async {
    container.dispose();
    container = makeContainer(settings: const AppSettings(offsetMs: 300));
    await controller().start();
    expect(player.schedules.single.first.atMs, 300);
  });

  test('pause, resume and stop move through the states', () async {
    await controller().start();

    await controller().pause();
    expect(read().session.status, SessionStatus.paused);
    expect(player.pauses, 1);
    expect(player.cancels, 0, reason: 'held, not thrown away');

    await controller().resume();
    expect(read().session.status, SessionStatus.running);
    expect(player.resumes, 1);
    expect(player.schedules.length, 1);

    await controller().stop();
    expect(read().session.status, SessionStatus.idle);
    expect(read().session.elapsedMs, 0);
    // Whatever the setting was, the screen is released on the way out.
    expect(player.awake.last, isFalse);
  });

  test('skip moves to the next phase and re-arms from there', () async {
    await controller().start();
    clock.advance(12000); // 2 s into the first work phase

    await controller().skip();

    expect(read().session.elapsedMs, 40000);
    expect(read().session.segment!.kind, SegmentKind.rest);
    expect(player.schedules.last.first.text, 'Rest');
    expect(player.descriptions.last, 'Tabata | Rest');
  });

  // The path that only happens on a real phone: the screen was off for
  // minutes, Dart was frozen, and its own reckoning of the time is stale.
  test('resync takes the platform clock as the truth', () async {
    await controller().start();
    clock.advance(500); // Dart barely ran

    player.fakeElapsedMs = 95000; // the platform knows better
    await controller().resync();

    expect(read().session.elapsedMs, 95000);
    expect(read().session.segment!.kind, SegmentKind.work);
    expect(read().session.segment!.index, 3);
    expect(player.descriptions.last, 'Tabata | Work · round 3');
  });

  test('resync is ignored when the platform has no session', () async {
    await controller().start();
    clock.advance(4000);

    player.fakeElapsedMs = null;
    await controller().resync();

    expect(read().session.elapsedMs, 4000);
  });

  test('the notification is told once per phase, not once per tick', () async {
    await controller().start();
    final afterStart = player.descriptions.length;

    clock.advance(1000);
    await controller().resync();
    clock.advance(1000);
    await controller().resync();

    expect(player.descriptions.length, afterStart, reason: 'same phase');
  });

  group('silencing the phone', () {
    void selectFocus() =>
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);

    test('a focus session silences it when the setting asks', () async {
      container.dispose();
      container = makeContainer(
        settings: const AppSettings(silenceDuringFocus: true),
      );
      selectFocus();

      await controller().start();
      expect(player.silences, [true]);

      await controller().stop();
      // Given back, and only once it is over.
      expect(player.silences, [true, false]);
    });

    test('a workout never silences it, whatever the setting says', () async {
      container.dispose();
      container = makeContainer(
        settings: const AppSettings(silenceDuringFocus: true),
      );

      await controller().start();
      expect(player.silences, isEmpty);
    });

    test('a focus session leaves it alone when the setting is off', () async {
      selectFocus();
      await controller().start();
      expect(player.silences, isEmpty);
    });

    test('stopping gives it back even if it was never taken', () async {
      // Unconditional on purpose: the platform only gives back what it wrote
      // down, and the alternative is remembering in two places.
      await controller().start();
      await controller().stop();
      expect(player.silences, [false]);
    });
  });

  group('what the notification says', () {
    test('a workout counts rounds', () {
      expect(
        notificationText(
          const Segment(
            kind: SegmentKind.work,
            startMs: 0,
            endMs: 1000,
            index: 2,
          ),
          TimerKind.workout,
        ),
        'Work · round 2',
      );
    });

    test('a focus session counts blocks, in its own words', () {
      expect(
        notificationText(
          const Segment(
            kind: SegmentKind.work,
            startMs: 0,
            endMs: 1000,
            index: 2,
          ),
          TimerKind.focus,
        ),
        'Focus · block 2',
      );
      expect(
        notificationText(
          const Segment(kind: SegmentKind.rest, startMs: 0, endMs: 1000),
          TimerKind.focus,
        ),
        'Break',
      );
    });

    test('nothing running says Done', () {
      expect(notificationText(null, TimerKind.focus), 'Done');
    });
  });

  // The bug this guards: the foreground service outlives the UI, so a workout
  // can still be playing long after the screen that started it was destroyed.
  // Coming back to a timer that says "Start" over a workout that is plainly
  // still counting is the worst thing this app could do — and starting again
  // would cancel it and begin from the top.
  group('coming back to a workout already running', () {
    test('starting writes down which workout it is', () async {
      await controller().start();
      expect(container.read(appDataProvider).runningWorkoutId, workout.id);
    });

    test('stopping forgets it again', () async {
      await controller().start();
      await controller().stop();
      expect(container.read(appDataProvider).runningWorkoutId, isNull);
    });

    test('finishing forgets it too', () async {
      await controller().start();
      clock.advance(120000);
      await controller().resync();
      expect(read().session.status, SessionStatus.finished);
      expect(container.read(appDataProvider).runningWorkoutId, isNull);
    });

    test('picks the session up at the platform clock, not from the top',
        () async {
      container.dispose();
      container = makeContainer(running: workout.id);
      player.fakeElapsedMs = 95000;

      await controller().restore();

      expect(read().session.status, SessionStatus.running);
      expect(read().session.elapsedMs, 95000);
      expect(read().session.segment!.kind, SegmentKind.work);
      expect(read().session.segment!.index, 3);
      // Nothing re-armed: the platform is already playing from its own list.
      expect(player.schedules, isEmpty);
    });

    test('picks up a held session as held', () async {
      container.dispose();
      container = makeContainer(running: workout.id);
      player
        ..fakeElapsedMs = 42000
        ..fakePaused = true;

      await controller().restore();

      expect(read().session.status, SessionStatus.paused);
      expect(read().session.elapsedMs, 42000);
    });

    test('forgets a session the platform no longer has', () async {
      container.dispose();
      container = makeContainer(running: workout.id);
      player.fakeElapsedMs = null; // the process died with it

      await controller().restore();

      expect(read().session.status, SessionStatus.idle);
      expect(container.read(appDataProvider).runningWorkoutId, isNull);
    });

    test('the notification\'s Pause button is followed here', () async {
      await controller().start();
      clock.advance(12000);

      // The platform pauses itself and tells us afterwards, because the
      // button that did it may have had no UI to route through.
      await player.pause();
      container.read(runProvider.notifier).followPlatformPause(true);

      expect(read().session.status, SessionStatus.paused);
      clock.advance(30000);
      expect(read().session.elapsedMs, 12000);

      await player.resume();
      container.read(runProvider.notifier).followPlatformPause(false);
      expect(read().session.status, SessionStatus.running);
    });
  });
}

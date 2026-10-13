import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/app/providers.dart';
import 'package:cadent/core/audio/cue_player.dart';
import 'package:cadent/core/clock/clock.dart';
import 'package:cadent/core/cues/plan_stopwatch.dart';
import 'package:cadent/core/store/store.dart';
import 'package:cadent/core/timeline/workout.dart';
import 'package:cadent/features/stopwatch/domain/stopwatch_controller.dart';
import '../../support/temp.dart';

void main() {
  late Directory dir;
  late FakeCuePlayer player;
  late FakeClock clock;
  late ProviderContainer container;

  ProviderContainer makeContainer({
    int announceSeconds = 60,
    bool keepScreenOn = false,
    int offsetMs = 0,
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
            presets: [Workout.simple(workSeconds: 30, restSeconds: 10, rounds: 3)],
            settings: AppSettings(
              stopwatchAnnounceSeconds: announceSeconds,
              keepScreenOn: keepScreenOn,
              offsetMs: offsetMs,
            ),
          ),
        ),
      ],
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stopwatch_test');
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await removeTemp(dir);
  });

  StopwatchController controller() => container.read(stopwatchProvider.notifier);
  StopwatchState read() => container.read(stopwatchProvider);

  /// Lets the fire-and-forget re-arm settle.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('starts at zero with nothing to reset', () {
    expect(read().running, isFalse);
    expect(read().elapsedMs, 0);
    expect(read().started, isFalse);
  });

  test('starting arms one window of announcements, counting up', () async {
    await controller().start();

    expect(read().running, isTrue);
    expect(player.schedules.length, 1);
    expect(player.countUps.single, isTrue, reason: 'no end to count down to');

    // Ten minutes of them, the first a minute in, and nothing at zero.
    expect(player.schedules.single.first.atMs, 60000);
    expect(player.schedules.single.first.text, '1 minute');
    expect(player.schedules.single.last.atMs, stopwatchWindowMs);
  });

  test('the clock does not start until the phrases are rendered', () async {
    // warm() is awaited before the anchor is set, so a slow first render
    // cannot come out of the user's time.
    final started = controller().start();
    clock.advance(3000);
    await started;
    expect(read().elapsedMs, 0);
  });

  // The state is a snapshot the ticker publishes, so a test moves the clock
  // and then ticks, exactly as the running screen does.
  test('elapsed follows the clock, and stops when paused', () async {
    await controller().start();
    clock.advance(42000);
    controller().tick();
    expect(read().elapsedMs, 42000);

    await controller().pause();
    expect(player.cancels, 1);
    clock.advance(60000);
    controller().tick();
    expect(read().elapsedMs, 42000);
    expect(read().running, isFalse);
    expect(read().started, isTrue);
  });

  test('resuming carries on from where it stopped', () async {
    await controller().start();
    clock.advance(42000);
    await controller().pause();
    clock.advance(10000); // paused time is not counted
    await controller().start();

    expect(read().elapsedMs, 42000);
    clock.advance(1000);
    controller().tick();
    expect(read().elapsedMs, 43000);

    // The second window is armed relative to now, not to zero.
    expect(player.schedules.length, 2);
    expect(player.schedules.last.first.atMs, 60000 - 42000);
  });

  test('laps are recorded against the running clock', () async {
    await controller().start();
    clock.advance(30000);
    controller().lap();
    clock.advance(45000);
    controller().lap();

    expect(read().laps, [30000, 75000]);
  });

  test('a lap does nothing while paused', () async {
    await controller().start();
    clock.advance(30000);
    await controller().pause();
    controller().lap();
    expect(read().laps, isEmpty);
  });

  test('reset clears the clock, the laps and the screen lock', () async {
    container.dispose();
    container = makeContainer(keepScreenOn: true);

    await controller().start();
    clock.advance(30000);
    controller().lap();
    await controller().reset();

    expect(read().elapsedMs, 0);
    expect(read().laps, isEmpty);
    expect(read().started, isFalse);
    expect(player.awake, [true, false]);
  });

  test('the next window goes down before the current one runs out', () async {
    await controller().start();
    expect(player.schedules.length, 1);

    clock.advance(stopwatchWindowMs - stopwatchExtendAtMs - 1000);
    controller().tick();
    await settle();
    expect(player.schedules.length, 1, reason: 'still plenty in hand');

    clock.advance(2000); // now inside the last five minutes
    controller().tick();
    await settle();
    expect(player.schedules.length, 2);

    // The new window reaches past the end of the old one, so there is no
    // gap where the stopwatch would fall silent.
    final elapsed = read().elapsedMs;
    expect(
      player.schedules.last.last.atMs + elapsed,
      greaterThan(stopwatchWindowMs),
    );
  });

  test('announcements turned off arm nothing to say', () async {
    container.dispose();
    container = makeContainer(announceSeconds: 0);

    await controller().start();
    clock.advance(120000);
    controller().tick();

    expect(player.schedules.single, isEmpty);
    expect(read().elapsedMs, 120000, reason: 'it still counts');
  });

  test('the calibration offset reaches the announcements', () async {
    container.dispose();
    container = makeContainer(offsetMs: -200);

    await controller().start();
    expect(player.schedules.single.first.atMs, 59800);
  });
}

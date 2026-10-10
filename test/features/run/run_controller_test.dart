import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/app/providers.dart';
import 'package:talking_stopwatch/core/audio/cue_player.dart';
import 'package:talking_stopwatch/core/clock/clock.dart';
import 'package:talking_stopwatch/core/session/session.dart';
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

  ProviderContainer makeContainer({AppSettings settings = const AppSettings()}) {
    player = FakeCuePlayer();
    clock = FakeClock();
    return ProviderContainer(
      overrides: [
        cuePlayerProvider.overrideWithValue(player),
        clockProvider.overrideWithValue(clock),
        storeProvider.overrideWithValue(Store(File('${dir.path}/data.json'))),
        initialDataProvider.overrideWithValue(
          AppData(presets: [workout], settings: settings),
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
    expect(player.cancels, 1);

    await controller().resume();
    expect(read().session.status, SessionStatus.running);
    expect(player.schedules.length, 2);

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
}

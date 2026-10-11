import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/store/store.dart';
import 'package:cadent/core/timeline/workout.dart';

void main() {
  late Directory dir;
  late Store store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cadent_test');
    store = Store(File('${dir.path}/data.json'));
  });

  tearDown(() async => dir.delete(recursive: true));

  test('a missing file loads the defaults, with a usable first preset', () async {
    final data = await store.load();
    expect(data.settings.offsetMs, 0);
    expect(data.presets, isNotEmpty);
    expect(data.presets.first.rounds, isNotEmpty);
  });

  test('a workout survives a round trip, cue settings and all', () async {
    final workout = Workout(
      id: 'w1',
      name: 'Tabata',
      prepareSeconds: 15,
      rounds: const [
        Round(label: 'push ups', workSeconds: 20, restSeconds: 10),
        Round(label: 'squats', workSeconds: 30, restSeconds: 15),
      ],
      repeats: 4,
      breakSeconds: 60,
      cooldownSeconds: 30,
      cues: const CueSettings(
        countdown: true,
        countdownFrom: 5,
        halfway: false,
        roundLabels: true,
        lastRound: false,
      ),
    );

    await store.save(
      AppData(
        presets: [workout],
        settings: const AppSettings(
          offsetMs: -150,
          keepScreenOn: true,
          stopwatchAnnounceSeconds: 30,
        ),
      ),
    );

    final back = await store.load();
    final w = back.presets.single;
    expect(w.id, 'w1');
    expect(w.name, 'Tabata');
    expect(w.prepareSeconds, 15);
    expect(w.repeats, 4);
    expect(w.breakSeconds, 60);
    expect(w.cooldownSeconds, 30);
    expect(w.rounds.map((r) => r.label), ['push ups', 'squats']);
    expect(w.rounds.map((r) => r.workSeconds), [20, 30]);
    expect(w.rounds.map((r) => r.restSeconds), [10, 15]);
    expect(w.cues.countdownFrom, 5);
    expect(w.cues.halfway, isFalse);
    expect(w.cues.lastRound, isFalse);

    expect(back.settings.offsetMs, -150);
    expect(back.settings.keepScreenOn, isTrue);
    expect(back.settings.stopwatchAnnounceSeconds, 30);
  });

  test('a corrupt file falls back to the defaults instead of throwing', () async {
    await store.file.writeAsString('{not json at all');
    final data = await store.load();
    expect(data.presets, isNotEmpty);
    expect(data.settings.offsetMs, 0);
  });

  test('a file from a newer schema falls back rather than guessing', () async {
    await store.file.writeAsString('{"schema": 99, "presets": []}');
    final data = await store.load();
    expect(data.presets, isNotEmpty, reason: 'should be the defaults');
  });

  test('a focus preset keeps its kind across a save', () async {
    await store.save(
      AppData(
        presets: [
          Workout(
            id: 'f1',
            name: 'Deep work',
            kind: TimerKind.focus,
            prepareSeconds: 0,
            rounds: const [Round(workSeconds: 3000, restSeconds: 600)],
            repeats: 2,
            cooldownSeconds: 900,
            cues: CueSettings.quiet,
          ),
        ],
      ),
    );

    final back = await store.load();
    expect(back.presets.single.kind, TimerKind.focus);
    expect(back.presets.single.cues.countdown, isFalse);
  });

  test('a preset saved before focus existed reads as a workout', () async {
    // No migration and no schema bump: the field is simply absent, and absent
    // means what every preset was before this.
    await File('${dir.path}/data.json').writeAsString(
      '{"schema":1,"presets":[{"id":"old","rounds":[{"work":30,"rest":10}],'
      '"repeats":8}],"settings":{}}',
    );

    final back = await store.load();
    expect(back.presets.single.kind, TimerKind.workout);
  });

  test('a fresh install has something to focus with', () async {
    final data = await store.load();
    expect(
      data.presets.where((p) => p.kind == TimerKind.focus),
      isNotEmpty,
    );
  });

  test('the silence setting survives a round trip, and defaults off', () async {
    expect((await store.load()).settings.silenceDuringFocus, isFalse);

    await store.save(
      const AppData(settings: AppSettings(silenceDuringFocus: true)),
    );
    expect((await store.load()).settings.silenceDuringFocus, isTrue);
  });

  test('saving leaves no temporary file behind', () async {
    await store.save(const AppData());
    final left = dir.listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(left, ['data.json']);
  });

  test('a save that replaces an existing file keeps it readable', () async {
    await store.save(AppData(presets: [Workout.simple(
      workSeconds: 10,
      restSeconds: 5,
      rounds: 2,
      id: 'first',
    )]));
    await store.save(AppData(presets: [Workout.simple(
      workSeconds: 20,
      restSeconds: 5,
      rounds: 2,
      id: 'second',
    )]));

    final back = await store.load();
    expect(back.presets.single.id, 'second');
  });
}

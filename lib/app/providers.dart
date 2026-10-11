import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/cue_player.dart';
import '../core/audio/platform_cue_player.dart';
import '../core/clock/clock.dart';
import '../core/ids.dart';
import '../core/store/store.dart';
import '../core/timeline/workout.dart';

/// Both of these are supplied by `main`, which loads the file before the first
/// frame so no screen ever has to render a loading state.
final storeProvider = Provider<Store>(
  (ref) => throw StateError('storeProvider must be overridden in main'),
);

final initialDataProvider = Provider<AppData>(
  (ref) => throw StateError('initialDataProvider must be overridden in main'),
);

/// The platform. Overridden with a [FakeCuePlayer] in tests, which is the
/// whole reason the contract is an interface.
final cuePlayerProvider = Provider<CuePlayer>((ref) {
  final player = PlatformCuePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// The session's clock. A provider so tests can hand it a fake one.
final clockProvider = Provider<Clock>((ref) => MonotonicClock());

/// Whether this phone can speak at all. When it cannot, the timer still runs;
/// it just says nothing, and the screen says so.
final voiceAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(cuePlayerProvider).available(),
);

/// Whether the session notification would actually be seen: false when it is
/// switched off, null where that is not a question at all (see
/// [CuePlayer.canNotify]).
///
/// Asked again every time something starts watching it, and that is the point.
/// The answer changes outside the app and nothing tells us when: it is a
/// system screen we send the user to, or the "turn these off" on the
/// notification itself, weeks later. So it is kept no longer than it is being
/// looked at, and settings invalidates it on resume as well, for the case
/// where the screen stayed open across the change.
final canNotifyProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(cuePlayerProvider).canNotify(),
);

/// Everything saved, held in memory and written back on every change.
class AppDataController extends Notifier<AppData> {
  @override
  AppData build() => ref.read(initialDataProvider);

  void edit(AppData Function(AppData) change) {
    state = change(state);
    unawaited(_save(state));
  }

  /// Fire and forget, and genuinely so: the write is atomic, and a full disk
  /// or a revoked permission must not take down the app in the middle of a
  /// workout. The next change writes the whole file again anyway.
  Future<void> _save(AppData data) async {
    try {
      await ref.read(storeProvider).save(data);
    } on FileSystemException {
      // Nothing useful to do about it here.
    }
  }

  /// Changes one saved workout, leaving the rest alone.
  void editWorkout(String id, Workout Function(Workout) change) => edit(
    (data) => data.copyWith(
      presets: [
        for (final w in data.presets)
          if (w.id == id) change(w) else w,
      ],
    ),
  );

  /// Adds a workout and returns it, so the caller can open its editor.
  Workout addWorkout({String name = 'New workout'}) {
    final workout = Workout.simple(
      id: newId(),
      name: name,
      workSeconds: 30,
      restSeconds: 10,
      rounds: 8,
    );
    edit((data) => data.copyWith(presets: [...data.presets, workout]));
    return workout;
  }

  /// The same, for the other mode. A new one starts at the pomodoro, which is
  /// the shape most people have in mind when they ask for a focus timer.
  Workout addFocus({String name = 'New focus'}) {
    final focus = Workout.focus(
      id: newId(),
      name: name,
      focusMinutes: 25,
      breakMinutes: 5,
      blocks: 4,
      longBreakMinutes: 15,
    );
    edit((data) => data.copyWith(presets: [...data.presets, focus]));
    return focus;
  }

  /// Copies a workout, so a variation does not have to be typed out again.
  Workout duplicate(String id) {
    final source = state.presets.firstWhere((w) => w.id == id);
    final copy = source.copyWith(id: newId(), name: '${source.name} copy');
    edit((data) => data.copyWith(presets: [...data.presets, copy]));
    return copy;
  }

  /// Removes a workout. The last one is kept: an empty list would leave the
  /// app with nothing to show and nothing to start.
  void deleteWorkout(String id) {
    if (state.presets.length <= 1) return;
    edit(
      (data) => data.copyWith(
        presets: [
          for (final w in data.presets)
            if (w.id != id) w,
        ],
      ),
    );
  }

  void editSettings(AppSettings Function(AppSettings) change) =>
      edit((data) => data.copyWith(settings: change(data.settings)));

  /// Remembers which workout is running, so the app can find its way back to
  /// it after the screen that started it is gone.
  void setRunning(String? id) => edit(
    (data) => id == null
        ? data.copyWith(clearRunning: true)
        : data.copyWith(runningWorkoutId: id),
  );
}

final appDataProvider = NotifierProvider<AppDataController, AppData>(
  AppDataController.new,
);

/// Which saved workout the run screen is pointed at. Not saved: opening the
/// app puts you back at the list, which is where the choice belongs.
class SelectedWorkout extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedWorkoutIdProvider = NotifierProvider<SelectedWorkout, String?>(
  SelectedWorkout.new,
);

/// The workout the run screen will start.
final workoutProvider = Provider<Workout>((ref) {
  final presets = ref.watch(appDataProvider).presets;
  final id = ref.watch(selectedWorkoutIdProvider);
  return presets.firstWhere((w) => w.id == id, orElse: () => presets.first);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/cue_player.dart';
import '../core/audio/platform_cue_player.dart';
import '../core/clock/clock.dart';
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

/// Everything saved, held in memory and written back on every change.
class AppDataController extends Notifier<AppData> {
  @override
  AppData build() => ref.read(initialDataProvider);

  void edit(AppData Function(AppData) change) {
    state = change(state);
    // Fire and forget: the write is atomic, and a failed save must not stop a
    // workout starting.
    ref.read(storeProvider).save(state);
  }

  /// Changes the workout being edited. Phase 2 has exactly one; the preset
  /// list and its editor arrive in phase 3.
  void editWorkout(Workout Function(Workout) change) => edit(
    (data) => data.copyWith(
      presets: [change(data.presets.first), ...data.presets.skip(1)],
    ),
  );

  void editSettings(AppSettings Function(AppSettings) change) =>
      edit((data) => data.copyWith(settings: change(data.settings)));
}

final appDataProvider = NotifierProvider<AppDataController, AppData>(
  AppDataController.new,
);

/// The workout the run screen will start.
final workoutProvider = Provider<Workout>(
  (ref) => ref.watch(appDataProvider).presets.first,
);

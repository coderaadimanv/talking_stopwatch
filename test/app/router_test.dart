import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/app/router.dart';
import 'package:cadent/core/store/store.dart';
import 'package:cadent/core/timeline/workout.dart';

/// Where the app opens after being killed with a session still playing.
///
/// Worth its own test because it is the one piece of `main()` with a decision
/// in it, and the device cannot easily be made to reproduce the case: it needs
/// the process gone while the foreground service lives on.
void main() {
  final workout = Workout.simple(
    id: 'w',
    workSeconds: 30,
    restSeconds: 10,
    rounds: 8,
  );
  final focus = Workout.focus(
    id: 'f',
    focusMinutes: 25,
    breakMinutes: 5,
    blocks: 4,
  );
  final data = AppData(presets: [workout, focus]);

  test('nothing running opens the list', () {
    expect(startLocation(data, running: false), '/');
  });

  test('a workout opens the run screen', () {
    expect(
      startLocation(
        data.copyWith(runningWorkoutId: 'w'),
        running: true,
      ),
      '/run',
    );
  });

  test('a focus session opens the focus screen', () {
    expect(
      startLocation(
        data.copyWith(runningWorkoutId: 'f'),
        running: true,
      ),
      '/focus',
    );
  });

  test('a session whose preset was deleted opens the list', () {
    expect(
      startLocation(
        data.copyWith(runningWorkoutId: 'gone'),
        running: true,
      ),
      '/',
    );
  });
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/app/providers.dart';
import 'package:cadent/core/store/store.dart';
import 'package:cadent/core/timeline/workout.dart';
import '../../support/temp.dart';

void main() {
  late Directory dir;
  late Store store;
  late ProviderContainer container;

  final first = Workout.simple(
    id: 'first',
    name: 'Tabata',
    workSeconds: 20,
    restSeconds: 10,
    rounds: 8,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('presets_test');
    store = Store(File('${dir.path}/data.json'));
    container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(AppData(presets: [first])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await removeTemp(dir);
  });

  AppDataController data() => container.read(appDataProvider.notifier);
  List<Workout> presets() => container.read(appDataProvider).presets;

  test('adding gives a workout its own id and leaves the others alone', () {
    final added = data().addWorkout();
    expect(presets().length, 2);
    expect(added.id, isNot(first.id));
    expect(presets().first.id, first.id);
  });

  test('two workouts added together do not share an id', () {
    final a = data().addWorkout();
    final b = data().addWorkout();
    expect(a.id, isNot(b.id));
  });

  test('editing one workout does not touch another', () {
    final other = data().addWorkout();
    data().editWorkout(other.id, (w) => w.copyWith(name: 'Changed'));

    expect(presets().firstWhere((w) => w.id == other.id).name, 'Changed');
    expect(presets().firstWhere((w) => w.id == first.id).name, 'Tabata');
  });

  test('a duplicate is a separate workout with the same numbers', () {
    final copy = data().duplicate(first.id);

    expect(copy.id, isNot(first.id));
    expect(copy.name, 'Tabata copy');
    expect(copy.rounds.single.workSeconds, 20);

    // Changing the copy must not change what it was copied from.
    data().editWorkout(copy.id, (w) => w.copyWith(prepareSeconds: 99));
    expect(presets().firstWhere((w) => w.id == first.id).prepareSeconds, 10);
  });

  test('deleting removes just that one', () {
    final other = data().addWorkout();
    data().deleteWorkout(other.id);

    expect(presets().map((w) => w.id), [first.id]);
  });

  test('the last workout cannot be deleted', () {
    data().deleteWorkout(first.id);
    expect(presets(), hasLength(1), reason: 'nothing left to show or start');
  });

  test('every change is written straight to the file', () async {
    data().addWorkout(name: 'Saved');
    // The save is fire and forget, so give it a moment to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final back = await store.load();
    expect(back.presets.map((w) => w.name), ['Tabata', 'Saved']);
  });

  group('which workout the run screen points at', () {
    test('is the first one until something is chosen', () {
      expect(container.read(workoutProvider).id, first.id);
    });

    test('follows the selection', () {
      final other = data().addWorkout(name: 'Other');
      container.read(selectedWorkoutIdProvider.notifier).select(other.id);
      expect(container.read(workoutProvider).id, other.id);
    });

    test('falls back to the first if the chosen one is deleted', () {
      final other = data().addWorkout();
      container.read(selectedWorkoutIdProvider.notifier).select(other.id);
      data().deleteWorkout(other.id);

      expect(container.read(workoutProvider).id, first.id);
    });
  });
}

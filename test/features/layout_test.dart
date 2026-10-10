import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talking_stopwatch/app/style.dart';
import 'package:talking_stopwatch/app/providers.dart';
import 'package:talking_stopwatch/core/audio/cue_player.dart';
import 'package:talking_stopwatch/core/clock/clock.dart';
import 'package:talking_stopwatch/core/store/store.dart';
import 'package:talking_stopwatch/core/timeline/workout.dart';
import 'package:talking_stopwatch/features/edit/ui/editor_screen.dart';
import 'package:talking_stopwatch/features/presets/ui/presets_screen.dart';
import 'package:talking_stopwatch/features/run/domain/run_controller.dart';
import 'package:talking_stopwatch/features/run/ui/run_screen.dart';
import 'package:talking_stopwatch/features/settings/ui/settings_screen.dart';
import 'package:talking_stopwatch/features/stopwatch/domain/stopwatch_controller.dart';
import 'package:talking_stopwatch/features/stopwatch/ui/stopwatch_screen.dart';

/// Every screen, on the smallest phone anyone still carries and on a normal
/// one, checked for the overflow stripes.
///
/// Worth its own file because this is the one kind of bug the other tests
/// cannot see: the logic is right, the state is right, and the buttons still
/// run off the side of a narrow screen.
void main() {
  late Directory dir;
  late ProviderContainer container;

  final workout = Workout(
    id: 'circuit',
    name: 'A fairly long workout name',
    rounds: const [
      Round(label: 'push ups', workSeconds: 40, restSeconds: 20),
      Round(label: 'squats', workSeconds: 30, restSeconds: 15),
    ],
    repeats: 4,
    breakSeconds: 60,
    cooldownSeconds: 30,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('layout_test');
    container = ProviderContainer(
      overrides: [
        cuePlayerProvider.overrideWithValue(FakeCuePlayer()),
        clockProvider.overrideWithValue(FakeClock()),
        storeProvider.overrideWithValue(Store(File('${dir.path}/data.json'))),
        initialDataProvider.overrideWithValue(AppData(presets: [workout])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await dir.delete(recursive: true);
  });

  /// 320x640 is a small phone; 360x800 is an ordinary one.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen, {
    required Size size,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme(), home: screen),
      ),
    );
    await tester.pump();
  }

  /// A wrapped label is not an overflow — nothing throws, the button simply
  /// grows taller and reads as "Re / set". So it has to be measured, and it is
  /// measured against a label on the same screen that is too short to wrap.
  /// No threshold to guess at, and nothing to re-tune when the type changes.
  void expectOneLine(
    WidgetTester tester,
    String label, {
    required String shortEnoughToNeverWrap,
  }) {
    // At most as tall as the short one: wrapping makes a label taller, and
    // being scaled down to fit makes it shorter, so this catches the one
    // without complaining about the other.
    expect(
      tester.getSize(find.text(label)).height,
      lessThanOrEqualTo(
        tester.getSize(find.text(shortEnoughToNeverWrap)).height,
      ),
      reason: '"$label" wrapped, where "$shortEnoughToNeverWrap" did not',
    );
  }

  const sizes = {'small': Size(320, 640), 'ordinary': Size(360, 800)};

  for (final entry in sizes.entries) {
    group('on a ${entry.key} screen', () {
      final size = entry.value;

      testWidgets('the list of workouts fits', (tester) async {
        await pumpAt(tester, const PresetsScreen(), size: size);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a workout waiting to start fits', (tester) async {
        await pumpAt(tester, const RunScreen(), size: size);
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');
      });

      testWidgets('a workout in progress fits', (tester) async {
        await pumpAt(tester, const RunScreen(), size: size);
        await container.read(runProvider.notifier).start();
        await tester.pump();

        expect(find.text('Get ready'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final label in ['Stop', 'Pause']) {
          expectOneLine(tester, label, shortEnoughToNeverWrap: 'Skip');
        }

        // The ticker has to be stopped inside the test: the pending-timer
        // check runs before any tearDown gets a chance to dispose it.
        await container.read(runProvider.notifier).stop();
      });

      testWidgets('the stopwatch fits, laps and all', (tester) async {
        await pumpAt(tester, const StopwatchScreen(), size: size);

        final stopwatch = container.read(stopwatchProvider.notifier);
        await stopwatch.start();
        stopwatch
          ..lap()
          ..lap();
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final label in ['Reset', 'Pause']) {
          expectOneLine(tester, label, shortEnoughToNeverWrap: 'Lap');
        }

        await stopwatch.reset();
      });

      testWidgets('the editor fits, with every row shown', (tester) async {
        // repeats > 1 and several rounds, so nothing is hidden by a branch.
        await pumpAt(tester, EditorScreen(id: workout.id), size: size);
        expect(tester.takeException(), isNull);

        // Scroll the whole form past, checking each screenful. A long list
        // only builds what is on screen, so this is the only way to see it.
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Say "halfway"'), findsOneWidget);
      });

      testWidgets('settings fit', (tester) async {
        await pumpAt(tester, const SettingsScreen(), size: size);
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/app/style.dart';
import 'package:cadent/app/widgets/tick_ring.dart';
import 'package:cadent/app/providers.dart';
import 'package:cadent/core/audio/cue_player.dart';
import 'package:cadent/core/clock/clock.dart';
import 'package:cadent/core/cues/sound_settings.dart';
import 'package:cadent/core/cues/tone.dart';
import 'package:cadent/core/store/store.dart';
import 'package:cadent/core/timeline/workout.dart';
import 'package:cadent/features/edit/ui/editor_screen.dart';
import 'package:cadent/features/focus/ui/focus_screen.dart';
import 'package:cadent/features/presets/ui/presets_screen.dart';
import 'package:cadent/features/run/domain/run_controller.dart';
import 'package:cadent/features/run/ui/run_screen.dart';
import 'package:cadent/features/settings/ui/settings_screen.dart';
import 'package:cadent/features/stopwatch/domain/stopwatch_controller.dart';
import 'package:cadent/features/stopwatch/ui/stopwatch_screen.dart';
import '../support/temp.dart';

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

  /// The pomodoro, with a name long enough to be awkward and a total long
  /// enough to need the hour field.
  final focus = Workout.focus(
    id: 'pomodoro',
    name: 'Deep work, mornings only',
    focusMinutes: 25,
    breakMinutes: 5,
    blocks: 4,
    longBreakMinutes: 15,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('layout_test');
    container = ProviderContainer(
      overrides: [
        cuePlayerProvider.overrideWithValue(FakeCuePlayer()),
        clockProvider.overrideWithValue(FakeClock()),
        storeProvider.overrideWithValue(Store(File('${dir.path}/data.json'))),
        initialDataProvider.overrideWithValue(
          AppData(presets: [workout, focus]),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await removeTemp(dir);
  });

  /// 320x640 is a small phone; 360x800 is an ordinary one.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    AppColors theme = AppColors.rust,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme(theme), home: screen),
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

  /// The same job as [expectOneLine] where the screen has no short label in
  /// the same style to measure against: a paragraph knows the height of one of
  /// its own lines, so ask it rather than guess a threshold.
  void expectSingleLine(WidgetTester tester, String label) {
    // Every one of them, not just the first: the sound settings put the same
    // three words on four rows, and only one of those rows has to be tight
    // for the screen to look broken.
    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.text(label))
        .toList();
    expect(paragraphs, isNotEmpty, reason: '"$label" is not on this screen');
    for (final paragraph in paragraphs) {
      expect(
        paragraph.size.height,
        lessThan(paragraph.preferredLineHeight * 2),
        reason: '"$label" wrapped onto a second line',
      );
    }
  }

  /// A platform with nothing working: no voice and no notifications, so every
  /// notice in the app is up at once and the screens under them are at their
  /// most crowded.
  /// Rebuilds the container with a different platform or different settings,
  /// for the screens that only look their worst in one particular state.
  void useContainer({
    FakeCuePlayer? player,
    AppSettings settings = const AppSettings(),
  }) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        cuePlayerProvider.overrideWithValue(player ?? FakeCuePlayer()),
        clockProvider.overrideWithValue(FakeClock()),
        storeProvider.overrideWithValue(Store(File('${dir.path}/data.json'))),
        initialDataProvider.overrideWithValue(
          AppData(presets: [workout, focus], settings: settings),
        ),
      ],
    );
  }

  /// A platform with nothing working: no voice and no notifications, so
  /// every notice in the app is up at once and the screens under them are at
  /// their most crowded.
  void withNothingWorking() => useContainer(
    player: FakeCuePlayer(hasVoice: false)..notifyAllowed = false,
  );

  const sizes = {'small': Size(320, 640), 'ordinary': Size(360, 800)};

  for (final entry in sizes.entries) {
    group('on a ${entry.key} screen', () {
      final size = entry.value;

      testWidgets('the list of workouts fits', (tester) async {
        await pumpAt(tester, const PresetsScreen(), size: size);
        expect(tester.takeException(), isNull);

        // Both sections, both "new" buttons and the stopwatch, on the
        // narrowest screen. Home is the one screen that grew when focus
        // arrived.
        expect(find.text('Workouts'), findsOneWidget);
        expect(find.text('Focus'), findsOneWidget);
        expect(find.text('Stopwatch'), findsOneWidget);
      });

      testWidgets('a focus session waiting to start fits', (tester) async {
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);
        await pumpAt(tester, const FocusScreen(), size: size);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');
        // Measured against its own line height rather than another label:
        // this one is titleMedium and "Edit" is a button's own style, so the
        // two heights were never comparable.
        expectSingleLine(tester, 'Silence the phone');
      });

      testWidgets('a focus session that may not silence the phone fits', (
        tester,
      ) async {
        // Asked for but not allowed: the row grows a second line, and it is
        // the longest sentence this screen ever has to hold.
        useContainer(
          player: FakeCuePlayer()..silenceAllowed = false,
          settings: const AppSettings(silenceDuringFocus: true),
        );
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);
        await pumpAt(tester, const FocusScreen(), size: size);
        await tester.pump();

        expect(find.textContaining('Android has to allow'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');
      });

      testWidgets('nothing offers to silence a phone that cannot', (
        tester,
      ) async {
        // iOS: no app can turn a Focus on, so there is no switch to turn on.
        // Null is not false.
        useContainer(player: FakeCuePlayer()..silenceAllowed = null);
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);
        await pumpAt(tester, const FocusScreen(), size: size);
        await tester.pump();

        expect(find.text('Silence the phone'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a focus session in progress fits', (tester) async {
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);
        await pumpAt(tester, const FocusScreen(), size: size);
        await container.read(runProvider.notifier).start();
        await tester.pump();

        // No warm up on a focus session: it starts in the first block.
        expect(find.text('Focus'), findsOneWidget);
        expect(find.text('Block 1 of 4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final label in ['Stop', 'Pause']) {
          expectOneLine(tester, label, shortEnoughToNeverWrap: 'Skip');
        }

        await container.read(runProvider.notifier).stop();
      });

      testWidgets('a finished focus session fits', (tester) async {
        container.read(selectedWorkoutIdProvider.notifier).select(focus.id);
        await pumpAt(tester, const FocusScreen(), size: size);
        final run = container.read(runProvider.notifier);
        await run.start();

        (container.read(clockProvider) as FakeClock).advance(3 * 60 * 60 * 1000);
        await run.resync();
        await tester.pump();

        expect(find.text('Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Again', shortEnoughToNeverWrap: 'Home');

        await run.stop();
      });

      testWidgets('the focus editor fits', (tester) async {
        await pumpAt(tester, EditorScreen(id: focus.id), size: size);
        expect(tester.takeException(), isNull);

        // The total in the badge is "2:10:00" where a workout's is "5:20",
        // and inside a small disc it wrapped to "2:10:0 / 0" — which throws
        // nothing, so only measuring it finds it.
        expectOneLine(tester, '2:10:00', shortEnoughToNeverWrap: 'Focus');

        // Four numbers and nothing else: no warm up, no exercises, and no
        // switches for a script that is fixed quiet.
        expect(find.text('Long break'), findsOneWidget);
        expect(find.text('Get ready'), findsNothing);
        expect(find.text('What it says'), findsNothing);
      });

      testWidgets('a workout waiting to start fits', (tester) async {
        await pumpAt(tester, const RunScreen(), size: size);
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');
      });

      testWidgets('a workout waiting to start fits with both notices up', (
        tester,
      ) async {
        // The tightest this screen ever gets: the dial is the only thing that
        // can give way, and it has to give way rather than Start.
        withNothingWorking();
        await pumpAt(tester, const RunScreen(), size: size);
        // The platform answers both questions a frame later.
        await tester.pump();

        expect(
          find.textContaining('Notifications are off'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');

        // The ring is what gives way, and on a 320dp phone with both notices
        // showing it has given way to almost nothing — which is the screen
        // behaving as intended, and also why this test exists. There are a
        // dozen logical pixels in hand here, so a longer notice fails on the
        // line above rather than in a screenshot.
        expect(tester.getSize(find.byType(TickRing)).height, greaterThan(0));
      });

      // One screen under every theme. The contrast arithmetic lives in
      // theme_test; this is here for the other thing a palette can break —
      // a layout that quietly assumed the colours it was given.
      for (final theme in AppColors.themes.skip(1)) {
        testWidgets('a workout waiting to start fits in ${theme.name}', (
          tester,
        ) async {
          await pumpAt(tester, const RunScreen(), size: size, theme: theme);
          expect(tester.takeException(), isNull);
          expectOneLine(tester, 'Start', shortEnoughToNeverWrap: 'Edit');
          expect(tester.getSize(find.byType(TickRing)).height, greaterThan(0));
        });
      }

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

      testWidgets('a finished workout fits', (tester) async {
        await pumpAt(tester, const RunScreen(), size: size);
        final run = container.read(runProvider.notifier);
        await run.start();

        // Run the clock past the end of the whole workout. The state is a
        // snapshot the ticker publishes, so it has to be asked to republish —
        // which is what the app itself does when it comes back to the front.
        (container.read(clockProvider) as FakeClock).advance(60 * 60 * 1000);
        await run.resync();
        await tester.pump();

        expect(find.text('Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectOneLine(tester, 'Workouts', shortEnoughToNeverWrap: 'Again');

        await run.stop();
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

        // Three segments to a row, four rows of them, on the narrowest phone
        // the app supports. These are the newest thing on this screen and the
        // most likely to wrap.
        for (final label in ['Voice', 'Tone', 'Both']) {
          expectSingleLine(tester, label);
        }
        expectSingleLine(tester, 'Phase changes');

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // The chosen segment carries more than the others and is the one
        // that wraps. 'Off' is never chosen in this fixture, so it is the
        // honest single-line reference.
        expectOneLine(tester, '1m', shortEnoughToNeverWrap: 'Off');

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('picking your own sounds fits, and says what it did', (
        tester,
      ) async {
        useContainer(
          player: FakeCuePlayer()
            ..own = const {'tone-work': 'Chime'},
          settings: const AppSettings(sounds: SoundSettings.tones),
        );
        await pumpAt(tester, const SettingsScreen(), size: size);
        await tester.pump();

        await tester.dragUntilVisible(
          find.text('Tones'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // The replaced one says what it was replaced with; the rest say whose
        // tone they are. A row that said neither would be the bug here.
        expect(find.text('Chime'), findsOneWidget);
        expect(find.text('Wood tone'), findsNWidgets(4));
        expectSingleLine(tester, 'Halfway');

        // The way back is a label, not a bare icon with a tooltip. It was an
        // undo arrow, and a tooltip on a phone needs a long press — so in
        // practice there was no way back at all from a sound you had picked.
        // Exactly one, on the row that has something to undo.
        expect(find.text('Use ours'), findsOneWidget);
        expect(find.text('Change'), findsNWidgets(5));

        // And every sound can be heard before it is chosen, ours included.
        expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(5));

        // Every set is offered, and exactly one is on.
        for (final pack in TonePack.values) {
          expect(find.text(pack.label), findsOneWidget);
        }
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('the rows follow whichever set is on', (tester) async {
        useContainer(
          player: FakeCuePlayer(),
          settings: const AppSettings(
            sounds: SoundSettings(
              pack: TonePack.tabla,
              phase: SoundMode.tone,
            ),
          ),
        );
        await pumpAt(tester, const SettingsScreen(), size: size);
        await tester.pump();
        await tester.dragUntilVisible(
          find.text('Tones'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pump();

        // Five rows saying whose tone they play, and it is the chosen set's —
        // not the default's, and not a label frozen at build time.
        expect(find.text('Tabla tone'), findsNWidgets(5));
        expect(find.text('Wood tone'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('there is nothing to undo until something is replaced', (
        tester,
      ) async {
        useContainer(
          player: FakeCuePlayer(),
          settings: const AppSettings(sounds: SoundSettings.tones),
        );
        await pumpAt(tester, const SettingsScreen(), size: size);
        await tester.pump();
        await tester.dragUntilVisible(
          find.text('Tones'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pump();

        expect(find.text('Use ours'), findsNothing);
        expect(find.text('Wood tone'), findsNWidgets(5));
      });

      testWidgets('nothing offers to replace a sound where it cannot', (
        tester,
      ) async {
        // iOS: no app can read or offer the system's sounds, so there is no
        // section at all. Null is not empty.
        useContainer(
          player: FakeCuePlayer()..own = null,
          settings: const AppSettings(sounds: SoundSettings.tones),
        );
        await pumpAt(tester, const SettingsScreen(), size: size);
        await tester.pump();

        expect(find.text('Tones'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('nothing offers to replace a tone nothing will play', (
        tester,
      ) async {
        // Every cue is spoken, so no tone is ever reached. Offering to change
        // one is an invitation to wonder why nothing happened.
        useContainer(player: FakeCuePlayer());
        await pumpAt(tester, const SettingsScreen(), size: size);
        await tester.pump();

        expect(find.text('Tones'), findsNothing);
      });

      testWidgets('settings fit with both notices up', (tester) async {
        // The worst case for this screen: no voice and no notifications, so
        // both notices are up and the longest prose in the app is above the
        // fold. The notification one carries an action row of a fixed height,
        // which is the only thing here that cannot grow to fit its label —
        // and a label that wraps inside it does not overflow, so nothing
        // would throw.
        withNothingWorking();

        await pumpAt(tester, const SettingsScreen(), size: size);
        // The platform answers both questions a frame later.
        await tester.pump();

        expect(find.text('Notifications are off'), findsOneWidget);
        expect(find.text('This phone has no voice installed'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectSingleLine(tester, 'Turn them on');
      });
    });
  }
}

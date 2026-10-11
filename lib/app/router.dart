import 'package:go_router/go_router.dart';

import '../core/store/store.dart';
import '../core/timeline/workout.dart';

import '../features/edit/ui/editor_screen.dart';
import '../features/focus/ui/focus_screen.dart';
import '../features/presets/ui/presets_screen.dart';
import '../features/run/ui/run_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/stopwatch/ui/stopwatch_screen.dart';

/// Six screens, one level deep. The list is home because choosing what to do
/// is the first thing that happens, and everything else is a step away from it.
///
/// `/run` and `/focus` are two screens over one controller: the same session,
/// drawn for a gym or drawn for a desk.
GoRouter appRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const PresetsScreen(),
      routes: [
        GoRoute(path: 'run', builder: (_, _) => const RunScreen()),
        GoRoute(path: 'focus', builder: (_, _) => const FocusScreen()),
        GoRoute(
          path: 'edit/:id',
          builder: (_, state) =>
              EditorScreen(id: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(path: 'stopwatch', builder: (_, _) => const StopwatchScreen()),
        GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
  ],
);

/// Where the app opens.
///
/// A session outlives the UI — the foreground service keeps playing while the
/// activity that started it is long gone — so the app often has to open on one
/// rather than on the list. [running] is the platform's answer to "is there
/// still a session", which only it can give.
///
/// Which screen depends on what the session is. One controller runs both, and
/// a focus session restored onto the run screen would be the right session
/// drawn in the loudest way there is.
String startLocation(AppData data, {required bool running}) {
  if (!running) return '/';

  final kind = data.presets
      .where((p) => p.id == data.runningWorkoutId)
      .firstOrNull
      ?.kind;

  return switch (kind) {
    // Written down, but no longer in the list: the preset was deleted while
    // it ran. Open on the list rather than on a screen with nothing behind it.
    null => '/',
    TimerKind.focus => '/focus',
    TimerKind.workout => '/run',
  };
}

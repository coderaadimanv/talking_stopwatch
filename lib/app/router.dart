import 'package:go_router/go_router.dart';

import '../features/edit/ui/editor_screen.dart';
import '../features/presets/ui/presets_screen.dart';
import '../features/run/ui/run_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/stopwatch/ui/stopwatch_screen.dart';

/// Five screens, one level deep. The list is home because choosing what to do
/// is the first thing that happens, and everything else is a step away from it.
GoRouter appRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const PresetsScreen(),
      routes: [
        GoRoute(path: 'run', builder: (_, _) => const RunScreen()),
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

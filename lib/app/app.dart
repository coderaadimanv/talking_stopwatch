import 'package:flutter/material.dart';

import 'palette.dart';
import 'sizes.dart';

/// The app's theme. Dark by default: this screen gets looked at in a gym, at
/// six in the morning, and it is mostly one enormous number.
ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.work,
      brightness: Brightness.dark,
      surface: Palette.surface,
    ),
    scaffoldBackgroundColor: Palette.ink,
    extensions: const [AppColors.dark],
  );

  return base.copyWith(
    // Sizes belong to the theme, so no screen has to name them.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(Sizes.control, Sizes.control),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(Sizes.control, Sizes.control),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(Sizes.control, Sizes.control),
      ),
    ),
    iconTheme: const IconThemeData(size: Sizes.icon),
    listTileTheme: const ListTileThemeData(minTileHeight: Sizes.row),
  );
}

class TalkingStopwatchApp extends StatelessWidget {
  const TalkingStopwatchApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Talking Stopwatch',
    theme: appTheme(),
    home: const _Scaffolding(),
  );
}

/// Phase 1 ships the core and its tests; the run screen arrives with the
/// Android audio layer in Phase 2. Until then there is something to launch.
class _Scaffolding extends StatelessWidget {
  const _Scaffolding();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(Sizes.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Talking Stopwatch',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Sizes.gap),
            Text(
              'The cue engine is in place and tested.\n'
              'The run screen comes with the audio layer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.idle,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

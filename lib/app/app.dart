import 'package:flutter/material.dart';

import 'palette.dart';
import 'router.dart';
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
    // The two sizes that carry the screen. They live here rather than in the
    // run screen because a size named in a widget is a size nobody can compare
    // against the others.
    textTheme: base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontSize: Sizes.countdownText,
        fontWeight: FontWeight.w200,
        height: 1,
        letterSpacing: -4,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: Sizes.phaseText,
        fontWeight: FontWeight.w600,
      ),
    ),
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
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Talking Stopwatch',
    theme: appTheme(),
    routerConfig: _router,
  );
}

final _router = appRouter();

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'style.dart';

class CadentApp extends ConsumerWidget {
  const CadentApp({super.key, this.initialLocation = '/'});

  /// Where to open. `/run` when a workout is already under way, so the app
  /// comes back to it rather than to a list it has to be found in again.
  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched here and nowhere else: a theme is one object handed to
    // MaterialApp, and every screen reads it back out of the tree through
    // `context.colors`. So changing it rebuilds everything and no screen has
    // to know the setting exists.
    final themeId = ref.watch(
      appDataProvider.select((data) => data.settings.themeId),
    );

    return MaterialApp.router(
      title: 'Cadent',
      theme: appTheme(AppColors.byId(themeId)),
      routerConfig: appRouter(initialLocation: initialLocation),
    );
  }
}

import 'package:flutter/material.dart';

import 'router.dart';
import 'style.dart';

class CadentApp extends StatelessWidget {
  const CadentApp({super.key, this.initialLocation = '/'});

  /// Where to open. `/run` when a workout is already under way, so the app
  /// comes back to it rather than to a list it has to be found in again.
  final String initialLocation;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Cadent',
    theme: appTheme(),
    routerConfig: appRouter(initialLocation: initialLocation),
  );
}

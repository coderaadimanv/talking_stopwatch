import 'package:flutter/material.dart';

import 'router.dart';
import 'style.dart';

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

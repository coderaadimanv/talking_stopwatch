import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/audio/platform_cue_player.dart';
import 'core/store/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the saved workout before the first frame. It is one small file, so
  // this costs a few milliseconds and saves every screen from having to render
  // a loading state it would otherwise need.
  final directory = await getApplicationDocumentsDirectory();
  final store = Store(File('${directory.path}/data.json'));
  final data = await store.load();

  // A session may still be running, started by a screen that no longer
  // exists: the foreground service outlives the UI. Ask the platform before
  // the first frame, so the app opens on the session rather than flashing the
  // list and jumping.
  final player = PlatformCuePlayer();
  final running =
      data.runningWorkoutId != null && await player.elapsedMs() != null;

  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(data),
        cuePlayerProvider.overrideWithValue(player),
      ],
      child: CadentApp(
        initialLocation: startLocation(data, running: running),
      ),
    ),
  );
}

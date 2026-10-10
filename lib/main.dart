import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/store/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the saved workout before the first frame. It is one small file, so
  // this costs a few milliseconds and saves every screen from having to render
  // a loading state it would otherwise need.
  final directory = await getApplicationDocumentsDirectory();
  final store = Store(File('${directory.path}/data.json'));
  final data = await store.load();

  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const TalkingStopwatchApp(),
    ),
  );
}

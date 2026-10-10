import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/style.dart';
import '../../../app/providers.dart';
import '../../../core/cues/cue.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appDataProvider).settings;
    final data = ref.read(appDataProvider.notifier);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Sizes.gap),
        children: [
          if (!hasVoice)
            ListTile(
              leading: Icon(Icons.volume_off, color: context.colors.danger),
              title: const Text('This phone has no voice installed'),
              subtitle: const Text(
                'Timers still run, they just will not speak. Install a '
                'text-to-speech voice in Android settings.',
              ),
            ),

          const _Heading('Stopwatch'),
          ListTile(
            title: const Text('Call out the time'),
            subtitle: Text(
              settings.stopwatchAnnounceSeconds == 0
                  ? 'Never'
                  : 'Every ${settings.stopwatchAnnounceSeconds} seconds',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.gutter),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Off')),
                ButtonSegment(value: 15, label: Text('15s')),
                ButtonSegment(value: 30, label: Text('30s')),
                ButtonSegment(value: 60, label: Text('1m')),
              ],
              selected: {settings.stopwatchAnnounceSeconds},
              onSelectionChanged: (choice) => data.editSettings(
                (s) => s.copyWith(stopwatchAnnounceSeconds: choice.first),
              ),
            ),
          ),

          const _Heading('Timing'),
          ListTile(
            title: const Text('Audio delay'),
            subtitle: Text(
              settings.offsetMs == 0
                  ? 'Cues play on the beat'
                  : settings.offsetMs < 0
                  ? 'Cues play ${-settings.offsetMs}ms early'
                  : 'Cues play ${settings.offsetMs}ms late',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.gutter),
            child: Slider(
              value: settings.offsetMs.toDouble(),
              min: -500,
              max: 500,
              divisions: 20,
              label: '${settings.offsetMs}ms',
              onChanged: (value) =>
                  data.editSettings((s) => s.copyWith(offsetMs: value.round())),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Sizes.gutter),
            child: Text(
              'Bluetooth earbuds run 150–300ms behind and will not say how '
              'far. If the countdown sounds late on yours, drag this to the '
              'left until it lands on the beat.',
            ),
          ),
          const SizedBox(height: Sizes.gap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.gutter),
            child: OutlinedButton.icon(
              onPressed: () => _testVoice(ref),
              icon: const Icon(Icons.volume_up),
              label: const Text('Test the voice'),
            ),
          ),

          const _Heading('Screen'),
          SwitchListTile(
            title: const Text('Keep the screen on'),
            subtitle: const Text(
              'Uses more battery. Cues play with the screen off anyway, so '
              'this is only for watching the countdown.',
            ),
            value: settings.keepScreenOn,
            onChanged: (v) =>
                data.editSettings((s) => s.copyWith(keepScreenOn: v)),
          ),
        ],
      ),
    );
  }

  /// Says one word down the real path — rendered, cached and scheduled — so
  /// what you hear is what a cue will sound like, delay and all.
  Future<void> _testVoice(WidgetRef ref) async {
    const cue = Cue(atMs: 0, text: 'Go', priority: CuePriority.phaseWord);
    final player = ref.read(cuePlayerProvider);
    await player.describe('Talking Stopwatch', 'Testing the voice');
    await player.warm(const [cue]);
    await player.schedule(const [cue], countUp: true);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Sizes.gutter,
      Sizes.bigGap,
      Sizes.gutter,
      Sizes.gap,
    ),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: context.colors.muted,
        letterSpacing: 1.5,
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_badge.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/cues/cue.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appDataProvider).settings;
    final data = ref.read(appDataProvider.notifier);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final face = colors.faceOn(colors.stopwatch);
    final deep = colors.deepOf(colors.stopwatch);

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(
        backgroundColor: Brand.transparent,
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: SoftBackground(
        color: Brand.ink,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sizes.gutter,
              Sizes.gap,
              Sizes.gutter,
              Sizes.bigGap,
            ),
            children: [
              if (!hasVoice) ...[
                Card(
                  child: ListTile(
                    leading: Icon(Icons.volume_off, color: colors.danger),
                    title: const Text('This phone has no voice installed'),
                    subtitle: const Text(
                      'Timers still run, they just will not speak. Install a '
                      'text-to-speech voice in Android settings.',
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: Sizes.gap),
              ],

              _Section(
                icon: Icons.timer_outlined,
                title: 'Stopwatch',
                face: face,
                deep: deep,
                children: [
                  _Row(
                    title: 'Call out the time',
                    value: settings.stopwatchAnnounceSeconds == 0
                        ? 'Never'
                        : 'Every ${settings.stopwatchAnnounceSeconds} seconds',
                  ),
                  const SizedBox(height: Sizes.gap),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Off')),
                      ButtonSegment(value: 15, label: Text('15s')),
                      ButtonSegment(value: 30, label: Text('30s')),
                      ButtonSegment(value: 60, label: Text('1m')),
                    ],
                    showSelectedIcon: false,
                    selected: {settings.stopwatchAnnounceSeconds},
                    onSelectionChanged: (choice) => data.editSettings(
                      (s) =>
                          s.copyWith(stopwatchAnnounceSeconds: choice.first),
                    ),
                  ),
                ],
              ),

              _Section(
                icon: Icons.graphic_eq_rounded,
                title: 'Timing',
                face: face,
                deep: deep,
                children: [
                  _Row(
                    title: 'Audio delay',
                    value: settings.offsetMs == 0
                        ? 'On the beat'
                        : settings.offsetMs < 0
                        ? '${-settings.offsetMs}ms early'
                        : '${settings.offsetMs}ms late',
                  ),
                  Slider(
                    value: settings.offsetMs.toDouble(),
                    min: -500,
                    max: 500,
                    divisions: 20,
                    label: '${settings.offsetMs}ms',
                    onChanged: (value) => data.editSettings(
                      (s) => s.copyWith(offsetMs: value.round()),
                    ),
                  ),
                  Text(
                    'Bluetooth earbuds run 150–300ms behind and will not say '
                    'how far. If the countdown sounds late on yours, drag '
                    'this to the left until it lands on the beat.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Sizes.gap),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _testVoice(ref),
                      icon: const Icon(Icons.volume_up),
                      label: const ActionLabel('Test the voice'),
                    ),
                  ),
                ],
              ),

              _Section(
                icon: Icons.light_mode_outlined,
                title: 'Screen',
                face: face,
                deep: deep,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep the screen on'),
                    subtitle: const Text(
                      'Uses more battery. Cues play with the screen off '
                      'anyway, so this is only for watching the countdown.',
                    ),
                    value: settings.keepScreenOn,
                    onChanged: (v) =>
                        data.editSettings((s) => s.copyWith(keepScreenOn: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
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

/// A heading with its own badge, and the card of settings under it.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.face,
    required this.deep,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color face;
  final Color deep;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          top: Sizes.bigGap,
          bottom: Sizes.gap,
          left: Sizes.gap / 2,
        ),
        child: Row(
          children: [
            CircleBadge(
              size: Sizes.badgeTiny,
              background: face,
              child: Icon(icon, color: deep, size: Sizes.iconSmall),
            ),
            const SizedBox(width: Sizes.gap),
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

/// A setting's name, with what it is currently set to beside it.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(title, style: text.titleMedium)),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}

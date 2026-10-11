import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/section.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/cues/cue.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// How far the calibration slider goes either way.
  static const _offsetRangeMs = 500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appDataProvider).settings;
    final data = ref.read(appDataProvider.notifier);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(
        leadingWidth: Sizes.bigControl,
        leading: Padding(
          padding: const EdgeInsets.only(left: Sizes.gap),
          child: IconButton(
            onPressed: () => context.go('/'),
            style: chipIconButton(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: const Text('Settings'),
      ),
      body: SoftBackground(
        color: Brand.ink,
        glow: colors.work,
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

              Section(
                icon: Icons.timer_outlined,
                title: 'Stopwatch',
                subtitle: 'Call out the time',
                children: [
                  _Reading(
                    label: settings.stopwatchAnnounceSeconds == 0
                        ? 'The stopwatch stays quiet'
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
                    // No tick. Four segments across a 320dp phone leave about
                    // 64 logical pixels each, and the tick takes a third of
                    // that — enough to wrap "1m" onto two lines. The solid
                    // fill already says which one is chosen.
                    showSelectedIcon: false,
                    selected: {settings.stopwatchAnnounceSeconds},
                    onSelectionChanged: (choice) => data.editSettings(
                      (s) =>
                          s.copyWith(stopwatchAnnounceSeconds: choice.first),
                    ),
                  ),
                ],
              ),

              Section(
                icon: Icons.graphic_eq_rounded,
                title: 'Timing',
                subtitle: 'Audio delay',
                children: [
                  _Reading(
                    label: settings.offsetMs == 0
                        ? 'Cues play on the beat'
                        : settings.offsetMs < 0
                        ? 'Cues play early'
                        : 'Cues play late',
                    value: settings.offsetMs == 0
                        ? '0 ms'
                        : '${settings.offsetMs.abs()} ms',
                  ),
                  Slider(
                    value: settings.offsetMs.toDouble(),
                    min: -_offsetRangeMs.toDouble(),
                    max: _offsetRangeMs.toDouble(),
                    divisions: 20,
                    onChanged: (value) => data.editSettings(
                      (s) => s.copyWith(offsetMs: value.round()),
                    ),
                  ),
                  // The ends mean opposite things and a number alone does not
                  // say which. Just the direction: the reading above already
                  // gives the size, and spelling out both bounds in full is
                  // wider than a 320dp phone has to give.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Early', style: text.bodySmall),
                      Text('Late', style: text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: Sizes.gap),
                  Text(
                    'Bluetooth earbuds run 150–300ms behind and will not say '
                    'how far. If the countdown sounds late on yours, drag '
                    'this to the left until it lands on the beat.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Sizes.gap),
                  _ActionRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Test the voice',
                    onTap: () => _testVoice(ref),
                  ),
                ],
              ),

              Section(
                icon: Icons.light_mode_outlined,
                title: 'Screen',
                subtitle: 'Keep the screen on',
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

/// What a setting currently says, and the number behind it.
class _Reading extends StatelessWidget {
  const _Reading({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.bodyLarge)),
        if (value != null)
          Text(
            value!,
            style: text.titleMedium?.copyWith(color: context.colors.work),
          ),
      ],
    );
  }
}

/// A row that does something, rather than setting something.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Brand.transparent,
    borderRadius: BorderRadius.circular(Sizes.radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: Sizes.control,
        padding: const EdgeInsets.symmetric(horizontal: Sizes.gutter),
        decoration: BoxDecoration(
          border: Border.all(color: Brand.cardLine, width: Sizes.hairline),
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        child: Row(
          children: [
            Icon(icon, size: Sizes.icon, color: context.colors.work),
            const SizedBox(width: Sizes.gap),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: Sizes.icon,
              color: context.colors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

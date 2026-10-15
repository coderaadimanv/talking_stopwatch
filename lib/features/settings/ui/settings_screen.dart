import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/section.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/audio/cue_player.dart';
import '../../../core/cues/cue.dart';
import '../../../core/cues/sound_settings.dart';
import '../../../core/cues/tone.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// How far the calibration slider goes either way.
  static const _offsetRangeMs = 500;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Turning notifications back on happens on a system screen, so the app is
    // in the background while the answer changes and coming back is the only
    // notice it gets. Without this the notice stays up after it has been
    // fixed, which reads as the fix not having worked.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(canNotifyProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appDataProvider).settings;
    final data = ref.read(appDataProvider.notifier);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;
    // Nothing until the platform has answered, and nothing at all where the
    // question does not apply: a notice about a missing permission is worse
    // than useless on a phone that has no such permission.
    final canNotify = ref.watch(canNotifyProvider).asData?.value;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.colors.ground,
      appBar: AppBar(
        leadingWidth: Sizes.bigControl,
        leading: Padding(
          padding: const EdgeInsets.only(left: Sizes.gap),
          child: IconButton(
            onPressed: () => context.go('/'),
            style: chipIconButton(context.colors),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: const Text('Settings'),
      ),
      body: SoftBackground(
        color: context.colors.ground,
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
                const _Notice(
                  icon: Icons.volume_off,
                  title: 'This phone has no voice installed',
                  body:
                      'Timers still run, they just will not speak. Install a '
                      'text-to-speech voice in Android settings.',
                ),
                const SizedBox(height: Sizes.gap),
              ],

              if (canNotify == false) ...[
                _Notice(
                  icon: Icons.notifications_off_outlined,
                  title: 'Notifications are off',
                  body:
                      'Workouts still run and still talk. What is missing is '
                      'the session on your lock screen: the countdown, and '
                      'the Pause and Stop buttons that work without '
                      'unlocking the phone.',
                  actionLabel: 'Turn them on',
                  onAction: () =>
                      ref.read(cuePlayerProvider).openNotifySettings(),
                ),
                const SizedBox(height: Sizes.gap),
              ],

              Section(
                icon: Icons.music_note_outlined,
                title: 'Sound',
                subtitle: _soundSummary(settings.sounds),
                children: [
                  _SoundRow(
                    label: 'Phase changes',
                    detail: settings.sounds.phase == SoundMode.tone
                        ? 'A tone cannot say which round it is'
                        : '"Go, round 3" · "Rest" · "Done"',
                    mode: settings.sounds.phase,
                    onChanged: (m) => data.editSettings(
                      (s) => s.copyWith(sounds: s.sounds.copyWith(phase: m)),
                    ),
                  ),
                  _SoundRow(
                    label: 'Countdown',
                    detail: '"three, two, one" into a change',
                    mode: settings.sounds.countdown,
                    onChanged: (m) => data.editSettings(
                      (s) =>
                          s.copyWith(sounds: s.sounds.copyWith(countdown: m)),
                    ),
                  ),
                  _SoundRow(
                    label: 'Halfway',
                    detail: 'Through a long work phase',
                    mode: settings.sounds.halfway,
                    onChanged: (m) => data.editSettings(
                      (s) => s.copyWith(sounds: s.sounds.copyWith(halfway: m)),
                    ),
                  ),
                  _SoundRow(
                    label: 'Stopwatch time',
                    detail: 'The stopwatch reading the time out',
                    mode: settings.sounds.elapsed,
                    onChanged: (m) => data.editSettings(
                      (s) => s.copyWith(sounds: s.sounds.copyWith(elapsed: m)),
                    ),
                  ),
                ],
              ),

              // Only where tones are actually being used. Offering to replace
              // a sound nothing is going to play is an invitation to wonder
              // why nothing happened.
              if (settings.sounds.usesTones) const _OwnSounds(),

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
                    onTap: _testVoice,
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

              Section(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: colors.name,
                children: [
                  for (final theme in AppColors.themes)
                    _ThemeRow(
                      theme: theme,
                      chosen: theme.id == colors.id,
                      onTap: () => data.editSettings(
                        (s) => s.copyWith(themeId: theme.id),
                      ),
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
  Future<void> _testVoice() =>
      playOnce(ref.read(cuePlayerProvider), const Cue(
        atMs: 0,
        text: 'Go',
        priority: CuePriority.phaseWord,
      ), 'Testing the voice');
}

/// Plays one cue now, down the real path, and then lets go.
///
/// Scheduling is how this app makes any sound at all, so a preview goes the
/// same way: rendered or installed, loaded, armed and fired. What you hear is
/// exactly what a session will play, the calibration delay and the user's own
/// sound included.
///
/// The cancel at the end is not tidiness. A schedule that counts up has no end
/// to stop itself at — that is what a stopwatch needs — so without this the
/// service and its notification stay up after a one-shot preview, which is
/// what the voice test has been doing. The wait is longer than any clip,
/// including one of the user's own at its cap.
Future<void> playOnce(CuePlayer player, Cue cue, String saying) async {
  await player.describe('Cadent', saying);
  await player.warm([cue]);
  await player.schedule([cue], countUp: true);
  await Future<void>.delayed(const Duration(seconds: 3));
  await player.cancel();
}

/// Replacing one of the app's tones with a sound off the phone.
///
/// Not on every tone: the countdown's tick is ours and stays ours. Three of
/// them land a second apart, and a notification sound in their place would
/// still be ringing when the next one is due — the one thing that makes a
/// timer unreadable by ear. It is a timing mark rather than an event, and
/// the others are events.
///
/// The section is absent, rather than disabled, where picking cannot work at
/// all: on iOS no app can read or offer the system's sounds, so there is
/// nothing here to show and a greyed-out row would only promise otherwise.
class _OwnSounds extends ConsumerWidget {
  const _OwnSounds();

  /// Each replaceable tone, and what the row is for.
  /// One word each. A 320dp phone leaves a list row about two hundred logical
  /// pixels once the trailing control has taken its share, and "Rest and
  /// breaks" wraps in it — so what the rest tone also covers is said in the
  /// footnote rather than in the row.
  static const _rows = [
    (Tone.work, 'Work'),
    (Tone.rest, 'Rest'),
    (Tone.ready, 'Ready'),
    (Tone.halfway, 'Halfway'),
    (Tone.done, 'Finished'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = ref.watch(ownSoundsProvider).asData?.value;
    if (own == null) return const SizedBox.shrink();

    final player = ref.read(cuePlayerProvider);
    Future<void> refreshAfter(Future<void> work) async {
      await work;
      ref.invalidate(ownSoundsProvider);
    }

    final pack = ref.watch(
      appDataProvider.select((data) => data.settings.sounds.pack),
    );
    final data = ref.read(appDataProvider.notifier);

    return Section(
      icon: Icons.library_music_outlined,
      title: 'Tones',
      subtitle: own.isEmpty
          ? pack.detail
          : '${pack.label} · ${own.length} replaced',
      children: [
        // The same shape as the theme picker: a tick on the one that is on,
        // an empty ring on the rest.
        for (final choice in TonePack.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(choice.label),
            subtitle: Text(choice.detail),
            onTap: () => data.editSettings(
              (s) => s.copyWith(sounds: s.sounds.copyWith(pack: choice)),
            ),
            trailing: Icon(
              choice == pack
                  ? Icons.check_rounded
                  : Icons.circle_outlined,
              color: choice == pack
                  ? context.colors.work
                  : context.colors.line,
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(bottom: Sizes.gap),
          child: Text(
            'Any one of them can be a sound off your phone instead.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final (tone, label) in _rows)
          _SoundChoice(
            label: label,
            sound: own[tone.key] ?? '${pack.label} tone',
            replaced: own.containsKey(tone.key),
            onPlay: () => playOnce(
              player,
              Cue(
                atMs: 0,
                tone: tone,
                pack: pack,
                priority: CuePriority.phaseWord,
              ),
              'Playing $label',
            ),
            onChange: () => refreshAfter(player.pickSound(tone.key)),
            onReset: () => refreshAfter(player.clearSound(tone.key)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Sizes.gap / 2),
          child: Text(
            'Rest covers breaks and the cool down too. The countdown keeps '
            'its own tick: three of them land a second apart, and a longer '
            'sound would still be ringing when the next one is due. A sound '
            'you pick is copied, so it keeps working if you move or delete '
            'the original, and it is faded out after a second and a half.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// One tone: what it is, what it currently plays, and what can be done to it.
///
/// Three controls rather than a tappable row, and the middle one is the whole
/// reason this was rebuilt. The reset used to be a bare undo arrow with a
/// tooltip, and a tooltip on a phone needs a long press — so in practice there
/// was no way back from a sound you had picked. A control nobody can find is
/// not a control.
///
/// Play is first because you cannot judge a sound you have not heard, and that
/// applies to ours as much as to theirs.
class _SoundChoice extends StatelessWidget {
  const _SoundChoice({
    required this.label,
    required this.sound,
    required this.replaced,
    required this.onPlay,
    required this.onChange,
    required this.onReset,
  });

  final String label;
  final String sound;
  final bool replaced;
  final VoidCallback onPlay;
  final VoidCallback onChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: text.titleMedium),
              const SizedBox(width: Sizes.gap),
              // What it plays now, given the room the name leaves it.
              Expanded(
                child: Text(
                  sound,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          // The two labels are Expanded, not merely shrink-to-fit: ActionLabel
          // scales a label down only when something has bounded its width, and
          // a Row gives its children all the room they ask for. Unbounded, the
          // pair overflowed a 320dp phone by fifty pixels.
          Row(
            children: [
              IconButton(
                onPressed: onPlay,
                tooltip: 'Play it',
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onChange,
                  child: const ActionLabel('Change'),
                ),
              ),
              if (replaced)
                Expanded(
                  child: TextButton(
                    onPressed: onReset,
                    child: const ActionLabel('Use ours'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the Sound section is set to, in a phrase rather than four words.
String _soundSummary(SoundSettings sounds) {
  final modes = {sounds.phase, sounds.countdown, sounds.halfway, sounds.elapsed};
  if (modes.length > 1) return 'Voice and tones';
  return switch (modes.first) {
    SoundMode.voice => 'The phone speaks',
    SoundMode.tone => 'Tones only',
    SoundMode.both => 'A tone, then the words',
  };
}

/// One kind of cue, and how it is sounded.
///
/// The detail line under the label is doing real work on the phase row: a
/// round number is spoken as part of its phase word rather than as a cue of
/// its own, so choosing a tone there is choosing to lose it. That is the only
/// thing in this feature anybody can be surprised by, so it is said at the
/// moment it becomes true rather than buried in a help page.
class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.label,
    required this.detail,
    required this.mode,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final SoundMode mode;
  final ValueChanged<SoundMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.bigGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleMedium),
          Text(detail, style: text.bodySmall),
          const SizedBox(height: Sizes.gap),
          SegmentedButton<SoundMode>(
            // ActionLabel, not Text: three segments on a 320dp phone leave
            // about fifty logical pixels of text each, and "Voice" wants more
            // than that — it wrapped to two lines, which throws nothing and
            // looks like a design choice.
            segments: const [
              ButtonSegment(
                value: SoundMode.voice,
                label: ActionLabel('Voice'),
              ),
              ButtonSegment(value: SoundMode.tone, label: ActionLabel('Tone')),
              ButtonSegment(value: SoundMode.both, label: ActionLabel('Both')),
            ],
            // No tick, for the same reason as the stopwatch's row: three
            // segments on a 320dp phone have no width to give away.
            showSelectedIcon: false,
            selected: {mode},
            onSelectionChanged: (choice) => onChanged(choice.first),
          ),
        ],
      ),
    );
  }
}

/// One theme to choose, shown as the thing it actually changes.
///
/// Three dots rather than a swatch: a theme is a *set* of colours that have to
/// stay tellable apart, so the row shows the three you will spend the session
/// looking at — work, rest and the long break — instead of one accent that
/// says nothing about whether the run screen will be readable.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.chosen,
    required this.onTap,
  });

  final AppColors theme;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: SizedBox(
        width: Sizes.badgeTiny,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final colour in [theme.work, theme.rest, theme.breakBetween])
              Padding(
                padding: const EdgeInsets.only(right: Sizes.gap / 4),
                child: _Swatch(colour: colour),
              ),
          ],
        ),
      ),
      title: Text(theme.name),
      // The tick wears the theme's own accent, not the one in use, so the
      // row shows what it would look like rather than what is on now.
      trailing: chosen
          ? Icon(Icons.check_rounded, color: theme.work)
          : Icon(Icons.circle_outlined, color: colors.line),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: Sizes.dot,
    height: Sizes.dot,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

/// Something wrong with the phone rather than something to choose.
///
/// Both notices cost the app something it cannot fix for itself and neither
/// stops a workout running, which is why they sit above the settings instead
/// of among them: there is nothing to set, only something to go and do.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: colors.danger),
            title: Text(title),
            subtitle: Text(body),
            isThreeLine: true,
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gutter,
                0,
                Sizes.gutter,
                Sizes.gutter,
              ),
              child: _ActionRow(
                icon: Icons.open_in_new_rounded,
                label: actionLabel!,
                onTap: onAction!,
              ),
            ),
        ],
      ),
    );
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
          border: Border.all(color: context.colors.cardLine, width: Sizes.hairline),
          borderRadius: BorderRadius.circular(Sizes.radius),
        ),
        child: Row(
          children: [
            Icon(icon, size: Sizes.icon, color: context.colors.work),
            const SizedBox(width: Sizes.gap),
            // Shrinks rather than wraps. There is about 164dp of room here
            // on a 320dp phone: enough for "Turn them on" at the normal type
            // size, and not enough once the owner turns their system font up.
            Expanded(
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleMedium,
                child: ActionLabel(
                  label,
                  alignment: AlignmentDirectional.centerStart,
                ),
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

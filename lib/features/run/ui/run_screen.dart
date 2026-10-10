import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/palette.dart';
import '../../../app/providers.dart';
import '../../../app/sizes.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/timeline.dart';
import '../../../core/timeline/workout.dart';
import '../domain/run_controller.dart';

String mmss(int ms) {
  final total = (ms / 1000).ceil();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// The one screen that matters, and the one the user is trying not to look at.
///
/// So: the phase colour fills the whole screen, the seconds remaining are the
/// biggest thing on it, and every control is a thumb's width. If the design
/// works, a glance from across a room is enough and the voice does the rest.
class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back to the front after the screen was off: Dart may have been
    // frozen for the last twenty minutes, so take the platform's word for how
    // long the session has really been running.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(runProvider.notifier).resync(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runProvider);
    final session = run.session;
    final segment = session.activeSegment;

    final background = segment == null
        ? null
        : context.colors.phase(segment.kind);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: background,
          padding: const EdgeInsets.all(Sizes.gutter),
          child: switch (session.status) {
            SessionStatus.idle => const _Setup(),
            SessionStatus.finished => const _Finished(),
            _ => _Running(session: session),
          },
        ),
      ),
    );
  }
}

/// Before the start: set the interval and go. The preset list and the full
/// editor arrive in phase 3; this is the smallest thing that is actually
/// usable for a workout.
class _Setup extends ConsumerWidget {
  const _Setup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider);
    final round = workout.rounds.first;
    final total = expand(workout).totalMs;
    final controller = ref.read(appDataProvider.notifier);
    final run = ref.watch(runProvider);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Talking Stopwatch',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Sizes.bigGap),
        _Number(
          label: 'Work',
          value: '${round.workSeconds}s',
          onChange: (by) => controller.editWorkout(
            (w) => w.copyWith(
              rounds: [
                round.copyWith(
                  workSeconds: (round.workSeconds + by * 5).clamp(5, 600),
                ),
              ],
            ),
          ),
        ),
        _Number(
          label: 'Rest',
          value: '${round.restSeconds}s',
          onChange: (by) => controller.editWorkout(
            (w) => w.copyWith(
              rounds: [
                round.copyWith(
                  restSeconds: (round.restSeconds + by * 5).clamp(0, 300),
                ),
              ],
            ),
          ),
        ),
        _Number(
          label: 'Rounds',
          value: '${workout.repeats}',
          onChange: (by) => controller.editWorkout(
            (w) => w.copyWith(repeats: (w.repeats + by).clamp(1, 60)),
          ),
        ),
        const SizedBox(height: Sizes.gap),
        Text(
          'Total ${mmss(total)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (!hasVoice) ...[
          const SizedBox(height: Sizes.gap),
          Text(
            'This phone has no voice installed, so the timer will '
            'run without speaking.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.danger,
            ),
          ),
        ],
        const SizedBox(height: Sizes.bigGap),
        SizedBox(
          height: Sizes.bigControl,
          width: double.infinity,
          child: FilledButton(
            onPressed: run.preparing
                ? null
                : () => ref.read(runProvider.notifier).start(),
            child: Text(run.preparing ? 'Getting ready…' : 'Start'),
          ),
        ),
      ],
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
    required this.label,
    required this.value,
    required this.onChange,
  });

  final String label;
  final String value;
  final void Function(int by) onChange;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Sizes.row,
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.filledTonal(
          onPressed: () => onChange(-1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: Sizes.bigControl,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => onChange(1),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class _Running extends ConsumerWidget {
  const _Running({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(runProvider.notifier);
    final segment = session.segment;
    final paused = session.status == SessionStatus.paused;
    final rounds = ref.watch(workoutProvider).workPhases;
    final text = Theme.of(context).textTheme;
    final on = context.colors.onPhase;
    final accent = segment == null
        ? context.colors.idle
        : context.colors.phase(segment.kind);

    return Column(
      children: [
        const Spacer(),
        Text(
          segment == null ? '' : phaseLabel(segment.kind),
          style: text.headlineLarge?.copyWith(color: on),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            mmss(session.segmentRemainingMs),
            style: text.displayLarge?.copyWith(color: on),
          ),
        ),
        if (segment != null && segment.kind == SegmentKind.work)
          Text(
            segment.label.isNotEmpty
                ? segment.label
                : 'Round ${segment.index} of $rounds',
            style: text.titleMedium?.copyWith(color: on),
          ),
        const SizedBox(height: Sizes.gap),
        Text(
          paused ? 'Paused' : '${mmss(session.remainingMs)} left',
          style: text.bodyMedium?.copyWith(color: on),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Control(
              icon: Icons.stop,
              label: 'Stop',
              accent: accent,
              onPressed: controller.stop,
            ),
            _Control(
              icon: paused ? Icons.play_arrow : Icons.pause,
              label: paused ? 'Resume' : 'Pause',
              accent: accent,
              big: true,
              onPressed: paused ? controller.resume : controller.pause,
            ),
            _Control(
              icon: Icons.skip_next,
              label: 'Skip',
              accent: accent,
              onPressed: controller.skip,
            ),
          ],
        ),
      ],
    );
  }
}

/// A control drawn on top of a phase colour, so it takes its colours from the
/// phase rather than from the theme's own palette — a green button on a green
/// background is no button at all.
class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
    this.big = false,
  });

  final IconData icon;
  final String label;

  /// The colour behind this control, which its icon is punched out of.
  final Color accent;

  final VoidCallback onPressed;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final side = big ? Sizes.bigControl : Sizes.control;
    final on = context.colors.onPhase;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Every control reserves the same height, so the labels line up even
        // though the middle button is the big one.
        SizedBox(
          height: Sizes.bigControl,
          child: Center(
            child: SizedBox(
              height: side,
              width: side,
              child: big
                  ? FilledButton(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(backgroundColor: on),
                      child: Icon(icon, color: accent),
                    )
                  : OutlinedButton(
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: on,
                        side: BorderSide(color: on),
                      ),
                      child: Icon(icon),
                    ),
            ),
          ),
        ),
        const SizedBox(height: Sizes.gap),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: on),
        ),
      ],
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Done', style: Theme.of(context).textTheme.displayLarge),
      const SizedBox(height: Sizes.bigGap),
      SizedBox(
        height: Sizes.bigControl,
        width: double.infinity,
        child: FilledButton(
          onPressed: ref.read(runProvider.notifier).stop,
          child: const Text('Again'),
        ),
      ),
    ],
  );
}

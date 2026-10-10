import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/style.dart';
import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/workout.dart';
import '../domain/run_controller.dart';

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
      // No app bar once it is running: nothing should compete with the number,
      // and leaving mid-workout is what Stop is for.
      appBar: session.isActive
          ? null
          : AppBar(
              backgroundColor: background,
              leading: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: background,
          padding: const EdgeInsets.all(Sizes.gutter),
          child: switch (session.status) {
            SessionStatus.idle => const _Ready(),
            SessionStatus.finished => const _Finished(),
            _ => _Running(session: session),
          },
        ),
      ),
    );
  }
}

/// What a workout looks like before it starts: what you are about to do, how
/// long it takes, and one button the size of a thumb.
class _Ready extends ConsumerWidget {
  const _Ready();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider);
    final run = ref.watch(runProvider);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          workout.name.isEmpty ? 'Workout' : workout.name,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        const SizedBox(height: Sizes.gap),
        Text(workout.summary, style: text.bodyLarge),
        const SizedBox(height: Sizes.bigGap),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(workout.totalLabel, style: text.displayLarge),
        ),
        const SizedBox(height: Sizes.bigGap),
        if (!hasVoice) ...[
          Text(
            'This phone has no voice installed, so the timer will run '
            'without speaking.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: context.colors.danger),
          ),
          const SizedBox(height: Sizes.gap),
        ],
        SizedBox(
          height: Sizes.bigControl,
          width: double.infinity,
          child: FilledButton(
            onPressed: run.preparing
                ? null
                : () => ref.read(runProvider.notifier).start(),
            child: ActionLabel(run.preparing ? 'Getting ready…' : 'Start'),
          ),
        ),
        const SizedBox(height: Sizes.gap),
        TextButton(
          onPressed: () => context.go('/edit/${workout.id}'),
          child: const Text('Edit'),
        ),
      ],
    );
  }
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
    final kind = segment?.kind ?? SegmentKind.work;
    final accent = context.colors.phase(kind);
    final on = context.colors.onPhase(kind);

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
            countdown(session.segmentRemainingMs),
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
          paused ? 'Paused' : '${countdown(session.remainingMs)} left',
          style: text.bodyMedium?.copyWith(color: on),
        ),
        const Spacer(),
        // Each control takes a third of whatever width there is: three
        // fixed-width buttons fit a 360dp phone and overflow a 320dp one.
        Row(
          children: [
            Expanded(
              child: _Control(
                icon: Icons.stop,
                label: 'Stop',
                accent: accent,
                on: on,
                onPressed: controller.stop,
              ),
            ),
            Expanded(
              child: _Control(
                icon: paused ? Icons.play_arrow : Icons.pause,
                label: paused ? 'Resume' : 'Pause',
                accent: accent,
                on: on,
                big: true,
                onPressed: paused ? controller.resume : controller.pause,
              ),
            ),
            Expanded(
              child: _Control(
                icon: Icons.skip_next,
                label: 'Skip',
                accent: accent,
                on: on,
                onPressed: controller.skip,
              ),
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
    required this.on,
    required this.onPressed,
    this.big = false,
  });

  final IconData icon;
  final String label;

  /// The colour behind this control, which its icon is punched out of.
  final Color accent;

  /// What reads on top of [accent].
  final Color on;

  final VoidCallback onPressed;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final side = big ? Sizes.bigControl : Sizes.control;
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
          child: const ActionLabel('Again'),
        ),
      ),
      const SizedBox(height: Sizes.gap),
      TextButton(
        onPressed: () async {
          await ref.read(runProvider.notifier).stop();
          if (context.mounted) context.go('/');
        },
        child: const Text('Back to the list'),
      ),
    ],
  );
}

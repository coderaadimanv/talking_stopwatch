import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_control.dart';
import '../../../app/widgets/dial.dart';
import '../../../app/widgets/round_tracker.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/format.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/timeline.dart';
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
      body: _Ground(
        // Only a running phase gets the soft ground; idle and finished sit on
        // the app's own dark surface, where they belong with the rest of it.
        color: background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sizes.gutter),
            child: switch (session.status) {
              SessionStatus.idle => const _Ready(),
              SessionStatus.finished => const _Finished(),
              _ => _Running(session: session),
            },
          ),
        ),
      ),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground({required this.color, required this.child});

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) => color == null
      ? child
      : SoftBackground(color: color!, child: child);
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

/// A workout in progress, and the screen the whole app exists for.
///
/// Read from across a room: the colour says which phase, the arc says how far
/// through, and only a proper look needs the number. The number itself sits on
/// the pale dial rather than on the phase colour, which is where it gets its
/// contrast — the heading and caption are the parts that can afford to be
/// softer.
class _Running extends ConsumerWidget {
  const _Running({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(runProvider.notifier);
    final segment = session.segment;
    final paused = session.status == SessionStatus.paused;
    final workout = ref.watch(workoutProvider);
    final text = Theme.of(context).textTheme;

    final kind = segment?.kind ?? SegmentKind.work;
    final colors = context.colors;
    final on = colors.onPhase(kind);
    final face = colors.phaseFace(kind);
    final deep = colors.phaseDeep(kind);

    final elapsed = segment == null || segment.durationMs == 0
        ? 0.0
        : 1 - session.segmentRemainingMs / segment.durationMs;

    return Column(
      children: [
        const SizedBox(height: Sizes.bigGap),
        Container(
          width: Sizes.badge,
          height: Sizes.badge,
          decoration: BoxDecoration(color: face, shape: BoxShape.circle),
          child: Icon(phaseIcon(kind), color: deep, size: Sizes.bigIcon),
        ),
        const SizedBox(height: Sizes.gap),
        Text(
          segment == null ? '' : phaseLabel(segment.kind),
          style: text.headlineLarge?.copyWith(color: on),
        ),
        Text(
          segment == null ? '' : phaseCaption(segment),
          style: text.labelLarge?.copyWith(color: on.withValues(alpha: 0.72)),
        ),

        Expanded(
          child: Center(
            child: Dial(
              progress: elapsed,
              face: face,
              arc: deep,
              child: _DialFace(
                session: session,
                segment: segment,
                rounds: workout.workPhases,
                paused: paused,
              ),
            ),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: CircleControl(
                icon: Icons.stop_rounded,
                label: 'Stop',
                onPressed: controller.stop,
                background: face,
                foreground: deep,
                labelColor: on,
              ),
            ),
            Expanded(
              child: CircleControl(
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: paused ? 'Resume' : 'Pause',
                onPressed: paused ? controller.resume : controller.pause,
                background: deep,
                foreground: colors.onPhaseDeep(kind),
                labelColor: on,
                primary: true,
              ),
            ),
            Expanded(
              child: CircleControl(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                onPressed: controller.skip,
                background: face,
                foreground: deep,
                labelColor: on,
              ),
            ),
          ],
        ),
        const SizedBox(height: Sizes.bigGap),

        RoundTracker(
          done: segment?.kind == SegmentKind.work
              ? segment!.index
              : _roundsDone(session, workout.workPhases),
          total: workout.workPhases,
          filled: deep,
          empty: face.withValues(alpha: 0.45),
          track: face.withValues(alpha: 0.18),
        ),
      ],
    );
  }

  /// Between work phases — resting, on a break — the round just finished is
  /// the one to show as done.
  int _roundsDone(SessionState session, int total) {
    var done = 0;
    for (final s in session.timeline.segments) {
      if (s.kind == SegmentKind.work && s.endMs <= session.elapsedMs) done++;
    }
    return done > total ? total : done;
  }
}

/// What sits inside the dial: the number, which round, and how long is left of
/// the whole workout.
class _DialFace extends StatelessWidget {
  const _DialFace({
    required this.session,
    required this.segment,
    required this.rounds,
    required this.paused,
  });

  final SessionState session;
  final Segment? segment;
  final int rounds;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = context.colors.onPhase(SegmentKind.prepare);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            countdown(session.segmentRemainingMs),
            style: text.displayLarge?.copyWith(color: ink),
          ),
        ),
        if (segment != null && segment!.kind == SegmentKind.work)
          Text(
            'Round ${segment!.index} of $rounds',
            style: text.titleMedium?.copyWith(color: ink),
          ),
        const SizedBox(height: Sizes.gap),
        _Chip(
          icon: paused ? Icons.pause_rounded : Icons.schedule_rounded,
          label: paused
              ? 'Paused'
              : '${countdown(session.remainingMs)} left',
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onPhase(SegmentKind.prepare);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.gap,
        vertical: Sizes.gap / 2,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Sizes.control / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.chipIcon, color: ink.withValues(alpha: 0.7)),
          const SizedBox(width: Sizes.gap / 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
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

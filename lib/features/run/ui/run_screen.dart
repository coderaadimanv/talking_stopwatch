import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_badge.dart';
import '../../../app/widgets/circle_control.dart';
import '../../../app/widgets/pill_button.dart';
import '../../../app/widgets/tick_ring.dart';
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
      onResume: () {
        ref.read(runProvider.notifier).resync();
        // The ready screen sends people to a system screen to turn
        // notifications on. Coming back is the only word of it we get.
        ref.invalidate(canNotifyProvider);
      },
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
              backgroundColor: Brand.transparent,
              leadingWidth: Sizes.bigControl,
              leading: Padding(
                padding: const EdgeInsets.only(left: Sizes.gap),
                child: IconButton(
                  onPressed: () => context.go('/'),
                  style: chipIconButton(),
                  icon: const Icon(Icons.arrow_back),
                ),
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
      // Nothing running: the app's own dark ground, lit by the accent.
      ? SoftBackground(
          color: Brand.ink,
          glow: context.colors.work,
          child: child,
        )
      : SoftBackground(color: color!, child: child);
}

/// What a workout looks like before it starts.
///
/// The running screen's anatomy, held still: the same badge, name and caption
/// at the top, and a ring where the dial will be. There is no progress to draw
/// yet, so the ring is marked rather than filled — an empty arc would only ask
/// to be read as zero.
class _Ready extends ConsumerWidget {
  const _Ready();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider);
    final run = ref.watch(runProvider);
    final hasVoice = ref.watch(voiceAvailableProvider).asData?.value ?? true;
    final canNotify = ref.watch(canNotifyProvider).asData?.value;
    final colors = context.colors;
    final accent = colors.work;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        CircleBadge.icon(
          background: Brand.accentWash,
          ring: accent,
          icon: Icons.directions_run_rounded,
          color: accent,
        ),
        const SizedBox(height: Sizes.gap),
        Text('Workout', style: text.headlineLarge),
        Text('GET READY', style: text.labelLarge),
        const SizedBox(height: Sizes.bigGap),

        // Which workout, under what you are about to do.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Sizes.gap),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: accent, size: Sizes.bigIcon),
                const SizedBox(width: Sizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name.isEmpty ? 'Untitled' : workout.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        workout.summary,
                        style: text.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Center(
            child: TickRing(
              color: accent,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  workout.totalLabel,
                  style: text.displayLarge?.copyWith(
                    // Lit from within, which is the only thing separating a
                    // waiting clock from a stopped one.
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // What is wrong with the phone, in the smallest type on the screen
        // and directly above the button it affects. Both notices are one
        // block with no gap between them: on a 320dp phone with both of them
        // showing there is nothing left of the ring, and spacing between two
        // warnings is the first thing that should go.
        if (!hasVoice)
          Text(
            'This phone has no voice installed, so the timer will run '
            'without speaking.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.danger),
          ),

        // Said here as well as in settings, because this is the last moment
        // it can still be acted on: once the phone is face down in a gym bag
        // the empty lock screen is the symptom, and nobody goes looking for
        // the cause.
        if (canNotify == false)
          _NotifyNotice(
            onTap: () => ref.read(cuePlayerProvider).openNotifySettings(),
          ),

        if (!hasVoice || canNotify == false)
          const SizedBox(height: Sizes.gap),

        PillButton.primary(
          icon: Icons.play_arrow_rounded,
          label: run.preparing ? 'Getting ready…' : 'Start',
          accent: accent,
          foreground: colors.readableOn(accent),
          onPressed: run.preparing
              ? null
              : () => ref.read(runProvider.notifier).start(),
        ),
        const SizedBox(height: Sizes.gap),
        FractionallySizedBox(
          widthFactor: 0.56,
          child: PillButton.outlined(
            icon: Icons.edit_outlined,
            label: 'Edit',
            accent: accent,
            onPressed: () => context.go('/edit/${workout.id}'),
          ),
        ),
      ],
    );
  }
}

/// One line above Start: the lock screen will be empty, and a tap that fixes
/// it.
///
/// The same words as the notice in settings, said in the space the ready
/// screen has — which is one line, under a dial, above the only button that
/// matters. So the explanation goes and the consequence stays, and anyone who
/// wants the rest of it finds it in settings.
class _NotifyNotice extends StatelessWidget {
  const _NotifyNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.bodySmall;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Sizes.radius),
      child: Padding(
        // Enough to be hit without looking, which is the standard everything
        // else on this screen is held to, without taking a line off the dial.
        padding: const EdgeInsets.symmetric(vertical: Sizes.gap / 2),
        child: Text.rich(
          textAlign: TextAlign.center,
          TextSpan(
            style: style?.copyWith(color: colors.danger),
            children: [
              const TextSpan(text: 'Notifications are off, so the lock '
                  'screen will stay empty. '),
              TextSpan(
                text: 'Turn them on',
                style: style?.copyWith(
                  color: colors.work,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.work,
                ),
              ),
            ],
          ),
        ),
      ),
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
        CircleBadge.icon(
          background: face,
          icon: phaseIcon(kind),
          color: deep,
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

/// The end of a workout, in the same shape as its start.
class _Finished extends ConsumerWidget {
  const _Finished();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent = colors.work;
    final text = Theme.of(context).textTheme;
    final workout = ref.watch(workoutProvider);

    return Column(
      children: [
        const Spacer(),
        CircleBadge.icon(
          background: Brand.accentWash,
          ring: accent,
          icon: Icons.check_rounded,
          color: accent,
        ),
        const SizedBox(height: Sizes.gap),
        Text('Done', style: text.headlineLarge),
        Text(
          workout.totalLabel.toUpperCase(),
          style: text.labelLarge,
        ),
        const Spacer(),
        PillButton.primary(
          icon: Icons.replay_rounded,
          label: 'Again',
          accent: accent,
          foreground: colors.readableOn(accent),
          onPressed: ref.read(runProvider.notifier).stop,
        ),
        const SizedBox(height: Sizes.gap),
        FractionallySizedBox(
          widthFactor: 0.56,
          child: PillButton.outlined(
            icon: Icons.list_rounded,
            label: 'Workouts',
            accent: accent,
            onPressed: () async {
              await ref.read(runProvider.notifier).stop();
              if (context.mounted) context.go('/');
            },
          ),
        ),
      ],
    );
  }
}

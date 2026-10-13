import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_control.dart';
import '../../../app/widgets/dial.dart';
import '../../../app/widgets/pill_button.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/format.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/timeline.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/workout.dart';
import '../../run/domain/run_controller.dart';

/// The run screen's opposite number, over the same controller.
///
/// Everything the run screen does to be seen from across a gym, this one
/// undoes. The ground stays the app's own dark rather than flooding with the
/// phase colour; the number is a size you read rather than one you glance at;
/// there is no badge, no tracker and no caption. The phase is said in one
/// quiet word, because during focused work knowing which phase you are in is
/// worth exactly one word and no more.
///
/// It drives [RunController] unchanged — the same session, the same pause,
/// resume and skip, the same Stop from the lock screen. Only the drawing is
/// different, which is the whole difference between the two modes.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // A focus block is twenty-five minutes long, so this screen is far more
    // likely than the run screen to come back from a frozen Dart. Take the
    // platform's word for the elapsed time rather than our own.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(runProvider.notifier).resync();
        // Do Not Disturb access is granted on a system screen, so the app was
        // in the background while the answer changed.
        ref.invalidate(canSilenceProvider);
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
    final session = ref.watch(runProvider).session;

    return Scaffold(
      backgroundColor: context.colors.ground,
      appBar: session.isActive
          ? null
          : AppBar(
              backgroundColor: Brand.transparent,
              leadingWidth: Sizes.bigControl,
              leading: Padding(
                padding: const EdgeInsets.only(left: Sizes.gap),
                child: IconButton(
                  onPressed: () => context.go('/'),
                  style: chipIconButton(context.colors),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
      body: SoftBackground(
        color: context.colors.ground,
        glow: context.colors.focus,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sizes.gutter),
            child: switch (session.status) {
              SessionStatus.idle => const _Ready(),
              SessionStatus.finished => const _Done(),
              _ => _Running(session: session),
            },
          ),
        ),
      ),
    );
  }
}

/// Before a session: what it is, how long it takes, and one way in.
class _Ready extends ConsumerWidget {
  const _Ready();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider);
    final run = ref.watch(runProvider);
    final accent = context.colors.focus;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: Sizes.bigGap),
        Text(
          workout.name.isEmpty ? 'Focus' : workout.name,
          style: text.headlineLarge,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Sizes.gap),
        Text(
          workout.summary,
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),

        // The total, as large as the room allows and no larger. The run
        // screen's shape, for the same reason: on a short phone the number
        // gives way, never the buttons.
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                workout.totalLabel,
                style: text.displayLarge?.copyWith(color: accent),
              ),
            ),
          ),
        ),

        const _Silence(),

        PillButton.primary(
          icon: Icons.play_arrow_rounded,
          label: run.preparing ? 'Getting ready…' : 'Start',
          accent: accent,
          foreground: context.colors.readableOn(accent),
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

/// Do Not Disturb for the length of the session, if the phone will allow it.
///
/// Off by default and shown here rather than buried in settings, because it
/// is a decision about *this* session: silencing someone's phone is not
/// something to do on their behalf because they opened a timer.
///
/// It is not shown at all where it cannot work. On iOS no app can turn a
/// Focus on, [canSilenceProvider] answers null, and a switch promising it
/// would simply be a lie.
class _Silence extends ConsumerWidget {
  const _Silence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(canSilenceProvider).asData?.value;
    if (allowed == null) return const SizedBox.shrink();

    final on = ref.watch(appDataProvider).settings.silenceDuringFocus;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: Sizes.gap),
      padding: const EdgeInsets.fromLTRB(
        Sizes.gutter,
        Sizes.gap / 2,
        Sizes.gap,
        Sizes.gap / 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.cardLine, width: Sizes.hairline),
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.do_not_disturb_on_outlined,
                size: Sizes.icon,
                color: colors.focus,
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: text.titleMedium,
                  child: const ActionLabel(
                    'Silence the phone',
                    alignment: AlignmentDirectional.centerStart,
                  ),
                ),
              ),
              Switch(
                value: on,
                // Both halves: the thumb alone leaves the track wearing the
                // app's terracotta on a screen that is entirely teal.
                activeThumbColor: colors.focus,
                activeTrackColor: colors.washOf(colors.focus),
                onChanged: (value) => ref
                    .read(appDataProvider.notifier)
                    .editSettings(
                      (settings) =>
                          settings.copyWith(silenceDuringFocus: value),
                    ),
              ),
            ],
          ),

          // Switched on but not allowed yet. Said here rather than refused
          // at the switch, because wanting it and being allowed it are two
          // different things and only one of them is the user's answer.
          if (on && !allowed)
            InkWell(
              onTap: () =>
                  ref.read(cuePlayerProvider).openSilenceSettings(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Sizes.gap / 2),
                child: Text(
                  'Android has to allow this first. Tap to turn it on.',
                  style: text.bodySmall?.copyWith(
                    color: colors.danger,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A session under way. One word, one number, three controls.
class _Running extends ConsumerWidget {
  const _Running({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(runProvider.notifier);
    final workout = ref.watch(workoutProvider);
    final segment = session.segment;
    final paused = session.status == SessionStatus.paused;

    final colors = context.colors;
    final accent = colors.focus;
    final text = Theme.of(context).textTheme;

    final through = segment == null || segment.durationMs == 0
        ? 0.0
        : 1 - session.segmentRemainingMs / segment.durationMs;

    return Column(
      children: [
        const SizedBox(height: Sizes.bigGap),
        // The phase, in a word. This is the only thing on the screen that
        // changes character between focus and break, and it is deliberately
        // not the whole screen changing colour.
        Text(
          segment == null
              ? ''
              : phaseLabel(segment.kind, of: TimerKind.focus),
          style: text.headlineSmall?.copyWith(color: accent),
        ),

        Expanded(
          child: Center(
            child: Dial(
              progress: through,
              // A dark face, not a pale one: a bright disc is the last thing
              // a screen meant to be ignored should have on it.
              face: context.colors.surface,
              arc: accent,
              child: _Face(
                session: session,
                segment: segment,
                blocks: workout.workPhases,
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
                background: context.colors.surface,
                foreground: accent,
                labelColor: colors.muted,
              ),
            ),
            Expanded(
              child: CircleControl(
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: paused ? 'Resume' : 'Pause',
                onPressed: paused ? controller.resume : controller.pause,
                background: accent,
                foreground: colors.readableOn(accent),
                labelColor: colors.muted,
                primary: true,
              ),
            ),
            Expanded(
              child: CircleControl(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                onPressed: controller.skip,
                background: context.colors.surface,
                foreground: accent,
                labelColor: colors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: Sizes.bigGap),
      ],
    );
  }
}

/// What sits inside the dial: how long is left of this block, which block it
/// is, and how long is left of the whole thing.
class _Face extends StatelessWidget {
  const _Face({
    required this.session,
    required this.segment,
    required this.blocks,
    required this.paused,
  });

  final SessionState session;
  final Segment? segment;
  final int blocks;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            countdown(session.segmentRemainingMs),
            // Smaller than the run screen's, and ivory rather than ink: this
            // one is read at a desk, by someone who is not out of breath.
            style: text.displayMedium?.copyWith(color: context.colors.onGround),
          ),
        ),
        if (segment != null && segment!.kind == SegmentKind.work)
          Text(
            'Block ${segment!.index} of $blocks',
            style: text.bodyMedium?.copyWith(color: colors.muted),
          ),
        const SizedBox(height: Sizes.gap / 2),
        Text(
          paused ? 'Paused' : '${countdown(session.remainingMs)} left',
          style: text.labelMedium?.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

/// The end, in the same shape as the start.
class _Done extends ConsumerWidget {
  const _Done();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider);
    final accent = context.colors.focus;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: Sizes.bigGap),
        Icon(Icons.check_rounded, size: Sizes.bigIcon, color: accent),
        const SizedBox(height: Sizes.gap),
        Text('Done', style: text.headlineLarge),
        const SizedBox(height: Sizes.gap),
        Text(
          '${workout.totalLabel} of focus',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        PillButton.primary(
          icon: Icons.replay_rounded,
          label: 'Again',
          accent: accent,
          foreground: context.colors.readableOn(accent),
          onPressed: () => ref.read(runProvider.notifier).start(),
        ),
        const SizedBox(height: Sizes.gap),
        FractionallySizedBox(
          widthFactor: 0.56,
          child: PillButton.outlined(
            icon: Icons.list_rounded,
            label: 'Home',
            accent: accent,
            onPressed: () => context.go('/'),
          ),
        ),
      ],
    );
  }
}

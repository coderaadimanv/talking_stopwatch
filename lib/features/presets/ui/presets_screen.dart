import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_badge.dart';
import '../../../app/widgets/section.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/workout.dart';

/// Home: the workouts you have saved, the focus sessions, and the stopwatch.
///
/// Dark rather than coloured, unlike the screens it opens into. A phase colour
/// is information — it says which phase you are in from across a room — and
/// there is no phase here, so colouring the whole page would only be shouting.
/// What carries over is the vocabulary: soft depth, round badges, cards with
/// room to breathe.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(appDataProvider).presets;
    final data = ref.read(appDataProvider.notifier);
    final colors = context.colors;

    final workouts = [
      for (final p in presets)
        if (p.kind == TimerKind.workout) p,
    ];
    final focus = [
      for (final p in presets)
        if (p.kind == TimerKind.focus) p,
    ];

    /// Opens a preset in whichever screen belongs to it. The same controller
    /// runs both, so this is only a choice of how it is drawn.
    void open(Workout preset) {
      ref.read(selectedWorkoutIdProvider.notifier).select(preset.id);
      context.go(preset.kind == TimerKind.focus ? '/focus' : '/run');
    }

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(
        backgroundColor: Brand.transparent,
        title: const Text('Talking Stopwatch'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SoftBackground(
        color: Brand.ink,
        glow: colors.work,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sizes.gutter,
              0,
              Sizes.gutter,
              Sizes.bigGap,
            ),
            children: [
              // Two lists rather than one, and a "new" on each heading rather
              // than a single button floating over the bottom: with two kinds
              // of preset, one New has nothing to say about which kind it
              // would make.
              SectionHeading(
                icon: Icons.fitness_center_rounded,
                title: 'Workouts',
                subtitle: 'Counted out loud',
                trailing: _Add(
                  tooltip: 'New workout',
                  onPressed: () => context.go('/edit/${data.addWorkout().id}'),
                ),
              ),
              for (final workout in workouts) ...[
                _WorkoutCard(
                  workout: workout,
                  onRun: () => open(workout),
                  onEdit: () => context.go('/edit/${workout.id}'),
                ),
                const SizedBox(height: Sizes.gap),
              ],

              SectionHeading(
                icon: Icons.psychology_alt_rounded,
                title: 'Focus',
                subtitle: 'One word, then quiet',
                accent: colors.focus,
                trailing: _Add(
                  tooltip: 'New focus session',
                  onPressed: () => context.go('/edit/${data.addFocus().id}'),
                ),
              ),
              for (final session in focus) ...[
                _WorkoutCard(
                  workout: session,
                  onRun: () => open(session),
                  onEdit: () => context.go('/edit/${session.id}'),
                ),
                const SizedBox(height: Sizes.gap),
              ],

              const SizedBox(height: Sizes.bigGap),
              _StopwatchCard(
                onTap: () => context.go('/stopwatch'),
                accent: colors.stopwatch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "new" on a section heading.
class _Add extends StatelessWidget {
  const _Add({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style: chipIconButton(),
    icon: const Icon(Icons.add),
  );
}

class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard({
    required this.workout,
    required this.onRun,
    required this.onEdit,
  });

  final Workout workout;
  final VoidCallback onRun;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    // A workout wears the colour of the phase it is mostly made of; a focus
    // session wears the mode's own.
    final ground = workout.kind == TimerKind.focus
        ? colors.focus
        : colors.work;

    return Card(
      child: InkWell(
        onTap: onRun,
        borderRadius: BorderRadius.circular(Sizes.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gutter),
          child: Row(
            children: [
              // The dial, shrunk: how long the whole thing takes, which is
              // what anyone checks before committing to it.
              CircleBadge(
                size: Sizes.badgeSmall,
                background: colors.washOf(ground),
                // Scaled rather than sized: a workout's total is "5:20" and a
                // focus session's is "2:10:00", and both have to sit in the
                // same disc.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    workout.totalLabel,
                    style: text.titleMedium?.copyWith(color: ground),
                  ),
                ),
              ),
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
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Edit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopwatchCard extends StatelessWidget {
  const _StopwatchCard({required this.onTap, required this.accent});

  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sizes.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gutter),
          child: Row(
            children: [
              CircleBadge.icon(
                size: Sizes.badgeSmall,
                background: Brand.accentWash,
                icon: Icons.timer_outlined,
                color: accent,
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stopwatch', style: text.titleMedium),
                    Text(
                      'Counts up and calls out the time',
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/style.dart';
import '../../../app/providers.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/workout.dart';

/// Home: the workouts you have saved, and the stopwatch.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(appDataProvider).presets;
    final data = ref.read(appDataProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talking Stopwatch'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Sizes.gap),
        children: [
          for (final workout in presets)
            _PresetRow(
              workout: workout,
              onRun: () {
                ref.read(selectedWorkoutIdProvider.notifier).select(workout.id);
                context.go('/run');
              },
              onEdit: () => context.go('/edit/${workout.id}'),
            ),
          const Divider(height: Sizes.bigGap),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Stopwatch'),
            subtitle: const Text('Counts up and calls out the time'),
            onTap: () => context.go('/stopwatch'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/edit/${data.addWorkout().id}'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.workout,
    required this.onRun,
    required this.onEdit,
  });

  final Workout workout;
  final VoidCallback onRun;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      workout.name.isEmpty ? 'Untitled' : workout.name,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Text(workout.summary),
    // The total is the thing you check before committing to a workout.
    leading: SizedBox(
      width: Sizes.bigControl,
      child: Text(
        workout.totalLabel,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: context.colors.work,
        ),
      ),
    ),
    trailing: IconButton(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined),
      tooltip: 'Edit',
    ),
    onTap: onRun,
  );
}

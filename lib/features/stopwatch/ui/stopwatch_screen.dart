import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/style.dart';
import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../domain/stopwatch_controller.dart';

/// Counts up, and calls out the time so you do not have to look.
class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(stopwatchProvider);
    final controller = ref.read(stopwatchProvider.notifier);
    final every = ref.watch(appDataProvider).settings.stopwatchAnnounceSeconds;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Stopwatch'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gutter),
          child: Column(
            children: [
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(elapsed(watch.elapsedMs), style: text.displayLarge),
              ),
              Text(
                every > 0
                    ? 'Calls out the time every ${every}s'
                    : 'Silent — turn announcements on in settings',
                style: text.bodyMedium?.copyWith(color: context.colors.muted),
              ),
              const SizedBox(height: Sizes.bigGap),
              Expanded(child: _Laps(laps: watch.laps)),
              // Shares out whatever width there is rather than claiming a
              // fixed amount: three fixed buttons overflow a narrow phone.
              Row(
                children: [
                  // Equal thirds. The primary action is already obvious from
                  // being filled and taller, and giving it extra width only
                  // takes room the side labels need to stay on one line.
                  Expanded(
                    child: OutlinedButton(
                      onPressed: watch.started ? controller.reset : null,
                      child: const ActionLabel('Reset'),
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: SizedBox(
                      height: Sizes.bigControl,
                      child: FilledButton(
                        onPressed: watch.preparing
                            ? null
                            : watch.running
                            ? controller.pause
                            : controller.start,
                        child: ActionLabel(
                          watch.preparing
                              ? '…'
                              : watch.running
                              ? 'Pause'
                              : watch.started
                              ? 'Resume'
                              : 'Start',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: watch.running ? controller.lap : null,
                      child: const ActionLabel('Lap'),
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
}

class _Laps extends StatelessWidget {
  const _Laps({required this.laps});

  final List<int> laps;

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      reverse: true,
      itemCount: laps.length,
      itemBuilder: (context, i) {
        final index = laps.length - 1 - i;
        // Each lap against the one before it, which is the number people
        // actually want, with the running total beside it.
        final since = index == 0 ? laps[0] : laps[index] - laps[index - 1];
        return ListTile(
          dense: true,
          leading: Text('${index + 1}'),
          title: Text(elapsed(since)),
          trailing: Text(
            elapsed(laps[index]),
            style: TextStyle(color: context.colors.muted),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_control.dart';
import '../../../app/widgets/dial.dart';
import '../../../app/widgets/soft_background.dart';
import '../../../core/format.dart';
import '../domain/stopwatch_controller.dart';

/// Counts up, and calls out the time so you do not have to look.
///
/// Built like the running screen, because it is the same job. The dial sweeps
/// once a minute rather than once a phase: a stopwatch has no end to show
/// progress towards, and the seconds hand is the one thing it can honestly
/// draw.
class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  /// How far through the current minute, which is what the dial draws.
  static double minuteProgress(int elapsedMs) => (elapsedMs % 60000) / 60000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(stopwatchProvider);
    final controller = ref.read(stopwatchProvider.notifier);
    final every = ref.watch(appDataProvider).settings.stopwatchAnnounceSeconds;

    final colors = context.colors;
    final ground = colors.stopwatch;
    final face = colors.faceOn(ground);
    final deep = colors.deepOf(ground);
    final on = colors.readableOn(ground);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: ground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Brand.transparent,
        foregroundColor: on,
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SoftBackground(
        color: ground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sizes.gutter),
            child: Column(
              children: [
                const SizedBox(height: Sizes.bigGap),
                Container(
                  width: Sizes.badge,
                  height: Sizes.badge,
                  decoration: BoxDecoration(
                    color: face,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: deep,
                    size: Sizes.bigIcon,
                  ),
                ),
                const SizedBox(height: Sizes.gap),
                Text(
                  'Stopwatch',
                  style: text.headlineLarge?.copyWith(color: on),
                ),
                Text(
                  every > 0 ? 'CALLS OUT EVERY ${every}S' : 'SILENT',
                  style: text.labelLarge?.copyWith(
                    color: on.withValues(alpha: 0.72),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Dial(
                      progress: minuteProgress(watch.elapsedMs),
                      face: face,
                      arc: deep,
                      child: _Face(watch: watch),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: CircleControl(
                        icon: Icons.refresh_rounded,
                        label: 'Reset',
                        onPressed: watch.started ? controller.reset : null,
                        background: face,
                        foreground: deep,
                        labelColor: on,
                      ),
                    ),
                    Expanded(
                      child: CircleControl(
                        icon: watch.running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: watch.preparing
                            ? 'Wait'
                            : watch.running
                            ? 'Pause'
                            : watch.started
                            ? 'Resume'
                            : 'Start',
                        onPressed: watch.preparing
                            ? null
                            : watch.running
                            ? controller.pause
                            : controller.start,
                        background: deep,
                        foreground: colors.readableOn(deep),
                        labelColor: on,
                        primary: true,
                      ),
                    ),
                    Expanded(
                      child: CircleControl(
                        icon: Icons.flag_rounded,
                        label: 'Lap',
                        onPressed: watch.running ? controller.lap : null,
                        background: face,
                        foreground: deep,
                        labelColor: on,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sizes.bigGap),

                _Laps(laps: watch.laps, face: face, deep: deep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.watch});

  final StopwatchState watch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = context.colors.readableOn(context.colors.faceOn(
      context.colors.stopwatch,
    ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            elapsed(watch.elapsedMs),
            style: text.displayLarge?.copyWith(color: ink),
          ),
        ),
        if (watch.laps.isNotEmpty)
          Text(
            'Lap ${watch.laps.length}',
            style: text.titleMedium?.copyWith(color: ink),
          ),
      ],
    );
  }
}

/// The laps, newest first, along the foot of the screen.
///
/// A row rather than a list: it sits where the running screen keeps its round
/// tracker, and a row scrolls sideways for as many laps as anyone takes
/// without ever growing tall enough to push the controls off the screen.
class _Laps extends StatelessWidget {
  const _Laps({required this.laps, required this.face, required this.deep});

  final List<int> laps;
  final Color face;
  final Color deep;

  @override
  Widget build(BuildContext context) {
    // Keeps its height with no laps in it, so taking the first one does not
    // shift the controls under the user's thumb.
    if (laps.isEmpty) return const SizedBox(height: Sizes.control);

    return SizedBox(
      height: Sizes.control,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: laps.length,
        separatorBuilder: (_, _) => const SizedBox(width: Sizes.gap),
        itemBuilder: (context, position) {
          // Newest first, and filling from the left. Reversing the list rather
          // than the scroll view, so two laps sit where the eye starts instead
          // of hugging the right-hand edge.
          final i = laps.length - 1 - position;
          // Each lap against the one before it, which is the number people
          // actually want, not the running total.
          final since = i == 0 ? laps[0] : laps[i] - laps[i - 1];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.gap),
            decoration: BoxDecoration(
              color: face.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(Sizes.control / 2),
            ),
            child: Row(
              children: [
                Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: face.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: Sizes.gap / 2),
                Text(
                  elapsed(since),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: face,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/style.dart';
import '../../../app/providers.dart';
import '../../../app/widgets/number_row.dart';
import '../../../core/timeline/summary.dart';
import '../../../core/timeline/workout.dart';

/// Edits one workout, in place and immediately.
///
/// There is no Save: every nudge writes through to the file. A workout is a
/// handful of numbers, and asking someone to confirm the numbers they just
/// chose only adds a way to lose them.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(appDataProvider).presets;
    final workout = presets.where((w) => w.id == id).firstOrNull;
    if (workout == null) {
      // Deleted from under us.
      return const Scaffold(body: Center(child: Text('Gone')));
    }

    final data = ref.read(appDataProvider.notifier);
    void edit(Workout Function(Workout) change) => data.editWorkout(id, change);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(workout.totalLabel),
        actions: [
          IconButton(
            tooltip: 'Duplicate',
            onPressed: () => context.go('/edit/${data.duplicate(id).id}'),
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: presets.length <= 1
                ? null
                : () {
                    context.go('/');
                    data.deleteWorkout(id);
                  },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Sizes.gutter),
        children: [
          TextFormField(
            key: ValueKey('name-$id'),
            initialValue: workout.name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => edit((w) => w.copyWith(name: value)),
          ),
          const SizedBox(height: Sizes.gap),

          NumberRow(
            label: 'Get ready',
            value: '${workout.prepareSeconds}s',
            onChange: (by) => edit(
              (w) => w.copyWith(
                prepareSeconds: (w.prepareSeconds + by * 5).clamp(0, 120),
              ),
            ),
          ),

          const _Heading('Rounds'),
          for (var i = 0; i < workout.rounds.length; i++)
            _RoundCard(
              key: ValueKey('round-$id-$i'),
              index: i,
              round: workout.rounds[i],
              // One round is the shape of a plain interval; removing the last
              // one would leave a workout with nothing in it.
              onRemove: workout.rounds.length <= 1
                  ? null
                  : () => edit(
                      (w) => w.copyWith(
                        rounds: [...w.rounds]..removeAt(i),
                      ),
                    ),
              onChange: (round) => edit(
                (w) => w.copyWith(rounds: [...w.rounds]..[i] = round),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => edit(
                (w) => w.copyWith(
                  rounds: [
                    ...w.rounds,
                    const Round(workSeconds: 30, restSeconds: 10),
                  ],
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add an exercise'),
            ),
          ),

          const _Heading('Repeat'),
          NumberRow(
            label: workout.rounds.length > 1 ? 'Sets' : 'Rounds',
            value: '${workout.repeats}',
            onChange: (by) =>
                edit((w) => w.copyWith(repeats: (w.repeats + by).clamp(1, 60))),
          ),
          // Only for a circuit: with one exercise, every repeat is a round
          // and Rest already is the pause between them.
          if (workout.repeats > 1 && workout.rounds.length > 1)
            NumberRow(
              label: 'Break between sets',
              value: '${workout.breakSeconds}s',
              onChange: (by) => edit(
                (w) => w.copyWith(
                  breakSeconds: (w.breakSeconds + by * 15).clamp(0, 600),
                ),
              ),
            ),
          NumberRow(
            label: 'Cool down',
            value: '${workout.cooldownSeconds}s',
            onChange: (by) => edit(
              (w) => w.copyWith(
                cooldownSeconds: (w.cooldownSeconds + by * 15).clamp(0, 600),
              ),
            ),
          ),

          const _Heading('What it says'),
          _CueSettings(
            cues: workout.cues,
            onChange: (cues) => edit((w) => w.copyWith(cues: cues)),
          ),
          const SizedBox(height: Sizes.bigGap),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Sizes.bigGap, bottom: Sizes.gap),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: context.colors.muted,
        letterSpacing: 1.5,
      ),
    ),
  );
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    super.key,
    required this.index,
    required this.round,
    required this.onChange,
    required this.onRemove,
  });

  final int index;
  final Round round;
  final ValueChanged<Round> onChange;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: Sizes.gap),
    child: Padding(
      padding: const EdgeInsets.all(Sizes.gutter),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: round.label,
                  decoration: InputDecoration(
                    labelText: 'Exercise',
                    // The label is spoken, so say what it will sound like.
                    hintText: 'spoken as "go, round ${index + 1}" if empty',
                  ),
                  onChanged: (value) => onChange(round.copyWith(label: value)),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                tooltip: 'Remove',
              ),
            ],
          ),
          NumberRow(
            label: 'Work',
            value: '${round.workSeconds}s',
            onChange: (by) => onChange(
              round.copyWith(
                workSeconds: (round.workSeconds + by * 5).clamp(5, 900),
              ),
            ),
          ),
          NumberRow(
            label: 'Rest',
            value: '${round.restSeconds}s',
            onChange: (by) => onChange(
              round.copyWith(
                restSeconds: (round.restSeconds + by * 5).clamp(0, 600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CueSettings extends StatelessWidget {
  const _CueSettings({required this.cues, required this.onChange});

  final CueSettings cues;
  final ValueChanged<CueSettings> onChange;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Name each phase'),
        subtitle: const Text('"go", "rest"'),
        value: cues.phaseWords,
        onChanged: (v) => onChange(cues.copyWith(phaseWords: v)),
      ),
      SwitchListTile(
        title: const Text('Count down to the change'),
        subtitle: Text('"${cues.countdownFrom == 5 ? 'five, four, ' : ''}'
            'three, two, one"'),
        value: cues.countdown,
        onChanged: (v) => onChange(cues.copyWith(countdown: v)),
      ),
      if (cues.countdown)
        NumberRow(
          label: 'Count from',
          value: '${cues.countdownFrom}',
          onChange: (by) => onChange(
            cues.copyWith(
              countdownFrom: (cues.countdownFrom + by).clamp(1, 10),
            ),
          ),
        ),
      SwitchListTile(
        title: const Text('Say the round'),
        subtitle: const Text('"go, round 3" — or the exercise\'s name'),
        value: cues.roundLabels,
        onChanged: (v) => onChange(cues.copyWith(roundLabels: v)),
      ),
      SwitchListTile(
        title: const Text('Warn on the last round'),
        value: cues.lastRound,
        onChanged: (v) => onChange(cues.copyWith(lastRound: v)),
      ),
      SwitchListTile(
        title: const Text('Say "halfway"'),
        subtitle: const Text('On work phases of 20s or more'),
        value: cues.halfway,
        onChanged: (v) => onChange(cues.copyWith(halfway: v)),
      ),
    ],
  );
}

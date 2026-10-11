import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/style.dart';
import '../../../app/widgets/circle_badge.dart';
import '../../../app/widgets/number_row.dart';
import '../../../app/widgets/section.dart';
import '../../../app/widgets/soft_background.dart';
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
    final colors = context.colors;
    // The editor wears what it is editing, so there is never a moment of
    // editing a focus session on a screen lit like a workout.
    final accent = workout.kind == TimerKind.focus
        ? colors.focus
        : colors.work;
    void edit(Workout Function(Workout) change) => data.editWorkout(id, change);

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(
        leadingWidth: Sizes.bigControl,
        leading: Padding(
          padding: const EdgeInsets.only(left: Sizes.gap),
          child: IconButton(
            onPressed: () => context.go('/'),
            style: chipIconButton(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: const Text('Edit'),
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
      body: SoftBackground(
        color: Brand.ink,
        glow: accent,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sizes.gutter,
              Sizes.gap,
              Sizes.gutter,
              Sizes.bigGap,
            ),
            children: [
              // The name, beside the one number that changes as you edit.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Sizes.gutter),
                  child: Row(
                    children: [
                      CircleBadge(
                        size: Sizes.badgeSmall,
                        background: colors.washOf(accent),
                        // Scaled, not wrapped. A focus session's total is
                        // "2:10:00" and wrapping it inside a disc reads as
                        // "2:10:0 / 0", which throws nothing and looks like
                        // a bug because it is one.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            workout.totalLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: Sizes.gap),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('name-$id'),
                          initialValue: workout.name,
                          decoration: const InputDecoration(labelText: 'Name'),
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (value) =>
                              edit((w) => w.copyWith(name: value)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // A focus session is four numbers, and the workout editor's
              // shape is wrong for every one of them: no warm up, no circuit
              // of exercises, and nothing to decide about what it says
              // because the script is fixed quiet.
              if (workout.kind == TimerKind.focus)
                Section(
                  icon: Icons.psychology_alt_rounded,
                  title: 'Blocks',
                  subtitle: workout.summary,
                  accent: accent,
                  children: [
                    NumberRow(
                      label: 'Focus',
                      value: '${workout.rounds.first.workSeconds ~/ 60}m',
                      onChange: (by) => edit(
                        (w) => w.copyWith(
                          rounds: [
                            w.rounds.first.copyWith(
                              workSeconds:
                                  (w.rounds.first.workSeconds + by * 300).clamp(
                                    300,
                                    7200,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    NumberRow(
                      label: 'Break',
                      value: '${workout.rounds.first.restSeconds ~/ 60}m',
                      onChange: (by) => edit(
                        (w) => w.copyWith(
                          rounds: [
                            w.rounds.first.copyWith(
                              restSeconds:
                                  (w.rounds.first.restSeconds + by * 60).clamp(
                                    0,
                                    3600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    NumberRow(
                      label: 'Blocks',
                      value: '${workout.repeats}',
                      onChange: (by) => edit(
                        (w) =>
                            w.copyWith(repeats: (w.repeats + by).clamp(1, 12)),
                      ),
                    ),
                    // After the last block, not between every pair of them —
                    // which is why it is the cool down underneath.
                    NumberRow(
                      label: 'Long break',
                      value: '${workout.cooldownSeconds ~/ 60}m',
                      onChange: (by) => edit(
                        (w) => w.copyWith(
                          cooldownSeconds: (w.cooldownSeconds + by * 300).clamp(
                            0,
                            3600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                Section(
                  icon: Icons.hourglass_top_rounded,
                  title: 'Warm up',
                  subtitle: workout.prepareSeconds == 0
                      ? 'Straight in'
                      : '${workout.prepareSeconds}s before the first round',
                  children: [
                    NumberRow(
                      label: 'Get ready',
                      value: '${workout.prepareSeconds}s',
                      onChange: (by) => edit(
                        (w) => w.copyWith(
                          prepareSeconds: (w.prepareSeconds + by * 5).clamp(
                            0,
                            120,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // A card each rather than one long box: a round is a thing, and
                // five of them in one card read as one thing with fifteen rows.
                SectionHeading(
                  icon: Icons.fitness_center_rounded,
                  title: 'Exercises',
                  subtitle: workout.rounds.length == 1
                      ? 'One exercise, repeated'
                      : '${workout.rounds.length} exercises in a circuit',
                ),
                for (var i = 0; i < workout.rounds.length; i++) ...[
                  _RoundCard(
                    key: ValueKey('round-$id-$i'),
                    index: i,
                    round: workout.rounds[i],
                    // One round is the shape of a plain interval; removing the
                    // last would leave a workout with nothing in it.
                    onRemove: workout.rounds.length <= 1
                        ? null
                        : () => edit(
                            (w) =>
                                w.copyWith(rounds: [...w.rounds]..removeAt(i)),
                          ),
                    onChange: (round) => edit(
                      (w) => w.copyWith(rounds: [...w.rounds]..[i] = round),
                    ),
                  ),
                  const SizedBox(height: Sizes.gap),
                ],
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
                    label: const ActionLabel('Add an exercise'),
                  ),
                ),

                Section(
                  icon: Icons.repeat_rounded,
                  title: 'Repeat',
                  subtitle: workout.summary,
                  children: [
                    NumberRow(
                      label: workout.rounds.length > 1 ? 'Sets' : 'Rounds',
                      value: '${workout.repeats}',
                      onChange: (by) => edit(
                        (w) =>
                            w.copyWith(repeats: (w.repeats + by).clamp(1, 60)),
                      ),
                    ),
                    // Only for a circuit: with one exercise, every repeat is a
                    // round and Rest already is the pause between them.
                    if (workout.repeats > 1 && workout.rounds.length > 1)
                      NumberRow(
                        label: 'Break between sets',
                        value: '${workout.breakSeconds}s',
                        onChange: (by) => edit(
                          (w) => w.copyWith(
                            breakSeconds: (w.breakSeconds + by * 15).clamp(
                              0,
                              600,
                            ),
                          ),
                        ),
                      ),
                    NumberRow(
                      label: 'Cool down',
                      value: '${workout.cooldownSeconds}s',
                      onChange: (by) => edit(
                        (w) => w.copyWith(
                          cooldownSeconds: (w.cooldownSeconds + by * 15).clamp(
                            0,
                            600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Section(
                  icon: Icons.record_voice_over_rounded,
                  title: 'What it says',
                  subtitle: _spoken(workout.cues),
                  children: [
                    _CueSettings(
                      cues: workout.cues,
                      onChange: (cues) => edit((w) => w.copyWith(cues: cues)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The heading says what it will actually say, so the switches below do not
  /// have to be read to find out.
  String _spoken(CueSettings cues) {
    final on = [
      if (cues.phaseWords) 'phases',
      if (cues.countdown) 'countdown',
      if (cues.roundLabels) 'rounds',
      if (cues.halfway) 'halfway',
    ];
    return on.isEmpty ? 'Silent' : on.join(', ');
  }
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
    child: Padding(
      padding: const EdgeInsets.all(Sizes.gutter),
      child: Column(
        children: [
          Row(
            children: [
              CircleBadge(
                size: Sizes.badgeTiny,
                background: Brand.accentWash,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: context.colors.work),
                ),
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                child: TextFormField(
                  initialValue: round.label,
                  decoration: InputDecoration(
                    labelText: 'Exercise',
                    // The label is spoken, so say what it will sound like.
                    hintText: 'spoken as "round ${index + 1}" if empty',
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
      _Switch(
        title: 'Name each phase',
        subtitle: '"go", "rest"',
        value: cues.phaseWords,
        onChanged: (v) => onChange(cues.copyWith(phaseWords: v)),
      ),
      _Switch(
        title: 'Count down to the change',
        subtitle:
            '"${cues.countdownFrom == 5 ? 'five, four, ' : ''}three, two, one"',
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
      _Switch(
        title: 'Say the round',
        subtitle: '"go, round 3" — or the exercise\'s name',
        value: cues.roundLabels,
        onChanged: (v) => onChange(cues.copyWith(roundLabels: v)),
      ),
      _Switch(
        title: 'Warn on the last round',
        subtitle: '"go, last round"',
        value: cues.lastRound,
        onChanged: (v) => onChange(cues.copyWith(lastRound: v)),
      ),
      _Switch(
        title: 'Say "halfway"',
        subtitle: 'On work phases of 20s or more',
        value: cues.halfway,
        onChanged: (v) => onChange(cues.copyWith(halfway: v)),
      ),
    ],
  );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

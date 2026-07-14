import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'habit_repository.dart';

final _allHabitsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(habitRepositoryProvider).watchAllHabits();
});

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(_allHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showAddHabitSheet(context, ref),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return const EmptyState(
              icon: Icons.water_drop_outlined,
              message: 'No habits set',
              hint: 'Tap + to set a habit to track daily.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: habits.length,
            itemBuilder: (context, i) => _HabitTile(habit: habits[i]),
          );
        },
      ),
    );
  }

  void _showAddHabitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HabitAddSheet(),
    );
  }
}

// ── Habit Tile ────────────────────────────────────────────────────────────────

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(habitRepositoryProvider);

    return AppCard(
      child: ListTile(
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: habit.active ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Target: ${habit.targetPerDay} per day',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (habit.reminderTimes != null &&
                habit.reminderTimes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: habit.reminderTimes!.map<Widget>((time) {
                  return StatusChip(status: time);
                }).toList(),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: habit.active,
              onChanged: (active) {
                repo.updateHabit(habit.copyWith(active: active));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Habit?',
      message: 'Remove "${habit.name}"? This deletes all history logs.',
    );
    if (confirmed == true) {
      await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
    }
  }
}

// ── Habit Add Sheet ───────────────────────────────────────────────────────────

class _HabitAddSheet extends ConsumerStatefulWidget {
  const _HabitAddSheet();

  @override
  ConsumerState<_HabitAddSheet> createState() => _HabitAddSheetState();
}

class _HabitAddSheetState extends ConsumerState<_HabitAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '1');
  final _times = <String>{};

  static const _defaultTimes = ['09:00', '13:00', '17:00', '21:00'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Habit', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target count per day',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Reminders (Select times)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _defaultTimes.map((time) {
                final selected = _times.contains(time);
                return ChoiceChip(
                  label: Text(time),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _times.add(time);
                      } else {
                        _times.remove(time);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final target = int.parse(_targetCtrl.text);
    final timesList = _times.toList()..sort();

    await ref
        .read(habitRepositoryProvider)
        .createHabit(
          HabitsCompanion.insert(
            name: _nameCtrl.text.trim(),
            targetPerDay: Value(target),
            reminderTimes: Value(timesList.isEmpty ? null : timesList),
          ),
        );

    if (mounted) Navigator.of(context).pop();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'reminder_edit_sheet.dart';
import 'reminder_repository.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(_remindersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'reminder_fab',
        onPressed: () => ReminderEditSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: remindersAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reminders) {
          if (reminders.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_outlined,
              message: 'No reminders',
              hint: 'Tap + to add a reminder with a window',
            );
          }
          final today = _todayStr();
          final active = reminders
              .where((r) => ReminderRepository.isActiveOn(r, today))
              .toList();
          final upcoming = reminders
              .where(
                (r) => r.status == 'open' && r.windowStart.compareTo(today) > 0,
              )
              .toList();
          final closed = reminders.where((r) => r.status != 'open').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                const SectionHeader(title: 'Active now'),
                ...active.map((r) => _ReminderCard(r)),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                const SectionHeader(title: 'Upcoming'),
                ...upcoming.map((r) => _ReminderCard(r)),
                const SizedBox(height: 16),
              ],
              if (closed.isNotEmpty) ...[
                const SectionHeader(title: 'Closed'),
                ...closed.map((r) => _ReminderCard(r)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}

final _remindersProvider = StreamProvider.autoDispose<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchAll(),
);

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard(this.reminder);
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('d MMM yyyy');
    final startDt = _parse(reminder.windowStart);
    final endDt = reminder.windowEnd != null
        ? _parse(reminder.windowEnd!)
        : null;

    return AppCard(
      child: ListTile(
        leading: PriorityBadge(priority: reminder.priority),
        title: Text(reminder.title),
        subtitle: Text(
          endDt != null
              ? '${fmt.format(startDt)} – ${fmt.format(endDt)}'
              : 'From ${fmt.format(startDt)}',
        ),
        trailing: StatusChip(status: reminder.status),
        onTap: () => ReminderEditSheet.show(context, existing: reminder),
        onLongPress: () => _showActions(context, ref),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final repo = ref.read(reminderRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reminder.status == 'open') ...[
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Mark done'),
                onTap: () async {
                  Navigator.pop(context);
                  await repo.markDone(reminder.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Dismiss'),
                onTap: () async {
                  Navigator.pop(context);
                  await repo.dismiss(reminder.id);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                await repo.delete(reminder.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _parse(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}

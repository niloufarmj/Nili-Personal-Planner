import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import 'wellbeing_repository.dart';

final _activeActionsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(wellbeingRepositoryProvider).watchActiveActions();
});

final _logsForDateProvider = StreamProvider.autoDispose.family<List<WellbeingLog>, String>((ref, dateStr) {
  return ref.watch(wellbeingRepositoryProvider).watchLogsForDate(dateStr);
});

final _dailyLogCountsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(wellbeingRepositoryProvider).watchDailyLogCounts();
});

class WellbeingScreen extends ConsumerStatefulWidget {
  const WellbeingScreen({super.key});

  @override
  ConsumerState<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends ConsumerState<WellbeingScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _fmt(now);

    final actionsAsync = ref.watch(_activeActionsProvider);
    final logsAsync = ref.watch(_logsForDateProvider(todayStr));
    final countsAsync = ref.watch(_dailyLogCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeling Better'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add self-care action',
            onPressed: () => _showAddActionSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Today's checklist ─────────────────────────────────────────────
          const SectionHeader(title: "Today's Checklist"),
          const SizedBox(height: 8),
          actionsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (actions) {
              if (actions.isEmpty) {
                return const EmptyState(
                  icon: Icons.self_improvement,
                  message: 'No checklist items',
                  hint: 'Add some daily self-care goals!',
                );
              }

              return logsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (logs) {
                  final loggedIds = logs.map((l) => l.actionId).toSet();

                  return AppCard(
                    child: Column(
                      children: actions.map((action) {
                        final isLogged = loggedIds.contains(action.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: isLogged,
                            onChanged: (val) async {
                              HapticFeedback.lightImpact();
                              final repo = ref.read(wellbeingRepositoryProvider);
                              if (isLogged) {
                                await repo.unlogAction(action.id, todayStr);
                              } else {
                                await repo.logAction(action.id, todayStr);
                              }
                            },
                          ),
                          title: Text(action.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _deleteAction(action),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Heatmap calendar ──────────────────────────────────────────────
          const SectionHeader(title: 'Activity Heatmap'),
          const SizedBox(height: 8),
          countsAsync.when(
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (counts) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar<void>(
                    firstDay: DateTime(2025),
                    lastDay: DateTime(2030),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, _) => _buildHeatCell(day, counts),
                      todayBuilder: (context, day, _) => _buildHeatCell(day, counts, isToday: true),
                      outsideBuilder: (context, day, _) => _buildHeatCell(day, counts, isOutside: true),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeatCell(DateTime day, Map<String, int> counts, {bool isToday = false, bool isOutside = false}) {
    final dateStr = _fmt(day);
    final count = counts[dateStr] ?? 0;

    // Heat intensities
    Color? color;
    if (count > 0) {
      final intensity = (count * 0.25).clamp(0.2, 0.9);
      color = Colors.teal.withValues(alpha: intensity);
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isOutside
                ? Colors.grey[400]
                : (count > 0 ? Colors.white : null),
            fontWeight: isToday ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAction(WellbeingAction action) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Action?',
      message: 'Remove "${action.name}"? This deletes all completed logs for this action.',
    );
    if (confirmed == true) {
      await ref.read(wellbeingRepositoryProvider).deleteAction(action.id);
    }
  }

  void _showAddActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ActionAddSheet(),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Action add sheet ──────────────────────────────────────────────────────────

class _ActionAddSheet extends ConsumerStatefulWidget {
  const _ActionAddSheet();

  @override
  ConsumerState<_ActionAddSheet> createState() => _ActionAddSheetState();
}

class _ActionAddSheetState extends ConsumerState<_ActionAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
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
            Text('Add Self-Care Action', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Action Name (e.g. read, tea)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
    await ref.read(wellbeingRepositoryProvider).createAction(_ctrl.text.trim());
    if (mounted) Navigator.of(context).pop();
  }
}

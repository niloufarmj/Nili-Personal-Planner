import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calendar/calendar_aggregator.dart';
import '../../core/calendar/calendar_day_data.dart';
import '../../core/conflicts/conflict_engine.dart';
import '../../core/conflicts/conflict_item.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/design/design.dart';
import '../calendar/day_tag_picker.dart';
import '../calendar/event_edit_sheet.dart';
import '../../core/db/database.dart';
import '../meals/meal_slot_repository.dart';
import '../meals/recipe_repository.dart';

// ── Provider: today's aggregated data ─────────────────────────────────────────

final _todayDataProvider = FutureProvider.autoDispose<CalendarDayData>((
  ref,
) async {
  final today = _todayDate();
  final agg = ref.watch(calendarAggregatorProvider);
  final map = await agg.getDataForRange(today, today);
  return map[_fmtDate(today)] ?? CalendarDayData(date: today);
});

final _todayEventsProvider = FutureProvider.autoDispose<List<EventOccurrence>>((
  ref,
) {
  final today = _todayDate();
  final repo = ref.watch(eventRepositoryProvider);
  return repo.expandOccurrences(today, today);
});

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── Screen ─────────────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _todayDate();
    final todayStr = _fmtDate(today);
    final headerFmt = DateFormat('EEEE, MMMM d');

    return Scaffold(
      appBar: AppBar(
        title: Text(headerFmt.format(today)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tag),
            tooltip: 'Day tags',
            onPressed: () => _showTagSheet(context, todayStr),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'today_fab',
        onPressed: () => _showQuickAdd(context, todayStr),
        tooltip: 'Quick add',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_todayDataProvider);
          ref.invalidate(_todayEventsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Day overview strip ─────────────────────────────────
            _DayOverviewStrip(todayStr: todayStr),
            const SizedBox(height: 20),

            // ── Events ────────────────────────────────────────────
            const SectionHeader(title: "Today's Events"),
            const SizedBox(height: 8),
            _EventsList(todayStr: todayStr),
            const SizedBox(height: 20),

            // ── Conflict feed ──────────────────────────────────────
            const SectionHeader(title: 'Conflicts & Reminders'),
            _ConflictFeed(today: today),
            const SizedBox(height: 20),

            // ── Today's meals ──────────────────────────────────────
            const SectionHeader(title: "Today's Meals"),
            _TodayMeals(todayStr: todayStr),
            const SizedBox(height: 20),

            const SectionHeader(title: 'Habits'),
            const _AgentPlaceholder('Habit tracker — agent 4'),
            const SizedBox(height: 80), // FAB clearance
          ],
        ),
      ),
    );
  }

  void _showTagSheet(BuildContext context, String todayStr) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tags for today',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DayTagPicker(date: todayStr),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickAdd(BuildContext context, String todayStr) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _QuickAddSheet(todayStr: todayStr),
    );
  }
}

// ── Day overview strip ─────────────────────────────────────────────────────────

class _DayOverviewStrip extends ConsumerWidget {
  const _DayOverviewStrip({required this.todayStr});
  final String todayStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_todayDataProvider);
    return dataAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final chips = <Widget>[];
        if (data.gymSession != null) {
          chips.add(const _OverviewChip(Icons.fitness_center, 'Gym'));
        }
        if (data.mealDots > 0) {
          chips.add(_OverviewChip(Icons.restaurant, '${data.mealDots} meals'));
        }
        if (data.dueDots > 0) {
          chips.add(_OverviewChip(Icons.task_alt, '${data.dueDots} due'));
        }
        if (data.tripBars.isNotEmpty) {
          chips.add(const _OverviewChip(Icons.flight_takeoff, 'Travel'));
        }
        if (chips.isEmpty) return const SizedBox.shrink();
        return Wrap(spacing: 8, runSpacing: 4, children: chips);
      },
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Events list ───────────────────────────────────────────────────────────────

class _EventsList extends ConsumerWidget {
  const _EventsList({required this.todayStr});
  final String todayStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occsAsync = ref.watch(_todayEventsProvider);
    return occsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Nothing scheduled today',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: occs.map((occ) {
            final e = occ.event;
            final timeStr = e.startTime != null
                ? '${e.startTime}${e.endTime != null ? ' – ${e.endTime}' : ''}'
                : null;
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_categoryIcon(e.category)),
                title: Text(e.title),
                subtitle: timeStr != null ? Text(timeStr) : null,
                trailing: e.location != null
                    ? Text(
                        e.location!,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                onTap: () => EventEditSheet.show(context, existing: e),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static IconData _categoryIcon(String cat) => switch (cat) {
    'appointment' => Icons.medical_services_outlined,
    'partner' => Icons.favorite_outline,
    'uni' => Icons.school_outlined,
    'work' => Icons.work_outline,
    _ => Icons.event_outlined,
  };
}

// ── Conflict feed ─────────────────────────────────────────────────────────────

final _conflictsProvider = StreamProvider.autoDispose
    .family<List<ConflictItem>, DateTime>(
      (ref, date) => ref.watch(conflictFeedProvider).watchConflicts(date),
    );

class _ConflictFeed extends ConsumerWidget {
  const _ConflictFeed({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_conflictsProvider(today));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 12),
                  Text('No conflicts or active reminders'),
                ],
              ),
            ),
          );
        }
        return Column(
          children: items.map((item) => _ConflictCard(item: item)).toList(),
        );
      },
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.item});
  final ConflictItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.severity) {
      ConflictSeverity.error => Colors.red,
      ConflictSeverity.warning => Colors.orange,
      ConflictSeverity.info => Colors.blue,
    };
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(item.message)),
              ],
            ),
            if (item.actions.isNotEmpty)
              Wrap(
                spacing: 8,
                children: item.actions
                    .map(
                      (a) =>
                          TextButton(onPressed: a.onTap, child: Text(a.label)),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Today's meals ─────────────────────────────────────────────────────────────

final _todayMealSlotsProvider = FutureProvider.autoDispose
    .family<List<MealSlot>, String>(
      (ref, date) => ref.watch(mealSlotRepositoryProvider).getForDate(date),
    );

class _TodayMeals extends ConsumerWidget {
  const _TodayMeals({required this.todayStr});
  final String todayStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_todayMealSlotsProvider(todayStr));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (slots) {
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'No meals planned',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: slots.map((s) => _MealSlotChip(slot: s)).toList(),
        );
      },
    );
  }
}

class _MealSlotChip extends ConsumerWidget {
  const _MealSlotChip({required this.slot});
  final MealSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = slot.recipeId != null
        ? ref.watch(_recipeNameForTodayProvider(slot.recipeId!))
        : const AsyncData<String?>(null);
    final name = recipeAsync.valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(_slotIcon(slot.slot), size: 20),
          title: Text(name ?? slot.slot),
          subtitle: Text(_capitalize(slot.slot)),
          trailing: _statusChip(slot.status),
        ),
      ),
    );
  }

  static IconData _slotIcon(String s) => switch (s) {
    'breakfast' => Icons.free_breakfast_outlined,
    'lunch' => Icons.lunch_dining_outlined,
    'dinner' => Icons.dinner_dining_outlined,
    _ => Icons.sports_bar_outlined,
  };

  static Widget _statusChip(String status) {
    final color = switch (status) {
      'accepted' => Colors.green,
      'eaten' => Colors.blue,
      'skipped' => Colors.grey,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

final _recipeNameForTodayProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, id) async {
      final r = await ref.watch(recipeRepositoryProvider).getById(id);
      return r?.name;
    });

// ── Agent placeholder ─────────────────────────────────────────────────────────

class _AgentPlaceholder extends StatelessWidget {
  const _AgentPlaceholder(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}

// ── Quick-add sheet ───────────────────────────────────────────────────────────

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.todayStr});
  final String todayStr;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quick add', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _QuickAddTile(
              icon: Icons.event_outlined,
              label: 'Event',
              onTap: () {
                Navigator.of(context).pop();
                EventEditSheet.show(context, initialDate: todayStr);
              },
            ),
            _QuickAddTile(
              icon: Icons.attach_money,
              label: 'Expense',
              onTap: () {
                Navigator.of(context).pop();
                _comingSoon(context, 'Expense');
              },
            ),
            _QuickAddTile(
              icon: Icons.check_box_outlined,
              label: 'Task',
              onTap: () {
                Navigator.of(context).pop();
                _comingSoon(context, 'Task');
              },
            ),
            _QuickAddTile(
              icon: Icons.flight_outlined,
              label: 'Trip',
              onTap: () {
                Navigator.of(context).pop();
                _comingSoon(context, 'Trip');
              },
            ),
            _QuickAddTile(
              icon: Icons.sticky_note_2_outlined,
              label: 'Note',
              onTap: () {
                Navigator.of(context).pop();
                _comingSoon(context, 'Note');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what — coming soon')));
  }
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}

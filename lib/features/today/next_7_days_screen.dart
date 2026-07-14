import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/design/design.dart';
import '../lists/repositories/item_repository.dart';

class DayPlans {
  final DateTime date;
  final List<EventOccurrence> events;
  final List<Item> tasks;
  final List<GymSession> gymSessions;

  DayPlans({
    required this.date,
    required this.events,
    required this.tasks,
    required this.gymSessions,
  });

  bool get isEmpty => events.isEmpty && tasks.isEmpty && gymSessions.isEmpty;
}

class Next7DaysData {
  final List<DayPlans> days;
  final Map<int, WorkoutPlan> planById;

  Next7DaysData({required this.days, required this.planById});
}

final next7DaysDataProvider = FutureProvider.autoDispose<Next7DaysData>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final endDay = today.add(const Duration(days: 6));

  final events = await ref.read(eventRepositoryProvider).expandOccurrences(today, endDay);
  final tasks = await ref.read(itemRepositoryProvider).getItemsDueInRange(today, endDay);

  final db = ref.read(appDatabaseProvider);
  final startStr = DateFormat('yyyy-MM-dd').format(today);
  final endStr = DateFormat('yyyy-MM-dd').format(endDay);
  
  final gymSessions = await (db.select(db.gymSessions)
        ..where((s) => s.date.isBiggerOrEqualValue(startStr) & s.date.isSmallerOrEqualValue(endStr)))
      .get();
      
  final plans = await db.select(db.workoutPlans).get();
  final planById = {for (final p in plans) p.id: p};

  final Map<String, DayPlans> map = {};
  for (int i = 0; i < 7; i++) {
    final d = today.add(Duration(days: i));
    final key = DateFormat('yyyy-MM-dd').format(d);
    map[key] = DayPlans(
      date: d,
      events: [],
      tasks: [],
      gymSessions: [],
    );
  }

  for (final ev in events) {
    final key = DateFormat('yyyy-MM-dd').format(ev.date);
    map[key]?.events.add(ev);
  }

  for (final t in tasks) {
    if (t.dueDate == null) continue;
    map[t.dueDate!]?.tasks.add(t);
  }

  for (final s in gymSessions) {
    map[s.date]?.gymSessions.add(s);
  }

  final sortedDays = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return Next7DaysData(days: sortedDays, planById: planById);
});

class Next7DaysScreen extends ConsumerWidget {
  const Next7DaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final plansAsync = ref.watch(next7DaysDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Next 7 Days Plans'),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final days = data.days;
          final planById = data.planById;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final dayPlan = days[index];
              final date = dayPlan.date;
              final isToday = index == 0;
              final isTomorrow = index == 1;

              String title = '';
              if (isToday) {
                title = 'Today';
              } else if (isTomorrow) {
                title = 'Tomorrow';
              } else {
                title = DateFormat('EEEE').format(date);
              }

              final dateSub = DateFormat('MMMM d').format(date);

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: title,
                      trailing: Text(
                        dateSub,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dayPlan.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        child: Center(
                          child: Text(
                            'No plans scheduled.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            // Gym sessions
                            ...dayPlan.gymSessions.map((gym) {
                              final planName = planById[gym.planId]?.name ?? '';
                              return _PlanItemRow(
                                icon: Icons.fitness_center,
                                iconColor: DesignTokens.dustyBlue,
                                title: planName.isNotEmpty ? 'Gym Workout - Plan $planName' : 'Gym Workout',
                                subtitle: gym.notes ?? 'Planned session',
                              );
                            }),
                            // Events
                            ...dayPlan.events.map((ev) {
                              final timeStr = ev.event.startTime != null
                                  ? '${ev.event.startTime}${ev.event.endTime != null ? ' - ${ev.event.endTime}' : ''}'
                                  : 'All Day';
                              return _PlanItemRow(
                                icon: Icons.event,
                                iconColor: DesignTokens.rose,
                                title: ev.event.title,
                                subtitle: '$timeStr${ev.event.location != null ? ' @ ${ev.event.location}' : ''}',
                              );
                            }),
                            // Tasks / Deadlines
                            ...dayPlan.tasks.map((task) {
                              final isCompleted = task.status == 'done';
                              return _PlanItemRow(
                                icon: Icons.check_circle_outline,
                                iconColor: isCompleted ? DesignTokens.success : DesignTokens.lavender,
                                title: task.title,
                                subtitle: 'Deadline • ${task.description ?? 'No description'}',
                                isStrikethrough: isCompleted,
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isStrikethrough = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isStrikethrough;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isStrikethrough ? TextDecoration.lineThrough : null,
                    color: isStrikethrough
                        ? Colors.grey
                        : (isDark ? DesignTokens.inkDark : DesignTokens.inkLight),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

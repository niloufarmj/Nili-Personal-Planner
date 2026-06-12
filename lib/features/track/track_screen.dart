import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/db/database.dart';
import '../../core/design/design.dart';
import '../finance/repositories/transaction_repository.dart';
import '../habits/habit_repository.dart';

// ── Providers for Real-time Statistics ─────────────────────────────────────────

final _financeStatsProvider = StreamProvider.autoDispose<int>((ref) {
  final now = DateTime.now();
  return ref
      .watch(transactionRepositoryProvider)
      .watchByMonth(now.year, now.month)
      .map((txs) {
        int net = 0;
        for (final tx in txs) {
          if (tx.direction == 'in') {
            net += tx.amountCents;
          } else {
            net -= tx.amountCents;
          }
        }
        return net;
      });
});

final _activeHabitsProvider = StreamProvider.autoDispose<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchActiveHabits();
});

final _todayLogsProvider = StreamProvider.autoDispose<List<HabitLog>>((ref) {
  final todayStr = DateTime.now().toIso8601String().split('T').first;
  return ref.watch(habitRepositoryProvider).watchLogsForDate(todayStr);
});

final _habitsStatsProvider = Provider.autoDispose<String>((ref) {
  final habitsAsync = ref.watch(_activeHabitsProvider);
  final logsAsync = ref.watch(_todayLogsProvider);

  return habitsAsync.maybeWhen(
    data: (habits) {
      if (habits.isEmpty) return '0 habits';
      return logsAsync.maybeWhen(
        data: (logs) {
          final logMap = {for (final l in logs) l.habitId: l.count};
          int completed = 0;
          for (final h in habits) {
            final count = logMap[h.id] ?? 0;
            if (count >= h.targetPerDay) {
              completed++;
            }
          }
          return '$completed/${habits.length} done';
        },
        orElse: () => '—',
      );
    },
    orElse: () => '—',
  );
});

final _gymStatsProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final daysFromMonday = (now.weekday - 1) % 7;
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: daysFromMonday));
  final sunday = monday.add(const Duration(days: 6));

  final startStr =
      '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';
  final endStr =
      '${sunday.year.toString().padLeft(4, '0')}-'
      '${sunday.month.toString().padLeft(2, '0')}-'
      '${sunday.day.toString().padLeft(2, '0')}';

  return (db.select(db.gymSessions)..where(
        (s) =>
            s.status.equals('done') & s.date.isBetweenValues(startStr, endStr),
      ))
      .watch()
      .map((rows) => rows.length);
});

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Track tab — Finance · Work Time · Social · Gym · Fitness · Habits · Wellbeing · Meals.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final financeNetAsync = ref.watch(_financeStatsProvider);
    final habitsStats = ref.watch(_habitsStatsProvider);
    final gymCountAsync = ref.watch(_gymStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track',
          style: GoogleFonts.fraunces(
            fontSize: DesignTokens.fontTitle,
            fontWeight: FontWeight.w600,
            color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        children: [
          _TrackEntry(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Finance',
            subtitle: 'Transactions, budget forecast & debts',
            route: '/finance',
            color: DesignTokens.sage,
            trailing: financeNetAsync.maybeWhen(
              data: (net) {
                final formatted = CurrencyFormatter.format(net.abs());
                final sign = net >= 0 ? '+' : '–';
                final color = net >= 0
                    ? DesignTokens.success
                    : DesignTokens.danger;
                return Text(
                  '$sign$formatted',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
              orElse: () => const Text('—'),
            ),
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.access_time,
            title: 'Work Time',
            subtitle: 'Log hours, run timer & track overtime',
            route: '/worktime',
            color: DesignTokens.lavender,
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.share,
            title: 'Social',
            subtitle: 'Social media usage & post streaks',
            route: '/social',
            color: DesignTokens.rose,
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.fitness_center,
            title: 'Gym',
            subtitle: 'Sessions, plans & attendance',
            route: '/gym',
            color: DesignTokens.dustyBlue,
            trailing: gymCountAsync.maybeWhen(
              data: (count) {
                return Text(
                  '$count ${count == 1 ? 'workout' : 'workouts'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? DesignTokens.inkDark
                        : DesignTokens.inkLight,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
              orElse: () => const Text('—'),
            ),
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.monitor_weight_outlined,
            title: 'Fitness',
            subtitle: 'Measurements, goals & charts',
            route: '/fitness',
            color: DesignTokens.blush,
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.water_drop_outlined,
            title: 'Habits',
            subtitle: 'Water, skincare, reading & more',
            route: '/habits',
            color: DesignTokens.dustyBlue,
            trailing: Text(
              habitsStats,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.self_improvement,
            title: 'Feeling Better',
            subtitle: 'Self-care actions & history',
            route: '/wellbeing',
            color: DesignTokens.peach,
          ),
          const SizedBox(height: 16),
          _TrackEntry(
            icon: Icons.restaurant,
            title: 'Meals',
            subtitle: 'Weekly meal grid & shopping list',
            route: '/meals',
            color: DesignTokens.peach,
          ),
        ],
      ),
    );
  }
}

class _TrackEntry extends StatelessWidget {
  const _TrackEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = DesignTokens.resolvePastelFill(color: color, isDark: isDark);
    final fg = isDark ? DesignTokens.inkDark : color;
    final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => context.push(route),
      child: Row(
        children: [
          // Circular Pastel Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(width: 16),
          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: inkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? DesignTokens.inkSoftDark
                        : DesignTokens.inkSoftLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Trailing Stat
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
            size: 20,
          ),
        ],
      ),
    );
  }
}

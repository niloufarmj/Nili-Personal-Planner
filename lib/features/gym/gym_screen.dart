import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import 'gym_repository.dart';
import 'gym_session_log_sheet.dart';
import 'gym_program_guide_screen.dart';
import 'log_sport_activity_sheet.dart';
import 'plan_sport_session_sheet.dart';
import 'sport_analytics_screen.dart';
import 'sport_repository.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _upcomingProvider = StreamProvider.autoDispose<List<GymSession>>(
  (ref) => ref.watch(gymRepositoryProvider).watchUpcoming(),
);

final _historyProvider = StreamProvider.autoDispose<List<GymSession>>(
  (ref) => ref.watch(gymRepositoryProvider).watchHistory(),
);

final _weekStatProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(gymRepositoryProvider).doneCountForWeek(DateTime.now()),
);

// Family providers used by tiles (stable identity → no rebuild loop)
final _gymSessionForDateProvider = FutureProvider.autoDispose
    .family<GymSession?, String>(
      (ref, date) => ref.watch(gymRepositoryProvider).sessionForDate(date),
    );

final _tagsForDateProvider = FutureProvider.autoDispose
    .family<List<Tag>, String>(
      (ref, date) => ref.watch(dayRepositoryProvider).getTagsForDate(date),
    );

class GymScreen extends ConsumerWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym & Sport Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_available),
            tooltip: 'Plan Session',
            onPressed: () => PlanSportSessionSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Sport Analytics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SportAnalyticsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Gym Program Guide',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GymProgramGuideScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'gym_log_fab',
        icon: const Icon(Icons.check),
        label: const Text('Done today'),
        onPressed: () => GymSessionLogSheet.show(context, date: _todayStr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // Action Quick Cards (Plan, Guide, Analytics)
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Plan Session',
                  subtitle: 'Schedule upcoming',
                  icon: Icons.event_available,
                  color: DesignTokens.peach,
                  onTap: () => PlanSportSessionSheet.show(context),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Gym Program',
                  subtitle: 'Month 3+ Plans A/B/C',
                  icon: Icons.assignment_outlined,
                  color: DesignTokens.dustyBlue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GymProgramGuideScreen(),
                    ),
                  ),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'Analytics',
                  subtitle: 'Daily/Weekly',
                  icon: Icons.show_chart,
                  color: DesignTokens.sage,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SportAnalyticsScreen(),
                    ),
                  ),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _WeekStatCard(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Recent Sport Activities'),
          const SizedBox(height: 8),
          _RecentSportActivitiesList(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Upcoming Gym Sessions'),
          const SizedBox(height: 8),
          _UpcomingList(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'History'),
          const SizedBox(height: 8),
          _HistoryList(),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDark ? DesignTokens.adjustColorForDark(color) : color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSportActivitiesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asyncData = ref.watch(sportActivitiesProvider);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (activities) {
        if (activities.isEmpty) {
          return AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No sport activities logged yet.\nTap "Done today" below to start!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                  ),
                ),
              ),
            ),
          );
        }

        final recent = activities.take(5).toList();

        return Column(
          children: recent.map((act) {
            IconData icon = Icons.fitness_center;
            Color color = DesignTokens.dustyBlue;
            switch (act.activityType) {
              case 'Swimming':
                icon = Icons.pool;
                color = DesignTokens.sage;
                break;
              case 'Tennis':
                icon = Icons.sports_tennis;
                color = DesignTokens.butter;
                break;
              case 'Biking':
                icon = Icons.directions_bike;
                color = DesignTokens.blush;
                break;
              case 'Running':
                icon = Icons.directions_run;
                color = DesignTokens.rose;
                break;
              case 'Walking':
                icon = Icons.directions_walk;
                color = DesignTokens.peach;
                break;
              case 'Yoga':
                icon = Icons.self_improvement;
                color = DesignTokens.lavender;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: isDark ? DesignTokens.adjustColorForDark(color) : color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.activityType,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${act.date} • ${act.durationMin} min${act.calories != null ? ' • ${act.calories} kcal' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (act.notes != null && act.notes!.isNotEmpty)
                      Text(
                        act.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? DesignTokens.inkSoftDark : DesignTokens.inkSoftLight,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Week stat ─────────────────────────────────────────────────────────────────

class _WeekStatCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_weekStatProvider);
    const target = 3;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: AppColors.catFitness),
            const SizedBox(width: 12),
            Expanded(
              child: countAsync.when(
                loading: () => const Text('This week: …'),
                error: (_, _) => const Text('This week: —'),
                data: (count) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week: $count / $target sessions',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (count / target).clamp(0.0, 1.0),
                      color: AppColors.catFitness,
                      backgroundColor: AppColors.catFitness.withAlpha(40),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming sessions ─────────────────────────────────────────────────────────

class _UpcomingList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_upcomingProvider);
    return asyncData.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (sessions) {
        if (sessions.isEmpty) {
          return InkWell(
            onTap: () => PlanSportSessionSheet.show(context),
            child: const EmptyState(
              icon: Icons.event_available,
              message: 'No upcoming sessions',
              hint: 'Tap here or tap "Plan Session" above to schedule a workout!',
            ),
          );
        }
        return Column(
          children: sessions.map((s) => _SessionTile(session: s)).toList(),
        );
      },
    );
  }
}

// ── History list ──────────────────────────────────────────────────────────────

class _HistoryList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(_historyProvider);
    return asyncData.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('No history yet', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: sessions
              .take(20)
              .map((s) => _SessionTile(session: s))
              .toList(),
        );
      },
    );
  }
}

// ── Single session tile ───────────────────────────────────────────────────────

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});
  final GymSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = session.status == 'done';
    final isMissed = session.status == 'missed';
    final isPlanned = session.status == 'planned';

    final statusColor = isDone
        ? Colors.green
        : isMissed
        ? Colors.red.shade200
        : AppColors.statusPlanned;

    // Travel-day awareness: read tags for this date and warn if 'travel'
    final tagsAsync = ref.watch(_tagsForDateProvider(session.date));

    final hasTravelWarning = tagsAsync.maybeWhen(
      data: (tags) => tags.any((t) => t.name.toLowerCase() == 'travel'),
      orElse: () => false,
    );

    return AppCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(50),
          child: Icon(
            isDone
                ? Icons.check
                : isMissed
                ? Icons.close
                : Icons.fitness_center,
            color: statusColor,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Text(_formatDate(session.date)),
            if (session.planId != null) ...[
              const SizedBox(width: 6),
              _PlanBadge(planId: session.planId!),
            ],
            if (hasTravelWarning) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message: 'Travel day — you may want to reschedule',
                child: Icon(
                  Icons.flight_takeoff,
                  size: 14,
                  color: AppColors.travel,
                ),
              ),
            ],
          ],
        ),
        subtitle: _buildSubtitle(context),
        trailing: isPlanned
            ? FilledButton.tonal(
                onPressed: () => GymSessionLogSheet.show(
                  context,
                  date: session.date,
                  plannedPlanId: session.planId,
                ),
                child: const Text('Done'),
              )
            : StatusChip(status: session.status),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (session.durationMin != null) parts.add('${session.durationMin} min');
    if (session.notes != null && session.notes!.isNotEmpty) {
      parts.add(session.notes!);
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Plan badge ────────────────────────────────────────────────────────────────

class _PlanBadge extends ConsumerWidget {
  const _PlanBadge({required this.planId});
  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(workoutPlanRepositoryProvider);
    return FutureBuilder<WorkoutPlan>(
      future: repo.get(planId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.catFitness.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Plan ${snap.data!.name}',
            style: Theme.of(
              ctx,
            ).textTheme.labelSmall?.copyWith(color: AppColors.catFitness),
          ),
        );
      },
    );
  }
}

// ── Day detail gym section (exported for DayDetailScreen) ─────────────────────

class DayDetailGymSection extends ConsumerWidget {
  const DayDetailGymSection({required this.date, super.key});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(_gymSessionForDateProvider(date));

    // Travel-day awareness
    final tagsAsync = ref.watch(_tagsForDateProvider(date));
    final hasTravelWarning = tagsAsync.maybeWhen(
      data: (tags) => tags.any((t) => t.name.toLowerCase() == 'travel'),
      orElse: () => false,
    );

    return sessionAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Error: $e'),
      data: (session) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTravelWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flight_takeoff,
                      size: 14,
                      color: AppColors.travel,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Travel day — gym session may need rescheduling',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.travel),
                    ),
                  ],
                ),
              ),
            if (session == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.fitness_center, size: 16),
                      label: const Text('Log gym session'),
                      onPressed: () =>
                          GymSessionLogSheet.show(context, date: date),
                    ),
                  ),
                ],
              )
            else
              AppCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    session.status == 'done'
                        ? Icons.check_circle
                        : session.status == 'missed'
                        ? Icons.cancel
                        : Icons.fitness_center,
                    color: session.status == 'done'
                        ? Colors.green
                        : session.status == 'missed'
                        ? Colors.red.shade200
                        : AppColors.catFitness,
                  ),
                  title: Text(
                    session.status == 'done'
                        ? 'Session done${session.durationMin != null ? ' · ${session.durationMin} min' : ''}'
                        : session.status == 'missed'
                        ? 'Missed session'
                        : 'Planned session',
                  ),
                  subtitle: session.notes != null ? Text(session.notes!) : null,
                  trailing: session.status == 'planned'
                      ? FilledButton.tonal(
                          onPressed: () => GymSessionLogSheet.show(
                            context,
                            date: date,
                            plannedPlanId: session.planId,
                          ),
                          child: const Text('Done'),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _todayStr() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

String _formatDate(String iso) {
  try {
    final p = iso.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return DateFormat('EEE, MMM d').format(d);
  } catch (_) {
    return iso;
  }
}

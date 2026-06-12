import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:figma_squircle/figma_squircle.dart';

import '../../core/calendar/calendar_aggregator.dart';
import '../../core/calendar/calendar_day_data.dart';
import '../../core/conflicts/conflict_engine.dart';
import '../../core/conflicts/conflict_item.dart';
import '../../core/db/repositories/event_repository.dart';
import '../../core/db/repositories/day_repository.dart';
import '../../core/design/design.dart';
import '../calendar/day_tag_picker.dart';
import '../calendar/event_edit_sheet.dart';
import '../../core/db/database.dart';
import '../gym/gym_repository.dart';
import '../habits/habit_repository.dart';
import '../meals/meal_slot_repository.dart';
import '../meals/recipe_repository.dart';
import '../../core/services/backup_service.dart';

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

final todayTagsProvider = FutureProvider.autoDispose<List<Tag>>((ref) {
  final todayStr = _fmtDate(_todayDate());
  return ref.watch(dayRepositoryProvider).getTagsForDate(todayStr);
});

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _backupNudgeDismissedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

// ── Screen ─────────────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _todayDate();
    final todayStr = _fmtDate(today);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tag),
            tooltip: 'Day tags',
            onPressed: () => _showTagSheet(context, todayStr, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_todayDataProvider);
              ref.invalidate(_todayEventsProvider);
              ref.invalidate(todayTagsProvider);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _TodayHeader(todayStr: todayStr, today: today),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if ((ref.watch(shouldNudgeProvider).value ?? false) &&
                          !ref.watch(_backupNudgeDismissedProvider)) ...[
                        _BackupNudgeCard(
                          onBackup: () async {
                            try {
                              await ref
                                  .read(backupServiceProvider)
                                  .exportAndShare();
                              ref.invalidate(shouldNudgeProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Backup failed: $e')),
                                );
                              }
                            }
                          },
                          onDismiss: () =>
                              ref
                                      .read(
                                        _backupNudgeDismissedProvider.notifier,
                                      )
                                      .state =
                                  true,
                        ),
                        const SizedBox(height: 20),
                      ],
                      // ── Day overview strip ─────────────────────────────────
                      _DayOverviewStrip(todayStr: todayStr),
                      const SizedBox(height: 12),

                      // ── Events ────────────────────────────────────────────
                      const SectionHeader(title: "Today's Events"),
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
                      _TodayHabits(todayStr: todayStr),
                      const SizedBox(height: 20),

                      const _TodayGymQuickDone(),
                      const SizedBox(height: 100), // FAB clearance
                    ],
                  ),
                ),
              ],
            ),
          ),
          TodayFab(todayStr: todayStr),
        ],
      ),
    );
  }

  void _showTagSheet(BuildContext context, String todayStr, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tags for today',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DayTagPicker(date: todayStr),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Invalidate today tags to update header wash
      ref.invalidate(todayTagsProvider);
      ref.invalidate(_todayDataProvider);
    });
  }
}

// ── Today Header ───────────────────────────────────────────────────────────────

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader({required this.todayStr, required this.today});
  final String todayStr;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      >= 17 && < 22 => 'Good evening',
      _ => 'Good night',
    };

    final headerFmt = DateFormat('EEEE, MMMM d');
    final formattedDate = headerFmt.format(today);

    final tagsAsync = ref.watch(todayTagsProvider);

    return tagsAsync.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(height: 220),
      data: (tags) {
        final washColors = tags
            .map((t) => AppColors.forTagName(t.name))
            .toList();
        final inkColor = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;
        final inkSoftColor = isDark
            ? DesignTokens.inkSoftDark
            : DesignTokens.inkSoftLight;

        return Container(
          width: double.infinity,
          decoration: DayWashDecoration(tagColors: washColors, isDark: isDark),
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + 20,
            24,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, Nili'.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: inkSoftColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formattedDate,
                style: theme.textTheme.displayMedium?.copyWith(color: inkColor),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: tags.map((tag) {
                    final baseColor = AppColors.forTagName(tag.name);
                    final bg = DesignTokens.resolvePastelFill(
                      color: baseColor,
                      isDark: isDark,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusInput,
                        ),
                        border: Border.all(
                          color: isDark
                              ? DesignTokens.lineDark
                              : DesignTokens.lineLight,
                        ),
                      ),
                      child: Text(
                        tag.name.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? DesignTokens.inkDark : baseColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return dataAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final chips = <Widget>[];
        if (data.gymSession != null) {
          chips.add(
            const _OverviewChip(
              Icons.fitness_center,
              'Gym',
              DesignTokens.dustyBlue,
            ),
          );
        }
        if (data.mealDots > 0) {
          chips.add(
            _OverviewChip(
              Icons.restaurant,
              '${data.mealDots} meals',
              DesignTokens.peach,
            ),
          );
        }
        if (data.dueDots > 0) {
          chips.add(
            _OverviewChip(
              Icons.task_alt,
              '${data.dueDots} due',
              DesignTokens.lavender,
            ),
          );
        }
        if (data.tripBars.isNotEmpty) {
          chips.add(
            const _OverviewChip(
              Icons.flight_takeoff,
              'Travel',
              DesignTokens.sage,
            ),
          );
        }
        if (chips.isEmpty) return const SizedBox.shrink();
        return Wrap(spacing: 8, runSpacing: 8, children: chips);
      },
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = DesignTokens.resolvePastelFill(color: color, isDark: isDark);
    final fg = isDark ? DesignTokens.inkDark : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        border: Border.all(
          color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return occsAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (occs) {
        if (occs.isEmpty) {
          return EmptyState(
            icon: Icons.event_note,
            message: 'A free day. Add something — or don\'t.',
            hint: 'No calendar events scheduled for today.',
          );
        }
        return Column(
          children: occs.map((occ) {
            final e = occ.event;
            final timeStr = e.startTime != null
                ? '${e.startTime}${e.endTime != null ? ' – ${e.endTime}' : ''}'
                : null;

            final catColor = AppColors.forTagName(e.category);
            final badgeBg = DesignTokens.resolvePastelFill(
              color: catColor,
              isDark: isDark,
            );
            final badgeFg = isDark ? DesignTokens.inkDark : catColor;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _categoryIcon(e.category),
                      color: badgeFg,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    e.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: timeStr != null
                      ? Text(timeStr, style: theme.textTheme.bodySmall)
                      : null,
                  trailing: e.location != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DesignTokens.lineDark
                                : DesignTokens.lineLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.location!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => EventEditSheet.show(context, existing: e),
                ),
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
          return const SizedBox.shrink();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = switch (item.severity) {
      ConflictSeverity.error => DesignTokens.danger,
      ConflictSeverity.warning => DesignTokens.warning,
      ConflictSeverity.info => DesignTokens.dustyBlue,
    };

    final bg = DesignTokens.resolvePastelFill(
      color: color,
      isDark: isDark,
      customOpacity: isDark ? 0.18 : 0.12,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: bg,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? DesignTokens.inkDark
                          : DesignTokens.inkLight,
                    ),
                  ),
                ),
              ],
            ),
            if (item.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: item.actions
                    .map(
                      (a) => OutlinedButton(
                        onPressed: a.onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? DesignTokens.inkDark
                              : DesignTokens.inkLight,
                          side: BorderSide(color: color.withAlpha(120)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusInput,
                            ),
                          ),
                        ),
                        child: Text(a.label),
                      ),
                    )
                    .toList(),
              ),
            ],
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
            padding: EdgeInsets.symmetric(vertical: 8),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final recipeAsync = slot.recipeId != null
        ? ref.watch(_recipeNameForTodayProvider(slot.recipeId!))
        : const AsyncData<String?>(null);
    final name = recipeAsync.valueOrNull;

    final mealColor = DesignTokens.peach;
    final badgeBg = DesignTokens.resolvePastelFill(
      color: mealColor,
      isDark: isDark,
    );
    final badgeFg = isDark ? DesignTokens.inkDark : mealColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(_slotIcon(slot.slot), color: badgeFg, size: 20),
          ),
          title: Text(
            name ?? slot.slot,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(_capitalize(slot.slot)),
          trailing: _statusChip(slot.status, theme),
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

  static Widget _statusChip(String status, ThemeData theme) {
    return StatusChip(status: status, compact: true);
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

final _recipeNameForTodayProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, id) async {
      final r = await ref.watch(recipeRepositoryProvider).getById(id);
      return r?.name;
    });

final _todayActiveHabitsProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(habitRepositoryProvider).watchActiveHabits();
});

final _todayHabitLogsProvider = StreamProvider.autoDispose
    .family<List<HabitLog>, String>((ref, dateStr) {
      return ref.watch(habitRepositoryProvider).watchLogsForDate(dateStr);
    });

// ── Today habits section ──────────────────────────────────────────────────────

class _TodayHabits extends ConsumerWidget {
  const _TodayHabits({required this.todayStr});
  final String todayStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(_todayActiveHabitsProvider);
    final logsAsync = ref.watch(_todayHabitLogsProvider(todayStr));

    return habitsAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (habits) {
        if (habits.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No active habits today. Go to Track > Habits to set them up!',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return logsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
          data: (logs) {
            final countByHabitId = {for (final l in logs) l.habitId: l.count};

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: habits.map((habit) {
                  final count = countByHabitId[habit.id] ?? 0;
                  final target = habit.targetPerDay;

                  // Map water drop or checkmark, resolve colors
                  final Color habitColor =
                      habit.name.toLowerCase().contains('water')
                      ? DesignTokens.dustyBlue
                      : DesignTokens.rose;

                  return HabitPillChip(
                    name: habit.name,
                    count: count,
                    target: target,
                    color: habitColor,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(habitRepositoryProvider)
                          .incrementCount(habit.id, todayStr);
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(habitRepositoryProvider)
                          .decrementCount(habit.id, todayStr);
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ── HabitPillChip Widget (Micro-animated scale tap feedback) ───────────────────

class HabitPillChip extends StatefulWidget {
  const HabitPillChip({
    required this.name,
    required this.count,
    required this.target,
    required this.color,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final String name;
  final int count;
  final int target;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<HabitPillChip> createState() => _HabitPillChipState();
}

class _HabitPillChipState extends State<HabitPillChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final completed = widget.count >= widget.target;

    final baseColor = widget.color;
    final bgResolved = completed
        ? DesignTokens.resolvePastelFill(
            color: baseColor,
            isDark: isDark,
            customOpacity: 0.40,
          )
        : DesignTokens.resolvePastelFill(
            color: baseColor,
            isDark: isDark,
            customOpacity: 0.12,
          );
    final borderColor = completed
        ? DesignTokens.resolvePastelFill(
            color: baseColor,
            isDark: isDark,
            customOpacity: 0.80,
          )
        : isDark
        ? DesignTokens.lineDark
        : DesignTokens.lineLight;
    final fgResolved = isDark ? DesignTokens.inkDark : DesignTokens.inkLight;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgResolved,
            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: completed
                    ? Icon(
                        Icons.check_circle,
                        size: 18,
                        color: isDark ? DesignTokens.inkDark : baseColor,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (widget.count / widget.target).clamp(
                              0.0,
                              1.0,
                            ),
                            strokeWidth: 2.0,
                            backgroundColor:
                                (isDark
                                        ? DesignTokens.lineDark
                                        : DesignTokens.lineLight)
                                    .withAlpha(100),
                            color: isDark ? DesignTokens.inkDark : baseColor,
                          ),
                          Text(
                            '${widget.count}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: fgResolved,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fgResolved,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Today Gym quick done button ───────────────────────────────────────────────

class _TodayGymQuickDone extends ConsumerWidget {
  const _TodayGymQuickDone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_todayDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final session = data.gymSession;
        if (session == null || session.status != 'planned') {
          return const SizedBox.shrink();
        }

        final gymColor = DesignTokens.dustyBlue;
        final badgeBg = DesignTokens.resolvePastelFill(
          color: gymColor,
          isDark: isDark,
        );
        final badgeFg = isDark ? DesignTokens.inkDark : gymColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fitness_center, color: badgeFg, size: 20),
              ),
              title: Text(
                'Gym Session Scheduled',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Tap Done to log completion'),
              trailing: FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Done'),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await ref
                      .read(gymRepositoryProvider)
                      .logDone(
                        date: _fmtDate(DateTime.now()),
                        planId: session.planId,
                        durationMin: 45,
                      );
                  ref.invalidate(_todayDataProvider);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Today FAB & Speed-Dial Widget ──────────────────────────────────────────────

class TodayFab extends StatefulWidget {
  const TodayFab({required this.todayStr, super.key});
  final String todayStr;

  @override
  State<TodayFab> createState() => _TodayFabState();
}

class _TodayFabState extends State<TodayFab> {
  bool _isOpen = false;

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? DesignTokens.accentDark
        : DesignTokens.accentLight;

    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isOpen) ...[
                _buildOption(
                      icon: Icons.event,
                      label: 'Event',
                      color: DesignTokens.rose,
                      onTap: () {
                        _toggle();
                        EventEditSheet.show(
                          context,
                          initialDate: widget.todayStr,
                        );
                      },
                    )
                    .animate()
                    .fade(duration: 150.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 10),
                _buildOption(
                      icon: Icons.attach_money,
                      label: 'Expense',
                      color: DesignTokens.sage,
                      onTap: () {
                        _toggle();
                        context.push('/finance');
                      },
                    )
                    .animate(delay: 40.ms)
                    .fade(duration: 150.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 10),
                _buildOption(
                      icon: Icons.check_box_outlined,
                      label: 'Task',
                      color: DesignTokens.lavender,
                      onTap: () {
                        _toggle();
                        context.push('/lists');
                      },
                    )
                    .animate(delay: 80.ms)
                    .fade(duration: 150.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 10),
                _buildOption(
                      icon: Icons.flight,
                      label: 'Trip',
                      color: DesignTokens.dustyBlue,
                      onTap: () {
                        _toggle();
                        context.push('/trips');
                      },
                    )
                    .animate(delay: 120.ms)
                    .fade(duration: 150.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 10),
                _buildOption(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'Note',
                      color: DesignTokens.peach,
                      onTap: () {
                        _toggle();
                        context.push('/lists');
                      },
                    )
                    .animate(delay: 160.ms)
                    .fade(duration: 150.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 16),
              ],
              FloatingActionButton(
                heroTag: 'today_fab',
                backgroundColor: accentColor,
                elevation: 4,
                shape: SmoothRectangleBorder(
                  borderRadius: const SmoothBorderRadius.all(
                    SmoothRadius(
                      cornerRadius: DesignTokens.radiusCard,
                      cornerSmoothing: 1.0,
                    ),
                  ),
                ),
                onPressed: _toggle,
                child: AnimatedRotation(
                  turns: _isOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = DesignTokens.resolvePastelFill(color: color, isDark: isDark);
    final fg = isDark ? DesignTokens.inkDark : color;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? DesignTokens.lineDark : DesignTokens.lineLight,
              ),
              boxShadow: DesignTokens.shadow(
                isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: ShapeDecoration(
              color: bg,
              shape: SmoothRectangleBorder(
                borderRadius: const SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 12, cornerSmoothing: 1.0),
                ),
                side: BorderSide(
                  color: isDark
                      ? DesignTokens.lineDark
                      : DesignTokens.lineLight,
                ),
              ),
              shadows: DesignTokens.shadow(
                isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
              ),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Backup nudge card ─────────────────────────────────────────────────────────

class _BackupNudgeCard extends StatelessWidget {
  const _BackupNudgeCard({required this.onBackup, required this.onDismiss});

  final VoidCallback onBackup;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final warningColor = DesignTokens.warning;
    final bg = DesignTokens.resolvePastelFill(
      color: warningColor,
      isDark: isDark,
      customOpacity: isDark ? 0.18 : 0.15,
    );
    final borderColor = isDark
        ? warningColor.withAlpha(100)
        : warningColor.withAlpha(150);

    return Container(
      decoration: ShapeDecoration(
        color: bg,
        shape: SmoothRectangleBorder(
          side: BorderSide(color: borderColor, width: 1.5),
          borderRadius: const SmoothBorderRadius.all(
            SmoothRadius(
              cornerRadius: DesignTokens.radiusCard,
              cornerSmoothing: 1.0,
            ),
          ),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warningColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Backup Recommended',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? DesignTokens.inkDark
                        : DesignTokens.inkLight,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You haven\'t backed up your data in over 30 days. Export a zip backup now to keep your offline data safe.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? DesignTokens.inkDark : DesignTokens.inkLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? DesignTokens.inkDark
                      : DesignTokens.inkLight,
                  side: BorderSide(
                    color: isDark
                        ? DesignTokens.lineDark
                        : DesignTokens.lineLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusInput,
                    ),
                  ),
                ),
                child: const Text('Later'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onBackup,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Back Up Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? DesignTokens.accentDark
                      : DesignTokens.accentLight,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusInput,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
